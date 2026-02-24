import os
import psycopg2
from dotenv import load_dotenv

load_dotenv('backend/.env')
db_url = os.getenv('DATABASE_URL')

def run_migration():
    if not db_url:
        print("DATABASE_URL not found")
        return

    # Construct the external hostname for Render
    external_url = db_url.replace('@dpg-d61mhge3jp1c7390jcm0-a', '@dpg-d61mhge3jp1c7390jcm0-a.oregon-postgres.render.com')
    
    migration_path = 'backend/sql/add_missing_client_columns.sql'
    
    try:
        print(f"Applying migration to: {external_url.split('@')[1]}")
        with open(migration_path, 'r') as f:
            sql = f.read()
            
        conn = psycopg2.connect(external_url)
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(sql)
            print("Migration successful: Columns added to 'clients' table.")
            
    except Exception as e:
        print(f"Migration failed: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    run_migration()
