from flask import Blueprint, request, jsonify
from datetime import datetime, timedelta
import psycopg2
from api.utils.database import _pg_conn, release_pg_conn
from api.utils.decorators import token_required

bp = Blueprint("cycle_time", __name__)


def _parse_date(s: str | None):
    if not s:
        return None
    # Accept "YYYY-MM-DD" or full ISO string
    try:
        return datetime.fromisoformat(s)
    except ValueError:
        return datetime.strptime(s, "%Y-%m-%d")


def _table_exists(cursor, table_name: str) -> bool:
    cursor.execute("SELECT to_regclass(%s)", (f"public.{table_name}",))
    return cursor.fetchone()[0] is not None


@bp.get("/analytics/cycle-time")
@token_required
def cycle_time_metrics(username=None, user_id=None, email=None):
    """
    First pass cycle time:
      cycle_time = updated_at - created_at

    Group by status to represent "stage".

    Filters (all optional):
      - start_date=YYYY-MM-DD
      - end_date=YYYY-MM-DD
      - status=<exact status string>
      - owner_id=<int>   (if not supplied, we use the current user's id)
    """
    conn = _pg_conn()
    cursor = conn.cursor()

    try:
        start_date_raw = request.args.get("start_date")
        end_date_raw = request.args.get("end_date")
        start_date = _parse_date(start_date_raw)
        end_date = _parse_date(end_date_raw)
        status = request.args.get("status")
        owner_filter = request.args.get("owner")
        proposal_type = request.args.get("proposal_type")
        scope = (request.args.get("scope") or "self").strip().lower()
        department_filter = (request.args.get("department") or "").strip()

        # If end_date is passed as a date-only string (YYYY-MM-DD), treat it as end-of-day.
        # Otherwise, proposals created later that same day get excluded by created_at <= end_date.
        if end_date and end_date_raw and "T" not in end_date_raw and len(end_date_raw) == 10:
            end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        # Backward compatibility
        if owner_filter is None:
            owner_filter = request.args.get("owner_id")

        # Discover schema
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

        # Resolve current user id
        # Prefer the trusted numeric user_id supplied by token_required (Firebase flow)
        owner_id = user_id
        if not owner_id:
            lookup_email = email or username
            cursor.execute(
                "SELECT id FROM users WHERE email = %s OR username = %s",
                (lookup_email, username),
            )
            row = cursor.fetchone()
            if not row:
                return jsonify(
                    {
                        "metric": "cycle_time",
                        "definition": "updated_at - created_at",
                        "filters": {
                            "start_date": request.args.get("start_date"),
                            "end_date": request.args.get("end_date"),
                            "status": status,
                            "owner": owner_filter,
                            "proposal_type": proposal_type,
                            "scope": scope,
                            "department": department_filter or None,
                        },
                        "bottleneck": None,
                        "by_stage": [],
                    }
                ), 200

            owner_id = row[0]

        team_owner_ids = None
        if scope in {"team", "all"} and not owner_filter:
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
            if owner_row:
                owner_id = owner_row[0]
            else:
                return jsonify(
                    {
                        "metric": "cycle_time",
                        "definition": "updated_at - created_at",
                        "filters": {
                            "start_date": request.args.get("start_date"),
                            "end_date": request.args.get("end_date"),
                            "status": status,
                            "owner": owner_filter,
                            "proposal_type": proposal_type,
                        },
                        "bottleneck": None,
                        "by_stage": [],
                    }
                ), 200

        where = ["1=1"]
        params = []

        if owner_filter:
            if owner_col_is_text:
                where.append(f"{owner_col}::text = %s::text")
                params.append(str(owner_id))
            else:
                where.append(f"{owner_col} = %s")
                params.append(owner_id)
        else:
            if scope == "all":
                pass
            elif scope == "team" and team_owner_ids is not None:
                if not team_owner_ids:
                    return jsonify(
                        {
                            "metric": "cycle_time",
                            "definition": "time spent in each stage (status transitions)",
                            "filters": {
                                "start_date": request.args.get("start_date"),
                                "end_date": request.args.get("end_date"),
                                "status": status,
                                "owner": owner_filter,
                                "proposal_type": proposal_type,
                                "scope": scope,
                                "department": department_filter or None,
                            },
                            "bottleneck": None,
                            "by_stage": [],
                        }
                    ), 200
                if owner_col_is_text:
                    where.append(f"{owner_col}::text = ANY(%s::text[])")
                    params.append([str(x) for x in team_owner_ids])
                else:
                    where.append(f"{owner_col} = ANY(%s::int[])")
                    params.append(team_owner_ids)
            else:
                if owner_col_is_text:
                    where.append(f"{owner_col}::text = %s::text")
                    params.append(str(owner_id))
                else:
                    where.append(f"{owner_col} = %s")
                    params.append(owner_id)

        if start_date:
            where.append("created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("created_at <= %s")
            params.append(end_date)
        if proposal_type:
            if proposal_type_col == "template_type":
                where.append("LOWER(template_type) = LOWER(%s)")
                params.append(proposal_type)
            elif proposal_type_col == "template_key":
                where.append("template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

        where_sql = " AND ".join(where)

        cursor.execute(
            f"""
            SELECT id, created_at, COALESCE(updated_at, created_at), status
            FROM proposals
            WHERE {where_sql}
            """,
            params,
        )

        proposals = cursor.fetchall()
        proposal_ids = [int(r[0]) for r in proposals]

        stage_durations = {}

        events_by_proposal = {}
        if proposal_ids:
            cursor.execute(
                """
                SELECT
                    proposal_id,
                    created_at,
                    COALESCE(metadata->>'from', metadata->>'old_status') AS from_status,
                    COALESCE(metadata->>'to', metadata->>'new_status') AS to_status
                FROM activity_log
                WHERE action_type = 'status_changed'
                  AND proposal_id = ANY(%s)
                ORDER BY proposal_id, created_at ASC
                """,
                (proposal_ids,),
            )
            for pid, at, from_status, to_status in cursor.fetchall():
                events_by_proposal.setdefault(int(pid), []).append(
                    {
                        "at": at,
                        "from": from_status,
                        "to": to_status,
                    }
                )

        for proposal_id, created_at, end_at, current_status in proposals:
            created_at = created_at
            end_at = end_at
            events = events_by_proposal.get(int(proposal_id)) or []

            if events:
                cur_stage = events[0].get("from") or current_status
                cur_start = created_at
                for ev in events:
                    ev_at = ev.get("at")
                    from_stage = ev.get("from")
                    to_stage = ev.get("to")

                    if from_stage and (not cur_stage or str(cur_stage).lower() != str(from_stage).lower()):
                        cur_stage = from_stage

                    if cur_stage and ev_at and cur_start and ev_at >= cur_start:
                        days = (ev_at - cur_start).total_seconds() / 86400.0
                        stage_durations.setdefault(str(cur_stage), []).append(days)

                    cur_stage = to_stage or cur_stage
                    cur_start = ev_at or cur_start

                if cur_stage and end_at and cur_start and end_at >= cur_start:
                    days = (end_at - cur_start).total_seconds() / 86400.0
                    stage_durations.setdefault(str(cur_stage), []).append(days)
            else:
                if current_status and created_at and end_at and end_at >= created_at:
                    days = (end_at - created_at).total_seconds() / 86400.0
                    stage_durations.setdefault(str(current_status), []).append(days)

        by_stage = []
        for stage_name, durations in stage_durations.items():
            if not durations:
                continue
            if status and str(stage_name).lower() != str(status).lower():
                continue
            by_stage.append(
                {
                    "stage": stage_name,
                    "samples": int(len(durations)),
                    "avg_days": float(sum(durations) / len(durations)) if durations else None,
                    "max_days": float(max(durations)) if durations else None,
                }
            )

        by_stage.sort(key=lambda x: (x.get("avg_days") is None, -(x.get("avg_days") or 0.0)))

        bottleneck = by_stage[0] if by_stage else None

        return jsonify(
            {
                "metric": "cycle_time",
                "definition": "time spent in each stage (status transitions)",
                "filters": {
                    "start_date": request.args.get("start_date"),
                    "end_date": request.args.get("end_date"),
                    "status": status,
                    "owner": owner_filter,
                    "proposal_type": proposal_type,
                    "scope": scope,
                    "department": department_filter or None,
                },
                "bottleneck": bottleneck,
                "by_stage": by_stage,
            }
        ), 200

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"detail": str(e)}), 500

    finally:
        release_pg_conn(conn)


@bp.get("/analytics/client-engagement")
@token_required
def client_engagement(username=None, user_id=None, email=None):
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
        region_filter = (request.args.get("region") or "").strip()
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

        clients_cols = set()
        if region_filter and _table_exists(cursor, "clients"):
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'clients'
                """
            )
            clients_cols = {r[0] for r in cursor.fetchall() or []}

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

        if not owner_id:
            return jsonify(
                {
                    "metric": "client_engagement",
                    "definition": "daily views (open events) + time spent + time-to-sign",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter,
                        "proposal_type": proposal_type,
                        "client": client_filter or None,
                        "region": region_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                    },
                    "views_total": 0,
                    "views_by_day": [],
                    "unique_clients": 0,
                    "time_spent_seconds": 0,
                    "sessions_count": 0,
                    "time_to_sign": {"samples": 0, "avg_days": None},
                    "conversion": {"released": 0, "signed": 0, "rate_percent": 0.0},
                }
            ), 200

        team_owner_ids = None
        if scope in {"team", "all"} and not owner_filter:
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
                        "metric": "client_engagement",
                        "definition": "daily views (open events) + time spent + time-to-sign",
                        "filters": {
                            "start_date": start_date_raw,
                            "end_date": end_date_raw,
                            "owner": owner_filter,
                            "proposal_type": proposal_type,
                            "client": client_filter or None,
                            "region": region_filter or None,
                            "scope": scope,
                            "department": department_filter or None,
                        },
                        "views_total": 0,
                        "views_by_day": [],
                        "unique_clients": 0,
                        "time_spent_seconds": 0,
                        "sessions_count": 0,
                        "time_to_sign": {"samples": 0, "avg_days": None},
                        "conversion": {"released": 0, "signed": 0, "rate_percent": 0.0},
                    }
                ), 200

        where = ["created_at IS NOT NULL"]
        params = []

        if owner_filter:
            if owner_col_is_text:
                where.append(f"{owner_col}::text = %s::text")
                params.append(str(owner_id))
            else:
                where.append(f"{owner_col} = %s")
                params.append(owner_id)
        else:
            if scope == "all":
                pass
            elif scope == "team" and team_owner_ids is not None:
                if not team_owner_ids:
                    proposal_ids = []
                else:
                    if owner_col_is_text:
                        where.append(f"{owner_col}::text = ANY(%s::text[])")
                        params.append([str(x) for x in team_owner_ids])
                    else:
                        where.append(f"{owner_col} = ANY(%s::int[])")
                        params.append(team_owner_ids)
            else:
                if owner_col_is_text:
                    where.append(f"{owner_col}::text = %s::text")
                    params.append(str(owner_id))
                else:
                    where.append(f"{owner_col} = %s")
                    params.append(owner_id)

        if proposal_type:
            if proposal_type_col == "template_type":
                where.append("LOWER(template_type) = LOWER(%s)")
                params.append(proposal_type)
            elif proposal_type_col == "template_key":
                where.append("template_key ILIKE %s")
                params.append(f"%{proposal_type}%")

        if client_filter and client_expr != "NULL::text":
            where.append(f"{client_expr} ILIKE %s")
            params.append(f"%{client_filter}%")

        if region_filter and "region" in clients_cols:
            region_proposal_ids = []
            try:
                if "client_id" in existing_columns:
                    cursor.execute(
                        """
                        SELECT p.id
                        FROM proposals p
                        JOIN clients c ON c.id = p.client_id
                        WHERE c.region ILIKE %s
                        """,
                        (f"%{region_filter}%",),
                    )
                    region_proposal_ids = [r[0] for r in cursor.fetchall() or []]
                elif "client_email" in existing_columns:
                    cursor.execute(
                        """
                        SELECT p.id
                        FROM proposals p
                        JOIN clients c ON c.email = p.client_email
                        WHERE c.region ILIKE %s
                        """,
                        (f"%{region_filter}%",),
                    )
                    region_proposal_ids = [r[0] for r in cursor.fetchall() or []]
            except Exception:
                region_proposal_ids = []

            if not region_proposal_ids:
                return jsonify(
                    {
                        "metric": "client_engagement",
                        "definition": "daily views (open events) + time spent + time-to-sign",
                        "filters": {
                            "start_date": start_date_raw,
                            "end_date": end_date_raw,
                            "owner": owner_filter,
                            "proposal_type": proposal_type,
                            "client": client_filter or None,
                            "region": region_filter or None,
                            "scope": scope,
                            "department": department_filter or None,
                        },
                        "views_total": 0,
                        "views_by_day": [],
                        "unique_clients": 0,
                        "time_spent_seconds": 0,
                        "sessions_count": 0,
                        "time_to_sign": {"samples": 0, "avg_days": None},
                        "conversion": {"released": 0, "signed": 0, "rate_percent": 0.0},
                    }
                ), 200

            where.append("id = ANY(%s)")
            params.append(region_proposal_ids)

        where_sql = " AND ".join(where)

        release_expr = "NULL::timestamp"
        if "released_at" in existing_columns:
            release_expr = "released_at"
        elif "sent_to_client_at" in existing_columns:
            release_expr = "sent_to_client_at"
        elif "sent_at" in existing_columns:
            release_expr = "sent_at"

        signed_expr = "NULL::timestamp"
        if "signed_at" in existing_columns:
            signed_expr = "signed_at"
        elif "signed_date" in existing_columns:
            signed_expr = "signed_date"

        cursor.execute(
            f"""
            SELECT id, created_at, {release_expr} AS released_at, {signed_expr} AS signed_at
            FROM proposals
            WHERE {where_sql}
            """,
            params,
        )
        proposals = cursor.fetchall() or []
        proposal_ids = [r[0] for r in proposals]

        if not proposal_ids:
            return jsonify(
                {
                    "metric": "client_engagement",
                    "definition": "daily views (open events) + time spent + time-to-sign",
                    "filters": {
                        "start_date": start_date_raw,
                        "end_date": end_date_raw,
                        "owner": owner_filter,
                        "proposal_type": proposal_type,
                        "client": client_filter or None,
                        "region": region_filter or None,
                        "scope": scope,
                        "department": department_filter or None,
                    },
                    "views_total": 0,
                    "views_by_day": [],
                    "unique_clients": 0,
                    "time_spent_seconds": 0,
                    "sessions_count": 0,
                    "time_to_sign": {"samples": 0, "avg_days": None},
                    "conversion": {"released": 0, "signed": 0, "rate_percent": 0.0},
                }
            ), 200

        # Views over time (client "open" events)
        views_by_day = []
        views_total = 0
        unique_clients = 0

        if _table_exists(cursor, "proposal_client_activity"):
            v_where = ["proposal_id = ANY(%s)", "event_type = 'open'"]
            v_params = [proposal_ids]
            if start_date:
                v_where.append("created_at >= %s")
                v_params.append(start_date)
            if end_date:
                v_where.append("created_at <= %s")
                v_params.append(end_date)
            v_where_sql = " AND ".join(v_where)

            cursor.execute(
                f"""
                SELECT DATE(created_at) AS day, COUNT(*)
                FROM proposal_client_activity
                WHERE {v_where_sql}
                GROUP BY DATE(created_at)
                ORDER BY day ASC
                """,
                v_params,
            )
            day_rows = cursor.fetchall() or []

            counts = {r[0]: int(r[1]) for r in day_rows}

            if start_date and end_date:
                day = start_date.date()
                end_day = end_date.date()
                while day <= end_day:
                    views_by_day.append({"date": day.isoformat(), "views": int(counts.get(day, 0))})
                    day = day + timedelta(days=1)
            else:
                for d, c in day_rows:
                    views_by_day.append({"date": d.isoformat(), "views": int(c)})

            views_total = int(sum(item["views"] for item in views_by_day))

            cursor.execute(
                f"""
                SELECT COUNT(DISTINCT client_id)
                FROM proposal_client_activity
                WHERE {v_where_sql}
                """,
                v_params,
            )
            unique_clients = int((cursor.fetchone() or [0])[0] or 0)

        # Time spent from client sessions
        time_spent_seconds = 0
        sessions_count = 0
        if _table_exists(cursor, "proposal_client_session"):
            s_where = ["proposal_id = ANY(%s)"]
            s_params = [proposal_ids]
            if start_date:
                s_where.append("session_start >= %s")
                s_params.append(start_date)
            if end_date:
                s_where.append("session_start <= %s")
                s_params.append(end_date)
            s_where_sql = " AND ".join(s_where)

            cursor.execute(
                f"""
                SELECT
                    COALESCE(SUM(total_seconds), 0) AS total_seconds,
                    COUNT(*) AS sessions_count
                FROM proposal_client_session
                WHERE {s_where_sql}
                """,
                s_params,
            )
            row = cursor.fetchone() or [0, 0]
            time_spent_seconds = int(row[0] or 0)
            sessions_count = int(row[1] or 0)

        # Time to sign: signed_at - released_at (fallback created_at)
        signed_durations = []
        for _, created_at, released_at, signed_at in proposals:
            if not signed_at:
                continue
            if start_date and signed_at < start_date:
                continue
            if end_date and signed_at > end_date:
                continue
            base = released_at or created_at
            if base and signed_at and signed_at >= base:
                signed_durations.append((signed_at - base).total_seconds() / 86400.0)

        avg_days = None
        if signed_durations:
            avg_days = float(sum(signed_durations) / len(signed_durations))

        released_count = 0
        signed_count = 0
        for _, _, released_at, signed_at in proposals:
            if released_at:
                released_count += 1
            if signed_at and released_at:
                signed_count += 1
        rate_percent = 0.0
        if released_count > 0:
            rate_percent = (signed_count / released_count) * 100.0

        return jsonify(
            {
                "metric": "client_engagement",
                "definition": "daily views (open events) + time spent + time-to-sign",
                "filters": {
                    "start_date": start_date_raw,
                    "end_date": end_date_raw,
                    "owner": owner_filter,
                    "proposal_type": proposal_type,
                    "client": client_filter or None,
                    "region": region_filter or None,
                    "scope": scope,
                    "department": department_filter or None,
                },
                "views_total": int(views_total),
                "views_by_day": views_by_day,
                "unique_clients": int(unique_clients),
                "time_spent_seconds": int(time_spent_seconds),
                "sessions_count": int(sessions_count),
                "time_to_sign": {"samples": int(len(signed_durations)), "avg_days": avg_days},
                "conversion": {
                    "released": int(released_count),
                    "signed": int(signed_count),
                    "rate_percent": float(rate_percent),
                },
            }
        ), 200

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"detail": str(e)}), 500

    finally:
        release_pg_conn(conn)


@bp.get("/analytics/collaboration-load")
@token_required
def collaboration_load(username=None, user_id=None, email=None):
    retried = False
    while True:
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
                if not row:
                    return jsonify(
                        {
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
                                "comments": 0,
                                "versions": 0,
                                "activity_events": 0,
                                "interactions": 0,
                            },
                            "total_proposals": 0,
                            "top_proposals": [],
                        }
                    ), 200
                owner_id = row[0]

            team_owner_ids = None
            if scope in {"team", "all"} and not owner_filter:
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
                if owner_row:
                    owner_id = owner_row[0]
                else:
                    return jsonify(
                        {
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
                                "comments": 0,
                                "versions": 0,
                                "activity_events": 0,
                                "interactions": 0,
                            },
                            "total_proposals": 0,
                            "top_proposals": [],
                        }
                    ), 200

            where = ["created_at IS NOT NULL"]
            params = []

            if owner_filter:
                if owner_col_is_text:
                    where.append(f"{owner_col}::text = %s::text")
                    params.append(str(owner_id))
                else:
                    where.append(f"{owner_col} = %s")
                    params.append(owner_id)
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
                                    "owner": owner_filter,
                                    "proposal_type": proposal_type,
                                    "client": client_filter or None,
                                    "scope": scope,
                                    "department": department_filter or None,
                                },
                                "totals": {
                                    "comments": 0,
                                    "versions": 0,
                                    "activity_events": 0,
                                    "interactions": 0,
                                },
                                "total_proposals": 0,
                                "top_proposals": [],
                            }
                        ), 200
                    if owner_col_is_text:
                        where.append(f"{owner_col}::text = ANY(%s::text[])")
                        params.append([str(x) for x in team_owner_ids])
                    else:
                        where.append(f"{owner_col} = ANY(%s::int[])")
                        params.append(team_owner_ids)
                else:
                    if owner_col_is_text:
                        where.append(f"{owner_col}::text = %s::text")
                        params.append(str(owner_id))
                    else:
                        where.append(f"{owner_col} = %s")
                        params.append(owner_id)

            if start_date:
                where.append("created_at >= %s")
                params.append(start_date)
            if end_date:
                where.append("created_at <= %s")
                params.append(end_date)

            if proposal_type:
                if proposal_type_col == "template_type":
                    where.append("LOWER(template_type) = LOWER(%s)")
                    params.append(proposal_type)
                elif proposal_type_col == "template_key":
                    where.append("template_key ILIKE %s")
                    params.append(f"%{proposal_type}%")

            if client_filter and client_expr != "NULL::text":
                where.append(f"{client_expr} ILIKE %s")
                params.append(f"%{client_filter}%")

            where_sql = " AND ".join(where)
            cursor.execute(
                f"""
                SELECT id, title, status, {client_expr} AS client
                FROM proposals
                WHERE {where_sql}
                """,
                params,
            )
            proposals = cursor.fetchall()
            proposal_ids = [int(r[0]) for r in proposals]
            proposal_meta = {
                int(r[0]): {
                    "proposal_id": int(r[0]),
                    "title": r[1],
                    "status": r[2],
                    "client": r[3],
                }
                for r in proposals
            }

            comments_by_proposal = {}
            versions_by_proposal = {}
            activity_by_proposal = {}

            if proposal_ids and _table_exists(cursor, "document_comments"):
                c_where = ["proposal_id = ANY(%s)"]
                c_params = [proposal_ids]
                if start_date:
                    c_where.append("created_at >= %s")
                    c_params.append(start_date)
                if end_date:
                    c_where.append("created_at <= %s")
                    c_params.append(end_date)
                c_where_sql = " AND ".join(c_where)
                cursor.execute(
                    f"""
                    SELECT proposal_id, COUNT(*)
                    FROM document_comments
                    WHERE {c_where_sql}
                    GROUP BY proposal_id
                    """,
                    c_params,
                )
                for pid, cnt in cursor.fetchall() or []:
                    comments_by_proposal[int(pid)] = int(cnt)

            if proposal_ids and _table_exists(cursor, "proposal_versions"):
                v_where = ["proposal_id = ANY(%s)"]
                v_params = [proposal_ids]
                if start_date:
                    v_where.append("created_at >= %s")
                    v_params.append(start_date)
                if end_date:
                    v_where.append("created_at <= %s")
                    v_params.append(end_date)
                v_where_sql = " AND ".join(v_where)
                cursor.execute(
                    f"""
                    SELECT proposal_id, COUNT(*)
                    FROM proposal_versions
                    WHERE {v_where_sql}
                    GROUP BY proposal_id
                    """,
                    v_params,
                )
                for pid, cnt in cursor.fetchall() or []:
                    versions_by_proposal[int(pid)] = int(cnt)

            if proposal_ids and _table_exists(cursor, "activity_log"):
                a_where = ["proposal_id = ANY(%s)", "action_type <> 'status_changed'"]
                a_params = [proposal_ids]
                if start_date:
                    a_where.append("created_at >= %s")
                    a_params.append(start_date)
                if end_date:
                    a_where.append("created_at <= %s")
                    a_params.append(end_date)
                a_where_sql = " AND ".join(a_where)
                cursor.execute(
                    f"""
                    SELECT proposal_id, COUNT(*)
                    FROM activity_log
                    WHERE {a_where_sql}
                    GROUP BY proposal_id
                    """,
                    a_params,
                )
                for pid, cnt in cursor.fetchall() or []:
                    activity_by_proposal[int(pid)] = int(cnt)

            total_comments = sum(comments_by_proposal.values())
            total_versions = sum(versions_by_proposal.values())
            total_activity = sum(activity_by_proposal.values())
            total_interactions = total_comments + total_versions + total_activity

            rows = []
            for pid in proposal_ids:
                meta = proposal_meta.get(pid) or {"proposal_id": pid, "title": None, "status": None, "client": None}
                c = int(comments_by_proposal.get(pid, 0))
                v = int(versions_by_proposal.get(pid, 0))
                a = int(activity_by_proposal.get(pid, 0))
                rows.append(
                    {
                        "proposal_id": meta.get("proposal_id"),
                        "title": meta.get("title"),
                        "status": meta.get("status"),
                        "client": meta.get("client"),
                        "comments": c,
                        "versions": v,
                        "activity_events": a,
                        "interactions": c + v + a,
                    }
                )

            rows.sort(key=lambda r: (-int(r.get("interactions") or 0), str(r.get("title") or "")))
            top_proposals = rows[:10]

            avg_per_proposal = None
            if proposal_ids:
                avg_per_proposal = {
                    "comments": float(total_comments) / len(proposal_ids),
                    "versions": float(total_versions) / len(proposal_ids),
                    "activity_events": float(total_activity) / len(proposal_ids),
                    "interactions": float(total_interactions) / len(proposal_ids),
                }

            return jsonify(
                {
                    "metric": "collaboration_load",
                    "definition": "comments + versions + activity events (excluding status changes)",
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
                        "comments": int(total_comments),
                        "versions": int(total_versions),
                        "activity_events": int(total_activity),
                        "interactions": int(total_interactions),
                    },
                    "total_proposals": int(len(proposal_ids)),
                    "avg_per_proposal": avg_per_proposal,
                    "top_proposals": top_proposals,
                }
            ), 200

        except (psycopg2.OperationalError, psycopg2.InterfaceError) as e:
            msg = str(e).lower()
            if (not retried) and (
                "server closed the connection unexpectedly" in msg
                or "connection not open" in msg
                or "terminating connection" in msg
            ):
                retried = True
                continue
            import traceback
            traceback.print_exc()
            return jsonify({"detail": str(e)}), 500

        except Exception as e:
            import traceback
            traceback.print_exc()
            return jsonify({"detail": str(e)}), 500

        finally:
            release_pg_conn(conn)
