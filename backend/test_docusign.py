"""
Quick test to verify DocuSign configuration
Run this to test if DocuSign JWT authentication works
"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_docusign_config():
    """Test if all DocuSign configuration is present"""
    print("🔍 Checking DocuSign Configuration...")
    print("-" * 50)
    
    required_vars = {
        'DOCUSIGN_INTEGRATION_KEY': os.getenv('DOCUSIGN_INTEGRATION_KEY'),
        'DOCUSIGN_USER_ID': os.getenv('DOCUSIGN_USER_ID'),
        'DOCUSIGN_ACCOUNT_ID': os.getenv('DOCUSIGN_ACCOUNT_ID'),
        'DOCUSIGN_PRIVATE_KEY_PATH': os.getenv('DOCUSIGN_PRIVATE_KEY_PATH'),
        'DOCUSIGN_BASE_PATH': os.getenv('DOCUSIGN_BASE_PATH'),
        'DOCUSIGN_AUTH_SERVER': os.getenv('DOCUSIGN_AUTH_SERVER'),
    }
    
    all_present = True
    for key, value in required_vars.items():
        if value:
            # Mask sensitive values
            if 'KEY' in key and len(value) > 10:
                display_value = f"{value[:8]}...{value[-4:]}"
            else:
                display_value = value
            print(f"✅ {key}: {display_value}")
        else:
            print(f"❌ {key}: NOT SET")
            all_present = False
    
    print("-" * 50)
    
    # Check if private key file exists
    private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH')
    if private_key_path:
        if os.path.exists(private_key_path):
            print(f"✅ Private key file found: {private_key_path}")
        else:
            print(f"❌ Private key file NOT found: {private_key_path}")
            all_present = False
    
    # Try to import DocuSign SDK
    print("-" * 50)
    try:
        import docusign_esign as docusign
        print(f"✅ DocuSign SDK imported successfully")
    except ImportError as e:
        print(f"❌ DocuSign SDK import failed: {e}")
        all_present = False
    
    # Try to import JWT
    try:
        import jwt
        print(f"✅ PyJWT imported successfully")
    except ImportError as e:
        print(f"❌ PyJWT import failed: {e}")
        all_present = False
    
    print("-" * 50)
    
    if all_present:
        print("🎉 All DocuSign configuration is correct!")
        print("\n📋 Next step: Test JWT authentication")
        print("   Run: python test_docusign_auth.py")
    else:
        print("⚠️ Some configuration is missing. Please fix the issues above.")
    
    return all_present

def test_jwt_authentication():
    """Test DocuSign JWT authentication"""
    print("\n🔐 Testing DocuSign JWT Authentication...")
    print("-" * 50)
    
    try:
        import docusign_esign as docusign
        import jwt
        from datetime import datetime, timedelta
        
        # Load configuration
        integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
        user_id = os.getenv('DOCUSIGN_USER_ID')
        auth_server = os.getenv('DOCUSIGN_AUTH_SERVER')
        private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH')
        
        # Read private key
        with open(private_key_path, 'r') as key_file:
            private_key = key_file.read()
        
        print("✅ Private key loaded")
        
        # Create JWT
        now = datetime.utcnow()
        token = jwt.encode(
            {
                'iss': integration_key,
                'sub': user_id,
                'aud': auth_server,
                'iat': now,
                'exp': now + timedelta(hours=1),
                'scope': 'signature impersonation'
            },
            private_key,
            algorithm='RS256'
        )
        
        print("✅ JWT token created")
        
        # Request access token
        import requests
        
        response = requests.post(
            f'https://{auth_server}/oauth/token',
            data={
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion': token
            },
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )
        
        if response.status_code == 200:
            access_token = response.json().get('access_token')
            print("✅ Access token received!")
            print(f"   Token: {access_token[:20]}...{access_token[-10:]}")
            print("\n🎉 DocuSign JWT authentication works!")
            print("\n✅ Your DocuSign integration is ready to use!")
            return True
        else:
            print(f"❌ Authentication failed: {response.status_code}")
            print(f"   Response: {response.text}")
            
            if 'consent_required' in response.text:
                print("\n⚠️ Consent required! Please complete the consent flow:")
                print(f"   https://{auth_server}/oauth/auth?response_type=code&scope=signature%20impersonation&client_id={integration_key}&redirect_uri=https://www.docusign.com/api")
            
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("\n" + "=" * 50)
    print("   DOCUSIGN INTEGRATION TEST")
    print("=" * 50 + "\n")
    
    # Test configuration
    config_ok = test_docusign_config()
    
    if config_ok:
        # Test JWT authentication
        test_jwt_authentication()
    
    print("\n" + "=" * 50)

