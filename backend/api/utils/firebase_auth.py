"""
Firebase Authentication utilities
Verifies Firebase ID tokens from the frontend
"""
import os
try:
    import firebase_admin
    from firebase_admin import credentials, auth
except Exception:
    firebase_admin = None
    credentials = None
    auth = None
from functools import wraps
from flask import request, jsonify

# Initialize Firebase Admin SDK
_firebase_app = None
_last_verify_error = None


def get_last_verify_error():
    return _last_verify_error


def _get_project_id_from_env():
    return (
        os.getenv('FIREBASE_PROJECT_ID')
        or os.getenv('GOOGLE_CLOUD_PROJECT')
        or os.getenv('GCLOUD_PROJECT')
    )


def _get_project_id_from_service_account_info(cred_info):
    if not isinstance(cred_info, dict):
        return None
    return cred_info.get('project_id')

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    global _firebase_app

    if _firebase_app is not None:
        return _firebase_app

    if firebase_admin is None or credentials is None:
        print("⚠️ Firebase Admin SDK not available (firebase_admin not installed)")
        return None
    
    try:
        # Try to get credentials from environment variable (service account JSON)
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        
        # If not set, try default location in backend directory
        if not cred_path:
            backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
            default_path = os.path.join(backend_dir, 'firebase-service-account.json')
            if os.path.exists(default_path):
                cred_path = default_path
                print(f"📁 Using default Firebase credentials: {default_path}")
        
        project_id = None

        if cred_path and os.path.exists(cred_path):
            try:
                import json
                with open(cred_path, 'r', encoding='utf-8') as f:
                    cred_info = json.load(f)
                project_id = _get_project_id_from_service_account_info(cred_info)
            except Exception:
                project_id = None

            cred = credentials.Certificate(cred_path)
            options = {'projectId': project_id} if project_id else None
            _firebase_app = firebase_admin.initialize_app(cred, options=options)
            print(f"✅ Firebase Admin SDK initialized from: {cred_path}")
        else:
            # Try to use default credentials (for Google Cloud environments)
            # Or use service account JSON from environment variable
            service_account_json = os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON')
            if service_account_json:
                import json
                cred_info = json.loads(service_account_json)
                project_id = _get_project_id_from_service_account_info(cred_info)
                cred = credentials.Certificate(cred_info)
                options = {'projectId': project_id} if project_id else None
                _firebase_app = firebase_admin.initialize_app(cred, options=options)
                print("✅ Firebase Admin SDK initialized from environment variable")
            else:
                # Try default credentials (for local development with gcloud auth)
                try:
                    project_id = _get_project_id_from_env()
                    if not project_id:
                        print("⚠️ Firebase Admin SDK not initialized: project ID not set")
                        print("   Set FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT) for local development")
                        return None

                    _firebase_app = firebase_admin.initialize_app(options={'projectId': project_id})
                    print("✅ Firebase Admin SDK initialized with default credentials")
                except Exception as e:
                    print(f"⚠️ Firebase Admin SDK not initialized: {e}")
                    print("   Set FIREBASE_CREDENTIALS_PATH or FIREBASE_SERVICE_ACCOUNT_JSON")
                    return None
    except Exception as e:
        print(f"❌ Error initializing Firebase Admin SDK: {e}")
        return None
    
    return _firebase_app


def verify_firebase_token(id_token):
    """
    Verify a Firebase ID token and return the decoded token
    
    Args:
        id_token: Firebase ID token string from the frontend
        
    Returns:
        dict: Decoded token with user info (uid, email, etc.) or None if invalid
    """
    global _last_verify_error
    try:
        _last_verify_error = None
        if auth is None:
            print("⚠️ Firebase Admin SDK not available, cannot verify token")
            _last_verify_error = 'firebase_admin not installed'
            return None

        if _firebase_app is None:
            initialize_firebase()
        
        if _firebase_app is None:
            print("⚠️ Firebase not initialized, cannot verify token")
            return None
        
        # Check if token looks like a Firebase ID token (JWT format: three parts separated by dots)
        if not id_token or len(id_token.split('.')) != 3:
            print(f"⚠️ Token doesn't look like a Firebase ID token (JWT format required)")
            return None
        
        # Verify the ID token
        decoded_token = auth.verify_id_token(id_token)
        print(f"✅ Firebase ID token verified successfully")
        return decoded_token
    except Exception as e:
        _last_verify_error = f"{type(e).__name__}: {str(e)}"
        invalid_cls = getattr(auth, 'InvalidIdTokenError', None)
        expired_cls = getattr(auth, 'ExpiredIdTokenError', None)
        if invalid_cls and isinstance(e, invalid_cls):
            print(f"❌ Invalid Firebase ID token: {str(e)}")
            return None
        if expired_cls and isinstance(e, expired_cls):
            print(f"❌ Expired Firebase ID token: {str(e)}")
            return None
        if isinstance(e, ValueError):
            print(f"⚠️ Token format error (likely not a Firebase token): {str(e)}")
            return None
        print(f"❌ Error verifying Firebase token: {type(e).__name__}: {str(e)}")
        return None


def get_user_from_token(decoded_token):
    """
    Extract user information from decoded Firebase token
    
    Args:
        decoded_token: Decoded token from verify_firebase_token
        
    Returns:
        dict: User information (uid, email, name, etc.)
    """
    if not decoded_token:
        return None
    
    return {
        'uid': decoded_token.get('uid'),
        'email': decoded_token.get('email'),
        'name': decoded_token.get('name'),
        'email_verified': decoded_token.get('email_verified', False),
        'firebase_claims': decoded_token
    }


def firebase_token_required(f):
    """
    Decorator to require Firebase authentication
    Expects Firebase ID token in Authorization header: "Bearer <token>"
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Get token from Authorization header
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return {'detail': 'Authorization header missing'}, 401
        
        try:
            # Extract token from "Bearer <token>"
            token = auth_header.split(' ')[1] if ' ' in auth_header else auth_header
        except IndexError:
            return {'detail': 'Invalid authorization header format'}, 401
        
        # Verify Firebase token
        decoded_token = verify_firebase_token(token)
        if not decoded_token:
            return {'detail': 'Invalid or expired token'}, 401
        
        # Get user info
        user_info = get_user_from_token(decoded_token)
        if not user_info:
            return {'detail': 'Could not extract user information'}, 401
        
        # Add user info to kwargs
        kwargs['firebase_user'] = user_info
        kwargs['firebase_uid'] = user_info['uid']
        kwargs['firebase_email'] = user_info['email']
        
        return f(*args, **kwargs)
    
    return decorated_function

