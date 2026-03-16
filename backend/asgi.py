"""ASGI wrapper for Flask app to work with Uvicorn"""
import sys
import os

# Get the directory this script is in
script_dir = os.path.dirname(os.path.abspath(__file__))

# Add the backend directory to path if not already there
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

# Change to backend directory for proper imports
os.chdir(script_dir)

# Initialize DB at startup so first request doesn't trigger sync init (avoids ASGI deadlock)
try:
    from api.utils.database import init_database
    init_database()
except Exception as e:
    print(f"[WARN] Startup DB init failed (will retry on first request): {e}")

# Import Flask app
from app import app as flask_app

# Create ASGI app by wrapping the Flask WSGI app.
# Prefer Starlette's WSGIMiddleware to avoid asgiref's thread-sensitive deadlock
# under concurrent requests.
try:
    from starlette.middleware.wsgi import WSGIMiddleware  # type: ignore

    app = WSGIMiddleware(flask_app)
except Exception:
    from asgiref.wsgi import WsgiToAsgi

    app = WsgiToAsgi(flask_app)

# Make sure this is the entry point Uvicorn calls
__all__ = ['app']