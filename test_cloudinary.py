import os
import sys
sys.path.insert(0, 'backend')

from dotenv import load_dotenv
load_dotenv()

print("=== Cloudinary Configuration Check ===")
print(f"CLOUDINARY_CLOUD_NAME: {os.getenv('CLOUDINARY_CLOUD_NAME')}")
print(f"CLOUDINARY_API_KEY: {os.getenv('CLOUDINARY_API_KEY')}")
print(f"CLOUDINARY_API_SECRET: {'*' * 10 if os.getenv('CLOUDINARY_API_SECRET') else 'NOT SET'}")

# Test import
try:
    from backend.cloudinary_config import upload_to_cloudinary
    print("\n✓ cloudinary_config imported successfully")
    
    # Test with a non-existent file to see the error
    result = upload_to_cloudinary("nonexistent.txt", resource_type="raw", folder="test")
    print(f"\nTest result: {result}")
except Exception as e:
    print(f"\n✗ Error: {e}")
    import traceback
    traceback.print_exc()