import json
import os
from typing import Any, Optional

import requests
from pydantic import BaseModel, ValidationError

from api.utils.ai_safety import AISafetyError, enforce_safe_for_external_ai


class GeminiSchemaError(Exception):
    pass


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

    def generate_text(
        self,
        prompt: str,
        *,
        temperature: float = 0.5,
        max_output_tokens: int = 2048,
        timeout_seconds: int = 60,
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

        try:
            resp = requests.post(url, params=params, json=payload, timeout=timeout_seconds)
            resp.raise_for_status()
            data = resp.json()
        except requests.exceptions.RequestException as e:
            raise Exception(
                "Gemini API request failed (HTTP error). Verify GEMINI_API_KEY, GEMINI_MODEL, and GEMINI_BASE_URL."
            ) from e

        candidates = data.get("candidates") or []
        if not candidates:
            raise Exception("Gemini returned no candidates")

        content = candidates[0].get("content") or {}
        parts = content.get("parts") or []
        if not parts or not isinstance(parts[0], dict) or "text" not in parts[0]:
            raise Exception("Gemini response missing text")

        return str(parts[0]["text"])

    def generate_json(
        self,
        prompt: str,
        schema: type[BaseModel],
        *,
        temperature: float = 0.3,
        max_output_tokens: int = 2048,
        timeout_seconds: int = 60,
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
