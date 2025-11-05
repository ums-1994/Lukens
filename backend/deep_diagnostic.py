"""
Deep diagnostic to identify the exact DocuSign issue
"""
import os
import requests
import jwt
from datetime import datetime, timezone, timedelta
from dotenv import load_dotenv
import json

load_dotenv()

def test_everything():
    print("\n" + "=" * 80)
    print("   DOCUSIGN DEEP DIAGNOSTIC")
    print("=" * 80)
    
    # 1. Check files exist
    print("\n📁 STEP 1: Checking Key Files...")
    print("-" * 80)
    
    private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH')
    
    if os.path.exists(private_key_path):
        print(f"✅ Private key exists: {private_key_path}")
        with open(private_key_path, 'r') as f:
            private_key = f.read()
            print(f"   Length: {len(private_key)} characters")
            print(f"   Starts with: {private_key[:27]}")
    else:
        print(f"❌ Private key NOT found: {private_key_path}")
        return
    
    if os.path.exists('docusign_public.key'):
        print(f"✅ Public key exists: docusign_public.key")
        with open('docusign_public.key', 'r') as f:
            public_key_content = f.read()
            print(f"   Length: {len(public_key_content)} characters")
    else:
        print("❌ Public key NOT found")
        return
    
    # 2. Check configuration
    print("\n⚙️  STEP 2: Checking Configuration...")
    print("-" * 80)
    
    config = {
        'DOCUSIGN_INTEGRATION_KEY': os.getenv('DOCUSIGN_INTEGRATION_KEY'),
        'DOCUSIGN_USER_ID': os.getenv('DOCUSIGN_USER_ID'),
        'DOCUSIGN_ACCOUNT_ID': os.getenv('DOCUSIGN_ACCOUNT_ID'),
        'DOCUSIGN_AUTH_SERVER': os.getenv('DOCUSIGN_AUTH_SERVER'),
        'DOCUSIGN_BASE_PATH': os.getenv('DOCUSIGN_BASE_PATH'),
    }
    
    all_present = True
    for key, value in config.items():
        if value:
            if 'KEY' in key:
                display = f"{value[:8]}...{value[-4:]}"
            else:
                display = value
            print(f"✅ {key}: {display}")
        else:
            print(f"❌ {key}: NOT SET")
            all_present = False
    
    if not all_present:
        print("\n❌ Configuration incomplete!")
        return
    
    # 3. Test keypair validity
    print("\n🔐 STEP 3: Testing Keypair...")
    print("-" * 80)
    
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.backends import default_backend
    
    try:
        private_key_obj = serialization.load_pem_private_key(
            private_key.encode(),
            password=None,
            backend=default_backend()
        )
        print("✅ Private key is valid")
        
        public_key_obj = serialization.load_pem_public_key(
            public_key_content.encode(),
            backend=default_backend()
        )
        print("✅ Public key is valid")
        print("✅ Keys are properly formatted")
    except Exception as e:
        print(f"❌ Key format error: {e}")
        return
    
    # 4. Create JWT
    print("\n🔑 STEP 4: Creating JWT Token...")
    print("-" * 80)
    
    integration_key = config['DOCUSIGN_INTEGRATION_KEY']
    user_id = config['DOCUSIGN_USER_ID']
    auth_server = config['DOCUSIGN_AUTH_SERVER']
    
    now = datetime.now(timezone.utc)
    exp = now + timedelta(hours=1)
    
    jwt_payload = {
        'iss': integration_key,
        'sub': user_id,
        'aud': f'https://{auth_server}',  # Must include https://
        'iat': int(now.timestamp()),
        'exp': int(exp.timestamp()),
        'scope': 'signature impersonation'
    }
    
    print("JWT Payload:")
    print(json.dumps(jwt_payload, indent=2))
    
    try:
        token = jwt.encode(jwt_payload, private_key, algorithm='RS256')
        print(f"\n✅ JWT created successfully")
        print(f"   Token length: {len(token)} chars")
        print(f"   First 50 chars: {token[:50]}...")
    except Exception as e:
        print(f"❌ JWT creation failed: {e}")
        return
    
    # 5. Test DocuSign authentication
    print("\n🌐 STEP 5: Testing DocuSign Authentication...")
    print("-" * 80)
    
    url = f'https://{auth_server}/oauth/token'
    
    print(f"Sending request to: {url}")
    print(f"Integration Key: {integration_key}")
    print(f"User ID: {user_id}")
    
    try:
        response = requests.post(
            url,
            data={
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion': token
            },
            headers={'Content-Type': 'application/x-www-form-urlencoded'},
            timeout=10
        )
        
        print(f"\nResponse Status: {response.status_code}")
        print(f"Response Body: {response.text}")
        
        if response.status_code == 200:
            print("\n" + "=" * 80)
            print("🎉 SUCCESS! Authentication works!")
            print("=" * 80)
            result = response.json()
            print(f"Access Token: {result['access_token'][:30]}...{result['access_token'][-20:]}")
            return True
        else:
            print("\n" + "=" * 80)
            print("❌ AUTHENTICATION FAILED")
            print("=" * 80)
            
            error_data = response.json() if response.headers.get('content-type', '').startswith('application/json') else {}
            error = error_data.get('error', 'unknown')
            error_desc = error_data.get('error_description', '')
            
            print(f"\nError: {error}")
            print(f"Description: {error_desc}")
            
            if 'no_valid_keys_or_signatures' in error_desc:
                print("\n" + "⚠️ " * 40)
                print("\n🔴 PROBLEM: Public Key Mismatch")
                print("\nThis means DocuSign DOES NOT have the correct public key.")
                print("\n📋 TROUBLESHOOTING:")
                print("\n1️⃣  Did you DELETE ALL old keypairs in DocuSign?")
                print("   Go to: https://demo.docusign.net")
                print("   Settings → Apps & Keys → Your App")
                print("   In 'RSA Keypairs' section: DELETE EVERY SINGLE ONE!")
                print("\n2️⃣  Did you upload the ENTIRE public key?")
                print("   It must include the -----BEGIN/END----- lines")
                print("   Run: python show_public_key.py")
                print("   Copy ALL 7 lines and paste in DocuSign")
                print("\n3️⃣  Are you looking at the CORRECT app?")
                print(f"   Your Integration Key: {integration_key}")
                print("   Make sure you're editing the app with THIS key!")
                print("\n4️⃣  Did you wait 5 minutes after uploading?")
                print("   DocuSign needs time to propagate the key")
                print("\n5️⃣  Did you grant consent AFTER uploading the key?")
                print("   Run: python check_consent.py")
                print("   Open the URL and click 'Allow Access'")
                
                print("\n" + "⚠️ " * 40)
                
                print("\n\n💡 RECOMMENDED ACTION:")
                print("-" * 80)
                print("1. Open DocuSign in your browser RIGHT NOW")
                print("2. Count how many RSA Keypairs you see")
                print("3. If you see MORE THAN 1, that's the problem!")
                print("4. DELETE ALL of them")
                print("5. Run: python show_public_key.py")
                print("6. Add ONLY that one key")
                print("7. Wait 5 minutes")
                print("8. Run: python check_consent.py and grant consent")
                print("9. Run: python quick_test.py")
                print("-" * 80)
            
            elif 'consent_required' in error_desc:
                print("\n🔴 PROBLEM: Consent Not Granted")
                print("\nRun: python check_consent.py")
                print("Open the URL and click 'Allow Access'")
            
            return False
            
    except Exception as e:
        print(f"\n❌ Request failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_everything()

