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

# Load environment variables early
from dotenv import load_dotenv
load_dotenv()

# Initialize Firestore if enabled (before importing app)
USE_FIRESTORE = os.getenv('USE_FIRESTORE', 'false').lower() == 'true'
if USE_FIRESTORE:
    try:
        from api.utils.firestore_db import get_firestore_client
        # Initialize Firestore client on startup
        get_firestore_client()
        print("[OK] Firestore initialized on startup")
    except Exception as e:
        print(f"[ERROR] Failed to initialize Firestore on startup: {e}")
        import traceback
        traceback.print_exc()

# Import Flask app
from app import app as flask_app
from asgiref.wsgi import WsgiToAsgi

# Create ASGI app by wrapping the Flask WSGI app
app = WsgiToAsgi(flask_app)

# Make sure this is the entry point Uvicorn calls
__all__ = ['app']