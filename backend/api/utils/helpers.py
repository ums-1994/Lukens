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
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
    from reportlab.pdfgen import canvas
    from reportlab.lib.utils import ImageReader
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
    print("[OK] DocuSign SDK imported successfully")
except ImportError as e:
    DOCUSIGN_AVAILABLE = False
    print(f"[WARNING] DocuSign SDK not available: {e}")
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
            if 'type' in column_names:
                add_column('type', notification_type)
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


def generate_proposal_pdf(
    proposal_id,
    title,
    content,
    client_name=None,
    client_email=None,
    signer_name=None,
    signer_title=None,
    signed_date=None,
):
    """Generate PDF from proposal content"""
    if not PDF_AVAILABLE:
        raise Exception("ReportLab not installed. PDF generation unavailable.")
    created_at = datetime.now()

    import time
    _t_start = time.perf_counter()

    def _coerce_to_structured(value):
        if value is None:
            return {"sections": []}
        if isinstance(value, dict):
            return value
        if isinstance(value, (list, tuple)):
            return {"sections": list(value)}
        if isinstance(value, str):
            raw = value.strip()
            if not raw:
                return {"sections": []}

            # Guardrail: very large JSON strings can take a long time to parse and/or
            # generate enormous PDF layout work. For the client preview, fail fast.
            # (Download/export can still be used for full fidelity.)
            if len(raw) > 500_000 and raw[:1] in ('{', '['):
                return {
                    "text": "[Content too large to render in preview. Please use Export PDF/Word.]",
                    "sections": [],
                }
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, dict):
                    return parsed
                if isinstance(parsed, list):
                    return {"sections": parsed}
            except Exception:
                pass
            return {"text": raw, "sections": []}
        return {"text": str(value), "sections": []}

    def _normalize_sections(structured):
        if not isinstance(structured, dict):
            return []

        candidates = []
        for key in ("sections", "moduleContents", "modules", "content", "proposal"):
            if key in structured:
                candidates.append(structured.get(key))

        for candidate in candidates:
            if isinstance(candidate, dict):
                items = []
                for k, v in candidate.items():
                    items.append({"title": str(k), "body": v})
                if items:
                    return items
            if isinstance(candidate, list):
                return candidate

        if structured.get("text"):
            return [{"title": "Proposal", "body": structured.get("text")}]

        return []

    def _find_cover_image_url(structured):
        try:
            if not isinstance(structured, dict):
                return None

            for key in (
                'coverImageUrl',
                'cover_image_url',
                'coverUrl',
                'cover_url',
                'backgroundImageUrl',
            ):
                v = structured.get(key)
                if isinstance(v, str) and v.strip():
                    return v.strip()

            for section in _normalize_sections(structured) or []:
                if not isinstance(section, dict):
                    continue

                is_cover = section.get('isCoverPage') or section.get('cover') or section.get('is_cover')
                if is_cover:
                    v = (
                        section.get('backgroundImageUrl')
                        or section.get('coverImageUrl')
                        or section.get('coverUrl')
                    )
                    if isinstance(v, str) and v.strip():
                        return v.strip()

                v = section.get('backgroundImageUrl')
                if isinstance(v, str) and v.strip():
                    return v.strip()
        except Exception:
            return None
        return None

    def _fetch_cover_bytes(url: str):
        if not url or not isinstance(url, str):
            return None
        url = url.strip()
        if not (url.startswith('http://') or url.startswith('https://')):
            return None
        try:
            import urllib.request

            with urllib.request.urlopen(url, timeout=10) as resp:
                return resp.read()
        except Exception:
            return None

    _SKIP_KEYS = {
        'backgroundColor',
        'backgroundImageUrl',
        'inlineImages',
        'images',
        'tables',
        'metadata',
        'styles',
        'style',
        'layout',
        'sectionType',
        'isCoverPage',
        'id',
        'key',
        'uuid',
        'created_at',
        'updated_at',
        'createdAt',
        'updatedAt',
        'source',
    }

    _PREFERRED_TEXT_KEYS = (
        'body',
        'content',
        'text',
        'description',
        'summary',
        'value',
    )

    def _extract_text(value, *, depth: int = 0, max_depth: int = 6):
        if value is None:
            return ""
        if isinstance(value, str):
            s = value
            # Drop pathological strings (base64, long hashes, etc.) that can hang layout.
            if len(s) > 5000:
                ws = sum(1 for ch in s if ch.isspace())
                if ws / max(len(s), 1) < 0.01:
                    return ""
                s = s[:20000]
            return s
        if isinstance(value, (int, float, bool)):
            return str(value)
        if depth >= max_depth:
            return ""

        if isinstance(value, dict):
            # Fast path: common text fields
            for k in _PREFERRED_TEXT_KEYS:
                v = value.get(k)
                if isinstance(v, str) and v.strip():
                    return _extract_text(v, depth=depth + 1, max_depth=max_depth)

            # Otherwise, recursively collect text from non-noisy keys.
            parts = []
            for k, v in value.items():
                if k in _SKIP_KEYS or k in ('sections', 'subsections'):
                    continue
                extracted = _extract_text(v, depth=depth + 1, max_depth=max_depth)
                if extracted.strip():
                    parts.append(extracted.strip())
                if len(parts) >= 10:
                    break
            return "\n\n".join(parts)

        if isinstance(value, (list, tuple)):
            parts = []
            for item in value[:25]:
                extracted = _extract_text(item, depth=depth + 1, max_depth=max_depth)
                if extracted.strip():
                    parts.append(extracted.strip())
                if len(parts) >= 25:
                    break
            return "\n\n".join(parts)

        # Unknown types: avoid expensive serialization
        return ""

    def _as_paragraph_text(value):
        text = _extract_text(value).strip()
        if not text:
            return ""

        # Safety limit: prevent massive documents from taking minutes to lay out.
        # Keep enough to be useful while ensuring the preview loads quickly.
        max_chars = 120_000
        if len(text) > max_chars:
            text = text[:max_chars].rstrip() + "\n\n[Content truncated for preview]"
        return text

    def _render_body(elements, body, style_normal, style_bullet):
        text = _as_paragraph_text(body).strip()
        if not text:
            return

        text = text.replace("\r\n", "\n").replace("\r", "\n")

        max_blocks = 400
        blocks_rendered = 0
        for block in [b.strip() for b in text.split("\n\n") if b.strip()]:
            blocks_rendered += 1
            if blocks_rendered > max_blocks:
                elements.append(Paragraph("[Content truncated for preview]", style_normal))
                elements.append(Spacer(1, 0.15 * inch))
                break
            lines = [ln.rstrip() for ln in block.split("\n")]
            bullet_like = all(
                (ln.lstrip().startswith(("- ", "* ", "• ")) for ln in lines if ln.strip())
            )
            if bullet_like and len(lines) > 1:
                # Cap bullet lines per block to avoid pathological layouts.
                if len(lines) > 100:
                    lines = lines[:100]
                for ln in lines:
                    cleaned = ln.lstrip()
                    cleaned = cleaned[2:] if cleaned[:2] in ("- ", "* ") else cleaned
                    cleaned = cleaned[1:].lstrip() if cleaned.startswith("•") else cleaned
                    if cleaned.strip():
                        elements.append(
                            Paragraph(f"• {html.escape(cleaned.strip())}", style_bullet)
                        )
                elements.append(Spacer(1, 0.15 * inch))
            else:
                elements.append(Paragraph(html.escape(block), style_normal))
                elements.append(Spacer(1, 0.15 * inch))

    t_parse0 = time.perf_counter()
    structured = _coerce_to_structured(content)
    sections = _normalize_sections(structured)
    t_parse_ms = (time.perf_counter() - t_parse0) * 1000.0

    cover_url = _find_cover_image_url(structured)
    cover_bytes = _fetch_cover_bytes(cover_url) if cover_url else None

    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=0.85 * inch,
        rightMargin=0.85 * inch,
        topMargin=1.05 * inch,
        bottomMargin=1.0 * inch,
        title=title or "Proposal",
        author="ProposalHub",
    )

    styles = getSampleStyleSheet()
    elements = []

    title_style = ParagraphStyle(
        "CustomTitle",
        parent=styles["Heading1"],
        fontSize=26,
        leading=30,
        textColor="#2C3E50",
        spaceAfter=22,
        alignment=TA_CENTER,
    )
    meta_style = ParagraphStyle(
        "Meta",
        parent=styles["Normal"],
        fontSize=9,
        leading=12,
        textColor="#666666",
        alignment=TA_CENTER,
        spaceAfter=10,
    )
    heading_style = ParagraphStyle(
        "SectionHeading",
        parent=styles["Heading2"],
        fontSize=16,
        leading=20,
        textColor="#2C3E50",
        spaceBefore=14,
        spaceAfter=8,
        keepWithNext=True,
    )
    subheading_style = ParagraphStyle(
        "SubHeading",
        parent=styles["Heading3"],
        fontSize=12.5,
        leading=16,
        textColor="#2C3E50",
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True,
    )
    content_style = ParagraphStyle(
        "Body",
        parent=styles["Normal"],
        fontSize=11,
        leading=16,
        alignment=TA_LEFT,
        spaceAfter=6,
    )

    bullet_style = ParagraphStyle(
        "Bullet",
        parent=content_style,
        leftIndent=12,
        firstLineIndent=0,
        spaceAfter=2,
    )

    if cover_bytes:
        elements.append(Spacer(1, 0.01 * inch))
        elements.append(PageBreak())

    t_elements0 = time.perf_counter()

    # Hard cap number of sections rendered in preview.
    # Prevents huge proposals from generating thousands of Flowables.
    max_sections = 80
    if sections:
        for idx, section in enumerate(sections[:max_sections]):
            if isinstance(section, dict):
                section_title = (
                    section.get("title")
                    or section.get("name")
                    or section.get("label")
                    or section.get("id")
                    or "Section"
                )
                body = None
                if "body" in section:
                    body = section.get("body")
                elif "content" in section:
                    body = section.get("content")
                elif "text" in section:
                    body = section.get("text")

                # Some builders store nested content.
                if isinstance(body, dict):
                    body = body.get("content") or body.get("text") or body

                if body is None:
                    body = section
            else:
                section_title = "Section"
                body = section

            section_title = str(section_title).replace("_", " ").strip() or "Section"
            numbered_title = f"{idx + 1}. {section_title}".strip()
            elements.append(Paragraph(html.escape(numbered_title), heading_style))

            # Optional: render subsection blocks if the body is structured.
            if isinstance(body, dict) and isinstance(body.get('subsections'), list):
                for sub_idx, sub in enumerate(body.get('subsections') or []):
                    if not isinstance(sub, dict):
                        continue
                    sub_title = (sub.get('title') or sub.get('name') or '').strip()
                    sub_body = sub.get('body') if 'body' in sub else (sub.get('content') if 'content' in sub else sub.get('text'))
                    if sub_title:
                        elements.append(
                            Paragraph(
                                html.escape(f"{idx + 1}.{sub_idx + 1} {sub_title}"),
                                subheading_style,
                            )
                        )
                    _render_body(elements, sub_body, content_style, bullet_style)
            else:
                _render_body(elements, body, content_style, bullet_style)

            elements.append(Spacer(1, 0.15 * inch))
        if len(sections) > max_sections:
            elements.append(Paragraph("[Additional sections omitted for preview]", content_style))
    elif structured.get("text"):
        _render_body(elements, structured.get("text"), content_style, bullet_style)
    else:
        elements.append(Paragraph("No content available.", content_style))

    t_elements_ms = (time.perf_counter() - t_elements0) * 1000.0

    elements.append(PageBreak())
    elements.append(Paragraph("Signature", heading_style))
    elements.append(Spacer(1, 0.3 * inch))
    elements.append(Paragraph("Please sign in the space below.", content_style))
    elements.append(Spacer(1, 0.35 * inch))
    elements.append(
        Paragraph(
            "/sig1/",
            ParagraphStyle(
                "SigAnchor",
                parent=styles["Normal"],
                fontSize=1,
                leading=1,
            ),
        )
    )
    elements.append(Spacer(1, 0.6 * inch))
    elements.append(Paragraph("Name: ________________________________", content_style))
    elements.append(Spacer(1, 0.15 * inch))
    elements.append(Paragraph("Title: _________________________________", content_style))
    elements.append(Spacer(1, 0.15 * inch))
    elements.append(Paragraph("Date: _________________________________", content_style))

    has_cover_page = bool(cover_bytes)
    header_title = (title or "Proposal").strip() or "Proposal"

    def _draw_cover_page(c, _doc):
        if not cover_bytes:
            return
        try:
            page_width, page_height = _doc.pagesize
            img = ImageReader(BytesIO(cover_bytes))
            c.saveState()
            c.drawImage(img, 0, 0, width=page_width, height=page_height, preserveAspectRatio=True, anchor='c')
            c.restoreState()
        except Exception:
            pass

    class _NumberedCanvas(canvas.Canvas):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self._saved_page_states = []

        def showPage(self):
            self._saved_page_states.append(dict(self.__dict__))
            self._startPage()

        def save(self):
            total_pages = len(self._saved_page_states)
            for state in self._saved_page_states:
                self.__dict__.update(state)
                self._draw_header_footer(total_pages)
                super().showPage()
            super().save()

        def _draw_header_footer(self, total_pages: int):
            page_width, page_height = doc.pagesize
            page_num = self.getPageNumber()
            if has_cover_page and page_num == 1:
                return
            self.saveState()
            self.setFont("Helvetica", 8)
            self.setFillColorRGB(0.25, 0.25, 0.25)

            header_y = page_height - (0.75 * inch)
            footer_y = 0.75 * inch

            self.setStrokeColorRGB(0.85, 0.85, 0.85)
            self.setLineWidth(0.5)
            self.line(doc.leftMargin, header_y - 8, page_width - doc.rightMargin, header_y - 8)
            self.line(doc.leftMargin, footer_y + 8, page_width - doc.rightMargin, footer_y + 8)

            self.drawString(doc.leftMargin, header_y, header_title)

            footer_right = f"Page {page_num} of {total_pages}"
            self.drawRightString(page_width - doc.rightMargin, footer_y, footer_right)
            self.restoreState()

    t_build0 = time.perf_counter()
    doc.build(
        elements,
        canvasmaker=_NumberedCanvas,
        onFirstPage=_draw_cover_page,
    )
    t_build_ms = (time.perf_counter() - t_build0) * 1000.0

    total_ms = (time.perf_counter() - _t_start) * 1000.0
    try:
        print(
            f"[PDF_GEN] proposal_id={proposal_id} parse_ms={t_parse_ms:.0f} elements_ms={t_elements_ms:.0f} build_ms={t_build_ms:.0f} total_ms={total_ms:.0f} sections={len(sections) if isinstance(sections, list) else 0}"
        )
    except Exception:
        pass
    pdf_bytes = buffer.getvalue()
    buffer.close()
    return pdf_bytes


def create_docusign_envelope(proposal_id, pdf_bytes, signer_name, signer_email, signer_title, return_url):
    """
    Create DocuSign envelope with redirect signing (works on HTTP)
    Uses redirect mode instead of embedded signing - user is redirected to DocuSign website
    """
    if os.getenv('ENABLE_DOCUSIGN', 'false').lower() != 'true':
        return {
            'disabled': True,
            'reason': 'docusign_disabled',
            'detail': 'DocuSign is disabled on this server. Set ENABLE_DOCUSIGN=true to enable.',
        }

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
