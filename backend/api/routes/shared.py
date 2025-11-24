"""
Shared utility routes - Notifications, mentions, user search, DocuSign, etc.
"""
from flask import Blueprint, request, jsonify
import os
import traceback
import difflib
import base64
import psycopg2.extras
from datetime import datetime

from api.utils.database import get_db_connection
from api.utils.decorators import token_required
from api.utils.helpers import log_activity, generate_proposal_pdf, create_docusign_envelope, notify_proposal_collaborators

bp = Blueprint('shared', __name__)

# Import DocuSign availability
DOCUSIGN_AVAILABLE = False
try:
    from docusign_esign import ApiClient, EnvelopesApi
    DOCUSIGN_AVAILABLE = True
except ImportError:
    pass


@bp.get("/users/search")
def search_users_for_mentions():
    """Search proposal collaborators for @mention functionality."""
    try:
        query = request.args.get('q', '').strip()
        proposal_id = request.args.get('proposal_id', type=int)
        
        if not query or len(query) < 2:
            return {'users': []}, 200
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Search users by username, email, or full name
            cursor.execute("""
                SELECT DISTINCT u.id, u.username, u.email, u.full_name
                FROM users u
                WHERE (
                    u.username ILIKE %s OR
                    u.email ILIKE %s OR
                    u.full_name ILIKE %s
                )
                AND u.is_active = true
                LIMIT 10
            """, (f'%{query}%', f'%{query}%', f'%{query}%'))
            
            users = cursor.fetchall()
            
            # If proposal_id provided, also include collaborators
            if proposal_id:
                cursor.execute("""
                    SELECT DISTINCT u.id, u.username, u.email, u.full_name
                    FROM collaboration_invitations ci
                    JOIN users u ON ci.invited_email = u.email
                    WHERE ci.proposal_id = %s
                    AND (u.username ILIKE %s OR u.email ILIKE %s OR u.full_name ILIKE %s)
                    LIMIT 5
                """, (proposal_id, f'%{query}%', f'%{query}%', f'%{query}%'))
                
                collaborators = cursor.fetchall()
                # Merge and deduplicate
                existing_ids = {u['id'] for u in users}
                for collab in collaborators:
                    if collab['id'] not in existing_ids:
                        users.append(collab)
            
            return {
                'users': [dict(u) for u in users[:10]]
            }, 200
            
    except Exception as e:
        print(f"❌ Error searching users: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/api/notifications")
@token_required
def get_notifications(username=None):
    """Get all notifications for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user['id']
            
            # Get notifications
            # Handle case where user_id might be VARCHAR in some databases
            cursor.execute("""
                SELECT id, proposal_id, notification_type, title, message, 
                       metadata, is_read, created_at, read_at
                FROM notifications
                WHERE user_id::text = %s::text
                ORDER BY created_at DESC
                LIMIT 50
            """, (str(user_id),))
            
            notifications = cursor.fetchall()
            
            return {
                'notifications': [dict(n) for n in notifications]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting notifications: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/notifications/<int:notification_id>/mark-read")
@token_required
def mark_notification_read(username=None, notification_id=None):
    """Mark a notification as read"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user[0]
            
            # Update notification
            cursor.execute("""
                UPDATE notifications
                SET is_read = TRUE, read_at = NOW()
                WHERE id = %s AND user_id = %s
            """, (notification_id, user_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return {'detail': 'Notification not found'}, 404
            
            return {'message': 'Notification marked as read'}, 200
            
    except Exception as e:
        print(f"❌ Error marking notification as read: {e}")
        return {'detail': str(e)}, 500


@bp.post("/api/notifications/mark-all-read")
@token_required
def mark_all_notifications_read(username=None):
    """Mark all notifications as read for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user[0]
            
            # Update all notifications
            cursor.execute("""
                UPDATE notifications
                SET is_read = TRUE, read_at = NOW()
                WHERE user_id = %s AND is_read = FALSE
            """, (user_id,))
            
            conn.commit()
            
            return {'message': f'{cursor.rowcount} notifications marked as read'}, 200
            
    except Exception as e:
        print(f"❌ Error marking all notifications as read: {e}")
        return {'detail': str(e)}, 500


@bp.get("/api/mentions")
@token_required
def get_user_mentions(username=None):
    """Get all mentions for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user['id']
            
            # Get mentions
            cursor.execute("""
                SELECT cm.id, cm.comment_id, cm.created_at, cm.is_read,
                       dc.proposal_id, dc.comment_text,
                       u.full_name as mentioned_by_name, u.email as mentioned_by_email
                FROM comment_mentions cm
                JOIN document_comments dc ON cm.comment_id = dc.id
                JOIN users u ON cm.mentioned_by_user_id = u.id
                WHERE cm.mentioned_user_id = %s
                ORDER BY cm.created_at DESC
                LIMIT 50
            """, (user_id,))
            
            mentions = cursor.fetchall()
            
            return {
                'mentions': [dict(m) for m in mentions]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting mentions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/mentions/<int:mention_id>/mark-read")
@token_required
def mark_mention_read(username=None, mention_id=None):
    """Mark a mention as read"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user[0]
            
            # Update mention
            cursor.execute("""
                UPDATE comment_mentions
                SET is_read = TRUE
                WHERE id = %s AND mentioned_user_id = %s
            """, (mention_id, user_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return {'detail': 'Mention not found'}, 404
            
            return {'message': 'Mention marked as read'}, 200
            
    except Exception as e:
        print(f"❌ Error marking mention as read: {e}")
        return {'detail': str(e)}, 500


@bp.get("/api/proposals/<proposal_id>/activity")
@token_required
def get_activity_timeline(username=None, proposal_id=None):
    """Get activity timeline for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT al.id, al.action_type, al.action_description, al.metadata,
                       al.created_at, u.full_name as user_name, u.email as user_email
                FROM activity_log al
                LEFT JOIN users u ON al.user_id = u.id
                WHERE al.proposal_id = %s
                ORDER BY al.created_at DESC
                LIMIT 100
            """, (proposal_id,))
            
            activities = cursor.fetchall()
            
            return {
                'activities': [dict(a) for a in activities]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting activity timeline: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/api/proposals/<proposal_id>/versions/compare")
@token_required
def compare_proposal_versions(username=None, proposal_id=None):
    """Compare two versions of a proposal"""
    try:
        version1 = request.args.get('v1', type=int)
        version2 = request.args.get('v2', type=int)
        
        if not version1 or not version2:
            return {'detail': 'Both v1 and v2 parameters are required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get both versions
            cursor.execute("""
                SELECT id, version_number, content, created_at, created_by,
                       u.full_name as created_by_name
                FROM proposal_versions pv
                LEFT JOIN users u ON pv.created_by = u.id
                WHERE proposal_id = %s AND version_number IN (%s, %s)
                ORDER BY version_number
            """, (proposal_id, version1, version2))
            
            versions = cursor.fetchall()
            
            if len(versions) != 2:
                return {'detail': 'One or both versions not found'}, 404
            
            # Parse JSON content
            import json
            v1_content = json.loads(versions[0]['content']) if isinstance(versions[0]['content'], str) else versions[0]['content']
            v2_content = json.loads(versions[1]['content']) if isinstance(versions[1]['content'], str) else versions[1]['content']
            
            # Convert to text for comparison
            v1_text = json.dumps(v1_content, indent=2, sort_keys=True)
            v2_text = json.dumps(v2_content, indent=2, sort_keys=True)
            
            # Generate diff
            diff = difflib.unified_diff(
                v1_text.splitlines(keepends=True),
                v2_text.splitlines(keepends=True),
                fromfile=f'Version {version1}',
                tofile=f'Version {version2}',
                lineterm=''
            )
            
            # Generate HTML diff
            html_diff = difflib.HtmlDiff()
            html_diff_output = html_diff.make_table(
                v1_text.splitlines(),
                v2_text.splitlines(),
                fromdesc=f'Version {version1} ({versions[0]["created_at"]})',
                todesc=f'Version {version2} ({versions[1]["created_at"]})',
                context=True,
                numlines=3
            )
            
            # Calculate statistics
            changes = {'additions': 0, 'deletions': 0, 'modifications': 0}
            for line in difflib.unified_diff(v1_text.splitlines(), v2_text.splitlines(), lineterm=''):
                if line.startswith('+') and not line.startswith('+++'):
                    changes['additions'] += 1
                elif line.startswith('-') and not line.startswith('---'):
                    changes['deletions'] += 1
            
            return {
                'version1': {
                    'version_number': versions[0]['version_number'],
                    'created_at': versions[0]['created_at'].isoformat() if versions[0]['created_at'] else None,
                    'created_by': versions[0]['created_by_name']
                },
                'version2': {
                    'version_number': versions[1]['version_number'],
                    'created_at': versions[1]['created_at'].isoformat() if versions[1]['created_at'] else None,
                    'created_by': versions[1]['created_by_name']
                },
                'diff': '\n'.join(diff),
                'html_diff': html_diff_output,
                'changes': changes
            }, 200
            
    except Exception as e:
        print(f"❌ Error comparing versions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/proposals/<proposal_id>/docusign/send")
@token_required
def send_for_signature(username=None, proposal_id=None):
    """Send proposal for DocuSign signature"""
    try:
        if not DOCUSIGN_AVAILABLE:
            return {'detail': 'DocuSign integration not available'}, 503
        
        data = request.get_json()
        signer_name = data.get('signer_name')
        signer_email = data.get('signer_email')
        signer_title = data.get('signer_title', '')
        return_url = data.get('return_url', 'http://localhost:8081')
        
        if not signer_name or not signer_email:
            return {'detail': 'Signer name and email are required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Ensure the current user owns the proposal via owner_id
            cursor.execute("""
                SELECT id, title, content, client_name, client_email 
                FROM proposals 
                WHERE id = %s AND owner_id = %s
            """, (proposal_id, current_user['id']))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Generate PDF
            pdf_content = generate_proposal_pdf(
                proposal_id=proposal_id,
                title=proposal['title'],
                content=proposal.get('content', ''),
                client_name=proposal.get('client_name'),
                client_email=proposal.get('client_email')
            )
            
            # Create DocuSign envelope
            envelope_result = create_docusign_envelope(
                proposal_id=proposal_id,
                pdf_bytes=pdf_content,
                signer_name=signer_name,
                signer_email=signer_email,
                signer_title=signer_title,
                return_url=return_url
            )
            
            # Store signature record
            cursor.execute("""
                INSERT INTO proposal_signatures 
                (proposal_id, envelope_id, signer_name, signer_email, signer_title, 
                 signing_url, status, created_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, sent_at
            """, (proposal_id, envelope_result['envelope_id'], signer_name, signer_email, 
                  signer_title, envelope_result['signing_url'], 'sent', current_user['id']))
            
            signature_record = cursor.fetchone()
            conn.commit()
            
            log_activity(
                proposal_id,
                current_user['id'],
                'signature_requested',
                f"Proposal sent to {signer_name} for signature",
                {'envelope_id': envelope_result['envelope_id'], 'signer_email': signer_email}
            )
            
            cursor.execute("""
                UPDATE proposals 
                SET status = 'Sent for Signature', updated_at = NOW()
                WHERE id = %s
            """, (proposal_id,))
            conn.commit()
            
            return {
                'envelope_id': envelope_result['envelope_id'],
                'signing_url': envelope_result['signing_url'],
                'signature_id': signature_record['id'],
                'sent_at': signature_record['sent_at'].isoformat() if signature_record['sent_at'] else None,
                'message': 'Envelope created successfully'
            }, 200
            
    except Exception as e:
        print(f"❌ Error sending for signature: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/api/proposals/<proposal_id>/signatures")
@token_required
def get_proposal_signatures(username=None, proposal_id=None):
    """Get all signatures for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            cursor.execute("""
                SELECT id, envelope_id, signer_name, signer_email, signer_title,
                       status, signing_url, sent_at, signed_at, declined_at, decline_reason
                FROM proposal_signatures
                WHERE proposal_id = %s
                ORDER BY sent_at DESC
            """, (proposal_id,))
            
            signatures = cursor.fetchall()
            
            return {
                'signatures': [dict(s) for s in signatures]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting signatures: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/proposals/<proposal_id>/suggestions")
@token_required
def create_suggestion(username=None, proposal_id=None):
    """Create a suggested change (for reviewers with suggest permission)"""
    try:
        data = request.get_json()
        section_id = data.get('section_id')
        suggestion_text = data.get('suggestion_text')
        original_text = data.get('original_text', '')
        
        if not suggestion_text:
            return {'detail': 'Suggestion text is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute('SELECT id, email, full_name FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            cursor.execute("""
                SELECT ci.permission_level
                FROM collaboration_invitations ci
                WHERE ci.proposal_id = %s 
                AND ci.invited_email = %s
                AND ci.status = 'accepted'
            """, (proposal_id, current_user['email']))
            
            invitation = cursor.fetchone()
            # Allow all collaborators to suggest changes (no permission restrictions)
            if not invitation:
                return {'detail': 'Collaboration invitation not found'}, 403
            # Removed permission check - all collaborators can suggest changes
            # if not invitation or invitation['permission_level'] not in ['suggest', 'edit']:
            #     return {'detail': 'Insufficient permissions'}, 403
            
            cursor.execute("""
                INSERT INTO suggested_changes 
                (proposal_id, section_id, suggested_by, suggestion_text, original_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, created_at
            """, (proposal_id, section_id, current_user['id'], suggestion_text, original_text, 'pending'))
            
            result = cursor.fetchone()
            conn.commit()
            
            log_activity(
                proposal_id,
                current_user['id'],
                'suggestion_created',
                f"{current_user.get('full_name', current_user['email'])} suggested a change{' to ' + section_id if section_id else ''}",
                {'suggestion_id': result['id'], 'section_id': section_id}
            )
            
            notify_proposal_collaborators(
                proposal_id,
                'suggestion_created',
                'New Suggestion',
                f"{current_user.get('full_name', current_user['email'])} suggested a change{' to ' + section_id if section_id else ''}",
                exclude_user_id=current_user['id'],
                metadata={'suggestion_id': result['id'], 'section_id': section_id}
            )
            
            return {
                'id': result['id'],
                'created_at': result['created_at'].isoformat() if result['created_at'] else None,
                'message': 'Suggestion created successfully'
            }, 201
            
    except Exception as e:
        print(f"❌ Error creating suggestion: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/api/proposals/<proposal_id>/suggestions")
@token_required
def get_suggestions(username=None, proposal_id=None):
    """Get all suggestions for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT sc.*, 
                       u.full_name as suggested_by_name,
                       u.email as suggested_by_email,
                       r.full_name as resolved_by_name
                FROM suggested_changes sc
                LEFT JOIN users u ON sc.suggested_by = u.id
                LEFT JOIN users r ON sc.resolved_by = r.id
                WHERE sc.proposal_id = %s
                ORDER BY sc.created_at DESC
            """, (proposal_id,))
            
            suggestions = cursor.fetchall()
            
            return {
                'suggestions': [dict(s) for s in suggestions]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting suggestions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/proposals/<proposal_id>/suggestions/<int:suggestion_id>/resolve")
@token_required
def resolve_suggestion(username=None, proposal_id=None, suggestion_id=None):
    """Accept or reject a suggestion (proposal owner only)"""
    try:
        data = request.get_json()
        action = data.get('action')  # 'accept' or 'reject'
        
        if action not in ['accept', 'reject']:
            return {'detail': 'Action must be accept or reject'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute('SELECT id, email, full_name FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            cursor.execute("""
                SELECT owner_id FROM proposals WHERE id = %s
            """, (proposal_id,))
            
            proposal = cursor.fetchone()
            if not proposal or proposal['owner_id'] != current_user['id']:
                return {'detail': 'Only proposal owner can resolve suggestions'}, 403
            
            cursor.execute("""
                UPDATE suggested_changes
                SET status = %s,
                    resolved_at = NOW(),
                    resolved_by = %s,
                    resolution_action = %s
                WHERE id = %s AND proposal_id = %s
                RETURNING id
            """, ('accepted' if action == 'accept' else 'rejected', 
                  current_user['id'], action, suggestion_id, proposal_id))
            
            result = cursor.fetchone()
            if not result:
                return {'detail': 'Suggestion not found'}, 404
            
            conn.commit()
            
            log_activity(
                proposal_id,
                current_user['id'],
                f'suggestion_{action}ed',
                f"{current_user.get('full_name', current_user['email'])} {action}ed a suggestion",
                {'suggestion_id': suggestion_id, 'action': action}
            )
            
            return {'message': f'Suggestion {action}ed successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error resolving suggestion: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/proposals/<proposal_id>/sections/<section_id>/lock")
@token_required
def lock_section(username=None, proposal_id=None, section_id=None):
    """Lock a section for editing"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            user_id = current_user['id']
            
            # Check if already locked
            cursor.execute("""
                SELECT locked_by FROM section_locks
                WHERE proposal_id = %s AND section_id = %s
                AND (expires_at IS NULL OR expires_at > NOW())
            """, (proposal_id, section_id))
            
            existing_lock = cursor.fetchone()
            if existing_lock:
                if existing_lock['locked_by'] == user_id:
                    return {'message': 'Section already locked by you'}, 200
                else:
                    return {'detail': 'Section is locked by another user'}, 409
            
            # Create lock (expires in 1 hour)
            from datetime import timedelta
            expires_at = datetime.now() + timedelta(hours=1)
            
            cursor.execute("""
                INSERT INTO section_locks (proposal_id, section_id, locked_by, expires_at)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (proposal_id, section_id) 
                DO UPDATE SET locked_by = %s, locked_at = NOW(), expires_at = %s
                RETURNING id, locked_at
            """, (proposal_id, section_id, user_id, expires_at, user_id, expires_at))
            
            result = cursor.fetchone()
            conn.commit()
            
            return {
                'message': 'Section locked successfully',
                'locked_at': result['locked_at'].isoformat() if result['locked_at'] else None,
                'expires_at': expires_at.isoformat()
            }, 200
            
    except Exception as e:
        print(f"❌ Error locking section: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/proposals/<proposal_id>/sections/<section_id>/unlock")
@token_required
def unlock_section(username=None, proposal_id=None, section_id=None):
    """Unlock a section"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            user_id = current_user[0]
            
            # Delete lock (only if locked by current user or if user owns proposal)
            cursor.execute("""
                DELETE FROM section_locks
                WHERE proposal_id = %s AND section_id = %s
                AND (locked_by = %s OR EXISTS (
                    SELECT 1 FROM proposals WHERE id = %s AND owner_id = %s
                ))
            """, (proposal_id, section_id, user_id, proposal_id, user_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return {'detail': 'Section not locked or you do not have permission to unlock it'}, 404
            
            return {'message': 'Section unlocked successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error unlocking section: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/api/proposals/<proposal_id>/sections/locks")
@token_required
def get_section_locks(username=None, proposal_id=None):
    """Get all section locks for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT sl.section_id, sl.locked_by, sl.locked_at, sl.expires_at,
                       u.full_name as locked_by_name, u.email as locked_by_email
                FROM section_locks sl
                LEFT JOIN users u ON sl.locked_by = u.id
                WHERE sl.proposal_id = %s
                AND (sl.expires_at IS NULL OR sl.expires_at > NOW())
            """, (proposal_id,))
            
            locks = cursor.fetchall()
            
            return {
                'locks': [dict(l) for l in locks]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting section locks: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/docusign/webhook")
def docusign_webhook():
    """Handle DocuSign webhook events"""
    try:
        data = request.get_json()
        event = data.get('event')
        envelope_id = data.get('envelope_id')
        
        if not event or not envelope_id:
            return {'detail': 'Missing event or envelope_id'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            if event == 'envelope-completed':
                cursor.execute("""
                    UPDATE proposal_signatures 
                    SET status = 'signed',
                        signed_at = NOW()
                    WHERE envelope_id = %s
                    RETURNING proposal_id
                """, (envelope_id,))
                
                signature = cursor.fetchone()
                if signature:
                    cursor.execute("""
                        UPDATE proposals 
                        SET status = 'Signed', updated_at = NOW()
                        WHERE id = %s
                    """, (signature['proposal_id'],))
                    
                    log_activity(
                        signature['proposal_id'],
                        None,
                        'signature_completed',
                        f"Proposal signed via DocuSign (envelope: {envelope_id})",
                        {'envelope_id': envelope_id}
                    )
            
            elif event == 'envelope-declined':
                decline_reason = data.get('decline_reason', 'No reason provided')
                cursor.execute("""
                    UPDATE proposal_signatures 
                    SET status = 'declined',
                        declined_at = NOW(),
                        decline_reason = %s
                    WHERE envelope_id = %s
                    RETURNING proposal_id
                """, (decline_reason, envelope_id))
                
                signature = cursor.fetchone()
                if signature:
                    log_activity(
                        signature['proposal_id'],
                        None,
                        'signature_declined',
                        f"Signature declined: {decline_reason}",
                        {'envelope_id': envelope_id}
                    )
            
            elif event == 'envelope-voided':
                cursor.execute("""
                    UPDATE proposal_signatures 
                    SET status = 'voided'
                    WHERE envelope_id = %s
                """, (envelope_id,))
            
            conn.commit()
        
        return {'message': 'Webhook processed successfully'}, 200
        
    except Exception as e:
        print(f"❌ Error processing DocuSign webhook: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

