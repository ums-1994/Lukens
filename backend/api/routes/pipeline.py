from flask import Blueprint, request, jsonify
from datetime import datetime
from api.utils.database import _pg_conn, release_pg_conn
from api.utils.decorators import token_required

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
    if "review" in s or ("pending" in s and "ceo" in s) or "approved" in s:
        return "In Review"
    return None


def _sections_readiness(sections) -> tuple[int, list[str]]:
    required = ["Introduction", "Methodology", "Conclusion"]
    total = len(required)
    if total == 0:
        return 0, []

    completed = 0
    issues: list[str] = []

    if not isinstance(sections, dict):
        sections = {}

    for field in required:
        val = sections.get(field)
        ok = False
        if isinstance(val, str):
            ok = bool(val.strip())
        elif val is not None:
            ok = True

        if ok:
            completed += 1
        else:
            issues.append(f"{field} is required")

    score = int(round((completed / total) * 100))
    return score, issues


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
        industry_filter = (request.args.get("industry") or "").strip()
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

        clients_join = ""
        industry_where = ""
        if industry_filter:
            try:
                cursor.execute("SELECT to_regclass(%s)", ("public.clients",))
                has_clients = cursor.fetchone()[0] is not None
            except Exception:
                has_clients = False
            if has_clients:
                join_cond = None
                if "client_id" in existing_columns:
                    join_cond = "c.id = p.client_id"
                elif "client_email" in existing_columns:
                    join_cond = "c.email = p.client_email"
                if join_cond:
                    clients_join = f"LEFT JOIN clients c ON {join_cond}"
                    industry_where = " AND c.industry ILIKE %s"
                    params.append(f"%{industry_filter}%")

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

            if scope == "all":
                role_lower = str(my_role).strip().lower()
                if role_lower not in {"admin", "ceo"}:
                    return jsonify({"detail": "Not authorized for scope=all"}), 403
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
            {clients_join}
            WHERE {where_sql}{industry_where}
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
        industry_filter = (request.args.get("industry") or "").strip()
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

        clients_join = ""
        industry_where = ""
        if industry_filter:
            try:
                cursor.execute("SELECT to_regclass(%s)", ("public.clients",))
                has_clients = cursor.fetchone()[0] is not None
            except Exception:
                has_clients = False
            if has_clients:
                join_cond = None
                if "client_id" in existing_columns:
                    join_cond = "c.id = p.client_id"
                elif "client_email" in existing_columns:
                    join_cond = "c.email = p.client_email"
                if join_cond:
                    clients_join = f"LEFT JOIN clients c ON {join_cond}"
                    industry_where = " AND c.industry ILIKE %s"
                    params.append(f"%{industry_filter}%")

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

            if scope == "all":
                role_lower = str(my_role).strip().lower()
                if role_lower not in {"admin", "ceo"}:
                    return jsonify({"detail": "Not authorized for scope=all"}), 403
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
                {sections_expr} AS sections
            FROM proposals p
            LEFT JOIN users u ON {join_cond}
            {clients_join}
            WHERE {where_sql}{industry_where}
            ORDER BY updated_at DESC NULLS LAST, p.id DESC
            """,
            params,
        )

        proposals = []
        passed = 0
        failed = 0

        for pid, title, status, created_at, updated_at, client, owner_id_row, owner, sections_raw in cursor.fetchall() or []:
            sections = {}
            if sections_raw:
                if isinstance(sections_raw, dict):
                    sections = sections_raw
                else:
                    try:
                        import json

                        sections = json.loads(sections_raw)
                    except Exception:
                        sections = {}

            score, issues = _sections_readiness(sections)
            ok = len(issues) == 0
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
                    "readiness_score": int(score),
                    "readiness_issues": issues,
                }
            )

        total = int(len(proposals))
        pass_rate = 0
        if total > 0:
            pass_rate = int(round((passed / total) * 100))

        low = [p for p in proposals if int(p.get("readiness_score") or 0) < 100]
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
