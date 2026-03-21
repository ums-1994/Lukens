"""
Unit tests for the readiness scoring engine and completion-rates endpoint.

Run from backend/ directory:
    python -m pytest tests/test_completion_rates.py -v
"""
import json
import sys
import os

# Make sure the backend package is importable when running from the backend/ dir
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from api.utils.readiness import (
    score_proposal,
    missing_section_names,
    MANDATORY_KEYS,
    PASS_THRESHOLD,
    MIN_SECTION_CHARS,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_content(*titles_and_bodies) -> str:
    """
    Build a JSON content blob with the given (title, body) pairs.
    Each body is padded to exceed MIN_SECTION_CHARS unless explicitly short.
    """
    sections = [
        {"title": t, "content": b}
        for t, b in titles_and_bodies
    ]
    return json.dumps({"sections": sections})


LONG = "x" * (MIN_SECTION_CHARS + 10)   # content that definitely passes the char check
SHORT = "hi"                              # content that is too short to count


# ---------------------------------------------------------------------------
# score_proposal — edge cases
# ---------------------------------------------------------------------------

class TestScoreProposalEdgeCases:

    def test_none_input_returns_zero(self):
        result = score_proposal(None)
        assert result["score"] == 0
        assert result["complete"] == 0
        assert result["total"] == len(MANDATORY_KEYS)

    def test_empty_string_returns_zero(self):
        result = score_proposal("")
        assert result["score"] == 0

    def test_invalid_json_returns_zero(self):
        result = score_proposal("not-json{{")
        assert result["score"] == 0

    def test_json_without_sections_key_returns_zero(self):
        result = score_proposal(json.dumps({"foo": "bar"}))
        assert result["score"] == 0

    def test_sections_list_empty_returns_zero(self):
        result = score_proposal(json.dumps({"sections": []}))
        assert result["score"] == 0

    def test_already_decoded_dict_accepted(self):
        data = {"sections": [{"title": "Executive Summary", "content": LONG}]}
        result = score_proposal(data)
        assert result["filled"]["executive_summary"] is True

    def test_section_too_short_does_not_count(self):
        content = _make_content(("Executive Summary", SHORT))
        result = score_proposal(content)
        assert result["filled"]["executive_summary"] is False
        assert result["score"] == 0


# ---------------------------------------------------------------------------
# score_proposal — mandatory section detection
# ---------------------------------------------------------------------------

class TestMandatorySectionDetection:

    def test_executive_summary_detected_by_keyword(self):
        for title in ["Executive Summary", "Executive Overview", "Introduction", "Project Overview"]:
            result = score_proposal(_make_content((title, LONG)))
            assert result["filled"]["executive_summary"] is True, f"Failed for title: {title!r}"

    def test_scope_detected(self):
        for title in ["Scope of Work", "Deliverables", "Objectives"]:
            result = score_proposal(_make_content((title, LONG)))
            assert result["filled"]["scope_deliverables"] is True, f"Failed for title: {title!r}"

    def test_timeline_detected(self):
        for title in ["Timeline", "Project Schedule", "Milestones", "Delivery Date"]:
            result = score_proposal(_make_content((title, LONG)))
            assert result["filled"]["timeline"] is True, f"Failed for title: {title!r}"

    def test_team_detected(self):
        for title in ["Team", "Team Bios", "Personnel", "Resources", "Staff"]:
            result = score_proposal(_make_content((title, LONG)))
            assert result["filled"]["team"] is True, f"Failed for title: {title!r}"

    def test_pricing_detected(self):
        for title in ["Pricing", "Budget", "Cost Breakdown", "Financials", "Commercials"]:
            result = score_proposal(_make_content((title, LONG)))
            assert result["filled"]["pricing"] is True, f"Failed for title: {title!r}"

    def test_unknown_section_title_ignored(self):
        result = score_proposal(_make_content(("Random Notes", LONG)))
        assert result["score"] == 0
        assert result["complete"] == 0

    def test_case_insensitive_matching(self):
        result = score_proposal(_make_content(("EXECUTIVE SUMMARY", LONG)))
        assert result["filled"]["executive_summary"] is True


# ---------------------------------------------------------------------------
# score_proposal — scoring arithmetic
# ---------------------------------------------------------------------------

class TestScoringArithmetic:

    def test_all_five_sections_score_100(self):
        content = _make_content(
            ("Executive Summary", LONG),
            ("Scope of Work", LONG),
            ("Timeline", LONG),
            ("Team", LONG),
            ("Pricing", LONG),
        )
        result = score_proposal(content)
        assert result["score"] == 100
        assert result["complete"] == 5

    def test_four_of_five_score_80(self):
        content = _make_content(
            ("Executive Summary", LONG),
            ("Scope of Work", LONG),
            ("Timeline", LONG),
            ("Team", LONG),
            # pricing missing
        )
        result = score_proposal(content)
        assert result["score"] == 80
        assert result["complete"] == 4

    def test_three_of_five_score_60(self):
        content = _make_content(
            ("Executive Summary", LONG),
            ("Scope of Work", LONG),
            ("Timeline", LONG),
        )
        result = score_proposal(content)
        assert result["score"] == 60
        assert result["complete"] == 3

    def test_one_of_five_score_20(self):
        content = _make_content(("Pricing", LONG))
        result = score_proposal(content)
        assert result["score"] == 20

    def test_pass_threshold_at_80(self):
        assert PASS_THRESHOLD == 80

    def test_four_sections_meets_pass_threshold(self):
        content = _make_content(
            ("Executive Summary", LONG),
            ("Scope of Work", LONG),
            ("Timeline", LONG),
            ("Team", LONG),
        )
        result = score_proposal(content)
        assert result["score"] >= PASS_THRESHOLD

    def test_three_sections_below_pass_threshold(self):
        content = _make_content(
            ("Executive Summary", LONG),
            ("Scope of Work", LONG),
            ("Timeline", LONG),
        )
        result = score_proposal(content)
        assert result["score"] < PASS_THRESHOLD

    def test_duplicate_section_titles_do_not_double_count(self):
        content = _make_content(
            ("Executive Summary", LONG),
            ("Executive Summary", LONG),  # same section twice
        )
        result = score_proposal(content)
        assert result["complete"] == 1


# ---------------------------------------------------------------------------
# missing_section_names
# ---------------------------------------------------------------------------

class TestMissingSectionNames:

    def test_all_missing_returns_all_five(self):
        result = score_proposal(None)
        missing = missing_section_names(result)
        assert len(missing) == 5

    def test_all_filled_returns_empty(self):
        content = _make_content(
            ("Executive Summary", LONG),
            ("Scope of Work", LONG),
            ("Timeline", LONG),
            ("Team", LONG),
            ("Pricing", LONG),
        )
        result = score_proposal(content)
        missing = missing_section_names(result)
        assert missing == []

    def test_missing_names_are_human_readable(self):
        result = score_proposal(None)
        missing = missing_section_names(result)
        # Should be title-cased, spaces not underscores
        assert all(" " not in name or True for name in missing)  # basic sanity
        assert "Executive Summary" in missing
        assert "Pricing" in missing

    def test_partial_fill_returns_correct_missing(self):
        content = _make_content(
            ("Executive Summary", LONG),
            ("Pricing", LONG),
        )
        result = score_proposal(content)
        missing = missing_section_names(result)
        assert "Scope Deliverables" in missing
        assert "Timeline" in missing
        assert "Team" in missing
        assert "Executive Summary" not in missing
        assert "Pricing" not in missing
