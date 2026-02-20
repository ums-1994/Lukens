import json
from dataclasses import dataclass
from typing import Any, Optional


@dataclass
class GovernanceResult:
    score: int
    issues: list[str]
    required_sections: list[str]
    missing_required: list[str]
    missing_optional: list[str]
    blocked: bool
    block_reasons: list[str]


def _extract_sections_from_content(content_raw: Any) -> dict:
    if not content_raw:
        return {}

    content_obj = content_raw
    if isinstance(content_raw, str):
        try:
            content_obj = json.loads(content_raw)
        except Exception:
            return {}

    if not isinstance(content_obj, dict):
        return {}

    raw_sections = content_obj.get("sections")
    if not isinstance(raw_sections, list):
        return {}

    out: dict = {}
    for s in raw_sections:
        if not isinstance(s, dict):
            continue
        title = s.get("title")
        if not isinstance(title, str) or not title.strip():
            continue
        content_val = s.get("content")
        out[title.strip()] = content_val
    return out


def _normalize_template_key(template_key: Optional[str]) -> str:
    return (template_key or "").strip().lower()


def _required_optional_sections(template_key: Optional[str]) -> tuple[list[str], list[str]]:
    tk = _normalize_template_key(template_key)

    if "sow" in tk or "statement" in tk:
        required = [
            "Executive Summary",
            "Scope & Deliverables",
            "Investment",
            "Assumptions",
            "Terms and Conditions",
        ]
        optional = [
            "Risks",
            "References",
            "Team Bios",
            "Methodology",
        ]
        return required, optional

    if "rfi" in tk or "rfp" in tk:
        required = [
            "Executive Summary",
            "Scope & Deliverables",
            "Methodology",
        ]
        optional = [
            "Assumptions",
            "Risks",
            "References",
            "Team Bios",
        ]
        return required, optional

    required = [
        "Executive Summary",
        "Scope & Deliverables",
        "Methodology",
        "Assumptions",
    ]
    optional = [
        "Risks",
        "References",
        "Team Bios",
        "Conclusion",
    ]
    return required, optional


def _section_has_content(val: Any) -> bool:
    if val is None:
        return False
    if isinstance(val, str):
        return bool(val.strip())
    return True


def _resolve_sections(sections_raw: Any, content_raw: Any) -> dict:
    if isinstance(sections_raw, dict):
        return sections_raw

    if isinstance(sections_raw, str) and sections_raw.strip():
        try:
            parsed = json.loads(sections_raw)
            if isinstance(parsed, dict):
                return parsed
        except Exception:
            pass

    extracted = _extract_sections_from_content(content_raw)
    if extracted:
        return extracted

    return {}


def evaluate_governance(
    *,
    template_key: Optional[str],
    sections_raw: Any,
    content_raw: Any,
    risk_gate_status: Optional[str] = None,
    risk_gate_overridden: Optional[bool] = None,
    pass_threshold: int = 80,
    compound_optional_threshold: int = 2,
) -> GovernanceResult:
    required, optional = _required_optional_sections(template_key)
    sections = _resolve_sections(sections_raw, content_raw)

    missing_required: list[str] = []
    missing_optional: list[str] = []
    completed_required = 0

    for name in required:
        if _section_has_content(sections.get(name)):
            completed_required += 1
        else:
            missing_required.append(name)

    for name in optional:
        if not _section_has_content(sections.get(name)):
            missing_optional.append(name)

    score = 0
    if required:
        score = int(round((completed_required / len(required)) * 100))

    issues: list[str] = []
    for s in missing_required:
        issues.append(f"{s} is required")

    block_reasons: list[str] = []

    rg = (risk_gate_status or "").strip().upper()
    if rg == "BLOCK" and risk_gate_overridden is not True:
        block_reasons.append("Risk Gate is blocking release")

    if score < int(pass_threshold):
        block_reasons.append("Mandatory sections incomplete")

    # Compound risk should not block a proposal that has satisfied mandatory readiness.
    # It is intended to strengthen the block signal when mandatory sections are already
    # incomplete and multiple additional gaps exist.
    if len(missing_optional) >= int(compound_optional_threshold) and score < int(pass_threshold):
        block_reasons.append("Multiple governance gaps detected")

    blocked = len(block_reasons) > 0

    if missing_optional:
        issues.append("Optional sections missing: " + ", ".join(missing_optional[:6]))

    for r in block_reasons:
        issues.append(r)

    return GovernanceResult(
        score=int(score),
        issues=issues,
        required_sections=required,
        missing_required=missing_required,
        missing_optional=missing_optional,
        blocked=blocked,
        block_reasons=block_reasons,
    )
