#!/usr/bin/env python
"""
Migration script to be deployed to Render
Runs during deployment to migrate data from local backup to Render DB
"""
import psycopg2
from psycopg2 import sql
import os
import sys

# Source: Local database (will be loaded from dump)
LOCAL_DB = {
    'host': 'localhost',
    'port': 5432,
    'database': 'proposal_sow_builder',
    'user': 'postgres',
    'password': 'Password123'
}

# Target: Render database (from environment or hardcoded)
RENDER_CONNECTION_STRING = os.getenv(
    'DATABASE_URL',
    'postgresql://sowbuilder_jdyx_user:LvUDRxCLtJSQn7tTKhux50kfCsL89cuF@dpg-d61mhge3jp1c7390jcm0-a/sowbuilder_jdyx'
)

def connect_render():
    """Connect to Render database (runs inside Render environment)"""
    try:
        conn = psycopg2.connect(RENDER_CONNECTION_STRING)
        print("✅ Connected to Render database (internal)")
        return conn
    except Exception as e:
        print(f"❌ Failed to connect to Render: {e}")
        return None

def get_tables_from_dump():
    """
    Get tables from SQL dump file
    This script assumes local_db_backup.sql exists
    """
    dump_file = 'local_db_backup.sql'
    if not os.path.exists(dump_file):
        print(f"⚠️  Dump file not found: {dump_file}")
        return False
    
    try:
        conn = connect_render()
        if not conn:
            return False
        
        cursor = conn.cursor()
        
        print(f"📖 Restoring from {dump_file}...")
        with open(dump_file, 'r') as f:
            sql_content = f.read()
        
        # Execute dump
        cursor.execute(sql_content)
        conn.commit()
        
        cursor.close()
        conn.close()
        
        print("✅ Database restored successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Restore failed: {e}")
        return False

def main():
    print("🚀 Render Migration Script\n")
    
    # Check if migration should run
    should_migrate = os.getenv('SKIP_MIGRATION', 'false').lower() != 'true'
    
    if not should_migrate:
        print("⏭️  Migration skipped (SKIP_MIGRATION=true)")
        return 0
    
    # Restore from dump
    if not get_tables_from_dump():
        print("\n⚠️  Migration script completed with errors")
        return 1
    
    print("\n✅ All done!")
    return 0

if __name__ == '__main__':
    sys.exit(main())
