#!/usr/bin/env python3
"""Test PostgreSQL and SQLite database connections"""

import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_postgresql():
    """Test PostgreSQL connection"""
    print("🔍 Testing PostgreSQL Connection...")
    try:
        import psycopg2
        
        config = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'database': os.getenv('DB_NAME', 'proposal_db'),
            'user': os.getenv('DB_USER', 'postgres'),
            'password': os.getenv('DB_PASSWORD', ''),
            'port': os.getenv('DB_PORT', '5432')
        }
        
        print(f"  Connecting to: {config['host']}:{config['port']}/{config['database']}")
        print(f"  User: {config['user']}")
        
        conn = psycopg2.connect(**config)
        print("  ✅ PostgreSQL connection successful!")
        
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        print(f"  PostgreSQL version: {version[0]}")
        
        # Check if tables exist
        cursor.execute("""
            SELECT table_name FROM information_schema.tables 
            WHERE table_schema = 'public'
        """)
        tables = cursor.fetchall()
        print(f"  Existing tables: {len(tables)}")
        if tables:
            for table in tables:
                print(f"    - {table[0]}")
        
        conn.close()
        return True
    except Exception as e:
        print(f"  ❌ PostgreSQL connection failed: {e}")
        return False

def test_sqlite():
    """Test SQLite connection"""
    print("\n🔍 Testing SQLite Connection...")
    try:
        import sqlite3
        
        db_path = os.getenv('DB_PATH', ':memory:')
        print(f"  Database: {db_path}")
        
        conn = sqlite3.connect(db_path)
        print("  ✅ SQLite connection successful!")
        
        cursor = conn.cursor()
        cursor.execute("SELECT sqlite_version();")
        version = cursor.fetchone()
        print(f"  SQLite version: {version[0]}")
        
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        print(f"  Existing tables: {len(tables)}")
        if tables:
            for table in tables:
                print(f"    - {table[0]}")
        
        conn.close()
        return True
    except Exception as e:
        print(f"  ❌ SQLite connection failed: {e}")
        return False

def main():
    backend_type = os.getenv('BACKEND_TYPE', 'sqlite')
    
    print("=" * 60)
    print("DATABASE CONNECTION TEST")
    print("=" * 60)
    print(f"Backend type: {backend_type.upper()}")
    print("=" * 60 + "\n")
    
    if backend_type == 'postgresql':
        success = test_postgresql()
    else:
        success = test_sqlite()
    
    print("\n" + "=" * 60)
    if success:
        print("✅ Database test completed successfully!")
        print("\nYou can now start the server with:")
        print("  python start_python_backend.py")
    else:
        print("❌ Database test failed. Please check your configuration.")
        if backend_type == 'postgresql':
            print("\nMake sure:")
            print("  1. PostgreSQL server is running")
            print("  2. Database exists: " + os.getenv('DB_NAME', 'proposal_db'))
            print("  3. User credentials are correct")
        sys.exit(1)
    print("=" * 60)

if __name__ == "__main__":
    main()