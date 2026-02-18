"""
Proposal management routes
Extracted from app.py for better organization
"""
from flask import Blueprint, request, jsonify
from typing import Optional
from api.utils.decorators import token_required, admin_required
from api.utils.database import get_db_connection
from api.utils.helpers import resolve_user_id, create_notification
from api.utils.email import send_email
import json
import psycopg2.extras
import traceback

bp = Blueprint('proposals', __name__)


def _role_key(raw_role: Optional[str]) -> str:
    return (raw_role or '').strip().lower()


def _normalize_status_key(raw_status: Optional[str]) -> str:
    return (raw_status or '').strip().lower()


def _is_finance_role(role_key: str) -> bool:
    return role_key.startswith('finance') or role_key == 'finance'


def _is_admin_role(role_key: str) -> bool:
    return role_key in ['admin', 'ceo']


def _is_manager_role(role_key: str) -> bool:
    return role_key in ['manager', 'creator', 'user'] or not role_key


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
            client_id = data.get('client_id')
            
            # Insert
            cursor.execute(
                """
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'proposals'
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

            if 'client_id' in existing_columns and client_id is not None:
                insert_cols.append('client_id')
                values.append(client_id)

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
            column_names = [desc[0] for desc in cursor.description]
            row_dict = dict(zip(column_names, row))

            try:
                engagement_updates = []
                engagement_params = []

                if 'opportunity_id' in existing_columns and row_dict.get('id') is not None:
                    try:
                        opportunity_id = f"OPP-{int(row_dict['id']):06d}"
                        engagement_updates.append('opportunity_id = %s')
                        engagement_params.append(opportunity_id)
                        row_dict['opportunity_id'] = opportunity_id
                    except Exception:
                        # If anything goes wrong, skip setting opportunity_id
                        pass

                if 'engagement_stage' in existing_columns:
                    initial_stage = 'Proposal Drafted'
                    engagement_updates.append('engagement_stage = %s')
                    engagement_params.append(initial_stage)
                    row_dict['engagement_stage'] = initial_stage

                if 'engagement_opened_at' in existing_columns and row_dict.get('created_at') is not None:
                    engagement_updates.append('engagement_opened_at = %s')
                    engagement_params.append(row_dict['created_at'])
                    row_dict['engagement_opened_at'] = row_dict['created_at']

                if engagement_updates:
                    engagement_params.append(row_dict['id'])
                    cursor.execute(
                        f"UPDATE proposals SET {', '.join(engagement_updates)} WHERE id = %s",
                        engagement_params,
                    )
            except Exception as meta_err:
                print(f"⚠️ Failed to set engagement metadata for proposal: {meta_err}")

            conn.commit()

            new_proposal = {
                'id': row_dict.get('id'),
                'title': row_dict.get('title', title),
                'content': row_dict.get('content', content),
                'status': row_dict.get('status', status),
            }

            try:
                proposal_id = new_proposal.get('id')
                proposal_title = new_proposal.get('title') or title
                if proposal_id is not None and user_id is not None:
                    create_notification(
                        user_id=user_id,
                        notification_type='proposal_created',
                        title='Proposal Created',
                        message=f"Your proposal '{proposal_title}' was created.",
                        proposal_id=proposal_id,
                        metadata={
                            'proposal_id': proposal_id,
                            'proposal_title': proposal_title,
                        },
                    )
            except Exception as notif_err:
                print(f"⚠️ Failed to create proposal_created notification: {notif_err}")

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
            if 'client_id' in row_dict:
                new_proposal['client_id'] = row_dict.get('client_id')
            if 'opportunity_id' in row_dict:
                new_proposal['opportunity_id'] = row_dict.get('opportunity_id')
            if 'engagement_stage' in row_dict:
                new_proposal['engagement_stage'] = row_dict.get('engagement_stage')
            if 'engagement_opened_at' in row_dict:
                opened_val = row_dict.get('engagement_opened_at')
                new_proposal['engagement_opened_at'] = (
                    opened_val.isoformat() if hasattr(opened_val, 'isoformat') and opened_val else None
                )
            
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
            
            # Determine requester role (to support finance/admin behaviours)
            requester_role = None
            try:
                if user_id:
                    cursor.execute('SELECT role FROM users WHERE id = %s', (user_id,))
                    role_row = cursor.fetchone()
                    if role_row:
                        requester_role = role_row[0]
            except Exception:
                requester_role = None

            requester_role = (requester_role or '').strip().lower()
            is_finance = requester_role.startswith('finance') or requester_role in ['finance']

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
            if not user_id and not is_finance:
                print(f"⚠️ Could not resolve numeric ID for {username or email}, returning empty list")
                return jsonify([]), 200
            
            # Check what columns exist in proposals table
            cursor.execute("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'proposals'
            """)
            existing_columns = [row[0] for row in cursor.fetchall()]
            print(f"📋 Available columns in proposals table: {existing_columns}")
            
            # Finance users can see all proposals
            if is_finance:
                select_cols = ['id', 'title', 'content', 'status']
                if 'owner_id' in existing_columns:
                    select_cols.append('owner_id')
                elif 'user_id' in existing_columns:
                    select_cols.append('user_id')
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
                if 'template_key' in existing_columns:
                    select_cols.append('template_key')
                if 'sections' in existing_columns:
                    select_cols.append('sections')
                if 'pdf_url' in existing_columns:
                    select_cols.append('pdf_url')

                query = f'''SELECT {', '.join(select_cols)}
                     FROM proposals
                     WHERE LOWER(COALESCE(status, '')) <> 'draft'
                     ORDER BY created_at DESC'''
                cursor.execute(query)

            # Build query dynamically based on available columns for non-finance users
            elif 'owner_id' in existing_columns:
                select_cols = ['id', 'owner_id', 'title', 'content', 'status']
                if 'client' in existing_columns:
                    select_cols.append('client')
                elif 'client_name' in existing_columns:
                    select_cols.append('client_name')
                if 'budget' in existing_columns:
                    select_cols.append('budget')
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

                # Handle legacy schemas where user_id may be stored as VARCHAR
                query = f'''SELECT {', '.join(select_cols)}
                   FROM proposals WHERE user_id::text = %s::text
                     ORDER BY created_at DESC'''
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

        for forbidden_key in [
            'opportunity_id',
            'engagement_stage',
            'engagement_opened_at',
            'engagement_target_close_at',
        ]:
            if forbidden_key in data:
                data.pop(forbidden_key, None)
        
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Determine ownership column based on actual schema
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
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

            # Determine requester role (to support finance/admin behaviours)
            requester_role = None
            try:
                cursor.execute('SELECT role FROM users WHERE id = %s', (user_id,))
                role_row = cursor.fetchone()
                if role_row:
                    requester_role = role_row[0]
            except Exception:
                requester_role = None

            requester_role = (requester_role or '').strip().lower()
            is_finance = requester_role.startswith('finance') or requester_role in ['finance']

            # Finance users can only update pricing-related fields.
            # We enforce this server-side so Finance cannot modify scope/content/client metadata.
            if is_finance:
                for forbidden in [
                    'title',
                    'client',
                    'client_name',
                    'client_email',
                    'client_id',
                    'timeline_days',
                    # Status transitions must go through the dedicated status endpoint
                    'status',
                ]:
                    data.pop(forbidden, None)

            if not is_finance:
                cursor.execute(
                    f"SELECT {owner_col} FROM proposals WHERE id = %s",
                    (proposal_id,),
                )
                proposal = cursor.fetchone()
                if not proposal or str(proposal[0]) != str(user_id):
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
            if 'status' in data and not is_finance:
                updates.append('status = %s')
                params.append(data['status'])
            # Determine client / metadata columns safely based on schema
            client_col = None
            if 'client' in existing_columns:
                client_col = 'client'
            elif 'client_name' in existing_columns:
                client_col = 'client_name'

            if client_col and ('client_name' in data or 'client' in data) and not is_finance:
                updates.append(f"{client_col} = %s")
                params.append(data.get('client_name') or data.get('client'))
            if (
                'client_email' in data
                and 'client_email' in existing_columns
                and not is_finance
            ):
                updates.append('client_email = %s')
                params.append(data['client_email'])
            if 'budget' in data and 'budget' in existing_columns:
                updates.append('budget = %s')
                params.append(data['budget'])
            if (
                'timeline_days' in data
                and 'timeline_days' in existing_columns
                and not is_finance
            ):
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


@bp.patch("/proposals/<int:proposal_id>/status")
@token_required
def update_proposal_status(username=None, proposal_id=None, user_id=None, email=None):
    """Update proposal status with RBAC/state-machine enforcement (Option B workflow)."""
    try:
        data = request.get_json(force=True, silent=True) or {}
        requested_status = data.get('status')
        if not requested_status:
            return jsonify({'detail': 'Status is required'}), 400

        with get_db_connection() as conn:
            cursor = conn.cursor()

            resolved_user_id = user_id
            if not resolved_user_id:
                resolved_user_id = resolve_user_id(cursor, username or email)
            if not resolved_user_id:
                return jsonify({'detail': 'User not found'}), 400

            cursor.execute('SELECT role FROM users WHERE id = %s', (resolved_user_id,))
            role_row = cursor.fetchone()
            role_key = _role_key(role_row[0] if role_row else None)

            cursor.execute('SELECT status FROM proposals WHERE id = %s', (proposal_id,))
            proposal_row = cursor.fetchone()
            if not proposal_row:
                return jsonify({'detail': 'Proposal not found'}), 404

            current_key = _normalize_status_key(proposal_row[0])
            target_key = _normalize_status_key(str(requested_status))

            # Normalize common variants
            if current_key == '':
                current_key = 'draft'
            if target_key == 'pending ceo approval':
                target_key = 'pending approval'

            # Option B workflow:
            # Manager: Draft -> Pricing In Progress
            # Finance: Pricing In Progress -> Pending Approval
            # Admin: Pending Approval -> Approved/Rejected
            allowed = False

            if _is_manager_role(role_key):
                if current_key == 'draft' and target_key == 'pricing in progress':
                    allowed = True
                # Allow returning to draft from rejected
                if current_key == 'rejected' and target_key == 'draft':
                    allowed = True

            if _is_finance_role(role_key):
                if current_key in ['draft', 'pricing in progress'] and target_key == 'pricing in progress':
                    allowed = True
                if current_key == 'pricing in progress' and target_key == 'pending approval':
                    allowed = True

            if _is_admin_role(role_key):
                if current_key == 'pending approval' and target_key in ['approved', 'rejected']:
                    allowed = True
                if current_key == 'rejected' and target_key == 'draft':
                    allowed = True

            if not allowed:
                return jsonify({
                    'detail': 'Status transition not allowed',
                    'current_status': proposal_row[0],
                    'requested_status': requested_status,
                    'role': role_key,
                }), 403

            # Write canonical display values
            status_to_store = requested_status
            if target_key == 'draft':
                status_to_store = 'Draft'
            elif target_key == 'pricing in progress':
                status_to_store = 'Pricing In Progress'
            elif target_key == 'pending approval':
                status_to_store = 'Pending Approval'
            elif target_key == 'approved':
                status_to_store = 'Approved'
            elif target_key == 'rejected':
                status_to_store = 'Rejected'

            cursor.execute(
                '''UPDATE proposals SET status = %s, updated_at = NOW() WHERE id = %s''',
                (status_to_store, proposal_id),
            )
            conn.commit()

            return jsonify({'detail': 'Status updated', 'status': status_to_store}), 200
    except Exception as e:
        print(f"❌ Error updating proposal status: {e}")
        traceback.print_exc()
        return jsonify({'detail': str(e)}), 500


@bp.delete("/proposals/<int:proposal_id>")
@token_required
def delete_proposal(username=None, proposal_id=None, user_id=None, email=None):
    """Delete a proposal"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Detect proposals ownership column based on actual schema
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
                """
            )
            proposal_columns = [row[0] for row in cursor.fetchall()]
            owner_col = 'owner_id' if 'owner_id' in proposal_columns else (
                'user_id' if 'user_id' in proposal_columns else None
            )
            if not owner_col:
                return jsonify({'detail': 'Proposals table is missing owner column'}), 500

            # Resolve requester id (prefer token_required-provided numeric id)
            resolved_user_id = user_id
            if not resolved_user_id:
                resolved_user_id = resolve_user_id(cursor, username or email)
            if not resolved_user_id:
                return jsonify({'detail': f"User '{username or email}' not found"}), 400

            # Determine requester role for admin delete capability
            requester_role = None
            try:
                cursor.execute('SELECT role FROM users WHERE id = %s', (resolved_user_id,))
                role_row = cursor.fetchone()
                if role_row:
                    requester_role = role_row[0]
            except Exception:
                requester_role = None
            requester_role = (requester_role or '').strip().lower()
            is_admin = requester_role in ['admin', 'ceo']

            # Verify proposal exists and ownership (unless admin)
            cursor.execute(
                f"SELECT {owner_col} FROM proposals WHERE id = %s",
                (proposal_id,),
            )
            proposal_row = cursor.fetchone()
            if not proposal_row:
                return jsonify({'detail': 'Proposal not found'}), 404

            proposal_owner_id = proposal_row[0]
            if not is_admin and str(proposal_owner_id) != str(resolved_user_id):
                return jsonify({'detail': 'Proposal not found or access denied'}), 404

            # Best-effort cleanup of dependent rows for schemas without ON DELETE CASCADE.
            # Only run DELETEs for tables that actually exist.
            cursor.execute(
                """
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = 'public'
                """
            )
            existing_tables = {row[0] for row in cursor.fetchall()}

            dependent_tables = [
                'approvals',
                'client_dashboard_tokens',
                'proposal_feedback',
                'proposal_client_activity',
                'proposal_client_session',
                'proposal_versions',
                'proposal_signatures',
                'document_comments',
                'section_locks',
                'suggested_changes',
                'collaboration_invitations',
                'collaborators',
                'client_proposals',
                'activity_log',
                'notifications',
            ]
            for table in dependent_tables:
                if table in existing_tables:
                    try:
                        cursor.execute(
                            f"DELETE FROM {table} WHERE proposal_id = %s",
                            (proposal_id,),
                        )
                    except Exception:
                        # Ignore cleanup errors to allow the main delete to surface a useful error
                        pass

            cursor.execute('DELETE FROM proposals WHERE id = %s', (proposal_id,))
            conn.commit()
            return jsonify({'detail': 'Proposal deleted'}), 200
    except psycopg2.IntegrityError as e:
        try:
            conn.rollback()
        except Exception:
            pass
        return jsonify({'detail': 'Cannot delete proposal due to related records', 'error': str(e)}), 409
    except Exception as e:
        traceback.print_exc()
        return jsonify({'detail': str(e)}), 500


@bp.get("/proposals/<int:proposal_id>")
@token_required
def get_proposal(username=None, proposal_id=None, user_id=None, email=None):
    """Get a single proposal by ID"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Resolve requester user_id (prefer token_required-provided user_id)
            resolved_user_id = user_id
            if not resolved_user_id:
                resolved_user_id = resolve_user_id(cursor, username or email)
            if not resolved_user_id:
                return jsonify({'detail': f"User '{username or email}' not found"}), 400

            # Determine if requester is admin/ceo
            requester_role = None
            try:
                cursor.execute('SELECT role FROM users WHERE id = %s', (resolved_user_id,))
                role_row = cursor.fetchone()
                if role_row:
                    requester_role = role_row[0]
            except Exception:
                requester_role = None

            requester_role = (requester_role or '').strip().lower()
            is_admin = requester_role in ['admin', 'ceo']

            # Detect proposals table schema
            cursor.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'proposals'
                """
            )
            existing_columns = [row[0] for row in cursor.fetchall()]

            owner_col = 'owner_id' if 'owner_id' in existing_columns else (
                'user_id' if 'user_id' in existing_columns else None
            )
            client_col = 'client' if 'client' in existing_columns else (
                'client_name' if 'client_name' in existing_columns else None
            )

            # Build SELECT clause using only existing columns
            select_cols = ['id', 'title', 'status']
            if client_col:
                select_cols.append(client_col)
            if owner_col:
                select_cols.append(owner_col)
            if 'created_at' in existing_columns:
                select_cols.append('created_at')
            if 'updated_at' in existing_columns:
                select_cols.append('updated_at')
            if 'template_key' in existing_columns:
                select_cols.append('template_key')
            if 'content' in existing_columns:
                select_cols.append('content')
            if 'sections' in existing_columns:
                select_cols.append('sections')
            if 'pdf_url' in existing_columns:
                select_cols.append('pdf_url')
            if 'client_email' in existing_columns:
                select_cols.append('client_email')

            where_clause = 'id = %s'
            params = [proposal_id]

            # Non-admins can only read their own proposals
            if not is_admin and owner_col:
                where_clause += f' AND {owner_col}::text = %s::text'
                params.append(str(resolved_user_id))

            cursor.execute(
                f"SELECT {', '.join(select_cols)} FROM proposals WHERE {where_clause}",
                tuple(params),
            )
            result = cursor.fetchone()
            
            if result:
                column_names = [desc[0] for desc in cursor.description] if cursor.description else []
                row_dict = dict(zip(column_names, result))

                sections_val = row_dict.get('sections')
                parsed_sections = {}
                if sections_val:
                    try:
                        parsed_sections = (
                            json.loads(sections_val)
                            if isinstance(sections_val, str)
                            else sections_val
                        )
                    except Exception:
                        parsed_sections = {}

                response = {
                    'id': row_dict.get('id'),
                    'title': row_dict.get('title'),
                    'status': row_dict.get('status'),
                    'content': row_dict.get('content'),
                    'sections': parsed_sections,
                    'template_key': row_dict.get('template_key'),
                    'pdf_url': row_dict.get('pdf_url'),
                    'client_email': row_dict.get('client_email') or '',
                }

                if 'budget' in row_dict:
                    response['budget'] = row_dict.get('budget')

                if client_col:
                    response['client'] = row_dict.get(client_col) or ''
                    response['client_name'] = row_dict.get(client_col) or ''
                else:
                    response['client'] = ''
                    response['client_name'] = ''

                if owner_col:
                    response['owner_id'] = row_dict.get(owner_col)
                    response['user_id'] = row_dict.get(owner_col)

                created_at = row_dict.get('created_at')
                updated_at = row_dict.get('updated_at')
                response['created_at'] = (
                    created_at.isoformat() if hasattr(created_at, 'isoformat') and created_at else None
                )
                response['updated_at'] = (
                    updated_at.isoformat() if hasattr(updated_at, 'isoformat') and updated_at else None
                )
                response['updatedAt'] = response['updated_at']

                return jsonify(response), 200

            # Preserve old message but clarify access
            return jsonify({'detail': 'Proposal not found or access denied'}), 404
    except Exception as e:
        return jsonify({'detail': str(e)}), 500
