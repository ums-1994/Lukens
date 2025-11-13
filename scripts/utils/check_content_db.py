#!/usr/bin/env python3
import psycopg2
import json

try:
    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        database="proposal_sow_builder",
        user="postgres",
        password="Password123"
    )
    
    with conn.cursor() as cur:
        # Check if table exists
        cur.execute("""
            SELECT EXISTS(
                SELECT FROM information_schema.tables 
                WHERE table_name = 'content_blocks'
            )
        """)
        table_exists = cur.fetchone()[0]
        print(f"Table exists: {table_exists}")
        
        if table_exists:
            # Get row count
            cur.execute("SELECT COUNT(*) FROM content_blocks")
            count = cur.fetchone()[0]
            print(f"Total rows: {count}")
            
            # Get columns
            cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name='content_blocks' ORDER BY ordinal_position")
            columns = [row[0] for row in cur.fetchall()]
            print(f"Columns: {columns}")
            
            # Get first 10 rows
            cur.execute("SELECT * FROM content_blocks LIMIT 10")
            rows = cur.fetchall()
            print(f"\nFirst {len(rows)} rows:")
            for row in rows:
                print(json.dumps(dict(zip(columns, row)), indent=2, default=str))
        
    conn.close()
    print("\n✓ Database connection successful!")
    
except Exception as e:
    print(f"✗ Error: {e}")