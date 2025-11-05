#!/usr/bin/env python3
"""
Database Setup Test Script (Windows-compatible)
Run this after setting up your PostgreSQL database to verify everything works
"""

import psycopg2
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'khonology_proposals'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', ''),
}

EXPECTED_TABLES = [
    'users',
    'proposals',
    'content',
    'settings',
    'proposal_versions',
    'document_comments',
    'collaboration_invitations',
    'collaboration_sessions',
    'clients',
    'approvals',
    'client_dashboard_tokens',
    'proposal_feedback',
]

def test_connection():
    """Test database connection"""
    print("=" * 60)
    print("TESTING DATABASE CONNECTION")
    print("=" * 60)
    print("\nConnection Details:")
    print(f"   Host: {DB_CONFIG['host']}")
    print(f"   Port: {DB_CONFIG['port']}")
    print(f"   Database: {DB_CONFIG['database']}")
    print(f"   User: {DB_CONFIG['user']}")
    print()
    
    try:
        # Attempt connection
        conn = psycopg2.connect(**DB_CONFIG)
        print("[SUCCESS] Database connection successful!")
        
        # Test query
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        print(f"[SUCCESS] PostgreSQL Version: {version[0][:50]}...")
        
        return conn, cursor
        
    except psycopg2.OperationalError as e:
        print("[ERROR] Connection failed!")
        print(f"   Error: {e}")
        print("\nTroubleshooting:")
        print("   1. Make sure PostgreSQL is running")
        print("   2. Check your .env file has correct credentials")
        print("   3. Verify the database exists in pgAdmin")
        return None, None
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}")
        return None, None

def check_tables(cursor):
    """Check if all required tables exist"""
    print("\n" + "=" * 60)
    print("CHECKING TABLES")
    print("=" * 60)
    
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name;
    """)
    
    existing_tables = [row[0] for row in cursor.fetchall()]
    
    print(f"\n[INFO] Found {len(existing_tables)} tables in database:")
    
    missing_tables = []
    for table in EXPECTED_TABLES:
        if table in existing_tables:
            print(f"   [OK] {table}")
        else:
            print(f"   [MISSING] {table}")
            missing_tables.append(table)
    
    if missing_tables:
        print(f"\n[ERROR] Missing {len(missing_tables)} tables!")
        print("   Action: Run backend/setup_complete_database.sql in pgAdmin")
        return False
    else:
        print("\n[SUCCESS] All required tables exist!")
        return True

def check_sample_data(cursor):
    """Check if sample data exists"""
    print("\n" + "=" * 60)
    print("CHECKING SAMPLE DATA")
    print("=" * 60)
    
    # Check users
    cursor.execute("SELECT COUNT(*) FROM users;")
    user_count = cursor.fetchone()[0]
    print(f"\n[INFO] Users: {user_count}")
    
    if user_count > 0:
        cursor.execute("SELECT username, email, role FROM users;")
        users = cursor.fetchall()
        for user in users:
            print(f"   [OK] {user[0]} ({user[1]}) - Role: {user[2]}")
    else:
        print("   [WARNING] No users found")
    
    # Check proposals
    cursor.execute("SELECT COUNT(*) FROM proposals;")
    proposal_count = cursor.fetchone()[0]
    print(f"\n[INFO] Proposals: {proposal_count}")
    
    # Check clients
    cursor.execute("SELECT COUNT(*) FROM clients;")
    client_count = cursor.fetchone()[0]
    print(f"[INFO] Clients: {client_count}")
    
    if client_count > 0:
        cursor.execute("SELECT name, email, organization FROM clients;")
        clients = cursor.fetchall()
        for client in clients:
            print(f"   [OK] {client[0]} ({client[1]}) - {client[2]}")

def main():
    """Main test function"""
    # Test connection
    conn, cursor = test_connection()
    
    if not conn:
        print("\n[ERROR] Cannot proceed without database connection")
        print("\nNext Steps:")
        print("1. Make sure you created backend/.env file")
        print("2. Update DB_PASSWORD in .env with your PostgreSQL password")
        print("3. Verify PostgreSQL service is running")
        print("4. Make sure database 'khonology_proposals' exists in pgAdmin")
        return False
    
    try:
        # Check tables
        tables_ok = check_tables(cursor)
        
        if not tables_ok:
            print("\n[ERROR] Database schema incomplete!")
            print("\nNext Steps:")
            print("1. Open pgAdmin 4")
            print("2. Right-click 'khonology_proposals' database")
            print("3. Select 'Query Tool'")
            print("4. Open backend/setup_complete_database.sql")
            print("5. Copy all contents and paste in Query Tool")
            print("6. Click Execute button")
            return False
        
        # Check sample data
        check_sample_data(cursor)
        
        # Success summary
        print("\n" + "=" * 60)
        print("DATABASE SETUP VERIFICATION COMPLETE!")
        print("=" * 60)
        print("\n[SUCCESS] Your database is ready to use!")
        print("\nTest Login Credentials:")
        print("   Email: admin@khonology.com")
        print("   Password: password123")
        print("\nNext Steps:")
        print("   1. Start backend: python app.py")
        print("   2. Start frontend: flutter run -d chrome")
        print("   3. Login with test credentials above")
        
        return True
        
    except Exception as e:
        print(f"\n[ERROR] Error during verification: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        cursor.close()
        conn.close()
        print("\n[INFO] Database connection closed")

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)





