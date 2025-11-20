"""
Email sending utilities
"""
import os
import smtplib
import traceback
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path
import base64

# Cloudinary for logo hosting
try:
    import cloudinary  # type: ignore
    import cloudinary.uploader  # type: ignore
    import cloudinary.config  # type: ignore
    CLOUDINARY_AVAILABLE = True
except ImportError:
    CLOUDINARY_AVAILABLE = False


def send_email(to_email, subject, html_content):
    """Send email using SMTP"""
    try:
        print(f"[EMAIL] Attempting to send email to {to_email}")

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

        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = f"{smtp_from_name} <{smtp_from_email}>"
        msg['To'] = to_email

        # Attach HTML content
        html_part = MIMEText(html_content, 'html')
        msg.attach(html_part)

        # Send email
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
                    
                    # Provide helpful guidance based on the error
                    if 'gmail.com' in smtp_host.lower() or 'google' in smtp_host.lower():
                        print("[HELP] Gmail authentication troubleshooting:")
                        print("  1. Enable 2-Step Verification: https://myaccount.google.com/security")
                        print("  2. Generate an App Password: https://myaccount.google.com/apppasswords")
                        print("  3. Use the App Password (16 characters) instead of your regular password")
                        print("  4. Make sure 'Less secure app access' is NOT needed (deprecated)")
                        print("  5. If using a workspace account, check with your admin for SMTP settings")
                    else:
                        print("[HELP] SMTP authentication troubleshooting:")
                        print("  1. Verify your SMTP_USER and SMTP_PASS are correct")
                        print("  2. Check if your email provider requires app-specific passwords")
                        print("  3. Verify SMTP_HOST and SMTP_PORT are correct")
                        print("  4. Some providers require enabling 'Less secure app access' (not recommended)")
                        print("  5. Consider using OAuth2 authentication for better security")
                    
                    raise
                except (smtplib.SMTPException, OSError, ConnectionError) as smtp_error:
                    print(f"[ERROR] SMTP connection error: {smtp_error}")
                    print(f"[ERROR] This might be a network/DNS issue. Check your internet connection and SMTP settings.")
                    raise
                
                print('[EMAIL] Sending message...')
                server.send_message(msg)

        print(f"[SUCCESS] Email sent to {to_email}")
        return True
    except Exception as exc:
        print(f"[ERROR] Error sending email: {exc}")
        traceback.print_exc()
        return False


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
                <p style="color: #666; font-size: 16px;">We received a request to reset your password. Click the link below to reset it.</p>
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{reset_link}" style="background-color: #007bff; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-size: 16px;">Reset Password</a>
                </div>
                <p style="color: #999; font-size: 12px;">If you didn't request this, you can ignore this email.</p>
                <p style="color: #999; font-size: 12px;">This link will expire in 24 hours.</p>
            </div>
        </body>
    </html>
    """
    return send_email(email, subject, html_content)


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
                    Thank you for registering with Khonology! Please verify your email address by clicking the button below.
                </p>
                <div style="text-align:center;margin:30px 0;">
                    <a href="{verification_link}" style="background-color:#E9293A;color:#fff;padding:14px 32px;text-decoration:none;border-radius:8px;display:inline-block;font-size:16px;font-weight:600;">Verify Email Address</a>
                </div>
                <p style="color:#666;font-size:12px;line-height:1.6;">
                    Or copy and paste this link into your browser:<br>
                    <span style="color:#B3B3B3;word-break:break-all;">{verification_link}</span>
                </p>
                <p style="color:#666;font-size:12px;margin-top:24px;">
                    This verification link will expire in 24 hours. If you didn't create an account, you can safely ignore this email.
                </p>
                <p style="color:#666;font-size:12px;text-align:center;margin-top:30px;">© 2025 Khonology. All rights reserved.</p>
            </div>
        </body>
    </html>
    """
    return send_email(email, subject, html_content)


def get_logo_html():
    """Get HTML for Khonology logo (Cloudinary URL, env URL, or base64 fallback)"""
    # Priority 1: Use explicit URL from environment
    logo_url = os.getenv('KHONOLOGY_LOGO_URL', '')
    if logo_url:
        return f'<img src="{logo_url}" alt="Khonology" style="max-width: 200px; height: auto; display: block; margin: 0 auto;" />'

    # Priority 2: Try Cloudinary public_id from environment
    cloudinary_public_id = os.getenv('KHONOLOGY_LOGO_CLOUDINARY_ID', '')
    if cloudinary_public_id and CLOUDINARY_AVAILABLE:
        try:
            cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME', '')
            if cloud_name:
                logo_url = f"https://res.cloudinary.com/{cloud_name}/image/upload/{cloudinary_public_id}"
                return f'<img src="{logo_url}" alt="Khonology" style="max-width: 200px; height: auto; display: block; margin: 0 auto;" />'
        except Exception as exc:
            print(f"[WARN] Could not generate Cloudinary URL: {exc}")

    # Priority 3: Fallback to base64 embedding
    logo_path = Path(__file__).resolve().parent.parent.parent / 'frontend_flutter' / 'assets' / 'images' / '2026.png'
    if logo_path.exists():
        try:
            with open(logo_path, 'rb') as logo_file:
                logo_data = base64.b64encode(logo_file.read()).decode('utf-8')
                return (
                    '<img src="data:image/png;base64,'
                    f"{logo_data}"
                    '" alt="Khonology" style="max-width: 200px; height: auto; display: block; margin: 0 auto;" />'
                )
        except Exception as exc:
            print(f"[WARN] Could not embed logo as base64: {exc}")

    # Priority 4: Text fallback
    return "<h1 style=\"margin: 0; font-family: 'Poppins', Arial, sans-serif; font-size: 32px; font-weight: bold; color: #FFFFFF; letter-spacing: -0.5px;\">✕ Khonology</h1>"


