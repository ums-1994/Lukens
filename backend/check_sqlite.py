import sqlite3
import os

# Connect to the SQLite database
db_path = "khonopro_client.db"
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check all users
    print("=== ALL USERS ===")
    cursor.execute("SELECT id, username, email, firebase_uid FROM users ORDER BY id DESC")
    users = cursor.fetchall()
    for user in users:
        print(f"ID: {user[0]}, Username: {user[1]}, Email: {user[2]}, Firebase UID: {user[3]}")
    
    # Check proposals table schema
    print("\n=== PROPOSALS TABLE SCHEMA ===")
    cursor.execute("PRAGMA table_info(proposals)")
    columns = cursor.fetchall()
    for col in columns:
        print(f"Column: {col[1]}, Type: {col[2]}, NotNull: {col[3]}, Default: {col[4]}, PK: {col[5]}")
    
    # Check proposals
    print("\n=== ALL PROPOSALS ===")
    cursor.execute("SELECT id, title, created_by FROM proposals ORDER BY id DESC")
    proposals = cursor.fetchall()
    for proposal in proposals:
        print(f"Proposal ID: {proposal[0]}, Title: {proposal[1]}, Created By: {proposal[2]}")
    
    conn.close()
else:
    print(f"Database file not found: {db_path}")
