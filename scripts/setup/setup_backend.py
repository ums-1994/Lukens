#!/usr/bin/env python3
"""
Setup script for Proposal & SOW Builder Python Backend
Run this script to automatically set up and start the backend server.
"""

import subprocess
import sys
import os
import time

def run_command(command, description):
    """Run a command and handle errors"""
    print(f"🔄 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed:")
        print(f"Error: {e.stderr}")
        return False

def check_python_version():
    """Check if Python version is compatible"""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 8):
        print("❌ Python 3.8 or higher is required")
        print(f"Current version: {version.major}.{version.minor}.{version.micro}")
        return False
    print(f"✅ Python version {version.major}.{version.minor}.{version.micro} is compatible")
    return True

def main():
    print("🚀 Setting up Proposal & SOW Builder Backend")
    print("=" * 50)
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Change to backend directory (go up from scripts/setup/ to root, then to backend)
    script_dir = os.path.dirname(__file__)
    root_dir = os.path.dirname(os.path.dirname(script_dir))
    backend_dir = os.path.join(root_dir, 'backend')
    if not os.path.exists(backend_dir):
        print("❌ Backend directory not found")
        sys.exit(1)
    
    os.chdir(backend_dir)
    print(f"📁 Changed to directory: {backend_dir}")
    
    # Install dependencies
    if not run_command("pip install -r requirements.txt", "Installing Python dependencies"):
        print("💡 Try running: pip install --upgrade pip")
        sys.exit(1)
    
    print("\n🎉 Setup completed successfully!")
    print("\n📋 Next steps:")
    print("1. Start the backend server:")
    print("   uvicorn app:app --host 0.0.0.0 --port 8000 --reload")
    print("\n2. In another terminal, run the Flutter app:")
    print("   cd frontend_flutter")
    print("   flutter run -d chrome")
    print("\n3. The backend will be available at: http://localhost:8000")
    print("4. API documentation at: http://localhost:8000/docs")
    
    # Ask if user wants to start the server now
    try:
        start_now = input("\n🤔 Do you want to start the server now? (y/n): ").lower().strip()
        if start_now in ['y', 'yes']:
            print("\n🚀 Starting backend server...")
            print("Press Ctrl+C to stop the server")
            print("=" * 50)
            subprocess.run("uvicorn app:app --host 0.0.0.0 --port 8000 --reload", shell=True)
    except KeyboardInterrupt:
        print("\n👋 Server stopped. Goodbye!")

if __name__ == "__main__":
    main()
