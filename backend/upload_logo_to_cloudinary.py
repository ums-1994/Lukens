"""
One-time script to upload Khonology logo to Cloudinary
Run this once to upload the logo, then set KHONOLOGY_LOGO_CLOUDINARY_ID in your .env
"""
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

try:
    import cloudinary
    import cloudinary.uploader
    import cloudinary.config
except ImportError:
    print("[ERROR] Cloudinary not installed. Run: pip install cloudinary")
    exit(1)

# Configure Cloudinary
cloud_name = os.getenv('CLOUDINARY_CLOUD_NAME')
api_key = os.getenv('CLOUDINARY_API_KEY')
api_secret = os.getenv('CLOUDINARY_API_SECRET')

if not all([cloud_name, api_key, api_secret]):
    print("[ERROR] Cloudinary credentials not found in .env file")
    print("[INFO] Please set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET")
    exit(1)

cloudinary.config(
    cloud_name=cloud_name,
    api_key=api_key,
    api_secret=api_secret
)

# Find logo file
logo_path = Path(__file__).parent.parent / 'frontend_flutter' / 'assets' / 'images' / '2026.png'

if not logo_path.exists():
    print(f"[ERROR] Logo file not found at: {logo_path}")
    exit(1)

print(f"[*] Uploading logo from: {logo_path}")
print(f"[*] Cloudinary cloud: {cloud_name}")

try:
    # Upload to Cloudinary
    result = cloudinary.uploader.upload(
        str(logo_path),
        public_id='khonology_logo',
        folder='email_assets',
        overwrite=True,
        resource_type='image',
        transformation=[
            {'width': 400, 'height': 400, 'crop': 'limit', 'quality': 'auto'}
        ]
    )
    
    logo_url = result.get('secure_url') or result.get('url')
    public_id = result.get('public_id', 'email_assets/khonology_logo')
    
    print(f"\n[SUCCESS] Logo uploaded successfully!")
    print(f"[URL] {logo_url}")
    print(f"[PUBLIC_ID] {public_id}")
    print(f"\n[INFO] Add this to your .env file:")
    print(f"KHONOLOGY_LOGO_CLOUDINARY_ID={public_id}")
    print(f"\n[INFO] Or use the direct URL:")
    print(f"KHONOLOGY_LOGO_URL={logo_url}")
    
except Exception as e:
    print(f"[ERROR] Failed to upload logo: {e}")
    import traceback
    traceback.print_exc()
    exit(1)




