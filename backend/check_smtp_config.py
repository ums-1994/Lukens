"""Check email configuration and test SMTP connectivity.

This script helps debug SMTP issues (e.g., Mailgun) by validating env vars,
printing EHLO capabilities, and attempting an authenticated login.
"""
import os
from dotenv import load_dotenv
from pathlib import Path
import smtplib
import ssl

from api.utils.email import send_email, get_logo_html, SENDGRID_AVAILABLE

# Load .env file from backend directory
env_path = Path(__file__).parent / '.env'
load_dotenv(dotenv_path=env_path, override=True)

def check_email_config():
    """Check if SendGrid email configuration is set"""
    print("=" * 60)
    print("SendGrid Email Configuration Check")
    print("=" * 60)
    
    sendgrid_api_key = os.getenv('SENDGRID_API_KEY')
    sendgrid_from_email = os.getenv('SENDGRID_FROM_EMAIL')
    sendgrid_from_name = os.getenv('SENDGRID_FROM_NAME', 'Khonology')
    
    print(f"\nSENDGRID_AVAILABLE: {'✅ YES' if SENDGRID_AVAILABLE else '❌ NO (install: pip install sendgrid)'}")
    print(f"\nSENDGRID_API_KEY: {'✅ SET' if sendgrid_api_key else '❌ NOT SET'}")
    if sendgrid_api_key:
        print(f"   Value: {'*' * min(len(sendgrid_api_key), 20)}...")
    
    print(f"\nSENDGRID_FROM_EMAIL: {'✅ SET' if sendgrid_from_email else '❌ NOT SET'}")
    if sendgrid_from_email:
        print(f"   Value: {sendgrid_from_email}")
    
    print(f"\nSENDGRID_FROM_NAME: {sendgrid_from_name}")
    
    sendgrid_configured = all([sendgrid_api_key, sendgrid_from_email])
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    if sendgrid_configured:
        print("✅ SendGrid is configured and ready to send emails")
        return True
    else:
        print("❌ SendGrid configuration incomplete!")
        print("\nPlease configure SendGrid in your .env file:")
        print("\n  SENDGRID_API_KEY=your-sendgrid-api-key")
        print("  SENDGRID_FROM_EMAIL=your-verified-email@domain.com")
        print("  SENDGRID_FROM_NAME=Khonology (optional)")
        print("\nGet your API key from: https://app.sendgrid.com/settings/api_keys")
        print("Verify your sender email at: https://app.sendgrid.com/settings/sender_auth/senders")
        return False

def check_smtp_config():
    """Check SMTP configuration and attempt login."""
    print("=" * 60)
    print("SMTP Configuration Check")
    print("=" * 60)

    smtp_host = (os.getenv('SMTP_HOST') or '').strip()
    smtp_port_raw = (os.getenv('SMTP_PORT') or '587').strip()
    smtp_user = (os.getenv('SMTP_USER') or '').strip()
    smtp_pass = os.getenv('SMTP_PASS')
    smtp_use_ssl = (os.getenv('SMTP_USE_SSL') or '').strip().lower() in ('1', 'true', 'yes')

    try:
        smtp_port = int(smtp_port_raw)
    except Exception:
        smtp_port = 587

    print(f"\nSMTP_HOST: {'✅ SET' if smtp_host else '❌ NOT SET'}")
    if smtp_host:
        print(f"   Value: {smtp_host}")
    print(f"\nSMTP_PORT: {smtp_port}")
    print(f"\nSMTP_USE_SSL: {smtp_use_ssl}")
    print(f"\nSMTP_USER: {'✅ SET' if smtp_user else '❌ NOT SET'}")
    if smtp_user:
        print(f"   Value: {smtp_user}")
    print(f"\nSMTP_PASS: {'✅ SET' if smtp_pass else '❌ NOT SET'}")

    if not (smtp_host and smtp_user and smtp_pass):
        print("\n❌ SMTP configuration incomplete")
        return False

    timeout_s = int((os.getenv('SMTP_TIMEOUT_SECONDS') or '20').strip())
    use_ssl = smtp_use_ssl or smtp_port == 465
    context = ssl.create_default_context()

    print("\n" + "=" * 60)
    print("SMTP Handshake / Login Test")
    print("=" * 60)
    print(f"Connecting to {smtp_host}:{smtp_port} (ssl={use_ssl}, timeout={timeout_s}s)")

    try:
        if use_ssl:
            with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=timeout_s, context=context) as server:
                server.set_debuglevel(1)
                server.ehlo()
                print(f"\nESMTP features: {getattr(server, 'esmtp_features', {})}")
                server.login(smtp_user, smtp_pass)
                print("\n✅ SMTP login succeeded")
                return True
        else:
            with smtplib.SMTP(smtp_host, smtp_port, timeout=timeout_s) as server:
                server.set_debuglevel(1)
                server.ehlo()
                server.starttls(context=context)
                server.ehlo()
                print(f"\nESMTP features: {getattr(server, 'esmtp_features', {})}")
                server.login(smtp_user, smtp_pass)
                print("\n✅ SMTP login succeeded")
                return True
    except Exception as e:
        print(f"\n❌ SMTP test failed: {e}")
        print("\n[HELP] If you are using Mailgun: try SMTP_HOST=smtp.mailgun.org (US) or smtp.eu.mailgun.org (EU).")
        print("[HELP] Verify SMTP_USER is exactly the postmaster@<domain> shown in Mailgun and SMTP_PASS matches the SMTP password.")
        return False

def test_email():
    """Test sending an email"""
    print("\n" + "=" * 60)
    print("Testing Email Sending")
    print("=" * 60)
    
    test_email = input("\nEnter an email address to send a test email to: ").strip()
    if not test_email:
        print("❌ No email address provided")
        return
    
    subject = "Test Email from Khonology"
    html_content = f"""
    {get_logo_html()}
    <h2>Test Email</h2>
    <p>This is a test email from your Khonology proposal system.</p>
    <p>If you received this email, your SendGrid configuration is working correctly!</p>
    <p><strong>Email Service:</strong> SendGrid</p>
    """
    
    print(f"\nSending test email to {test_email}...")
    result = send_email(test_email, subject, html_content)
    
    if result:
        print("✅ Test email sent successfully!")
    else:
        print("❌ Failed to send test email. Check the error messages above.")

if __name__ == '__main__':
    provider = (os.getenv('EMAIL_PROVIDER') or 'auto').strip().lower()
    if provider == 'smtp':
        ok = check_smtp_config()
        if ok:
            test = input("\nWould you like to send a test email? (y/n): ").strip().lower()
            if test == 'y':
                test_email()
    else:
        if check_email_config():
            test = input("\nWould you like to send a test email? (y/n): ").strip().lower()
            if test == 'y':
                test_email()

