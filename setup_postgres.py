#!/usr/bin/env python3
"""
Setup PostgreSQL database for the Proposal & SOW Builder
"""
import psycopg2
import os
from dotenv import load_dotenv

load_dotenv()

# Connect to default postgres database
try:
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD'),
        port=os.getenv('DB_PORT', '5432'),
        database='postgres'
    )
    
    conn.autocommit = True
    cursor = conn.cursor()
    
    db_name = os.getenv('DB_NAME', 'proposal_sow_builder')
    
    # Check if database exists
    cursor.execute(f"SELECT 1 FROM pg_database WHERE datname = '{db_name}'")
    exists = cursor.fetchone()
    
    if not exists:
        print(f"📝 Creating database '{db_name}'...")
        cursor.execute(f"CREATE DATABASE {db_name}")
        print(f"✅ Database '{db_name}' created successfully!")
    else:
        print(f"✅ Database '{db_name}' already exists")
    
    cursor.close()
    conn.close()
    
    print("\n✅ PostgreSQL setup completed successfully!")
    
except Exception as e:
    print(f"❌ Error setting up PostgreSQL: {e}")
    exit(1)