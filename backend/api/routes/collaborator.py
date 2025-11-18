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
from api.utils.decorators import token_required
from api.utils.email import send_email, get_logo_html

bp = Blueprint('collaborator', __name__)

@bp.get("/api/collaborate")
def get_collaboration_access():
    """Get proposal access for collaborator using token"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT ci.*, p.title, p.content, p.status as proposal_status
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid or expired token'}, 404
            
            # Generate auth token for collaborator (all collaborators get full access)
            guest_email = invitation['invited_email']
            jwt_secret = os.getenv('JWT_SECRET', 'your-secret-key')
            
            # Create auth token for collaborator
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
                    'status': invitation['proposal_status']
                },
                'permission_level': invitation['permission_level'],
                'invited_email': invitation['invited_email'],
                'auth_token': auth_token,
                # All collaborators get full edit and comment access
                'can_edit': True,
                'can_comment': True,
                'can_suggest': True
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
            
            # Allow all permission levels to comment (no restrictions)
            proposal_id = invitation['proposal_id']
            invited_email = invitation['invited_email']
            
            # Get or create user for guest
            cursor.execute('SELECT id FROM users WHERE email = %s', (invited_email,))
            user = cursor.fetchone()
            if user:
                user_id = user['id']
            else:
                # Create guest user
                cursor.execute("""
                    INSERT INTO users (username, email, full_name, role, is_active)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id
                """, (invited_email, invited_email, f'Guest ({invited_email})', 'collaborator', True))
                user_id = cursor.fetchone()['id']
            
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

@bp.post("/api/comments/document/<int:proposal_id>")
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

@bp.get("/api/comments/document/<int:proposal_id>")
@token_required
def get_document_comments(username=None, proposal_id=None):
    """Get all comments for a document"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT dc.id, dc.comment_text, dc.created_at, dc.created_by,
                       dc.section_index, dc.highlighted_text, dc.status,
                       u.full_name as author_name, u.email as author_email, u.username as author_username
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                WHERE dc.proposal_id = %s
                ORDER BY dc.created_at DESC
            """, (proposal_id,))
            
            comments = cursor.fetchall()
            
            return {
                'comments': [dict(c) for c in comments]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting document comments: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500
