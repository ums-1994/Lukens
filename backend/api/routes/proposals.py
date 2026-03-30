"""
Proposal management routes
Extracted from app.py for better organization
"""
from flask import Blueprint, request, jsonify
import os
import psycopg2
import psycopg2.extras
import json
import traceback
import os
import psycopg2
import psycopg2.extras
import json
import traceback
from typing import Optional


from api.utils.decorators import token_required, admin_required
from api.utils.database import get_db_connection
from api.utils.helpers import create_notification, resolve_user_id
from api.utils.finance_audit import log_finance_audit_async, evaluate_proposal_compliance
from api.utils.helpers import create_notification, resolve_user_id
from api.utils.finance_audit import log_finance_audit_async, evaluate_proposal_compliance
from api.utils.email import send_email

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


def _safe_json_load(value):
    if value is None:
        return None
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str):
        s = value.strip()
        if not s:
            return None
        if not (s.startswith('{') or s.startswith('[')):
            return None
        try:
            return json.loads(s)
        except Exception:
            return None
    return None


def _extract_amount_from_content(content_data):
    if not content_data:
        return 0.0

    def _parse_num(v):
        if v is None:
            return 0.0
        if isinstance(v, (int, float)):
            return float(v)
        cleaned = str(v).replace(',', '').replace('R', '').replace('$', '').strip()
        try:
            return float(cleaned)
        except Exception:
            return 0.0

    if isinstance(content_data, dict):
        for key in ['budget', 'amount', 'total', 'value', 'price']:
            if key in content_data:
                amount = _parse_num(content_data.get(key))
                if amount > 0:
                    return amount

    if isinstance(content_data, dict) and 'sections' in content_data:
        total = 0.0
        for section in content_data.get('sections', []) or []:
            if not isinstance(section, dict):
                continue
            for table in section.get('tables', []) or []:
                if isinstance(table, dict) and table.get('type') == 'price':
                    cells = table.get('cells', [])
                    if isinstance(cells, list) and len(cells) > 1:
                        header_row = cells[0] if isinstance(cells[0], list) else []
                        total_col_idx = None
                        for i, header in enumerate(header_row):
                            if isinstance(header, str) and 'total' in header.lower():
                                total_col_idx = i
                                break
                        if total_col_idx is not None:
                            for row in cells[1:]:
                                if isinstance(row, list) and len(row) > total_col_idx:
                                    total += _parse_num(row[total_col_idx])
        return total

    return 0.0


@bp.post("/proposals")
@token_required
def create_proposal(username=None, user_id=None, email=None, auto_created=False):
    """Create a new proposal"""
    try:
        data = request.get_json()
        print(f"📝 DEBUG: create_proposal called with auto_created={auto_created}, user_id={user_id}")
        print(f"📝 Creating proposal for user {username} (user_id: {user_id}, email: {email})")
        
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # If token_required already provided a numeric user_id, trust it directly.
            # The Firebase flow guarantees this id comes from a committed INSERT
            # even if this connection can't see the users row yet due to
            # eventual consistency. We don't need to re-look it up.
            found_user_id = None
            auto_created_in_request = False
            import time

            if user_id:
                found_user_id = user_id
                print(f"🔍 Using user_id from decorator: {found_user_id} (trusting decorator verification)")

                # Check if this user was auto-created in this request (avoids DB replication lag)
                if auto_created:
                    auto_created_in_request = True
                    print(
                        f"✅ User {user_id} was auto-created in this request (auto_created=True), skipping DB verification")

                if not auto_created_in_request:
                    try:
                        from flask import g

                        auto_created_row = getattr(g, '_auto_created_user', None)
                        if auto_created_row and auto_created_row.get('user_id') == user_id:
                            auto_created_in_request = True
                            print(
                                f"✅ User {user_id} was auto-created in this request, skipping DB verification")
                    except Exception as e:
                        print(f"⚠️ Could not check g object: {e}")
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

            # Safety: ensure the user actually exists in this database connection so that
            # the proposals.owner_id → users.id foreign key will succeed. In some
            # environments we've seen cases where the Firebase decorator created the user
            # on a different connection/database, causing FK violations here.
            # SKIP this check if user was auto-created in this request (we know they exist)
            if not auto_created_in_request:
                try:
                    if user_id is not None:
                        cursor.execute('SELECT id FROM users WHERE id = %s', (user_id,))
                        exists_row = cursor.fetchone()
                    else:
                        exists_row = None

                    if not exists_row:
                        # Try to recover using email (should be present for Firebase users)
                        recovered_id = None
                        if email:
                            cursor.execute('SELECT id FROM users WHERE email = %s', (email,))
                            by_email = cursor.fetchone()
                            if by_email:
                                recovered_id = by_email[0]

                        if recovered_id:
                            print(f"🔄 Recovered user_id {recovered_id} from users table for email {email}")
                            user_id = recovered_id
                        elif email:
                            # As a last resort, auto-create a minimal user record here so the FK can succeed.
                            # This mirrors the Firebase decorator's behaviour but is scoped to this DB.
                            base_username = (email.split('@')[0] or 'user').strip() or 'user'
                            username_candidate = base_username
                            counter = 1
                            while True:
                                cursor.execute('SELECT id FROM users WHERE username = %s', (username_candidate,))
                                if cursor.fetchone() is None:
                                    break
                                username_candidate = f"{base_username}{counter}"
                                counter += 1

                            dummy_password_hash = f"firebase-proposal:{email}"
                            role = 'manager'
                            cursor.execute(
                                '''INSERT INTO users (username, email, password_hash, full_name, role, is_active, is_email_verified)
                                   VALUES (%s, %s, %s, %s, %s, %s, %s)
                                   RETURNING id''',
                                (
                                    username_candidate,
                                    email,
                                    dummy_password_hash,
                                    username_candidate,
                                    role,
                                    True,
                                    True,
                                ),
                            )
                            created_row = cursor.fetchone()
                            user_id = created_row[0]
                            print(f"🔧 Auto-created fallback user {username_candidate} (id={user_id}) for email {email}")

                            # Commit immediately so that later INSERT into proposals can see this row
                            conn.commit()
                        else:
                            print(f"❌ User id {user_id} not found in users table and no email available to recover")
                            return jsonify({'detail': 'User not found in users table'}), 400
                except Exception as verify_err:
                    print(f"⚠️ Error verifying/repairing user record before proposal insert: {verify_err}")
                    # If we cannot confidently ensure the user exists, fail fast with 400 to avoid FK 500s.
                    return jsonify({'detail': 'Could not verify user in database'}), 400
                
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
            budget = data.get('budget')
            timeline_days = data.get('timeline_days')
            
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

            if 'budget' in existing_columns and budget is not None:
                insert_cols.append('budget')
                values.append(budget)

            if 'timeline_days' in existing_columns and timeline_days is not None:
                insert_cols.append('timeline_days')
                values.append(timeline_days)

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

            if 'budget' in row_dict:
                new_proposal['budget'] = row_dict.get('budget')

            if 'timeline_days' in row_dict:
                new_proposal['timeline_days'] = row_dict.get('timeline_days')

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
            is_admin = requester_role in ['admin', 'ceo']
<<<<<<< HEAD
=======
            is_manager = _is_manager_role(requester_role)
>>>>>>> origin/PSB-215_manager_full_access

            if not user_id and not is_finance:
                resolved_user_id = resolve_user_id(cursor, username or email)
                user_id = resolved_user_id
                if not user_id:
                    print(f"⚠️ Could not resolve numeric ID for {username or email}, returning empty list")
                    return jsonify([]), 200
                resolved_user_id = resolve_user_id(cursor, username or email)
                user_id = resolved_user_id
                if not user_id:
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
            
<<<<<<< HEAD
            # Finance users can see all proposals
            # Admin/CEO should also see all proposals (team default)
            if is_finance or is_admin:
=======
            # Finance/Admin/Manager users can see all proposals (including drafts).
            if is_finance or is_admin or is_manager:
>>>>>>> origin/PSB-215_manager_full_access
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
                    sections_data: object = {}
                    if 'sections' in row_dict and row_dict['sections']:
                        try:
                            if isinstance(row_dict['sections'], str):
                                sections_data = json.loads(row_dict['sections'])
                            elif isinstance(row_dict['sections'], (dict, list)):
                                sections_data = row_dict['sections']
                        except (json.JSONDecodeError, TypeError):
                            sections_data = {}

                    # Fallback: some environments store sections inside content JSON.
                    if (not sections_data or sections_data == {}) and row_dict.get('content'):
                        try:
                            content_obj = (
                                json.loads(row_dict['content'])
                                if isinstance(row_dict['content'], str)
                                else row_dict['content']
                            )
                            if isinstance(content_obj, dict) and isinstance(content_obj.get('sections'), list):
                                sections_data = content_obj.get('sections')
                            elif isinstance(content_obj, list):
                                sections_data = content_obj
                        except Exception:
                            pass
                    
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

                    if not proposal.get('budget'):
                        content_obj = _safe_json_load(proposal.get('content'))
                        derived = 0.0
                        if isinstance(content_obj, dict):
                            derived = _extract_amount_from_content(content_obj)
                        if (not derived) and sections_data:
                            derived = _extract_amount_from_content({'sections': sections_data.get('sections') if isinstance(sections_data, dict) else sections_data})
                        if derived and derived > 0:
                            proposal['budget'] = float(derived)
                    
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
            is_admin = requester_role in ['admin', 'ceo']
            is_manager = _is_manager_role(requester_role)

            # Some environments do not have a dedicated `sections` column on proposals.
            # If the client sends `sections` but the DB does not support it, store it in `content`.
            if 'sections' in data and 'sections' not in existing_columns:
                if 'content' not in data:
                    data['content'] = data.get('sections')
                data.pop('sections', None)

            select_cols = ['status', 'content']
            if 'sections' in existing_columns:
                select_cols.append('sections')
            if 'budget' in existing_columns:
                select_cols.append('budget')

            cursor.execute(
                f"""
                SELECT {', '.join(select_cols)}
                FROM proposals
                WHERE id = %s
                """,
                (proposal_id,),
            )
            before_row = cursor.fetchone()
            if not before_row:
                return jsonify({'detail': 'Proposal not found'}), 404

            before_status = (before_row[0] or '').strip().lower()
            before_content = before_row[1] if len(before_row) > 1 else None

            sent_locked = ('sent to client' in before_status) or ('released' in before_status)
            if sent_locked and is_finance:
                if any(k in data for k in ['content', 'budget']):
                    return jsonify({'detail': 'Pricing changes are not allowed after proposal is sent to client'}), 403

            before_sections = None
            if 'sections' in existing_columns:
                try:
                    before_sections = before_row[select_cols.index('sections')]
                except Exception:
                    before_sections = None

            before_budget = None
            if 'budget' in existing_columns:
                try:
                    before_budget = before_row[select_cols.index('budget')]
                except Exception:
                    before_budget = None

            sent_locked = ('sent to client' in before_status) or ('released' in before_status)
            if sent_locked and is_finance:
                if any(k in data for k in ['content', 'budget']):
                    return jsonify({'detail': 'Pricing changes are not allowed after proposal is sent to client'}), 403

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

            if not is_finance and not is_admin and not is_manager:
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
            if 'sections' in data and 'sections' in existing_columns:
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

            changes = []
            if is_finance:
                if 'content' in data:
                    changes.append({'field': 'content', 'old': before_content, 'new': data.get('content')})
                if 'sections' in data and 'sections' in existing_columns:
                    changes.append({'field': 'sections', 'old': before_sections, 'new': data.get('sections')})
                if 'budget' in data and 'budget' in existing_columns:
                    changes.append({'field': 'budget', 'old': before_budget, 'new': data.get('budget')})
                if changes:
                    log_finance_audit_async(
                        user_id=user_id,
                        username=username,
                        entity_type='proposal',
                        entity_id=str(proposal_id),
                        action_type='PRICING_UPDATE',
                        changes=changes,
                    )
                    try:
                        evaluate_proposal_compliance(proposal_id=proposal_id)
                    except Exception as comp_err:
                        print(f"[COMPLIANCE] Failed to evaluate compliance for proposal {proposal_id}: {comp_err}")
            
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
            old_status = proposal_row[0]
            old_status = proposal_row[0]

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

            log_finance_audit_async(
                user_id=resolved_user_id,
                username=username,
                entity_type='proposal',
                entity_id=str(proposal_id),
                action_type='STATUS_CHANGE',
                changes=[{'field': 'status', 'old': old_status, 'new': status_to_store}],
            )
            try:
                evaluate_proposal_compliance(proposal_id=proposal_id)
            except Exception as comp_err:
                print(f"[COMPLIANCE] Failed to evaluate compliance for proposal {proposal_id}: {comp_err}")

            log_finance_audit_async(
                user_id=resolved_user_id,
                username=username,
                entity_type='proposal',
                entity_id=str(proposal_id),
                action_type='STATUS_CHANGE',
                changes=[{'field': 'status', 'old': old_status, 'new': status_to_store}],
            )
            try:
                evaluate_proposal_compliance(proposal_id=proposal_id)
            except Exception as comp_err:
                print(f"[COMPLIANCE] Failed to evaluate compliance for proposal {proposal_id}: {comp_err}")

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
            is_manager = _is_manager_role(requester_role)

            # Verify proposal exists and ownership (unless admin)
            cursor.execute(
                f"SELECT {owner_col} FROM proposals WHERE id = %s",
                (proposal_id,),
            )
            proposal_row = cursor.fetchone()
            if not proposal_row:
                return jsonify({'detail': 'Proposal not found'}), 404

            proposal_owner_id = proposal_row[0]
            if not is_admin and not is_manager and str(proposal_owner_id) != str(resolved_user_id):
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
            is_admin = requester_role in ['admin', 'ceo', 'approver']
            is_finance = requester_role.startswith('finance') or requester_role == 'finance'
            is_manager = _is_manager_role(requester_role)

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

            # Non-admins can only read their own proposals.
            # Managers are allowed to read all proposals.
            if not is_admin and not is_finance and not is_manager and owner_col:
                where_clause += (
                    f" AND ({owner_col}::text = %s::text"
                    " OR status IN ('Changes Requested', 'changes requested', 'Resubmitted', 'resubmitted'))"
                )
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
