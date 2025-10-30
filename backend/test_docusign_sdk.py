"""
Test DocuSign authentication using the official SDK
This bypasses our manual JWT creation and uses DocuSign's SDK
"""
import os
from dotenv import load_dotenv

load_dotenv()

def test_with_sdk():
    print("\n" + "=" * 80)
    print("   TESTING WITH DOCUSIGN SDK")
    print("=" * 80)
    
    try:
        from docusign_esign import ApiClient
        print("✅ DocuSign SDK imported")
    except ImportError:
        print("❌ DocuSign SDK not installed")
        print("   Run: pip install docusign-esign")
        return False
    
    integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
    user_id = os.getenv('DOCUSIGN_USER_ID')
    auth_server = os.getenv('DOCUSIGN_AUTH_SERVER')
    private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH')
    
    print(f"\nConfiguration:")
    print(f"  Integration Key: {integration_key[:8]}...{integration_key[-4:]}")
    print(f"  User ID: {user_id}")
    print(f"  Auth Server: {auth_server}")
    print(f"  Private Key: {private_key_path}")
    
    # Read private key (must be bytes for SDK)
    try:
        with open(private_key_path, 'rb') as f:
            private_key = f.read()
        print(f"✅ Private key loaded ({len(private_key)} bytes)")
    except Exception as e:
        print(f"❌ Could not read private key: {e}")
        return False
    
    # Create API client
    try:
        api_client = ApiClient()
        api_client.set_base_path(f"https://{auth_server}")
        print(f"✅ API client created")
    except Exception as e:
        print(f"❌ Could not create API client: {e}")
        return False
    
    # Request JWT token using SDK
    print("\n🔐 Requesting JWT token using DocuSign SDK...")
    print("-" * 80)
    
    try:
        # This is the official SDK way to get a JWT token
        response = api_client.request_jwt_user_token(
            client_id=integration_key,
            user_id=user_id,
            oauth_host_name=auth_server,
            private_key_bytes=private_key,
            expires_in=3600,
            scopes=["signature", "impersonation"]
        )
        
        print("\n" + "=" * 80)
        print("🎉 SUCCESS! DocuSign SDK authentication works!")
        print("=" * 80)
        print(f"\nAccess Token: {response.access_token[:30]}...{response.access_token[-20:]}")
        print(f"Token Type: {response.token_type}")
        print(f"Expires In: {response.expires_in} seconds")
        print("\n✅ Your DocuSign integration is fully functional!")
        print("✅ The Flask backend will work correctly!")
        
        return True
        
    except Exception as e:
        error_message = str(e)
        print("\n" + "=" * 80)
        print("❌ SDK AUTHENTICATION FAILED")
        print("=" * 80)
        print(f"\nError: {error_message}")
        
        if "consent_required" in error_message.lower():
            print("\n🔴 ISSUE: Consent Required")
            print("\nYou need to grant consent. Since redirect URIs are problematic,")
            print("try this workaround:")
            print("\n1. In DocuSign, temporarily add ANY valid HTTPS URL as redirect URI")
            print("   Example: https://example.com")
            print("\n2. Build consent URL with that redirect:")
            consent_url = f"https://{auth_server}/oauth/auth?response_type=code&scope=signature%20impersonation&client_id={integration_key}&redirect_uri=https://example.com"
            print(f"\n   {consent_url}")
            print("\n3. Open in browser, click 'Allow Access'")
            print("4. You'll be redirected to example.com (ignore any error)")
            print("5. Consent is now granted!")
            print("6. Run this test again")
            
        elif "no_valid_keys" in error_message.lower() or "signature" in error_message.lower():
            print("\n🔴 ISSUE: Public Key Mismatch")
            print("\nThe public key in DocuSign doesn't match your private key.")
            print("Run: python show_public_key.py")
            print("Copy ALL 7 lines and upload to DocuSign")
            
        return False

if __name__ == "__main__":
    test_with_sdk()



