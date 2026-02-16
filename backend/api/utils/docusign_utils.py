"""
DocuSign utility functions
"""
import os
import traceback
from pathlib import Path

from dotenv import load_dotenv

# Load environment variables deterministically regardless of cwd.
_this_file = Path(__file__).resolve()
_backend_dir = _this_file.parents[2]  # .../backend
_repo_root = _backend_dir.parent
load_dotenv(dotenv_path=_backend_dir / '.env', override=False)
load_dotenv(dotenv_path=_repo_root / '.env', override=False)

DOCUSIGN_AVAILABLE = False
try:
    from docusign_esign import ApiClient
    DOCUSIGN_AVAILABLE = True
    print("✅ DocuSign SDK imported successfully in docusign_utils")
except ImportError as e:
    DOCUSIGN_AVAILABLE = False
    print(f"⚠️ DocuSign SDK not available in docusign_utils: {e}")
except Exception as e:
    DOCUSIGN_AVAILABLE = False
    print(f"⚠️ DocuSign SDK import error in docusign_utils: {e}")


def get_docusign_jwt_token():
    """
    Get DocuSign access token using JWT authentication
    
    Returns:
        str: Access token for DocuSign API
        
    Raises:
        Exception: If SDK not installed, credentials missing, or authentication fails
    """
    if not DOCUSIGN_AVAILABLE:
        raise Exception("DocuSign SDK not installed. Install with: pip install docusign-esign")
    
    try:
        # Get environment variables
        integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
        user_id = os.getenv('DOCUSIGN_USER_ID')
        auth_server = os.getenv('DOCUSIGN_AUTH_SERVER', 'account-d.docusign.com')
        
        # Validate required credentials
        if not integration_key:
            raise Exception("DOCUSIGN_INTEGRATION_KEY not set in environment variables")
        if not user_id:
            raise Exception("DOCUSIGN_USER_ID not set in environment variables")
        
        # Try to get private key from environment variable first (for Render/cloud deployments)
        private_key = os.getenv('DOCUSIGN_PRIVATE_KEY')

        # If not in DOCUSIGN_PRIVATE_KEY, fall back to DOCUSIGN_PRIVATE_KEY_PATH.
        # IMPORTANT: Many existing deployments store the *key contents* directly
        # in DOCUSIGN_PRIVATE_KEY_PATH instead of a file path. To be backward
        # compatible, we treat a value that looks like a PEM key as the key
        # itself; otherwise we treat it as a filesystem path and try to read it.
        if not private_key:
            raw_path_or_key = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH')

            if raw_path_or_key:
                candidate = raw_path_or_key.strip()

                # If it starts with a PEM header, assume it is the key content.
                if candidate.startswith('-----BEGIN'):
                    private_key = raw_path_or_key
                else:
                    private_key_path = raw_path_or_key or './docusign_private.key'

                    # Resolve relative paths relative to the backend directory (not cwd)
                    try:
                        if not os.path.isabs(private_key_path):
                            private_key_path = str((_backend_dir / private_key_path).resolve())
                    except Exception:
                        pass

                    # Check if private key file exists
                    if not os.path.exists(private_key_path):
                        raise Exception(
                            f"DocuSign private key not found. Either:\n"
                            f"1. Set DOCUSIGN_PRIVATE_KEY environment variable with the key content, OR\n"
                            f"2. Set DOCUSIGN_PRIVATE_KEY_PATH to a valid file path (current: {private_key_path})"
                        )

                    # Read private key from file
                    try:
                        with open(private_key_path, 'r') as key_file:
                            private_key = key_file.read()
                    except Exception as e:
                        raise Exception(f"Failed to read private key file: {e}")

        # If we still don't have a private key at this point, raise a clear error
        if not private_key:
            raise Exception(
                "DocuSign private key not configured. Set DOCUSIGN_PRIVATE_KEY "
                "or DOCUSIGN_PRIVATE_KEY_PATH with either the key contents or a valid file path."
            )
        
        # Handle newlines in environment variable (Render may escape them)
        if private_key:
            # Replace literal \n with actual newlines
            private_key = private_key.replace('\\n', '\n')
        
        # Validate private key format
        if not private_key.strip().startswith('-----BEGIN'):
            raise Exception("Invalid private key format. Key should start with '-----BEGIN'")
        
        print(f"🔐 Authenticating with DocuSign...")
        print(f"   Integration Key: {integration_key[:8]}...{integration_key[-4:]}")
        print(f"   User ID: {user_id}")
        print(f"   Auth Server: {auth_server}")
        
        # Create API client
        api_client = ApiClient()
        api_client.set_base_path(f"https://{auth_server}")
        
        # Request JWT token
        try:
            response = api_client.request_jwt_user_token(
                client_id=integration_key,
                user_id=user_id,
                oauth_host_name=auth_server,
                private_key_bytes=private_key,
                expires_in=3600,  # Token valid for 1 hour
                scopes=["signature", "impersonation"]
            )
            
            if not response or not hasattr(response, 'access_token'):
                raise Exception("Failed to get access token from DocuSign")
            
            print(f"✅ DocuSign authentication successful")
            return response.access_token
            
        except Exception as auth_error:
            error_msg = str(auth_error)
            if "consent_required" in error_msg.lower():
                raise Exception(
                    "DocuSign consent required. Please grant consent by visiting:\n"
                    f"https://{auth_server}/oauth/auth?response_type=code&scope=signature%20impersonation&"
                    f"client_id={integration_key}&redirect_uri=https://www.docusign.com"
                )
            elif "invalid_grant" in error_msg.lower():
                raise Exception(
                    "DocuSign authentication failed. Please verify:\n"
                    "1. Integration Key is correct\n"
                    "2. User ID is correct\n"
                    "3. Private key matches the public key uploaded to DocuSign\n"
                    "4. Consent has been granted for this integration"
                )
            else:
                raise Exception(f"DocuSign authentication error: {error_msg}")
        
    except Exception as e:
        print(f"❌ Error getting DocuSign JWT token: {e}")
        traceback.print_exc()
        raise









