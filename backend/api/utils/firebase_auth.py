"""
Firebase Authentication utilities
Verifies Firebase ID tokens from the frontend
"""
import os
import firebase_admin
from firebase_admin import credentials, auth
from functools import wraps
from flask import request, jsonify

# Initialize Firebase Admin SDK
_firebase_app = None

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    global _firebase_app
    
    if _firebase_app is not None:
        return _firebase_app
    
    try:
        # Try to get credentials from environment variable (service account JSON)
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        
        # If not set, try default location in backend directory
        if not cred_path:
            # Get the backend directory (api/utils/firebase_auth.py -> backend/)
            current_file = os.path.abspath(__file__)  # Full path to firebase_auth.py
            backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(current_file)))  # Go up 3 levels
            default_path = os.path.join(backend_dir, 'firebase-service-account.json')
            
            print(f"[FIREBASE] Looking for credentials at: {default_path}")
            print(f"[FIREBASE] File exists: {os.path.exists(default_path)}")
            
            if os.path.exists(default_path):
                cred_path = default_path
                print(f"[FIREBASE] Using default Firebase credentials: {default_path}")
        
        if cred_path and os.path.exists(cred_path):
            print(f"[FIREBASE] Loading credentials from: {cred_path}")
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            print(f"[OK] [FIREBASE] Firebase Admin SDK initialized from: {cred_path}")
        else:
            # Try to use default credentials (for Google Cloud environments)
            # Or use service account JSON from environment variable
            service_account_json = os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON')
            if service_account_json:
                import json
                cred_info = json.loads(service_account_json)
                cred = credentials.Certificate(cred_info)
                _firebase_app = firebase_admin.initialize_app(cred)
                print("[FIREBASE] [OK] Firebase Admin SDK initialized from environment variable")
            else:
                # Try default credentials (for local development with gcloud auth)
                try:
                    _firebase_app = firebase_admin.initialize_app()
                    print("[FIREBASE] [OK] Firebase Admin SDK initialized with default credentials")
                except Exception as e:
                    print(f"[FIREBASE] [ERROR] WARNING: Firebase Admin SDK not initialized: {e}")
                    print("[FIREBASE]    Set FIREBASE_CREDENTIALS_PATH or FIREBASE_SERVICE_ACCOUNT_JSON")
                    return None
    except Exception as e:
        import traceback
        print(f"[FIREBASE] [ERROR] Error initializing Firebase Admin SDK: {e}")
        print(f"[FIREBASE] Stack trace: {traceback.format_exc()}")
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
    try:
        if _firebase_app is None:
            initialize_firebase()
        
        if _firebase_app is None:
            print("[FIREBASE] WARNING: Firebase not initialized, cannot verify token")
            return None
        
        # Check if token looks like a Firebase ID token (JWT format: three parts separated by dots)
        if not id_token or len(id_token.split('.')) != 3:
            print(f"[FIREBASE] WARNING: Token doesn't look like a Firebase ID token (JWT format required)")
            return None
        
        # Verify the ID token
        decoded_token = auth.verify_id_token(id_token)
        print(f"✅ Firebase ID token verified successfully")
        return decoded_token
    except auth.InvalidIdTokenError as e:
        print(f"[FIREBASE] ERROR: Invalid Firebase ID token: {str(e)}")
        return None
    except auth.ExpiredIdTokenError as e:
        print(f"[FIREBASE] ERROR: Expired Firebase ID token: {str(e)}")
        return None
    except ValueError as e:
        # Token format errors
        print(f"[FIREBASE] WARNING: Token format error (likely not a Firebase token): {str(e)}")
        return None
    except Exception as e:
        print(f"[FIREBASE] ERROR: Error verifying Firebase token: {type(e).__name__}: {str(e)}")
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

