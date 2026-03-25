"""
Email sending utilities - SendGrid only
"""
import os
import traceback
import re
from pathlib import Path
import base64
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import parseaddr, formataddr

# SendGrid SDK
try:
    from sendgrid import SendGridAPIClient
    from sendgrid.helpers.mail import Mail, Email, Content
    SENDGRID_AVAILABLE = True
except ImportError:
    SENDGRID_AVAILABLE = False
    print("[WARN] SendGrid SDK not installed. Install with: pip install sendgrid")

# Cloudinary for logo hosting
try:
    import cloudinary  # type: ignore
    import cloudinary.uploader  # type: ignore
    import cloudinary.config  # type: ignore
    CLOUDINARY_AVAILABLE = True
except ImportError:
    CLOUDINARY_AVAILABLE = False


def send_email_via_sendgrid(to_email, subject, html_content):
    """Send email using SendGrid API"""
    try:
        sendgrid_api_key = os.getenv('SENDGRID_API_KEY')
        sendgrid_from_email = os.getenv('SENDGRID_FROM_EMAIL')
        sendgrid_from_name = os.getenv('SENDGRID_FROM_NAME', 'Khonology')

        def _extract_email(raw: str | None) -> str:
            if not raw:
                return ''
            raw = str(raw).strip()
            _, parsed = parseaddr(raw)
            parsed = (parsed or '').strip()
            if parsed and re.fullmatch(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", parsed):
                return parsed
            m = re.search(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", raw)
            return (m.group(0).strip() if m else '')

        # Strip whitespace and newlines from API key (common issue with environment variables)
        if sendgrid_api_key:
            sendgrid_api_key = sendgrid_api_key.strip()
        
        if not sendgrid_api_key:
            print('[ERROR] SENDGRID_API_KEY not set')
            return False

        if not sendgrid_from_email:
            print('[ERROR] SENDGRID_FROM_EMAIL not set')
            return False

        safe_to_email = _extract_email(to_email)
        if not safe_to_email:
            print(f"[ERROR] Invalid recipient email for SendGrid: {to_email}")
            return False

        print(f"[EMAIL] Using SendGrid to send email to {safe_to_email}")
        print(f"[EMAIL] From: {sendgrid_from_name} <{sendgrid_from_email}>")

        message = Mail(
            from_email=Email(sendgrid_from_email, sendgrid_from_name),
            to_emails=safe_to_email,
            subject=subject,
            html_content=html_content
        )

        sg = SendGridAPIClient(sendgrid_api_key)
        
        try:
            response = sg.send(message)
            
            if response.status_code in [200, 201, 202]:
                print(f"[SUCCESS] Email sent via SendGrid to {safe_to_email} (Status: {response.status_code})")
                return True
            else:
                # Get detailed error information
                error_body = response.body.decode('utf-8') if hasattr(response.body, 'decode') else str(response.body)
                print(f"[ERROR] SendGrid returned status {response.status_code}")
                print(f"[ERROR] Response: {error_body}")
                
                if response.status_code == 401:
                    print("\n[HELP] SendGrid 401 Unauthorized - Possible causes:")
                    print("  1. Invalid API key - Check SENDGRID_API_KEY in your .env file")
                    print("  2. API key doesn't have 'Mail Send' permission")
                    print("  3. Sender email not verified in SendGrid")
                    print("     → Go to: https://app.sendgrid.com/settings/sender_auth/senders")
                    print("     → Verify: " + sendgrid_from_email)
                    print("  4. API key might be revoked or expired")
                    print("     → Check: https://app.sendgrid.com/settings/api_keys")
                
                return False
                
        except Exception as send_error:
            # Handle SendGrid-specific exceptions
            error_msg = str(send_error)
            print(f"[ERROR] SendGrid API error: {error_msg}")
            
            if "401" in error_msg or "Unauthorized" in error_msg:
                print("\n[HELP] SendGrid 401 Unauthorized - Troubleshooting:")
                print("  1. Verify your API key is correct:")
                print(f"     → Current key starts with: {sendgrid_api_key[:10]}...")
                print("  2. Check API key permissions:")
                print("     → Go to: https://app.sendgrid.com/settings/api_keys")
                print("     → Ensure it has 'Mail Send' permission")
                print("  3. Verify sender email is authenticated:")
                print("     → Go to: https://app.sendgrid.com/settings/sender_auth/senders")
                print(f"     → Verify: {sendgrid_from_email}")
                print("  4. If using a new API key, wait a few minutes for it to activate")
                print("  5. Try creating a new API key if the current one doesn't work")
            
            traceback.print_exc()
            return False

    except Exception as e:
        print(f"[ERROR] Unexpected error in SendGrid email function: {e}")
        traceback.print_exc()
        return False


def send_email(to_email, subject, html_content):
    """
    Send email using SendGrid API
    
    Requires:
    - SENDGRID_API_KEY: Your SendGrid API key
    - SENDGRID_FROM_EMAIL: Verified sender email address
    - SENDGRID_FROM_NAME: Sender name (optional, defaults to 'Khonology')
    """
    provider = (os.getenv('EMAIL_PROVIDER') or 'auto').strip().lower()
    disable_smtp = (os.getenv('DISABLE_SMTP') or '').strip().lower() in ('1', 'true', 'yes')

    # Prefer SendGrid when fully configured
    sendgrid_api_key = (os.getenv('SENDGRID_API_KEY') or '').strip()
    sendgrid_from_email = (os.getenv('SENDGRID_FROM_EMAIL') or '').strip()
    smtp_host = (os.getenv('SMTP_HOST') or '').strip()
    smtp_user = (os.getenv('SMTP_USER') or '').strip()
    smtp_pass = os.getenv('SMTP_PASS')

    if provider == 'smtp':
        if disable_smtp:
            print('[ERROR] SMTP is disabled (DISABLE_SMTP=true)')
            return False
        if smtp_host and smtp_user and smtp_pass:
            return send_email_via_smtp(to_email, subject, html_content)
        print('[ERROR] EMAIL_PROVIDER=smtp but SMTP is not fully configured')
        if not smtp_host:
            print('[ERROR] SMTP_HOST not set')
        if not smtp_user:
            print('[ERROR] SMTP_USER not set')
        if not smtp_pass:
            print('[ERROR] SMTP_PASS not set')
        return False

    if provider == 'sendgrid':
        if SENDGRID_AVAILABLE and sendgrid_api_key and sendgrid_from_email:
            return send_email_via_sendgrid(to_email, subject, html_content)
        if not SENDGRID_AVAILABLE:
            print("[ERROR] SendGrid SDK not installed. Install with: pip install sendgrid")
        if not sendgrid_api_key:
            print('[ERROR] SENDGRID_API_KEY not set')
        if not sendgrid_from_email:
            print('[ERROR] SENDGRID_FROM_EMAIL not set')
        return False

    if SENDGRID_AVAILABLE and sendgrid_api_key and sendgrid_from_email:
        ok = send_email_via_sendgrid(to_email, subject, html_content)
        if ok:
            return True
        if disable_smtp:
            return False
        if smtp_host and smtp_user and smtp_pass:
            print('[EMAIL] SendGrid failed; attempting SMTP fallback...')
            return send_email_via_smtp(to_email, subject, html_content)
        return False

    # Fallback to SMTP if configured
    if disable_smtp:
        return False
    if smtp_host and smtp_user and smtp_pass:
        return send_email_via_smtp(to_email, subject, html_content)

    if not SENDGRID_AVAILABLE:
        print("[ERROR] SendGrid SDK not installed. Install with: pip install sendgrid")
    if not sendgrid_api_key:
        print('[ERROR] SENDGRID_API_KEY not set')
    if not sendgrid_from_email:
        print('[ERROR] SENDGRID_FROM_EMAIL not set')
    if not smtp_host:
        print('[ERROR] SMTP_HOST not set')
    if not smtp_user:
        print('[ERROR] SMTP_USER not set')
    if not smtp_pass:
        print('[ERROR] SMTP_PASS not set')
    return False


def send_email_via_smtp(to_email, subject, html_content):
    try:
        smtp_host = (os.getenv('SMTP_HOST') or '').strip()
        smtp_port = int((os.getenv('SMTP_PORT') or '587').strip())
        smtp_user = (os.getenv('SMTP_USER') or '').strip()
        smtp_pass = os.getenv('SMTP_PASS')
        smtp_pass = smtp_pass.strip() if isinstance(smtp_pass, str) else smtp_pass
        smtp_from_email = (os.getenv('SMTP_FROM_EMAIL') or smtp_user).strip()
        smtp_from_name = os.getenv('SMTP_FROM_NAME', 'Khonology')

        # Sanitize the From header to avoid malformed values (multiple emails, stray text, etc.)
        # Some SMTP relays will silently drop or reject messages with invalid From headers.
        def _extract_email(raw: str | None) -> str:
            if not raw:
                return ''
            raw = str(raw).strip()
            _, parsed = parseaddr(raw)
            parsed = (parsed or '').strip()
            if parsed and re.fullmatch(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", parsed):
                return parsed
            # Some env vars accidentally contain extra text after the email.
            # Extract the first email-like token.
            m = re.search(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", raw)
            return (m.group(0).strip() if m else '')

        safe_to_email = _extract_email(to_email)
        if not safe_to_email:
            print(f"[ERROR] Invalid recipient email for SMTP: {to_email}")
            return False

        parsed_name, parsed_email = parseaddr(f"{smtp_from_name} <{smtp_from_email}>")
        parsed_email = (parsed_email or '').strip()
        parsed_email = _extract_email(parsed_email) or _extract_email(smtp_from_email)
        if not parsed_email:
            parsed_email = _extract_email(smtp_from_email)
        if not parsed_email and smtp_user:
            parsed_email = _extract_email(smtp_user)
        if not parsed_email:
            print('[ERROR] SMTP_FROM_EMAIL invalid and SMTP_USER missing; cannot send email')
            return False
        safe_from_name = (parsed_name or smtp_from_name or 'Khonology').replace('\r', ' ').replace('\n', ' ').strip()
        safe_from = formataddr((safe_from_name, parsed_email))

        if not all([smtp_host, smtp_user, smtp_pass, smtp_from_email]):
            print('[ERROR] SMTP configuration incomplete')
            return False

        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = safe_from
        msg['To'] = safe_to_email
        msg.attach(MIMEText(html_content, 'html'))

        print(f"[EMAIL] Using SMTP to send email to {safe_to_email}")
        print(f"[EMAIL] SMTP Host: {smtp_host}, Port: {smtp_port}, User: {smtp_user}")
        print(f"[EMAIL] From: {safe_from}")

        timeout_s = int((os.getenv('SMTP_TIMEOUT_SECONDS') or '20').strip())
        use_ssl_env = (os.getenv('SMTP_USE_SSL') or '').strip().lower() in ('1', 'true', 'yes')
        use_ssl = use_ssl_env or smtp_port == 465
        context = ssl.create_default_context()

        if use_ssl:
            with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=timeout_s, context=context) as server:
                server.ehlo()
                server.login(smtp_user, smtp_pass)
                server.send_message(msg)
        else:
            with smtplib.SMTP(smtp_host, smtp_port, timeout=timeout_s) as server:
                server.ehlo()
                server.starttls(context=context)
                server.ehlo()
                server.login(smtp_user, smtp_pass)
                server.send_message(msg)
        print(f"[SUCCESS] Email sent via SMTP to {safe_to_email}")
        return True
    except Exception as e:
        print(f"[ERROR] SMTP email error: {e}")
        print(
            "[HELP] If using Mailgun SMTP, confirm: SMTP_HOST=smtp.mailgun.org, SMTP_PORT=587 (STARTTLS) or 465 (SSL), "
            "SMTP_USER=postmaster@<your-mailgun-domain>, SMTP_PASS is correct, and your network allows outbound SMTP."
        )
        traceback.print_exc()
        return False


# ----------------------------------------------------------
# PASSWORD RESET EMAIL
# ----------------------------------------------------------
def send_password_reset_email(email, reset_token):
    """Send password reset email"""
    from api.utils.helpers import get_frontend_url
    frontend_url = get_frontend_url()
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
    from api.utils.helpers import get_frontend_url
    frontend_url = get_frontend_url()
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
