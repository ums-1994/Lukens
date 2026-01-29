from flask import Blueprint, request, jsonify
from datetime import datetime
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
        start_date = _parse_date(request.args.get("start_date"))
        end_date = _parse_date(request.args.get("end_date"))
        status = request.args.get("status")
        owner_filter = request.args.get("owner")
        proposal_type = request.args.get("proposal_type")

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
                        },
                        "bottleneck": None,
                        "by_stage": [],
                    }
                ), 200

            owner_id = row[0]
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

        where = ["created_at IS NOT NULL"]
        params = []

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
