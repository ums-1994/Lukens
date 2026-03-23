from flask import Blueprint, request, jsonify
import json
from datetime import datetime, timedelta
from api.utils.database import _pg_conn, release_pg_conn
from api.utils.decorators import token_required
from api.utils.readiness import (
    score_proposal as _score_proposal,
    missing_section_names as _missing_section_names,
    PASS_THRESHOLD as _PASS_THRESHOLD,
)

bp = Blueprint("pipeline", __name__)


def _parse_date(s: str | None):
    if not s:
        return None

    try:
        return datetime.fromisoformat(s)
    except ValueError:
        return datetime.strptime(s, "%Y-%m-%d")


def _safe_int(v):
    try:
        if v is None:
            return None
        return int(str(v))
    except Exception:
        return None


def _table_exists(cursor, table_name: str) -> bool:
    cursor.execute(
        """
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = %s
        LIMIT 1
        """,
        (table_name,),
    )
    return bool(cursor.fetchone())


def _get_table_columns(cursor, table_name: str):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (table_name,),
    )
    return {r[0] for r in cursor.fetchall() or []}


def _get_table_column_types(cursor, table_name: str):
    cursor.execute(
        """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (table_name,),
    )
    return {r[0]: r[1] for r in cursor.fetchall() or []}


def _resolve_owner_scope(cursor, username, user_id, email, owner_filter: str, scope: str, department_filter: str):
    owner_id_val = user_id
    if not owner_id_val:
        lookup_email = email or username
        cursor.execute(
            "SELECT id FROM users WHERE email = %s OR username = %s",
            (lookup_email, username),
        )
        row = cursor.fetchone()
        owner_id_val = row[0] if row else None

    team_owner_ids = None
    my_role = ""
    my_department = None
    if owner_id_val:
        cursor.execute(
            "SELECT role, department FROM users WHERE id = %s",
            (owner_id_val,),
        )
        me = cursor.fetchone()
        my_role = (me[0] if me else None) or ""
        my_department = (me[1] if me else None) or None

    role_lower = str(my_role).strip().lower()
    is_admin = role_lower in {"admin", "ceo"}

    if scope == "all":
        if not is_admin:
            return owner_id_val, team_owner_ids, None, is_admin, ("Not authorized for scope=all", 403)
        team_owner_ids = None
    elif scope == "team":
        if is_admin:
            if department_filter:
                cursor.execute(
                    "SELECT id FROM users WHERE department = %s",
                    (department_filter,),
                )
                team_owner_ids = [int(r[0]) for r in cursor.fetchall() or []]
            else:
                team_owner_ids = None
        else:
            dept = department_filter or my_department
            if dept:
                cursor.execute(
                    "SELECT id FROM users WHERE department = %s",
                    (dept,),
                )
                team_owner_ids = [int(r[0]) for r in cursor.fetchall() or []]
            elif owner_id_val:
                team_owner_ids = [int(owner_id_val)]

    resolved_owner_id = None
    if owner_filter:
        cursor.execute(
            "SELECT id FROM users WHERE username = %s OR email = %s OR id::text = %s",
            (owner_filter, owner_filter, owner_filter),
        )
        row = cursor.fetchone()
        resolved_owner_id = row[0] if row else None

    return owner_id_val, team_owner_ids, resolved_owner_id, is_admin, None


def _stage_for_status(status: str | None) -> str | None:
    s = (status or "").strip().lower()
    if not s or "draft" in s:
        return "Draft"
    if "archiv" in s or "cancel" in s or "declin" in s or "lost" in s:
        return "Archived"
    if "signed" in s or "won" in s:
        return "Signed"
    if "sent to client" in s or "released" in s:
        return "Released"
    if (
        "review" in s
        or "pending approval" in s
        or ("pending" in s and "ceo" in s)
        or "approved" in s
    ):
        return "In Review"
    return None


@bp.get("/analytics/owner-leaderboard")
@token_required
def owner_leaderboard(username=None, user_id=None, email=None):
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        owner_filter = (request.args.get("owner") or "").strip()
        proposal_type = (request.args.get("proposal_type") or "").strip()
        client_filter = (request.args.get("client") or "").strip()
        region_filter = (request.args.get("region") or "").strip()
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()

        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        # Determine current user id
        owner_id = user_id
        if not owner_id:
            lookup_email = email or username
            cursor.execute(
                "SELECT id FROM users WHERE email = %s OR username = %s",
                (lookup_email, username),
            )
            row = cursor.fetchone()
            owner_id = row[0] if row else None

        # Determine allowed owner ids for team scope
        # Semantics:
        # - scope=self: current user only
        # - scope=team:
        #   - admin/ceo: everyone by default; restrict to department only if explicitly requested
        #   - non-admin: department peers if department is known, else self
        # - scope=all: admin/ceo only (explicit)
        team_owner_ids = None
        my_role = ""
        my_department = None
        if owner_id:
            cursor.execute(
                "SELECT role, department FROM users WHERE id = %s",
                (owner_id,),
            )
            me = cursor.fetchone()
            my_role = (me[0] if me else None) or ""
            my_department = (me[1] if me else None) or None

        role_lower = str(my_role).strip().lower()
        is_admin = role_lower in {"admin", "ceo"}

        if scope == "all":
            if not is_admin:
                return jsonify({"detail": "Not authorized for scope=all"}), 403
            team_owner_ids = None
        elif scope == "team":
            if is_admin:
                # Admin team view defaults to everyone; only narrow if department filter is provided.
                if department_filter:
                    cursor.execute(
                        "SELECT id FROM users WHERE department = %s",
                        (department_filter,),
                    )
                    team_owner_ids = [int(r[0]) for r in cursor.fetchall() or []]
                else:
                    team_owner_ids = None
            else:
                dept = department_filter or my_department
                if dept:
                    cursor.execute(
                        "SELECT id FROM users WHERE department = %s",
                        (dept,),
                    )
                    team_owner_ids = [int(r[0]) for r in cursor.fetchall() or []]
                elif owner_id:
                    team_owner_ids = [int(owner_id)]

        # Resolve explicit owner filter to an id if provided
        resolved_owner_id = None
        if owner_filter:
            cursor.execute(
                "SELECT id FROM users WHERE username = %s OR email = %s OR id::text = %s",
                (owner_filter, owner_filter, owner_filter),
            )
            row = cursor.fetchone()
            resolved_owner_id = row[0] if row else None
            if not resolved_owner_id:
                return jsonify(
                    {
                        "metric": "owner_leaderboard",
                        "filters": {
                            "start_date": start_date_raw,
                            "end_date": end_date_raw,
                            "owner": owner_filter,
                            "proposal_type": proposal_type or None,
                            "client": client_filter or None,
                            "region": region_filter or None,
                            "scope": scope,
                            "department": department_filter or None,
                        },
                        "rows": [],
                    }
                ), 200

        where = ["p.created_at IS NOT NULL"]
        params = []

        if start_date:
            where.append("p.created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("p.created_at <= %s")
            params.append(end_date)

        # Optional shared filters (best-effort by column existence)
        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'proposals'
            """
        )
        existing_columns = {r[0] for r in cursor.fetchall() or []}

        owner_col = None
        if "owner_id" in existing_columns:
            owner_col = "owner_id"
        elif "user_id" in existing_columns:
            owner_col = "user_id"
        if not owner_col:
            return jsonify({"detail": "Proposals table is missing owner column"}), 500

        cursor.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'proposals'
            """
        )
        col_types = {r[0]: r[1] for r in cursor.fetchall() or []}
        owner_col_type = (col_types.get(owner_col) or "").lower()
        owner_col_is_text = owner_col_type in {"character varying", "text", "varchar"}

        proposal_type_col = None
        if "template_type" in existing_columns:
            proposal_type_col = "template_type"
        elif "template_key" in existing_columns:
            proposal_type_col = "template_key"

        client_col = None
        if "client" in existing_columns:
            client_col = "client"
        elif "client_name" in existing_columns:
            client_col = "client_name"
        elif "client_email" in existing_columns:
            client_col = "client_email"

        if proposal_type and proposal_type_col:
            where.append(f"p.{proposal_type_col} = %s")
            params.append(proposal_type)

        if client_filter and client_col:
            where.append(f"COALESCE(p.{client_col}::text, '') ILIKE %s")
            params.append(f"%{client_filter}%")

        if region_filter and "region" in existing_columns:
            where.append("COALESCE(p.region::text, '') ILIKE %s")
            params.append(f"%{region_filter}%")

        # Scope filtering
        if resolved_owner_id:
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
                            "metric": "owner_leaderboard",
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter or None,
                                "proposal_type": proposal_type or None,
                                "client": client_filter or None,
                                "region": region_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                            },
                            "rows": [],
                        }
                    ), 200
                # Avoid psycopg2 adaptation issues passing Python lists to int[] casts.
                placeholders = ",".join(["%s"] * len(team_owner_ids))
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text IN ({placeholders})")
                    params.extend([str(x) for x in team_owner_ids])
                else:
                    where.append(f"p.{owner_col} IN ({placeholders})")
                    params.extend(team_owner_ids)
            elif scope == "team" and team_owner_ids is None:
                pass
            else:
                if owner_id:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id)

        # Sent vs signed classification using status text
        # sent: Released or In Review
        # signed: Signed
        sql = f"""
            SELECT
                p.{owner_col}::text AS owner_key,
                COALESCE(u.username, u.email, p.{owner_col}::text) AS owner,
                SUM(CASE WHEN (LOWER(COALESCE(p.status,'')) LIKE '%%sent to client%%' OR LOWER(COALESCE(p.status,'')) LIKE '%%released%%' OR LOWER(COALESCE(p.status,'')) LIKE '%%review%%' OR LOWER(COALESCE(p.status,'')) LIKE '%%approved%%' OR LOWER(COALESCE(p.status,'')) LIKE '%%pending approval%%') THEN 1 ELSE 0 END) AS sent_count,
                SUM(CASE WHEN (LOWER(COALESCE(p.status,'')) LIKE '%%signed%%' OR LOWER(COALESCE(p.status,'')) LIKE '%%won%%') THEN 1 ELSE 0 END) AS signed_count,
                COUNT(*) AS total_count
            FROM proposals p
            LEFT JOIN users u ON (
                u.id::text = p.{owner_col}::text
                OR LOWER(COALESCE(u.email,'')) = LOWER(p.{owner_col}::text)
                OR LOWER(COALESCE(u.username,'')) = LOWER(p.{owner_col}::text)
            )
            WHERE {' AND '.join(where)}
            GROUP BY p.{owner_col}::text, u.username, u.email
            ORDER BY signed_count DESC, sent_count DESC, total_count DESC
        """

        cursor.execute(sql, tuple(params))
        rows = cursor.fetchall() or []

        result_rows = []
        expected_cols = 5
        actual_cols = len(cursor.description or [])
        if actual_cols and actual_cols < expected_cols:
            return (
                jsonify(
                    {
                        "detail": "Owner leaderboard query returned fewer columns than expected",
                        "expected_cols": expected_cols,
                        "actual_cols": actual_cols,
                        "first_row": rows[0] if rows else None,
                    }
                ),
                500,
            )

        for r in rows:
            if r is None or len(r) < expected_cols:
                continue
            owner_key, owner_label, sent_raw, signed_raw, total_raw = r[:expected_cols]
            sent = int(sent_raw or 0)
            signed = int(signed_raw or 0)
            conversion = (signed / sent) if sent > 0 else 0.0

            parsed_owner_id = None
            try:
                if owner_key is not None:
                    parsed_owner_id = int(str(owner_key))
            except Exception:
                parsed_owner_id = None

            result_rows.append(
                {
                    "owner_id": parsed_owner_id,
                    "owner": owner_label,
                    "sent": sent,
                    "signed": signed,
                    "conversion_rate": conversion,
                    "total": int(total_raw or 0),
                }
            )

        return jsonify(
            {
                "metric": "owner_leaderboard",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter or None,
                    "proposal_type": proposal_type or None,
                    "client": client_filter or None,
                    "region": region_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                },
                "rows": result_rows,
            }
        ), 200

    except Exception as exc:
        import traceback

        traceback.print_exc()
        return (
            jsonify(
                {
                    "detail": str(exc),
                    "error_type": exc.__class__.__name__,
                }
            ),
            500,
        )
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        release_pg_conn(conn)


@bp.get("/analytics/stage-aging")
@token_required
def stage_aging(username=None, user_id=None, email=None):
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        owner_filter = (request.args.get("owner") or request.args.get("owner_id") or "").strip()
        proposal_type = (request.args.get("proposal_type") or "").strip()
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()

        stale_draft_days = request.args.get("stale_draft_days", default=14, type=int)
        stale_review_days = request.args.get("stale_review_days", default=7, type=int)
        stale_released_days = request.args.get("stale_released_days", default=14, type=int)
        stale_draft_days = min(max(int(stale_draft_days or 14), 1), 365)
        stale_review_days = min(max(int(stale_review_days or 7), 1), 365)
        stale_released_days = min(max(int(stale_released_days or 14), 1), 365)

        limit = request.args.get("limit", default=100, type=int)
        limit = min(max(int(limit or 100), 1), 500)

        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        owner_id_val, team_owner_ids, resolved_owner_id, _, err = _resolve_owner_scope(
            cursor,
            username,
            user_id,
            email,
            owner_filter,
            scope,
            department_filter,
        )
        if err:
            detail, code = err
            return jsonify({"detail": detail}), code

        if not owner_id_val and scope != "all":
            return jsonify(
                {
                    "metric": "stage_aging",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter or None,
                        "proposal_type": proposal_type or None,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                        "limit": limit,
                        "thresholds_days": {
                            "Draft": stale_draft_days,
                            "In Review": stale_review_days,
                            "Released": stale_released_days,
                        },
                    },
                    "by_stage": [],
                    "stale": [],
                    "data_source": "missing_user",
                }
            ), 200

        proposals_cols = _get_table_columns(cursor, "proposals")
        proposals_types = _get_table_column_types(cursor, "proposals")

        owner_col = "owner_id" if "owner_id" in proposals_cols else ("user_id" if "user_id" in proposals_cols else None)
        if not owner_col:
            return jsonify({"detail": "Proposals table is missing owner column"}), 500

        owner_col_type = (proposals_types.get(owner_col) or "").lower()
        owner_col_is_text = owner_col_type in {"character varying", "text", "varchar"}

        proposal_type_col = None
        if "template_type" in proposals_cols:
            proposal_type_col = "template_type"
        elif "template_key" in proposals_cols:
            proposal_type_col = "template_key"

        client_cols = [c for c in ("client", "client_name", "client_email") if c in proposals_cols]
        client_expr = client_cols[0] if client_cols else "NULL::text"

        updated_expr = "p.created_at"
        if "updated_at" in proposals_cols:
            updated_expr = "COALESCE(p.updated_at, p.created_at)"

        where = ["p.created_at IS NOT NULL"]
        params = []

        if start_date:
            where.append("p.created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("p.created_at <= %s")
            params.append(end_date)

        if proposal_type and proposal_type_col:
            if proposal_type_col == "template_type":
                where.append("LOWER(p.template_type) = LOWER(%s)")
                params.append(proposal_type)
            else:
                where.append("p.template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

        if client_filter and client_cols:
            or_parts = []
            for col in client_cols:
                or_parts.append(f"p.{col} ILIKE %s")
                params.append(f"%{client_filter}%")
            where.append("(" + " OR ".join(or_parts) + ")")

        if resolved_owner_id:
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
                            "metric": "stage_aging",
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter or None,
                                "proposal_type": proposal_type or None,
                                "client": client_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                                "limit": limit,
                                "thresholds_days": {
                                    "Draft": stale_draft_days,
                                    "In Review": stale_review_days,
                                    "Released": stale_released_days,
                                },
                            },
                            "by_stage": [],
                            "stale": [],
                            "data_source": "empty_team",
                        }
                    ), 200
                placeholders = ",".join(["%s"] * len(team_owner_ids))
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text IN ({placeholders})")
                    params.extend([str(x) for x in team_owner_ids])
                else:
                    where.append(f"p.{owner_col} IN ({placeholders})")
                    params.extend(team_owner_ids)
            elif scope == "team" and team_owner_ids is None:
                pass
            else:
                if owner_id_val:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id_val))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id_val)

        where_sql = " AND ".join(where)

        activity_exists = _table_exists(cursor, "activity_log")
        activity_cols = set()
        if activity_exists:
            activity_cols = _get_table_columns(cursor, "activity_log")
            if "proposal_id" not in activity_cols or "created_at" not in activity_cols:
                activity_exists = False

        stage_entered_expr = updated_expr
        activity_join = ""
        if activity_exists and "metadata" in activity_cols:
            stage_entered_expr = "COALESCE(al.created_at, " + updated_expr + ")"
            activity_join = """
            LEFT JOIN LATERAL (
                SELECT created_at
                FROM activity_log
                WHERE proposal_id = p.id
                  AND action_type = 'status_changed'
                  AND LOWER(COALESCE(metadata->>'to','')) = LOWER(COALESCE(p.status,''))
                ORDER BY created_at DESC
                LIMIT 1
            ) al ON TRUE
            """

        join_cond = f"u.id = p.{owner_col}"
        if owner_col_is_text:
            join_cond = f"u.id::text = p.{owner_col}::text"

        cursor.execute(
            f"""
            SELECT
                p.id,
                p.title,
                p.status,
                p.created_at,
                {updated_expr} AS updated_at,
                {stage_entered_expr} AS stage_entered_at,
                p.{client_expr} AS client,
                u.id AS owner_id,
                COALESCE(u.full_name, u.username, u.email) AS owner
            FROM proposals p
            LEFT JOIN users u ON {join_cond}
            {activity_join}
            WHERE {where_sql}
            ORDER BY {updated_expr} DESC NULLS LAST, p.id DESC
            """,
            tuple(params),
        )

        thresholds = {
            "Draft": stale_draft_days,
            "In Review": stale_review_days,
            "Released": stale_released_days,
        }

        now_utc = datetime.utcnow()
        stale_rows = []
        stage_totals = {}

        for pid, title, status, created_at, updated_at, stage_entered_at, client, owner_id_row, owner in cursor.fetchall() or []:
            stage = _stage_for_status(status)
            if not stage:
                continue
            if stage in {"Archived", "Signed"}:
                continue

            ref_dt = stage_entered_at or updated_at or created_at
            age_days = None
            if ref_dt:
                try:
                    age_days = float((now_utc - ref_dt).total_seconds()) / 86400.0
                except Exception:
                    age_days = None

            stage_totals[stage] = int(stage_totals.get(stage) or 0) + 1

            threshold_days = thresholds.get(stage)
            if threshold_days is None:
                continue
            if age_days is None:
                continue
            if age_days < float(threshold_days):
                continue

            stale_rows.append(
                {
                    "proposal_id": _safe_int(pid) if _safe_int(pid) is not None else str(pid),
                    "title": title,
                    "status": status,
                    "stage": stage,
                    "client": client,
                    "owner": owner,
                    "owner_id": _safe_int(owner_id_row),
                    "created_at": created_at.isoformat() if created_at else None,
                    "updated_at": updated_at.isoformat() if updated_at else None,
                    "stage_entered_at": ref_dt.isoformat() if ref_dt else None,
                    "age_days": age_days,
                    "threshold_days": int(threshold_days),
                }
            )

        stale_rows.sort(key=lambda r: (-(float(r.get("age_days") or 0.0)), str(r.get("title") or "")))

        stale_counts = {}
        for r in stale_rows:
            st = r.get("stage")
            if not st:
                continue
            stale_counts[st] = int(stale_counts.get(st) or 0) + 1

        by_stage = []
        for stage, total in sorted(stage_totals.items(), key=lambda kv: kv[0]):
            by_stage.append(
                {
                    "stage": stage,
                    "total": int(total),
                    "stale": int(stale_counts.get(stage) or 0),
                    "threshold_days": int(thresholds.get(stage) or 0),
                }
            )

        return jsonify(
            {
                "metric": "stage_aging",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter or None,
                    "proposal_type": proposal_type or None,
                    "client": client_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                    "limit": limit,
                    "thresholds_days": thresholds,
                },
                "by_stage": by_stage,
                "stale": stale_rows[:limit],
                "data_source": "activity_log" if activity_exists else "updated_at",
            }
        ), 200

    except Exception as exc:
        import traceback

        traceback.print_exc()
        return jsonify({"detail": str(exc), "error_type": exc.__class__.__name__}), 500
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        release_pg_conn(conn)


@bp.get("/analytics/risk-gate/details")
@token_required
def risk_gate_details(username=None, user_id=None, email=None):
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        owner_filter = (request.args.get("owner") or request.args.get("owner_id") or "").strip()
        proposal_type = (request.args.get("proposal_type") or "").strip()
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()
        limit = request.args.get("limit", default=50, type=int)
        limit = min(max(int(limit or 50), 1), 200)
        blocked_only = request.args.get("blocked_only", default="true")
        blocked_only = str(blocked_only).strip().lower() not in {"0", "false", "no"}

        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        owner_id_val, team_owner_ids, resolved_owner_id, _, err = _resolve_owner_scope(
            cursor,
            username,
            user_id,
            email,
            owner_filter,
            scope,
            department_filter,
        )
        if err:
            detail, code = err
            return jsonify({"detail": detail}), code

        if not owner_id_val and scope != "all":
            return jsonify(
                {
                    "metric": "risk_gate_details",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter or None,
                        "proposal_type": proposal_type or None,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                        "limit": limit,
                        "blocked_only": blocked_only,
                    },
                    "counts": {"PASS": 0, "REVIEW": 0, "BLOCK": 0, "NONE": 0},
                    "total_proposals": 0,
                    "analyzed_proposals": 0,
                    "issues_histogram": [],
                    "overrides": {"count": 0},
                    "blocked_proposals": [],
                    "data_source": "missing_user",
                }
            ), 200

        proposals_cols = _get_table_columns(cursor, "proposals")
        proposals_types = _get_table_column_types(cursor, "proposals")

        owner_col = "owner_id" if "owner_id" in proposals_cols else ("user_id" if "user_id" in proposals_cols else None)
        if not owner_col:
            return jsonify({"detail": "Proposals table is missing owner column"}), 500

        owner_col_type = (proposals_types.get(owner_col) or "").lower()
        owner_col_is_text = owner_col_type in {"character varying", "text", "varchar"}

        proposal_type_col = None
        if "template_type" in proposals_cols:
            proposal_type_col = "template_type"
        elif "template_key" in proposals_cols:
            proposal_type_col = "template_key"

        client_cols = [c for c in ("client", "client_name", "client_email") if c in proposals_cols]
        client_expr = client_cols[0] if client_cols else "NULL::text"

        updated_expr = "p.created_at"
        if "updated_at" in proposals_cols:
            updated_expr = "COALESCE(p.updated_at, p.created_at)"

        where = ["p.created_at IS NOT NULL"]
        params = []

        if start_date:
            where.append("p.created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("p.created_at <= %s")
            params.append(end_date)

        if proposal_type and proposal_type_col:
            if proposal_type_col == "template_type":
                where.append("LOWER(p.template_type) = LOWER(%s)")
                params.append(proposal_type)
            else:
                where.append("p.template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

        if client_filter and client_cols:
            or_parts = []
            for col in client_cols:
                or_parts.append(f"p.{col} ILIKE %s")
                params.append(f"%{client_filter}%")
            where.append("(" + " OR ".join(or_parts) + ")")

        if resolved_owner_id:
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
                            "metric": "risk_gate_details",
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter or None,
                                "proposal_type": proposal_type or None,
                                "client": client_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                                "limit": limit,
                                "blocked_only": blocked_only,
                            },
                            "counts": {"PASS": 0, "REVIEW": 0, "BLOCK": 0, "NONE": 0},
                            "total_proposals": 0,
                            "analyzed_proposals": 0,
                            "issues_histogram": [],
                            "overrides": {"count": 0},
                            "blocked_proposals": [],
                            "data_source": "empty_team",
                        }
                    ), 200
                placeholders = ",".join(["%s"] * len(team_owner_ids))
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text IN ({placeholders})")
                    params.extend([str(x) for x in team_owner_ids])
                else:
                    where.append(f"p.{owner_col} IN ({placeholders})")
                    params.extend(team_owner_ids)
            elif scope == "team" and team_owner_ids is None:
                pass
            else:
                if owner_id_val:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id_val))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id_val)

        where_sql = " AND ".join(where)

        if not _table_exists(cursor, "risk_gate_runs"):
            return jsonify(
                {
                    "metric": "risk_gate_details",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter or None,
                        "proposal_type": proposal_type or None,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                        "limit": limit,
                        "blocked_only": blocked_only,
                    },
                    "counts": {"PASS": 0, "REVIEW": 0, "BLOCK": 0, "NONE": 0},
                    "total_proposals": 0,
                    "analyzed_proposals": 0,
                    "issues_histogram": [],
                    "overrides": {"count": 0},
                    "blocked_proposals": [],
                    "data_source": "missing_risk_gate_runs",
                }
            ), 200

        join_cond = f"u.id = p.{owner_col}"
        if owner_col_is_text:
            join_cond = f"u.id::text = p.{owner_col}::text"

        cursor.execute(
            f"""
            SELECT
                p.id AS proposal_id,
                p.title AS title,
                p.status AS proposal_status,
                p.created_at AS created_at,
                {updated_expr} AS updated_at,
                p.{client_expr} AS client,
                u.id AS owner_id,
                COALESCE(u.full_name, u.username, u.email) AS owner,
                rr.status AS risk_status,
                rr.risk_score AS risk_score,
                rr.overridden AS overridden,
                rr.issues AS issues,
                rr.created_at AS run_created_at
            FROM proposals p
            LEFT JOIN users u ON {join_cond}
            LEFT JOIN LATERAL (
                SELECT status, risk_score, overridden, issues, created_at
                FROM risk_gate_runs
                WHERE proposal_id = p.id
                ORDER BY created_at DESC
                LIMIT 1
            ) rr ON TRUE
            WHERE {where_sql}
            ORDER BY COALESCE(rr.created_at, {updated_expr}) DESC NULLS LAST
            """,
            tuple(params),
        )

        counts = {"PASS": 0, "REVIEW": 0, "BLOCK": 0, "NONE": 0}
        issues_counts = {}
        blocked = []
        overrides_count = 0

        blocked_statuses = {"BLOCK"}
        for r in cursor.fetchall() or []:
            (
                pid,
                title,
                proposal_status,
                created_at,
                updated_at,
                client,
                owner_id_row,
                owner,
                risk_status,
                risk_score,
                overridden,
                issues_raw,
                run_created_at,
            ) = r

            key = (str(risk_status).strip().upper() if risk_status else "NONE")
            if key not in counts:
                key = "NONE"
            counts[key] = int(counts.get(key) or 0) + 1

            if overridden:
                overrides_count += 1

            issues_obj = None
            if issues_raw is not None:
                if isinstance(issues_raw, (list, dict)):
                    issues_obj = issues_raw
                elif isinstance(issues_raw, str):
                    try:
                        issues_obj = json.loads(issues_raw)
                    except Exception:
                        issues_obj = None

            issues_list = []
            if isinstance(issues_obj, list):
                issues_list = issues_obj
            elif isinstance(issues_obj, dict) and isinstance(issues_obj.get("issues"), list):
                issues_list = issues_obj.get("issues")

            for issue in issues_list or []:
                if not isinstance(issue, dict):
                    continue
                label = (
                    issue.get("category")
                    or issue.get("type")
                    or issue.get("code")
                    or issue.get("title")
                    or issue.get("name")
                    or "Unknown"
                )
                label = str(label).strip() or "Unknown"
                issues_counts[label] = int(issues_counts.get(label) or 0) + 1

            if (key in blocked_statuses) or (not blocked_only and key in {"BLOCK", "REVIEW"}):
                blocked.append(
                    {
                        "proposal_id": _safe_int(pid) if _safe_int(pid) is not None else str(pid),
                        "title": title,
                        "status": proposal_status,
                        "client": client,
                        "owner": owner,
                        "owner_id": _safe_int(owner_id_row),
                        "created_at": created_at.isoformat() if created_at else None,
                        "updated_at": updated_at.isoformat() if updated_at else None,
                        "risk_status": key,
                        "risk_score": float(risk_score) if risk_score is not None else None,
                        "overridden": bool(overridden),
                        "run_created_at": run_created_at.isoformat() if run_created_at else None,
                    }
                )

        total_proposals = int(sum(counts.values()))
        analyzed_proposals = int(total_proposals - int(counts.get("NONE") or 0))

        issues_histogram = [
            {"issue": k, "count": int(v)}
            for k, v in sorted(issues_counts.items(), key=lambda kv: (-int(kv[1] or 0), kv[0]))
        ]

        blocked.sort(
            key=lambda r: (
                0 if r.get("risk_status") == "BLOCK" else 1,
                -(float(r.get("risk_score") or 0.0)),
                str(r.get("title") or ""),
            )
        )

        return jsonify(
            {
                "metric": "risk_gate_details",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter or None,
                    "proposal_type": proposal_type or None,
                    "client": client_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                    "limit": limit,
                    "blocked_only": blocked_only,
                },
                "counts": counts,
                "total_proposals": total_proposals,
                "analyzed_proposals": analyzed_proposals,
                "issues_histogram": issues_histogram[:25],
                "overrides": {"count": int(overrides_count)},
                "blocked_proposals": blocked[:limit],
                "data_source": "risk_gate_runs",
            }
        ), 200

    except Exception as exc:
        import traceback

        traceback.print_exc()
        return jsonify({"detail": str(exc), "error_type": exc.__class__.__name__}), 500
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        release_pg_conn(conn)


@bp.get("/analytics/readiness/governance")
@token_required
def readiness_governance(username=None, user_id=None, email=None):
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        owner_filter = (request.args.get("owner") or request.args.get("owner_id") or "").strip()
        proposal_type = (request.args.get("proposal_type") or "").strip()
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()
        limit = request.args.get("limit", default=50, type=int)
        limit = min(max(int(limit or 50), 1), 200)

        threshold = request.args.get("pass_threshold", default=None, type=int)
        try:
            pass_threshold = int(threshold) if threshold is not None else int(_PASS_THRESHOLD)
        except Exception:
            pass_threshold = int(_PASS_THRESHOLD)

        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        owner_id_val, team_owner_ids, resolved_owner_id, _, err = _resolve_owner_scope(
            cursor,
            username,
            user_id,
            email,
            owner_filter,
            scope,
            department_filter,
        )
        if err:
            detail, code = err
            return jsonify({"detail": detail}), code

        if not owner_id_val and scope != "all":
            return jsonify(
                {
                    "metric": "readiness_governance",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter or None,
                        "proposal_type": proposal_type or None,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                        "pass_threshold": int(pass_threshold),
                        "limit": limit,
                    },
                    "totals": {
                        "total": 0,
                        "blocked": 0,
                        "pass_rate": 0,
                    },
                    "missing_sections": [],
                    "blocked_proposals": [],
                }
            ), 200

        proposals_cols = _get_table_columns(cursor, "proposals")
        proposals_types = _get_table_column_types(cursor, "proposals")

        owner_col = "owner_id" if "owner_id" in proposals_cols else ("user_id" if "user_id" in proposals_cols else None)
        if not owner_col:
            return jsonify({"detail": "Proposals table is missing owner column"}), 500

        owner_col_type = (proposals_types.get(owner_col) or "").lower()
        owner_col_is_text = owner_col_type in {"character varying", "text", "varchar"}

        proposal_type_col = None
        if "template_type" in proposals_cols:
            proposal_type_col = "template_type"
        elif "template_key" in proposals_cols:
            proposal_type_col = "template_key"

        updated_expr = "p.created_at"
        if "updated_at" in proposals_cols:
            updated_expr = "COALESCE(p.updated_at, p.created_at)"

        client_expr = "NULL::text"
        if "client" in proposals_cols:
            client_expr = "client"
        elif "client_name" in proposals_cols:
            client_expr = "client_name"
        elif "client_email" in proposals_cols:
            client_expr = "client_email"

        sections_expr = "NULL::text"
        if "sections" in proposals_cols:
            sections_expr = "sections"
        content_expr = "NULL::text"
        if "content" in proposals_cols:
            content_expr = "content"
        elif "content_data" in proposals_cols:
            content_expr = "content_data"

        where = ["p.created_at IS NOT NULL"]
        params = []

        if start_date:
            where.append("p.created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("p.created_at <= %s")
            params.append(end_date)

        if proposal_type and proposal_type_col:
            if proposal_type_col == "template_type":
                where.append("LOWER(p.template_type) = LOWER(%s)")
                params.append(proposal_type)
            else:
                where.append("p.template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

        if client_filter and client_expr != "NULL::text":
            where.append(f"COALESCE(p.{client_expr}::text, '') ILIKE %s")
            params.append(f"%{client_filter}%")

        if resolved_owner_id:
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
                            "metric": "readiness_governance",
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter or None,
                                "proposal_type": proposal_type or None,
                                "client": client_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                                "pass_threshold": int(pass_threshold),
                                "limit": limit,
                            },
                            "totals": {
                                "total": 0,
                                "blocked": 0,
                                "pass_rate": 0,
                            },
                            "missing_sections": [],
                            "blocked_proposals": [],
                        }
                    ), 200
                placeholders = ",".join(["%s"] * len(team_owner_ids))
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text IN ({placeholders})")
                    params.extend([str(x) for x in team_owner_ids])
                else:
                    where.append(f"p.{owner_col} IN ({placeholders})")
                    params.extend(team_owner_ids)
            elif scope == "team" and team_owner_ids is None:
                pass
            else:
                if owner_id_val:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id_val))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id_val)

        where_sql = " AND ".join(where)

        join_cond = f"u.id = p.{owner_col}"
        if owner_col_is_text:
            join_cond = f"u.id::text = p.{owner_col}::text"

        cursor.execute(
            f"""
            SELECT
                p.id,
                p.title,
                p.status,
                p.created_at,
                {updated_expr} AS updated_at,
                p.{client_expr} AS client,
                u.id AS owner_id,
                COALESCE(u.full_name, u.username, u.email) AS owner,
                {sections_expr} AS sections,
                {content_expr} AS content_data
            FROM proposals p
            LEFT JOIN users u ON {join_cond}
            WHERE {where_sql}
            ORDER BY {updated_expr} DESC NULLS LAST, p.id DESC
            """,
            tuple(params),
        )

        missing_counts = {}
        blocked = []
        total = 0
        passed = 0

        for pid, title, status, created_at, updated_at, client, owner_id_row, owner, sections_raw, content_raw in cursor.fetchall() or []:
            total += 1
            scored = _score_proposal(content_raw)
            if (not scored) or int(scored.get("score") or 0) == 0:
                scored = _score_proposal(sections_raw)

            score_val = int(scored.get("score") or 0)
            ok = score_val >= pass_threshold
            if ok:
                passed += 1

            issues = _missing_section_names(scored) or []
            for name in issues:
                k = str(name or "").strip()
                if not k:
                    continue
                missing_counts[k] = int(missing_counts.get(k) or 0) + 1

            status_lower = str(status or "").strip().lower()
            is_active = True
            if ("archiv" in status_lower) or ("declin" in status_lower) or ("lost" in status_lower) or ("cancel" in status_lower):
                is_active = False

            if (not ok) and is_active:
                blocked.append(
                    {
                        "proposal_id": _safe_int(pid) if _safe_int(pid) is not None else str(pid),
                        "title": title,
                        "status": status,
                        "client": client,
                        "owner": owner,
                        "owner_id": _safe_int(owner_id_row),
                        "created_at": created_at.isoformat() if created_at else None,
                        "updated_at": updated_at.isoformat() if updated_at else None,
                        "readiness_score": score_val,
                        "missing_sections": issues,
                    }
                )

        pass_rate = 0
        if total > 0:
            pass_rate = int(round((passed / total) * 100))

        missing_sections = [
            {"section": k, "count": int(v)} for k, v in sorted(missing_counts.items(), key=lambda kv: (-int(kv[1] or 0), kv[0]))
        ]

        blocked.sort(key=lambda r: (int(r.get("readiness_score") or 0), str(r.get("title") or "")))

        return jsonify(
            {
                "metric": "readiness_governance",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter or None,
                    "proposal_type": proposal_type or None,
                    "client": client_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                    "pass_threshold": int(pass_threshold),
                    "limit": limit,
                },
                "totals": {
                    "total": int(total),
                    "blocked": int(len(blocked)),
                    "pass_rate": int(pass_rate),
                },
                "missing_sections": missing_sections[:25],
                "blocked_proposals": blocked[:limit],
            }
        ), 200

    except Exception as exc:
        import traceback

        traceback.print_exc()
        return jsonify({"detail": str(exc), "error_type": exc.__class__.__name__}), 500
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        release_pg_conn(conn)



@bp.get("/analytics/proposal-pipeline")
@token_required
def proposal_pipeline(username=None, user_id=None, email=None):
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        owner_filter = request.args.get("owner")
        proposal_type = request.args.get("proposal_type")
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()
        stage_filter = (request.args.get("stage") or "").strip()

        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        if owner_filter is None:
            owner_filter = request.args.get("owner_id")

        cursor.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'proposals'
            """
        )
        cols = cursor.fetchall()
        existing_columns = {r[0] for r in cols}
        col_types = {r[0]: r[1] for r in cols}

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

        updated_expr = "p.created_at"
        if "updated_at" in existing_columns:
            updated_expr = "COALESCE(p.updated_at, p.created_at)"

        if "client" in existing_columns:
            client_expr = "client"
        elif "client_name" in existing_columns:
            client_expr = "client_name"
        elif "client_email" in existing_columns:
            client_expr = "client_email"
        else:
            client_expr = "NULL::text"

        owner_id = user_id
        if not owner_id:
            lookup_email = email or username
            cursor.execute(
                "SELECT id FROM users WHERE email = %s OR username = %s",
                (lookup_email, username),
            )
            row = cursor.fetchone()
            owner_id = row[0] if row else None

        if not owner_id and scope != "all":
            return jsonify(
                {
                    "metric": "proposal_pipeline",
                    "definition": "proposals grouped by stage",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter,
                        "proposal_type": proposal_type,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                        "stage": stage_filter or None,
                    },
                    "stages": [],
                }
            ), 200

        team_owner_ids = None
        if scope in {"team", "all"} and not owner_filter and owner_id:
            cursor.execute(
                "SELECT role, department FROM users WHERE id = %s",
                (owner_id,),
            )
            me = cursor.fetchone()
            my_role = (me[0] if me else None) or ""
            my_department = (me[1] if me else None) or None

            role_lower = str(my_role).strip().lower()
            is_admin = role_lower in {"admin", "ceo"}

            if scope == "all":
                if not is_admin:
                    return jsonify({"detail": "Not authorized for scope=all"}), 403
                team_owner_ids = None
            else:
                if is_admin:
                    # Admin team view defaults to everyone; only narrow if department filter is provided.
                    if department_filter:
                        cursor.execute(
                            "SELECT id FROM users WHERE department = %s",
                            (department_filter,),
                        )
                        team_owner_ids = [int(r[0]) for r in cursor.fetchall() or []]
                    else:
                        team_owner_ids = None
                else:
                    dept = department_filter or my_department
                    if dept:
                        cursor.execute(
                            "SELECT id FROM users WHERE department = %s",
                            (dept,),
                        )
                        team_owner_ids = [int(r[0]) for r in cursor.fetchall() or []]
                    else:
                        team_owner_ids = [int(owner_id)]

        if owner_filter:
            cursor.execute(
                "SELECT id FROM users WHERE username = %s OR email = %s OR id::text = %s",
                (owner_filter, owner_filter, owner_filter),
            )
            owner_row = cursor.fetchone()
            owner_id = owner_row[0] if owner_row else None
            if not owner_id:
                return jsonify(
                    {
                        "metric": "proposal_pipeline",
                        "definition": "proposals grouped by stage",
                        "filters": {
                            "start_date": start_date_raw,
                            "end_date": end_date_raw,
                            "owner": owner_filter,
                            "proposal_type": proposal_type,
                            "client": client_filter or None,
                            "scope": scope,
                            "department": department_filter or None,
                            "stage": stage_filter or None,
                        },
                        "stages": [],
                    }
                ), 200

        where = ["p.created_at IS NOT NULL"]
        params = []

        if owner_filter:
            if owner_col_is_text:
                where.append(f"p.{owner_col}::text = %s::text")
                params.append(str(owner_id))
            else:
                where.append(f"p.{owner_col} = %s")
                params.append(owner_id)
        else:
            if scope == "all":
                pass
            elif scope == "team" and team_owner_ids is not None:
                if not team_owner_ids:
                    return jsonify(
                        {
                            "metric": "proposal_pipeline",
                            "definition": "proposals grouped by stage",
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter,
                                "proposal_type": proposal_type,
                                "client": client_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                                "stage": stage_filter or None,
                            },
                            "stages": [],
                        }
                    ), 200
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text = ANY(%s::text[])")
                    params.append([str(x) for x in team_owner_ids])
                else:
                    where.append(f"p.{owner_col} = ANY(%s::int[])")
                    params.append(team_owner_ids)
            elif scope == "team" and team_owner_ids is None:
                pass
            else:
                if owner_id:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id)

        if start_date:
            where.append("p.created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("p.created_at <= %s")
            params.append(end_date)

        if proposal_type:
            if proposal_type_col == "template_type":
                where.append("LOWER(p.template_type) = LOWER(%s)")
                params.append(proposal_type)
            elif proposal_type_col == "template_key":
                where.append("p.template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

        if client_filter and client_expr != "NULL::text":
            where.append(f"p.{client_expr} ILIKE %s")
            params.append(f"%{client_filter}%")

        where_sql = " AND ".join(where)

        join_cond = f"u.id = p.{owner_col}"
        if owner_col_is_text:
            join_cond = f"u.id::text = p.{owner_col}::text"

        cursor.execute(
            f"""
            SELECT
                p.id,
                p.title,
                p.status,
                p.created_at,
                {updated_expr} AS updated_at,
                p.{client_expr} AS client,
                u.id AS owner_id,
                COALESCE(u.full_name, u.username, u.email) AS owner
            FROM proposals p
            LEFT JOIN users u ON {join_cond}
            WHERE {where_sql}
            ORDER BY updated_at DESC NULLS LAST, p.id DESC
            """,
            params,
        )

        stages_order = ["Draft", "In Review", "Released", "Signed", "Archived"]
        stage_buckets = {s: [] for s in stages_order}

        for pid, title, status, created_at, updated_at, client, owner_id_row, owner in cursor.fetchall() or []:
            stage = _stage_for_status(status)
            if not stage:
                continue
            if stage_filter and stage.lower() != stage_filter.strip().lower():
                continue
            if stage not in stage_buckets:
                continue

            stage_buckets[stage].append(
                {
                    "proposal_id": int(pid),
                    "title": title,
                    "status": status,
                    "stage": stage,
                    "client": client,
                    "owner": owner,
                    "owner_id": int(owner_id_row) if owner_id_row is not None else None,
                    "created_at": created_at.isoformat() if created_at else None,
                    "updated_at": updated_at.isoformat() if updated_at else None,
                }
            )

        stages = []
        for s in stages_order:
            proposals = stage_buckets.get(s) or []
            stages.append({"stage": s, "count": int(len(proposals)), "proposals": proposals})

        return jsonify(
            {
                "metric": "proposal_pipeline",
                "definition": "proposals grouped by stage",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter,
                    "proposal_type": proposal_type,
                    "client": client_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                    "stage": stage_filter or None,
                },
                "stages": stages,
            }
        ), 200

    except Exception as e:
        import traceback

        traceback.print_exc()
        return jsonify({"detail": str(e)}), 500

    finally:
        release_pg_conn(conn)


@bp.get("/analytics/approvals/summary")
@token_required
def approvals_summary(username=None, user_id=None, email=None):
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        owner_filter = (request.args.get("owner") or request.args.get("owner_id") or "").strip()
        proposal_type = (request.args.get("proposal_type") or "").strip()
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()

        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        owner_id_val, team_owner_ids, resolved_owner_id, _, err = _resolve_owner_scope(
            cursor,
            username,
            user_id,
            email,
            owner_filter,
            scope,
            department_filter,
        )
        if err:
            detail, code = err
            return jsonify({"detail": detail}), code

        if not owner_id_val and scope != "all":
            return jsonify(
                {
                    "metric": "approvals_summary",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter or None,
                        "proposal_type": proposal_type or None,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                    },
                    "totals": {
                        "total": 0,
                        "pending": 0,
                        "approved": 0,
                        "avg_approval_hours": None,
                    },
                }
            ), 200

        proposals_cols = _get_table_columns(cursor, "proposals")
        proposals_types = _get_table_column_types(cursor, "proposals")

        owner_col = "owner_id" if "owner_id" in proposals_cols else ("user_id" if "user_id" in proposals_cols else None)
        if not owner_col:
            return jsonify({"detail": "Proposals table is missing owner column"}), 500

        owner_col_type = (proposals_types.get(owner_col) or "").lower()
        owner_col_is_text = owner_col_type in {"character varying", "text", "varchar"}

        proposal_type_col = None
        if "template_type" in proposals_cols:
            proposal_type_col = "template_type"
        elif "template_key" in proposals_cols:
            proposal_type_col = "template_key"

        client_col = None
        if "client" in proposals_cols:
            client_col = "client"
        elif "client_name" in proposals_cols:
            client_col = "client_name"
        elif "client_email" in proposals_cols:
            client_col = "client_email"

        where = ["p.created_at IS NOT NULL"]
        params = []

        if start_date:
            where.append("p.created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("p.created_at <= %s")
            params.append(end_date)

        if proposal_type and proposal_type_col:
            where.append(f"p.{proposal_type_col} = %s")
            params.append(proposal_type)

        if client_filter and client_col:
            where.append(f"COALESCE(p.{client_col}::text, '') ILIKE %s")
            params.append(f"%{client_filter}%")

        if resolved_owner_id:
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
                            "metric": "approvals_summary",
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter or None,
                                "proposal_type": proposal_type or None,
                                "client": client_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                            },
                            "totals": {
                                "total": 0,
                                "pending": 0,
                                "approved": 0,
                                "avg_approval_hours": None,
                            },
                        }
                    ), 200
                placeholders = ",".join(["%s"] * len(team_owner_ids))
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text IN ({placeholders})")
                    params.extend([str(x) for x in team_owner_ids])
                else:
                    where.append(f"p.{owner_col} IN ({placeholders})")
                    params.extend(team_owner_ids)
            elif scope == "team" and team_owner_ids is None:
                pass
            else:
                if owner_id_val:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id_val))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id_val)

        where_sql = " AND ".join(where)

        approvals_exists = _table_exists(cursor, "approvals")
        approvals_join = ""
        approved_at_expr = "NULL::timestamp"
        if approvals_exists:
            approvals_cols = _get_table_columns(cursor, "approvals")
            if "proposal_id" in approvals_cols and "approved_at" in approvals_cols:
                approvals_join = "LEFT JOIN approvals a ON a.proposal_id = p.id"
                approved_at_expr = "MIN(a.approved_at)"
            else:
                approvals_exists = False

        cursor.execute(
            f"""
            SELECT
                COUNT(*) AS total,
                SUM(
                    CASE WHEN LOWER(COALESCE(p.status,'')) IN (
                        'pending ceo approval',
                        'pending approval',
                        'submitted',
                        'in review'
                    ) THEN 1 ELSE 0 END
                ) AS pending,
                SUM(
                    CASE
                        WHEN {approved_at_expr} IS NOT NULL THEN 1
                        WHEN LOWER(COALESCE(p.status,'')) LIKE '%approved%' THEN 1
                        WHEN LOWER(COALESCE(p.status,'')) LIKE '%sent to client%' THEN 1
                        ELSE 0
                    END
                ) AS approved,
                AVG(
                    CASE
                        WHEN {approved_at_expr} IS NOT NULL AND p.created_at IS NOT NULL THEN
                            EXTRACT(EPOCH FROM ({approved_at_expr} - p.created_at)) / 3600.0
                        ELSE NULL
                    END
                ) AS avg_approval_hours
            FROM proposals p
            {approvals_join}
            WHERE {where_sql}
            GROUP BY 1=1
            """,
            tuple(params),
        )
        row = cursor.fetchone()
        if not row:
            totals = {"total": 0, "pending": 0, "approved": 0, "avg_approval_hours": None}
        else:
            total, pending, approved, avg_hours = row[:4]
            try:
                avg_hours_out = float(avg_hours) if avg_hours is not None else None
            except Exception:
                avg_hours_out = None
            totals = {
                "total": int(total or 0),
                "pending": int(pending or 0),
                "approved": int(approved or 0),
                "avg_approval_hours": avg_hours_out,
            }

        return jsonify(
            {
                "metric": "approvals_summary",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter or None,
                    "proposal_type": proposal_type or None,
                    "client": client_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                },
                "totals": totals,
                "data_source": "approvals" if approvals_exists else "status_only",
            }
        ), 200

    except Exception as exc:
        import traceback

        traceback.print_exc()
        return jsonify({"detail": str(exc), "error_type": exc.__class__.__name__}), 500
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        release_pg_conn(conn)


@bp.get("/analytics/approvals/bottlenecks")
@token_required
def approvals_bottlenecks(username=None, user_id=None, email=None):
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        owner_filter = (request.args.get("owner") or request.args.get("owner_id") or "").strip()
        proposal_type = (request.args.get("proposal_type") or "").strip()
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()
        stale_days = request.args.get("stale_days", default=7, type=int)
        stale_days = min(max(int(stale_days or 7), 1), 365)
        limit = request.args.get("limit", default=50, type=int)
        limit = min(max(int(limit or 50), 1), 200)

        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        owner_id_val, team_owner_ids, resolved_owner_id, _, err = _resolve_owner_scope(
            cursor,
            username,
            user_id,
            email,
            owner_filter,
            scope,
            department_filter,
        )
        if err:
            detail, code = err
            return jsonify({"detail": detail}), code

        if not owner_id_val and scope != "all":
            return jsonify(
                {
                    "metric": "approvals_bottlenecks",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter or None,
                        "proposal_type": proposal_type or None,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                        "stale_days": stale_days,
                        "limit": limit,
                    },
                    "by_status": [],
                    "aging_buckets": [],
                    "stuck": [],
                }
            ), 200

        proposals_cols = _get_table_columns(cursor, "proposals")
        proposals_types = _get_table_column_types(cursor, "proposals")

        owner_col = "owner_id" if "owner_id" in proposals_cols else ("user_id" if "user_id" in proposals_cols else None)
        if not owner_col:
            return jsonify({"detail": "Proposals table is missing owner column"}), 500

        owner_col_type = (proposals_types.get(owner_col) or "").lower()
        owner_col_is_text = owner_col_type in {"character varying", "text", "varchar"}

        proposal_type_col = None
        if "template_type" in proposals_cols:
            proposal_type_col = "template_type"
        elif "template_key" in proposals_cols:
            proposal_type_col = "template_key"

        updated_expr = "p.created_at"
        if "updated_at" in proposals_cols:
            updated_expr = "COALESCE(p.updated_at, p.created_at)"

        client_col = None
        if "client" in proposals_cols:
            client_col = "client"
        elif "client_name" in proposals_cols:
            client_col = "client_name"
        elif "client_email" in proposals_cols:
            client_col = "client_email"

        where = ["p.created_at IS NOT NULL"]
        params = []

        if start_date:
            where.append("p.created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("p.created_at <= %s")
            params.append(end_date)

        if proposal_type and proposal_type_col:
            where.append(f"p.{proposal_type_col} = %s")
            params.append(proposal_type)

        if client_filter and client_col:
            where.append(f"COALESCE(p.{client_col}::text, '') ILIKE %s")
            params.append(f"%{client_filter}%")

        if resolved_owner_id:
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
                            "metric": "approvals_bottlenecks",
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter or None,
                                "proposal_type": proposal_type or None,
                                "client": client_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                                "stale_days": stale_days,
                                "limit": limit,
                            },
                            "by_status": [],
                            "aging_buckets": [],
                            "stuck": [],
                        }
                    ), 200
                placeholders = ",".join(["%s"] * len(team_owner_ids))
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text IN ({placeholders})")
                    params.extend([str(x) for x in team_owner_ids])
                else:
                    where.append(f"p.{owner_col} IN ({placeholders})")
                    params.extend(team_owner_ids)
            elif scope == "team" and team_owner_ids is None:
                pass
            else:
                if owner_id_val:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id_val))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id_val)

        where.append(
            "LOWER(COALESCE(p.status, '')) IN ('pending ceo approval','pending approval','submitted','in review')"
        )

        where_sql = " AND ".join(where)

        cursor.execute(
            f"""
            SELECT
                LOWER(COALESCE(p.status, '')) AS status_key,
                COUNT(*) AS cnt
            FROM proposals p
            WHERE {where_sql}
            GROUP BY LOWER(COALESCE(p.status, ''))
            ORDER BY cnt DESC
            """,
            tuple(params),
        )
        by_status = [{"status": r[0] or "", "count": int(r[1] or 0)} for r in (cursor.fetchall() or [])]

        cursor.execute(
            f"""
            SELECT
                p.id,
                p.title,
                p.status,
                p.created_at,
                {updated_expr} AS updated_at,
                {('p.' + client_col) if client_col else 'NULL::text'} AS client
            FROM proposals p
            WHERE {where_sql}
            ORDER BY {updated_expr} ASC NULLS FIRST, p.created_at ASC
            LIMIT %s
            """,
            tuple(params + [limit]),
        )

        now_utc = datetime.utcnow()
        stuck = []
        bucket_counts = {"0-1": 0, "1-3": 0, "3-7": 0, "7-14": 0, "14+": 0}
        stale_cutoff = now_utc - timedelta(days=stale_days)

        for pid, title, status, created_at, updated_at, client in cursor.fetchall() or []:
            ref_dt = updated_at or created_at
            age_days = None
            is_stale = False
            if ref_dt:
                try:
                    age_days = float((now_utc - ref_dt).total_seconds()) / 86400.0
                except Exception:
                    age_days = None
                if ref_dt <= stale_cutoff:
                    is_stale = True

            if age_days is None:
                bucket_counts["14+"] += 1
            elif age_days < 1:
                bucket_counts["0-1"] += 1
            elif age_days < 3:
                bucket_counts["1-3"] += 1
            elif age_days < 7:
                bucket_counts["3-7"] += 1
            elif age_days < 14:
                bucket_counts["7-14"] += 1
            else:
                bucket_counts["14+"] += 1

            if is_stale:
                stuck.append(
                    {
                        "proposal_id": _safe_int(pid) if _safe_int(pid) is not None else str(pid),
                        "title": title,
                        "status": status,
                        "client": client,
                        "created_at": created_at.isoformat() if created_at else None,
                        "updated_at": updated_at.isoformat() if updated_at else None,
                        "age_days": age_days,
                    }
                )

        aging_buckets = [{"bucket": k, "count": int(v)} for k, v in bucket_counts.items()]
        stuck.sort(key=lambda r: (-(float(r.get("age_days") or 0.0)), str(r.get("title") or "")))

        return jsonify(
            {
                "metric": "approvals_bottlenecks",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter or None,
                    "proposal_type": proposal_type or None,
                    "client": client_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                    "stale_days": stale_days,
                    "limit": limit,
                },
                "by_status": by_status,
                "aging_buckets": aging_buckets,
                "stuck": stuck[:limit],
                "data_source": "status_only",
            }
        ), 200

    except Exception as exc:
        import traceback

        traceback.print_exc()
        return jsonify({"detail": str(exc), "error_type": exc.__class__.__name__}), 500
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        release_pg_conn(conn)


@bp.get("/analytics/completion-rates")
@token_required
def completion_rates(username=None, user_id=None, email=None):
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        owner_filter = request.args.get("owner")
        proposal_type = request.args.get("proposal_type")
        client_filter = (request.args.get("client") or "").strip()
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()

        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        if owner_filter is None:
            owner_filter = request.args.get("owner_id")

        cursor.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'proposals'
            """
        )
        cols = cursor.fetchall()
        existing_columns = {r[0] for r in cols}
        col_types = {r[0]: r[1] for r in cols}

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

        updated_expr = "p.created_at"
        if "updated_at" in existing_columns:
            updated_expr = "COALESCE(p.updated_at, p.created_at)"

        if "client" in existing_columns:
            client_expr = "client"
        elif "client_name" in existing_columns:
            client_expr = "client_name"
        elif "client_email" in existing_columns:
            client_expr = "client_email"
        else:
            client_expr = "NULL::text"

        sections_expr = "NULL::text"
        if "sections" in existing_columns:
            sections_expr = "p.sections"

        content_expr = "NULL::text"
        if "content" in existing_columns:
            content_expr = "p.content"

        owner_id = user_id
        if not owner_id:
            lookup_email = email or username
            cursor.execute(
                "SELECT id FROM users WHERE email = %s OR username = %s",
                (lookup_email, username),
            )
            row = cursor.fetchone()
            owner_id = row[0] if row else None

        if not owner_id and scope != "all":
            return jsonify(
                {
                    "metric": "completion_rates",
                    "definition": "readiness score based on mandatory sections",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter,
                        "proposal_type": proposal_type,
                        "client": client_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                    },
                    "totals": {
                        "total": 0,
                        "passed": 0,
                        "failed": 0,
                        "pass_rate": 0,
                    },
                    "low_proposals": [],
                }
            ), 200

        team_owner_ids = None
        if scope in {"team", "all"} and not owner_filter and owner_id:
            cursor.execute(
                "SELECT role, department FROM users WHERE id = %s",
                (owner_id,),
            )
            me = cursor.fetchone()
            my_role = (me[0] if me else None) or ""
            my_department = (me[1] if me else None) or None

            role_lower = str(my_role).strip().lower()
            is_admin = role_lower in {"admin", "ceo"}

            if scope == "all":
                if not is_admin:
                    return jsonify({"detail": "Not authorized for scope=all"}), 403
                team_owner_ids = None
            else:
                if is_admin:
                    # Admin team view defaults to everyone; only narrow if department filter is provided.
                    if department_filter:
                        cursor.execute(
                            "SELECT id FROM users WHERE department = %s",
                            (department_filter,),
                        )
                        team_owner_ids = [int(r[0]) for r in cursor.fetchall() or []]
                    else:
                        team_owner_ids = None
                else:
                    dept = department_filter or my_department
                    if dept:
                        cursor.execute(
                            "SELECT id FROM users WHERE department = %s",
                            (dept,),
                        )
                        team_owner_ids = [int(r[0]) for r in cursor.fetchall() or []]
                    else:
                        team_owner_ids = [int(owner_id)]

        if owner_filter:
            cursor.execute(
                "SELECT id FROM users WHERE username = %s OR email = %s OR id::text = %s",
                (owner_filter, owner_filter, owner_filter),
            )
            owner_row = cursor.fetchone()
            owner_id = owner_row[0] if owner_row else None
            if not owner_id:
                return jsonify(
                    {
                        "metric": "completion_rates",
                        "definition": "readiness score based on mandatory sections",
                        "filters": {
                            "start_date": start_date_raw,
                            "end_date": end_date_raw,
                            "owner": owner_filter,
                            "proposal_type": proposal_type,
                            "client": client_filter or None,
                            "scope": scope,
                            "department": department_filter or None,
                        },
                        "totals": {
                            "total": 0,
                            "passed": 0,
                            "failed": 0,
                            "pass_rate": 0,
                        },
                        "low_proposals": [],
                    }
                ), 200

        where = ["p.created_at IS NOT NULL"]
        params = []

        if owner_filter:
            if owner_col_is_text:
                where.append(f"p.{owner_col}::text = %s::text")
                params.append(str(owner_id))
            else:
                where.append(f"p.{owner_col} = %s")
                params.append(owner_id)
        else:
            if scope == "all":
                pass
            elif scope == "team" and team_owner_ids is not None:
                if not team_owner_ids:
                    return jsonify(
                        {
                            "metric": "completion_rates",
                            "definition": "readiness score based on mandatory sections",
                            "filters": {
                                "start_date": start_date_raw,
                                "end_date": end_date_raw,
                                "owner": owner_filter,
                                "proposal_type": proposal_type,
                                "client": client_filter or None,
                                "scope": scope,
                                "department": department_filter or None,
                            },
                            "totals": {
                                "total": 0,
                                "passed": 0,
                                "failed": 0,
                                "pass_rate": 0,
                            },
                            "low_proposals": [],
                        }
                    ), 200
                if owner_col_is_text:
                    where.append(f"p.{owner_col}::text = ANY(%s::text[])")
                    params.append([str(x) for x in team_owner_ids])
                else:
                    where.append(f"p.{owner_col} = ANY(%s::int[])")
                    params.append(team_owner_ids)
            elif scope == "team" and team_owner_ids is None:
                pass
            else:
                if owner_id:
                    if owner_col_is_text:
                        where.append(f"p.{owner_col}::text = %s::text")
                        params.append(str(owner_id))
                    else:
                        where.append(f"p.{owner_col} = %s")
                        params.append(owner_id)

        if start_date:
            where.append("p.created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("p.created_at <= %s")
            params.append(end_date)

        if proposal_type:
            if proposal_type_col == "template_type":
                where.append("LOWER(p.template_type) = LOWER(%s)")
                params.append(proposal_type)
            elif proposal_type_col == "template_key":
                where.append("p.template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

        if client_filter and client_expr != "NULL::text":
            where.append(f"p.{client_expr} ILIKE %s")
            params.append(f"%{client_filter}%")

        where_sql = " AND ".join(where)

        join_cond = f"u.id = p.{owner_col}"
        if owner_col_is_text:
            join_cond = f"u.id::text = p.{owner_col}::text"

        cursor.execute(
            f"""
            SELECT
                p.id,
                p.title,
                p.status,
                p.created_at,
                {updated_expr} AS updated_at,
                p.{client_expr} AS client,
                u.id AS owner_id,
                COALESCE(u.full_name, u.username, u.email) AS owner,
                {sections_expr} AS sections,
                {content_expr} AS content_data
            FROM proposals p
            LEFT JOIN users u ON {join_cond}
            WHERE {where_sql}
            ORDER BY updated_at DESC NULLS LAST, p.id DESC
            """,
            params,
        )

        proposals = []
        passed = 0
        failed = 0
        per_day = {}

        for pid, title, status, created_at, updated_at, client, owner_id_row, owner, sections_raw, content_raw in cursor.fetchall() or []:
            # Prefer the richer `content` column; fall back to `sections`
            scored = _score_proposal(content_raw)
            if (not scored) or int(scored.get('score') or 0) == 0:
                scored = _score_proposal(sections_raw)
            issues = _missing_section_names(scored)
            ok = scored['score'] >= _PASS_THRESHOLD
            if ok:
                passed += 1
            else:
                failed += 1

            day_key = None
            if created_at:
                try:
                    day_key = created_at.date().isoformat()
                except Exception:
                    day_key = None
            if day_key:
                bucket = per_day.get(day_key)
                if not bucket:
                    bucket = {"created": 0, "passed": 0}
                    per_day[day_key] = bucket
                bucket["created"] += 1
                if ok:
                    bucket["passed"] += 1

            proposals.append(
                {
                    "proposal_id": int(pid),
                    "title": title,
                    "status": status,
                    "client": client,
                    "owner": owner,
                    "owner_id": int(owner_id_row) if owner_id_row is not None else None,
                    "created_at": created_at.isoformat() if created_at else None,
                    "updated_at": updated_at.isoformat() if updated_at else None,
                    "readiness_score": int(scored['score']),
                    "readiness_issues": issues,
                }
            )

        total = int(len(proposals))
        pass_rate = 0
        if total > 0:
            pass_rate = int(round((passed / total) * 100))

        # Trend: daily created volume + daily readiness pass rate
        trend = []
        if start_date and end_date and start_date <= end_date:
            d = start_date.date()
            end_d = end_date.date()
            while d <= end_d:
                key = d.isoformat()
                bucket = per_day.get(key) or {"created": 0, "passed": 0}
                created = int(bucket.get("created") or 0)
                passed_day = int(bucket.get("passed") or 0)
                cr = 0
                if created > 0:
                    cr = int(round((passed_day / created) * 100))
                trend.append({"date": key, "created": created, "completion_rate": cr})
                d = d + timedelta(days=1)

        low = [p for p in proposals if int(p.get("readiness_score") or 0) < _PASS_THRESHOLD]
        low.sort(key=lambda p: (int(p.get("readiness_score") or 0), str(p.get("title") or "")))

        return jsonify(
            {
                "metric": "completion_rates",
                "definition": "readiness score based on mandatory sections",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter,
                    "proposal_type": proposal_type,
                    "client": client_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                },
                "totals": {
                    "total": total,
                    "passed": int(passed),
                    "failed": int(failed),
                    "pass_rate": int(pass_rate),
                    "pass_threshold": int(_PASS_THRESHOLD),
                },
                "low_proposals": low[:25],
                "trend": trend,
            }
        ), 200

    except Exception as e:
        import traceback

        traceback.print_exc()
        return jsonify({"detail": str(e)}), 500

    finally:
        release_pg_conn(conn)
