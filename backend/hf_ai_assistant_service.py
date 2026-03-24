"""
Hugging Face AI Assistant API client.
Calls the deployed HF Space: generate-section, improve-area, correct-clause.
Uses Bearer token auth; handles 401, 400 (guardrails), retries for 5xx/timeouts.
"""

import os
import random
import time
import requests
from pathlib import Path
from typing import Dict, Any, Optional
from dotenv import load_dotenv

# Load backend .env so we get AI_ASSISTANT_HF_* regardless of cwd
_env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=_env_path)
load_dotenv()  # allow override from cwd

def _getenv(name: str, default: str = "") -> str:
    v = os.getenv(name) or default
    v = (v or "").strip()
    # .env mistakes: AI_ASSISTANT_API_KEY="foo" sometimes leaves quotes depending on editor
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        v = v[1:-1].strip()
    return v

# Support both naming conventions; no baked-in Space URL — set AI_ASSISTANT_HF_URL in .env / Render.
_raw_base = (_getenv("AI_ASSISTANT_HF_URL") or _getenv("HF_AI_ASSISTANT_BASE_URL") or "").rstrip("/")
HF_AI_ASSISTANT_BASE_URL = ""
if _raw_base:
    HF_AI_ASSISTANT_BASE_URL = (
        _raw_base if "/ai-assistant" in _raw_base else f"{_raw_base}/ai-assistant"
    )

# Prefer AI_ASSISTANT_API_KEY (matches HF Space secret name); fallback to AI_ASSISTANT_HF_TOKEN
AI_ASSISTANT_API_KEY = _getenv("AI_ASSISTANT_API_KEY") or _getenv("AI_ASSISTANT_HF_TOKEN") or None

# Retry config for transient errors
MAX_RETRIES = 3
BASE_DELAY = 1.0
TIMEOUT = 60


class HFAIAssistantError(Exception):
    """Raised when the HF AI Assistant API returns an error we surface to the caller."""
    def __init__(self, message: str, status_code: Optional[int] = None, reasons: Optional[list] = None):
        super().__init__(message)
        self.status_code = status_code
        self.reasons = reasons or []


class HFAIAssistantService:
    """Client for the Hugging Face AI Assistant API (generate-section, improve-area, correct-clause)."""

    def __init__(self, base_url: Optional[str] = None, api_key: Optional[str] = None):
        self.base_url = (base_url or HF_AI_ASSISTANT_BASE_URL).rstrip("/")
        raw = (api_key or AI_ASSISTANT_API_KEY) or ""
        self.api_key = raw.strip() if isinstance(raw, str) else ""
        if not self.api_key:
            raise ValueError("AI_ASSISTANT_HF_TOKEN (or AI_ASSISTANT_API_KEY) is required for HF AI Assistant.")
        if not (self.base_url or "").strip():
            raise ValueError("AI_ASSISTANT_HF_URL (or HF_AI_ASSISTANT_BASE_URL) is required for HF AI Assistant.")
        # Some HF Spaces expect "Bearer <token>"; others accept token as-is
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        print(f"[HF AI Assistant] Using token from env (length={len(self.api_key)}), base={self.base_url}")

    def _make_request(self, endpoint: str, data: dict) -> dict:
        url = f"{self.base_url}{endpoint}"
        last_exc = None
        for attempt in range(MAX_RETRIES):
            try:
                response = requests.post(
                    url,
                    headers=self.headers,
                    json=data,
                    timeout=TIMEOUT,
                )
                # 401: do not retry
                if response.status_code == 401:
                    err = self._parse_error(response, "Authentication failed: Invalid or missing API key.")
                    raise HFAIAssistantError(err, status_code=401)
                # 403: public Space can still return this from *your* app (wrong API key) or HF edge
                if response.status_code == 403:
                    body_preview = (response.text or "")[:800]
                    print(f"DEBUG: HF Assistant 403 response body: {body_preview!r}")
                    err = self._parse_error(
                        response,
                        "Forbidden (403). Check API key matches Space secret, or response body above.",
                    )
                    raise HFAIAssistantError(err, status_code=403)
                # 400: guardrails or bad request – do not retry
                if response.status_code == 400:
                    err, reasons = self._parse_400(response)
                    raise HFAIAssistantError(err, status_code=400, reasons=reasons)
                response.raise_for_status()
                return response.json()
            except HFAIAssistantError:
                raise
            except requests.exceptions.HTTPError as e:
                last_exc = e
                if e.response is not None and e.response.status_code in (500, 502, 503):
                    if attempt < MAX_RETRIES - 1:
                        delay = BASE_DELAY * (2 ** attempt) + random.uniform(0, 1)
                        print(f"⚠️ HF AI Assistant server error ({e.response.status_code}), retry in {delay:.1f}s")
                        time.sleep(delay)
                    else:
                        raise HFAIAssistantError(
                            f"AI Assistant unavailable (server error {e.response.status_code}). Please try again later.",
                            status_code=e.response.status_code,
                        )
                else:
                    err = self._parse_error(e.response, str(e)) if e.response else str(e)
                    raise HFAIAssistantError(err, status_code=e.response.status_code if e.response else None)
            except requests.exceptions.RequestException as e:
                last_exc = e
                if attempt < MAX_RETRIES - 1:
                    delay = BASE_DELAY * (2 ** attempt) + random.uniform(0, 1)
                    print(f"⚠️ HF AI Assistant network error, retry in {delay:.1f}s: {e}")
                    time.sleep(delay)
                else:
                    raise HFAIAssistantError(f"Network or connection error: {e}")
        raise HFAIAssistantError(str(last_exc) if last_exc else "Request failed")

    @staticmethod
    def _parse_error(response: Optional[requests.Response], default: str) -> str:
        if not response or not response.text:
            return default
        try:
            body = response.json()
            return body.get("error") or body.get("detail") or body.get("message") or default
        except Exception:
            return response.text[:500] if response.text else default

    @staticmethod
    def _parse_400(response: requests.Response) -> tuple:
        """Return (message, reasons) for 400 (e.g. guardrails blocked)."""
        default_msg = "Content blocked due to safety policy."
        reasons = []
        try:
            body = response.json()
            reasons = body.get("reasons") or body.get("block_reasons")
            if isinstance(reasons, list):
                reasons = [str(r) for r in reasons]
            else:
                reasons = [str(reasons)] if reasons else []
            msg = body.get("message") or body.get("detail") or body.get("error")
            if reasons:
                msg = msg or default_msg
                msg = f"{msg}: {'; '.join(reasons)}"
            else:
                msg = msg or default_msg
            return msg, reasons
        except Exception:
            return default_msg, []

    def generate_section(self, section_name: str, proposal_text: str) -> dict:
        """POST /generate-section. Returns dict with generated_text, optional reasoning, confidence."""
        data = {"section_name": section_name, "proposal_text": proposal_text}

        # Surgeon-style diagnostics for 401s: log target + masked auth header
        try:
            auth = self.headers.get("Authorization", "")
            masked = ""
            if auth:
                # e.g. "Bearer sk-xxxx..."
                prefix = auth[:12]
                suffix = auth[-4:]
                masked = f"{prefix}...{suffix}"
            else:
                masked = "<EMPTY>"
            print(f"DEBUG: HF Assistant Target URL: {self.base_url}/generate-section")
            # len(auth) is whole header; api_key len matters for HF private-Space vs custom-key confusion
            print(
                f"DEBUG: HF Assistant Auth: {masked} "
                f"(header_len={len(auth)}, api_key_len={len(self.api_key)})"
            )
        except Exception as log_err:
            print(f"DEBUG: Failed to log HF Assistant headers: {log_err}")

        return self._make_request("/generate-section", data)

    def improve_area(self, area_name: str, proposal_text: str) -> dict:
        """POST /improve-area. Returns dict with generated_text (improved content), optional reasoning, confidence."""
        data = {"area_name": area_name, "proposal_text": proposal_text}
        return self._make_request("/improve-area", data)

    def correct_clause(self, clause_name: str, proposal_text: str) -> dict:
        """POST /correct-clause. Returns dict with generated_text, optional reasoning, confidence."""
        data = {"clause_name": clause_name, "proposal_text": proposal_text}
        return self._make_request("/correct-clause", data)


def get_hf_ai_assistant_service() -> Optional[HFAIAssistantService]:
    """Return a configured HFAIAssistantService if URL + API key are set, else None."""
    if not AI_ASSISTANT_API_KEY or not HF_AI_ASSISTANT_BASE_URL:
        return None
    try:
        return HFAIAssistantService()
    except ValueError:
        return None
