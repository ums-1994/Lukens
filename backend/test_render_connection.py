#!/usr/bin/env python3
"""
Quick test script to check Render PostgreSQL connection
"""
import os
import sys
import psycopg2
from dotenv import load_dotenv

load_dotenv()

# Get Render database credentials
host = os.getenv('DEST_DB_HOST', os.getenv('RENDER_DB_HOST', ''))
database = os.getenv('DEST_DB_NAME', os.getenv('RENDER_DB_NAME', ''))
user = os.getenv('DEST_DB_USER', os.getenv('RENDER_DB_USER', ''))
password = os.getenv('DEST_DB_PASSWORD', os.getenv('RENDER_DB_PASSWORD', ''))
port = int(os.getenv('DEST_DB_PORT', os.getenv('RENDER_DB_PORT', '5432')))

if not host or not database:
    print("❌ Render database credentials not set!")
    print("\nSet these environment variables:")
    print("  DEST_DB_HOST=your-render-host.render.com")
    print("  DEST_DB_NAME=your_database_name")
    print("  DEST_DB_USER=your_database_user")
    print("  DEST_DB_PASSWORD=your_database_password")
    sys.exit(1)

print("=" * 70)
print("🔍 Testing Render PostgreSQL Connection")
print("=" * 70)
print(f"\nHost: {host}")
print(f"Database: {database}")
print(f"User: {user}")
print(f"Port: {port}")
print("\nAttempting connection...")

try:
    # Try connection with SSL
    conn = psycopg2.connect(
        host=host,
        database=database,
        user=user,
        password=password,
        port=port,
        sslmode='require',
        connect_timeout=30,
        keepalives=1,
        keepalives_idle=30,
        keepalives_interval=10,
        keepalives_count=5
    )
    
    print("✅ Connection successful!")
    
    # Test a simple query
    cursor = conn.cursor()
    cursor.execute("SELECT version();")
    version = cursor.fetchone()[0]
    print(f"\n📊 PostgreSQL Version: {version.split(',')[0]}")
    
    # Check database size
    cursor.execute("""
        SELECT pg_size_pretty(pg_database_size(current_database())) as size;
    """)
    size = cursor.fetchone()[0]
    print(f"💾 Database Size: {size}")
    
    # List tables
    cursor.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    """)
    tables = cursor.fetchall()
    print(f"\n📋 Tables in database: {len(tables)}")
    if tables:
        print("   First 10 tables:")
        for table in tables[:10]:
            print(f"   - {table[0]}")
        if len(tables) > 10:
            print(f"   ... and {len(tables) - 10} more")
    
    cursor.close()
    conn.close()
    
    print("\n" + "=" * 70)
    print("✅ Connection test passed! Database is accessible.")
    print("=" * 70)
    print("\nYou can now run the migration:")
    print("   python migrate_postgres_to_postgres.py")
    
except psycopg2.OperationalError as e:
    print(f"\n❌ Connection failed: {e}")
    print("\n💡 Possible issues:")
    print("   1. Database is paused (Render free tier)")
    print("      → Go to https://dashboard.render.com and wake it up")
    print("   2. Network/firewall blocking connection")
    print("      → Check your internet connection")
    print("   3. Credentials are incorrect")
    print("      → Verify credentials in Render dashboard")
    print("   4. Database doesn't exist")
    print("      → Check database name in Render dashboard")
    sys.exit(1)
    
except Exception as e:
    print(f"\n❌ Unexpected error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

