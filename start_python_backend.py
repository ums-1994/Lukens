#!/usr/bin/env python3
"""
Start the Python backend server for Proposal & SOW Builder
"""

import subprocess
import sys
import os

def main():
    # Change to the backend directory
    backend_dir = os.path.join(os.path.dirname(__file__), 'backend')
    os.chdir(backend_dir)
    
    print("🚀 Starting Python Backend Server...")
    print("📧 SMTP Email Verification: ENABLED")
    print("🔗 Server URL: http://localhost:8000")
    print("📚 API Docs: http://localhost:8000/docs")
    print("\n" + "="*50)
    
    try:
        # Start the Flask server with Uvicorn (using ASGI adapter)
        subprocess.run([
            sys.executable, "-m", "uvicorn", 
            "asgi:app", 
            "--host", "127.0.0.1", 
            "--port", "8000", 
            "--reload"
        ])
    except KeyboardInterrupt:
        print("\n\n🛑 Server stopped by user")
    except Exception as e:
        print(f"\n❌ Error starting server: {e}")
        print("\n💡 Make sure you have installed the requirements:")
        print("   pip install -r requirements.txt")

if __name__ == "__main__":
    main()
