#!/usr/bin/env python3
"""
Setup script for compatible database schema
"""
import os
import sys
from sqlalchemy import create_engine, text
from database_config import create_database_engine
from models_compatible import Base

def setup_compatible_database():
    """Set up the compatible client tables"""
    print("🗄️  Setting up KhonoPro Client Tables (compatible with existing schema)...")
    
    try:
        # Create tables
        print("📋 Creating compatible client tables...")
        engine = create_database_engine()
        Base.metadata.create_all(bind=engine)
        print("✅ Compatible client tables created successfully!")
        
        # Test connection
        print("🔗 Testing database connection...")
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version()"))
            version = result.fetchone()[0]
            print(f"✅ Connected to: {version}")
        
        # Check existing data
        with engine.connect() as conn:
            # Check existing proposals
            result = conn.execute(text("SELECT COUNT(*) FROM proposals"))
            proposal_count = result.fetchone()[0]
            print(f"📊 Found {proposal_count} existing proposals")
            
            # Check if clients exist
            result = conn.execute(text("SELECT COUNT(*) FROM clients"))
            client_count = result.fetchone()[0]
            
            if client_count > 0:
                print(f"ℹ️  Found {client_count} existing clients")
            else:
                # Insert sample clients
                print("📊 Inserting sample clients...")
                conn.execute(text("""
                    INSERT INTO clients (name, email, organization, role, token) VALUES 
                    ('Jane Doe', 'jane.doe@example.com', 'Acme Corp', 'Client', gen_random_uuid()),
                    ('John Smith', 'john.smith@techcorp.com', 'Tech Corp', 'Client', gen_random_uuid()),
                    ('Admin User', 'admin@khonology.com', 'Khonology', 'Admin', gen_random_uuid())
                    ON CONFLICT (email) DO NOTHING;
                """))
                
                # Link existing proposals to clients (optional)
                conn.execute(text("""
                    UPDATE proposals 
                    SET client_id = (SELECT id FROM clients WHERE email = 'jane.doe@example.com' LIMIT 1)
                    WHERE client_email = 'jane.doe@example.com';
                """))
                
                conn.execute(text("""
                    UPDATE proposals 
                    SET client_id = (SELECT id FROM clients WHERE email = 'john.smith@techcorp.com' LIMIT 1)
                    WHERE client_email = 'john.smith@techcorp.com';
                """))
                
                conn.commit()
                print("✅ Sample clients inserted and linked to existing proposals!")
        
        print("\n🎉 Compatible database setup completed successfully!")
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
    setup_compatible_database()
