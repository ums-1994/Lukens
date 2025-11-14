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
    """
    if not DOCUSIGN_AVAILABLE:
        raise Exception("DocuSign SDK not installed")
    
    try:
        integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
        user_id = os.getenv('DOCUSIGN_USER_ID')
        auth_server = os.getenv('DOCUSIGN_AUTH_SERVER', 'account-d.docusign.com')
        private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH', './docusign_private.key')
        
        if not all([integration_key, user_id]):
            raise Exception("DocuSign credentials not configured")
        
        # Read private key
        with open(private_key_path, 'r') as key_file:
            private_key = key_file.read()
        
        # Create API client
        api_client = ApiClient()
        api_client.set_base_path(f"https://{auth_server}")
        
        # Request JWT token
        response = api_client.request_jwt_user_token(
            client_id=integration_key,
            user_id=user_id,
            oauth_host_name=auth_server,
            private_key_bytes=private_key,
            expires_in=3600,
            scopes=["signature", "impersonation"]
        )
        
        return response.access_token
        
    except Exception as e:
        print(f"❌ Error getting DocuSign JWT token: {e}")
        traceback.print_exc()
        raise



