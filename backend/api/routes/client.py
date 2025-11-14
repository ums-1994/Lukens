"""
Client role routes - Viewing proposals, commenting, approving/rejecting, signing
"""
from flask import Blueprint, request, jsonify
import os
import traceback
import psycopg2.extras
from datetime import datetime

from api.utils.database import get_db_connection
from api.utils.decorators import token_required

bp = Blueprint('client', __name__)

# ============================================================================
# CLIENT PROPOSAL ROUTES (using token-based access)
# ============================================================================

@bp.get("/api/client/proposals")
def get_client_proposals():
    """Get all proposals for a client using their access token"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation details to find client email
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            # Check if expired
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            client_email = invitation['invited_email']
            
            # Get all proposals for this client email
            cursor.execute("""
                SELECT 
                    p.id, 
                    p.title, 
                    p.status, 
                    p.created_at, 
                    p.updated_at, 
                    p.client_name, 
                    p.client_email,
                    ps.signing_url,
                    ps.status AS signature_status,
                    ps.envelope_id
                FROM proposals p
                LEFT JOIN LATERAL (
                    SELECT envelope_id, signing_url, status
                    FROM proposal_signatures
                    WHERE proposal_id = p.id
                    ORDER BY sent_at DESC
                    LIMIT 1
                ) ps ON TRUE
                WHERE p.client_email = %s
                ORDER BY p.updated_at DESC
            """, (client_email,))
            
            proposals = cursor.fetchall()
            
            return {
                'client_email': client_email,
                'proposals': [dict(p) for p in proposals]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting client proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/client/proposals/<int:proposal_id>")
def get_client_proposal_details(proposal_id):
    """Get detailed proposal information for client"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token and get client email
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Get proposal details
            cursor.execute("""
                SELECT p.id, p.title, p.content, p.status, p.created_at, p.updated_at,
                       p.client_name, p.client_email, p.user_id,
                       u.full_name as owner_name, u.email as owner_email
                FROM proposals p
                LEFT JOIN users u ON p.user_id = u.username
                WHERE p.id = %s AND p.client_email = %s
            """, (proposal_id, invitation['invited_email']))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            cursor.execute("""
                SELECT envelope_id, signing_url, status, sent_at, signed_at
                FROM proposal_signatures
                WHERE proposal_id = %s
                ORDER BY sent_at DESC
                LIMIT 1
            """, (proposal_id,))
            signature = cursor.fetchone()
            
            # Get comments
            cursor.execute("""
                SELECT dc.id, dc.comment_text, dc.created_at, dc.created_by,
                       u.full_name as created_by_name, u.email as created_by_email
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                WHERE dc.proposal_id = %s
                ORDER BY dc.created_at DESC
            """, (proposal_id,))
            
            comments = cursor.fetchall()
            
            return {
                'proposal': dict(proposal),
                'signature': dict(signature) if signature else None,
                'comments': [dict(c) for c in comments]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting client proposal details: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/client/proposals/<int:proposal_id>/comment")
def add_client_comment(proposal_id):
    """Add a comment from client"""
    try:
        data = request.get_json()
        token = data.get('token')
        comment_text = data.get('comment_text')
        
        if not token or not comment_text:
            return {'detail': 'Token and comment text required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Create or get guest user
            guest_email = invitation['invited_email']
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (guest_email, guest_email, '', f'Client ({guest_email})', 'client'))
            
            guest_user_id = cursor.fetchone()['id']
            conn.commit()
            
            # Add comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, created_at
            """, (proposal_id, comment_text, guest_user_id, 
                  data.get('section_index'), data.get('highlighted_text'), 'open'))
            
            result = cursor.fetchone()
            conn.commit()
            
            return {
                'id': result['id'],
                'message': 'Comment added successfully',
                'created_at': result['created_at'].isoformat() if result['created_at'] else None
            }, 201
            
    except Exception as e:
        print(f"❌ Error adding client comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/client/proposals/<int:proposal_id>/approve")
def client_approve_proposal(proposal_id):
    """Client approves and signs proposal"""
    try:
        data = request.get_json()
        token = data.get('token')
        signer_name = data.get('signer_name')
        signer_title = data.get('signer_title', '')
        comments = data.get('comments', '')
        signature_date = data.get('signature_date')
        
        if not token or not signer_name:
            return {'detail': 'Token and signer name required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Update proposal status
            cursor.execute("""
                UPDATE proposals 
                SET status = 'Client Approved', updated_at = NOW()
                WHERE id = %s AND client_email = %s
                RETURNING id, title, client_name, user_id
            """, (proposal_id, invitation['invited_email']))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Store signature information
            signature_info = f"""
✓ APPROVED AND SIGNED
Signer: {signer_name}
{f"Title: {signer_title}" if signer_title else ""}
Date: {signature_date or datetime.now().isoformat()}
{f"Comments: {comments}" if comments else ""}
            """
            
            # Get or create client user
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (invitation['invited_email'], invitation['invited_email'], '', signer_name, 'client'))
            
            client_user_id = cursor.fetchone()['id']
            
            # Add signature as comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, status)
                VALUES (%s, %s, %s, %s)
            """, (proposal_id, signature_info, client_user_id, 'resolved'))
            
            conn.commit()
            
            print(f"✅ Proposal {proposal_id} approved by client: {signer_name}")
            
            return {
                'message': 'Proposal approved successfully',
                'proposal_id': proposal['id'],
                'status': 'Client Approved'
            }, 200
            
    except Exception as e:
        print(f"❌ Error approving proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/client/proposals/<int:proposal_id>/reject")
def client_reject_proposal(proposal_id):
    """Client rejects proposal"""
    try:
        data = request.get_json()
        token = data.get('token')
        reason = data.get('reason')
        
        if not token or not reason:
            return {'detail': 'Token and reason required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Update proposal status
            cursor.execute("""
                UPDATE proposals 
                SET status = 'Client Declined', updated_at = NOW()
                WHERE id = %s AND client_email = %s
                RETURNING id, title
            """, (proposal_id, invitation['invited_email']))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Add rejection reason as comment
            rejection_info = f"✗ REJECTED\nReason: {reason}"
            
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (invitation['invited_email'], invitation['invited_email'], '', f'Client ({invitation["invited_email"]})', 'client'))
            
            client_user_id = cursor.fetchone()['id']
            
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, status)
                VALUES (%s, %s, %s, %s)
            """, (proposal_id, rejection_info, client_user_id, 'resolved'))
            
            conn.commit()
            
            return {
                'message': 'Proposal rejected',
                'proposal_id': proposal['id'],
                'status': 'Client Declined'
            }, 200
            
    except Exception as e:
        print(f"❌ Error rejecting proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# ============================================================================
# LEGACY CLIENT ROUTES (for backward compatibility)
# ============================================================================

@bp.get("/client/proposals")
@token_required
def fetch_client_proposals(username=None):
    """Get client proposals (legacy route)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at
                   FROM proposals WHERE client_can_edit = true ORDER BY created_at DESC'''
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
            return proposals, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/client/proposals/<int:proposal_id>")
@token_required
def get_client_proposal(username=None, proposal_id=None):
    """Get a client proposal (legacy route)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at, content
                   FROM proposals WHERE id = %s AND client_can_edit = true''',
                (proposal_id,)
            )
            result = cursor.fetchone()
            
            if result:
                return {
                    'id': result[0],
                    'title': result[1],
                    'client': result[2],
                    'owner_id': result[3],
                    'status': result[4],
                    'created_at': result[5].isoformat() if result[5] else None,
                    'content': result[6]
                }, 200
            return {'detail': 'Proposal not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/client/proposals/<int:proposal_id>/sign")
@token_required
def client_sign_proposal(username=None, proposal_id=None):
    """Sign a proposal as client (legacy route)"""
    try:
        data = request.get_json()
        signer_name = data.get('signer_name')
        
        if not signer_name:
            return {'detail': 'Signer name is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''UPDATE proposals SET status = 'Client Signed' WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()
            return {'detail': 'Proposal signed by client'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/client/dashboard_stats")
@token_required
def get_client_dashboard_stats(username=None):
    """Get client dashboard statistics"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT status, COUNT(*) FROM proposals WHERE client_can_edit = true
                   GROUP BY status'''
            )
            rows = cursor.fetchall()
            stats = {row[0]: row[1] for row in rows}
            return stats, 200
    except Exception as e:
        return {'detail': str(e)}, 500



