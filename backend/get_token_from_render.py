"""
Script to help retrieve JWT token from Render server
Since tokens are stored on Render, this provides instructions and checks
"""
import os
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
import json

load_dotenv()

def check_render_connection():
    """Check if we can connect to Render database"""
    print("=" * 80)
    print("CHECKING RENDER DATABASE CONNECTION")
    print("=" * 80)
    
    try:
        database_url = os.getenv('DATABASE_URL')
        if database_url:
            print(f"\n[SUCCESS] DATABASE_URL found")
            print(f"  Connection string: {database_url[:50]}...")
            
            conn = psycopg2.connect(database_url)
            cursor = conn.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()
            print(f"\n[SUCCESS] Connected to database!")
            print(f"  Database version: {version[0][:50]}...")
            cursor.close()
            conn.close()
            return True
        else:
            print("\n[WARNING] DATABASE_URL not found in environment")
            print("  Make sure you're running this with Render environment variables")
            return False
    except Exception as e:
        print(f"\n[ERROR] Could not connect to database: {e}")
        return False

def get_user_info(username):
    """Get user information from database"""
    print("\n" + "=" * 80)
    print(f"USER INFORMATION FOR: {username}")
    print("=" * 80)
    
    try:
        database_url = os.getenv('DATABASE_URL')
        if not database_url:
            print("\n[ERROR] DATABASE_URL not found")
            return None
        
        conn = psycopg2.connect(database_url)
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        cursor.execute("""
            SELECT id, username, email, full_name, role, is_active, created_at
            FROM users
            WHERE LOWER(username) = LOWER(%s)
               OR LOWER(email) = LOWER(%s)
        """, (username, username))
        
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if user:
            print(f"\n[SUCCESS] User found:")
            print(f"  ID: {user['id']}")
            print(f"  Username: {user['username']}")
            print(f"  Email: {user['email']}")
            print(f"  Full Name: {user['full_name']}")
            print(f"  Role: {user['role']}")
            print(f"  Active: {user['is_active']}")
            print(f"  Created: {user['created_at']}")
            return user
        else:
            print(f"\n[WARNING] User '{username}' not found in database")
            return None
            
    except Exception as e:
        print(f"\n[ERROR] Error querying database: {e}")
        return None

def show_token_instructions(username, user_info):
    """Show instructions on how to get the token"""
    print("\n" + "=" * 80)
    print("HOW TO GET JWT TOKEN FOR THIS USER")
    print("=" * 80)
    
    print("\nMethod 1: Check Render Logs")
    print("-" * 80)
    print("1. Go to your Render dashboard: https://dashboard.render.com")
    print("2. Navigate to your backend service")
    print("3. Click on 'Logs' tab")
    print("4. Search for: 'Generated new token for user'")
    print(f"5. Look for logs containing: '{user_info['username'] if user_info else username}'")
    print("\n   The log will show:")
    print("   [TOKEN] Generated new token for user 'username': abc123...xyz789")
    
    print("\nMethod 2: Access Render Shell (if available)")
    print("-" * 80)
    print("1. Go to Render dashboard -> Your backend service")
    print("2. Click 'Shell' tab (if available)")
    print("3. Run: cat backend/auth_tokens.json")
    print("4. Or: cat auth_tokens.json")
    print("5. Find the token for username: " + (user_info['username'] if user_info else username))
    
    print("\nMethod 3: Check Browser (for Firebase tokens)")
    print("-" * 80)
    print("1. Have the user log in to the application")
    print("2. Open browser DevTools (F12)")
    print("3. Go to Application -> Local Storage")
    print("4. Look for keys containing 'token' or 'auth'")
    print("5. Firebase ID tokens are stored there (these are session tokens)")
    
    print("\nMethod 4: Generate New Token")
    print("-" * 80)
    print("If you need a token for testing:")
    print("1. Have the user log in through the application")
    print("2. A new token will be generated and logged")
    print("3. Check Render logs immediately after login")
    
    print("\n" + "=" * 80)
    print("TOKEN FILE LOCATION ON RENDER SERVER")
    print("=" * 80)
    print("\nThe token file is located at:")
    print("  backend/auth_tokens.json")
    print("\nOr at the root:")
    print("  auth_tokens.json")
    print("\nThe file contains JSON like:")
    print("""
{
  "token_abc123...": {
    "username": "nkosinathikhono",
    "created_at": "2025-01-19T10:00:00",
    "expires_at": "2025-01-26T10:00:00"
  }
}
""")

if __name__ == '__main__':
    import sys
    
    username = sys.argv[1] if len(sys.argv) > 1 else "nkosinathikhono"
    
    print("\n" + "=" * 80)
    print(f"FINDING JWT TOKEN FOR USER: {username}")
    print("=" * 80)
    
    # Check connection
    can_connect = check_render_connection()
    
    # Get user info
    user_info = None
    if can_connect:
        user_info = get_user_info(username)
    else:
        print("\n[INFO] Cannot query database, but showing instructions anyway...")
    
    # Show instructions
    show_token_instructions(username, user_info)
    
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    if user_info:
        print(f"\nUser '{username}' exists in database.")
        print("To get their token, check Render logs or access the server file system.")
    else:
        print(f"\nCould not verify user '{username}' in database.")
        print("Make sure you have DATABASE_URL set to connect to Render database.")
    
    print("\nNote: JWT tokens are stored server-side, not in the database.")
    print("      They are in auth_tokens.json file on the Render server.")
