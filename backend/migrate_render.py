#!/usr/bin/env python
"""
Migration script to be deployed to Render.

It restores a SQL dump (local_db_backup.sql) into the database
configured via the usual DB_* environment variables. This means:

- When run on Render, it will connect using the same internal
  host/credentials that your app uses.
- When run locally, it will connect to whatever DB_* or DATABASE_URL
  you have configured (for example, the Render external URL).
"""
import os
import sys

import psycopg2


def build_connection_dsn() -> str:
    """Build a psycopg2 DSN from environment variables."""
    # Prefer DATABASE_URL if it is explicitly set
    database_url = os.getenv("DATABASE_URL")
    if database_url:
        return database_url

    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("DB_NAME", "proposal_sow_builder")
    user = os.getenv("DB_USER", "postgres")
    password = os.getenv("DB_PASSWORD", "Password123")
    sslmode = os.getenv("DB_SSLMODE", "prefer")

    return (
        f"postgresql://{user}:{password}@{host}:{port}/{name}"
        f"?sslmode={sslmode}"
    )


def connect_render():
    """Connect to target database (Render when running there)."""
    dsn = build_connection_dsn()
    print(f"Connecting with DSN: {dsn}")

    try:
        conn = psycopg2.connect(dsn)
        print("✅ Connected to target database")
        return conn
    except Exception as e:
        print(f"❌ Failed to connect to database: {e}")
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

        # WARNING: this will wipe the current schema and all data
        # in the "public" schema before restoring from the dump.
        # This is safe for a fresh Render database that you want
        # to completely replace with the local contents.
        print("🧹 Dropping existing public schema (if any)...")
        cursor.execute("DROP SCHEMA IF EXISTS public CASCADE;")
        cursor.execute("CREATE SCHEMA public;")
        conn.commit()

        print(f"📖 Restoring from {dump_file}...")
        with open(dump_file, 'r', encoding='utf-8') as f:
            sql_content = f.read()

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
