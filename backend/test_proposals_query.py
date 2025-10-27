import psycopg2
from dotenv import load_dotenv
import os

load_dotenv()

# Connect to database
conn = psycopg2.connect(
    host=os.getenv('DB_HOST', 'localhost'),
    port=os.getenv('DB_PORT', '5432'),
    database=os.getenv('DB_NAME', 'proposal_sow_builder'),
    user=os.getenv('DB_USER', 'postgres'),
    password=os.getenv('DB_PASSWORD', '')
)

cursor = conn.cursor()

print("=" * 80)
print("CHECKING PROPOSALS TABLE")
print("=" * 80)

# Check table structure
cursor.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name='proposals' 
    ORDER BY ordinal_position
""")
columns = cursor.fetchall()
print("\n📋 Table columns:")
for col in columns:
    print(f"  - {col[0]}: {col[1]}")

# Check all proposals
cursor.execute("SELECT id, title, user_id, status, created_at FROM proposals ORDER BY created_at DESC")
proposals = cursor.fetchall()
print(f"\n📊 Total proposals in database: {len(proposals)}")
if proposals:
    print("\nProposals:")
    for p in proposals:
        print(f"  ID: {p[0]}, Title: {p[1]}, User: {p[2]}, Status: {p[3]}, Created: {p[4]}")
else:
    print("  No proposals found!")

# Check users
cursor.execute("SELECT id, username, email FROM users ORDER BY id")
users = cursor.fetchall()
print(f"\n👥 Users in database: {len(users)}")
for u in users:
    print(f"  ID: {u[0]}, Username: {u[1]}, Email: {u[2]}")

cursor.close()
conn.close()

print("\n" + "=" * 80)

