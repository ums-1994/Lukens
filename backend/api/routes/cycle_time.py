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
def cycle_time_metrics(username=None):
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
        # ---- 1) Resolve owner_id ----
        owner_id = request.args.get("owner_id")
        if owner_id:
            # ensure numeric
            try:
                owner_id = int(owner_id)
            except ValueError:
                return jsonify({"detail": "owner_id must be an integer"}), 400
        else:
            # derive from logged-in username
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            row = cursor.fetchone()
            if not row:
                return jsonify({"detail": "User not found"}), 404
            owner_id = row[0]

        # ---- 2) Optional filters ----
        start_date = _parse_date(request.args.get("start_date"))
        end_date = _parse_date(request.args.get("end_date"))
        status = request.args.get("status")

        where = [
            "owner_id = %s",
            "created_at IS NOT NULL",
            "updated_at IS NOT NULL",
        ]
        params = [owner_id]

        if start_date:
            where.append("created_at >= %s")
            params.append(start_date)
        if end_date:
            where.append("created_at <= %s")
            params.append(end_date)
        if status:
            where.append("status = %s")
            params.append(status)

        where_sql = " AND ".join(where)

        # ---- 3) Query averages by stage (status) ----
        cursor.execute(
            f"""
            SELECT
                status AS stage,
                COUNT(*) AS samples,
                AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 86400.0) AS avg_days,
                MAX(EXTRACT(EPOCH FROM (updated_at - created_at)) / 86400.0) AS max_days
            FROM proposals
            WHERE {where_sql}
            GROUP BY status
            ORDER BY avg_days DESC NULLS LAST;
            """,
            params,
        )

        rows = cursor.fetchall()

        by_stage = [
            {
                "stage": r[0],
                "samples": int(r[1]),
                "avg_days": float(r[2]) if r[2] is not None else None,
                "max_days": float(r[3]) if r[3] is not None else None,
            }
            for r in rows
        ]

        bottleneck = by_stage[0] if by_stage else None

        return jsonify(
            {
                "metric": "cycle_time",
                "definition": "updated_at - created_at",
                "filters": {
                    "start_date": request.args.get("start_date"),
                    "end_date": request.args.get("end_date"),
                    "owner_id": owner_id,
                    "status": status,
                },
                "bottleneck": bottleneck,
                "by_stage": by_stage,
            }
        ), 200

    finally:
        release_pg_conn(conn)
