import sys
import traceback

try:
    import psycopg2
except ImportError:
    print('psycopg2 not installed')
    sys.exit(2)

if len(sys.argv) < 3:
    print('Usage: run_migration_remote.py <connection_string> <sql_file_path>')
    sys.exit(2)

conn_str = sys.argv[1]
sql_path = sys.argv[2]

try:
    with open(sql_path, 'r', encoding='utf-8') as f:
        sql_text = f.read()
except Exception as e:
    print(f'Failed to read SQL file: {e}')
    sys.exit(1)

try:
    # connect (psycopg2 accepts libpq connection string)
    print(f'Attempting to connect using: {conn_str}')
    conn = psycopg2.connect(conn_str, connect_timeout=10)
    conn.autocommit = True
    cur = conn.cursor()
    print('Connected. Executing SQL...')
    cur.execute(sql_text)
    print('SQL executed successfully.')
    cur.close()
    conn.close()
    sys.exit(0)
except Exception as e:
    print('Exception while running migration:')
    traceback.print_exc()
    sys.exit(1)
