#!/usr/bin/env python3
"""
Quick test to verify Firebase Admin SDK is set up correctly
"""
import os
import sys

# Add backend to path
sys.path.insert(0, os.path.dirname(__file__))

def test_firebase_setup():
    """Test Firebase initialization"""
    print("=" * 60)
    print("Testing Firebase Admin SDK Setup")
    print("=" * 60)
    
    try:
        from api.utils.firebase_auth import initialize_firebase
        
        print("\n1. Testing Firebase initialization...")
        app = initialize_firebase()
        
        if app:
            print("✅ Firebase Admin SDK initialized successfully!")
            print(f"   App name: {app.name}")
            return True
        else:
            print("❌ Firebase Admin SDK failed to initialize")
            print("\nTroubleshooting:")
            print("1. Check that firebase-service-account.json exists in backend/")
            print("2. Verify the JSON file is valid")
            print("3. Make sure firebase-admin is installed: pip install firebase-admin")
            return False
            
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("\nInstall Firebase Admin SDK:")
        print("  pip install firebase-admin")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_firebase_setup()
    print("\n" + "=" * 60)
    if success:
        print("✅ Firebase setup is ready!")
        print("\nYou can now use Firebase authentication in your app.")
    else:
        print("❌ Firebase setup needs attention")
    print("=" * 60)
    sys.exit(0 if success else 1)

