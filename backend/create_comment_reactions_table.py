#!/usr/bin/env python3
"""Create comment_reactions table if it doesn't exist. Run this if reactions don't show after adding."""
import os
import sys

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def main():
    try:
        from api.utils.database import get_db_connection
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''CREATE TABLE IF NOT EXISTS comment_reactions (
            id SERIAL PRIMARY KEY,
            comment_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            emoji VARCHAR(20) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(comment_id, user_id, emoji),
            FOREIGN KEY (comment_id) REFERENCES document_comments(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )''')
            cursor.execute('''CREATE INDEX IF NOT EXISTS idx_comment_reactions_comment 
                             ON comment_reactions(comment_id)''')
            conn.commit()
        print("[OK] comment_reactions table created successfully")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
