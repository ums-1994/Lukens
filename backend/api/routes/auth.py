"""
Authentication routes - Registration, login, password reset, user profile
Supports both Firebase authentication and legacy JWT tokens
"""
from flask import Blueprint, request, jsonify
import os
import json
import traceback
from datetime import datetime, timedelta, timezone
import psycopg2
import psycopg2.extras

from api.utils.database import get_db_connection, _pg_conn, release_pg_conn
from api.utils.decorators import token_required
from api.utils.auth import verify_token, get_valid_tokens, generate_token, hash_password, verify_password, save_tokens
from api.utils.firebase_auth import verify_firebase_token, get_user_from_token, firebase_token_required, initialize_firebase
from api.utils.email import send_email, send_verification_email
from api.utils.jwt_validator import JWTValidationError, validate_jwt_token, extract_user_info
from werkzeug.security import check_password_hash

bp = Blueprint('auth', __name__)

# Initialize Firebase on module load (with error handling to prevent import failures)
try:
    print("[AUTH] Initializing Firebase Admin SDK...")
    result = initialize_firebase()
    if result:
        print("[AUTH] [OK] Firebase initialization succeeded")
    else:
        print("[AUTH] [WARNING] Firebase initialization returned None - check logs above")
except Exception as e:
    import traceback
    print(f"[AUTH] [ERROR] Firebase initialization failed: {e}")
    print(f"[AUTH] Stack trace: {traceback.format_exc()}")
    print("[AUTH]    Firebase authentication features may not be available until Firebase is properly configured.")

def generate_verification_token(user_id, email):
    """Generate a verification token for email verification and store in database"""
    import secrets
    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=24)
    
    conn = _pg_conn()
    cursor = conn.cursor()
    try:
        # Invalidate any existing unused tokens for this user
        cursor.execute(
            '''UPDATE user_email_verification_tokens 
               SET used_at = CURRENT_TIMESTAMP 
               WHERE user_id = %s AND used_at IS NULL''',
            (user_id,)
        )
        
        # Insert new token
        cursor.execute(
            '''INSERT INTO user_email_verification_tokens (user_id, token, email, expires_at)
               VALUES (%s, %s, %s, %s)''',
            (user_id, token, email, expires_at)
        )
        conn.commit()
    finally:
        release_pg_conn(conn)
    
    return token

@bp.post("/register")
def register():
    """Register a new user and send verification email"""
    try:
        data = request.get_json()
        if data is None:
            return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
        
        username = data.get('username')
        email = data.get('email')
        password = data.get('password')
        full_name = data.get('full_name')
        role = data.get('role', 'user')
        
        if not all([username, email, password]):
            return {'detail': 'Missing required fields'}, 400
        
        password_hash = hash_password(password)
        
        conn = _pg_conn()
        cursor = conn.cursor()
        try:
            # Check if is_email_verified column exists, if not add it
            try:
                cursor.execute('''
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name='users' AND column_name='is_email_verified'
                ''')
                has_column = cursor.fetchone() is not None
                
                if not has_column:
                    print("[INFO] Adding is_email_verified column to users table...")
                    cursor.execute('''
                        ALTER TABLE users 
                        ADD COLUMN is_email_verified BOOLEAN DEFAULT true
                    ''')
                    conn.commit()
            except Exception as e:
                print(f"[WARN] Could not check/add is_email_verified column: {e}")
            
            # Insert user with email not verified
            try:
                cursor.execute(
                    '''INSERT INTO users (username, email, password_hash, full_name, role, is_email_verified)
                       VALUES (%s, %s, %s, %s, %s, %s)
                       RETURNING id''',
                    (username, email, password_hash, full_name, role, False)
                )
            except psycopg2.ProgrammingError as e:
                # Column doesn't exist, try without it
                if 'is_email_verified' in str(e):
                    print("[WARN] is_email_verified column not found, inserting without it...")
                    cursor.execute(
                        '''INSERT INTO users (username, email, password_hash, full_name, role)
                           VALUES (%s, %s, %s, %s, %s)
                           RETURNING id''',
                        (username, email, password_hash, full_name, role)
                    )
                else:
                    raise
            
            user_id = cursor.fetchone()[0]
            conn.commit()
            
            # Generate verification token and send email
            verification_token = generate_verification_token(user_id, email)
            email_sent = send_verification_email(email, verification_token, username)
            
            if not email_sent:
                print(f'[WARN] Failed to send verification email to {email}, but user was created')
            
            return {
                'detail': 'Registration successful. Please check your email to verify your account.',
                'email': email,
                'email_sent': email_sent
            }, 200
        except psycopg2.IntegrityError:
            conn.rollback()
            return {'detail': 'Username or email already exists'}, 409
        finally:
            release_pg_conn(conn)
    except Exception as e:
        print(f'Registration error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/login")
def login():
    """Login with username and password"""
    try:
        data = request.form
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            # Try JSON
            data = request.get_json()
            if data:
                username = data.get('username')
                password = data.get('password')
            else:
                return {'detail': 'Username and password required'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, username, email, password_hash, full_name, role, department, is_active
               FROM users WHERE username = %s''',
            (username,)
        )
        user = cursor.fetchone()
        release_pg_conn(conn)
        
        if not user or not check_password_hash(user[3], password):
            return {'detail': 'Invalid credentials'}, 401
        
        if not user[7]:  # is_active
            return {'detail': 'Account is inactive'}, 403
        
        # Generate token
        token = generate_token(username)
        save_tokens(get_valid_tokens())
        
        return {
            'token': token,
            'user': {
                'id': user[0],
                'username': user[1],
                'email': user[2],
                'full_name': user[4],
                'role': user[5],
                'department': user[6]
            }
        }, 200
    except Exception as e:
        print(f'Login error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/login-email")
def login_email():
    """Login with email and password"""
    try:
        data = request.get_json()
        if data is None:
            return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
        
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return {'detail': 'Email and password required'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, username, email, password_hash, full_name, role, department, is_active
               FROM users WHERE email = %s''',
            (email,)
        )
        user = cursor.fetchone()
        release_pg_conn(conn)
        
        if not user or not check_password_hash(user[3], password):
            return {'detail': 'Invalid credentials'}, 401
        
        if not user[7]:  # is_active
            return {'detail': 'Account is inactive'}, 403
        
        # Generate token
        token = generate_token(user[1])  # username
        save_tokens(get_valid_tokens())
        
        return {
            'token': token,
            'user': {
                'id': user[0],
                'username': user[1],
                'email': user[2],
                'full_name': user[4],
                'role': user[5],
                'department': user[6]
            }
        }, 200
    except Exception as e:
        print(f'Login error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/forgot-password")
def forgot_password():
    """Request password reset"""
    try:
        data = request.get_json()
        if data is None:
            return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
        
        email = data.get('email')
        if not email:
            return {'detail': 'Missing email'}, 400
        
        # Check if user exists
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
        result = cursor.fetchone()
        release_pg_conn(conn)
        
        if not result:
            # For security, don't reveal whether email exists
            return {'detail': 'If this email exists, a password reset link will be sent'}, 200
        
        # Generate reset token (using old method for password reset)
        reset_token = os.urandom(32).hex()
        
        # Send password reset email
        from api.utils.helpers import get_frontend_url
        frontend_url = get_frontend_url()
        reset_link = f"{frontend_url}/verify.html?token={reset_token}"
        
        subject = "Reset Your Password"
        html_content = f"""
        <html>
            <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 10px;">
                    <h1 style="color: #333;">Password Reset Request</h1>
                    <p style="color: #666; font-size: 16px;">We received a request to reset your password. Click the link below to reset it.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{reset_link}" style="background-color: #007bff; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-size: 16px;">Reset Password</a>
                    </div>
                    <p style="color: #999; font-size: 12px;">If you didn't request this, you can ignore this email.</p>
                    <p style="color: #999; font-size: 12px;">This link will expire in 24 hours.</p>
                </div>
            </body>
        </html>
        """
        
        send_email(email, subject, html_content)
        
        return {'detail': 'If this email exists, a password reset link will be sent', 'message': 'Password reset link has been sent to your email'}, 200
    except Exception as e:
        print(f'Forgot password error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/me")
@token_required
def get_current_user(username=None):
    """Get current user information"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, username, email, full_name, role, department, is_active
                   FROM users WHERE username = %s''',
                (username,)
            )
            result = cursor.fetchone()
            if result:
                return {
                    'id': result[0],
                    'username': result[1],
                    'email': result[2],
                    'full_name': result[3],
                    'role': result[4],
                    'department': result[5],
                    'is_active': result[6]
                }
            
            return {'detail': 'User not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/user/profile")
@token_required
def get_user_profile(username=None):
    """Get user profile (alias for /me)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, username, email, full_name, role, department, is_active
                   FROM users WHERE username = %s''',
                (username,)
            )
            result = cursor.fetchone()
            if result:
                return {
                    'id': result[0],
                    'username': result[1],
                    'email': result[2],
                    'full_name': result[3],
                    'role': result[4],
                    'department': result[5],
                    'is_active': result[6]
                }
            
            return {'detail': 'User not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/test")
def test_auth_blueprint():
    """Test route to verify auth blueprint is registered"""
    return {'status': 'ok', 'message': 'Auth blueprint is working'}, 200

@bp.route("/firebase", methods=['OPTIONS'])
def options_firebase():
    return {}, 200

@bp.post("/firebase")
def firebase_auth():
    """
    Authenticate with Firebase ID token
    Creates or updates user in database based on Firebase user
    """
    try:
        data = request.get_json(silent=True)
        if data is None:
            return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
        
        id_token = data.get('idToken') or data.get('id_token')
        if not id_token:
            return {'detail': 'Firebase ID token required'}, 400
        
        # Get role from request (for new registrations)
        requested_role = data.get('role', 'user')
        
        # Verify Firebase token
        decoded_token = verify_firebase_token(id_token)
        if not decoded_token:
            return {'detail': 'Invalid or expired Firebase token'}, 401
        
        # Extract user info from Firebase token
        firebase_user = get_user_from_token(decoded_token)
        if not firebase_user:
            return {'detail': 'Could not extract user information from token'}, 401
        
        uid = firebase_user['uid']
        email = firebase_user['email']
        name = firebase_user.get('name') or email.split('@')[0]  # Use email prefix if no name
        
        # Check if user exists in database
        conn = _pg_conn()
        cursor = conn.cursor()
        
        try:
            # Try to find user by email or create firebase_uid column if needed
            cursor.execute(
                '''SELECT id, username, email, full_name, role, department, is_active
                   FROM users WHERE lower(email) = lower(%s)
                   ORDER BY id DESC
                   LIMIT 1''',
                (email,)
            )
            user = cursor.fetchone()
            
            if user:
                # User exists, update Firebase UID if needed
                user_id = user[0]
                username = user[1]
                user_role = user[4]  # Get role from database
                
                # Normalize role: map variations to standardized roles
                # Supported normalized roles: 'admin', 'manager', 'finance_manager'
                role_lower = user_role.lower().strip() if user_role else 'user'
                if role_lower in ['admin', 'ceo']:
                    normalized_role = 'admin'
                elif role_lower in ['financial manager', 'finance manager', 'finance_manager', 'financial_manager']:
                    # Preserve a distinct finance manager role so frontend can route to finance dashboard
                    normalized_role = 'finance_manager'
                elif role_lower in ['manager', 'creator', 'user']:
                    normalized_role = 'manager'
                else:
                    # Default to manager for unknown roles but log it for visibility
                    normalized_role = 'manager'
                    print(f'⚠️ Unknown role "{user_role}", defaulting to "manager"')
                
                print(f'🔍 Login: User found - email={email}, role from DB="{user_role}", normalized="{normalized_role}"')
                
                # Check if firebase_uid column exists, if not we'll skip updating it
                try:
                    cursor.execute(
                        '''UPDATE users SET firebase_uid = %s WHERE id = %s''',
                        (uid, user_id)
                    )
                    conn.commit()
                except psycopg2.ProgrammingError:
                    # Column doesn't exist, that's okay
                    conn.rollback()

                # Generate backend auth token for this user using legacy token system
                backend_token = generate_token(username)
                save_tokens(get_valid_tokens())
                
                return {
                    'token': id_token,  # Return Firebase token for frontend
                    'backend_token': backend_token,
                    'user': {
                        'id': user[0],
                        'username': user[1],
                        'email': user[2],
                        'full_name': user[3],
                        'role': normalized_role,  # Return normalized role
                        'department': user[5],
                        'firebase_uid': uid
                    }
                }, 200
            else:
                # User doesn't exist, create new user
                username = email.split('@')[0]  # Use email prefix as username
                
                # Make username unique if needed
                base_username = username
                counter = 1
                while True:
                    cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                    if cursor.fetchone() is None:
                        break
                    username = f"{base_username}{counter}"
                    counter += 1
                
                # Use requested role if provided, otherwise default to 'manager'
                # Supported roles: 'admin', 'manager', 'finance_manager'
                normalized_role = requested_role.lower().strip() if requested_role else 'manager'
                if normalized_role in ['admin', 'ceo']:
                    role_to_use = 'admin'
                elif normalized_role in ['financial manager', 'finance manager', 'finance_manager', 'financial_manager', 'finance']:
                    # Preserve a distinct finance manager role so frontend can route to finance dashboard
                    role_to_use = 'finance_manager'
                elif normalized_role in ['manager', 'creator', 'user']:
                    role_to_use = 'manager'
                else:
                    # Default to manager for unknown roles
                    role_to_use = 'manager'
                    print(f'⚠️ Unknown role "{requested_role}", defaulting to "manager"')
                
                print(f'🔍 Registration: requested_role="{requested_role}", normalized="{normalized_role}", using="{role_to_use}"')

                # For Firebase-only accounts, we don't use a local password.
                # Just store a deterministic non-null string to satisfy NOT NULL constraint.
                dummy_password_hash = f"firebase:{uid}:{email}"

                cursor.execute(
                    '''INSERT INTO users (username, email, password_hash, full_name, role, is_active, is_email_verified)
                       VALUES (%s, %s, %s, %s, %s, %s, %s)
                       RETURNING id, username, email, full_name, role, department, is_active''',
                    (username, email, dummy_password_hash, name, role_to_use, True, firebase_user.get('email_verified', False))
                )
                user = cursor.fetchone()
                user_id = user[0]
                
                # Try to add firebase_uid if column exists
                try:
                    cursor.execute(
                        '''UPDATE users SET firebase_uid = %s WHERE id = %s''',
                        (uid, user_id)
                    )
                except psycopg2.ProgrammingError:
                    # Column doesn't exist, that's okay
                    pass
                
                conn.commit()

                # Generate backend auth token for this new user using legacy token system
                backend_token = generate_token(user[1])
                save_tokens(get_valid_tokens())
                
                return {
                    'token': id_token,  # Return Firebase token for frontend
                    'backend_token': backend_token,
                    'user': {
                        'id': user[0],
                        'username': user[1],
                        'email': user[2],
                        'full_name': user[3],
                        'role': user[4],
                        'department': user[5],
                        'firebase_uid': uid
                    }
                }, 201  # Created
        finally:
            release_pg_conn(conn)
            
    except Exception as e:
        print(f'Firebase auth error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/firebase/verify")
@firebase_token_required
def verify_firebase_auth(firebase_user=None, firebase_uid=None, firebase_email=None):
    """
    Verify Firebase token and return user info
    Protected endpoint that requires valid Firebase token
    """
    try:
        # Get user from database
        conn = _pg_conn()
        cursor = conn.cursor()
        
        try:
            cursor.execute(
                '''SELECT id, username, email, full_name, role, department, is_active
                   FROM users WHERE lower(email) = lower(%s)
                   ORDER BY id DESC
                   LIMIT 1''',
                (firebase_email,)
            )
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found in database'}, 404
            
            return {
                'user': {
                    'id': user[0],
                    'username': user[1],
                    'email': user[2],
                    'full_name': user[3],
                    'role': user[4],
                    'department': user[5],
                    'is_active': user[6],
                    'firebase_uid': firebase_uid
                }
            }, 200
        finally:
            release_pg_conn(conn)
    except Exception as e:
        return {'detail': str(e)}, 500


@bp.post("/khonobuzz/jwt-login")
def khonobuzz_jwt_login():
    """
    Authenticate user using external Khonobuzz JWT token.

    Expects JSON body: {"token": "<jwt>"} or query parameter ?token=...
    Validates JWT, upserts user by email, and returns backend auth token + user info.
    """
    try:
        data = request.get_json(silent=True) or {}
        token = data.get('token') or request.args.get('token')

        if not token:
            return {'detail': 'JWT token is required'}, 400

        try:
            decoded = validate_jwt_token(token)
            user_info = extract_user_info(decoded)
        except JWTValidationError as e:
            return {'detail': str(e)}, 401

        email = user_info.get('email')
        user_id_claim = user_info.get('user_id')

        if not email:
            return {'detail': 'Token must include email or user_email/email_address claim'}, 400

        conn = _pg_conn()
        cursor = conn.cursor()

        try:
            cursor.execute(
                '''SELECT id, username, email, full_name, role, department, is_active
                   FROM users WHERE email = %s''',
                (email,)
            )
            user = cursor.fetchone()

            if user:
                user_id = user[0]
                username = user[1]
                full_name = user[3] or email.split('@')[0]
                role_value = user[4] or 'manager'
                department = user[5]
                is_active = user[6]
            else:
                base_username = email.split('@')[0]
                username = base_username
                counter = 1
                while True:
                    cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                    if cursor.fetchone() is None:
                        break
                    username = f"{base_username}{counter}"
                    counter += 1

                full_name = decoded.get('name') or decoded.get('full_name') or email.split('@')[0]
                role_value = decoded.get('role') or 'manager'
                department = decoded.get('department')
                is_active = True

                cursor.execute(
                    '''INSERT INTO users (username, email, password_hash, full_name, role, department, is_active, is_email_verified)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                       RETURNING id''',
                    (
                        username,
                        email,
                        f"external_jwt:{user_id_claim or email}",
                        full_name,
                        role_value,
                        department,
                        is_active,
                        True,
                    ),
                )
                user_id = cursor.fetchone()[0]

                conn.commit()

            backend_token = generate_token(username)
            save_tokens(get_valid_tokens())

            return {
                'token': backend_token,
                'user': {
                    'id': user_id,
                    'username': username,
                    'email': email,
                    'full_name': full_name,
                    'role': role_value,
                    'department': department,
                    'is_active': is_active,
                    'external_source': 'khonobuzz',
                },
                'claims': decoded,
            }, 200
        finally:
            release_pg_conn(conn)
    except Exception as e:
        print(f'Khonobuzz JWT login error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/verify-email")
@bp.get("/verify-email")
def verify_email():
    """Verify email address using verification token (supports both GET and POST)"""
    try:
        # Support both GET (from email link) and POST (from frontend)
        if request.method == 'GET':
            token = request.args.get('token')
            print(f"[VERIFY] GET request - token from args: {token[:20] + '...' if token else 'None'}")
        else:
            print(f"[VERIFY] POST request - Content-Type: {request.content_type}")
            data = request.get_json()
            if data is None:
                print("[VERIFY] ERROR: Invalid JSON or missing Content-Type header")
                print(f"[VERIFY] Request data: {request.data}")
                return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
            token = data.get('token')
            print(f"[VERIFY] POST request - token from JSON: {token[:20] + '...' if token else 'None'}")
        
        if not token:
            print("[VERIFY] ERROR: Verification token required")
            return {'detail': 'Verification token required'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            # Find token
            cursor.execute(
                '''SELECT user_id, email, expires_at, used_at
                   FROM user_email_verification_tokens
                   WHERE token = %s''',
                (token,)
            )
            token_data = cursor.fetchone()
            
            if not token_data:
                print(f"[VERIFY] Token not found in user tokens table, checking client invites...")
                cursor.execute(
                    '''SELECT id, invited_email, expires_at, status, email_verified_at
                       FROM client_onboarding_invitations
                       WHERE access_token = %s''',
                    (token,)
                )
                invite = cursor.fetchone()
                if invite:
                    invite_id = invite['id']
                    invited_email = invite['invited_email']
                    expires_at = invite['expires_at']
                    status = invite['status']
                    email_verified_at = invite['email_verified_at']
                    print(f"[VERIFY] Invitation token matched - id: {invite_id}, email: {invited_email}, status: {status}")

                    if status != 'pending':
                        return {'detail': 'This invitation has already been completed or cancelled.'}, 400

                    now = datetime.now(timezone.utc)
                    if isinstance(expires_at, str):
                        expires_at = datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
                    elif expires_at and expires_at.tzinfo is None:
                        expires_at = expires_at.replace(tzinfo=timezone.utc)
                    elif expires_at:
                        expires_at = expires_at.astimezone(timezone.utc)

                    if expires_at and now > expires_at:
                        return {'detail': 'This invitation link has expired.'}, 400

                    if not email_verified_at:
                        cursor.execute(
                            '''UPDATE client_onboarding_invitations
                               SET email_verified_at = CURRENT_TIMESTAMP
                               WHERE id = %s''',
                            (invite_id,)
                        )
                        conn.commit()
                        print(f"[VERIFY] ✅ Invitation email verified for invite_id: {invite_id}")

                    detail = {
                        'detail': 'Client invitation email verified',
                        'email': invited_email,
                        'invitation_id': invite_id
                    }

                    if request.method == 'GET':
                        from api.utils.helpers import get_frontend_url
                        frontend_url = get_frontend_url()
                        html = f"""
                        <!DOCTYPE html>
                        <html>
                        <head><meta charset="UTF-8"><title>Email Verified</title></head>
                        <body style="font-family: Arial, sans-serif; background:#000; color:#fff; display:flex; align-items:center; justify-content:center; min-height:100vh;">
                          <div style="background:#1A1A1A; border:1px solid rgba(233,41,58,0.3); border-radius:16px; padding:32px; max-width:520px; text-align:center;">
                            <h1>Email Verified</h1>
                            <p>The onboarding invitation for <strong>{invited_email}</strong> is verified. You may continue the onboarding process.</p>
                            <a href="{frontend_url}/#/onboard?token={token}" style="display:inline-block; margin-top:24px; background:#E9293A; color:#fff; padding:12px 24px; text-decoration:none; border-radius:8px;">Continue Onboarding</a>
                          </div>
                        </body>
                        </html>
                        """
                        from flask import Response
                        return Response(html, mimetype='text/html'), 200

                    return detail, 200

                print(f"[VERIFY] ERROR: Token not found in any table: {token[:20]}...")
                return {'detail': 'Invalid verification token'}, 400
            
            user_id = token_data['user_id']
            email = token_data['email']
            expires_at = token_data['expires_at']
            used_at = token_data['used_at']
            print(f"[VERIFY] Token found - user_id: {user_id}, email: {email}, expires_at: {expires_at}, used_at: {used_at}")
            
            # Check if already used
            if used_at:
                print(f"[VERIFY] ERROR: Token already used at {used_at}")
                return {'detail': 'This verification link has already been used'}, 400
            
            # Check if expired
            # Ensure both datetimes are timezone-aware for comparison
            now = datetime.now(timezone.utc)
            if isinstance(expires_at, str):
                expires_at = datetime.fromisoformat(expires_at.replace('Z', '+00:00'))
            elif expires_at.tzinfo is None:
                # If timezone-naive, assume UTC
                expires_at = expires_at.replace(tzinfo=timezone.utc)
            else:
                expires_at = expires_at.astimezone(timezone.utc)
            
            if now > expires_at:
                print(f"[VERIFY] ERROR: Token expired. Now: {now}, Expires: {expires_at}")
                return {'detail': 'Verification link has expired. Please request a new one.'}, 400
            
            # Mark token as used
            cursor.execute(
                '''UPDATE user_email_verification_tokens
                   SET used_at = CURRENT_TIMESTAMP
                   WHERE token = %s''',
                (token,)
            )
            
            # Update user email verification status
            try:
                cursor.execute(
                    '''UPDATE users
                       SET is_email_verified = TRUE, updated_at = CURRENT_TIMESTAMP
                       WHERE id = %s''',
                    (user_id,)
                )
            except psycopg2.ProgrammingError as e:
                # Column doesn't exist, try to add it first
                if 'is_email_verified' in str(e):
                    print("[INFO] Adding is_email_verified column to users table...")
                    cursor.execute('''
                        ALTER TABLE users 
                        ADD COLUMN is_email_verified BOOLEAN DEFAULT true
                    ''')
                    conn.commit()
                    # Retry the update
                    cursor.execute(
                        '''UPDATE users
                           SET is_email_verified = TRUE, updated_at = CURRENT_TIMESTAMP
                           WHERE id = %s''',
                        (user_id,)
                    )
                else:
                    raise
            
            conn.commit()
            
            print(f"[VERIFY] ✅ Email verified successfully for user_id: {user_id}, email: {email}")
            
            # Return HTML for GET requests (from email link), JSON for POST
            if request.method == 'GET':
                from api.utils.helpers import get_frontend_url
                frontend_url = get_frontend_url()
                html_response = f"""
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Email Verified - Khonology</title>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>
                        body {{
                            font-family: 'Poppins', Arial, sans-serif;
                            background: #000;
                            color: #fff;
                            padding: 24px;
                            margin: 0;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            min-height: 100vh;
                        }}
                        .container {{
                            max-width: 600px;
                            background: #1A1A1A;
                            border-radius: 16px;
                            border: 1px solid rgba(233, 41, 58, 0.3);
                            padding: 32px;
                            text-align: center;
                        }}
                        h1 {{
                            color: #fff;
                            font-size: 24px;
                            margin-bottom: 16px;
                        }}
                        p {{
                            color: #B3B3B3;
                            font-size: 16px;
                            line-height: 1.6;
                        }}
                        .success-icon {{
                            font-size: 64px;
                            color: #4CAF50;
                            margin-bottom: 20px;
                        }}
                        a {{
                            display: inline-block;
                            background-color: #E9293A;
                            color: #fff;
                            padding: 14px 32px;
                            text-decoration: none;
                            border-radius: 8px;
                            font-size: 16px;
                            font-weight: 600;
                            margin-top: 24px;
                        }}
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="success-icon">✓</div>
                        <h1>Email Verified Successfully!</h1>
                        <p>Your email address <strong>{email}</strong> has been verified.</p>
                        <p>You can now log in to your account.</p>
                        <a href="{frontend_url}/login">Go to Login</a>
                    </div>
                </body>
                </html>
                """
                from flask import Response
                return Response(html_response, mimetype='text/html'), 200
            
            return {
                'detail': 'Email verified successfully',
                'email': email
            }, 200
        finally:
            release_pg_conn(conn)
    except Exception as e:
        print(f'Email verification error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/resend-verification")
def resend_verification():
    """Resend verification email"""
    try:
        data = request.get_json()
        if data is None:
            return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
        
        email = data.get('email')
        if not email:
            return {'detail': 'Email address required'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        try:
            # Find user (check if is_email_verified column exists first)
            try:
                cursor.execute(
                    '''SELECT id, username, email, is_email_verified
                       FROM users WHERE email = %s''',
                    (email,)
                )
                user = cursor.fetchone()
                if user:
                    user_id, username, user_email, is_verified = user[0], user[1], user[2], user[3]
            except psycopg2.ProgrammingError as e:
                # Column doesn't exist, select without it
                if 'is_email_verified' in str(e):
                    cursor.execute(
                        '''SELECT id, username, email
                           FROM users WHERE email = %s''',
                        (email,)
                    )
                    user = cursor.fetchone()
                    if user:
                        user_id, username, user_email = user[0], user[1], user[2]
                        is_verified = False
                else:
                    raise
            
            if not user:
                # For security, don't reveal whether email exists
                return {'detail': 'If this email exists and is not verified, a verification email will be sent'}, 200
            
            # Check if already verified
            if is_verified:
                return {'detail': 'Email is already verified'}, 400
            
            # Generate new verification token and send email
            verification_token = generate_verification_token(user_id, user_email)
            email_sent = send_verification_email(user_email, verification_token, username)
            
            if not email_sent:
                return {'detail': 'Failed to send verification email. Please try again later.'}, 500
            
            return {
                'detail': 'Verification email sent successfully',
                'email': user_email
            }, 200
        finally:
            release_pg_conn(conn)
    except Exception as e:
        print(f'Resend verification error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

