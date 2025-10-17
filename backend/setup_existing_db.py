#!/usr/bin/env python3
"""
Setup script for existing PostgreSQL database
"""
import os
import sys
from sqlalchemy import create_engine, text
from database_config import create_database_engine, create_tables

def setup_existing_database():
    """Set up the client tables in your existing PostgreSQL database"""
    print("🗄️  Setting up KhonoPro Client Tables in existing database...")
    
    try:
        # Create tables
        print("📋 Creating client tables in your existing database...")
        engine = create_tables()
        print("✅ Client tables created successfully!")
        
        # Test connection
        print("🔗 Testing database connection...")
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version()"))
            version = result.fetchone()[0]
            print(f"✅ Connected to: {version}")
        
        # Check if tables already have data
        with engine.connect() as conn:
            result = conn.execute(text("SELECT COUNT(*) FROM clients"))
            client_count = result.fetchone()[0]
            
            if client_count > 0:
                print(f"ℹ️  Found {client_count} existing clients in database")
                print("📊 Skipping sample data insertion to avoid duplicates")
            else:
                # Insert sample data only if no clients exist
                print("📊 Inserting sample data...")
                conn.execute(text("""
                    INSERT INTO clients (name, email, organization, role) VALUES 
                    ('Jane Doe', 'jane.doe@example.com', 'Acme Corp', 'Client'),
                    ('John Smith', 'john.smith@techcorp.com', 'Tech Corp', 'Client'),
                    ('Admin User', 'admin@khonology.com', 'Khonology', 'Admin')
                    ON CONFLICT (email) DO NOTHING;
                """))
                
                conn.execute(text("""
                    INSERT INTO proposals (title, content, status, client_id) VALUES 
                    ('Acme Financial Proposal', 'Comprehensive financial analysis and recommendations for Acme Corp', 'Released', 
                     (SELECT id FROM clients WHERE email='jane.doe@example.com')),
                    ('Tech Corp Digital Transformation', 'Digital transformation strategy for Tech Corp', 'In Review',
                     (SELECT id FROM clients WHERE email='john.smith@techcorp.com'))
                    ON CONFLICT DO NOTHING;
                """))
                
                conn.commit()
                print("✅ Sample data inserted successfully!")
        
        print("\n🎉 Database setup completed successfully!")
        print(f"📊 Database: {os.getenv('DB_NAME', 'proposal_sow_builder')}")
        print(f"🏠 Host: {os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}")
        print("\n📋 Next steps:")
        print("1. Start the backend: python -m uvicorn app:app --host 127.0.0.1 --port 8000")
        print("2. Start the Flutter app: cd frontend_flutter && flutter run -d chrome --web-port 3000")
        print("3. Test the client dashboard flow")
        
    except Exception as e:
        print(f"❌ Error setting up database: {e}")
        print("\n🔧 Troubleshooting:")
        print("1. Make sure PostgreSQL is running")
        print("2. Check your .env file has correct database credentials")
        print("3. Ensure the database 'proposal_sow_builder' exists")
        print("4. Verify the user has proper permissions")
        sys.exit(1)

if __name__ == "__main__":
    setup_existing_database()
