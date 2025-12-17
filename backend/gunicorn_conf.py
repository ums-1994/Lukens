import os

# Use PORT from environment (Render provides this) or default to 8000
# Render automatically sets PORT environment variable
port = os.environ.get('PORT', '8000')
if not port:
    port = '8000'

bind = f"0.0.0.0:{port}"
workers = int(os.environ.get('WORKERS', '4'))
threads = int(os.environ.get('THREADS', '2'))
timeout = int(os.environ.get('TIMEOUT', '120'))
worker_class = 'sync'

# Log the bind address for debugging
print(f"🔌 Gunicorn binding to: {bind}")
