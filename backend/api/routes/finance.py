"""Finance role routes - Metrics and finance queue helpers"""

from flask import Blueprint, request
import psycopg2.extras
from datetime import datetime, timedelta

from api.utils.database import get_db_connection
from api.utils.decorators import token_required


bp = Blueprint('finance', __name__)


def _safe_lower(v):
    try:
        return (v or '').strip().lower()
    except Exception:
        return ''


def _pick_first(existing, candidates):
    for c in candidates:
        if c in existing:
            return c
    return None


@bp.get('/finance/metrics')
@token_required
def get_finance_metrics(username=None, user_id=None, email=None):
    """Return finance dashboard metrics.

    Finance queue default: proposals that are approved internally but not yet released/sent to client/signed.
    """
    try:
        start_str = (request.args.get('start') or '').strip()
        end_str = (request.args.get('end') or '').strip()

        start_dt = datetime.fromisoformat(start_str) if start_str else None
        end_dt = datetime.fromisoformat(end_str) if end_str else None

        if end_dt is not None and start_dt is None:
            start_dt = end_dt - timedelta(days=30)
        if start_dt is not None and end_dt is None:
            end_dt = datetime.utcnow()

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
                  AND table_schema = current_schema()
                """
            )
            cols = cursor.fetchall() or []
            existing_columns = [
                (c['column_name'] if isinstance(c, dict) else c[0]) for c in cols
            ]

            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'users'
                  AND table_schema = current_schema()
                """
            )
            user_cols = cursor.fetchall() or []
            existing_user_columns = [
                (c['column_name'] if isinstance(c, dict) else c[0]) for c in user_cols
            ]

            if user_id and 'role' in existing_user_columns:
                cursor.execute('SELECT role FROM users WHERE id = %s', (user_id,))
                u = cursor.fetchone()
                role = _safe_lower(u.get('role') if isinstance(u, dict) else None) if u else ''
                if role and ('finance' not in role and 'admin' not in role and 'ceo' not in role):
                    return {'detail': 'Forbidden'}, 403

            client_col = _pick_first(existing_columns, ['client', 'client_name'])
            budget_col = _pick_first(existing_columns, ['budget', 'amount', 'price', 'total', 'value'])
            created_col = _pick_first(existing_columns, ['created_at', 'createdAt']) or 'created_at'
            updated_col = _pick_first(existing_columns, ['updated_at', 'updatedAt']) or 'updated_at'

            client_expr = f"p.{client_col}" if client_col else "NULL::text"
            budget_expr = f"p.{budget_col}" if budget_col else "NULL::numeric"

            date_filters = []
            params = []
            if start_dt is not None:
                date_filters.append(f"p.{updated_col} >= %s")
                params.append(start_dt)
            if end_dt is not None:
                date_filters.append(f"p.{updated_col} <= %s")
                params.append(end_dt)

            date_where = ''
            if date_filters:
                date_where = ' AND ' + ' AND '.join(date_filters)

            cursor.execute(
                f"""
                SELECT
                    p.id,
                    p.title,
                    {client_expr} AS client_name,
                    p.status,
                    p.{created_col} AS created_at,
                    p.{updated_col} AS updated_at,
                    COALESCE({budget_expr}, 0) AS budget
                FROM proposals p
                WHERE 1=1{date_where}
                ORDER BY p.{updated_col} DESC
                """,
                tuple(params),
            )
            rows = cursor.fetchall() or []

            def _is_queue(status: str) -> bool:
                s = _safe_lower(status)
                if not s:
                    return False
                return (s == 'pending finance') or (s == 'finance in progress')

            # For this workflow, "approved" means "submitted onwards to approver"
            def _is_fin_approved(status: str) -> bool:
                s = _safe_lower(status)
                return s == 'pending approval'

            def _is_fin_rejected(status: str) -> bool:
                s = _safe_lower(status)
                return ('finance_rejected' in s) or (s == 'finance rejected')

            queue_items = []
            queue_value = 0.0

            approved_items = []
            approved_value = 0.0

            rejected_items = []
            rejected_value = 0.0

            for r in rows:
                status = str(r.get('status') or '')
                budget = r.get('budget')
                try:
                    budget_val = float(budget) if budget is not None else 0.0
                except Exception:
                    budget_val = 0.0

                if _is_queue(status):
                    queue_items.append(r)
                    queue_value += budget_val
                elif _is_fin_approved(status):
                    approved_items.append(r)
                    approved_value += budget_val
                elif _is_fin_rejected(status):
                    rejected_items.append(r)
                    rejected_value += budget_val

            now = datetime.utcnow()
            attention = []
            for r in queue_items:
                updated_at = r.get('updated_at')
                age_days = None
                try:
                    if updated_at is not None:
                        if isinstance(updated_at, str):
                            parsed = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
                            age_days = (now - parsed.replace(tzinfo=None)).days
                        else:
                            age_days = (now - updated_at.replace(tzinfo=None)).days
                except Exception:
                    age_days = None

                budget = r.get('budget')
                try:
                    budget_val = float(budget) if budget is not None else 0.0
                except Exception:
                    budget_val = 0.0

                if age_days is not None and age_days >= 7:
                    attention.append({
                        'id': r.get('id'),
                        'title': r.get('title'),
                        'client_name': r.get('client_name'),
                        'status': r.get('status'),
                        'days_in_stage': age_days,
                        'budget': budget_val,
                    })

            attention.sort(key=lambda x: (-(x.get('budget') or 0), -(x.get('days_in_stage') or 0)))

            def _serialize_row(r):
                created_at = r.get('created_at')
                updated_at = r.get('updated_at')
                return {
                    'id': r.get('id'),
                    'title': r.get('title'),
                    'client_name': r.get('client_name'),
                    'status': r.get('status'),
                    'budget': float(r.get('budget') or 0),
                    'created_at': created_at.isoformat() if hasattr(created_at, 'isoformat') and created_at else (str(created_at) if created_at else None),
                    'updated_at': updated_at.isoformat() if hasattr(updated_at, 'isoformat') and updated_at else (str(updated_at) if updated_at else None),
                }

            return {
                'range': {
                    'start': start_dt.isoformat() if start_dt else None,
                    'end': end_dt.isoformat() if end_dt else None,
                },
                'queue': {
                    'count': len(queue_items),
                    'value': queue_value,
                },
                'decisions': {
                    'approved': {'count': len(approved_items), 'value': approved_value},
                    'rejected': {'count': len(rejected_items), 'value': rejected_value},
                },
                'attention': attention[:10],
                'items': {
                    'queue': [_serialize_row(r) for r in queue_items[:50]],
                },
                'money_field': budget_col,
            }, 200

    except Exception as e:
        return {'detail': str(e)}, 500
