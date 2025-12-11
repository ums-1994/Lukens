"""
Check SendGrid email configuration and test email sending
"""
import os
from dotenv import load_dotenv
from pathlib import Path
from api.utils.email import send_email, get_logo_html, SENDGRID_AVAILABLE

# Load .env file from backend directory
env_path = Path(__file__).parent / '.env'
load_dotenv(dotenv_path=env_path)

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
    """Legacy function name - redirects to check_email_config"""
    return check_email_config()

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
    if check_email_config():
        test = input("\nWould you like to send a test email? (y/n): ").strip().lower()
        if test == 'y':
            test_email()

