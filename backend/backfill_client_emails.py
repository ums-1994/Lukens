"""
Backfill client_email for proposals that have collaboration_invitations
but empty or null client_email fields.

This fixes proposals that were sent to clients before the fix that updates
client_email when sending proposals.
"""
import os
import sys
from api.utils.database import get_db_connection

def backfill_client_emails():
    """Update client_email for proposals using their collaboration_invitations"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Find proposals with empty/null client_email but have collaboration_invitations
            cursor.execute("""
                UPDATE proposals p
                SET client_email = ci.invited_email,
                    updated_at = NOW()
                FROM collaboration_invitations ci
                WHERE ci.proposal_id = p.id
                  AND (p.client_email IS NULL OR p.client_email = '')
                  AND ci.invited_email IS NOT NULL
                  AND ci.invited_email != ''
            """)
            
            updated_count = cursor.rowcount
            conn.commit()
            
            print(f"✅ Updated {updated_count} proposals with client_email from collaboration_invitations")
            
            # Also update proposals that have proposal_signatures but empty client_email
            cursor.execute("""
                UPDATE proposals p
                SET client_email = ps.signer_email,
                    updated_at = NOW()
                FROM proposal_signatures ps
                WHERE ps.proposal_id = p.id
                  AND (p.client_email IS NULL OR p.client_email = '')
                  AND ps.signer_email IS NOT NULL
                  AND ps.signer_email != ''
                  AND NOT EXISTS (
                      SELECT 1 FROM collaboration_invitations ci 
                      WHERE ci.proposal_id = p.id 
                      AND ci.invited_email IS NOT NULL
                  )
            """)
            
            updated_count2 = cursor.rowcount
            conn.commit()
            
            print(f"✅ Updated {updated_count2} additional proposals with client_email from proposal_signatures")
            print(f"📊 Total updated: {updated_count + updated_count2} proposals")
            
    except Exception as e:
        print(f"❌ Error backfilling client emails: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    print("🔄 Backfilling client_email for existing proposals...")
    backfill_client_emails()
    print("✅ Backfill complete!")


