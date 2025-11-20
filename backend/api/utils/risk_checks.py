import json
from typing import Any, Dict, List


class RiskPrecheck:
    """Lightweight deterministic checks that run before the AI risk gate."""

    placeholder_tokens = {"lorem ipsum", "tbd", "to be decided", "filler text", "template text"}
    mandatory_sections = {"introduction", "scope", "deliverables", "timeline", "commercials", "assumptions"}

    def __init__(self, proposal: Dict[str, Any]):
        self.proposal = proposal or {}
        self.issues: List[Dict[str, Any]] = []
        self.flags: Dict[str, List[str]] = {
            "missing_sections": [],
            "incomplete_metadata": [],
            "placeholder_hits": [],
            "currency_anomalies": [],
        }
        self.block_release = False
        self.risk_score = 0

    def _add_issue(self, category: str, severity: str, description: str, recommendation: str):
        severity_weights = {"low": 5, "medium": 10, "high": 20, "critical": 35}
        self.issues.append(
            {
                "category": category,
                "severity": severity,
                "description": description,
                "recommendation": recommendation,
            }
        )
        self.risk_score += severity_weights.get(severity.lower(), 5)
        if severity.lower() in {"high", "critical"}:
            self.block_release = True

    def check_sections(self):
        sections = self.proposal.get("sections")
        if isinstance(sections, str):
            try:
                sections = json.loads(sections or "{}")
            except json.JSONDecodeError:
                sections = {}

        section_keys = {k.lower() for k in sections.keys()} if isinstance(sections, dict) else set()
        missing = sorted(self.mandatory_sections - section_keys)
        if missing:
            self.flags["missing_sections"] = missing
            self._add_issue(
                "structure",
                "medium",
                f"Missing required sections: {', '.join(missing)}",
                "Complete the mandatory structure before sending to clients.",
            )

    def check_metadata(self):
        required = {
            "client_name": "Client name is required",
            "title": "Proposal title is required",
            "status": "Proposal status missing",
        }
        for field, message in required.items():
            value = self.proposal.get(field) or self.proposal.get(field.replace("client_", "client"))
            if not value:
                self.flags["incomplete_metadata"].append(field)
                self._add_issue("metadata", "medium", message, f"Populate the `{field}` field.")

    def check_placeholders(self):
        text_fields = [
            self.proposal.get("title", ""),
            self.proposal.get("content", ""),
            json.dumps(self.proposal.get("sections", "")),
        ]
        hits = set()
        for text in text_fields:
            lower = str(text).lower()
            for placeholder in self.placeholder_tokens:
                if placeholder in lower:
                    hits.add(placeholder)
        if hits:
            self.flags["placeholder_hits"] = sorted(hits)
            self._add_issue(
                "quality",
                "high",
                f"Placeholder content detected: {', '.join(hits)}",
                "Replace template fillers with final customer-ready wording.",
            )

    def check_currency(self):
        currency = (self.proposal.get("currency") or "USD").upper()
        total_value = self.proposal.get("total_value") or self.proposal.get("budget")
        try:
            total_value = float(total_value) if total_value is not None else None
        except (TypeError, ValueError):
            total_value = None

        if total_value is None:
            self.flags["currency_anomalies"].append("missing_budget")
            self._add_issue("financials", "medium", "Budget/value missing", "Provide a total commercial value.")
        elif total_value <= 0:
            self.flags["currency_anomalies"].append("non_positive_budget")
            self._add_issue(
                "financials",
                "high",
                "Budget is non-positive",
                "Ensure the commercial value is captured correctly.",
            )

        if currency not in {"USD", "ZAR", "GBP", "EUR"}:
            self.flags["currency_anomalies"].append("unsupported_currency")
            self._add_issue(
                "financials",
                "low",
                f"Currency {currency} is not on the approved list",
                "Confirm FX conversions with finance before release.",
            )

    def run_all(self) -> Dict[str, Any]:
        self.check_sections()
        self.check_metadata()
        self.check_placeholders()
        self.check_currency()

        summary = "Deterministic checks completed."
        if self.block_release:
            summary = "Blocking issues detected. Do not release without remediation."
        elif self.risk_score == 0:
            summary = "No blocking deterministic signals detected."

        return {
            "issues": self.issues,
            "flags": self.flags,
            "risk_score": min(self.risk_score, 100),
            "block_release": self.block_release,
            "summary": summary,
        }


def run_prechecks(proposal_data: Dict[str, Any]) -> Dict[str, Any]:
    """Public entry point used by the Flask route."""
    checker = RiskPrecheck(proposal_data or {})
    return checker.run_all()


def combine_assessments(precheck_summary: Dict[str, Any], ai_assessment: Dict[str, Any]) -> Dict[str, Any]:
    """Merge deterministic signals with AI verdict."""
    precheck_score = precheck_summary.get("risk_score", 0) or 0
    ai_score = ai_assessment.get("risk_score", 0) or 0

    combined_score = int(round((precheck_score * 0.4) + (ai_score * 0.6)))
    combined_issues = []
    combined_issues.extend(precheck_summary.get("issues", []))
    combined_issues.extend(ai_assessment.get("issues", []))

    if combined_score >= 80:
        level = "critical"
    elif combined_score >= 60:
        level = "high"
    elif combined_score >= 40:
        level = "medium"
    else:
        level = "low"

    can_release = bool(ai_assessment.get("can_release", True)) and not precheck_summary.get("block_release", False)

    return {
        "overall_risk_level": level,
        "risk_score": combined_score,
        "issues": combined_issues,
        "precheck_summary": precheck_summary,
        "ai_summary": ai_assessment,
        "can_release": can_release,
        "required_actions": ai_assessment.get("required_actions") or [],
        "summary": ai_assessment.get("summary") or precheck_summary.get("summary"),
    }
