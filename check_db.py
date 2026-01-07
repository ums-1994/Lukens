import sqlite3

conn = sqlite3.connect('backend/proposals.db')
cursor = conn.cursor()

# Check total proposals
cursor.execute('SELECT COUNT(*) FROM proposals')
total = cursor.fetchone()
print(f'Total proposals: {total[0] if total else 0}')

# Check active proposals (not draft)
cursor.execute('SELECT COUNT(*) FROM proposals WHERE status IS NOT NULL AND status != "Draft"')
active = cursor.fetchone()
print(f'Active proposals: {active[0] if active else 0}')

# Show sample proposals
cursor.execute('SELECT id, title, status, client FROM proposals WHERE status IS NOT NULL AND status != "Draft" LIMIT 5')
rows = cursor.fetchall()
for row in rows:
    print(f'ID: {row[0]}, Title: {row[1]}, Status: {row[2]}, Client: {row[3]}')

conn.close()
