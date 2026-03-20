"""
Quick connectivity and latency probe for AI Assistant HF endpoint.

Usage:
  python debug_hf_ai_assistant_ping.py
"""

import os
import time
from pathlib import Path

import requests
from dotenv import load_dotenv


def _getenv(name: str, default: str = "") -> str:
    value = (os.getenv(name) or default or "").strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1].strip()
    return value


def _join_url(base: str, path: str) -> str:
    base = (base or "").rstrip("/")
    if not path.startswith("/"):
        path = "/" + path
    return f"{base}{path}"


def _build_target(base: str) -> str:
    normalized = (base or "").rstrip("/")
    if normalized.endswith("/ai-assistant"):
        return _join_url(normalized, "/generate-section")
    return _join_url(normalized, "/ai-assistant/generate-section")


def _mask(secret: str) -> str:
    s = (secret or "").strip()
    if not s:
        return "<EMPTY>"
    if len(s) <= 8:
        return "*" * len(s)
    return f"{s[:4]}...{s[-4:]}"


def main() -> int:
    load_dotenv(dotenv_path=Path(__file__).resolve().with_name(".env"), override=True)
    load_dotenv()

    base_url = _getenv("AI_ASSISTANT_HF_URL")
    api_key = _getenv("AI_ASSISTANT_API_KEY")
    connect_timeout = int(_getenv("AI_ASSISTANT_CONNECT_TIMEOUT_S", "8"))
    read_timeout = int(_getenv("AI_ASSISTANT_UPSTREAM_TIMEOUT_S", "30"))

    if not base_url:
        print("ERROR: AI_ASSISTANT_HF_URL is missing.")
        return 1
    if not api_key:
        print("ERROR: AI_ASSISTANT_API_KEY is missing.")
        return 1

    url = _build_target(base_url)
    payload = {
        "section_name": "Executive Summary",
        "proposal_text": "Create a concise executive summary for a software delivery statement of work.",
        "max_tokens": 96,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    print(f"Target URL: {url}")
    print(f"API key: {_mask(api_key)}")
    print(f"Timeouts: connect={connect_timeout}s read={read_timeout}s")
    print("Sending probe request...")
    started = time.monotonic()
    try:
        response = requests.post(
            url,
            headers=headers,
            json=payload,
            timeout=(connect_timeout, read_timeout),
        )
    except requests.exceptions.RequestException as exc:
        elapsed_ms = int((time.monotonic() - started) * 1000)
        print(f"Request failed after {elapsed_ms}ms: {type(exc).__name__}: {exc}")
        return 2

    elapsed_ms = int((time.monotonic() - started) * 1000)
    print(f"Status: {response.status_code} in {elapsed_ms}ms")
    preview = (response.text or "").strip().replace("\n", " ")
    print(f"Body preview: {preview[:400]}")
    return 0 if 200 <= response.status_code <= 299 else 3


if __name__ == "__main__":
    raise SystemExit(main())
