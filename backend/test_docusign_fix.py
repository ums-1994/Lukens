#!/usr/bin/env python3
"""
Quick test script to verify DocuSign Account ID fix
"""
import os
import sys

print("=" * 80)
print("🔍 DocuSign Account ID Fix - Diagnostic Test")
print("=" * 80)

# Check if DocuSign SDK is installed
print("\n1. Checking DocuSign SDK installation...")
try:
    from docusign_esign import ApiClient
    print("   ✅ DocuSign SDK is installed")
    DOCUSIGN_AVAILABLE = True
except ImportError:
    print("   ❌ DocuSign SDK NOT installed")
    print("   Run: pip install docusign-esign")
    DOCUSIGN_AVAILABLE = False
    sys.exit(1)

# Check environment variables
print("\n2. Checking environment variables...")
required_vars = {
    'DOCUSIGN_INTEGRATION_KEY': os.getenv('DOCUSIGN_INTEGRATION_KEY'),
    'DOCUSIGN_USER_ID': os.getenv('DOCUSIGN_USER_ID'),
    'DOCUSIGN_PRIVATE_KEY_PATH': os.getenv('DOCUSIGN_PRIVATE_KEY_PATH', './docusign_private.key'),
    'DOCUSIGN_ACCOUNT_ID': os.getenv('DOCUSIGN_ACCOUNT_ID'),  # Optional now
}

for var_name, var_value in required_vars.items():
    if var_value:
        if 'KEY' in var_name or 'ID' in var_name:
            # Mask sensitive values
            display_value = f"{var_value[:8]}...{var_value[-4:]}" if len(var_value) > 12 else "***"
        else:
            display_value = var_value
        print(f"   ✅ {var_name}: {display_value}")
    else:
        if var_name == 'DOCUSIGN_ACCOUNT_ID':
            print(f"   ⚠️  {var_name}: NOT SET (optional - will be extracted from JWT)")
        else:
            print(f"   ❌ {var_name}: NOT SET")

# Check private key file
print("\n3. Checking private key file...")
private_key_path = required_vars['DOCUSIGN_PRIVATE_KEY_PATH']
if os.path.exists(private_key_path):
    print(f"   ✅ Private key file exists: {private_key_path}")
    try:
        with open(private_key_path, 'r') as f:
            key_content = f.read()
            if key_content.strip().startswith('-----BEGIN'):
                print("   ✅ Private key format looks correct")
            else:
                print("   ⚠️  Private key format may be incorrect (should start with '-----BEGIN')")
    except Exception as e:
        print(f"   ❌ Error reading private key: {e}")
else:
    print(f"   ❌ Private key file NOT FOUND: {private_key_path}")
    print("   Set DOCUSIGN_PRIVATE_KEY_PATH or place key at ./docusign_private.key")

# Test JWT authentication
print("\n4. Testing JWT authentication...")
if not all([required_vars['DOCUSIGN_INTEGRATION_KEY'], required_vars['DOCUSIGN_USER_ID']]):
    print("   ⚠️  Skipping - missing required credentials")
else:
    try:
        from api.utils.docusign_utils import get_docusign_jwt_token
        
        print("   🔐 Attempting authentication...")
        auth_data = get_docusign_jwt_token()
        
        access_token = auth_data.get('access_token')
        account_id = auth_data.get('account_id')
        
        if access_token:
            print(f"   ✅ Access token obtained: {access_token[:30]}...")
        else:
            print("   ❌ No access token returned")
            
        if account_id:
            print(f"   ✅ Account ID extracted: {account_id}")
            print("   ✅ FIX VERIFIED - Account ID comes from JWT response!")
        else:
            print("   ⚠️  Account ID not extracted from JWT")
            if required_vars['DOCUSIGN_ACCOUNT_ID']:
                print(f"   ⚠️  Will fallback to .env: {required_vars['DOCUSIGN_ACCOUNT_ID'][:8]}...")
            else:
                print("   ❌ No account ID available (neither from JWT nor .env)")
                
    except Exception as e:
        print(f"   ❌ Authentication failed: {e}")
        import traceback
        traceback.print_exc()

print("\n" + "=" * 80)
print("📋 Summary:")
print("=" * 80)
print("If all checks pass, DocuSign should work correctly.")
print("The Account ID fix extracts account_id from JWT response automatically.")
print("=" * 80)
