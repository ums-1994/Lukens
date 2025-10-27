import psycopg2
import psycopg2.extras
from contextlib import contextmanager
import os
from dotenv import load_dotenv

load_dotenv()

@contextmanager
def get_db_connection():
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        port=os.getenv('DB_PORT', '5432'),
        database=os.getenv('DB_NAME', 'proposal_sow_builder'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD', '')
    )
    try:
        yield conn
    finally:
        conn.close()

def fix_comments_table():
    """Check if document_comments table exists and has correct schema"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Check if table exists
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'document_comments'
            )
        """)
        table_exists = cursor.fetchone()[0]
        
        print(f"Table exists: {table_exists}")
        
        if table_exists:
            # Check columns
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='document_comments' 
                ORDER BY ordinal_position
            """)
            columns = [row[0] for row in cursor.fetchall()]
            print(f"Existing columns: {columns}")
            
            # Drop and recreate if schema is wrong
            if 'section_index' not in columns:
                print("⚠️ Schema is outdated, recreating table...")
                cursor.execute('DROP TABLE IF EXISTS document_comments CASCADE')
                conn.commit()
                table_exists = False
        
        if not table_exists:
            print("Creating document_comments table...")
            cursor.execute('''CREATE TABLE document_comments (
                id SERIAL PRIMARY KEY,
                proposal_id INTEGER NOT NULL,
                comment_text TEXT NOT NULL,
                created_by INTEGER NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                section_index INTEGER,
                highlighted_text TEXT,
                status VARCHAR(50) DEFAULT 'open',
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                resolved_by INTEGER,
                resolved_at TIMESTAMP,
                FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
                FOREIGN KEY (created_by) REFERENCES users(id),
                FOREIGN KEY (resolved_by) REFERENCES users(id)
            )''')
            conn.commit()
            print("✅ Table created successfully!")
        else:
            print("✅ Table schema is correct!")

if __name__ == '__main__':
    fix_comments_table()

