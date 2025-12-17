"""
Proposal management routes
Extracted from app.py for better organization
"""
from flask import Blueprint, request, jsonify
from api.utils.decorators import token_required, admin_required
from api.utils.database import get_db_connection
from api.utils.helpers import resolve_user_id
from api.utils.email import send_email
import json
import psycopg2.extras
import traceback

bp = Blueprint('proposals', __name__)


@bp.post("/proposals")
@token_required
def create_proposal(username=None, user_id=None, email=None):
    """Create a new proposal"""
    try:
        data = request.get_json()
        print(f"📝 Creating proposal for user {username} (user_id: {user_id}, email: {email})")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Robust user lookup with retries (ported from creator.py)
            # This handles eventual consistency where the user might not be visible immediately after creation
            found_user_id = None
            import time
            
            # Strategy: Try user_id first (if provided), then email, then username
            lookup_strategies = []
            if user_id:
                lookup_strategies.append(('user_id', user_id))
            if email:
                lookup_strategies.append(('email', email))
            if username:
                lookup_strategies.append(('username', username))
            
            max_retries = 30
            retry_delay = 0.2
            
            for attempt in range(max_retries):
                for strategy_type, strategy_value in lookup_strategies:
                    try:
                        if strategy_type == 'user_id':
                            cursor.execute('SELECT id FROM users WHERE id = %s', (strategy_value,))
                        elif strategy_type == 'email':
                            cursor.execute('SELECT id FROM users WHERE email = %s', (strategy_value,))
                        elif strategy_type == 'username':
                            cursor.execute('SELECT id FROM users WHERE username = %s', (strategy_value,))
                        
                        user_row = cursor.fetchone()
                        if user_row:
                            found_user_id = user_row[0]
                            print(f"✅ Found user_id {found_user_id} using {strategy_type}: {strategy_value} (attempt {attempt + 1})")
                            break
                    except Exception as e:
                        print(f"⚠️ Error looking up by {strategy_type}: {e}")
                
                if found_user_id:
                    break
                
                if attempt < max_retries - 1:
                    print(f"⚠️ User not found yet, waiting {retry_delay}s before retry {attempt + 2}/{max_retries}...")
                    time.sleep(retry_delay)
                    retry_delay = min(retry_delay * 1.3, 1.0)
            
            if not found_user_id:
                print(f"❌ User lookup failed after {max_retries} attempts for username: {username}, email: {email}, user_id: {user_id}")
                return jsonify({'detail': f"User not found after {max_retries} retries"}), 400
            
            user_id = found_user_id
                
            # Extract fields
            title = data.get('title', 'Untitled Proposal')
            content = data.get('content')
            
            # Normalize status
            raw_status = data.get('status', 'draft')
            status = 'draft'
            if raw_status:
                status_lower = str(raw_status).lower().strip()
                if status_lower == 'draft':
                    status = 'draft'
                elif 'pending' in status_lower and 'ceo' in status_lower:
                    status = 'Pending CEO Approval'
                elif 'sent' in status_lower and 'client' in status_lower:
                    status = 'Sent to Client'
                elif status_lower == 'signed':
                    status = 'Signed'
                elif status_lower == 'approved':
                    status = 'Approved'
                elif 'review' in status_lower:
                    status = 'In Review'
                else:
                    status = status_lower

            client_name = data.get('client_name') or data.get('client') or 'Unknown Client'
            client_email = data.get('client_email')
            
            # Insert
            cursor.execute("""
                INSERT INTO proposals 
                (title, content, status, client, client_email, owner_id)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id, title, content, status, client, client_email, owner_id, created_at, updated_at
            """, (title, content, status, client_name, client_email, user_id))
            
            row = cursor.fetchone()
            conn.commit()
            
            new_proposal = {
                'id': row[0],
                'title': row[1],
                'content': row[2],
                'status': row[3],
                'client_name': row[4],
                'client_email': row[5],
                'owner_id': row[6],
                'created_at': row[7].isoformat() if row[7] else None,
                'updated_at': row[8].isoformat() if row[8] else None
            }
            
            print(f"✅ Proposal created: {new_proposal['id']}")
            return jsonify(new_proposal), 201
            
    except Exception as e:
        print(f"❌ Error creating proposal: {e}")
        traceback.print_exc()
        return jsonify({'detail': str(e)}), 500


@bp.get("/proposals")
@token_required
def get_proposals(username=None, user_id=None, email=None):
    """Get all proposals for the current user"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            print(f"🔍 Looking for proposals for user {username} (user_id: {user_id}, email: {email})")
            
            # Robust user lookup (similar to create_proposal but simpler since read doesn't need to wait for write visibility as critically)
            found_user_id = None
            
            # 1. Trust decorator user_id if provided
            if user_id:
                try:
                    cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
                    if cursor.fetchone():
                        found_user_id = user_id
                except Exception:
                    pass
            
            # 2. Try email
            if not found_user_id and email:
                cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
                row = cursor.fetchone()
                if row:
                    found_user_id = row[0]
            
            # 3. Try username (fallback)
            if not found_user_id and username:
                found_user_id = resolve_user_id(cursor, username)
            
            user_id = found_user_id
            if not user_id:
                print(f"⚠️ Could not resolve numeric ID for {username}, returning empty list")
                return jsonify([]), 200
            
            # Check what columns exist in proposals table
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'proposals'
            """)
            existing_columns = [row[0] for row in cursor.fetchall()]
            print(f"📋 Available columns in proposals table: {existing_columns}")
            
            # Build query dynamically based on available columns
            if 'owner_id' in existing_columns:
                select_cols = ['id', 'owner_id', 'title', 'content', 'status']
                if 'client' in existing_columns:
                    select_cols.append('client')
                elif 'client_name' in existing_columns:
                    select_cols.append('client_name')
                if 'created_at' in existing_columns:
                    select_cols.append('created_at')
                if 'updated_at' in existing_columns:
                    select_cols.append('updated_at')
                if 'template_key' in existing_columns:
                    select_cols.append('template_key')
                if 'sections' in existing_columns:
                    select_cols.append('sections')
                if 'pdf_url' in existing_columns:
                    select_cols.append('pdf_url')
                
                query = f'''SELECT {', '.join(select_cols)}
                     FROM proposals WHERE owner_id = %s
                     ORDER BY created_at DESC'''
                cursor.execute(query, (user_id,))
            elif 'user_id' in existing_columns:
                select_cols = ['id', 'user_id', 'title', 'content', 'status']
                if 'client' in existing_columns:
                    select_cols.append('client')
                elif 'client_name' in existing_columns:
                    select_cols.append('client_name')
                if 'client_email' in existing_columns:
                    select_cols.append('client_email')
                if 'budget' in existing_columns:
                    select_cols.append('budget')
                if 'timeline_days' in existing_columns:
                    select_cols.append('timeline_days')
                if 'created_at' in existing_columns:
                    select_cols.append('created_at')
                if 'updated_at' in existing_columns:
                    select_cols.append('updated_at')
                
                query = f'''SELECT {', '.join(select_cols)}
                   FROM proposals WHERE user_id = %s
                     ORDER BY created_at DESC'''
                cursor.execute(query, (user_id,))
            else:
                print(f"⚠️ No owner_id or user_id column found in proposals table")
                return jsonify([]), 200
            
            rows = cursor.fetchall()
            column_names = [desc[0] for desc in cursor.description] if cursor.description else []
            
            proposals = []
            for row in rows:
                try:
                    row_dict = dict(zip(column_names, row))
                    
                    # Parse sections JSON
                    sections_data = {}
                    if 'sections' in row_dict and row_dict['sections']:
                        try:
                            if isinstance(row_dict['sections'], str):
                                sections_data = json.loads(row_dict['sections'])
                            elif isinstance(row_dict['sections'], dict):
                                sections_data = row_dict['sections']
                        except (json.JSONDecodeError, TypeError):
                            sections_data = {}
                    
                    # Build proposal object
                    proposal = {
                        'id': row_dict.get('id'),
                        'title': row_dict.get('title') or '',
                        'content': row_dict.get('content') or '',
                        'status': row_dict.get('status') or 'Draft',
                        'sections': sections_data,
                    }
                    
                    # Handle user/owner ID
                    if 'owner_id' in row_dict:
                        proposal['owner_id'] = str(row_dict['owner_id'])
                        proposal['user_id'] = str(row_dict['owner_id'])
                    elif 'user_id' in row_dict:
                        proposal['user_id'] = str(row_dict['user_id'])
                        proposal['owner_id'] = str(row_dict['user_id'])
                    
                    # Handle client
                    if 'client' in row_dict:
                        proposal['client'] = row_dict['client'] or ''
                        proposal['client_name'] = row_dict['client'] or ''
                    elif 'client_name' in row_dict:
                        proposal['client_name'] = row_dict['client_name'] or ''
                        proposal['client'] = row_dict['client_name'] or ''
                    else:
                        proposal['client'] = ''
                        proposal['client_name'] = ''
                    
                    proposal['client_email'] = row_dict.get('client_email') or ''
                    
                    # Handle budget
                    if 'budget' in row_dict:
                        try:
                            proposal['budget'] = float(row_dict['budget']) if row_dict['budget'] else None
                        except (ValueError, TypeError):
                            proposal['budget'] = None
                    else:
                        proposal['budget'] = None
                    
                    proposal['timeline_days'] = row_dict.get('timeline_days')
                    
                    # Handle timestamps
                    if 'created_at' in row_dict and row_dict['created_at']:
                        proposal['created_at'] = row_dict['created_at'].isoformat() if hasattr(row_dict['created_at'], 'isoformat') else str(row_dict['created_at'])
                    else:
                        proposal['created_at'] = None
                    
                    if 'updated_at' in row_dict and row_dict['updated_at']:
                        proposal['updated_at'] = row_dict['updated_at'].isoformat() if hasattr(row_dict['updated_at'], 'isoformat') else str(row_dict['updated_at'])
                        proposal['updatedAt'] = proposal['updated_at']
                    else:
                        proposal['updated_at'] = None
                        proposal['updatedAt'] = None
                    
                    proposal['template_key'] = row_dict.get('template_key')
                    proposal['pdf_url'] = row_dict.get('pdf_url')
                    
                    proposals.append(proposal)
                except Exception as row_error:
                    print(f"⚠️ Error processing proposal row: {row_error}")
                    continue
            
            print(f"✅ Found {len(proposals)} proposals for user {username}")
            return jsonify(proposals), 200
    except Exception as e:
        print(f"❌ Error getting proposals: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'detail': str(e)}), 500


@bp.put("/proposals/<int:proposal_id>")
@token_required
def update_proposal(username, proposal_id):
    """Update a proposal"""
    try:
        data = request.get_json()
        print(f"📝 Updating proposal {proposal_id} for user {username}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Verify ownership
            user_id = resolve_user_id(cursor, username)
            if not user_id:
                return jsonify({'detail': f"User '{username}' not found"}), 400
            
            cursor.execute("SELECT owner_id FROM proposals WHERE id = %s", (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal or proposal[0] != user_id:
                return jsonify({'detail': 'Proposal not found or access denied'}), 404
            
            updates = ['updated_at = NOW()']
            params = []
            
            if 'title' in data:
                updates.append('title = %s')
                params.append(data['title'])
            if 'content' in data:
                updates.append('content = %s')
                params.append(data['content'])
            if 'sections' in data:
                updates.append('sections = %s')
                try:
                    sections_json = json.dumps(data['sections'])
                except Exception:
                    sections_json = str(data['sections'])
                params.append(sections_json)
            if 'status' in data:
                updates.append('status = %s')
                params.append(data['status'])
            if 'client_name' in data or 'client' in data:
                updates.append('client_name = %s')
                params.append(data.get('client_name') or data.get('client'))
            if 'client_email' in data:
                updates.append('client_email = %s')
                params.append(data['client_email'])
            if 'budget' in data:
                updates.append('budget = %s')
                params.append(data['budget'])
            if 'timeline_days' in data:
                updates.append('timeline_days = %s')
                params.append(data['timeline_days'])
            
            params.append(proposal_id)
            cursor.execute(f'''UPDATE proposals SET {', '.join(updates)} WHERE id = %s''', params)
            conn.commit()
            
            print(f"✅ Proposal {proposal_id} updated successfully")
            return jsonify({'detail': 'Proposal updated'}), 200
    except Exception as e:
        print(f"❌ Error updating proposal {proposal_id}: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'detail': str(e)}), 500


@bp.delete("/proposals/<int:proposal_id>")
@token_required
def delete_proposal(username, proposal_id):
    """Delete a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Verify ownership
            user_id = resolve_user_id(cursor, username)
            if not user_id:
                return jsonify({'detail': f"User '{username}' not found"}), 400
            
            cursor.execute("SELECT owner_id FROM proposals WHERE id = %s", (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal or proposal[0] != user_id:
                return jsonify({'detail': 'Proposal not found or access denied'}), 404
            
            cursor.execute('DELETE FROM proposals WHERE id = %s', (proposal_id,))
            conn.commit()
            return jsonify({'detail': 'Proposal deleted'}), 200
    except Exception as e:
        return jsonify({'detail': str(e)}), 500


@bp.get("/proposals/<int:proposal_id>")
@token_required
def get_proposal(username, proposal_id):
    """Get a single proposal by ID"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Verify ownership
            user_id = resolve_user_id(cursor, username)
            if not user_id:
                return jsonify({'detail': f"User '{username}' not found"}), 400
            
            cursor.execute(
                '''SELECT id, title, client, owner_id, status, created_at, updated_at, template_key, content, sections, pdf_url
                   FROM proposals WHERE id = %s AND owner_id = %s''',
                (proposal_id, user_id)
            )
            result = cursor.fetchone()
            
            if result:
                return jsonify({
                    'id': result[0],
                    'title': result[1],
                    'client': result[2],
                    'owner_id': result[3],
                    'status': result[4],
                    'created_at': result[5].isoformat() if result[5] else None,
                    'updated_at': result[6].isoformat() if result[6] else None,
                    'template_key': result[7],
                    'content': result[8],
                    'sections': json.loads(result[9]) if result[9] else {},
                    'pdf_url': result[10]
                }), 200
            return jsonify({'detail': 'Proposal not found'}), 404
    except Exception as e:
        return jsonify({'detail': str(e)}), 500
