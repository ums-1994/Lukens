#!/usr/bin/env python3
"""
Migrate data from local PostgreSQL database to production PostgreSQL database (e.g., Render)
This script will:
1. Connect to source PostgreSQL database (local)
2. Connect to destination PostgreSQL database (Render/production)
3. Migrate all tables and data
4. Preserve foreign key relationships
"""
import os
import sys
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
from datetime import datetime

# Load environment variables
load_dotenv()

# Source PostgreSQL (local) connection details
SOURCE_CONFIG = {
    'host': os.getenv('SOURCE_DB_HOST', os.getenv('DB_HOST', 'localhost')),
    'database': os.getenv('SOURCE_DB_NAME', os.getenv('DB_NAME', 'proposal_sow_builder')),
    'user': os.getenv('SOURCE_DB_USER', os.getenv('DB_USER', 'postgres')),
    'password': os.getenv('SOURCE_DB_PASSWORD', os.getenv('DB_PASSWORD', '')),
    'port': int(os.getenv('SOURCE_DB_PORT', os.getenv('DB_PORT', '5432'))),
}

# Destination PostgreSQL (production/Render) connection details
DEST_CONFIG = {
    'host': os.getenv('DEST_DB_HOST', os.getenv('RENDER_DB_HOST', '')),
    'database': os.getenv('DEST_DB_NAME', os.getenv('RENDER_DB_NAME', '')),
    'user': os.getenv('DEST_DB_USER', os.getenv('RENDER_DB_USER', '')),
    'password': os.getenv('DEST_DB_PASSWORD', os.getenv('RENDER_DB_PASSWORD', '')),
    'port': int(os.getenv('DEST_DB_PORT', os.getenv('RENDER_DB_PORT', '5432'))),
}

# Add SSL mode for destination (usually required for Render)
dest_ssl_mode = os.getenv('DEST_DB_SSLMODE', os.getenv('DB_SSLMODE', 'prefer'))
if 'render.com' in DEST_CONFIG.get('host', '').lower() or os.getenv('DEST_DB_REQUIRE_SSL', 'false').lower() == 'true':
    dest_ssl_mode = 'require'
    DEST_CONFIG['sslmode'] = dest_ssl_mode


def get_postgres_connection(config, label='PostgreSQL'):
    """Get PostgreSQL connection"""
    try:
        conn = psycopg2.connect(**config)
        print(f"✅ Connected to {label}: {config['host']}:{config['port']}/{config['database']}")
        return conn
    except Exception as e:
        print(f"❌ Error connecting to {label}: {e}")
        print(f"   Config: host={config.get('host')}, database={config.get('database')}, user={config.get('user')}")
        return None


def get_table_names(conn):
    """Get list of tables from database"""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
        AND table_name NOT LIKE 'pg_%'
        ORDER BY table_name
    """)
    return [row[0] for row in cursor.fetchall()]


def get_row_count(conn, table_name):
    """Get row count for a table"""
    cursor = conn.cursor()
    try:
        cursor.execute(f'SELECT COUNT(*) FROM "{table_name}"')
        return cursor.fetchone()[0]
    except Exception as e:
        print(f"   ⚠️  Error counting rows in {table_name}: {e}")
        return 0


def migrate_table(source_conn, dest_conn, table_name, skip_if_exists=True, truncate_first=False):
    """Migrate a single table from source to destination PostgreSQL"""
    print(f"\n📦 Migrating table: {table_name}")
    
    # Check if table exists in destination
    dest_cursor = dest_conn.cursor()
    dest_cursor.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = %s
        )
    """, (table_name,))
    table_exists = dest_cursor.fetchone()[0]
    
    if not table_exists:
        print(f"   ⚠️  Table {table_name} does not exist in destination. Skipping...")
        print(f"   💡 Run 'python migrate_db.py' first to create schema")
        return False
    
    # Get row count from source
    source_count = get_row_count(source_conn, table_name)
    
    if source_count == 0:
        print(f"   ℹ️  Table {table_name} is empty in source, skipping")
        return True
    
    # Get row count from destination
    dest_count = get_row_count(dest_conn, table_name)
    
    if dest_count > 0:
        if skip_if_exists:
            print(f"   ⏭️  Table {table_name} already has {dest_count} rows, skipping...")
            return True
        elif truncate_first:
            print(f"   🗑️  Truncating existing {dest_count} rows...")
            dest_cursor.execute(f'TRUNCATE TABLE "{table_name}" CASCADE')
            dest_conn.commit()
    
    print(f"   📊 Source: {source_count} rows, Destination: {dest_count} rows")
    
    # Get column names from source
    source_cursor = source_conn.cursor()
    source_cursor.execute(f"""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = %s
        ORDER BY ordinal_position
    """, (table_name,))
    column_names = [row[0] for row in source_cursor.fetchall()]
    
    if not column_names:
        print(f"   ⚠️  No columns found in {table_name}")
        return False
    
    # Fetch data from source
    print(f"   📥 Fetching data from source...")
    source_cursor.execute(f'SELECT * FROM "{table_name}"')
    rows = source_cursor.fetchall()
    
    if not rows:
        print(f"   ℹ️  No rows to migrate")
        return True
    
    # Prepare insert statement
    placeholders = ', '.join(['%s'] * len(column_names))
    columns = ', '.join([f'"{col}"' for col in column_names])
    insert_sql = f'INSERT INTO "{table_name}" ({columns}) VALUES ({placeholders})'
    
    # Migrate data in batches
    print(f"   📤 Migrating {len(rows)} rows...")
    migrated_count = 0
    error_count = 0
    batch_size = 1000
    
    try:
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i + batch_size]
            try:
                dest_cursor.executemany(insert_sql, batch)
                migrated_count += len(batch)
                if (i + batch_size) % 5000 == 0:
                    print(f"      ... {migrated_count} rows migrated so far")
            except psycopg2.IntegrityError as e:
                # Try inserting one by one to identify problematic rows
                print(f"   ⚠️  Batch insert failed, trying individual inserts...")
                for row in batch:
                    try:
                        dest_cursor.execute(insert_sql, row)
                        migrated_count += 1
                    except psycopg2.IntegrityError:
                        # Skip duplicate entries
                        error_count += 1
                        if error_count <= 5:  # Only show first 5 errors
                            print(f"      ⚠️  Skipping duplicate row")
                    except Exception as e:
                        error_count += 1
                        if error_count <= 5:
                            print(f"      ❌ Error: {e}")
            except Exception as e:
                print(f"   ❌ Batch insert error: {e}")
                error_count += len(batch)
        
        if migrated_count > 0:
            dest_conn.commit()
            print(f"   ✅ Migrated {migrated_count} rows successfully")
        if error_count > 0:
            print(f"   ⚠️  {error_count} rows failed to migrate (likely duplicates)")
        
        return True
        
    except Exception as e:
        print(f"   ❌ Error migrating table {table_name}: {e}")
        import traceback
        traceback.print_exc()
        dest_conn.rollback()
        return False


def migrate_all_tables(source_conn, dest_conn, truncate_first=False):
    """Migrate all tables from source to destination PostgreSQL"""
    # Get list of tables
    source_tables = get_table_names(source_conn)
    
    if not source_tables:
        print("⚠️  No tables found in source database")
        return False
    
    print(f"\n📋 Found {len(source_tables)} tables in source database:")
    for table in source_tables[:10]:  # Show first 10
        print(f"   - {table}")
    if len(source_tables) > 10:
        print(f"   ... and {len(source_tables) - 10} more")
    
    # Tables to migrate in order (respecting foreign key dependencies)
    priority_tables = [
        'users', 'clients', 'content', 
        'proposals', 'proposal_versions',
        'notifications', 'collaborators', 'collaboration_invitations',
        'comments', 'ai_usage', 'proposal_client_activity'
    ]
    
    # Sort tables: priority first, then others
    ordered_tables = []
    for priority in priority_tables:
        if priority in source_tables:
            ordered_tables.append(priority)
    
    # Add remaining tables
    for table in source_tables:
        if table not in ordered_tables:
            ordered_tables.append(table)
    
    print(f"\n🔄 Migrating tables in order (respecting dependencies)...")
    
    success_count = 0
    for table in ordered_tables:
        if migrate_table(source_conn, dest_conn, table, skip_if_exists=not truncate_first, truncate_first=truncate_first):
            success_count += 1
    
    print(f"\n✅ Migration complete: {success_count}/{len(ordered_tables)} tables migrated")
    return success_count == len(ordered_tables)


def verify_migration(source_conn, dest_conn):
    """Verify migration by comparing row counts"""
    print("\n🔍 Verifying migration...")
    
    source_tables = get_table_names(source_conn)
    
    all_match = True
    for table in source_tables:
        source_count = get_row_count(source_conn, table)
        dest_count = get_row_count(dest_conn, table)
        
        if source_count == dest_count:
            print(f"   ✅ {table}: {dest_count} rows (matches source)")
        else:
            print(f"   ⚠️  {table}: Source={source_count}, Dest={dest_count} (mismatch)")
            all_match = False
    
    return all_match


def main():
    """Main migration function"""
    print("=" * 70)
    print("🔄 PostgreSQL to PostgreSQL Migration Tool")
    print("=" * 70)
    print(f"\n📥 Source (Local): {SOURCE_CONFIG['host']}:{SOURCE_CONFIG['port']}/{SOURCE_CONFIG['database']}")
    print(f"📤 Destination (Production): {DEST_CONFIG.get('host', 'NOT SET')}:{DEST_CONFIG.get('port', '5432')}/{DEST_CONFIG.get('database', 'NOT SET')}")
    
    # Validate destination config
    if not DEST_CONFIG.get('host') or not DEST_CONFIG.get('database'):
        print("\n❌ Destination database not configured!")
        print("\n💡 Set these environment variables:")
        print("   DEST_DB_HOST=your-render-host.render.com")
        print("   DEST_DB_NAME=your_database_name")
        print("   DEST_DB_USER=your_database_user")
        print("   DEST_DB_PASSWORD=your_database_password")
        print("   DEST_DB_SSLMODE=require")
        print("\n   Or use RENDER_DB_* prefix:")
        print("   RENDER_DB_HOST=...")
        print("   RENDER_DB_NAME=...")
        print("   RENDER_DB_USER=...")
        print("   RENDER_DB_PASSWORD=...")
        return 1
    
    # Connect to databases
    source_conn = get_postgres_connection(SOURCE_CONFIG, "Source (Local)")
    if not source_conn:
        return 1
    
    dest_conn = get_postgres_connection(DEST_CONFIG, "Destination (Production)")
    if not dest_conn:
        source_conn.close()
        return 1
    
    try:
        # Ensure destination schema is initialized
        print("\n📋 Ensuring destination schema is initialized...")
        script_dir = os.path.dirname(os.path.abspath(__file__))
        if script_dir not in sys.path:
            sys.path.insert(0, script_dir)
        os.chdir(script_dir)
        
        # Temporarily switch to destination config for schema init
        original_env = {}
        for key, value in DEST_CONFIG.items():
            env_key = f"DB_{key.upper()}" if key != 'sslmode' else 'DB_SSLMODE'
            if key == 'host':
                original_env['DB_HOST'] = os.getenv('DB_HOST')
                os.environ['DB_HOST'] = str(value)
            elif key == 'database':
                original_env['DB_NAME'] = os.getenv('DB_NAME')
                os.environ['DB_NAME'] = str(value)
            elif key == 'user':
                original_env['DB_USER'] = os.getenv('DB_USER')
                os.environ['DB_USER'] = str(value)
            elif key == 'password':
                original_env['DB_PASSWORD'] = os.getenv('DB_PASSWORD')
                os.environ['DB_PASSWORD'] = str(value)
            elif key == 'port':
                original_env['DB_PORT'] = os.getenv('DB_PORT')
                os.environ['DB_PORT'] = str(value)
        
        from api.utils.database import init_pg_schema
        init_pg_schema()
        print("✅ Destination schema initialized")
        
        # Restore original env
        for key, value in original_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        
        # Ask user about truncation
        print("\n❓ Migration options:")
        print("   1. Skip existing data (default) - Safe, won't overwrite")
        print("   2. Truncate and re-migrate - Will delete existing data first")
        
        # For non-interactive mode, use skip
        truncate = os.getenv('MIGRATE_TRUNCATE', 'false').lower() == 'true'
        
        if truncate:
            print("\n⚠️  TRUNCATE MODE: Will delete existing data in destination!")
            response = input("   Continue? (yes/no): ").strip().lower()
            if response != 'yes':
                print("   Migration cancelled")
                return 0
        
        # Migrate tables
        if migrate_all_tables(source_conn, dest_conn, truncate_first=truncate):
            # Verify migration
            if verify_migration(source_conn, dest_conn):
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
            
    except KeyboardInterrupt:
        print("\n\n⚠️  Migration interrupted by user")
        return 1
    except Exception as e:
        print(f"\n❌ Migration error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        source_conn.close()
        dest_conn.close()
        print("\n🔌 Database connections closed")


if __name__ == "__main__":
    sys.exit(main())

