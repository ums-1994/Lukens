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
import xml.etree.ElementTree as ET
import sys

from api.utils.database import get_db_connection
from api.utils.decorators import token_required
from api.utils.helpers import (
    log_activity,
    generate_proposal_pdf,
    create_docusign_envelope,
    notify_proposal_collaborators,
    get_docusign_envelope_status,
)

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
                WHERE (id = %s OR id::text = %s) AND owner_id = %s
            """, (proposal_id, str(proposal_id), current_user['id']))
            
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
                WHERE id = %s OR id::text = %s
            """, (proposal_id, str(proposal_id)))
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


@bp.post("/api/proposals/<proposal_id>/docusign/refresh-status")
@token_required
def refresh_docusign_status(username=None, proposal_id=None):
    """Refresh DocuSign envelope status for a proposal and update local records."""
    try:
        if not DOCUSIGN_AVAILABLE:
            return {'detail': 'DocuSign integration not available'}, 503

        # Load current user, proposal, and latest signature record
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404

            cursor.execute("""
                SELECT id, owner_id, status
                FROM proposals
                WHERE id = %s OR id::text = %s
            """, (proposal_id, str(proposal_id)))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            if proposal['owner_id'] != current_user['id']:
                return {'detail': 'Access denied'}, 403

            cursor.execute("""
                SELECT id, envelope_id, status, signing_url, sent_at, signed_at, declined_at, decline_reason
                FROM proposal_signatures
                WHERE proposal_id = %s
                ORDER BY sent_at DESC
                LIMIT 1
            """, (proposal_id,))
            signature = cursor.fetchone()

        if not signature or not signature.get('envelope_id'):
            return {'detail': 'No DocuSign envelope found for this proposal'}, 404

        envelope_id = signature['envelope_id']
        local_status = (signature.get('status') or '').lower()

        # If already in a terminal state, nothing to update
        if local_status in ['signed', 'declined', 'voided']:
            return {
                'envelope_id': envelope_id,
                'envelope_status': local_status,
                'signature_status': signature.get('status'),
                'proposal_status': proposal['status'],
            }, 200

        # Ask DocuSign for the latest envelope status
        status_info = get_docusign_envelope_status(envelope_id)
        envelope_status = (status_info.get('status') or '').lower()

        if not envelope_status:
            return {
                'envelope_id': envelope_id,
                'envelope_status': None,
                'signature_status': signature.get('status'),
                'proposal_status': proposal['status'],
            }, 200

        new_sig_status = None
        new_proposal_status = None
        set_signed_at = False
        set_declined_at = False

        if envelope_status == 'completed':
            new_sig_status = 'signed'
            new_proposal_status = 'Signed'
            set_signed_at = True
        elif envelope_status == 'declined':
            new_sig_status = 'declined'
            set_declined_at = True
        elif envelope_status == 'voided':
            new_sig_status = 'voided'

        # If nothing changed, return current info
        if not new_sig_status or new_sig_status == signature.get('status'):
            return {
                'envelope_id': envelope_id,
                'envelope_status': envelope_status,
                'signature_status': signature.get('status'),
                'proposal_status': proposal['status'],
            }, 200

        # Persist updates
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            if set_signed_at:
                cursor.execute("""
                    UPDATE proposal_signatures
                    SET status = %s,
                        signed_at = NOW()
                    WHERE id = %s
                """, (new_sig_status, signature['id']))
            elif set_declined_at:
                cursor.execute("""
                    UPDATE proposal_signatures
                    SET status = %s,
                        declined_at = NOW()
                    WHERE id = %s
                """, (new_sig_status, signature['id']))
            else:
                cursor.execute("""
                    UPDATE proposal_signatures
                    SET status = %s
                    WHERE id = %s
                """, (new_sig_status, signature['id']))

            if new_proposal_status:
                cursor.execute("""
                    UPDATE proposals
                    SET status = %s,
                        updated_at = NOW()
                    WHERE id = %s OR id::text = %s
                """, (new_proposal_status, proposal_id, str(proposal_id)))

            conn.commit()

            if envelope_status == 'completed':
                log_activity(
                    proposal_id,
                    current_user['id'],
                    'signature_completed',
                    f"Proposal signed via DocuSign (envelope: {envelope_id})",
                    {'envelope_id': envelope_id},
                )

        return {
            'envelope_id': envelope_id,
            'envelope_status': envelope_status,
            'signature_status': new_sig_status,
            'proposal_status': new_proposal_status or proposal['status'],
        }, 200

    except Exception as e:
        print(f"❌ Error refreshing DocuSign status: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/api/proposals/<int:proposal_id>/signed-document")
@token_required
def get_signed_document(username=None, proposal_id=None):
    """Get the signed document PDF from DocuSign for a signed proposal"""
    try:
        if not DOCUSIGN_AVAILABLE:
            return {'detail': 'DocuSign SDK not installed'}, 503

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404

            cursor.execute(
                """
                SELECT id, owner_id
                FROM proposals
                WHERE id = %s OR id::text = %s
                """,
                (proposal_id, str(proposal_id)),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            if proposal['owner_id'] != current_user['id']:
                return {'detail': 'Access denied'}, 403

            # Get the signed signature record (check for 'signed' status or any completed status)
            cursor.execute(
                """
                SELECT envelope_id, status, signed_at
                FROM proposal_signatures
                WHERE proposal_id = %s AND (status = 'signed' OR status = 'completed')
                ORDER BY signed_at DESC, sent_at DESC
                LIMIT 1
                """,
                (proposal_id,),
            )
            signature = cursor.fetchone()
            if not signature:
                # Check if there are any signatures at all
                cursor.execute(
                    """
                    SELECT envelope_id, status, signed_at
                    FROM proposal_signatures
                    WHERE proposal_id = %s
                    ORDER BY sent_at DESC
                    LIMIT 1
                    """,
                    (proposal_id,),
                )
                any_signature = cursor.fetchone()
                if any_signature:
                    return {
                        'detail': f'Proposal has signature record but status is "{any_signature.get("status")}", not "signed". Envelope ID: {any_signature.get("envelope_id")}'
                    }, 400
                return {'detail': 'No signature record found for this proposal'}, 404

            envelope_id = signature.get('envelope_id')
            if not envelope_id:
                return {'detail': 'No envelope ID found for this signed proposal'}, 404

        # Ensure envelope_id is a string and strip whitespace
        envelope_id = str(envelope_id).strip()
        if not envelope_id or envelope_id.lower() == 'none':
            return {'detail': 'Invalid envelope ID format'}, 400

        print(f"📄 Retrieving signed document for proposal {proposal_id}")
        print(f"📄 Envelope ID: {envelope_id}")
        print(f"📄 Signature status: {signature.get('status')}")
        print(f"📄 Signed at: {signature.get('signed_at')}")

        # Get DocuSign access token
        from api.utils.docusign_utils import get_docusign_jwt_token
        from docusign_esign.client.api_exception import ApiException

        access_token = get_docusign_jwt_token()
        account_id = os.getenv('DOCUSIGN_ACCOUNT_ID')
        base_path = os.getenv('DOCUSIGN_BASE_PATH') or os.getenv('DOCUSIGN_BASE_URL', 'https://demo.docusign.net/restapi')

        print(f"📄 Account ID: {account_id}")
        print(f"📄 Base path: {base_path}")

        api_client = ApiClient()
        api_client.host = base_path
        api_client.set_default_header("Authorization", f"Bearer {access_token}")

        print(f"📄 API Client host: {api_client.host}")

        envelopes_api = EnvelopesApi(api_client)

        try:
            envelope_info = envelopes_api.get_envelope(account_id, envelope_id)
            print(f"✅ Envelope found: {envelope_info.envelope_id}, Status: {envelope_info.status}")
        except ApiException as e:
            print(f"❌ Error getting envelope info: {e}")
            print(f"   Error body: {e.body if hasattr(e, 'body') else 'N/A'}")
            return {'detail': f'DocuSign envelope not found or invalid: {str(e)}'}, 404

        try:
            docs_list = envelopes_api.list_documents(account_id, envelope_id)
            document_id = None

            if hasattr(docs_list, 'envelope_documents') and docs_list.envelope_documents:
                for doc in docs_list.envelope_documents:
                    doc_id = str(doc.document_id) if hasattr(doc, 'document_id') else None
                    if doc_id and doc_id != 'certificate':
                        document_id = doc_id
                        doc_name = getattr(doc, 'name', 'N/A')
                        print(f"📄 Using document ID: {document_id} (name: {doc_name})")
                        break

                if not document_id and docs_list.envelope_documents:
                    first_doc = docs_list.envelope_documents[0]
                    document_id = str(first_doc.document_id) if hasattr(first_doc, 'document_id') else None
                    print(f"📄 Using first available document ID: {document_id}")

            if not document_id:
                print("📄 No document ID found in list, defaulting to '1'")
                document_id = '1'

            print(f"📄 Retrieving document with ID: {document_id} (type: {type(document_id)})")
            print(f"📄 Account ID: {account_id}, Envelope ID: {envelope_id}")

            try:
                import requests
                use_requests = True
            except ImportError:
                use_requests = False
                print("📄 requests library not available, using SDK method only")

            if use_requests:
                doc_url = f"{base_path}/v2.1/accounts/{account_id}/envelopes/{envelope_id}/documents/{document_id}"
                print(f"📄 Document URL: {doc_url}")

                headers = {
                    "Authorization": f"Bearer {access_token}",
                    "Accept": "application/pdf"
                }

                response = requests.get(doc_url, headers=headers)
                if response.status_code == 200:
                    document_pdf = response.content
                    print(f"✅ Document retrieved successfully via REST API, size: {len(document_pdf)} bytes")
                else:
                    print(f"❌ REST API error: {response.status_code}")
                    print(f"   Response: {response.text[:500]}")
                    raise Exception(f"REST API returned {response.status_code}: {response.text[:200]}")
            else:
                document_pdf = envelopes_api.get_document(
                    account_id,
                    envelope_id,
                    str(document_id)
                )
                print(f"✅ Document retrieved successfully via SDK, size: {len(document_pdf) if document_pdf else 0} bytes")

        except ApiException as e:
            print(f"❌ Error getting document: {e}")
            print(f"   Error body: {e.body if hasattr(e, 'body') else 'N/A'}")
            try:
                docs = envelopes_api.list_documents(account_id, envelope_id)
                doc_ids = [doc.document_id for doc in docs.envelope_documents] if hasattr(docs, 'envelope_documents') else []
                print(f"   Available documents: {doc_ids}")
            except Exception:
                pass
            return {'detail': f'Error retrieving document from DocuSign: {str(e)}'}, 500

        from flask import Response
        return Response(
            document_pdf,
            mimetype='application/pdf',
            headers={
                'Content-Disposition': f'inline; filename="signed_proposal_{proposal_id}.pdf"',
                'Content-Type': 'application/pdf',
            }
        ), 200

    except Exception as e:
        print(f"❌ Error getting signed document: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/proposals/<int:proposal_id>/suggestions")
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
    """Handle DocuSign Connect webhook events (supports both XML and JSON formats)"""
    try:
        # Log the raw request for debugging
        content_type = request.content_type or ''
        raw_data = request.get_data(as_text=True)
        print(f"📥 DocuSign webhook received - Content-Type: {content_type}")
        print(f"📥 Raw data (first 500 chars): {raw_data[:500]}")
        
        envelope_id = None
        status = None
        event = None
        decline_reason = None
        data = {}
        
        # Handle XML format (DocuSign Connect default)
        if 'xml' in content_type.lower() or raw_data.strip().startswith('<?xml') or raw_data.strip().startswith('<'):
            try:
                root = ET.fromstring(raw_data)
                # DocuSign Connect XML structure
                envelope_status = root.find('.//EnvelopeStatus')
                if envelope_status is not None:
                    envelope_id_elem = envelope_status.find('EnvelopeID')
                    if envelope_id_elem is not None:
                        envelope_id = envelope_id_elem.text
                    
                    status_elem = envelope_status.find('Status')
                    if status_elem is not None:
                        status = status_elem.text.lower()
                    
                    # Map DocuSign status to our event names
                    if status == 'completed':
                        event = 'envelope-completed'
                    elif status == 'declined':
                        event = 'envelope-declined'
                        # Get decline reason if declined
                        decline_reason_elem = envelope_status.find('DeclinedReason')
                        if decline_reason_elem is not None:
                            decline_reason = decline_reason_elem.text
                    elif status == 'voided':
                        event = 'envelope-voided'
            except ET.ParseError as e:
                print(f"⚠️ Failed to parse XML: {e}")
                return {'detail': 'Invalid XML format'}, 400
        
        # Handle JSON format
        else:
            try:
                data = request.get_json(force=True) if raw_data else {}
                
                # Try different JSON structures that DocuSign might use
                if 'data' in data and isinstance(data['data'], dict):
                    # DocuSign Connect JSON format
                    envelope_data = data['data']
                    envelope_id = envelope_data.get('envelopeId') or envelope_data.get('envelope_id')
                    status = envelope_data.get('status', '').lower()
                    event = data.get('event') or envelope_data.get('event')
                elif 'envelopeId' in data or 'envelope_id' in data:
                    # Direct format
                    envelope_id = data.get('envelopeId') or data.get('envelope_id')
                    status = data.get('status', '').lower()
                    event = data.get('event')
                else:
                    # Fallback to original format
                    event = data.get('event')
                    envelope_id = data.get('envelope_id')
                    status = data.get('status', '').lower()
                
                # Map status to event if event not provided
                if not event and status:
                    if status == 'completed':
                        event = 'envelope-completed'
                    elif status == 'declined':
                        event = 'envelope-declined'
                    elif status == 'voided':
                        event = 'envelope-voided'
                
                # Get decline reason from JSON if declined
                if status == 'declined' or event == 'envelope-declined':
                    decline_reason = data.get('decline_reason') or data.get('declinedReason')
            except Exception as e:
                print(f"⚠️ Failed to parse JSON: {e}")
                return {'detail': 'Invalid JSON format'}, 400
        
        # Validate we have required data
        if not envelope_id:
            print(f"⚠️ Missing envelope_id. Data received: {raw_data[:200]}")
            return {'detail': 'Missing envelope_id'}, 400
        
        if not event and not status:
            print(f"⚠️ Missing event/status. Data received: {raw_data[:200]}")
            return {'detail': 'Missing event or status'}, 400
        
        print(f"✅ Parsed webhook - Envelope: {envelope_id}, Event: {event}, Status: {status}")
        
        # Process the webhook
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            if event == 'envelope-completed' or status == 'completed':
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
                    print(f"✅ Updated proposal {signature['proposal_id']} to Signed status")
                else:
                    print(f"⚠️ No signature record found for envelope {envelope_id}")
            
            elif event == 'envelope-declined' or status == 'declined':
                # Use decline_reason parsed above, or default
                if not decline_reason:
                    decline_reason = 'No reason provided'
                
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
                    print(f"✅ Updated proposal {signature['proposal_id']} to Declined status")
            
            elif event == 'envelope-voided' or status == 'voided':
                cursor.execute("""
                    UPDATE proposal_signatures 
                    SET status = 'voided'
                    WHERE envelope_id = %s
                    RETURNING proposal_id
                """, (envelope_id,))
                
                signature = cursor.fetchone()
                if signature:
                    print(f"✅ Updated proposal signature to Voided status")
            
            conn.commit()
        
        return {'message': 'Webhook processed successfully'}, 200
        
    except Exception as e:
        print(f"❌ Error processing DocuSign webhook: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.post("/api/admin/seed-content")
@token_required
def seed_content_library(username=None):
    """Seed the content library with default content blocks (Admin only)"""
    try:
        # Check if user is admin
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user or user.get('role') != 'admin':
                return {'detail': 'Admin access required'}, 403
        
        # Import and run the seed function
        try:
            # Add backend directory to path to import seed script
            backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            if backend_dir not in sys.path:
                sys.path.insert(0, backend_dir)
            
            from seed_content_blocks import seed_content_blocks
            
            # Run the seed function
            seed_content_blocks()
            
            return {
                'message': 'Content library seeded successfully',
                'status': 'success'
            }, 200
            
        except ImportError as e:
            print(f"❌ Error importing seed script: {e}")
            return {'detail': f'Failed to import seed script: {str(e)}'}, 500
        except Exception as e:
            print(f"❌ Error seeding content: {e}")
            traceback.print_exc()
            return {'detail': f'Failed to seed content: {str(e)}'}, 500
            
    except Exception as e:
        print(f"❌ Error in seed endpoint: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

