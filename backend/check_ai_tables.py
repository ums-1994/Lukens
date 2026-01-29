"""
Query specific AI-related tables and show existence + row counts.
"""
import os
from check_tables_pg import load_env

ENV_PATH = os.path.join(os.path.dirname(__file__), '.env')

env = load_env(ENV_PATH)
HOST = env.get('DB_HOST')
PORT = int(env.get('DB_PORT', 5432))
DB = env.get('DB_NAME') or env.get('DATABASE')
USER = env.get('DB_USER')
PASSWORD = env.get('DB_PASSWORD')
SSL = env.get('DB_SSLMODE', '').lower() in ('require','verify-ca','verify-full')

TABLES = ['ai_usage', 'ai_content_feedback', 'ai_settings', 'ai_analytics']

try:
    import pg8000
except Exception as e:
    print('pg8000 not installed:', e)
    raise SystemExit(1)


def query():
    try:
        # pg8000 may accept `ssl` (bool) or `ssl_context` depending on version.
        try:
            conn = pg8000.connect(host=HOST, port=PORT, database=DB, user=USER, password=PASSWORD, ssl=SSL)
        except TypeError:
            import ssl as _ssl
            ssl_ctx = None
            if SSL:
                ssl_ctx = _ssl.create_default_context()
            conn = pg8000.connect(host=HOST, port=PORT, database=DB, user=USER, password=PASSWORD, ssl_context=ssl_ctx)
        cur = conn.cursor()
        for t in TABLES:
            try:
                cur.execute(f"SELECT to_regclass('public.'||%s)", (t,))
                exists = cur.fetchone()[0]
                if not exists:
                    print(f"{t}: MISSING")
                    continue
                cur.execute(f"SELECT count(*) FROM {t}")
                count = cur.fetchone()[0]
                print(f"{t}: EXISTS ({count} rows)")
            except Exception as e:
                print(f"{t}: error - {e}")
        cur.close()
        conn.close()
    except Exception as e:
        print('Connection error:', e)
        raise

if __name__ == '__main__':
    query()
