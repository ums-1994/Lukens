#!/usr/bin/env python3
"""
Simple PostgreSQL Database Manager
Use this instead of psql to manage your database
"""

import psycopg2
from dotenv import load_dotenv
import os

def connect_to_db():
    """Connect to database"""
    load_dotenv()
    try:
        conn = psycopg2.connect(os.getenv('DATABASE_URL'))
        print(f"🔗 Connecting to: {os.getenv('DATABASE_URL').split('@')[1]}")
        return conn
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return None

def show_tables():
    """Show all tables in the database"""
    conn = connect_to_db()
    if not conn:
        return
    
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)
        tables = cursor.fetchall()
        print("\n📋 Tables in lukens_db:")
        for table in tables:
            print(f"  - {table[0]}")
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"❌ Error: {e}")

def show_users():
    """Show all users in the database"""
    conn = connect_to_db()
    if not conn:
        return
    
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id, username, email, role, is_active FROM users ORDER BY id")
        users = cursor.fetchall()
        print("\n👥 Users in database:")
        print("ID | Username | Email | Role | Active")
        print("-" * 50)
        for user in users:
            print(f"{user[0]} | {user[1]} | {user[2]} | {user[3]} | {user[4]}")
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"❌ Error: {e}")

def run_query(query):
    """Run a custom SQL query"""
    conn = connect_to_db()
    if not conn:
        return
    
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        
        if query.strip().upper().startswith('SELECT'):
            results = cursor.fetchall()
            print(f"\n📊 Query Results ({len(results)} rows):")
            for row in results:
                print(row)
        else:
            conn.commit()
            print(f"✅ Query executed successfully")
        
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"❌ Error: {e}")

def main():
    """Main menu"""
    while True:
        print("\n" + "="*50)
        print("🗄️  PostgreSQL Database Manager")
        print("="*50)
        print("1. Show all tables")
        print("2. Show all users")
        print("3. Run custom SQL query")
        print("4. Test database connection")
        print("5. Exit")
        
        choice = input("\nSelect option (1-5): ").strip()
        
        if choice == '1':
            show_tables()
        elif choice == '2':
            show_users()
        elif choice == '3':
            query = input("Enter SQL query: ").strip()
            if query:
                run_query(query)
        elif choice == '4':
            conn = connect_to_db()
            if conn:
                print("✅ Database connection successful!")
                conn.close()
            else:
                print("❌ Database connection failed!")
        elif choice == '5':
            print("👋 Goodbye!")
            break
        else:
            print("❌ Invalid option!")

if __name__ == "__main__":
    main()
