"""
Create proposal_client_activity and proposal_client_session tables
These tables use integer IDs to match the existing proposals table structure
"""
import psycopg2
from api.utils.database import get_db_connection
import os
from dotenv import load_dotenv

load_dotenv()

def create_activity_tables():
    """Create the activity tracking tables with integer IDs"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Create proposal_client_activity table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS proposal_client_activity (
                    id SERIAL PRIMARY KEY,
                    proposal_id INTEGER NOT NULL,
                    client_id INTEGER,
                    event_type VARCHAR(50) NOT NULL,
                    metadata JSONB,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
                    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL
                )
            """)
            
            # Create proposal_client_session table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS proposal_client_session (
                    id SERIAL PRIMARY KEY,
                    proposal_id INTEGER NOT NULL,
                    client_id INTEGER,
                    session_start TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    session_end TIMESTAMP,
                    total_seconds INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
                    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL
                )
            """)
            
            # Create indexes for activity tracking
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_activity_proposal_id 
                ON proposal_client_activity(proposal_id)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_activity_client_id 
                ON proposal_client_activity(client_id)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_activity_event_type 
                ON proposal_client_activity(event_type)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_activity_created_at 
                ON proposal_client_activity(created_at)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_session_proposal_id 
                ON proposal_client_session(proposal_id)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_session_client_id 
                ON proposal_client_session(client_id)
            """)
            
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_session_start 
                ON proposal_client_session(session_start)
            """)
            
            conn.commit()
            print("✅ Activity tracking tables created successfully")
            
            # Verify tables exist
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name IN ('proposal_client_activity', 'proposal_client_session')
            """)
            tables = cursor.fetchall()
            print(f"✅ Verified tables exist: {[t[0] for t in tables]}")
            
    except Exception as e:
        print(f"❌ Error creating activity tables: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    create_activity_tables()

