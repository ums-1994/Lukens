"""
Script to find user information including tokens from Render database
"""
import os
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv()

def get_db_connection():
    """Get database connection from environment variables"""
    database_url = os.getenv('DATABASE_URL')
    
    if database_url:
        return psycopg2.connect(database_url)
    else:
        return psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=int(os.getenv('DB_PORT', '5432')),
            dbname=os.getenv('DB_NAME', 'proposal_sow_builder'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', os.getenv('DB_PASS', 'Password123')),
        )

def find_user_info(username):
    """Find user information from database"""
    print("=" * 80)
    print(f"SEARCHING FOR USER: {username}")
    print("=" * 80)
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    try:
        # Search by username (case-insensitive) - use basic columns that should exist
        cursor.execute("""
            SELECT id, username, email, full_name, role, department, 
                   is_active, is_email_verified, created_at, updated_at
            FROM users
            WHERE LOWER(username) LIKE LOWER(%s)
               OR LOWER(email) LIKE LOWER(%s)
               OR LOWER(full_name) LIKE LOWER(%s)
            ORDER BY created_at DESC
        """, (f'%{username}%', f'%{username}%', f'%{username}%'))
        
        users = cursor.fetchall()
        
        if users:
            print(f"\n[SUCCESS] Found {len(users)} user(s) matching '{username}':\n")
            
            for i, user in enumerate(users, 1):
                print("-" * 80)
                print(f"USER #{i}")
                print("-" * 80)
                print(f"\nID: {user['id']}")
                print(f"Username: {user['username']}")
                print(f"Email: {user['email']}")
                print(f"Full Name: {user['full_name']}")
                print(f"Role: {user['role']}")
                print(f"Department: {user.get('department') or 'N/A'}")
                print(f"Active: {user['is_active']}")
                print(f"Email Verified: {user.get('is_email_verified', 'N/A')}")
                print(f"Created: {user['created_at']}")
                print(f"Updated: {user['updated_at']}")
                print()
        else:
            print(f"\n[WARNING] No users found matching '{username}'")
            print("\nSearching for similar usernames...")
            
            cursor.execute("""
                SELECT username, email, full_name
                FROM users
                ORDER BY username
                LIMIT 20
            """)
            all_users = cursor.fetchall()
            
            if all_users:
                print("\nAvailable users:")
                for u in all_users:
                    print(f"  - {u['username']} ({u['email']})")
        
        # Note about tokens
        print("\n" + "=" * 80)
        print("ABOUT TOKENS")
        print("=" * 80)
        print("\nNote: JWT tokens are stored in auth_tokens.json file on the Render server,")
        print("      not in the database. To see tokens:")
        print("      1. Check Render logs for token generation")
        print("      2. SSH into Render server and check auth_tokens.json file")
        print("      3. Or check browser localStorage for Firebase ID tokens")
        print("\nFirebase ID tokens are generated per-session and stored in the browser.")
        print("Backend JWT tokens are stored in: backend/auth_tokens.json on the server.")
        
    except Exception as e:
        print(f"\n[ERROR] Error querying database: {e}")
        import traceback
        traceback.print_exc()
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) > 1:
        username = sys.argv[1]
        find_user_info(username)
    else:
        find_user_info("Kgothatso")
        print("\n" + "=" * 80)
        print("TIP: To search for a different user, run:")
        print("  python find_user_info.py <username>")
        print("=" * 80)
