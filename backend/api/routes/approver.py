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
from api.utils.helpers import generate_proposal_pdf, create_docusign_envelope, create_notification, log_status_change

bp = Blueprint('approver', __name__)

# ============================================================================
# APPROVER ROUTES
# ============================================================================

@bp.route("/api/proposals/pending_approval", methods=['OPTIONS'])
@bp.route("/proposals/pending_approval", methods=['OPTIONS'])
def options_pending_approvals():
    """Handle CORS preflight for pending approvals endpoint"""
    origin = request.headers.get("Origin")
    resp = jsonify({})
    if origin and (
        origin.startswith("http://localhost:")
        or origin.startswith("http://127.0.0.1:")
        or origin == "https://proposals2025.netlify.app"
    ):
        resp.headers["Access-Control-Allow-Origin"] = origin
        resp.headers["Vary"] = "Origin"
        resp.headers["Access-Control-Allow-Credentials"] = "true"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    resp.headers["Access-Control-Allow-Methods"] = "GET, HEAD, POST, OPTIONS, PUT, PATCH, DELETE"
    return resp, 200

@bp.get("/api/proposals/pending_approval")
@bp.get("/proposals/pending_approval")
@token_required
def get_pending_approvals(username=None):
    """Get all proposals pending approval"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Detect actual proposals table schema so we can support
            # environments with either client/client_name and owner_id/user_id.
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
                  AND table_schema = current_schema()
                """
            )
            cols = cursor.fetchall()
            existing_columns = [
                (c['column_name'] if isinstance(c, dict) else c[0]) for c in cols
            ]

            order_parts = []
            if 'updated_at' in existing_columns:
                order_parts.append('updated_at DESC')
            if 'created_at' in existing_columns:
                order_parts.append('created_at DESC')
            if not order_parts:
                order_parts.append('id DESC')
            order_by = ', '.join(order_parts)

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
                WHERE status IN ('Pending CEO Approval', 'In Review', 'Submitted')
                ORDER BY {order_by}
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

@bp.post("/api/proposals/<int:proposal_id>/approve")
@bp.post("/proposals/<int:proposal_id>/approve")
@token_required
def approve_proposal(username=None, proposal_id=None):
    """Approve proposal and send to client"""
    try:
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

            # Detect proposals table schema for client / owner / email columns
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

            # Block release if latest Risk Gate run is BLOCK without override.
            try:
                cursor.execute(
                    """
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_schema = 'public' AND table_name = 'risk_gate_runs'
                    """
                )
                has_risk_gate = cursor.fetchone() is not None
                if has_risk_gate:
                    cursor.execute(
                        """
                        SELECT id, status, risk_score, overridden, override_reason, created_at
                        FROM risk_gate_runs
                        WHERE proposal_id = %s
                        ORDER BY created_at DESC
                        LIMIT 1
                        """,
                        (proposal_id,),
                    )
                    rg = cursor.fetchone()
                    if rg and str(rg.get('status') or '').strip().upper() == 'BLOCK' and rg.get('overridden') is not True:
                        return {
                            'detail': 'Proposal blocked by risk gate',
                            'message': 'This proposal is blocked by Risk Gate. Resolve issues or request an override before approving/sending to client.',
                            'risk_gate': {
                                'run_id': rg.get('id'),
                                'status': rg.get('status'),
                                'risk_score': rg.get('risk_score'),
                                'overridden': False,
                                'override_reason': rg.get('override_reason'),
                                'run_created_at': rg.get('created_at').isoformat() if rg.get('created_at') else None,
                            },
                        }, 400
            except Exception as rg_err:
                print(f"[WARN] Risk Gate check failed for approver approve proposal {proposal_id}: {rg_err}")
            
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
                cursor.execute(
                    '''SELECT invited_email FROM collaboration_invitations 
                       WHERE proposal_id = %s 
                       ORDER BY invited_at DESC LIMIT 1''',
                    (proposal_id,)
                )
                inv_row = cursor.fetchone()
                if inv_row:
                    invited_email = inv_row.get('invited_email') if isinstance(inv_row, dict) else (inv_row[0] if isinstance(inv_row, (tuple, list)) and len(inv_row) > 0 else '')
                    if invited_email and '@' in invited_email:
                        client_email = invited_email.strip()

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

            cursor.execute('SELECT status FROM proposals WHERE id = %s', (proposal_id,))
            srow = cursor.fetchone()
            old_status = (
                (srow.get('status') if hasattr(srow, 'get') else (srow[0] if srow else None))
            )
            
            # Update status to Sent to Client
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() 
                   WHERE id = %s RETURNING status''',
                ('Sent to Client', proposal_id)
            )
            status_row = cursor.fetchone()

            # Record approval event (best-effort).
            try:
                cursor.execute(
                    """
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_schema = 'public' AND table_name = 'approvals'
                    """
                )
                has_approvals_table = cursor.fetchone() is not None
                if has_approvals_table:
                    cursor.execute(
                        """
                        INSERT INTO approvals (approver_name, approver_email, approved_pdf_path, proposal_id)
                        VALUES (%s, %s, NULL, %s)
                        """,
                        (
                            str(approver_name or username or 'Unknown'),
                            str((approver_user or {}).get('email') or username or 'unknown'),
                            proposal_id,
                        ),
                    )
            except Exception as approval_log_err:
                print(f"[WARN] Failed to record approval event for proposal {proposal_id}: {approval_log_err}")
            conn.commit()
            
            if status_row:
                new_status = status_row['status']
                print(f"[SUCCESS] Proposal {proposal_id} '{title}' approved and status updated")

                if old_status is not None and new_status is not None and str(old_status) != str(new_status):
                    log_status_change(proposal_id, approver_user_id, old_status, new_status)

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
                        <p style="word-break: break-all; color: #666;"><a href="{client_link}" style="color: #0066cc; text-decoration: underline;">{client_link}</a></p>
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

            cursor.execute('SELECT status FROM proposals WHERE id = %s', (proposal_id,))
            srow = cursor.fetchone()
            old_status = srow[0] if srow else None

            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            urow = cursor.fetchone()
            actor_id = urow[0] if urow else None
            
            # Update status to Draft
            cursor.execute(
                '''UPDATE proposals SET status = 'Draft', updated_at = NOW() WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()

            if old_status is not None and old_status != 'Draft':
                log_status_change(proposal_id, actor_id, old_status, 'Draft')

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

            cursor.execute('SELECT status FROM proposals WHERE id = %s', (proposal_id,))
            srow = cursor.fetchone()
            old_status = srow[0] if srow else None

            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            urow = cursor.fetchone()
            actor_id = urow[0] if urow else None

            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() WHERE id = %s''',
                (status, proposal_id)
            )
            conn.commit()

            if old_status is not None and status is not None and str(old_status) != str(status):
                log_status_change(proposal_id, actor_id, old_status, status)
            return {'detail': 'Status updated'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500





