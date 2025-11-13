"""
Flask decorators for authentication and authorization
Supports both Firebase tokens and legacy JWT tokens
"""
import os
from functools import wraps
from flask import request
from api.utils.auth import verify_token, get_valid_tokens
from api.utils.firebase_auth import verify_firebase_token, get_user_from_token
from api.utils.database import get_db_connection


DEV_BYPASS_ENABLED = os.getenv('DEV_BYPASS_AUTH', 'false').lower() == 'true'
DEV_DEFAULT_USERNAME = os.getenv('DEV_DEFAULT_USERNAME', 'admin')


def token_required(f):
    """
    Decorator to require valid authentication token
    Supports both Firebase ID tokens and legacy JWT tokens
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header:
                try:
                    parts = auth_header.split()
                    token = parts[-1]
                    print(f"[TOKEN] Token received: {token[:20]}...{token[-10:]}")
                except (IndexError, AttributeError):
                    print(f"[ERROR] Invalid token format in header: {auth_header}")
                    return {'detail': 'Invalid token format'}, 401

        if not token:
            if DEV_BYPASS_ENABLED:
                print(
                    "[DEV] No token provided. Using development bypass for user "
                    f"'{DEV_DEFAULT_USERNAME}'. Set DEV_BYPASS_AUTH=false to disable."
                )
                return f(username=DEV_DEFAULT_USERNAME, *args, **kwargs)
            print('[ERROR] No token found in Authorization header')
            return {'detail': 'Token is missing'}, 401

        # Try Firebase token first (only if token looks like a Firebase JWT)
        # Firebase ID tokens are JWTs with 3 parts separated by dots
        token_parts = token.split('.')
        is_firebase_token_format = len(token_parts) == 3
        
        if is_firebase_token_format:
            decoded_token = verify_firebase_token(token)
            if decoded_token:
                firebase_user = get_user_from_token(decoded_token)
                if firebase_user:
                    email = firebase_user['email']
                    # Get username from database using email
                    with get_db_connection() as conn:
                        cursor = conn.cursor()
                        cursor.execute('SELECT username FROM users WHERE email = %s', (email,))
                        result = cursor.fetchone()
                        if result:
                            username = result[0]
                            print(f"[FIREBASE] Token validated for user: {username} (email: {email})")
                            # Remove any Firebase-specific kwargs to avoid passing them to functions that don't accept them
                            # Only pass username (functions can access Firebase info via database if needed)
                            clean_kwargs = {k: v for k, v in kwargs.items() if k not in ['firebase_user', 'firebase_uid']}
                            return f(username=username, *args, **clean_kwargs)
                        else:
                            print(f"[FIREBASE] Valid token but user not found in database: {email}")
                            return {'detail': 'User not found in database'}, 404
            else:
                # Firebase token verification failed, but don't log error if it's clearly not a Firebase token
                # (will fall through to legacy token validation)
                pass
        else:
            # Token doesn't look like a Firebase JWT, skip Firebase verification
            print(f"[TOKEN] Token format suggests legacy token (not Firebase JWT), skipping Firebase verification")

        # Fall back to legacy JWT token
        valid_tokens = get_valid_tokens()
        print(f"[TOKEN] Validating legacy token... (valid_tokens has {len(valid_tokens)} tokens)")
        username = verify_token(token)
        if not username:
            if DEV_BYPASS_ENABLED:
                print(
                    "[DEV] Token invalid. Using development bypass for user "
                    f"'{DEV_DEFAULT_USERNAME}'. Set DEV_BYPASS_AUTH=false to disable."
                )
                return f(username=DEV_DEFAULT_USERNAME, *args, **kwargs)
            print('[ERROR] Token validation failed - token not found or expired')
            print(f"[TOKEN] Current valid tokens: {list(valid_tokens.keys())[:3]}...")
            return {'detail': 'Invalid or expired token'}, 401

        print(f"[OK] Legacy token validated for user: {username}")
        return f(username=username, *args, **kwargs)

    return decorated


def admin_required(f):
    """Decorator to require admin role"""
    @wraps(f)
    def decorated(username=None, *args, **kwargs):
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
            result = cursor.fetchone()

        if not result or result[0] != 'admin':
            return {'detail': 'Admin access required'}, 403

        return f(username=username, *args, **kwargs)

    return decorated
