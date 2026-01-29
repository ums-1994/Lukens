"""
Apply AI analytics SQL schema to the database using pg8000.
Reads `backend/.env` for DB connection info and `ai_analytics_schema.sql` for SQL.
Splits statements by semicolon and executes them sequentially.
"""
import os
import sys
from check_tables_pg import load_env

BASE = os.path.dirname(__file__)
ENV_PATH = os.path.join(BASE, '.env')
SQL_PATH = os.path.join(BASE, 'ai_analytics_schema.sql')

env = load_env(ENV_PATH)
HOST = env.get('DB_HOST')
PORT = int(env.get('DB_PORT', 5432))
DB = env.get('DB_NAME') or env.get('DATABASE')
USER = env.get('DB_USER')
PASSWORD = env.get('DB_PASSWORD')
SSL = env.get('DB_SSLMODE', '').lower() in ('require','verify-ca','verify-full')

if not all([HOST, DB, USER]):
    print('[ERROR] Missing DB connection info in .env')
    sys.exit(2)

try:
    import pg8000
except Exception as e:
    print('[ERROR] pg8000 not installed:', e)
    sys.exit(3)

if not os.path.exists(SQL_PATH):
    print('[ERROR] SQL file not found:', SQL_PATH)
    sys.exit(4)

with open(SQL_PATH, 'r', encoding='utf-8') as f:
    sql = f.read()

# Naive split by semicolon; keep statements non-empty
stmts = [s.strip() for s in sql.split(';') if s.strip()]

try:
    # Connect with ssl compatibility
    try:
        conn = pg8000.connect(host=HOST, port=PORT, database=DB, user=USER, password=PASSWORD, ssl=SSL)
    except TypeError:
        import ssl as _ssl
        ssl_ctx = None
        if SSL:
            ssl_ctx = _ssl.create_default_context()
        conn = pg8000.connect(host=HOST, port=PORT, database=DB, user=USER, password=PASSWORD, ssl_context=ssl_ctx)

    cur = conn.cursor()
    for i, stmt in enumerate(stmts, start=1):
        try:
            cur.execute(stmt)
            print(f"[OK] Executed statement {i}/{len(stmts)}")
        except Exception as e:
            print(f"[WARN] Statement {i} failed: {e}")
    conn.commit()
    cur.close()
    conn.close()
    print('[DONE] AI schema applied')
    sys.exit(0)
except Exception as e:
    print('[ERROR] Could not apply schema:', e)
    sys.exit(5)
