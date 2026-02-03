import re
from dataclasses import dataclass
from typing import Any, Dict, List, Tuple


class AISafetyError(Exception):
    def __init__(self, message: str, *, reasons: List[str] | None = None):
        super().__init__(message)
        self.reasons = reasons or []


@dataclass
class SanitizationResult:
    sanitized: Any
    redactions: List[str]
    blocked: bool
    block_reasons: List[str]


_EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
_PHONE_RE = re.compile(
    r"\b(?:(?:\+?\d{1,3}[\s.-]+)?(?:\(\d{2,4}\)[\s.-]+)?\d{3,4}[\s.-]+\d{4})\b"
)

# Common secret patterns (MVP)
_OPENAI_KEY_RE = re.compile(r"\bsk-[A-Za-z0-9]{20,}\b")
_OPENAI_KEY_V2_RE = re.compile(r"\bsk-(?:live|test)-[A-Za-z0-9]{10,}\b")
_AWS_ACCESS_KEY_RE = re.compile(r"\bAKIA[0-9A-Z]{16}\b")
_SLACK_TOKEN_RE = re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")
_GOOGLE_API_KEY_RE = re.compile(r"\bAIza[0-9A-Za-z\-_]{30,}\b")
_BEARER_RE = re.compile(r"\bBearer\s+[A-Za-z0-9\-\._~\+/]+=*\b", re.IGNORECASE)
_PRIVATE_KEY_RE = re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")

# Some strong indicators that we should NOT send any of this content to third-party AI.
_DO_NOT_SEND_PATTERNS: List[Tuple[str, re.Pattern]] = [
    ("email", _EMAIL_RE),
    ("phone", _PHONE_RE),
    ("private_key", _PRIVATE_KEY_RE),
    ("openai_api_key", _OPENAI_KEY_RE),
    ("openai_api_key", _OPENAI_KEY_V2_RE),
    ("aws_access_key", _AWS_ACCESS_KEY_RE),
    ("slack_token", _SLACK_TOKEN_RE),
    ("google_api_key", _GOOGLE_API_KEY_RE),
    ("bearer_token", _BEARER_RE),
]


def _redact_text(text: str) -> Tuple[str, List[str], List[str]]:
    redactions: List[str] = []
    block_reasons: List[str] = []

    for name, pattern in _DO_NOT_SEND_PATTERNS:
        if pattern.search(text):
            block_reasons.append(name)

    def sub_and_mark(pattern: re.Pattern, replacement: str, label: str) -> None:
        nonlocal text
        if pattern.search(text):
            redactions.append(label)
            text = pattern.sub(replacement, text)

    sub_and_mark(_EMAIL_RE, "[REDACTED_EMAIL]", "email")
    sub_and_mark(_PHONE_RE, "[REDACTED_PHONE]", "phone")

    # Even if we redact secrets, we still block outbound calls if we detected them.
    sub_and_mark(_OPENAI_KEY_RE, "[REDACTED_API_KEY]", "api_key")
    sub_and_mark(_OPENAI_KEY_V2_RE, "[REDACTED_API_KEY]", "api_key")
    sub_and_mark(_AWS_ACCESS_KEY_RE, "[REDACTED_AWS_ACCESS_KEY]", "aws_access_key")
    sub_and_mark(_SLACK_TOKEN_RE, "[REDACTED_SLACK_TOKEN]", "slack_token")
    sub_and_mark(_GOOGLE_API_KEY_RE, "[REDACTED_GOOGLE_API_KEY]", "google_api_key")
    sub_and_mark(_BEARER_RE, "Bearer [REDACTED_TOKEN]", "bearer_token")

    return text, redactions, block_reasons


def sanitize_for_external_ai(payload: Any) -> SanitizationResult:
    redactions: List[str] = []
    block_reasons: List[str] = []

    def walk(value: Any) -> Any:
        if value is None:
            return None
        if isinstance(value, (int, float, bool)):
            return value
        if isinstance(value, str):
            sanitized, r, b = _redact_text(value)
            redactions.extend(r)
            block_reasons.extend(b)
            return sanitized
        if isinstance(value, list):
            return [walk(v) for v in value]
        if isinstance(value, tuple):
            return [walk(v) for v in value]
        if isinstance(value, dict):
            out: Dict[str, Any] = {}
            for k, v in value.items():
                out[str(k)] = walk(v)
            return out

        # Unknown objects: fall back to string representation
        sanitized, r, b = _redact_text(str(value))
        redactions.extend(r)
        block_reasons.extend(b)
        return sanitized

    sanitized_payload = walk(payload)
    unique_redactions = sorted(set(redactions))
    unique_block_reasons = sorted(set(block_reasons))

    return SanitizationResult(
        sanitized=sanitized_payload,
        redactions=unique_redactions,
        blocked=bool(unique_block_reasons),
        block_reasons=unique_block_reasons,
    )


def enforce_safe_for_external_ai(payload: Any) -> Any:
    result = sanitize_for_external_ai(payload)
    if result.blocked:
        raise AISafetyError(
            "Blocked outbound AI request due to sensitive data detected.",
            reasons=result.block_reasons,
        )
    return result.sanitized
