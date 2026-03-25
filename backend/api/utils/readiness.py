"""
Shared proposal readiness scoring.

Used by:
  - api/routes/creator.py   → GET /api/proposals/completion-rates  (widget)
  - api/routes/pipeline.py  → GET /analytics/completion-rates       (analytics)

A section "passes" if its title matches one of the mandatory keyword groups
AND the text content is at least MIN_SECTION_CHARS non-whitespace characters.
"""
import json

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MANDATORY_SECTIONS: dict[str, list[str]] = {
    'executive_summary': ['executive summary', 'executive', 'overview', 'introduction'],
    'scope_deliverables': ['scope', 'deliverable', 'objective'],
    'timeline':           ['timeline', 'schedule', 'milestone', 'delivery date'],
    'team':               ['team', 'bio', 'personnel', 'resource', 'staff'],
    'pricing':            ['pricing', 'budget', 'cost', 'financial', 'commercials'],
}

MANDATORY_KEYS: list[str] = list(MANDATORY_SECTIONS.keys())
PASS_THRESHOLD: int = 80    # readiness score (%) needed to "pass"
MIN_SECTION_CHARS: int = 50  # minimum non-whitespace chars to count a section filled


# ---------------------------------------------------------------------------
# Core scoring
# ---------------------------------------------------------------------------

def score_proposal(content_raw) -> dict:
    """
    Parse proposal content and return a readiness dict.

    Accepts:
      - A JSON string encoding {"sections": [{"title": str, "content": str}, ...]}
      - An already-decoded dict with the same shape

    Returns:
      {
        "score":    int   (0-100),
        "filled":   {key: bool, ...},
        "complete": int,
        "total":    int,
      }
    """
    filled = {k: False for k in MANDATORY_KEYS}

    try:
        if not content_raw:
            return {'score': 0, 'filled': filled, 'complete': 0, 'total': len(MANDATORY_KEYS)}

        content = (
            json.loads(content_raw)
            if isinstance(content_raw, str)
            else content_raw
        )
        if not isinstance(content, dict):
            return {'score': 0, 'filled': filled, 'complete': 0, 'total': len(MANDATORY_KEYS)}

        sections = content.get('sections') or []
        for sec in sections:
            title = (sec.get('title') or '').lower().strip()
            text  = (sec.get('content') or '').strip()
            if len(text) < MIN_SECTION_CHARS:
                continue
            for key, keywords in MANDATORY_SECTIONS.items():
                if not filled[key] and any(kw in title for kw in keywords):
                    filled[key] = True

    except Exception:
        pass

    total    = len(MANDATORY_KEYS)
    complete = sum(filled.values())
    score    = round(complete / total * 100) if total else 0
    return {'score': score, 'filled': filled, 'complete': complete, 'total': total}


def missing_section_names(scored: dict) -> list[str]:
    """Return human-readable names of sections not yet filled."""
    return [k.replace('_', ' ').title() for k, v in scored['filled'].items() if not v]
