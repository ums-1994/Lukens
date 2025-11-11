"""
Flask decorators for authentication and authorization
"""
from functools import wraps
from flask import request
from api.utils.auth import verify_token, get_valid_tokens
from api.utils.database import get_db_connection

def token_required(f):
    """Decorator to require valid authentication token"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header:
                try:
                    token = auth_header.split(" ")[1]
                    print(f"[TOKEN] Token received: {token[:20]}...{token[-10:]}")
                except (IndexError, AttributeError):
                    print(f"[ERROR] Invalid token format in header: {auth_header}")
                    return {'detail': 'Invalid token format'}, 401
        
        if not token:
            print(f"[ERROR] No token found in Authorization header")
            return {'detail': 'Token is missing'}, 401
        
        valid_tokens = get_valid_tokens()
        print(f"[TOKEN] Validating token... (valid_tokens has {len(valid_tokens)} tokens)")
        username = verify_token(token)
        if not username:
            print(f"[ERROR] Token validation failed - token not found or expired")
            print(f"[TOKEN] Current valid tokens: {list(valid_tokens.keys())[:3]}...")
            return {'detail': 'Invalid or expired token'}, 401
        
        print(f"[OK] Token validated for user: {username}")
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

