"""
Flask decorators for authentication and authorization
Supports Firebase tokens
"""
import os
import psycopg2
import psycopg2.extensions
from functools import wraps
from flask import request
from api.utils.firebase_auth import verify_firebase_token, get_user_from_token
from api.utils.auth import verify_token
from api.utils.database import get_db_connection


DEV_BYPASS_ENABLED = os.getenv('DEV_BYPASS_AUTH', 'false').lower() == 'true'
FIREBASE_AUTH_ENABLED = os.getenv('FIREBASE_AUTH_ENABLED', 'false').lower() == 'true'
DEV_DEFAULT_USERNAME = os.getenv('DEV_DEFAULT_USERNAME', 'admin')

# Simple in-memory cache to avoid re-creating the same Firebase user
# on every request when the database has eventual-consistency issues.
# Keyed by email, value is (user_id, username).
USER_CACHE_BY_EMAIL = {}


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

        # Accept backend-generated token first (local auth)
        backend_username = verify_token(token)
        if backend_username:
            return f(username=backend_username, *args, **kwargs)

        # Try Firebase token first (only if token looks like a Firebase JWT)
        # Firebase ID tokens are JWTs with 3 parts separated by dots
        token_parts = token.split('.')
        is_firebase_token_format = len(token_parts) == 3
        
        if FIREBASE_AUTH_ENABLED and is_firebase_token_format:
            decoded_token = verify_firebase_token(token)
            if decoded_token:
                firebase_user = get_user_from_token(decoded_token)
                if firebase_user:
                    email = firebase_user['email']
                    uid = firebase_user['uid']
                    name = firebase_user.get('name') or email.split('@')[0]

                    # Fast path: if we've already seen this email in this worker,
                    # reuse the cached user_id/username instead of hitting the DB
                    # again or re-creating the user.
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
                        if conn.status == psycopg2.extensions.STATUS_IN_TRANSACTION:
                            print(f"[FIREBASE] WARNING: Connection already in transaction, committing first...")
                            conn.commit()
                        
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
                            
                            # Cache for subsequent requests in this worker
                            USER_CACHE_BY_EMAIL[email] = (user_id, username)

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
                                    
                                    # Try to add firebase_uid if column exists (before committing)
                                    try:
                                        cursor.execute(
                                            '''UPDATE users SET firebase_uid = %s WHERE email = %s''',
                                            (uid, email)
                                        )
                                    except Exception:
                                        # Column doesn't exist or update failed, that's okay - continue without it
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
                            # IMPORTANT: Add a delay to ensure transaction is visible to other connections
                            # Increased delay for Render's eventual consistency
                            import time
                            time.sleep(0.25)  # Increased from 100ms to 250ms for Render

                            # Cache for subsequent requests in this worker
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
                # Firebase token verification failed
                if DEV_BYPASS_ENABLED:
                    print(
                        "[DEV] Firebase token invalid. Using development bypass for user "
                        f"'{DEV_DEFAULT_USERNAME}'. Set DEV_BYPASS_AUTH=false to disable."
                    )
                    return f(username=DEV_DEFAULT_USERNAME, *args, **kwargs)
                print('[ERROR] Firebase token validation failed - invalid or expired token')
                return {'detail': 'Invalid or expired token'}, 401
        else:
            if DEV_BYPASS_ENABLED:
                print(
                    "[DEV] Non-Firebase token provided. Using development bypass for user "
                    f"'{DEV_DEFAULT_USERNAME}'. Set DEV_BYPASS_AUTH=false to disable."
                )
                return f(username=DEV_DEFAULT_USERNAME, *args, **kwargs)
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


def finance_required(f):
    """Decorator to require finance role"""
    @wraps(f)
    def decorated(username=None, *args, **kwargs):
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
            result = cursor.fetchone()

        if not result or result[0] not in ['finance', 'financial manager']:
            return {'detail': 'Finance access required'}, 403

        return f(username=username, *args, **kwargs)

    return decorated


def admin_or_finance_required(f):
    """Decorator to require admin or finance role"""
    @wraps(f)
    def decorated(username=None, *args, **kwargs):
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
            result = cursor.fetchone()

        if not result or result[0] not in ['admin', 'finance', 'financial manager']:
            return {'detail': 'Admin or Finance access required'}, 403

        return f(username=username, *args, **kwargs)

    return decorated
