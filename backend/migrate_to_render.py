"""
Migrate tables from local database to Render database
"""
import psycopg2
from psycopg2 import sql
import ssl
import sys

# Local database
LOCAL_DB = {
    'host': 'localhost',
    'port': 5432,
    'database': 'proposal_sow_builder',
    'user': 'postgres',
    'password': 'Password123'
}

# Render database (INTERNAL connection string - use from Render env vars)
RENDER_CONNECTION_STRING = "postgresql://sowbuilder_jdyx_user:LvUDRxCLtJSQn7tTKhux50kfCsL89cuF@dpg-d61mhge3jp1c7390jcm0-a/sowbuilder_jdyx"

def connect_to_local():
    """Connect to local database"""
    try:
        conn = psycopg2.connect(**LOCAL_DB)
        print("✅ Connected to local database")
        return conn
    except Exception as e:
        print(f"❌ Failed to connect to local DB: {e}")
        return None

def connect_to_render():
    """Connect to Render database with SSL"""
    try:
        conn = psycopg2.connect(RENDER_CONNECTION_STRING)
        print("✅ Connected to Render database")
        return conn
    except Exception as e:
        print(f"❌ Failed to connect to Render DB: {e}")
        # Try alternative connection methods
        print("\n🔄 Trying alternative SSL settings...")
        try:
            conn = psycopg2.connect(
                host='dpg-d61mhge3jp1c7390jcm0-a.oregon-postgres.render.com',
                port=5432,
                database='sowbuilder_jdyx',
                user='sowbuilder_jdyx_user',
                password='LvUDRxCLtJSQn7tTKhux50kfCsL89cuF',
                sslmode='prefer'
            )
            print("✅ Connected to Render with sslmode=prefer")
            return conn
        except Exception as e2:
            print(f"❌ Alternative connection also failed: {e2}")
            return None

def get_tables(conn):
    """Get all tables from database"""
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)
        tables = [row[0] for row in cursor.fetchall()]
        cursor.close()
        return tables
    except Exception as e:
        print(f"❌ Error getting tables: {e}")
        return []

def copy_table_data(local_conn, render_conn, table_name):
    """Copy table structure and data from local to Render"""
    try:
        local_cursor = local_conn.cursor()
        render_cursor = render_conn.cursor()
        
        # Get table definition
        local_cursor.execute(f"""
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_name = %s
            ORDER BY ordinal_position
        """, (table_name,))
        
        columns = local_cursor.fetchall()
        
        # Drop existing table in Render
        try:
            render_cursor.execute(f"DROP TABLE IF EXISTS {sql.Identifier(table_name).as_string(render_cursor)} CASCADE")
            render_conn.commit()
        except:
            pass
        
        # Build CREATE TABLE statement
        col_defs = []
        for col_name, data_type, is_nullable, col_default in columns:
            col_def = f"{col_name} {data_type}"
            if col_default:
                col_def += f" DEFAULT {col_default}"
            if is_nullable == 'NO':
                col_def += " NOT NULL"
            col_defs.append(col_def)
        
        create_table_sql = f"CREATE TABLE {sql.Identifier(table_name).as_string(render_cursor)} ({', '.join(col_defs)})"
        render_cursor.execute(create_table_sql)
        render_conn.commit()
        
        # Get column names
        col_names = [col[0] for col in columns]
        
        # Copy data
        local_cursor.execute(f"SELECT * FROM {sql.Identifier(table_name).as_string(local_cursor)}")
        rows = local_cursor.fetchall()
        
        if rows:
            col_names_str = ', '.join([sql.Identifier(c).as_string(render_cursor) for c in col_names])
            placeholders = ', '.join(['%s'] * len(col_names))
            insert_sql = f"INSERT INTO {sql.Identifier(table_name).as_string(render_cursor)} ({col_names_str}) VALUES ({placeholders})"
            render_cursor.executemany(insert_sql, rows)
            render_conn.commit()
        
        print(f"✅ Migrated '{table_name}' ({len(rows)} rows)")
        local_cursor.close()
        render_cursor.close()
        return True
        
    except Exception as e:
        print(f"❌ Error migrating '{table_name}': {e}")
        try:
            render_conn.rollback()
        except:
            pass
        return False

def main():
    print("🔄 Starting database migration (Local → Render)\n")
    
    # Connect to databases
    print("📍 Connecting to local database...")
    local_conn = connect_to_local()
    if not local_conn:
        sys.exit(1)
    
    print("🌐 Connecting to Render database...")
    render_conn = connect_to_render()
    if not render_conn:
        local_conn.close()
        sys.exit(1)
    
    # Get tables
    print("\n📋 Fetching tables from local database...")
    tables = get_tables(local_conn)
    print(f"Found {len(tables)} tables: {tables}\n")
    
    if not tables:
        print("⚠️  No tables found in local database")
        local_conn.close()
        render_conn.close()
        sys.exit(0)
    
    # Migrate tables
    print("🚀 Starting migration...\n")
    success = 0
    failed = 0
    
    for table in tables:
        if copy_table_data(local_conn, render_conn, table):
            success += 1
        else:
            failed += 1
    
    print(f"\n✅ Migration complete! {success} tables migrated, {failed} failed")
    
    local_conn.close()
    render_conn.close()

if __name__ == '__main__':
    main()

