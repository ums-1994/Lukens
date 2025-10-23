import psycopg2
from datetime import datetime
import os
from dotenv import load_dotenv

load_dotenv()

# Database configuration
DATABASE_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', 5432),
    'database': os.getenv('DB_NAME', 'khonology'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'postgres')
}

print("""
╔══════════════════════════════════════════════════════════════╗
║         Add Your Cloudinary Images to Content Library        ║
╚══════════════════════════════════════════════════════════════╝

This script will help you add your own Cloudinary images.

Instructions:
1. Paste your Cloudinary image URLs one by one
2. Give each image a descriptive name
3. Type 'done' when finished
""")

images = []

while True:
    print("\n" + "="*60)
    url = input("\nEnter Cloudinary image URL (or 'done' to finish): ").strip()
    
    if url.lower() == 'done':
        break
    
    if not url:
        print("❌ URL cannot be empty!")
        continue
    
    if not url.startswith('http'):
        print("❌ Please enter a valid URL starting with http:// or https://")
        continue
    
    name = input("Enter a name for this image: ").strip()
    
    if not name:
        print("❌ Name cannot be empty!")
        continue
    
    # Generate key from name
    key = name.lower().replace(' ', '_').replace('-', '_')
    
    # Extract public_id from Cloudinary URL (optional)
    public_id = key
    if '/upload/' in url:
        try:
            parts = url.split('/upload/')
            if len(parts) > 1:
                # Get the part after /upload/
                after_upload = parts[1]
                # Remove version if present (v1234567890/)
                if after_upload.startswith('v'):
                    after_upload = '/'.join(after_upload.split('/')[1:])
                # Remove file extension
                public_id = after_upload.rsplit('.', 1)[0]
        except:
            pass
    
    images.append({
        'key': key,
        'label': name,
        'content': url,
        'category': 'Images',
        'public_id': public_id
    })
    
    print(f"✅ Added: {name}")
    print(f"   URL: {url}")

if not images:
    print("\n❌ No images to add. Exiting...")
    exit()

print(f"\n📦 Total images to add: {len(images)}")
confirm = input("\nDo you want to add these images to the database? (yes/no): ").strip().lower()

if confirm not in ['yes', 'y']:
    print("❌ Cancelled.")
    exit()

# Add to database
try:
    conn = psycopg2.connect(**DATABASE_CONFIG)
    cursor = conn.cursor()
    
    print("\n🔄 Adding images to database...")
    
    for img in images:
        try:
            cursor.execute("""
                INSERT INTO content (key, label, content, category, is_folder, public_id, created_at, updated_at, is_deleted)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (key) DO UPDATE SET
                    content = EXCLUDED.content,
                    label = EXCLUDED.label,
                    updated_at = EXCLUDED.updated_at
            """, (
                img['key'],
                img['label'],
                img['content'],
                img['category'],
                False,  # is_folder
                img['public_id'],
                datetime.now(),
                datetime.now(),
                False  # is_deleted
            ))
            print(f"  ✅ {img['label']}")
        except Exception as e:
            print(f"  ⚠️ Error adding {img['label']}: {e}")
    
    conn.commit()
    
    # Show total count
    cursor.execute("SELECT COUNT(*) FROM content WHERE category = 'Images' AND is_deleted = false")
    total = cursor.fetchone()[0]
    
    cursor.close()
    conn.close()
    
    print(f"\n✅ Success! Total images in library: {total}")
    print("\n💡 Refresh your browser to see the new images in the Content Library!")
    
except Exception as e:
    print(f"\n❌ Database error: {e}")
    print(f"\nMake sure:")
    print(f"  • Your database is running")
    print(f"  • Database credentials are correct in .env file")

