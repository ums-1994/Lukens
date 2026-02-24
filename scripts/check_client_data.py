import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv('backend/.env')
db_url = os.getenv('DATABASE_URL')

def check_clients():
    if not db_url:
        print("DATABASE_URL not found in backend/.env")
        return
    
    try:
        conn = psycopg2.connect(db_url)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Check columns
            cur.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'clients'
            """)
            columns = [row['column_name'] for row in cur.fetchall()]
            print(f"Columns in 'clients' table: {columns}")
            
            # Check data
            cur.execute("SELECT * FROM clients ORDER BY created_at DESC LIMIT 5")
            rows = cur.fetchall()
            print("\nLatest 5 clients:")
            for row in rows:
                print(f"ID: {row.get('id')}, Name: {row.get('company_name') or row.get('name')}")
                print(f"  Holding: {row.get('holding_information')}")
                print(f"  Address: {row.get('address')}")
                print(f"  Mobile: {row.get('client_contact_mobile')}")
                print(f"  Addtl Info: {row.get('additional_info')}")
                print("-" * 20)
                
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    check_clients()
