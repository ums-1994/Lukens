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

# Import Flask app
from app import app as flask_app
from asgiref.wsgi import WsgiToAsgi

# Create ASGI app by wrapping the Flask WSGI app
app = WsgiToAsgi(flask_app)

# Make sure this is the entry point Uvicorn calls
__all__ = ['app']