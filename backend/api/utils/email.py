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
    import cloudinary
    import cloudinary.uploader
    import cloudinary.config
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
            print(f"[ERROR] SMTP configuration incomplete")
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
        print(f"[EMAIL] Connecting to SMTP server...")
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            print(f"[EMAIL] Starting TLS...")
            server.starttls()
            print(f"[EMAIL] Logging in...")
            server.login(smtp_user, smtp_pass)
            print(f"[EMAIL] Sending message...")
            server.send_message(msg)
        
        print(f"[SUCCESS] Email sent to {to_email}")
        return True
    except Exception as e:
        print(f"[ERROR] Error sending email: {e}")
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
        except Exception as e:
            print(f"[WARN] Could not generate Cloudinary URL: {e}")
    
    # Priority 3: Fallback to base64 embedding
    logo_path = Path(__file__).parent.parent.parent / 'frontend_flutter' / 'assets' / 'images' / '2026.png'
    if logo_path.exists():
        try:
            with open(logo_path, 'rb') as f:
                logo_data = base64.b64encode(f.read()).decode('utf-8')
                return f'<img src="data:image/png;base64,{logo_data}" alt="Khonology" style="max-width: 200px; height: auto; display: block; margin: 0 auto;" />'
        except Exception as e:
            print(f"[WARN] Could not embed logo as base64: {e}")
    
    # Priority 4: Text fallback
    return '<h1 style="margin: 0; font-family: \'Poppins\', Arial, sans-serif; font-size: 32px; font-weight: bold; color: #FFFFFF; letter-spacing: -0.5px;">✕ Khonology</h1>'

