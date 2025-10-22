#!/usr/bin/env python3
import psycopg2

try:
    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="proposal_sow_builder",
        user="postgres",
        password="Password123"
    )
    cursor = conn.cursor()
    
    # Delete all users
    cursor.execute("DELETE FROM users;")
    deleted_rows = cursor.rowcount
    conn.commit()
    
    print(f"✅ Successfully deleted {deleted_rows} users from the database")
    
    # Show current user count
    cursor.execute("SELECT COUNT(*) FROM users;")
    count = cursor.fetchone()[0]
    print(f"📊 Users remaining in database: {count}")
    
    cursor.close()
    conn.close()
    
except Exception as e:
    print(f"❌ Error: {e}")