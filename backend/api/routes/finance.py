"""Finance role routes - Financial data, payments, receipts, reports"""
from flask import Blueprint, request, jsonify
from api.utils.decorators import token_required
from api.utils.database import get_db_connection

bp = Blueprint('finance', __name__, url_prefix='/api/finance')

@bp.get('/dashboard')
@token_required
def finance_dashboard(username):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
        result = cursor.fetchone()
        if not result or result[0] not in ('finance', 'admin'):
            return jsonify({'detail': 'Finance access required'}), 403
    return jsonify({"message": f"Finance dashboard for {username}"})

@bp.get('/proposals')
@token_required
def list_finance_proposals(username, user_id=None, email=None):
    """List proposals relevant for finance."""
    with get_db_connection() as conn:
        cursor = conn.cursor()

        cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
        result = cursor.fetchone()
        if not result or result[0] not in ('finance', 'admin'):
            return jsonify({'detail': 'Finance access required'}), 403

        cursor.execute(
            '''SELECT id, owner_id, title, client, status, content, created_at, updated_at
               FROM proposals
               WHERE status IS NOT NULL AND status <> 'Draft'
               ORDER BY created_at DESC'''
        )
        rows = cursor.fetchall()

        proposals = []
        for row in rows:
            (pid, owner_id, title, client, status, content, created_at, updated_at) = row
            proposals.append({
                'id': pid,
                'owner_id': owner_id,
                'title': title,
                'client': client,
                'status': status,
                'content': content,
                'created_at': created_at.isoformat() if created_at else None,
                'updated_at': updated_at.isoformat() if updated_at else None,
            })

    return jsonify({'proposals': proposals})

def _update_finance_status(proposal_id, new_status, username, reason=None):
    """Internal helper to update proposal status for finance actions."""
    with get_db_connection() as conn:
        cursor = conn.cursor()

        cursor.execute('SELECT role, id FROM users WHERE username = %s', (username,))
        result = cursor.fetchone()
        if not result or result[0] not in ('finance', 'admin'):
            return {'detail': 'Finance access required'}, 403

        user_db_id = result[1]

        cursor.execute('SELECT id, status FROM proposals WHERE id = %s', (proposal_id,))
        row = cursor.fetchone()
        if not row:
            return {'detail': f'Proposal {proposal_id} not found'}, 404

        cursor.execute(
            '''UPDATE proposals
               SET status = %s, updated_at = NOW()
               WHERE id = %s''',
            (new_status, proposal_id)
        )

        try:
            cursor.execute(
                '''INSERT INTO activity_log (proposal_id, user_id, action_type, action_description)
                   VALUES (%s, %s, %s, %s)''',
                (
                    proposal_id,
                    user_db_id,
                    'finance_status_change',
                    f'Finance set status to "{new_status}"' + (f' with reason: {reason}' if reason else ''),
                ),
            )
        except Exception:
            pass

        conn.commit()

    return {'detail': f'Proposal {proposal_id} updated to {new_status}'}, 200

@bp.post('/proposals/<int:proposal_id>/approve')
@token_required
def approve_proposal_finance(username, proposal_id, user_id=None, email=None):
    body = request.get_json(silent=True) or {}
    reason = body.get('reason')
    payload, status_code = _update_finance_status(
        proposal_id,
        'Finance Approved',
        username,
        reason=reason,
    )
    return jsonify(payload), status_code

@bp.post('/proposals/<int:proposal_id>/reject')
@token_required
def reject_proposal_finance(username, proposal_id, user_id=None, email=None):
    body = request.get_json(silent=True) or {}
    reason = body.get('reason')
    payload, status_code = _update_finance_status(
        proposal_id,
        'Finance Rejected',
        username,
        reason=reason,
    )
    return jsonify(payload), status_code
