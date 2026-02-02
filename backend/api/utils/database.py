"""
Database connection and schema utilities
"""
import os
import psycopg2
import psycopg2.extras
import psycopg2.pool
from contextlib import contextmanager

# PostgreSQL connection pool
_pg_pool = None
_db_initialized = False


def get_pg_pool():
    """Get or create PostgreSQL connection pool"""
    global _pg_pool
    if _pg_pool is None:
        try:
            # Prefer DATABASE_URL when available (Render/prod style).
            # This prevents accidentally using localhost when DB_* vars aren't set.
            db_url = os.getenv("DATABASE_URL")
            if db_url:
                sslmode = os.getenv("DB_SSLMODE") or os.getenv("DB_SSL_MODE")
                if sslmode and "sslmode=" not in db_url:
                    joiner = "&" if "?" in db_url else "?"
                    db_url = f"{db_url}{joiner}sslmode={sslmode}"
                print("[*] Connecting to PostgreSQL via DATABASE_URL")
                _pg_pool = psycopg2.pool.SimpleConnectionPool(
                    minconn=1,
                    maxconn=20,
                    dsn=db_url,
                )
            else:
                db_config = {
                    'host': os.getenv('DB_HOST', 'localhost'),
                    'database': os.getenv('DB_NAME', 'proposal_db'),
                    'user': os.getenv('DB_USER', 'postgres'),
                    'password': os.getenv('DB_PASSWORD', ''),
                    'port': int(os.getenv('DB_PORT', '5432')),
                }
                
                # Add SSL mode for external connections (like Render)
                # Check if host contains 'render.com' or SSL is explicitly required
                ssl_mode = os.getenv('DB_SSLMODE', 'prefer')
                if 'render.com' in db_config['host'].lower() or os.getenv('DB_REQUIRE_SSL', 'false').lower() == 'true':
                    ssl_mode = 'require'
                    db_config['sslmode'] = ssl_mode
                    print(f"[*] Using SSL mode: {ssl_mode} for external connection")
                
                print(f"[*] Connecting to PostgreSQL: {db_config['host']}:{db_config['port']}/{db_config['database']}")
                _pg_pool = psycopg2.pool.SimpleConnectionPool(
                    minconn=1,
                    maxconn=20,
                    **db_config,
                )
            print("[OK] PostgreSQL connection pool created successfully")
        except Exception as exc:
            print(f"[ERROR] Error creating PostgreSQL connection pool: {exc}")
            raise
    return _pg_pool


def _pg_conn():
    """Get a connection from the pool with retry logic for SSL errors"""
    max_retries = 3
    for attempt in range(max_retries):
        try:
            conn = get_pg_pool().getconn()

            # If the previous user of this connection left it in a transaction
            # (or error state), clean it up *before* issuing any SQL.
            try:
                import psycopg2.extensions as ext
                tx_status = conn.get_transaction_status()
                if tx_status in (
                    ext.TRANSACTION_STATUS_INTRANS,
                    ext.TRANSACTION_STATUS_INERROR,
                ):
                    conn.rollback()
            except Exception:
                pass

            # Test the connection is still alive
            cursor = conn.cursor()
            cursor.execute('SELECT 1')
            cursor.close()
            return conn
        except (psycopg2.OperationalError, psycopg2.InterfaceError) as exc:
            if attempt < max_retries - 1:
                print(f"[WARN] Connection error (attempt {attempt + 1}/{max_retries}): {exc}. Retrying...")
                import time
                time.sleep(0.1)
                # Try to close the bad connection if we got one
                try:
                    if 'conn' in locals():
                        conn.close()
                except:
                    pass
            else:
                print(f"[ERROR] Error getting PostgreSQL connection after {max_retries} attempts: {exc}")
                raise
        except Exception as exc:
            print(f"[ERROR] Error getting PostgreSQL connection: {exc}")
            raise


def release_pg_conn(conn):
    """Return a connection to the pool, resetting its state and closing it if corrupted"""
    try:
        if conn:
            # Check if connection is still valid and reset its state before returning to pool
            try:
                # Check if connection is in a transaction and rollback if needed
                import psycopg2.extensions as ext
                tx_status = conn.get_transaction_status()
                if tx_status in (
                    ext.TRANSACTION_STATUS_INTRANS,
                    ext.TRANSACTION_STATUS_INERROR,
                ):
                    print(f"[DB] Connection in transaction, rolling back before returning to pool")
                    conn.rollback()
                
                # Reset autocommit to default state (False)
                conn.autocommit = False
                
                # Verify connection is still alive
                cursor = conn.cursor()
                cursor.execute('SELECT 1')
                cursor.close()
                
                # Connection is clean and valid, return to pool
                get_pg_pool().putconn(conn)
            except (psycopg2.OperationalError, psycopg2.InterfaceError):
                # Connection is corrupted, close it instead of returning to pool
                print(f"[WARN] Connection corrupted, closing instead of returning to pool")
                try:
                    conn.close()
                except:
                    pass
    except Exception as exc:
        print(f"[WARN] Error releasing PostgreSQL connection: {exc}")
        # Try to close the connection if we can't return it
        try:
            if conn:
                conn.close()
        except:
            pass


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


def init_pg_schema():
    """Initialize PostgreSQL schema"""
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
        
        # Add is_email_verified column if it doesn't exist (migration for existing databases)
        try:
            cursor.execute('''
                ALTER TABLE users 
                ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN DEFAULT true
            ''')
        except Exception as e:
            print(f"[WARN] Could not add is_email_verified column (may already exist): {e}")

        try:
            cursor.execute('''
                ALTER TABLE users
                ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(255)
            ''')
        except Exception as e:
            print(f"[WARN] Could not add firebase_uid column (may already exist): {e}")

        try:
            cursor.execute('''
                CREATE UNIQUE INDEX IF NOT EXISTS users_firebase_uid_unique
                ON users(firebase_uid)
                WHERE firebase_uid IS NOT NULL
            ''')
        except Exception as e:
            print(f"[WARN] Could not create users_firebase_uid_unique index: {e}")

        # Proposals table
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

        # Ensure client_email column exists for storing client contact email
        try:
            cursor.execute('''
                ALTER TABLE proposals 
                ADD COLUMN IF NOT EXISTS client_email VARCHAR(255)
            ''')
        except Exception as e:
            print(f"[WARN] Could not add client_email column to proposals (may already exist or be incompatible): {e}")

        # Content library table
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

        # Settings table
        cursor.execute('''CREATE TABLE IF NOT EXISTS settings (
        id SERIAL PRIMARY KEY,
        key VARCHAR(255) UNIQUE NOT NULL,
        value TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )''')

        # Clients table for client management
        cursor.execute('''CREATE TABLE IF NOT EXISTS clients (
        id SERIAL PRIMARY KEY,
        company_name VARCHAR(255) NOT NULL,
        contact_person VARCHAR(255),
        email VARCHAR(255) UNIQUE NOT NULL,
        phone VARCHAR(100),
        industry VARCHAR(255),
        company_size VARCHAR(100),
        location VARCHAR(255),
        business_type VARCHAR(255),
        project_needs TEXT,
        budget_range VARCHAR(100),
        timeline VARCHAR(255),
        additional_info TEXT,
        status VARCHAR(50) DEFAULT 'active',
        onboarding_token VARCHAR(255),
        created_by INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (created_by) REFERENCES users(id)
        )''')
        
        # Add company_name column if it doesn't exist (migration for existing databases)
        try:
            cursor.execute('''
                ALTER TABLE clients 
                ADD COLUMN IF NOT EXISTS company_name VARCHAR(255)
            ''')
            # If column was just added and is NULL, set a default value
            cursor.execute('''
                UPDATE clients 
                SET company_name = COALESCE(email, 'Unknown Company')
                WHERE company_name IS NULL
            ''')
            # Then make it NOT NULL if it's safe
            try:
                cursor.execute('''
                    ALTER TABLE clients 
                    ALTER COLUMN company_name SET NOT NULL
                ''')
            except Exception:
                # If there are still NULLs, just leave it nullable
                pass
        except Exception as e:
            print(f"[WARN] Could not add company_name column (may already exist): {e}")

        # Add contact_person column if it doesn't exist (migration for existing databases)
        try:
            cursor.execute('''
                ALTER TABLE clients 
                ADD COLUMN IF NOT EXISTS contact_person VARCHAR(255)
            ''')
        except Exception as e:
            print(f"[WARN] Could not add contact_person column (may already exist): {e}")

        # Proposal versions table
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

        # Suggested changes table
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

        # Section locks table
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

        # Activity log table
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
        
        # Migration: Ensure user_id is INTEGER (fix for existing databases with VARCHAR)
        try:
            # Check current column type
            cursor.execute("""
                SELECT data_type 
                FROM information_schema.columns 
                WHERE table_name='notifications' AND column_name='user_id'
            """)
            result = cursor.fetchone()
            if result and result[0] == 'character varying':
                print("[INFO] Migrating notifications.user_id from VARCHAR to INTEGER...")
                # Convert VARCHAR to INTEGER
                cursor.execute("""
                    ALTER TABLE notifications 
                    ALTER COLUMN user_id TYPE INTEGER USING user_id::integer
                """)
                conn.commit()
                print("[OK] Migration complete: user_id is now INTEGER")
        except Exception as e:
            print(f"[WARN] Could not migrate user_id column type: {e}")
            # Continue anyway - the text comparison in queries will handle it

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

        cursor.execute('''CREATE INDEX IF NOT EXISTS idx_proposal_signatures 
                         ON proposal_signatures(proposal_id, status, sent_at DESC)''')

        # Client onboarding invitations table
        cursor.execute('''CREATE TABLE IF NOT EXISTS client_onboarding_invitations (
        id SERIAL PRIMARY KEY,
        access_token VARCHAR(255) UNIQUE NOT NULL,
        invited_email VARCHAR(255) NOT NULL,
        invited_by INTEGER NOT NULL,
        expected_company VARCHAR(255),
        status VARCHAR(50) DEFAULT 'pending',
        invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        completed_at TIMESTAMP,
        expires_at TIMESTAMP,
        client_id INTEGER,
        email_verified_at TIMESTAMP,
        verification_code_hash VARCHAR(255),
        code_expires_at TIMESTAMP,
        verification_attempts INTEGER DEFAULT 0,
        last_code_sent_at TIMESTAMP,
        FOREIGN KEY (invited_by) REFERENCES users(id),
        FOREIGN KEY (client_id) REFERENCES clients(id)
        )''')

        # Client notes table
        cursor.execute('''CREATE TABLE IF NOT EXISTS client_notes (
        id SERIAL PRIMARY KEY,
        client_id INTEGER NOT NULL,
        note_text TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
        FOREIGN KEY (created_by) REFERENCES users(id)
        )''')

        # Client proposals linkage table
        cursor.execute('''CREATE TABLE IF NOT EXISTS client_proposals (
        id SERIAL PRIMARY KEY,
        client_id INTEGER NOT NULL,
        proposal_id INTEGER NOT NULL,
        relationship_type VARCHAR(50) DEFAULT 'primary',
        linked_by INTEGER,
        linked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (client_id, proposal_id),
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
        FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
        FOREIGN KEY (linked_by) REFERENCES users(id)
        )''')

        # Email verification events table
        cursor.execute('''CREATE TABLE IF NOT EXISTS email_verification_events (
        id SERIAL PRIMARY KEY,
        invitation_id INTEGER NOT NULL,
        email VARCHAR(255) NOT NULL,
        event_type VARCHAR(50) NOT NULL,
        event_detail TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (invitation_id) REFERENCES client_onboarding_invitations(id) ON DELETE CASCADE
        )''')

        # User email verification tokens table
        cursor.execute('''CREATE TABLE IF NOT EXISTS user_email_verification_tokens (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL,
        token VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        used_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )''')

        conn.commit()
        release_pg_conn(conn)
        print("[OK] PostgreSQL schema initialized successfully")
    except Exception as exc:
        print(f"[ERROR] Error initializing PostgreSQL schema: {exc}")
        if conn:
            try:
                release_pg_conn(conn)
            except Exception:
                pass
        raise


def init_database():
    """Initialize database schema on first request"""
    global _db_initialized
    if _db_initialized:
        return

    try:
        print("[*] Initializing PostgreSQL schema...")
        init_pg_schema()
        _db_initialized = True
        print("[OK] Database schema initialized successfully")
    except Exception as exc:
        print(f"[ERROR] Database initialization error: {exc}")
        raise
