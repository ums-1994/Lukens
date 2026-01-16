"""Script to fix user roles in database - allow admin, manager and finance_manager"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from api.utils.database import get_db_connection

def fix_user_roles():
    """Update all user roles to be either 'admin' or 'manager'"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        try:
            # First, show current roles
            print("📊 Current roles in database:")
            cursor.execute('SELECT DISTINCT role, COUNT(*) FROM users GROUP BY role ORDER BY role')
            roles = cursor.fetchall()
            for role, count in roles:
                print(f"  - {role}: {count} users")
            
            # Show specific user
            print("\n🔍 Checking user: sheziluthando513@gmail.com")
            cursor.execute("SELECT email, role FROM users WHERE email = %s", ('sheziluthando513@gmail.com',))
            user = cursor.fetchone()
            if user:
                print(f"  Current role: {user[1]}")
            else:
                print("  User not found!")
                return
            
            # Update all roles to standardize them
            print("\n🔄 Updating roles...")
            
            # Map common variations to 'manager', but preserve/standardize Financial Manager to 'finance_manager'
            cursor.execute("""
                UPDATE users
                SET role = 'finance_manager'
                WHERE LOWER(role) IN ('financial manager', 'finance manager', 'finance_manager', 'financial_manager')
            """)
            fm_count = cursor.rowcount
            print(f"  Updated {fm_count} users to 'finance_manager'")

            cursor.execute("""
                UPDATE users
                SET role = 'manager'
                WHERE LOWER(role) IN ('manager', 'creator', 'user', 'business developer')
            """)
            manager_count = cursor.rowcount
            print(f"  Updated {manager_count} users to 'manager'")
            
            # Map CEO to admin
            cursor.execute("""
                UPDATE users 
                SET role = 'admin' 
                WHERE LOWER(role) = 'ceo'
            """)
            ceo_count = cursor.rowcount
            print(f"  Updated {ceo_count} users to 'admin' (from CEO)")
            
            # Update the specific user to admin if they registered as admin
            print("\n🔧 Updating sheziluthando513@gmail.com to 'admin'...")
            cursor.execute("""
                UPDATE users 
                SET role = 'admin' 
                WHERE email = %s
            """, ('sheziluthando513@gmail.com',))
            conn.commit()
            print("  ✅ Updated to admin")
            
            # Show final roles
            print("\n📊 Final roles in database:")
            cursor.execute('SELECT DISTINCT role, COUNT(*) FROM users GROUP BY role ORDER BY role')
            roles = cursor.fetchall()
            for role, count in roles:
                print(f"  - {role}: {count} users")
            
            # Verify the specific user
            print("\n✅ Verification:")
            cursor.execute("SELECT email, role FROM users WHERE email = %s", ('sheziluthando513@gmail.com',))
            user = cursor.fetchone()
            if user:
                print(f"  {user[0]}: {user[1]}")
            
        except Exception as e:
            print(f"❌ Error: {e}")
            conn.rollback()
            raise

if __name__ == '__main__':
    fix_user_roles()

