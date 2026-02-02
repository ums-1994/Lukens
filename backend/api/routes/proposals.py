"""
Proposal management routes
Extracted from app.py for better organization
"""
from flask import Blueprint, request, jsonify
from api.utils.decorators import token_required, admin_required
from api.utils.database import get_db_connection
from api.utils.helpers import resolve_user_id, log_status_change
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

            # If token_required already provided a numeric user_id, trust it directly.
            # The Firebase flow guarantees this id comes from a committed INSERT
            # even if this connection can't see the users row yet due to
            # eventual consistency. We don't need to re-look it up.
            found_user_id = None
            import time

            if user_id:
                found_user_id = user_id
                print(f"🔍 Using user_id from decorator: {found_user_id} (trusting decorator verification)")
            else:
                # Robust user lookup with retries (ported from creator.py)
                # This handles cases where legacy/dev flows call this route
                # without a trusted user_id from the decorator.
                lookup_strategies = []
                if email:
                    lookup_strategies.append(('email', email))
                if username:
                    lookup_strategies.append(('username', username))

                max_retries = 30
                retry_delay = 0.2

                for attempt in range(max_retries):
                    for strategy_type, strategy_value in lookup_strategies:
                        try:
                            if strategy_type == 'email':
                                cursor.execute(
                                    'SELECT id FROM users WHERE lower(email) = lower(%s) ORDER BY id DESC LIMIT 1',
                                    (strategy_value,),
                                )
                            elif strategy_type == 'username':
                                cursor.execute(
                                    'SELECT id FROM users WHERE username = %s ORDER BY id DESC LIMIT 1',
                                    (strategy_value,),
                                )

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

            template_key = data.get('template_key') or data.get('templateKey')
            template_type = data.get('template_type') or data.get('templateType')
            
            # Insert
            cursor.execute(
                """
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'proposals'
                  AND table_schema = current_schema()
                """
            )
            existing_columns = [row[0] for row in cursor.fetchall()]

            insert_cols = ['title', 'content', 'status']
            values = [title, content, status]

            if 'client' in existing_columns:
                insert_cols.append('client')
                values.append(client_name)
            elif 'client_name' in existing_columns:
                insert_cols.append('client_name')
                values.append(client_name)

            if 'client_email' in existing_columns:
                insert_cols.append('client_email')
                values.append(client_email)

            if template_key and 'template_key' in existing_columns:
                insert_cols.append('template_key')
                values.append(template_key)
            if template_type and 'template_type' in existing_columns:
                insert_cols.append('template_type')
                values.append(template_type)

            if 'owner_id' in existing_columns:
                insert_cols.append('owner_id')
                values.append(user_id)
            elif 'user_id' in existing_columns:
                insert_cols.append('user_id')
                values.append(user_id)

            placeholders = ', '.join(['%s'] * len(insert_cols))
            columns_sql = ', '.join(insert_cols)

            cursor.execute(
                f"INSERT INTO proposals ({columns_sql}) VALUES ({placeholders}) RETURNING *",
                values,
            )
            
            row = cursor.fetchone()
            conn.commit()

            column_names = [desc[0] for desc in cursor.description]
            row_dict = dict(zip(column_names, row))

            new_proposal = {
                'id': row_dict.get('id'),
                'title': row_dict.get('title', title),
                'content': row_dict.get('content', content),
                'status': row_dict.get('status', status),
            }

            if 'client' in row_dict:
                new_proposal['client_name'] = row_dict.get('client') or ''
                new_proposal['client'] = row_dict.get('client') or ''
            elif 'client_name' in row_dict:
                new_proposal['client_name'] = row_dict.get('client_name') or ''
                new_proposal['client'] = row_dict.get('client_name') or ''
            else:
                new_proposal['client_name'] = client_name
                new_proposal['client'] = client_name

            new_proposal['client_email'] = row_dict.get('client_email') or client_email

            if 'owner_id' in row_dict:
                new_proposal['owner_id'] = row_dict.get('owner_id')
                new_proposal['user_id'] = row_dict.get('owner_id')
            elif 'user_id' in row_dict:
                new_proposal['owner_id'] = row_dict.get('user_id')
                new_proposal['user_id'] = row_dict.get('user_id')
            else:
                new_proposal['owner_id'] = user_id
                new_proposal['user_id'] = user_id

            created_at_val = row_dict.get('created_at')
            updated_at_val = row_dict.get('updated_at')
            new_proposal['created_at'] = (
                created_at_val.isoformat() if hasattr(created_at_val, 'isoformat') and created_at_val else None
            )
            new_proposal['updated_at'] = (
                updated_at_val.isoformat() if hasattr(updated_at_val, 'isoformat') and updated_at_val else None
            )
            new_proposal['updatedAt'] = new_proposal['updated_at']
            
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
            
            # Prefer the user_id provided by the Firebase-aware token_required decorator.
            # That decorator either looked up the existing user or auto-created them
            # and returns a trusted numeric user_id, even if this connection can't
            # yet see the row due to Render's eventual-consistency behaviour.
            resolved_user_id = None
            import time

            if user_id:
                resolved_user_id = user_id
                print(f"🔍 Using user_id from decorator: {resolved_user_id} (trusting decorator verification)")
            else:
                # Fallback for legacy/dev flows where user_id isn't passed through
                lookup_strategies = []
                if email:
                    lookup_strategies.append(("email", email))
                if username:
                    lookup_strategies.append(("username", username))

                max_retries = 10
                retry_delay = 0.2

                for attempt in range(max_retries):
                    for strategy_type, strategy_value in lookup_strategies:
                        try:
                            if strategy_type == "email":
                                cursor.execute("SELECT id FROM users WHERE email = %s", (strategy_value,))
                            elif strategy_type == "username":
                                cursor.execute("SELECT id FROM users WHERE username = %s", (strategy_value,))

                            row = cursor.fetchone()
                            if row:
                                resolved_user_id = row[0]
                                print(
                                    f"✅ Found user_id {resolved_user_id} using {strategy_type}: {strategy_value} "
                                    f"(attempt {attempt + 1})"
                                )
                                break
                        except Exception as e:
                            print(f"⚠️ Error looking up by {strategy_type}: {e}")

                    if resolved_user_id:
                        break

                    if attempt < max_retries - 1:
                        print(
                            f"⚠️ Could not resolve user yet, waiting {retry_delay}s before "
                            f"retry {attempt + 2}/{max_retries}..."
                        )
                        time.sleep(retry_delay)
                        retry_delay = min(retry_delay * 1.3, 1.0)

            user_id = resolved_user_id
            if not user_id:
                print(f"⚠️ Could not resolve numeric ID for {username or email}, returning empty list")
                return jsonify([]), 200
            
            # Check what columns exist in proposals table
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'proposals'
                  AND table_schema = current_schema()
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

                order_by_col = 'created_at' if 'created_at' in existing_columns else 'id'

                query = f'''SELECT {', '.join(select_cols)}
                     FROM proposals WHERE owner_id = %s
                     ORDER BY {order_by_col} DESC'''
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

                # Handle legacy schemas where user_id may be stored as VARCHAR
                order_by_col = 'created_at' if 'created_at' in existing_columns else 'id'

                query = f'''SELECT {', '.join(select_cols)}
                   FROM proposals WHERE user_id::text = %s::text
                     ORDER BY {order_by_col} DESC'''
                cursor.execute(query, (str(user_id),))
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
def update_proposal(username=None, proposal_id=None, user_id=None, email=None):
    """Update a proposal"""
    try:
        data = request.get_json()
        print(f"📝 Updating proposal {proposal_id} for user {username}")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Determine ownership column based on actual schema
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
                  AND table_schema = current_schema()
                """
            )
            existing_columns = [row[0] for row in cursor.fetchall()]

            owner_col = None
            if 'owner_id' in existing_columns:
                owner_col = 'owner_id'
            elif 'user_id' in existing_columns:
                owner_col = 'user_id'

            if not owner_col:
                print("⚠️ No owner_id or user_id column found in proposals table when updating")
                return jsonify({'detail': 'Proposals table is missing owner column'}), 500

            # Verify ownership
            resolved_user_id = None
            # Prefer user_id supplied by the Firebase token_required decorator
            if user_id:
                resolved_user_id = user_id
                print(f"🔍 Using user_id from decorator for update: {resolved_user_id}")
            else:
                # Fallback for legacy/dev flows: resolve from username/email
                identifier = username or email
                resolved_user_id = resolve_user_id(cursor, identifier)

            if not resolved_user_id:
                return jsonify({'detail': f"User '{username}' not found"}), 400

            user_id = resolved_user_id

            cursor.execute(
                f"SELECT {owner_col} FROM proposals WHERE id = %s",
                (proposal_id,),
            )
            proposal = cursor.fetchone()
            if not proposal or str(proposal[0]) != str(user_id):
                return jsonify({'detail': 'Proposal not found or access denied'}), 404
            
            updates = ['updated_at = NOW()']
            params = []

            old_status = None
            new_status = None
            if 'status' in data:
                new_status = data.get('status')
                cursor.execute(
                    "SELECT status FROM proposals WHERE id = %s",
                    (proposal_id,),
                )
                srow = cursor.fetchone()
                if srow:
                    old_status = srow[0]
            
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
            # Determine client / metadata columns safely based on schema
            client_col = None
            if 'client' in existing_columns:
                client_col = 'client'
            elif 'client_name' in existing_columns:
                client_col = 'client_name'

            if client_col and ('client_name' in data or 'client' in data):
                updates.append(f"{client_col} = %s")
                params.append(data.get('client_name') or data.get('client'))
            if 'client_email' in data and 'client_email' in existing_columns:
                updates.append('client_email = %s')
                params.append(data['client_email'])
            if 'budget' in data and 'budget' in existing_columns:
                updates.append('budget = %s')
                params.append(data['budget'])
            if 'timeline_days' in data and 'timeline_days' in existing_columns:
                updates.append('timeline_days = %s')
                params.append(data['timeline_days'])
            
            params.append(proposal_id)
            cursor.execute(f'''UPDATE proposals SET {', '.join(updates)} WHERE id = %s''', params)
            conn.commit()

            if new_status is not None and old_status is not None and str(new_status) != str(old_status):
                log_status_change(proposal_id, user_id, old_status, new_status)
            
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
