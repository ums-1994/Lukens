#!/usr/bin/env python3
"""Direct email test - bypasses all the app logic"""
import os
import sys
from dotenv import load_dotenv
from api.utils.email import send_email

# Load environment variables
load_dotenv()

if __name__ == '__main__':
    test_email = input("Enter email to send test to: ").strip()
    if not test_email:
        print("No email provided")
        sys.exit(1)
    
    print(f"\nSending test email to: {test_email}")
    print("=" * 60)
    
    result = send_email(
        to_email=test_email,
        subject="Direct Email Test - Khonology",
        html_content="""
        <html>
        <body style="font-family: Arial, sans-serif; padding: 20px;">
            <h2>Direct Email Test</h2>
            <p>If you received this, the email system is working!</p>
        </body>
        </html>
        """
    )
    
    print("=" * 60)
    if result:
        print("✅ SUCCESS: Email sent!")
    else:
        print("❌ FAILED: Email not sent. Check logs above.")
    sys.exit(0 if result else 1)





"""Direct email test - bypasses all the app logic"""
import os
import sys
from dotenv import load_dotenv
from api.utils.email import send_email

# Load environment variables
load_dotenv()

if __name__ == '__main__':
    test_email = input("Enter email to send test to: ").strip()
    if not test_email:
        print("No email provided")
        sys.exit(1)
    
    print(f"\nSending test email to: {test_email}")
    print("=" * 60)
    
    result = send_email(
        to_email=test_email,
        subject="Direct Email Test - Khonology",
        html_content="""
        <html>
        <body style="font-family: Arial, sans-serif; padding: 20px;">
            <h2>Direct Email Test</h2>
            <p>If you received this, the email system is working!</p>
        </body>
        </html>
        """
    )
    
    print("=" * 60)
    if result:
        print("✅ SUCCESS: Email sent!")
    else:
        print("❌ FAILED: Email not sent. Check logs above.")
    sys.exit(0 if result else 1)





















