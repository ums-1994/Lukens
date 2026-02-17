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
from api.utils.decorators import token_required, admin_required
from api.utils.database import get_db_connection
from api.utils.helpers import (
    generate_proposal_pdf,
    create_docusign_envelope,
    get_logo_html,
    create_notification,
    log_activity,
    log_proposal_audit_event,
)
from api.utils.email import send_email

bp = Blueprint('approver', __name__)

# ============================================================================
# APPROVER ROUTES
# ============================================================================

@bp.route("/proposals/pending_approval", methods=['OPTIONS'])
def options_pending_approvals():
    """Handle CORS preflight for pending approvals endpoint"""
    return {}, 200

@bp.get("/proposals/pending_approval")
@token_required
def get_pending_approvals(username=None):
    """Get all proposals pending approval"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            def _get_table_columns(table_name: str):
                cursor.execute(
                    """
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_name = %s
                    """,
                    (table_name,),
                )
                cols = cursor.fetchall() or []
                return [
                    (c['column_name'] if isinstance(c, dict) else c[0])
                    for c in cols
                ]

            def _pick_first(existing, candidates):
                for c in candidates:
                    if c in existing:
                        return c
                return None

            # Detect actual proposals table schema so we can support
            # environments with either client/client_name and owner_id/user_id.
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
                """
            )
            cols = cursor.fetchall()
            existing_columns = [
                (c['column_name'] if isinstance(c, dict) else c[0]) for c in cols
            ]

            # Build column expressions that only reference existing columns
            if 'client' in existing_columns:
                client_expr = 'client'
            elif 'client_name' in existing_columns:
                client_expr = 'client_name'
            else:
                client_expr = "NULL::text"

            if 'client_email' in existing_columns:
                client_email_expr = 'client_email'
            else:
                client_email_expr = "NULL::text"

            if 'owner_id' in existing_columns:
                owner_expr = 'owner_id'
            elif 'user_id' in existing_columns:
                owner_expr = 'user_id'
            else:
                owner_expr = "NULL::text"

            if 'budget' in existing_columns:
                budget_expr = 'budget'
            else:
                budget_expr = 'NULL::numeric'

            query = f'''
                SELECT 
                    id,
                    title,
                    content,
                    {client_expr} AS client,
                    {client_email_expr} AS client_email,
                    {owner_expr} AS user_id,
                    status,
                    created_at,
                    updated_at,
                    {budget_expr} AS budget
                FROM proposals
                WHERE LOWER(COALESCE(status, '')) IN (
                    'pending ceo approval',
                    'pending approval',
                    'in review',
                    'submitted'
                )
                ORDER BY updated_at DESC, created_at DESC
            '''

            cursor.execute(query)
            rows = cursor.fetchall()
            proposals = []
            for row in rows:
                proposals.append({
                    'id': row['id'],
                    'title': row['title'],
                    'content': row.get('content'),
                    'client': row.get('client') or 'Unknown',
                    'client_name': row.get('client') or 'Unknown',
                    'client_email': (row.get('client_email') or '') if isinstance(row, dict) else '',
                    'owner_id': row.get('user_id'),
                    'status': row['status'],
                    'budget': row.get('budget'),
                    'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                    'updated_at': row['updated_at'].isoformat() if row['updated_at'] else None,
                })
            return {'proposals': proposals}, 200
    except Exception as e:
        print(f"❌ Error fetching pending approvals: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/approve")
@token_required
def approve_proposal(username=None, proposal_id=None):
    """Approve proposal and send to client"""
    try:
        print(f"🟦 [APPROVE] approve_proposal called for proposal_id={proposal_id} by username={username}")
        data = request.get_json(force=True, silent=True) or {}
        comments = data.get('comments', '')
        # Allow client_email override to be passed explicitly from the frontend
        # (e.g., for older proposals that were created before client_email
        # was consistently stored on the proposal record).
        override_client_email = (
            data.get('client_email')
            or data.get('clientEmail')
            or ''
        )
        override_client_email = override_client_email.strip() if isinstance(override_client_email, str) else ''
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            def _get_table_columns(table_name: str):
                cursor.execute(
                    """
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_name = %s
                    """,
                    (table_name,),
                )
                cols = cursor.fetchall() or []
                return [
                    (c['column_name'] if isinstance(c, dict) else c[0])
                    for c in cols
                ]

            def _pick_first(existing, candidates):
                for c in candidates:
                    if c in existing:
                        return c
                return None

            # Detect proposals table schema for client / owner / email columns
            existing_columns = _get_table_columns('proposals')

            if 'client' in existing_columns:
                client_expr = 'p.client'
            elif 'client_name' in existing_columns:
                client_expr = 'p.client_name'
            else:
                client_expr = "NULL::text"

            if 'owner_id' in existing_columns:
                owner_expr = 'p.owner_id'
            elif 'user_id' in existing_columns:
                owner_expr = 'p.user_id'
            else:
                owner_expr = "NULL::text"

            if 'client_email' in existing_columns:
                client_email_expr = 'p.client_email'
            else:
                client_email_expr = "NULL::text"

            # Get proposal details (including client_email if available)
            query = f'''
                SELECT 
                    p.id, 
                    p.title, 
                    {client_expr} AS client,
                    {owner_expr} AS user_id,
                    p.content,
                    {client_email_expr} AS client_email
                FROM proposals p
                WHERE p.id = %s
            '''
            cursor.execute(query, (proposal_id,))
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            title = proposal.get('title')
            client_name = proposal.get('client') or proposal.get('client_name') or 'Unknown'

            # Start with client_email stored on the proposal (if schema supports it)
            client_email = (proposal.get('client_email') or '').strip()

            # If frontend explicitly provided a client email and it looks valid,
            # prefer that and persist it immediately to the proposal so future
            # approvals don't have to infer it again.
            if override_client_email and '@' in override_client_email:
                client_email = override_client_email
                try:
                    cursor.execute(
                        '''UPDATE proposals 
                           SET client_email = %s, updated_at = NOW() 
                           WHERE id = %s''',
                        (client_email, proposal_id),
                    )
                    conn.commit()
                    print(f"✅ Updated proposal {proposal_id} with override client_email from request: {client_email}")
                except Exception as email_update_err:
                    print(f"⚠️ Failed to persist override client_email for proposal {proposal_id}: {email_update_err}")

            # Fallback: Get client_email from collaboration_invitations
            if not client_email or '@' not in client_email:
                try:
                    inv_cols = _get_table_columns('collaboration_invitations')
                    inv_email_col = _pick_first(
                        inv_cols,
                        ['invited_email', 'email', 'client_email', 'invitee_email', 'collaborator_email'],
                    )
                    invited_at_col = _pick_first(
                        inv_cols,
                        ['invited_at', 'created_at', 'updated_at', 'id'],
                    )

                    if inv_email_col:
                        order_col = invited_at_col or 'id'
                        cursor.execute(
                            f"""SELECT {inv_email_col} AS invited_email
                               FROM collaboration_invitations
                               WHERE proposal_id = %s
                               ORDER BY {order_col} DESC
                               LIMIT 1""",
                            (proposal_id,),
                        )
                        inv_row = cursor.fetchone()
                        if inv_row:
                            invited_email = (
                                inv_row.get('invited_email')
                                if isinstance(inv_row, dict)
                                else (inv_row[0] if isinstance(inv_row, (tuple, list)) and len(inv_row) > 0 else '')
                            )
                            if invited_email and '@' in str(invited_email):
                                client_email = str(invited_email).strip()
                except Exception as inv_lookup_err:
                    print(f"⚠️ Failed to infer client email from collaboration_invitations: {inv_lookup_err}")

            # Fallback: Also try to get from proposal_signatures if available
            if not client_email or '@' not in client_email:
                cursor.execute(
                    '''SELECT signer_email FROM proposal_signatures 
                       WHERE proposal_id = %s 
                       ORDER BY sent_at DESC LIMIT 1''',
                    (proposal_id,)
                )
                sig_row = cursor.fetchone()
                if sig_row:
                    sig_email = sig_row.get('signer_email') if isinstance(sig_row, dict) else (sig_row[0] if isinstance(sig_row, (tuple, list)) and len(sig_row) > 0 else '')
                    if sig_email and '@' in sig_email:
                        client_email = sig_email.strip()

            # Final attempt: if we have now resolved a valid client email from any
            # source but the proposal row is still empty, backfill it so future
            # operations see a consistent value.
            if client_email and '@' in client_email and not (proposal.get('client_email') or '').strip():
                try:
                    cursor.execute(
                        '''UPDATE proposals 
                           SET client_email = %s, updated_at = NOW() 
                           WHERE id = %s''',
                        (client_email, proposal_id),
                    )
                    conn.commit()
                    print(f"✅ Backfilled client_email on proposal {proposal_id}: {client_email}")
                except Exception as backfill_err:
                    print(f"⚠️ Failed to backfill client_email on proposal {proposal_id}: {backfill_err}")
            creator = proposal.get('user_id')
            proposal_content = proposal.get('content')
            display_title = title or f"Proposal {proposal_id}"
            
            # Get approver info
            cursor.execute(
                """
                SELECT id, username, email, full_name
                FROM users
                WHERE username = %s
                """,
                (username,)
            )
            approver_user = cursor.fetchone()
            approver_user_id = approver_user['id'] if approver_user else None
            if approver_user_id is None and username and '@' in str(username):
                # DEV_BYPASS_AUTH can set username to an email in some environments.
                cursor.execute(
                    """
                    SELECT id, username, email, full_name
                    FROM users
                    WHERE email = %s
                    """,
                    (username,),
                )
                approver_user = cursor.fetchone() or approver_user
                approver_user_id = approver_user['id'] if approver_user else None
            approver_name = (
                approver_user.get('full_name')
                or approver_user.get('username')
                or username
            ) if approver_user else (username or 'Approver')
            
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

                try:
                    log_proposal_audit_event(
                        proposal_id,
                        'approved',
                        actor_user_id=approver_user_id,
                        actor_name=approver_name,
                        actor_email=(approver_user.get('email') if approver_user else None),
                        metadata={'comments': comments} if comments else None,
                    )
                except Exception:
                    pass

                # Notify proposal creator about approval
                try:
                    if creator:
                        create_notification(
                            user_id=creator,
                            notification_type='proposal_approved',
                            title='Proposal Approved',
                            message=f"Your proposal '{display_title}' for {client_name or 'Client'} has been approved by {approver_name}.",
                            proposal_id=proposal_id,
                            metadata={'approver': approver_name, 'comments': comments} if comments else {'approver': approver_name},
                        )
                except Exception as notif_err:
                    print(f"[WARN] Failed to create approval notification for proposal {proposal_id}: {notif_err}")

                # Send email to client
                email_sent = False
                # Note: client_email might be empty since the column doesn't exist in schema
                # We'll still create the envelope if we have a client name
                if client_name and client_name != 'Unknown':
                    try:
                        from api.utils.helpers import get_frontend_url
                        frontend_url = get_frontend_url()
                        print(f"🌐 Using frontend URL: {frontend_url}")
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

                            # Provide a more structured error back to the frontend so
                            # it can prompt the approver/creator to supply the email
                            # and retry, while also exposing the proposal/client info.
                            return {
                                'detail': 'Cannot send proposal: No valid client email address. Please add client email to proposal.',
                                'error': 'missing_client_email',
                                'client_name': client_name,
                                'proposal_id': proposal_id,
                                'has_override_option': True,
                            }, 400
                        
                        effective_client_email = client_email.strip()
                        print(f"✅ Using client email: {effective_client_email}")
                        
                        # Store token in collaboration_invitations for client access
                        try:
                            inv_cols = _get_table_columns('collaboration_invitations')
                            inv_email_col = _pick_first(
                                inv_cols,
                                ['invited_email', 'invitee_email', 'email', 'client_email', 'collaborator_email'],
                            )
                            invited_by_col = _pick_first(
                                inv_cols,
                                ['invited_by', 'inviter_id', 'created_by', 'user_id'],
                            )
                            permission_col = _pick_first(inv_cols, ['permission_level', 'permission', 'role'])
                            token_col = _pick_first(inv_cols, ['access_token', 'token'])
                            status_col = _pick_first(inv_cols, ['status'])
                            expires_col = _pick_first(inv_cols, ['expires_at', 'expires', 'token_expires_at'])
                            proposal_id_col = 'proposal_id' if 'proposal_id' in inv_cols else None

                            insert_cols = []
                            insert_vals = []
                            if proposal_id_col:
                                insert_cols.append(proposal_id_col)
                                insert_vals.append(proposal_id)
                            if inv_email_col:
                                insert_cols.append(inv_email_col)
                                insert_vals.append(effective_client_email)
                            if invited_by_col:
                                if approver_user_id is None:
                                    print(
                                        "⚠️ collaboration_invitations requires inviter id but approver_user_id is unknown; "
                                        "skipping invitation insert"
                                    )
                                    raise RuntimeError("missing_approver_user_id_for_invitation")
                                insert_cols.append(invited_by_col)
                                insert_vals.append(approver_user_id)
                            if permission_col:
                                insert_cols.append(permission_col)
                                insert_vals.append('view')
                            if token_col:
                                insert_cols.append(token_col)
                                insert_vals.append(access_token)
                            if status_col:
                                insert_cols.append(status_col)
                                insert_vals.append('pending')
                            if expires_col:
                                insert_cols.append(expires_col)
                                insert_vals.append(datetime.utcnow() + timedelta(days=90))

                            if proposal_id_col and inv_email_col and insert_cols:
                                placeholders = ', '.join(['%s'] * len(insert_cols))
                                cols_sql = ', '.join(insert_cols)
                                cursor.execute(
                                    f"""INSERT INTO collaboration_invitations ({cols_sql})
                                       VALUES ({placeholders})
                                       ON CONFLICT DO NOTHING""",
                                    tuple(insert_vals),
                                )
                                conn.commit()
                            else:
                                print(
                                    "⚠️ collaboration_invitations schema missing required columns; "
                                    "skipping invitation insert"
                                )
                        except Exception as inv_insert_err:
                            # Do not fail the overall approval due to invitation schema mismatches.
                            print(f"⚠️ Failed to insert collaboration invitation: {inv_insert_err}")
                            traceback.print_exc()

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

                            # Return URL back to client view using the collaboration router
                            return_url = f"{frontend_url}/#/collaborate?token={access_token}&signed=true"

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

                        client_link = f"{frontend_url}/#/collaborate?token={access_token}"

                        sendgrid_configured = bool(
                            (os.getenv('SENDGRID_API_KEY') or '').strip()
                            and (os.getenv('SENDGRID_FROM_EMAIL') or '').strip()
                        )
                        smtp_configured = bool(
                            (os.getenv('SMTP_HOST') or '').strip()
                            and (os.getenv('SMTP_USER') or '').strip()
                            and (os.getenv('SMTP_PASS') or '')
                        )
                        print(
                            "📧 [EMAIL] Attempting proposal email send "
                            f"(SendGrid={'yes' if sendgrid_configured else 'no'}, "
                            f"SMTP={'yes' if smtp_configured else 'no'}) "
                            f"to={effective_client_email}"
                        )

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
                        <p style="word-break: break-all; color: #666;"><a href="{client_link}" style="color: #0066cc; text-decoration: underline;">{client_link}</a></p>
                        <p>If you have any questions, please don't hesitate to reach out.</p>
                        <p>Best regards,<br>{approver_name}</p>
                        """
                        
                        email_sent = send_email(effective_client_email, email_subject, email_body)
                        if email_sent:
                            print(f"[EMAIL] ✅ Proposal email sent successfully to {effective_client_email}")
                        else:
                            print(f"[EMAIL] ❌ Failed to send proposal email to {effective_client_email}")
                            print(f"   Check SENDGRID_* or SMTP_* env vars and logs above for details")
                            return {
                                'detail': 'Proposal approved but email failed to send (secure link not delivered). Fix email configuration and retry.',
                                'error': 'email_send_failed',
                                'proposal_id': proposal_id,
                                'client_email': effective_client_email,
                            }, 502
                    except Exception as email_error:
                        print(f"[EMAIL] Error sending proposal email: {email_error}")
                        traceback.print_exc()
                        return {
                            'detail': 'Proposal approved but email failed to send due to server error. Check email configuration and retry.',
                            'error': 'email_send_exception',
                            'proposal_id': proposal_id,
                            'client_email': effective_client_email,
                        }, 502
                
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

@bp.post("/proposals/<int:proposal_id>/reject")
@token_required
def reject_proposal(username=None, proposal_id=None):
    """Reject proposal and send back to creator"""
    try:
        data = request.get_json()
        comments = data.get('comments', '')
        
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Determine ownership column (owner_id vs user_id)
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
                """
            )
            existing_columns = [row[0] for row in cursor.fetchall()]

            owner_col = None
            if 'owner_id' in existing_columns:
                owner_col = 'owner_id'
            elif 'user_id' in existing_columns:
                owner_col = 'user_id'

            if not owner_col:
                print("⚠️ No owner_id or user_id column found in proposals table when rejecting")
                return {
                    'detail': 'Proposals table is missing owner column; cannot determine creator for rejection.'
                }, 500

            # Get proposal (use resolved owner column as the creator/owner)
            cursor.execute(
                f'SELECT id, title, {owner_col} FROM proposals WHERE id = %s',
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404

            proposal_id_db, title, creator_user_id = proposal
            
            # Update status to Draft
            cursor.execute(
                '''UPDATE proposals SET status = 'Draft', updated_at = NOW() WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()

            try:
                cursor.execute(
                    "SELECT id, username, email, full_name FROM users WHERE username = %s",
                    (username,),
                )
                approver_user = cursor.fetchone()
                approver_user_id = approver_user['id'] if approver_user else None
                approver_name = (
                    approver_user.get('full_name')
                    or approver_user.get('username')
                    or username
                ) if approver_user else (username or 'Approver')
                log_proposal_audit_event(
                    proposal_id,
                    'rejected',
                    actor_user_id=approver_user_id,
                    actor_name=approver_name,
                    actor_email=(approver_user.get('email') if approver_user else None),
                    metadata={'comments': comments} if comments else None,
                )
            except Exception:
                pass

            # Notify proposal creator about rejection
            try:
                if creator_user_id:
                    rejection_message = f"Your proposal '{title}' was rejected by {username}."
                    if comments:
                        rejection_message += f" Comments: {comments}"

                    create_notification(
                        user_id=creator_user_id,
                        notification_type='proposal_rejected',
                        title='Proposal Rejected',
                        message=rejection_message,
                        proposal_id=proposal_id,
                        metadata={'comments': comments} if comments else None,
                    )
            except Exception as notif_err:
                print(f"[WARN] Failed to create rejection notification for proposal {proposal_id}: {notif_err}")

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





