"""
Collaborator role routes - Inviting collaborators, commenting, viewing proposals
"""
from flask import Blueprint, request, jsonify
import os
import traceback
import secrets
import psycopg2.extras
from datetime import datetime, timedelta

from api.utils.database import get_db_connection
from api.utils.email import send_email
from api.utils.decorators import token_required

bp = Blueprint('collaborator', __name__)

# ============================================================================
# COLLABORATION ROUTES
# ============================================================================

# Explicit CORS preflight handler for invite endpoint (no auth required)
@bp.route("/api/proposals/<proposal_id>/invite", methods=["OPTIONS"])
def invite_collaborator_options(proposal_id=None):
    return "", 200

@bp.post("/api/proposals/<proposal_id>/invite")
@token_required
def invite_collaborator(username=None, proposal_id=None):
    """Invite a collaborator to view and comment on a proposal"""
    try:
        data = request.get_json()
        invited_email = data.get('email')
        permission_level = data.get('permission_level', 'comment')  # 'view' or 'comment'
        
        if not invited_email:
            return {'detail': 'Email is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute('SELECT id, email FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user[0]
            inviter_email = user[1]
            
            # Check if proposal exists and belongs to user (owner_id matches current user id)
            cursor.execute(
                'SELECT title FROM proposals WHERE id = %s AND owner_id = %s',
                (proposal_id, user_id)
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            proposal_title = proposal[0]
            
            # Generate unique access token
            access_token = secrets.token_urlsafe(32)
            
            # Set expiration (30 days from now)
            expires_at = datetime.now() + timedelta(days=30)
            
            # Create invitation
            cursor.execute("""
                INSERT INTO collaboration_invitations 
                (proposal_id, invited_email, invited_by, access_token, permission_level, expires_at)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (proposal_id, invited_email, user_id, access_token, permission_level, expires_at))
            
            invitation_id = cursor.fetchone()[0]
            conn.commit()
            
            # Send invitation email (simplified - you can enhance this)
            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
            collaboration_url = f"{frontend_url}/#/collaborate?token={access_token}"
            
            # Note: send_email would need to be imported from app.py or utils
            # For now, we'll just return the URL
            
            email_sent = False
            try:
                subject = f"You've been invited to collaborate on '{proposal_title}'"
                html_content = (
                    f"<p>You have been invited to collaborate on the proposal "
                    f"'<strong>{proposal_title}</strong>'.</p>"
                    f"<p>Open it here: <a href=\"{collaboration_url}\">{collaboration_url}</a></p>"
                )
                email_sent = send_email(invited_email, subject, html_content)
                print(f"[INVITE] Collaborator email sent: {email_sent}")
            except Exception as email_error:
                print(f"[WARN] Failed to send collaborator invitation email: {email_error}")
                email_sent = False
            
            return {
                'id': invitation_id,
                'message': 'Invitation sent successfully',
                'collaboration_url': collaboration_url,
                'expires_at': expires_at.isoformat(),
                'email_sent': email_sent
            }, 201
            
    except Exception as e:
        print(f"❌ Error inviting collaborator: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.route("/api/proposals/<proposal_id>/collaborators", methods=["OPTIONS"])
def get_collaborators_options(proposal_id=None):
    return "", 200

@bp.get("/api/proposals/<proposal_id>/collaborators")
@token_required
def get_collaborators(username=None, proposal_id=None):
    """Get all collaborators for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify proposal exists (ownership is already enforced on invite)
            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Get collaborators
            cursor.execute("""
                SELECT 
                    ci.id,
                    ci.invited_email,
                    ci.permission_level,
                    ci.status,
                    ci.invited_at,
                    ci.accessed_at,
                    ci.expires_at,
                    u.full_name as invited_by_name
                FROM collaboration_invitations ci
                LEFT JOIN users u ON ci.invited_by = u.id
                WHERE ci.proposal_id = %s
                ORDER BY ci.invited_at DESC
            """, (proposal_id,))
            
            collaborators = cursor.fetchall()
            
            return [dict(row) for row in collaborators], 200
            
    except Exception as e:
        print(f"❌ Error getting collaborators: {e}")
        return {'detail': str(e)}, 500

@bp.delete("/api/collaborations/<int:invitation_id>")
@token_required
def remove_collaborator(username=None, invitation_id=None):
    """Remove a collaborator invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user[0]
            
            # Check if user owns the proposal
            cursor.execute("""
                SELECT ci.id 
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.id = %s AND (ci.invited_by = %s OR p.owner_id = %s)
            """, (invitation_id, user_id, user_id))
            
            if not cursor.fetchone():
                return {'detail': 'Invitation not found or access denied'}, 404
            
            # Delete invitation
            cursor.execute('DELETE FROM collaboration_invitations WHERE id = %s', (invitation_id,))
            conn.commit()
            
            return {'message': 'Collaborator removed successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error removing collaborator: {e}")
        return {'detail': str(e)}, 500

@bp.get("/api/collaborate")
def get_collaboration_access():
    """Get proposal access via collaboration token (no auth required)"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token and load proposal basic data
            cursor.execute("""
                SELECT 
                    ci.id,
                    ci.proposal_id,
                    ci.invited_email,
                    ci.permission_level,
                    ci.expires_at,
                    ci.status,
                    p.title,
                    p.content,
                    p.status as proposal_status,
                    p.owner_id
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            # Check expiration
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Mark invitation as accessed/accepted
            cursor.execute("""
                UPDATE collaboration_invitations 
                SET accessed_at = NOW(), status = 'accepted'
                WHERE id = %s
            """, (invitation['id'],))
            
            # Load owner details (for "Shared by" text)
            owner_name = None
            owner_email = None
            if invitation.get('owner_id'):
                cursor.execute(
                    'SELECT full_name, email FROM users WHERE id = %s',
                    (invitation['owner_id'],),
                )
                owner = cursor.fetchone()
                if owner:
                    owner_name = owner.get('full_name')
                    owner_email = owner.get('email')

            # Load existing comments for this proposal
            cursor.execute("""
                SELECT dc.id,
                       dc.proposal_id,
                       dc.comment_text,
                       dc.created_at,
                       dc.section_index,
                       dc.highlighted_text,
                       dc.status,
                       u.full_name AS created_by_name,
                       u.email AS created_by_email
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                WHERE dc.proposal_id = %s
                ORDER BY dc.created_at ASC
            """, (invitation['proposal_id'],))
            comments = [dict(row) for row in cursor.fetchall()]

            # Compute simple permission flag used by frontend
            can_comment = invitation['permission_level'] in ['comment', 'edit', 'suggest']

            # Shape response for guest_collaboration_page.dart while keeping
            # existing top-level fields for backward compatibility.
            response = {
                'proposal_id': invitation['proposal_id'],
                'title': invitation['title'],
                'content': invitation['content'],
                'proposal_status': invitation['proposal_status'],
                'permission_level': invitation['permission_level'],
                'invited_email': invitation['invited_email'],
                'can_comment': can_comment,
                'proposal': {
                    'id': invitation['proposal_id'],
                    'title': invitation['title'],
                    'content': invitation['content'],
                    'owner_name': owner_name,
                    'owner_email': owner_email,
                },
                'comments': comments,
            }

            conn.commit()
            return response, 200
            
    except Exception as e:
        print(f"❌ Error getting collaboration access: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/collaborate/comment")
def add_guest_comment():
    """Add a comment as a guest collaborator (no auth required)"""
    try:
        data = request.get_json()
        token = data.get('token')
        comment_text = data.get('comment_text')
        section_index = data.get('section_index')
        highlighted_text = data.get('highlighted_text')
        
        if not token or not comment_text:
            return {'detail': 'Token and comment text are required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token and get permission
            cursor.execute("""
                SELECT ci.proposal_id, ci.invited_email, ci.permission_level, ci.expires_at
                FROM collaboration_invitations ci
                WHERE ci.access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            if invitation['permission_level'] not in ['comment', 'edit', 'suggest']:
                return {'detail': 'Permission denied'}, 403
            
            # Create or get guest user
            guest_email = invitation['invited_email']
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (guest_email, guest_email, '', f'Guest ({guest_email})', 'collaborator'))
            
            guest_user_id = cursor.fetchone()['id']
            
            # Add comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, created_at
            """, (invitation['proposal_id'], comment_text, guest_user_id, 
                  section_index, highlighted_text, 'open'))
            
            result = cursor.fetchone()
            conn.commit()
            
            return {
                'id': result['id'],
                'message': 'Comment added successfully',
                'created_at': result['created_at'].isoformat() if result['created_at'] else None
            }, 201
            
    except Exception as e:
        print(f"❌ Error adding guest comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/comments/document/<proposal_id>")
@token_required
def create_comment(username=None, proposal_id=None):
    """Create a new comment on a document"""
    try:
        data = request.get_json()
        comment_text = data.get('comment_text')
        section_index = data.get('section_index')
        highlighted_text = data.get('highlighted_text')
        
        if not comment_text:
            return {'detail': 'Comment text is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute('SELECT id, email, full_name FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user['id']
            
            cursor.execute('SELECT title FROM proposals WHERE id = %s', (proposal_id,))
            proposal_row = cursor.fetchone()
            proposal_title = proposal_row['title'] if proposal_row else f"Proposal {proposal_id}"
            
            # Create comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, proposal_id, comment_text, created_by, created_at, 
                          section_index, highlighted_text, status, updated_at
            """, (proposal_id, comment_text, user_id, section_index, highlighted_text, 'open'))
            
            result = cursor.fetchone()
            conn.commit()
            
            return dict(result), 201
            
    except Exception as e:
        print(f"❌ Error creating comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500




