"""
Lightweight DB table checker using pg8000 (pure-Python) to avoid compiling psycopg2.
Reads `backend/.env` for DB_* vars and prints public tables.
"""
import os
import ssl

ENV_PATH = os.path.join(os.path.dirname(__file__), '.env')

def load_env(path):
    data = {}
    if not os.path.exists(path):
        return data
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                k, v = line.split('=', 1)
                data[k.strip()] = v.strip()
    return data


def main():
    env = load_env(ENV_PATH)
    host = env.get('DB_HOST') or env.get('HOST')
    port = int(env.get('DB_PORT', 5432))
    dbname = env.get('DB_NAME') or env.get('DATABASE') or env.get('DATABASE_URL')
    user = env.get('DB_USER') or env.get('DATABASE_USER')
    password = env.get('DB_PASSWORD')
    sslmode = env.get('DB_SSLMODE', '').lower()

    if not host or not dbname or not user:
        print('[ERROR] Missing DB connection info in .env')
        print('Found keys:', ','.join(sorted(env.keys())))
        return 2

    try:
        import pg8000
    except Exception as e:
        print('[ERROR] pg8000 not installed:', e)
        return 3

    use_ssl = sslmode in ('require', 'verify-ca', 'verify-full')
    ssl_context = None
    if use_ssl:
        ssl_context = ssl.create_default_context()

    try:
        # pg8000.connect accepts ssl=bool or ssl_context depending on version
        conn = None
        try:
            conn = pg8000.connect(host=host, port=port, database=dbname, user=user, password=password, ssl=use_ssl)
        except TypeError:
            # Fallback to ssl_context arg
            conn = pg8000.connect(host=host, port=port, database=dbname, user=user, password=password, ssl_context=ssl_context)

        cur = conn.cursor()
        cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;")
        rows = cur.fetchall()
        if not rows:
            print('No tables found in public schema.')
        else:
            print(f'Found {len(rows)} tables:')
            for r in rows:
                print('  -', r[0])
        cur.close()
        conn.close()
        return 0
    except Exception as e:
        print('[ERROR] Could not query database:', e)
        return 4


if __name__ == '__main__':
    raise SystemExit(main())
