import os
import json
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

# Try to load environment variables
load_dotenv('backend/.env')
db_url = os.getenv('DATABASE_URL')

def check_db_schema_and_data():
    # If the internal Render URL fails (dpg-xxx-a), we might be on a different network.
    # We can try to replace the internal host with the external one if known, 
    # but for now let's just try to connect.
    
    if not db_url:
        print("DATABASE_URL not found")
        return

    try:
        # If it's a Render internal URL, it might not work from a local machine 
        # unless it's the external one. 
        # The user's DATABASE_URL: postgresql://sowbuilder_jdyx_user:LvUDRxCLtJSQn7tTKhux50kfCsL89cuF@dpg-d61mhge3jp1c7390jcm0-a/sowbuilder_jdyx
        
        # Construct the external hostname (standard Render format)
        external_url = db_url.replace('@dpg-d61mhge3jp1c7390jcm0-a', '@dpg-d61mhge3jp1c7390jcm0-a.oregon-postgres.render.com')
        
        print(f"Connecting to: {external_url.split('@')[1]}")
        conn = psycopg2.connect(external_url)
        
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # 1. Check if columns exist
            cur.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'clients'
            """)
            columns = [row['column_name'] for row in cur.fetchall()]
            print(f"\n[SCHEMA] Columns in 'clients' table: {columns}")
            
            # 2. Check the most recently updated client
            cur.execute("""
                SELECT id, company_name, email, holding_information, address, 
                       client_contact_mobile, client_contact_email, additional_info, 
                       updated_at 
                FROM clients 
                ORDER BY updated_at DESC LIMIT 1
            """)
            client = cur.fetchone()
            
            if client:
                print(f"\n[DATA] Most recently updated client:")
                print(f"  ID: {client['id']}")
                print(f"  Name: {client['company_name']}")
                print(f"  Holding: {client['holding_information']}")
                print(f"  Address: {client['address']}")
                print(f"  Mobile: {client['client_contact_mobile']}")
                print(f"  Email: {client['client_contact_email']}")
                print(f"  Additional Info: {client['additional_info']}")
                print(f"  Updated At: {client['updated_at']}")
            else:
                print("\n[DATA] No clients found in table.")
                
    except Exception as e:
        print(f"\n[ERROR] Connection failed: {e}")
        print("This usually means the external hostname is different or the DB is restricted to Render's network.")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    check_db_schema_and_data()
