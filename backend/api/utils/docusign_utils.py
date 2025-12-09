"""
DocuSign utility functions
"""
import os
import traceback

DOCUSIGN_AVAILABLE = False
try:
    from docusign_esign import ApiClient
    DOCUSIGN_AVAILABLE = True
except ImportError:
    pass


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
        
        # If not in env var, try to read from file
        if not private_key:
            private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH', './docusign_private.key')
            
            # Check if private key file exists
            if not os.path.exists(private_key_path):
                raise Exception(
                    f"DocuSign private key not found. Either:\n"
                    f"1. Set DOCUSIGN_PRIVATE_KEY environment variable with the key content, OR\n"
                    f"2. Set DOCUSIGN_PRIVATE_KEY_PATH to a file path (current: {private_key_path})"
                )
            
            # Read private key from file
            try:
                with open(private_key_path, 'r') as key_file:
                    private_key = key_file.read()
            except Exception as e:
                raise Exception(f"Failed to read private key file: {e}")
        
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









