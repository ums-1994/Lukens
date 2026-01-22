"""
Script to check Render database for user roles and token information
Run this to inspect the database state
"""
import os
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
import json

load_dotenv()

def get_db_connection():
    """Get database connection from environment variables"""
    # Try DATABASE_URL first (Render format)
    database_url = os.getenv('DATABASE_URL')
    
    if database_url:
        # Parse DATABASE_URL if it's in Render format
        # Format: postgresql://user:password@host:port/dbname
        return psycopg2.connect(database_url)
    else:
        # Fallback to individual environment variables
        return psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=int(os.getenv('DB_PORT', '5432')),
            dbname=os.getenv('DB_NAME', 'proposal_sow_builder'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', os.getenv('DB_PASS', 'Password123')),
        )

def check_user_roles():
    """Check all users and their roles"""
    print("=" * 80)
    print("CHECKING USER ROLES IN DATABASE")
    print("=" * 80)
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    try:
        # Get all users with their roles
        cursor.execute("""
            SELECT id, username, email, full_name, role, is_active, created_at
            FROM users
            ORDER BY created_at DESC
        """)
        users = cursor.fetchall()
        
        print(f"\nTotal users: {len(users)}\n")
        
        # Group by role
        role_counts = {}
        for user in users:
            role = user['role'] or 'NULL'
            role_counts[role] = role_counts.get(role, 0) + 1
        
        print("Role distribution:")
        for role, count in sorted(role_counts.items()):
            print(f"  {role}: {count} user(s)")
        
        print("\n" + "-" * 80)
        print("All users:")
        print("-" * 80)
        
        for user in users:
            role = user['role'] or 'NULL'
            status = "✓ Active" if user['is_active'] else "✗ Inactive"
            print(f"\nID: {user['id']}")
            print(f"  Username: {user['username']}")
            print(f"  Email: {user['email']}")
            print(f"  Full Name: {user['full_name']}")
            print(f"  Role: {role} {'⚠️' if role not in ['admin', 'manager', 'finance_manager'] else ''}")
            print(f"  Status: {status}")
            print(f"  Created: {user['created_at']}")
        
        # Check specifically for finance_manager role variations
        print("\n" + "=" * 80)
        print("CHECKING FINANCE MANAGER ROLES")
        print("=" * 80)
        
        cursor.execute("""
            SELECT id, username, email, full_name, role
            FROM users
            WHERE LOWER(role) LIKE '%finance%' OR LOWER(role) LIKE '%financial%'
            ORDER BY role, email
        """)
        finance_users = cursor.fetchall()
        
        if finance_users:
            print(f"\nFound {len(finance_users)} user(s) with finance-related roles:\n")
            for user in finance_users:
                print(f"  Email: {user['email']}")
                print(f"  Role: '{user['role']}'")
                print(f"  Username: {user['username']}")
                print()
        else:
            print("\n⚠️ No users found with finance-related roles!")
        
        # Check for users that should be finance_manager but aren't
        print("\n" + "=" * 80)
        print("USERS WITH NON-STANDARD ROLES")
        print("=" * 80)
        
        cursor.execute("""
            SELECT id, username, email, full_name, role
            FROM users
            WHERE role NOT IN ('admin', 'manager', 'finance_manager')
               OR role IS NULL
            ORDER BY role, email
        """)
        non_standard = cursor.fetchall()
        
        if non_standard:
            print(f"\nFound {len(non_standard)} user(s) with non-standard roles:\n")
            for user in non_standard:
                role = user['role'] or 'NULL'
                print(f"  Email: {user['email']}")
                print(f"  Role: '{role}'")
                print(f"  Username: {user['username']}")
                print()
        else:
            print("\n✓ All users have standard roles (admin, manager, finance_manager)")
        
    finally:
        cursor.close()
        conn.close()

def check_tokens_file():
    """Check the tokens file location"""
    print("\n" + "=" * 80)
    print("JWT TOKEN STORAGE")
    print("=" * 80)
    
    token_file = os.path.join(os.path.dirname(__file__), 'auth_tokens.json')
    
    print(f"\nToken file location: {token_file}")
    print(f"File exists: {os.path.exists(token_file)}")
    
    if os.path.exists(token_file):
        try:
            with open(token_file, 'r', encoding='utf-8') as f:
                tokens = json.load(f)
            
            print(f"\nTotal tokens in file: {len(tokens)}")
            
            if tokens:
                print("\nActive tokens:")
                for token, token_data in list(tokens.items())[:10]:  # Show first 10
                    username = token_data.get('username', 'Unknown')
                    created = token_data.get('created_at', 'Unknown')
                    expires = token_data.get('expires_at', 'Unknown')
                    print(f"\n  Token: {token[:20]}...{token[-10:]}")
                    print(f"    Username: {username}")
                    print(f"    Created: {created}")
                    print(f"    Expires: {expires}")
                
                if len(tokens) > 10:
                    print(f"\n  ... and {len(tokens) - 10} more tokens")
        except Exception as e:
            print(f"\n⚠️ Error reading token file: {e}")
    else:
        print("\n⚠️ Token file not found. Tokens may be stored in memory only.")
        print("Note: Tokens are stored in a file (auth_tokens.json), not in the database.")

def check_client_tokens():
    """Check client dashboard tokens in database"""
    print("\n" + "=" * 80)
    print("CLIENT DASHBOARD TOKENS (in database)")
    print("=" * 80)
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    try:
        # Check if table exists
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'client_dashboard_tokens'
            )
        """)
        table_exists = cursor.fetchone()[0]
        
        if table_exists:
            cursor.execute("""
                SELECT id, token, client_id, proposal_id, expires_at, used_at, created_at
                FROM client_dashboard_tokens
                ORDER BY created_at DESC
                LIMIT 20
            """)
            tokens = cursor.fetchall()
            
            print(f"\nTotal client dashboard tokens: {len(tokens)}")
            
            if tokens:
                print("\nRecent tokens:")
                for token in tokens:
                    print(f"\n  Token ID: {token['id']}")
                    print(f"    Token: {token['token'][:30]}...")
                    print(f"    Client ID: {token['client_id']}")
                    print(f"    Proposal ID: {token['proposal_id']}")
                    print(f"    Expires: {token['expires_at']}")
                    print(f"    Used: {'Yes' if token['used_at'] else 'No'}")
                    print(f"    Created: {token['created_at']}")
            else:
                print("\nNo client dashboard tokens found.")
        else:
            print("\n⚠️ client_dashboard_tokens table does not exist.")
    except Exception as e:
        print(f"\n⚠️ Error checking client tokens: {e}")
    finally:
        cursor.close()
        conn.close()

if __name__ == '__main__':
    try:
        check_user_roles()
        check_tokens_file()
        check_client_tokens()
        
        print("\n" + "=" * 80)
        print("SUMMARY")
        print("=" * 80)
        print("\n✓ Database check complete!")
        print("\nNote: JWT tokens for user authentication are stored in auth_tokens.json file,")
        print("      not in the database. The database only stores client dashboard tokens.")
        
    except psycopg2.OperationalError as e:
        print(f"\n❌ Database connection error: {e}")
        print("\nMake sure you have:")
        print("  1. DATABASE_URL environment variable set (for Render)")
        print("  OR")
        print("  2. DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD set")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
