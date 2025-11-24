"""
Check SMTP configuration and test email sending
"""
import os
from dotenv import load_dotenv
from api.utils.email import send_email, get_logo_html

load_dotenv()

def check_smtp_config():
    """Check if SMTP configuration is set"""
    print("=" * 60)
    print("SMTP Configuration Check")
    print("=" * 60)
    
    smtp_host = os.getenv('SMTP_HOST')
    smtp_port = os.getenv('SMTP_PORT', '587')
    smtp_user = os.getenv('SMTP_USER')
    smtp_pass = os.getenv('SMTP_PASS')
    smtp_from_email = os.getenv('SMTP_FROM_EMAIL', smtp_user)
    smtp_from_name = os.getenv('SMTP_FROM_NAME', 'Khonology')
    
    print(f"\nSMTP_HOST: {'✅ SET' if smtp_host else '❌ NOT SET'}")
    if smtp_host:
        print(f"   Value: {smtp_host}")
    
    print(f"\nSMTP_PORT: {'✅ SET' if smtp_port else '❌ NOT SET'}")
    if smtp_port:
        print(f"   Value: {smtp_port}")
    
    print(f"\nSMTP_USER: {'✅ SET' if smtp_user else '❌ NOT SET'}")
    if smtp_user:
        print(f"   Value: {smtp_user}")
    
    print(f"\nSMTP_PASS: {'✅ SET' if smtp_pass else '❌ NOT SET'}")
    if smtp_pass:
        print(f"   Value: {'*' * len(smtp_pass)}")
    
    print(f"\nSMTP_FROM_EMAIL: {smtp_from_email or 'NOT SET'}")
    print(f"SMTP_FROM_NAME: {smtp_from_name or 'NOT SET'}")
    
    print("\n" + "=" * 60)
    
    if not all([smtp_host, smtp_user, smtp_pass]):
        print("❌ SMTP configuration is incomplete!")
        print("\nPlease set the following environment variables in your .env file:")
        print("  SMTP_HOST=smtp.gmail.com")
        print("  SMTP_PORT=587")
        print("  SMTP_USER=your-email@gmail.com")
        print("  SMTP_PASS=your-app-password")
        print("  SMTP_FROM_EMAIL=your-email@gmail.com (optional)")
        print("  SMTP_FROM_NAME=Khonology (optional)")
        print("\nFor Gmail, you need to:")
        print("  1. Enable 2-Step Verification")
        print("  2. Generate an App Password")
        print("  3. Use the App Password as SMTP_PASS")
        return False
    else:
        print("✅ SMTP configuration looks good!")
        return True

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
    <p>If you received this email, your SMTP configuration is working correctly!</p>
    """
    
    print(f"\nSending test email to {test_email}...")
    result = send_email(test_email, subject, html_content)
    
    if result:
        print("✅ Test email sent successfully!")
    else:
        print("❌ Failed to send test email. Check the error messages above.")

if __name__ == '__main__':
    if check_smtp_config():
        test = input("\nWould you like to send a test email? (y/n): ").strip().lower()
        if test == 'y':
            test_email()

