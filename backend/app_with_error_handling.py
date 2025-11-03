"""
Enhanced Flask App with Comprehensive Error Handling
This is an updated version of your app.py with integrated error handling
"""

import os
import sys
import json
import re
import base64
import hashlib
import hmac
import secrets
import smtplib
import difflib
from datetime import datetime, timedelta
from pathlib import Path
from functools import wraps
from urllib.parse import urlparse, parse_qs
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import traceback

import psycopg2
import psycopg2.extras
import cloudinary
import cloudinary.uploader
from cryptography.fernet import Fernet
from flask import Flask, request, jsonify, send_file, Response, send_from_directory, g
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from asgiref.wsgi import WsgiToAsgi
import openai
from dotenv import load_dotenv

# Import our new error handling system
from error_handler import (
    ErrorHandler, AppError, ValidationError, AuthenticationError, 
    PermissionError, DatabaseError, handle_errors, validate_required_fields, 
    validate_email, require_auth
)
from middleware import RequestMiddleware, require_auth as auth_decorator, rate_limit, validate_json, add_health_check

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app, supports_credentials=True)

# Initialize error handling and middleware
error_handler = ErrorHandler(app)
middleware = RequestMiddleware(app)
add_health_check(app)

# Wrap Flask app with ASGI adapter for Uvicorn compatibility
asgi_app = WsgiToAsgi(app)

# Mark if database has been initialized
_db_initialized = False

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

app.config['JSON_SORT_KEYS'] = False
app.config['PROPAGATE_EXCEPTIONS'] = True

# Configure Cloudinary
cloudinary.config(
    cloud_name=os.getenv('CLOUDINARY_CLOUD_NAME'),
    api_key=os.getenv('CLOUDINARY_API_KEY'),
    api_secret=os.getenv('CLOUDINARY_API_SECRET')
)

# Database configuration
UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', './uploads')
MAX_CONTENT_LENGTH = int(os.getenv('MAX_CONTENT_LENGTH', 104857600))  # 100MB default

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

# Database connection with error handling
def get_db_connection():
    """Get database connection with proper error handling"""
    try:
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            database=os.getenv('DB_NAME', 'lukens_db'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', ''),
            port=os.getenv('DB_PORT', '5432')
        )
        return conn
    except psycopg2.OperationalError as e:
        raise DatabaseError(
            message=f"Database connection failed: {str(e)}",
            user_message="Unable to connect to database. Please try again later."
        )
    except Exception as e:
        raise DatabaseError(
            message=f"Unexpected database error: {str(e)}",
            user_message="Database service temporarily unavailable."
        )


# Enhanced route examples with error handling
@app.route('/register', methods=['POST'])
@handle_errors
@validate_json(['username', 'email', 'password', 'full_name'])
@rate_limit(max_requests=5, window=3600)  # 5 registrations per hour
def register():
    """Enhanced user registration with comprehensive error handling"""
    data = g.json_data
    
    # Validate email format
    validate_email(data['email'])
    
    # Validate password strength
    if len(data['password']) < 8:
        raise ValidationError(
            message="Password too short",
            field="password",
            user_message="Password must be at least 8 characters long"
        )
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check if user already exists
        cursor.execute("SELECT id FROM users WHERE email = %s OR username = %s", 
                      (data['email'], data['username']))
        
        if cursor.fetchone():
            raise ValidationError(
                message="User already exists",
                field="email",
                user_message="An account with this email or username already exists"
            )
        
        # Hash password
        password_hash = generate_password_hash(data['password'])
        
        # Insert new user
        cursor.execute("""
            INSERT INTO users (username, email, password_hash, full_name, role, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            data['username'],
            data['email'],
            password_hash,
            data['full_name'],
            data.get('role', 'user'),
            datetime.utcnow()
        ))
        
        user_id = cursor.fetchone()[0]
        conn.commit()
        
        app.logger.info(f"User registered successfully: {data['email']} [ID: {user_id}]")
        
        return jsonify({
            'success': True,
            'message': 'User registered successfully',
            'user_id': user_id
        }), 201
        
    except psycopg2.IntegrityError as e:
        conn.rollback()
        if 'email' in str(e):
            raise ValidationError(
                message="Email already exists",
                field="email",
                user_message="An account with this email already exists"
            )
        elif 'username' in str(e):
            raise ValidationError(
                message="Username already exists", 
                field="username",
                user_message="This username is already taken"
            )
        else:
            raise DatabaseError(
                message=f"Database integrity error: {str(e)}",
                user_message="Registration failed due to data conflict"
            )
    
    finally:
        if 'conn' in locals():
            conn.close()


@app.route('/login-email', methods=['POST'])
@handle_errors
@validate_json(['email', 'password'])
@rate_limit(max_requests=10, window=900)  # 10 login attempts per 15 minutes
def login_email():
    """Enhanced email login with comprehensive error handling"""
    data = g.json_data
    
    # Validate email format
    validate_email(data['email'])
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        # Get user by email
        cursor.execute("""
            SELECT id, username, email, password_hash, full_name, role, is_active, email_verified
            FROM users WHERE email = %s
        """, (data['email'],))
        
        user = cursor.fetchone()
        
        if not user:
            raise AuthenticationError(
                message="User not found",
                user_message="Invalid email or password"
            )
        
        if not user['is_active']:
            raise AuthenticationError(
                message="Account deactivated",
                user_message="Your account has been deactivated. Please contact support."
            )
        
        # Verify password
        if not check_password_hash(user['password_hash'], data['password']):
            raise AuthenticationError(
                message="Invalid password",
                user_message="Invalid email or password"
            )
        
        # Generate JWT token (placeholder - implement with PyJWT)
        token = generate_jwt_token(user['id'], user['email'])
        
        app.logger.info(f"User logged in successfully: {data['email']} [ID: {user['id']}]")
        
        return jsonify({
            'access_token': token,
            'token_type': 'bearer',
            'user': {
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'full_name': user['full_name'],
                'role': user['role']
            }
        }), 200
        
    finally:
        if 'conn' in locals():
            conn.close()


@app.route('/verify-email', methods=['POST'])
@handle_errors
@validate_json(['token'])
def verify_email():
    """Enhanced email verification with error handling"""
    data = g.json_data
    token = data['token']
    
    if not token:
        raise ValidationError(
            message="No token provided",
            field="token",
            user_message="Invalid verification link"
        )
    
    try:
        # Decode and validate token (implement based on your token system)
        user_id = decode_verification_token(token)
        
        if not user_id:
            raise ValidationError(
                message="Invalid verification token",
                user_message="Invalid or expired verification link"
            )
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Update user email verification status
        cursor.execute("""
            UPDATE users SET email_verified = TRUE, updated_at = %s 
            WHERE id = %s AND email_verified = FALSE
        """, (datetime.utcnow(), user_id))
        
        if cursor.rowcount == 0:
            raise ValidationError(
                message="Email already verified or user not found",
                user_message="Email is already verified or verification link is invalid"
            )
        
        conn.commit()
        
        app.logger.info(f"Email verified successfully for user ID: {user_id}")
        
        return jsonify({
            'success': True,
            'message': 'Email verified successfully'
        }), 200
        
    finally:
        if 'conn' in locals():
            conn.close()


@app.route('/content', methods=['GET'])
@handle_errors
@auth_decorator
def get_content():
    """Enhanced content retrieval with error handling"""
    try:
        category = request.args.get('category')
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        # Build query based on category filter
        if category:
            cursor.execute("""
                SELECT id, key, label, content, category, is_folder, parent_id, 
                       public_id, created_at, updated_at
                FROM content_library 
                WHERE category = %s AND deleted_at IS NULL
                ORDER BY created_at DESC
            """, (category,))
        else:
            cursor.execute("""
                SELECT id, key, label, content, category, is_folder, parent_id, 
                       public_id, created_at, updated_at
                FROM content_library 
                WHERE deleted_at IS NULL
                ORDER BY created_at DESC
            """)
        
        content_items = cursor.fetchall()
        
        # Convert datetime objects to ISO strings
        for item in content_items:
            if item['created_at']:
                item['created_at'] = item['created_at'].isoformat()
            if item['updated_at']:
                item['updated_at'] = item['updated_at'].isoformat()
        
        return jsonify({
            'content': content_items,
            'total': len(content_items)
        }), 200
        
    finally:
        if 'conn' in locals():
            conn.close()


# Utility functions (implement based on your system)
def generate_jwt_token(user_id: int, email: str) -> str:
    """Generate JWT token for user authentication"""
    # Implement with PyJWT library
    # This is a placeholder
    import jwt
    from datetime import datetime, timedelta
    
    payload = {
        'user_id': user_id,
        'email': email,
        'exp': datetime.utcnow() + timedelta(hours=24),
        'iat': datetime.utcnow()
    }
    
    secret_key = os.getenv('JWT_SECRET_KEY', 'your-secret-key')
    return jwt.encode(payload, secret_key, algorithm='HS256')


def decode_verification_token(token: str) -> int:
    """Decode email verification token"""
    # Implement based on your token system
    # This is a placeholder
    try:
        import jwt
        secret_key = os.getenv('JWT_SECRET_KEY', 'your-secret-key')
        payload = jwt.decode(token, secret_key, algorithms=['HS256'])
        return payload.get('user_id')
    except jwt.ExpiredSignatureError:
        raise ValidationError(
            message="Token expired",
            user_message="Verification link has expired. Please request a new one."
        )
    except jwt.InvalidTokenError:
        raise ValidationError(
            message="Invalid token",
            user_message="Invalid verification link"
        )


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8000)
