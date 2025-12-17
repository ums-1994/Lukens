#!/usr/bin/env python3
"""
Setup script for AI Analytics tables
Applies the ai_analytics_schema.sql to your database
"""

import os
import sys
import psycopg2
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def setup_ai_analytics():
    """Setup AI analytics tables in the database"""
    
    # Get database connection details
    db_url = os.getenv('DATABASE_URL')
    
    if not db_url:
        print("❌ DATABASE_URL not found in environment variables!")
        print("Please set it in your .env file or environment")
        sys.exit(1)
    
    print("🔧 Setting up AI Analytics tables...")
    print(f"📊 Database: {db_url.split('@')[1] if '@' in db_url else 'local'}")
    
    try:
        # Connect to database
        conn = psycopg2.connect(db_url)
        cursor = conn.cursor()
        
        print("✅ Connected to database")
        
        # Read SQL schema file
        schema_file = os.path.join(os.path.dirname(__file__), 'ai_analytics_schema.sql')
        
        with open(schema_file, 'r') as f:
            sql_script = f.read()
        
        print("📄 Executing SQL schema...")
        
        # Execute the schema
        cursor.execute(sql_script)
        conn.commit()
        
        print("✅ AI Analytics tables created successfully!")
        
        # Verify tables exist
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_name IN ('ai_usage', 'ai_content_feedback')
        """)
        
        tables = cursor.fetchall()
        print(f"\n📋 Verified tables: {[t[0] for t in tables]}")
        
        # Check if proposals table has new columns
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'proposals' 
            AND column_name IN ('ai_generated', 'ai_metadata')
        """)
        
        columns = cursor.fetchall()
        if columns:
            print(f"✅ Proposals table updated with columns: {[c[0] for c in columns]}")
        
        # Check views
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.views 
            WHERE table_name IN ('ai_analytics_summary', 'user_ai_stats')
        """)
        
        views = cursor.fetchall()
        if views:
            print(f"📊 Analytics views created: {[v[0] for v in views]}")
        
        cursor.close()
        conn.close()
        
        print("\n🎉 Setup complete! AI Analytics is ready to track usage.")
        print("\n📝 Next steps:")
        print("   1. Restart your backend: python app.py")
        print("   2. Use AI Assistant in the app")
        print("   3. View analytics: GET /ai/analytics/summary")
        
    except FileNotFoundError:
        print("❌ ai_analytics_schema.sql not found!")
        print("Make sure you're running this from the backend directory")
        sys.exit(1)
        
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        sys.exit(1)
        
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    setup_ai_analytics()

