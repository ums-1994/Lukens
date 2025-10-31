"""
Display the public key in an easy-to-copy format
Extracts it from the private key to ensure it matches
"""
import os
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

def extract_and_display_public_key():
    print("\n" + "=" * 70)
    print("   YOUR PUBLIC KEY TO UPLOAD TO DOCUSIGN")
    print("=" * 70)
    print("\n⚠️  IMPORTANT: Copy EVERYTHING below (including the BEGIN/END lines)\n")
    print("-" * 70)
    
    try:
        # Get private key path from environment or default
        private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH', 'docusign_private.key')
        
        # Read private key
        with open(private_key_path, 'rb') as f:
            private_key_data = f.read()
        
        # Load the private key
        private_key = serialization.load_pem_private_key(
            private_key_data,
            password=None,
            backend=default_backend()
        )
        
        # Extract the public key from the private key
        public_key = private_key.public_key()
        
        # Serialize it to PEM format (what DocuSign expects)
        public_pem = public_key.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        ).decode('utf-8')
        
        print(public_pem)
        print("-" * 70)
        return True
        
    except FileNotFoundError:
        print("\n❌ ERROR: Private key file not found!")
        print(f"   Looking for: {os.getenv('DOCUSIGN_PRIVATE_KEY_PATH', 'docusign_private.key')}")
        print("   Make sure you're in the 'backend' directory and the key file exists")
        return False
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        print("   This means your private key file is corrupted or invalid")
        return False

if extract_and_display_public_key():
    print("\n📋 STEP-BY-STEP INSTRUCTIONS:")
    print("\n1. Go to: https://demo.docusign.net")
    print("2. Click profile icon (top right) → Settings")
    print("3. Click 'Apps and Keys' in left menu")
    print("4. Click on your app (Integration Key: c72eda5f-...)")
    print("\n5. ⚠️  IN THE 'RSA Keypairs' SECTION:")
    print("   - Look for ANY existing keypairs")
    print("   - Click the TRASH ICON (🗑️) next to EACH one to delete ALL of them")
    print("   - Make sure the section is COMPLETELY EMPTY")
    print("\n6. NOW click '+ ADD RSA KEYPAIR'")
    print("7. A text box will appear")
    print("8. Copy EVERYTHING between the lines above")
    print("9. Paste it in the text box")
    print("10. Click SAVE")
    print("11. You should see 'RSA public key added successfully'")
    print("\n12. ⏰ WAIT 5 MINUTES (set a timer!)")
    print("13. Run: python test_docusign_sdk.py")
    print("\n" + "=" * 70)
    print("\n💡 TIP: If you have multiple keypairs, DocuSign might use the wrong one!")
    print("   That's why you MUST delete all old ones first.\n")



