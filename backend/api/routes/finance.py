from flask import Blueprint, request, jsonify
import psycopg2.extras
import traceback

from api.utils.database import get_db_connection
from api.utils.decorators import token_required

bp = Blueprint('finance', __name__)


def _get_existing_proposals_columns(cursor):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'proposals'
        """
    )
    rows = cursor.fetchall() or []
    cols = set()

    for row in rows:
        if row is None:
            continue

        # RealDictCursor returns dict-like rows: {'column_name': 'id'}
        if isinstance(row, dict):
            value = row.get('column_name')
            if value:
                cols.add(value)
            continue

        # Tuple/list rows: ('id',)
        try:
            cols.add(row[0])
        except Exception:
            continue

    return cols


@bp.get("/finance/proposals")
@token_required
def list_finance_proposals(username=None, user_id=None, email=None):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cols = _get_existing_proposals_columns(cursor)

            select_cols = [
                'id',
                'title',
                'status',
            ]

            if 'client' in cols:
                select_cols.append('client')
            if 'client_name' in cols:
                select_cols.append('client_name')
            if 'client_email' in cols:
                select_cols.append('client_email')

            if 'created_at' in cols:
                select_cols.append('created_at')
            if 'updated_at' in cols:
                select_cols.append('updated_at')

            # Attempt common amount/budget fields
            for amount_col in ('amount', 'total_amount', 'value', 'price'):
                if amount_col in cols:
                    select_cols.append(amount_col)
                    break

            # Owner column varies across branches
            owner_col = None
            if 'owner_id' in cols:
                owner_col = 'owner_id'
            elif 'user_id' in cols:
                owner_col = 'user_id'

            if owner_col:
                select_cols.append(owner_col)

            select_sql = ', '.join(select_cols)

            cursor.execute(
                f"""
                SELECT {select_sql}
                FROM proposals
                ORDER BY COALESCE(updated_at, created_at) DESC NULLS LAST, id DESC
                """
            )

            proposals = cursor.fetchall() or []
            return {'proposals': proposals}, 200

    except Exception as e:
        print(f"❌ Error fetching finance proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


def _update_proposal_status(proposal_id: int, status: str):
    with get_db_connection() as conn:
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        cols = _get_existing_proposals_columns(cursor)

        set_parts = ['status = %s']
        params = [status]

        if 'updated_at' in cols:
            set_parts.append('updated_at = NOW()')

        set_sql = ', '.join(set_parts)

        cursor.execute(
            f"""
            UPDATE proposals
            SET {set_sql}
            WHERE id = %s
            RETURNING id, title, status
            """,
            params + [proposal_id],
        )

        updated = cursor.fetchone()
        conn.commit()
        return updated


def _update_proposal_pricing(proposal_id: int, price: float):
    with get_db_connection() as conn:
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cols = _get_existing_proposals_columns(cursor)

        price_col = None
        for candidate in ('price', 'amount', 'total_amount', 'value'):
            if candidate in cols:
                price_col = candidate
                break

        if not price_col:
            return None

        set_parts = [f"{price_col} = %s"]
        params = [price]

        if 'updated_at' in cols:
            set_parts.append('updated_at = NOW()')

        set_sql = ', '.join(set_parts)

        cursor.execute(
            f"""
            UPDATE proposals
            SET {set_sql}
            WHERE id = %s
            RETURNING id, title, status
            """,
            params + [proposal_id],
        )

        updated = cursor.fetchone()
        conn.commit()
        return updated


@bp.post('/finance/proposals/<int:proposal_id>/approve')
@token_required
def approve_finance_proposal(username=None, proposal_id=None, user_id=None, email=None):
    try:
        data = request.get_json(silent=True) or {}
        price = data.get('price')

        if price is not None:
            try:
                price_value = float(price)
                _update_proposal_pricing(proposal_id, price_value)
            except Exception:
                pass

        updated = _update_proposal_status(proposal_id, 'Approved')
        if not updated:
            return {'detail': 'Proposal not found'}, 404
        return {'message': 'Proposal approved', 'proposal': updated}, 200
    except Exception as e:
        print(f"❌ Error approving proposal {proposal_id}: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post('/finance/proposals/<int:proposal_id>/reject')
@token_required
def reject_finance_proposal(username=None, proposal_id=None, user_id=None, email=None):
    try:
        data = request.get_json(silent=True) or {}
        reason = data.get('reason')
        price = data.get('price')

        if price is not None:
            try:
                price_value = float(price)
                _update_proposal_pricing(proposal_id, price_value)
            except Exception:
                pass

        updated = _update_proposal_status(proposal_id, 'Rejected')
        if not updated:
            return {'detail': 'Proposal not found'}, 404

        response = {'message': 'Proposal rejected', 'proposal': updated}
        if reason:
            response['reason'] = reason
        return response, 200
    except Exception as e:
        print(f"❌ Error rejecting proposal {proposal_id}: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500
