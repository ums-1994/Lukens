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

# Ensure full domain for Render (short hostname doesn't work from outside)
if DEST_CONFIG.get('host') and 'render.com' not in DEST_CONFIG.get('host', '').lower():
    # If host is short (like "dpg-xxxxx-a"), add the domain
    if DEST_CONFIG['host'].startswith('dpg-') and DEST_CONFIG['host'].endswith('-a'):
        DEST_CONFIG['host'] = f"{DEST_CONFIG['host']}.oregon-postgres.render.com"
        print(f"[INFO] Expanded Render hostname to: {DEST_CONFIG['host']}")

# Add SSL mode for destination (prefer works better than require for Render)
dest_ssl_mode = os.getenv('DEST_DB_SSLMODE', os.getenv('DB_SSLMODE', 'prefer'))
if 'render.com' in DEST_CONFIG.get('host', '').lower():
    # Use 'prefer' for Render (tested and works)
    dest_ssl_mode = 'prefer'
    DEST_CONFIG['sslmode'] = dest_ssl_mode
    DEST_CONFIG['connect_timeout'] = 30


def get_postgres_connection(config, label='PostgreSQL'):
    """Get PostgreSQL connection"""
    try:
        # Create connection string with proper SSL handling
        # For Render, we need to use sslmode in the connection
        conn_params = config.copy()
        
        # psycopg2 accepts sslmode as a parameter
        # Ensure SSL is set for Render connections (use 'prefer' which works)
        if 'render.com' in conn_params.get('host', '').lower():
            # Use 'prefer' instead of 'require' - tested and works
            if 'sslmode' not in conn_params:
                conn_params['sslmode'] = 'prefer'
            conn_params['connect_timeout'] = 30
        
        conn = psycopg2.connect(**conn_params)
        print(f"✅ Connected to {label}: {config['host']}:{config['port']}/{config['database']}")
        return conn
    except psycopg2.OperationalError as e:
        print(f"❌ Connection error to {label}: {e}")
        print(f"   Config: host={config.get('host')}, database={config.get('database')}, user={config.get('user')}")
        if 'render.com' in config.get('host', '').lower():
            print(f"   💡 Tip: Render requires SSL. Checking if database is accessible...")
            print(f"   💡 If using Render free tier, make sure the database is not paused")
        return None
    except Exception as e:
        print(f"❌ Error connecting to {label}: {e}")
        print(f"   Config: host={config.get('host')}, database={config.get('database')}, user={config.get('user')}")
        import traceback
        traceback.print_exc()
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


def get_column_mapping(table_name):
    """Get column mapping for schema differences between source and destination"""
    mappings = {
        'proposals': {
            'user_id': 'owner_id',  # Local has user_id, Render has owner_id
            'client_name': 'client',  # Local has client_name, Render has client
        }
    }
    return mappings.get(table_name, {})


def get_default_value(table_name, col_name, dest_type):
    """Get default value for NOT NULL columns that might be missing"""
    defaults = {
        'proposals': {
            'client': 'Unknown Client',  # Default client name if NULL
        },
        'notifications': {
            'id': None,  # Will need to generate or skip
        }
    }
    return defaults.get(table_name, {}).get(col_name, None)


def migrate_table(source_conn, dest_conn, table_name, skip_if_exists=True, truncate_first=False):
    """Migrate a single table from source to destination PostgreSQL"""
    print(f"\n📦 Migrating table: {table_name}")
    
    # Check if table exists in destination
    dest_cursor = dest_conn.cursor()
    try:
        dest_cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = %s
            )
        """, (table_name,))
        table_exists = dest_cursor.fetchone()[0]
    except Exception as e:
        print(f"   ❌ Error checking table existence: {e}")
        dest_conn.rollback()
        return False
    
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
            try:
                dest_cursor.execute(f'TRUNCATE TABLE "{table_name}" CASCADE')
                dest_conn.commit()
            except Exception as e:
                print(f"   ❌ Error truncating: {e}")
                dest_conn.rollback()
                return False
    
    print(f"   📊 Source: {source_count} rows, Destination: {dest_count} rows")
    
    # Get column names from source
    source_cursor = source_conn.cursor()
    source_cursor.execute(f"""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = %s
        ORDER BY ordinal_position
    """, (table_name,))
    source_columns = [row[0] for row in source_cursor.fetchall()]
    
    if not source_columns:
        print(f"   ⚠️  No columns found in {table_name}")
        return False
    
    # Get column names from destination
    dest_cursor.execute(f"""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = %s
        ORDER BY ordinal_position
    """, (table_name,))
    dest_columns = [row[0] for row in dest_cursor.fetchall()]
    
    # Get column mapping for schema differences
    column_mapping = get_column_mapping(table_name)
    
    # Map source columns to destination columns
    mapped_columns = []
    mapped_source_columns = []
    for col in source_columns:
        # Use mapping if exists, otherwise use column name as-is
        dest_col = column_mapping.get(col, col)
        if dest_col in dest_columns:
            mapped_columns.append(dest_col)
            mapped_source_columns.append(col)
        else:
            print(f"   ⚠️  Column '{col}' not found in destination, skipping...")
    
    # Create reverse mapping for value conversion
    column_mapping_reverse = {}
    for src_col, dest_col in zip(mapped_source_columns, mapped_columns):
        if src_col != dest_col:
            column_mapping_reverse[dest_col] = src_col
    
    # Check for required columns in destination that might be missing from source
    dest_cursor.execute(f"""
        SELECT column_name, is_nullable, column_default
        FROM information_schema.columns 
        WHERE table_name = %s
        AND is_nullable = 'NO'
        AND column_default IS NULL
    """, (table_name,))
    required_columns = [row[0] for row in dest_cursor.fetchall()]
    missing_required = [col for col in required_columns if col not in mapped_columns]
    if missing_required:
        print(f"   ⚠️  Required columns missing: {', '.join(missing_required)}")
        # Try to add defaults for known mappings
        for req_col in missing_required:
            default = get_default_value(table_name, req_col, '')
            if default is not None:
                mapped_columns.append(req_col)
                mapped_source_columns.append(None)  # Will use default
                print(f"   ✅ Adding default value for '{req_col}': {default}")
    
    if not mapped_columns:
        print(f"   ❌ No matching columns found between source and destination")
        return False
    
    print(f"   📋 Mapping {len(mapped_columns)} columns: {', '.join(mapped_columns[:5])}{'...' if len(mapped_columns) > 5 else ''}")
    
    # Get data types and constraints for destination columns
    dest_cursor.execute(f"""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns 
        WHERE table_name = %s
        ORDER BY ordinal_position
    """, (table_name,))
    dest_column_info = {row[0]: {'type': row[1], 'nullable': row[2] == 'YES', 'default': row[3]} 
                       for row in dest_cursor.fetchall()}
    dest_column_types = {col: info['type'] for col, info in dest_column_info.items()}
    
    # Fetch data from source (only selected columns)
    print(f"   📥 Fetching data from source...")
    source_cols_str = ', '.join([f'"{col}"' for col in mapped_source_columns])
    source_cursor.execute(f'SELECT {source_cols_str} FROM "{table_name}"')
    rows = source_cursor.fetchall()
    
    if not rows:
        print(f"   ℹ️  No rows to migrate")
        return True
    
    # Prepare insert statement with mapped columns
    placeholders = ', '.join(['%s'] * len(mapped_columns))
    columns = ', '.join([f'"{col}"' for col in mapped_columns])
    insert_sql = f'INSERT INTO "{table_name}" ({columns}) VALUES ({placeholders})'
    
    # Helper function to convert data types
    def convert_value(value, col_name, dest_type, source_col_name):
        """Convert value to match destination column type"""
        col_info = dest_column_info.get(col_name, {})
        is_nullable = col_info.get('nullable', True)
        
        if value is None:
            # Check if column is NOT NULL and has a default
            if not is_nullable:
                default = get_default_value(table_name, col_name, dest_type)
                if default is not None:
                    return default
                # If no default and NOT NULL, we might have a problem
                print(f"      ⚠️  Warning: NULL value for NOT NULL column '{col_name}', using default")
                return get_default_value(table_name, col_name, dest_type) or ''
            return None
        
        # Handle JSON/dict types
        if isinstance(value, dict):
            import json
            try:
                return json.dumps(value)
            except Exception:
                return str(value)
        
        # Handle user_id -> owner_id conversion for proposals
        if table_name == 'proposals' and col_name == 'owner_id' and dest_type in ['integer', 'bigint']:
            # If value is a string (email/username), try to look up user ID
            if isinstance(value, str):
                try:
                    # Try to find user by email or username
                    lookup_cursor = dest_conn.cursor()
                    lookup_cursor.execute('SELECT id FROM users WHERE email = %s OR username = %s', (value, value))
                    user_row = lookup_cursor.fetchone()
                    if user_row:
                        return user_row[0]  # Return integer user ID
                    else:
                        # If not found, return None (will skip this row)
                        return None
                except Exception as e:
                    return None
            elif isinstance(value, int):
                return value
            else:
                # Try to convert to int if possible
                try:
                    return int(value)
                except (ValueError, TypeError):
                    return None
        
        # Handle integer conversions for integer columns
        if dest_type in ['integer', 'bigint', 'smallint'] and not isinstance(value, int):
            try:
                return int(value)
            except (ValueError, TypeError):
                return None
        
        # Handle UUID conversions
        if dest_type == 'uuid' and isinstance(value, str):
            # If it's already a valid UUID string, return as-is
            # psycopg2 will handle the conversion
            return value
        
        return value
    
    # Migrate data in batches
    print(f"   📤 Migrating {len(rows)} rows...")
    migrated_count = 0
    error_count = 0
    skipped_rows = 0
    batch_size = 100
    
    try:
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i + batch_size]
            converted_batch = []
            
            # Convert each row
            for row in batch:
                try:
                    converted_row = []
                    for idx, col_name in enumerate(mapped_columns):
                        # Get the corresponding source column
                        source_col = mapped_source_columns[idx]
                        
                        # If source_col is None, use default value
                        if source_col is None:
                            default = get_default_value(table_name, col_name, dest_column_types.get(col_name, ''))
                            converted_row.append(default)
                            continue
                        
                        # Find the index of source_col in the original source_columns list
                        try:
                            source_idx = source_columns.index(source_col)
                            if source_idx < len(row):
                                value = row[source_idx]
                                dest_type = dest_column_types.get(col_name, '')
                                converted_value = convert_value(value, col_name, dest_type, source_col)
                                converted_row.append(converted_value)
                            else:
                                # Index out of range, use default
                                default = get_default_value(table_name, col_name, dest_column_types.get(col_name, ''))
                                converted_row.append(default)
                        except ValueError:
                            # Source column not found, use default
                            default = get_default_value(table_name, col_name, dest_column_types.get(col_name, ''))
                            converted_row.append(default)
                    
                    # Skip rows where required ID columns are NULL (can't be defaulted)
                    if 'id' in mapped_columns:
                        id_idx = mapped_columns.index('id')
                        if converted_row[id_idx] is None:
                            skipped_rows += 1
                            if skipped_rows <= 3:
                                print(f"      ⚠️  Skipping row - NULL ID value")
                            continue
                    
                    # Skip rows where owner_id conversion failed (None)
                    if table_name == 'proposals' and 'owner_id' in mapped_columns:
                        owner_idx = mapped_columns.index('owner_id')
                        if converted_row[owner_idx] is None:
                            skipped_rows += 1
                            if skipped_rows <= 3:
                                print(f"      ⚠️  Skipping row - user not found for owner_id")
                            continue
                    converted_batch.append(tuple(converted_row))
                except Exception as e:
                    error_count += 1
                    if error_count <= 3:
                        print(f"      ⚠️  Error converting row: {str(e)[:80]}")
                    continue
            
            if not converted_batch:
                continue
                
            try:
                dest_cursor.executemany(insert_sql, converted_batch)
                migrated_count += len(converted_batch)
                if (i + batch_size) % 500 == 0:
                    print(f"      ... {migrated_count} rows migrated so far")
            except psycopg2.IntegrityError as e:
                # Try inserting one by one to identify problematic rows
                if error_count == 0:
                    print(f"   ⚠️  Batch insert failed, trying individual inserts...")
                dest_conn.rollback()  # Rollback the failed batch
                for row in converted_batch:
                    try:
                        dest_cursor.execute(insert_sql, row)
                        dest_conn.commit()
                        migrated_count += 1
                    except psycopg2.IntegrityError as e2:
                        error_count += 1
                        error_msg = str(e2)
                        # Always show first 3 errors in detail
                        if error_count <= 3:
                            print(f"      ❌ Row {error_count} error: {error_msg[:150]}")
                        elif 'duplicate key' in error_msg.lower() or 'unique constraint' in error_msg.lower():
                            if error_count <= 5:
                                print(f"      ⚠️  Skipping duplicate row")
                        elif 'foreign key' in error_msg.lower():
                            if error_count <= 5:
                                print(f"      ❌ Foreign key violation")
                        else:
                            if error_count <= 5:
                                print(f"      ❌ Integrity error")
                        dest_conn.rollback()
                    except psycopg2.DataError as e2:
                        error_count += 1
                        if error_count <= 3:
                            print(f"      ❌ Data type error: {str(e2)[:150]}")
                        elif error_count <= 5:
                            print(f"      ❌ Data type error")
                        dest_conn.rollback()
                    except Exception as e2:
                        error_count += 1
                        if error_count <= 3:
                            print(f"      ❌ Error: {str(e2)[:150]}")
                        elif error_count <= 5:
                            print(f"      ❌ Error occurred")
                        dest_conn.rollback()
            except psycopg2.ProgrammingError as e:
                # Schema mismatch or data type error
                error_msg = str(e)
                if 'can\'t adapt type' in error_msg or 'invalid input syntax' in error_msg:
                    print(f"   ⚠️  Data type conversion needed. Trying individual inserts with better error handling...")
                    dest_conn.rollback()
                    # Try one by one with better error messages
                    for row_idx, row in enumerate(converted_batch):
                        try:
                            dest_cursor.execute(insert_sql, row)
                            dest_conn.commit()
                            migrated_count += 1
                        except Exception as e2:
                            error_count += 1
                            if error_count <= 3:
                                print(f"      ❌ Row {i + row_idx + 1}: {str(e2)[:120]}")
                            dest_conn.rollback()
                else:
                    print(f"   ❌ Schema mismatch error: {e}")
                    print(f"   💡 This usually means column names don't match between source and destination")
                    dest_conn.rollback()
                    return False
            except Exception as e:
                print(f"   ❌ Batch insert error: {e}")
                error_count += len(batch)
                dest_conn.rollback()
        
        if migrated_count > 0:
            dest_conn.commit()
            print(f"   ✅ Migrated {migrated_count} rows successfully")
        if error_count > 0:
            print(f"   ⚠️  {error_count} rows failed to migrate")
        
        return migrated_count > 0  # Return True if at least some rows migrated
        
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

