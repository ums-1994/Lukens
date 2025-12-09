#!/usr/bin/env python3
"""
Very simple connection test - minimal code to isolate the issue
"""
import psycopg2
import sys

print("=" * 70)
print("🔍 Simple Connection Test")
print("=" * 70)

# Try with the EXACT connection string from user
CONNECTION_STRING = "postgresql://proposal_sow_builder_user:LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez@dpg-d4iq5fa4d50c73d9m3n0-a/proposal_sow_builder"

# Parse connection string
from urllib.parse import urlparse
parsed = urlparse(CONNECTION_STRING)

host = parsed.hostname  # This will be "dpg-d4iq5fa4d50c73d9m3n0-a" (no domain!)
port = parsed.port or 5432
database = parsed.path.lstrip('/')
user = parsed.username
password = parsed.password

print(f"\nUsing EXACT connection string from Render:")
print(f"  {CONNECTION_STRING}")
print(f"\nParsed details:")
print(f"  Host: {host}")
print(f"  Port: {port}")
print(f"  Database: {database}")
print(f"  User: {user}")
print(f"  Password length: {len(password)} characters")
print(f"\n⚠️  Note: Host is '{host}' (no .oregon-postgres.render.com)")
print(f"   This might need the full domain. Testing both...")

# Try with connection string first
print("\n" + "=" * 70)
print("Method 1: Using connection string directly")
print("=" * 70)
try:
    conn = psycopg2.connect(CONNECTION_STRING + "?sslmode=require", connect_timeout=10)
    print("✅ SUCCESS with connection string!")
    cursor = conn.cursor()
    cursor.execute("SELECT version();")
    version = cursor.fetchone()[0]
    print(f"📊 PostgreSQL: {version.split(',')[0]}")
    cursor.close()
    conn.close()
    print("\n✅ CONNECTION SUCCESSFUL!")
    sys.exit(0)
except Exception as e:
    print(f"❌ Connection string failed: {str(e)[:150]}")

# Try with parsed host (short version)
print("\n" + "=" * 70)
print("Method 2: Using parsed host (short)")
print("=" * 70)

methods = [
    ("No SSL", {'sslmode': 'disable'}),
    ("Prefer SSL", {'sslmode': 'prefer'}),
    ("Require SSL", {'sslmode': 'require'}),
    ("Allow SSL", {'sslmode': 'allow'}),
]

for method_name, ssl_config in methods:
    print(f"\n--- Trying: {method_name} ---")
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=user,
            password=password,
            connect_timeout=10,
            **ssl_config
        )
        print(f"✅ SUCCESS with {method_name}!")
        
        # Test query
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()[0]
        print(f"📊 PostgreSQL: {version.split(',')[0]}")
        
        cursor.close()
        conn.close()
        
        print("\n" + "=" * 70)
        print("✅ CONNECTION SUCCESSFUL!")
        print("=" * 70)
        sys.exit(0)
        
    except psycopg2.OperationalError as e:
        error_msg = str(e)
        if "server closed the connection" in error_msg:
            print(f"❌ Server closed connection (database might need more time to wake up)")
        elif "timeout" in error_msg.lower():
            print(f"❌ Connection timeout")
        elif "authentication" in error_msg.lower() or "password" in error_msg.lower():
            print(f"❌ Authentication failed (wrong password?)")
        else:
            print(f"❌ {error_msg[:100]}")
    except Exception as e:
        print(f"❌ Error: {type(e).__name__}: {str(e)[:100]}")

# Try with full domain host
print("\n" + "=" * 70)
print("Method 3: Using full domain host")
print("=" * 70)
full_host = f"{host}.oregon-postgres.render.com"
print(f"Trying with full host: {full_host}")

for method_name, ssl_config in methods:
    print(f"\n--- Trying: {method_name} (full domain) ---")
    try:
        conn = psycopg2.connect(
            host=full_host,
            port=port,
            database=database,
            user=user,
            password=password,
            connect_timeout=10,
            **ssl_config
        )
        print(f"✅ SUCCESS with {method_name} (full domain)!")
        
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()[0]
        print(f"📊 PostgreSQL: {version.split(',')[0]}")
        
        cursor.close()
        conn.close()
        
        print("\n" + "=" * 70)
        print("✅ CONNECTION SUCCESSFUL!")
        print("=" * 70)
        sys.exit(0)
        
    except psycopg2.OperationalError as e:
        error_msg = str(e)
        if "server closed the connection" in error_msg:
            print(f"❌ Server closed connection")
        elif "timeout" in error_msg.lower():
            print(f"❌ Connection timeout")
        elif "authentication" in error_msg.lower() or "password" in error_msg.lower():
            print(f"❌ Authentication failed (wrong password?)")
        else:
            print(f"❌ {error_msg[:100]}")
    except Exception as e:
        print(f"❌ Error: {type(e).__name__}: {str(e)[:100]}")

print("\n" + "=" * 70)
print("❌ All connection methods failed")
print("=" * 70)
print("\n💡 Next steps:")
print("   1. Verify password in Render dashboard (Environment tab)")
print("   2. Get the EXACT connection string from Render (Info tab)")
print("   3. Make sure database has been awake for at least 60 seconds")
print("   4. Check if there's a firewall blocking port 5432")
print("   5. Try the connection string from Render's 'Info' tab directly")

