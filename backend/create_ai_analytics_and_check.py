"""
Create `ai_analytics` table (if missing) and check presence of all tables/views
mentioned in `database_schema.sql` and `ai_analytics_schema.sql`.
"""
import os
import re
import sys
from check_tables_pg import load_env

BASE = os.path.dirname(__file__)
ENV_PATH = os.path.join(BASE, '.env')
DB_SCHEMA = os.path.join(BASE, 'database_schema.sql')
AI_SCHEMA = os.path.join(BASE, 'ai_analytics_schema.sql')

env = load_env(ENV_PATH)
HOST = env.get('DB_HOST')
PORT = int(env.get('DB_PORT', 5432))
DB = env.get('DB_NAME') or env.get('DATABASE')
USER = env.get('DB_USER')
PASSWORD = env.get('DB_PASSWORD')
SSLFLAG = env.get('DB_SSLMODE', '').lower() in ('require','verify-ca','verify-full')

if not all([HOST, DB, USER]):
    print('[ERROR] Missing DB connection info in .env')
    sys.exit(2)

try:
    import pg8000
except Exception as e:
    print('[ERROR] pg8000 not installed:', e)
    sys.exit(3)

# SQL to create ai_analytics table
CREATE_AI_ANALYTICS = '''
CREATE TABLE IF NOT EXISTS ai_analytics (
    id SERIAL PRIMARY KEY,
    usage_date DATE NOT NULL,
    endpoint VARCHAR(100),
    total_requests INTEGER DEFAULT 0,
    accepted_count INTEGER DEFAULT 0,
    rejected_count INTEGER DEFAULT 0,
    avg_response_time NUMERIC,
    avg_tokens NUMERIC,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
'''


def parse_expected(sql_path):
    text = ''
    if not os.path.exists(sql_path):
        return []
    with open(sql_path, 'r', encoding='utf-8') as f:
        text = f.read()
    # Find CREATE TABLE IF NOT EXISTS <name> and CREATE TABLE <name>
    tables = re.findall(r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_\\.\"]+)", text, flags=re.IGNORECASE)
    # Clean table names
    clean = [t.replace('public.','').replace('"','') for t in tables]
    # Also find CREATE OR REPLACE VIEW names
    views = re.findall(r"CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+([a-zA-Z0-9_\\.\"]+)", text, flags=re.IGNORECASE)
    clean_views = [v.replace('public.','').replace('"','') for v in views]
    return clean + clean_views


def connect():
    try:
        try:
            conn = pg8000.connect(host=HOST, port=PORT, database=DB, user=USER, password=PASSWORD, ssl=SSLFLAG)
        except TypeError:
            import ssl as _ssl
            ssl_ctx = None
            if SSLFLAG:
                ssl_ctx = _ssl.create_default_context()
            conn = pg8000.connect(host=HOST, port=PORT, database=DB, user=USER, password=PASSWORD, ssl_context=ssl_ctx)
        return conn
    except Exception as e:
        print('[ERROR] Connection failed:', e)
        raise


def ensure_ai_table(conn):
    cur = conn.cursor()
    try:
        cur.execute(CREATE_AI_ANALYTICS)
        conn.commit()
        print('[OK] Ensured ai_analytics table exists')
    except Exception as e:
        print('[WARN] Could not create ai_analytics:', e)
        conn.rollback()
    finally:
        cur.close()


def check_expected(conn, expected):
    cur = conn.cursor()
    missing = []
    present = []
    for name in sorted(set(expected)):
        try:
            # check tables/views via to_regclass
            cur.execute("SELECT to_regclass('public.' || %s)", (name,))
            found = cur.fetchone()[0]
            if not found:
                missing.append(name)
            else:
                # get row count if it's a table
                try:
                    cur.execute(f"SELECT count(*) FROM {name}")
                    cnt = cur.fetchone()[0]
                    present.append((name, cnt))
                except Exception:
                    present.append((name, 'view-or-no-count'))
        except Exception as e:
            missing.append(f"{name} (error: {e})")
    cur.close()
    return present, missing


def main():
    expected_db = parse_expected(DB_SCHEMA)
    expected_ai = parse_expected(AI_SCHEMA)
    expected = expected_db + expected_ai
    # Add explicit ai_analytics if not present
    if 'ai_analytics' not in expected:
        expected.append('ai_analytics')

    conn = connect()
    try:
        ensure_ai_table(conn)
        present, missing = check_expected(conn, expected)
        print('\nPresent tables/views:')
        for p in present:
            print(' -', p[0], ':', p[1])
        print('\nMissing tables/views:')
        if not missing:
            print(' - None')
        else:
            for m in missing:
                print(' -', m)
    finally:
        conn.close()

if __name__ == '__main__':
    main()
