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

                    # Fast path: reuse cached user only if they still exist in DB
                    cached = USER_CACHE_BY_EMAIL.get(email)
                    if cached:
                        cached_user_id, cached_username = cached
                        # Safety: cache can become stale (e.g., switching DATABASE_URL / fresh DB).
                        # If the cached id no longer exists in the current DB, invalidate and fall through.
                        try:
                            with get_db_connection() as cache_conn:
                                cache_cursor = cache_conn.cursor()
                                cache_cursor.execute(
                                    'SELECT id FROM users WHERE id = %s AND email = %s',
                                    (cached_user_id, email),
                                )
                                if cache_cursor.fetchone() is None:
                                    print(
                                        f"[FIREBASE] ⚠️ Cached user_id {cached_user_id} for {email} not found in DB; invalidating cache"
                                    )
                                    USER_CACHE_BY_EMAIL.pop(email, None)
                                    cached = None
                        except Exception as cache_verify_err:
                            print(f"[FIREBASE] ⚠️ Error verifying cached user: {cache_verify_err}; invalidating cache")
                            USER_CACHE_BY_EMAIL.pop(email, None)
                            cached = None

                    if cached:
                        cached_user_id, cached_username = cached
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

                                        if conn.status == psycopg2.extensions.STATUS_IN_TRANSACTION:
                                            conn.commit()

                                        cursor.close()
                                        cursor = conn.cursor()

                                        if original_autocommit:
                                            conn.autocommit = True

                                    except Exception as commit_error:
                                        print(f"[FIREBASE] ERROR during commit: {commit_error}")
                                        conn.rollback()
                                        raise

                                    print(f"[FIREBASE] Auto-created user: {username} (email: {email}, user_id: {user_id})")

                                    try:
                                        import time
                                        # Verify user is readable (read-after-write verification)
                                        # This prevents the user being invisible to subsequent connections
                                        for verify_attempt in range(5):
                                            cursor.execute('SELECT id, email FROM users WHERE id = %s', (user_id,))
                                            verified = cursor.fetchone()
                                            if verified:
                                                print(f"[FIREBASE] ✅ User {user_id} verified readable after commit (attempt {verify_attempt + 1})")
                                                break
                                            if verify_attempt < 4:
                                                print(f"[FIREBASE] ⚠️ User {user_id} not readable yet, waiting... (attempt {verify_attempt + 1}/5)")
                                                time.sleep(0.1)
                                        
                                        if not verified:
                                            print(f"[FIREBASE] ⚠️ WARNING: User {user_id} not readable after 5 verification attempts, but proceeding")
                                    except Exception as verify_error:
                                        print(f"[FIREBASE] ⚠️ Error verifying user readability: {verify_error}, but proceeding")
                                    
                                    # NOTE: Do NOT rollback here. User has already been committed successfully.
                                    # If connection status shows as in-transaction, it's psycopg2 state tracking, not
                                    # an active transaction. Rollback here would undo the user creation, causing FK errors
                                    # when proposals try to reference the user. This was the root cause of "Key (owner_id)=()
                                    # is not present in table 'users'" errors.
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
                            # Longer delay for Render's read replica replication lag
                            time.sleep(2.0)

                            # Store auto-created user info in Flask g object for this request
                            # This avoids DB lookup race conditions since g persists for the request
                            try:
                                from flask import g
                                g._auto_created_user = {
                                    'user_id': user_id,
                                    'username': username,
                                    'email': email
                                }
                                print(f"[FIREBASE] Stored auto-created user {user_id} in request context")
                            except Exception as e:
                                print(f"[FIREBASE] Warning: Could not store in g object: {e}")

                            # Also cache by user_id for immediate lookup
                            USER_CACHE_BY_EMAIL[email] = (user_id, username)

                            import inspect
                            sig = inspect.signature(f)
                            clean_kwargs = {
                                k: v
                                for k, v in kwargs.items()
                                if k not in ['firebase_user', 'firebase_uid', 'user_id', 'email', 'auto_created']
                            }
                            if 'user_id' in sig.parameters:
                                clean_kwargs['user_id'] = user_id
                            if 'email' in sig.parameters:
                                clean_kwargs['email'] = email
                            # Pass flag to indicate user was just auto-created (avoids DB lookup race condition)
                            clean_kwargs['auto_created'] = True
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
