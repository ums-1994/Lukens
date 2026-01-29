"""
Risk Gate endpoints
"""
import hashlib
import json
import traceback
from datetime import date, datetime
from decimal import Decimal
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from api.utils.database import get_db_connection
from api.utils.ai_safety import AISafetyError, sanitize_for_external_ai, enforce_safe_for_external_ai
from api.utils.decorators import token_required

bp = Blueprint("risk_gate", __name__)


def _json_default(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    return str(value)


def _stable_json_dumps(payload) -> str:
    return json.dumps(payload, default=_json_default, ensure_ascii=False)


def _stable_json_hash(payload) -> str:
    return hashlib.sha256(
        json.dumps(payload, default=_json_default, sort_keys=True).encode("utf-8")
    ).hexdigest()


def _get_user_role(conn, username: str) -> str | None:
    cursor = conn.cursor()
    cursor.execute("SELECT role FROM users WHERE username = %s", (username,))
    row = cursor.fetchone()
    return row[0] if row else None


def _is_override_authorized(role: str | None) -> bool:
    if not role:
        return False
    role_lower = str(role).strip().lower()
    return role_lower in {
        "admin",
        "ceo",
        "manager",
        "approver",
        "finance",
        "financial manager",
    }


def _dev_bypass_user_role_hint() -> str | None:
    """When DEV bypass auth is enabled, the bypass user may not exist in the DB.

    In that case, allow a role hint based on the X-Dev-Bypass-User header if it
    matches an authorized role name.
    """
    bypass_user = (request.headers.get("X-Dev-Bypass-User") or "").strip().lower()
    if not bypass_user:
        return None
    if bypass_user in {
        "admin",
        "ceo",
        "manager",
        "approver",
        "finance",
        "financial manager",
    }:
        return bypass_user
    return None


def _map_score_to_status(score: int, issues: list) -> str:
    """Simple rule: BLOCK if any high/critical or score >= 80, REVIEW if 40–79, PASS otherwise."""
    if any(issue.get("severity") in ("high", "critical") for issue in issues):
        return "BLOCK"
    if score >= 80:
        return "BLOCK"
    if score >= 40:
        return "REVIEW"
    return "PASS"


def _build_kb_citations(conn, issues: list) -> list:
    """Return list of KB citations with doc_id + clause_id."""
    if not issues:
        return []

    clause_keys = set()
    for issue in issues:
        category = str(issue.get("category", "")).lower()
        description = str(issue.get("description", "")).lower()
        recommendation = str(issue.get("recommendation", "")).lower()
        combined = " ".join([category, description, recommendation])

        if any(t in combined for t in ["credential", "api key", "apikey", "secret", "token", "password"]):
            clause_keys.add("no_credentials_minimum")
        if any(t in combined for t in ["pii", "personal data", "personal information", "id number", "passport", "email", "phone"]):
            clause_keys.add("pii_handling_minimum")
        if any(t in combined for t in ["confidential", "confidentiality", "nda", "non-disclosure"]):
            clause_keys.add("confidentiality_minimum")

    clause_keys = sorted(clause_keys)
    if not clause_keys:
        return []

    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute(
        """
        SELECT
            c.id AS clause_id,
            d.id AS doc_id,
            d.key AS document_key,
            c.clause_key,
            c.title,
            c.category,
            c.severity,
            c.clause_text,
            c.recommended_text,
            c.tags
        FROM kb_clauses c
        JOIN kb_documents d ON d.id = c.document_id
        WHERE c.is_active = TRUE
          AND c.clause_key = ANY(%s)
        ORDER BY c.id
        """,
        (clause_keys,),
    )
    rows = cursor.fetchall() or []
    return [dict(r) for r in rows]


@bp.post("/analyze")
@token_required
def analyze(username=None):
    """Risk Gate analyze endpoint (persists a run for override/audit support)."""
    try:
        data = request.get_json()
        proposal_id = data.get("proposal_id")
        if not proposal_id:
            return {"detail": "proposal_id is required"}, 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute("SELECT * FROM proposals WHERE id = %s", (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {"detail": "Proposal not found"}, 404

            proposal_dict = dict(proposal)

            # Sanitize + block check
            safety_result = sanitize_for_external_ai(proposal_dict)
            if safety_result.blocked:
                response_body = {
                    "status": "BLOCK",
                    "risk_score": 100,
                    "issues": [],
                    "kb_citations": [],
                    "redaction_summary": {
                        "blocked": True,
                        "reasons": safety_result.block_reasons,
                        "sanitized_payload_hash": _stable_json_hash(safety_result.sanitized),
                    },
                }

                cursor.execute(
                    """
                    INSERT INTO risk_gate_runs (proposal_id, requested_by, status, risk_score, issues, kb_citations, redaction_summary)
                    VALUES (%s, %s, %s, %s, %s::jsonb, %s::jsonb, %s::jsonb)
                    RETURNING id
                    """,
                    (
                        proposal_id,
                        username,
                        response_body["status"],
                        response_body["risk_score"],
                        _stable_json_dumps(response_body["issues"]),
                        _stable_json_dumps(response_body["kb_citations"]),
                        _stable_json_dumps(response_body["redaction_summary"]),
                    ),
                )
                run_id = cursor.fetchone()["id"]
                conn.commit()

                response_body["run_id"] = run_id
                return response_body, 400

            # Run AI analysis
            from ai_service import ai_service

            try:
                ai_analysis = ai_service.analyze_proposal_risks(proposal_dict)
                issues = ai_analysis.get("issues", [])
                risk_score = ai_analysis.get("risk_score", 0)
            except Exception as exc:
                # If the AI provider is unavailable/rate-limited, do not 500.
                # Return a safe REVIEW result and persist the run so override/audit
                # flows can still proceed.
                issues = [
                    {
                        "category": "analysis_error",
                        "section": "AI Analysis",
                        "severity": "medium",
                        "description": "AI analysis temporarily unavailable",
                        "recommendation": "Manual review required",
                        "error": str(exc),
                    }
                ]
                risk_score = 50

            # KB citations
            kb_citations = _build_kb_citations(conn, issues)

            # Decision
            status = _map_score_to_status(risk_score, issues)

            # Redaction summary
            redaction_summary = {
                "blocked": False,
                "reasons": [],
                "sanitized_payload_hash": _stable_json_hash(safety_result.sanitized),
            }

            cursor.execute(
                """
                INSERT INTO risk_gate_runs (proposal_id, requested_by, status, risk_score, issues, kb_citations, redaction_summary)
                VALUES (%s, %s, %s, %s, %s::jsonb, %s::jsonb, %s::jsonb)
                RETURNING id
                """,
                (
                    proposal_id,
                    username,
                    status,
                    int(risk_score or 0),
                    _stable_json_dumps(issues),
                    _stable_json_dumps(kb_citations),
                    _stable_json_dumps(redaction_summary),
                ),
            )
            run_id = cursor.fetchone()["id"]
            conn.commit()

            return {
                "run_id": run_id,
                "status": status,
                "risk_score": risk_score,
                "issues": issues,
                "kb_citations": kb_citations,
                "redaction_summary": redaction_summary,
            }, 200

    except AISafetyError as e:
        return {
            "status": "BLOCK",
            "risk_score": 100,
            "issues": [],
            "kb_citations": [],
            "redaction_summary": {
                "blocked": True,
                "reasons": getattr(e, "reasons", []),
                "sanitized_payload_hash": None,
            },
        }, 400
    except Exception as e:
        print(f"❌ Risk Gate analyze error: {e}")
        traceback.print_exc()
        return {"detail": "Internal error"}, 500


@bp.post("/override")
@token_required
def override(username=None):
    """Override a Risk Gate run with justification and audit trail."""
    try:
        data = request.get_json(force=True, silent=True) or {}
        run_id = data.get("run_id") or data.get("risk_gate_run_id")
        override_reason = (data.get("override_reason") or data.get("reason") or "").strip()

        if not run_id:
            return {"detail": "run_id is required"}, 400
        if not override_reason:
            return {"detail": "override_reason is required"}, 400

        with get_db_connection() as conn:
            role = _get_user_role(conn, username)
            if not _is_override_authorized(role):
                bypass_role_hint = _dev_bypass_user_role_hint()
                if not _is_override_authorized(bypass_role_hint):
                    return {"detail": "Not authorized to override"}, 403

            cursor = conn.cursor(cursor_factory=RealDictCursor)
            cursor.execute(
                "SELECT id, proposal_id, status, overridden FROM risk_gate_runs WHERE id = %s",
                (run_id,),
            )
            existing = cursor.fetchone()
            if not existing:
                return {"detail": "Risk Gate run not found"}, 404

            if existing.get("overridden") is True:
                return {
                    "detail": "Run already overridden",
                    "run_id": existing.get("id"),
                    "proposal_id": existing.get("proposal_id"),
                }, 200

            cursor.execute(
                """
                INSERT INTO risk_gate_overrides (run_id, override_reason, approved_by)
                VALUES (%s, %s, %s)
                RETURNING id, approved_at
                """,
                (run_id, override_reason, username),
            )
            override_row = cursor.fetchone()

            cursor.execute(
                """
                UPDATE risk_gate_runs
                   SET overridden = TRUE,
                       override_reason = %s,
                       overridden_by = %s,
                       overridden_at = NOW(),
                       updated_at = NOW()
                 WHERE id = %s
                """,
                (override_reason, username, run_id),
            )
            conn.commit()

            return {
                "run_id": int(run_id),
                "proposal_id": existing.get("proposal_id"),
                "overridden": True,
                "override": {
                    "id": override_row.get("id"),
                    "approved_by": username,
                    "approved_at": override_row.get("approved_at").isoformat() if override_row.get("approved_at") else None,
                    "override_reason": override_reason,
                },
            }, 200
    except Exception as e:
        print(f"❌ Risk Gate override error: {e}")
        traceback.print_exc()
        return {"detail": "Internal error"}, 500
