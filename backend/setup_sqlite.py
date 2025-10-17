#!/usr/bin/env python3
"""
SQLite setup script for KhonoPro Proposal System (Development)
"""
import os
import sys
from sqlalchemy import create_engine, text
from database_config import create_database_engine, create_tables

def setup_sqlite():
    """Set up SQLite database for development"""
    print("🗄️  Setting up KhonoPro Proposal System with SQLite...")
    
    # Set environment to use SQLite
    os.environ["USE_SQLITE"] = "true"
    
    try:
        # Create tables
        print("📋 Creating SQLite database and tables...")
        engine = create_tables()
        print("✅ SQLite database created successfully!")
        
        # Test connection
        print("🔗 Testing database connection...")
        with engine.connect() as conn:
            result = conn.execute(text("SELECT sqlite_version()"))
            version = result.fetchone()[0]
            print(f"✅ Connected to SQLite: {version}")
        
        # Insert sample data
        print("📊 Inserting sample data...")
        with engine.connect() as conn:
            # Insert sample clients
            conn.execute(text("""
                INSERT OR IGNORE INTO clients (id, name, email, organization, role) VALUES 
                ('550e8400-e29b-41d4-a716-446655440001', 'Jane Doe', 'jane.doe@example.com', 'Acme Corp', 'Client'),
                ('550e8400-e29b-41d4-a716-446655440002', 'John Smith', 'john.smith@techcorp.com', 'Tech Corp', 'Client'),
                ('550e8400-e29b-41d4-a716-446655440003', 'Admin User', 'admin@khonology.com', 'Khonology', 'Admin');
            """))
            
            # Insert sample proposals
            conn.execute(text("""
                INSERT OR IGNORE INTO proposals (id, title, content, status, client_id) VALUES 
                ('650e8400-e29b-41d4-a716-446655440001', 'Acme Financial Proposal', 
                 'Comprehensive financial analysis and recommendations for Acme Corp', 'Released', 
                 '550e8400-e29b-41d4-a716-446655440001'),
                ('650e8400-e29b-41d4-a716-446655440002', 'Tech Corp Digital Transformation', 
                 'Digital transformation strategy for Tech Corp', 'In Review',
                 '550e8400-e29b-41d4-a716-446655440002');
            """))
            
            # Insert sample dashboard token
            conn.execute(text("""
                INSERT OR IGNORE INTO client_dashboard_tokens (id, token, client_id, proposal_id, expires_at) VALUES 
                ('750e8400-e29b-41d4-a716-446655440001', 
                 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJwcm9wb3NhbF9pZCI6IjY1MGU4NDAwLWUyOWItNDFkNC1hNzE2LTQ0NjY1NTQ0MDAwMSIsImNsaWVudF9lbWFpbCI6ImphbmUuZG9lQGV4YW1wbGUuY29tIiwicHJvcG9zYWxfZGF0YSI6eyJ0aXRsZSI6IkFjbWUgRmluYW5jaWFsIFByb3Bvc2FsIn0sImV4cCI6MTc2MjM2MzI0Mn0.test_token_for_development',
                 '550e8400-e29b-41d4-a716-446655440001',
                 '650e8400-e29b-41d4-a716-446655440001',
                 datetime('now', '+30 days'));
            """))
            
            conn.commit()
            print("✅ Sample data inserted successfully!")
        
        print("\n🎉 SQLite setup completed successfully!")
        print(f"📁 Database file: {os.path.abspath('khonopro_client.db')}")
        print("\n📋 Next steps:")
        print("1. Start the backend: python -m uvicorn app:app --host 127.0.0.1 --port 8000")
        print("2. Start the Flutter app: cd frontend_flutter && flutter run -d chrome --web-port 3000")
        print("3. Test client dashboard with token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
        
    except Exception as e:
        print(f"❌ Error setting up SQLite: {e}")
        sys.exit(1)

if __name__ == "__main__":
    setup_sqlite()
