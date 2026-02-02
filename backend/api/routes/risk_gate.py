"""
Risk Gate endpoints
"""
import hashlib
import json
import traceback
from datetime import date, datetime
from decimal import Decimal
from flask import Blueprint, request, jsonify
from psycopg2.extras import RealDictCursor

from api.utils.database import get_db_connection
from api.utils.ai_safety import AISafetyError, sanitize_for_external_ai, enforce_safe_for_external_ai
from api.utils.decorators import token_required

bp = Blueprint("risk_gate", __name__)


def _parse_datetime_param(value: str | None):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return datetime.strptime(value, "%Y-%m-%d")


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
                return response_body, 200

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
        }, 200
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


@bp.get("/summary")
@token_required
def summary(username=None, user_id=None, email=None):
    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_datetime_param(start_date_raw)
        end_date = _parse_datetime_param(end_date_raw)
        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        owner_filter = (request.args.get("owner") or request.args.get("owner_id") or "").strip()
        proposal_type = (request.args.get("proposal_type") or "").strip()
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "team").strip().lower()
        department_filter = (request.args.get("department") or "").strip()

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)

            cursor.execute(
                """
                SELECT column_name, data_type
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'proposals'
                """
            )
            cols = cursor.fetchall() or []
            existing_columns = {r["column_name"] for r in cols}
            col_types = {r["column_name"]: r["data_type"] for r in cols}

            owner_col = None
            if "owner_id" in existing_columns:
                owner_col = "owner_id"
            elif "user_id" in existing_columns:
                owner_col = "user_id"
            if not owner_col:
                return jsonify({"detail": "Proposals table is missing owner column"}), 500

            owner_col_type = (col_types.get(owner_col) or "").lower()
            owner_col_is_text = owner_col_type in {"character varying", "text", "varchar"}

            proposal_type_col = None
            if "template_type" in existing_columns:
                proposal_type_col = "template_type"
            elif "template_key" in existing_columns:
                proposal_type_col = "template_key"

            client_cols = [c for c in ("client", "client_name", "client_email") if c in existing_columns]

            owner_id_val = user_id
            if not owner_id_val:
                lookup_email = email or username
                cursor.execute(
                    "SELECT id FROM users WHERE email = %s OR username = %s",
                    (lookup_email, username),
                )
                row = cursor.fetchone()
                owner_id_val = row["id"] if row else None

            if not owner_id_val:
                return jsonify(
                    {
                        "filters": {
                            "start_date": start_date_raw,
                            "end_date": end_date_raw,
                            "owner": owner_filter or None,
                            "proposal_type": proposal_type or None,
                            "client": client_filter or None,
                            "scope": scope,
                            "department": department_filter or None,
                        },
                        "overall_level": "NONE",
                        "counts": {"PASS": 0, "REVIEW": 0, "BLOCK": 0, "NONE": 0},
                        "total_proposals": 0,
                        "analyzed_proposals": 0,
                    }
                ), 200

            team_owner_ids = None
            if scope in {"team", "all"} and not owner_filter:
                cursor.execute(
                    "SELECT role, department FROM users WHERE id = %s",
                    (owner_id_val,),
                )
                me = cursor.fetchone() or {}
                my_role = (me.get("role") or "").strip().lower()
                my_department = (me.get("department") or "").strip() or None

                if scope == "all":
                    if my_role not in {"admin", "ceo"}:
                        return jsonify({"detail": "Not authorized for scope=all"}), 403
                    team_owner_ids = None
                else:
                    dept = department_filter or my_department
                    if dept:
                        cursor.execute("SELECT id FROM users WHERE department = %s", (dept,))
                        team_owner_ids = [int(r["id"]) for r in cursor.fetchall() or []]
                    else:
                        team_owner_ids = [int(owner_id_val)]

            resolved_owner_id = None
            if owner_filter:
                cursor.execute(
                    "SELECT id FROM users WHERE username = %s OR email = %s OR id::text = %s",
                    (owner_filter, owner_filter, owner_filter),
                )
                owner_row = cursor.fetchone()
                if owner_row:
                    resolved_owner_id = owner_row["id"]
                else:
                    return jsonify(
                        {
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter,
                                "proposal_type": proposal_type or None,
                                "client": client_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                            },
                            "overall_level": "NONE",
                            "counts": {"PASS": 0, "REVIEW": 0, "BLOCK": 0, "NONE": 0},
                            "total_proposals": 0,
                            "analyzed_proposals": 0,
                        }
                    ), 200

            where = ["p.created_at IS NOT NULL"]
            params = []

            if owner_filter and resolved_owner_id is not None:
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text = %s::text")
                    params.append(str(resolved_owner_id))
                else:
                    where.append(f"p.{owner_col} = %s")
                    params.append(resolved_owner_id)
            else:
                if scope == "all":
                    pass
                elif scope == "team" and team_owner_ids is not None:
                    if not team_owner_ids:
                        return jsonify(
                            {
                                "filters": {
                                    "start_date": start_date_raw,
                                    "end_date": end_date_raw,
                                    "owner": owner_filter or None,
                                    "proposal_type": proposal_type or None,
                                    "client": client_filter or None,
                                    "scope": scope,
                                    "department": department_filter or None,
                                },
                                "overall_level": "NONE",
                                "counts": {"PASS": 0, "REVIEW": 0, "BLOCK": 0, "NONE": 0},
                                "total_proposals": 0,
                                "analyzed_proposals": 0,
                            }
                        ), 200
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = ANY(%s::text[])")
                        params.append([str(x) for x in team_owner_ids])
                    else:
                        where.append(f"p.{owner_col} = ANY(%s::int[])")
                        params.append(team_owner_ids)
                else:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id_val))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id_val)

            if start_date:
                where.append("p.created_at >= %s")
                params.append(start_date)
            if end_date:
                where.append("p.created_at <= %s")
                params.append(end_date)

            if proposal_type and proposal_type_col == "template_type":
                where.append("LOWER(p.template_type) = LOWER(%s)")
                params.append(proposal_type)
            elif proposal_type and proposal_type_col == "template_key":
                where.append("p.template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

            if client_filter and client_cols:
                or_parts = []
                for col in client_cols:
                    or_parts.append(f"p.{col} ILIKE %s")
                    params.append(f"%{client_filter}%")
                where.append("(" + " OR ".join(or_parts) + ")")

            where_sql = " AND ".join(where)

            cursor.execute(
                f"""
                SELECT
                    p.id AS proposal_id,
                    rr.status AS risk_status,
                    rr.risk_score AS risk_score,
                    rr.overridden AS overridden,
                    rr.created_at AS run_created_at
                FROM proposals p
                LEFT JOIN LATERAL (
                    SELECT status, risk_score, overridden, created_at
                    FROM risk_gate_runs
                    WHERE proposal_id = p.id
                    ORDER BY created_at DESC
                    LIMIT 1
                ) rr ON TRUE
                WHERE {where_sql}
                """,
                params,
            )

            rows = cursor.fetchall() or []

            counts = {"PASS": 0, "REVIEW": 0, "BLOCK": 0, "NONE": 0}
            for r in rows:
                status_val = r.get("risk_status")
                if not status_val:
                    counts["NONE"] += 1
                    continue
                key = str(status_val).strip().upper()
                if key not in counts:
                    counts["NONE"] += 1
                else:
                    counts[key] += 1

            total_proposals = len(rows)
            analyzed_proposals = total_proposals - counts["NONE"]

            overall_level = "NONE"
            if counts["BLOCK"] > 0:
                overall_level = "BLOCK"
            elif counts["REVIEW"] > 0:
                overall_level = "REVIEW"
            elif analyzed_proposals > 0:
                overall_level = "PASS"

            return jsonify(
                {
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter or None,
                        "proposal_type": proposal_type or None,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                    },
                    "overall_level": overall_level,
                    "counts": counts,
                    "total_proposals": total_proposals,
                    "analyzed_proposals": analyzed_proposals,
                }
            ), 200
    except Exception as e:
        print(f"❌ Risk Gate summary error: {e}")
        traceback.print_exc()
        return jsonify({"detail": "Internal error"}), 500


@bp.get("/proposals")
@token_required
def proposals(username=None, user_id=None, email=None):
    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_datetime_param(start_date_raw)
        end_date = _parse_datetime_param(end_date_raw)
        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        risk_status = (request.args.get("risk_status") or "").strip().upper()
        limit = request.args.get("limit", default=200, type=int)
        limit = min(max(limit, 1), 500)

        owner_filter = (request.args.get("owner") or request.args.get("owner_id") or "").strip()
        proposal_type = (request.args.get("proposal_type") or "").strip()
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "team").strip().lower()
        department_filter = (request.args.get("department") or "").strip()

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=RealDictCursor)

            cursor.execute(
                """
                SELECT column_name, data_type
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'proposals'
                """
            )
            cols = cursor.fetchall() or []
            existing_columns = {r["column_name"] for r in cols}
            col_types = {r["column_name"]: r["data_type"] for r in cols}

            owner_col = None
            if "owner_id" in existing_columns:
                owner_col = "owner_id"
            elif "user_id" in existing_columns:
                owner_col = "user_id"
            if not owner_col:
                return jsonify({"detail": "Proposals table is missing owner column"}), 500

            owner_col_type = (col_types.get(owner_col) or "").lower()
            owner_col_is_text = owner_col_type in {"character varying", "text", "varchar"}

            proposal_type_col = None
            if "template_type" in existing_columns:
                proposal_type_col = "template_type"
            elif "template_key" in existing_columns:
                proposal_type_col = "template_key"

            client_cols = [c for c in ("client", "client_name", "client_email") if c in existing_columns]
            client_expr = client_cols[0] if client_cols else "NULL::text"

            owner_id_val = user_id
            if not owner_id_val:
                lookup_email = email or username
                cursor.execute(
                    "SELECT id FROM users WHERE email = %s OR username = %s",
                    (lookup_email, username),
                )
                row = cursor.fetchone()
                owner_id_val = row["id"] if row else None

            if not owner_id_val:
                return jsonify({"proposals": [], "total": 0}), 200

            team_owner_ids = None
            if scope in {"team", "all"} and not owner_filter:
                cursor.execute(
                    "SELECT role, department FROM users WHERE id = %s",
                    (owner_id_val,),
                )
                me = cursor.fetchone() or {}
                my_role = (me.get("role") or "").strip().lower()
                my_department = (me.get("department") or "").strip() or None

                if scope == "all":
                    if my_role not in {"admin", "ceo"}:
                        return jsonify({"detail": "Not authorized for scope=all"}), 403
                    team_owner_ids = None
                else:
                    dept = department_filter or my_department
                    if dept:
                        cursor.execute("SELECT id FROM users WHERE department = %s", (dept,))
                        team_owner_ids = [int(r["id"]) for r in cursor.fetchall() or []]
                    else:
                        team_owner_ids = [int(owner_id_val)]

            resolved_owner_id = None
            if owner_filter:
                cursor.execute(
                    "SELECT id FROM users WHERE username = %s OR email = %s OR id::text = %s",
                    (owner_filter, owner_filter, owner_filter),
                )
                owner_row = cursor.fetchone()
                if owner_row:
                    resolved_owner_id = owner_row["id"]
                else:
                    return jsonify({"proposals": [], "total": 0}), 200

            where = ["p.created_at IS NOT NULL"]
            params = []

            if owner_filter and resolved_owner_id is not None:
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text = %s::text")
                    params.append(str(resolved_owner_id))
                else:
                    where.append(f"p.{owner_col} = %s")
                    params.append(resolved_owner_id)
            else:
                if scope == "all":
                    pass
                elif scope == "team" and team_owner_ids is not None:
                    if not team_owner_ids:
                        return jsonify({"proposals": [], "total": 0}), 200
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = ANY(%s::text[])")
                        params.append([str(x) for x in team_owner_ids])
                    else:
                        where.append(f"p.{owner_col} = ANY(%s::int[])")
                        params.append(team_owner_ids)
                else:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id_val))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id_val)

            if start_date:
                where.append("p.created_at >= %s")
                params.append(start_date)
            if end_date:
                where.append("p.created_at <= %s")
                params.append(end_date)

            if proposal_type and proposal_type_col == "template_type":
                where.append("LOWER(p.template_type) = LOWER(%s)")
                params.append(proposal_type)
            elif proposal_type and proposal_type_col == "template_key":
                where.append("p.template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

            if client_filter and client_cols:
                or_parts = []
                for col in client_cols:
                    or_parts.append(f"p.{col} ILIKE %s")
                    params.append(f"%{client_filter}%")
                where.append("(" + " OR ".join(or_parts) + ")")

            if risk_status and risk_status not in {"ALL"}:
                if risk_status == "NONE":
                    where.append("rr.status IS NULL")
                else:
                    where.append("UPPER(rr.status) = %s")
                    params.append(risk_status)

            where_sql = " AND ".join(where)

            cursor.execute(
                f"""
                SELECT
                    p.id AS proposal_id,
                    p.title AS proposal_title,
                    p.status AS proposal_status,
                    {client_expr} AS client,
                    rr.status AS risk_status,
                    rr.risk_score AS risk_score,
                    rr.overridden AS overridden,
                    rr.created_at AS run_created_at
                FROM proposals p
                LEFT JOIN LATERAL (
                    SELECT status, risk_score, overridden, created_at
                    FROM risk_gate_runs
                    WHERE proposal_id = p.id
                    ORDER BY created_at DESC
                    LIMIT 1
                ) rr ON TRUE
                WHERE {where_sql}
                ORDER BY
                    CASE
                        WHEN rr.status ILIKE 'BLOCK' THEN 1
                        WHEN rr.status ILIKE 'REVIEW' THEN 2
                        WHEN rr.status ILIKE 'PASS' THEN 3
                        ELSE 4
                    END,
                    COALESCE(rr.created_at, p.created_at) DESC
                LIMIT %s
                """,
                params + [limit],
            )

            rows = cursor.fetchall() or []
            return jsonify({"proposals": rows, "total": len(rows)}), 200
    except Exception as e:
        print(f"❌ Risk Gate proposals error: {e}")
        traceback.print_exc()
        return jsonify({"detail": "Internal error"}), 500
