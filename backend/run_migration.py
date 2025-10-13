#!/usr/bin/env python3
"""
Database migration runner for Proposal Builder
Run this script to apply database migrations
"""

import os
import sys
import psycopg2
from pathlib import Path

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

def run_migration(migration_file):
    """Run a single migration file"""
    print(f"Running migration: {migration_file}")
    
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Read migration file
        with open(migration_file, 'r', encoding='utf-8') as f:
            migration_sql = f.read()
        
        # Execute migration
        cur.execute(migration_sql)
        conn.commit()
        
        print(f"✅ Migration {migration_file} completed successfully")
        
    except Exception as e:
        print(f"❌ Error running migration {migration_file}: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if 'cur' in locals():
            cur.close()
        if 'conn' in locals():
            conn.close()

def main():
    """Run all pending migrations"""
    print("🚀 Starting database migrations...")
    
    # Get migrations directory
    migrations_dir = Path(__file__).parent / "migrations"
    
    if not migrations_dir.exists():
        print("❌ Migrations directory not found")
        sys.exit(1)
    
    # Get all SQL migration files
    migration_files = sorted(migrations_dir.glob("*.sql"))
    
    if not migration_files:
        print("ℹ️  No migration files found")
        return
    
    print(f"Found {len(migration_files)} migration(s) to run")
    
    # Run each migration
    for migration_file in migration_files:
        run_migration(migration_file)
    
    print("🎉 All migrations completed successfully!")

if __name__ == "__main__":
    main()
