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
from api.utils.helpers import generate_proposal_pdf, create_docusign_envelope

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
                '''SELECT id, title, content, client, '' as client_email, owner_id as user_id, status, created_at, updated_at, NULL as budget
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
                    'client': row.get('client') or 'Unknown',
                    'client_name': row.get('client') or 'Unknown',  # Map client to client_name for compatibility
                    'client_email': row.get('client_email') or '',  # Empty string since column doesn't exist
                    'owner_id': row.get('user_id'),
                    'status': row['status'],
                    'budget': None,  # Budget column doesn't exist in Render schema
                    'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                    'updated_at': row['updated_at'].isoformat() if row['updated_at'] else None,
                })
            return {'proposals': proposals}, 200
    except Exception as e:
        print(f"❌ Error fetching pending approvals: {e}")
        import traceback
        traceback.print_exc()
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
            
            # Get proposal details - try to get client_email from proposals table or collaboration_invitations
            cursor.execute(
                '''SELECT p.id, p.title, p.client, 
                          COALESCE(p.client_email, ci.invited_email, '') as client_email,
                          p.owner_id as user_id, p.content 
                   FROM proposals p
                   LEFT JOIN collaboration_invitations ci ON p.id = ci.proposal_id AND ci.status = 'pending'
                   WHERE p.id = %s
                   LIMIT 1''',
                (proposal_id,)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            title = proposal.get('title')
            client_name = proposal.get('client') or proposal.get('client_name') or 'Unknown'
            client_email = proposal.get('client_email') or ''
            
            # If still no email, try to get from collaboration_invitations directly
            if not client_email or not client_email.strip():
                cursor.execute(
                    '''SELECT invited_email FROM collaboration_invitations 
                       WHERE proposal_id = %s AND status = 'pending' 
                       ORDER BY invited_at DESC LIMIT 1''',
                    (proposal_id,)
                )
                inv_row = cursor.fetchone()
                if inv_row:
                    client_email = inv_row.get('invited_email') if isinstance(inv_row, dict) else inv_row[0] if inv_row else ''
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
                # Note: client_email might be empty since the column doesn't exist in schema
                # We'll still create the envelope if we have a client name
                if client_name and client_name != 'Unknown':
                    try:
                        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                        backend_url = os.getenv('BACKEND_URL') or os.getenv('API_URL') or os.getenv('RENDER_EXTERNAL_URL')
                        
                        # Log webhook URL configuration for debugging
                        if backend_url:
                            webhook_url = f"{backend_url.rstrip('/')}/api/docusign/webhook"
                            print(f"🔗 DocuSign Webhook URL (configure in DocuSign Connect): {webhook_url}")
                        else:
                            print(f"⚠️  WARNING: Backend URL not configured!")
                            print(f"   Set BACKEND_URL, API_URL, or RENDER_EXTERNAL_URL environment variable")
                            print(f"   Webhook URL should be: https://your-backend-url.com/api/docusign/webhook")
                            print(f"   Configure this in DocuSign: Settings → Connect → Add Configuration")
                        
                        # Generate client access token (you may need to create this in collaboration_invitations)
                        import secrets
                        access_token = secrets.token_urlsafe(32)
                        
                        # Validate client email - must be a real email address
                        if not client_email or not client_email.strip() or '@' not in client_email:
                            print(f"⚠️  WARNING: No valid client email found for proposal {proposal_id}")
                            print(f"   Client name: {client_name}")
                            print(f"   Attempted email: {client_email}")
                            print(f"   Cannot send DocuSign envelope or email without valid email address")
                            return {
                                'detail': f'Cannot send proposal: No valid client email address. Please add client email to proposal.',
                                'error': 'missing_client_email',
                                'client_name': client_name
                            }, 400
                        
                        effective_client_email = client_email.strip()
                        print(f"✅ Using client email: {effective_client_email}")
                        
                        # Store token in collaboration_invitations for client access
                        cursor.execute("""
                            INSERT INTO collaboration_invitations 
                            (proposal_id, invited_email, invited_by, permission_level, access_token, status)
                            VALUES (%s, %s, %s, %s, %s, 'pending')
                            ON CONFLICT DO NOTHING
                        """, (proposal_id, effective_client_email, approver_user_id, 'view', access_token))
                        conn.commit()

                        # Create DocuSign envelope so client link already has a signing URL
                        print(f"🔐 Attempting to create DocuSign envelope for proposal {proposal_id}...")
                        print(f"   Client: {client_name}")
                        print(f"   Email: {effective_client_email}")
                        try:
                            # Generate PDF for DocuSign
                            pdf_content = generate_proposal_pdf(
                                proposal_id=proposal_id,
                                title=title or display_title,
                                content=proposal_content or '',
                                client_name=client_name,
                                client_email=client_email,
                            )

                            # Return URL back to client proposals view with same token
                            return_url = f"{frontend_url}/#/client/proposals?token={access_token}&signed=true"

                            envelope_result = create_docusign_envelope(
                                proposal_id=proposal_id,
                                pdf_bytes=pdf_content,
                                signer_name=client_name or effective_client_email,
                                signer_email=effective_client_email,
                                signer_title='',
                                return_url=return_url,
                            )

                            signing_url = envelope_result['signing_url']
                            envelope_id = envelope_result['envelope_id']
                            envelope_status = envelope_result.get('envelope_status', {})
                            
                            print(f"✅ DocuSign envelope created successfully!")
                            print(f"   Envelope ID: {envelope_id}")
                            print(f"   Signing URL: {signing_url[:50]}...")
                            print(f"   Envelope Status: {envelope_status.get('status', 'unknown')}")
                            
                            # Verify envelope was actually created
                            if not envelope_id:
                                raise Exception("DocuSign envelope creation returned no envelope ID")
                            
                            # Check envelope status
                            if envelope_status.get('status', '').lower() != 'sent':
                                print(f"⚠️  WARNING: Envelope status is '{envelope_status.get('status')}' - email may not be sent")
                                print(f"   Please check DocuSign dashboard for envelope: {envelope_id}")

                            # Store or update signature record
                            cursor.execute(
                                """
                                SELECT id FROM proposal_signatures WHERE proposal_id = %s
                                """,
                                (proposal_id,),
                            )
                            existing_sig = cursor.fetchone()

                            if existing_sig:
                                cursor.execute(
                                    """
                                    UPDATE proposal_signatures 
                                    SET envelope_id = %s,
                                        signer_name = %s,
                                        signer_email = %s,
                                        signer_title = %s,
                                        signing_url = %s,
                                        status = %s,
                                        sent_at = NOW()
                                    WHERE proposal_id = %s
                                    """,
                                    (
                                        envelope_id,
                                        client_name or effective_client_email,
                                        effective_client_email,
                                        '',
                                        signing_url,
                                        'sent',
                                        proposal_id,
                                    ),
                                )
                            else:
                                cursor.execute(
                                    """
                                    INSERT INTO proposal_signatures 
                                    (proposal_id, envelope_id, signer_name, signer_email, signer_title, 
                                     signing_url, status, created_by)
                                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                                    """,
                                    (
                                        proposal_id,
                                        envelope_id,
                                        client_name or effective_client_email,
                                        effective_client_email,
                                        '',
                                        signing_url,
                                        'sent',
                                        approver_user_id,
                                    ),
                                )

                            # Update proposal status and client_email to reflect that it has been sent for signature
                            cursor.execute(
                                """
                                UPDATE proposals 
                                SET status = 'Sent for Signature', 
                                    client_email = %s,
                                    updated_at = NOW()
                                WHERE id = %s
                                """,
                                (effective_client_email, proposal_id,),
                            )

                            conn.commit()
                            print(f"✅ Created DocuSign envelope for proposal {proposal_id} (client: {effective_client_email})")
                        except Exception as docusign_error:
                            error_msg = str(docusign_error)
                            error_type = type(docusign_error).__name__
                            
                            print(f"❌ DocuSign error during approver approval:")
                            print(f"   Error Type: {error_type}")
                            print(f"   Error Message: {error_msg}")
                            
                            # Try to extract more details from DocuSign API exceptions
                            if hasattr(docusign_error, 'body'):
                                try:
                                    error_body = docusign_error.body
                                    if isinstance(error_body, bytes):
                                        error_body = error_body.decode('utf-8')
                                    print(f"   DocuSign API Response: {error_body}")
                                except:
                                    pass
                            
                            if hasattr(docusign_error, 'status'):
                                print(f"   HTTP Status: {docusign_error.status}")
                            
                            if hasattr(docusign_error, 'headers'):
                                print(f"   Response Headers: {docusign_error.headers}")
                            
                            # Log full traceback for debugging
                            print(f"   Full Traceback:")
                            traceback.print_exc()
                            
                            # Provide actionable error messages
                            print(f"\n🔧 Troubleshooting steps:")
                            print(f"   1. Check DocuSign credentials in environment variables:")
                            print(f"      - DOCUSIGN_INTEGRATION_KEY")
                            print(f"      - DOCUSIGN_USER_ID")
                            print(f"      - DOCUSIGN_ACCOUNT_ID")
                            print(f"      - DOCUSIGN_PRIVATE_KEY or DOCUSIGN_PRIVATE_KEY_PATH")
                            print(f"   2. Verify sender email is valid: {effective_client_email}")
                            print(f"   3. Check DocuSign dashboard for any account issues")
                            print(f"   4. Verify DocuSign API access token is valid")
                            
                            # Don't fail the approval if DocuSign fails - still send email
                            print(f"\n⚠️  Continuing with approval despite DocuSign error")
                            print(f"   Client will receive email with proposal link, but DocuSign signing may not be available")

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
                        
                        email_sent = send_email(effective_client_email, email_subject, email_body)
                        if email_sent:
                            print(f"[EMAIL] ✅ Proposal email sent successfully to {effective_client_email}")
                        else:
                            print(f"[EMAIL] ❌ Failed to send proposal email to {effective_client_email}")
                            print(f"   Please check SendGrid configuration and logs above for details")
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





