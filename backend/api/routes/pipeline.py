from flask import Blueprint, request, jsonify
from datetime import datetime
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
                },
                "low_proposals": low[:25],
            }
        ), 200

    except Exception as e:
        import traceback

        traceback.print_exc()
        return jsonify({"detail": str(e)}), 500

    finally:
        release_pg_conn(conn)
