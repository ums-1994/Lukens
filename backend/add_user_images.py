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

# Your Cloudinary images
USER_IMAGES = [
    {
        'key': 'abstract_red_circular',
        'label': 'Abstract Red Circular Pattern',
        'content': 'https://res.cloudinary.com/dhy0jccgg/image/upload/v1760890158/proposal_builder/images/wcbprrnpmyg2phe4wtio.png',
        'category': 'Images',
        'public_id': 'proposal_builder/images/wcbprrnpmyg2phe4wtio'
    },
    {
        'key': 'background_image_2',
        'label': 'Background Image 2',
        'content': 'https://res.cloudinary.com/dhy0jccgg/image/upload/v1760884426/proposal_builder/images/qboeusv10uhgozkcbbkc.png',
        'category': 'Images',
        'public_id': 'proposal_builder/images/qboeusv10uhgozkcbbkc'
    },
    {
        'key': 'background_image_3',
        'label': 'Background Image 3',
        'content': 'https://res.cloudinary.com/dhy0jccgg/image/upload/v1760877243/proposal_builder/images/dcizyxk2xie2bhzoyail.jpg',
        'category': 'Images',
        'public_id': 'proposal_builder/images/dcizyxk2xie2bhzoyail'
    }
]

def add_images_to_db():
    """Insert user's Cloudinary images into the content table"""
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(**DATABASE_CONFIG)
        cursor = conn.cursor()
        
        print("🔄 Adding your Cloudinary images to content library...")
        print()
        
        # Insert each image
        for img in USER_IMAGES:
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
                print(f"✅ Added: {img['label']}")
                print(f"   URL: {img['content'][:80]}...")
            except Exception as e:
                print(f"⚠️ Error adding {img['label']}: {e}")
        
        # Commit changes
        conn.commit()
        
        # Verify insertion
        cursor.execute("SELECT COUNT(*) FROM content WHERE category = 'Images' AND is_deleted = false")
        count = cursor.fetchone()[0]
        
        # Show all images
        print()
        print("="*70)
        cursor.execute("SELECT label, content FROM content WHERE category = 'Images' AND is_deleted = false ORDER BY created_at DESC")
        images = cursor.fetchall()
        print(f"\n📚 All Images in Content Library ({count} total):\n")
        for idx, (label, url) in enumerate(images, 1):
            print(f"  {idx}. {label}")
            print(f"     {url[:70]}...")
        
        cursor.close()
        conn.close()
        
        print("\n" + "="*70)
        print("✅ Success! Your images have been added!")
        print("\n💡 Next steps:")
        print("   1. Refresh your browser (F5 or Ctrl+R)")
        print("   2. Go to Content Library → Images category")
        print("   3. You should see your 3 images plus the 8 sample images")
        print("   4. Use them as backgrounds in your documents!")
        
    except Exception as e:
        print(f"❌ Database error: {e}")
        print(f"\nMake sure your database is running and credentials are correct:")
        print(f"  Host: {DATABASE_CONFIG['host']}")
        print(f"  Database: {DATABASE_CONFIG['database']}")
        print(f"  User: {DATABASE_CONFIG['user']}")

if __name__ == "__main__":
    add_images_to_db()

