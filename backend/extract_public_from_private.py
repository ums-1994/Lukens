"""
Extract the public key from your private key to verify it matches DocuSign
"""
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

print("=" * 80)
print("   EXTRACTING PUBLIC KEY FROM YOUR PRIVATE KEY")
print("=" * 80)

try:
    # Read your private key
    with open("docusign_private.key", "rb") as f:
        private_key_data = f.read()
    
    print("\n✅ Private key file loaded")
    print(f"   Length: {len(private_key_data)} bytes")
    
    # Load the private key
    private_key = serialization.load_pem_private_key(
        private_key_data,
        password=None,
        backend=default_backend()
    )
    
    print("✅ Private key is valid and can be loaded")
    
    # Extract the public key from the private key
    public_key = private_key.public_key()
    
    # Serialize it to PEM format (what DocuSign expects)
    public_pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    ).decode('utf-8')
    
    print("\n" + "=" * 80)
    print("   THIS IS THE PUBLIC KEY THAT MATCHES YOUR PRIVATE KEY")
    print("=" * 80)
    print(public_pem)
    print("=" * 80)
    
    # Save it to a file for easy copying
    with open("EXPECTED_PUBLIC_KEY.txt", "w") as f:
        f.write(public_pem)
    
    print("\n✅ Public key saved to: EXPECTED_PUBLIC_KEY.txt")
    
    print("\n" + "=" * 80)
    print("   WHAT TO DO NOW:")
    print("=" * 80)
    print("1. Go to DocuSign: https://demo.docusign.net")
    print("2. Settings → Apps & Keys → Your App (db0483f5...c1cd)")
    print("3. Look at the RSA Keypairs section")
    print("4. Check if the public key shown above MATCHES what you see in DocuSign")
    print("5. If they DON'T match, DELETE the old key in DocuSign")
    print("6. Click 'ADD RSA KEYPAIR' and paste the key shown above")
    print("7. Wait 5 minutes")
    print("8. Run: python check_consent.py (grant consent again)")
    print("9. Run: python test_docusign_sdk.py")
    print("=" * 80)
    
except FileNotFoundError:
    print("\n❌ ERROR: docusign_private.key not found!")
    print("   Make sure you're in the 'backend' directory")
except Exception as e:
    print(f"\n❌ ERROR: {e}")
    print("\n   This means your private key file is corrupted or invalid")
    print("   You need to generate a fresh keypair in DocuSign")








