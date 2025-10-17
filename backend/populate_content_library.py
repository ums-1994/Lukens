"""
Populate Content Library with Khonology-specific content
"""
import psycopg2
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def get_db_connection():
    """Get PostgreSQL database connection"""
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        database=os.getenv("DB_NAME", "khonopro_db"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "")
    )

def populate_content_library():
    """Execute SQL script to create and populate content library"""
    print("🚀 Starting content library population...")
    
    # Read SQL file
    sql_file = os.path.join(os.path.dirname(__file__), "setup_content_library.sql")
    with open(sql_file, 'r', encoding='utf-8') as f:
        sql_script = f.read()
    
    try:
        # Connect to database
        conn = get_db_connection()
        cur = conn.cursor()
        
        print("📊 Creating tables and inserting content...")
        
        # Execute SQL script
        cur.execute(sql_script)
        conn.commit()
        
        # Get summary
        cur.execute("""
            SELECT 
                category,
                COUNT(*) as module_count
            FROM content_modules
            GROUP BY category
            ORDER BY category
        """)
        
        results = cur.fetchall()
        
        print("\n✅ Content library populated successfully!")
        print("\n📚 Content Summary:")
        print("-" * 50)
        
        total = 0
        for category, count in results:
            print(f"  {category:.<30} {count:>3} modules")
            total += count
        
        print("-" * 50)
        print(f"  {'TOTAL':.<30} {total:>3} modules")
        
        # Show sample titles
        print("\n📝 Sample Content Modules:")
        print("-" * 50)
        cur.execute("""
            SELECT title, category 
            FROM content_modules 
            ORDER BY category, title 
            LIMIT 10
        """)
        
        for title, category in cur.fetchall():
            print(f"  [{category}] {title}")
        
        cur.close()
        conn.close()
        
        print("\n✨ Done! Your content library is ready to use.")
        print("\n💡 Next steps:")
        print("  1. Start the backend: uvicorn app:app --reload")
        print("  2. Access content via: GET http://localhost:8000/api/modules/")
        print("  3. Filter by category: GET http://localhost:8000/api/modules/?category=Templates")
        
    except psycopg2.Error as e:
        print(f"\n❌ Database error: {e}")
        print("\n💡 Make sure:")
        print("  1. PostgreSQL is running")
        print("  2. Database credentials in .env are correct")
        print("  3. Database exists and is accessible")
        return False
    
    except FileNotFoundError:
        print(f"\n❌ SQL file not found: {sql_file}")
        return False
    
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        return False
    
    return True

if __name__ == "__main__":
    populate_content_library()