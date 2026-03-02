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
import hashlib
import hmac


DEV_BYPASS_ENABLED = os.getenv('DEV_BYPASS_AUTH', 'false').lower() == 'true'
DEV_DEFAULT_USERNAME = os.getenv('DEV_DEFAULT_USERNAME', 'admin')

# Simple in-memory cache to avoid re-creating the same Firebase user
# on every request when the database has eventual-consistency issues.
# Keyed by email, value is (user_id, username).
USER_CACHE_BY_EMAIL = {}


def _session_pepper() -> bytes:
    return (
        os.getenv('SESSION_TOKEN_PEPPER')
        or os.getenv('JWT_SECRET')
        or os.getenv('SECRET_KEY')
        or 'dev-session-pepper'
    ).encode('utf-8')


def _hash_session_token(token: str) -> str:
    digest = hmac.new(_session_pepper(), token.encode('utf-8'), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode('utf-8')


def token_required(f):
    """
    Decorator to require valid authentication token
    Supports Firebase ID tokens
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

        # Backend per-device session token support (non-JWT). If the token does not
        # look like a JWT, try validating it against user_sessions.
        token_parts = token.split('.') if isinstance(token, str) else []
        is_jwt_format = len(token_parts) == 3
        if not is_jwt_format:
            try:
                token_hash = _hash_session_token(token)
                device_id = (request.headers.get('X-Device-Id') or request.headers.get('x-device-id') or '').strip()
                with get_db_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute(
                        """
                        SELECT us.user_id, us.device_id, us.expires_at, us.revoked_at, u.username, u.email
                        FROM user_sessions us
                        JOIN users u ON u.id = us.user_id
                        WHERE us.session_token_hash = %s
                        ORDER BY us.created_at DESC
                        LIMIT 1
                        """,
                        (token_hash,),
                    )
                    row = cursor.fetchone()
                    if row:
                        user_id, session_device_id, expires_at, revoked_at, username_db, email_db = row
                        if revoked_at is not None:
                            return {'detail': 'Session revoked'}, 401
                        if expires_at is not None:
                            try:
                                from datetime import datetime, timezone

                                now = datetime.now(timezone.utc)
                                if getattr(expires_at, 'tzinfo', None) is None:
                                    expires_at = expires_at.replace(tzinfo=timezone.utc)
                                if expires_at < now:
                                    return {'detail': 'Session expired'}, 401
                            except Exception:
                                pass

                        if device_id and session_device_id and device_id != session_device_id:
                            return {'detail': 'Session device mismatch'}, 401

                        # best-effort last_seen update
                        try:
                            cursor.execute(
                                "UPDATE user_sessions SET last_seen_at = NOW() WHERE session_token_hash = %s",
                                (token_hash,),
                            )
                            conn.commit()
                        except Exception:
                            try:
                                conn.rollback()
                            except Exception:
                                pass

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
                            clean_kwargs['email'] = email_db
                        return f(username=username_db, *args, **clean_kwargs)
            except Exception as sess_err:
                # Session token not valid; fall through to other auth mechanisms.
                print(f"[AUTH] Session token validation skipped/failed: {sess_err}")

        # Try Firebase token first only when it actually looks like a Firebase JWT.
        # Firebase ID tokens are JWTs with a 'kid' header.
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

                    email_key = (email or '').strip().lower()

                    # Fast path: if we've already seen this email in this worker,
                    # reuse the cached user_id/username instead of hitting the DB
                    # again or re-creating the user.
                    cached = USER_CACHE_BY_EMAIL.get(email_key)
                    if cached:
                        cached_user_id, cached_username = cached

                        with get_db_connection() as conn:
                            cursor = conn.cursor()
                            cursor.execute('SELECT id FROM users WHERE id = %s', (cached_user_id,))
                            still_exists = cursor.fetchone()
                            if not still_exists:
                                cursor.execute(
                                    'SELECT id, username FROM users WHERE lower(email) = lower(%s) ORDER BY id DESC LIMIT 1',
                                    (email,),
                                )
                                row = cursor.fetchone()
                                if row:
                                    cached_user_id = row[0]
                                    cached_username = row[1]
                                    cached = (cached_user_id, cached_username)
                                    USER_CACHE_BY_EMAIL[email_key] = cached

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

                    # Get user from database using email, or create user if not found
                    # Always use email as the primary lookup since it's unique and comes from Firebase
                    with get_db_connection() as conn:
                        # CRITICAL: Ensure autocommit is OFF before starting transaction
                        # This is essential for commits to work properly
                        original_autocommit = conn.autocommit
                        if conn.autocommit:
                            print(f"[FIREBASE] Connection was in autocommit mode, disabling for transaction control")
                            conn.autocommit = False
                        
                        # Ensure we're not in a transaction already (shouldn't be, but check)
                        try:
                            import psycopg2.extensions as ext
                            tx_status = conn.get_transaction_status()
                            if tx_status in (
                                ext.TRANSACTION_STATUS_INTRANS,
                                ext.TRANSACTION_STATUS_INERROR,
                            ):
                                print(f"[FIREBASE] WARNING: Connection in transaction, rolling back first...")
                                conn.rollback()
                        except Exception:
                            pass
                        
                        cursor = conn.cursor()

                        def _optional_exec(sql, params=(), fetch_one=False):
                            try:
                                cursor.execute('SAVEPOINT opt_q')
                            except Exception:
                                try:
                                    conn.rollback()
                                except Exception:
                                    pass
                                return None
                            try:
                                cursor.execute(sql, params)
                                row = cursor.fetchone() if fetch_one else None
                                cursor.execute('RELEASE SAVEPOINT opt_q')
                                return row
                            except Exception:
                                try:
                                    cursor.execute('ROLLBACK TO SAVEPOINT opt_q')
                                    cursor.execute('RELEASE SAVEPOINT opt_q')
                                except Exception:
                                    try:
                                        conn.rollback()
                                    except Exception:
                                        pass
                                return None

                        _optional_exec('SELECT pg_advisory_xact_lock(hashtext(%s))', (uid or email_key,))

                        result = None
                        result = _optional_exec(
                            'SELECT id, username FROM users WHERE firebase_uid = %s ORDER BY id DESC LIMIT 1',
                            (uid,),
                            fetch_one=True,
                        )

                        # Look up by email (most reliable since it's unique and comes from Firebase)
                        if not result:
                            cursor.execute(
                                'SELECT id, username FROM users WHERE lower(email) = lower(%s) ORDER BY id DESC LIMIT 1',
                                (email,),
                            )
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
                            
                            # Cache for subsequent requests in this worker
                            USER_CACHE_BY_EMAIL[email_key] = (user_id, username)

                            # Pass username, user_id, and email to functions
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
                                    
                                    try:
                                        _optional_exec(
                                            'UPDATE users SET firebase_uid = %s WHERE id = %s',
                                            (uid, user_id),
                                        )
                                    except Exception:
                                        try:
                                            conn.rollback()
                                        except Exception:
                                            pass
                                    
                                    # CRITICAL: Commit the transaction and ensure it's persisted
                                    # We already set autocommit=False at the start of the with block
                                    # Don't change it again - it's already in the correct state
                                    
                                    try:
                                        # Commit the transaction
                                        print(f"[FIREBASE] 🔄 About to commit transaction. Connection status before: {conn.status}")
                                        print(f"[FIREBASE] 🔄 Autocommit mode: {conn.autocommit}")
                                        print(f"[FIREBASE] 🔄 Transaction isolation level: {conn.isolation_level}")
                                        
                                        conn.commit()
                                        print(f"[FIREBASE] ✅ Commit executed. Connection status after: {conn.status}")
                                        
                                        # Verify the commit worked by checking if we're still in a transaction
                                        if conn.status == psycopg2.extensions.STATUS_IN_TRANSACTION:
                                            print(f"[FIREBASE] ⚠️ WARNING: Still in transaction after commit! Forcing another commit...")
                                            conn.commit()
                                            print(f"[FIREBASE] ✅ Second commit executed. Connection status: {conn.status}")
                                        
                                        # CRITICAL: Don't restore autocommit until AFTER we verify the commit worked
                                        # Keep autocommit OFF to ensure the commit persists
                                        
                                        # Close the cursor and create a fresh one after commit to ensure we see committed data
                                        cursor.close()
                                        cursor = conn.cursor()
                                        
                                        # Verify the user exists in the SAME connection after commit with fresh cursor
                                        # This confirms the commit actually worked
                                        cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
                                        verify_result = cursor.fetchone()
                                        if verify_result:
                                            print(f"[FIREBASE] ✅ Verified user exists in same connection after commit: user_id {user_id}")
                                        else:
                                            print(f"[FIREBASE] ⚠️ WARNING: User {user_id} not found in same connection after commit!")
                                            # This is a serious issue - the commit didn't work
                                            # However, the RETURNING clause guarantees the user_id is correct
                                            # So we'll trust it and continue - the user exists even if this connection can't see it
                                            print(f"[FIREBASE] ⚠️ Trusting RETURNING clause - user_id {user_id} is valid even if not visible in this connection")
                                        
                                        # Restore original autocommit setting AFTER verification
                                        if original_autocommit:
                                            conn.autocommit = True
                                        
                                    except Exception as commit_error:
                                        print(f"[FIREBASE] ERROR during commit: {commit_error}")
                                        import traceback
                                        traceback.print_exc()
                                        conn.rollback()
                                        raise
                                    
                                    print(f"[FIREBASE] Auto-created user: {username} (email: {email}, user_id: {user_id})")
                                    
                                    # CRITICAL: Ensure commit is fully persisted and flushed before continuing
                                    # Force a sync point to ensure the transaction is committed and visible
                                    try:
                                        # Execute a sync query to force the connection to sync with the database
                                        # This ensures the commit is fully processed by PostgreSQL
                                        cursor.execute('SELECT pg_backend_pid()')
                                        cursor.fetchone()
                                        print(f"[FIREBASE] Connection synced with PostgreSQL backend after commit")
                                        
                                        # CRITICAL FIX: Increased delay for Render's eventual consistency
                                        # Render Postgres can take longer to propagate commits
                                        import time
                                        time.sleep(0.3)  # Increased from 150ms to 300ms for Render
                                        print(f"[FIREBASE] Waited 300ms for commit propagation (Render eventual consistency)")
                                        
                                        # Force a flush by executing a simple query that requires database round-trip
                                        cursor.execute('SELECT 1')
                                        cursor.fetchone()
                                        
                                        # Final verification: check if user is actually in the database
                                        # Note: Even if this fails, we trust the RETURNING clause
                                        # The user_id from RETURNING is guaranteed to be correct
                                        cursor.execute('SELECT id, email FROM users WHERE id = %s', (user_id,))
                                        final_verify = cursor.fetchone()
                                        if final_verify:
                                            print(f"[FIREBASE] ✅ Final verification: User {user_id} exists in database")
                                        else:
                                            print(f"[FIREBASE] ⚠️ WARNING: User {user_id} not visible in database after commit and sync")
                                            print(f"[FIREBASE] ⚠️ However, RETURNING clause guarantees user_id {user_id} is valid")
                                            print(f"[FIREBASE] ⚠️ This may be a transaction visibility issue - user exists but not visible yet")
                                            # Don't raise an error - trust the RETURNING clause
                                            # The user exists, even if this connection can't see it
                                    except Exception as sync_error:
                                        if "was not persisted" in str(sync_error):
                                            raise  # Re-raise the persistence error
                                        print(f"[FIREBASE] Warning: Could not sync/verify connection: {sync_error}")
                                    
                                    # Verify connection is not in a transaction before exiting context manager
                                    if conn.status == psycopg2.extensions.STATUS_IN_TRANSACTION:
                                        print(f"[FIREBASE] WARNING: Connection still in transaction before returning to pool, rolling back...")
                                        conn.rollback()
                                    
                                    print(f"[FIREBASE] Transaction committed successfully. User should be visible in new connections.")
                                except psycopg2.IntegrityError as e:
                                    # Race condition: another request created the user between our check and insert
                                    # This happens when multiple requests come in simultaneously
                                    # Rollback and look up the existing user
                                    conn.rollback()
                                    print(f"[FIREBASE] User was created by another request (race condition), looking up existing user...")
                                    
                                    # Retry lookup with small delay to ensure transaction is visible
                                    import time
                                    for retry_attempt in range(3):
                                        existing_user = _optional_exec(
                                            'SELECT id, username FROM users WHERE firebase_uid = %s ORDER BY id DESC LIMIT 1',
                                            (uid,),
                                            fetch_one=True,
                                        )

                                        if not existing_user:
                                            cursor.execute(
                                                'SELECT id, username FROM users WHERE lower(email) = lower(%s) ORDER BY id DESC LIMIT 1',
                                                (email,),
                                            )
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
                            # IMPORTANT: Add a delay to ensure transaction is visible to other connections
                            # Increased delay for Render's eventual consistency
                            import time
                            time.sleep(0.25)  # Increased from 100ms to 250ms for Render

                            # Cache for subsequent requests in this worker
                            USER_CACHE_BY_EMAIL[email_key] = (user_id, username)

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
                # Firebase token verification failed
                if DEV_BYPASS_ENABLED:
                    print(
                        "[DEV] Firebase token invalid. Using development bypass for user "
                        f"'{DEV_DEFAULT_USERNAME}'. Set DEV_BYPASS_AUTH=false to disable."
                    )
                    return f(username=DEV_DEFAULT_USERNAME, *args, **kwargs)
                # If Firebase verification fails, fall back to legacy/local DB validation
                username = verify_token(token)
                if username:
                    print(f"[TOKEN] Legacy token validated for user: {username}")

                    import inspect
                    sig = inspect.signature(f)
                    clean_kwargs = {
                        k: v
                        for k, v in kwargs.items()
                        if k not in ['firebase_user', 'firebase_uid', 'user_id', 'email']
                    }

                    resolved_user_id = None
                    resolved_email = None
                    resolved_username = username
                    try:
                        with get_db_connection() as conn:
                            cursor = conn.cursor()
                            cursor.execute(
                                """
                                SELECT id, username, email
                                FROM users
                                WHERE username = %s OR lower(email) = lower(%s)
                                ORDER BY id DESC
                                LIMIT 1
                                """,
                                (username, username),
                            )
                            row = cursor.fetchone()
                            if row:
                                resolved_user_id = row[0]
                                resolved_username = row[1] or resolved_username
                                resolved_email = row[2]
                    except Exception:
                        resolved_user_id = None
                        resolved_email = None

                    if 'user_id' in sig.parameters:
                        clean_kwargs['user_id'] = resolved_user_id
                    if 'email' in sig.parameters:
                        clean_kwargs['email'] = resolved_email
                    return f(username=resolved_username, *args, **clean_kwargs)
                print('[ERROR] Firebase token validation failed and legacy validation failed')
                return {'detail': 'Invalid or expired token'}, 401
        else:
            # Token doesn't look like a Firebase JWT.
# Fall back to legacy/local DB token validation.
            username = verify_token(token)
            if username:
                print(f"[TOKEN] Legacy token validated for user: {username}")

                import inspect
                sig = inspect.signature(f)
                clean_kwargs = {
                    k: v
                    for k, v in kwargs.items()
                    if k not in ['firebase_user', 'firebase_uid', 'user_id', 'email']
                }

                resolved_user_id = None
                resolved_email = None
                resolved_username = username
                try:
                    with get_db_connection() as conn:
                        cursor = conn.cursor()
                        cursor.execute(
                            """
                            SELECT id, username, email
                            FROM users
                            WHERE username = %s OR lower(email) = lower(%s)
                            ORDER BY id DESC
                            LIMIT 1
                            """,
                            (username, username),
                        )
                        row = cursor.fetchone()
                        if row:
                            resolved_user_id = row[0]
                            resolved_username = row[1] or resolved_username
                            resolved_email = row[2]
                except Exception:
                    resolved_user_id = None
                    resolved_email = None

                if 'user_id' in sig.parameters:
                    clean_kwargs['user_id'] = resolved_user_id
                if 'email' in sig.parameters:
                    clean_kwargs['email'] = resolved_email
                return f(username=resolved_username, *args, **clean_kwargs)

            if DEV_BYPASS_ENABLED:
                print(
                    "[DEV] Non-Firebase token provided. Using development bypass for user "
                    f"'{DEV_DEFAULT_USERNAME}'. Set DEV_BYPASS_AUTH=false to disable."
                )
                return f(username=DEV_DEFAULT_USERNAME, *args, **kwargs)

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
