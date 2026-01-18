#!/usr/bin/env python3
"""
Test script to verify the JWT token processing logic
"""
import os
from dotenv import load_dotenv
import sys
sys.path.append('.')

# Load environment variables
load_dotenv()

# Import the JWT validator
try:
    from api.utils.jwt_validator import validate_jwt_token, extract_user_info, _get_fernet
    print("✅ Successfully imported JWT validator")
except ImportError as e:
    print(f"❌ Failed to import JWT validator: {e}")
    sys.exit(1)

def test_encryption_key():
    """Test if encryption key is available"""
    print("\n=== Testing Encryption Key ===")
    
    # Check environment variables
    print(f"ENCRYPTION_KEY: {'SET' if os.getenv('ENCRYPTION_KEY') else 'NOT SET'}")
    print(f"JWT_SECRET_KEY: {'SET' if os.getenv('JWT_SECRET_KEY') else 'NOT SET'}")
    print(f"JWT_ENCRYPTION_KEY: {'SET' if os.getenv('JWT_ENCRYPTION_KEY') else 'NOT SET'}")
    print(f"FERNET_KEY: {'SET' if os.getenv('FERNET_KEY') else 'NOT SET'}")
    
    # Test Fernet initialization
    fernet = _get_fernet()
    print(f"Fernet instance: {'CREATED' if fernet else 'NOT CREATED'}")
    
    return fernet is not None

def test_jwt_validation():
    """Test JWT validation with the test token"""
    print("\n=== Testing JWT Validation ===")
    
    # Test token (Fernet-encrypted)
    test_token = "gAAAAABpbJUVzi5i48UxVLE482MF2g3Y9h5h7liF4jrJsx2ml1yVrKfM7k-zASENOoFJxcw-gzPoiTVRvjEyopKTkTz3MyK8DwtApx7qDNHBOFZM--y0mB0u9pCzzzF94BwMgmb8_fSTCbYsXNxCAOIT4dE7in0jni82tunuWulyRQakXfAz5GQpS5mw5R7v5TTEDQCkID7RGFnXHhoj0hbOqvOFXc3l3DOWMv06zwl1m97r8gpt8iUp5cCZ5krTNRqqkl6gIDzF_9FSeqSzUpAoKG5O8I_-j6sb4eUsX-zLB07Kihb05-rgUU2mFAIp6R_ESw4rJpveqlt2XlnBNwGPCc1fWa_hJPQiwgrr3HeU5EMqx2Be7PAq16opJdQNG2Diun9dx7gGcnrK4rUS2r_KN0Z62_lUDOvFFWK03ZoW12Q3s-1pqUkXUGdX4ixbs8M5WhmvJ32JwkzyOMehwhNc68skp6C9MchMXeZ01fsVmVX2WWdRMJW0QzhpRUBrTjSMO8YuQpZJtq4-jmxV88rfvSl6VJ1UDZ4njlujkoty6lCDC9VpISxEs36hc0dUY_jCTJ3WlJlAvLVFcsIfCFbeKzw8h0N5O9PBJe4qfPF0jyjR112buHXXgIjrYz_cNnwGouV6qpFZorrX7lC6iqp6rXKF5ybn9INpHTjlt-rd_2ZZPP8w2-C1UOSQwpaTuqP5XzSeV2leJm5RXyQ5NTROPUkVWGlRvXSGjRtQlxiExGFdLhU1bE2Zv9ciQb1yxz61qR6GsmsM"
    
    try:
        print(f"Testing token: {test_token[:50]}...")
        decoded = validate_jwt_token(test_token)
        print("✅ JWT validation successful!")
        print(f"User ID: {decoded.get('user_id')}")
        print(f"Email: {decoded.get('email')}")
        print(f"Roles: {decoded.get('roles')}")
        
        # Extract user info
        user_info = extract_user_info(decoded)
        print(f"✅ User info extracted: {user_info}")
        
        return True
    except Exception as e:
        print(f"❌ JWT validation failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("JWT Token Processing Test")
    print("=" * 50)
    
    # Test 1: Check encryption key
    key_ok = test_encryption_key()
    
    # Test 2: Test JWT validation
    jwt_ok = test_jwt_validation()
    
    # Summary
    print("\n" + "=" * 50)
    print("SUMMARY:")
    print(f"Encryption Key: {'✅ OK' if key_ok else '❌ MISSING'}")
    print(f"JWT Validation: {'✅ OK' if jwt_ok else '❌ FAILED'}")
    
    if key_ok and jwt_ok:
        print("\n🎉 All tests passed! The JWT processing should work correctly.")
    else:
        print("\n⚠️ Some tests failed. Check the environment variables and code.")

if __name__ == "__main__":
    main()
