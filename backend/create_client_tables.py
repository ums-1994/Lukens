"""
Create Client Management Database Tables
Run this script to set up all client management tables in PostgreSQL
"""

import psycopg2
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# SQL for creating all tables
CREATE_TABLES_SQL = """
-- ============================================================
-- CLIENT ONBOARDING INVITATIONS TABLE
-- ============================================================
DROP TABLE IF EXISTS client_notes CASCADE;
DROP TABLE IF EXISTS client_proposals CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS client_onboarding_invitations CASCADE;

CREATE TABLE client_onboarding_invitations (
    id SERIAL PRIMARY KEY,
    access_token VARCHAR(500) UNIQUE NOT NULL,
    invited_email VARCHAR(255),
    invited_by INTEGER NOT NULL,
    expected_company VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending',
    invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    client_id INTEGER,
    FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE CASCADE
);

-- Create indexes for faster queries
CREATE INDEX idx_client_onboard_token ON client_onboarding_invitations(access_token);
CREATE INDEX idx_client_onboard_status ON client_onboarding_invitations(status);
CREATE INDEX idx_client_onboard_invited_by ON client_onboarding_invitations(invited_by);
CREATE INDEX idx_client_onboard_expires ON client_onboarding_invitations(expires_at);

COMMENT ON TABLE client_onboarding_invitations IS 'Stores secure invitation links for client onboarding';


-- ============================================================
-- CLIENTS TABLE
-- ============================================================
CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    
    -- Basic Information
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    
    -- Business Details
    industry VARCHAR(100),
    company_size VARCHAR(50),
    location VARCHAR(255),
    business_type VARCHAR(100),
    
    -- Project Information
    project_needs TEXT,
    budget_range VARCHAR(50),
    timeline VARCHAR(100),
    additional_info TEXT,
    
    -- Status & Tracking
    status VARCHAR(50) DEFAULT 'active',
    onboarding_token VARCHAR(500),
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Keys
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (onboarding_token) REFERENCES client_onboarding_invitations(access_token) ON DELETE SET NULL
);

-- Create indexes for faster queries
CREATE INDEX idx_clients_email ON clients(email);
CREATE INDEX idx_clients_company ON clients(company_name);
CREATE INDEX idx_clients_status ON clients(status);
CREATE INDEX idx_clients_created_by ON clients(created_by);
CREATE INDEX idx_clients_created_at ON clients(created_at DESC);

COMMENT ON TABLE clients IS 'Stores all client information from onboarding';


-- ============================================================
-- CLIENT PROPOSALS LINK TABLE
-- ============================================================
CREATE TABLE client_proposals (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL,
    proposal_id INTEGER NOT NULL,
    relationship_type VARCHAR(50) DEFAULT 'primary',
    linked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    linked_by INTEGER NOT NULL,
    
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (linked_by) REFERENCES users(id) ON DELETE CASCADE,
    
    UNIQUE(client_id, proposal_id)
);

CREATE INDEX idx_client_proposals_client ON client_proposals(client_id);
CREATE INDEX idx_client_proposals_proposal ON client_proposals(proposal_id);

COMMENT ON TABLE client_proposals IS 'Links clients to their associated proposals';


-- ============================================================
-- CLIENT NOTES TABLE
-- ============================================================
CREATE TABLE client_notes (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL,
    note_text TEXT NOT NULL,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_client_notes_client ON client_notes(client_id);
CREATE INDEX idx_client_notes_created ON client_notes(created_at DESC);

COMMENT ON TABLE client_notes IS 'Internal notes about clients (not visible to clients)';


-- Add foreign key from client_onboarding_invitations to clients
-- (This must be done after clients table is created)
ALTER TABLE client_onboarding_invitations 
ADD CONSTRAINT fk_client_onboard_client 
FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
"""

VERIFY_SQL = """
SELECT table_name, 
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
AND table_name IN ('client_onboarding_invitations', 'clients', 'client_proposals', 'client_notes')
ORDER BY table_name;
"""

def main():
    print("=" * 70)
    print("CLIENT MANAGEMENT DATABASE SETUP")
    print("=" * 70)
    print()
    
    # Get database connection details
    db_host = os.getenv('DB_HOST', 'localhost')
    db_name = os.getenv('DB_NAME')
    db_user = os.getenv('DB_USER')
    db_password = os.getenv('DB_PASSWORD')
    db_port = os.getenv('DB_PORT', '5432')
    
    print(f"📡 Connecting to database...")
    print(f"   Host: {db_host}")
    print(f"   Database: {db_name}")
    print(f"   User: {db_user}")
    print()
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host=db_host,
            database=db_name,
            user=db_user,
            password=db_password,
            port=db_port,
            sslmode='require'  # Azure requires SSL
        )
        
        cursor = conn.cursor()
        
        print("✅ Connected successfully!")
        print()
        print("🔨 Creating tables...")
        print()
        
        # Execute the SQL
        cursor.execute(CREATE_TABLES_SQL)
        conn.commit()
        
        print("✅ Tables created successfully!")
        print()
        print("🔍 Verifying tables...")
        print()
        
        # Verify tables
        cursor.execute(VERIFY_SQL)
        results = cursor.fetchall()
        
        if results:
            print("📊 Created Tables:")
            print("-" * 70)
            for table_name, column_count in results:
                print(f"   ✓ {table_name:<40} ({column_count} columns)")
            print("-" * 70)
            print()
            print("🎉 SUCCESS! All client management tables are ready!")
        else:
            print("⚠️  Warning: No tables found. Check for errors above.")
        
        print()
        print("=" * 70)
        print("NEXT STEPS:")
        print("=" * 70)
        print("1. ✅ Database tables created")
        print("2. 🔜 Add API endpoints to app.py")
        print("3. 🔜 Create Flutter Client Management page")
        print("4. 🔜 Replace collaboration_page.dart")
        print("=" * 70)
        
        # Close connection
        cursor.close()
        conn.close()
        
    except psycopg2.Error as e:
        print(f"❌ Database Error: {e}")
        print()
        print("Troubleshooting:")
        print("- Check your .env file has correct DB credentials")
        print("- Verify your database is accessible")
        print("- Ensure 'users' and 'proposals' tables exist")
        return 1
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())







