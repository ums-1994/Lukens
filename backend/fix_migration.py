#!/usr/bin/env python3
"""
Fix migration to remove foreign key constraints
"""

import os
import sys
import psycopg2

def get_db_connection():
    """Get PostgreSQL database connection using environment variables"""
    host = os.getenv("DB_HOST", "localhost")
    port = int(os.getenv("DB_PORT", "5432"))
    name = os.getenv("DB_NAME", "proposal_sow_builder")
    user = os.getenv("DB_USER", "postgres")
    pwd = os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123"))
    
    return psycopg2.connect(
        host=host,
        port=port,
        dbname=name,
        user=user,
        password=pwd,
    )

def fix_migration():
    """Drop and recreate proposal_versions table without foreign key constraints"""
    print("Fixing proposal_versions table...")
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Drop the existing table
        cur.execute("DROP TABLE IF EXISTS proposal_versions CASCADE;")
        
        # Create the table without foreign key constraints
        migration_sql = """
        CREATE TABLE proposal_versions (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          proposal_id UUID NOT NULL,
          version_number INT NOT NULL,
          content JSONB NOT NULL,
          created_by UUID,
          created_at TIMESTAMP DEFAULT NOW()
        );

        -- Create indexes for better performance
        CREATE INDEX idx_proposal_versions_proposal_id 
          ON proposal_versions(proposal_id);

        CREATE INDEX idx_proposal_versions_created_at 
          ON proposal_versions(created_at DESC);

        CREATE INDEX idx_proposal_versions_version_number 
          ON proposal_versions(proposal_id, version_number);
        """
        
        # Execute migration
        cur.execute(migration_sql)
        conn.commit()
        
        print("Migration fixed successfully!")
        
        # Verify table was created
        cur.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'proposal_versions'
            );
        """)
        
        table_exists = cur.fetchone()[0]
        
        if table_exists:
            print("proposal_versions table exists and is ready!")
        else:
            print("ERROR: proposal_versions table was not created")
            return False
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"Error running migration: {e}")
        if conn:
            conn.rollback()
        return False
    finally:
        if 'cur' in locals():
            cur.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    success = fix_migration()
    sys.exit(0 if success else 1)
