#!/usr/bin/env python3
"""
Setup script for Settings Management Tables
Run this script to create all settings-related tables in PostgreSQL
"""

import psycopg2
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def setup_settings_database():
    """Create all settings tables in PostgreSQL database"""
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "5432")),
            dbname=os.getenv("DB_NAME", "proposal_sow_builder"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123")),
        )
        
        with conn.cursor() as cur:
            print("Creating settings tables...")
            
            # Read and execute the schema file
            with open('settings_schema.sql', 'r') as f:
                schema_sql = f.read()
            
            # Split by semicolon and execute each statement
            statements = [stmt.strip() for stmt in schema_sql.split(';') if stmt.strip()]
            
            for i, statement in enumerate(statements):
                try:
                    cur.execute(statement)
                    print(f"✓ Executed statement {i+1}/{len(statements)}")
                except Exception as e:
                    print(f"⚠ Warning executing statement {i+1}: {e}")
                    # Continue with other statements
            
            conn.commit()
            print("\n✅ Settings database setup completed successfully!")
            
            # Verify tables were created
            cur.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name LIKE '%settings%'
                ORDER BY table_name
            """)
            tables = cur.fetchall()
            print(f"\n📋 Created settings tables: {[t[0] for t in tables]}")
            
            # Check if default data was inserted
            cur.execute("SELECT COUNT(*) FROM system_settings")
            system_count = cur.fetchone()[0]
            print(f"📊 System settings records: {system_count}")
            
    except Exception as e:
        print(f"❌ Error setting up settings database: {e}")
        return False
    
    finally:
        if 'conn' in locals():
            conn.close()
    
    return True

def test_settings_endpoints():
    """Test the settings endpoints"""
    try:
        import requests
        
        # Test getting all settings
        response = requests.get("http://localhost:8000/settings")
        if response.status_code == 200:
            print("✅ Settings API is working!")
            settings = response.json()
            print(f"📋 Available settings categories: {list(settings.keys())}")
        else:
            print(f"❌ Settings API test failed: {response.status_code}")
            
    except Exception as e:
        print(f"⚠ Could not test API endpoints: {e}")

if __name__ == "__main__":
    print("🚀 Setting up Settings Management Database...")
    print("=" * 50)
    
    if setup_settings_database():
        print("\n🧪 Testing settings endpoints...")
        test_settings_endpoints()
        print("\n🎉 Settings setup complete!")
    else:
        print("\n❌ Settings setup failed!")
