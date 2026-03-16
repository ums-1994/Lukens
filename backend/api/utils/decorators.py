"""
Flask decorators for authentication and authorization
Supports Firebase tokens
"""
import os
import psycopg2
import psycopg2.extensions
import base64
import json
from functools import wraps
from flask import request
from api.utils.firebase_auth import verify_firebase_token, get_user_from_token
from api.utils.database import get_db_connection
from api.utils.auth import verify_token


# Simple in-memory cache to avoid re-querying the DB for the same Firebase user
# on every request. Keyed by email → (user_id, username).
USER_CACHE_BY_EMAIL = {}


def _verify_user_readable(conn, user_id, max_retries=10):
    """
    Verify that a user can be read from the database with retries.
    Handles eventual consistency in distributed databases.
    Returns True if user is readable, False otherwise.
    """
    import time
    for attempt in range(max_retries):
        try:
            cursor = conn.cursor()
            cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
            if cursor.fetchone():
                if attempt > 0:
                    print(f"[FIREBASE] ✅ User {user_id} became readable on attempt {attempt + 1}")
                return True
            cursor.close()
        except Exception:
            pass
        
        if attempt < max_retries - 1:
            wait_time = min(0.5 + (attempt * 0.1), 2.0)
            print(f"[FIREBASE] ⚠️ User {user_id} not readable (attempt {attempt + 1}/{max_retries}), waiting {wait_time:.1f}s...")
            time.sleep(wait_time)
    
    return False


def token_required(f):
    """
    Decorator to require valid authentication token.
    Accepts Firebase ID tokens (preferred) or legacy DB tokens.
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
            print('[ERROR] No token found in Authorization header')
            return {'detail': 'Token is missing'}, 401

        # Firebase ID tokens are JWTs with a 'kid' header — detect that first.
        token_parts = token.split('.')
        is_jwt_format = len(token_parts) == 3
        has_kid_header = False

        if is_jwt_format:
            try:
                header_b64 = token_parts[0]
                padding = '=' * (-len(header_b64) % 4)
                header_bytes = base64.urlsafe_b64decode(header_b64 + padding)
                header = json.loads(header_bytes.decode('utf-8'))
                has_kid_header = isinstance(header, dict) and bool(header.get('kid'))
            except Exception:
                has_kid_header = False

        if is_jwt_format and has_kid_header:
            decoded_token = verify_firebase_token(token)
            if decoded_token:
                firebase_user = get_user_from_token(decoded_token)
                if firebase_user:
                    email = firebase_user['email']
                    uid = firebase_user['uid']
                    name = firebase_user.get('name') or email.split('@')[0]

                    # Fast path: reuse cached user to avoid a DB round-trip,
                    # but verify it actually exists in the DB with retries.
                    cached = USER_CACHE_BY_EMAIL.get(email)
                    if cached:
                        cached_user_id, cached_username = cached
                        with get_db_connection() as verify_conn:
                            if _verify_user_readable(verify_conn, cached_user_id, max_retries=5):
                                print(f"[FIREBASE] Using cached user_id {cached_user_id} for {email}")
                                import inspect
                                sig = inspect.signature(f)
                                clean_kwargs = {
                                    k: v
                                    for k, v in kwargs.items()
                                    if k not in ['firebase_user', 'firebase_uid', 'user_id', 'email']
                                }
                                if 'user_id' in sig.parameters:
                                    clean_kwargs['user_id'] = cached_user_id
                                if 'email' in sig.parameters:
                                    clean_kwargs['email'] = email
                                return f(username=cached_username, *args, **clean_kwargs)
                            else:
                                print(f"[FIREBASE] ⚠️ Cached user_id {cached_user_id} for {email} not found in DB; invalidating cache")
                                del USER_CACHE_BY_EMAIL[email]

                    with get_db_connection() as conn:
                        original_autocommit = conn.autocommit
                        if conn.autocommit:
                            conn.autocommit = False

                        if conn.status == psycopg2.extensions.STATUS_IN_TRANSACTION:
                            conn.commit()

                        cursor = conn.cursor()
                        cursor.execute('SELECT id, username FROM users WHERE email = %s', (email,))
                        result = cursor.fetchone()

                        if result:
                            user_id = result[0]
                            username = result[1]

                            cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
                            verify = cursor.fetchone()
                            if not verify:
                                print(f"[FIREBASE] WARNING: user_id {user_id} not found on verification!")

                            USER_CACHE_BY_EMAIL[email] = (user_id, username)

                            import inspect
                            sig = inspect.signature(f)
                            clean_kwargs = {
                                k: v
                                for k, v in kwargs.items()
                                if k not in ['firebase_user', 'firebase_uid', 'user_id', 'email']
                            }
                            if 'user_id' in sig.parameters:
                                clean_kwargs['user_id'] = user_id
                            if 'email' in sig.parameters:
                                clean_kwargs['email'] = email
                            return f(username=username, *args, **clean_kwargs)
                        else:
                            # Auto-create user for a valid Firebase token not yet in DB
                            print(f"[FIREBASE] Valid token but user not found in database: {email}. Auto-creating user...")

                            try:
                                username = email.split('@')[0]
                                base_username = username
                                counter = 1
                                while True:
                                    cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                                    if cursor.fetchone() is None:
                                        break
                                    username = f"{base_username}{counter}"
                                    counter += 1

                                role = 'manager'
                                dummy_password_hash = f"firebase:{uid}:{email}"

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

                                    try:
                                        cursor.execute(
                                            '''UPDATE users SET firebase_uid = %s WHERE email = %s''',
                                            (uid, email)
                                        )
                                    except Exception:
                                        pass

                                    try:
                                        conn.commit()
                                        print(f"[FIREBASE] ✅ Auto-created user committed: {username} (id: {user_id})")
                                    except Exception as commit_error:
                                        print(f"[FIREBASE] ERROR during commit: {commit_error}")
                                        try:
                                            conn.rollback()
                                        except:
                                            pass
                                        raise

                                    # Verify user is readable with retries
                                    import time
                                    if _verify_user_readable(conn, user_id, max_retries=10):
                                        print(f"[FIREBASE] ✅ User {user_id} verified readable after creation")
                                    else:
                                        print(f"[FIREBASE] ⚠️ WARNING: User {user_id} not readable after verification attempts, but proceeding with caution")
                                    
                                    # Close old cursor and create fresh one from the committed state
                                    try:
                                        cursor.close()
                                    except:
                                        pass
                                    cursor = conn.cursor()
                                except psycopg2.IntegrityError:
                                    conn.rollback()
                                    import time
                                    for retry_attempt in range(3):
                                        cursor.execute('SELECT id, username FROM users WHERE email = %s', (email,))
                                        existing_user = cursor.fetchone()
                                        if existing_user:
                                            user_id = existing_user[0]
                                            username = existing_user[1]
                                            break
                                        if retry_attempt < 2:
                                            time.sleep(0.1)

                                    if not existing_user:
                                        print(f"[FIREBASE] ERROR: IntegrityError but user still not found after retries!")
                                        raise
                            except Exception as e:
                                conn.rollback()
                                print(f"[FIREBASE] Error creating user: {e}")
                                raise

                            import time
                            time.sleep(0.1)

                            # Cache the verified user
                            USER_CACHE_BY_EMAIL[email] = (user_id, username)
                            print(f"[FIREBASE] ✅ User cached for {email}: {username} (id: {user_id})")

                            import inspect
                            sig = inspect.signature(f)
                            clean_kwargs = {
                                k: v
                                for k, v in kwargs.items()
                                if k not in ['firebase_user', 'firebase_uid', 'user_id', 'email']
                            }
                            if 'user_id' in sig.parameters:
                                clean_kwargs['user_id'] = user_id
                            if 'email' in sig.parameters:
                                clean_kwargs['email'] = email
                            return f(username=username, *args, **clean_kwargs)
            else:
                # Firebase verification failed — fall back to legacy DB token
                username = verify_token(token)
                if username:
                    return f(username=username, *args, **kwargs)
                print('[ERROR] Firebase token validation failed and legacy validation failed')
                return {'detail': 'Invalid or expired token'}, 401
        else:
            username = verify_token(token)
            if username:
                return f(username=username, *args, **kwargs)

            print('[ERROR] Token is not a valid Firebase ID token and legacy validation failed')
            return {'detail': 'Invalid or unsupported token type'}, 401

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


def finance_audit_required(f):
    """Decorator to require finance_manager role or admin/ceo for audit/compliance access."""
    @wraps(f)
    def decorated(username=None, *args, **kwargs):
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
            result = cursor.fetchone()

        if not result:
            return {'detail': 'User not found'}, 403

        role = (result[0] or '').strip().lower()
        if role not in ['finance_manager', 'admin', 'ceo']:
            return {'detail': 'Finance manager access required'}, 403

        return f(username=username, *args, **kwargs)

    return decorated


def finance_required(f):
    """Decorator to require finance role or admin"""
    @wraps(f)
    def decorated(username=None, *args, **kwargs):
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
            result = cursor.fetchone()

        if not result:
            return {'detail': 'User not found'}, 403

        role = result[0].lower()
        if role not in ['finance', 'admin', 'ceo']:
            return {'detail': 'Finance access required'}, 403

        return f(username=username, *args, **kwargs)

    return decorated
