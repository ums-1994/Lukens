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
        data = request.json or {}
        print(f"[INVITE] Request data: {data}")

        invited_email = data.get('invited_email')
        expected_company = data.get('expected_company')
        expiry_days = data.get('expiry_days', 7)

        print(f"[INVITE] Email: {invited_email}, Company: {expected_company}, Expiry: {expiry_days} days")

        if not invited_email:
            print('[INVITE] ERROR: Email is required')
            return jsonify({"error": "Email is required"}), 400

        access_token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(days=expiry_days)

        with get_db_connection() as conn:
            cursor = conn.cursor()

            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404

            user_id = user_row[0]

            cursor.execute(
                """
                INSERT INTO client_onboarding_invitations 
                (access_token, invited_email, invited_by, expected_company, status, expires_at)
                VALUES (%s, %s, %s, %s, 'pending', %s)
                RETURNING id, access_token, invited_at
                """,
                (access_token, invited_email, user_id, expected_company, expires_at),
            )

            result = cursor.fetchone()
            conn.commit()

            invitation_id, token, invited_at = result

            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            # Use query parameter instead of hash for better email client compatibility
            onboarding_url = f"{frontend_url}/onboard?token={token}"

            template_path = Path(__file__).parent.parent.parent / 'templates' / 'email' / 'client_invitation.html'
            try:
                with open(template_path, 'r', encoding='utf-8') as template_file:
                    html_content = template_file.read()
            except FileNotFoundError:
                print(f"[WARN] Template not found at {template_path}, using fallback")
                logo_html = get_logo_html()
                # Fix: Use proper placeholder format and greeting
                company_placeholder = "{{COMPANY_NAME}}"
                url_placeholder = "{{ONBOARDING_URL}}"
                html_content = f"""
                <html><body style="font-family: 'Poppins', Arial, sans-serif; padding: 40px 20px; background: #000; color: #fff;">
                    <div style="max-width: 600px; margin: 0 auto; background: #1A1A1A; padding: 40px; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3);">
                        <div style="text-align: center; margin-bottom: 30px;">
                            {logo_html}
                        </div>
                        <p style="color: #fff; font-size: 16px;">Hello{company_placeholder}!</p>
                        <p style="color: #B3B3B3; font-size: 16px;">You've been invited to complete your client onboarding with Khonology. We're excited to start working with you!</p>
                        
                        <div style="background: #0A0A0A; border-left: 3px solid #E9293A; border-radius: 8px; padding: 16px; margin: 24px 0;">
                            <div style="display: flex; align-items: center; margin-bottom: 12px;">
                                <span style="font-size: 20px; margin-right: 8px;">🔒</span>
                                <strong style="color: #E9293A; font-size: 14px; text-transform: uppercase;">SECURITY NOTICE</strong>
                            </div>
                            <p style="color: #B3B3B3; font-size: 14px; line-height: 1.6; margin: 0;">
                                For your security, you'll need to verify your phone number before accessing the onboarding form. This helps protect your information and ensures a secure onboarding process.
                            </p>
                        </div>
                        
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{url_placeholder}" style="background: linear-gradient(135deg, #E9293A 0%, #780A01 100%); color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: 600;">Start Onboarding →</a>
                        </div>
                        <p style="color: #666; font-size: 12px; text-align: center; margin-top: 30px;">© 2025 Khonology. All rights reserved.</p>
                    </div>
                </body></html>
                """

            # Fix: Use the company name directly, not as a comma prefix
            company_name = expected_company if expected_company else "there"
            logo_html = get_logo_html()
            
            # Replace placeholders (handle both old and new formats)
            html_content = html_content.replace('{{COMPANY_NAME}}', company_name)
            html_content = html_content.replace('{{ company_name }}', company_name)
            html_content = html_content.replace('{{company_name}}', company_name)
            html_content = html_content.replace('{{ONBOARDING_URL}}', onboarding_url)
            html_content = html_content.replace('{{ onboarding_url }}', onboarding_url)
            html_content = html_content.replace('{{onboarding_url}}', onboarding_url)
            html_content = html_content.replace('{{ expiry_days }}', str(expiry_days))
            html_content = html_content.replace('{{expiry_days}}', str(expiry_days))
            html_content = html_content.replace('{{ logo_html }}', logo_html)
            html_content = html_content.replace('{{logo_html}}', logo_html)

            subject = "You're Invited to Complete Your Client Onboarding"

            print(f"[INVITE] Sending email to {invited_email}...")
            try:
                email_sent = send_email(invited_email, subject, html_content)
                print(f"[INVITE] Email sent: {email_sent}")
            except Exception as email_error:
                print(f"[WARN] Failed to send invitation email: {email_error}")
                print(f"[WARN] Invitation created successfully, but email delivery failed")
                email_sent = False
                # Don't fail the request if email fails - invitation is still created

            return jsonify({
                "success": True,
                "invitation_id": invitation_id,
                "access_token": token,
                "onboarding_url": onboarding_url,
                "invited_email": invited_email,
                "expires_at": expires_at.isoformat(),
                "invited_at": invited_at.isoformat(),
            }), 201

    except Exception as exc:
        print(f"[ERROR] Error sending invitation: {exc}")
        traceback.print_exc()
        return jsonify({"error": str(exc)}), 500


@bp.get("/clients/invitations")
@token_required
def get_invitations(username=None):
    """Get all client invitations for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404

            user_id = user_row['id']

            cursor.execute(
                """
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
                """,
                (user_id,),
            )

            invitations = cursor.fetchall()
            # Convert datetime objects to ISO format strings for JSON serialization
            result = []
            for inv in invitations:
                inv_dict = dict(inv)
                # Convert all datetime fields to ISO strings
                for key, value in inv_dict.items():
                    if isinstance(value, datetime):
                        inv_dict[key] = value.isoformat()
                result.append(inv_dict)
            return jsonify(result), 200

    except Exception as exc:
        print(f"[ERROR] Error fetching invitations: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.post("/clients/invitations/<int:invitation_id>/send-code")
@token_required
def admin_send_verification_code(username=None, invitation_id=None):
    """Admin action: send a fresh email verification code to the invited email"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

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

            if invitation['status'] != 'pending':
                return jsonify({"error": "Invitation already used or cancelled"}), 400

            expires_at_dt = invitation['expires_at']
            if isinstance(expires_at_dt, str):
                expires_at_dt = datetime.fromisoformat(expires_at_dt)
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            if expires_at_dt < datetime.now(timezone.utc):
                return jsonify({"error": "Invitation has expired"}), 400

            if invitation.get('last_code_sent_at'):
                last_sent = invitation['last_code_sent_at']
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
                        (invitation['id'],),
                    )
                    if (cursor.fetchone() or {}).get('count', 0) >= 3:
                        return jsonify({"error": "Too many codes sent in the last hour"}), 429

            verification_code = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
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
                (code_hash, code_expires_at, invitation['id']),
            )

            cursor.execute(
                """
                INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                VALUES (%s, %s, 'code_sent', 'Admin triggered email verification code send')
                """,
                (invitation['id'], invitation['invited_email']),
            )
            conn.commit()

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
            send_email(invitation['invited_email'], subject, html_content)

            return jsonify({"success": True, "message": "Verification code sent"}), 200

    except Exception as exc:
        print(f"[ERROR] Error sending verification code: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.post("/clients/invitations/<int:invitation_id>/resend")
@token_required
def resend_invitation(username=None, invitation_id=None):
    """Resend a client invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT invited_email, access_token, expected_company, expires_at
                FROM client_onboarding_invitations
                WHERE id = %s AND status = 'pending'
                """,
                (invitation_id,),
            )

            invitation = cursor.fetchone()
            if not invitation:
                return jsonify({"error": "Invitation not found or already completed"}), 404

            expires_at = invitation['expires_at']
            expires_at_dt = expires_at if isinstance(expires_at, datetime) else datetime.fromisoformat(str(expires_at))
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)

            if expires_at_dt < datetime.now(timezone.utc):
                new_token = secrets.token_urlsafe(32)
                new_expires_at = datetime.now(timezone.utc) + timedelta(days=7)

                cursor.execute(
                    """
                    UPDATE client_onboarding_invitations
                    SET access_token = %s, expires_at = %s
                    WHERE id = %s
                    """,
                    (new_token, new_expires_at, invitation_id),
                )
                conn.commit()

                token = new_token
                expires_at = new_expires_at
            else:
                token = invitation['access_token']

            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            # Use query parameter instead of hash for better email client compatibility
            onboarding_url = f"{frontend_url}/onboard?token={token}"

            expires_at_dt = expires_at if isinstance(expires_at, datetime) else datetime.fromisoformat(str(expires_at))
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            remaining_days = max(1, (expires_at_dt - datetime.now(timezone.utc)).days)

            template_path = Path(__file__).parent.parent.parent / 'templates' / 'email' / 'client_invitation.html'
            try:
                with open(template_path, 'r', encoding='utf-8') as template_file:
                    html_content = template_file.read()
            except FileNotFoundError:
                print(f"[WARN] Template not found at {template_path}, using fallback")
                logo_html = get_logo_html()
                # Fix: Use proper placeholder format and greeting
                company_placeholder = "{{COMPANY_NAME}}"
                url_placeholder = "{{ONBOARDING_URL}}"
                html_content = f"""
                <html><body style="font-family: 'Poppins', Arial, sans-serif; padding: 40px 20px; background: #000; color: #fff;">
                    <div style="max-width: 600px; margin: 0 auto; background: #1A1A1A; padding: 40px; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3);">
                        <div style="text-align: center; margin-bottom: 30px;">
                            {logo_html}
                        </div>
                        <p style="color: #fff; font-size: 16px;">Hello {company_placeholder}!</p>
                        <p style="color: #B3B3B3; font-size: 16px;">This is a friendly reminder to complete your client onboarding with Khonology. We're excited to start working with you!</p>
                        
                        <div style="background: #0A0A0A; border-left: 3px solid #E9293A; border-radius: 8px; padding: 16px; margin: 24px 0;">
                            <div style="display: flex; align-items: center; margin-bottom: 12px;">
                                <span style="font-size: 20px; margin-right: 8px;">🔒</span>
                                <strong style="color: #E9293A; font-size: 14px; text-transform: uppercase;">SECURITY NOTICE</strong>
                            </div>
                            <p style="color: #B3B3B3; font-size: 14px; line-height: 1.6; margin: 0;">
                                For your security, you'll need to verify your phone number before accessing the onboarding form. This helps protect your information and ensures a secure onboarding process.
                            </p>
                        </div>
                        
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{url_placeholder}" style="background: linear-gradient(135deg, #E9293A 0%, #780A01 100%); color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: 600;">Start Onboarding →</a>
                        </div>
                        <p style="color: #666; font-size: 12px; text-align: center; margin-top: 30px;">© 2025 Khonology. All rights reserved.</p>
                    </div>
                </body></html>
                """

            # Fix: Use the company name directly, not as a comma prefix
            company_name = invitation.get('expected_company') if invitation.get('expected_company') else "there"
            logo_html = get_logo_html()
            
            # Replace placeholders (handle both old and new formats)
            html_content = html_content.replace('{{COMPANY_NAME}}', company_name)
            html_content = html_content.replace('{{ company_name }}', company_name)
            html_content = html_content.replace('{{company_name}}', company_name)
            html_content = html_content.replace('{{ONBOARDING_URL}}', onboarding_url)
            html_content = html_content.replace('{{ onboarding_url }}', onboarding_url)
            html_content = html_content.replace('{{onboarding_url}}', onboarding_url)
            html_content = html_content.replace('{{ expiry_days }}', str(remaining_days))
            html_content = html_content.replace('{{expiry_days}}', str(remaining_days))
            html_content = html_content.replace('{{ logo_html }}', logo_html)
            html_content = html_content.replace('{{logo_html}}', logo_html)

            subject = "Reminder: Complete Your Client Onboarding"
            try:
                email_sent = send_email(invitation['invited_email'], subject, html_content)
                print(f"[RESEND] Email sent: {email_sent}")
            except Exception as email_error:
                print(f"[WARN] Failed to send reminder email: {email_error}")
                print(f"[WARN] Invitation updated successfully, but email delivery failed")
                # Don't fail the request if email fails - invitation is still updated

            return jsonify({"success": True, "message": "Invitation resent"}), 200

    except Exception as exc:
        print(f"[ERROR] Error resending invitation: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.delete("/clients/invitations/<int:invitation_id>")
@token_required
def cancel_invitation(username=None, invitation_id=None):
    """Cancel a pending invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            cursor.execute(
                """
                UPDATE client_onboarding_invitations
                SET status = 'cancelled'
                WHERE id = %s AND status = 'pending'
                """,
                (invitation_id,),
            )

            conn.commit()

            if cursor.rowcount == 0:
                return jsonify({"error": "Invitation not found or already completed"}), 404

            return jsonify({"success": True, "message": "Invitation cancelled"}), 200

    except Exception as exc:
        print(f"[ERROR] Error cancelling invitation: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.get("/clients")
@token_required
def get_clients(username=None):
    """Get all clients for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404

            user_id = user_row['id']

            # Check which columns exist in the clients table
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='clients'
                ORDER BY ordinal_position
            """)
            available_columns = {row[0] for row in cursor.fetchall()}
            
            # Build SELECT query based on available columns
            select_fields = []
            if 'id' in available_columns:
                select_fields.append('id')
            if 'company_name' in available_columns:
                select_fields.append('company_name')
            elif 'email' in available_columns:
                select_fields.append('email as company_name')
            if 'contact_person' in available_columns:
                select_fields.append('contact_person')
            if 'email' in available_columns:
                select_fields.append('email')
            if 'phone' in available_columns:
                select_fields.append('phone')
            if 'industry' in available_columns:
                select_fields.append('industry')
            if 'company_size' in available_columns:
                select_fields.append('company_size')
            if 'location' in available_columns:
                select_fields.append('location')
            if 'business_type' in available_columns:
                select_fields.append('business_type')
            if 'project_needs' in available_columns:
                select_fields.append('project_needs')
            if 'budget_range' in available_columns:
                select_fields.append('budget_range')
            if 'timeline' in available_columns:
                select_fields.append('timeline')
            if 'additional_info' in available_columns:
                select_fields.append('additional_info')
            if 'status' in available_columns:
                select_fields.append('status')
            if 'created_at' in available_columns:
                select_fields.append('created_at')
            if 'updated_at' in available_columns:
                select_fields.append('updated_at')
            
            if not select_fields:
                return jsonify([]), 200
            
            # Build ORDER BY clause - use created_at if available, otherwise id
            order_by = 'created_at DESC' if 'created_at' in available_columns else 'id DESC'
            
            # Ensure user_id is an integer
            if not isinstance(user_id, int):
                try:
                    user_id = int(user_id)
                except (ValueError, TypeError):
                    print(f"[ERROR] Invalid user_id type: {type(user_id)} = {user_id}")
                    return jsonify({"error": "Invalid user ID"}), 400
            
            query = f"""
                SELECT {', '.join(select_fields)}
                FROM clients
                WHERE created_by = %s OR created_by IS NULL
                ORDER BY {order_by}
            """
            
            try:
                cursor.execute(query, (user_id,))
                clients = cursor.fetchall()
            except Exception as query_error:
                print(f"[ERROR] Query execution failed: {type(query_error).__name__}: {query_error}")
                print(f"[ERROR] Query: {query}")
                print(f"[ERROR] User ID: {user_id} (type: {type(user_id)})")
                traceback.print_exc()
                raise
            
            # Convert datetime objects to ISO format strings for JSON serialization
            result = []
            for client in clients:
                client_dict = dict(client)
                # Convert all datetime fields to ISO strings
                for key, value in client_dict.items():
                    if isinstance(value, datetime):
                        client_dict[key] = value.isoformat()
                result.append(client_dict)
            
            return jsonify(result), 200

    except Exception as exc:
        print(f"[ERROR] Error fetching clients: {type(exc).__name__}: {exc}")
        traceback.print_exc()
        return jsonify({"error": str(exc)}), 500


@bp.get("/clients/<int:client_id>")
@token_required
def get_client(username=None, client_id=None):
    """Get a single client's details"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT 
                    id, company_name, contact_person, email, phone,
                    industry, company_size, location, business_type,
                    project_needs, budget_range, timeline, additional_info,
                    status, created_at, updated_at
                FROM clients
                WHERE id = %s
                """,
                (client_id,),
            )

            client = cursor.fetchone()

            if not client:
                return jsonify({"error": "Client not found"}), 404

            return jsonify(dict(client)), 200

    except Exception as exc:
        print(f"[ERROR] Error fetching client: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.patch("/clients/<int:client_id>/status")
@token_required
def update_client_status(username=None, client_id=None):
    """Update client status"""
    try:
        data = request.json or {}
        new_status = data.get('status')

        if not new_status:
            return jsonify({"error": "Status is required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()

            cursor.execute(
                """
                UPDATE clients
                SET status = %s, updated_at = NOW()
                WHERE id = %s
                """,
                (new_status, client_id),
            )

            conn.commit()

            if cursor.rowcount == 0:
                return jsonify({"error": "Client not found"}), 404

            return jsonify({"success": True, "message": "Status updated"}), 200

    except Exception as exc:
        print(f"[ERROR] Error updating client status: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.get("/clients/<int:client_id>/notes")
@token_required
def get_client_notes(username=None, client_id=None):
    """Get all notes for a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT 
                    cn.id, cn.note_text, cn.created_at, cn.updated_at,
                    u.email AS created_by_email, u.full_name AS created_by_name
                FROM client_notes cn
                JOIN users u ON cn.created_by = u.id
                WHERE cn.client_id = %s
                ORDER BY cn.created_at DESC
                """,
                (client_id,),
            )

            notes = cursor.fetchall()
            return jsonify([dict(note) for note in notes]), 200

    except Exception as exc:
        print(f"[ERROR] Error fetching client notes: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.post("/clients/<int:client_id>/notes")
@token_required
def add_client_note(username=None, client_id=None):
    """Add a note to a client"""
    try:
        data = request.json or {}
        note_text = data.get('note_text')

        if not note_text:
            return jsonify({"error": "Note text is required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404

            user_id = user_row['id']

            cursor.execute(
                """
                INSERT INTO client_notes (client_id, note_text, created_by)
                VALUES (%s, %s, %s)
                RETURNING id, created_at
                """,
                (client_id, note_text, user_id),
            )

            result = cursor.fetchone()
            conn.commit()

            return jsonify({
                "success": True,
                "note_id": result['id'],
                "created_at": result['created_at'].isoformat(),
            }), 201

    except Exception as exc:
        print(f"[ERROR] Error adding client note: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.put("/clients/notes/<int:note_id>")
@token_required
def update_client_note(username=None, note_id=None):
    """Update a client note"""
    try:
        data = request.json or {}
        note_text = data.get('note_text')

        if not note_text:
            return jsonify({"error": "Note text is required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()

            cursor.execute(
                """
                UPDATE client_notes
                SET note_text = %s, updated_at = NOW()
                WHERE id = %s
                """,
                (note_text, note_id),
            )

            conn.commit()

            if cursor.rowcount == 0:
                return jsonify({"error": "Note not found"}), 404

            return jsonify({"success": True, "message": "Note updated"}), 200

    except Exception as exc:
        print(f"[ERROR] Error updating client note: {exc}")
        return jsonify({"error": str(exc)}), 500


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

    except Exception as exc:
        print(f"[ERROR] Error deleting client note: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.post("/clients/onboard/<token>/send-code")
def public_send_verification_code(token):
    """Public endpoint: send verification code using invitation token (no auth required)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT id, invited_email, access_token, status, expires_at, last_code_sent_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
                """,
                (token,),
            )
            invitation = cursor.fetchone()
            if not invitation:
                return jsonify({"error": "Invalid invitation token"}), 404

            if invitation['status'] != 'pending':
                return jsonify({"error": "Invitation already used or cancelled"}), 400

            expires_at_dt = invitation['expires_at']
            if isinstance(expires_at_dt, str):
                expires_at_dt = datetime.fromisoformat(expires_at_dt)
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            if expires_at_dt < datetime.now(timezone.utc):
                return jsonify({"error": "Invitation has expired"}), 400

            # Rate limiting check
            if invitation.get('last_code_sent_at'):
                last_sent = invitation['last_code_sent_at']
                if isinstance(last_sent, str):
                    last_sent = datetime.fromisoformat(last_sent)
                last_sent = last_sent.astimezone(timezone.utc)
                seconds_since = (datetime.now(timezone.utc) - last_sent).total_seconds()
                if seconds_since < 60:  # 1 minute cooldown
                    return jsonify({"error": "Please wait before requesting another code"}), 429

            verification_code = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
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
                (code_hash, code_expires_at, invitation['id']),
            )

            conn.commit()

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
            send_email(invitation['invited_email'], subject, html_content)

            return jsonify({"success": True, "message": "Verification code sent"}), 200

    except Exception as exc:
        print(f"[ERROR] Error sending verification code: {exc}")
        traceback.print_exc()
        return jsonify({"error": str(exc)}), 500

@bp.post("/clients/onboard/<token>/verify-code")
def public_verify_code(token):
    """Public endpoint: verify code using invitation token (no auth required)"""
    try:
        data = request.json or {}
        code = data.get('code')
        email = data.get('email')
        
        if not code or len(code) != 6:
            return jsonify({"error": "Invalid verification code format"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT id, invited_email, verification_code_hash, code_expires_at, status
                FROM client_onboarding_invitations
                WHERE access_token = %s
                """,
                (token,),
            )
            invitation = cursor.fetchone()
            if not invitation:
                return jsonify({"error": "Invalid invitation token"}), 404

            if invitation['status'] != 'pending':
                return jsonify({"error": "Invitation already used or cancelled"}), 400

            if email and email.lower() != invitation['invited_email'].lower():
                return jsonify({"error": "Email does not match invitation"}), 400

            if not invitation.get('verification_code_hash'):
                return jsonify({"error": "No verification code found. Please request one first."}), 400

            code_hash = hashlib.sha256(code.encode()).hexdigest()
            if code_hash != invitation['verification_code_hash']:
                return jsonify({"error": "Invalid verification code"}), 400

            code_expires_at = invitation['code_expires_at']
            if isinstance(code_expires_at, str):
                code_expires_at = datetime.fromisoformat(code_expires_at)
            code_expires_at = code_expires_at.astimezone(timezone.utc)
            if code_expires_at < datetime.now(timezone.utc):
                return jsonify({"error": "Verification code has expired"}), 400

            # Mark email as verified
            cursor.execute(
                """
                UPDATE client_onboarding_invitations
                SET email_verified_at = NOW()
                WHERE id = %s
                """,
                (invitation['id'],),
            )
            conn.commit()

            return jsonify({"success": True, "message": "Email verified successfully"}), 200

    except Exception as exc:
        print(f"[ERROR] Error verifying code: {exc}")
        traceback.print_exc()
        return jsonify({"error": str(exc)}), 500

@bp.get("/onboard/<token>")
def get_onboarding_info(token):
    """Get invitation info for onboarding (no auth required - uses token)"""
    try:
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute(
                """
                SELECT 
                    id, invited_email, expected_company, status, expires_at,
                    invited_at, email_verified_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
                """,
                (token,)
            )
            
            invitation = cursor.fetchone()
            if not invitation:
                return jsonify({"error": "Invalid or expired invitation token"}), 404
            
            # Check if expired
            expires_at = invitation['expires_at']
            if expires_at:
                # Ensure both datetimes are timezone-aware
                if isinstance(expires_at, str):
                    expires_at = datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
                elif expires_at.tzinfo is None:
                    # If timezone-naive, assume UTC
                    expires_at = expires_at.replace(tzinfo=timezone.utc)
                else:
                    expires_at = expires_at.astimezone(timezone.utc)
                
                if datetime.now(timezone.utc) > expires_at:
                    return jsonify({"error": "Invitation has expired"}), 403
            
            # Check if already completed
            if invitation['status'] != 'pending':
                return jsonify({"error": "This invitation has already been used"}), 400
            
            # Convert datetime to ISO format
            result = dict(invitation)
            for key, value in result.items():
                if isinstance(value, datetime):
                    result[key] = value.isoformat()
            
            return jsonify(result), 200
            
    except Exception as exc:
        print(f"[ERROR] Error getting onboarding info: {exc}")
        traceback.print_exc()
        return jsonify({"error": str(exc)}), 500

@bp.post("/onboard/<token>")
def complete_onboarding(token):
    """Complete client onboarding (no auth required - uses token)"""
    try:
        data = request.json or {}
        
        # Extract form data
        company_name = data.get('company_name')
        contact_person = data.get('contact_person')
        email = data.get('email')
        phone = data.get('phone')
        industry = data.get('industry')
        company_size = data.get('company_size')
        location = data.get('location')
        business_type = data.get('business_type')
        project_needs = data.get('project_needs')
        budget_range = data.get('budget_range')
        timeline = data.get('timeline')
        additional_info = data.get('additional_info')
        
        if not company_name or not email:
            return jsonify({"error": "Company name and email are required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token and get invitation
            cursor.execute(
                """
                SELECT id, invited_email, expected_company, invited_by, status, expires_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
                """,
                (token,)
            )
            
            invitation = cursor.fetchone()
            if not invitation:
                return jsonify({"error": "Invalid or expired invitation token"}), 404
            
            # Check if expired
            expires_at = invitation['expires_at']
            if expires_at:
                # Ensure both datetimes are timezone-aware
                if isinstance(expires_at, str):
                    expires_at = datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
                elif expires_at.tzinfo is None:
                    # If timezone-naive, assume UTC
                    expires_at = expires_at.replace(tzinfo=timezone.utc)
                else:
                    expires_at = expires_at.astimezone(timezone.utc)
                
                if datetime.now(timezone.utc) > expires_at:
                    return jsonify({"error": "Invitation has expired"}), 403
            
            # Check if already completed
            if invitation['status'] != 'pending':
                return jsonify({"error": "This invitation has already been used"}), 400
            
            # Verify email matches invitation
            if email.lower() != invitation['invited_email'].lower():
                return jsonify({"error": "Email does not match the invitation"}), 400
            
            # Create or update client record
            cursor.execute(
                """
                INSERT INTO clients (
                    company_name, contact_person, email, phone, industry,
                    company_size, location, business_type, project_needs,
                    budget_range, timeline, additional_info, status,
                    onboarding_token, created_by
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET
                    company_name = EXCLUDED.company_name,
                    contact_person = EXCLUDED.contact_person,
                    phone = EXCLUDED.phone,
                    industry = EXCLUDED.industry,
                    company_size = EXCLUDED.company_size,
                    location = EXCLUDED.location,
                    business_type = EXCLUDED.business_type,
                    project_needs = EXCLUDED.project_needs,
                    budget_range = EXCLUDED.budget_range,
                    timeline = EXCLUDED.timeline,
                    additional_info = EXCLUDED.additional_info,
                    updated_at = CURRENT_TIMESTAMP
                RETURNING id, company_name, email, created_at
                """,
                (
                    company_name, contact_person, email, phone, industry,
                    company_size, location, business_type, project_needs,
                    budget_range, timeline, additional_info, 'active',
                    token, invitation['invited_by']
                )
            )
            
            client = cursor.fetchone()
            client_id = client['id']
            
            # Mark invitation as completed
            cursor.execute(
                """
                UPDATE client_onboarding_invitations
                SET status = 'completed', completed_at = CURRENT_TIMESTAMP, client_id = %s
                WHERE id = %s
                """,
                (client_id, invitation['id'])
            )
            
            conn.commit()
            
            # Convert datetime to ISO format
            result = dict(client)
            for key, value in result.items():
                if isinstance(value, datetime):
                    result[key] = value.isoformat()
            
            return jsonify({
                "success": True,
                "message": "Onboarding completed successfully",
                "client": result
            }), 201
            
    except Exception as exc:
        print(f"[ERROR] Error completing onboarding: {exc}")
        traceback.print_exc()
        return jsonify({"error": str(exc)}), 500

@bp.get("/clients/<int:client_id>/proposals")
@token_required
def get_client_linked_proposals(username=None, client_id=None):
    """Get all proposals linked to a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute(
                """
                SELECT 
                    p.id, p.title, p.status, p.created_at,
                    cp.relationship_type, cp.linked_at,
                    u.email AS linked_by_email
                FROM client_proposals cp
                JOIN proposals p ON cp.proposal_id = p.id
                JOIN users u ON cp.linked_by = u.id
                WHERE cp.client_id = %s
                ORDER BY cp.linked_at DESC
                """,
                (client_id,),
            )

            proposals = cursor.fetchall()
            return jsonify([dict(prop) for prop in proposals]), 200

    except Exception as exc:
        print(f"[ERROR] Error fetching client proposals: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.post("/clients/<int:client_id>/proposals")
@token_required
def link_client_proposal(username=None, client_id=None):
    """Link a proposal to a client"""
    try:
        data = request.json or {}
        proposal_id = data.get('proposal_id')
        relationship_type = data.get('relationship_type', 'primary')

        if not proposal_id:
            return jsonify({"error": "Proposal ID is required"}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404

            user_id = user_row['id']

            cursor.execute(
                """
                INSERT INTO client_proposals (client_id, proposal_id, relationship_type, linked_by)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (client_id, proposal_id) DO NOTHING
                RETURNING id
                """,
                (client_id, proposal_id, relationship_type, user_id),
            )

            result = cursor.fetchone()
            conn.commit()

            if not result:
                return jsonify({"error": "Proposal already linked to this client"}), 400

            return jsonify({"success": True, "link_id": result['id']}), 201

    except Exception as exc:
        print(f"[ERROR] Error linking proposal to client: {exc}")
        return jsonify({"error": str(exc)}), 500


@bp.delete("/clients/<int:client_id>/proposals/<int:proposal_id>")
@token_required
def unlink_client_proposal(username=None, client_id=None, proposal_id=None):
    """Unlink a proposal from a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            cursor.execute(
                """
                DELETE FROM client_proposals
                WHERE client_id = %s AND proposal_id = %s
                """,
                (client_id, proposal_id),
            )

            conn.commit()

            if cursor.rowcount == 0:
                return jsonify({"error": "Link not found"}), 404

            return jsonify({"success": True, "message": "Proposal unlinked"}), 200

    except Exception as exc:
        print(f"[ERROR] Error unlinking proposal: {exc}")
        return jsonify({"error": str(exc)}), 500


