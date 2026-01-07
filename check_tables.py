import sqlite3

conn = sqlite3.connect('backend/proposals.db')
cursor = conn.cursor()

# List all tables
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = cursor.fetchall()
print('Tables in database:')
for table in tables:
    print(f'  - {table[0]}')

# Check if proposals table exists
if any('proposals' in t for t in tables):
    print('\nProposals table exists')
    cursor.execute('PRAGMA table_info(proposals)')
    columns = cursor.fetchall()
    print('Columns in proposals table:')
    for col in columns:
        print(f'  - {col[1]} ({col[2]})')
else:
    print('\nProposals table does not exist')

conn.close()
