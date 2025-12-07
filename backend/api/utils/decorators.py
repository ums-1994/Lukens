"""
Flask decorators for authentication and authorization
Supports both Firebase tokens and legacy JWT tokens
"""
import os
import psycopg2
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
        # Allow OPTIONS requests for CORS preflight
        if request.method == 'OPTIONS':
            return {}, 200
        
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
                    uid = firebase_user['uid']
                    name = firebase_user.get('name') or email.split('@')[0]
                    
                    # Get user from database using email, or create user if not found
                    # Always use email as the primary lookup since it's unique and comes from Firebase
                    with get_db_connection() as conn:
                        cursor = conn.cursor()
                        # Look up by email (most reliable since it's unique and comes from Firebase)
                        cursor.execute('SELECT id, username FROM users WHERE email = %s', (email,))
                        result = cursor.fetchone()
                        
                        if result:
                            user_id = result[0]
                            username = result[1]
                            print(f"[FIREBASE] Token validated for existing user: {username} (email: {email}, user_id: {user_id})")
                            
                            # Verify user_id is actually valid (double-check)
                            cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
                            verify = cursor.fetchone()
                            if not verify:
                                print(f"[FIREBASE] WARNING: user_id {user_id} not found on verification, this shouldn't happen!")
                                # This is a serious error, but continue anyway
                            
                            # Pass username, user_id, and email to functions
                            import inspect
                            sig = inspect.signature(f)
                            clean_kwargs = {k: v for k, v in kwargs.items() if k not in ['firebase_user', 'firebase_uid', 'user_id', 'email']}
                            if 'user_id' in sig.parameters:
                                clean_kwargs['user_id'] = user_id
                            if 'email' in sig.parameters:
                                clean_kwargs['email'] = email
                            return f(username=username, *args, **clean_kwargs)
                        else:
                            # Auto-create user if they have a valid Firebase token but don't exist in database
                            # Use a transaction with proper error handling to avoid race conditions
                            print(f"[FIREBASE] Valid token but user not found in database: {email}. Auto-creating user...")
                            
                            try:
                                # Generate unique username from email
                                username = email.split('@')[0]
                                base_username = username
                                counter = 1
                                while True:
                                    cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                                    if cursor.fetchone() is None:
                                        break
                                    username = f"{base_username}{counter}"
                                    counter += 1
                                
                                # Default role for auto-created users
                                role = 'manager'
                                
                                # Create dummy password hash for Firebase-only accounts
                                dummy_password_hash = f"firebase:{uid}:{email}"
                                
                                # Insert new user (with error handling for race conditions)
                                try:
                                    cursor.execute(
                                        '''INSERT INTO users (username, email, password_hash, full_name, role, is_active, is_email_verified)
                                           VALUES (%s, %s, %s, %s, %s, %s, %s)
                                           RETURNING id, username''',
                                        (username, email, dummy_password_hash, name, role, True, firebase_user.get('email_verified', False))
                                    )
                                    new_user = cursor.fetchone()
                                    user_id = new_user[0]
                                    username = new_user[1]
                                    
                                    # Try to add firebase_uid if column exists (before committing)
                                    try:
                                        cursor.execute(
                                            '''UPDATE users SET firebase_uid = %s WHERE email = %s''',
                                            (uid, email)
                                        )
                                    except Exception:
                                        # Column doesn't exist or update failed, that's okay - continue without it
                                        pass
                                    
                                    # Commit both INSERT and UPDATE (if UPDATE succeeded)
                                    conn.commit()
                                    
                                    # Verify the user is visible immediately after commit
                                    # This ensures the transaction is fully committed and visible to other connections
                                    cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
                                    verify_user = cursor.fetchone()
                                    if not verify_user:
                                        print(f"[FIREBASE] WARNING: User {user_id} not visible immediately after commit!")
                                        # Small delay to allow transaction to propagate
                                        import time
                                        time.sleep(0.05)
                                        # Try one more time
                                        cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
                                        verify_user = cursor.fetchone()
                                        if not verify_user:
                                            print(f"[FIREBASE] ERROR: User {user_id} still not visible after delay!")
                                    
                                    print(f"[FIREBASE] Auto-created user: {username} (email: {email}, user_id: {user_id})")
                                except psycopg2.IntegrityError as e:
                                    # Race condition: another request created the user between our check and insert
                                    # This happens when multiple requests come in simultaneously
                                    # Rollback and look up the existing user
                                    conn.rollback()
                                    print(f"[FIREBASE] User was created by another request (race condition), looking up existing user...")
                                    
                                    # Retry lookup with small delay to ensure transaction is visible
                                    import time
                                    for retry_attempt in range(3):
                                        cursor.execute('SELECT id, username FROM users WHERE email = %s', (email,))
                                        existing_user = cursor.fetchone()
                                        if existing_user:
                                            user_id = existing_user[0]
                                            username = existing_user[1]
                                            print(f"[FIREBASE] Found existing user: {username} (email: {email}, user_id: {user_id})")
                                            break
                                        if retry_attempt < 2:
                                            time.sleep(0.1)  # Small delay before retry
                                    
                                    if not existing_user:
                                        # This shouldn't happen, but handle it gracefully
                                        print(f"[FIREBASE] ERROR: IntegrityError but user still not found after rollback and retries!")
                                        raise
                            except Exception as e:
                                # If anything else goes wrong, rollback and re-raise
                                conn.rollback()
                                print(f"[FIREBASE] Error creating user: {e}")
                                raise
                            
                            # Store user_id in kwargs so functions can use it without looking it up again
                            # Always pass email as well since it's unique and reliable for fallback lookups
                            import inspect
                            sig = inspect.signature(f)
                            clean_kwargs = {k: v for k, v in kwargs.items() if k not in ['firebase_user', 'firebase_uid', 'user_id', 'email']}
                            if 'user_id' in sig.parameters:
                                clean_kwargs['user_id'] = user_id
                            if 'email' in sig.parameters:
                                clean_kwargs['email'] = email
                            return f(username=username, *args, **clean_kwargs)
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
