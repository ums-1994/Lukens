"""
Test the complete DocuSign proposal signing flow
"""
import os
import sys
from dotenv import load_dotenv

load_dotenv()

def test_proposal_signing():
    print("\n" + "=" * 80)
    print("   TESTING PROPOSAL SIGNING FLOW")
    print("=" * 80)
    
    # Check environment variables
    required_vars = [
        'DOCUSIGN_INTEGRATION_KEY',
        'DOCUSIGN_USER_ID',
        'DOCUSIGN_ACCOUNT_ID',
        'DOCUSIGN_PRIVATE_KEY_PATH',
        'DOCUSIGN_AUTH_SERVER'
    ]
    
    print("\n📋 Checking Environment Variables:")
    missing_vars = []
    for var in required_vars:
        value = os.getenv(var)
        if value:
            # Mask sensitive values
            if 'KEY' in var or 'ID' in var:
                display_value = f"{value[:8]}...{value[-4:]}" if len(value) > 12 else "***"
            else:
                display_value = value
            print(f"  ✅ {var}: {display_value}")
        else:
            print(f"  ❌ {var}: MISSING")
            missing_vars.append(var)
    
    if missing_vars:
        print(f"\n⚠️  Missing required variables: {', '.join(missing_vars)}")
        print("   Please add them to your .env file")
        return False
    
    # Check if DOCUSIGN_ACCOUNT_ID is set (critical for envelope creation)
    account_id = os.getenv('DOCUSIGN_ACCOUNT_ID')
    if not account_id:
        print("\n🔴 CRITICAL: DOCUSIGN_ACCOUNT_ID is not set!")
        print("\n   To get your Account ID:")
        print("   1. Go to https://demo.docusign.net")
        print("   2. Click on your profile icon → Settings")
        print("   3. Click 'My Account Information'")
        print("   4. Copy the 'Account ID' (it's a GUID like: 70784c46-78c0-45af-8207-f4b8e8a43ea)")
        print("   5. Add to .env: DOCUSIGN_ACCOUNT_ID=your-account-id")
        return False
    
    print("\n✅ All environment variables are configured!")
    
    # Test imports
    print("\n📦 Testing Imports:")
    try:
        from docusign_esign import ApiClient
        print("  ✅ docusign-esign SDK")
    except ImportError:
        print("  ❌ docusign-esign SDK")
        print("     Run: pip install docusign-esign")
        return False
    
    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.platypus import SimpleDocTemplate
        print("  ✅ reportlab")
    except ImportError:
        print("  ⚠️  reportlab (optional but recommended)")
        print("     Run: pip install reportlab")
    
    # Test JWT authentication
    print("\n🔐 Testing JWT Authentication:")
    try:
        from api.utils.docusign_utils import get_docusign_jwt_token
        auth_data = get_docusign_jwt_token()
        token = auth_data['access_token']
        account_id = auth_data.get('account_id', 'N/A')
        print(f"  ✅ JWT token obtained: {token[:30]}...")
        print(f"  ✅ Account ID: {account_id}")
    except Exception as e:
        print(f"  ❌ JWT authentication failed: {e}")
        return False
    
    print("\n" + "=" * 80)
    print("✅ BASIC CHECKS PASSED")
    print("=" * 80)
    print("\n📋 Next Steps:")
    print("1. Make sure you have a proposal in your database")
    print("2. Get your authentication token from the login endpoint")
    print("3. Test the endpoint:")
    print("   POST /api/proposals/{id}/docusign/send")
    print("   Body: {")
    print('     "signer_name": "Test Client",')
    print('     "signer_email": "test@example.com",')
    print('     "return_url": "http://localhost:8081"')
    print("   }")
    print("\n4. The endpoint will return a 'signing_url'")
    print("5. Open that URL in a browser to test signing")
    print("\n" + "=" * 80)
    
    return True

if __name__ == "__main__":
    test_proposal_signing()



