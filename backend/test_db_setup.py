#!/usr/bin/env python3
"""
🧪 Database Setup Test Script
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
    print("🧪 TESTING DATABASE CONNECTION")
    print("=" * 60)
    print(f"\n📍 Connection Details:")
    print(f"   Host: {DB_CONFIG['host']}")
    print(f"   Port: {DB_CONFIG['port']}")
    print(f"   Database: {DB_CONFIG['database']}")
    print(f"   User: {DB_CONFIG['user']}")
    print()
    
    try:
        # Attempt connection
        conn = psycopg2.connect(**DB_CONFIG)
        print("✅ Database connection successful!")
        
        # Test query
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        print(f"✅ PostgreSQL Version: {version[0]}")
        
        return conn, cursor
        
    except psycopg2.OperationalError as e:
        print("❌ Connection failed!")
        print(f"   Error: {e}")
        print("\n💡 Troubleshooting:")
        print("   1. Make sure PostgreSQL is running")
        print("   2. Check your .env file has correct credentials")
        print("   3. Verify the database 'khonology_proposals' exists")
        return None, None
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return None, None

def check_tables(cursor):
    """Check if all required tables exist"""
    print("\n" + "=" * 60)
    print("📊 CHECKING TABLES")
    print("=" * 60)
    
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name;
    """)
    
    existing_tables = [row[0] for row in cursor.fetchall()]
    
    print(f"\n✅ Found {len(existing_tables)} tables in database:")
    
    missing_tables = []
    for table in EXPECTED_TABLES:
        if table in existing_tables:
            print(f"   ✅ {table}")
        else:
            print(f"   ❌ {table} (MISSING)")
            missing_tables.append(table)
    
    if missing_tables:
        print(f"\n❌ Missing {len(missing_tables)} tables!")
        print("   Run the setup script: backend/setup_complete_database.sql")
        return False
    else:
        print("\n✅ All required tables exist!")
        return True

def check_sample_data(cursor):
    """Check if sample data exists"""
    print("\n" + "=" * 60)
    print("👥 CHECKING SAMPLE DATA")
    print("=" * 60)
    
    # Check users
    cursor.execute("SELECT COUNT(*) FROM users;")
    user_count = cursor.fetchone()[0]
    print(f"\n📊 Users: {user_count}")
    
    if user_count > 0:
        cursor.execute("SELECT username, email, role FROM users;")
        users = cursor.fetchall()
        for user in users:
            print(f"   ✅ {user[0]} ({user[1]}) - Role: {user[2]}")
    else:
        print("   ⚠️ No users found - you may want to run the setup script again")
    
    # Check proposals
    cursor.execute("SELECT COUNT(*) FROM proposals;")
    proposal_count = cursor.fetchone()[0]
    print(f"\n📄 Proposals: {proposal_count}")
    
    # Check clients
    cursor.execute("SELECT COUNT(*) FROM clients;")
    client_count = cursor.fetchone()[0]
    print(f"🏢 Clients: {client_count}")
    
    if client_count > 0:
        cursor.execute("SELECT name, email, organization FROM clients;")
        clients = cursor.fetchall()
        for client in clients:
            print(f"   ✅ {client[0]} ({client[1]}) - {client[2]}")

def check_indexes(cursor):
    """Check if indexes exist"""
    print("\n" + "=" * 60)
    print("⚡ CHECKING INDEXES")
    print("=" * 60)
    
    cursor.execute("""
        SELECT schemaname, tablename, indexname 
        FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND indexname LIKE 'idx_%'
        ORDER BY tablename, indexname;
    """)
    
    indexes = cursor.fetchall()
    print(f"\n✅ Found {len(indexes)} custom indexes:")
    
    current_table = None
    for idx in indexes:
        table = idx[1]
        index = idx[2]
        if table != current_table:
            print(f"\n   📊 {table}:")
            current_table = table
        print(f"      ✅ {index}")

def main():
    """Main test function"""
    # Test connection
    conn, cursor = test_connection()
    
    if not conn:
        print("\n❌ Cannot proceed without database connection")
        return False
    
    try:
        # Check tables
        tables_ok = check_tables(cursor)
        
        if not tables_ok:
            return False
        
        # Check sample data
        check_sample_data(cursor)
        
        # Check indexes
        check_indexes(cursor)
        
        # Success summary
        print("\n" + "=" * 60)
        print("✅ DATABASE SETUP VERIFICATION COMPLETE!")
        print("=" * 60)
        print("\n🎉 Your database is ready to use!")
        print("\n📝 Test Login Credentials:")
        print("   Email: admin@khonology.com")
        print("   Password: password123")
        print("\n🚀 Start your backend: python app.py")
        print("🎨 Start your frontend: flutter run -d chrome")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error during verification: {e}")
        return False
    
    finally:
        cursor.close()
        conn.close()
        print("\n🔒 Database connection closed")

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)












