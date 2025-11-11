"""
Verify that the RSA keypair is valid and matches
"""
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

def verify_keypair():
    print("🔐 Verifying RSA Keypair...")
    print("-" * 50)
    
    try:
        # Read private key
        with open('docusign_private.key', 'rb') as f:
            private_key = serialization.load_pem_private_key(
                f.read(),
                password=None,
                backend=default_backend()
            )
        print("✅ Private key loaded and valid")
        
        # Read public key
        with open('docusign_public.key', 'rb') as f:
            public_key = serialization.load_pem_public_key(
                f.read(),
                backend=default_backend()
            )
        print("✅ Public key loaded and valid")
        
        # Test encryption/decryption
        test_message = b"DocuSign Integration Test"
        
        # Sign with private key
        signature = private_key.sign(
            test_message,
            padding.PSS(
                mgf=padding.MGF1(hashes.SHA256()),
                salt_length=padding.PSS.MAX_LENGTH
            ),
            hashes.SHA256()
        )
        print("✅ Signed test message with private key")
        
        # Verify with public key
        try:
            public_key.verify(
                signature,
                test_message,
                padding.PSS(
                    mgf=padding.MGF1(hashes.SHA256()),
                    salt_length=padding.PSS.MAX_LENGTH
                ),
                hashes.SHA256()
            )
            print("✅ Verified signature with public key")
            print("-" * 50)
            print("🎉 Keypair is valid and matches!")
            print("\nYour private and public keys are correctly paired.")
            return True
        except Exception as e:
            print(f"❌ Signature verification failed: {e}")
            print("-" * 50)
            print("⚠️ Keys do NOT match!")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    verify_keypair()








