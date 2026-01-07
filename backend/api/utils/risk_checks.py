import re


def _norm_text(value) -> str:
    if value is None:
        return ""
    return str(value)


def _join_text_parts(parts) -> str:
    return "\n".join([p for p in parts if p])


def _risk_level_from_score(score: int) -> str:
    if score >= 80:
        return "critical"
    if score >= 60:
        return "high"
    if score >= 30:
        return "medium"
    return "low"


def run_prechecks(proposal_dict: dict) -> dict:
    title = _norm_text(proposal_dict.get("title"))
    client = _norm_text(proposal_dict.get("client") or proposal_dict.get("client_name"))
    client_email = _norm_text(proposal_dict.get("client_email") or proposal_dict.get("clientEmail"))
    content = _norm_text(proposal_dict.get("content"))

    sections = proposal_dict.get("sections")
    if isinstance(sections, dict):
        sections_text = _join_text_parts([_norm_text(v) for v in sections.values()])
    else:
        sections_text = _norm_text(sections)

    text_blob = _join_text_parts([title, client, client_email, content, sections_text])
    text_lc = text_blob.lower()

    issues = []
    score = 0

    def add_issue(category: str, severity: str, section: str, description: str, recommendation: str, points: int):
        nonlocal score
        issues.append(
            {
                "category": category,
                "severity": severity,
                "section": section,
                "description": description,
                "recommendation": recommendation,
                "points": points,
            }
        )
        score += int(points)

    if not title.strip():
        add_issue(
            "missing_title",
            "medium",
            "Proposal",
            "Proposal title is missing.",
            "Add a clear proposal title.",
            10,
        )

    if not client.strip() or client.strip().lower() in {"unknown", "unknown client"}:
        add_issue(
            "missing_client",
            "high",
            "Client",
            "Client name is missing or unknown.",
            "Specify a real client name.",
            20,
        )

    if not client_email.strip() or "@" not in client_email:
        add_issue(
            "missing_client_email",
            "high",
            "Client",
            "Client email is missing or invalid.",
            "Add a valid client email.",
            20,
        )

    if len(text_blob.strip()) < 400:
        add_issue(
            "insufficient_content",
            "high",
            "Content",
            "Proposal content appears too short to be a real proposal.",
            "Add more detailed scope, deliverables, timeline, and terms.",
            25,
        )

    placeholders = [
        "lorem ipsum",
        "tbd",
        "to be determined",
        "insert",
        "placeholder",
        "[client name]",
        "[insert",
    ]
    placeholder_hits = sum(1 for p in placeholders if p in text_lc)
    if placeholder_hits:
        add_issue(
            "placeholder_content",
            "high",
            "Content",
            "Proposal includes placeholder text.",
            "Replace placeholders with real values.",
            15 + min(15, placeholder_hits * 5),
        )

    pii_patterns = [r"\b\d{3}-\d{2}-\d{4}\b", r"\b\d{16}\b"]
    if any(re.search(p, text_blob) for p in pii_patterns):
        add_issue(
            "pii_detected",
            "critical",
            "Compliance",
            "Potential sensitive personal/financial identifiers detected.",
            "Remove sensitive identifiers; include only necessary contact info.",
            60,
        )

    restricted_terms = [
        "guarantee",
        "100%",
        "no risk",
        "sure thing",
    ]
    if any(t in text_lc for t in restricted_terms):
        add_issue(
            "overpromising",
            "high",
            "Claims",
            "Overpromising language detected.",
            "Replace absolute guarantees with measurable outcomes and assumptions.",
            20,
        )

    overall = _risk_level_from_score(score)
    can_release = overall in {"low", "medium"}

    summary = f"Deterministic checks: {len(issues)} issue(s) found."
    return {
        "risk_score": score,
        "overall_risk_level": overall,
        "can_release": can_release,
        "issues": issues,
        "summary": summary,
    }


def combine_assessments(precheck_summary: dict, ai_result: dict | None) -> dict:
    ai_result = ai_result or {}

    combined_issues = []
    for src in (precheck_summary.get("issues") or []):
        combined_issues.append(src)
    for src in (ai_result.get("issues") or []):
        combined_issues.append(src)

    score = 0
    try:
        score += int(precheck_summary.get("risk_score") or 0)
    except Exception:
        pass
    try:
        score += int(ai_result.get("risk_score") or 0)
    except Exception:
        pass

    overall = _risk_level_from_score(score)
    can_release = overall in {"low", "medium"}

    summary_parts = []
    if precheck_summary.get("summary"):
        summary_parts.append(str(precheck_summary.get("summary")))
    if ai_result.get("summary"):
        summary_parts.append(str(ai_result.get("summary")))

    return {
        "risk_score": score,
        "overall_risk_level": overall,
        "can_release": can_release,
        "issues": combined_issues,
        "summary": " ".join(summary_parts).strip() or "Risk analysis complete.",
        "precheck": precheck_summary,
        "ai": ai_result,
    }
