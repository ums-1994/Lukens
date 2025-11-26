import os
import sys
import json
import re
import base64
import hashlib
import hmac
import secrets
import difflib
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from functools import wraps
from urllib.parse import urlparse, parse_qs
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
    print("[WARN] ReportLab not installed. PDF generation will be limited. Run: pip install reportlab")

# DocuSign SDK
try:
    from docusign_esign import ApiClient, EnvelopesApi, EnvelopeDefinition, Document, Signer, SignHere, Tabs, Recipients, RecipientViewRequest
    from docusign_esign.client.api_exception import ApiException
    import jwt
    DOCUSIGN_AVAILABLE = True
except ImportError:
    DOCUSIGN_AVAILABLE = False
    print("[WARN] DocuSign SDK not installed. Run: pip install docusign-esign")
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
from api.utils.risk_checks import run_prechecks, combine_assessments
from api.utils.email import send_email

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

# ============================================================================
# REGISTER BLUEPRINTS (Refactored routes)
# ============================================================================
# Import and register blueprints for refactored routes
try:
    from api.routes import auth, clients, onboarding
    app.register_blueprint(auth.bp)
    app.register_blueprint(clients.bp)
    app.register_blueprint(onboarding.bp)
    print("[OK] Registered refactored blueprints: auth, clients, onboarding")
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
            print(f"[*] Connecting to PostgreSQL: {db_config['host']}:{db_config['port']}/{db_config['database']}")
            _pg_pool = psycopg2.pool.SimpleConnectionPool(
                minconn=1,
                maxconn=20,  # Increased max connections
                **db_config
            )
            print("[OK] PostgreSQL connection pool created successfully")
        except Exception as e:
            print(f"[ERROR] Error creating PostgreSQL connection pool: {e}")
            raise
    return _pg_pool

def _pg_conn():
    try:
        return get_pg_pool().getconn()
    except Exception as e:
        print(f"[ERROR] Error getting PostgreSQL connection: {e}")
        raise

def release_pg_conn(conn):
    try:
        if conn:
            get_pg_pool().putconn(conn)
    except Exception as e:
        print(f"[WARN] Error releasing PostgreSQL connection: {e}")

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

        # Proposal risk audits table
        cursor.execute('''CREATE TABLE IF NOT EXISTS proposal_risk_audits (
        id SERIAL PRIMARY KEY,
        proposal_id INTEGER NOT NULL,
        triggered_by VARCHAR(255),
        model_used VARCHAR(255),
        precheck_summary JSONB NOT NULL,
        ai_summary JSONB,
        combined_summary JSONB,
        overall_risk_level VARCHAR(32),
        risk_score INTEGER,
        can_release BOOLEAN,
        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE
        )''')

        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_risk_audits_proposal 
                         ON proposal_risk_audits(proposal_id, created_at DESC)''')
        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_risk_audits_level 
                         ON proposal_risk_audits(overall_risk_level)''')
        
        conn.commit()
        release_pg_conn(conn)
        print("[OK] PostgreSQL schema initialized successfully")
    except Exception as e:
        print(f"[ERROR] Error initializing PostgreSQL schema: {e}")
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
        print("[*] Initializing PostgreSQL schema...")
        init_pg_schema()
        _db_initialized = True
        print("[OK] Database schema initialized successfully")
    except Exception as e:
        print(f"[ERROR] Database initialization error: {e}")
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
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute("""
                INSERT INTO activity_log (proposal_id, user_id, action_type, action_description, metadata)
                VALUES (%s, %s, %s, %s, %s)
            """, (proposal_id, user_id, action_type, description, json.dumps(metadata) if metadata else None))
            conn.commit()
    except Exception as e:
        print(f"⚠️ Failed to log activity: {e}")
        # Don't raise - activity logging should not break main functionality

# ============================================================================
# JSON SANITIZATION HELPERS
# ============================================================================

def _json_default(value):
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8")
        except Exception:
            return value.decode("latin-1", errors="ignore")
    return str(value)


def sanitize_for_json(payload):
    """Return a plain-Python structure that can be safely json.dumps'ed."""
    try:
        return json.loads(json.dumps(payload, default=_json_default))
    except TypeError:
        # Final fallback: convert anything still problematic into strings
        return json.loads(json.dumps(payload, default=str))

# ============================================================================
# NOTIFICATION HELPER
# ============================================================================

def create_notification(user_id, notification_type, title, message, proposal_id=None, metadata=None):
    """
    Create a notification for a user
    
    Args:
        user_id: ID of the user to notify
        notification_type: Type of notification (e.g., 'comment_added', 'suggestion_created')
        title: Notification title
        message: Notification message
        proposal_id: Optional proposal ID
        metadata: Optional dict with additional data
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO notifications (user_id, proposal_id, notification_type, title, message, metadata)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (user_id, proposal_id, notification_type, title, message, json.dumps(metadata) if metadata else None))
            conn.commit()
            print(f"✅ Notification created for user {user_id}: {title}")
    except Exception as e:
        print(f"⚠️ Failed to create notification: {e}")
        # Don't raise - notification should not break main functionality

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
            
            # Get proposal owner
            cursor.execute("SELECT user_id FROM proposals WHERE id = %s", (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return
            
            # Get owner's user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (proposal['user_id'],))
            owner = cursor.fetchone()
            if owner and owner['id'] != exclude_user_id:
                create_notification(owner['id'], notification_type, title, message, proposal_id, metadata)
            
            # Get all collaborators
            cursor.execute("""
                SELECT DISTINCT u.id
                FROM collaboration_invitations ci
                JOIN users u ON ci.invited_email = u.email
                WHERE ci.proposal_id = %s AND ci.status = 'accepted'
            """, (proposal_id,))
            
            collaborators = cursor.fetchall()
            for collab in collaborators:
                if collab['id'] != exclude_user_id:
                    create_notification(collab['id'], notification_type, title, message, proposal_id, metadata)
                    
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
                    {'comment_id': comment_id, 'mentioned_by': mentioned_by_user_id}
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
        
        with open(private_key_path, 'r') as key_file:
            private_key = key_file.read()
        
        api_client = ApiClient()
        api_client.set_base_path(f"https://{auth_server}")
        
        response = api_client.request_jwt_user_token(
            client_id=integration_key,
            user_id=user_id,
            oauth_host_name=auth_server,
            private_key_bytes=private_key,
            expires_in=3600,
            scopes=["signature", "impersonation"]
        )
        
        user_info = api_client.get_user_info(response.access_token)
        accounts = getattr(user_info, 'accounts', None)
        account = None
        if accounts:
            for acc in accounts:
                if getattr(acc, 'is_default', '').lower() == 'true':
                    account = acc
                    break
            if account is None:
                account = accounts[0]
        if not account or not getattr(account, 'account_id', None):
            raise Exception("No account_id returned from DocuSign user info")
        account_id = account.account_id
        base_uri = getattr(account, 'base_uri', None)
        if not base_uri:
            raise Exception("No base_uri returned from DocuSign user info")
        base_path = f"{base_uri}/restapi"
        
        print(f"✅ DocuSign JWT authenticated. Account ID: {account_id}")
        
        return {
            'access_token': response.access_token,
            'account_id': account_id,
            'base_path': base_path
        }
        
    except Exception as e:
        print(f"❌ Error getting DocuSign JWT token: {e}")
        traceback.print_exc()
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
        auth_data = get_docusign_jwt_token()
        access_token = auth_data['access_token']
        account_id = auth_data['account_id']
        base_path = auth_data.get('base_path') or os.getenv('DOCUSIGN_BASE_PATH', 'https://demo.docusign.net/restapi')
        
        print(f"ℹ️  Using account_id: {account_id}")
        print(f"ℹ️  Using base_path: {base_path}")
        
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
    print(f"[TOKEN] Generated new token for user '{username}': {token[:20]}...{token[-10:]}")
    print(f"[TOKEN] Total valid tokens: {len(valid_tokens)}")
    return token

def verify_token(token):
    # Dev bypass for testing
    if token == 'dev-bypass-token':
        print("[DEV] Using dev-bypass-token for username: admin")
        return 'admin'
    
    if token not in valid_tokens:
        return None
    token_data = valid_tokens[token]
    if datetime.now() > token_data['expires_at']:
        del valid_tokens[token]
        save_tokens()  # Persist after deleting expired token
        return None
    return token_data['username']


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
                    print(f"[TOKEN] Token received: {token[:20]}...{token[-10:]}")
                except (IndexError, AttributeError):
                    print(f"[ERROR] Invalid token format in header: {auth_header}")
                    return {'detail': 'Invalid token format'}, 401
        
        if not token:
            print(f"[ERROR] No token found in Authorization header")
            return {'detail': 'Token is missing'}, 401
        
        print(f"[TOKEN] Validating token... (valid_tokens has {len(valid_tokens)} tokens)")
        username = verify_token(token)
        if not username:
            print(f"[ERROR] Token validation failed - token not found or expired")
            print(f"[TOKEN] Current valid tokens: {list(valid_tokens.keys())[:3]}...")
            return {'detail': 'Invalid or expired token'}, 401
        
        print(f"[OK] Token validated for user: {username}")
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


@app.get("/proposals")
@token_required
def get_proposals(username):
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            print(f"🔍 Looking for proposals for user {username}")
            
            user_id = _resolve_user_id(cursor, username)
            if not user_id:
                print(f"⚠️ Could not resolve numeric ID for {username}, returning empty list")
                return [], 200
            
            # Query using owner_id (the actual column name in the schema)
            # First check what columns actually exist in the proposals table
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'proposals'
            """)
            existing_columns = [row[0] for row in cursor.fetchall()]
            print(f"📋 Available columns in proposals table: {existing_columns}")
            
            # Build query dynamically based on available columns
            if 'owner_id' in existing_columns:
                # Use owner_id (new schema)
                try:
                    # Build SELECT list based on what columns exist
                    select_cols = ['id', 'owner_id', 'title', 'content', 'status']
                    if 'client' in existing_columns:
                        select_cols.append('client')
                    elif 'client_name' in existing_columns:
                        select_cols.append('client_name')
                    if 'created_at' in existing_columns:
                        select_cols.append('created_at')
                    if 'updated_at' in existing_columns:
                        select_cols.append('updated_at')
                    if 'template_key' in existing_columns:
                        select_cols.append('template_key')
                    if 'sections' in existing_columns:
                        select_cols.append('sections')
                    if 'pdf_url' in existing_columns:
                        select_cols.append('pdf_url')
                    
                    query = f'''SELECT {', '.join(select_cols)}
                         FROM proposals WHERE owner_id = %s
                         ORDER BY created_at DESC'''
                    print(f"📋 Query: {query}")
                    cursor.execute(query, (user_id,))
                except Exception as query_error:
                    print(f"⚠️ Query with owner_id failed: {query_error}")
                    import traceback
                    traceback.print_exc()
                    raise
            elif 'user_id' in existing_columns:
                # Use user_id (old schema) - build query based on what columns exist
                print(f"⚠️ Using user_id column (old schema)")
                select_cols = ['id', 'user_id', 'title', 'content', 'status']
                if 'client' in existing_columns:
                    select_cols.append('client')
                elif 'client_name' in existing_columns:
                    select_cols.append('client_name')
                if 'client_email' in existing_columns:
                    select_cols.append('client_email')
                if 'budget' in existing_columns:
                    select_cols.append('budget')
                if 'timeline_days' in existing_columns:
                    select_cols.append('timeline_days')
                if 'created_at' in existing_columns:
                    select_cols.append('created_at')
                if 'updated_at' in existing_columns:
                    select_cols.append('updated_at')
                
                query = f'''SELECT {', '.join(select_cols)}
                   FROM proposals WHERE user_id = %s
                     ORDER BY created_at DESC'''
                print(f"📋 Query: {query}")
                cursor.execute(query, (user_id,))
            else:
                # No user identifier column found - return empty
                print(f"⚠️ No owner_id or user_id column found in proposals table")
                return [], 200
            
            rows = cursor.fetchall()
            # Get column names from cursor description
            column_names = [desc[0] for desc in cursor.description] if cursor.description else []
            print(f"📋 Column names in result: {column_names}")
            
            proposals = []
            for row in rows:
                try:
                    # Convert row to dictionary using column names
                    row_dict = dict(zip(column_names, row))
                    
                    # Safely parse sections JSON
                    sections_data = {}
                    if 'sections' in row_dict and row_dict['sections']:
                        try:
                            if isinstance(row_dict['sections'], str):
                                sections_data = json.loads(row_dict['sections'])
                            elif isinstance(row_dict['sections'], dict):
                                sections_data = row_dict['sections']
                        except (json.JSONDecodeError, TypeError) as json_err:
                            print(f"⚠️ Failed to parse sections JSON for proposal {row_dict.get('id')}: {json_err}")
                            sections_data = {}
                    
                    # Build proposal object with all available fields
                    proposal = {
                        'id': row_dict.get('id'),
                        'title': row_dict.get('title') or '',
                        'content': row_dict.get('content') or '',
                        'status': row_dict.get('status') or 'Draft',
                        'sections': sections_data,
                    }
                    
                    # Handle user/owner ID (both for compatibility)
                    if 'owner_id' in row_dict:
                        proposal['owner_id'] = str(row_dict['owner_id'])
                        proposal['user_id'] = str(row_dict['owner_id'])  # For compatibility
                    elif 'user_id' in row_dict:
                        proposal['user_id'] = str(row_dict['user_id'])
                        proposal['owner_id'] = str(row_dict['user_id'])  # For compatibility
                    
                    # Handle client/client_name
                    if 'client' in row_dict:
                        proposal['client'] = row_dict['client'] or ''
                        proposal['client_name'] = row_dict['client'] or ''
                    elif 'client_name' in row_dict:
                        proposal['client_name'] = row_dict['client_name'] or ''
                        proposal['client'] = row_dict['client_name'] or ''
                    else:
                        proposal['client'] = ''
                        proposal['client_name'] = ''
                    
                    # Handle client_email (may not exist)
                    proposal['client_email'] = row_dict.get('client_email') or ''
                    
                    # Handle budget and timeline_days (may not exist)
                    if 'budget' in row_dict:
                        try:
                            proposal['budget'] = float(row_dict['budget']) if row_dict['budget'] else None
                        except (ValueError, TypeError):
                            proposal['budget'] = None
                    else:
                        proposal['budget'] = None
                    
                    proposal['timeline_days'] = row_dict.get('timeline_days')
                    
                    # Handle timestamps
                    if 'created_at' in row_dict and row_dict['created_at']:
                        proposal['created_at'] = row_dict['created_at'].isoformat() if hasattr(row_dict['created_at'], 'isoformat') else str(row_dict['created_at'])
                    else:
                        proposal['created_at'] = None
                    
                    if 'updated_at' in row_dict and row_dict['updated_at']:
                        proposal['updated_at'] = row_dict['updated_at'].isoformat() if hasattr(row_dict['updated_at'], 'isoformat') else str(row_dict['updated_at'])
                        proposal['updatedAt'] = proposal['updated_at']  # For compatibility
                    else:
                        proposal['updated_at'] = None
                        proposal['updatedAt'] = None
                    
                    # Handle optional fields
                    proposal['template_key'] = row_dict.get('template_key')
                    proposal['pdf_url'] = row_dict.get('pdf_url')
                    
                    proposals.append(proposal)
                except Exception as row_error:
                    print(f"⚠️ Error processing proposal row: {row_error}")
                    import traceback
                    traceback.print_exc()
                    continue  # Skip this row and continue with others
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
            
            user_id = _resolve_user_id(cursor, username)
            if not user_id:
                return {'detail': f"User '{username}' not found"}, 400

            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'proposals'
            """)
            proposal_columns = {row[0] for row in cursor.fetchall()}

            client_name = data.get('client_name') or data.get('client') or 'Unknown Client'
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
                'client': data.get('client'),
                'client_email': data.get('client_email'),
                'budget': data.get('budget'),
                'timeline_days': data.get('timeline_days'),
                'sections': json.dumps(data.get('sections') or {}) if 'sections' in proposal_columns else None,
                'template_key': data.get('template_key'),
                'pdf_url': data.get('pdf_url'),
                'client_can_edit': data.get('client_can_edit'),
                'client_id': data.get('client_id'),
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

            cursor.execute(insert_sql, tuple(values))
            result = cursor.fetchone()
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
                'budget': float(result['budget']) if result.get('budget') is not None else None,
                'timeline_days': result.get('timeline_days'),
                'created_at': result['created_at'].isoformat() if result.get('created_at') else None,
                'updated_at': result['updated_at'].isoformat() if result.get('updated_at') else None,
                'updatedAt': result['updated_at'].isoformat() if result.get('updated_at') else None,
                'sections': section_data,
                'template_key': result.get('template_key'),
                'pdf_url': result.get('pdf_url'),
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
            # NOTE: We intentionally support a superset of fields so the
            #       Flutter editor can send rich proposal data.
            if 'title' in data:
                updates.append('title = %s')
                params.append(data['title'])
            if 'content' in data:
                updates.append('content = %s')
                params.append(data['content'])
            # Allow updating structured sections JSON used by the new editor
            if 'sections' in data:
                updates.append('sections = %s')
                # Store as JSON string for compatibility with existing readers
                try:
                    sections_json = json.dumps(data['sections'])
                except Exception:
                    # If it's already a JSON string or something unexpected,
                    # fall back to str() to avoid crashing the request.
                    sections_json = str(data['sections'])
                params.append(sections_json)
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

            # Get current user's ID from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            if not user:
                return {'detail': 'User not found'}, 404

            user_id = user[0]

            # Check if proposal exists and belongs to user
            cursor.execute(
                'SELECT id, title, status FROM proposals WHERE id = %s AND user_id = %s',
                (proposal_id, user_id)
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
                        # Get user ID for the invitation
                        cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                        user = cursor.fetchone()
                        user_id = user[0] if user else None
                        
                        # Generate secure access token for collaboration
                        access_token = secrets.token_urlsafe(32)
                        expires_at = datetime.now() + timedelta(days=90)  # 90 days for client access
                        
                        # Create collaboration invitation for the client
                        cursor.execute("""
                            INSERT INTO collaboration_invitations 
                            (proposal_id, invited_email, invited_by, access_token, permission_level, expires_at)
                            VALUES (%s, %s, %s, %s, %s, %s)
                            ON CONFLICT DO NOTHING
                        """, (proposal_id, client_email, user_id, access_token, 'view', expires_at))
                        conn.commit()
                        
                        frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                        proposal_url = f"{frontend_url}/#/collaborate?token={access_token}"
                        
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
                                    This secure link will remain active for 90 days.<br>
                                    This is an automated message. Please do not reply to this email.
                                </p>
                            </div>
                        </body>
                        </html>
                        """
                        
                        send_email(
                            to_email=client_email,
                            subject=f"Proposal Approved: {title}",
                            html_content=email_body
                        )
                        print(f"[SUCCESS] Email sent to client: {client_email} with collaboration token")
                    except Exception as email_error:
                        print(f"[WARN] Could not send email to client: {email_error}")
                        import traceback
                        traceback.print_exc()
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
                SELECT p.id, p.title, p.status, p.created_at, p.updated_at, p.client_name, p.client_email
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
            
            # Get proposal details
            cursor.execute("""
                SELECT p.id, p.title, p.content, p.status, p.created_at, p.updated_at,
                       p.client_name, p.client_email, p.user_id,
                       u.full_name as owner_name, u.email as owner_email
                FROM proposals p
                LEFT JOIN users u ON p.user_id = u.username
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
# COLLABORATION ADVANCED ENDPOINTS - Suggest Mode & Section Locking
# ============================================================================

@app.post("/api/proposals/<int:proposal_id>/suggestions")
@token_required
def create_suggestion(username, proposal_id):
    """Create a suggested change (for reviewers with suggest permission)"""
    try:
        data = request.get_json()
        section_id = data.get('section_id')
        suggestion_text = data.get('suggestion_text')
        original_text = data.get('original_text', '')
        
        if not suggestion_text:
            return {'detail': 'Suggestion text is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id, email, full_name FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Verify user has access to this proposal
            cursor.execute("""
                SELECT ci.permission_level
                FROM collaboration_invitations ci
                WHERE ci.proposal_id = %s 
                AND ci.invited_email = %s
                AND ci.status = 'accepted'
            """, (proposal_id, current_user['email']))
            
            invitation = cursor.fetchone()
            if not invitation or invitation['permission_level'] not in ['suggest', 'edit']:
                return {'detail': 'Insufficient permissions'}, 403
            
            # Create suggestion
            cursor.execute("""
                INSERT INTO suggested_changes 
                (proposal_id, section_id, suggested_by, suggestion_text, original_text, status)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, created_at
            """, (proposal_id, section_id, current_user['id'], suggestion_text, original_text, 'pending'))
            
            result = cursor.fetchone()
            conn.commit()
            
            # Log activity
            log_activity(
                proposal_id,
                current_user['id'],
                'suggestion_created',
                f"{current_user.get('full_name', current_user['email'])} suggested a change{' to ' + section_id if section_id else ''}",
                {'suggestion_id': result['id'], 'section_id': section_id}
            )
            
            # Notify proposal owner and collaborators
            notify_proposal_collaborators(
                proposal_id,
                'suggestion_created',
                'New Suggestion',
                f"{current_user.get('full_name', current_user['email'])} suggested a change{' to ' + section_id if section_id else ''}",
                exclude_user_id=current_user['id'],
                metadata={'suggestion_id': result['id'], 'section_id': section_id}
            )
            
            print(f"✅ Suggestion created by {current_user['email']} for proposal {proposal_id}")
            
            return {
                'id': result['id'],
                'created_at': result['created_at'].isoformat() if result['created_at'] else None,
                'message': 'Suggestion created successfully'
            }, 201
            
    except Exception as e:
        print(f"❌ Error creating suggestion: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/proposals/<int:proposal_id>/suggestions")
@token_required
def get_suggestions(username, proposal_id):
    """Get all suggestions for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details (not strictly needed here but for consistency)
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            cursor.execute("""
                SELECT sc.*, 
                       u.full_name as suggested_by_name,
                       u.email as suggested_by_email,
                       r.full_name as resolved_by_name
                FROM suggested_changes sc
                LEFT JOIN users u ON sc.suggested_by = u.id
                LEFT JOIN users r ON sc.resolved_by = r.id
                WHERE sc.proposal_id = %s
                ORDER BY sc.created_at DESC
            """, (proposal_id,))
            
            suggestions = cursor.fetchall()
            
            return {
                'suggestions': [dict(s) for s in suggestions]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting suggestions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/proposals/<int:proposal_id>/suggestions/<int:suggestion_id>/resolve")
@token_required
def resolve_suggestion(username, proposal_id, suggestion_id):
    """Accept or reject a suggestion (proposal owner only)"""
    try:
        data = request.get_json()
        action = data.get('action')  # 'accept' or 'reject'
        
        if action not in ['accept', 'reject']:
            return {'detail': 'Action must be accept or reject'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id, email, full_name FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Verify user owns the proposal
            cursor.execute("""
                SELECT user_id FROM proposals WHERE id = %s
            """, (proposal_id,))
            
            proposal = cursor.fetchone()
            if not proposal or proposal['user_id'] != username:
                return {'detail': 'Only proposal owner can resolve suggestions'}, 403
            
            # Update suggestion
            cursor.execute("""
                UPDATE suggested_changes
                SET status = %s,
                    resolved_at = NOW(),
                    resolved_by = %s,
                    resolution_action = %s
                WHERE id = %s AND proposal_id = %s
                RETURNING id
            """, ('accepted' if action == 'accept' else 'rejected', 
                  current_user['id'], action, suggestion_id, proposal_id))
            
            result = cursor.fetchone()
            if not result:
                return {'detail': 'Suggestion not found'}, 404
            
            conn.commit()
            
            # Log activity
            log_activity(
                proposal_id,
                current_user['id'],
                f'suggestion_{action}ed',
                f"{current_user.get('full_name', current_user['email'])} {action}ed a suggestion",
                {'suggestion_id': suggestion_id, 'action': action}
            )
            
            # Notify the suggestion creator
            cursor.execute("SELECT suggested_by FROM suggested_changes WHERE id = %s", (suggestion_id,))
            suggestion_creator = cursor.fetchone()
            if suggestion_creator and suggestion_creator['suggested_by'] != current_user['id']:
                create_notification(
                    suggestion_creator['suggested_by'],
                    f'suggestion_{action}ed',
                    f'Suggestion {action.title()}ed',
                    f"Your suggestion was {action}ed by {current_user.get('full_name', current_user['email'])}",
                    proposal_id,
                    {'suggestion_id': suggestion_id, 'action': action}
                )
            
            print(f"✅ Suggestion {suggestion_id} {action}ed by {current_user['email']}")
            
            return {
                'message': f'Suggestion {action}ed successfully',
                'suggestion_id': suggestion_id,
                'action': action
            }, 200
            
    except Exception as e:
        print(f"❌ Error resolving suggestion: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/proposals/<int:proposal_id>/sections/<section_id>/lock")
@token_required
def lock_section(username, proposal_id, section_id):
    """Lock a section for editing (soft lock)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id, full_name FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Check if section is already locked
            cursor.execute("""
                SELECT locked_by, expires_at, u.full_name
                FROM section_locks sl
                LEFT JOIN users u ON sl.locked_by = u.id
                WHERE proposal_id = %s AND section_id = %s
                AND (expires_at IS NULL OR expires_at > NOW())
            """, (proposal_id, section_id))
            
            existing_lock = cursor.fetchone()
            if existing_lock and existing_lock['locked_by'] != current_user['id']:
                return {
                    'locked': True,
                    'locked_by': existing_lock['full_name'],
                    'message': f"Section is being edited by {existing_lock['full_name']}"
                }, 409
            
            # Create or update lock (expires in 5 minutes)
            expires_at = datetime.now() + timedelta(minutes=5)
            cursor.execute("""
                INSERT INTO section_locks (proposal_id, section_id, locked_by, expires_at)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (proposal_id, section_id) 
                DO UPDATE SET locked_by = %s, locked_at = NOW(), expires_at = %s
                RETURNING id
            """, (proposal_id, section_id, current_user['id'], expires_at,
                  current_user['id'], expires_at))
            
            conn.commit()
            
            return {
                'locked': True,
                'locked_by': current_user['full_name'],
                'expires_at': expires_at.isoformat()
            }, 200
            
    except Exception as e:
        print(f"❌ Error locking section: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/proposals/<int:proposal_id>/sections/<section_id>/unlock")
@token_required
def unlock_section(username, proposal_id, section_id):
    """Unlock a section"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            cursor.execute("""
                DELETE FROM section_locks
                WHERE proposal_id = %s AND section_id = %s AND locked_by = %s
                RETURNING id
            """, (proposal_id, section_id, current_user['id']))
            
            result = cursor.fetchone()
            conn.commit()
            
            if result:
                return {'message': 'Section unlocked'}, 200
            else:
                return {'message': 'No lock found or not owned by you'}, 404
            
    except Exception as e:
        print(f"❌ Error unlocking section: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/proposals/<int:proposal_id>/sections/locks")
@token_required
def get_section_locks(username, proposal_id):
    """Get all active section locks for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT sl.section_id, sl.locked_by, sl.locked_at, sl.expires_at,
                       u.full_name as locked_by_name, u.email as locked_by_email
                FROM section_locks sl
                LEFT JOIN users u ON sl.locked_by = u.id
                WHERE sl.proposal_id = %s
                AND (sl.expires_at IS NULL OR sl.expires_at > NOW())
            """, (proposal_id,))
            
            locks = cursor.fetchall()
            
            return {
                'locks': [dict(lock) for lock in locks]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting section locks: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/notifications")
@token_required
def get_notifications(username):
    """Get all notifications for current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Get user's notifications
            cursor.execute("""
                SELECT n.*, p.title as proposal_title
                FROM notifications n
                LEFT JOIN proposals p ON n.proposal_id = p.id
                WHERE n.user_id = %s
                ORDER BY n.created_at DESC
                LIMIT 50
            """, (current_user['id'],))
            
            notifications = cursor.fetchall()
            
            # Get unread count
            cursor.execute("""
                SELECT COUNT(*) as unread_count
                FROM notifications
                WHERE user_id = %s AND is_read = FALSE
            """, (current_user['id'],))
            
            unread_count = cursor.fetchone()['unread_count']
            
            return {
                'notifications': [dict(n) for n in notifications],
                'unread_count': unread_count
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting notifications: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/notifications/<int:notification_id>/mark-read")
@token_required
def mark_notification_read(username, notification_id):
    """Mark a notification as read"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            cursor.execute("""
                UPDATE notifications
                SET is_read = TRUE, read_at = NOW()
                WHERE id = %s AND user_id = %s
            """, (notification_id, current_user['id']))
            
            conn.commit()
            
            return {'message': 'Notification marked as read'}, 200
            
    except Exception as e:
        print(f"❌ Error marking notification as read: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/notifications/mark-all-read")
@token_required
def mark_all_notifications_read(username):
    """Mark all notifications as read for current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            cursor.execute("""
                UPDATE notifications
                SET is_read = TRUE, read_at = NOW()
                WHERE user_id = %s AND is_read = FALSE
            """, (current_user['id'],))
            
            conn.commit()
            
            return {'message': 'All notifications marked as read'}, 200
            
    except Exception as e:
        print(f"❌ Error marking all notifications as read: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/mentions")
@token_required
def get_user_mentions(username):
    """Get all mentions for current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Get mentions with comment details
            cursor.execute("""
                SELECT cm.*, 
                       dc.comment_text, dc.proposal_id, dc.section_index,
                       u.full_name as mentioned_by_name, u.email as mentioned_by_email,
                       p.title as proposal_title
                FROM comment_mentions cm
                JOIN document_comments dc ON cm.comment_id = dc.id
                JOIN users u ON cm.mentioned_by_user_id = u.id
                LEFT JOIN proposals p ON dc.proposal_id = p.id
                WHERE cm.mentioned_user_id = %s
                ORDER BY cm.created_at DESC
                LIMIT 50
            """, (current_user['id'],))
            
            mentions = cursor.fetchall()
            
            # Get unread count
            cursor.execute("""
                SELECT COUNT(*) as unread_count
                FROM comment_mentions
                WHERE mentioned_user_id = %s AND is_read = FALSE
            """, (current_user['id'],))
            
            unread_count = cursor.fetchone()['unread_count']
            
            return {
                'mentions': [dict(m) for m in mentions],
                'unread_count': unread_count
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting mentions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/mentions/<int:mention_id>/mark-read")
@token_required
def mark_mention_read(username, mention_id):
    """Mark a mention as read"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            cursor.execute("""
                UPDATE comment_mentions
                SET is_read = TRUE
                WHERE id = %s AND mentioned_user_id = %s
            """, (mention_id, current_user['id']))
            
            conn.commit()
            
            return {'message': 'Mention marked as read'}, 200
            
    except Exception as e:
        print(f"❌ Error marking mention as read: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/proposals/<int:proposal_id>/activity")
@token_required
def get_activity_timeline(username, proposal_id):
    """Get comprehensive activity timeline for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id, email FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Verify user has access to this proposal
            cursor.execute("""
                SELECT p.id FROM proposals p
                LEFT JOIN collaboration_invitations ci ON p.id = ci.proposal_id
                WHERE p.id = %s 
                AND (p.user_id = %s OR ci.invited_email = %s)
            """, (proposal_id, username, current_user['email']))
            
            if not cursor.fetchone():
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Get all activities from activity_log table
            cursor.execute("""
                SELECT al.*, u.full_name as user_name, u.email as user_email
                FROM activity_log al
                LEFT JOIN users u ON al.user_id = u.id
                WHERE al.proposal_id = %s
                ORDER BY al.created_at DESC
                LIMIT 100
            """, (proposal_id,))
            
            activities = cursor.fetchall()
            
            return {
                'activities': [dict(activity) for activity in activities]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting activity timeline: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/proposals/<int:proposal_id>/versions/compare")
@token_required
def compare_proposal_versions(username, proposal_id):
    """Compare two versions of a proposal and return diff"""
    try:
        version1 = request.args.get('version1', type=int)
        version2 = request.args.get('version2', type=int)
        
        if not version1 or not version2:
            return {'detail': 'Both version1 and version2 parameters are required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id, email FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Verify user has access to this proposal
            cursor.execute("""
                SELECT p.id FROM proposals p
                LEFT JOIN collaboration_invitations ci ON p.id = ci.proposal_id
                WHERE p.id = %s 
                AND (p.user_id = %s OR ci.invited_email = %s)
            """, (proposal_id, username, current_user['email']))
            
            if not cursor.fetchone():
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Get both versions
            cursor.execute("""
                SELECT id, version_number, content, created_at, created_by,
                       u.full_name as created_by_name
                FROM proposal_versions pv
                LEFT JOIN users u ON pv.created_by = u.id
                WHERE proposal_id = %s AND version_number IN (%s, %s)
                ORDER BY version_number
            """, (proposal_id, version1, version2))
            
            versions = cursor.fetchall()
            
            if len(versions) != 2:
                return {'detail': 'One or both versions not found'}, 404
            
            # Parse JSON content
            v1_content = json.loads(versions[0]['content']) if isinstance(versions[0]['content'], str) else versions[0]['content']
            v2_content = json.loads(versions[1]['content']) if isinstance(versions[1]['content'], str) else versions[1]['content']
            
            # Convert to text for comparison
            v1_text = json.dumps(v1_content, indent=2, sort_keys=True)
            v2_text = json.dumps(v2_content, indent=2, sort_keys=True)
            
            # Generate diff using difflib
            diff = difflib.unified_diff(
                v1_text.splitlines(keepends=True),
                v2_text.splitlines(keepends=True),
                fromfile=f'Version {version1}',
                tofile=f'Version {version2}',
                lineterm=''
            )
            
            # Generate HTML diff for better visualization
            html_diff = difflib.HtmlDiff()
            html_diff_output = html_diff.make_table(
                v1_text.splitlines(),
                v2_text.splitlines(),
                fromdesc=f'Version {version1} ({versions[0]["created_at"]})',
                todesc=f'Version {version2} ({versions[1]["created_at"]})',
                context=True,
                numlines=3
            )
            
            # Calculate statistics
            changes = {
                'additions': 0,
                'deletions': 0,
                'modifications': 0
            }
            
            for line in difflib.unified_diff(v1_text.splitlines(), v2_text.splitlines(), lineterm=''):
                if line.startswith('+') and not line.startswith('+++'):
                    changes['additions'] += 1
                elif line.startswith('-') and not line.startswith('---'):
                    changes['deletions'] += 1
            
            return {
                'version1': {
                    'version_number': versions[0]['version_number'],
                    'created_at': versions[0]['created_at'].isoformat() if versions[0]['created_at'] else None,
                    'created_by': versions[0]['created_by_name']
                },
                'version2': {
                    'version_number': versions[1]['version_number'],
                    'created_at': versions[1]['created_at'].isoformat() if versions[1]['created_at'] else None,
                    'created_by': versions[1]['created_by_name']
                },
                'diff': '\n'.join(diff),
                'html_diff': html_diff_output,
                'changes': changes
            }, 200
            
    except Exception as e:
        print(f"❌ Error comparing versions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# ============================================================================
# DOCUSIGN E-SIGNATURE ENDPOINTS
# ============================================================================

@app.post("/api/proposals/<int:proposal_id>/docusign/send")
@token_required
def send_for_signature(username, proposal_id):
    """Send proposal for DocuSign signature (embedded signing)"""
    try:
        if not DOCUSIGN_AVAILABLE:
            return {'detail': 'DocuSign integration not available. Please install docusign-esign package.'}, 503
        
        data = request.get_json()
        signer_name = data.get('signer_name')
        signer_email = data.get('signer_email')
        signer_title = data.get('signer_title', '')
        return_url = data.get('return_url', 'http://localhost:8081')
        
        if not signer_name or not signer_email:
            return {'detail': 'Signer name and email are required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Verify user owns the proposal
            cursor.execute("""
                SELECT id, title, content FROM proposals 
                WHERE id = %s AND user_id = %s
            """, (proposal_id, username))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Generate PDF from proposal content
            pdf_content = generate_proposal_pdf(
                proposal_id=proposal_id,
                title=proposal['title'],
                content=proposal.get('content', ''),
                client_name=proposal.get('client_name'),
                client_email=proposal.get('client_email')
            )
            
            # Create DocuSign envelope
            envelope_result = create_docusign_envelope(
                proposal_id=proposal_id,
                pdf_bytes=pdf_content,
                signer_name=signer_name,
                signer_email=signer_email,
                signer_title=signer_title,
                return_url=return_url
            )
            
            # Store signature record
            cursor.execute("""
                INSERT INTO proposal_signatures 
                (proposal_id, envelope_id, signer_name, signer_email, signer_title, 
                 signing_url, status, created_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id, sent_at
            """, (proposal_id, envelope_result['envelope_id'], signer_name, signer_email, 
                  signer_title, envelope_result['signing_url'], 'sent', current_user['id']))
            
            signature_record = cursor.fetchone()
            conn.commit()
            
            # Log activity
            log_activity(
                proposal_id,
                current_user['id'],
                'signature_requested',
                f"Proposal sent to {signer_name} for signature",
                {'envelope_id': envelope_result['envelope_id'], 'signer_email': signer_email}
            )
            
            # Update proposal status
            cursor.execute("""
                UPDATE proposals 
                SET status = 'Sent for Signature', updated_at = NOW()
                WHERE id = %s
            """, (proposal_id,))
            conn.commit()
            
            print(f"✅ Proposal {proposal_id} sent for signature to {signer_email}")
            
            return {
                'envelope_id': envelope_result['envelope_id'],
                'signing_url': envelope_result['signing_url'],
                'signature_id': signature_record['id'],
                'sent_at': signature_record['sent_at'].isoformat() if signature_record['sent_at'] else None,
                'message': 'Envelope created successfully'
            }, 200
            
    except Exception as e:
        print(f"❌ Error sending for signature: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.get("/api/proposals/<int:proposal_id>/signatures")
@token_required
def get_proposal_signatures(username, proposal_id):
    """Get all signatures for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user details
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            current_user = cursor.fetchone()
            if not current_user:
                return {'detail': 'User not found'}, 404
            
            # Verify access
            cursor.execute("""
                SELECT id FROM proposals 
                WHERE id = %s AND user_id = %s
            """, (proposal_id, username))
            
            if not cursor.fetchone():
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Get signatures
            cursor.execute("""
                SELECT ps.*, u.full_name as created_by_name
                FROM proposal_signatures ps
                LEFT JOIN users u ON ps.created_by = u.id
                WHERE ps.proposal_id = %s
                ORDER BY ps.sent_at DESC
            """, (proposal_id,))
            
            signatures = cursor.fetchall()
            
            return {
                'signatures': [dict(sig) for sig in signatures]
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting signatures: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@app.post("/api/docusign/webhook")
def docusign_webhook():
    """Handle DocuSign webhook events"""
    try:
        # Get event data
        event_data = request.get_json()
        
        # Validate HMAC signature (if configured)
        hmac_key = os.getenv('DOCUSIGN_WEBHOOK_HMAC_KEY')
        if hmac_key:
            signature = request.headers.get('X-DocuSign-Signature-1')
            # TODO: Validate signature
        
        event = event_data.get('event')
        envelope_id = event_data.get('envelopeId')
        
        if not envelope_id:
            return {'detail': 'No envelope ID provided'}, 400
        
        print(f"📬 DocuSign webhook received: {event} for envelope {envelope_id}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Find signature record
            cursor.execute("""
                SELECT id, proposal_id, signer_email
                FROM proposal_signatures 
                WHERE envelope_id = %s
            """, (envelope_id,))
            
            signature = cursor.fetchone()
            if not signature:
                print(f"⚠️ Signature record not found for envelope {envelope_id}")
                return {'message': 'Signature record not found'}, 404
            
            # Handle different events
            if event == 'envelope-completed':
                # Signature completed
                cursor.execute("""
                    UPDATE proposal_signatures 
                    SET status = 'completed', signed_at = NOW()
                    WHERE envelope_id = %s
                """, (envelope_id,))
                
                cursor.execute("""
                    UPDATE proposals 
                    SET status = 'Signed', updated_at = NOW()
                    WHERE id = %s
                """, (signature['proposal_id'],))
                
                log_activity(
                    signature['proposal_id'],
                    None,
                    'signature_completed',
                    f"Proposal signed by {signature['signer_email']}",
                    {'envelope_id': envelope_id}
                )
                
                print(f"✅ Envelope {envelope_id} completed")
                
            elif event == 'envelope-declined':
                # Signature declined
                decline_reason = event_data.get('declineReason', 'No reason provided')
                
                cursor.execute("""
                    UPDATE proposal_signatures 
                    SET status = 'declined', declined_at = NOW(), decline_reason = %s
                    WHERE envelope_id = %s
                """, (decline_reason, envelope_id))
                
                cursor.execute("""
                    UPDATE proposals 
                    SET status = 'Signature Declined', updated_at = NOW()
                    WHERE id = %s
                """, (signature['proposal_id'],))
                
                log_activity(
                    signature['proposal_id'],
                    None,
                    'signature_declined',
                    f"Signature declined by {signature['signer_email']}: {decline_reason}",
                    {'envelope_id': envelope_id}
                )
                
                print(f"⚠️ Envelope {envelope_id} declined")
                
            elif event == 'envelope-voided':
                # Envelope voided
                cursor.execute("""
                    UPDATE proposal_signatures 
                    SET status = 'voided'
                    WHERE envelope_id = %s
                """, (envelope_id,))
                
                print(f"⚠️ Envelope {envelope_id} voided")
            
            conn.commit()
        
        return {'message': 'Webhook processed successfully'}, 200
        
    except Exception as e:
        print(f"❌ Error processing DocuSign webhook: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# ============================================================================
# END DOCUSIGN ENDPOINTS
# ============================================================================

# ============================================================================
# END COLLABORATION ADVANCED ENDPOINTS
# ============================================================================

# ============================================================
# CLIENT MANAGEMENT ENDPOINTS
# ============================================================

def _get_logo_html():
    """Generate HTML for Khonology logo in email template"""
    # Try to use logo URL from environment variable first
    logo_url = os.getenv('KHONOLOGY_LOGO_URL', '')
    
    if logo_url:
        # Use hosted logo URL
        return f'<img src="{logo_url}" alt="Khonology" style="max-width: 200px; height: auto; display: block; margin: 0 auto;" />'
    
    # Try to embed logo as base64 from local file
    logo_path = Path(__file__).parent.parent / 'frontend_flutter' / 'assets' / 'images' / '2026.png'
    
    if logo_path.exists():
        try:
            with open(logo_path, 'rb') as f:
                logo_data = base64.b64encode(f.read()).decode('utf-8')
                return f'<img src="data:image/png;base64,{logo_data}" alt="Khonology" style="max-width: 200px; height: auto; display: block; margin: 0 auto;" />'
        except Exception as e:
            print(f"[WARN] Could not embed logo as base64: {e}")
    
    # Fallback to text logo
    return '<h1 style="margin: 0; font-family: \'Poppins\', Arial, sans-serif; font-size: 32px; font-weight: bold; color: #FFFFFF; letter-spacing: -0.5px;">✕ Khonology</h1>'

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

@app.post("/onboard/<token>/verify-email")
def send_verification_code(token):
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

# Verify email code (PUBLIC - no auth)
@app.post("/onboard/<token>/verify-code")
def verify_email_code(token):
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

# Get onboarding form (PUBLIC - no auth)
@app.get("/onboard/<token>")
def get_onboarding_form(token):
    """Get onboarding form details by token (public endpoint)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT id, invited_email, expected_company, status, expires_at
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
            is_verified = verified and verified['email_verified_at']
            
            return jsonify({
                "invited_email": invitation['invited_email'],
                "expected_company": invitation['expected_company'],
                "expires_at": invitation['expires_at'].isoformat(),
                "email_verified": bool(is_verified)
            }), 200
            
    except Exception as e:
        print(f"❌ Error getting onboarding form: {e}")
        return jsonify({"error": str(e)}), 500

# Submit onboarding (PUBLIC - no auth)
@app.post("/onboard/<token>")
def submit_onboarding(token):
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
            
            # Get all clients
            cursor.execute("""
                SELECT 
                    id, company_name, contact_person, email, phone,
                    industry, company_size, location, business_type,
                    project_needs, budget_range, timeline, additional_info,
                    status, created_at, updated_at
                FROM clients
                WHERE created_by = %s
                ORDER BY created_at DESC
            """, (user_id,))
            
            clients = cursor.fetchall()
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
