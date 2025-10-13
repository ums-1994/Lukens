#!/usr/bin/env python3
"""
Database setup script for KhonoPro Proposal System
"""
import os
import sys
from sqlalchemy import text
from database_config import create_database_engine, create_tables

def setup_database():
    """Set up the database with schema and sample data"""
    print("🗄️  Setting up KhonoPro Proposal System Database...")
    
    try:
        # Create tables
        print("📋 Creating database tables...")
        engine = create_tables()
        print("✅ Database tables created successfully!")
        
        # Test connection
        print("🔗 Testing database connection...")
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version()"))
            version = result.fetchone()[0]
            print(f"✅ Connected to: {version}")
        
        # Insert sample data
        print("📊 Inserting sample data...")
        with engine.connect() as conn:
            # Insert sample clients
            conn.execute(text("""
                INSERT INTO clients (name, email, organization, role) VALUES 
                ('Jane Doe', 'jane.doe@example.com', 'Acme Corp', 'Client'),
                ('John Smith', 'john.smith@techcorp.com', 'Tech Corp', 'Client'),
                ('Admin User', 'admin@khonology.com', 'Khonology', 'Admin')
                ON CONFLICT (email) DO NOTHING;
            """))
            
            # Insert sample proposals
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
        print("\n📋 Next steps:")
        print("1. Start the backend: python -m uvicorn app:app --host 127.0.0.1 --port 8000")
        print("2. Start the Flutter app: cd frontend_flutter && flutter run -d chrome --web-port 3000")
        print("3. Access PgAdmin at: http://localhost:5050 (admin@khonology.com / admin123)")
        
    except Exception as e:
        print(f"❌ Error setting up database: {e}")
        sys.exit(1)

if __name__ == "__main__":
    setup_database()
