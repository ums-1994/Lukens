import json
import os
import time
from typing import Any, Optional

import requests
from pydantic import BaseModel, ValidationError

from api.utils.ai_safety import AISafetyError, enforce_safe_for_external_ai


class GeminiSchemaError(Exception):
    pass


class GeminiRequestError(Exception):
    def __init__(self, message: str, *, status_code: int | None = None):
        super().__init__(message)
        self.status_code = status_code


class GeminiClient:
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        self.model = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
        self.base_url = os.getenv(
            "GEMINI_BASE_URL",
            "https://generativelanguage.googleapis.com/v1beta",
        ).rstrip("/")

        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not found in environment variables")

        self.timeout_seconds = int(os.getenv("GEMINI_TIMEOUT_SECONDS", "30"))
        self.max_retries = int(os.getenv("GEMINI_MAX_RETRIES", "2"))
        self.retry_backoff_seconds = float(os.getenv("GEMINI_RETRY_BACKOFF_SECONDS", "0.6"))

    def generate_text(
        self,
        prompt: str,
        *,
        temperature: float = 0.5,
        max_output_tokens: int = 2048,
        timeout_seconds: int | None = None,
    ) -> str:
        safe_prompt = enforce_safe_for_external_ai(prompt)

        url = f"{self.base_url}/models/{self.model}:generateContent"
        params = {"key": self.api_key}
        payload = {
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": safe_prompt}],
                }
            ],
            "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": max_output_tokens,
            },
        }

        timeout = self.timeout_seconds if timeout_seconds is None else int(timeout_seconds)

        last_exc: Exception | None = None
        for attempt in range(self.max_retries + 1):
            try:
                resp = requests.post(url, params=params, json=payload, timeout=timeout)

                # Retry on transient upstream throttling/outages.
                if resp.status_code in (429, 500, 502, 503, 504):
                    raise GeminiRequestError(
                        f"Gemini API transient error: HTTP {resp.status_code}",
                        status_code=resp.status_code,
                    )

                resp.raise_for_status()
                data = resp.json()
                break
            except requests.exceptions.Timeout as e:
                last_exc = e
            except requests.exceptions.RequestException as e:
                last_exc = e
            except GeminiRequestError as e:
                last_exc = e

            if attempt < self.max_retries:
                time.sleep(self.retry_backoff_seconds * (2 ** attempt))
        else:
            raise GeminiRequestError(
                "Gemini API request failed after retries. Verify GEMINI_API_KEY, GEMINI_MODEL, and GEMINI_BASE_URL.",
            ) from last_exc

        candidates = data.get("candidates") or []
        if not candidates:
            raise GeminiRequestError("Gemini returned no candidates")

        content = candidates[0].get("content") or {}
        parts = content.get("parts") or []
        if not parts or not isinstance(parts[0], dict) or "text" not in parts[0]:
            raise GeminiRequestError("Gemini response missing text")

        return str(parts[0]["text"])

    def generate_json(
        self,
        prompt: str,
        schema: type[BaseModel],
        *,
        temperature: float = 0.3,
        max_output_tokens: int = 2048,
        timeout_seconds: int | None = None,
    ) -> BaseModel:
        text = self.generate_text(
            prompt,
            temperature=temperature,
            max_output_tokens=max_output_tokens,
            timeout_seconds=timeout_seconds,
        )

        start_idx = text.find("{")
        end_idx = text.rfind("}") + 1
        if start_idx < 0 or end_idx <= 0:
            raise GeminiSchemaError("Gemini did not return a JSON object")

        json_str = text[start_idx:end_idx]

        try:
            parsed: Any = json.loads(json_str)
        except json.JSONDecodeError as e:
            raise GeminiSchemaError(f"Gemini returned invalid JSON: {e}")

        try:
            return schema.model_validate(parsed)
        except ValidationError as e:
            raise GeminiSchemaError(f"Gemini JSON failed schema validation: {e}")
