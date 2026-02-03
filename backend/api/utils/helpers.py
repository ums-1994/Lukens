"""
Shared helper functions for the backend API
"""
import os
import json
import html
import traceback
from datetime import datetime, timedelta
import psycopg2.extras

from api.utils.database import get_db_connection
from api.utils.email import send_email

# Import PDF and DocuSign utilities if available
PDF_AVAILABLE = False
DOCUSIGN_AVAILABLE = False

try:
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
    from io import BytesIO
    PDF_AVAILABLE = True
except ImportError:
    pass

try:
    from docusign_esign import (
        ApiClient,
        EnvelopesApi,
        EnvelopeDefinition,
        Document,
        Signer,
        SignHere,
        Tabs,
        Recipients,
        RecipientViewRequest,
    )
    from docusign_esign.client.api_exception import ApiException
    import jwt
    DOCUSIGN_AVAILABLE = True
    print("✅ DocuSign SDK imported successfully")
except ImportError as e:
    DOCUSIGN_AVAILABLE = False
    print(f"⚠️ DocuSign SDK not available: {e}")
    print("   Install with: pip install docusign-esign")

def resolve_user_id(cursor, identifier):
    """
    Resolve a user identifier (username, email, or ID) to a user_id.
    """
    if not identifier:
        return None
        
    # 1. If it's an integer, verify it exists
    if isinstance(identifier, int) or (isinstance(identifier, str) and identifier.isdigit()):
        try:
            uid = int(identifier)
            cursor.execute("SELECT id FROM users WHERE id = %s", (uid,))
            if cursor.fetchone():
                return uid
        except Exception:
            pass
            
    # 2. Try by username
    cursor.execute("SELECT id FROM users WHERE username = %s", (str(identifier),))
    row = cursor.fetchone()
    if row:
        return row[0]
        
    # 3. Try by email
    cursor.execute("SELECT id FROM users WHERE email = %s", (str(identifier),))
    row = cursor.fetchone()
    if row:
        return row[0]
        
    return None


def get_frontend_url():
    """
    Get the frontend URL from environment variables with proper fallback.
    Returns production URL by default, not localhost.
    """
    import os
    frontend_url = os.getenv('FRONTEND_URL') or os.getenv('REACT_APP_API_URL') or 'https://sowbuilders.netlify.app'
    # Remove trailing slash and ensure it's the base URL (not API URL)
    frontend_url = frontend_url.rstrip('/').replace('/api', '').replace('/backend', '')
    return frontend_url


def log_activity(proposal_id, user_id, action_type, description, metadata=None):
    """
    Log an activity to the activity timeline
    
    Args:
        proposal_id: ID of the proposal
        user_id: ID of the user performing the action (can be None for system actions)
        action_type: Type of action (e.g., 'comment_added', 'suggestion_created', 'proposal_edited')
        description: Human-readable description of the action
        metadata: Optional dict with additional data
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO activity_log (proposal_id, user_id, action_type, action_description, metadata)
                VALUES (%s, %s, %s, %s, %s)
            """, (proposal_id, user_id, action_type, description, json.dumps(metadata) if metadata else None))
            conn.commit()
    except Exception as e:
        print(f"⚠️ Failed to log activity: {e}")


def log_status_change(proposal_id, user_id, from_status, to_status):
    log_activity(
        proposal_id,
        user_id,
        "status_changed",
        f"Status changed: {from_status} → {to_status}",
        {"from": from_status, "to": to_status},
    )


def create_notification(
    user_id,
    notification_type,
    title,
    message,
    proposal_id=None,
    metadata=None,
    send_email_flag=False,
    email_subject=None,
    email_body=None,
):
    """
    Create a notification for a user
    """
    try:
        recipient_info = None
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Determine which notifications table/columns exist
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name IN ('notifications', 'notificationss')
            """)
            table_rows = cursor.fetchall()
            if not table_rows:
                return

            table_names = {row['table_name'] for row in table_rows}
            table_name = 'notifications' if 'notifications' in table_names else table_rows[0]['table_name']

            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_schema = 'public' AND table_name = %s
            """, (table_name,))
            column_names = {row['column_name'] for row in cursor.fetchall()}

            metadata_json = json.dumps(metadata) if metadata else None

            columns = []
            values = []

            def add_column(col_name, value):
                columns.append(col_name)
                values.append(value)

            add_column('user_id', user_id)

            if 'notification_type' in column_names:
                add_column('notification_type', notification_type)
            if 'title' in column_names:
                add_column('title', title)
            if 'message' in column_names:
                add_column('message', message)
            if 'proposal_id' in column_names:
                add_column('proposal_id', proposal_id)
            if 'metadata' in column_names:
                add_column('metadata', metadata_json)

            placeholders = ', '.join(['%s'] * len(columns))
            columns_sql = ', '.join(columns)

            cursor.execute(
                f"INSERT INTO {table_name} ({columns_sql}) VALUES ({placeholders}) RETURNING id",
                values,
            )
            notification_row = cursor.fetchone()

            if send_email_flag:
                cursor.execute(
                    "SELECT email, full_name FROM users WHERE id = %s",
                    (user_id,)
                )
                recipient_info = cursor.fetchone()

            conn.commit()

        if send_email_flag and recipient_info and recipient_info.get('email'):
            recipient_email = recipient_info['email']
            recipient_name = recipient_info.get('full_name') or recipient_email
            subject = email_subject or title

            html_content = email_body or f"""
            <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6;">
                    <p>Hi {recipient_name},</p>
                    <p>{message}</p>
                    {f'<p><strong>Proposal ID:</strong> {proposal_id}</p>' if proposal_id else ''}
                    <p style="font-size: 12px; color: #888;">You received this notification because you are part of a proposal on ProposalHub.</p>
                </body>
            </html>
            """

            try:
                send_email(recipient_email, subject, html_content)
                print(f"📧 Notification email sent to {recipient_email}")
            except Exception as email_err:
                print(f"⚠️ Failed to send notification email to {recipient_email}: {email_err}")

    except Exception as e:
        print(f"⚠️ Failed to create notification: {e}")


def notify_proposal_collaborators(
    proposal_id,
    notification_type,
    title,
    message,
    exclude_user_id=None,
    metadata=None,
    send_email_flag=False,
    email_subject=None,
    email_body=None,
):
    """
    Notify all collaborators on a proposal
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Fetch proposal details
            cursor.execute(
                "SELECT user_id, title FROM proposals WHERE id = %s",
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return

            proposal_title = proposal.get('title') or f"Proposal #{proposal_id}"

            base_metadata = {
                'proposal_id': proposal_id,
                'proposal_title': proposal_title,
                'resource_id': proposal_id,
            }
            if isinstance(metadata, dict):
                base_metadata.update(metadata)

            def _resolve_user_row(identifier):
                if identifier is None:
                    return None
                if isinstance(identifier, int):
                    cursor.execute("SELECT id FROM users WHERE id = %s", (identifier,))
                    return cursor.fetchone()
                try:
                    numeric_id = int(identifier)
                    cursor.execute("SELECT id FROM users WHERE id = %s", (numeric_id,))
                    row = cursor.fetchone()
                    if row:
                        return row
                except (TypeError, ValueError):
                    pass
                cursor.execute("SELECT id FROM users WHERE username = %s", (identifier,))
                return cursor.fetchone()

            owner = _resolve_user_row(proposal.get('user_id'))
            if owner and owner['id'] != exclude_user_id:
                create_notification(
                    owner['id'],
                    notification_type,
                    title,
                    message,
                    proposal_id,
                    base_metadata,
                    send_email_flag=send_email_flag,
                    email_subject=email_subject,
                    email_body=email_body,
                )

            # Get accepted collaborators
            cursor.execute(
                """
                SELECT DISTINCT u.id
                FROM collaboration_invitations ci
                JOIN users u ON ci.invited_email = u.email
                WHERE ci.proposal_id = %s AND ci.status = 'accepted'
                """,
                (proposal_id,),
            )

            collaborators = cursor.fetchall()
            for collab in collaborators:
                collab_id = collab.get('id') if isinstance(collab, dict) else collab[0]
                if collab_id and collab_id != exclude_user_id:
                    create_notification(
                        collab_id,
                        notification_type,
                        title,
                        message,
                        proposal_id,
                        base_metadata,
                        send_email_flag=send_email_flag,
                        email_subject=email_subject,
                        email_body=email_body,
                    )
                    
    except Exception as e:
        print(f"⚠️ Failed to notify collaborators: {e}")


def extract_mentions(text):
    """
    Extract @mentions from text
    Returns list of mentioned usernames/emails
    """
    import re
    pattern = r'@([a-zA-Z0-9_.+-]+(?:@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)?)'
    mentions = re.findall(pattern, text)
    return list(set(mentions))  # Remove duplicates


def process_mentions(comment_id, comment_text, mentioned_by_user_id, proposal_id):
    """
    Process @mentions in a comment
    """
    mentions = extract_mentions(comment_text)
    if not mentions:
        return
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("SELECT full_name FROM users WHERE id = %s", (mentioned_by_user_id,))
            commenter = cursor.fetchone()
            commenter_name = commenter['full_name'] if commenter else 'Someone'
            
            for mention in mentions:
                cursor.execute("""
                    SELECT id, full_name, email FROM users 
                    WHERE username = %s OR email = %s OR email LIKE %s
                """, (mention, mention, f'{mention}@%'))
                
                mentioned_user = cursor.fetchone()
                if not mentioned_user:
                    continue
                
                if mentioned_user['id'] == mentioned_by_user_id:
                    continue
                
                cursor.execute("""
                    INSERT INTO comment_mentions 
                    (comment_id, mentioned_user_id, mentioned_by_user_id)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                """, (comment_id, mentioned_user['id'], mentioned_by_user_id))
                
                create_notification(
                    mentioned_user['id'],
                    'mentioned',
                    'You were mentioned',
                    f"{commenter_name} mentioned you in a comment",
                    proposal_id,
                    {'comment_id': comment_id, 'mentioned_by': mentioned_by_user_id},
                    send_email_flag=True,
                    email_subject=f"[ProposalHub] {commenter_name} mentioned you",
                )
            
            conn.commit()
    except Exception as e:
        print(f"⚠️ Failed to process mentions: {e}")


def generate_proposal_pdf(proposal_id, title, content, client_name=None, client_email=None):
    """Generate PDF from proposal content"""
    if not PDF_AVAILABLE:
        raise Exception("ReportLab not installed. PDF generation unavailable.")
    
    opportunity_id = None
    engagement_stage = None
    engagement_opened_at = None
    owner_name = None

    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT p.opportunity_id, p.engagement_stage, p.engagement_opened_at, u.full_name
                FROM proposals p
                LEFT JOIN users u ON p.user_id = u.id
                WHERE p.id = %s
                """,
                (proposal_id,),
            )
            row = cursor.fetchone()
            if row:
                opportunity_id, engagement_stage, engagement_opened_at, owner_name = row
    except Exception as e:
        print(f"⚠️ Failed to load engagement metadata for proposal {proposal_id}: {e}")

    from reportlab.lib.pagesizes import letter, A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
    from io import BytesIO
    
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, topMargin=0.75*inch, bottomMargin=0.75*inch)
    
    styles = getSampleStyleSheet()
    elements = []
    
    # Title
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=24,
        textColor='#2C3E50',
        spaceAfter=16,
        alignment=TA_CENTER
    )
    elements.append(Paragraph(html.escape(title or 'Untitled Proposal'), title_style))
    elements.append(Spacer(1, 0.2*inch))

    meta_style = ParagraphStyle(
        'Metadata',
        parent=styles['Normal'],
        fontSize=10,
        textColor='#7F8C8D',
        spaceAfter=4,
        alignment=TA_LEFT,
    )

    meta_lines = []
    if client_name or client_email:
        if client_name and client_email:
            meta_lines.append(f"Prepared for: {client_name} <{client_email}>")
        elif client_name:
            meta_lines.append(f"Prepared for: {client_name}")
        else:
            meta_lines.append(f"Prepared for: {client_email}")

    meta_parts = []
    if opportunity_id:
        meta_parts.append(f"Opp {opportunity_id}")
    if engagement_stage:
        meta_parts.append(f"Stage: {engagement_stage}")
    if owner_name:
        meta_parts.append(f"Owner: {owner_name}")
    if engagement_opened_at:
        try:
            if isinstance(engagement_opened_at, datetime):
                opened_str = engagement_opened_at.strftime('%Y-%m-%d')
            else:
                opened_str = str(engagement_opened_at)
            meta_parts.append(f"Opened: {opened_str}")
        except Exception:
            pass

    if meta_parts:
        meta_lines.append("\u2022 ".join(meta_parts))

    for line in meta_lines:
        elements.append(Paragraph(html.escape(line), meta_style))
    if meta_lines:
        elements.append(Spacer(1, 0.2*inch))
    
    # Content
    content_style = ParagraphStyle(
        'CustomContent',
        parent=styles['Normal'],
        fontSize=11,
        leading=14,
        alignment=TA_LEFT,
        spaceAfter=12
    )
    
    # Simple content parsing - split by paragraphs
    if content:
        for para in content.split('\n\n'):
            if para.strip():
                elements.append(Paragraph(html.escape(para.strip()), content_style))
                elements.append(Spacer(1, 0.2*inch))
    
    # Signature placeholder
    sig_style = ParagraphStyle(
        'Signature',
        parent=styles['Normal'],
        fontSize=10,
        textColor='#666666',
        spaceBefore=0.5*inch
    )
    
    elements.append(Paragraph("[SIGNATURE PLACEHOLDER: /sig1/]", sig_style))
    elements.append(Spacer(1, 0.5*inch))
    
    # Footer
    footer_style = ParagraphStyle(
        'Footer',
        parent=styles['Normal'],
        fontSize=8,
        textColor='#666666',
        alignment=TA_CENTER
    )
    footer_text = f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    if opportunity_id:
        footer_text += f" | Opp {opportunity_id}"
    if engagement_stage:
        footer_text += f" | Stage: {engagement_stage}"
    elements.append(Paragraph(footer_text, footer_style))
    
    doc.build(elements)
    pdf_bytes = buffer.getvalue()
    buffer.close()
    
    return pdf_bytes


def create_docusign_envelope(proposal_id, pdf_bytes, signer_name, signer_email, signer_title, return_url):
    """
    Create DocuSign envelope with redirect signing (works on HTTP)
    Uses redirect mode instead of embedded signing - user is redirected to DocuSign website
    """
    # Re-check DocuSign availability in case import failed at module load
    try:
        from docusign_esign import (
            ApiClient,
            EnvelopesApi,
            EnvelopeDefinition,
            Document,
            Signer,
            SignHere,
            Tabs,
            Recipients,
            RecipientViewRequest,
        )
        from docusign_esign.client.api_exception import ApiException
    except ImportError as e:
        raise Exception(f"DocuSign SDK not installed. Install with: pip install docusign-esign. Error: {e}")
    
    if not DOCUSIGN_AVAILABLE:
        # Try to import again to see if it's available now
        try:
            from docusign_esign import ApiClient
            print("✅ DocuSign SDK is actually available, but DOCUSIGN_AVAILABLE flag was False")
        except ImportError:
            raise Exception("DocuSign SDK not installed. Install with: pip install docusign-esign")
    
    try:
        import base64
        from api.utils.docusign_utils import get_docusign_jwt_token
        from docusign_esign.client.api_exception import ApiException
        
        # Get access token
        access_token = get_docusign_jwt_token()
        
        # Get account ID - must be set in .env
        account_id = os.getenv('DOCUSIGN_ACCOUNT_ID')
        if not account_id:
            raise Exception("DOCUSIGN_ACCOUNT_ID is required. Get it from: https://demo.docusign.net → Settings → My Account Information → Account ID")
        
        # Validate account ID format (should be a GUID)
        if len(account_id) < 30 or '-' not in account_id:
            raise Exception(f"Invalid DOCUSIGN_ACCOUNT_ID format: {account_id}. Should be a GUID like: 70784c46-78c0-45af-8207-f4b8e8a43ea")
        
        # Use DOCUSIGN_BASE_PATH (matches working implementation) or fallback to DOCUSIGN_BASE_URL
        base_path = os.getenv('DOCUSIGN_BASE_PATH') or os.getenv('DOCUSIGN_BASE_URL', 'https://demo.docusign.net/restapi')
        
        # Create API client
        api_client = ApiClient()
        api_client.host = base_path
        api_client.set_default_header("Authorization", f"Bearer {access_token}")
        
        # Create document
        document = Document(
            document_base64=base64.b64encode(pdf_bytes).decode('utf-8'),
            name=f'Proposal_{proposal_id}.pdf',
            file_extension='pdf',
            document_id='1'
        )
        
        # Create signer with anchor string (matches PDF placeholder /sig1/)
        sign_here = SignHere(
            anchor_string='/sig1/',
            anchor_units='pixels',
            anchor_y_offset='10',
            anchor_x_offset='20'
        )
        
        tabs = Tabs(sign_here_tabs=[sign_here])
        
        # Create signer - email notifications will be handled by DocuSign automatically
        signer = Signer(
            email=signer_email,
            name=signer_name,
            recipient_id='1',
            routing_order='1',
            # client_user_id is NOT set - this enables redirect mode (works on HTTP)
            tabs=tabs
        )
        
        # If title provided, add custom field
        if signer_title:
            signer.note = f"Title: {signer_title}"
        
        # Create recipients
        recipients = Recipients(signers=[signer])
        
        # Create envelope with notification settings using dict format (works with all SDK versions)
        envelope_definition = EnvelopeDefinition(
            email_subject=f'Please sign: Proposal #{proposal_id}',
            documents=[document],
            recipients=recipients,
            status='sent'  # Send immediately
        )
        
        # DocuSign will automatically use account default notification settings
        # No need to set notification explicitly - DocuSign handles this automatically
        print("✅ Envelope will use DocuSign account default notifications")
        
        # Create envelope via API
        envelopes_api = EnvelopesApi(api_client)
        results = envelopes_api.create_envelope(account_id, envelope_definition=envelope_definition)
        envelope_id = results.envelope_id
        
        print(f"✅ DocuSign envelope created: {envelope_id}")
        
        # Verify envelope status after creation to confirm it was sent
        try:
            envelope_status = envelopes_api.get_envelope(account_id, envelope_id)
            actual_status = envelope_status.status
            print(f"📊 Envelope status after creation: {actual_status}")
            
            if actual_status.lower() != 'sent':
                print(f"⚠️  WARNING: Envelope status is '{actual_status}' but expected 'sent'")
                print(f"   This may indicate the envelope was not sent successfully")
            else:
                print(f"✅ Envelope confirmed as 'sent' - email should be delivered to {signer_email}")
        except Exception as status_error:
            print(f"⚠️  Could not verify envelope status: {status_error}")
            # Don't fail if status check fails, but log it
        
        # Create recipient view (redirect signing URL - works on HTTP)
        # For redirect mode, we don't set client_user_id (that's only for embedded)
        recipient_view_request = RecipientViewRequest(
            authentication_method='none',
            # client_user_id is NOT set - this makes it redirect mode instead of embedded
            recipient_id='1',
            return_url=return_url,
            user_name=signer_name,
            email=signer_email
        )
        
        view_results = envelopes_api.create_recipient_view(
            account_id,
            envelope_id,
            recipient_view_request=recipient_view_request
        )
        
        signing_url = view_results.url
        
        print(f"✅ Redirect signing URL created (works on HTTP)")
        
        # Get final envelope status for return value
        envelope_status_info = {'status': 'unknown'}
        try:
            final_status = envelopes_api.get_envelope(account_id, envelope_id)
            envelope_status_info = {
                'status': final_status.status,
                'status_date_time': str(final_status.status_date_time) if hasattr(final_status, 'status_date_time') else None
            }
        except Exception:
            pass  # Status already logged above
        
        return {
            'envelope_id': envelope_id,
            'signing_url': signing_url,
            'envelope_status': envelope_status_info
        }
        
    except ApiException as e:
        print(f"❌ DocuSign API error: {e}")
        raise
    except Exception as e:
        print(f"❌ Error creating DocuSign envelope: {e}")
        traceback.print_exc()
        raise
