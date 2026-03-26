"""
AI Assistant proxy routes.

These endpoints forward requests to the Hugging Face Space while keeping the
AI assistant API key server-side.
"""

import contextlib
import os
import time
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

import requests
from dotenv import load_dotenv
from flask import Blueprint, jsonify, request

from api.utils.decorators import token_required
from api.utils.database import get_db_connection


# Load backend .env regardless of cwd (mirrors other backend modules)
_env_path = Path(__file__).resolve().parents[2] / ".env"
load_dotenv(dotenv_path=_env_path)
load_dotenv()


bp = Blueprint("ai_assistant_proxy", __name__, url_prefix="")
_async_jobs: Dict[str, Dict[str, Any]] = {}
_async_jobs_lock = threading.Lock()
_async_executor: Optional[ThreadPoolExecutor] = None
# Serialize authenticated upstream POSTs so one worker never runs two HF calls at once (OOM on small RAM).
_upstream_post_lock = threading.Lock()


def _getenv(name: str, default: str = "") -> str:
    v = (os.getenv(name) or default or "").strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        v = v[1:-1].strip()
    return v


def _join_url(base: str, path: str) -> str:
    base = (base or "").rstrip("/")
    path = (path or "")
    if not path.startswith("/"):
        path = "/" + path
    return base + path


def _getenv_int(name: str, default: int, *, minimum: int, maximum: int) -> int:
    raw = (os.getenv(name) or "").strip()
    if not raw:
        return default
    try:
        parsed = int(raw)
    except Exception:
        return default
    return max(minimum, min(parsed, maximum))


def _extract_error(payload: Any) -> str:
    if isinstance(payload, dict):
        for k in ("error", "detail", "message"):
            v = payload.get(k)
            if v:
                return str(v)
    return "Upstream AI Assistant error"


def _is_async_enabled() -> bool:
    return _getenv("AI_ASSISTANT_ASYNC_ENABLED", "false").lower() in ("1", "true", "yes", "on")


def _get_async_executor() -> ThreadPoolExecutor:
    global _async_executor
    if _async_executor is None:
        _async_executor = ThreadPoolExecutor(
            max_workers=_getenv_int("AI_ASSISTANT_ASYNC_MAX_WORKERS", 1, minimum=1, maximum=8)
        )
    return _async_executor


def _set_async_job(job_id: str, patch: Dict[str, Any]) -> None:
    with _async_jobs_lock:
        existing = _async_jobs.get(job_id, {})
        existing.update(patch)
        _async_jobs[job_id] = existing


def _get_async_job(job_id: str) -> Optional[Dict[str, Any]]:
    with _async_jobs_lock:
        data = _async_jobs.get(job_id)
        return dict(data) if data is not None else None


def _parse_max_tokens(value: Any, default: int = 192) -> int:
    try:
        parsed = int(value)
    except Exception:
        parsed = default
    # Keep tokens bounded to avoid very slow generations.
    return max(48, min(parsed, 192))


def _compact_text(text: str, max_chars: int) -> str:
    t = (text or "").strip()
    if len(t) <= max_chars:
        return t
    return t[:max_chars]


def _mask_secret(secret: str) -> str:
    s = (secret or "").strip()
    if not s:
        return "<EMPTY>"
    if len(s) <= 8:
        return "*" * len(s)
    return f"{s[:4]}...{s[-4:]}"


def _build_upstream_url(hf_base: str, endpoint: str) -> str:
    normalized = (hf_base or "").rstrip("/")
    if normalized.endswith("/ai-assistant"):
        url = _join_url(normalized, endpoint)
    else:
        url = _join_url(normalized, f"/ai-assistant{endpoint}")
    return url


def _extract_text_for_token_estimate(payload: Any) -> str:
    if payload is None:
        return ""
    if isinstance(payload, str):
        return payload
    if isinstance(payload, dict):
        # Common response shapes from assistant endpoints.
        for key in ("generated_text", "improved_text", "text", "content"):
            value = payload.get(key)
            if isinstance(value, str) and value.strip():
                return value
        result = payload.get("result")
        if isinstance(result, dict):
            for key in ("generated_text", "improved_text", "text", "content"):
                value = result.get(key)
                if isinstance(value, str) and value.strip():
                    return value
        return str(payload)
    return str(payload)


def _estimate_response_tokens(payload: Any) -> int:
    text = _extract_text_for_token_estimate(payload).strip()
    if not text:
        return 0
    # Approximation: word count as lightweight token proxy for dashboard budgeting.
    return max(1, len(text.split()))


def _track_ai_usage(
    *,
    username: Optional[str],
    endpoint: str,
    prompt_text: str,
    section_type: str,
    response_tokens: int,
    response_time_ms: int,
) -> None:
    if not username:
        return
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO ai_usage (
                    username, endpoint, prompt_text, section_type, response_tokens, response_time_ms
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    username,
                    endpoint,
                    (prompt_text or "")[:500],
                    section_type,
                    int(response_tokens or 0),
                    int(response_time_ms or 0),
                ),
            )
            conn.commit()
    except Exception as track_error:
        print(f"[AI Assistant Proxy] usage tracking failed endpoint={endpoint}: {track_error}")


def _fallback_generate_section_text(section_name: str, proposal_text: str) -> str:
    seed = _compact_text(proposal_text, 1200)
    if not seed:
        seed = "No source context was provided."
    return (
        f"{section_name}\n\n"
        "This draft was generated from local fallback because the upstream AI service was unavailable.\n\n"
        "Context summary:\n"
        f"{seed}\n\n"
        "Suggested next steps:\n"
        "- Refine this section with client-specific details.\n"
        "- Add measurable outcomes, timelines, and assumptions.\n"
        "- Validate scope, dependencies, and acceptance criteria."
    )


def _fallback_improve_text(area_name: str, proposal_text: str) -> str:
    base = (proposal_text or "").strip()
    if not base:
        return (
            f"{area_name}\n\n"
            "No content was provided to improve. Please add section text and retry."
        )
    # Lightweight local cleanup when upstream AI is unavailable.
    cleaned = " ".join(base.split())
    return (
        f"{cleaned}\n\n"
        f"[Note: Local fallback applied for '{area_name}' while AI service was unavailable. "
        "Please review and polish tone/detail as needed.]"
    )


def _call_upstream(
    endpoint: str,
    payload: Optional[Dict[str, Any]] = None,
    *,
    include_auth: bool,
    connect_timeout_s: Optional[int] = None,
    read_timeout_s: Optional[int] = None,
) -> Tuple[Any, int]:
    """
    Call HF Space upstream and normalize errors.

    Returns: (json_or_normalized_error_dict, http_status_code)
    """
    hf_base = _getenv("AI_ASSISTANT_HF_URL")
    if not hf_base:
        return (
            {
                "success": False,
                "error": "AI_ASSISTANT_HF_URL is not configured on the server.",
                "upstream_status": None,
            },
            500,
        )

    url = _build_upstream_url(hf_base, endpoint)
    if "/ai-assistant/ai-assistant/" in url:
        return (
            {
                "success": False,
                "error": "Malformed AI assistant URL: duplicated /ai-assistant path.",
                "code": "UPSTREAM_URL_MISCONFIGURED",
                "upstream_status": None,
                "details": {"url": url},
            },
            500,
        )

    headers = {"Content-Type": "application/json"}
    if include_auth:
        api_key = _getenv("AI_ASSISTANT_API_KEY")
        if not api_key:
            return (
                {
                    "success": False,
                    "error": "AI_ASSISTANT_API_KEY is not configured on the server.",
                    "upstream_status": None,
                },
                500,
            )
        headers["Authorization"] = f"Bearer {api_key}"

    connect_timeout = connect_timeout_s or _getenv_int(
        "AI_ASSISTANT_CONNECT_TIMEOUT_S", 8, minimum=2, maximum=30
    )
    read_timeout = read_timeout_s or _getenv_int(
        "AI_ASSISTANT_UPSTREAM_TIMEOUT_S", 120, minimum=5, maximum=600
    )
    method = "GET" if payload is None else "POST"
    payload_chars = len(str(payload)) if payload is not None else 0
    print(
        f"[AI Assistant Proxy] request method={method} endpoint={endpoint} "
        f"url={url} payload_chars={payload_chars} include_auth={include_auth} "
        f"timeouts=({connect_timeout},{read_timeout})"
    )
    if include_auth:
        print(
            f"[AI Assistant Proxy] auth_header=Bearer {_mask_secret(headers.get('Authorization', '').replace('Bearer ', ''))}"
        )

    start = time.monotonic()
    lock_ctx = _upstream_post_lock if include_auth and method == "POST" else contextlib.nullcontext()
    try:
        with lock_ctx:
            resp = requests.request(
                method,
                url,
                headers=headers,
                json=payload,
                # Separate connect/read timeouts: fail fast on bad network, allow slow model inference.
                timeout=(connect_timeout, read_timeout),
            )
            elapsed_ms = int((time.monotonic() - start) * 1000)
            print(f"[AI Assistant Proxy] response status={resp.status_code} elapsed_ms={elapsed_ms} endpoint={endpoint}")

            # Parse body best-effort (keep inside lock so a second HF call does not start while buffering body).
            body_json: Any = None
            body_text = (resp.text or "").strip()
            if body_text:
                try:
                    body_json = resp.json()
                except Exception:
                    body_json = None

            if 200 <= resp.status_code <= 299:
                # Success: return upstream JSON if available; otherwise wrap the text.
                if body_json is not None:
                    return body_json, resp.status_code
                return {"success": True, "result": body_text}, resp.status_code

            # Error: normalize
            details: Any = body_json if body_json is not None else (body_text[:2000] if body_text else None)
            err_msg = _extract_error(details) if details is not None else "Upstream AI Assistant error"
            return (
                {
                    "success": False,
                    "error": err_msg,
                    "upstream_status": resp.status_code,
                    "details": details,
                },
                resp.status_code,
            )
    except requests.exceptions.ConnectTimeout as e:
        elapsed_ms = int((time.monotonic() - start) * 1000)
        print(
            f"[AI Assistant Proxy] connect_timeout elapsed_ms={elapsed_ms} endpoint={endpoint} "
            f"connect_timeout_s={connect_timeout} error={type(e).__name__}"
        )
        return (
            {
                "success": False,
                "error": "Upstream AI Assistant connect timeout.",
                "code": "UPSTREAM_TIMEOUT",
                "timeout_type": "connect",
                "upstream_status": None,
            },
            504,
        )
    except requests.exceptions.Timeout as e:
        elapsed_ms = int((time.monotonic() - start) * 1000)
        print(
            f"[AI Assistant Proxy] read_timeout elapsed_ms={elapsed_ms} endpoint={endpoint} "
            f"read_timeout_s={read_timeout} error={type(e).__name__}"
        )
        return (
            {
                "success": False,
                "error": "Upstream AI Assistant timed out.",
                "code": "UPSTREAM_TIMEOUT",
                "timeout_type": "read",
                "upstream_status": None,
            },
            504,
        )
    except requests.exceptions.RequestException as e:
        elapsed_ms = int((time.monotonic() - start) * 1000)
        print(f"[AI Assistant Proxy] network_error {elapsed_ms}ms {endpoint}: {type(e).__name__}")
        return (
            {
                "success": False,
                "error": "Network error calling upstream AI Assistant.",
                "code": "UPSTREAM_NETWORK_ERROR",
                "upstream_status": None,
                "details": str(e)[:500],
            },
            502,
        )


@bp.get("/ai-assistant/health")
def ai_assistant_health():
    # Per requirement: calls upstream health; no key required.
    body, status = _call_upstream("/health", payload=None, include_auth=False)
    return jsonify(body), status


@bp.post("/ai-assistant/generate-section")
@token_required
def proxy_generate_section(username=None):
    req_start = time.monotonic()
    req_id = (request.headers.get("X-AI-Request-ID") or "").strip() or f"gen-{int(time.time()*1000)}"
    data = request.get_json(silent=True) or {}
    section_name = (data.get("section_name") or "").strip()
    proposal_text = (data.get("proposal_text") or "").strip()
    max_tokens = _parse_max_tokens(data.get("max_tokens"), default=96)
    print(f"[AI Assistant Proxy][{req_id}] action=generate-section section={section_name!r} chars={len(proposal_text)} max_tokens={max_tokens}")
    if not section_name or not proposal_text:
        return (
            jsonify(
                {
                    "success": False,
                    "error": "section_name and proposal_text are required.",
                    "upstream_status": None,
                }
            ),
            400,
        )

    primary_max_chars = _getenv_int("AI_ASSISTANT_MAX_CHARS", 12000, minimum=1000, maximum=30000)
    retry_max_chars = _getenv_int("AI_ASSISTANT_RETRY_MAX_CHARS", 5000, minimum=500, maximum=20000)
    retry_max_tokens = _getenv_int("AI_ASSISTANT_RETRY_MAX_TOKENS", 96, minimum=48, maximum=192)
    retry_read_timeout = _getenv_int("AI_ASSISTANT_RETRY_TIMEOUT_S", 90, minimum=5, maximum=300)
    primary_payload = {
        "section_name": section_name,
        "proposal_text": _compact_text(proposal_text, primary_max_chars),
        "max_tokens": max_tokens,
    }
    body, status = _call_upstream(
        "/generate-section",
        primary_payload,
        include_auth=True,
    )
    print(f"[AI Assistant Proxy][{req_id}] primary_status={status}")
    # Retry once for upstream server/gateway errors (not timeout) with lighter payload.
    upstream_status = body.get("upstream_status") if isinstance(body, dict) else None
    if status in (500, 502, 503) and upstream_status in (500, 502, 503):
        fallback_payload = {
            "section_name": section_name,
            "proposal_text": _compact_text(proposal_text, retry_max_chars),
            "max_tokens": min(max_tokens, retry_max_tokens),
        }
        if fallback_payload != primary_payload:
            time.sleep(1.0)
            retry_body, retry_status = _call_upstream(
                "/generate-section",
                fallback_payload,
                include_auth=True,
                read_timeout_s=retry_read_timeout,
            )
            print(f"[AI Assistant Proxy][{req_id}] retry_status={retry_status} retry_chars={len(fallback_payload['proposal_text'])} retry_tokens={fallback_payload['max_tokens']}")
            if 200 <= retry_status <= 299:
                return jsonify(retry_body), retry_status
            # Preserve richer error details from retry attempt.
            body, status = retry_body, retry_status

    total_elapsed_ms = int((time.monotonic() - req_start) * 1000)
    print(f"[AI Assistant Proxy][{req_id}] completed status={status} total_elapsed_ms={total_elapsed_ms}")
    if 200 <= status <= 299:
        _track_ai_usage(
            username=username,
            endpoint="generate",
            prompt_text=proposal_text,
            section_type=section_name or "generate",
            response_tokens=_estimate_response_tokens(body),
            response_time_ms=total_elapsed_ms,
        )
    return jsonify(body), status


@bp.post("/ai-assistant/generate-section/async")
@token_required
def proxy_generate_section_async(username=None):
    if not _is_async_enabled():
        return jsonify({"success": False, "error": "Async AI assistant mode is disabled."}), 404

    data = request.get_json(silent=True) or {}
    section_name = (data.get("section_name") or "").strip()
    proposal_text = (data.get("proposal_text") or "").strip()
    max_tokens = _parse_max_tokens(data.get("max_tokens"), default=96)
    if not section_name or not proposal_text:
        return jsonify({"success": False, "error": "section_name and proposal_text are required."}), 400

    req_id = (request.headers.get("X-AI-Request-ID") or "").strip() or f"ai-{int(time.time()*1000)}"
    job_id = f"job-{int(time.time()*1000)}-{os.getpid()}-{abs(hash(req_id)) % 100000}"
    _set_async_job(
        job_id,
        {
            "status": "pending",
            "created_at": int(time.time()),
            "req_id": req_id,
            "action": "generate-section",
            "section_name": section_name,
        },
    )

    def _run() -> None:
        started = time.monotonic()
        payload = {
            "section_name": section_name,
            "proposal_text": _compact_text(
                proposal_text,
                _getenv_int("AI_ASSISTANT_MAX_CHARS", 12000, minimum=1000, maximum=30000),
            ),
            "max_tokens": max_tokens,
        }
        body, status = _call_upstream("/generate-section", payload, include_auth=True)
        if 200 <= status <= 299:
            _track_ai_usage(
                username=username,
                endpoint="generate",
                prompt_text=proposal_text,
                section_type=section_name or "generate",
                response_tokens=_estimate_response_tokens(body),
                response_time_ms=int((time.monotonic() - started) * 1000),
            )
            _set_async_job(job_id, {"status": "done", "status_code": status, "result": body})
        else:
            _set_async_job(job_id, {"status": "error", "status_code": status, "error": body})

    _get_async_executor().submit(_run)
    return jsonify({"success": True, "job_id": job_id, "status": "pending"}), 202


@bp.get("/ai-assistant/jobs/<job_id>")
@token_required
def proxy_ai_job_status(job_id: str, username=None):
    if not _is_async_enabled():
        return jsonify({"success": False, "error": "Async AI assistant mode is disabled."}), 404

    job = _get_async_job(job_id)
    if job is None:
        return jsonify({"success": False, "error": "Job not found."}), 404

    status = (job.get("status") or "").lower()
    if status == "done":
        return jsonify({"success": True, "job_id": job_id, "status": "done", "result": job.get("result")}), 200
    if status == "error":
        err = job.get("error")
        status_code = int(job.get("status_code") or 500)
        return jsonify({"success": False, "job_id": job_id, "status": "error", "error": err}), status_code
    return jsonify({"success": True, "job_id": job_id, "status": "pending"}), 200


@bp.post("/ai-assistant/improve-area")
@token_required
def proxy_improve_area(username=None):
    req_start = time.monotonic()
    req_id = (request.headers.get("X-AI-Request-ID") or "").strip() or f"imp-{int(time.time()*1000)}"
    data = request.get_json(silent=True) or {}
    area_name = (data.get("area_name") or "").strip()
    proposal_text = (data.get("proposal_text") or "").strip()
    max_tokens = _parse_max_tokens(data.get("max_tokens"), default=96)
    print(f"[AI Assistant Proxy][{req_id}] action=improve-area area={area_name!r} chars={len(proposal_text)} max_tokens={max_tokens}")
    if not area_name or not proposal_text:
        return (
            jsonify(
                {
                    "success": False,
                    "error": "area_name and proposal_text are required.",
                    "upstream_status": None,
                }
            ),
            400,
        )

    primary_max_chars = _getenv_int("AI_ASSISTANT_MAX_CHARS", 12000, minimum=1000, maximum=30000)
    retry_max_chars = _getenv_int("AI_ASSISTANT_RETRY_MAX_CHARS", 5000, minimum=500, maximum=20000)
    retry_max_tokens = _getenv_int("AI_ASSISTANT_RETRY_MAX_TOKENS", 96, minimum=48, maximum=192)
    retry_read_timeout = _getenv_int("AI_ASSISTANT_RETRY_TIMEOUT_S", 90, minimum=5, maximum=300)
    primary_payload = {
        "area_name": area_name,
        "proposal_text": _compact_text(proposal_text, primary_max_chars),
        "max_tokens": max_tokens,
    }
    body, status = _call_upstream(
        "/improve-area",
        primary_payload,
        include_auth=True,
    )
    print(f"[AI Assistant Proxy][{req_id}] primary_status={status}")
    # Retry once for upstream server/gateway errors (not timeout) with lighter payload.
    upstream_status = body.get("upstream_status") if isinstance(body, dict) else None
    if status in (500, 502, 503) and upstream_status in (500, 502, 503):
        fallback_payload = {
            "area_name": area_name,
            "proposal_text": _compact_text(proposal_text, retry_max_chars),
            "max_tokens": min(max_tokens, retry_max_tokens),
        }
        if fallback_payload != primary_payload:
            time.sleep(1.0)
            retry_body, retry_status = _call_upstream(
                "/improve-area",
                fallback_payload,
                include_auth=True,
                read_timeout_s=retry_read_timeout,
            )
            print(f"[AI Assistant Proxy][{req_id}] retry_status={retry_status} retry_chars={len(fallback_payload['proposal_text'])} retry_tokens={fallback_payload['max_tokens']}")
            if 200 <= retry_status <= 299:
                return jsonify(retry_body), retry_status
            body, status = retry_body, retry_status

    total_elapsed_ms = int((time.monotonic() - req_start) * 1000)
    print(f"[AI Assistant Proxy][{req_id}] completed status={status} total_elapsed_ms={total_elapsed_ms}")
    if 200 <= status <= 299:
        _track_ai_usage(
            username=username,
            endpoint="improve",
            prompt_text=proposal_text,
            section_type=area_name or "improve",
            response_tokens=_estimate_response_tokens(body),
            response_time_ms=total_elapsed_ms,
        )
    return jsonify(body), status


@bp.post("/ai-assistant/improve-area/async")
@token_required
def proxy_improve_area_async(username=None):
    if not _is_async_enabled():
        return jsonify({"success": False, "error": "Async AI assistant mode is disabled."}), 404

    data = request.get_json(silent=True) or {}
    area_name = (data.get("area_name") or "").strip()
    proposal_text = (data.get("proposal_text") or "").strip()
    max_tokens = _parse_max_tokens(data.get("max_tokens"), default=96)
    if not area_name or not proposal_text:
        return jsonify({"success": False, "error": "area_name and proposal_text are required."}), 400

    req_id = (request.headers.get("X-AI-Request-ID") or "").strip() or f"ai-{int(time.time()*1000)}"
    job_id = f"job-{int(time.time()*1000)}-{os.getpid()}-{abs(hash(req_id)) % 100000}"
    _set_async_job(
        job_id,
        {
            "status": "pending",
            "created_at": int(time.time()),
            "req_id": req_id,
            "action": "improve-area",
            "area_name": area_name,
        },
    )

    def _run() -> None:
        started = time.monotonic()
        payload = {
            "area_name": area_name,
            "proposal_text": _compact_text(
                proposal_text,
                _getenv_int("AI_ASSISTANT_MAX_CHARS", 12000, minimum=1000, maximum=30000),
            ),
            "max_tokens": max_tokens,
        }
        body, status = _call_upstream("/improve-area", payload, include_auth=True)
        if 200 <= status <= 299:
            _track_ai_usage(
                username=username,
                endpoint="improve",
                prompt_text=proposal_text,
                section_type=area_name or "improve",
                response_tokens=_estimate_response_tokens(body),
                response_time_ms=int((time.monotonic() - started) * 1000),
            )
            _set_async_job(job_id, {"status": "done", "status_code": status, "result": body})
        else:
            _set_async_job(job_id, {"status": "error", "status_code": status, "error": body})

    _get_async_executor().submit(_run)
    return jsonify({"success": True, "job_id": job_id, "status": "pending"}), 202

