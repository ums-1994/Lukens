#!/usr/bin/env python3
"""
Simple SMTP test script
Run this to test your SMTP configuration independently
"""
import os
import sys
from dotenv import load_dotenv
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Load environment variables
load_dotenv()

def test_smtp():
    """Test SMTP connection and send a test email"""
    print("=" * 60)
    print("SMTP Configuration Test")
    print("=" * 60)
    
    # Get configuration
    smtp_host = os.getenv('SMTP_HOST')
    smtp_port_str = os.getenv('SMTP_PORT', '587')
    smtp_port = int(smtp_port_str) if smtp_port_str else 587
    smtp_user = os.getenv('SMTP_USER')
    smtp_pass = os.getenv('SMTP_PASS')
    smtp_from_email = os.getenv('SMTP_FROM_EMAIL', smtp_user)
    smtp_from_name = os.getenv('SMTP_FROM_NAME', 'Khonology')
    
    print(f"\n📧 SMTP Configuration:")
    print(f"   Host: {smtp_host}")
    print(f"   Port: {smtp_port}")
    print(f"   User: {smtp_user}")
    print(f"   Pass: {'***SET***' if smtp_pass else '❌ NOT SET'}")
    print(f"   From: {smtp_from_name} <{smtp_from_email}>")
    
    # Check configuration
    if not all([smtp_host, smtp_user, smtp_pass]):
        print("\n❌ ERROR: SMTP configuration incomplete!")
        missing = []
        if not smtp_host:
            missing.append("SMTP_HOST")
        if not smtp_user:
            missing.append("SMTP_USER")
        if not smtp_pass:
            missing.append("SMTP_PASS")
        print(f"   Missing: {', '.join(missing)}")
        return False
    
    # Get test email
    test_email = input(f"\n📬 Enter email address to send test email to (or press Enter to use {smtp_user}): ").strip()
    if not test_email:
        test_email = smtp_user
    
    print(f"\n🔄 Testing SMTP connection...")
    
    try:
        # Step 1: Connect
        print("   1. Connecting to SMTP server...", end=" ")
        server = smtplib.SMTP(smtp_host, smtp_port, timeout=10)
        print("✅ Connected")
        
        # Step 2: Start TLS
        print("   2. Starting TLS...", end=" ")
        server.starttls()
        print("✅ TLS started")
        
        # Step 3: Login
        print("   3. Authenticating...", end=" ")
        server.login(smtp_user, smtp_pass)
        print("✅ Authenticated")
        
        # Step 4: Create and send email
        print("   4. Creating test email...", end=" ")
        msg = MIMEMultipart('alternative')
        msg['Subject'] = 'SMTP Test - Khonology'
        msg['From'] = f"{smtp_from_name} <{smtp_from_email}>"
        msg['To'] = test_email
        
        html_content = f"""
        <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; background-color: #f5f5f5;">
                <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                    <h2 style="color: #E9293A;">✅ SMTP Test Successful!</h2>
                    <p>If you received this email, your SMTP configuration is working correctly.</p>
                    <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
                    <p style="color: #666; font-size: 14px;">
                        <strong>Configuration:</strong><br>
                        Host: {smtp_host}<br>
                        Port: {smtp_port}<br>
                        From: {smtp_from_name} &lt;{smtp_from_email}&gt;
                    </p>
                </div>
            </body>
        </html>
        """
        
        html_part = MIMEText(html_content, 'html')
        msg.attach(html_part)
        print("✅ Created")
        
        print(f"   5. Sending email to {test_email}...", end=" ")
        server.send_message(msg)
        print("✅ Sent")
        
        server.quit()
        
        print("\n" + "=" * 60)
        print("✅ SUCCESS! Test email sent successfully!")
        print(f"   Please check {test_email} (and spam folder)")
        print("=" * 60)
        return True
        
    except smtplib.SMTPAuthenticationError as e:
        print(f"\n❌ Authentication failed: {e}")
        print("\n💡 Troubleshooting:")
        print("   1. Make sure you're using an App Password (not your regular Gmail password)")
        print("   2. For Gmail: Go to https://myaccount.google.com/apppasswords")
        print("   3. Generate a new App Password and update SMTP_PASS in .env")
        return False
    except smtplib.SMTPConnectError as e:
        print(f"\n❌ Connection failed: {e}")
        print("\n💡 Troubleshooting:")
        print("   1. Check your internet connection")
        print("   2. Verify SMTP_HOST and SMTP_PORT are correct")
        print("   3. Check if your firewall is blocking the connection")
        return False
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = test_smtp()
    sys.exit(0 if success else 1)



















