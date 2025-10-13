import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

def check_database():
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "5432")),
            dbname=os.getenv("DB_NAME", "proposal_sow_builder"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123")),
        )
        
        with conn.cursor() as cur:
            # Check if proposals table exists
            cur.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name LIKE '%proposal%'
            """)
            tables = cur.fetchall()
            print("Tables with 'proposal' in name:", tables)
            
            # Check all tables
            cur.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name
            """)
            all_tables = cur.fetchall()
            print("All tables:", [t[0] for t in all_tables])
            
            # If proposals table exists, check its structure
            if any('proposal' in t[0].lower() for t in tables):
                cur.execute("""
                    SELECT column_name, data_type 
                    FROM information_schema.columns 
                    WHERE table_name = 'proposals'
                    ORDER BY ordinal_position
                """)
                columns = cur.fetchall()
                print("Proposals table columns:", columns)
                
                # Check if there's any data
                cur.execute("SELECT COUNT(*) FROM proposals")
                count = cur.fetchone()[0]
                print(f"Number of proposals in database: {count}")
                
                if count > 0:
                    cur.execute("SELECT id, title, client, status FROM proposals LIMIT 5")
                    sample_data = cur.fetchall()
                    print("Sample proposal data:", sample_data)
        
        conn.close()
        print("Database connection successful!")
        
    except Exception as e:
        print(f"Database connection failed: {e}")

if __name__ == "__main__":
    check_database()
