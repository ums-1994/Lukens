#!/usr/bin/env python3
"""
Simple script to create settings tables directly
"""

import psycopg2
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def create_settings_tables():
    """Create settings tables directly"""
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "5432")),
            dbname=os.getenv("DB_NAME", "proposal_sow_builder"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123")),
        )
        
        with conn.cursor() as cur:
            print("Creating settings tables...")
            
            # System Settings Table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS system_settings (
                    id INTEGER PRIMARY KEY DEFAULT 1,
                    company_name VARCHAR(255) NOT NULL DEFAULT 'Your Company',
                    company_email VARCHAR(255) NOT NULL DEFAULT 'contact@yourcompany.com',
                    company_phone VARCHAR(50),
                    company_address TEXT,
                    company_website VARCHAR(255),
                    default_proposal_template VARCHAR(100) DEFAULT 'proposal_standard',
                    auto_save_interval INTEGER DEFAULT 30,
                    email_notifications BOOLEAN DEFAULT true,
                    approval_workflow VARCHAR(50) DEFAULT 'sequential',
                    signature_required BOOLEAN DEFAULT true,
                    pdf_watermark BOOLEAN DEFAULT false,
                    client_portal_enabled BOOLEAN DEFAULT true,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            print("✓ Created system_settings table")
            
            # User Preferences Table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS user_preferences (
                    user_id VARCHAR(255) PRIMARY KEY,
                    theme VARCHAR(50) DEFAULT 'light',
                    language VARCHAR(10) DEFAULT 'en',
                    timezone VARCHAR(100) DEFAULT 'UTC',
                    dashboard_layout VARCHAR(50) DEFAULT 'grid',
                    notifications_enabled BOOLEAN DEFAULT true,
                    email_digest VARCHAR(50) DEFAULT 'daily',
                    auto_logout INTEGER DEFAULT 30,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            print("✓ Created user_preferences table")
            
            # Email Settings Table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS email_settings (
                    id INTEGER PRIMARY KEY DEFAULT 1,
                    smtp_server VARCHAR(255) NOT NULL DEFAULT 'smtp.gmail.com',
                    smtp_port INTEGER DEFAULT 587,
                    smtp_username VARCHAR(255) NOT NULL DEFAULT '',
                    smtp_password VARCHAR(255) NOT NULL DEFAULT '',
                    smtp_use_tls BOOLEAN DEFAULT true,
                    from_email VARCHAR(255) NOT NULL DEFAULT '',
                    from_name VARCHAR(255) NOT NULL DEFAULT 'Proposal System',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            print("✓ Created email_settings table")
            
            # AI Settings Table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS ai_settings (
                    id INTEGER PRIMARY KEY DEFAULT 1,
                    openai_api_key VARCHAR(255),
                    ai_analysis_enabled BOOLEAN DEFAULT true,
                    risk_threshold INTEGER DEFAULT 50,
                    auto_analysis BOOLEAN DEFAULT false,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            print("✓ Created ai_settings table")
            
            # Database Settings Table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS database_settings (
                    id INTEGER PRIMARY KEY DEFAULT 1,
                    backup_enabled BOOLEAN DEFAULT true,
                    backup_frequency VARCHAR(50) DEFAULT 'daily',
                    retention_days INTEGER DEFAULT 30,
                    auto_cleanup BOOLEAN DEFAULT true,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            print("✓ Created database_settings table")
            
            # Insert default records
            cur.execute("INSERT INTO system_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING")
            cur.execute("INSERT INTO email_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING")
            cur.execute("INSERT INTO ai_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING")
            cur.execute("INSERT INTO database_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING")
            print("✓ Inserted default records")
            
            conn.commit()
            print("\n✅ Settings tables created successfully!")
            
            # Verify tables
            cur.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name LIKE '%settings%'
                ORDER BY table_name
            """)
            tables = cur.fetchall()
            print(f"📋 Created tables: {[t[0] for t in tables]}")
            
    except Exception as e:
        print(f"❌ Error creating settings tables: {e}")
        return False
    
    finally:
        if 'conn' in locals():
            conn.close()
    
    return True

if __name__ == "__main__":
    print("🚀 Creating Settings Tables...")
    print("=" * 40)
    
    if create_settings_tables():
        print("\n🎉 Settings setup complete!")
    else:
        print("\n❌ Settings setup failed!")
