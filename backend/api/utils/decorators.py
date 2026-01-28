"""
Flask decorators for authentication and authorization
Supports Firebase tokens + legacy tokens issued by /login
"""
import os
import psycopg2
import psycopg2.extensions
from functools import wraps
from flask import request

from api.utils.firebase_auth import verify_firebase_token, get_user_from_token
from api.utils.database import get_db_connection
from api.utils.auth import verify_token  # ✅ legacy token validation (tokens from /login)

DEV_BYPASS_ENABLED = os.getenv('DEV_BYPASS_AUTH', 'false').lower() == 'true'
DEV_DEFAULT_USERNAME = os.getenv('DEV_DEFAULT_USERNAME', 'admin')

# Simple in-memory cache to avoid re-creating the same Firebase user
# on every request when the database has eventual-consistency issues.
# Keyed by email, value is (user_id, username).
USER_CACHE_BY_EMAIL = {}


def token_required(f):
    """
    Decorator to require valid authentication token.
    Supports:
      - Firebase ID tokens (JWTs: 3 parts separated by dots)
      - Legacy opaque tokens issued by /login (validated via verify_token)
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

        # ---- 1) Firebase token path (JWT format: x.y.z) ----
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

                    cached = USER_CACHE_BY_EMAIL.get(email)
                    if cached:
                        cached_user_id, cached_username = cached
                        print(
                            f"[FIREBASE] Using cached user: {cached_username} "
                            f"(email: {email}, user_id: {cached_user_id})"
                        )
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
                            print("[FIREBASE] Connection was in autocommit mode, disabling for transaction control")
                            conn.autocommit = False

                        if conn.status == psycopg2.extensions.STATUS_IN_TRANSACTION:
                            print("[FIREBASE] WARNING: Connection already in transaction, committing first...")
                            conn.commit()

                        cursor = conn.cursor()
                        cursor.execute('SELECT id, username FROM users WHERE email = %s', (email,))
                        result = cursor.fetchone()

                        if result:
                            user_id = result[0]
                            username = result[1]
                            print(f"[FIREBASE] Token validated for existing user: {username} (email: {email}, user_id: {user_id})")

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

                        # Auto-create user if they have a valid Firebase token but don't exist in DB
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
                                cursor.execute('''UPDATE users SET firebase_uid = %s WHERE email = %s''', (uid, email))
                            except Exception:
                                pass

                            conn.commit()

                            if original_autocommit:
                                conn.autocommit = True

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

                        except Exception as e:
                            conn.rollback()
                            print(f"[FIREBASE] Error creating user: {e}")
                            raise

            # Firebase token format but failed verification
            if DEV_BYPASS_ENABLED:
                print(
                    "[DEV] Firebase token invalid. Using development bypass for user "
                    f"'{DEV_DEFAULT_USERNAME}'. Set DEV_BYPASS_AUTH=false to disable."
                )
                return f(username=DEV_DEFAULT_USERNAME, *args, **kwargs)

            print('[ERROR] Firebase token validation failed - invalid or expired token')
            return {'detail': 'Invalid or expired token'}, 401

        # ---- 2) Legacy token fallback (opaque tokens from /login) ----
        legacy_username = verify_token(token)
        if legacy_username:
            return f(username=legacy_username, *args, **kwargs)

        if DEV_BYPASS_ENABLED:
            print(
                "[DEV] Non-Firebase token provided. Using development bypass for user "
                f"'{DEV_DEFAULT_USERNAME}'. Set DEV_BYPASS_AUTH=false to disable."
            )
            return f(username=DEV_DEFAULT_USERNAME, *args, **kwargs)

        print('[ERROR] Token is neither a valid Firebase ID token nor a valid legacy token')
        return {'detail': 'Invalid or expired token'}, 401

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
