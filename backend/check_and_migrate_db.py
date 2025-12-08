#!/usr/bin/env python3
"""
Check database tables and run migration if needed
Can be run locally to connect to Render database
"""
import os
import sys
from dotenv import load_dotenv
import psycopg2

# Load environment variables
load_dotenv()

def check_tables():
    """Check which tables exist in the database"""
    try:
        # Connect to database using environment variables
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', '5432'),
            database=os.getenv('DB_NAME', 'proposal_sow_builder'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', ''),
            sslmode=os.getenv('DB_SSLMODE', 'prefer')
        )
        
        cursor = conn.cursor()
        
        # Check which tables exist
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name;
        """)
        
        existing_tables = [row[0] for row in cursor.fetchall()]
        
        print("=" * 60)
        print("📊 DATABASE TABLES CHECK")
        print("=" * 60)
        print(f"🔗 Connected to: {os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'proposal_sow_builder')}")
        print(f"\n📋 Existing tables ({len(existing_tables)}):")
        
        if existing_tables:
            for table in existing_tables:
                # Get row count
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    count = cursor.fetchone()[0]
                    print(f"  ✅ {table} ({count} rows)")
                except Exception as e:
                    print(f"  ⚠️  {table} (error checking count: {e})")
        else:
            print("  ❌ No tables found!")
        
        # Check for required tables
        required_tables = [
            'users', 'proposals', 'content', 'settings', 
            'clients', 'notifications', 'document_comments',
            'collaboration_invitations', 'proposal_versions'
        ]
        
        print(f"\n🔍 Checking required tables:")
        missing_tables = []
        for table in required_tables:
            if table in existing_tables:
                print(f"  ✅ {table}")
            else:
                print(f"  ❌ {table} - MISSING")
                missing_tables.append(table)
        
        cursor.close()
        conn.close()
        
        return existing_tables, missing_tables
        
    except Exception as e:
        print(f"❌ Error checking database: {e}")
        import traceback
        traceback.print_exc()
        return None, None


def run_migration():
    """Run the database schema migration"""
    print("\n" + "=" * 60)
    print("🔄 RUNNING DATABASE MIGRATION")
    print("=" * 60)
    
    try:
        # Import the schema initialization function
        sys.path.insert(0, os.path.dirname(__file__))
        from api.utils.database import init_pg_schema
        
        print("📋 Initializing PostgreSQL schema...")
        init_pg_schema()
        print("✅ Schema initialization completed!")
        
        return True
        
    except Exception as e:
        print(f"❌ Error running migration: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Main function"""
    # Check if running in non-interactive mode (no TTY)
    is_interactive = sys.stdin.isatty()
    
    print("\n" + "=" * 60)
    print("🗄️  DATABASE CHECK AND MIGRATION TOOL")
    print("=" * 60)
    print("\nThis script will:")
    print("1. Check which tables exist in your database")
    print("2. Run migration to create missing tables")
    print("\nUsing database connection from .env file:")
    print(f"  Host: {os.getenv('DB_HOST', 'localhost')}")
    print(f"  Database: {os.getenv('DB_NAME', 'proposal_sow_builder')}")
    print(f"  User: {os.getenv('DB_USER', 'postgres')}")
    if not is_interactive:
        print("\n⚠️  Running in non-interactive mode (auto-running migration)")
    print()
    
    # Check tables
    existing_tables, missing_tables = check_tables()
    
    if existing_tables is None:
        print("\n❌ Failed to connect to database. Please check your .env file.")
        sys.exit(1)
    
    # If there are missing tables, run migration automatically
    if missing_tables:
        print(f"\n⚠️  Found {len(missing_tables)} missing table(s): {', '.join(missing_tables)}")
        if is_interactive:
            print("\nWould you like to run the migration? (This will create missing tables)")
            response = input("Type 'yes' to continue, or anything else to cancel: ").strip().lower()
            if response != 'yes':
                print("\n❌ Migration cancelled.")
                sys.exit(0)
        else:
            print("\n🔄 Auto-running migration (non-interactive mode)...")
        
        if run_migration():
            print("\n✅ Migration completed! Checking tables again...")
            existing_tables, missing_tables = check_tables()
            if missing_tables:
                print(f"\n⚠️  Some tables are still missing: {', '.join(missing_tables)}")
            else:
                print("\n🎉 All required tables are now present!")
        else:
            print("\n❌ Migration failed. Please check the error messages above.")
            sys.exit(1)
    else:
        print("\n✅ All required tables are present!")
        if is_interactive:
            print("\nWould you like to re-run the migration anyway? (This is safe - uses CREATE TABLE IF NOT EXISTS)")
            response = input("Type 'yes' to continue, or anything else to skip: ").strip().lower()
            if response == 'yes':
                if run_migration():
                    print("\n✅ Migration completed!")
                else:
                    print("\n❌ Migration failed. Please check the error messages above.")
                    sys.exit(1)
        else:
            # In non-interactive mode, skip re-running if all tables exist
            print("\n✅ All tables present - skipping migration (use migrate_db.py to force migration)")
    
    print("\n" + "=" * 60)
    print("✅ DONE")
    print("=" * 60)


if __name__ == "__main__":
    main()

