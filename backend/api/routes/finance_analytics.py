"""Finance analytics routes for the finance dashboard.

Provides KPI and chart data such as:
- Monthly revenue forecast (AI-derived probability)
- Proposal win rate analytics
- Average deal size
- Deal aging report
- Revenue funnel
- Signed revenue growth trend
- Top clients by revenue
- Financial alerts
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import psycopg2
import psycopg2.extras
from psycopg2.extras import Json
from flask import Blueprint, jsonify, request

from api.utils.database import get_db_connection
from api.utils.decorators import token_required, finance_required
from api.utils.helpers import create_notification
from api.routes.finance_export import _extract_amount_from_content as _extract_amount_from_content_export


bp = Blueprint("finance_analytics", __name__)


def _parse_int(value: Any, default: Optional[int] = None) -> Optional[int]:
    if value is None:
        return default
    try:
        return int(str(value).strip())
    except Exception:
        return default


def _parse_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    if isinstance(value, (int, float)):
        return float(value)
    try:
        s = str(value).strip()
    except Exception:
        return default
    if not s:
        return default
    cleaned = "".join(ch for ch in s if (ch.isdigit() or ch in ".-"))
    try:
        return float(cleaned)
    except Exception:
        return default


def _parse_date(value: Any) -> Optional[datetime]:
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    try:
        s = str(value).strip()
        if not s:
            return None
        return datetime.fromisoformat(s)
    except Exception:
        return None


def _month_key(dt: datetime) -> str:
    return f"{dt.year:04d}-{dt.month:02d}"


def _month_start(year: int, month: int) -> datetime:
    return datetime(year, month, 1, tzinfo=timezone.utc)


def _next_month_start(dt: datetime) -> datetime:
    if dt.month == 12:
        return datetime(dt.year + 1, 1, 1, tzinfo=timezone.utc)
    return datetime(dt.year, dt.month + 1, 1, tzinfo=timezone.utc)


def _status_key(status: Any) -> str:
    return (str(status or "")).strip().lower()


def _stage_from_status(status: Any) -> str:
    s = _status_key(status)
    if not s or "draft" in s:
        return "Draft"
    if "signed" in s or "client signed" in s or "won" in s:
        return "Signed"
    if "negotiat" in s:
        return "Negotiation"
    if "view" in s or "opened" in s:
        return "Viewed"
    if "sent" in s or "released" in s:
        return "Sent"
    if "review" in s or "pending" in s or "approved" in s:
        return "In Review"
    if "archiv" in s or "cancel" in s or "declin" in s or "lost" in s:
        return "Archived"
    return "Other"


def _stage_probability(stage: str) -> float:
    # Deterministic fallback if AI probability is unavailable.
    stage_key = (stage or "").strip().lower()
    mapping = {
        "draft": 0.10,
        "in review": 0.35,
        "sent": 0.55,
        "viewed": 0.50,
        "negotiation": 0.70,
        "signed": 1.00,
        "archived": 0.0,
        "other": 0.25,
    }
    return float(mapping.get(stage_key, 0.25))


def _extract_amount_from_content(content_data: Any) -> float:
    """Extract a monetary amount from proposal content.

    We intentionally reuse the finance export extraction logic so analytics and exports
    stay consistent.
    """
    try:
        return float(_extract_amount_from_content_export(content_data) or 0.0)
    except Exception:
        return 0.0


def _safe_json_load(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str):
        try:
            return json.loads(value)
        except Exception:
            return None
    return None


def _year_param() -> int:
    y = _parse_int(request.args.get("year"), None)
    if y is None:
        return datetime.now(timezone.utc).year
    return max(1970, min(y, 2100))


def _table_exists(cursor, table_name: str) -> bool:
    cursor.execute("SELECT to_regclass(%s)", (f"public.{table_name}",))
    row = cursor.fetchone()
    if not row:
        return False
    val = row.get("to_regclass") if isinstance(row, dict) else row[0]
    return val is not None


@dataclass
class ProposalFinanceRow:
    proposal_id: int
    title: str
    client_name: str
    status: str
    created_at: Optional[datetime]
    updated_at: Optional[datetime]
    target_close_at: Optional[datetime]
    amount_field: Optional[float]
    amount: float
    ai_probability: Optional[float]


def _load_proposals_with_finance(year: int) -> List[ProposalFinanceRow]:
    with get_db_connection() as conn:
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'proposals'
            """
        )
        cols = {r["column_name"] for r in cursor.fetchall() or []}

        client_expr = "NULL::text"
        if "client" in cols:
            client_expr = "p.client"
        elif "client_name" in cols:
            client_expr = "p.client_name"

        target_close_expr = "NULL::timestamp"
        if "engagement_target_close_at" in cols:
            target_close_expr = "p.engagement_target_close_at"

        updated_expr = "COALESCE(p.updated_at, p.created_at)"
        if "updated_at" not in cols:
            updated_expr = "p.created_at"

        content_expr = "p.content" if "content" in cols else "NULL::text"
        sections_expr = "p.sections" if "sections" in cols else "NULL::text"

        # Pull a numeric amount directly from the proposals table when available.
        # This matches what the Flutter UI shows in the proposals list.
        amount_expr = "NULL::text"
        for candidate in ["budget", "amount", "total_amount", "value", "total", "price"]:
            if candidate in cols:
                amount_expr = f"p.{candidate}::text"
                break

        # Load proposals broadly (pipeline KPIs should not go blank when the user selects
        # a year that doesn't match created_at/updated_at). Year filtering is applied
        # later at aggregation time for month-based charts.
        cursor.execute(
            f"""
            WITH latest_risk AS (
                SELECT DISTINCT ON (proposal_id)
                       proposal_id,
                       risk_score,
                       created_at
                FROM risk_gate_runs
                ORDER BY proposal_id, created_at DESC
            )
            SELECT
                p.id,
                COALESCE(p.title, '') AS title,
                COALESCE({client_expr}, '') AS client_name,
                COALESCE(p.status, '') AS status,
                p.created_at,
                {updated_expr} AS updated_at,
                {target_close_expr} AS target_close_at,
                {amount_expr} AS amount_field,
                {content_expr} AS content,
                {sections_expr} AS sections,
                lr.risk_score AS risk_score
            FROM proposals p
            LEFT JOIN latest_risk lr ON lr.proposal_id = p.id
            """,
        )

        rows = cursor.fetchall() or []

    out: List[ProposalFinanceRow] = []
    for r in rows:
        pid = _parse_int(r.get("id"), None)
        if pid is None:
            continue

        content_obj = _safe_json_load(r.get("content"))
        sections_obj = _safe_json_load(r.get("sections"))
        amount_field = None
        try:
            if r.get("amount_field") is not None:
                amount_field = _parse_float(r.get("amount_field"), default=0.0)
                if amount_field <= 0:
                    amount_field = None
        except Exception:
            amount_field = None

        amount = 0.0
        if amount_field is not None and amount_field > 0:
            amount = float(amount_field)
        else:
            amount = float(_extract_amount_from_content(content_obj) or 0.0)
            # Fallback: some deployments store pricing tables in the `sections` column
            # while leaving `content` as non-JSON text.
            if amount <= 0 and sections_obj is not None:
                amount = float(_extract_amount_from_content(sections_obj) or 0.0)

        risk_score = r.get("risk_score")
        ai_probability = None
        if risk_score is not None:
            try:
                rs = float(risk_score)
                rs = max(0.0, min(100.0, rs))
                # Interpret Risk Gate risk_score as probability of failure.
                # Convert to close probability as (1 - risk).
                ai_probability = max(0.0, min(1.0, 1.0 - (rs / 100.0)))
            except Exception:
                ai_probability = None

        out.append(
            ProposalFinanceRow(
                proposal_id=int(pid),
                title=str(r.get("title") or ""),
                client_name=str(r.get("client_name") or ""),
                status=str(r.get("status") or ""),
                created_at=_parse_date(r.get("created_at")),
                updated_at=_parse_date(r.get("updated_at")),
                target_close_at=_parse_date(r.get("target_close_at")),
                amount_field=amount_field,
                amount=float(amount or 0.0),
                ai_probability=ai_probability,
            )
        )

    return out


def _effective_probability(p: ProposalFinanceRow) -> float:
    if p.ai_probability is not None:
        return float(max(0.0, min(1.0, p.ai_probability)))
    stage = _stage_from_status(p.status)
    return _stage_probability(stage)


def _expected_close_month(p: ProposalFinanceRow) -> Optional[str]:
    # If the proposal has an explicit expected/target close date, use it.
    dt = p.target_close_at

    # Otherwise derive a forward-looking expected close month for open deals.
    # Falling back to updated_at/created_at will often place "forecast" revenue
    # in the past, which is not the intended meaning of a forecast chart.
    if dt is None and _is_open_deal(p):
        now = datetime.now(timezone.utc)
        stage = _stage_from_status(p.status)
        # Conservative defaults; tuned to produce a realistic future curve.
        stage_offsets_days = {
            "Draft": 90,
            "In Review": 60,
            "Sent": 45,
            "Viewed": 30,
            "Negotiation": 21,
            "Other": 60,
        }
        offset_days = int(stage_offsets_days.get(stage, 60))
        dt = now + timedelta(days=offset_days)

    # Signed/archived deals (or anything else without a target close date)
    # are attributed to the last update timestamp.
    if dt is None:
        dt = p.updated_at or p.created_at

    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return _month_key(dt)


def _signed_month(p: ProposalFinanceRow) -> Optional[str]:
    # Prefer target close date for signed deals if it exists; otherwise updated_at.
    # (We do not yet persist a dedicated signed_at column in the main schema.)
    if "signed" not in _status_key(p.status) and "approved" not in _status_key(p.status):
        return None
    dt = p.updated_at or p.created_at
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return _month_key(dt)


def _is_sent(p: ProposalFinanceRow) -> bool:
    s = _status_key(p.status)
    return ("sent" in s) or ("released" in s)


def _is_signed(p: ProposalFinanceRow) -> bool:
    s = _status_key(p.status)
    return ("signed" in s) or ("approved" in s) or ("client signed" in s)


def _is_open_deal(p: ProposalFinanceRow) -> bool:
    stage = _stage_from_status(p.status)
    return stage not in {"Signed", "Archived"}


def _signed_at(p: ProposalFinanceRow) -> Optional[datetime]:
    if not _is_signed(p):
        return None
    dt = p.updated_at or p.created_at
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


@bp.get("/finance/summary")
@token_required
@finance_required
def finance_summary(username=None, user_id=None, email=None):
    year = _year_param()
    proposals = _load_proposals_with_finance(year)

    pipeline_value = 0.0
    expected_revenue = 0.0
    signed_revenue = 0.0
    signed_deals = 0
    sent_total = 0
    signed_total = 0

    for p in proposals:
        pipeline_value += float(p.amount)

        if _is_open_deal(p):
            expected_revenue += float(p.amount) * float(_effective_probability(p))

        if _is_signed(p):
            signed_revenue += float(p.amount)
            signed_deals += 1

        if _is_sent(p):
            sent_total += 1
        if _is_signed(p):
            signed_total += 1

    # Some deployments mark proposals directly as Signed without ever passing
    # through an explicit Sent/Released status. If we only divide by sent_total
    # we can incorrectly show 0% even though signed deals exist.
    denom = sent_total if sent_total > 0 else signed_total
    win_rate = (signed_total / denom) if denom > 0 else 0.0
    avg_deal = (signed_revenue / signed_deals) if signed_deals > 0 else 0.0

    return (
        jsonify(
            {
                "metric": "finance_summary",
                "year": year,
                "pipeline_value": round(pipeline_value, 2),
                "expected_revenue": round(expected_revenue, 2),
                "signed_revenue": round(signed_revenue, 2),
                "win_rate": round(win_rate, 4),
                "average_deal_size": round(avg_deal, 2),
                "sent": int(sent_total),
                "signed": int(signed_total),
                "signed_deals": int(signed_deals),
            }
        ),
        200,
    )


@bp.get("/finance/recent-signed")
@token_required
@finance_required
def recent_signed_deals(username=None, user_id=None, email=None):
    year = _year_param()
    limit = _parse_int(request.args.get("limit"), 10) or 10
    limit = max(1, min(limit, 50))

    proposals = _load_proposals_with_finance(year)

    signed_rows: List[Tuple[datetime, ProposalFinanceRow]] = []
    for p in proposals:
        dt = _signed_at(p)
        if dt is None:
            continue
        signed_rows.append((dt, p))

    signed_rows.sort(key=lambda t: t[0], reverse=True)

    items: List[Dict[str, Any]] = []
    for dt, p in signed_rows[:limit]:
        items.append(
            {
                "proposal_id": int(p.proposal_id),
                "proposal": p.title,
                "client": p.client_name,
                "amount": round(float(p.amount), 2),
                "signed_at": dt.isoformat(),
            }
        )

    return jsonify({"metric": "recent_signed_deals", "year": year, "items": items}), 200


@bp.get("/finance/forecast/monthly")
@token_required
@finance_required
def revenue_forecast_monthly(username=None, user_id=None, email=None):
    year = _year_param()
    proposals = _load_proposals_with_finance(year)

    forecast: Dict[str, float] = {f"{year:04d}-{m:02d}": 0.0 for m in range(1, 13)}

    for p in proposals:
        month = _expected_close_month(p)
        if not month or not month.startswith(f"{year:04d}-"):
            continue
        prob = _effective_probability(p)
        forecast[month] = float(forecast.get(month, 0.0) + (p.amount * prob))

    items = [{"month": k, "forecast_revenue": round(v, 2)} for k, v in sorted(forecast.items())]

    return jsonify({"metric": "monthly_revenue_forecast", "year": year, "items": items}), 200


@bp.get("/finance/win-rate")
@token_required
@finance_required
def proposal_win_rate(username=None, user_id=None, email=None):
    year = _year_param()
    proposals = _load_proposals_with_finance(year)

    sent_total = 0
    signed_total = 0

    by_month: Dict[str, Dict[str, int]] = {f"{year:04d}-{m:02d}": {"sent": 0, "signed": 0} for m in range(1, 13)}

    for p in proposals:
        # Attribute sent/signed to the month of last update/creation (simple and consistent).
        dt = p.updated_at or p.created_at
        if dt is None:
            continue
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        if dt.year != year:
            continue
        month = _month_key(dt)

        if _is_sent(p):
            sent_total += 1
            by_month[month]["sent"] += 1
        if _is_signed(p):
            signed_total += 1
            by_month[month]["signed"] += 1

    denom = sent_total if sent_total > 0 else signed_total
    win_rate = (signed_total / denom) if denom > 0 else 0.0
    trend = []
    for month in sorted(by_month.keys()):
        sent = int(by_month[month]["sent"])
        signed = int(by_month[month]["signed"])
        month_denom = sent if sent > 0 else signed
        rate = (signed / month_denom) if month_denom > 0 else 0.0
        trend.append({"month": month, "sent": sent, "signed": signed, "win_rate": round(rate, 4)})

    return jsonify(
        {
            "metric": "proposal_win_rate",
            "year": year,
            "sent": int(sent_total),
            "signed": int(signed_total),
            "win_rate": round(win_rate, 4),
            "trend": trend,
        }
    ), 200


@bp.get("/finance/average-deal-size")
@token_required
@finance_required
def average_deal_size(username=None, user_id=None, email=None):
    year = _year_param()
    proposals = _load_proposals_with_finance(year)

    total_signed = 0.0
    count_signed = 0

    for p in proposals:
        if not _is_signed(p):
            continue
        total_signed += float(p.amount)
        count_signed += 1

    avg = (total_signed / count_signed) if count_signed > 0 else 0.0

    return jsonify(
        {
            "metric": "average_deal_size",
            "year": year,
            "total_signed_revenue": round(total_signed, 2),
            "signed_deals": int(count_signed),
            "average_deal_size": round(avg, 2),
        }
    ), 200


@bp.get("/finance/revenue-growth")
@token_required
@finance_required
def revenue_growth_trend(username=None, user_id=None, email=None):
    year = _year_param()
    proposals = _load_proposals_with_finance(year)

    by_month: Dict[str, float] = {f"{year:04d}-{m:02d}": 0.0 for m in range(1, 13)}

    for p in proposals:
        if not _is_signed(p):
            continue
        month = _signed_month(p)
        if not month or not month.startswith(f"{year:04d}-"):
            continue
        by_month[month] = float(by_month.get(month, 0.0) + p.amount)

    items = [{"month": k, "signed_revenue": round(v, 2)} for k, v in sorted(by_month.items())]

    return jsonify({"metric": "signed_revenue_growth", "year": year, "items": items}), 200


@bp.get("/finance/funnel")
@token_required
@finance_required
def revenue_funnel(username=None, user_id=None, email=None):
    year = _year_param()
    proposals = _load_proposals_with_finance(year)

    stage_order = ["Sent", "Viewed", "Negotiation", "Signed"]
    totals = {s: 0.0 for s in stage_order}

    for p in proposals:
        stage = _stage_from_status(p.status)
        if stage not in totals:
            continue
        totals[stage] += float(p.amount)

    items = [{"stage": s, "value": round(float(totals.get(s, 0.0)), 2)} for s in stage_order]

    return jsonify({"metric": "revenue_funnel", "year": year, "items": items}), 200


def _latest_status_change_at(cursor, proposal_id: int) -> Optional[datetime]:
    if not _table_exists(cursor, "activity_log"):
        return None
    cursor.execute(
        """
        SELECT created_at
        FROM activity_log
        WHERE proposal_id = %s AND action_type = 'status_changed'
        ORDER BY created_at DESC
        LIMIT 1
        """,
        (proposal_id,),
    )
    row = cursor.fetchone()
    if not row:
        return None
    if isinstance(row, dict):
        return row.get("created_at")
    return row[0]


@bp.get("/finance/deal-aging")
@token_required
@finance_required
def deal_aging(username=None, user_id=None, email=None):
    threshold_days = _parse_int(request.args.get("threshold_days"), 30) or 30
    threshold_days = max(1, min(threshold_days, 3650))

    year = _year_param()
    proposals = _load_proposals_with_finance(year)

    now = datetime.now(timezone.utc)

    items: List[Dict[str, Any]] = []

    with get_db_connection() as conn:
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        for p in proposals:
            stage = _stage_from_status(p.status)
            if stage in {"Signed", "Archived"}:
                continue

            changed_at = _latest_status_change_at(cursor, p.proposal_id) or p.updated_at or p.created_at
            if changed_at is None:
                continue
            if changed_at.tzinfo is None:
                changed_at = changed_at.replace(tzinfo=timezone.utc)

            days = (now - changed_at).total_seconds() / 86400.0
            if days < 0:
                continue

            flagged = days >= float(threshold_days)
            if not flagged:
                continue

            items.append(
                {
                    "proposal_id": int(p.proposal_id),
                    "proposal": p.title,
                    "client": p.client_name,
                    "stage": stage,
                    "days_in_stage": int(round(days)),
                    "status": p.status,
                    "flagged": bool(flagged),
                }
            )

    items.sort(key=lambda x: (-(x.get("days_in_stage") or 0), str(x.get("proposal") or "")))

    return jsonify(
        {
            "metric": "deal_aging",
            "year": year,
            "threshold_days": int(threshold_days),
            "items": items[:250],
        }
    ), 200


@bp.get("/finance/top-clients")
@token_required
@finance_required
def top_clients_by_revenue(username=None, user_id=None, email=None):
    year = _year_param()
    limit = _parse_int(request.args.get("limit"), 10) or 10
    limit = max(1, min(limit, 50))

    proposals = _load_proposals_with_finance(year)

    totals: Dict[str, float] = {}
    for p in proposals:
        if not _is_signed(p):
            continue
        client = (p.client_name or "").strip() or "Unknown Client"
        totals[client] = float(totals.get(client, 0.0) + p.amount)

    items = [
        {"client": k, "revenue": round(float(v), 2)}
        for k, v in sorted(totals.items(), key=lambda kv: kv[1], reverse=True)
    ]

    return jsonify({"metric": "top_clients_by_revenue", "year": year, "items": items[:limit]}), 200


def _compute_finance_alert_items(
    year: int, discount_max: float, stuck_days: int
) -> List[Dict[str, Any]]:
    """Compute current finance alerts from proposals and compliance (ephemeral snapshot)."""
    proposals = _load_proposals_with_finance(year)
    now = datetime.now(timezone.utc)

    alerts: List[Dict[str, Any]] = []

    for p in proposals:
        try:
            _ = _safe_json_load(None)
        except Exception:
            pass

        stage = _stage_from_status(p.status)
        if stage == "Negotiation":
            dt = p.updated_at or p.created_at
            if dt is not None:
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
                days = (now - dt).total_seconds() / 86400.0
                if days >= float(stuck_days):
                    alerts.append(
                        {
                            "type": "STUCK_IN_NEGOTIATION",
                            "severity": "warning",
                            "proposal_id": int(p.proposal_id),
                            "proposal": p.title,
                            "client": p.client_name,
                            "details": {"days": int(round(days)), "threshold": int(stuck_days)},
                        }
                    )

        prob = _effective_probability(p)
        if stage in {"Sent", "Viewed", "Negotiation", "In Review"} and prob < 0.3:
            alerts.append(
                {
                    "type": "LOW_CLOSE_PROBABILITY",
                    "severity": "info",
                    "proposal_id": int(p.proposal_id),
                    "proposal": p.title,
                    "client": p.client_name,
                    "details": {"probability": round(prob, 4)},
                }
            )

    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            if _table_exists(cursor, "proposal_compliance"):
                cursor.execute(
                    """
                    SELECT pc.proposal_id, pc.status, pc.reasons, p.title, p.status AS proposal_status,
                           COALESCE(p.client, p.client_name, '') AS client_name
                    FROM proposal_compliance pc
                    JOIN proposals p ON p.id = pc.proposal_id
                    WHERE pc.status = 'NON_COMPLIANT'
                    ORDER BY pc.evaluated_at DESC
                    LIMIT 250
                    """
                )
                rows = cursor.fetchall() or []
                for r in rows:
                    reasons = r.get("reasons")
                    if isinstance(reasons, str):
                        try:
                            reasons = json.loads(reasons)
                        except Exception:
                            reasons = []
                    if not isinstance(reasons, list):
                        reasons = []

                    for reason in reasons:
                        if not isinstance(reason, dict):
                            continue
                        if reason.get("rule") != "DISCOUNT_THRESHOLD":
                            continue
                        val = _parse_float(reason.get("value"), 0.0)
                        maxv = _parse_float(reason.get("max"), discount_max)
                        if val <= maxv:
                            continue
                        alerts.append(
                            {
                                "type": "DISCOUNT_THRESHOLD",
                                "severity": "warning",
                                "proposal_id": int(r.get("proposal_id")),
                                "proposal": r.get("title") or "",
                                "client": r.get("client_name") or "",
                                "details": {"discount": val, "max": maxv, "path": reason.get("path")},
                            }
                        )
    except Exception:
        pass

    seen = set()
    deduped: List[Dict[str, Any]] = []
    for a in alerts:
        key = (a.get("type"), a.get("proposal_id"))
        if key in seen:
            continue
        seen.add(key)
        deduped.append(a)

    return deduped[:250]


def _finance_alert_recipient_user_ids(cursor) -> List[int]:
    cursor.execute(
        """
        SELECT id FROM users
        WHERE LOWER(TRIM(COALESCE(role, ''))) IN ('finance_manager', 'finance', 'financial_manager')
           OR LOWER(TRIM(COALESCE(role, ''))) IN ('finance manager', 'financial manager')
           OR LOWER(TRIM(COALESCE(role, ''))) LIKE 'finance%%manager%%'
        """
    )
    rows = cursor.fetchall() or []
    out: List[int] = []
    for r in rows:
        uid = r.get("id") if isinstance(r, dict) else r[0]
        try:
            out.append(int(uid))
        except Exception:
            continue
    return list(dict.fromkeys(out))


def _ensure_finance_alert_events_table(cursor) -> None:
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS finance_alert_events (
            id SERIAL PRIMARY KEY,
            alert_type TEXT NOT NULL,
            proposal_id INTEGER NOT NULL,
            severity TEXT,
            details JSONB,
            proposal_title TEXT,
            client_name TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc', now())),
            resolved_at TIMESTAMPTZ NULL
        )
        """
    )
    cursor.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_finance_alert_events_open_unique
        ON finance_alert_events (alert_type, proposal_id)
        WHERE resolved_at IS NULL
        """
    )
    cursor.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_finance_alert_events_created
        ON finance_alert_events (created_at DESC)
        """
    )


def _sync_finance_alert_events_and_fetch(
    year: int, current: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """Persist open/resolved lifecycle; notify finance users when a new alert row opens."""
    year_start = datetime(year, 1, 1, tzinfo=timezone.utc)
    year_end = datetime(year + 1, 1, 1, tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)

    current_keys = {(str(a.get("type")), int(a.get("proposal_id"))) for a in current}

    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            _ensure_finance_alert_events_table(cursor)

            cursor.execute(
                """
                SELECT id, alert_type, proposal_id
                FROM finance_alert_events
                WHERE resolved_at IS NULL
                """
            )
            open_rows = cursor.fetchall() or []
            open_by_key = {
                (str(r["alert_type"]), int(r["proposal_id"])): int(r["id"])
                for r in open_rows
                if r.get("alert_type") is not None and r.get("proposal_id") is not None
            }

            for key, row_id in list(open_by_key.items()):
                if key not in current_keys:
                    cursor.execute(
                        """
                        UPDATE finance_alert_events
                        SET resolved_at = %s
                        WHERE id = %s AND resolved_at IS NULL
                        """,
                        (now, row_id),
                    )
                    del open_by_key[key]

            new_for_notify: List[Dict[str, Any]] = []
            for a in current:
                k = (str(a.get("type")), int(a.get("proposal_id")))
                if k in open_by_key:
                    continue
                details = a.get("details")
                details_param = Json(details) if isinstance(details, (dict, list)) else None
                cursor.execute("SAVEPOINT finance_alert_ins")
                try:
                    cursor.execute(
                        """
                        INSERT INTO finance_alert_events
                            (alert_type, proposal_id, severity, details, proposal_title, client_name)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        RETURNING id
                        """,
                        (
                            k[0],
                            k[1],
                            (a.get("severity") or "info"),
                            details_param,
                            (a.get("proposal") or "")[:2000],
                            (a.get("client") or "")[:2000],
                        ),
                    )
                    ins = cursor.fetchone()
                    cursor.execute("RELEASE SAVEPOINT finance_alert_ins")
                    if ins and ins.get("id"):
                        new_for_notify.append({**a, "_event_id": ins["id"]})
                        open_by_key[k] = int(ins["id"])
                except psycopg2.IntegrityError:
                    cursor.execute("ROLLBACK TO SAVEPOINT finance_alert_ins")

            conn.commit()

            # Notify after commit so row exists
            finance_ids = _finance_alert_recipient_user_ids(cursor)
            for a in new_for_notify:
                title = (a.get("type") or "Finance alert").replace("_", " ")
                pid = a.get("proposal_id")
                prop = (a.get("proposal") or "").strip()
                msg = f"{title}: {prop}" if prop else title
                meta = {
                    "finance_alert": True,
                    "alert_type": a.get("type"),
                    "proposal_id": pid,
                    "details": a.get("details"),
                }
                for uid in finance_ids:
                    try:
                        create_notification(
                            user_id=uid,
                            notification_type="finance_alert",
                            title=f"Financial alert: {title}",
                            message=msg[:2000],
                            proposal_id=int(pid) if pid is not None else None,
                            metadata=meta,
                        )
                    except Exception:
                        pass

            cursor.execute(
                """
                SELECT id, alert_type AS type, proposal_id, severity, details,
                       proposal_title AS proposal, client_name AS client,
                       created_at, resolved_at
                FROM finance_alert_events
                WHERE (created_at >= %s AND created_at < %s)
                   OR (resolved_at IS NOT NULL AND resolved_at >= %s AND resolved_at < %s)
                   OR (resolved_at IS NULL)
                ORDER BY created_at DESC
                LIMIT 250
                """,
                (year_start, year_end, year_start, year_end),
            )
            rows = cursor.fetchall() or []
            out: List[Dict[str, Any]] = []
            for r in rows:
                if not r:
                    continue
                rid = r.get("resolved_at")
                st = "resolved" if rid else "active"
                details = r.get("details")
                if isinstance(details, str):
                    try:
                        details = json.loads(details)
                    except Exception:
                        details = {}
                item = {
                    "id": int(r["id"]),
                    "type": r.get("type") or "",
                    "severity": (r.get("severity") or "info"),
                    "proposal_id": int(r["proposal_id"]) if r.get("proposal_id") is not None else None,
                    "proposal": r.get("proposal") or "",
                    "client": r.get("client") or "",
                    "details": details,
                    "status": st,
                    "triggered_at": r["created_at"].isoformat() if r.get("created_at") else None,
                    "resolved_at": rid.isoformat() if rid else None,
                }
                out.append(item)
            conn.commit()
            return out
    except Exception as e:
        print(f"⚠️ finance_alert_events sync/fetch failed (non-fatal): {e}")
        return []


def _iter_discount_values(content_obj: Any) -> List[Tuple[str, float]]:
    results: List[Tuple[str, float]] = []

    def walk(node: Any, path: str) -> None:
        if isinstance(node, dict):
            for k, v in node.items():
                p = f"{path}.{k}" if path else str(k)
                if isinstance(k, str) and "discount" in k.lower():
                    num = _parse_float(v, default=0.0)
                    if num != 0.0:
                        results.append((p, float(num)))
                walk(v, p)
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, f"{path}[{i}]")

    walk(content_obj, "")
    return results


@bp.get("/finance/alerts")
@token_required
@finance_required
def finance_alerts(username=None, user_id=None, email=None):
    # Alerts are best-effort and should never error.
    year = _year_param()
    discount_max = _parse_float(request.args.get("discount_max"), 20.0)
    stuck_days = _parse_int(request.args.get("stuck_days"), 45) or 45

    deduped = _compute_finance_alert_items(year, discount_max, stuck_days)
    persisted = _sync_finance_alert_events_and_fetch(year, deduped)

    if persisted:
        items = persisted
    else:
        items = [
            {
                **a,
                "status": "active",
                "triggered_at": None,
                "resolved_at": None,
            }
            for a in deduped
        ]

    return jsonify({"metric": "finance_alerts", "year": year, "items": items[:250]}), 200
