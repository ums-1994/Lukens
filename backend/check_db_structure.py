#!/usr/bin/env python3
"""
Check existing database structure
"""
import os
from dotenv import load_dotenv
import psycopg2

def check_database_structure():
    load_dotenv()
    
    try:
        # Connect to your database
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', '5432'),
            database=os.getenv('DB_NAME', 'proposal_sow_builder'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', 'Password123')
        )
        
        cur = conn.cursor()
        
        # Check existing tables
        cur.execute("""
            SELECT table_name, column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name IN ('proposals', 'clients') 
            ORDER BY table_name, ordinal_position;
        """)
        
        print("Existing tables structure:")
        for row in cur.fetchall():
            print(f"{row[0]}.{row[1]}: {row[2]}")
        
        # Check if tables exist
        cur.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('proposals', 'clients');
        """)
        
        existing_tables = [row[0] for row in cur.fetchall()]
        print(f"\nExisting tables: {existing_tables}")
        
        cur.close()
        conn.close()
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_database_structure()
