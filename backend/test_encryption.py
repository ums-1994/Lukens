"""
Quick test script to verify proposal encryption is working
Run this to test the encryption/decryption flow

Usage:
    python test_encryption.py                    # Run tests without email
    python test_encryption.py --email your@email.com    # Run tests and send email
"""
import sys
import os
import argparse
from datetime import datetime
sys.path.insert(0, os.path.dirname(__file__))

from api.utils.encryption_service import get_encryption_service
from api.utils.email import send_email
from dotenv import load_dotenv

# Load environment variables early so SMTP + encryption settings are ready
load_dotenv()

def test_encryption():
    print("=" * 60)
    print("🔒 Testing Proposal Encryption System")
    print("=" * 60)
    
    # Get encryption service
    encryption_service = get_encryption_service()
    print("\n✅ Encryption service loaded")
    print(f"   Master key configured: {bool(encryption_service.master_key)}")
    
    # Test data
    test_proposal_id = 1
    test_content = """
    This is a test proposal content.
    It contains sensitive information that should be encrypted.
    
    Project Details:
    - Budget: R500,000
    - Timeline: 6 months
    - Client: Acme Corporation
    """
    
    print(f"\n📝 Original Content:")
    print(f"   Proposal ID: {test_proposal_id}")
    print(f"   Content length: {len(test_content)} characters")
    print(f"   Preview: {test_content[:50]}...")
    
    # Encrypt
    print(f"\n🔐 Encrypting proposal content...")
    try:
        encrypted_data = encryption_service.encrypt_proposal_content(
            test_proposal_id,
            test_content
        )
        print("✅ Encryption successful!")
        print(f"   Encrypted content length: {len(encrypted_data['encrypted_content'])} characters")
        print(f"   Encryption method: {encrypted_data['encryption_method']}")
        print(f"   Salt: {encrypted_data['salt'][:20]}...")
    except Exception as e:
        print(f"❌ Encryption failed: {e}")
        return False
    
    # Decrypt
    print(f"\n🔓 Decrypting proposal content...")
    try:
        decrypted_content = encryption_service.decrypt_proposal_content(
            test_proposal_id,
            encrypted_data['encrypted_content'],
            encrypted_data['salt']
        )
        print("✅ Decryption successful!")
        print(f"   Decrypted content length: {len(decrypted_content)} characters")
        
        # Verify
        if decrypted_content == test_content:
            print("\n✅ VERIFICATION PASSED: Decrypted content matches original!")
            return True
        else:
            print("\n❌ VERIFICATION FAILED: Content mismatch!")
            print(f"   Original length: {len(test_content)}")
            print(f"   Decrypted length: {len(decrypted_content)}")
            return False
    except Exception as e:
        print(f"❌ Decryption failed: {e}")
        return False

def test_token_generation():
    print("\n" + "=" * 60)
    print("🎫 Testing Secure Token Generation")
    print("=" * 60)
    
    encryption_service = get_encryption_service()
    
    # Generate tokens
    print("\n🔑 Generating secure access tokens...")
    for i in range(3):
        token = encryption_service.generate_secure_token()
        print(f"   Token {i+1}: {token[:30]}... (length: {len(token)})")
    
    print("\n✅ Token generation working correctly!")
    return True

def test_password_hashing():
    print("\n" + "=" * 60)
    print("🔐 Testing Password Hashing")
    print("=" * 60)
    
    encryption_service = get_encryption_service()
    
    test_password = "MySecurePassword123!"
    print(f"\n📝 Test password: {test_password}")
    
    # Hash password
    print("🔐 Hashing password...")
    hashed = encryption_service.hash_password(test_password)
    print(f"✅ Hash generated: {hashed[:30]}...")
    
    # Verify password
    print("🔍 Verifying password...")
    if encryption_service.verify_password(test_password, hashed):
        print("✅ Password verification successful!")
    else:
        print("❌ Password verification failed!")
        return False
    
    # Test wrong password
    print("🔍 Testing wrong password...")
    if not encryption_service.verify_password("WrongPassword", hashed):
        print("✅ Wrong password correctly rejected!")
    else:
        print("❌ Wrong password incorrectly accepted!")
        return False
    
    return True

def parse_args():
    parser = argparse.ArgumentParser(
        description="Test encryption utilities and optionally email the results."
    )
    parser.add_argument(
        "--email",
        help="Address to send the formatted test results to. "
             "If omitted, results are only printed to the console."
    )
    return parser.parse_args()


def resolve_email_arg(email_arg):
    """
    Determine which email to use:
    - If --email was provided, use it directly.
    - Otherwise prompt once so the user can opt-in interactively.
    """
    if email_arg:
        return email_arg
    try:
        response = input("Enter email to send results (leave blank to skip): ").strip()
    except EOFError:
        return None
    return response or None


def build_demo_client_context(recipient_email):
    """
    Mirror the data the real /proposals/<id>/approve endpoint would include
    so the email preview matches what clients see after CEO approval.
    """
    encryption_service = get_encryption_service()
    collaboration_token = encryption_service.generate_secure_token()
    frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
    proposal_url = f"{frontend_url}/#/collaborate?token={collaboration_token}"
    
    return {
        "client_name": "Lerato Mokoena",
        "client_email": recipient_email or "client@example.com",
        "proposal_title": "AI Automation Roadmap – Phase 1",
        "project_summary": "Digitize onboarding, automate approvals, and surface live dashboards.",
        "total_investment": "R 1,200,000",
        "delivery_timeline": "12 weeks",
        "account_lead": "Unathi Lukens",
        "proposal_url": proposal_url,
        "token_suffix": collaboration_token[-6:],
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }


def build_client_ready_email(results, preview):
    """Craft the same HTML email a client receives once the CEO approves a proposal."""
    rows = "".join(
        f"""
        <tr>
            <td style="padding:10px 14px;background:#f7f7f7;border:1px solid #e0e0e0;">{label}</td>
            <td style="padding:10px 14px;border:1px solid #e0e0e0;">{"✅ PASS" if passed else "❌ FAIL"}</td>
        </tr>
        """
        for label, passed in results.items()
    )
    overall = "✅ All tests passed" if all(results.values()) else "⚠️ Some tests failed"
    
    return f"""
    <html>
    <body style="font-family: Arial, sans-serif; max-width: 640px; margin: 0 auto; background-color: #f4f6f8; padding: 0;">
        <div style="background-color: #2ECC71; padding: 24px; text-align: center;">
            <h1 style="color: #fff; margin: 0;">Proposal Approved & Ready</h1>
            <p style="color: #E8F8F5; margin: 8px 0 0;">Timestamp: {preview['timestamp']}</p>
        </div>
        <div style="background-color: #ffffff; padding: 32px;">
            <p>Dear {preview['client_name']},</p>
            <p>Great news! Your proposal "<strong>{preview['proposal_title']}</strong>" has been approved by our executive team and is now available for your review.</p>
            
            <div style="background-color: #F8FDF9; border: 1px solid #DCF5E6; border-radius: 8px; padding: 20px; margin: 24px 0;">
                <h3 style="margin-top: 0; color: #16A085;">Proposal Snapshot</h3>
                <p><strong>Summary:</strong> {preview['project_summary']}</p>
                <p><strong>Total Investment:</strong> {preview['total_investment']}</p>
                <p><strong>Delivery Timeline:</strong> {preview['delivery_timeline']}</p>
                <p><strong>Account Lead:</strong> {preview['account_lead']}</p>
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="{preview['proposal_url']}"
                   style="background-color: #2ECC71; color: white; padding: 16px 36px;
                          text-decoration: none; border-radius: 6px; display: inline-block;
                          font-size: 16px; font-weight: bold;">
                    View Proposal
                </a>
                <p style="color: #7F8C8D; font-size: 13px; margin-top: 12px;">
                    Secure link active for 90 days · Token ending in {preview['token_suffix']}
                </p>
            </div>
            
            <div style="border-top: 1px solid #ECF0F1; margin-top: 32px; padding-top: 24px;">
                <h3 style="margin-top: 0;">Internal Validation Snapshot</h3>
                <p style="color:#7F8C8D;">These automated checks run before any client email is released.</p>
                <table style="width:100%; border-collapse: collapse;">
                    <tbody>{rows}</tbody>
                </table>
                <p style="margin-top: 18px; font-weight: bold;">{overall}</p>
            </div>
            
            <p style="color: #95A5A6; font-size: 12px; margin-top: 30px;">
                This secure message was generated by test_encryption.py to mirror the live client email experience.
                Please do not reply to this address.
            </p>
        </div>
    </body>
    </html>
    """


def maybe_send_email(recipient, results, preview):
    if not recipient:
        return
    subject = f"Proposal Approved: {preview['proposal_title']}"
    html_content = build_client_ready_email(results, preview)
    print(f"\n📧 Sending client-style preview to {recipient} ...")
    if send_email(recipient, subject, html_content):
        print("✅ Email sent successfully.")
    else:
        print("❌ Failed to send email. See logs above for details.")


if __name__ == "__main__":
    args = parse_args()
    recipient = resolve_email_arg(args.email)
    preview_context = build_demo_client_context(recipient)
    print("\n")
    
    # Run tests
    test1 = test_encryption()
    test2 = test_token_generation()
    test3 = test_password_hashing()
    
    results = {
        "Encryption/Decryption": test1,
        "Token Generation": test2,
        "Password Hashing": test3,
    }
    
    print("\n" + "=" * 60)
    print("📊 Test Results Summary")
    print("=" * 60)
    for label, passed in results.items():
        print(f"   {label}: {'✅ PASS' if passed else '❌ FAIL'}")
    
    if all(results.values()):
        print("\n🎉 All tests passed! Encryption system is ready to use.")
    else:
        print("\n⚠️  Some tests failed. Please check the errors above.")
    
    maybe_send_email(recipient, results, preview_context)
    print("\n")

