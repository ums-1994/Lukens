"""
Check if consent has been granted and provide the exact consent URL
"""
import os
from dotenv import load_dotenv

load_dotenv()

integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
auth_server = os.getenv('DOCUSIGN_AUTH_SERVER')

print("\n" + "=" * 70)
print("   DOCUSIGN CONSENT CHECKER")
print("=" * 70)

print("\n🔍 Checking if consent might be an issue...")
print("-" * 70)

# Build consent URL
consent_url = f"https://{auth_server}/oauth/auth?response_type=code&scope=signature%20impersonation&client_id={integration_key}&redirect_uri=https://www.docusign.com/api"

print("\n📋 Your Integration Key:", integration_key)
print("📋 Auth Server:", auth_server)

print("\n" + "=" * 70)
print("   GRANT CONSENT (Do this AFTER uploading the public key)")
print("=" * 70)

print("\n1️⃣  Open this URL in your browser:\n")
print(f"   {consent_url}\n")

print("2️⃣  You'll see a DocuSign page asking to 'Allow Access'")
print("3️⃣  Click 'ALLOW ACCESS' button")
print("4️⃣  You'll be redirected to docusign.com/api (that's normal!)")
print("5️⃣  The consent is now granted (one-time only)")

print("\n" + "=" * 70)
print("\n⚠️  IMPORTANT ORDER:")
print("   1. Delete all old RSA keypairs in DocuSign")
print("   2. Upload the NEW public key")
print("   3. WAIT 5 minutes")
print("   4. Grant consent using the URL above")
print("   5. Test with: python quick_test.py")
print("\n" + "=" * 70)

print("\n💡 Note: You must have the correct RSA key uploaded BEFORE granting consent!")
print("   Otherwise, consent won't work.\n")








