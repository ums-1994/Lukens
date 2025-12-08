"""
Collaborator routes - Invitations, guest access, comments
"""
from flask import Blueprint, request, jsonify
import os
import traceback
import secrets
import jwt
import psycopg2.extras
from datetime import datetime, timedelta

from api.utils.database import get_db_connection
from api.utils.email import send_email
from api.utils.decorators import token_required
from api.utils.email import send_email, get_logo_html

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
    """Get proposal access for collaborator using token"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token and load proposal basic data (explicit columns for clarity)
            cursor.execute("""
                SELECT 
                    ci.id,
                    ci.proposal_id,
                    ci.invited_email,
                    ci.permission_level,
                    ci.expires_at,
                    ci.status,
                    ci.invited_by,
                    ci.invited_at,
                    ci.accessed_at,
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
                return {'detail': 'Invalid or expired token'}, 404
            
            # Check expiration
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Mark invitation as accessed/accepted
            cursor.execute("""
                UPDATE collaboration_invitations 
                SET accessed_at = CURRENT_TIMESTAMP, status = 'active'
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

            # Load existing comments for this proposal (for guest and client viewers)
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

            # Compute simple permission flag used by guest_collaboration_page.dart
            can_comment = invitation['permission_level'] in ['comment', 'edit', 'suggest']

            # Also ensure collaborators table and JWT auth token are updated for full editor access
            cursor.execute("""
                INSERT INTO collaborators 
                (proposal_id, email, invited_by, permission_level, status, last_accessed_at)
                VALUES (%s, %s, %s, %s, 'active', CURRENT_TIMESTAMP)
                ON CONFLICT (proposal_id, email) 
                DO UPDATE SET 
                    last_accessed_at = CURRENT_TIMESTAMP,
                    status = 'active'
            """, (
                invitation['proposal_id'],
                invitation['invited_email'],
                invitation['invited_by'],
                invitation['permission_level']
            ))

            guest_email = invitation['invited_email']
            jwt_secret = os.getenv('JWT_SECRET', 'your-secret-key')
            auth_token = jwt.encode({
                'username': guest_email,
                'email': guest_email,
                'role': 'collaborator',
                'exp': datetime.utcnow() + timedelta(days=30)
            }, jwt_secret, algorithm='HS256')
            response = {
                'proposal': {
                    'id': invitation['proposal_id'],
                    'title': invitation['title'],
                    'content': invitation['content'],
                    'status': invitation['proposal_status'],
                    'owner_name': owner_name,
                    'owner_email': owner_email,
                },
                'permission_level': invitation['permission_level'],
                'invited_email': invitation['invited_email'],
                'comments': comments,
                # Compatibility with both guest and full-editor collaboration flows
                'can_comment': can_comment,
                'auth_token': auth_token,
                'can_edit': True,
                'can_suggest': True,
            }
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
        
        if not token or not comment_text:
            return {'detail': 'Token and comment text required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation
            cursor.execute("""
                SELECT ci.*, p.id as proposal_id
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid token'}, 404
            
            # Allow only comment-capable permission levels to add comments
            proposal_id = invitation['proposal_id']
            invited_email = invitation['invited_email']

            if invitation['permission_level'] not in ['comment', 'edit', 'suggest']:
                return {'detail': 'Permission denied'}, 403

            # Get or create user for guest, using email as key and keeping account active
            cursor.execute('SELECT id FROM users WHERE email = %s', (invited_email,))
            user = cursor.fetchone()
            if user:
                user_id = user['id'] if isinstance(user, dict) else user[0]
            else:
                cursor.execute("""
                    INSERT INTO users (username, email, password_hash, full_name, role, is_active)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
<<<<<<< HEAD
                """, (invited_email, invited_email, f'Guest ({invited_email})', 'collaborator', True))
                row = cursor.fetchone()
                user_id = row['id'] if isinstance(row, dict) else row[0]
=======
                """, (invited_email, invited_email, '', f'Guest ({invited_email})', 'collaborator', True))
                user_id = cursor.fetchone()['id']
>>>>>>> origin/Cleaned_Code
            
            # Add comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, status)
                VALUES (%s, %s, %s, %s)
                RETURNING id, proposal_id, comment_text, created_by, created_at, status
            """, (proposal_id, comment_text, user_id, 'open'))
            
            result = cursor.fetchone()
            conn.commit()
            
            return dict(result), 201
            
    except Exception as e:
        print(f"❌ Error adding guest comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/comments/document/<proposal_id>")
@token_required
def create_comment(username=None, proposal_id=None):
    """Create a new comment on a document with support for threading and block-level comments"""
    try:
        data = request.get_json()
        comment_text = data.get('comment_text')
        section_index = data.get('section_index')
        section_name = data.get('section_name')
        highlighted_text = data.get('highlighted_text')
        parent_id = data.get('parent_id')  # For threaded replies
        block_type = data.get('block_type')  # 'text', 'table', 'image'
        block_id = data.get('block_id')  # Identifier for the block
        
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
            
            # Validate parent_id if provided (must exist and belong to same proposal)
            if parent_id:
                cursor.execute("""
                    SELECT id, proposal_id FROM document_comments 
                    WHERE id = %s AND proposal_id = %s
                """, (parent_id, proposal_id))
                parent_comment = cursor.fetchone()
                if not parent_comment:
                    return {'detail': 'Parent comment not found'}, 404
            
            # Create comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, section_name, 
                 highlighted_text, parent_id, block_type, block_id, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, proposal_id, comment_text, created_by, created_at, 
                          section_index, section_name, highlighted_text, parent_id,
                          block_type, block_id, status, updated_at
            """, (proposal_id, comment_text, user_id, section_index, section_name, 
                  highlighted_text, parent_id, block_type, block_id, 'open'))
            
            result = cursor.fetchone()
            comment_id = result['id']
            conn.commit()
            
            # Process @mentions in comment text
            try:
                from app import process_mentions
                process_mentions(comment_id, comment_text, user_id, proposal_id)
            except Exception as e:
                print(f"⚠️ Error processing mentions: {e}")
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id, 
                    user_id, 
                    'comment_added',
                    f'Added a comment{(" on " + section_name) if section_name else ""}',
                    {'comment_id': comment_id, 'parent_id': parent_id}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return dict(result), 201
            
    except Exception as e:
        print(f"❌ Error creating comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/comments/document/<int:proposal_id>")
@token_required
def get_document_comments(username=None, proposal_id=None):
    """Get all comments for a document with threaded structure"""
    try:
        section_id = request.args.get('section_id', type=int)
        block_id = request.args.get('block_id')
        block_type = request.args.get('block_type')
        status_filter = request.args.get('status')  # 'open', 'resolved', or None for all
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Build WHERE clause
            where_clauses = ['dc.proposal_id = %s']
            params = [proposal_id]
            
            if section_id is not None:
                where_clauses.append('dc.section_index = %s')
                params.append(section_id)
            
            if block_id:
                where_clauses.append('dc.block_id = %s')
                params.append(block_id)
                if block_type:
                    where_clauses.append('dc.block_type = %s')
                    params.append(block_type)
            
            if status_filter:
                where_clauses.append('dc.status = %s')
                params.append(status_filter)
            
            where_sql = ' AND '.join(where_clauses)
            
            cursor.execute(f"""
                SELECT dc.id, dc.comment_text, dc.created_at, dc.created_by,
                       dc.section_index, dc.section_name, dc.highlighted_text, dc.status,
                       dc.parent_id, dc.block_type, dc.block_id,
                       dc.resolved_by, dc.resolved_at, dc.updated_at,
                       u.full_name as author_name, u.email as author_email, u.username as author_username,
                       ru.full_name as resolver_name
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                LEFT JOIN users ru ON dc.resolved_by = ru.id
                WHERE {where_sql}
                ORDER BY dc.created_at ASC
            """, tuple(params))
            
            comments = cursor.fetchall()
            
            # Build threaded structure (parent comments with nested replies)
            comments_dict = {}
            root_comments = []
            
            for comment in comments:
                comment_dict = dict(comment)
                comment_dict['replies'] = []
                comments_dict[comment['id']] = comment_dict
                
                if comment['parent_id']:
                    # This is a reply - add to parent's replies
                    if comment['parent_id'] in comments_dict:
                        comments_dict[comment['parent_id']]['replies'].append(comment_dict)
                else:
                    # This is a root comment
                    root_comments.append(comment_dict)
            
            # Sort root comments by created_at DESC (newest first)
            root_comments.sort(key=lambda x: x['created_at'], reverse=True)
            
            return {
                'comments': root_comments,
                'total': len(comments),
                'open_count': sum(1 for c in comments if c['status'] == 'open'),
                'resolved_count': sum(1 for c in comments if c['status'] == 'resolved')
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting document comments: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/comments/proposal/<proposal_id>")
@token_required
def get_comments(username=None, proposal_id=None):
    """Get all comments for a proposal (creator/editor view)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Verify proposal exists and is owned by the current user
            cursor.execute(
                'SELECT id, owner_id FROM proposals WHERE id = %s',
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404

            # Fetch comments with author details
            cursor.execute(
                """
                SELECT dc.id,
                       dc.proposal_id,
                       dc.comment_text,
                       dc.created_by,
                       dc.created_at,
                       dc.section_index,
                       dc.highlighted_text,
                       dc.status,
                       u.full_name AS created_by_name,
                       u.email AS created_by_email
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                WHERE dc.proposal_id = %s
                ORDER BY dc.created_at DESC
                """,
                (proposal_id,),
            )

            comments = cursor.fetchall()
            return [dict(row) for row in comments], 200

    except Exception as e:
        print(f"❌ Error getting comments: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.patch("/api/comments/<int:comment_id>/resolve")
@token_required
def resolve_comment(username=None, comment_id=None):
    """Mark a comment and all its replies as resolved"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute('SELECT id, full_name FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user['id']
            
            # Get comment and check permissions
            cursor.execute("""
                SELECT id, proposal_id, status, parent_id
                FROM document_comments 
                WHERE id = %s
            """, (comment_id,))
            
            comment = cursor.fetchone()
            if not comment:
                return {'detail': 'Comment not found'}, 404
            
            if comment['status'] == 'resolved':
                return {'detail': 'Comment is already resolved'}, 400
            
            proposal_id = comment['proposal_id']
            
            # Resolve comment and all its replies recursively
            def resolve_comment_and_replies(cid):
                # Mark this comment as resolved
                cursor.execute("""
                    UPDATE document_comments
                    SET status = 'resolved', resolved_by = %s, resolved_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (user_id, cid))
                
                # Get all replies to this comment
                cursor.execute("""
                    SELECT id FROM document_comments
                    WHERE parent_id = %s AND status = 'open'
                """, (cid,))
                
                replies = cursor.fetchall()
                for reply in replies:
                    resolve_comment_and_replies(reply['id'])
            
            resolve_comment_and_replies(comment_id)
            conn.commit()
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id,
                    user_id,
                    'comment_resolved',
                    f'Resolved comment #{comment_id}',
                    {'comment_id': comment_id}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return {'message': 'Comment resolved successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error resolving comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.patch("/api/comments/<int:comment_id>/reopen")
@token_required
def reopen_comment(username=None, comment_id=None):
    """Reopen a resolved comment"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user['id']
            
            # Get comment
            cursor.execute("""
                SELECT id, proposal_id, status
                FROM document_comments 
                WHERE id = %s
            """, (comment_id,))
            
            comment = cursor.fetchone()
            if not comment:
                return {'detail': 'Comment not found'}, 404
            
            if comment['status'] != 'resolved':
                return {'detail': 'Comment is not resolved'}, 400
            
            proposal_id = comment['proposal_id']
            
            # Reopen comment (does not reopen replies - they stay resolved)
            cursor.execute("""
                UPDATE document_comments
                SET status = 'open', resolved_by = NULL, resolved_at = NULL, updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (comment_id,))
            
            conn.commit()
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id,
                    user_id,
                    'comment_reopened',
                    f'Reopened comment #{comment_id}',
                    {'comment_id': comment_id}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return {'message': 'Comment reopened successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error reopening comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/users/search")
@token_required
def search_users(username=None):
    """Search users for @mention autocomplete"""
    try:
        query = request.args.get('q', '').strip()
        limit = request.args.get('limit', 10, type=int)
        
        if not query or len(query) < 2:
            return {'users': []}, 200
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Search users by username, email, or full_name
            search_pattern = f'%{query}%'
            cursor.execute("""
                SELECT id, username, email, full_name
                FROM users
                WHERE is_active = true 
                  AND (
                    username ILIKE %s 
                    OR email ILIKE %s 
                    OR full_name ILIKE %s
                  )
                ORDER BY 
                  CASE 
                    WHEN username ILIKE %s THEN 1
                    WHEN full_name ILIKE %s THEN 2
                    ELSE 3
                  END,
                  username
                LIMIT %s
            """, (search_pattern, search_pattern, search_pattern, f'{query}%', f'{query}%', limit))
            
            users = cursor.fetchall()
            
            return {
                'users': [
                    {
                        'id': u['id'],
                        'username': u['username'],
                        'email': u['email'],
                        'full_name': u['full_name'] or u['username'],
                        'display_name': u['full_name'] or u['username']
                    }
                    for u in users
                ]
            }, 200
            
    except Exception as e:
        print(f"❌ Error searching users: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500
