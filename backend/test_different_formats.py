"""
Test different JWT audience formats to see which one DocuSign accepts
"""
import os
import requests
import jwt
from datetime import datetime, timezone, timedelta
from dotenv import load_dotenv

load_dotenv()

integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
user_id = os.getenv('DOCUSIGN_USER_ID')
auth_server = os.getenv('DOCUSIGN_AUTH_SERVER')

with open(os.getenv('DOCUSIGN_PRIVATE_KEY_PATH'), 'r') as f:
    private_key = f.read()

# Try different audience formats
audiences = [
    auth_server,  # account-d.docusign.com
    f"https://{auth_server}",  # https://account-d.docusign.com
    f"{auth_server}/oauth",  # account-d.docusign.com/oauth
]

print("\n" + "=" * 80)
print("   TESTING DIFFERENT JWT FORMATS")
print("=" * 80)

for i, aud in enumerate(audiences, 1):
    print(f"\n📋 Test #{i}: audience = '{aud}'")
    print("-" * 80)
    
    now = datetime.now(timezone.utc)
    
    payload = {
        'iss': integration_key,
        'sub': user_id,
        'aud': aud,
        'iat': int(now.timestamp()),
        'exp': int((now + timedelta(hours=1)).timestamp()),
        'scope': 'signature impersonation'
    }
    
    token = jwt.encode(payload, private_key, algorithm='RS256')
    
    try:
        response = requests.post(
            f'https://{auth_server}/oauth/token',
            data={
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion': token
            },
            headers={'Content-Type': 'application/x-www-form-urlencoded'},
            timeout=10
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 200:
            print("\n🎉 SUCCESS! This format works!")
            print(f"   Correct audience format: {aud}")
            result = response.json()
            token = result['access_token']
            print(f"   Access Token: {token[:30]}...{token[-20:]}")
            print("\n✅ DocuSign authentication is working!")
            break
        else:
            error_data = response.json()
            print(f"❌ Error: {error_data.get('error')}")
            print(f"   Description: {error_data.get('error_description', 'N/A')}")
            
    except Exception as e:
        print(f"❌ Request failed: {e}")

print("\n" + "=" * 80)






