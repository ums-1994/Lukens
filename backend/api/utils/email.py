"""Email sending utilities"""
import os
import smtplib
import traceback
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path
import base64
import requests

# Cloudinary for logo hosting
try:
    import cloudinary  # type: ignore
    import cloudinary.uploader  # type: ignore
    import cloudinary.config  # type: ignore
    CLOUDINARY_AVAILABLE = True
except ImportError:
    CLOUDINARY_AVAILABLE = False


def send_email(to_email, subject, html_content):
    """Send email.

    Uses Brevo (Sendinblue) HTTP API when BREVO_API_KEY is configured,
    and falls back to SMTP settings otherwise (useful for local dev).
    """
    try:
        print(f"[EMAIL] Attempting to send email to {to_email}")

        # Prefer Brevo HTTP API if available (works on Render free tier)
        brevo_api_key = os.getenv('BREVO_API_KEY')
        if brevo_api_key:
            try:
                brevo_sender_email = os.getenv('BREVO_SENDER_EMAIL') or os.getenv('SMTP_FROM_EMAIL') or os.getenv('SMTP_USER')
                brevo_sender_name = os.getenv('BREVO_SENDER_NAME') or os.getenv('SMTP_FROM_NAME', 'Khonology')

                if not brevo_sender_email:
                    print('[ERROR] Brevo sender email is not configured (BREVO_SENDER_EMAIL or SMTP_FROM_EMAIL)')
                else:
                    print(f"[EMAIL] Using Brevo API with sender {brevo_sender_name} <{brevo_sender_email}>")
                    url = 'https://api.brevo.com/v3/smtp/email'
                    headers = {
                        'accept': 'application/json',
                        'content-type': 'application/json',
                        'api-key': brevo_api_key,
                    }
                    payload = {
                        'sender': {
                            'name': brevo_sender_name,
                            'email': brevo_sender_email,
                        },
                        'to': [{'email': to_email}],
                        'subject': subject,
                        'htmlContent': html_content,
                    }
                    response = requests.post(url, headers=headers, json=payload, timeout=10)
                    if response.status_code in (200, 201, 202):
                        print(f"[SUCCESS] Brevo email sent to {to_email} (status {response.status_code})")
                        return True
                    else:
                        print(f"[ERROR] Brevo email failed: {response.status_code} - {response.text}")
            except Exception as brevo_exc:
                print(f"[ERROR] Brevo API error: {brevo_exc}")
                traceback.print_exc()
                # Fall through to SMTP fallback

        # SMTP fallback (useful for local dev / non-Render environments)
        smtp_host = os.getenv('SMTP_HOST')
        smtp_port = int(os.getenv('SMTP_PORT', '587'))
        smtp_user = os.getenv('SMTP_USER')
        smtp_pass = os.getenv('SMTP_PASS')
        smtp_from_email = os.getenv('SMTP_FROM_EMAIL', smtp_user)
        smtp_from_name = os.getenv('SMTP_FROM_NAME', 'Khonology')

        print(f"[EMAIL] SMTP Config - Host: {smtp_host}, Port: {smtp_port}, User: {smtp_user}")
        print(f"[EMAIL] From: {smtp_from_name} <{smtp_from_email}>")

        if not all([smtp_host, smtp_user, smtp_pass]):
            print('[ERROR] SMTP configuration incomplete')
            print(f"[ERROR] Missing: Host={smtp_host}, User={smtp_user}, Pass={'SET' if smtp_pass else 'NOT SET'}")
            return False

        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = f"{smtp_from_name} <{smtp_from_email}>"
        msg['To'] = to_email

        html_part = MIMEText(html_content, 'html')
        msg.attach(html_part)

        print('[EMAIL] Connecting to SMTP server...')
        try:
            with smtplib.SMTP(smtp_host, smtp_port, timeout=10) as server:
                print('[EMAIL] Starting TLS...')
                server.starttls()

                print('[EMAIL] Logging in...')
                try:
                    server.login(smtp_user, smtp_pass)
                except smtplib.SMTPAuthenticationError as auth_error:
                    error_code = getattr(auth_error, 'smtp_code', None)
                    error_msg = str(auth_error)
                    print(f"[ERROR] SMTP Authentication failed (Code: {error_code})")
                    print(f"[ERROR] Error: {error_msg}")
                    if smtp_host and ('gmail.com' in smtp_host.lower() or 'google' in smtp_host.lower()):
                        print("[HELP] Gmail authentication troubleshooting:")
                        print("  1. Enable 2-Step Verification")
                        print("  2. Generate an App Password")
                        print("  3. Use the App Password instead of your normal password")
                    else:
                        print("[HELP] Check SMTP username, password, host, port")
                    raise

                print('[EMAIL] Sending message...')
                server.send_message(msg)

        except (smtplib.SMTPException, OSError, ConnectionError) as smtp_error:
            print(f"[ERROR] SMTP connection error: {smtp_error}")
            traceback.print_exc()
            return False

        print(f"[SUCCESS] Email sent to {to_email}")
        return True

    except Exception as exc:
        print(f"[ERROR] Unexpected error while sending email: {exc}")
        traceback.print_exc()
        return False


# ----------------------------------------------------------
# PASSWORD RESET EMAIL
# ----------------------------------------------------------
def send_password_reset_email(email, reset_token):
    """Send password reset email"""
    frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8080')
    reset_link = f"{frontend_url}/verify.html?token={reset_token}"

    subject = "Reset Your Password"
    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
            <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 10px;">
                <h1 style="color: #333;">Password Reset Request</h1>
                <p style="color: #666; font-size: 16px;">Click the link below to reset your password:</p>
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{reset_link}" style="background-color: #007bff; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-size: 16px;">
                        Reset Password
                    </a>
                </div>
                <p style="color: #999; font-size: 12px;">If you didn't request this, you can ignore this email.</p>
            </div>
        </body>
    </html>
    """
    return send_email(email, subject, html_content)


# ----------------------------------------------------------
# EMAIL VERIFICATION EMAIL
# ----------------------------------------------------------
def send_verification_email(email, verification_token, username=None):
    """Send email verification email"""
    frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8080')
    verification_link = f"{frontend_url}/verify-email?token={verification_token}"

    subject = "Verify Your Email Address"
    html_content = f"""
    <html>
        <body style="font-family: 'Poppins', Arial, sans-serif; background:#000; color:#fff; padding:24px;">
            <div style="max-width:600px;margin:0 auto;background:#1A1A1A;border-radius:16px;border:1px solid rgba(233,41,58,0.3);padding:32px;">
                <div style="text-align:center;margin-bottom:24px;">{get_logo_html()}</div>
                <h1 style="color:#fff;font-size:24px;margin-bottom:16px;">Verify Your Email Address</h1>
                <p style="color:#B3B3B3;font-size:16px;line-height:1.6;">
                    {'Hi ' + username + ',' if username else 'Hi,'}<br><br>
                    Please verify your email by clicking the button below.
                </p>
                <div style="text-align:center;margin:30px 0;">
                    <a href="{verification_link}" style="background-color:#E9293A;color:#fff;padding:14px 32px;text-decoration:none;border-radius:8px;display:inline-block;font-size:16px;font-weight:600;">
                        Verify Email Address
                    </a>
                </div>
                <p style="color:#666;font-size:12px;line-height:1.6;">
                    Or copy this link:<br>
                    <span style="color:#B3B3B3;word-break:break-all;">{verification_link}</span>
                </p>
            </div>
        </body>
    </html>
    """
    return send_email(email, subject, html_content)


# ----------------------------------------------------------
# LOGO EMBEDDING
# ----------------------------------------------------------
def get_logo_html():
    """Get HTML for Khonology logo (Cloudinary URL, env URL, or base64 fallback)"""
    logo_url = os.getenv('KHONOLOGY_LOGO_URL', '')
    if logo_url:
        return f'<img src="{logo_url}" alt="Khonology" style="max-width:200px; height:auto; margin:0 auto;" />'

    cloudinary_public_id = os.getenv('KHONOLOGY_LOGO_CLOUDINARY_ID', '')
    if cloudinary_public_id and CLOUDINARY_AVAILABLE:
        try:
            cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME', '')
            if cloud_name:
                url = f"https://res.cloudinary.com/{cloud_name}/image/upload/{cloudinary_public_id}"
                return f'<img src="{url}" alt="Khonology" style="max-width:200px; height:auto; margin:0 auto;" />'
        except Exception as exc:
            print(f"[WARN] Cloudinary error: {exc}")

    # Base64 fallback
    logo_path = Path(__file__).resolve().parent.parent.parent / 'frontend_flutter' / 'assets' / 'images' / '2026.png'
    if logo_path.exists():
        try:
            with open(logo_path, 'rb') as f:
                encoded = base64.b64encode(f.read()).decode('utf-8')
                return f'<img src="data:image/png;base64,{encoded}" alt="Khonology" style="max-width:200px; height:auto; margin:0 auto;" />'
        except Exception as exc:
            print(f"[WARN] Base64 logo error: {exc}")

    # Text fallback
    return "<h1 style=\"color:#fff;text-align:center;font-family:'Poppins';\">✕ Khonology</h1>"
