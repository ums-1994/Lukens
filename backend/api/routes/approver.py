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
from api.utils.email import send_email, get_logo_html

bp = Blueprint('approver', __name__)

# ============================================================================
# APPROVER ROUTES
# ============================================================================

@bp.route("/api/proposals/pending_approval", methods=['OPTIONS'])
@bp.route("/proposals/pending_approval", methods=['OPTIONS'])
def options_pending_approvals():
    """Handle CORS preflight for pending approvals endpoint"""
    return {}, 200

@bp.get("/api/proposals/pending_approval")
@bp.get("/proposals/pending_approval")
@token_required
def get_pending_approvals(username=None):
    """Get all proposals pending approval"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                '''SELECT id, title, content, client_name, client_email, user_id, status, created_at, updated_at, budget
                   FROM proposals 
                   WHERE status = 'Pending CEO Approval' 
                      OR status = 'In Review' 
                      OR status = 'Submitted'
                   ORDER BY updated_at DESC, created_at DESC'''
            )
            rows = cursor.fetchall()
            proposals = []
            for row in rows:
                proposals.append({
                    'id': row['id'],
                    'title': row['title'],
                    'content': row.get('content'),  # Include content field
                    'client': row['client_name'] or row.get('client') or 'Unknown',
                    'client_name': row['client_name'],
                    'client_email': row['client_email'],
                    'owner_id': row['user_id'],
                    'status': row['status'],
                    'budget': float(row['budget']) if row['budget'] else None,
                    'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                    'updated_at': row['updated_at'].isoformat() if row['updated_at'] else None,
                })
            return {'proposals': proposals}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/api/proposals/<int:proposal_id>/approve")
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
                
                # Send email to client
                email_sent = False
                if client_email and client_email.strip():
                    try:
                        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                        # Generate client access token (you may need to create this in collaboration_invitations)
                        import secrets
                        access_token = secrets.token_urlsafe(32)
                        
                        # Store token in collaboration_invitations for client access
                        cursor.execute("""
                            INSERT INTO collaboration_invitations 
                            (proposal_id, invited_email, invited_by, permission_level, access_token, status)
                            VALUES (%s, %s, %s, %s, %s, 'pending')
                            ON CONFLICT DO NOTHING
                        """, (proposal_id, client_email, approver_user_id, 'view', access_token))
                        conn.commit()
                        
                        client_link = f"{frontend_url}/client/proposals?token={access_token}"
                        
                        email_subject = f"Proposal Ready: {display_title}"
                        email_body = f"""
                        {get_logo_html()}
                        <h2>Your Proposal is Ready</h2>
                        <p>Dear {client_name or 'Client'},</p>
                        <p>We're pleased to share your proposal: <strong>{display_title}</strong></p>
                        <p>Click the link below to view and review your proposal:</p>
                        <p style="text-align: center; margin: 30px 0;">
                            <a href="{client_link}" style="background-color: #27AE60; color: white; padding: 14px 32px; text-decoration: none; border-radius: 8px; display: inline-block; font-size: 16px; font-weight: 600;">View Proposal</a>
                        </p>
                        <p>Or copy and paste this link into your browser:</p>
                        <p style="word-break: break-all; color: #666;">{client_link}</p>
                        <p>If you have any questions, please don't hesitate to reach out.</p>
                        <p>Best regards,<br>{approver_name}</p>
                        """
                        
                        email_sent = send_email(client_email, email_subject, email_body)
                        if email_sent:
                            print(f"[EMAIL] Proposal email sent to {client_email}")
                        else:
                            print(f"[EMAIL] Failed to send proposal email to {client_email}")
                    except Exception as email_error:
                        print(f"[EMAIL] Error sending proposal email: {email_error}")
                        traceback.print_exc()
                
                return {
                    'detail': 'Proposal approved and sent to client',
                    'status': new_status,
                    'email_sent': email_sent
                }, 200
            else:
                return {'detail': 'Failed to update proposal status'}, 500
                
    except Exception as e:
        print(f"[ERROR] Error approving proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/proposals/<int:proposal_id>/reject")
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





