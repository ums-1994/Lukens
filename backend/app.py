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
import html
from datetime import datetime, timedelta
from pathlib import Path
from functools import wraps
from urllib.parse import urlparse, parse_qs
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import traceback
from io import BytesIO

import psycopg2
import psycopg2.extras
import cloudinary
import cloudinary.uploader

# PDF Generation
try:
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
    from reportlab.pdfgen import canvas
    PDF_AVAILABLE = True
except ImportError:
    PDF_AVAILABLE = False
    print("⚠️ ReportLab not installed. PDF generation will be limited. Run: pip install reportlab")

# DocuSign SDK
try:
    from docusign_esign import ApiClient, EnvelopesApi, EnvelopeDefinition, Document, Signer, SignHere, Tabs, Recipients, RecipientViewRequest
    from docusign_esign.client.api_exception import ApiException
    import jwt
    DOCUSIGN_AVAILABLE = True
except ImportError:
    DOCUSIGN_AVAILABLE = False
    print("⚠️ DocuSign SDK not installed. Run: pip install docusign-esign")
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
# Configure CORS to allow requests from frontend
CORS(app, 
     supports_credentials=True,
     origins=['http://localhost:8081', 'http://localhost:8080', 'http://127.0.0.1:8081', '*'],
     methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
     allow_headers=['Content-Type', 'Authorization', 'Collab-Token'],
     expose_headers=['Content-Type', 'Authorization'],
     automatic_options=True)  # Automatically handle OPTIONS requests

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
            
            # Add SSL mode for external connections (like Render)
            # Check if host contains 'render.com' or SSL is explicitly required
            ssl_mode = os.getenv('DB_SSLMODE', 'prefer')
            if 'render.com' in db_config['host'].lower() or os.getenv('DB_REQUIRE_SSL', 'false').lower() == 'true':
                ssl_mode = 'require'
                db_config['sslmode'] = ssl_mode
                print(f"🔒 Using SSL mode: {ssl_mode} for external connection")
            
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
        
        # Add new columns for enhanced comment features (PostgreSQL)
        cursor.execute('''ALTER TABLE document_comments 
                         ADD COLUMN IF NOT EXISTS parent_id INTEGER REFERENCES document_comments(id) ON DELETE CASCADE''')
        cursor.execute('''ALTER TABLE document_comments 
                         ADD COLUMN IF NOT EXISTS block_type VARCHAR(50)''')
        cursor.execute('''ALTER TABLE document_comments 
                         ADD COLUMN IF NOT EXISTS block_id VARCHAR(255)''')
        cursor.execute('''ALTER TABLE document_comments 
                         ADD COLUMN IF NOT EXISTS section_name VARCHAR(255)''')
        
        # Create indexes for performance (PostgreSQL-specific optimizations)
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_document_comments_proposal 
                         ON document_comments(proposal_id)''')
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_document_comments_parent 
                         ON document_comments(parent_id) WHERE parent_id IS NOT NULL''')
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_document_comments_status 
                         ON document_comments(status) WHERE status = 'open' ''')
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_document_comments_section 
                         ON document_comments(proposal_id, section_index) WHERE section_index IS NOT NULL''')
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_document_comments_block 
                         ON document_comments(proposal_id, block_type, block_id) WHERE block_id IS NOT NULL''')
        
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
        
        # Active collaborators table (tracks collaborators who have accessed the proposal)
        cursor.execute('''CREATE TABLE IF NOT EXISTS collaborators (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        email VARCHAR(255) NOT NULL,
        user_id INTEGER,
        invited_by INTEGER NOT NULL,
        permission_level VARCHAR(50) DEFAULT 'comment',
        status VARCHAR(50) DEFAULT 'active',
        joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_accessed_at TIMESTAMP,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
        FOREIGN KEY (invited_by) REFERENCES users(id),
        UNIQUE(proposal_id, email)
        )''')
        
        # Suggested changes table for suggest mode
        cursor.execute('''CREATE TABLE IF NOT EXISTS suggested_changes (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        section_id VARCHAR(255),
        suggested_by INTEGER NOT NULL,
        suggestion_text TEXT NOT NULL,
        original_text TEXT,
        status VARCHAR(50) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        resolved_at TIMESTAMP,
        resolved_by INTEGER,
        resolution_action VARCHAR(50),
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
        FOREIGN KEY (suggested_by) REFERENCES users(id),
        FOREIGN KEY (resolved_by) REFERENCES users(id)
        )''')
        
        # Section locks table for soft locking
        cursor.execute('''CREATE TABLE IF NOT EXISTS section_locks (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        section_id VARCHAR(255) NOT NULL,
        locked_by INTEGER NOT NULL,
        locked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
        FOREIGN KEY (locked_by) REFERENCES users(id),
        UNIQUE(proposal_id, section_id)
        )''')
        
        # Activity log table for comprehensive timeline
        cursor.execute('''CREATE TABLE IF NOT EXISTS activity_log (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        user_id INTEGER,
        action_type VARCHAR(100) NOT NULL,
        action_description TEXT NOT NULL,
        metadata JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id)
        )''')
        
        # Create index for faster activity queries
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_activity_log_proposal 
                         ON activity_log(proposal_id, created_at DESC)''')
        
        # Notifications table
        cursor.execute('''CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        proposal_id INTEGER,
        notification_type VARCHAR(100) NOT NULL,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        metadata JSONB,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        read_at TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE
        )''')

        # Ensure notification table has latest columns/constraints
        cursor.execute('''
            ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS proposal_id INTEGER
        ''')
        cursor.execute('''
            ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS notification_type VARCHAR(100)
        ''')
        cursor.execute('''
            ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS title VARCHAR(255)
        ''')
        cursor.execute('''
            ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS message TEXT
        ''')
        cursor.execute('''
            ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS metadata JSONB
        ''')
        cursor.execute('''
            ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE
        ''')
        cursor.execute('''
            ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ''')
        cursor.execute('''
            ALTER TABLE notifications
            ADD COLUMN IF NOT EXISTS read_at TIMESTAMP
        ''')
        
        # Create index for faster notification queries
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_notifications_user 
                         ON notifications(user_id, is_read, created_at DESC)''')
        
        # Mentions table
        cursor.execute('''CREATE TABLE IF NOT EXISTS comment_mentions (
        id SERIAL PRIMARY KEY,
        comment_id INTEGER NOT NULL,
        mentioned_user_id INTEGER NOT NULL,
        mentioned_by_user_id INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_read BOOLEAN DEFAULT FALSE,
        FOREIGN KEY (comment_id) REFERENCES document_comments(id) ON DELETE CASCADE,
        FOREIGN KEY (mentioned_user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (mentioned_by_user_id) REFERENCES users(id)
        )''')
        
        # Create index for faster mention queries
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_comment_mentions_user 
                         ON comment_mentions(mentioned_user_id, is_read, created_at DESC)''')
        
        # DocuSign signatures table
        cursor.execute('''CREATE TABLE IF NOT EXISTS proposal_signatures (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        envelope_id VARCHAR(255) UNIQUE,
        signer_name VARCHAR(255) NOT NULL,
        signer_email VARCHAR(255) NOT NULL,
        signer_title VARCHAR(255),
        status VARCHAR(50) DEFAULT 'sent',
        signing_url TEXT,
        sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        signed_at TIMESTAMP,
        declined_at TIMESTAMP,
        decline_reason TEXT,
        signed_document_url TEXT,
        created_by INTEGER,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
        FOREIGN KEY (created_by) REFERENCES users(id)
        )''')
        
        # Create index for faster signature queries
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_proposal_signatures 
                         ON proposal_signatures(proposal_id, status, sent_at DESC)''')
        
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

# Handle CORS preflight requests globally (must be first before_request)
@app.before_request
def handle_preflight():
    """Handle CORS preflight OPTIONS requests"""
    if request.method == 'OPTIONS':
        print(f'[CORS] Handling OPTIONS request for: {request.path}')
        response = Response()
        origin = request.headers.get('Origin', '*')
        response.headers.add('Access-Control-Allow-Origin', origin)
        response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization, Collab-Token')
        response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS')
        response.headers.add('Access-Control-Allow-Credentials', 'true')
        response.headers.add('Access-Control-Max-Age', '3600')
        print(f'[CORS] OPTIONS response sent with origin: {origin}')
        return response

# Initialize database schema on first request
@app.before_request
def init_db():
    """Initialize PostgreSQL schema on first request"""
    # Skip OPTIONS requests (handled by handle_preflight)
    if request.method == 'OPTIONS':
        return
    
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

# ============================================================================
# ACTIVITY LOG HELPER
# ============================================================================

def log_activity(proposal_id, user_id, action_type, description, metadata=None):
    """
    Log an activity to the activity timeline
    
    Args:
        proposal_id: ID of the proposal
        user_id: ID of the user performing the action (can be None for system actions)
        action_type: Type of action (e.g., 'comment_added', 'suggestion_created', 'proposal_edited')
        description: Human-readable description of the action
        metadata: Optional dict with additional data
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO activity_log (proposal_id, user_id, action_type, action_description, metadata)
                VALUES (%s, %s, %s, %s, %s)
            """, (proposal_id, user_id, action_type, description, json.dumps(metadata) if metadata else None))
            conn.commit()
    except Exception as e:
        print(f"⚠️ Failed to log activity: {e}")
        # Don't raise - activity logging should not break main functionality

# ============================================================================
# NOTIFICATION HELPER
# ============================================================================

def create_notification(
    user_id,
    notification_type,
    title,
    message,
    proposal_id=None,
    metadata=None,
    send_email_flag=False,
    email_subject=None,
    email_body=None,
):
    """
    Create a notification for a user
    
    Args:
        user_id: ID of the user to notify
        notification_type: Type of notification (e.g., 'comment_added', 'suggestion_created')
        title: Notification title
        message: Notification message
        proposal_id: Optional proposal ID
        metadata: Optional dict with additional data
        send_email_flag: Whether to send an email in addition to the in-app notification
        email_subject: Optional override for the email subject
        email_body: Optional override for the email body (HTML)
    """
    try:
        recipient_info = None
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Determine which notifications table/columns exist (legacy support)
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name IN ('notifications', 'notificationss')
            """)
            table_rows = cursor.fetchall()
            if not table_rows:
                raise Exception("Notifications table not found")

            table_names = {row['table_name'] for row in table_rows}
            table_name = 'notifications' if 'notifications' in table_names else table_rows[0]['table_name']

            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_schema = 'public' AND table_name = %s
            """, (table_name,))
            column_names = {row['column_name'] for row in cursor.fetchall()}

            metadata_json = json.dumps(metadata) if metadata else None

            columns = []
            values = []

            def add_column(col_name, value):
                columns.append(col_name)
                values.append(value)

            add_column('user_id', user_id)

            if 'notification_type' in column_names:
                add_column('notification_type', notification_type)
            if 'type' in column_names:
                add_column('type', notification_type)
            if 'resource_type' in column_names:
                add_column('resource_type', notification_type)
            if 'resource_id' in column_names:
                resource_id = None
                if metadata and isinstance(metadata, dict):
                    resource_id = metadata.get('resource_id')
                if resource_id is None:
                    resource_id = proposal_id
                add_column('resource_id', resource_id)

            if 'title' in column_names:
                add_column('title', title)
            if 'message' in column_names:
                add_column('message', message)
            if 'proposal_id' in column_names:
                add_column('proposal_id', proposal_id)
            if 'metadata' in column_names:
                add_column('metadata', metadata_json)

            placeholders = ', '.join(['%s'] * len(columns))
            columns_sql = ', '.join(columns)

            cursor.execute(
                f"INSERT INTO {table_name} ({columns_sql}) VALUES ({placeholders}) RETURNING id",
                values,
            )
            notification_row = cursor.fetchone()

            if send_email_flag:
                cursor.execute(
                    "SELECT email, full_name FROM users WHERE id = %s",
                    (user_id,)
                )
                recipient_info = cursor.fetchone()

            conn.commit()

        if notification_row:
            print(f"✅ Notification created for user {user_id}: {title}")

        if send_email_flag and recipient_info and recipient_info.get('email'):
            recipient_email = recipient_info['email']
            recipient_name = recipient_info.get('full_name') or recipient_email
            subject = email_subject or title

            html_content = email_body or f"""
            <html>
                <body style="font-family: Arial, sans-serif; line-height: 1.6;">
                    <p>Hi {recipient_name},</p>
                    <p>{message}</p>
                    {f'<p><strong>Proposal ID:</strong> {proposal_id}</p>' if proposal_id else ''}
                    <p style="font-size: 12px; color: #888;">You received this notification because you are part of a proposal on ProposalHub.</p>
                </body>
            </html>
            """

            try:
                send_email(recipient_email, subject, html_content)
                print(f"📧 Notification email sent to {recipient_email}")
            except Exception as email_err:
                print(f"⚠️ Failed to send notification email to {recipient_email}: {email_err}")

    except Exception as e:
        print(f"⚠️ Failed to create notification: {e}")
        # Don't raise - notification should not break main functionality

def notify_proposal_collaborators(
    proposal_id,
    notification_type,
    title,
    message,
    exclude_user_id=None,
    metadata=None,
    send_email_flag=False,
    email_subject=None,
    email_body=None,
):
    """
    Notify all collaborators on a proposal
    
    Args:
        proposal_id: ID of the proposal
        notification_type: Type of notification
        title: Notification title
        message: Notification message
        exclude_user_id: Optional user ID to exclude from notifications (e.g., the person who made the change)
        metadata: Optional dict with additional data
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

            # Fetch proposal details once
            cursor.execute(
                "SELECT user_id, title FROM proposals WHERE id = %s",
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return

            proposal_title = (
                proposal.get('title')
                if isinstance(proposal, dict)
                else None
            ) or f"Proposal #{proposal_id}"

            base_metadata = {
                'proposal_id': proposal_id,
                'proposal_title': proposal_title,
                'resource_id': proposal_id,
            }
            if isinstance(metadata, dict):
                base_metadata.update(metadata)

            def _resolve_user_row(identifier):
                if identifier is None:
                    return None
                if isinstance(identifier, int):
                    cursor.execute(
                        "SELECT id FROM users WHERE id = %s",
                        (identifier,),
                    )
                    return cursor.fetchone()
                # Try to treat as numeric string id
                try:
                    numeric_id = int(identifier)
                except (TypeError, ValueError):
                    numeric_id = None
                if numeric_id is not None:
                    cursor.execute(
                        "SELECT id FROM users WHERE id = %s",
                        (numeric_id,),
                    )
                    row = cursor.fetchone()
                    if row:
                        return row
                cursor.execute(
                    "SELECT id FROM users WHERE username = %s",
                    (identifier,),
                )
                return cursor.fetchone()

            owner = _resolve_user_row(proposal.get('user_id'))
            if owner and owner['id'] != exclude_user_id:
                create_notification(
                    owner['id'],
                    notification_type,
                    title,
                    message,
                    proposal_id,
                    base_metadata,
                    send_email_flag=send_email_flag,
                    email_subject=email_subject,
                    email_body=email_body,
                )

            # Get accepted collaborators (users with accepted invitation)
            cursor.execute(
                """
                SELECT DISTINCT u.id
                FROM collaboration_invitations ci
                JOIN users u ON ci.invited_email = u.email
                WHERE ci.proposal_id = %s AND ci.status = 'accepted'
                """,
                (proposal_id,),
            )

            collaborators = cursor.fetchall()
            for collab in collaborators:
                collab_id = collab.get('id') if isinstance(collab, dict) else collab[0]
                if collab_id and collab_id != exclude_user_id:
                    create_notification(
                        collab_id,
                        notification_type,
                        title,
                        message,
                        proposal_id,
                        base_metadata,
                        send_email_flag=send_email_flag,
                        email_subject=email_subject,
                        email_body=email_body,
                    )
                    
    except Exception as e:
        print(f"⚠️ Failed to notify collaborators: {e}")

# ============================================================================
# MENTION HELPER
# ============================================================================

def extract_mentions(text):
    """
    Extract @mentions from text
    Returns list of mentioned usernames/emails
    
    Supports:
    - @username
    - @email@domain.com
    """
    # Pattern to match @username or @email
    pattern = r'@([a-zA-Z0-9_.+-]+(?:@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)?)'
    mentions = re.findall(pattern, text)
    return list(set(mentions))  # Remove duplicates

def process_mentions(comment_id, comment_text, mentioned_by_user_id, proposal_id):
    """
    Process @mentions in a comment
    - Extract mentions from text
    - Find mentioned users
    - Create mention records
    - Send notifications
    
    Args:
        comment_id: ID of the comment containing mentions
        comment_text: Text of the comment
        mentioned_by_user_id: ID of user who created the comment
        proposal_id: ID of the proposal
    """
    try:
        mentions = extract_mentions(comment_text)
        if not mentions:
            return
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get the commenter's name
            cursor.execute("SELECT full_name FROM users WHERE id = %s", (mentioned_by_user_id,))
            commenter = cursor.fetchone()
            commenter_name = commenter['full_name'] if commenter else 'Someone'
            
            for mention in mentions:
                # Try to find user by username or email
                cursor.execute("""
                    SELECT id, full_name, email FROM users 
                    WHERE username = %s OR email = %s OR email LIKE %s
                """, (mention, mention, f'{mention}@%'))
                
                mentioned_user = cursor.fetchone()
                if not mentioned_user:
                    print(f"⚠️ Mentioned user not found: @{mention}")
                    continue
                
                # Don't mention yourself
                if mentioned_user['id'] == mentioned_by_user_id:
                    continue
                
                # Create mention record
                cursor.execute("""
                    INSERT INTO comment_mentions 
                    (comment_id, mentioned_user_id, mentioned_by_user_id)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                """, (comment_id, mentioned_user['id'], mentioned_by_user_id))
                
                # Send notification
                create_notification(
                    mentioned_user['id'],
                    'mentioned',
                    'You were mentioned',
                    f"{commenter_name} mentioned you in a comment",
                    proposal_id,
                    {'comment_id': comment_id, 'mentioned_by': mentioned_by_user_id},
                    send_email_flag=True,
                    email_subject=f"[ProposalHub] {commenter_name} mentioned you",
                    email_body=f"""
                    <html>
                        <body style='font-family: Arial, sans-serif; line-height:1.6;'>
                            <p>{html.escape(commenter_name)} mentioned you in a comment on proposal #{proposal_id}.</p>
                            <blockquote style='margin: 0; padding-left: 15px; border-left: 3px solid #27ae60; color: #555;'>
                                {html.escape(comment_text)}
                            </blockquote>
                            <p style='font-size: 12px; color: #888;'>Sign in to ProposalHub to respond.</p>
                        </body>
                    </html>
                    """
                )
                
                print(f"✅ Notified @{mentioned_user['email']} about mention")
            
            conn.commit()
            
    except Exception as e:
        print(f"⚠️ Failed to process mentions: {e}")
        traceback.print_exc()

# ============================================================================
# DOCUSIGN HELPER FUNCTIONS
# ============================================================================

def get_docusign_jwt_token():
    """
    Get DocuSign access token using JWT authentication
    """
    if not DOCUSIGN_AVAILABLE:
        raise Exception("DocuSign SDK not installed")
    
    try:
        integration_key = os.getenv('DOCUSIGN_INTEGRATION_KEY')
        user_id = os.getenv('DOCUSIGN_USER_ID')
        auth_server = os.getenv('DOCUSIGN_AUTH_SERVER', 'account-d.docusign.com')
        private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH', './docusign_private.key')
        
        if not all([integration_key, user_id]):
            raise Exception("DocuSign credentials not configured")
        
        # Read private key
        with open(private_key_path, 'r') as key_file:
            private_key = key_file.read()
        
        # Create API client
        api_client = ApiClient()
        api_client.set_base_path(f"https://{auth_server}")
        
        # Request JWT token
        response = api_client.request_jwt_user_token(
            client_id=integration_key,
            user_id=user_id,
            oauth_host_name=auth_server,
            private_key_bytes=private_key,
            expires_in=3600,
            scopes=["signature", "impersonation"]
        )
        
        return response.access_token
        
    except Exception as e:
        print(f"❌ Error getting DocuSign JWT token: {e}")
        raise

def generate_proposal_pdf(proposal_id, title, content, client_name=None, client_email=None):
    """
    Generate a PDF from proposal content using ReportLab
    
    Args:
        proposal_id: ID of the proposal
        title: Proposal title
        content: Proposal content (can be HTML/text)
        client_name: Optional client name
        client_email: Optional client email
    
    Returns:
        bytes: PDF content as bytes
    """
    if not PDF_AVAILABLE:
        # Fallback: Return minimal PDF-like structure
        # If reportlab is not available, create a basic text representation
        # Note: This will not create a valid PDF, but prevents errors
        import warnings
        warnings.warn("ReportLab not available. PDF generation may be limited.")
        
        # Try to use basic canvas if available
        try:
            from reportlab.pdfgen import canvas
        except ImportError:
            # Last resort: return minimal bytes that DocuSign might accept
            # This should rarely happen if reportlab is in requirements.txt
            minimal_pdf = f"""
%PDF-1.4
PROPOSAL #{proposal_id}
Title: {title}
Content: {content[:500] if content else 'No content'}
[SIGNATURE PLACEHOLDER: /sig1/]
            """.encode('utf-8')
            return minimal_pdf
        buffer = BytesIO()
        p = canvas.Canvas(buffer, pagesize=letter)
        width, height = letter
        
        # Title
        p.setFont("Helvetica-Bold", 20)
        p.drawString(50, height - 50, f"PROPOSAL #{proposal_id}")
        
        # Proposal Title
        p.setFont("Helvetica-Bold", 16)
        p.drawString(50, height - 80, title)
        
        # Client info
        if client_name:
            p.setFont("Helvetica", 12)
            p.drawString(50, height - 110, f"Client: {client_name}")
        
        # Content
        p.setFont("Helvetica", 10)
        y_position = height - 150
        
        # Simple text content (first 2000 chars)
        text_content = content[:2000] if content else "No content provided."
        lines = text_content.split('\n')[:50]  # Limit to 50 lines
        
        for line in lines:
            if y_position < 100:
                p.showPage()
                y_position = height - 50
            # Wrap long lines
            words = line.split()
            current_line = ""
            for word in words:
                test_line = current_line + " " + word if current_line else word
                if len(test_line) * 6 < width - 100:  # Approximate character width
                    current_line = test_line
                else:
                    if current_line:
                        p.drawString(50, y_position, current_line)
                        y_position -= 15
                    current_line = word
            if current_line:
                p.drawString(50, y_position, current_line)
                y_position -= 15
        
        # Signature placeholder
        y_position -= 30
        p.setFont("Helvetica-Bold", 12)
        p.drawString(50, y_position, "[SIGNATURE PLACEHOLDER: /sig1/]")
        
        # Footer
        p.setFont("Helvetica", 8)
        p.drawString(50, 30, f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        p.save()
        pdf_bytes = buffer.getvalue()
        buffer.close()
        return pdf_bytes
    
    # Proper PDF generation with ReportLab
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter,
                           rightMargin=72, leftMargin=72,
                           topMargin=72, bottomMargin=18)
    
    # Container for the 'Flowable' objects
    elements = []
    
    # Define styles
    styles = getSampleStyleSheet()
    
    # Title style
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=24,
        textColor='#1a1a1a',
        spaceAfter=30,
        alignment=TA_CENTER
    )
    
    # Heading style
    heading_style = ParagraphStyle(
        'CustomHeading',
        parent=styles['Heading2'],
        fontSize=16,
        textColor='#2c3e50',
        spaceAfter=12,
        spaceBefore=12
    )
    
    # Body style
    body_style = ParagraphStyle(
        'CustomBody',
        parent=styles['Normal'],
        fontSize=11,
        textColor='#333333',
        alignment=TA_JUSTIFY,
        spaceAfter=12,
        leading=14
    )
    
    # Add title
    elements.append(Paragraph(f"PROPOSAL #{proposal_id}", title_style))
    elements.append(Spacer(1, 0.2*inch))
    
    # Add proposal title
    elements.append(Paragraph(title, heading_style))
    elements.append(Spacer(1, 0.1*inch))
    
    # Add client info if available
    if client_name or client_email:
        client_info = []
        if client_name:
            client_info.append(f"Client: {client_name}")
        if client_email:
            client_info.append(f"Email: {client_email}")
        elements.append(Paragraph("<br/>".join(client_info), body_style))
        elements.append(Spacer(1, 0.2*inch))
    
    # Add content
    if content:
        # Clean HTML tags if present (basic cleaning)
        import re
        # Remove HTML tags but keep content
        text_content = re.sub(r'<[^>]+>', '', str(content))
        # Split into paragraphs
        paragraphs = text_content.split('\n\n')
        
        for para in paragraphs:
            if para.strip():
                # Escape special characters for Paragraph
                para_escaped = para.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                elements.append(Paragraph(para_escaped, body_style))
                elements.append(Spacer(1, 0.1*inch))
    
    # Add signature placeholder
    elements.append(PageBreak())
    elements.append(Spacer(1, 4*inch))
    
    sig_style = ParagraphStyle(
        'Signature',
        parent=styles['Normal'],
        fontSize=14,
        textColor='#000000',
        alignment=TA_CENTER,
        spaceBefore=0.5*inch
    )
    
    elements.append(Paragraph("[SIGNATURE PLACEHOLDER: /sig1/]", sig_style))
    elements.append(Spacer(1, 0.5*inch))
    
    # Add footer
    footer_style = ParagraphStyle(
        'Footer',
        parent=styles['Normal'],
        fontSize=8,
        textColor='#666666',
        alignment=TA_CENTER
    )
    elements.append(Paragraph(f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", footer_style))
    
    # Build PDF
    doc.build(elements)
    pdf_bytes = buffer.getvalue()
    buffer.close()
    
    return pdf_bytes

def create_docusign_envelope(proposal_id, pdf_bytes, signer_name, signer_email, signer_title, return_url):
    """
    Create DocuSign envelope with embedded signing
    
    Args:
        proposal_id: ID of the proposal
        pdf_bytes: PDF content as bytes
        signer_name: Name of the signer
        signer_email: Email of the signer
        signer_title: Title of the signer (optional)
        return_url: URL to return to after signing
    
    Returns:
        dict with envelope_id and signing_url
    """
    if not DOCUSIGN_AVAILABLE:
        raise Exception("DocuSign SDK not installed")
    
    try:
        # Get access token
        access_token = get_docusign_jwt_token()
        
        # Get account ID - must be set in .env
        account_id = os.getenv('DOCUSIGN_ACCOUNT_ID')
        if not account_id:
            raise Exception("DOCUSIGN_ACCOUNT_ID is required. Get it from: https://demo.docusign.net → Settings → My Account Information → Account ID")
        
        # Validate account ID format (should be a GUID)
        if len(account_id) < 30 or '-' not in account_id:
            raise Exception(f"Invalid DOCUSIGN_ACCOUNT_ID format: {account_id}. Should be a GUID like: 70784c46-78c0-45af-8207-f4b8e8a43ea")
        
        base_path = os.getenv('DOCUSIGN_BASE_PATH', 'https://demo.docusign.net/restapi')
        
        # Create API client
        api_client = ApiClient()
        api_client.host = base_path
        api_client.set_default_header("Authorization", f"Bearer {access_token}")
        
        # Create document
        document = Document(
            document_base64=base64.b64encode(pdf_bytes).decode('utf-8'),
            name=f'Proposal_{proposal_id}.pdf',
            file_extension='pdf',
            document_id='1'
        )
        
        # Create signer
        sign_here = SignHere(
            anchor_string='/sig1/',
            anchor_units='pixels',
            anchor_y_offset='10',
            anchor_x_offset='20'
        )
        
        tabs = Tabs(sign_here_tabs=[sign_here])
        
        signer = Signer(
            email=signer_email,
            name=signer_name,
            recipient_id='1',
            routing_order='1',
            client_user_id='1000',  # Required for embedded signing
            tabs=tabs
        )
        
        # If title provided, add custom field
        if signer_title:
            signer.note = f"Title: {signer_title}"
        
        # Create recipients
        recipients = Recipients(signers=[signer])
        
        # Create envelope
        envelope_definition = EnvelopeDefinition(
            email_subject=f'Please sign: Proposal #{proposal_id}',
            documents=[document],
            recipients=recipients,
            status='sent'  # Send immediately
        )
        
        # Create envelope via API
        envelopes_api = EnvelopesApi(api_client)
        results = envelopes_api.create_envelope(account_id, envelope_definition=envelope_definition)
        envelope_id = results.envelope_id
        
        print(f"✅ DocuSign envelope created: {envelope_id}")
        
        # Create recipient view (embedded signing URL)
        recipient_view_request = RecipientViewRequest(
            authentication_method='none',
            client_user_id='1000',
            recipient_id='1',
            return_url=return_url,
            user_name=signer_name,
            email=signer_email
        )
        
        view_results = envelopes_api.create_recipient_view(
            account_id,
            envelope_id,
            recipient_view_request=recipient_view_request
        )
        
        signing_url = view_results.url
        
        print(f"✅ Embedded signing URL created")
        
        return {
            'envelope_id': envelope_id,
            'signing_url': signing_url
        }
        
    except ApiException as e:
        print(f"❌ DocuSign API error: {e}")
        raise
    except Exception as e:
        print(f"❌ Error creating DocuSign envelope: {e}")
        traceback.print_exc()
        raise

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

# ============================================================================
# ROUTES MOVED TO ROLE-BASED FILES
# ============================================================================
# All routes have been moved to:
# - api/routes/auth.py (authentication)
# - api/routes/creator.py (creator routes)
# - api/routes/client.py (client routes)
# - api/routes/approver.py (approver routes)
# - api/routes/collaborator.py (collaborator routes)
# - api/routes/shared.py (shared utility routes)
# - api/routes/clients.py (client management)
# ============================================================================

# ============================================================================
# ESSENTIAL ENDPOINTS ONLY
# ============================================================================
# All route definitions have been moved to role-based files.
# See api/routes/ directory for all endpoints.
# ============================================================================

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

# ============================================================================
# BLUEPRINT REGISTRATION
# ============================================================================
try:
    from api.utils.database import init_database
    
    init_database()
    
    # Import blueprints with individual error handling
    blueprints = {}
    blueprint_names = {
        'auth_bp': 'Auth routes',
        'creator_bp': 'Creator routes',
        'client_bp': 'Client routes',
        'approver_bp': 'Approver routes',
        'collaborator_bp': 'Collaborator routes',
        'clients_bp': 'Client management routes',
        'shared_bp': 'Shared utility routes'
    }
    
    try:
        from api.routes import creator_bp, client_bp, approver_bp, collaborator_bp, clients_bp, auth_bp, shared_bp
        blueprints['auth_bp'] = auth_bp
        blueprints['creator_bp'] = creator_bp
        blueprints['client_bp'] = client_bp
        blueprints['approver_bp'] = approver_bp
        blueprints['collaborator_bp'] = collaborator_bp
        blueprints['clients_bp'] = clients_bp
        blueprints['shared_bp'] = shared_bp
    except ImportError as import_error:
        print(f"[WARN] Failed to import blueprints from api.routes: {import_error}")
        # Try alternative import method
        try:
            from api.routes.auth import bp as auth_bp
            from api.routes.creator import bp as creator_bp
            from api.routes.client import bp as client_bp
            from api.routes.approver import bp as approver_bp
            from api.routes.collaborator import bp as collaborator_bp
            from api.routes.clients import bp as clients_bp
            from api.routes.shared import bp as shared_bp
            blueprints['auth_bp'] = auth_bp
            blueprints['creator_bp'] = creator_bp
            blueprints['client_bp'] = client_bp
            blueprints['approver_bp'] = approver_bp
            blueprints['collaborator_bp'] = collaborator_bp
            blueprints['clients_bp'] = clients_bp
            blueprints['shared_bp'] = shared_bp
            print("[OK] Successfully imported blueprints using alternative method")
        except Exception as alt_import_error:
            print(f"[ERROR] Failed to import blueprints using alternative method: {alt_import_error}")
            import traceback
            traceback.print_exc()
            raise
    
    # Register all role-based blueprints with individual error handling
    registered_count = 0
    for bp_name, bp_obj in blueprints.items():
        try:
            app.register_blueprint(bp_obj)
            print(f"[OK] Registered {blueprint_names.get(bp_name, bp_name)}")
            registered_count += 1
        except Exception as reg_error:
            print(f"[ERROR] Failed to register {blueprint_names.get(bp_name, bp_name)}: {reg_error}")
            import traceback
            traceback.print_exc()
    
    print(f"[OK] Successfully registered {registered_count}/{len(blueprints)} blueprints")
    
    # Log all registered routes for debugging (focus on auth routes)
    print("\n[DEBUG] Scanning registered routes...")
    auth_routes = []
    firebase_routes = []
    all_routes_count = 0
    
    for rule in app.url_map.iter_rules():
        all_routes_count += 1
        route_str = f"  {', '.join(rule.methods)} {rule.rule}"
        
        if 'firebase' in rule.rule.lower():
            firebase_routes.append(route_str)
            auth_routes.append(route_str)
        elif 'auth' in rule.rule.lower() or '/register' in rule.rule or '/login' in rule.rule:
            auth_routes.append(route_str)
    
    print(f"[DEBUG] Total routes registered: {all_routes_count}")
    
    if auth_routes:
        print(f"\n[DEBUG] Auth-related routes found ({len(auth_routes)}):")
        for route in auth_routes:
            print(route)
    else:
        print("\n[WARN] No auth-related routes found!")
    
    # Specifically check for /firebase route
    if firebase_routes:
        print(f"\n[OK] Firebase routes found ({len(firebase_routes)}):")
        for route in firebase_routes:
            print(f"  ✓ {route}")
    else:
        print("\n[WARN] No Firebase routes found in registered routes!")
        print("       This indicates the auth blueprint may not be registered correctly.")
except Exception as blueprint_error:
    print(f"[ERROR] Could not register blueprints: {blueprint_error}")
    import traceback
    traceback.print_exc()

if __name__ == '__main__':
    # When running with 'python app.py'
    try:
        # Initialize database before running (outside Flask context)
        # Call init_pg_schema directly - it doesn't require Flask request context
        print("🔄 Initializing database schema...")
        init_pg_schema()
        print("✅ Database schema initialized successfully")
    except Exception as e:
        print(f"⚠️ Warning: Database initialization failed: {e}")
        # Don't raise - allow app to start even if schema init fails
        # Schema will be initialized on first request via init_db() if needed
        import traceback
        traceback.print_exc()
    app.run(debug=True, host='0.0.0.0', port=8000)
