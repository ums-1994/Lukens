"""
Helper script to get the actual Cloudinary image URL from a collection URL
"""
import os
from dotenv import load_dotenv

load_dotenv()

# The collection URL you provided
collection_url = "https://collection.cloudinary.com/dhy0jccgg/00b50c51d68087e18eee4633e14212ad"

# Extract cloud name from URL
# Format: https://collection.cloudinary.com/{cloud_name}/...
cloud_name = collection_url.split('/')[3]  # Should be 'dhy0jccgg'

print(f"[INFO] Cloud name: {cloud_name}")
print(f"[INFO] Collection URL: {collection_url}")

# You need to get the public_id from Cloudinary dashboard
# Or we can try to construct it

# Option 1: If you know the public_id, construct the URL directly
# public_id = "your_public_id_here"
# image_url = f"https://res.cloudinary.com/{cloud_name}/image/upload/{public_id}"

# Option 2: Use the asset ID from the URL (might work)
asset_id = collection_url.split('/')[-1]
print(f"\n[INFO] Asset ID from URL: {asset_id}")

# Try to get the actual image URL
# Note: Collection URLs don't directly translate to image URLs
# You need to:
# 1. Go to Cloudinary Dashboard
# 2. Find the image in Media Library
# 3. Click on it to see the delivery URL
# OR use the API to fetch it

try:
    import cloudinary
    import cloudinary.api
    
    # Configure with your credentials
    api_key = os.getenv('CLOUDINARY_API_KEY')
    api_secret = os.getenv('CLOUDINARY_API_SECRET')
    
    if all([cloud_name, api_key, api_secret]):
        cloudinary.config(
            cloud_name=cloud_name,
            api_key=api_key,
            api_secret=api_secret
        )
        
        # Try to search for resources
        print("\n[*] Searching for resources in Cloudinary...")
        resources = cloudinary.api.resources(max_results=10)
        
        print(f"\n[INFO] Found {len(resources.get('resources', []))} resources")
        print("\n[INFO] Recent images:")
        for resource in resources.get('resources', [])[:5]:
            public_id = resource.get('public_id')
            secure_url = resource.get('secure_url')
            print(f"  - Public ID: {public_id}")
            print(f"    URL: {secure_url}")
            if asset_id in str(resource.get('asset_id', '')):
                print(f"    *** This might be your logo! ***")
                print(f"\n[SUCCESS] Use this in your .env:")
                print(f"KHONOLOGY_LOGO_URL={secure_url}")
                print(f"\nOr:")
                print(f"KHONOLOGY_LOGO_CLOUDINARY_ID={public_id}")
    else:
        print("\n[INFO] Cloudinary credentials not found in .env")
        print("[INFO] Please set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET")
        print("\n[MANUAL] To get the image URL manually:")
        print("1. Go to https://cloudinary.com/console")
        print("2. Navigate to Media Library")
        print("3. Find your logo image")
        print("4. Click on it to see the delivery URL")
        print("5. Copy the 'Secure URL' or 'URL'")
        print("6. Add to .env: KHONOLOGY_LOGO_URL=<that_url>")
        
except ImportError:
    print("\n[ERROR] Cloudinary not installed. Run: pip install cloudinary")
except Exception as e:
    print(f"\n[ERROR] {e}")
    print("\n[MANUAL] To get the image URL manually:")
    print("1. Go to https://cloudinary.com/console")
    print("2. Navigate to Media Library")
    print("3. Find your logo image")
    print("4. Click on it to see the delivery URL")
    print("5. Copy the 'Secure URL' or 'URL'")
    print("6. Add to .env: KHONOLOGY_LOGO_URL=<that_url>")




