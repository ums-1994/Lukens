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

bp = Blueprint('creator', __name__)

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
def get_proposals(username=None):
    """Get all proposals for the creator"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            print(f"🔍 Looking for proposals for user {username}")

            # Resolve numeric owner_id from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row[0]
            
            cursor.execute(
                '''SELECT id, owner_id, title, content, status, client_name, client_email, 
                          budget, timeline_days, created_at, updated_at
                   FROM proposals WHERE owner_id = %s
                   ORDER BY created_at DESC''',
                (owner_id,)
            )
            rows = cursor.fetchall()
            proposals = []
            for row in rows:
                proposals.append({
                    'id': row[0],
                    'user_id': row[1],
                    'owner_id': row[1],  # For compatibility
                    'title': row[2],
                    'content': row[3],
                    'status': row[4],
                    'client_name': row[5],
                    'client': row[5],  # For compatibility
                    'client_email': row[6],
                    'budget': float(row[7]) if row[7] else None,
                    'timeline_days': row[8],
                    'created_at': row[9].isoformat() if row[9] else None,
                    'updated_at': row[10].isoformat() if row[10] else None,
                    'updatedAt': row[10].isoformat() if row[10] else None,
                })
            print(f"✅ Found {len(proposals)} proposals for user {username}")
            return proposals, 200
    except Exception as e:
        print(f"❌ Error getting proposals: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/proposals")
@token_required
def create_proposal(username=None):
    """Create a new proposal"""
    try:
        data = request.get_json()
        print(f"📝 Creating proposal for user {username}: {data.get('title', 'Untitled')}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Resolve numeric owner_id from username
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row[0]

            client_name = data.get('client_name') or data.get('client') or 'Unknown Client'
            client_email = data.get('client_email') or ''
            
            # Normalize status to proper capitalization
            raw_status = data.get('status', 'Draft')
            normalized_status = 'Draft'  # Default
            if raw_status:
                status_lower = str(raw_status).lower().strip()
                if status_lower == 'draft':
                    normalized_status = 'Draft'
                elif 'pending' in status_lower and 'ceo' in status_lower:
                    normalized_status = 'Pending CEO Approval'
                elif 'sent' in status_lower and 'client' in status_lower:
                    normalized_status = 'Sent to Client'
                elif status_lower in ['signed', 'approved']:
                    normalized_status = 'Signed'
                elif 'review' in status_lower:
                    normalized_status = 'In Review'
                else:
                    # Capitalize first letter of each word
                    normalized_status = ' '.join(word.capitalize() for word in status_lower.split())
            
            cursor.execute(
                '''INSERT INTO proposals (owner_id, title, content, status, client_name, client_email, budget, timeline_days)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s) 
                   RETURNING id, owner_id, title, content, status, client_name, client_email, budget, timeline_days, created_at, updated_at''',
                (
                    owner_id,
                    data.get('title', 'Untitled Document'),
                    data.get('content'),
                    normalized_status,
                    client_name,
                    client_email,
                    data.get('budget'),
                    data.get('timeline_days')
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
                'client_name': result[5],
                'client': result[5],
                'client_email': result[6],
                'budget': float(result[7]) if result[7] else None,
                'timeline_days': result[8],
                'created_at': result[9].isoformat() if result[9] else None,
                'updated_at': result[10].isoformat() if result[10] else None,
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
            
            # Verify ownership
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row[0]

            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404

            if proposal[0] != owner_id:
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
                   RETURNING id, owner_id, title, content, status, client_name, client_email, budget, timeline_days, created_at, updated_at''',
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
            
            # Verify ownership
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user_row = cursor.fetchone()
            if not user_row:
                return {'detail': 'User not found'}, 404
            owner_id = user_row[0]

            cursor.execute('SELECT owner_id FROM proposals WHERE id = %s', (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404

            if proposal[0] != owner_id:
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
                '''UPDATE proposals SET status = 'In Review', updated_at = CURRENT_TIMESTAMP WHERE id = %s''',
                (proposal_id,)
            )
            conn.commit()
            return {'detail': 'Proposal sent for approval', 'status': 'In Review'}, 200
    except Exception as e:
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
                SELECT id, title, client_name, client_email, owner_id
                FROM proposals
                WHERE id = %s
                """,
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            if not proposal:
                return {'detail': 'Proposal not found'}, 404
            
            cursor.execute(
                "SELECT id, full_name, username, email FROM users WHERE username = %s",
                (username,),
            )
            sender = cursor.fetchone()
            
            if not sender:
                return {'detail': 'User not found'}, 404
            
            # Update status
            new_status = 'Released'
            cursor.execute(
                """UPDATE proposals SET status = %s, updated_at = CURRENT_TIMESTAMP WHERE id = %s""",
                (new_status, proposal_id)
            )
            conn.commit()
            
            return {
                'detail': 'Proposal sent to client',
                'status': new_status,
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

