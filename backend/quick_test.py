"""Quick DocuSign authentication test"""
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

now = datetime.now(timezone.utc)
token = jwt.encode({
    'iss': integration_key,
    'sub': user_id,
    'aud': f'https://{auth_server}',  # Must include https://
    'iat': int(now.timestamp()),
    'exp': int((now + timedelta(hours=1)).timestamp()),
    'scope': 'signature impersonation'
}, private_key, algorithm='RS256')

response = requests.post(
    f'https://{auth_server}/oauth/token',
    data={
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': token
    },
    headers={'Content-Type': 'application/x-www-form-urlencoded'}
)

print("\n" + "=" * 60)
if response.status_code == 200:
    print("✅ SUCCESS! DocuSign authentication works!")
    print("🎉 Your integration is ready to use!")
    token = response.json().get('access_token')
    print(f"\n   Access Token: {token[:30]}...{token[-20:]}")
else:
    print("❌ Authentication failed")
    print(f"   Status: {response.status_code}")
    print(f"   Error: {response.json()}")
    print("\n⚠️ Make sure you:")
    print("   1. Deleted ALL old RSA keypairs in DocuSign")
    print("   2. Added the NEW public key")
    print("   3. Waited 3-5 minutes")
print("=" * 60 + "\n")

