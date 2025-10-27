import os
import sys
import json
import re
import base64
import hashlib
import hmac
import secrets
import smtplib
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
from flask import Flask, request, jsonify, send_file, Response, send_from_directory
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from asgiref.wsgi import WsgiToAsgi
import openai
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app, supports_credentials=True)

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

# Initialize OpenAI with API key
openai.api_key = os.getenv('OPENAI_API_KEY')

# Database initialization - PostgreSQL only
BACKEND_TYPE = 'postgresql'

# PostgreSQL connection pool
_pg_pool = None

def get_pg_pool():
    global _pg_pool
    if _pg_pool is None:
        import psycopg2.pool
        try:
            db_config = {
                'host': os.getenv('DB_HOST', 'localhost'),
                'database': os.getenv('DB_NAME', 'proposal_db'),
                'user': os.getenv('DB_USER', 'postgres'),
                'password': os.getenv('DB_PASSWORD', ''),
                'port': int(os.getenv('DB_PORT', '5432'))
            }
            print(f"🔄 Connecting to PostgreSQL: {db_config['host']}:{db_config['port']}/{db_config['database']}")
            _pg_pool = psycopg2.pool.SimpleConnectionPool(
                minconn=1,
                maxconn=20,  # Increased max connections
                **db_config
            )
            print("✅ PostgreSQL connection pool created successfully")
        except Exception as e:
            print(f"❌ Error creating PostgreSQL connection pool: {e}")
            raise
    return _pg_pool

def _pg_conn():
    try:
        return get_pg_pool().getconn()
    except Exception as e:
        print(f"❌ Error getting PostgreSQL connection: {e}")
        raise

def release_pg_conn(conn):
    try:
        if conn:
            get_pg_pool().putconn(conn)
    except Exception as e:
        print(f"⚠️ Error releasing PostgreSQL connection: {e}")

# Context manager for automatic connection cleanup
from contextlib import contextmanager

@contextmanager
def get_db_connection():
    """Context manager that ensures connections are always returned to pool"""
    conn = None
    try:
        conn = _pg_conn()
        yield conn
    finally:
        if conn:
            release_pg_conn(conn)

# Token for encryption
ENCRYPTION_KEY = os.getenv('ENCRYPTION_KEY', 'dev-key-change-in-production')
cipher = Fernet(base64.urlsafe_b64encode(ENCRYPTION_KEY.ljust(32)[:32].encode()))

def init_pg_schema():
    """Initialize PostgreSQL schema on app startup"""
    conn = None
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        
        # Users table
        cursor.execute('''CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(255),
        role VARCHAR(50) DEFAULT 'user',
        department VARCHAR(255),
        is_active BOOLEAN DEFAULT true,
        is_email_verified BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )''')
        
        
        cursor.execute('''CREATE TABLE IF NOT EXISTS proposals (
        id SERIAL PRIMARY KEY,
        title VARCHAR(500) NOT NULL,
        client VARCHAR(500) NOT NULL,
        owner_id INTEGER NOT NULL,
        status VARCHAR(50) DEFAULT 'Draft',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        template_key VARCHAR(255),
        content TEXT,
        sections TEXT,
        pdf_url TEXT,
        client_can_edit BOOLEAN DEFAULT false,
        FOREIGN KEY (owner_id) REFERENCES users(id)
        )''')
        
        cursor.execute('''CREATE TABLE IF NOT EXISTS content (
        id SERIAL PRIMARY KEY,
        key VARCHAR(255) UNIQUE NOT NULL,
        label VARCHAR(500) NOT NULL,
        content TEXT,
        category VARCHAR(100) DEFAULT 'Templates',
        is_folder BOOLEAN DEFAULT false,
        parent_id INTEGER,
        public_id VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_deleted BOOLEAN DEFAULT false,
        FOREIGN KEY (parent_id) REFERENCES content(id)
        )''')
        
        cursor.execute('''CREATE TABLE IF NOT EXISTS settings (
        id SERIAL PRIMARY KEY,
        key VARCHAR(255) UNIQUE NOT NULL,
        value TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )''')
        
        cursor.execute('''CREATE TABLE IF NOT EXISTS proposal_versions (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        version_number INTEGER NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_by INTEGER,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id),
        FOREIGN KEY (created_by) REFERENCES users(id)
        )''')
        
        # Document comments table
        cursor.execute('''CREATE TABLE IF NOT EXISTS document_comments (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        comment_text TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        section_index INTEGER,
        highlighted_text TEXT,
        status VARCHAR(50) DEFAULT 'open',
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        resolved_by INTEGER,
        resolved_at TIMESTAMP,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id),
        FOREIGN KEY (created_by) REFERENCES users(id),
        FOREIGN KEY (resolved_by) REFERENCES users(id)
        )''')
        
        # Collaboration invitations table
        cursor.execute('''CREATE TABLE IF NOT EXISTS collaboration_invitations (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        invited_email VARCHAR(255) NOT NULL,
        invited_by INTEGER NOT NULL,
        access_token VARCHAR(500) UNIQUE NOT NULL,
        permission_level VARCHAR(50) DEFAULT 'comment',
        status VARCHAR(50) DEFAULT 'pending',
        invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        accessed_at TIMESTAMP,
        expires_at TIMESTAMP,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
        FOREIGN KEY (invited_by) REFERENCES users(id)
        )''')
        
        conn.commit()
        release_pg_conn(conn)
        print("✅ PostgreSQL schema initialized successfully")
    except Exception as e:
        print(f"❌ Error initializing PostgreSQL schema: {e}")
        if conn:
            try:
                release_pg_conn(conn)
            except:
                pass
        raise

# Initialize database schema on first request
@app.before_request
def init_db():
    """Initialize PostgreSQL schema on first request"""
    global _db_initialized
    if _db_initialized:
        return
    
    try:
        print("🔄 Initializing PostgreSQL schema...")
        init_pg_schema()
        _db_initialized = True
        print("✅ Database schema initialized successfully")
    except Exception as e:
        print(f"❌ Database initialization error: {e}")
        raise

# Auth token storage (in production, use Redis or session manager)
# File-based persistence to survive restarts
TOKEN_FILE = os.path.join(os.path.dirname(__file__), 'auth_tokens.json')

def load_tokens():
    """Load tokens from file"""
    try:
        if os.path.exists(TOKEN_FILE):
            with open(TOKEN_FILE, 'r') as f:
                data = json.load(f)
                # Convert string timestamps back to datetime objects
                for token, token_data in data.items():
                    token_data['created_at'] = datetime.fromisoformat(token_data['created_at'])
                    token_data['expires_at'] = datetime.fromisoformat(token_data['expires_at'])
                print(f"[INFO] Loaded {len(data)} tokens from file")
                return data
    except Exception as e:
        print(f"[WARN] Could not load tokens from file: {e}")
    return {}

def save_tokens():
    """Save tokens to file"""
    try:
        # Convert datetime objects to strings for JSON serialization
        data = {}
        for token, token_data in valid_tokens.items():
            data[token] = {
                'username': token_data['username'],
                'created_at': token_data['created_at'].isoformat(),
                'expires_at': token_data['expires_at'].isoformat()
            }
        with open(TOKEN_FILE, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"[INFO] Saved {len(data)} tokens to file")
    except Exception as e:
        print(f"[WARN] Could not save tokens to file: {e}")

valid_tokens = load_tokens()

# Utility functions
def get_db():
    """Get PostgreSQL connection"""
    return _pg_conn()

def hash_password(password):
    return generate_password_hash(password)

def verify_password(stored_hash, password):
    return check_password_hash(stored_hash, password)

def generate_token(username):
    token = secrets.token_urlsafe(32)
    valid_tokens[token] = {
        'username': username,
        'created_at': datetime.now(),
        'expires_at': datetime.now() + timedelta(days=7)
    }
    save_tokens()  # Persist to file
    print(f"🎫 Generated new token for user '{username}': {token[:20]}...{token[-10:]}")
    print(f"📋 Total valid tokens: {len(valid_tokens)}")
    return token

def verify_token(token):
    if token not in valid_tokens:
        return None
    token_data = valid_tokens[token]
    if datetime.now() > token_data['expires_at']:
        del valid_tokens[token]
        save_tokens()  # Persist after deleting expired token
        return None
    return token_data['username']


def send_email(to_email, subject, html_content):
    """Send email using SMTP"""
    try:
        smtp_host = os.getenv('SMTP_HOST')
        smtp_port = int(os.getenv('SMTP_PORT', '587'))
        smtp_user = os.getenv('SMTP_USER')
        smtp_pass = os.getenv('SMTP_PASS')
        
        if not all([smtp_host, smtp_user, smtp_pass]):
            print(f"❌ SMTP configuration incomplete")
            return False
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = smtp_user
        msg['To'] = to_email
        
        # Attach HTML content
        html_part = MIMEText(html_content, 'html')
        msg.attach(html_part)
        
        # Send email
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            server.starttls()
            server.login(smtp_user, smtp_pass)
            server.send_message(msg)
        
        print(f"✅ Email sent to {to_email}")
        return True
    except Exception as e:
        print(f"❌ Error sending email: {e}")
        traceback.print_exc()
        return False


def send_password_reset_email(email, reset_token):
    """Send password reset email"""
    frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8080')
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
    
    return send_email(email, subject, html_content)

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header:
                try:
                    token = auth_header.split(" ")[1]
                    print(f"🔑 Token received: {token[:20]}...{token[-10:]}")
                except (IndexError, AttributeError):
                    print(f"❌ Invalid token format in header: {auth_header}")
                    return {'detail': 'Invalid token format'}, 401
        
        if not token:
            print(f"❌ No token found in Authorization header")
            return {'detail': 'Token is missing'}, 401
        
        print(f"🔍 Validating token... (valid_tokens has {len(valid_tokens)} tokens)")
        username = verify_token(token)
        if not username:
            print(f"❌ Token validation failed - token not found or expired")
            print(f"📋 Current valid tokens: {list(valid_tokens.keys())[:3]}...")
            return {'detail': 'Invalid or expired token'}, 401
        
        print(f"✅ Token validated for user: {username}")
        return f(username=username, *args, **kwargs)
    return decorated

def admin_required(f):
    @wraps(f)
    def decorated(username=None, *args, **kwargs):
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
        result = cursor.fetchone()
        release_pg_conn(conn)
        
        if not result or result[0] != 'admin':
            return {'detail': 'Admin access required'}, 403
        
        return f(username=username, *args, **kwargs)
    return decorated

# Authentication endpoints

@app.post("/register")
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
        
        conn = _pg_conn()
        cursor = conn.cursor()
        try:
            cursor.execute(
                '''INSERT INTO users (username, email, password_hash, full_name, role)
                   VALUES (%s, %s, %s, %s, %s)''',
                (username, email, password_hash, full_name, role)
            )
            conn.commit()
        except psycopg2.IntegrityError:
            conn.rollback()
            return {'detail': 'Username or email already exists'}, 409
        finally:
            release_pg_conn(conn)
        
        # Email verification disabled - users can login immediately
        # verification_token = generate_verification_token(email)
        # send_verification_email(email, verification_token)
        
        return {'detail': 'Registration successful. You can now login.', 'email': email}, 200
    except Exception as e:
        print(f'Registration error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/login")
def login():
    try:
        data = request.form
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return {'detail': 'Missing username or password'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('SELECT password_hash FROM users WHERE username = %s', (username,))
        result = cursor.fetchone()
        release_pg_conn(conn)
        
        if not result or not result[0] or not verify_password(result[0], password):
            return {'detail': 'Invalid credentials'}, 401
        
        token = generate_token(username)
        return {'access_token': token, 'token_type': 'bearer'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/login-email")
def login_email():
    try:
        data = request.get_json()
        if data is None:
            return {'detail': 'Invalid JSON or missing Content-Type header'}, 400
        
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return {'detail': 'Missing email or password'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('SELECT password_hash FROM users WHERE email = %s', (email,))
        result = cursor.fetchone()
        release_pg_conn(conn)
        
        if not result or not result[0] or not verify_password(result[0], password):
            return {'detail': 'Invalid credentials'}, 401
        
        token = generate_token(email)
        return {'access_token': token, 'token_type': 'bearer'}, 200
    except Exception as e:
        print(f'Login error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500


@app.post("/forgot-password")
def forgot_password():
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
        
        # Generate reset token
        reset_token = generate_verification_token(email)
        
        # Send password reset email
        send_password_reset_email(email, reset_token)
        
        return {'detail': 'If this email exists, a password reset link will be sent', 'message': 'Password reset link has been sent to your email'}, 200
    except Exception as e:
        print(f'Forgot password error: {e}')
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/me")
@token_required
def get_current_user(username):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, username, email, full_name, role, department, is_active
               FROM users WHERE username = %s''',
            (username,)
        )
        result = cursor.fetchone()
        release_pg_conn(conn)
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

@app.get("/user/profile")
@token_required
def get_user_profile(username):
    """Alias for /me endpoint for Flutter compatibility"""
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, username, email, full_name, role, department, is_active
               FROM users WHERE username = %s''',
            (username,)
        )
        result = cursor.fetchone()
        release_pg_conn(conn)
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

# Content library endpoints

@app.get("/content")
@token_required
def get_content(username):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('''SELECT id, key, label, content, category, is_folder, parent_id, public_id
                       FROM content WHERE is_deleted = false ORDER BY created_at DESC''')
        rows = cursor.fetchall()
        release_pg_conn(conn)
        content = []
        for row in rows:
            content.append({
                'id': row[0],
                'key': row[1],
                'label': row[2],
                'content': row[3],
                'category': row[4],
                'is_folder': row[5],
                'parent_id': row[6],
                'public_id': row[7]
            })
        return {'content': content}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/content")
@token_required
def create_content(username):
    try:
        data = request.get_json()
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''INSERT INTO content (key, label, content, category, is_folder, parent_id, public_id)
               VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id''',
            (data['key'], data['label'], data.get('content', ''), 
             data.get('category', 'Templates'), data.get('is_folder', False),
             data.get('parent_id'), data.get('public_id'))
        )
        content_id = cursor.fetchone()[0]
        conn.commit()
        release_pg_conn(conn)
        return {'id': content_id, 'detail': 'Content created'}, 201
    except Exception as e:
        return {'detail': str(e)}, 500

@app.put("/content/<int:content_id>")
@token_required
def update_content(username, content_id):
    try:
        data = request.get_json()
        
        conn = _pg_conn()
        cursor = conn.cursor()
        updates = []
        params = []
        if 'label' in data:
            updates.append('label = %s')
            params.append(data['label'])
        if 'content' in data:
            updates.append('content = %s')
            params.append(data['content'])
        if 'category' in data:
            updates.append('category = %s')
            params.append(data['category'])
        if 'public_id' in data:
            updates.append('public_id = %s')
            params.append(data['public_id'])
        
        if not updates:
                return {'detail': 'No updates provided'}, 400
        
        params.append(content_id)
        cursor.execute(f'''UPDATE content SET {', '.join(updates)} WHERE id = %s''', params)
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Content updated'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.delete("/content/<int:content_id>")
@token_required
def delete_content(username, content_id):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('UPDATE content SET is_deleted = true WHERE id = %s', (content_id,))
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Content deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/content/<int:content_id>/restore")
@token_required
def restore_content(username, content_id):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('UPDATE content SET is_deleted = false WHERE id = %s', (content_id,))
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Content restored'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.delete("/content/<int:content_id>/permanent")
@token_required
def permanently_delete_content(username, content_id):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('DELETE FROM content WHERE id = %s', (content_id,))
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Content permanently deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.get("/content/trash")
@token_required
def get_trash(username):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('''SELECT id, key, label, content, category, is_folder, parent_id, public_id
                       FROM content WHERE is_deleted = true ORDER BY created_at DESC''')
        rows = cursor.fetchall()
        release_pg_conn(conn)
        trash = []
        for row in rows:
            trash.append({
                'id': row[0],
                'key': row[1],
                'label': row[2],
                'content': row[3],
                'category': row[4],
                'is_folder': row[5],
                'parent_id': row[6],
                'public_id': row[7]
            })
        return trash, 200
    except Exception as e:
        return {'detail': str(e)}, 500

# Proposal endpoints

@app.get("/proposals")
@token_required
def get_proposals(username):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            print(f"🔍 Looking for proposals for user {username}")
            
            # Query all columns that exist in the database
            cursor.execute(
                '''SELECT id, user_id, title, content, status, client_name, client_email, 
                          budget, timeline_days, created_at, updated_at
                   FROM proposals WHERE user_id = %s
                   ORDER BY created_at DESC''',
                (username,)
            )
            rows = cursor.fetchall()
            proposals = []
            for row in rows:
                proposals.append({
                    'id': row[0],
                    'user_id': row[1],
                    'owner_id': row[1],  # For compatibility
                    'title': row[2],
                    'content': row[3],
                    'status': row[4],
                    'client_name': row[5],
                    'client': row[5],  # For compatibility
                    'client_email': row[6],
                    'budget': float(row[7]) if row[7] else None,
                    'timeline_days': row[8],
                    'created_at': row[9].isoformat() if row[9] else None,
                    'updated_at': row[10].isoformat() if row[10] else None,
                    'updatedAt': row[10].isoformat() if row[10] else None,
                })
            print(f"✅ Found {len(proposals)} proposals for user {username}")
            return proposals, 200
    except Exception as e:
        print(f"❌ Error getting proposals: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/proposals")
@token_required
def create_proposal(username):
    try:
        data = request.get_json()
        print(f"📝 Creating proposal for user {username}: {data.get('title', 'Untitled')}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Insert using all available columns
            client_name = data.get('client_name') or data.get('client') or 'Unknown Client'
            client_email = data.get('client_email') or ''
            
            cursor.execute(
                '''INSERT INTO proposals (user_id, title, content, status, client_name, client_email, budget, timeline_days)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s) 
                   RETURNING id, user_id, title, content, status, client_name, client_email, budget, timeline_days, created_at, updated_at''',
                (
                    username,
                    data.get('title', 'Untitled Document'),
                    data.get('content'),
                    data.get('status', 'draft'),
                    client_name,
                    client_email,
                    data.get('budget'),
                    data.get('timeline_days')
                )
            )
            result = cursor.fetchone()
            conn.commit()
            
            proposal = {
                'id': result[0],
                'user_id': result[1],
                'owner_id': result[1],  # For compatibility
                'title': result[2],
                'content': result[3],
                'status': result[4],
                'client_name': result[5],
                'client': result[5],
                'client_email': result[6],
                'budget': float(result[7]) if result[7] else None,
                'timeline_days': result[8],
                'created_at': result[9].isoformat() if result[9] else None,
                'updated_at': result[10].isoformat() if result[10] else None,
                'updatedAt': result[10].isoformat() if result[10] else None,
            }
            
            print(f"✅ Proposal created successfully with ID: {result[0]}")
            return proposal, 201
    except Exception as e:
        print(f"❌ Error creating proposal: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.put("/proposals/<int:proposal_id>")
@token_required
def update_proposal(username, proposal_id):
    try:
        data = request.get_json()
        print(f"📝 Updating proposal {proposal_id} for user {username}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            updates = ['updated_at = NOW()']
            params = []
            
            # Update all columns that exist in the database
            if 'title' in data:
                updates.append('title = %s')
                params.append(data['title'])
            if 'content' in data:
                updates.append('content = %s')
                params.append(data['content'])
            if 'status' in data:
                updates.append('status = %s')
                params.append(data['status'])
            if 'client_name' in data or 'client' in data:
                updates.append('client_name = %s')
                params.append(data.get('client_name') or data.get('client'))
            if 'client_email' in data:
                updates.append('client_email = %s')
                params.append(data['client_email'])
            if 'budget' in data:
                updates.append('budget = %s')
                params.append(data['budget'])
            if 'timeline_days' in data:
                updates.append('timeline_days = %s')
                params.append(data['timeline_days'])
            
            params.append(proposal_id)
            cursor.execute(f'''UPDATE proposals SET {', '.join(updates)} WHERE id = %s''', params)
            conn.commit()
            
            print(f"✅ Proposal {proposal_id} updated successfully")
            return {'detail': 'Proposal updated'}, 200
    except Exception as e:
        print(f"❌ Error updating proposal {proposal_id}: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.delete("/proposals/<int:proposal_id>")
@token_required
def delete_proposal(username, proposal_id):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('DELETE FROM proposals WHERE id = %s', (proposal_id,))
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.get("/proposals/<int:proposal_id>")
@token_required
def get_proposal(username, proposal_id):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, title, client, owner_id, status, created_at, updated_at, template_key, content, sections, pdf_url
               FROM proposals WHERE id = %s''',
            (proposal_id,)
        )
        result = cursor.fetchone()
        release_pg_conn(conn)
        
        if result:
                return {
                'id': result[0],
                'title': result[1],
                'client': result[2],
                'owner_id': result[3],
                'status': result[4],
                'created_at': result[5].isoformat() if result[5] else None,
                'updated_at': result[6].isoformat() if result[6] else None,
                'template_key': result[7],
                'content': result[8],
                'sections': json.loads(result[9]) if result[9] else {},
                'pdf_url': result[10]
            }, 200
        return {'detail': 'Proposal not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/submit")
@token_required
def submit_for_review(username, proposal_id):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT sections FROM proposals WHERE id = %s''',
            (proposal_id,)
        )
        result = cursor.fetchone()
        release_pg_conn(conn)
        if not result:
            return {'detail': 'Proposal not found'}, 404
        
        sections = json.loads(result[0]) if result[0] else {}
        
        # Check if all required fields are filled
        issues = []
        for field in ['Introduction', 'Methodology', 'Conclusion']:
            if not sections.get(field):
                issues.append(f'{field} is required')
        
        if issues:
            return {'detail': {'issues': issues}}, 400
        
        # Update status
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = 'Submitted' WHERE id = %s RETURNING *''',
            (proposal_id,)
        )
        result = cursor.fetchone()
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal submitted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/api/proposals/<int:proposal_id>/send-for-approval")
@token_required
def send_for_approval(username, proposal_id):
    """Send proposal for CEO approval"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Check if proposal exists and belongs to user
            cursor.execute(
                'SELECT id, title, status FROM proposals WHERE id = %s AND user_id = %s',
                (proposal_id, username)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            current_status = proposal[2]
            if current_status != 'draft':
                return {'detail': f'Proposal is already {current_status}'}, 400
            
            # Update status to Pending CEO Approval
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() 
                   WHERE id = %s RETURNING status''',
                ('Pending CEO Approval', proposal_id)
            )
            result = cursor.fetchone()
            conn.commit()
            
            print(f"✅ Proposal {proposal_id} sent for approval")
            return {
                'detail': 'Proposal sent for approval successfully',
                'status': result[0]
            }, 200
            
    except Exception as e:
        print(f"❌ Error sending proposal for approval: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/approve")
@token_required
def approve_proposal(username, proposal_id):
    """Approve proposal and send to client"""
    try:
        # Handle both JSON and empty body
        data = request.get_json(force=True, silent=True) or {}
        comments = data.get('comments', '')
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get proposal details including client email
            cursor.execute(
                '''SELECT id, title, client_name, client_email, user_id 
                   FROM proposals WHERE id = %s''',
                (proposal_id,)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            proposal_id, title, client_name, client_email, creator = proposal
            
            # Update status to Sent to Client
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() 
                   WHERE id = %s RETURNING status''',
                ('Sent to Client', proposal_id)
            )
            result = cursor.fetchone()
            conn.commit()
            
            if result:
                print(f"[SUCCESS] Proposal {proposal_id} '{title}' approved and status updated")
                
                # Send email to client if email is provided
                if client_email and client_email.strip():
                    try:
                        proposal_url = f"{FRONTEND_URL}/#/client-portal/{proposal_id}"
                        
                        email_body = f"""
                        <html>
                        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                            <div style="background-color: #2ECC71; padding: 20px; text-align: center;">
                                <h1 style="color: white; margin: 0;">Proposal Approved</h1>
                            </div>
                            <div style="padding: 30px; background-color: #f9f9f9;">
                                <p>Dear {client_name or 'Valued Client'},</p>
                                
                                <p>Great news! Your proposal "<strong>{title}</strong>" has been approved and is ready for your review.</p>
                                
                                <div style="background-color: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
                                    <h3 style="margin-top: 0; color: #2C3E50;">Proposal Details</h3>
                                    <p><strong>Title:</strong> {title}</p>
                                    <p><strong>Status:</strong> <span style="color: #2ECC71;">Approved & Ready for Review</span></p>
                                </div>
                                
                                <div style="text-align: center; margin: 30px 0;">
                                    <a href="{proposal_url}" 
                                       style="background-color: #2ECC71; color: white; padding: 15px 30px; 
                                              text-decoration: none; border-radius: 5px; display: inline-block;
                                              font-weight: bold;">
                                        View Proposal
                                    </a>
                                </div>
                                
                                <p style="color: #7F8C8D; font-size: 12px; margin-top: 30px;">
                                    This is an automated message. Please do not reply to this email.
                                </p>
                            </div>
                        </body>
                        </html>
                        """
                        
                        send_email(
                            to_email=client_email,
                            subject=f"Proposal Approved: {title}",
                            body=email_body
                        )
                        print(f"[SUCCESS] Email sent to client: {client_email}")
                    except Exception as email_error:
                        print(f"[WARN] Could not send email to client: {email_error}")
                        # Don't fail the approval if email fails
                
                return {
                    'detail': 'Proposal approved and sent to client',
                    'status': result[0],
                    'email_sent': bool(client_email and client_email.strip())
                }, 200
            else:
                return {'detail': 'Failed to update proposal status'}, 500
                
    except Exception as e:
        print(f"[ERROR] Error approving proposal: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/reject")
@token_required
def reject_proposal(username, proposal_id):
    """Reject proposal and send back to draft"""
    try:
        # Handle both JSON and empty body
        data = request.get_json(force=True, silent=True) or {}
        comments = data.get('comments', '')
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Update status to draft (rejected proposals go back to draft for editing)
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() 
                   WHERE id = %s RETURNING id, title, status''',
                ('draft', proposal_id)
            )
            result = cursor.fetchone()
            conn.commit()
            
            if result:
                print(f"✅ Proposal {proposal_id} '{result[1]}' rejected and returned to draft")
                return {
                    'detail': 'Proposal rejected and returned to draft',
                    'status': result[2],
                    'comments': comments
                }, 200
            else:
                return {'detail': 'Proposal not found'}, 404
                
    except Exception as e:
        print(f"❌ Error rejecting proposal: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.patch("/proposals/<int:proposal_id>/status")
@token_required
def update_proposal_status(username, proposal_id):
    try:
        data = request.get_json()
        status = data.get('status')
        
        if not status:
            return {'detail': 'Status is required'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = %s WHERE id = %s''',
            (status, proposal_id)
        )
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Status updated'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/send_to_client")
@token_required
def send_to_client(username, proposal_id):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = 'Sent to Client' WHERE id = %s''',
            (proposal_id,)
        )
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal sent to client'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/client_decline")
@token_required
def client_decline_proposal(username, proposal_id):
    try:
        comments = request.args.get('comments', '')
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = 'Client Declined' WHERE id = %s''',
            (proposal_id,)
        )
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal declined'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/client_view")
@token_required
def track_client_view(username, proposal_id):
    try:
        return {'detail': 'View tracked'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.get("/proposals/pending_approval")
@token_required
def get_pending_approvals(username):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, title, client, owner_id, status, created_at
               FROM proposals WHERE status = 'Submitted' ORDER BY created_at DESC'''
        )
        rows = cursor.fetchall()
        release_pg_conn(conn)
        proposals = []
        for row in rows:
            proposals.append({
                'id': row[0],
                'title': row[1],
                'client': row[2],
                'owner_id': row[3],
                'status': row[4],
                'created_at': row[5].isoformat() if row[5] else None
            })
            return {'proposals': proposals}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.get("/proposals/my_proposals")
@token_required
def get_my_proposals(username):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, title, client, owner_id, status, created_at
               FROM proposals WHERE owner_id = (SELECT id FROM users WHERE username = %s)
               ORDER BY created_at DESC''',
            (username,)
        )
        rows = cursor.fetchall()
        release_pg_conn(conn)
        proposals = []
        for row in rows:
            proposals.append({
                'id': row[0],
                'title': row[1],
                'client': row[2],
                'owner_id': row[3],
                'status': row[4],
                'created_at': row[5].isoformat() if row[5] else None
            })
            return {'proposals': proposals}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/sign")
@token_required
def sign_off(username, proposal_id):
    try:
        data = request.get_json()
        signer_name = data.get('signer_name')
        
        if not signer_name:
            return {'detail': 'Signer name is required'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = 'Signed' WHERE id = %s''',
            (proposal_id,)
        )
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal signed'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/approve")
@token_required
@admin_required
def approve_stage(username, proposal_id):
    try:
        stage = request.args.get('stage')
        
        if not stage:
            return {'detail': 'Stage is required'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = %s WHERE id = %s''',
            (f'Approved - {stage}', proposal_id)
        )
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Stage approved'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/create_esign_request")
@token_required
def request_esign(username, proposal_id):
    try:
        # This would normally interact with an e-signature service
        sign_url = f"https://example.com/sign/{proposal_id}"
        
        return {'sign_url': sign_url}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.get("/client/proposals")
@token_required
def fetch_client_proposals(username):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, title, client, owner_id, status, created_at
               FROM proposals WHERE client_can_edit = true ORDER BY created_at DESC'''
        )
        rows = cursor.fetchall()
        release_pg_conn(conn)
        proposals = []
        for row in rows:
            proposals.append({
                'id': row[0],
                'title': row[1],
                'client': row[2],
                'owner_id': row[3],
                'status': row[4],
                'created_at': row[5].isoformat() if row[5] else None
            })
            return proposals, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.get("/client/proposals/<int:proposal_id>")
@token_required
def get_client_proposal(username, proposal_id):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, title, client, owner_id, status, created_at, content
               FROM proposals WHERE id = %s AND client_can_edit = true''',
            (proposal_id,)
        )
        result = cursor.fetchone()
        release_pg_conn(conn)
        
        if result:
                return {
                'id': result[0],
                'title': result[1],
                'client': result[2],
                'owner_id': result[3],
                'status': result[4],
                'created_at': result[5].isoformat() if result[5] else None,
                'content': result[6]
            }, 200
        return {'detail': 'Proposal not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/client/proposals/<int:proposal_id>/sign")
@token_required
def client_sign_proposal(username, proposal_id):
    try:
        data = request.get_json()
        signer_name = data.get('signer_name')
        
        if not signer_name:
            return {'detail': 'Signer name is required'}, 400
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = 'Client Signed' WHERE id = %s''',
            (proposal_id,)
        )
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal signed by client'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/upload/image")
@token_required
def upload_image(username):
    try:
        if 'file' not in request.files:
            return {'detail': 'No file provided'}, 400
        
        file = request.files['file']
        result = cloudinary.uploader.upload(file)
        return result, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/upload/template")
@token_required
def upload_template(username):
    try:
        if 'file' not in request.files:
            return {'detail': 'No file provided'}, 400
        
        file = request.files['file']
        result = cloudinary.uploader.upload(file)
        return result, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.delete("/upload/<public_id>")
@token_required
def delete_from_cloudinary(username, public_id):
    try:
        cloudinary.uploader.destroy(public_id)
        return {'detail': 'File deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/upload/signature")
@token_required
def get_upload_signature(username):
    try:
        data = request.get_json()
        public_id = data.get('public_id')
        
        # This would normally generate a real Cloudinary signature
        signature = "dummy_signature"
        return {'signature': signature, 'public_id': public_id}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.get("/client/dashboard_stats")
@token_required
def get_client_dashboard_stats(username):
    try:
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT status, COUNT(*) FROM proposals WHERE client_can_edit = true
               GROUP BY status'''
        )
        rows = cursor.fetchall()
        release_pg_conn(conn)
        stats = {row[0]: row[1] for row in rows}
        return stats, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/api/comments/document/<int:proposal_id>")
@token_required
def create_comment(username, proposal_id):
    """Create a new comment on a document"""
    try:
        data = request.get_json()
        comment_text = data.get('comment_text')
        section_index = data.get('section_index')
        highlighted_text = data.get('highlighted_text')
        
        if not comment_text:
            return {'detail': 'Comment text is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute('SELECT id, email, full_name FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user['id']
            
            # Create comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, proposal_id, comment_text, created_by, created_at, 
                          section_index, highlighted_text, status, updated_at
            """, (proposal_id, comment_text, user_id, section_index, highlighted_text, 'open'))
            
            result = cursor.fetchone()
            conn.commit()
            
            return {
                'id': result['id'],
                'proposal_id': result['proposal_id'],
                'comment_text': result['comment_text'],
                'created_by': result['created_by'],
                'created_by_email': user['email'],
                'created_by_name': user['full_name'],
                'created_at': result['created_at'].isoformat() if result['created_at'] else None,
                'section_index': result['section_index'],
                'highlighted_text': result['highlighted_text'],
                'status': result['status'],
                'updated_at': result['updated_at'].isoformat() if result['updated_at'] else None,
                'resolved_by': None,
                'resolved_at': None
            }, 201
            
    except Exception as e:
        print(f"❌ Error creating comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.route("/api/comments/proposal/<int:proposal_id>", methods=['GET', 'OPTIONS'])
def get_proposal_comments(proposal_id):
    """Get all comments for a proposal"""
    try:
        with _pg_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """SELECT 
                           dc.id, dc.proposal_id, dc.comment_text, dc.created_by, dc.created_at,
                           dc.section_index, dc.highlighted_text, dc.status, dc.updated_at, 
                           dc.resolved_by, dc.resolved_at,
                           u.email as created_by_email,
                           u.full_name as created_by_name,
                           r.email as resolved_by_email,
                           r.full_name as resolved_by_name
                       FROM document_comments dc
                       LEFT JOIN users u ON dc.created_by = u.id
                       LEFT JOIN users r ON dc.resolved_by = r.id
                       WHERE dc.proposal_id = %s
                       ORDER BY dc.created_at DESC""",
                    (proposal_id,)
                )
                rows = cur.fetchall()
                
                # Convert timestamps to ISO format
                comments = []
                for row in rows:
                    comments.append({
                        "id": row["id"],
                        "proposal_id": row["proposal_id"],
                        "comment_text": row["comment_text"],
                        "created_by": row["created_by"],
                        "created_by_email": row["created_by_email"],
                        "created_by_name": row["created_by_name"],
                        "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                        "section_index": row["section_index"],
                        "highlighted_text": row["highlighted_text"],
                        "status": row["status"],
                        "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
                        "resolved_by": row["resolved_by"],
                        "resolved_by_email": row["resolved_by_email"],
                        "resolved_by_name": row["resolved_by_name"],
                        "resolved_at": row["resolved_at"].isoformat() if row["resolved_at"] else None
                    })
                return comments
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Proposal Versions endpoints
@app.post("/api/proposals/<int:proposal_id>/versions")
@token_required
def create_version(username, proposal_id):
    """Create a new version of a proposal"""
    try:
        data = request.get_json()
        print(f"📝 Creating version {data.get('version_number')} for proposal {proposal_id}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            user_id = user_row[0] if user_row else None
            
            cursor.execute(
                '''INSERT INTO proposal_versions 
                   (proposal_id, version_number, content, created_by, change_description)
                   VALUES (%s, %s, %s, %s, %s)
                   RETURNING id, proposal_id, version_number, content, created_by, created_at, change_description''',
                (
                    proposal_id,
                    data.get('version_number', 1),
                    data.get('content', ''),
                    user_id,
                    data.get('change_description', 'Version created')
                )
            )
            result = cursor.fetchone()
            conn.commit()
            
            version = {
                'id': result[0],
                'proposal_id': result[1],
                'version_number': result[2],
                'content': result[3],
                'created_by': result[4],
                'created_at': result[5].isoformat() if result[5] else None,
                'change_description': result[6]
            }
            
            print(f"✅ Version {result[2]} created for proposal {proposal_id}")
            return version, 201
    except Exception as e:
        print(f"❌ Error creating version: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/proposals/<int:proposal_id>/versions")
@token_required
def get_versions(username, proposal_id):
    """Get all versions of a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, proposal_id, version_number, content, created_by, created_at, change_description
                   FROM proposal_versions
                   WHERE proposal_id = %s
                   ORDER BY version_number DESC''',
                (proposal_id,)
            )
            rows = cursor.fetchall()
            
            versions = []
            for row in rows:
                versions.append({
                    'id': row[0],
                    'proposal_id': row[1],
                    'version_number': row[2],
                    'content': row[3],
                    'created_by': row[4],
                    'created_at': row[5].isoformat() if row[5] else None,
                    'change_description': row[6]
                })
            
            print(f"✅ Found {len(versions)} versions for proposal {proposal_id}")
            return versions, 200
    except Exception as e:
        print(f"❌ Error getting versions: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/proposals/<int:proposal_id>/versions/<int:version_number>")
@token_required
def get_version(username, proposal_id, version_number):
    """Get a specific version of a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, proposal_id, version_number, content, created_by, created_at, change_description
                   FROM proposal_versions
                   WHERE proposal_id = %s AND version_number = %s''',
                (proposal_id, version_number)
            )
            row = cursor.fetchone()
            
            if not row:
                return {'detail': 'Version not found'}, 404
            
            version = {
                'id': row[0],
                'proposal_id': row[1],
                'version_number': row[2],
                'content': row[3],
                'created_by': row[4],
                'created_at': row[5].isoformat() if row[5] else None,
                'change_description': row[6]
            }
            
            return version, 200
    except Exception as e:
        print(f"❌ Error getting version: {e}")
        return {'detail': str(e)}, 500

# ============================================================
# AI ASSISTANT ENDPOINTS
# ============================================================

@app.post("/ai/generate")
@token_required
def ai_generate_content(username):
    """Generate proposal content using AI"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        prompt = data.get('prompt', '')
        context = data.get('context', {})
        section_type = data.get('section_type', 'general')
        
        if not prompt:
            return {'detail': 'Prompt is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Create enhanced prompt with context
        full_context = {
            'user_request': prompt,
            'section_type': section_type,
            **context
        }
        
        # Generate content
        generated_content = ai_service.generate_proposal_section(section_type, full_context)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, prompt_text, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'generate', prompt[:500], section_type, 
                      len(generated_content.split()), response_time_ms))
                conn.commit()
                print(f"📊 AI usage tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return {
            'content': generated_content,
            'section_type': section_type
        }, 200
        
    except Exception as e:
        print(f"❌ Error generating AI content: {e}")
        return {'detail': str(e)}, 500

@app.post("/ai/improve")
@token_required
def ai_improve_content(username):
    """Improve existing content using AI"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        content = data.get('content', '')
        section_type = data.get('section_type', 'general')
        
        if not content:
            return {'detail': 'Content is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Get improvement suggestions
        result = ai_service.improve_content(content, section_type)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'improve', section_type, 
                      len(result.get('improved_version', '').split()), response_time_ms))
                conn.commit()
                print(f"📊 AI improve tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return result, 200
        
    except Exception as e:
        print(f"❌ Error improving content: {e}")
        return {'detail': str(e)}, 500

@app.post("/ai/generate-full-proposal")
@token_required
def ai_generate_full_proposal(username):
    """Generate a complete multi-section proposal"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        prompt = data.get('prompt', '')
        context = data.get('context', {})
        
        if not prompt:
            return {'detail': 'Prompt is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Create enhanced context
        full_context = {
            'user_request': prompt,
            'company': 'Khonology',
            **context
        }
        
        # Generate full proposal
        sections = ai_service.generate_full_proposal(full_context)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        total_tokens = sum(len(str(content).split()) for content in sections.values())
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, prompt_text, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'full_proposal', prompt[:500], 'full_proposal', 
                      total_tokens, response_time_ms))
                conn.commit()
                print(f"📊 AI full proposal tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return {
            'sections': sections,
            'section_count': len(sections)
        }, 200
        
    except Exception as e:
        print(f"❌ Error generating full proposal: {e}")
        return {'detail': str(e)}, 500

@app.post("/ai/analyze-risks")
@token_required
def ai_analyze_risks(username):
    """Analyze proposal for risks"""
    try:
        data = request.get_json()
        proposal_id = data.get('proposal_id')
        
        if not proposal_id:
            return {'detail': 'Proposal ID is required'}, 400
        
        # Get proposal data
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                "SELECT * FROM proposals WHERE id = %s",
                (proposal_id,)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Import AI service
            from ai_service import ai_service
            
            # Analyze risks
            risk_analysis = ai_service.analyze_proposal_risks(dict(proposal))
            
            return risk_analysis, 200
        
    except Exception as e:
        print(f"❌ Error analyzing risks: {e}")
        return {'detail': str(e)}, 500

# ============================================================
# AI ANALYTICS ENDPOINTS
# ============================================================

@app.get("/ai/analytics/summary")
@token_required
def get_ai_analytics_summary(username):
    """Get AI usage analytics summary"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Overall stats
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_requests,
                    COUNT(DISTINCT username) as unique_users,
                    AVG(response_time_ms) as avg_response_time,
                    SUM(response_tokens) as total_tokens,
                    COUNT(CASE WHEN was_accepted = TRUE THEN 1 END) as accepted_count,
                    COUNT(CASE WHEN was_accepted = FALSE THEN 1 END) as rejected_count
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
            """)
            overall_stats = cursor.fetchone()
            
            # By endpoint
            cursor.execute("""
                SELECT 
                    endpoint,
                    COUNT(*) as count,
                    AVG(response_time_ms) as avg_response_time
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
                GROUP BY endpoint
                ORDER BY count DESC
            """)
            by_endpoint = cursor.fetchall()
            
            # Daily usage trend
            cursor.execute("""
                SELECT 
                    DATE(created_at) as date,
                    COUNT(*) as requests
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                LIMIT 30
            """)
            daily_trend = cursor.fetchall()
            
            return {
                'overall': dict(overall_stats) if overall_stats else {},
                'by_endpoint': [dict(row) for row in by_endpoint],
                'daily_trend': [dict(row) for row in daily_trend]
            }, 200
            
    except Exception as e:
        print(f"❌ Error fetching AI analytics: {e}")
        return {'detail': str(e)}, 500

@app.get("/ai/analytics/user-stats")
@token_required
def get_user_ai_stats(username):
    """Get current user's AI usage statistics"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_requests,
                    COUNT(DISTINCT endpoint) as endpoints_used,
                    COUNT(CASE WHEN was_accepted = TRUE THEN 1 END) as content_accepted,
                    COUNT(CASE WHEN endpoint = 'full_proposal' THEN 1 END) as full_proposals_generated,
                    AVG(response_time_ms) as avg_response_time,
                    MAX(created_at) as last_used
                FROM ai_usage
                WHERE username = %s
            """, (username,))
            
            stats = cursor.fetchone()
            
            # Recent activity
            cursor.execute("""
                SELECT 
                    endpoint,
                    section_type,
                    response_time_ms,
                    created_at
                FROM ai_usage
                WHERE username = %s
                ORDER BY created_at DESC
                LIMIT 10
            """, (username,))
            
            recent_activity = cursor.fetchall()
            
            return {
                'stats': dict(stats) if stats else {},
                'recent_activity': [dict(row) for row in recent_activity]
            }, 200
            
    except Exception as e:
        print(f"❌ Error fetching user AI stats: {e}")
        return {'detail': str(e)}, 500

@app.post("/ai/feedback")
@token_required
def submit_ai_feedback(username):
    """Submit feedback for AI-generated content"""
    try:
        data = request.get_json()
        ai_usage_id = data.get('ai_usage_id')
        rating = data.get('rating')  # 1-5
        feedback_text = data.get('feedback_text', '')
        was_edited = data.get('was_edited', False)
        
        if not ai_usage_id:
            return {'detail': 'AI usage ID is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Update ai_usage was_accepted status
            cursor.execute("""
                UPDATE ai_usage 
                SET was_accepted = TRUE 
                WHERE id = %s
            """, (ai_usage_id,))
            
            # Insert feedback
            cursor.execute("""
                INSERT INTO ai_content_feedback 
                (ai_usage_id, rating, feedback_text, was_edited)
                VALUES (%s, %s, %s, %s)
            """, (ai_usage_id, rating, feedback_text, was_edited))
            
            conn.commit()
            
            return {'message': 'Feedback submitted successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error submitting feedback: {e}")
        return {'detail': str(e)}, 500

# ============================================================
# COLLABORATION ENDPOINTS
# ============================================================

@app.post("/api/proposals/<int:proposal_id>/invite")
@token_required
def invite_collaborator(username, proposal_id):
    """Invite a collaborator to view and comment on a proposal"""
    try:
        data = request.get_json()
        invited_email = data.get('email')
        permission_level = data.get('permission_level', 'comment')  # 'view' or 'comment'
        
        if not invited_email:
            return {'detail': 'Email is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute('SELECT id, email FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user[0]
            inviter_email = user[1]
            
            # Check if proposal exists and belongs to user
            cursor.execute(
                'SELECT title FROM proposals WHERE id = %s AND user_id = %s',
                (proposal_id, username)
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            proposal_title = proposal[0]
            
            # Generate unique access token
            access_token = secrets.token_urlsafe(32)
            
            # Set expiration (30 days from now)
            expires_at = datetime.now() + timedelta(days=30)
            
            # Create invitation
            cursor.execute("""
                INSERT INTO collaboration_invitations 
                (proposal_id, invited_email, invited_by, access_token, permission_level, expires_at)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (proposal_id, invited_email, user_id, access_token, permission_level, expires_at))
            
            invitation_id = cursor.fetchone()[0]
            conn.commit()
            
            # Send invitation email
            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
            collaboration_url = f"{frontend_url}/#/collaborate?token={access_token}"
            
            subject = f"You've been invited to collaborate on '{proposal_title}'"
            html_content = f"""
            <html>
                <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                        <div style="text-align: center; margin-bottom: 30px;">
                            <h1 style="color: #2C3E50; margin: 0;">Collaboration Invitation</h1>
                        </div>
                        
                        <p style="color: #333; font-size: 16px; line-height: 1.6;">
                            Hi there,
                        </p>
                        
                        <p style="color: #333; font-size: 16px; line-height: 1.6;">
                            <strong>{inviter_email}</strong> has invited you to collaborate on the proposal:
                        </p>
                        
                        <div style="background-color: #f8f9fa; padding: 20px; border-left: 4px solid #3498DB; margin: 20px 0;">
                            <h2 style="color: #2C3E50; margin: 0 0 10px 0; font-size: 18px;">{proposal_title}</h2>
                            <p style="color: #666; margin: 0; font-size: 14px;">
                                Permission: <strong>{permission_level.title()}</strong>
                            </p>
                        </div>
                        
                        <p style="color: #333; font-size: 16px; line-height: 1.6;">
                            You can view the proposal and {'add comments' if permission_level == 'comment' else 'review it'} using the link below:
                        </p>
                        
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{collaboration_url}" 
                               style="background-color: #3498DB; color: white; padding: 14px 30px; text-decoration: none; border-radius: 5px; display: inline-block; font-size: 16px; font-weight: 600;">
                                Open Proposal
                            </a>
                        </div>
                        
                        <p style="color: #666; font-size: 14px; line-height: 1.6;">
                            Or copy and paste this link into your browser:
                        </p>
                        <p style="word-break: break-all; color: #3498DB; font-size: 12px; background-color: #f8f9fa; padding: 10px; border-radius: 4px;">
                            {collaboration_url}
                        </p>
                        
                        <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;">
                            <p style="color: #999; font-size: 12px; line-height: 1.4; margin: 0;">
                                This invitation will expire on {expires_at.strftime('%B %d, %Y at %I:%M %p')}.<br>
                                If you didn't expect this invitation, you can safely ignore this email.
                            </p>
                        </div>
                    </div>
                </body>
            </html>
            """
            
            email_sent = send_email(invited_email, subject, html_content)
            
            return {
                'id': invitation_id,
                'message': 'Invitation sent successfully',
                'email_sent': email_sent,
                'collaboration_url': collaboration_url,
                'expires_at': expires_at.isoformat()
            }, 201
            
    except Exception as e:
        print(f"❌ Error inviting collaborator: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/proposals/<int:proposal_id>/collaborators")
@token_required
def get_collaborators(username, proposal_id):
    """Get all collaborators for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify ownership
            cursor.execute(
                'SELECT id FROM proposals WHERE id = %s AND user_id = %s',
                (proposal_id, username)
            )
            if not cursor.fetchone():
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Get collaborators
            cursor.execute("""
                SELECT 
                    id,
                    invited_email,
                    permission_level,
                    status,
                    invited_at,
                    accessed_at,
                    expires_at
                FROM collaboration_invitations
                WHERE proposal_id = %s
                ORDER BY invited_at DESC
            """, (proposal_id,))
            
            collaborators = cursor.fetchall()
            
            return [dict(row) for row in collaborators], 200
            
    except Exception as e:
        print(f"❌ Error getting collaborators: {e}")
        return {'detail': str(e)}, 500

@app.delete("/api/collaborations/<int:invitation_id>")
@token_required
def remove_collaborator(username, invitation_id):
    """Remove a collaborator invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user[0]
            
            # Check if user owns the proposal
            cursor.execute("""
                SELECT ci.id 
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.id = %s AND (ci.invited_by = %s OR p.user_id = %s)
            """, (invitation_id, user_id, username))
            
            if not cursor.fetchone():
                return {'detail': 'Invitation not found or access denied'}, 404
            
            # Delete invitation
            cursor.execute('DELETE FROM collaboration_invitations WHERE id = %s', (invitation_id,))
            conn.commit()
            
            return {'message': 'Collaborator removed successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error removing collaborator: {e}")
        return {'detail': str(e)}, 500

@app.get("/api/collaborate")
def get_collaboration_access():
    """Get proposal access via collaboration token (no auth required)"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation details
            cursor.execute("""
                SELECT 
                    ci.id,
                    ci.proposal_id,
                    ci.invited_email,
                    ci.permission_level,
                    ci.status,
                    ci.expires_at,
                    p.title,
                    p.content,
                    p.user_id,
                    u.email as owner_email,
                    u.full_name as owner_name
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                JOIN users u ON ci.invited_by = u.id
                WHERE ci.access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                return {'detail': 'Invalid collaboration token'}, 404
            
            # Check if expired
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'This invitation has expired'}, 403
            
            # Update accessed_at timestamp on first access
            if invitation['status'] == 'pending':
                cursor.execute("""
                    UPDATE collaboration_invitations 
                    SET status = 'accepted', accessed_at = NOW()
                    WHERE id = %s
                """, (invitation['id'],))
                conn.commit()
            
            # Get comments for the proposal with user details
            cursor.execute("""
                SELECT 
                    dc.id,
                    dc.comment_text,
                    dc.created_by,
                    u.email as created_by_email,
                    u.full_name as created_by_name,
                    dc.created_at,
                    dc.section_index,
                    dc.highlighted_text,
                    dc.status
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                WHERE dc.proposal_id = %s
                ORDER BY dc.created_at DESC
            """, (invitation['proposal_id'],))
            
            comments = cursor.fetchall()
            
            return {
                'proposal': {
                    'id': invitation['proposal_id'],
                    'title': invitation['title'],
                    'content': invitation['content'],
                    'owner_email': invitation['owner_email'],
                    'owner_name': invitation['owner_name']
                },
                'permission_level': invitation['permission_level'],
                'invited_email': invitation['invited_email'],
                'comments': [dict(row) for row in comments],
                'can_comment': invitation['permission_level'] == 'comment'
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting collaboration access: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/collaborate/comment")
def add_guest_comment():
    """Add a comment as a guest collaborator (no auth required)"""
    try:
        data = request.get_json()
        token = data.get('token')
        comment_text = data.get('comment_text')
        section_index = data.get('section_index')
        highlighted_text = data.get('highlighted_text')
        
        if not token or not comment_text:
            return {'detail': 'Token and comment text are required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token and get permission
            cursor.execute("""
                SELECT 
                    ci.proposal_id,
                    ci.permission_level,
                    ci.invited_email,
                    ci.expires_at
                FROM collaboration_invitations ci
                WHERE ci.access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                return {'detail': 'Invalid collaboration token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'This invitation has expired'}, 403
            
            if invitation['permission_level'] != 'comment':
                return {'detail': 'You do not have permission to comment'}, 403
            
            # Create a guest user if not exists
            guest_email = invitation['invited_email']
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (guest_email, guest_email, '', f'Guest ({guest_email})', 'guest'))
            
            guest_user_id = cursor.fetchone()['id']
            conn.commit()
            
            # Add comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, proposal_id, comment_text, created_by, created_at, 
                          section_index, highlighted_text, status
            """, (
                invitation['proposal_id'],
                comment_text,
                guest_user_id,
                section_index,
                highlighted_text,
                'open'
            ))
            
            result = cursor.fetchone()
            conn.commit()
            
            return {
                'id': result['id'],
                'proposal_id': result['proposal_id'],
                'comment_text': result['comment_text'],
                'created_by': guest_email,
                'created_at': result['created_at'].isoformat() if result['created_at'] else None,
                'section_index': result['section_index'],
                'highlighted_text': result['highlighted_text'],
                'status': result['status']
            }, 201
            
    except Exception as e:
        print(f"❌ Error adding guest comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# Health check endpoint (no auth required)
@app.get("/health")
def health_check():
    """Health check endpoint with connection pool info"""
    pool_info = {
        "status": "ok",
        "db_initialized": _db_initialized
    }
    
    # Add connection pool status if available
    try:
        if _pg_pool:
            # Try to get pool stats (note: SimpleConnectionPool doesn't expose all stats)
            pool_info["database"] = "postgresql"
            pool_info["pool_type"] = "SimpleConnectionPool"
            pool_info["pool_configured"] = True
            
            # Test connection
            try:
                with get_db_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute("SELECT 1")
                    cursor.fetchone()
                pool_info["database_connection"] = "ok"
            except Exception as e:
                pool_info["database_connection"] = f"error: {str(e)}"
        else:
            pool_info["pool_configured"] = False
    except Exception as e:
        pool_info["pool_error"] = str(e)
    
    return pool_info, 200

# Initialize database on app startup
@app.get("/api/init")
def initialize_database():
    """Manual database initialization endpoint"""
    try:
        init_db()
        return {"status": "ok", "message": "Database initialized"}, 200
    except Exception as e:
        return {"status": "error", "message": str(e)}, 500

if __name__ == '__main__':
    # When running with 'python app.py'
    try:
        init_db()  # Initialize database before running
    except Exception as e:
        print(f"Warning: Database initialization failed: {e}")
    app.run(debug=True, host='0.0.0.0', port=8000)
