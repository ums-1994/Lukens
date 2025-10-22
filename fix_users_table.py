#!/usr/bin/env python3
"""
Fix the users table schema by dropping and recreating it
"""
import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

# Database configuration
db_config = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'database': os.getenv('DB_NAME', 'proposal_db'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', ''),
    'port': int(os.getenv('DB_PORT', '5432'))
}

try:
    conn = psycopg2.connect(**db_config)
    cursor = conn.cursor()
    
    print("🗑️  Dropping old users table...")
    cursor.execute('DROP TABLE IF EXISTS users CASCADE;')
    
    print("✅ Creating new users table with correct schema...")
    cursor.execute('''CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(255),
        role VARCHAR(50) DEFAULT 'user',
        department VARCHAR(255),
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )''')
    
    print("✅ Creating verify_tokens table...")
    cursor.execute('''CREATE TABLE IF NOT EXISTS verify_tokens (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) NOT NULL,
        token VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP NOT NULL
    )''')
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print("✅ Database tables fixed successfully!")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()