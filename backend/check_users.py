import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

def check_users():
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "5432")),
            dbname=os.getenv("DB_NAME", "proposal_sow_builder"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123")),
        )
        
        with conn.cursor() as cur:
            # Check users table schema
            cur.execute("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_name = 'users'
                ORDER BY ordinal_position
            """)
            columns = cur.fetchall()
            print("=== USERS TABLE SCHEMA ===")
            for col in columns:
                print(f"Column: {col[0]}, Type: {col[1]}")
            
            # Check all users
            cur.execute("SELECT * FROM users ORDER BY id DESC LIMIT 10")
            users = cur.fetchall()
            print("\n=== RECENT USERS ===")
            for user in users:
                print(f"User: {user}")
            
            # Check specifically for the user from the logs
            cur.execute("SELECT id, username, email FROM users WHERE email = %s", ('modise.sithebe@khonology.com',))
            user = cur.fetchone()
            if user:
                print(f"\n=== FOUND USER ===")
                print(f"ID: {user[0]}, Username: {user[1]}, Email: {user[2]}")
            else:
                print("\n=== USER NOT FOUND ===")
                print("User with email modise.sithebe@khonology.com not found in database")
        
        conn.close()
        print("Database connection successful!")
        
    except Exception as e:
        print(f"Database connection failed: {e}")

if __name__ == "__main__":
    check_users()
