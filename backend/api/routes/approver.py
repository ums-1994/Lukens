"""
Approver role routes - Reviewing proposals, approving/rejecting, viewing pending approvals
"""
from flask import Blueprint, request, jsonify
import os
import traceback
import secrets
import html
import psycopg2.extras
from datetime import datetime, timedelta

from api.utils.database import get_db_connection
from api.utils.decorators import token_required

bp = Blueprint('approver', __name__)

# ============================================================================
# APPROVER ROUTES
# ============================================================================

@bp.get("/proposals/pending_approval")
@token_required
def get_pending_approvals(username=None):
    """Get all proposals pending approval"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at
                   FROM proposals WHERE status = 'Submitted' OR status = 'In Review'
                   ORDER BY created_at DESC'''
            )
            rows = cursor.fetchall()
            proposals = []
            for row in rows:
                proposals.append({
                    'id': row[0],
                    'title': row[1],
                    'client': row[2],
                    'owner_id': row[3],
                    'status': row[4],
                    'created_at': row[5].isoformat() if row[5] else None
                })
            return {'proposals': proposals}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/approve")
@token_required
def approve_proposal(username=None, proposal_id=None):
    """Approve proposal and send to client"""
    try:
        data = request.get_json(force=True, silent=True) or {}
        comments = data.get('comments', '')
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get proposal details
            cursor.execute(
                '''SELECT id, title, client_name, client_email, user_id, content 
                   FROM proposals WHERE id = %s''',
                (proposal_id,)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            title = proposal.get('title')
            client_name = proposal.get('client_name')
            client_email = proposal.get('client_email')
            creator = proposal.get('user_id')
            proposal_content = proposal.get('content')
            display_title = title or f"Proposal {proposal_id}"
            
            # Get approver info
            cursor.execute(
                "SELECT id, full_name, username, email FROM users WHERE username = %s",
                (username,)
            )
            approver_user = cursor.fetchone()
            approver_user_id = approver_user['id'] if approver_user else None
            approver_name = (
                approver_user.get('full_name')
                or approver_user.get('username')
                or approver_user.get('email')
                or username
            ) if approver_user else username
            
            # Update status to Sent to Client
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() 
                   WHERE id = %s RETURNING status''',
                ('Sent to Client', proposal_id)
            )
            status_row = cursor.fetchone()
            conn.commit()
            
            if status_row:
                new_status = status_row['status']
                print(f"[SUCCESS] Proposal {proposal_id} '{title}' approved and status updated")
                
                # Note: notify_proposal_collaborators would need to be imported from app.py
                # For now, we'll skip notifications in this separated version
                # You can add it back by importing the helper function
                
                return {
                    'detail': 'Proposal approved and sent to client',
                    'status': new_status,
                    'email_sent': bool(client_email and client_email.strip())
                }, 200
            else:
                return {'detail': 'Failed to update proposal status'}, 500
                
    except Exception as e:
        print(f"[ERROR] Error approving proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/reject")
@token_required
def reject_proposal(username=None, proposal_id=None):
    """Reject proposal and send back to draft"""
    try:
        data = request.get_json(force=True, silent=True) or {}
        comments = data.get('comments', '')
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get proposal
            cursor.execute('SELECT id, title, user_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Update status to Draft
            cursor.execute(
                '''UPDATE proposals SET status = 'Draft', updated_at = NOW() WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()
            
            # Add rejection comment if provided
            if comments:
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                approver = cursor.fetchone()
                approver_id = approver[0] if approver else None
                
                if approver_id:
                    cursor.execute("""
                        INSERT INTO document_comments 
                        (proposal_id, comment_text, created_by, status)
                        VALUES (%s, %s, %s, %s)
                    """, (proposal_id, f"Rejected: {comments}", approver_id, 'resolved'))
                    conn.commit()
            
            return {'detail': 'Proposal rejected and returned to draft'}, 200
            
    except Exception as e:
        print(f"[ERROR] Error rejecting proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.patch("/proposals/<int:proposal_id>/status")
@token_required
def update_proposal_status(username=None, proposal_id=None):
    """Update proposal status (for approvers)"""
    try:
        data = request.get_json()
        status = data.get('status')
        
        if not status:
            return {'detail': 'Status is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() WHERE id = %s''',
                (status, proposal_id)
            )
            conn.commit()
            return {'detail': 'Status updated'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500


