"""
Comprehensive DocuSign troubleshooting tool
"""
import os
import requests
import jwt
from datetime import datetime, timezone, timedelta
from dotenv import load_dotenv

load_dotenv()

def check_docusign_connection():
    """Check basic DocuSign API connectivity"""
    print("\n🌐 Testing DocuSign API Connectivity...")
    print("-" * 50)
    
    auth_server = os.getenv('DOCUSIGN_AUTH_SERVER')
    
    try:
        # Test if DocuSign auth server is reachable
        response = requests.get(f'https://{auth_server}/', timeout=5)
        print(f"✅ DocuSign auth server is reachable: {auth_server}")
        print(f"   Status: {response.status_code}")
    except Exception as e:
        print(f"❌ Cannot reach DocuSign auth server: {e}")
        return False
    
    return True

def test_jwt_creation():
    """Test JWT token creation"""
    print("\n🔐 Testing JWT Token Creation...")
    print("-" * 50)
    
    try:
        integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
        user_id = os.getenv('DOCUSIGN_USER_ID')
        auth_server = os.getenv('DOCUSIGN_AUTH_SERVER')
        private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH')
        
        print(f"Integration Key: {integration_key[:8]}...{integration_key[-4:]}")
        print(f"User ID: {user_id}")
        print(f"Auth Server: {auth_server}")
        
        # Read private key
        with open(private_key_path, 'r') as key_file:
            private_key = key_file.read()
        
        # Check key format
        if not private_key.strip().startswith('-----BEGIN'):
            print("❌ Private key format is invalid")
            return None
        
        print("✅ Private key format is valid")
        
        # Create JWT with timezone-aware datetime
        now = datetime.now(timezone.utc)
        exp = now + timedelta(hours=1)
        
        payload = {
            'iss': integration_key,
            'sub': user_id,
            'aud': auth_server,
            'iat': int(now.timestamp()),
            'exp': int(exp.timestamp()),
            'scope': 'signature impersonation'
        }
        
        print("\nJWT Payload:")
        for key, value in payload.items():
            if key in ['iat', 'exp']:
                dt = datetime.fromtimestamp(value, tz=timezone.utc)
                print(f"  {key}: {value} ({dt.isoformat()})")
            else:
                print(f"  {key}: {value}")
        
        token = jwt.encode(payload, private_key, algorithm='RS256')
        print(f"\n✅ JWT token created successfully")
        print(f"   Token length: {len(token)} characters")
        print(f"   First 50 chars: {token[:50]}...")
        
        return token
        
    except Exception as e:
        print(f"❌ JWT creation failed: {e}")
        import traceback
        traceback.print_exc()
        return None

def test_docusign_auth(token):
    """Test DocuSign authentication with detailed error info"""
    print("\n🔑 Testing DocuSign Authentication...")
    print("-" * 50)
    
    auth_server = os.getenv('DOCUSIGN_AUTH_SERVER')
    integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
    
    try:
        url = f'https://{auth_server}/oauth/token'
        
        data = {
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': token
        }
        
        headers = {
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        
        print(f"Requesting: {url}")
        print(f"Grant type: {data['grant_type']}")
        print(f"Assertion (JWT) length: {len(token)}")
        
        response = requests.post(url, data=data, headers=headers, timeout=10)
        
        print(f"\nResponse Status: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"\nResponse Body:")
        print(response.text)
        
        if response.status_code == 200:
            result = response.json()
            access_token = result.get('access_token')
            print("\n🎉 SUCCESS! Authentication works!")
            print(f"   Access Token: {access_token[:20]}...{access_token[-10:]}")
            print(f"   Token Type: {result.get('token_type')}")
            print(f"   Expires In: {result.get('expires_in')} seconds")
            return True
        else:
            error_data = response.json() if response.headers.get('content-type', '').startswith('application/json') else {}
            error = error_data.get('error', 'unknown')
            error_desc = error_data.get('error_description', 'No description')
            
            print(f"\n❌ Authentication Failed")
            print(f"   Error: {error}")
            print(f"   Description: {error_desc}")
            
            # Provide specific troubleshooting
            if error == 'invalid_grant':
                if 'consent_required' in error_desc or 'consent' in response.text.lower():
                    print("\n⚠️ ISSUE: Consent Required")
                    print("\n📋 Solution: Grant consent by opening this URL in your browser:")
                    print(f"   https://{auth_server}/oauth/auth?response_type=code&scope=signature%20impersonation&client_id={integration_key}&redirect_uri=https://www.docusign.com/api")
                    print("\n   After clicking 'Allow Access', wait 2-3 minutes and try again.")
                
                elif 'no_valid_keys' in error_desc or 'signature' in error_desc:
                    print("\n⚠️ ISSUE: Public Key Mismatch")
                    print("\n📋 Solution:")
                    print("1. Go to https://demo.docusign.net")
                    print("2. Settings → Apps and Keys → Your App")
                    print("3. In RSA Keypairs section:")
                    print("   - DELETE all existing keypairs")
                    print("   - Click '+ ADD RSA KEYPAIR'")
                    print("   - Copy the ENTIRE contents of 'docusign_public.key' file")
                    print("   - Paste it (must include -----BEGIN/END----- lines)")
                    print("   - Click SAVE")
                    print("4. WAIT 3-5 minutes for DocuSign to process")
                    print("5. Run this test again")
                    
                    print("\n📄 Your public key to upload:")
                    print("   Location: backend/docusign_public.key")
                    print("\n   Run: type backend\\docusign_public.key")
            
            return False
            
    except Exception as e:
        print(f"❌ Request failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("\n" + "=" * 60)
    print("   DOCUSIGN COMPREHENSIVE DIAGNOSTIC")
    print("=" * 60)
    
    # Step 1: Check connectivity
    if not check_docusign_connection():
        print("\n❌ Cannot proceed - DocuSign is not reachable")
        return
    
    # Step 2: Create JWT
    token = test_jwt_creation()
    if not token:
        print("\n❌ Cannot proceed - JWT creation failed")
        return
    
    # Step 3: Test authentication
    success = test_docusign_auth(token)
    
    print("\n" + "=" * 60)
    if success:
        print("✅ ALL TESTS PASSED - DocuSign is ready to use!")
    else:
        print("⚠️ AUTHENTICATION FAILED - Follow the troubleshooting steps above")
    print("=" * 60 + "\n")

if __name__ == "__main__":
    main()








