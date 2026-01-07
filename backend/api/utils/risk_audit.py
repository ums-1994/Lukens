import json
import psycopg2.extras


def record_proposal_risk_audit(
    conn,
    proposal_id: int,
    triggered_by: str,
    model_used: str | None,
    precheck_summary: dict | None,
    ai_summary: dict | None,
    combined_summary: dict | None,
    decision_action: str,
    override_applied: bool = False,
    override_reason: str | None = None,
    override_by: str | None = None,
) -> None:
    precheck_summary = precheck_summary or {}
    ai_summary = ai_summary or {}
    combined_summary = combined_summary or {}

    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO proposal_risk_audits (
            proposal_id,
            triggered_by,
            model_used,
            precheck_summary,
            ai_summary,
            combined_summary,
            overall_risk_level,
            risk_score,
            can_release,
            decision_action,
            override_applied,
            override_reason,
            override_by
        ) VALUES (%s, %s, %s, %s::jsonb, %s::jsonb, %s::jsonb, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            proposal_id,
            triggered_by,
            model_used,
            json.dumps(precheck_summary),
            json.dumps(ai_summary),
            json.dumps(combined_summary),
            combined_summary.get("overall_risk_level"),
            combined_summary.get("risk_score"),
            combined_summary.get("can_release"),
            decision_action,
            bool(override_applied),
            override_reason,
            override_by,
        ),
    )


def get_latest_risk_audit(conn, proposal_id: int) -> dict | None:
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute(
        """
        SELECT *
        FROM proposal_risk_audits
        WHERE proposal_id = %s
        ORDER BY created_at DESC, id DESC
        LIMIT 1
        """,
        (proposal_id,),
    )
    row = cursor.fetchone()
    if not row:
        return None
    return dict(row)
