"""
Fix the proposals_status_check constraint to allow all needed status values
"""
import psycopg2
from api.utils.database import get_db_connection
import os
from dotenv import load_dotenv

load_dotenv()

def fix_status_constraint():
    """Update the proposals_status_check constraint to allow all status values"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Drop the old constraint if it exists
            cursor.execute("""
                ALTER TABLE proposals 
                DROP CONSTRAINT IF EXISTS proposals_status_check;
            """)
            
            # Add new constraint with all allowed status values
            cursor.execute("""
                ALTER TABLE proposals 
                ADD CONSTRAINT proposals_status_check 
                CHECK (status IN (
                    'draft',
                    'Draft',
                    'submitted',
                    'Submitted',
                    'approved',
                    'Approved',
                    'rejected',
                    'Rejected',
                    'archived',
                    'Archived',
                    'Pending CEO Approval',
                    'Sent to Client',
                    'Sent for Signature',
                    'In Review',
                    'Signed',
                    'signed',
                    'Client Signed',
                    'Client Approved',
                    'Client Declined'
                ) OR status IS NULL);
            """)
            
            conn.commit()
            print("✅ Status constraint updated successfully")
            
            # Verify the constraint
            cursor.execute("""
                SELECT conname, pg_get_constraintdef(oid)
                FROM pg_constraint
                WHERE conrelid = 'proposals'::regclass 
                AND contype = 'c' 
                AND conname LIKE '%status%'
            """)
            result = cursor.fetchone()
            if result:
                print(f"✅ Constraint verified: {result[0]}")
                print(f"   Definition: {result[1]}")
            
    except Exception as e:
        print(f"❌ Error fixing constraint: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    fix_status_constraint()

