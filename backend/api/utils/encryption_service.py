"""
Proposal Encryption Service
Handles encryption/decryption of proposal content for secure client delivery
"""
import os
import secrets
import hashlib
from datetime import datetime, timedelta
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.backends import default_backend
import base64


class ProposalEncryptionService:
    """Service for encrypting and decrypting proposal content"""
    
    def __init__(self):
        # Get master key from environment or generate one (for development)
        self.master_key = os.getenv('PROPOSAL_ENCRYPTION_KEY')
        if not self.master_key:
            # Generate a key for development (should be set in production)
            self.master_key = Fernet.generate_key().decode()
            print("[WARN] Using auto-generated encryption key. Set PROPOSAL_ENCRYPTION_KEY in production!")
    
    def _derive_key(self, proposal_id: int, salt: bytes = None) -> bytes:
        """
        Derive a unique encryption key for a specific proposal
        Uses PBKDF2 with the master key and proposal ID
        """
        if salt is None:
            # Generate salt from proposal ID for consistency
            salt = hashlib.sha256(str(proposal_id).encode()).digest()[:16]
        
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
            backend=default_backend()
        )
        
        # Combine master key with proposal ID for uniqueness
        key_material = f"{self.master_key}:{proposal_id}".encode()
        key = base64.urlsafe_b64encode(kdf.derive(key_material))
        return key
    
    def encrypt_proposal_content(self, proposal_id: int, content: str) -> dict:
        """
        Encrypt proposal content
        
        Args:
            proposal_id: Unique proposal identifier
            content: Proposal content to encrypt
            
        Returns:
            dict with encrypted_content, salt (base64), and encryption_metadata
        """
        try:
            # Derive key for this proposal
            salt = hashlib.sha256(str(proposal_id).encode()).digest()[:16]
            key = self._derive_key(proposal_id, salt)
            
            # Create Fernet cipher
            fernet = Fernet(key)
            
            # Encrypt content
            encrypted_bytes = fernet.encrypt(content.encode('utf-8'))
            encrypted_content = base64.urlsafe_b64encode(encrypted_bytes).decode('utf-8')
            
            return {
                'encrypted_content': encrypted_content,
                'salt': base64.urlsafe_b64encode(salt).decode('utf-8'),
                'encryption_method': 'AES-256-Fernet',
                'encrypted_at': datetime.utcnow().isoformat()
            }
        except Exception as e:
            print(f"[ERROR] Encryption failed: {e}")
            raise Exception(f"Failed to encrypt proposal content: {str(e)}")
    
    def decrypt_proposal_content(self, proposal_id: int, encrypted_content: str, salt: str) -> str:
        """
        Decrypt proposal content
        
        Args:
            proposal_id: Unique proposal identifier
            encrypted_content: Base64 encoded encrypted content
            salt: Base64 encoded salt used for encryption
            
        Returns:
            Decrypted content as string
        """
        try:
            # Decode salt
            salt_bytes = base64.urlsafe_b64decode(salt.encode('utf-8'))
            
            # Derive the same key
            key = self._derive_key(proposal_id, salt_bytes)
            
            # Create Fernet cipher
            fernet = Fernet(key)
            
            # Decrypt content
            encrypted_bytes = base64.urlsafe_b64decode(encrypted_content.encode('utf-8'))
            decrypted_bytes = fernet.decrypt(encrypted_bytes)
            
            return decrypted_bytes.decode('utf-8')
        except Exception as e:
            print(f"[ERROR] Decryption failed: {e}")
            raise Exception(f"Failed to decrypt proposal content: {str(e)}")
    
    def generate_secure_token(self, length: int = 32) -> str:
        """
        Generate a cryptographically secure token for proposal access
        
        Args:
            length: Token length in bytes (default 32)
            
        Returns:
            URL-safe base64 encoded token
        """
        return secrets.token_urlsafe(length)
    
    def hash_password(self, password: str) -> str:
        """
        Hash a password for secure storage
        
        Args:
            password: Plain text password
            
        Returns:
            Hashed password (salt:hash format)
        """
        salt = secrets.token_hex(16)
        password_hash = hashlib.pbkdf2_hmac(
            'sha256',
            password.encode('utf-8'),
            salt.encode('utf-8'),
            100000
        )
        return f"{salt}:{base64.b64encode(password_hash).decode('utf-8')}"
    
    def verify_password(self, password: str, stored_hash: str) -> bool:
        """
        Verify a password against stored hash
        
        Args:
            password: Plain text password to verify
            stored_hash: Stored hash in format salt:hash
            
        Returns:
            True if password matches, False otherwise
        """
        try:
            salt, password_hash = stored_hash.split(':')
            new_hash = hashlib.pbkdf2_hmac(
                'sha256',
                password.encode('utf-8'),
                salt.encode('utf-8'),
                100000
            )
            return base64.b64encode(new_hash).decode('utf-8') == password_hash
        except Exception:
            return False


# Singleton instance
_encryption_service = None

def get_encryption_service() -> ProposalEncryptionService:
    """Get singleton encryption service instance"""
    global _encryption_service
    if _encryption_service is None:
        _encryption_service = ProposalEncryptionService()
    return _encryption_service

























