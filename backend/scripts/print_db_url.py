import pathlib
p = pathlib.Path(__file__).parent.parent.joinpath('.env')
text = p.read_text()
lines = [l.strip() for l in text.splitlines() if l.strip() and not l.strip().startswith('#')]
d = {}
for l in lines:
    if '=' in l:
        k, v = l.split('=', 1)
        d[k.strip()] = v.strip()

if d.get('USE_SQLITE', '').lower() == 'true':
    print('Using SQLite:', d.get('SQLITE_URL', 'sqlite:///./khonopro_client.db'))
elif d.get('DATABASE_URL'):
    print('DATABASE_URL in .env:', d.get('DATABASE_URL'))
else:
    url = f"postgresql+psycopg2://{d.get('DB_USER','postgres')}:{d.get('DB_PASSWORD','')}@{d.get('DB_HOST','localhost')}:{d.get('DB_PORT','5432')}/{d.get('DB_NAME','proposal_sow_builder')}"
    print('Computed URL:', url)
