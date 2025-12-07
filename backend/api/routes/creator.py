"""
Creator role routes - Content management, proposal CRUD, AI features, uploads
"""
from flask import Blueprint, request, jsonify
import os
import traceback
import cloudinary
import cloudinary.uploader
import psycopg2.extras
from datetime import datetime

from api.utils.database import get_db_connection
from api.utils.decorators import token_required

bp = Blueprint('creator', __name__, url_prefix='')

# ============================================================================
# CONTENT LIBRARY ROUTES
# ============================================================================

@bp.get("/content")
@token_required
def get_content(username=None):
    """Get all content items"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''SELECT id, key, label, content, category, is_folder, parent_id, public_id
                           FROM content WHERE is_deleted = false ORDER BY created_at DESC''')
            rows = cursor.fetchall()
            content = []
            for row in rows:
                content.append({
                    'id': row[0],
                    'key': row[1],
                    'label': row[2],
                    'content': row[3],
                    'category': row[4],
                    'is_folder': row[5],
                    'parent_id': row[6],
                    'public_id': row[7]
                })
            return {'content': content}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/content")
@token_required
def create_content(username=None):
    """Create a new content item"""
    try:
        data = request.get_json()
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''INSERT INTO content (key, label, content, category, is_folder, parent_id, public_id)
                   VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id''',
                (data['key'], data['label'], data.get('content', ''), 
                 data.get('category', 'Templates'), data.get('is_folder', False),
                 data.get('parent_id'), data.get('public_id'))
            )
            content_id = cursor.fetchone()[0]
            conn.commit()
            return {'id': content_id, 'detail': 'Content created'}, 201
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.put("/content/<int:content_id>")
@token_required
def update_content(username=None, content_id=None):
    """Update a content item"""
    try:
        data = request.get_json()
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            updates = []
            params = []
            if 'label' in data:
                updates.append('label = %s')
                params.append(data['label'])
            if 'content' in data:
                updates.append('content = %s')
                params.append(data['content'])
            if 'category' in data:
                updates.append('category = %s')
                params.append(data['category'])
            if 'public_id' in data:
                updates.append('public_id = %s')
                params.append(data['public_id'])
            
            if not updates:
                return {'detail': 'No updates provided'}, 400
            
            params.append(content_id)
            cursor.execute(f'''UPDATE content SET {', '.join(updates)} WHERE id = %s''', params)
            conn.commit()
            return {'detail': 'Content updated'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.delete("/content/<int:content_id>")
@token_required
def delete_content(username=None, content_id=None):
    """Delete a content item (soft delete)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('UPDATE content SET is_deleted = true WHERE id = %s', (content_id,))
            conn.commit()
            return {'detail': 'Content deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/content/<int:content_id>/restore")
@token_required
def restore_content(username=None, content_id=None):
    """Restore a deleted content item"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('UPDATE content SET is_deleted = false WHERE id = %s', (content_id,))
            conn.commit()
            return {'detail': 'Content restored'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.delete("/content/<int:content_id>/permanent")
@token_required
def permanently_delete_content(username=None, content_id=None):
    """Permanently delete a content item"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM content WHERE id = %s', (content_id,))
            conn.commit()
            return {'detail': 'Content permanently deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/content/trash")
@token_required
def get_trash(username=None):
    """Get all deleted content items"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('''SELECT id, key, label, content, category, is_folder, parent_id, public_id
                           FROM content WHERE is_deleted = true ORDER BY created_at DESC''')
            rows = cursor.fetchall()
            trash = []
            for row in rows:
                trash.append({
                    'id': row[0],
                    'key': row[1],
                    'label': row[2],
                    'content': row[3],
                    'category': row[4],
                    'is_folder': row[5],
                    'parent_id': row[6],
                    'public_id': row[7]
                })
            return trash, 200
    except Exception as e:
        return {'detail': str(e)}, 500

# ============================================================================
# PROPOSAL ROUTES (CREATOR)
# ============================================================================

@bp.get("/proposals")
@token_required
def get_proposals(username=None, user_id=None, email=None):
    """Get all proposals for the creator"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            print(f"🔍 Looking for proposals for user {username} (user_id: {user_id}, email: {email})")
            
            # Use the same simple lookup pattern as the user profile endpoint (which works)
            # Try email first (most reliable since it's unique and comes from Firebase)
            found_user_id = None
            if email:
                print(f"🔍 Looking up user by email: {email}")
                cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
                user_row = cursor.fetchone()
                if user_row:
                    found_user_id = user_row[0]
                    print(f"✅ Found user_id {found_user_id} by email: {email}")
            
            # If email lookup failed, try username (same as user profile endpoint)
            if not found_user_id and username:
                print(f"🔍 Looking up user by username: {username}")
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    found_user_id = user_row[0]
                    print(f"✅ Found user_id {found_user_id} by username: {username}")
            
            # Use the found user_id
            user_id = found_user_id
            
            if not user_id:
                print(f"❌ User lookup failed for username: {username}, email: {email}")
                return {'detail': 'User not found'}, 404
            
            print(f"✅ Using user_id: {user_id} for proposals query")
            
            cursor.execute(
                '''SELECT id, owner_id, title, content, status, client, 
                          created_at, updated_at
                   FROM proposals WHERE owner_id = %s
                   ORDER BY created_at DESC''',
                (user_id,)
            )
            rows = cursor.fetchall()
            proposals = []
            for row in rows:
                # Handle NULL status - default to 'draft' (lowercase to match constraint)
                status = row[4] if row[4] is not None else 'draft'
                proposals.append({
                    'id': row[0],
                    'user_id': row[1],  # Keep for backward compatibility
                    'owner_id': row[1],
                    'title': row[2],
                    'content': row[3],
                    'status': status,
                    'client_name': row[5] if row[5] else 'Unknown Client',  # Map client to client_name for compatibility
                    'client': row[5] if row[5] else 'Unknown Client',
                    'client_email': '',  # Not in schema, return empty string
                    'budget': None,  # Not in schema
                    'timeline_days': None,  # Not in schema
                    'created_at': row[6].isoformat() if row[6] else None,
                    'updated_at': row[7].isoformat() if row[7] else None,
                    'updatedAt': row[7].isoformat() if row[7] else None,
                })
            print(f"✅ Found {len(proposals)} proposals for user {username} (user_id: {user_id})")
            # Return list directly (Flask will JSON-encode it)
            return jsonify(proposals), 200
    except Exception as e:
        print(f"❌ Error getting proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/proposals")
@token_required
def create_proposal(username=None, user_id=None, email=None):
    """Create a new proposal"""
    try:
        data = request.get_json()
        print(f"📝 Creating proposal for user {username} (user_id: {user_id}, email: {email}): {data.get('title', 'Untitled')}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            client = data.get('client_name') or data.get('client') or 'Unknown Client'
            
            # Normalize status - use lowercase to match database constraint
            raw_status = data.get('status', 'draft')
            normalized_status = 'draft'  # Default - lowercase to match constraint
            if raw_status:
                status_lower = str(raw_status).lower().strip()
                if status_lower == 'draft':
                    normalized_status = 'draft'
                elif 'pending' in status_lower and 'ceo' in status_lower:
                    normalized_status = 'Pending CEO Approval'
                elif 'sent' in status_lower and 'client' in status_lower:
                    normalized_status = 'Sent to Client'
                elif status_lower in ['signed', 'approved']:
                    normalized_status = 'signed'
                elif 'review' in status_lower:
                    normalized_status = 'In Review'
                else:
                    # Keep as lowercase for basic statuses, or use exact value if it's a special status
                    normalized_status = status_lower
            
            # Use the same simple lookup pattern as the user profile endpoint (which works)
            # Try email first (most reliable since it's unique and comes from Firebase)
            found_user_id = None
            if email:
                print(f"🔍 Looking up user by email: {email}")
                cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
                user_row = cursor.fetchone()
                if user_row:
                    found_user_id = user_row[0]
                    print(f"✅ Found user_id {found_user_id} by email: {email}")
            
            # If email lookup failed, try username (same as user profile endpoint)
            if not found_user_id and username:
                print(f"🔍 Looking up user by username: {username}")
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    found_user_id = user_row[0]
                    print(f"✅ Found user_id {found_user_id} by username: {username}")
            
            # Use the found user_id
            user_id = found_user_id
            
            if not user_id:
                print(f"❌ User lookup failed for username: {username}, email: {email}")
                return {'detail': 'User not found'}, 404
            
            print(f"✅ Using user_id: {user_id} for proposal creation")
            
            # Final verification before inserting proposal
            cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
            final_check = cursor.fetchone()
            if not final_check:
                print(f"❌ CRITICAL: user_id {user_id} doesn't exist right before proposal insert!")
                return {'detail': f'User with ID {user_id} not found in database'}, 404
            
            cursor.execute(
                '''INSERT INTO proposals (owner_id, title, content, status, client)
                   VALUES (%s, %s, %s, %s, %s) 
                   RETURNING id, owner_id, title, content, status, client, created_at, updated_at''',
                (
                    user_id,
                    data.get('title', 'Untitled Document'),
                    data.get('content'),
                    normalized_status,
                    client
                )
            )
            result = cursor.fetchone()
            conn.commit()
            
            proposal = {
                'id': result[0],
                'user_id': result[1],
                'owner_id': result[1],
                'title': result[2],
                'content': result[3],
                'status': result[4],
                'client_name': result[5] if result[5] else 'Unknown Client',  # Map client to client_name for compatibility
                'client': result[5] if result[5] else 'Unknown Client',
                'client_email': '',  # Not in schema
                'budget': None,  # Not in schema
                'timeline_days': None,  # Not in schema
                'created_at': result[6].isoformat() if result[6] else None,
                'updated_at': result[7].isoformat() if result[7] else None,
            }
            
            print(f"✅ Proposal created: {proposal['id']}")
            return proposal, 201
    except Exception as e:
        print(f"❌ Error creating proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.put("/proposals/<int:proposal_id>")
@token_required
def update_proposal(username=None, proposal_id=None):
    """Update a proposal"""
    try:
        data = request.get_json()
        print(f"📝 Updating proposal {proposal_id} for user {username}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID from username (try multiple times in case user was just created)
            user_row = None
            for attempt in range(3):
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    break
                # If user not found and this is the first attempt, wait a bit (user might have just been created)
                if attempt == 0:
                    import time
                    time.sleep(0.1)  # Small delay to allow transaction to commit
            
            if not user_row:
                print(f"❌ User lookup failed after 3 attempts for username: {username}")
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            # Verify ownership
            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            if proposal[0] != user_id:
                return {'detail': 'Access denied'}, 403
            
            # Build update query
            updates = []
            params = []
            
            if 'title' in data:
                updates.append('title = %s')
                params.append(data['title'])
            if 'content' in data:
                updates.append('content = %s')
                params.append(data['content'])
            if 'status' in data:
                updates.append('status = %s')
                params.append(data['status'])
            if 'client_name' in data or 'client' in data:
                client_name = data.get('client_name') or data.get('client')
                updates.append('client_name = %s')
                params.append(client_name)
            if 'client_email' in data:
                updates.append('client_email = %s')
                params.append(data['client_email'])
            if 'budget' in data:
                updates.append('budget = %s')
                params.append(data['budget'])
            if 'timeline_days' in data:
                updates.append('timeline_days = %s')
                params.append(data['timeline_days'])
            
            if not updates:
                return {'detail': 'No updates provided'}, 400
            
            updates.append('updated_at = CURRENT_TIMESTAMP')
            params.append(proposal_id)
            
            cursor.execute(
                f'''UPDATE proposals SET {', '.join(updates)} WHERE id = %s
                   RETURNING id, user_id, title, content, status, client_name, client_email, budget, timeline_days, created_at, updated_at''',
                params
            )
            result = cursor.fetchone()
            conn.commit()
            
            proposal = {
                'id': result[0],
                'user_id': result[1],
                'owner_id': result[1],
                'title': result[2],
                'content': result[3],
                'status': result[4],
                'client_name': result[5],
                'client': result[5],
                'client_email': result[6],
                'budget': float(result[7]) if result[7] else None,
                'timeline_days': result[8],
                'created_at': result[9].isoformat() if result[9] else None,
                'updated_at': result[10].isoformat() if result[10] else None,
            }
            
            print(f"✅ Proposal updated: {proposal_id}")
            return proposal, 200
    except Exception as e:
        print(f"❌ Error updating proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.delete("/proposals/<int:proposal_id>")
@token_required
def delete_proposal(username=None, proposal_id=None):
    """Delete a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID from username (try multiple times in case user was just created)
            user_row = None
            for attempt in range(3):
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    break
                # If user not found and this is the first attempt, wait a bit (user might have just been created)
                if attempt == 0:
                    import time
                    time.sleep(0.1)  # Small delay to allow transaction to commit
            
            if not user_row:
                print(f"❌ User lookup failed after 3 attempts for username: {username}")
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            # Verify ownership
            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            if proposal[0] != user_id:
                return {'detail': 'Access denied'}, 403
            
            cursor.execute('DELETE FROM proposals WHERE id = %s', (proposal_id,))
            conn.commit()
            return {'detail': 'Proposal deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/proposals/<int:proposal_id>")
@token_required
def get_proposal(username=None, proposal_id=None):
    """Get a single proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, owner_id, title, content, status, client_name, client_email, 
                          budget, timeline_days, created_at, updated_at
                   FROM proposals WHERE id = %s''',
                (proposal_id,)
            )
            result = cursor.fetchone()
            if result:
                return {
                    'id': result[0],
                    'user_id': result[1],
                    'owner_id': result[1],
                    'title': result[2],
                    'content': result[3],
                    'status': result[4],
                    'client_name': result[5],
                    'client': result[5],
                    'client_email': result[6],
                    'budget': float(result[7]) if result[7] else None,
                    'timeline_days': result[8],
                    'created_at': result[9].isoformat() if result[9] else None,
                    'updated_at': result[10].isoformat() if result[10] else None,
                }, 200
            return {'detail': 'Proposal not found'}, 404
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.get("/proposals/my_proposals")
@token_required
def get_my_proposals(username=None):
    """Get all proposals created by the user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at
                   FROM proposals WHERE owner_id = (SELECT id FROM users WHERE username = %s)
                   ORDER BY created_at DESC''',
                (username,)
            )
            rows = cursor.fetchall()
            proposals = []
            for row in rows:
                proposals.append({
                    'id': row[0],
                    'title': row[1],
                    'client': row[2],
                    'owner_id': row[3],
                    'status': row[4],
                    'created_at': row[5].isoformat() if row[5] else None
                })
            return {'proposals': proposals}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/submit")
@token_required
def submit_for_review(username=None, proposal_id=None):
    """Submit proposal for review"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]

            cursor.execute('SELECT id FROM proposals WHERE id = %s AND owner_id = %s', (proposal_id, user_id))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            cursor.execute(
                '''UPDATE proposals SET status = 'Submitted', updated_at = CURRENT_TIMESTAMP WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()
            return {'detail': 'Proposal submitted for review'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/send-for-approval")
@bp.post("/api/proposals/<int:proposal_id>/send-for-approval")
@token_required
def send_for_approval(username=None, proposal_id=None):
    """Send proposal for approval"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Get user ID from username (try multiple times in case user was just created)
            user_row = None
            for attempt in range(3):
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    break
                # If user not found and this is the first attempt, wait a bit (user might have just been created)
                if attempt == 0:
                    import time
                    time.sleep(0.1)  # Small delay to allow transaction to commit
            
            if not user_row:
                print(f"❌ User lookup failed after 3 attempts for username: {username}")
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            # Check if proposal exists and belongs to user
            cursor.execute('SELECT id FROM proposals WHERE id = %s AND owner_id = %s', (proposal_id, user_id))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found or access denied'}, 404
            
            # Update status to "Pending CEO Approval" (more descriptive than "In Review")
            cursor.execute(
                '''UPDATE proposals SET status = 'Pending CEO Approval', updated_at = CURRENT_TIMESTAMP WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()
            return {'detail': 'Proposal sent for approval', 'status': 'Pending CEO Approval'}, 200
    except Exception as e:
        print(f"❌ Error sending proposal for approval: {e}")
        import traceback
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/proposals/<int:proposal_id>/send_to_client")
@token_required
def send_to_client(username=None, proposal_id=None):
    """Send proposal to client"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute(
                """
                SELECT id, title, client_name, client_email, user_id
                FROM proposals
                WHERE id = %s
                """,
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            # Run compound risk gate check
            risk_result = evaluate_compound_risk(dict(proposal))
            if risk_result.get('blocked'):
                return {
                    'detail': 'Proposal blocked by risk gate',
                    'risk_score': risk_result.get('score'),
                    'flags': risk_result.get('flags', []),
                    'message': 'This proposal has too many risk factors. Please address the issues before sending to client.'
                }, 400                
            
            cursor.execute(
                "SELECT id, full_name, username, email FROM users WHERE username = %s",
                (username,),
            )
            sender = cursor.fetchone()
            
            if not sender:
                return {'detail': 'User not found'}, 404
            
            # Update status
            new_status = 'Sent to Client'
            cursor.execute(
                """UPDATE proposals SET status = %s, updated_at = CURRENT_TIMESTAMP WHERE id = %s""",
                (new_status, proposal_id)
            )
            conn.commit()
            
            # Send email to client
            email_sent = False
            client_email = proposal.get('client_email')
            client_name = proposal.get('client_name', 'Client')
            proposal_title = proposal.get('title', 'Proposal')
            
            if client_email and client_email.strip():
                try:
                    from api.utils.email import send_email, get_logo_html
                    import secrets
                    
                    frontend_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                    access_token = secrets.token_urlsafe(32)
                    
                    # Store token in collaboration_invitations for client access
                    sender_id = sender.get('id')
                    cursor.execute("""
                        INSERT INTO collaboration_invitations 
                        (proposal_id, invited_email, invited_by, permission_level, access_token, status)
                        VALUES (%s, %s, %s, %s, %s, 'pending')
                        ON CONFLICT DO NOTHING
                    """, (proposal_id, client_email, sender_id, 'view', access_token))
                    conn.commit()
                    
                    client_link = f"{frontend_url}/client/proposals?token={access_token}"
                    
                    sender_name = sender.get('full_name') or sender.get('username') or 'Your Team'
                    
                    email_subject = f"Proposal: {proposal_title}"
                    email_body = f"""
                    {get_logo_html()}
                    <h2>Your Proposal is Ready</h2>
                    <p>Dear {client_name},</p>
                    <p>We're pleased to share your proposal: <strong>{proposal_title}</strong></p>
                    <p>Click the link below to view and review your proposal:</p>
                    <p style="text-align: center; margin: 30px 0;">
                        <a href="{client_link}" style="background-color: #27AE60; color: white; padding: 14px 32px; text-decoration: none; border-radius: 8px; display: inline-block; font-size: 16px; font-weight: 600;">View Proposal</a>
                    </p>
                    <p>Or copy and paste this link into your browser:</p>
                    <p style="word-break: break-all; color: #666;">{client_link}</p>
                    <p>If you have any questions, please don't hesitate to reach out.</p>
                    <p>Best regards,<br>{sender_name}</p>
                    """
                    
                    email_sent = send_email(client_email, email_subject, email_body)
                    if email_sent:
                        print(f"[EMAIL] Proposal email sent to {client_email}")
                    else:
                        print(f"[EMAIL] Failed to send proposal email to {client_email}")
                except Exception as email_error:
                    print(f"[EMAIL] Error sending proposal email: {email_error}")
                    traceback.print_exc()
            
            return {
                'detail': 'Proposal sent to client',
                'status': new_status,
                'email_sent': email_sent
            }, 200
    except Exception as e:
        print(f"❌ Error sending proposal to client: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# ============================================================================
# UPLOAD ROUTES
# ============================================================================

@bp.post("/upload/image")
@token_required
def upload_image(username=None):
    """Upload an image to Cloudinary"""
    try:
        if 'file' not in request.files:
            return {'detail': 'No file provided'}, 400
        
        file = request.files['file']
        result = cloudinary.uploader.upload(file)
        return result, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/upload/template")
@token_required
def upload_template(username=None):
    """Upload a template to Cloudinary"""
    try:
        if 'file' not in request.files:
            return {'detail': 'No file provided'}, 400
        
        file = request.files['file']
        result = cloudinary.uploader.upload(file)
        return result, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.delete("/upload/<public_id>")
@token_required
def delete_from_cloudinary(username=None, public_id=None):
    """Delete a file from Cloudinary"""
    try:
        cloudinary.uploader.destroy(public_id)
        return {'detail': 'File deleted'}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

@bp.post("/upload/signature")
@token_required
def get_upload_signature(username=None):
    """Get upload signature for Cloudinary"""
    try:
        data = request.get_json()
        public_id = data.get('public_id')
        
        # This would normally generate a real Cloudinary signature
        signature = "dummy_signature"
        return {'signature': signature, 'public_id': public_id}, 200
    except Exception as e:
        return {'detail': str(e)}, 500

# ============================================================================
# VERSION MANAGEMENT ROUTES
# ============================================================================

@bp.post("/api/proposals/<int:proposal_id>/versions")
@token_required
def create_version(username=None, proposal_id=None):
    """Create a new version of a proposal"""
    try:
        data = request.get_json()
        print(f"📝 Creating version {data.get('version_number')} for proposal {proposal_id}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Get user ID from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            user_id = user_row[0] if user_row else None
            
            cursor.execute(
                '''INSERT INTO proposal_versions 
                   (proposal_id, version_number, content, created_by, change_description)
                   VALUES (%s, %s, %s, %s, %s)
                   RETURNING id, proposal_id, version_number, content, created_by, created_at, change_description''',
                (
                    proposal_id,
                    data.get('version_number', 1),
                    data.get('content', ''),
                    user_id,
                    data.get('change_description', 'Version created')
                )
            )
            result = cursor.fetchone()
            conn.commit()
            
            version = {
                'id': result[0],
                'proposal_id': result[1],
                'version_number': result[2],
                'content': result[3],
                'created_by': result[4],
                'created_at': result[5].isoformat() if result[5] else None,
                'change_description': result[6]
            }
            
            print(f"✅ Version {result[2]} created for proposal {proposal_id}")
            return version, 201
    except Exception as e:
        print(f"❌ Error creating version: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/proposals/<int:proposal_id>/versions")
@token_required
def get_versions(username=None, proposal_id=None):
    """Get all versions of a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, proposal_id, version_number, content, created_by, created_at, change_description
                   FROM proposal_versions
                   WHERE proposal_id = %s
                   ORDER BY version_number DESC''',
                (proposal_id,)
            )
            rows = cursor.fetchall()
            
            versions = []
            for row in rows:
                versions.append({
                    'id': row[0],
                    'proposal_id': row[1],
                    'version_number': row[2],
                    'content': row[3],
                    'created_by': row[4],
                    'created_at': row[5].isoformat() if row[5] else None,
                    'change_description': row[6]
                })
            
            print(f"✅ Found {len(versions)} versions for proposal {proposal_id}")
            return versions, 200
    except Exception as e:
        print(f"❌ Error getting versions: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/proposals/<int:proposal_id>/versions/<int:version_number>")
@token_required
def get_version(username=None, proposal_id=None, version_number=None):
    """Get a specific version of a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                '''SELECT id, proposal_id, version_number, content, created_by, created_at, change_description
                   FROM proposal_versions
                   WHERE proposal_id = %s AND version_number = %s''',
                (proposal_id, version_number)
            )
            row = cursor.fetchone()
            
            if not row:
                return {'detail': 'Version not found'}, 404
            
            version = {
                'id': row[0],
                'proposal_id': row[1],
                'version_number': row[2],
                'content': row[3],
                'created_by': row[4],
                'created_at': row[5].isoformat() if row[5] else None,
                'change_description': row[6]
            }
            
            return version, 200
    except Exception as e:
        print(f"❌ Error getting version: {e}")
        return {'detail': str(e)}, 500

# ============================================================================
# AI ROUTES
# ============================================================================

@bp.post("/ai/generate")
@token_required
def ai_generate_content(username=None):
    """Generate proposal content using AI"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        prompt = data.get('prompt', '')
        context = data.get('context', {})
        section_type = data.get('section_type', 'general')
        
        if not prompt:
            return {'detail': 'Prompt is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Create enhanced prompt with context
        full_context = {
            'user_request': prompt,
            'section_type': section_type,
            **context
        }
        
        # Generate content
        generated_content = ai_service.generate_proposal_section(section_type, full_context)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, prompt_text, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'generate', prompt[:500], section_type, 
                      len(generated_content.split()), response_time_ms))
                conn.commit()
                print(f"📊 AI usage tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return {
            'content': generated_content,
            'section_type': section_type
        }, 200
        
    except Exception as e:
        print(f"❌ Error generating AI content: {e}")
        return {'detail': str(e)}, 500

@bp.post("/ai/improve")
@token_required
def ai_improve_content(username=None):
    """Improve existing content using AI"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        content = data.get('content', '')
        section_type = data.get('section_type', 'general')
        
        if not content:
            return {'detail': 'Content is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Get improvement suggestions
        result = ai_service.improve_content(content, section_type)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'improve', section_type, 
                      len(result.get('improved_version', '').split()), response_time_ms))
                conn.commit()
                print(f"📊 AI improve tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return result, 200
        
    except Exception as e:
        print(f"❌ Error improving content: {e}")
        return {'detail': str(e)}, 500

@bp.post("/ai/generate-full-proposal")
@token_required
def ai_generate_full_proposal(username=None):
    """Generate a complete multi-section proposal"""
    import time
    start_time = time.time()
    
    try:
        data = request.get_json()
        prompt = data.get('prompt', '')
        context = data.get('context', {})
        
        if not prompt:
            return {'detail': 'Prompt is required'}, 400
        
        # Import AI service
        from ai_service import ai_service
        
        # Create enhanced context
        full_context = {
            'user_request': prompt,
            'company': 'Khonology',
            **context
        }
        
        # Generate full proposal
        sections = ai_service.generate_full_proposal(full_context)
        
        # Track AI usage
        response_time_ms = int((time.time() - start_time) * 1000)
        total_tokens = sum(len(str(content).split()) for content in sections.values())
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    INSERT INTO ai_usage (username, endpoint, prompt_text, section_type, 
                                         response_tokens, response_time_ms)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (username, 'full_proposal', prompt[:500], 'full_proposal', 
                      total_tokens, response_time_ms))
                conn.commit()
                print(f"📊 AI full proposal tracked for {username}")
        except Exception as track_error:
            print(f"⚠️ Failed to track AI usage: {track_error}")
        
        return {
            'sections': sections,
            'section_count': len(sections)
        }, 200
        
    except Exception as e:
        print(f"❌ Error generating full proposal: {e}")
        return {'detail': str(e)}, 500

@bp.post("/ai/analyze-risks")
@token_required
def ai_analyze_risks(username=None):
    """Analyze proposal for risks"""
    try:
        data = request.get_json()
        proposal_id = data.get('proposal_id')
        
        if not proposal_id:
            return {'detail': 'Proposal ID is required'}, 400
        
        # Get proposal data
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(
                "SELECT * FROM proposals WHERE id = %s",
                (proposal_id,)
            )
            proposal = cursor.fetchone()
            
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Import AI service
            from ai_service import ai_service
            
            # Analyze risks
            risk_analysis = ai_service.analyze_proposal_risks(dict(proposal))
            
            return risk_analysis, 200
        
    except Exception as e:
        print(f"❌ Error analyzing risks: {e}")
        return {'detail': str(e)}, 500

@bp.get("/ai/analytics/summary")
@token_required
def get_ai_analytics_summary(username=None):
    """Get AI usage analytics summary"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Overall stats
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_requests,
                    COUNT(DISTINCT username) as unique_users,
                    AVG(response_time_ms) as avg_response_time,
                    SUM(response_tokens) as total_tokens,
                    COUNT(CASE WHEN was_accepted = TRUE THEN 1 END) as accepted_count,
                    COUNT(CASE WHEN was_accepted = FALSE THEN 1 END) as rejected_count
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
            """)
            overall_stats = cursor.fetchone()
            
            # By endpoint
            cursor.execute("""
                SELECT 
                    endpoint,
                    COUNT(*) as count,
                    AVG(response_time_ms) as avg_response_time
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
                GROUP BY endpoint
                ORDER BY count DESC
            """)
            by_endpoint = cursor.fetchall()
            
            # Daily usage trend
            cursor.execute("""
                SELECT 
                    DATE(created_at) as date,
                    COUNT(*) as requests
                FROM ai_usage
                WHERE created_at >= NOW() - INTERVAL '30 days'
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                LIMIT 30
            """)
            daily_trend = cursor.fetchall()
            
            return {
                'overall': dict(overall_stats) if overall_stats else {},
                'by_endpoint': [dict(row) for row in by_endpoint],
                'daily_trend': [dict(row) for row in daily_trend]
            }, 200
            
    except Exception as e:
        print(f"❌ Error fetching AI analytics: {e}")
        return {'detail': str(e)}, 500

@bp.get("/ai/analytics/user-stats")
@token_required
def get_user_ai_stats(username=None):
    """Get current user's AI usage statistics"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_requests,
                    COUNT(DISTINCT endpoint) as endpoints_used,
                    COUNT(CASE WHEN was_accepted = TRUE THEN 1 END) as content_accepted,
                    COUNT(CASE WHEN endpoint = 'full_proposal' THEN 1 END) as full_proposals_generated,
                    AVG(response_time_ms) as avg_response_time,
                    MAX(created_at) as last_used
                FROM ai_usage
                WHERE username = %s
            """, (username,))
            
            stats = cursor.fetchone()
            
            # Recent activity
            cursor.execute("""
                SELECT 
                    endpoint,
                    section_type,
                    response_time_ms,
                    created_at
                FROM ai_usage
                WHERE username = %s
                ORDER BY created_at DESC
                LIMIT 10
            """, (username,))
            
            recent_activity = cursor.fetchall()
            
            return {
                'stats': dict(stats) if stats else {},
                'recent_activity': [dict(row) for row in recent_activity]
            }, 200
            
    except Exception as e:
        print(f"❌ Error fetching user AI stats: {e}")
        return {'detail': str(e)}, 500

@bp.get("/api/proposals/<int:proposal_id>/analytics")
@bp.get("/proposals/<int:proposal_id>/analytics")
@token_required
def get_proposal_analytics(username=None, proposal_id=None):
    """Get client activity analytics for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Verify proposal exists and user has access
            cursor.execute("""
                SELECT id, title, status, client_name, client_email
                FROM proposals 
                WHERE id = %s OR id::text = %s
            """, (proposal_id, str(proposal_id)))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            actual_proposal_id = proposal['id']
            
            # Get all activity events
            cursor.execute("""
                SELECT 
                    pca.id, pca.event_type, pca.metadata, pca.created_at,
                    c.name as client_name, c.email as client_email
                FROM proposal_client_activity pca
                LEFT JOIN clients c ON pca.client_id = c.id
                WHERE pca.proposal_id = %s
                ORDER BY pca.created_at DESC
            """, (actual_proposal_id,))
            
            events = cursor.fetchall()
            
            # Get all sessions
            cursor.execute("""
                SELECT 
                    pcs.id, pcs.session_start, pcs.session_end, pcs.total_seconds,
                    c.name as client_name, c.email as client_email
                FROM proposal_client_session pcs
                LEFT JOIN clients c ON pcs.client_id = c.id
                WHERE pcs.proposal_id = %s
                ORDER BY pcs.session_start DESC
            """, (actual_proposal_id,))
            
            sessions = cursor.fetchall()
            
            # Calculate analytics
            total_time_seconds = sum(s['total_seconds'] or 0 for s in sessions)
            views = len([e for e in events if e['event_type'] == 'open'])
            downloads = len([e for e in events if e['event_type'] == 'download'])
            signs = len([e for e in events if e['event_type'] == 'sign'])
            comments = len([e for e in events if e['event_type'] == 'comment'])
            
            # Get first and last open times
            open_events = [e for e in events if e['event_type'] == 'open']
            first_open = min([e['created_at'] for e in open_events]) if open_events else None
            last_open = max([e['created_at'] for e in open_events]) if open_events else None
            
            # Get section view times from metadata
            section_times = {}
            for event in events:
                if event['event_type'] == 'view_section' and event['metadata']:
                    metadata = event['metadata']
                    if isinstance(metadata, dict):
                        section = metadata.get('section', 'Unknown')
                        duration = metadata.get('duration', 0)
                        if section not in section_times:
                            section_times[section] = 0
                        section_times[section] += duration
            
            # Format events for response
            formatted_events = []
            for event in events:
                formatted_events.append({
                    'id': str(event['id']),
                    'event_type': event['event_type'],
                    'metadata': event['metadata'] if event['metadata'] else {},
                    'created_at': event['created_at'].isoformat() if event['created_at'] else None,
                    'client_name': event.get('client_name'),
                    'client_email': event.get('client_email')
                })
            
            # Format sessions for response
            formatted_sessions = []
            for session in sessions:
                formatted_sessions.append({
                    'id': str(session['id']),
                    'session_start': session['session_start'].isoformat() if session['session_start'] else None,
                    'session_end': session['session_end'].isoformat() if session['session_end'] else None,
                    'total_seconds': session['total_seconds'],
                    'client_name': session.get('client_name'),
                    'client_email': session.get('client_email')
                })
            
            return {
                'proposal_id': str(actual_proposal_id),
                'proposal_title': proposal['title'],
                'analytics': {
                    'total_time_seconds': total_time_seconds,
                    'total_time_formatted': _format_duration(total_time_seconds),
                    'views': views,
                    'downloads': downloads,
                    'signs': signs,
                    'comments': comments,
                    'first_open': first_open.isoformat() if first_open else None,
                    'last_open': last_open.isoformat() if last_open else None,
                    'section_times': section_times,
                    'sessions_count': len(sessions)
                },
                'events': formatted_events,
                'sessions': formatted_sessions
            }, 200
            
    except Exception as e:
        print(f"❌ Error fetching proposal analytics: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

def _format_duration(seconds):
    """Helper function to format seconds into human-readable duration"""
    if not seconds:
        return "0s"
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    if hours > 0:
        return f"{hours}h {minutes}m {secs}s"
    elif minutes > 0:
        return f"{minutes}m {secs}s"
    else:
        return f"{secs}s"

@bp.post("/ai/feedback")
@token_required
def submit_ai_feedback(username=None):
    """Submit feedback for AI-generated content"""
    try:
        data = request.get_json()
        ai_usage_id = data.get('ai_usage_id')
        rating = data.get('rating')  # 1-5
        feedback_text = data.get('feedback_text', '')
        was_edited = data.get('was_edited', False)
        
        if not ai_usage_id:
            return {'detail': 'AI usage ID is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Update ai_usage was_accepted status
            cursor.execute("""
                UPDATE ai_usage 
                SET was_accepted = TRUE 
                WHERE id = %s
            """, (ai_usage_id,))
            
            # Insert feedback
            cursor.execute("""
                INSERT INTO ai_content_feedback 
                (ai_usage_id, rating, feedback_text, was_edited)
                VALUES (%s, %s, %s, %s)
            """, (ai_usage_id, rating, feedback_text, was_edited))
            
            conn.commit()
            
            return {'message': 'Feedback submitted successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error submitting feedback: {e}")
        return {'detail': str(e)}, 500

# ============================================================================
# COLLABORATION ROUTES
# ============================================================================

@bp.get("/api/proposals/<int:proposal_id>/collaborators")
@bp.get("/proposals/<int:proposal_id>/collaborators")
@token_required
def get_proposal_collaborators(username=None, proposal_id=None):
    """Get all collaborators for a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID from username (try multiple times in case user was just created)
            user_row = None
            for attempt in range(3):
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    break
                # If user not found and this is the first attempt, wait a bit (user might have just been created)
                if attempt == 0:
                    import time
                    time.sleep(0.1)  # Small delay to allow transaction to commit
            
            if not user_row:
                print(f"❌ User lookup failed after 3 attempts for username: {username}")
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            # Verify ownership
            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            if proposal['owner_id'] != user_id:
                return {'detail': 'Access denied'}, 403
            
            # Get active collaborators from collaborators table
            cursor.execute("""
                SELECT c.id, c.proposal_id, c.email, c.email as invited_email, 
                       c.permission_level, c.status, c.joined_at, c.joined_at as invited_at,
                       c.last_accessed_at, c.last_accessed_at as accessed_at,
                       c.invited_by, u.username as invited_by_username
                FROM collaborators c
                LEFT JOIN users u ON c.invited_by = u.id
                WHERE c.proposal_id = %s
                ORDER BY c.joined_at DESC
            """, (proposal_id,))
            
            collaborators = cursor.fetchall()
            
            # Also get pending invitations
            cursor.execute("""
                SELECT id, proposal_id, invited_email, invited_email as email, 
                       permission_level, status, invited_at, invited_at as joined_at, 
                       accessed_at, accessed_at as last_accessed_at,
                       invited_by, access_token
                FROM collaboration_invitations
                WHERE proposal_id = %s AND status = 'pending'
                ORDER BY invited_at DESC
            """, (proposal_id,))
            
            pending_invitations = cursor.fetchall()
            
            # Combine active collaborators and pending invitations
            # Return both 'email' and 'invited_email' for backward compatibility
            result = [dict(collab) for collab in collaborators]
            result.extend([dict(inv) for inv in pending_invitations])
            
            return result, 200
            
    except Exception as e:
        print(f"❌ Error getting collaborators: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/proposals/<int:proposal_id>/invite")
@bp.post("/proposals/<int:proposal_id>/invite")
@token_required
def invite_collaborator(username=None, proposal_id=None):
    """Invite a collaborator to a proposal"""
    try:
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return {'detail': 'Email is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID from username (try multiple times in case user was just created)
            user_row = None
            for attempt in range(3):
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if user_row:
                    break
                # If user not found and this is the first attempt, wait a bit (user might have just been created)
                if attempt == 0:
                    import time
                    time.sleep(0.1)  # Small delay to allow transaction to commit
            
            if not user_row:
                print(f"❌ User lookup failed after 3 attempts for username: {username}")
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            # Verify ownership
            cursor.execute('SELECT owner_id, title FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            if proposal['owner_id'] != user_id:
                return {'detail': 'Access denied'}, 403
            
            # Check if invitation already exists
            cursor.execute("""
                SELECT id FROM collaboration_invitations
                WHERE proposal_id = %s AND invited_email = %s
            """, (proposal_id, email))
            existing = cursor.fetchone()
            if existing:
                return {'detail': 'Invitation already sent to this email'}, 400
            
            # Generate access token
            import secrets
            access_token = secrets.token_urlsafe(32)
            
            # Get the user ID from the users table (invited_by is required)
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            invited_by_user_id = user_row['id']
            
            # All collaborators get 'edit' permission (full access: edit, comment, suggest)
            permission_level = 'edit'
            
            # Create invitation
            cursor.execute("""
                INSERT INTO collaboration_invitations 
                (proposal_id, invited_email, invited_by, permission_level, access_token, status)
                VALUES (%s, %s, %s, %s, %s, 'pending')
                RETURNING id, proposal_id, invited_email, permission_level, 
                          status, invited_at, access_token
            """, (proposal_id, email, invited_by_user_id, permission_level, access_token))
            
            invitation = cursor.fetchone()
            conn.commit()
            
            # Send invitation email
            email_sent = False
            email_error = None
            try:
                from api.utils.email import send_email, get_logo_html
                base_url = os.getenv('FRONTEND_URL', 'http://localhost:8081')
                invite_url = f"{base_url}/collaborate?token={access_token}"
                
                email_body = f"""
                {get_logo_html()}
                <h2>You've been invited to collaborate</h2>
                <p>You've been invited to collaborate on the proposal: <strong>{proposal['title']}</strong></p>
                <p>Click the link below to access the proposal:</p>
                <p><a href="{invite_url}" style="background-color: #27AE60; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">Open Proposal</a></p>
                <p>Or copy and paste this link:</p>
                <p style="word-break: break-all; color: #666;">{invite_url}</p>
                <p>This link will give you full access to edit, comment, and suggest changes.</p>
                """
                
                send_email(
                    to_email=email,
                    subject=f"Collaboration Invitation: {proposal['title']}",
                    html_content=email_body
                )
                email_sent = True
                print(f"✅ Invitation email sent successfully to {email}")
            except Exception as e:
                email_error = str(e)
                print(f"❌ Error sending invitation email to {email}: {email_error}")
                print(f"⚠️ Email service may not be configured. Check SMTP settings.")
                traceback.print_exc()
            
            result = {
                'id': invitation['id'],
                'proposal_id': invitation['proposal_id'],
                'invited_email': invitation['invited_email'],
                'permission_level': invitation['permission_level'],
                'status': invitation['status'],
                'invited_at': invitation['invited_at'].isoformat() if invitation['invited_at'] else None,
                'access_token': invitation['access_token'],
                'email_sent': email_sent
            }
            
            # Include email error message if email failed to send
            if not email_sent and email_error:
                result['email_error'] = email_error
            
            return result, 201
            
    except Exception as e:
        print(f"❌ Error inviting collaborator: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.delete("/api/collaborations/<int:invitation_id>")
@bp.delete("/collaborations/<int:invitation_id>")
@token_required
def remove_collaborator(username=None, invitation_id=None):
    """Remove a collaborator invitation"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation and verify ownership
            cursor.execute("""
                SELECT ci.*, p.owner_id as proposal_owner
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.id = %s
            """, (invitation_id,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invitation not found'}, 404
            
            if invitation['proposal_owner'] != username:
                return {'detail': 'Access denied'}, 403
            
            # Delete invitation
            cursor.execute("""
                DELETE FROM collaboration_invitations WHERE id = %s
            """, (invitation_id,))
            
            conn.commit()
            
            return {'message': 'Collaborator removed successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error removing collaborator: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

# ============================================================================
# PROPOSAL ARCHIVAL ROUTES
# ============================================================================

@bp.patch("/api/proposals/<int:proposal_id>/archive")
@bp.patch("/proposals/<int:proposal_id>/archive")
@token_required
def archive_proposal(username=None, proposal_id=None):
    """Archive a proposal (set status to 'Archived')"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get proposal and verify ownership
            cursor.execute("""
                SELECT id, owner_id, title, status
                FROM proposals
                WHERE id = %s
            """, (proposal_id,))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Get user ID from username for comparison
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            if proposal['owner_id'] != user_id:
                return {'detail': 'Access denied'}, 403
            
            if proposal['status'] == 'Archived':
                return {'detail': 'Proposal is already archived'}, 400
            
            # Get user ID for activity log
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            user_id = user['id'] if user else None
            
            # Archive proposal
            cursor.execute("""
                UPDATE proposals
                SET status = 'Archived', updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                RETURNING id, title, status, updated_at
            """, (proposal_id,))
            
            result = cursor.fetchone()
            conn.commit()
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id,
                    user_id,
                    'proposal_archived',
                    f'Archived proposal "{proposal["title"]}"',
                    {'old_status': proposal['status'], 'new_status': 'Archived'}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return {
                'message': 'Proposal archived successfully',
                'proposal': dict(result)
            }, 200
            
    except Exception as e:
        print(f"❌ Error archiving proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.patch("/api/proposals/<int:proposal_id>/restore")
@bp.patch("/proposals/<int:proposal_id>/restore")
@token_required
def restore_proposal(username=None, proposal_id=None):
    """Restore a proposal from archive (admin only)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user role to check if admin
            cursor.execute('SELECT id, role FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found'}, 404
            
            is_admin = user['role'] == 'admin'
            
            # Get proposal
            cursor.execute("""
                SELECT id, owner_id, title, status
                FROM proposals
                WHERE id = %s
            """, (proposal_id,))
            
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            # Get user ID from username for comparison
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            user_id = user_row[0]
            
            # Check permissions (owner or admin)
            if proposal['owner_id'] != user_id and not is_admin:
                return {'detail': 'Access denied. Only owner or admin can restore proposals.'}, 403
            
            if proposal['status'] != 'Archived':
                return {'detail': 'Proposal is not archived'}, 400
            
            # Restore proposal (set to Draft)
            cursor.execute("""
                UPDATE proposals
                SET status = 'Draft', updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                RETURNING id, title, status, updated_at
            """, (proposal_id,))
            
            result = cursor.fetchone()
            conn.commit()
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id,
                    user['id'],
                    'proposal_restored',
                    f'Restored proposal "{proposal["title"]}" from archive',
                    {'old_status': 'Archived', 'new_status': 'Draft'}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return {
                'message': 'Proposal restored successfully',
                'proposal': dict(result)
            }, 200
            
    except Exception as e:
        print(f"❌ Error restoring proposal: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/proposals/archived")
@bp.get("/proposals/archived")
@token_required
def get_archived_proposals(username=None):
    """Get all archived proposals for the user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Check if user is admin (admins can see all archived proposals)
            cursor.execute('SELECT role FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            is_admin = user and user['role'] == 'admin'
            
            if is_admin:
                # Admin can see all archived proposals
                cursor.execute("""
                    SELECT id, owner_id, title, content, status, client_name, client_email, 
                           budget, timeline_days, created_at, updated_at
                    FROM proposals
                    WHERE status = 'Archived'
                    ORDER BY updated_at DESC
                """)
            else:
                # Get user ID from username
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                user_row = cursor.fetchone()
                if not user_row:
                    return {'detail': 'User not found'}, 404
                user_id = user_row[0]
                
                # Regular users see only their archived proposals
                cursor.execute("""
                    SELECT id, owner_id, title, content, status, client_name, client_email, 
                           budget, timeline_days, created_at, updated_at
                    FROM proposals
                    WHERE owner_id = %s AND status = 'Archived'
                    ORDER BY updated_at DESC
                """, (user_id,))
            
            rows = cursor.fetchall()
            proposals = []
            
            for row in rows:
                proposals.append({
                    'id': row['id'],
                    'user_id': row['owner_id'],  # Keep for backward compatibility
                    'owner_id': row['owner_id'],
                    'title': row['title'],
                    'content': row['content'],
                    'status': row['status'] or 'Archived',
                    'client_name': row['client_name'],
                    'client': row['client_name'],
                    'client_email': row['client_email'],
                    'budget': float(row['budget']) if row['budget'] else None,
                    'timeline_days': row['timeline_days'],
                    'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                    'updated_at': row['updated_at'].isoformat() if row['updated_at'] else None,
                    'updatedAt': row['updated_at'].isoformat() if row['updated_at'] else None,
                })
            
            return proposals, 200
            
    except Exception as e:
        print(f"❌ Error getting archived proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

