#!/usr/bin/env python3
"""
Test Render PostgreSQL connection using connection string format
"""
import os
import sys
import psycopg2
from urllib.parse import urlparse, parse_qs

# Connection string from user
# Note: Using the exact string provided by user
CONNECTION_STRING = "postgresql://proposal_sow_builder_user:LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez@dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com/proposal_sow_builder"

print("=" * 70)
print("🔍 Testing Render PostgreSQL Connection (Connection String)")
print("=" * 70)

# Parse connection string
try:
    parsed = urlparse(CONNECTION_STRING)
    
    host = parsed.hostname
    port = parsed.port or 5432
    database = parsed.path.lstrip('/')
    user = parsed.username
    password = parsed.password
    
    print(f"\nHost: {host}")
    print(f"Port: {port}")
    print(f"Database: {database}")
    print(f"User: {user}")
    print(f"Password: {'*' * len(password) if password else 'NOT SET'}")
    
    # Parse query parameters if any
    query_params = parse_qs(parsed.query)
    sslmode = query_params.get('sslmode', ['require'])[0]
    
    print(f"\nAttempting connection with SSL mode: {sslmode}...")
    
    # Try connection WITHOUT SSL first
    print("\nMethod 1: Trying WITHOUT SSL (prefer)...")
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=user,
            password=password,
            sslmode='prefer',  # Try prefer first (will use SSL if available, but won't fail if not)
            connect_timeout=30
        )
        print("✅ Connection successful WITHOUT requiring SSL!")
        method = "no_ssl_prefer"
    except Exception as e1:
        print(f"❌ No SSL (prefer) failed: {e1}")
        
        # Try method 2: No SSL at all
        print("\nMethod 2: Trying with NO SSL (disable)...")
        try:
            conn = psycopg2.connect(
                host=host,
                port=port,
                database=database,
                user=user,
                password=password,
                sslmode='disable',  # Completely disable SSL
                connect_timeout=30
            )
            print("✅ Connection successful with SSL DISABLED!")
            method = "no_ssl_disable"
        except Exception as e2:
            print(f"❌ No SSL (disable) failed: {e2}")
            
            # Try method 3: With SSL require
            print("\nMethod 3: Trying WITH SSL (require)...")
            try:
                conn = psycopg2.connect(
                    host=host,
                    port=port,
                    database=database,
                    user=user,
                    password=password,
                    sslmode='require',
                    connect_timeout=30,
                    keepalives=1,
                    keepalives_idle=30,
                    keepalives_interval=10,
                    keepalives_count=5
                )
                print("✅ Connection successful WITH SSL!")
                method = "ssl_require"
            except Exception as e3:
                print(f"❌ SSL (require) failed: {e3}")
            print("\n" + "=" * 70)
            print("❌ Both connection methods failed!")
            print("=" * 70)
            print("\n💡 Most likely causes:")
            print("   1. Database is PAUSED (Render free tier)")
            print("      → Go to https://dashboard.render.com")
            print("      → Click on your PostgreSQL database")
            print("      → Wait 30-60 seconds for it to wake up")
            print("      → Then try again")
            print("\n   2. Password might be incorrect")
            print("      → Check the password in Render dashboard")
            print("      → Make sure there are no typos")
            print("\n   3. Network/firewall issue")
            print("      → Check your internet connection")
            print("      → Try from a different network")
            sys.exit(1)
    
    # If we got here, connection succeeded
    print(f"\n✅ Connection established using {method}!")
    
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
    print("✅ Connection test PASSED! Database is accessible.")
    print("=" * 70)
    print("\nYou can now run the migration:")
    print("   python migrate_postgres_to_postgres.py")
    
except Exception as e:
    print(f"\n❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

