#!/usr/bin/env python3
"""
Create missing tables on Render by copying structure from local database
"""
import os
import sys
import psycopg2
from dotenv import load_dotenv

load_dotenv()

# Source (local) - to get table structures
SOURCE_CONFIG = {
    'host': os.getenv('SOURCE_DB_HOST', 'localhost'),
    'database': os.getenv('SOURCE_DB_NAME', 'proposal_sow_builder'),
    'user': os.getenv('SOURCE_DB_USER', 'postgres'),
    'password': os.getenv('SOURCE_DB_PASSWORD', 'Password123'),
    'port': int(os.getenv('SOURCE_DB_PORT', '5432')),
}

# Destination (Render) - to create tables
DEST_CONFIG = {
    'host': os.getenv('DEST_DB_HOST', 'dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com'),
    'database': os.getenv('DEST_DB_NAME', 'proposal_sow_builder'),
    'user': os.getenv('DEST_DB_USER', 'proposal_sow_builder_user'),
    'password': os.getenv('DEST_DB_PASSWORD', 'LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez'),
    'port': int(os.getenv('DEST_DB_PORT', '5432')),
    'sslmode': 'prefer',
    'connect_timeout': 30,
}

# Ensure full domain for Render
if DEST_CONFIG['host'].startswith('dpg-') and DEST_CONFIG['host'].endswith('-a'):
    DEST_CONFIG['host'] = f"{DEST_CONFIG['host']}.oregon-postgres.render.com"

# List of missing tables (from migration output)
MISSING_TABLES = [
    'comments',
    'proposal_client_activity',
    'ai_settings',
    'approvals',
    'client_dashboard_tokens',
    'content_blocks',
    'content_library',
    'content_modules',
    'database_settings',
    'email_settings',
    'module_versions',
    'proposal_client_session',
    'proposal_feedback',
    'proposal_system_feedback',
    'proposal_system_proposals',
    'proposal_users',
    'sows',
    'system_settings',
    'team_members',
    'teams',
    'templates',
    'user_preferences',
    'verification_tokens',
    'verify_tokens',
    'workspace_documents',
    'workspace_members',
    'workspaces',
]

def get_table_ddl(conn, table_name):
    """Get CREATE TABLE statement for a table using pg_dump approach"""
    cursor = conn.cursor()
    try:
        # Get column definitions
        cursor.execute("""
            SELECT 
                column_name,
                data_type,
                udt_name,
                character_maximum_length,
                numeric_precision,
                numeric_scale,
                is_nullable,
                column_default,
                ordinal_position
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = %s
            ORDER BY ordinal_position;
        """, (table_name,))
        
        columns = cursor.fetchall()
        if not columns:
            return None
        
        # Build column definitions
        col_defs = []
        sequences_to_create = []
        
        for col in columns:
            col_name, data_type, udt_name, char_max, num_prec, num_scale, nullable, default, _ = col
            
            # Build type
            if data_type == 'ARRAY':
                # Get base type from udt_name (remove _array suffix)
                base_type = udt_name.replace('_array', '').replace('_', '')
                if 'text' in base_type.lower() or base_type == 'varchar':
                    col_type = 'TEXT[]'
                elif 'int' in base_type.lower():
                    col_type = 'INTEGER[]'
                elif base_type == 'uuid':
                    col_type = 'UUID[]'
                else:
                    # Use the base type directly
                    col_type = f'{base_type.upper()}[]'
            elif data_type == 'character varying':
                col_type = f'VARCHAR({char_max})' if char_max else 'VARCHAR'
            elif data_type == 'character':
                col_type = f'CHAR({char_max})' if char_max else 'CHAR'
            elif data_type == 'numeric':
                col_type = f'NUMERIC({num_prec},{num_scale})' if num_prec else 'NUMERIC'
            elif data_type == 'timestamp without time zone':
                col_type = 'TIMESTAMP'
            elif data_type == 'timestamp with time zone':
                col_type = 'TIMESTAMPTZ'
            elif data_type == 'double precision':
                col_type = 'DOUBLE PRECISION'
            elif udt_name == 'uuid':
                col_type = 'UUID'
            elif udt_name == 'jsonb':
                col_type = 'JSONB'
            elif udt_name == 'json':
                col_type = 'JSON'
            else:
                col_type = udt_name.upper() if udt_name else data_type.upper()
            
            # Build column definition
            col_def = f'"{col_name}" {col_type}'
            
            # Handle defaults
            if default:
                # Check if it's a sequence (SERIAL)
                if 'nextval' in str(default):
                    # Use SERIAL instead
                    if col_type in ['INTEGER', 'INT']:
                        col_def = f'"{col_name}" SERIAL'
                        sequences_to_create.append(f'{table_name}_{col_name}_seq')
                    elif col_type in ['BIGINT']:
                        col_def = f'"{col_name}" BIGSERIAL'
                        sequences_to_create.append(f'{table_name}_{col_name}_seq')
                elif 'uuid_generate_v4()' in str(default):
                    col_def += ' DEFAULT gen_random_uuid()'
                else:
                    # Clean up default value
                    clean_default = str(default).replace('::' + udt_name, '')
                    col_def += f' DEFAULT {clean_default}'
            
            # Add NOT NULL
            if nullable == 'NO':
                col_def += ' NOT NULL'
            
            col_defs.append(col_def)
        
        # Build CREATE TABLE statement
        ddl = f'CREATE TABLE IF NOT EXISTS "{table_name}" (\n    ' + ',\n    '.join(col_defs) + '\n);'
        
        return ddl
    except Exception as e:
        print(f"   ⚠️  Could not get DDL for {table_name}: {e}")
        import traceback
        traceback.print_exc()
        return None
    finally:
        cursor.close()

def create_table_from_source(source_conn, dest_conn, table_name):
    """Create a table on destination using structure from source"""
    try:
        # Enable UUID extension if needed
        dest_cursor = dest_conn.cursor()
        try:
            dest_cursor.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")
            dest_conn.commit()
        except:
            dest_conn.rollback()
        dest_cursor.close()
        
        # Get table structure from source
        ddl = get_table_ddl(source_conn, table_name)
        if not ddl:
            print(f"   ❌ Could not get DDL for {table_name}")
            return False
        
        # Execute on destination
        dest_cursor = dest_conn.cursor()
        try:
            dest_cursor.execute(ddl)
            dest_conn.commit()
            print(f"   ✅ Created table {table_name}")
            return True
        except psycopg2.errors.DuplicateTable:
            print(f"   ⏭️  Table {table_name} already exists")
            dest_conn.rollback()
            return True
        except Exception as e:
            print(f"   ❌ Error creating {table_name}: {e}")
            dest_conn.rollback()
            return False
        finally:
            dest_cursor.close()
    except Exception as e:
        print(f"   ❌ Error processing {table_name}: {e}")
        return False

def main():
    print("=" * 70)
    print("🔧 Creating Missing Tables on Render")
    print("=" * 70)
    print()
    
    # Connect to source
    print("📥 Connecting to source (local)...")
    try:
        source_conn = psycopg2.connect(**SOURCE_CONFIG)
        print("✅ Connected to source")
    except Exception as e:
        print(f"❌ Failed to connect to source: {e}")
        return 1
    
    # Connect to destination
    print("📤 Connecting to destination (Render)...")
    try:
        dest_conn = psycopg2.connect(**DEST_CONFIG)
        print("✅ Connected to destination")
    except Exception as e:
        print(f"❌ Failed to connect to destination: {e}")
        source_conn.close()
        return 1
    
    print()
    print(f"📋 Creating {len(MISSING_TABLES)} missing tables...")
    print()
    
    created = 0
    failed = 0
    
    for table in MISSING_TABLES:
        print(f"📦 Creating table: {table}")
        if create_table_from_source(source_conn, dest_conn, table):
            created += 1
        else:
            failed += 1
        print()
    
    source_conn.close()
    dest_conn.close()
    
    print("=" * 70)
    print(f"✅ Created: {created} tables")
    if failed > 0:
        print(f"❌ Failed: {failed} tables")
    print("=" * 70)
    
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())

