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
from api.utils.jwt_validator import validate_jwt_token, JWTValidationError

bp = Blueprint('client', __name__)


def _get_invitation_column_info(cursor):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'collaboration_invitations'
        """
    )
    cols = {r['column_name'] if isinstance(r, dict) else r[0] for r in cursor.fetchall()}

    token_col = 'access_token' if 'access_token' in cols else ('token' if 'token' in cols else None)
    email_col = (
        'invited_email'
        if 'invited_email' in cols
        else (
            'invitee_email'
            if 'invitee_email' in cols
            else ('email' if 'email' in cols else None)
        )
    )
    expires_col = 'expires_at' if 'expires_at' in cols else None
    return {
        'cols': cols,
        'token_col': token_col,
        'email_col': email_col,
        'expires_col': expires_col,
    }


def _get_proposal_column_info(cursor):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'proposals'
        """
    )
    rows = cursor.fetchall()
    column_names = set()
    for row in rows:
        if isinstance(row, dict):
            name = row.get('column_name')
        else:
            name = row[0] if row else None
        if name:
            column_names.add(name)
    if 'client_name' in column_names:
        client_name_expr = 'p.client_name'
    elif 'client' in column_names:
        client_name_expr = 'p.client'
    else:
        client_name_expr = "'Client'::text"
    if 'client_email' in column_names:
        client_email_expr = 'p.client_email'
    else:
        client_email_expr = 'ci.invited_email'
    return {
        'columns': column_names,
        'client_name_expr': client_name_expr,
        'client_email_expr': client_email_expr,
    }


# ============================================================================
# CLIENT DASHBOARD JWT TOKEN ROUTES
# ============================================================================


@bp.get("/client/validate-token")
def validate_client_dashboard_token():
    """
    Validate a JWT token for the client dashboard.
    """
    try:
        auth_header = request.headers.get('Authorization', '')
        token = None

        if auth_header.startswith('Bearer '):
            token = auth_header.split(' ', 1)[1].strip()
        else:
            token = request.args.get('token')

        if not token:
            return {'detail': 'Token is required'}, 400

        try:
            decoded = validate_jwt_token(token)
        except JWTValidationError as e:
            return {'detail': str(e)}, 401

        return decoded, 200
    except Exception as e:
        print(f"❌ Error validating client dashboard token: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.get("/client-dashboard-mini/<token>")
def client_dashboard_mini(token):
    """
    Minimal HTML dashboard view for clients using a JWT token.
    """
    try:
        try:
            decoded = validate_jwt_token(token)
        except JWTValidationError as e:
            return f"<h1>Invalid or expired token</h1><p>{e}</p>", 401

        client_email = decoded.get('client_email', 'Client')
        proposal_data = decoded.get('proposal_data') or {}
        proposal_title = proposal_data.get('title', 'Business Proposal')
        proposal_status = proposal_data.get('status', 'For Review')

        html = f"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>Client Dashboard</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {{
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                    background: #0b1020;
                    color: #f9fafb;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                }}
                .card {{
                    background: radial-gradient(circle at top left, #111827, #020617);
                    border-radius: 16px;
                    border: 1px solid rgba(148, 163, 184, 0.3);
                    box-shadow: 0 24px 60px rgba(15, 23, 42, 0.6);
                    padding: 32px;
                    max-width: 640px;
                    width: 100%;
                }}
                h1 {{
                    margin: 0 0 4px;
                    font-size: 24px;
                }}
                h2 {{
                    margin: 24px 0 8px;
                    font-size: 18px;
                }}
                p {{
                    margin: 4px 0;
                    color: #cbd5f5;
                    font-size: 14px;
                }}
                .badge {{
                    display: inline-flex;
                    align-items: center;
                    padding: 4px 10px;
                    border-radius: 999px;
                    font-size: 11px;
                    text-transform: uppercase;
                    letter-spacing: 0.08em;
                    background: rgba(56, 189, 248, 0.1);
                    color: #38bdf8;
                    border: 1px solid rgba(56, 189, 248, 0.4);
                    margin-bottom: 16px;
                }}
                .section-title {{
                    font-weight: 600;
                    margin-top: 24px;
                    margin-bottom: 8px;
                    font-size: 13px;
                    text-transform: uppercase;
                    letter-spacing: 0.08em;
                    color: #9ca3af;
                }}
                .proposal-card {{
                    margin-top: 8px;
                    padding: 16px;
                    border-radius: 12px;
                    background: rgba(15, 23, 42, 0.8);
                    border: 1px solid rgba(148, 163, 184, 0.3);
                }}
                .status-pill {{
                    display: inline-flex;
                    align-items: center;
                    padding: 4px 12px;
                    border-radius: 999px;
                    font-size: 12px;
                    background: rgba(34, 197, 94, 0.12);
                    color: #4ade80;
                    border: 1px solid rgba(34, 197, 94, 0.5);
                }}
            </style>
        </head>
        <body>
            <div class="card">
                <div class="badge">Client Dashboard</div>
                <h1>Welcome to Your Client Portal</h1>
                <p>Hi {client_email}, here's a quick view of your proposal.</p>

                <div class="section-title">My Proposals</div>
                <div class="proposal-card">
                    <p style="font-weight: 600; font-size: 15px;">{proposal_title}</p>
                    <p style="margin-top: 8px;">
                        <span class="status-pill">{proposal_status}</span>
                    </p>
                </div>

                <div class="section-title">Sign Documents</div>
                <p>Open your full client portal to review, comment and sign.</p>

                <div class="section-title">Signed History</div>
                <p>Keep track of your completed agreements and engagements.</p>

                <div class="section-title">Feedback</div>
                <p>Share feedback directly in the portal for quicker alignment.</p>
            </div>
        </body>
        </html>
        """

        return html, 200
    except Exception as e:
        print(f"❌ Error rendering mini client dashboard: {e}")
        traceback.print_exc()
        return "<h1>Server Error</h1><p>Unable to render dashboard.</p>", 500


# ============================================================================
# CLIENT PROPOSAL ROUTES (using token-based access)
# ============================================================================


@bp.get("/client/proposals")
def get_client_proposals():
    """Get all proposals for a client using their access token"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            inv_info = _get_invitation_column_info(cursor)
            token_col = inv_info['token_col']
            email_col = inv_info['email_col']
            expires_col = inv_info['expires_col']

            if not token_col:
                return {'detail': 'Client invitations not configured (missing token column)'}, 500

            if not email_col:
                return {'detail': 'Client invitations not configured (missing invited email column)'}, 500
            
            # Get invitation details to find client email
            select_expires = f", {expires_col}" if expires_col else ", NULL as expires_at"
            cursor.execute(
                f"""
                SELECT {email_col} as invited_email{select_expires}
                FROM collaboration_invitations
                WHERE {token_col} = %s
                """,
                (token,),
            )
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            # Check if expired
            if invitation.get('expires_at') and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            client_email = invitation['invited_email']
            
            column_info = _get_proposal_column_info(cursor)
            client_name_expr = column_info['client_name_expr']
            client_email_expr = column_info['client_email_expr']

            query = f"""
                SELECT DISTINCT
                    p.id,
                    p.title,
                    p.status,
                    p.created_at,
                    p.updated_at,
                    {client_name_expr} AS client_name,
                    {client_email_expr} AS client_email,
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
                LEFT JOIN collaboration_invitations ci ON ci.proposal_id = p.id
                WHERE (ci.{email_col} = %s OR ci.{token_col} = %s)
                ORDER BY p.updated_at DESC
            """

            cursor.execute(query, (client_email, token))
            
            proposals = cursor.fetchall()
            
            return {
                'client_email': client_email,
                'proposals': [dict(p) for p in proposals]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting client proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/client/proposals/<int:proposal_id>")
def get_client_proposal_details(proposal_id):
    """Get detailed proposal information for client"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            inv_info = _get_invitation_column_info(cursor)
            token_col = inv_info['token_col']
            email_col = inv_info['email_col']
            expires_col = inv_info['expires_col']

            if not token_col:
                return {'detail': 'Client invitations not configured (missing token column)'}, 500

            if not email_col:
                return {'detail': 'Client invitations not configured (missing invited email column)'}, 500
            
            # Verify token and get client email
            select_expires = f", {expires_col}" if expires_col else ", NULL as expires_at"
            cursor.execute(
                f"""
                SELECT {email_col} as invited_email{select_expires}
                FROM collaboration_invitations
                WHERE {token_col} = %s
                """,
                (token,),
            )
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation.get('expires_at') and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            column_info = _get_proposal_column_info(cursor)
            client_name_expr = column_info['client_name_expr']
            client_email_expr = column_info['client_email_expr']
            columns = column_info['columns']

            if 'user_id' in columns:
                owner_select_expr = 'p.user_id'
                user_join_clause = 'LEFT JOIN users u ON p.user_id = u.username'
            elif 'owner_id' in columns:
                owner_select_expr = 'p.owner_id'
                user_join_clause = 'LEFT JOIN users u ON p.owner_id = u.id'
            else:
                owner_select_expr = 'NULL'
                user_join_clause = 'LEFT JOIN users u ON 1 = 0'

            query = f"""
                SELECT 
                    p.id, p.title, p.content, p.status, p.created_at, p.updated_at,
                    {client_name_expr} AS client_name,
                    {client_email_expr} AS client_email,
                    {owner_select_expr} AS user_id,
                    u.full_name as owner_name, u.email as owner_email
                FROM proposals p
                {user_join_clause}
                LEFT JOIN collaboration_invitations ci ON ci.proposal_id = p.id AND ci.{token_col} = %s
                WHERE p.id = %s AND (ci.{email_col} = %s OR ci.{token_col} = %s)
            """

            cursor.execute(query, (token, proposal_id, invitation['invited_email'], token))
            
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

@bp.post("/client/proposals/<int:proposal_id>/comment")
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

@bp.post("/client/proposals/<int:proposal_id>/approve")
def client_approve_proposal(proposal_id):
    """Client approves proposal - creates DocuSign envelope for signing"""
    try:
        data = request.get_json()
        token = data.get('token')
        signer_name = data.get('signer_name')
        signer_title = data.get('signer_title', '')
        comments = data.get('comments', '')
        
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
            
            client_email = invitation['invited_email']
            
            # Get proposal details - match by client_email OR collaboration_invitation token
            column_info = _get_proposal_column_info(cursor)
            client_name_expr = column_info['client_name_expr']
            client_email_expr = column_info['client_email_expr']

            query = f"""
                SELECT p.id, p.title, p.content,
                       {client_name_expr} AS client_name,
                       {client_email_expr} AS client_email
                FROM proposals p
                LEFT JOIN collaboration_invitations ci ON ci.proposal_id = p.id AND ci.access_token = %s
                WHERE p.id = %s AND (ci.invited_email = %s OR ci.access_token = %s)
            """

            cursor.execute(query, (token, proposal_id, client_email, token))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Check if DocuSign envelope already exists
            cursor.execute("""
                SELECT envelope_id, signing_url, status
                FROM proposal_signatures
                WHERE proposal_id = %s
                ORDER BY sent_at DESC
                LIMIT 1
            """, (proposal_id,))
            
            existing_signature = cursor.fetchone()
            
            # If we have a valid signing URL, return it
            signing_url = None
            envelope_id = None
            
            if existing_signature and existing_signature.get('signing_url'):
                status = existing_signature.get('status', '').lower()
                if status not in ['completed', 'declined', 'voided']:
                    signing_url = existing_signature['signing_url']
                    envelope_id = existing_signature['envelope_id']
            
            # If no valid signing URL, create a new DocuSign envelope
            if not signing_url:
                try:
                    from api.utils.helpers import generate_proposal_pdf, create_docusign_envelope
                    import os
                    
                    # Generate PDF
                    pdf_content = generate_proposal_pdf(
                        proposal_id=proposal_id,
                        title=proposal['title'],
                        content=proposal.get('content', ''),
                        client_name=proposal.get('client_name') or signer_name,
                        client_email=client_email
                    )
                    
                    # Create DocuSign envelope
                    # Since we're on HTTP, DocuSign will open in a new tab (not embedded)
                    # Use a return URL that points back to the client proposals page
                    from api.utils.helpers import get_frontend_url
                    frontend_url = get_frontend_url()
                    # Return to client portal after signing
                    return_url = f"{frontend_url}/#/client/proposals?token={token}&signed=true"
                    
                    envelope_result = create_docusign_envelope(
                        proposal_id=proposal_id,
                        pdf_bytes=pdf_content,
                        signer_name=signer_name,
                        signer_email=client_email,
                        signer_title=signer_title,
                        return_url=return_url
                    )

                    if envelope_result.get('disabled'):
                        return {
                            'detail': envelope_result.get('detail') or 'DocuSign disabled',
                            'error': envelope_result.get('reason') or 'docusign_disabled',
                        }, 501
                    
                    signing_url = envelope_result['signing_url']
                    envelope_id = envelope_result['envelope_id']
                    
                    # Store signature record
                    cursor.execute("""
                        SELECT id FROM proposal_signatures WHERE proposal_id = %s
                    """, (proposal_id,))
                    existing = cursor.fetchone()
                    
                    if existing:
                        # Update existing record
                        cursor.execute("""
                            UPDATE proposal_signatures 
                            SET envelope_id = %s,
                                signer_name = %s,
                                signer_email = %s,
                                signer_title = %s,
                                signing_url = %s,
                                status = %s,
                                sent_at = NOW()
                            WHERE proposal_id = %s
                        """, (
                            envelope_id,
                            signer_name,
                            client_email,
                            signer_title,
                            signing_url,
                            'sent',
                            proposal_id
                        ))
                    else:
                        # Insert new record
                        cursor.execute("""
                            INSERT INTO proposal_signatures 
                            (proposal_id, envelope_id, signer_name, signer_email, signer_title, 
                             signing_url, status, created_by)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, NULL)
                        """, (
                            proposal_id,
                            envelope_id,
                            signer_name,
                            client_email,
                            signer_title,
                            signing_url,
                            'sent'
                        ))
                    
                    # Update proposal status
                    cursor.execute("""
                        UPDATE proposals 
                        SET status = 'Sent for Signature', updated_at = NOW()
                        WHERE id = %s
                    """, (proposal_id,))
                    
                    conn.commit()
                    
                    print(f"✅ Created DocuSign envelope for proposal {proposal_id} (client: {client_email})")
                    
                except ImportError:
                    return {'detail': 'DocuSign integration not available'}, 503
                except Exception as docusign_error:
                    print(f"❌ DocuSign error: {docusign_error}")
                    traceback.print_exc()
                    return {'detail': f'Failed to create signing URL: {str(docusign_error)}'}, 500
            
            return {
                'message': 'Proposal ready for signing',
                'proposal_id': proposal['id'],
                'signing_url': signing_url,
                'envelope_id': envelope_id,
                'status': 'Sent for Signature'
            }, 200
            
    except Exception as e:
        print(f"❌ Error approving proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/client/proposals/<int:proposal_id>/reject")
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
            
            # Update proposal status - match by collaboration_invitation token only
            cursor.execute("""
                UPDATE proposals 
                SET status = 'Client Declined', updated_at = NOW()
                WHERE id = %s AND id IN (
                    SELECT proposal_id FROM collaboration_invitations 
                    WHERE access_token = %s AND proposal_id = %s
                )
                RETURNING id, title
            """, (proposal_id, token, proposal_id))
            
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

@bp.post("/client/proposals/<int:proposal_id>/get_signing_url")
def get_client_signing_url(proposal_id):
    """Get or create DocuSign signing URL for client"""
    try:
        data = request.get_json() or {}
        token = data.get('token') or request.args.get('token')
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
            
            client_email = invitation['invited_email']
            
            # Get proposal details - match by collaboration_invitation token
            column_info = _get_proposal_column_info(cursor)
            client_name_expr = column_info['client_name_expr']
            client_email_expr = column_info['client_email_expr']

            query = f"""
                SELECT p.id, p.title, p.content,
                       {client_name_expr} AS client_name,
                       {client_email_expr} AS client_email
                FROM proposals p
                LEFT JOIN collaboration_invitations ci ON ci.proposal_id = p.id AND ci.access_token = %s
                WHERE p.id = %s AND (ci.invited_email = %s OR ci.access_token = %s)
            """

            cursor.execute(query, (token, proposal_id, client_email, token))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Check if signing URL already exists and is still valid
            cursor.execute("""
                SELECT envelope_id, signing_url, status
                FROM proposal_signatures
                WHERE proposal_id = %s
                ORDER BY sent_at DESC
                LIMIT 1
            """, (proposal_id,))
            
            existing_signature = cursor.fetchone()
            
            # If we have a valid signing URL, return it
            if existing_signature and existing_signature.get('signing_url'):
                # Check if envelope is still active (not completed/declined)
                status = existing_signature.get('status', '').lower()
                if status not in ['completed', 'declined', 'voided']:
                    return {
                        'signing_url': existing_signature['signing_url'],
                        'envelope_id': existing_signature['envelope_id'],
                        'status': existing_signature.get('status', 'sent')
                    }, 200
            
            # No valid signing URL exists, create a new DocuSign envelope
            try:
                from api.utils.helpers import generate_proposal_pdf, create_docusign_envelope
                import os
                
                # Generate PDF
                pdf_content = generate_proposal_pdf(
                    proposal_id=proposal_id,
                    title=proposal['title'],
                    content=proposal.get('content', ''),
                    client_name=proposal.get('client_name'),
                    client_email=client_email
                )
                
                # Create DocuSign envelope
                # Since we're on HTTP, DocuSign will open in a new tab (not embedded)
                # Use a return URL that points back to the client proposals page
                frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                # Return to client portal after signing
                return_url = f"{frontend_url}/#/client/proposals?token={token}&signed=true"
                
                envelope_result = create_docusign_envelope(
                    proposal_id=proposal_id,
                    pdf_bytes=pdf_content,
                    signer_name=proposal.get('client_name') or client_email,
                    signer_email=client_email,
                    signer_title='',
                    return_url=return_url
                )
                
                # Store signature record - check if one exists first
                cursor.execute("""
                    SELECT id FROM proposal_signatures WHERE proposal_id = %s
                """, (proposal_id,))
                existing = cursor.fetchone()
                
                if existing:
                    # Update existing record
                    cursor.execute("""
                        UPDATE proposal_signatures 
                        SET envelope_id = %s,
                            signer_name = %s,
                            signer_email = %s,
                            signer_title = %s,
                            signing_url = %s,
                            status = %s,
                            sent_at = NOW()
                        WHERE proposal_id = %s
                        RETURNING id, signing_url, envelope_id
                    """, (
                        envelope_result['envelope_id'],
                        proposal.get('client_name') or client_email,
                        client_email,
                        '',
                        envelope_result['signing_url'],
                        'sent',
                        proposal_id
                    ))
                else:
                    # Insert new record
                    cursor.execute("""
                        INSERT INTO proposal_signatures 
                        (proposal_id, envelope_id, signer_name, signer_email, signer_title, 
                         signing_url, status, created_by)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, NULL)
                        RETURNING id, signing_url, envelope_id
                    """, (
                        proposal_id,
                        envelope_result['envelope_id'],
                        proposal.get('client_name') or client_email,
                        client_email,
                        '',
                        envelope_result['signing_url'],
                        'sent'
                    ))
                
                signature_record = cursor.fetchone()
                conn.commit()
                
                print(f"✅ Created DocuSign envelope for proposal {proposal_id} (client: {client_email})")
                
                return {
                    'signing_url': signature_record['signing_url'],
                    'envelope_id': signature_record['envelope_id'],
                    'status': 'sent',
                    'message': 'Signing URL created successfully'
                }, 200
                
            except ImportError:
                return {'detail': 'DocuSign integration not available'}, 503
            except Exception as docusign_error:
                print(f"❌ DocuSign error: {docusign_error}")
                traceback.print_exc()
                return {'detail': f'Failed to create signing URL: {str(docusign_error)}'}, 500
            
    except Exception as e:
        print(f"❌ Error getting signing URL: {e}")
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

# ============================================================================
# CLIENT ACTIVITY TRACKING ROUTES
# ============================================================================

@bp.post("/client/activity")
def log_client_activity():
    """Log client activity event (open, close, view_section, download, sign, comment)"""
    try:
        data = request.get_json()
        if not data:
            return {'detail': 'Request body required'}, 400
        
        token = data.get('token')
        proposal_id = data.get('proposal_id')
        event_type = data.get('event_type')
        metadata = data.get('metadata', {})
        
        if not token or not proposal_id or not event_type:
            return {'detail': 'Token, proposal_id, and event_type required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'collaboration_invitations'
                """
            )
            inv_cols = {r['column_name'] for r in cursor.fetchall()}

            token_col = 'access_token' if 'access_token' in inv_cols else ('token' if 'token' in inv_cols else None)
            if not token_col:
                return {'detail': 'Client invitations not configured (missing token column)'}, 500
            
            # Get client info from token
            cursor.execute("""
                SELECT ci.invited_email, c.id as client_id
                FROM collaboration_invitations ci
                LEFT JOIN clients c ON c.email = ci.invited_email
                WHERE ci.""" + token_col + """ = %s
            """, (token,))
            
            result = cursor.fetchone()
            if not result:
                return {'detail': 'Invalid access token'}, 404
            
            client_email = result['invited_email']
            client_id = result.get('client_id')
            
            # If client doesn't exist in clients table, try to find by email
            if not client_id:
                cursor.execute("""
                    SELECT id FROM clients WHERE email = %s
                """, (client_email,))
                client_row = cursor.fetchone()
                client_id = client_row['id'] if client_row else None
            
            # Convert proposal_id to appropriate type (handle both int and UUID)
            # First try to get proposal to verify it exists
            cursor.execute("""
                SELECT id FROM proposals WHERE id = %s OR id::text = %s
            """, (proposal_id, str(proposal_id)))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            actual_proposal_id = proposal['id']
            
            # Insert activity log
            import json as json_module
            metadata_json = json_module.dumps(metadata) if metadata else '{}'
            
            cursor.execute("""
                INSERT INTO proposal_client_activity 
                (proposal_id, client_id, event_type, metadata, created_at)
                VALUES (%s, %s, %s, %s::jsonb, NOW())
                RETURNING id, created_at
            """, (actual_proposal_id, client_id, event_type, metadata_json))
            
            activity = cursor.fetchone()
            conn.commit()
            
            return {
                'success': True,
                'activity_id': str(activity['id']),
                'created_at': activity['created_at'].isoformat() if activity['created_at'] else None
            }, 201
            
    except Exception as e:
        print(f"❌ Error logging client activity: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/client/session/start")
def start_client_session():
    """Start a new client session for time tracking"""
    try:
        data = request.get_json()
        if not data:
            return {'detail': 'Request body required'}, 400
        
        token = data.get('token')
        proposal_id = data.get('proposal_id')
        
        if not token or not proposal_id:
            return {'detail': 'Token and proposal_id required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'collaboration_invitations'
                """
            )
            inv_cols = {r['column_name'] for r in cursor.fetchall()}

            token_col = 'access_token' if 'access_token' in inv_cols else ('token' if 'token' in inv_cols else None)
            if not token_col:
                return {'detail': 'Client invitations not configured (missing token column)'}, 500
            
            # Get client info from token
            cursor.execute("""
                SELECT ci.invited_email, c.id as client_id
                FROM collaboration_invitations ci
                LEFT JOIN clients c ON c.email = ci.invited_email
                WHERE ci.""" + token_col + """ = %s
            """, (token,))
            
            result = cursor.fetchone()
            if not result:
                return {'detail': 'Invalid access token'}, 404
            
            client_id = result.get('client_id')
            if not client_id:
                cursor.execute("SELECT id FROM clients WHERE email = %s", (result['invited_email'],))
                client_row = cursor.fetchone()
                client_id = client_row['id'] if client_row else None
            
            # Verify proposal exists
            cursor.execute("""
                SELECT id FROM proposals WHERE id = %s OR id::text = %s
            """, (proposal_id, str(proposal_id)))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            actual_proposal_id = proposal['id']
            
            # Create session
            cursor.execute("""
                INSERT INTO proposal_client_session 
                (proposal_id, client_id, session_start)
                VALUES (%s, %s, NOW())
                RETURNING id, session_start
            """, (actual_proposal_id, client_id))
            
            session = cursor.fetchone()
            conn.commit()
            
            return {
                'success': True,
                'session_id': str(session['id']),
                'session_start': session['session_start'].isoformat() if session['session_start'] else None
            }, 201
            
    except Exception as e:
        print(f"❌ Error starting client session: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/client/session/end")
def end_client_session():
    """End a client session and calculate time spent"""
    try:
        data = request.get_json()
        if not data:
            return {'detail': 'Request body required'}, 400
        
        session_id = data.get('session_id')
        
        if not session_id:
            return {'detail': 'session_id required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get session
            cursor.execute("""
                SELECT id, session_start, proposal_id, client_id
                FROM proposal_client_session
                WHERE id = %s OR id::text = %s
            """, (session_id, str(session_id)))
            
            session = cursor.fetchone()
            if not session:
                return {'detail': 'Session not found'}, 404
            
            # Calculate time spent
            session_end = datetime.now()
            session_start = session['session_start']
            if session_start:
                total_seconds = int((session_end - session_start).total_seconds())
            else:
                total_seconds = 0
            
            # Update session
            cursor.execute("""
                UPDATE proposal_client_session
                SET session_end = %s, total_seconds = %s
                WHERE id = %s
                RETURNING id, total_seconds
            """, (session_end, total_seconds, session['id']))
            
            updated = cursor.fetchone()
            conn.commit()
            
            return {
                'success': True,
                'session_id': str(updated['id']),
                'total_seconds': updated['total_seconds']
            }, 200
            
    except Exception as e:
        print(f"❌ Error ending client session: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500









