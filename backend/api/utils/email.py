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
        print(f"[EMAIL] ========================================")
        print(f"[EMAIL] Attempting to send email to: {to_email}")
        print(f"[EMAIL] Subject: {subject}")
        
        # Load environment variables explicitly
        from dotenv import load_dotenv
        load_dotenv()
        
        smtp_host = os.getenv('SMTP_HOST')
        smtp_port_str = os.getenv('SMTP_PORT', '587')
        smtp_port = int(smtp_port_str) if smtp_port_str else 587
        smtp_user = os.getenv('SMTP_USER')
        smtp_pass = os.getenv('SMTP_PASS')
        smtp_from_email = os.getenv('SMTP_FROM_EMAIL', smtp_user)
        smtp_from_name = os.getenv('SMTP_FROM_NAME', 'Khonology')
        
        print(f"[EMAIL] SMTP Configuration:")
        print(f"[EMAIL]   Host: {smtp_host}")
        print(f"[EMAIL]   Port: {smtp_port}")
        print(f"[EMAIL]   User: {smtp_user}")
        print(f"[EMAIL]   Pass: {'***SET***' if smtp_pass else 'NOT SET'}")
        print(f"[EMAIL]   From Email: {smtp_from_email}")
        print(f"[EMAIL]   From Name: {smtp_from_name}")
        
        if not all([smtp_host, smtp_user, smtp_pass]):
            print(f"[ERROR] ❌ SMTP configuration incomplete!")
            print(f"[ERROR]   Host: {smtp_host or 'MISSING'}")
            print(f"[ERROR]   User: {smtp_user or 'MISSING'}")
            print(f"[ERROR]   Pass: {'SET' if smtp_pass else 'MISSING'}")
            return False
        
        # Send email
        print(f"[EMAIL] Connecting to SMTP server {smtp_host}:{smtp_port}...")
        server = None
        try:
            # 1. Establish connection
            server = smtplib.SMTP(smtp_host, smtp_port, timeout=10)
            print(f"[EMAIL] ✅ Connected to SMTP server")
            server.ehlo()
            
            # 2. **CRITICAL FIX: Start TLS Encryption**
            print(f"[EMAIL] Starting TLS...")
            server.starttls()
            server.ehlo()
            print(f"[EMAIL] ✅ TLS started successfully")
            
            # 3. Login using the App Password
            print(f"[EMAIL] Logging in as {smtp_user}...")
            server.login(smtp_user, smtp_pass)
            print(f"[EMAIL] ✅ Login successful")
            
            # 4. Construct and send message
            msg = MIMEMultipart('alternative')
            msg['From'] = f"{smtp_from_name} <{smtp_from_email}>"
            msg['To'] = to_email
            msg['Subject'] = subject
            
            # Attach HTML content
            html_part = MIMEText(html_content, 'html')
            msg.attach(html_part)
            
            print(f"[EMAIL] Sending message to {to_email}...")
            print(f"[EMAIL] Message details:")
            print(f"[EMAIL]   From: {msg['From']}")
            print(f"[EMAIL]   To: {msg['To']}")
            print(f"[EMAIL]   Subject: {msg['Subject']}")
            
            server.sendmail(smtp_from_email, to_email, msg.as_string())
            print(f"[EMAIL] ✅ Email successfully sent to {to_email}")
            print(f"[EMAIL] ========================================")
            return True
            
        except smtplib.SMTPAuthenticationError as auth_err:
            print(f"[EMAIL ERROR] ❌ SMTP Authentication Failed. Check SMTP_PASS (App Password) and SMTP_USER. Error: {auth_err}")
            print(f"[EMAIL ERROR]   This usually means:")
            print(f"[EMAIL ERROR]   1. Wrong password/app password")
            print(f"[EMAIL ERROR]   2. Gmail 'Less secure app access' not enabled (use App Password instead)")
            print(f"[EMAIL ERROR]   3. 2FA enabled but not using App Password")
            print(f"[EMAIL] ========================================")
            return False
        except smtplib.SMTPException as smtp_err:
            print(f"[EMAIL ERROR] ❌ An SMTP error occurred during sending. Error: {smtp_err}")
            print(f"[EMAIL] ========================================")
            return False
        except Exception as e:
            print(f"[EMAIL ERROR] ❌ An unexpected error occurred: {e}")
            print(f"[EMAIL ERROR]   Error type: {type(e).__name__}")
            traceback.print_exc()
            print(f"[EMAIL] ========================================")
            return False
        finally:
            # 5. Quit the server connection
            if server:
                try:
                    server.quit()
                    print(f"[EMAIL] ✅ SMTP connection closed")
                except:
                    pass
        
    except Exception as e:
        print(f"[ERROR] ❌ Unexpected error sending email: {e}")
        traceback.print_exc()
        print(f"[EMAIL] ========================================")
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

