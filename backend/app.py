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
from psycopg2 import errors
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

# Optional import for risk checks - provide fallback if module doesn't exist
try:
    from api.utils.risk_checks import run_prechecks, combine_assessments
except ImportError:
    # Fallback implementations if risk_checks module doesn't exist
    def run_prechecks(proposal_dict):
        """Fallback: Return empty precheck summary if module not available"""
        return {
            "block_release": False,
            "risk_score": 0,
            "issues": [],
            "summary": "Risk checks module not available"
        }
    
    def combine_assessments(precheck_summary, ai_result):
        """Fallback: Return AI result if available, otherwise precheck"""
        if ai_result:
            return ai_result
        return precheck_summary

from api.utils.email import send_email, get_logo_html
from api.utils.decorators import token_required as api_token_required

# Load environment variables
load_dotenv()

app = Flask(__name__)
# Configure CORS to allow requests from frontend
# Note: When supports_credentials=True, cannot use '*' - must specify exact origins
# We'll handle Netlify subdomains dynamically in the before_request handler
allowed_origins_list = [
    'http://localhost:8081',
    'http://localhost:8080',
    'http://127.0.0.1:8081',
    'http://localhost:3000',
    'https://sowbuilders.netlify.app',  # Fixed typo: was sowbuilder, now sowbuilders
]

CORS(app, 
     supports_credentials=True,
     origins=allowed_origins_list,
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

# ============================================================================
# REGISTER BLUEPRINTS (Refactored routes)
# ============================================================================
# Import and register blueprints for refactored routes
try:
    from api.routes import auth, clients, onboarding, proposals
    app.register_blueprint(auth.bp)
    app.register_blueprint(clients.bp)
    app.register_blueprint(onboarding.bp)
    app.register_blueprint(proposals.bp)
    print("[OK] Registered refactored blueprints: auth, clients, onboarding, proposals")
except Exception as e:
    print(f"[WARN] Could not register blueprints: {e}")
    print("[INFO] Falling back to legacy routes in app.py")
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
        change_description TEXT DEFAULT 'Version created',
        FOREIGN KEY (proposal_id) REFERENCES proposals(id),
        FOREIGN KEY (created_by) REFERENCES users(id)
        )''')
        
        # Add change_description column if it doesn't exist (for existing tables)
        cursor.execute('''
            DO $$ 
            BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM information_schema.columns 
                    WHERE table_name = 'proposal_versions' 
                    AND column_name = 'change_description'
                ) THEN
                    ALTER TABLE proposal_versions 
                    ADD COLUMN change_description TEXT DEFAULT 'Version created';
                END IF;
            END $$;
        ''')
        
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

        # Ensure proposal_signatures.id sequence is in sync with existing rows
        cursor.execute('''
            SELECT setval(
                pg_get_serial_sequence('proposal_signatures', 'id'),
                COALESCE((SELECT MAX(id) FROM proposal_signatures), 0) + 1,
                false
            )
        ''')
        
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

# Handle CORS for Netlify subdomains not in the allowed_origins_list
# Flask-CORS already handles origins in allowed_origins_list, so we only handle others
@app.after_request
def handle_cors_after_request(response):
    """Add CORS headers for Netlify subdomains that aren't in the static allowed_origins_list"""
    origin = request.headers.get('Origin')
    
    # Only handle Netlify subdomains that are NOT in the allowed_origins_list
    # Flask-CORS will handle the ones that are in the list
    if origin and origin.endswith('.netlify.app') and origin not in allowed_origins_list:
        # This is a Netlify subdomain not in our list, so we need to add headers
        # But first check if Flask-CORS already set them (shouldn't happen, but be safe)
        if 'Access-Control-Allow-Origin' not in response.headers:
            response.headers['Access-Control-Allow-Origin'] = origin
            response.headers['Access-Control-Allow-Credentials'] = 'true'
            response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, Collab-Token'
            response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, PATCH, OPTIONS'
    
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

def get_approvers():
    """
    Get all users with approver/CEO role
    
    Returns:
        List of dicts with id, username, email, first_name, last_name
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            # Get users with approver, CEO, or admin role
            cursor.execute("""
                SELECT id, username, email, first_name, last_name, role
                FROM users 
                WHERE role IN ('approver', 'CEO', 'admin', 'reviewer_approver')
                AND email IS NOT NULL
            """)
            approvers = cursor.fetchall()
            return [dict(approver) for approver in approvers]
    except Exception as e:
        print(f"⚠️ Failed to get approvers: {e}")
        return []

def notify_proposal_collaborators(proposal_id, notification_type, title, message, exclude_user_id=None, metadata=None):
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
        
        if not all([integration_key, user_id]):
            raise Exception("DocuSign credentials not configured")
        
        # Try to get private key from environment variable first (for Render/cloud deployments)
        private_key = os.getenv('DOCUSIGN_PRIVATE_KEY')
        
        # If not in env var, try to read from file
        if not private_key:
            private_key_path = os.getenv('DOCUSIGN_PRIVATE_KEY_PATH', './docusign_private.key')
            if not os.path.exists(private_key_path):
                raise Exception(f"DocuSign private key not found. Set DOCUSIGN_PRIVATE_KEY env var or DOCUSIGN_PRIVATE_KEY_PATH to a valid file path.")
            with open(private_key_path, 'r') as key_file:
                private_key = key_file.read()
        
        # Handle newlines in environment variable (Render may escape them)
        if private_key:
            private_key = private_key.replace('\\n', '\n')
        
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
    frontend_url = os.getenv('FRONTEND_URL') or os.getenv('REACT_APP_API_URL') or 'https://sowbuilders.netlify.app'
    frontend_url = frontend_url.rstrip('/').replace('/api', '').replace('/backend', '')
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
    return api_token_required(f)

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

# Content library endpoints

@app.get("/content")
@api_token_required
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
@api_token_required
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
@api_token_required
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
@api_token_required
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
@api_token_required
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
@api_token_required
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

def _resolve_user_id(cursor, username: str):
    """
    Normalize any username/email/string identifier into the numeric user ID.
    Supports:
      - username stored in users table
      - email stored in users table
      - numeric username strings (legacy)
    """
    try:
        cursor.execute(
            "SELECT id FROM users WHERE username = %s OR email = %s",
            (username, username),
        )
        result = cursor.fetchone()
        if result:
            return result[0]
    except Exception as lookup_err:
        print(f"⚠️ Error resolving user id for {username}: {lookup_err}")
        traceback.print_exc()

    if isinstance(username, str) and username.isdigit():
        print(f"⚠️ Falling back to numeric conversion for username '{username}'")
        return int(username)

    return None


# ============================================================================
# PROPOSAL ROUTES - PARTIALLY MIGRATED
# ============================================================================
# GET /proposals has been migrated to api/routes/proposals.py
# All other proposal routes below still need to be migrated
# TODO: Extract remaining proposal routes to api/routes/proposals.py

@app.post("/proposals")
@token_required
def create_proposal(username):
    """Create a new proposal - TODO: Migrate to api/routes/proposals.py"""
    try:
        data = request.get_json()
        print(f"📝 Creating proposal for user {username}: {data.get('title', 'Untitled')}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            user_id = _resolve_user_id(cursor, username)
            if not user_id:
                return {'detail': f"User '{username}' not found"}, 400

            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'proposals'
            """)
            proposal_columns = {row[0] for row in cursor.fetchall()}

            # Check if client_id column exists, if not add it
            if 'client_id' not in proposal_columns:
                try:
                    cursor.execute("""
                        ALTER TABLE proposals 
                        ADD COLUMN IF NOT EXISTS client_id INTEGER
                    """)
                    conn.commit()
                    print(f"[INFO] Added client_id column to proposals table")
                    proposal_columns.add('client_id')
                except Exception as e:
                    print(f"[WARN] Could not add client_id column: {e}")

            # If client_id is provided, fetch client details and auto-fill
            client_id = data.get('client_id')
            client_name = data.get('client_name') or data.get('client') or 'Unknown Client'
            client_email = data.get('client_email')
            
            if client_id:
                try:
                    cursor.execute("""
                        SELECT id, company_name, contact_person, email
                        FROM clients
                        WHERE id = %s AND created_by = %s
                    """, (client_id, user_id))
                    client = cursor.fetchone()
                    
                    if client:
                        # Auto-fill client details from client record
                        if not client_name or client_name == 'Unknown Client':
                            client_name = client[1] or client[2] or 'Unknown Client'  # company_name or contact_person
                        if not client_email:
                            client_email = client[3]  # email
                        print(f"[INFO] Auto-filled client details from client_id {client_id}: {client_name}, {client_email}")
                    else:
                        print(f"[WARN] Client ID {client_id} not found or not owned by user {username}")
                        client_id = None  # Don't use invalid client_id
                except Exception as e:
                    print(f"[WARN] Error fetching client details: {e}")
                    client_id = None  # Don't use client_id if there's an error

            insert_columns = []
            values = []

            owner_column = None
            if 'owner_id' in proposal_columns:
                owner_column = 'owner_id'
            elif 'user_id' in proposal_columns:
                owner_column = 'user_id'
            else:
                return {'detail': "proposals table missing owner_id/user_id column"}, 500

            insert_columns.append(owner_column)
            values.append(user_id)

            field_map = {
                'title': data.get('title', 'Untitled Document'),
                'content': data.get('content'),
                'status': data.get('status', 'draft'),
                'client_name': client_name,
                'client': data.get('client') or client_name,  # Use client_name if client not provided
                'client_email': client_email,  # Use auto-filled email if available
                'budget': data.get('budget'),
                'timeline_days': data.get('timeline_days'),
                'sections': json.dumps(data.get('sections') or {}) if 'sections' in proposal_columns else None,
                'template_key': data.get('template_key'),
                'pdf_url': data.get('pdf_url'),
                'client_can_edit': data.get('client_can_edit'),
                'client_id': client_id,  # Use validated client_id
                'content_html': data.get('content_html'),
            }

            for column, value in field_map.items():
                if column in proposal_columns and value is not None:
                    insert_columns.append(column)
                    values.append(value)

            placeholders = ', '.join(['%s'] * len(values))

            return_fields = [
                "id",
                owner_column,
                "title",
                "content",
                "status",
            ]

            if 'client_name' in proposal_columns:
                return_fields.append("client_name")
            else:
                return_fields.append("NULL::text AS client_name")

            if 'client' in proposal_columns:
                return_fields.append("client")
            elif 'client_name' in proposal_columns:
                return_fields.append("client_name AS client")
            else:
                return_fields.append("NULL::text AS client")

            if 'client_email' in proposal_columns:
                return_fields.append("client_email")
            else:
                return_fields.append("NULL::text AS client_email")
            
            if 'client_id' in proposal_columns:
                return_fields.append("client_id")
            else:
                return_fields.append("NULL::integer AS client_id")

            if 'budget' in proposal_columns:
                return_fields.append("budget")
            else:
                return_fields.append("NULL::numeric AS budget")

            if 'timeline_days' in proposal_columns:
                return_fields.append("timeline_days")
            else:
                return_fields.append("NULL::integer AS timeline_days")

            if 'created_at' in proposal_columns:
                return_fields.append("created_at")
            else:
                return_fields.append("NOW() AS created_at")

            if 'updated_at' in proposal_columns:
                return_fields.append("updated_at")
            else:
                return_fields.append("NOW() AS updated_at")

            if 'sections' in proposal_columns:
                return_fields.append("sections")
            else:
                return_fields.append("NULL::text AS sections")

            if 'template_key' in proposal_columns:
                return_fields.append("template_key")
            else:
                return_fields.append("NULL::text AS template_key")

            if 'pdf_url' in proposal_columns:
                return_fields.append("pdf_url")
            else:
                return_fields.append("NULL::text AS pdf_url")

            insert_sql = f"""
                INSERT INTO proposals ({', '.join(insert_columns)})
                VALUES ({placeholders})
                RETURNING {', '.join(return_fields)}
            """

            try:
                cursor.execute(insert_sql, tuple(values))
            except errors.UniqueViolation as seq_error:
                # Handle out-of-sync proposals.id sequence by resetting it and retrying once
                print(f"⚠️ Sequence issue detected while inserting into proposals: {seq_error}")
                try:
                    conn.rollback()
                except Exception as rollback_error:
                    print(f"[WARN] Error during rollback after sequence issue: {rollback_error}")

                try:
                    cursor = conn.cursor()
                    cursor.execute(
                        """
                        SELECT setval(
                            pg_get_serial_sequence('proposals', 'id'),
                            COALESCE((SELECT MAX(id) FROM proposals), 1),
                            true
                        )
                        """
                    )
                    conn.commit()
                    print("✅ Reset proposals.id sequence based on MAX(id)")

                    cursor = conn.cursor()
                    cursor.execute(insert_sql, tuple(values))
                except Exception as reset_error:
                    print(f"❌ Failed to reset proposals sequence and re-insert: {reset_error}")
                    raise

            result_row = cursor.fetchone()
            if not result_row:
                return {'detail': 'Failed to create proposal'}, 500

            # Convert row tuple to dict keyed by column names for easier access
            column_names = [desc[0] for desc in cursor.description] if cursor.description else []
            result = dict(zip(column_names, result_row)) if column_names else {}

            proposal_id = result.get('id')
            
            # If client_id was provided and valid, create link in client_proposals table
            if client_id and proposal_id:
                try:
                    # Check if client_proposals table exists
                    cursor.execute("""
                        SELECT EXISTS (
                            SELECT FROM information_schema.tables 
                            WHERE table_name = 'client_proposals'
                        )
                    """)
                    table_exists = cursor.fetchone()[0]
                    
                    if table_exists:
                        cursor.execute("""
                            INSERT INTO client_proposals (client_id, proposal_id, relationship_type, linked_by)
                            VALUES (%s, %s, 'primary', %s)
                            ON CONFLICT (client_id, proposal_id) DO NOTHING
                        """, (client_id, proposal_id, user_id))
                        print(f"[INFO] Linked proposal {proposal_id} to client {client_id}")
                    else:
                        print(f"[WARN] client_proposals table does not exist, skipping link creation")
                except Exception as e:
                    print(f"[WARN] Could not create client-proposal link: {e}")
                    # Don't fail proposal creation if link fails
            
            conn.commit()
            
            section_data = {}
            if result.get('sections'):
                try:
                    if isinstance(result['sections'], str):
                        section_data = json.loads(result['sections'])
                    else:
                        section_data = result['sections']
                except json.JSONDecodeError:
                    section_data = {}

            owner_value = result.get(owner_column)
            proposal = {
                'id': result.get('id'),
                'owner_id': str(owner_value) if owner_value is not None else None,
                'user_id': str(owner_value) if owner_value is not None else None,
                'title': result.get('title'),
                'content': result.get('content'),
                'status': result.get('status'),
                'client_name': result.get('client_name') or '',
                'client': result.get('client') or '',
                'client_email': result.get('client_email') or '',
                'client_id': result.get('client_id'),
                'budget': float(result['budget']) if result.get('budget') is not None else None,
                'timeline_days': result.get('timeline_days'),
                'created_at': result['created_at'].isoformat() if result.get('created_at') else None,
                'updated_at': result['updated_at'].isoformat() if result.get('updated_at') else None,
                'updatedAt': result['updated_at'].isoformat() if result.get('updated_at') else None,
                'sections': section_data,
                'template_key': result.get('template_key'),
                'pdf_url': result.get('pdf_url'),
            }
            
            print(f"✅ Proposal created successfully with ID: {proposal_id}")
            
            # Send email notifications and create in-app notifications
            try:
                proposal_id = result.get('id')
                proposal_title = result.get('title', 'Untitled Document')
                client_name = result.get('client_name') or 'Unknown Client'
                
                # Get creator's email
                cursor.execute("SELECT id, email, full_name FROM users WHERE id = %s", (user_id,))
                creator_row = cursor.fetchone()
                creator = None
                if creator_row:
                    creator_columns = [desc[0] for desc in cursor.description] if cursor.description else []
                    creator = dict(zip(creator_columns, creator_row)) if creator_columns else {}

                creator_email = creator.get('email') if creator else None
                creator_name = creator.get('full_name') if creator else username
                
                # Send email to creator
                if creator_email:
                    try:
                        email_body = f"""
                        <html>
                        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                                <h2 style="color: #2ECC71;">✅ Proposal Created Successfully</h2>
                                <p>Hello {creator_name},</p>
                                <p>Your proposal <strong>"{proposal_title}"</strong> for <strong>{client_name}</strong> has been created successfully.</p>
                                <p><strong>Status:</strong> Draft</p>
                                <p>You can now edit and prepare your proposal before sending it for approval.</p>
                                <p style="margin-top: 30px; color: #7F8C8D; font-size: 12px;">
                                    This is an automated notification from Khonology.
                                </p>
                            </div>
                        </body>
                        </html>
                        """
                        send_email(
                            to_email=creator_email,
                            subject=f"Proposal Created: {proposal_title}",
                            html_content=email_body
                        )
                        print(f"[EMAIL] ✅ Notification sent to creator: {creator_email}")
                    except Exception as email_error:
                        print(f"[EMAIL] ⚠️ Failed to send email to creator: {email_error}")
                
                # Create in-app notification for creator
                create_notification(
                    user_id=user_id,
                    notification_type='proposal_created',
                    title='Proposal Created',
                    message=f'Your proposal "{proposal_title}" has been created successfully.',
                    proposal_id=proposal_id
                )
                
                # Get approvers and notify them
                approvers = get_approvers()
                for approver in approvers:
                    approver_id = approver['id']
                    approver_email = approver.get('email')
                    approver_name = approver.get('full_name') or approver.get('username', 'Approver')
                    
                    # Send email to approver
                    if approver_email:
                        try:
                            email_body = f"""
                            <html>
                            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                                    <h2 style="color: #3498DB;">📋 New Proposal Created</h2>
                                    <p>Hello {approver_name},</p>
                                    <p>A new proposal has been created by <strong>{creator_name}</strong>:</p>
                                    <div style="background-color: #F8F9FA; padding: 15px; border-radius: 5px; margin: 20px 0;">
                                        <p><strong>Title:</strong> {proposal_title}</p>
                                        <p><strong>Client:</strong> {client_name}</p>
                                        <p><strong>Status:</strong> Draft</p>
                                    </div>
                                    <p>The proposal is currently in draft status. You will be notified when it's ready for your review.</p>
                                    <p style="margin-top: 30px; color: #7F8C8D; font-size: 12px;">
                                        This is an automated notification from Khonology.
                                    </p>
                                </div>
                            </body>
                            </html>
                            """
                            send_email(
                                to_email=approver_email,
                                subject=f"New Proposal Created: {proposal_title}",
                                html_content=email_body
                            )
                            print(f"[EMAIL] ✅ Notification sent to approver: {approver_email}")
                        except Exception as email_error:
                            print(f"[EMAIL] ⚠️ Failed to send email to approver {approver_email}: {email_error}")
                    
                    # Create in-app notification for approver
                    create_notification(
                        user_id=approver_id,
                        notification_type='new_proposal_created',
                        title='New Proposal Created',
                        message=f'"{proposal_title}" for {client_name} has been created by {creator_name}.',
                        proposal_id=proposal_id
                    )
                
            except Exception as notif_error:
                print(f"[WARN] Failed to send notifications for proposal {result.get('id')}: {notif_error}")
                import traceback
                traceback.print_exc()
                # Don't fail the proposal creation if notifications fail
            
            return proposal, 201
    except Exception as e:
        print(f"❌ Error creating proposal: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

# PUT, DELETE, GET by ID routes migrated to api/routes/proposals.py

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

            # Get current user's ID from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404

            user_id = user[0]

            # Check if proposal exists and belongs to user (schema uses owner_id, not user_id)
            cursor.execute(
                'SELECT id, title, status FROM proposals WHERE id = %s AND owner_id = %s',
                (proposal_id, user_id)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            current_status = proposal[2]
            if current_status != 'draft':
                return {'detail': f'Proposal is already {current_status}'}, 400
            
            # Get proposal details (Render/Postgres schema uses "client" column, not client_name)
            cursor.execute(
                '''SELECT id, title, client, client_email, owner_id 
                   FROM proposals WHERE id = %s''',
                (proposal_id,)
            )
            proposal_details = cursor.fetchone()
            if not proposal_details:
                return {'detail': 'Proposal not found'}, 404
            
            proposal_id_db, title, client_name, client_email, creator_user_id = proposal_details
            
            # Update status to Pending CEO Approval
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() 
                   WHERE id = %s RETURNING status''',
                ('Pending CEO Approval', proposal_id)
            )
            result = cursor.fetchone()
            conn.commit()
            
            # Send email notifications and create in-app notifications
            try:
                # Get creator's details
                cursor.execute("SELECT id, email, full_name, username FROM users WHERE id = %s", (creator_user_id,))
                creator = cursor.fetchone()
                creator_email = creator[1] if creator and creator[1] else None
                creator_name = creator[2] if creator and creator[2] else (creator[3] if creator else username)
                
                # Send email to creator (confirmation)
                if creator_email:
                    try:
                        email_body = f"""
                        <html>
                        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                                <h2 style="color: #F39C12;">📤 Proposal Sent for Approval</h2>
                                <p>Hello {creator_name},</p>
                                <p>Your proposal <strong>"{title}"</strong> for <strong>{client_name or 'Client'}</strong> has been successfully sent for CEO approval.</p>
                                <div style="background-color: #FFF3CD; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #F39C12;">
                                    <p><strong>Status:</strong> Pending CEO Approval</p>
                                    <p>The proposal is now under review. You will be notified once a decision has been made.</p>
                                </div>
                                <p style="margin-top: 30px; color: #7F8C8D; font-size: 12px;">
                                    This is an automated notification from Khonology.
                                </p>
                            </div>
                        </body>
                        </html>
                        """
                        email_sent = send_email(
                            to_email=creator_email,
                            subject=f"Proposal Sent for Approval: {title}",
                            html_content=email_body
                        )
                        if email_sent:
                            print(f"[EMAIL] ✅ Confirmation sent to creator: {creator_email}")
                        else:
                            print(f"[EMAIL] ❌ Failed to send email to creator: {creator_email}")
                    except Exception as email_error:
                        print(f"[EMAIL] ❌ Exception sending email to creator: {email_error}")
                        import traceback
                        traceback.print_exc()
                
                # Create in-app notification for creator
                create_notification(
                    user_id=creator_user_id,
                    notification_type='proposal_sent_for_approval',
                    title='Proposal Sent for Approval',
                    message=f'Your proposal "{title}" has been sent for CEO approval.',
                    proposal_id=proposal_id
                )
                
                # Get approvers and notify them
                approvers = get_approvers()
                for approver in approvers:
                    approver_id = approver['id']
                    approver_email = approver.get('email')
                    approver_name = approver.get('full_name') or approver.get('username', 'Approver')
                    
                    # Send email to approver
                    if approver_email:
                        try:
                            proposal_url = f"{os.getenv('FRONTEND_URL', 'http://localhost:8081')}/#/approver_dashboard"
                            email_body = f"""
                            <html>
                            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                                    <h2 style="color: #E74C3C;">🔔 Action Required: Proposal Pending Approval</h2>
                                    <p>Hello {approver_name},</p>
                                    <p>A proposal requires your review and approval:</p>
                                    <div style="background-color: #F8F9FA; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #E74C3C;">
                                        <p><strong>Title:</strong> {title}</p>
                                        <p><strong>Client:</strong> {client_name or 'Not specified'}</p>
                                        <p><strong>Created by:</strong> {creator_name}</p>
                                        <p><strong>Status:</strong> <span style="color: #E74C3C; font-weight: bold;">Pending CEO Approval</span></p>
                                    </div>
                                    <div style="text-align: center; margin: 30px 0;">
                                        <a href="{proposal_url}" 
                                           style="background-color: #E74C3C; color: white; padding: 15px 30px; 
                                                  text-decoration: none; border-radius: 5px; display: inline-block;
                                                  font-weight: bold;">
                                            Review Proposal
                                        </a>
                                    </div>
                                    <p style="margin-top: 30px; color: #7F8C8D; font-size: 12px;">
                                        This is an automated notification from Khonology.
                                    </p>
                                </div>
                            </body>
                            </html>
                            """
                            email_sent = send_email(
                                to_email=approver_email,
                                subject=f"Action Required: Review Proposal - {title}",
                                html_content=email_body
                            )
                            if email_sent:
                                print(f"[EMAIL] ✅ Notification sent to approver: {approver_email}")
                            else:
                                print(f"[EMAIL] ❌ Failed to send email to approver: {approver_email}")
                        except Exception as email_error:
                            print(f"[EMAIL] ❌ Exception sending email to approver {approver_email}: {email_error}")
                            import traceback
                            traceback.print_exc()
                    
                    # Create in-app notification for approver
                    create_notification(
                        user_id=approver_id,
                        notification_type='proposal_pending_approval',
                        title='Proposal Pending Approval',
                        message=f'"{title}" for {client_name or "Client"} requires your review and approval.',
                        proposal_id=proposal_id
                    )
                
            except Exception as notif_error:
                print(f"[WARN] Failed to send notifications for proposal {proposal_id}: {notif_error}")
                import traceback
                traceback.print_exc()
                # Don't fail the request if notifications fail
            
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

@app.post("/legacy/proposals/<int:proposal_id>/approve")
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
                '''SELECT id, title, client, client_email, owner_id 
                   FROM proposals WHERE id = %s''',
                (proposal_id,)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            proposal_id, title, client_name, client_email, creator_user_id = proposal
            
            # Update status to Approved (not Sent to Client - that happens when approver sends to client)
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() 
                   WHERE id = %s RETURNING status''',
                ('Approved', proposal_id)
            )
            result = cursor.fetchone()
            conn.commit()
            
            if result:
                print(f"[SUCCESS] Proposal {proposal_id} '{title}' approved")
                
                # Get approver's name
                cursor.execute('SELECT id, full_name, username FROM users WHERE username = %s', (username,))
                approver = cursor.fetchone()
                approver_name = approver[1] if approver and approver[1] else (approver[2] if approver else username)
                
                # Get creator's details
                cursor.execute("SELECT id, email, full_name, username FROM users WHERE id = %s", (creator_user_id,))
                creator = cursor.fetchone()
                creator_email = creator[1] if creator and creator[1] else None
                creator_name = creator[2] if creator and creator[2] else (creator[3] if creator else 'Creator')
                
                # Send email to creator (notification of approval)
                if creator_email:
                    try:
                        email_body = f"""
                        <html>
                        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                            <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                                <h2 style="color: #2ECC71;">✅ Proposal Approved</h2>
                                <p>Hello {creator_name},</p>
                                <p>Great news! Your proposal <strong>"{title}"</strong> for <strong>{client_name or 'Client'}</strong> has been approved by <strong>{approver_name}</strong>.</p>
                                <div style="background-color: #D4EDDA; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #2ECC71;">
                                    <p><strong>Status:</strong> <span style="color: #2ECC71; font-weight: bold;">Approved</span></p>
                                    <p>The proposal is now ready to be sent to the client. The approver will send the encrypted email with secure link to the client.</p>
                                </div>
                                {f'<p><strong>Approver Comments:</strong> {comments}</p>' if comments else ''}
                                <p style="margin-top: 30px; color: #7F8C8D; font-size: 12px;">
                                    This is an automated notification from Khonology.
                                </p>
                            </div>
                        </body>
                        </html>
                        """
                        email_sent = send_email(
                            to_email=creator_email,
                            subject=f"Proposal Approved: {title}",
                            html_content=email_body
                        )
                        if email_sent:
                            print(f"[EMAIL] ✅ Approval notification sent to creator: {creator_email}")
                        else:
                            print(f"[EMAIL] ❌ Failed to send email to creator: {creator_email}")
                    except Exception as email_error:
                        print(f"[EMAIL] ❌ Exception sending email to creator: {email_error}")
                        import traceback
                        traceback.print_exc()
                
                # Create in-app notification for creator
                create_notification(
                    user_id=creator_user_id,
                    notification_type='proposal_approved',
                    title='Proposal Approved',
                    message=f'Your proposal "{title}" has been approved by {approver_name}.',
                    proposal_id=proposal_id,
                    metadata={'approver': approver_name, 'comments': comments} if comments else {'approver': approver_name}
                )
                
                return {
                    'detail': 'Proposal approved successfully',
                    'status': result[0],
                    'message': 'The proposal has been approved. You can now send it to the client using the "Send to Client" action.'
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

@app.post("/api/proposals/<int:proposal_id>/send-to-client")
@token_required
def send_to_client(username, proposal_id):
    """Send encrypted email with secure link to client (for approvers only)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get current user's role
            cursor.execute('SELECT id, role, full_name FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id, user_role, full_name = user
            approver_name = full_name if full_name else username
            
            # Check if user is an approver
            if user_role not in ('approver', 'CEO', 'admin', 'reviewer_approver'):
                return {'detail': 'Only approvers can send proposals to clients'}, 403
            
            # Get proposal details
            cursor.execute(
                '''SELECT id, title, client, client_email, owner_id, status 
                   FROM proposals WHERE id = %s''',
                (proposal_id,)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            proposal_id_db, title, client_name, client_email, creator_user_id, current_status = proposal
            
            # Check if proposal is approved
            if current_status not in ('Approved', 'Pending CEO Approval'):
                return {'detail': f'Proposal must be approved before sending to client. Current status: {current_status}'}, 400
            
            # Check if client email is provided
            if not client_email or not client_email.strip():
                return {'detail': 'Client email is required to send the proposal'}, 400
            
            # Generate secure access token for client onboarding
            access_token = secrets.token_urlsafe(32)
            expires_at = datetime.now(timezone.utc) + timedelta(days=90)  # 90 days for client access
            
            # Create client onboarding invitation (not collaboration invitation)
            # This will allow the client to access the proposal through onboarding
            cursor.execute("""
                INSERT INTO client_onboarding_invitations 
                (access_token, invited_email, invited_by, expected_company, status, expires_at)
                VALUES (%s, %s, %s, %s, 'pending', %s)
                ON CONFLICT (access_token) 
                DO UPDATE SET access_token = EXCLUDED.access_token, expires_at = EXCLUDED.expires_at
                RETURNING id, access_token
            """, (access_token, client_email, user_id, client_name, expires_at))
            
            result = cursor.fetchone()
            if not result:
                return {'detail': 'Failed to create client invitation'}, 500
            
            invitation_id, onboarding_token = result
            conn.commit()
            
            # Generate onboarding link (using hash-based routing)
            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
            onboarding_url = f"{frontend_url}/#/onboard/{onboarding_token}"
            
            # Send email with onboarding link to client
            try:
                logo_html = get_logo_html()
                html_content = f"""
                <html>
                <head>
                    <style>
                        body {{ font-family: 'Poppins', Arial, sans-serif; background-color: #000000; padding: 40px 20px; }}
                        .container {{ max-width: 600px; margin: 0 auto; background-color: #1A1A1A; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3); padding: 40px; }}
                        .security-box {{ background-color: #2A2A2A; border: 2px solid #E9293A; border-radius: 12px; padding: 24px; margin: 30px 0; }}
                        .token-box {{ background-color: #111111; border: 1px solid #333333; border-radius: 8px; padding: 16px; text-align: center; margin: 20px 0; font-family: 'Courier New', monospace; font-size: 14px; color: #E9293A; word-break: break-all; }}
                        .footer {{ color: #666; font-size: 12px; text-align: center; margin-top: 30px; }}
                    </style>
                </head>
                <body>
                    <div class="container">
                        {logo_html}
                        <h1 style="color: #FFFFFF; text-align: center; margin-bottom: 20px;">🔒 Secure Proposal Access</h1>
                        <p style="color: #B3B3B3; font-size: 16px; line-height: 1.6;">
                            Hello! Your proposal "<strong style="color: #FFFFFF;">{title}</strong>" is ready for secure access.
                        </p>
                        
                        <div class="security-box">
                            <p style="margin: 0 0 15px 0; font-family: 'Poppins', Arial, sans-serif; font-size: 14px; font-weight: 600; color: #E9293A; text-transform: uppercase; letter-spacing: 0.5px;">
                                🔐 Security Features
                            </p>
                            <ul style="margin: 0; padding-left: 20px; color: #B3B3B3; font-size: 14px; line-height: 1.8;">
                                <li>End-to-end encryption (AES-256)</li>
                                <li>Secure token-based access</li>
                                <li>Time-limited access link</li>
                                <li>No password required (token-based)</li>
                            </ul>
                        </div>
                        
                        <p style="color: #B3B3B3; font-size: 16px; line-height: 1.6; text-align: center; margin: 30px 0 20px 0;">
                            Click the button below to access your proposal:
                        </p>
                        
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{onboarding_url}" style="display: inline-block; padding: 16px 40px; font-family: 'Poppins', Arial, sans-serif; font-size: 16px; font-weight: 600; color: #FFFFFF; text-decoration: none; border-radius: 8px; background: linear-gradient(135deg, #E9293A 0%, #780A01 100%); box-shadow: 0 4px 20px rgba(233, 41, 58, 0.4);">
                                Access Proposal →
                            </a>
                        </div>
                        
                        <p style="color: #B3B3B3; font-size: 14px; line-height: 1.6; margin-top: 20px;">
                            Or copy and paste this secure link into your browser:
                        </p>
                        <p style="color: #E9293A; font-size: 11px; line-height: 1.5; word-break: break-all; text-align: center; background-color: #2A2A2A; padding: 12px; border-radius: 6px; margin: 10px 0 30px 0;">
                            {onboarding_url}
                        </p>
                        
                        <div class="footer">
                            <p>© 2025 Khonology. All rights reserved.</p>
                            <p style="margin-top: 8px; color: #555;">This is a secure, encrypted message. Please do not reply to this email.</p>
                        </div>
                    </div>
                </body>
                </html>
                """
                
                email_sent = send_email(
                    to_email=client_email,
                    subject=f"Secure Access: {title}",
                    html_content=html_content
                )
                
                if not email_sent:
                    print(f"[EMAIL] ❌ Failed to send email to client: {client_email}")
                    return {'detail': 'Failed to send email to client. Please check email configuration.'}, 500
                
                print(f"[EMAIL] ✅ Encrypted email sent to client: {client_email}")
            except Exception as email_error:
                print(f"[EMAIL] ❌ Failed to send email to client: {email_error}")
                import traceback
                traceback.print_exc()
                return {'detail': f'Failed to send email: {str(email_error)}'}, 500
            
            # Update status to Sent to Client
            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() 
                   WHERE id = %s RETURNING status''',
                ('Sent to Client', proposal_id)
            )
            result = cursor.fetchone()
            conn.commit()
            
            # Get creator's details for notification
            cursor.execute("SELECT id, email, full_name, username FROM users WHERE id = %s", (creator_user_id,))
            creator = cursor.fetchone()
            creator_email = creator[1] if creator and creator[1] else None
            creator_name = creator[2] if creator and creator[2] else (creator[3] if creator else 'Creator')
            
            # Send email to creator (notification that proposal was sent to client)
            if creator_email:
                try:
                    email_body = f"""
                    <html>
                    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                            <h2 style="color: #3498DB;">📧 Proposal Sent to Client</h2>
                            <p>Hello {creator_name},</p>
                            <p>Your proposal <strong>"{title}"</strong> for <strong>{client_name or 'Client'}</strong> has been sent to the client by <strong>{approver_name}</strong>.</p>
                            <div style="background-color: #E8F4F8; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #3498DB;">
                                <p><strong>Status:</strong> <span style="color: #3498DB; font-weight: bold;">Sent to Client</span></p>
                                <p><strong>Client Email:</strong> {client_email}</p>
                                <p>The client has received an encrypted email with a secure link to access the proposal.</p>
                            </div>
                            <p style="margin-top: 30px; color: #7F8C8D; font-size: 12px;">
                                This is an automated notification from Khonology.
                            </p>
                        </div>
                    </body>
                    </html>
                    """
                    email_sent = send_email(
                        to_email=creator_email,
                        subject=f"Proposal Sent to Client: {title}",
                        html_content=email_body
                    )
                    if email_sent:
                        print(f"[EMAIL] ✅ Notification sent to creator: {creator_email}")
                    else:
                        print(f"[EMAIL] ❌ Failed to send email to creator: {creator_email}")
                except Exception as email_error:
                    print(f"[EMAIL] ❌ Exception sending email to creator: {email_error}")
                    import traceback
                    traceback.print_exc()
            
            # Create in-app notification for creator
            create_notification(
                user_id=creator_user_id,
                notification_type='proposal_sent_to_client',
                title='Proposal Sent to Client',
                message=f'Your proposal "{title}" has been sent to {client_name or "the client"} by {approver_name}.',
                proposal_id=proposal_id
            )
            
            return {
                'detail': 'Proposal sent to client successfully',
                'status': result[0],
                'email_sent': True,
                'client_email': client_email
            }, 200
                
    except Exception as e:
        print(f"❌ Error sending proposal to client: {e}")
        import traceback
        traceback.print_exc()
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
    """Return proposals that are pending approval (backend used by /approvals)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at
                   FROM proposals
                   WHERE status = 'Submitted'
                   ORDER BY created_at DESC'''
            )
            rows = cursor.fetchall()

        proposals = []
        for row in rows:
            created_at = row[5]
            if hasattr(created_at, "isoformat"):
                created_at = created_at.isoformat()
            elif created_at is not None:
                created_at = str(created_at)

            proposals.append(
                {
                    'id': row[0],
                    'title': row[1],
                    'client': row[2],
                    'owner_id': row[3],
                    'status': row[4],
                    'created_at': created_at,
                }
            )

        return {'proposals': proposals}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@app.get("/proposals/my_proposals")
@token_required
def get_my_proposals(username):
    """Return proposals owned by the current user."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at
                   FROM proposals
                   WHERE owner_id = (SELECT id FROM users WHERE username = %s)
                   ORDER BY created_at DESC''',
                (username,),
            )
            rows = cursor.fetchall()

        proposals = []
        for row in rows:
            created_at = row[5]
            if hasattr(created_at, "isoformat"):
                created_at = created_at.isoformat()
            elif created_at is not None:
                created_at = str(created_at)

            proposals.append(
                {
                    'id': row[0],
                    'title': row[1],
                    'client': row[2],
                    'owner_id': row[3],
                    'status': row[4],
                    'created_at': created_at,
                }
            )

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
            
            # Create comment, handling potential out-of-sync sequence on document_comments.id
            # First, ensure the sequence is properly synchronized
            cursor.execute("""
                SELECT setval(
                    pg_get_serial_sequence('document_comments', 'id'),
                    COALESCE((SELECT MAX(id) FROM document_comments), 1),
                    true
                )
            """)
            conn.commit()
            
            insert_sql = """
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, proposal_id, comment_text, created_by, created_at, 
                          section_index, highlighted_text, status, updated_at
            """

            try:
                cursor.execute(
                    insert_sql,
                    (proposal_id, comment_text, user_id, section_index, highlighted_text, 'open')
                )
            except psycopg2.errors.UniqueViolation as seq_error:
                # Handle out-of-sync document_comments.id sequence by resetting it and retrying once
                print(f"⚠️ Sequence issue detected while inserting into document_comments: {seq_error}")
                try:
                    conn.rollback()
                except Exception as rollback_error:
                    print(f"[WARN] Error during rollback after document_comments sequence issue: {rollback_error}")

                try:
                    # Reset the sequence based on the current MAX(id)
                    cursor = conn.cursor()
                    cursor.execute(
                        """
                        SELECT setval(
                            pg_get_serial_sequence('document_comments', 'id'),
                            COALESCE((SELECT MAX(id) FROM document_comments), 1),
                            true
                        )
                        """
                    )
                    conn.commit()
                    print("✅ Reset document_comments.id sequence based on MAX(id)")

                    # Retry the insert using a RealDictCursor
                    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                    cursor.execute(
                        insert_sql,
                        (proposal_id, comment_text, user_id, section_index, highlighted_text, 'open')
                    )
                except Exception as reset_error:
                    print(f"❌ Failed to reset document_comments sequence and re-insert: {reset_error}")
                    raise

            result = cursor.fetchone()
            conn.commit()
            
            # Log activity
            section_text = f" on section {section_index}" if section_index is not None else ""
            log_activity(
                proposal_id,
                user_id,
                'comment_added',
                f"{user['full_name']} added a comment{section_text}",
                {'comment_id': result['id'], 'section_index': section_index}
            )
            
            # Notify proposal owner and collaborators
            notify_proposal_collaborators(
                proposal_id,
                'comment_added',
                'New Comment',
                f"{user['full_name']} commented{section_text}",
                exclude_user_id=user_id,
                metadata={'comment_id': result['id'], 'section_index': section_index}
            )
            
            # Process @mentions in the comment
            process_mentions(result['id'], comment_text, user_id, proposal_id)
            
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
    except Exception as e:
        print(f"[ERROR] Error in get_comments: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

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
        try:
            from ai_service import ai_service
        except Exception as e:
            return {'detail': f'AI service not available: {str(e)}. Please check OPENROUTER_API_KEY in .env file.'}, 503
        
        # Check if AI service is configured
        if not ai_service.is_configured():
            return {'detail': 'OpenRouter API key not configured. Please set OPENROUTER_API_KEY in your .env file.'}, 503
        
        # Get improvement suggestions
        result = ai_service.improve_content(content, section_type)
        
        # Validate result structure
        if not isinstance(result, dict):
            raise Exception(f"Unexpected result format from AI service: {type(result)}")
        
        if 'improved_version' not in result:
            raise Exception("AI service did not return 'improved_version' in result")
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        improved_text = result.get('improved_version', '') or ''
        response_tokens = len(improved_text.split()) if improved_text else 0
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, prompt_text, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'improve', None, section_type, 
                      response_tokens, response_time_ms))
                conn.commit()
                print(f"📊 AI improve tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
            # Don't fail the request if tracking fails
        
        return result, 200
        
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        print(f"❌ Error improving content: {e}")
        print(f"❌ Traceback: {error_trace}")
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

@app.get("/ai/status")
def ai_status():
    """Check OpenRouter AI service status"""
    try:
        from ai_service import ai_service
        status = ai_service.test_connection()
        return status, 200 if status.get("status") == "connected" else 503
    except Exception as e:
        return {
            "configured": False,
            "status": "error",
            "message": f"AI service initialization failed: {str(e)}"
        }, 503

def record_proposal_risk_audit(
    proposal_id: int,
    triggered_by: str,
    model_used: str,
    precheck_summary: dict,
    ai_summary: dict,
    combined_summary: dict,
) -> None:
    """Persist deterministic + AI assessments for auditing."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO proposal_risk_audits (
                    proposal_id,
                    triggered_by,
                    model_used,
                    precheck_summary,
                    ai_summary,
                    combined_summary,
                    overall_risk_level,
                    risk_score,
                    can_release
                ) VALUES (%s, %s, %s, %s::jsonb, %s::jsonb, %s::jsonb, %s, %s, %s)
            """, (
                proposal_id,
                triggered_by,
                model_used,
                json.dumps(precheck_summary),
                json.dumps(ai_summary),
                json.dumps(combined_summary),
                combined_summary.get("overall_risk_level"),
                combined_summary.get("risk_score"),
                combined_summary.get("can_release"),
            ))
            conn.commit()
            print(f"[OK] Stored risk audit for proposal {proposal_id}")
    except Exception as e:
        print(f"[WARN] Failed to record risk audit: {e}")


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
            
            proposal_dict_raw = dict(proposal)
            proposal_dict = sanitize_for_json(proposal_dict_raw)
            precheck_summary = run_prechecks(proposal_dict)

            analysis_payload = {
                "proposal": proposal_dict,
                "precheck": precheck_summary,
            }

            try:
                ai_result = ai_service.analyze_proposal_risks(analysis_payload)
            except Exception as ai_error:
                print(f"[WARN] AI analysis failed, falling back to precheck only: {ai_error}")
                ai_result = {
                    "overall_risk_level": "unknown",
                    "can_release": not precheck_summary.get("block_release", True),
                    "risk_score": precheck_summary.get("risk_score", 0),
                    "issues": [{
                        "category": "analysis_error",
                        "severity": "medium",
                        "section": "AI Risk Gate",
                        "description": "OpenRouter analysis was unavailable; relying on deterministic checks.",
                        "recommendation": "Retry AI analysis once service is restored."
                    }],
                    "summary": "AI response unavailable",
                    "required_actions": ["Retry AI analysis or proceed after manual review"],
                }

            combined = combine_assessments(precheck_summary, ai_result)

            model_used = getattr(ai_service, "model", "unknown")
            record_proposal_risk_audit(
                proposal_id=proposal_id,
                triggered_by=username,
                model_used=model_used,
                precheck_summary=precheck_summary,
                ai_summary=ai_result,
                combined_summary=combined,
            )

            return combined, 200
        
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
            
            # Check if proposal exists and belongs to user (schema uses owner_id)
            cursor.execute(
                'SELECT title FROM proposals WHERE id = %s AND owner_id = %s',
                (proposal_id, user_id)
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
            
            # Resolve username to numeric user_id
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            owner_row = cursor.fetchone()
            if not owner_row:
                return {'detail': 'User not found'}, 404
            owner_id = owner_row['id'] if isinstance(owner_row, dict) else owner_row[0]

            # Verify ownership using owner_id
            cursor.execute(
                'SELECT id FROM proposals WHERE id = %s AND owner_id = %s',
                (proposal_id, owner_id)
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
            
            # Check if user owns the proposal (match by invited_by or proposal owner_id)
            cursor.execute("""
                SELECT ci.id 
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.id = %s AND (ci.invited_by = %s OR p.owner_id = %s)
            """, (invitation_id, user_id, user_id))
            
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
            
            # For edit/suggest permission, create/get guest user and generate auth token
            auth_token = None
            if invitation['permission_level'] in ['edit', 'suggest']:
                guest_email = invitation['invited_email']
                
                # Create or get guest user
                cursor.execute("""
                    INSERT INTO users (username, email, password_hash, full_name, role)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                    RETURNING id, email
                """, (guest_email, guest_email, '', f'Collaborator ({guest_email})', 'collaborator'))
                
                user = cursor.fetchone()
                conn.commit()
                
                # Generate temporary auth token for this collaborator
                auth_token = generate_token(user['email'])
                print(f"✅ Generated auth token for collaborator: {guest_email} (permission: {invitation['permission_level']})")
            
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
            
            response = {
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
                'can_comment': invitation['permission_level'] in ['comment', 'suggest', 'edit'],
                'can_suggest': invitation['permission_level'] in ['suggest', 'edit'],
                'can_edit': invitation['permission_level'] == 'edit'
            }
            
            # Add auth token for edit/suggest permission
            if auth_token:
                response['auth_token'] = auth_token
            
            return response, 200
            
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

# ============================================================
# CLIENT PORTAL ENDPOINTS (Token-based, no auth required)
# ============================================================

@app.get("/api/client/proposals")
def get_client_proposals():
    """Get all proposals for a client using their access token"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation details to find client email
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            # Check if expired
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            client_email = invitation['invited_email']
            
            # Get all proposals for this client email
            cursor.execute("""
                SELECT p.id, p.title, p.status, p.created_at, p.updated_at, p.client, p.client_email
                FROM proposals p
                WHERE p.client_email = %s
                ORDER BY p.updated_at DESC
            """, (client_email,))
            
            proposals = cursor.fetchall()
            
            return {
                'client_email': client_email,
                'proposals': [dict(p) for p in proposals]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting client proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/client/proposals/<int:proposal_id>")
def get_client_proposal_details(proposal_id):
    """Get detailed proposal information for client"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token and get client email
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Get proposal details (schema uses owner_id as foreign key to users.id)
            cursor.execute("""
                SELECT p.id, p.title, p.content, p.status, p.created_at, p.updated_at,
                       p.client, p.client_email, p.owner_id,
                       u.full_name as owner_name, u.email as owner_email
                FROM proposals p
                LEFT JOIN users u ON p.owner_id = u.id
                WHERE p.id = %s AND p.client_email = %s
            """, (proposal_id, invitation['invited_email']))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Get comments
            cursor.execute("""
                SELECT dc.id, dc.comment_text, dc.created_at, dc.created_by,
                       u.full_name as created_by_name, u.email as created_by_email
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                WHERE dc.proposal_id = %s
                ORDER BY dc.created_at DESC
            """, (proposal_id,))
            
            comments = cursor.fetchall()
            
            # Get activity log (simplified - you can enhance this)
            activity = [
                {
                    'action': 'Proposal Created',
                    'description': f'Proposal was created by {proposal["owner_name"]}',
                    'timestamp': proposal['created_at'].isoformat() if proposal['created_at'] else None
                },
                {
                    'action': 'Sent to Client',
                    'description': f'Proposal was sent to {proposal["client_name"]}',
                    'timestamp': proposal['updated_at'].isoformat() if proposal['updated_at'] else None
                }
            ]
            
            return {
                'proposal': dict(proposal),
                'comments': [dict(c) for c in comments],
                'activity': activity
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting client proposal details: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/client/proposals/<int:proposal_id>/comment")
def add_client_comment(proposal_id):
    """Add a comment from client"""
    try:
        data = request.get_json()
        token = data.get('token')
        comment_text = data.get('comment_text')
        
        if not token or not comment_text:
            return {'detail': 'Token and comment text required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Create or get guest user
            guest_email = invitation['invited_email']
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (guest_email, guest_email, '', f'Client ({guest_email})', 'client'))
            
            guest_user_id = cursor.fetchone()['id']
            conn.commit()
            
            # Add comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, section_index, highlighted_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, created_at
            """, (proposal_id, comment_text, guest_user_id, 
                  data.get('section_index'), data.get('highlighted_text'), 'open'))
            
            result = cursor.fetchone()
            conn.commit()
            
            return {
                'id': result['id'],
                'message': 'Comment added successfully',
                'created_at': result['created_at'].isoformat() if result['created_at'] else None
            }, 201
            
    except Exception as e:
        print(f"❌ Error adding client comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/client/proposals/<int:proposal_id>/approve")
def client_approve_proposal(proposal_id):
    """Client approves and signs proposal"""
    try:
        data = request.get_json()
        token = data.get('token')
        signer_name = data.get('signer_name')
        signer_title = data.get('signer_title', '')
        comments = data.get('comments', '')
        signature_date = data.get('signature_date')
        
        if not token or not signer_name:
            return {'detail': 'Token and signer name required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Update proposal status
            cursor.execute("""
                UPDATE proposals 
                SET status = 'Client Approved', updated_at = NOW()
                WHERE id = %s AND client_email = %s
                RETURNING id, title, client_name, user_id
            """, (proposal_id, invitation['invited_email']))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Store signature information (you might want a separate table for this)
            # For now, add as a comment
            signature_info = f"""
✓ APPROVED AND SIGNED
Signer: {signer_name}
{f"Title: {signer_title}" if signer_title else ""}
Date: {signature_date or datetime.now().isoformat()}
{f"Comments: {comments}" if comments else ""}
            """
            
            # Get or create client user
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (invitation['invited_email'], invitation['invited_email'], '', signer_name, 'client'))
            
            client_user_id = cursor.fetchone()['id']
            
            # Add signature as comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, status)
                VALUES (%s, %s, %s, %s)
            """, (proposal_id, signature_info, client_user_id, 'resolved'))
            
            conn.commit()
            
            print(f"✅ Proposal {proposal_id} approved by client: {signer_name}")
            
            return {
                'message': 'Proposal approved successfully',
                'proposal_id': proposal['id'],
                'status': 'Client Approved'
            }, 200
            
    except Exception as e:
        print(f"❌ Error approving proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/client/proposals/<int:proposal_id>/reject")
def client_reject_proposal(proposal_id):
    """Client rejects proposal"""
    try:
        data = request.get_json()
        token = data.get('token')
        reason = data.get('reason')
        
        if not token or not reason:
            return {'detail': 'Token and reason required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify token
            cursor.execute("""
                SELECT invited_email, expires_at
                FROM collaboration_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid access token'}, 404
            
            if invitation['expires_at'] and datetime.now() > invitation['expires_at']:
                return {'detail': 'Access token has expired'}, 403
            
            # Update proposal status
            cursor.execute("""
                UPDATE proposals 
                SET status = 'Client Declined', updated_at = NOW()
                WHERE id = %s AND client_email = %s
                RETURNING id, title
            """, (proposal_id, invitation['invited_email']))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Add rejection reason as comment
            rejection_info = f"✗ REJECTED\nReason: {reason}"
            
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, full_name, role)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (email) DO UPDATE SET email = EXCLUDED.email
                RETURNING id
            """, (invitation['invited_email'], invitation['invited_email'], '', f'Client ({invitation["invited_email"]})', 'client'))
            
            client_user_id = cursor.fetchone()['id']
            
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, status)
                VALUES (%s, %s, %s, %s)
            """, (proposal_id, rejection_info, client_user_id, 'open'))
            
            conn.commit()
            
            print(f"⚠️ Proposal {proposal_id} rejected by client")
            
            return {
                'message': 'Proposal rejected',
                'proposal_id': proposal['id'],
                'status': 'Client Declined'
            }, 200
            
    except Exception as e:
        print(f"❌ Error rejecting proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

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
# CLIENT MANAGEMENT ENDPOINTS - MIGRATED TO api/routes/clients.py
# ============================================================================
# NOTE: These routes have been migrated to the 'clients' blueprint.
# The blueprint routes are registered above and will take precedence.
# TODO: Remove these old route definitions after confirming everything works.

@app.post("/clients/invite")
@token_required
def send_client_invitation(username=None):
    """Send a secure onboarding invitation to a client"""
    try:
        print(f"[INVITE] Received invitation request from user: {username}")
        data = request.json
        print(f"[INVITE] Request data: {data}")
        
        invited_email = data.get('invited_email')
        expected_company = data.get('expected_company')
        expiry_days = data.get('expiry_days', 7)
        
        print(f"[INVITE] Email: {invited_email}, Company: {expected_company}, Expiry: {expiry_days} days")
        
        if not invited_email:
            print("[INVITE] ERROR: Email is required")
            return jsonify({"error": "Email is required"}), 400
        
        # Generate secure token
        access_token = secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(days=expiry_days)
        
        # Get current user ID
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row[0]
            
            # Insert invitation
            cursor.execute("""
                INSERT INTO client_onboarding_invitations 
                (access_token, invited_email, invited_by, expected_company, status, expires_at)
                VALUES (%s, %s, %s, %s, 'pending', %s)
                RETURNING id, access_token, invited_at
            """, (access_token, invited_email, user_id, expected_company, expires_at))
            
            result = cursor.fetchone()
            conn.commit()
            
            invitation_id, token, invited_at = result
            
            # Generate onboarding link (using hash-based routing)
            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            onboarding_url = f"{frontend_url}/#/onboard/{token}"
            
            # Load email template
            template_path = Path(__file__).parent / 'templates' / 'email' / 'client_invitation.html'
            try:
                with open(template_path, 'r', encoding='utf-8') as f:
                    html_content = f.read()
            except FileNotFoundError:
                print(f"[WARN] Template not found at {template_path}, using fallback")
                logo_html = _get_logo_html()
                html_content = f"""
                <html><body style="font-family: 'Poppins', Arial, sans-serif; padding: 40px 20px; background: #000; color: #fff;">
                    <div style="max-width: 600px; margin: 0 auto; background: #1A1A1A; padding: 40px; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3);">
                        <div style="text-align: center; margin-bottom: 30px;">
                            {logo_html}
                        </div>
                        <p style="color: #fff; font-size: 16px;">Hello{{ company_name }}!</p>
                        <p style="color: #B3B3B3; font-size: 16px;">You've been invited to complete your client onboarding with Khonology.</p>
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{{ onboarding_url }}" style="background: linear-gradient(135deg, #E9293A 0%, #780A01 100%); color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: 600;">Start Onboarding →</a>
                        </div>
                        <p style="color: #666; font-size: 12px; text-align: center; margin-top: 30px;">© 2025 Khonology. All rights reserved.</p>
                    </div>
                </body></html>
                """
            
            # Replace template variables
            company_name = f", {expected_company}" if expected_company else ""
            logo_html = _get_logo_html()
            html_content = html_content.replace('{{ company_name }}', company_name)
            html_content = html_content.replace('{{ onboarding_url }}', onboarding_url)
            html_content = html_content.replace('{{ expiry_days }}', str(expiry_days))
            html_content = html_content.replace('{{ logo_html }}', logo_html)
            
            # Send email
            subject = "You're Invited to Complete Your Client Onboarding"
            
            print(f"[INVITE] Sending email to {invited_email}...")
            email_sent = send_email(invited_email, subject, html_content)
            print(f"[INVITE] Email sent: {email_sent}")
            
            return jsonify({
                "success": True,
                "invitation_id": invitation_id,
                "access_token": token,
                "onboarding_url": onboarding_url,
                "invited_email": invited_email,
                "expires_at": expires_at.isoformat(),
                "invited_at": invited_at.isoformat()
            }), 201
            
    except Exception as e:
        print(f"[ERROR] Error sending invitation: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# Get all invitations
@app.get("/clients/invitations")
@token_required
def get_invitations(username=None):
    """Get all client invitations for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Get all invitations
            cursor.execute("""
                SELECT 
                    id, access_token, invited_email, expected_company, 
                    status, invited_at, completed_at, expires_at, client_id
                FROM client_onboarding_invitations
                WHERE invited_by = %s
                ORDER BY invited_at DESC
            """, (user_id,))
            
            invitations = cursor.fetchall()
            return jsonify([dict(inv) for inv in invitations]), 200
            
    except Exception as e:
        print(f"❌ Error fetching invitations: {e}")
        return jsonify({"error": str(e)}), 500

# Resend invitation
@app.post("/clients/invitations/<int:invitation_id>/resend")
@token_required
def resend_invitation(username=None, invitation_id=None):
    """Resend a client invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation
            cursor.execute("""
                SELECT invited_email, access_token, expected_company, expires_at
                FROM client_onboarding_invitations
                WHERE id = %s AND status = 'pending'
            """, (invitation_id,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return jsonify({"error": "Invitation not found or already completed"}), 404
            
            # Check if expired
            if datetime.fromisoformat(str(invitation['expires_at'])) < datetime.now(timezone.utc):
                # Generate new token and extend expiry
                new_token = secrets.token_urlsafe(32)
                new_expires_at = datetime.now(timezone.utc) + timedelta(days=7)
                
                cursor.execute("""
                    UPDATE client_onboarding_invitations
                    SET access_token = %s, expires_at = %s
                    WHERE id = %s
                """, (new_token, new_expires_at, invitation_id))
                conn.commit()
                
                token = new_token
                expires_at = new_expires_at
            else:
                token = invitation['access_token']
                expires_at = invitation['expires_at']
            
            # Generate onboarding link (using hash-based routing)
            frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:3000')
            onboarding_url = f"{frontend_url}/#/onboard/{token}"
            
            # Calculate remaining days
            expires_at_dt = datetime.fromisoformat(str(expires_at)) if isinstance(expires_at, str) else expires_at
            remaining_days = max(1, (expires_at_dt - datetime.now(timezone.utc)).days)
            
            # Load email template
            template_path = Path(__file__).parent / 'templates' / 'email' / 'client_invitation.html'
            try:
                with open(template_path, 'r', encoding='utf-8') as f:
                    html_content = f.read()
            except FileNotFoundError:
                print(f"[WARN] Template not found at {template_path}, using fallback")
                logo_html = _get_logo_html()
                html_content = f"""
                <html><body style="font-family: 'Poppins', Arial, sans-serif; padding: 40px 20px; background: #000; color: #fff;">
                    <div style="max-width: 600px; margin: 0 auto; background: #1A1A1A; padding: 40px; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3);">
                        <div style="text-align: center; margin-bottom: 30px;">
                            {logo_html}
                        </div>
                        <p style="color: #fff; font-size: 16px;">Hello{{ company_name }}!</p>
                        <p style="color: #B3B3B3; font-size: 16px;">This is a friendly reminder to complete your client onboarding with Khonology.</p>
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{{ onboarding_url }}" style="background: linear-gradient(135deg, #E9293A 0%, #780A01 100%); color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: 600;">Start Onboarding →</a>
                        </div>
                        <p style="color: #666; font-size: 12px; text-align: center; margin-top: 30px;">© 2025 Khonology. All rights reserved.</p>
                    </div>
                </body></html>
                """
            
            # Replace template variables
            company_name = f", {invitation['expected_company']}" if invitation.get('expected_company') else ""
            logo_html = _get_logo_html()
            html_content = html_content.replace('{{ company_name }}', company_name)
            html_content = html_content.replace('{{ onboarding_url }}', onboarding_url)
            html_content = html_content.replace('{{ expiry_days }}', str(remaining_days))
            html_content = html_content.replace('{{ logo_html }}', logo_html)
            
            # Send email
            subject = "Reminder: Complete Your Client Onboarding"
            send_email(invitation['invited_email'], subject, html_content)
            
            return jsonify({"success": True, "message": "Invitation resent"}), 200
            
    except Exception as e:
        print(f"❌ Error resending invitation: {e}")
        return jsonify({"error": str(e)}), 500

# Cancel invitation
@app.delete("/clients/invitations/<int:invitation_id>")
@token_required
def cancel_invitation(username=None, invitation_id=None):
    """Cancel a pending invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                UPDATE client_onboarding_invitations
                SET status = 'cancelled'
                WHERE id = %s AND status = 'pending'
            """, (invitation_id,))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Invitation not found or already completed"}), 404
            
            return jsonify({"success": True, "message": "Invitation cancelled"}), 200
            
    except Exception as e:
        print(f"❌ Error cancelling invitation: {e}")
        return jsonify({"error": str(e)}), 500

# ============================================================================
# ONBOARDING ENDPOINTS - MIGRATED TO api/routes/onboarding.py
# ============================================================================
# NOTE: These routes have been migrated to the 'onboarding' blueprint.
# The blueprint routes are registered above and will take precedence.
# TODO: Remove these old route definitions after confirming everything works.

# NOTE: Verify email route is handled by the 'onboarding' blueprint
# This duplicate route has been removed to avoid conflicts
# Route is defined in: api/routes/onboarding.py
def _legacy_send_verification_code(token):
    """Send verification code to email (public endpoint)"""
    try:
        data = request.json
        email = data.get('email')
        
        if not email:
            return jsonify({"error": "Email is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Validate token and get invitation
            cursor.execute("""
                SELECT id, invited_email, status, expires_at, 
                       last_code_sent_at, verification_attempts
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                return jsonify({"error": "Invalid invitation link"}), 404
            
            if invitation['status'] != 'pending':
                return jsonify({"error": "This invitation has already been used"}), 400
            
            if datetime.fromisoformat(str(invitation['expires_at'])) < datetime.now(timezone.utc):
                return jsonify({"error": "This invitation has expired"}), 400
            
            # Verify email matches invitation
            if email.lower() != invitation['invited_email'].lower():
                return jsonify({"error": "Email does not match the invitation"}), 400
            
            # Rate limiting: max 3 codes per hour
            if invitation['last_code_sent_at']:
                last_sent = datetime.fromisoformat(str(invitation['last_code_sent_at']))
                time_since_last = datetime.now(timezone.utc) - last_sent
                if time_since_last.total_seconds() < 3600:  # 1 hour
                    # Check how many codes sent in last hour
                    cursor.execute("""
                        SELECT COUNT(*) as count
                        FROM email_verification_events
                        WHERE invitation_id = %s 
                        AND event_type = 'code_sent'
                        AND created_at > NOW() - INTERVAL '1 hour'
                    """, (invitation['id'],))
                    recent_sends = cursor.fetchone()['count']
                    if recent_sends >= 3:
                        return jsonify({"error": "Too many verification codes sent. Please try again later."}), 429
            
            # Generate 6-digit code
            verification_code = ''.join([str(secrets.randbelow(10)) for _ in range(6)])
            
            # Hash the code (simple hash for now, can upgrade to bcrypt later)
            import hashlib
            code_hash = hashlib.sha256(verification_code.encode()).hexdigest()
            code_expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)
            
            # Store hashed code
            cursor.execute("""
                UPDATE client_onboarding_invitations
                SET verification_code_hash = %s,
                    code_expires_at = %s,
                    last_code_sent_at = NOW(),
                    verification_attempts = 0
                WHERE id = %s
            """, (code_hash, code_expires_at, invitation['id']))
            
            # Log event
            cursor.execute("""
                INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                VALUES (%s, %s, 'code_sent', 'Verification code sent')
            """, (invitation['id'], email))
            
            conn.commit()
            
            # Send email with code
            subject = "Your Khonology Verification Code"
            html_content = f"""
            <html>
            <head>
                <style>
                    body {{ font-family: 'Poppins', Arial, sans-serif; background-color: #000000; padding: 40px 20px; }}
                    .container {{ max-width: 600px; margin: 0 auto; background-color: #1A1A1A; border-radius: 24px; border: 1px solid rgba(233, 41, 58, 0.3); padding: 40px; }}
                    .code-box {{ background-color: #2A2A2A; border: 2px solid #E9293A; border-radius: 12px; padding: 24px; text-align: center; margin: 30px 0; }}
                    .code {{ font-size: 36px; font-weight: bold; color: #E9293A; letter-spacing: 8px; font-family: 'Courier New', monospace; }}
                    .footer {{ color: #666; font-size: 12px; text-align: center; margin-top: 30px; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <h1 style="color: #FFFFFF; text-align: center; margin-bottom: 20px;">Email Verification</h1>
                    <p style="color: #B3B3B3; font-size: 16px; line-height: 1.6;">
                        Hello! Please use the verification code below to complete your onboarding:
                    </p>
                    <div class="code-box">
                        <div class="code">{verification_code}</div>
                    </div>
                    <p style="color: #B3B3B3; font-size: 14px; line-height: 1.6;">
                        This code will expire in 15 minutes. If you didn't request this code, please ignore this email.
                    </p>
                    <div class="footer">
                        <p>© 2025 Khonology. All rights reserved.</p>
                    </div>
                </div>
            </body>
            </html>
            """
            
            send_email(email, subject, html_content)
            
            return jsonify({
                "success": True,
                "message": "Verification code sent to your email"
            }), 200
            
    except Exception as e:
        print(f"[ERROR] Error sending verification code: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# NOTE: Verify code route is handled by the 'onboarding' blueprint
# This duplicate route has been removed to avoid conflicts
# Route is defined in: api/routes/onboarding.py
def _legacy_verify_email_code(token):
    """Verify email verification code (public endpoint)"""
    try:
        data = request.json
        code = data.get('code')
        email = data.get('email')
        
        if not code or not email:
            return jsonify({"error": "Code and email are required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation
            cursor.execute("""
                SELECT id, invited_email, verification_code_hash, code_expires_at,
                       verification_attempts, status, expires_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                return jsonify({"error": "Invalid invitation link"}), 404
            
            if invitation['status'] != 'pending':
                return jsonify({"error": "This invitation has already been used"}), 400
            
            if datetime.fromisoformat(str(invitation['expires_at'])) < datetime.now(timezone.utc):
                return jsonify({"error": "This invitation has expired"}), 400
            
            # Verify email matches
            if email.lower() != invitation['invited_email'].lower():
                return jsonify({"error": "Email does not match the invitation"}), 400
            
            # Check if code exists
            if not invitation['verification_code_hash']:
                return jsonify({"error": "No verification code found. Please request a new code."}), 400
            
            # Check if code expired
            if invitation['code_expires_at']:
                if datetime.fromisoformat(str(invitation['code_expires_at'])) < datetime.now(timezone.utc):
                    cursor.execute("""
                        INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                        VALUES (%s, %s, 'code_expired', 'Verification code expired')
                    """, (invitation['id'], email))
                    conn.commit()
                    return jsonify({"error": "Verification code has expired. Please request a new one."}), 400
            
            # Check attempts (max 5 attempts)
            if invitation['verification_attempts'] and invitation['verification_attempts'] >= 5:
                cursor.execute("""
                    INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                    VALUES (%s, %s, 'rate_limited', 'Too many verification attempts')
                """, (invitation['id'], email))
                conn.commit()
                return jsonify({"error": "Too many failed attempts. Please request a new code."}), 429
            
            # Verify code
            import hashlib
            code_hash = hashlib.sha256(code.encode()).hexdigest()
            
            if code_hash != invitation['verification_code_hash']:
                # Increment attempts
                cursor.execute("""
                    UPDATE client_onboarding_invitations
                    SET verification_attempts = COALESCE(verification_attempts, 0) + 1
                    WHERE id = %s
                """, (invitation['id'],))
                
                cursor.execute("""
                    INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                    VALUES (%s, %s, 'verify_failed', 'Invalid verification code')
                """, (invitation['id'], email))
                conn.commit()
                
                remaining = 5 - (invitation['verification_attempts'] or 0) - 1
                return jsonify({
                    "error": "Invalid verification code",
                    "remaining_attempts": max(0, remaining)
                }), 400
            
            # Code is valid - mark email as verified
            cursor.execute("""
                UPDATE client_onboarding_invitations
                SET email_verified_at = NOW(),
                    verification_code_hash = NULL,
                    code_expires_at = NULL,
                    verification_attempts = 0
                WHERE id = %s
            """, (invitation['id'],))
            
            cursor.execute("""
                INSERT INTO email_verification_events (invitation_id, email, event_type, event_detail)
                VALUES (%s, %s, 'code_verified', 'Email successfully verified')
            """, (invitation['id'], email))
            
            conn.commit()
            
            return jsonify({
                "success": True,
                "message": "Email verified successfully"
            }), 200
            
    except Exception as e:
        print(f"[ERROR] Error verifying code: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# NOTE: Onboarding routes are handled by the 'onboarding' blueprint
# These duplicate routes have been removed to avoid conflicts
# Routes are defined in: api/routes/onboarding.py

# NOTE: Submit onboarding route is handled by the 'onboarding' blueprint
# This duplicate route has been removed to avoid conflicts
# Route is defined in: api/routes/onboarding.py
def _legacy_submit_onboarding(token):
    """Submit client onboarding form (public endpoint)"""
    try:
        data = request.json
        
        # Required fields
        required_fields = ['company_name', 'contact_person', 'email', 'phone']
        for field in required_fields:
            if not data.get(field):
                return jsonify({"error": f"Missing required field: {field}"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Validate token
            cursor.execute("""
                SELECT id, invited_by, status, expires_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            
            if not invitation:
                return jsonify({"error": "Invalid invitation link"}), 404
            
            if invitation['status'] != 'pending':
                return jsonify({"error": "This invitation has already been used"}), 400
            
            if datetime.fromisoformat(str(invitation['expires_at'])) < datetime.now(timezone.utc):
                return jsonify({"error": "This invitation has expired"}), 400
            
            # Check if email is verified
            cursor.execute("""
                SELECT email_verified_at
                FROM client_onboarding_invitations
                WHERE access_token = %s
            """, (token,))
            verified = cursor.fetchone()
            if not verified or not verified['email_verified_at']:
                return jsonify({"error": "Email must be verified before submitting the form"}), 403
            
            # Insert client
            cursor.execute("""
                INSERT INTO clients (
                    company_name, contact_person, email, phone,
                    industry, company_size, location, business_type,
                    project_needs, budget_range, timeline, additional_info,
                    status, onboarding_token, created_by
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'active', %s, %s
                )
                RETURNING id
            """, (
                data.get('company_name'),
                data.get('contact_person'),
                data.get('email'),
                data.get('phone'),
                data.get('industry'),
                data.get('company_size'),
                data.get('location'),
                data.get('business_type'),
                data.get('project_needs'),
                data.get('budget_range'),
                data.get('timeline'),
                data.get('additional_info'),
                token,
                invitation['invited_by']
            ))
            
            client_id = cursor.fetchone()['id']
            
            # Update invitation
            cursor.execute("""
                UPDATE client_onboarding_invitations
                SET status = 'completed', completed_at = NOW(), client_id = %s
                WHERE id = %s
            """, (client_id, invitation['id']))
            
            conn.commit()
            
            return jsonify({
                "success": True,
                "message": "Onboarding completed successfully",
                "client_id": client_id
            }), 201
            
    except Exception as e:
        print(f"❌ Error submitting onboarding: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# Get clients for dropdown selection (simplified format)
@app.get("/api/clients/for-selection")
@token_required
def get_clients_for_selection(username=None):
    """Get clients in a simplified format optimized for dropdown/selection components"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Get search parameter
            search = request.args.get('search', '').strip()
            
            if search:
                cursor.execute("""
                    SELECT 
                        id, company_name, contact_person, email, phone
                    FROM clients
                    WHERE created_by = %s
                    AND status = 'active'
                    AND (
                        company_name ILIKE %s 
                        OR contact_person ILIKE %s 
                        OR email ILIKE %s
                    )
                    ORDER BY company_name ASC
                    LIMIT 50
                """, (user_id, f'%{search}%', f'%{search}%', f'%{search}%'))
            else:
                cursor.execute("""
                    SELECT 
                        id, company_name, contact_person, email, phone
                    FROM clients
                    WHERE created_by = %s
                    AND status = 'active'
                    ORDER BY company_name ASC
                    LIMIT 100
                """, (user_id,))
            
            clients = cursor.fetchall()
            
            # Return simplified format for dropdown
            clients_list = [{
                'id': client['id'],
                'label': f"{client['company_name']} - {client['contact_person']}",
                'company_name': client['company_name'],
                'contact_person': client['contact_person'],
                'email': client['email'],
                'phone': client.get('phone')
            } for client in clients]
            
            return jsonify(clients_list), 200
            
    except Exception as e:
        print(f"❌ Error fetching clients for selection: {e}")
        return jsonify({"error": str(e)}), 500

# Get all clients
@app.get("/clients")
@token_required
def get_clients(username=None):
    """Get all clients for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Get all clients - optimized for dropdown selection
            # Include search parameter if provided
            search = request.args.get('search', '').strip()
            
            if search:
                cursor.execute("""
                    SELECT 
                        id, company_name, contact_person, email, phone,
                        industry, company_size, location, business_type,
                        project_needs, budget_range, timeline, additional_info,
                        status, created_at, updated_at
                    FROM clients
                    WHERE created_by = %s
                    AND (
                        company_name ILIKE %s 
                        OR contact_person ILIKE %s 
                        OR email ILIKE %s
                    )
                    ORDER BY company_name ASC
                    LIMIT 50
                """, (user_id, f'%{search}%', f'%{search}%', f'%{search}%'))
            else:
                cursor.execute("""
                    SELECT 
                        id, company_name, contact_person, email, phone,
                        industry, company_size, location, business_type,
                        project_needs, budget_range, timeline, additional_info,
                        status, created_at, updated_at
                    FROM clients
                    WHERE created_by = %s
                    ORDER BY company_name ASC
                    LIMIT 100
                """, (user_id,))
            
            clients = cursor.fetchall()
            
            # Format for dropdown (simplified response)
            format_type = request.args.get('format', 'full')
            if format_type == 'dropdown':
                # Return simplified format for dropdown selection
                clients_list = [{
                    'id': client['id'],
                    'label': f"{client['company_name']} - {client['contact_person']}",
                    'company_name': client['company_name'],
                    'contact_person': client['contact_person'],
                    'email': client['email'],
                    'phone': client.get('phone')
                } for client in clients]
                return jsonify(clients_list), 200
            else:
                # Return full client data
                return jsonify([dict(client) for client in clients]), 200
            
    except Exception as e:
        print(f"❌ Error fetching clients: {e}")
        return jsonify({"error": str(e)}), 500

# Get single client
@app.get("/clients/<int:client_id>")
@token_required
def get_client(username=None, client_id=None):
    """Get a single client's details"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    id, company_name, contact_person, email, phone,
                    industry, company_size, location, business_type,
                    project_needs, budget_range, timeline, additional_info,
                    status, created_at, updated_at
                FROM clients
                WHERE id = %s
            """, (client_id,))
            
            client = cursor.fetchone()
            
            if not client:
                return jsonify({"error": "Client not found"}), 404
            
            return jsonify(dict(client)), 200
            
    except Exception as e:
        print(f"❌ Error fetching client: {e}")
        return jsonify({"error": str(e)}), 500

# Update client status
@app.patch("/clients/<int:client_id>/status")
@token_required
def update_client_status(username=None, client_id=None):
    """Update client status"""
    try:
        data = request.json
        new_status = data.get('status')
        
        if not new_status:
            return jsonify({"error": "Status is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                UPDATE clients
                SET status = %s, updated_at = NOW()
                WHERE id = %s
            """, (new_status, client_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Client not found"}), 404
            
            return jsonify({"success": True, "message": "Status updated"}), 200
            
    except Exception as e:
        print(f"❌ Error updating client status: {e}")
        return jsonify({"error": str(e)}), 500

# Get client notes
@app.get("/clients/<int:client_id>/notes")
@token_required
def get_client_notes(username=None, client_id=None):
    """Get all notes for a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    cn.id, cn.note_text, cn.created_at, cn.updated_at,
                    u.email as created_by_email, u.full_name as created_by_name
                FROM client_notes cn
                JOIN users u ON cn.created_by = u.id
                WHERE cn.client_id = %s
                ORDER BY cn.created_at DESC
            """, (client_id,))
            
            notes = cursor.fetchall()
            return jsonify([dict(note) for note in notes]), 200
            
    except Exception as e:
        print(f"❌ Error fetching client notes: {e}")
        return jsonify({"error": str(e)}), 500

# Add client note
@app.post("/clients/<int:client_id>/notes")
@token_required
def add_client_note(username=None, client_id=None):
    """Add a note to a client"""
    try:
        data = request.json
        note_text = data.get('note_text')
        
        if not note_text:
            return jsonify({"error": "Note text is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Insert note
            cursor.execute("""
                INSERT INTO client_notes (client_id, note_text, created_by)
                VALUES (%s, %s, %s)
                RETURNING id, created_at
            """, (client_id, note_text, user_id))
            
            result = cursor.fetchone()
            conn.commit()
            
            return jsonify({
                "success": True,
                "note_id": result['id'],
                "created_at": result['created_at'].isoformat()
            }), 201
            
    except Exception as e:
        print(f"❌ Error adding client note: {e}")
        return jsonify({"error": str(e)}), 500

# Update client note
@app.put("/clients/notes/<int:note_id>")
@token_required
def update_client_note(username=None, note_id=None):
    """Update a client note"""
    try:
        data = request.json
        note_text = data.get('note_text')
        
        if not note_text:
            return jsonify({"error": "Note text is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                UPDATE client_notes
                SET note_text = %s, updated_at = NOW()
                WHERE id = %s
            """, (note_text, note_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Note not found"}), 404
            
            return jsonify({"success": True, "message": "Note updated"}), 200
            
    except Exception as e:
        print(f"❌ Error updating client note: {e}")
        return jsonify({"error": str(e)}), 500

# Delete client note
@app.delete("/clients/notes/<int:note_id>")
@token_required
def delete_client_note(username=None, note_id=None):
    """Delete a client note"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("DELETE FROM client_notes WHERE id = %s", (note_id,))
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Note not found"}), 404
            
            return jsonify({"success": True, "message": "Note deleted"}), 200
            
    except Exception as e:
        print(f"❌ Error deleting client note: {e}")
        return jsonify({"error": str(e)}), 500

# Get client linked proposals
@app.get("/clients/<int:client_id>/proposals")
@token_required
def get_client_linked_proposals(username=None, client_id=None):
    """Get all proposals linked to a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    p.id, p.title, p.status, p.created_at,
                    cp.relationship_type, cp.linked_at,
                    u.email as linked_by_email
                FROM client_proposals cp
                JOIN proposals p ON cp.proposal_id = p.id
                JOIN users u ON cp.linked_by = u.id
                WHERE cp.client_id = %s
                ORDER BY cp.linked_at DESC
            """, (client_id,))
            
            proposals = cursor.fetchall()
            return jsonify([dict(prop) for prop in proposals]), 200
            
    except Exception as e:
        print(f"❌ Error fetching client proposals: {e}")
        return jsonify({"error": str(e)}), 500

# Link proposal to client
@app.post("/clients/<int:client_id>/proposals")
@token_required
def link_client_proposal(username=None, client_id=None):
    """Link a proposal to a client"""
    try:
        data = request.json
        proposal_id = data.get('proposal_id')
        relationship_type = data.get('relationship_type', 'primary')
        
        if not proposal_id:
            return jsonify({"error": "Proposal ID is required"}), 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return jsonify({"error": "User not found"}), 404
            
            user_id = user_row['id']
            
            # Link proposal
            cursor.execute("""
                INSERT INTO client_proposals (client_id, proposal_id, relationship_type, linked_by)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (client_id, proposal_id) DO NOTHING
                RETURNING id
            """, (client_id, proposal_id, relationship_type, user_id))
            
            result = cursor.fetchone()
            conn.commit()
            
            if not result:
                return jsonify({"error": "Proposal already linked to this client"}), 400
            
            return jsonify({"success": True, "link_id": result['id']}), 201
            
    except Exception as e:
        print(f"❌ Error linking proposal to client: {e}")
        return jsonify({"error": str(e)}), 500

# Unlink proposal from client
@app.delete("/clients/<int:client_id>/proposals/<int:proposal_id>")
@token_required
def unlink_client_proposal(username=None, client_id=None, proposal_id=None):
    """Unlink a proposal from a client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                DELETE FROM client_proposals
                WHERE client_id = %s AND proposal_id = %s
            """, (client_id, proposal_id))
            
            conn.commit()
            
            if cursor.rowcount == 0:
                return jsonify({"error": "Link not found"}), 404
            
            return jsonify({"success": True, "message": "Proposal unlinked"}), 200
            
    except Exception as e:
        print(f"❌ Error unlinking proposal: {e}")
        return jsonify({"error": str(e)}), 500

# ============================================================
# END CLIENT MANAGEMENT ENDPOINTS
# ============================================================

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

# Route listing endpoint for debugging (no auth required)
@app.get("/routes")
def list_routes():
    """List all registered routes for debugging"""
    routes = []
    for rule in app.url_map.iter_rules():
        routes.append({
            "endpoint": rule.endpoint,
            "methods": list(rule.methods),
            "path": rule.rule
        })
    
    # Filter for proposals-related routes
    proposals_routes = [r for r in routes if "proposal" in r["path"].lower()]
    
    return {
        "total_routes": len(routes),
        "proposals_routes": proposals_routes,
        "all_routes": routes
    }, 200

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
