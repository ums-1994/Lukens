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
                maxconn=10,
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
        get_pg_pool().putconn(conn)
    except Exception as e:
        print(f"⚠️ Error releasing PostgreSQL connection: {e}")

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
valid_tokens = {}

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
    return token

def verify_token(token):
    if token not in valid_tokens:
        return None
    token_data = valid_tokens[token]
    if datetime.now() > token_data['expires_at']:
        del valid_tokens[token]
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
                except (IndexError, AttributeError):
                    return {'detail': 'Invalid token format'}, 401
        
        if not token:
            return {'detail': 'Token is missing'}, 401
        
        username = verify_token(token)
        if not username:
            return {'detail': 'Invalid or expired token'}, 401
        
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
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''SELECT id, title, client, owner_id, status, created_at, updated_at, template_key, content, sections, pdf_url
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
                'created_at': row[5].isoformat() if row[5] else None,
                'updated_at': row[6].isoformat() if row[6] else None,
                'template_key': row[7],
                'content': row[8],
                'sections': json.loads(row[9]) if row[9] else {},
                'pdf_url': row[10]
            })
            return proposals, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals")
@token_required
def create_proposal(username):
    try:
        data = request.get_json()
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
        user_id = cursor.fetchone()[0]
        
        cursor.execute(
            '''INSERT INTO proposals (title, client, owner_id, template_key)
               VALUES (%s, %s, %s, %s) RETURNING id, title, client, owner_id, status, created_at, updated_at''',
            (data['title'], data['client'], user_id, data.get('template_key'))
        )
        result = cursor.fetchone()
        conn.commit()
        release_pg_conn(conn)
        
        return {
            'id': result[0],
            'title': result[1],
            'client': result[2],
            'owner_id': result[3],
            'status': result[4],
            'created_at': result[5].isoformat(),
            'updated_at': result[6].isoformat(),
            'sections': {}
        }, 201
    except Exception as e:
        return {'detail': str(e)}, 500

@app.put("/proposals/<int:proposal_id>")
@token_required
def update_proposal(username, proposal_id):
    try:
        data = request.get_json()
        
        conn = _pg_conn()
        cursor = conn.cursor()
        
        sections = json.dumps(data.get('sections', {})) if 'sections' in data else None
        
        updates = ['updated_at = NOW()']
        params = []
        
        if 'title' in data:
            updates.append('title = %s')
            params.append(data['title'])
        if 'client' in data:
            updates.append('client = %s')
            params.append(data['client'])
        if sections:
            updates.append('sections = %s')
            params.append(sections)
        if 'content' in data:
            updates.append('content = %s')
            params.append(data['content'])
        if 'pdf_url' in data:
            updates.append('pdf_url = %s')
            params.append(data['pdf_url'])
        
        params.append(proposal_id)
        cursor.execute(f'''UPDATE proposals SET {', '.join(updates)} WHERE id = %s''', params)
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal updated'}, 200
    except Exception as e:
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

@app.post("/proposals/<int:proposal_id>/approve")
@token_required
def approve_proposal(username, proposal_id):
    try:
        comments = request.args.get('comments', '')
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = 'Approved' WHERE id = %s''',
            (proposal_id,)
        )
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal approved'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.post("/proposals/<int:proposal_id>/reject")
@token_required
def reject_proposal(username, proposal_id):
    try:
        comments = request.args.get('comments', '')
        
        conn = _pg_conn()
        cursor = conn.cursor()
        cursor.execute(
            '''UPDATE proposals SET status = 'Rejected' WHERE id = %s''',
            (proposal_id,)
        )
        conn.commit()
        release_pg_conn(conn)
        return {'detail': 'Proposal rejected'}, 200
    except Exception as e:
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
def create_comment(proposal_id: int):
    """Create a new comment on a document"""
    try:
        data = request.get_json()
        
        with _pg_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO document_comments 
                       (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                       VALUES (%s, %s, %s, %s, %s, %s)
                       RETURNING id, proposal_id, comment_text, created_by, created_at, 
                                 section_index, highlighted_text, status, updated_at""",
                    (
                        proposal_id,
                        data['comment_text'],
                        data['created_by'],
                        data.get('section_index'),
                        data.get('highlighted_text'),
                        'open'
                    )
                )
                result = cur.fetchone()
                conn.commit()
                
                return {
                    "id": result[0],
                    "proposal_id": result[1],
                    "comment_text": result[2],
                    "created_by": result[3],
                    "created_at": result[4].isoformat() if result[4] else None,
                    "section_index": result[5],
                    "highlighted_text": result[6],
                    "status": result[7],
                    "updated_at": result[8].isoformat() if result[8] else None,
                    "resolved_by": None,
                    "resolved_at": None
                }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/comments/proposal/{proposal_id}")
def get_proposal_comments(proposal_id: int):
    """Get all comments for a proposal"""
    try:
        with _pg_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    """SELECT id, proposal_id, comment_text, created_by, created_at,
                              section_index, highlighted_text, status, updated_at, resolved_by, resolved_at
                       FROM document_comments
                       WHERE proposal_id = %s
                       ORDER BY created_at DESC""",
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
                        "created_at": row["created_at"].isoformat() if row["created_at"] else None,
                        "section_index": row["section_index"],
                        "highlighted_text": row["highlighted_text"],
                        "status": row["status"],
                        "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
                        "resolved_by": row["resolved_by"],
                        "resolved_at": row["resolved_at"].isoformat() if row["resolved_at"] else None
                    })
                return comments
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Health check endpoint (no auth required)
@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "ok", "db_initialized": _db_initialized}, 200

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
