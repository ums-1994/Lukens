#!/usr/bin/env python3
"""
Migrate data from local SQLite database to PostgreSQL database
This script will:
1. Connect to SQLite database
2. Connect to PostgreSQL database
3. Migrate all tables and data
4. Preserve foreign key relationships
"""
import os
import sys
import sqlite3
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
from datetime import datetime

# Load environment variables
load_dotenv()

# SQLite database path
SQLITE_DB_PATH = os.getenv('SQLITE_DB_PATH', 'khonopro_client.db')
CONTENT_DB_PATH = os.getenv('CONTENT_DB_PATH', 'content.db')

# PostgreSQL connection details
PG_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'database': os.getenv('DB_NAME', 'proposal_sow_builder'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', ''),
    'port': int(os.getenv('DB_PORT', '5432')),
}

# Add SSL mode for external connections (like Render)
ssl_mode = os.getenv('DB_SSLMODE', 'prefer')
if 'render.com' in PG_CONFIG['host'].lower() or os.getenv('DB_REQUIRE_SSL', 'false').lower() == 'true':
    ssl_mode = 'require'
    PG_CONFIG['sslmode'] = ssl_mode


def get_sqlite_connection(db_path):
    """Get SQLite connection"""
    if not os.path.exists(db_path):
        print(f"⚠️  SQLite database not found: {db_path}")
        return None
    
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row  # Return rows as dictionaries
        print(f"✅ Connected to SQLite: {db_path}")
        return conn
    except Exception as e:
        print(f"❌ Error connecting to SQLite: {e}")
        return None


def get_postgres_connection():
    """Get PostgreSQL connection"""
    try:
        conn = psycopg2.connect(**PG_CONFIG)
        print(f"✅ Connected to PostgreSQL: {PG_CONFIG['host']}:{PG_CONFIG['port']}/{PG_CONFIG['database']}")
        return conn
    except Exception as e:
        print(f"❌ Error connecting to PostgreSQL: {e}")
        return None


def get_table_names(conn, db_type='sqlite'):
    """Get list of tables from database"""
    if db_type == 'sqlite':
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
        return [row[0] for row in cursor.fetchall()]
    else:  # postgres
        cursor = conn.cursor()
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        return [row[0] for row in cursor.fetchall()]


def get_table_schema(conn, table_name, db_type='sqlite'):
    """Get table schema"""
    if db_type == 'sqlite':
        cursor = conn.cursor()
        cursor.execute(f"PRAGMA table_info({table_name})")
        return cursor.fetchall()
    else:  # postgres
        cursor = conn.cursor()
        cursor.execute("""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_name = %s
            ORDER BY ordinal_position
        """, (table_name,))
        return cursor.fetchall()


def migrate_table(sqlite_conn, pg_conn, table_name, skip_if_exists=True):
    """Migrate a single table from SQLite to PostgreSQL"""
    print(f"\n📦 Migrating table: {table_name}")
    
    # Check if table exists in PostgreSQL
    pg_cursor = pg_conn.cursor()
    pg_cursor.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = %s
        )
    """, (table_name,))
    table_exists = pg_cursor.fetchone()[0]
    
    if table_exists and skip_if_exists:
        print(f"   ⏭️  Table {table_name} already exists in PostgreSQL, skipping...")
        return True
    
    # Get data from SQLite
    sqlite_cursor = sqlite_conn.cursor()
    sqlite_cursor.execute(f"SELECT * FROM {table_name}")
    rows = sqlite_cursor.fetchall()
    
    if not rows:
        print(f"   ℹ️  Table {table_name} is empty, skipping data migration")
        return True
    
    print(f"   📊 Found {len(rows)} rows to migrate")
    
    # Get column names
    column_names = [description[0] for description in sqlite_cursor.description]
    
    # Prepare insert statement
    placeholders = ', '.join(['%s'] * len(column_names))
    columns = ', '.join([f'"{col}"' for col in column_names])
    insert_sql = f'INSERT INTO {table_name} ({columns}) VALUES ({placeholders})'
    
    # Migrate data
    migrated_count = 0
    error_count = 0
    
    try:
        for row in rows:
            try:
                # Convert row to tuple, handling None values
                values = tuple(None if val is None else val for val in row)
                pg_cursor.execute(insert_sql, values)
                migrated_count += 1
            except psycopg2.IntegrityError as e:
                # Skip duplicate entries
                if 'duplicate key' in str(e).lower() or 'unique constraint' in str(e).lower():
                    print(f"   ⚠️  Skipping duplicate row in {table_name}")
                    pg_conn.rollback()
                else:
                    error_count += 1
                    print(f"   ❌ Error inserting row: {e}")
                    pg_conn.rollback()
            except Exception as e:
                error_count += 1
                print(f"   ❌ Error inserting row: {e}")
                pg_conn.rollback()
        
        if migrated_count > 0:
            pg_conn.commit()
            print(f"   ✅ Migrated {migrated_count} rows successfully")
        if error_count > 0:
            print(f"   ⚠️  {error_count} rows failed to migrate")
        
        return True
        
    except Exception as e:
        print(f"   ❌ Error migrating table {table_name}: {e}")
        pg_conn.rollback()
        return False


def migrate_all_tables(sqlite_conn, pg_conn):
    """Migrate all tables from SQLite to PostgreSQL"""
    # Get list of tables
    sqlite_tables = get_table_names(sqlite_conn, 'sqlite')
    
    if not sqlite_tables:
        print("⚠️  No tables found in SQLite database")
        return False
    
    print(f"\n📋 Found {len(sqlite_tables)} tables in SQLite:")
    for table in sqlite_tables:
        print(f"   - {table}")
    
    # Tables to migrate in order (respecting foreign key dependencies)
    # Common order: users/clients first, then proposals, then related tables
    priority_tables = ['users', 'clients', 'proposals', 'content', 'notifications', 'collaborators']
    
    # Sort tables: priority first, then others
    ordered_tables = []
    for priority in priority_tables:
        if priority in sqlite_tables:
            ordered_tables.append(priority)
    
    # Add remaining tables
    for table in sqlite_tables:
        if table not in ordered_tables:
            ordered_tables.append(table)
    
    print(f"\n🔄 Migrating tables in order (respecting dependencies)...")
    
    success_count = 0
    for table in ordered_tables:
        if migrate_table(sqlite_conn, pg_conn, table):
            success_count += 1
    
    print(f"\n✅ Migration complete: {success_count}/{len(ordered_tables)} tables migrated")
    return success_count == len(ordered_tables)


def verify_migration(sqlite_conn, pg_conn):
    """Verify migration by comparing row counts"""
    print("\n🔍 Verifying migration...")
    
    sqlite_tables = get_table_names(sqlite_conn, 'sqlite')
    
    all_match = True
    for table in sqlite_tables:
        # Count SQLite rows
        sqlite_cursor = sqlite_conn.cursor()
        sqlite_cursor.execute(f"SELECT COUNT(*) FROM {table}")
        sqlite_count = sqlite_cursor.fetchone()[0]
        
        # Count PostgreSQL rows
        try:
            pg_cursor = pg_conn.cursor()
            pg_cursor.execute(f"SELECT COUNT(*) FROM {table}")
            pg_count = pg_cursor.fetchone()[0]
            
            if sqlite_count == pg_count:
                print(f"   ✅ {table}: {pg_count} rows (matches SQLite)")
            else:
                print(f"   ⚠️  {table}: SQLite={sqlite_count}, PostgreSQL={pg_count} (mismatch)")
                all_match = False
        except Exception as e:
            print(f"   ❌ {table}: Error verifying - {e}")
            all_match = False
    
    return all_match


def main():
    """Main migration function"""
    print("=" * 70)
    print("🔄 SQLite to PostgreSQL Migration Tool")
    print("=" * 70)
    print(f"\n📁 SQLite Database: {SQLITE_DB_PATH}")
    print(f"🐘 PostgreSQL: {PG_CONFIG['host']}:{PG_CONFIG['port']}/{PG_CONFIG['database']}")
    
    # Check if SQLite database exists
    if not os.path.exists(SQLITE_DB_PATH):
        print(f"\n❌ SQLite database not found: {SQLITE_DB_PATH}")
        print("   Please set SQLITE_DB_PATH environment variable or place database in backend/ directory")
        return 1
    
    # Connect to databases
    sqlite_conn = get_sqlite_connection(SQLITE_DB_PATH)
    if not sqlite_conn:
        return 1
    
    pg_conn = get_postgres_connection()
    if not pg_conn:
        sqlite_conn.close()
        return 1
    
    try:
        # Ensure PostgreSQL schema is initialized
        print("\n📋 Ensuring PostgreSQL schema is initialized...")
        script_dir = os.path.dirname(os.path.abspath(__file__))
        if script_dir not in sys.path:
            sys.path.insert(0, script_dir)
        os.chdir(script_dir)
        
        from api.utils.database import init_pg_schema
        init_pg_schema()
        print("✅ PostgreSQL schema initialized")
        
        # Migrate tables
        if migrate_all_tables(sqlite_conn, pg_conn):
            # Verify migration
            if verify_migration(sqlite_conn, pg_conn):
                print("\n" + "=" * 70)
                print("✅ MIGRATION COMPLETED SUCCESSFULLY")
                print("=" * 70)
                return 0
            else:
                print("\n" + "=" * 70)
                print("⚠️  MIGRATION COMPLETED WITH WARNINGS")
                print("=" * 70)
                print("   Some row counts don't match. Please verify manually.")
                return 0
        else:
            print("\n" + "=" * 70)
            print("❌ MIGRATION FAILED")
            print("=" * 70)
            return 1
            
    except Exception as e:
        print(f"\n❌ Migration error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        sqlite_conn.close()
        pg_conn.close()
        print("\n🔌 Database connections closed")


if __name__ == "__main__":
    sys.exit(main())

