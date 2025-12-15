"""
Public client onboarding routes (no authentication required)
"""
from flask import Blueprint, request, jsonify
import secrets
import traceback
import hashlib
from datetime import datetime, timedelta, timezone
import psycopg2.extras
from api.utils.database import get_db_connection
from api.utils.email import send_email

bp = Blueprint('onboarding', __name__)

@bp.post("/onboard/<token>/verify-email")
def send_verification_code(token):
    """Send verification code to email (public endpoint)"""
    try:
        data = request.json
        email = data.get('email')
        
        if not email:
            return jsonify({"error": "Email is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Validate token and get invitation
            cursor.execute("""
                SELECT id, invited_email, status, expires_at, 
                       last_code_sent_at, verification_attempts
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                return jsonify({"error": "Invalid invitation link"}), 404
            
            if invitation['status'] != 'pending':
                return jsonify({"error": "This invitation has already been used"}), 400
            
            expires_at_dt = invitation['expires_at']
            if isinstance(expires_at_dt, str):
                expires_at_dt = datetime.fromisoformat(expires_at_dt)
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            
            if expires_at_dt < datetime.now(timezone.utc):
                return jsonify({"error": "This invitation has expired"}), 400
            
            # Verify email matches invitation
            if email.lower() != invitation['invited_email'].lower():
                return jsonify({"error": "Email does not match the invitation"}), 400
            
            # Rate limiting: max 3 codes per hour
            if invitation['last_code_sent_at']:
                last_sent = invitation['last_code_sent_at']
                if isinstance(last_sent, str):
                    last_sent = datetime.fromisoformat(last_sent)
                last_sent = last_sent.astimezone(timezone.utc)
                time_since_last = datetime.now(timezone.utc) - last_sent
                if time_since_last.total_seconds() < 3600:  # 1 hour
                    # Check how many codes sent in last hour
                    cursor.execute("""
                        SELECT COUNT(*) as count
                        FROM email_verification_events
                        WHERE invitation_id = %s 
                        AND event_type = 'code_sent'
                        AND created_at > NOW() - INTERVAL '1 hour'
                    """, (invitation['id'],))
                    recent_sends = cursor.fetchone()['count']
                    if recent_sends >= 3:
                        return jsonify({"error": "Too many verification codes sent. Please try again later."}), 429
            
            # Generate 6-digit code
            verification_code = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
            
            # Hash the code
            code_hash = hashlib.sha256(verification_code.encode()).hexdigest()
            code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
            
            # Store hashed code
            cursor.execute("""
                UPDATE client_onboarding_invitations
                SET verification_code_hash = %s,
                    code_expires_at = %s,
                    last_code_sent_at = NOW(),
                    verification_attempts = 0
                WHERE id = %s
            """, (code_hash, code_expires_at, invitation['id']))
            
            # Log event
            cursor.execute("""
                INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                VALUES (%s, %s, 'code_sent', 'Verification code sent')
            """, (invitation['id'], email))
            
            conn.commit()
            
            # Send email with code
            subject = "Your Khonology Verification Code"
            html_content = f"""
            <html>
            <head>
                <style>
                    body {{ font-family: 'Poppins', Arial, sans-serif; background-color: #000000; padding: 40px 20px; }}
                    .container {{ max-width: 600px; margin: 0 auto; background-color: #1A1A1A; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3); padding: 40px; }}
                    .code-box {{ background-color: #2A2A2A; border: 2px solid #E9293A; border-radius: 12px; padding: 24px; text-align: center; margin: 30px 0; }}
                    .code {{ font-size: 36px; font-weight: bold; color: #E9293A; letter-spacing: 8px; font-family: 'Courier New', monospace; }}
                    .footer {{ color: #666; font-size: 12px; text-align: center; margin-top: 30px; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <h1 style="color: #FFFFFF; text-align: center; margin-bottom: 20px;">Email Verification</h1>
                    <p style="color: #B3B3B3; font-size: 16px; line-height: 1.6;">
                        Hello! Please use the verification code below to complete your onboarding:
                    </p>
                    <div class="code-box">
                        <div class="code">{verification_code}</div>
                    </div>
                    <p style="color: #B3B3B3; font-size: 14px; line-height: 1.6;">
                        This code will expire in 15 minutes. If you didn't request this code, please ignore this email.
                    </p>
                    <div class="footer">
                        <p>© 2025 Khonology. All rights reserved.</p>
                    </div>
                </div>
            </body>
            </html>
            """
            
            send_email(email, subject, html_content)
            
            return jsonify({
                "success": True,
                "message": "Verification code sent to your email"
            }), 200
            
    except Exception as e:
        print(f"[ERROR] Error sending verification code: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@bp.post("/onboard/<token>/verify-code")
def verify_email_code(token):
    """Verify email verification code (public endpoint)"""
    try:
        data = request.json
        code = data.get('code')
        email = data.get('email')
        
        if not code or not email:
            return jsonify({"error": "Code and email are required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation
            cursor.execute("""
                SELECT id, invited_email, verification_code_hash, code_expires_at,
                       verification_attempts, status, expires_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                return jsonify({"error": "Invalid invitation link"}), 404
            
            if invitation['status'] != 'pending':
                return jsonify({"error": "This invitation has already been used"}), 400
            
            expires_at_dt = invitation['expires_at']
            if isinstance(expires_at_dt, str):
                expires_at_dt = datetime.fromisoformat(expires_at_dt)
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            
            if expires_at_dt < datetime.now(timezone.utc):
                return jsonify({"error": "This invitation has expired"}), 400
            
            # Verify email matches
            if email.lower() != invitation['invited_email'].lower():
                return jsonify({"error": "Email does not match the invitation"}), 400
            
            # Check if code exists
            if not invitation['verification_code_hash']:
                return jsonify({"error": "No verification code found. Please request a new code."}), 400
            
            # Check if code expired
            if invitation['code_expires_at']:
                code_expires_at_dt = invitation['code_expires_at']
                if isinstance(code_expires_at_dt, str):
                    code_expires_at_dt = datetime.fromisoformat(code_expires_at_dt)
                code_expires_at_dt = code_expires_at_dt.astimezone(timezone.utc)
                
                if code_expires_at_dt < datetime.now(timezone.utc):
                    cursor.execute("""
                        INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                        VALUES (%s, %s, 'code_expired', 'Verification code expired')
                    """, (invitation['id'], email))
                    conn.commit()
                    return jsonify({"error": "Verification code has expired. Please request a new one."}), 400
            
            # Check attempts (max 5 attempts)
            if invitation['verification_attempts'] and invitation['verification_attempts'] >= 5:
                cursor.execute("""
                    INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                    VALUES (%s, %s, 'rate_limited', 'Too many verification attempts')
                """, (invitation['id'], email))
                conn.commit()
                return jsonify({"error": "Too many failed attempts. Please request a new code."}), 429
            
            # Verify code
            code_hash = hashlib.sha256(code.encode()).hexdigest()
            
            if code_hash != invitation['verification_code_hash']:
                # Increment attempts
                cursor.execute("""
                    UPDATE client_onboarding_invitations
                    SET verification_attempts = COALESCE(verification_attempts, 0) + 1
                    WHERE id = %s
                """, (invitation['id'],))
                
                cursor.execute("""
                    INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                    VALUES (%s, %s, 'verify_failed', 'Invalid verification code')
                """, (invitation['id'], email))
                conn.commit()
                
                remaining = 5 - (invitation['verification_attempts'] or 0) - 1
                return jsonify({
                    "error": "Invalid verification code",
                    "remaining_attempts": max(0, remaining)
                }), 400
            
            # Code is valid - mark email as verified
            cursor.execute("""
                UPDATE client_onboarding_invitations
                SET email_verified_at = NOW(),
                    verification_code_hash = NULL,
                    code_expires_at = NULL,
                    verification_attempts = 0
                WHERE id = %s
            """, (invitation['id'],))
            
            cursor.execute("""
                INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                VALUES (%s, %s, 'code_verified', 'Email successfully verified')
            """, (invitation['id'], email))
            
            conn.commit()
            
            return jsonify({
                "success": True,
                "message": "Email verified successfully"
            }), 200
            
    except Exception as e:
        print(f"[ERROR] Error verifying code: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@bp.get("/onboard/<token>")
def get_onboarding_form(token):
    """Get onboarding form details by token (public endpoint)"""
    try:
        print(f"[ONBOARD] Getting onboarding form for token: {token[:20]}...")
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT id, invited_email, expected_company, status, expires_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                print(f"[ONBOARD] ❌ No invitation found for token: {token[:20]}...")
                return jsonify({"error": "Invalid invitation link"}), 404
            
            print(f"[ONBOARD] Found invitation: ID={invitation['id']}, Email={invitation['invited_email']}, Status={invitation['status']}")
            
            if invitation['status'] != 'pending':
                print(f"[ONBOARD] ❌ Invitation already used: Status={invitation['status']}")
                return jsonify({"error": "This invitation has already been used"}), 400
            
            expires_at_dt = invitation['expires_at']
            if isinstance(expires_at_dt, str):
                expires_at_dt = datetime.fromisoformat(expires_at_dt)
            if hasattr(expires_at_dt, 'astimezone'):
                expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            
            if expires_at_dt < datetime.now(timezone.utc):
                print(f"[ONBOARD] ❌ Invitation expired: {expires_at_dt}")
                return jsonify({"error": "This invitation has expired"}), 400
            
            # Check if email is verified
            cursor.execute("""
                SELECT email_verified_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            verified = cursor.fetchone()
            is_verified = verified and verified['email_verified_at']
            
            print(f"[ONBOARD] ✅ Returning form data: Email={invitation['invited_email']}, Verified={bool(is_verified)}")
            
            return jsonify({
                "invited_email": invitation['invited_email'],
                "expected_company": invitation['expected_company'],
                "expires_at": invitation['expires_at'].isoformat() if hasattr(invitation['expires_at'], 'isoformat') else str(invitation['expires_at']),
                "email_verified": bool(is_verified)
            }), 200
            
    except Exception as e:
        print(f"[ONBOARD] ❌ Error getting onboarding form: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@bp.post("/onboard/<token>")
def submit_onboarding(token):
    """Submit client onboarding form (public endpoint)"""
    try:
        data = request.json
        
        # Required fields
        required_fields = ['company_name', 'contact_person', 'email', 'phone']
        for field in required_fields:
            if not data.get(field):
                return jsonify({"error": f"Missing required field: {field}"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Validate token
            cursor.execute("""
                SELECT id, invited_by, status, expires_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                return jsonify({"error": "Invalid invitation link"}), 404
            
            if invitation['status'] != 'pending':
                return jsonify({"error": "This invitation has already been used"}), 400
            
            expires_at_dt = invitation['expires_at']
            if isinstance(expires_at_dt, str):
                expires_at_dt = datetime.fromisoformat(expires_at_dt)
            expires_at_dt = expires_at_dt.astimezone(timezone.utc)
            
            if expires_at_dt < datetime.now(timezone.utc):
                return jsonify({"error": "This invitation has expired"}), 400
            
            # Check if email is verified
            cursor.execute("""
                SELECT email_verified_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            verified = cursor.fetchone()
            if not verified or not verified['email_verified_at']:
                return jsonify({"error": "Email must be verified before submitting the form"}), 403
            
            # Insert client
            cursor.execute("""
                INSERT INTO clients (
                    company_name, contact_person, email, phone,
                    industry, company_size, location, business_type,
                    project_needs, budget_range, timeline, additional_info,
                    status, onboarding_token, created_by
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'active', %s, %s
                )
                RETURNING id
            """, (
                data.get('company_name'),
                data.get('contact_person'),
                data.get('email'),
                data.get('phone'),
                data.get('industry'),
                data.get('company_size'),
                data.get('location'),
                data.get('business_type'),
                data.get('project_needs'),
                data.get('budget_range'),
                data.get('timeline'),
                data.get('additional_info'),
                token,
                invitation['invited_by']
            ))
            
            client_id = cursor.fetchone()['id']
            
            # Update invitation
            cursor.execute("""
                UPDATE client_onboarding_invitations
                SET status = 'completed', completed_at = NOW(), client_id = %s
                WHERE id = %s
            """, (client_id, invitation['id']))
            
            conn.commit()
            
            return jsonify({
                "success": True,
                "message": "Onboarding completed successfully",
                "client_id": client_id
            }), 201
            
    except Exception as e:
        print(f"[ERROR] Error submitting onboarding: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

