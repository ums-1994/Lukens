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

# Sample Cloudinary image URLs (using demo images)
SAMPLE_IMAGES = [
    {
        'key': 'abstract_blue_bg',
        'label': 'Abstract Blue Background',
        'content': 'https://res.cloudinary.com/demo/image/upload/v1312461204/sample.jpg',
        'category': 'Images',
        'public_id': 'abstract_blue_bg'
    },
    {
        'key': 'professional_office',
        'label': 'Professional Office',
        'content': 'https://res.cloudinary.com/demo/image/upload/v1652345874/samples/landscapes/architecture-signs.jpg',
        'category': 'Images',
        'public_id': 'professional_office'
    },
    {
        'key': 'business_meeting',
        'label': 'Business Meeting',
        'content': 'https://res.cloudinary.com/demo/image/upload/v1652366604/samples/people/kitchen-bar.jpg',
        'category': 'Images',
        'public_id': 'business_meeting'
    },
    {
        'key': 'modern_workspace',
        'label': 'Modern Workspace',
        'content': 'https://res.cloudinary.com/demo/image/upload/v1652345874/samples/landscapes/beach-boat.jpg',
        'category': 'Images',
        'public_id': 'modern_workspace'
    },
    {
        'key': 'city_skyline',
        'label': 'City Skyline',
        'content': 'https://res.cloudinary.com/demo/image/upload/v1652345874/samples/landscapes/girl-urban-view.jpg',
        'category': 'Images',
        'public_id': 'city_skyline'
    },
    {
        'key': 'texture_pattern_1',
        'label': 'Texture Pattern 1',
        'content': 'https://res.cloudinary.com/demo/image/upload/v1652345874/samples/food/spices.jpg',
        'category': 'Images',
        'public_id': 'texture_pattern_1'
    },
    {
        'key': 'corporate_background',
        'label': 'Corporate Background',
        'content': 'https://res.cloudinary.com/demo/image/upload/v1652345874/samples/ecommerce/leather-bag-gray.jpg',
        'category': 'Images',
        'public_id': 'corporate_background'
    },
    {
        'key': 'minimal_gradient',
        'label': 'Minimal Gradient',
        'content': 'https://res.cloudinary.com/demo/image/upload/v1652345874/samples/bike.jpg',
        'category': 'Images',
        'public_id': 'minimal_gradient'
    }
]

def add_images_to_db():
    """Insert sample images into the content table"""
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(**DATABASE_CONFIG)
        cursor = conn.cursor()
        
        print("🔄 Adding sample images to content library...")
        
        # Insert each image
        for img in SAMPLE_IMAGES:
            try:
                cursor.execute("""
                    INSERT INTO content (key, label, content, category, is_folder, public_id, created_at, updated_at, is_deleted)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (key) DO UPDATE SET
                        content = EXCLUDED.content,
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
            except Exception as e:
                print(f"⚠️ Error adding {img['label']}: {e}")
        
        # Commit changes
        conn.commit()
        
        # Verify insertion
        cursor.execute("SELECT COUNT(*) FROM content WHERE category = 'Images' AND is_deleted = false")
        count = cursor.fetchone()[0]
        print(f"\n✅ Total images in library: {count}")
        
        cursor.close()
        conn.close()
        
        print("\n🎉 Sample images added successfully!")
        
    except Exception as e:
        print(f"❌ Database error: {e}")
        print(f"\nMake sure your database is running and credentials are correct:")
        print(f"  Host: {DATABASE_CONFIG['host']}")
        print(f"  Database: {DATABASE_CONFIG['database']}")
        print(f"  User: {DATABASE_CONFIG['user']}")

if __name__ == "__main__":
    add_images_to_db()

