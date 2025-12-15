"""
Client management routes
"""
from flask import Blueprint, request, jsonify
import os
import secrets
import traceback
import hashlib
from datetime import datetime, timedelta, timezone
from pathlib import Path
import psycopg2.extras
from api.utils.database import get_db_connection
from api.utils.decorators import token_required
from api.utils.email import send_email, get_logo_html

bp = Blueprint('clients', __name__)

@bp.post("/clients/invite")
@token_required
def send_client_invitation(username=None):
    """Send a secure onboarding invitation to a client"""
    try:
        print(f"[INVITE] Received invitation request from user: {username}")
        data = request.json
        print(f"[INVITE] Request data: {data}")
        
        invited_email = data.get('invited_email')
        expected_company = data.get('expected_company')
        expiry_days = data.get('expiry_days', 7)
        
        print(f"[INVITE] Email: {invited_email}, Company: {expected_company}, Expiry: {expiry_days} days")
        
        if not invited_email:
            print("[INVITE] ERROR: Email is required")
            return jsonify({"error": "Email is required"}), 400
        
        # Generate secure token
        access_token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(days=expiry_days)
        
        # Get current user ID
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row[0]
            
            # Insert invitation
            cursor.execute("""
                INSERT INTO client_onboarding_invitations 
                (access_token, invited_email, invited_by, expected_company, status, expires_at)
                VALUES (%s, %s, %s, %s, 'pending', %s)
                RETURNING id, access_token, invited_at
            """, (access_token, invited_email, user_id, expected_company, expires_at))
            
            result = cursor.fetchone()
            conn.commit()
            
            invitation_id, token, invited_at = result
            
            # Generate onboarding link (using hash-based routing)
            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            onboarding_url = f"{frontend_url}/#/onboard/{token}"
            
            # Load email template
            template_path = Path(__file__).parent.parent.parent / 'templates' / 'email' / 'client_invitation.html'
            try:
                with open(template_path, 'r', encoding='utf-8') as f:
                    html_content = f.read()
            except FileNotFoundError:
                print(f"[WARN] Template not found at {template_path}, using fallback")
                logo_html = get_logo_html()
                html_content = f"""
                <html><body style="font-family: 'Poppins', Arial, sans-serif; padding: 40px 20px; background: #000; color: #fff;">
                    <div style="max-width: 600px; margin: 0 auto; background: #1A1A1A; padding: 40px; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3);">
                        <div style="text-align: center; margin-bottom: 30px;">
                            {logo_html}
                        </div>
                        <p style="color: #fff; font-size: 16px;">Hello{{ company_name }}!</p>
                        <p style="color: #B3B3B3; font-size: 16px;">You've been invited to complete your client onboarding with Khonology.</p>
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{{ onboarding_url }}" style="background: linear-gradient(135deg, #E9293A 0%, #780A01 100%); color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: 600;">Start Onboarding →</a>
                        </div>
                        <p style="color: #666; font-size: 12px; text-align: center; margin-top: 30px;">© 2025 Khonology. All rights reserved.</p>
                    </div>
                </body></html>
                """
            
            # Replace template variables
            company_name = f", {expected_company}" if expected_company else ""
            logo_html = get_logo_html()
            html_content = html_content.replace('{{ company_name }}', company_name)
            html_content = html_content.replace('{{ onboarding_url }}', onboarding_url)
            html_content = html_content.replace('{{ expiry_days }}', str(expiry_days))
            html_content = html_content.replace('{{ logo_html }}', logo_html)
            
            # Send email
            subject = "You're Invited to Complete Your Client Onboarding"
            
            print(f"[INVITE] Sending email to {invited_email}...")
            email_sent = send_email(invited_email, subject, html_content)
            print(f"[INVITE] Email sent: {email_sent}")
            
            return jsonify({
                "success": True,
                "invitation_id": invitation_id,
                "access_token": token,
                "onboarding_url": onboarding_url,
                "invited_email": invited_email,
                "expires_at": expires_at.isoformat(),
                "invited_at": invited_at.isoformat()
            }), 201
            
    except Exception as e:
        print(f"[ERROR] Error sending invitation: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@bp.get("/clients/invitations")
@token_required
def get_invitations(username=None):
    """Get all client invitations for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Get all invitations
            cursor.execute("""
                SELECT 
                    id,
                    access_token,
                    invited_email,
                    expected_company,
                    status,
                    invited_at,
                    completed_at,
                    expires_at,
                    client_id,
                    email_verified_at,
                    verification_attempts,
                    last_code_sent_at,
                    code_expires_at,
                    (email_verified_at IS NOT NULL) AS email_verified
                FROM client_onboarding_invitations
                WHERE invited_by = %s
                ORDER BY invited_at DESC
            """, (user_id,))
            
            invitations = cursor.fetchall()
            return jsonify([dict(inv) for inv in invitations]), 200
            
    except Exception as e:
        print(f"[ERROR] Error fetching invitations: {e}")
        return jsonify({"error": str(e)}), 500

@bp.post("/clients/invitations/<int:invitation_id>/send-code")
@token_required
def admin_send_verification_code(username=None, invitation_id=None):
    """Admin action: send a fresh email verification code to the invited email"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Load invitation (must be pending and not expired)
            cursor.execute(
                """
                SELECT id, invited_email, access_token, status, expires_at, last_code_sent_at
                FROM client_onboarding_invitations
                WHERE id = %s
                """,
                (invitation_id,),
            )
            invitation = cursor.fetchone()
            if not invitation:
                return jsonify({"error": "Invitation not found"}), 404

            if invitation["status"] != "pending":
                return jsonify({"error": "Invitation already used or cancelled"}), 400

            expires_at_dt = invitation["expires_at"]
            if isinstance(expires_at_dt, str):
                expires_at_dt = datetime.fromisoformat(expires_at_dt)
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            if expires_at_dt < datetime.now(timezone.utc):
                return jsonify({"error": "Invitation has expired"}), 400

            # Basic rate limit: not more than 3 sends per hour
            if invitation.get("last_code_sent_at"):
                last_sent = invitation["last_code_sent_at"]
                if isinstance(last_sent, str):
                    last_sent = datetime.fromisoformat(last_sent)
                last_sent = last_sent.astimezone(timezone.utc)
                seconds_since = (datetime.now(timezone.utc) - last_sent).total_seconds()
                if seconds_since < 3600:
                    cursor.execute(
                        """
                        SELECT COUNT(*) AS count
                        FROM email_verification_events
                        WHERE invitation_id = %s
                          AND event_type = 'code_sent'
                          AND created_at > NOW() - INTERVAL '1 hour'
                        """,
                        (invitation["id"],),
                    )
                    if (cursor.fetchone() or {}).get("count", 0) >= 3:
                        return jsonify({"error": "Too many codes sent in the last hour"}), 429

            # Generate and persist code (6 digits, hashed)
            verification_code = "".join([str(secrets.randbelow(10)) for _ in range(6)])
            code_hash = hashlib.sha256(verification_code.encode()).hexdigest()
            code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)

            cursor.execute(
                """
                UPDATE client_onboarding_invitations
                SET verification_code_hash = %s,
                    code_expires_at = %s,
                    last_code_sent_at = NOW()
                WHERE id = %s
                """,
                (code_hash, code_expires_at, invitation["id"]),
            )

            cursor.execute(
                """
                INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                VALUES (%s, %s, 'code_sent', 'Admin triggered email verification code send')
                """,
                (invitation["id"], invitation["invited_email"]),
            )
            conn.commit()

            # Send email with code
            subject = "Your Khonology Email Verification Code"
            html_content = f"""
            <html><body style="font-family: 'Poppins', Arial, sans-serif; background:#000; color:#fff; padding:24px;">
              <div style="max-width:600px;margin:0 auto;background:#1A1A1A;border-radius:16px;border:1px solid rgba(233,41,58,0.3);padding:32px;">
                <div style="text-align:center;margin-bottom:24px;">{get_logo_html()}</div>
                <p style="color:#B3B3B3;">Use the following 6-digit code to verify your email:</p>
                <div style="text-align:center;margin:20px 0;">
                  <div style="display:inline-block;background:#111;border:1px solid #333;border-radius:12px;padding:16px 24px;font-size:28px;letter-spacing:6px;color:#fff;font-weight:700;">
                    {verification_code}
                  </div>
                </div>
                <p style="color:#B3B3B3;">This code expires in 15 minutes.</p>
                <p style="color:#666;font-size:12px;text-align:center;margin-top:30px;">© 2025 Khonology. All rights reserved.</p>
              </div>
            </body></html>
            """
            send_email(invitation["invited_email"], subject, html_content)

            return jsonify({"success": True, "message": "Verification code sent"}), 200

    except Exception as e:
        print(f"[ERROR] Error sending verification code: {e}")
        return jsonify({"error": str(e)}), 500

@bp.post("/clients/invitations/<int:invitation_id>/resend")
@token_required
def resend_invitation(username=None, invitation_id=None):
    """Resend a client invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation
            cursor.execute("""
                SELECT invited_email, access_token, expected_company, expires_at
                FROM client_onboarding_invitations
                WHERE id = %s AND status = 'pending'
            """, (invitation_id,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return jsonify({"error": "Invitation not found or already completed"}), 404
            
            # Check if expired
            expires_at_dt = invitation['expires_at']
            if isinstance(expires_at_dt, str):
                expires_at_dt = datetime.fromisoformat(expires_at_dt)
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            
            if expires_at_dt < datetime.now(timezone.utc):
                # Generate new token and extend expiry
                new_token = secrets.token_urlsafe(32)
                new_expires_at = datetime.now(timezone.utc) + timedelta(days=7)
                
                cursor.execute("""
                    UPDATE client_onboarding_invitations
                    SET access_token = %s, expires_at = %s
                    WHERE id = %s
                """, (new_token, new_expires_at, invitation_id))
                conn.commit()
                
                token = new_token
                expires_at = new_expires_at
            else:
                token = invitation['access_token']
                expires_at = invitation['expires_at']
            
            # Generate onboarding link (using hash-based routing)
            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            onboarding_url = f"{frontend_url}/#/onboard/{token}"
            
            # Calculate remaining days
            expires_at_dt = expires_at if isinstance(expires_at, datetime) else datetime.fromisoformat(str(expires_at))
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            remaining_days = max(1, (expires_at_dt - datetime.now(timezone.utc)).days)
            
            # Load email template
            template_path = Path(__file__).parent.parent.parent / 'templates' / 'email' / 'client_invitation.html'
            try:
                with open(template_path, 'r', encoding='utf-8') as f:
                    html_content = f.read()
            except FileNotFoundError:
                print(f"[WARN] Template not found at {template_path}, using fallback")
                logo_html = get_logo_html()
                html_content = f"""
                <html><body style="font-family: 'Poppins', Arial, sans-serif; padding: 40px 20px; background: #000; color: #fff;">
                    <div style="max-width: 600px; margin: 0 auto; background: #1A1A1A; padding: 40px; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3);">
                        <div style="text-align: center; margin-bottom: 30px;">
                            {logo_html}
                        </div>
                        <p style="color: #fff; font-size: 16px;">Hello{{ company_name }}!</p>
                        <p style="color: #B3B3B3; font-size: 16px;">This is a friendly reminder to complete your client onboarding with Khonology.</p>
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{{ onboarding_url }}" style="background: linear-gradient(135deg, #E9293A 0%, #780A01 100%); color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: 600;">Start Onboarding →</a>
                        </div>
                        <p style="color: #666; font-size: 12px; text-align: center; margin-top: 30px;">© 2025 Khonology. All rights reserved.</p>
                    </div>
                </body></html>
                """
            
            # Replace template variables
            company_name = f", {invitation['expected_company']}" if invitation.get('expected_company') else ""
            logo_html = get_logo_html()
            html_content = html_content.replace('{{ company_name }}', company_name)
            html_content = html_content.replace('{{ onboarding_url }}', onboarding_url)
            html_content = html_content.replace('{{ expiry_days }}', str(remaining_days))
            html_content = html_content.replace('{{ logo_html }}', logo_html)
            
            # Send email
            subject = "Reminder: Complete Your Client Onboarding"
            send_email(invitation['invited_email'], subject, html_content)
            
            return jsonify({"success": True, "message": "Invitation resent"}), 200
            
    except Exception as e:
        print(f"[ERROR] Error resending invitation: {e}")
        return jsonify({"error": str(e)}), 500

@bp.delete("/clients/invitations/<int:invitation_id>")
@token_required
def cancel_invitation(username=None, invitation_id=None):
    """Cancel a pending invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                UPDATE client_onboarding_invitations
                SET status = 'cancelled'
                WHERE id = %s AND status = 'pending'
            """, (invitation_id,))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Invitation not found or already completed"}), 404
            
            return jsonify({"success": True, "message": "Invitation cancelled"}), 200
            
    except Exception as e:
        print(f"[ERROR] Error cancelling invitation: {e}")
        return jsonify({"error": str(e)}), 500

@bp.get("/clients")
@token_required
def get_clients(username=None):
    """Get all clients for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Get all clients
            cursor.execute("""
                SELECT 
                    id, company_name, contact_person, email, phone,
                    industry, company_size, location, business_type,
                    project_needs, budget_range, timeline, additional_info,
                    status, created_at, updated_at
                FROM clients
                WHERE created_by = %s
                ORDER BY created_at DESC
            """, (user_id,))
            
            clients = cursor.fetchall()
            return jsonify([dict(client) for client in clients]), 200
            
    except Exception as e:
        print(f"[ERROR] Error fetching clients: {e}")
        return jsonify({"error": str(e)}), 500

@bp.get("/clients/<int:client_id>")
@token_required
def get_client(username=None, client_id=None):
    """Get a single client's details"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    id, company_name, contact_person, email, phone,
                    industry, company_size, location, business_type,
                    project_needs, budget_range, timeline, additional_info,
                    status, created_at, updated_at
                FROM clients
                WHERE id = %s
            """, (client_id,))
            
            client = cursor.fetchone()
            
            if not client:
                return jsonify({"error": "Client not found"}), 404
            
            return jsonify(dict(client)), 200
            
    except Exception as e:
        print(f"[ERROR] Error fetching client: {e}")
        return jsonify({"error": str(e)}), 500

@bp.patch("/clients/<int:client_id>/status")
@token_required
def update_client_status(username=None, client_id=None):
    """Update client status"""
    try:
        data = request.json
        new_status = data.get('status')
        
        if not new_status:
            return jsonify({"error": "Status is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                UPDATE clients
                SET status = %s, updated_at = NOW()
                WHERE id = %s
            """, (new_status, client_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Client not found"}), 404
            
            return jsonify({"success": True, "message": "Status updated"}), 200
            
    except Exception as e:
        print(f"[ERROR] Error updating client status: {e}")
        return jsonify({"error": str(e)}), 500

@bp.get("/clients/<int:client_id>/notes")
@token_required
def get_client_notes(username=None, client_id=None):
    """Get all notes for a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    cn.id, cn.note_text, cn.created_at, cn.updated_at,
                    u.email as created_by_email, u.full_name as created_by_name
                FROM client_notes cn
                JOIN users u ON cn.created_by = u.id
                WHERE cn.client_id = %s
                ORDER BY cn.created_at DESC
            """, (client_id,))
            
            notes = cursor.fetchall()
            return jsonify([dict(note) for note in notes]), 200
            
    except Exception as e:
        print(f"[ERROR] Error fetching client notes: {e}")
        return jsonify({"error": str(e)}), 500

@bp.post("/clients/<int:client_id>/notes")
@token_required
def add_client_note(username=None, client_id=None):
    """Add a note to a client"""
    try:
        data = request.json
        note_text = data.get('note_text')
        
        if not note_text:
            return jsonify({"error": "Note text is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Insert note
            cursor.execute("""
                INSERT INTO client_notes (client_id, note_text, created_by)
                VALUES (%s, %s, %s)
                RETURNING id, created_at
            """, (client_id, note_text, user_id))
            
            result = cursor.fetchone()
            conn.commit()
            
            return jsonify({
                "success": True,
                "note_id": result['id'],
                "created_at": result['created_at'].isoformat()
            }), 201
            
    except Exception as e:
        print(f"[ERROR] Error adding client note: {e}")
        return jsonify({"error": str(e)}), 500

@bp.put("/clients/notes/<int:note_id>")
@token_required
def update_client_note(username=None, note_id=None):
    """Update a client note"""
    try:
        data = request.json
        note_text = data.get('note_text')
        
        if not note_text:
            return jsonify({"error": "Note text is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                UPDATE client_notes
                SET note_text = %s, updated_at = NOW()
                WHERE id = %s
            """, (note_text, note_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Note not found"}), 404
            
            return jsonify({"success": True, "message": "Note updated"}), 200
            
    except Exception as e:
        print(f"[ERROR] Error updating client note: {e}")
        return jsonify({"error": str(e)}), 500

@bp.delete("/clients/notes/<int:note_id>")
@token_required
def delete_client_note(username=None, note_id=None):
    """Delete a client note"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("DELETE FROM client_notes WHERE id = %s", (note_id,))
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Note not found"}), 404
            
            return jsonify({"success": True, "message": "Note deleted"}), 200
            
    except Exception as e:
        print(f"[ERROR] Error deleting client note: {e}")
        return jsonify({"error": str(e)}), 500

@bp.get("/clients/<int:client_id>/proposals")
@token_required
def get_client_linked_proposals(username=None, client_id=None):
    """Get all proposals linked to a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    p.id, p.title, p.status, p.created_at,
                    cp.relationship_type, cp.linked_at,
                    u.email as linked_by_email
                FROM client_proposals cp
                JOIN proposals p ON cp.proposal_id = p.id
                JOIN users u ON cp.linked_by = u.id
                WHERE cp.client_id = %s
                ORDER BY cp.linked_at DESC
            """, (client_id,))
            
            proposals = cursor.fetchall()
            return jsonify([dict(prop) for prop in proposals]), 200
            
    except Exception as e:
        print(f"[ERROR] Error fetching client proposals: {e}")
        return jsonify({"error": str(e)}), 500

@bp.post("/clients/<int:client_id>/proposals")
@token_required
def link_client_proposal(username=None, client_id=None):
    """Link a proposal to a client"""
    try:
        data = request.json
        proposal_id = data.get('proposal_id')
        relationship_type = data.get('relationship_type', 'primary')
        
        if not proposal_id:
            return jsonify({"error": "Proposal ID is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Link proposal
            cursor.execute("""
                INSERT INTO client_proposals (client_id, proposal_id, relationship_type, linked_by)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (client_id, proposal_id) DO NOTHING
                RETURNING id
            """, (client_id, proposal_id, relationship_type, user_id))
            
            result = cursor.fetchone()
            conn.commit()
            
            if not result:
                return jsonify({"error": "Proposal already linked to this client"}), 400
            
            return jsonify({"success": True, "link_id": result['id']}), 201
            
    except Exception as e:
        print(f"[ERROR] Error linking proposal to client: {e}")
        return jsonify({"error": str(e)}), 500

@bp.delete("/clients/<int:client_id>/proposals/<int:proposal_id>")
@token_required
def unlink_client_proposal(username=None, client_id=None, proposal_id=None):
    """Unlink a proposal from a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                DELETE FROM client_proposals
                WHERE client_id = %s AND proposal_id = %s
            """, (client_id, proposal_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Link not found"}), 404
            
            return jsonify({"success": True, "message": "Proposal unlinked"}), 200
            
    except Exception as e:
        print(f"[ERROR] Error unlinking proposal: {e}")
        return jsonify({"error": str(e)}), 500

