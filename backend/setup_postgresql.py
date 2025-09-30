#!/usr/bin/env python3
"""
PostgreSQL Setup Script for Proposal Builder
This script helps set up the PostgreSQL database and run migrations
"""

import os
import sys
import psycopg2
from pathlib import Path

def check_environment():
    """Check if required environment variables are set"""
    required_vars = ['DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD']
    missing_vars = []
    
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print("❌ Missing required environment variables:")
        for var in missing_vars:
            print(f"   - {var}")
        print("\nPlease set these in your .env file or environment")
        return False
    
    return True

def test_connection():
    """Test database connection"""
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "5432")),
            dbname=os.getenv("DB_NAME", "proposal_sow_builder"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123"))
        )
        conn.close()
        print("✅ Database connection successful")
        return True
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False

def run_migrations():
    """Run database migrations"""
    try:
        # Import and run the migration script
        sys.path.append(str(Path(__file__).parent))
        from run_migration import main as run_migrations_main
        run_migrations_main()
        return True
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return False

def verify_setup():
    """Verify the setup by checking if tables exist"""
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "5432")),
            dbname=os.getenv("DB_NAME", "proposal_sow_builder"),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123"))
        )
        cur = conn.cursor()
        
        # Check if proposal_versions table exists
        cur.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'proposal_versions'
            );
        """)
        
        table_exists = cur.fetchone()[0]
        
        if table_exists:
            print("✅ proposal_versions table exists")
            
            # Check table structure
            cur.execute("""
                SELECT column_name, data_type 
                FROM information_schema.columns 
                WHERE table_name = 'proposal_versions'
                ORDER BY ordinal_position;
            """)
            
            columns = cur.fetchall()
            print("📋 Table structure:")
            for col_name, col_type in columns:
                print(f"   - {col_name}: {col_type}")
        else:
            print("❌ proposal_versions table not found")
            return False
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Verification failed: {e}")
        return False

def main():
    """Main setup function"""
    print("🚀 Setting up PostgreSQL for Proposal Builder...")
    print("=" * 50)
    
    # Step 1: Check environment
    print("\n1. Checking environment variables...")
    if not check_environment():
        print("\n💡 Create a .env file with:")
        print("DB_HOST=localhost")
        print("DB_PORT=5432")
        print("DB_NAME=proposal_sow_builder")
        print("DB_USER=postgres")
        print("DB_PASSWORD=Password123")
        return False
    
    # Step 2: Test connection
    print("\n2. Testing database connection...")
    if not test_connection():
        print("\n💡 Make sure PostgreSQL is running and accessible")
        return False
    
    # Step 3: Run migrations
    print("\n3. Running database migrations...")
    if not run_migrations():
        return False
    
    # Step 4: Verify setup
    print("\n4. Verifying setup...")
    if not verify_setup():
        return False
    
    print("\n🎉 PostgreSQL setup completed successfully!")
    print("\n📝 Next steps:")
    print("1. Start your Flask backend: python app.py")
    print("2. Start your Flutter frontend: flutter run")
    print("3. Test the autosave functionality in the demo page")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
