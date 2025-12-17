#!/usr/bin/env python3
"""
Non-interactive database migration script
Automatically runs migration to ensure all tables are up to date
"""
import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def run_migration():
    """Run the database schema migration"""
    print("=" * 60)
    print("🔄 RUNNING DATABASE MIGRATION")
    print("=" * 60)
    print(f"🔗 Connecting to: {os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}/{os.getenv('DB_NAME', 'proposal_sow_builder')}")
    
    try:
        # Import the schema initialization function
        # Handle being run from root directory (backend/migrate_db.py) or backend directory (migrate_db.py)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        if script_dir not in sys.path:
            sys.path.insert(0, script_dir)
        
        # Change to backend directory for proper imports
        os.chdir(script_dir)
        
        from api.utils.database import init_pg_schema
        
        print("\n📋 Initializing PostgreSQL schema...")
        print("   (This will create any missing tables/columns)")
        init_pg_schema()
        print("\n✅ Schema migration completed successfully!")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error running migration: {e}")
        import traceback
        traceback.print_exc()
        return False


def check_tables():
    """Quick check of tables after migration"""
    try:
        import psycopg2
        
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', '5432'),
            database=os.getenv('DB_NAME', 'proposal_sow_builder'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', ''),
            sslmode=os.getenv('DB_SSLMODE', 'prefer')
        )
        
        cursor = conn.cursor()
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name;
        """)
        
        existing_tables = [row[0] for row in cursor.fetchall()]
        
        print(f"\n📊 Database now has {len(existing_tables)} tables")
        print("   Key tables:")
        key_tables = ['users', 'proposals', 'content', 'notifications', 'clients']
        for table in key_tables:
            if table in existing_tables:
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    count = cursor.fetchone()[0]
                    print(f"   ✅ {table}: {count} rows")
                except:
                    print(f"   ✅ {table}: exists")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"⚠️  Could not verify tables: {e}")


def main():
    """Main function"""
    print("\n" + "=" * 60)
    print("🗄️  DATABASE MIGRATION TOOL")
    print("=" * 60)
    
    if run_migration():
        check_tables()
        print("\n" + "=" * 60)
        print("✅ MIGRATION COMPLETED SUCCESSFULLY")
        print("=" * 60)
        return 0
    else:
        print("\n" + "=" * 60)
        print("❌ MIGRATION FAILED")
        print("=" * 60)
        return 1


if __name__ == "__main__":
    sys.exit(main())

