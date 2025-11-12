"""
Authentication routes
"""
from flask import Blueprint, request, jsonify
import traceback
import secrets
from api.utils.database import get_db_connection
from api.utils.auth import hash_password, verify_password, generate_token
from api.utils.decorators import token_required
from api.utils.email import send_password_reset_email

bp = Blueprint('auth', __name__)

def generate_verification_token(email):
    """Generate a verification token for email verification"""
    return secrets.token_urlsafe(32)

@bp.post("/register")
def register():
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
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    '''INSERT INTO users (username, email, password_hash, full_name, role)
                       VALUES (%s, %s, %s, %s, %s)''',
                    (username, email, password_hash, full_name, role)
                )
                conn.commit()
            except Exception as e:
                conn.rollback()
                if 'unique' in str(e).lower() or 'duplicate' in str(e).lower():
                    return {'detail': 'Username or email already exists'}, 409
                raise
        
        return {'detail': 'Registration successful. You can now login.', 'email': email}, 200
    except Exception as e:
        print(f'Registration error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/login")
def login():
    try:
        data = request.form
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return {'detail': 'Missing username or password'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT password_hash FROM users WHERE username = %s', (username,))
            result = cursor.fetchone()
        
        if not result or not result[0] or not verify_password(result[0], password):
            return {'detail': 'Invalid credentials'}, 401
        
        token = generate_token(username)
        return {'access_token': token, 'token_type': 'bearer'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/login-email")
def login_email():
    try:
        data = request.get_json()
        if data is None:
            return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
        
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return {'detail': 'Missing email or password'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT password_hash FROM users WHERE email = %s', (email,))
            result = cursor.fetchone()
        
        if not result or not result[0] or not verify_password(result[0], password):
            return {'detail': 'Invalid credentials'}, 401
        
        token = generate_token(email)
        return {'access_token': token, 'token_type': 'bearer'}, 200
    except Exception as e:
        print(f'Login error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/forgot-password")
def forgot_password():
    try:
        data = request.get_json()
        if data is None:
            return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
        
        email = data.get('email')
        if not email:
            return {'detail': 'Missing email'}, 400
        
        # Check if user exists
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
            result = cursor.fetchone()
        
        if not result:
            # For security, don't reveal whether email exists
            return {'detail': 'If this email exists, a password reset link will be sent'}, 200
        
        # Generate reset token
        reset_token = generate_verification_token(email)
        
        # Send password reset email
        send_password_reset_email(email, reset_token)
        
        return {'detail': 'If this email exists, a password reset link will be sent', 'message': 'Password reset link has been sent to your email'}, 200
    except Exception as e:
        print(f'Forgot password error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/me")
@token_required
def get_current_user(username):
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
            }, 200
        return {'detail': 'User not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/profile")
@token_required
def get_user_profile(username):
    """Alias for /me endpoint for Flutter compatibility"""
    return get_current_user(username)

