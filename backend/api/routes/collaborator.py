"""
Collaborator routes - Invitations, guest access, comments
"""
from flask import Blueprint, request, jsonify
import os
import traceback
import secrets
import jwt
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta

from api.utils.database import get_db_connection
from api.utils.decorators import token_required
from api.utils.email import send_email, get_logo_html
from api.utils.helpers import create_notification

bp = Blueprint('collaborator', __name__)


def _get_comment_notification_recipients(cursor, proposal_id, actor_user_id):
    """Collect users who should receive comment/reply notifications for a proposal."""
    recipients = set()

    # Proposal owner
    cursor.execute("SELECT owner_id FROM proposals WHERE id = %s", (proposal_id,))
    proposal_row = cursor.fetchone()
    owner_id = proposal_row.get('owner_id') if proposal_row else None
    if owner_id:
        recipients.add(int(owner_id))

    # Accepted collaborators mapped to existing users
    cursor.execute(
        """
        SELECT DISTINCT u.id
        FROM collaboration_invitations ci
        JOIN users u ON LOWER(u.email) = LOWER(ci.invited_email)
        WHERE ci.proposal_id = %s
          AND LOWER(COALESCE(ci.status, '')) IN ('accepted', 'active')
        """,
        (proposal_id,),
    )
    for row in cursor.fetchall() or []:
        uid = row.get('id')
        if uid:
            recipients.add(int(uid))

    # Existing participants in the comment thread (manager/admin/finance, etc.)
    cursor.execute(
        """
        SELECT DISTINCT created_by AS id
        FROM document_comments
        WHERE proposal_id = %s
        """,
        (proposal_id,),
    )
    for row in cursor.fetchall() or []:
        uid = row.get('id')
        if uid:
            recipients.add(int(uid))

    # Never notify the actor for their own comment/reply
    recipients.discard(int(actor_user_id))
    return recipients


def _get_proposal_owner_and_title(cursor, proposal_id):
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'proposals'
        """
    )
    cols = {r.get('column_name') for r in cursor.fetchall() or []}
    owner_col = 'user_id' if 'user_id' in cols else ('owner_id' if 'owner_id' in cols else None)
    if not owner_col:
        return None, f"Proposal {proposal_id}"

    cursor.execute(
        f"SELECT {owner_col} AS owner_id, title FROM proposals WHERE id = %s",
        (proposal_id,),
    )
    row = cursor.fetchone()
    if not row:
        return None, f"Proposal {proposal_id}"
    return row.get('owner_id'), row.get('title') or f"Proposal {proposal_id}"

@bp.get("/api/collaborate")
def get_collaboration_access():
    """Get proposal access for collaborator using token"""
    try:
        token = request.args.get('token')
        if not token:
            return {'detail': 'Access token required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cursor.execute("""
                SELECT ci.*, p.title, p.content, p.status as proposal_status
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid or expired token'}, 404
            
            # Update accessed_at timestamp in collaboration_invitations
            cursor.execute("""
                UPDATE collaboration_invitations 
                SET accessed_at = CURRENT_TIMESTAMP, status = 'active'
                WHERE id = %s
            """, (invitation['id'],))
            
            # Create or update collaborator record
            cursor.execute("""
                INSERT INTO collaborators 
                (proposal_id, email, invited_by, permission_level, status, last_accessed_at)
                VALUES (%s, %s, %s, %s, 'active', CURRENT_TIMESTAMP)
                ON CONFLICT (proposal_id, email) 
                DO UPDATE SET 
                    last_accessed_at = CURRENT_TIMESTAMP,
                    status = 'active'
            """, (
                invitation['proposal_id'],
                invitation['invited_email'],
                invitation['invited_by'],
                invitation['permission_level']
            ))
            conn.commit()
            
            # Generate auth token for collaborator (all collaborators get full access)
            guest_email = invitation['invited_email']
            jwt_secret = os.getenv('JWT_SECRET', 'your-secret-key')
            
            # Create auth token for collaborator
            auth_token = jwt.encode({
                'username': guest_email,
                'email': guest_email,
                'role': 'collaborator',
                'exp': datetime.utcnow() + timedelta(days=30)
            }, jwt_secret, algorithm='HS256')
            
            response = {
                'proposal': {
                    'id': invitation['proposal_id'],
                    'title': invitation['title'],
                    'content': invitation['content'],
                    'status': invitation['proposal_status']
                },
                'permission_level': invitation['permission_level'],
                'invited_email': invitation['invited_email'],
                'auth_token': auth_token,
                # All collaborators get full edit and comment access
                'can_edit': True,
                'can_comment': True,
                'can_suggest': True
            }
            return response, 200
    except Exception as e:
        print(f"❌ Error getting collaboration access: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.post("/api/collaborate/comment")
def add_guest_comment():
    """Add a comment as a guest collaborator (no auth required)"""
    try:
        data = request.get_json()
        token = data.get('token')
        comment_text = data.get('comment_text')
        
        if not token or not comment_text:
            return {'detail': 'Token and comment text required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get invitation
            cursor.execute("""
                SELECT ci.*, p.id as proposal_id
                FROM collaboration_invitations ci
                JOIN proposals p ON ci.proposal_id = p.id
                WHERE ci.access_token = %s
            """, (token,))
            
            invitation = cursor.fetchone()
            if not invitation:
                return {'detail': 'Invalid token'}, 404
            
            # Allow all permission levels to comment (no restrictions)
            proposal_id = invitation['proposal_id']
            invited_email = invitation['invited_email']
            
            # Get or create user for guest
            cursor.execute('SELECT id FROM users WHERE email = %s', (invited_email,))
            user = cursor.fetchone()
            if user:
                user_id = user['id']
            else:
                # Create guest user
                cursor.execute("""
                    INSERT INTO users (username, email, password_hash, full_name, role, is_active)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (invited_email, invited_email, '', f'Guest ({invited_email})', 'collaborator', True))
                user_id = cursor.fetchone()['id']
            
            # Add comment
            cursor.execute("""
                INSERT INTO document_comments 
                (proposal_id, comment_text, created_by, status)
                VALUES (%s, %s, %s, %s)
                RETURNING id, proposal_id, comment_text, created_by, created_at, status
            """, (proposal_id, comment_text, user_id, 'open'))
            
            result = cursor.fetchone()
            comment_id = result['id']

            # Notify proposal owner when a collaborator/guest comments
            try:
<<<<<<< HEAD
                cursor.execute(
                    "SELECT owner_id, title FROM proposals WHERE id = %s",
                    (proposal_id,),
                )
                proposal = cursor.fetchone()
                if proposal and proposal.get('owner_id') and proposal['owner_id'] != user_id:
                    commenter_label = invited_email or 'A collaborator'
                    proposal_title = proposal.get('title') or f"Proposal #{proposal_id}"
                    create_notification(
                        proposal['owner_id'],
=======
                owner_id, proposal_title = _get_proposal_owner_and_title(
                    cursor,
                    proposal_id,
                )
                commenter_label = invited_email or 'A collaborator'
                if owner_id:
                    create_notification(
                        owner_id,
>>>>>>> origin/PSB-215_manager_full_access
                        'proposal_comment_added',
                        'New comment on your proposal',
                        f"{commenter_label} commented on \"{proposal_title}\"",
                        proposal_id=proposal_id,
                        metadata={
                            'comment_id': comment_id,
                            'comment_author_id': user_id,
                            'comment_author_email': invited_email,
                            'proposal_title': proposal_title,
                        },
                    )
            except Exception as notify_error:
                print(f"⚠️ Error notifying proposal owner on guest comment: {notify_error}")

            conn.commit()
            
            return dict(result), 201
            
    except Exception as e:
        print(f"❌ Error adding guest comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.route("/api/comments/document/<int:proposal_id>", methods=['OPTIONS'])
@bp.route("/comments/document/<int:proposal_id>", methods=['OPTIONS'])
def options_comments_document(proposal_id=None):
    """Handle CORS preflight for comments document endpoint"""
    return {}, 200

@bp.post("/api/comments/document/<int:proposal_id>")
@bp.post("/comments/document/<int:proposal_id>")
@token_required
def create_comment(username=None, user_id=None, proposal_id=None):
    """Create a new comment on a document with support for threading and block-level comments"""
    try:
        data = request.get_json() or {}
        comment_text = data.get('comment_text')
        section_index = data.get('section_index')
        section_name = data.get('section_name')
        highlighted_text = data.get('highlighted_text')
        start_offset = data.get('start_offset')
        end_offset = data.get('end_offset')
        parent_id = data.get('parent_id')  # For threaded replies
        block_type = data.get('block_type')  # 'text', 'table', 'image'
        block_id = data.get('block_id')  # Identifier for the block
        
        if not comment_text:
            return {'detail': 'Comment text is required'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Resolve user
            # Prefer user_id injected by token_required (Firebase flow).
            user = None
            if user_id is not None:
                cursor.execute(
                    'SELECT id, email, full_name FROM users WHERE id = %s',
                    (user_id,),
                )
                user = cursor.fetchone()

            if not user:
                cursor.execute(
                    'SELECT id, email, full_name FROM users WHERE username = %s',
                    (username,),
                )
                user = cursor.fetchone()

            if not user:
                return {'detail': 'User not found'}, 404

            user_id = user['id']
<<<<<<< HEAD
            
            cursor.execute('SELECT owner_id, title FROM proposals WHERE id = %s', (proposal_id,))
            proposal_row = cursor.fetchone()
            proposal_title = proposal_row['title'] if proposal_row else f"Proposal {proposal_id}"
=======

            proposal_owner_id, proposal_title = _get_proposal_owner_and_title(
                cursor,
                proposal_id,
            )

            # Best-effort: if offsets aren't provided but highlighted_text is, derive offsets from
            # the current section text so highlights persist for all viewers.
            try:
                if (start_offset is None or end_offset is None) and highlighted_text and section_index is not None:
                    cursor.execute('SELECT content FROM proposals WHERE id = %s', (proposal_id,))
                    content_row = cursor.fetchone() or {}
                    content_val = content_row.get('content')
                    section_text = None
                    if isinstance(content_val, dict):
                        sections = content_val.get('sections')
                        if isinstance(sections, list) and 0 <= int(section_index) < len(sections):
                            sec = sections[int(section_index)]
                            if isinstance(sec, dict):
                                section_text = sec.get('content') or sec.get('text')
                            elif isinstance(sec, str):
                                section_text = sec
                    elif isinstance(content_val, str):
                        try:
                            import json
                            parsed = json.loads(content_val)
                            sections = parsed.get('sections') if isinstance(parsed, dict) else None
                            if isinstance(sections, list) and 0 <= int(section_index) < len(sections):
                                sec = sections[int(section_index)]
                                if isinstance(sec, dict):
                                    section_text = sec.get('content') or sec.get('text')
                                elif isinstance(sec, str):
                                    section_text = sec
                        except Exception:
                            section_text = None

                    if section_text and isinstance(section_text, str):
                        idx = section_text.find(str(highlighted_text))
                        if idx >= 0:
                            start_offset = idx
                            end_offset = idx + len(str(highlighted_text))
            except Exception as e:
                print(f"⚠️ Could not derive comment offsets: {e}")

            if block_id is not None:
                block_id = str(block_id)
>>>>>>> origin/PSB-215_manager_full_access
            
            # Validate parent_id if provided (must exist and belong to same proposal)
            if parent_id:
                cursor.execute("""
                    SELECT id, proposal_id FROM document_comments 
                    WHERE id = %s AND proposal_id = %s
                """, (parent_id, proposal_id))
                parent_comment = cursor.fetchone()
                if not parent_comment:
                    return {'detail': 'Parent comment not found'}, 404
            
            # Create comment - handle sequence issues and missing columns (old DB schema)
            err_msg = None
            try:
                cursor.execute("""
                    INSERT INTO document_comments 
                    (proposal_id, comment_text, created_by, section_index, section_name, 
                     highlighted_text, start_offset, end_offset, parent_id, block_type, block_id, status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id, proposal_id, comment_text, created_by, created_at, 
                              section_index, section_name, highlighted_text, start_offset, end_offset,
                              parent_id, block_type, block_id, status, updated_at
                """, (proposal_id, comment_text, user_id, section_index, section_name, 
                      highlighted_text, start_offset, end_offset, parent_id, block_type, block_id, 'open'))
            except Exception as seq_error:
                err_msg = str(seq_error)
                # If sequence issue, reset it and try again
                if 'duplicate key' in err_msg.lower() or 'pkey' in err_msg.lower():
                    print(f"⚠️ Sequence issue detected, resetting sequence for document_comments")
                    cursor.execute("""
                        SELECT setval(pg_get_serial_sequence('document_comments', 'id'), 
                                     COALESCE((SELECT MAX(id) FROM document_comments), 1), true)
                    """)
                    conn.commit()
                    cursor.execute("""
                        INSERT INTO document_comments 
                        (proposal_id, comment_text, created_by, section_index, section_name, 
                         highlighted_text, start_offset, end_offset, parent_id, block_type, block_id, status)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        RETURNING id, proposal_id, comment_text, created_by, created_at, 
                                  section_index, section_name, highlighted_text, start_offset, end_offset,
                                  parent_id, block_type, block_id, status, updated_at
                    """, (proposal_id, comment_text, user_id, section_index, section_name, 
                          highlighted_text, start_offset, end_offset, parent_id, block_type, block_id, 'open'))
                else:
                    raise
            
            result = cursor.fetchone()
            comment_id = result['id']
            conn.commit()
            
            # Process @mentions in comment text
            try:
                from app import process_mentions
                process_mentions(comment_id, comment_text, user_id, proposal_id)
            except Exception as e:
                print(f"⚠️ Error processing mentions: {e}")
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id, 
                    user_id, 
                    'comment_added',
                    f'Added a comment{(" on " + section_name) if section_name else ""}',
                    {'comment_id': comment_id, 'parent_id': parent_id}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")

<<<<<<< HEAD
            # Notify proposal owner when someone else comments on their proposal
            try:
                proposal_owner_id = proposal_row.get('owner_id') if proposal_row else None
                if proposal_owner_id and proposal_owner_id != user_id:
                    commenter_name = user.get('full_name') or user.get('email') or username or 'Someone'
                    create_notification(
                        proposal_owner_id,
                        'proposal_comment_added',
                        'New comment on your proposal',
                        f"{commenter_name} commented on \"{proposal_title}\"",
=======
            # Notify all proposal participants (owner/collaborators/comment participants)
            try:
                commenter_name = user.get('full_name') or user.get('email') or username or 'Someone'
                is_reply = bool(parent_id)
                notification_title = (
                    'New reply on proposal comment' if is_reply else 'New comment on your proposal'
                )
                notification_message = (
                    f"{commenter_name} replied on \"{proposal_title}\""
                    if is_reply
                    else f"{commenter_name} commented on \"{proposal_title}\""
                )
                notification_type = 'proposal_comment_replied' if is_reply else 'proposal_comment_added'

                recipient_ids = _get_comment_notification_recipients(
                    cursor, proposal_id=proposal_id, actor_user_id=user_id
                )
                for recipient_id in recipient_ids:
                    create_notification(
                        recipient_id,
                        notification_type,
                        notification_title,
                        notification_message,
>>>>>>> origin/PSB-215_manager_full_access
                        proposal_id=proposal_id,
                        metadata={
                            'comment_id': comment_id,
                            'comment_author_id': user_id,
                            'proposal_title': proposal_title,
                            'parent_id': parent_id,
                        },
                    )
            except Exception as notify_error:
<<<<<<< HEAD
                print(f"⚠️ Error notifying proposal owner on comment: {notify_error}")
=======
                print(f"⚠️ Error notifying participants on comment: {notify_error}")
>>>>>>> origin/PSB-215_manager_full_access
            
            return dict(result), 201
            
    except Exception as e:
        print(f"❌ Error creating comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/comments/document/<int:proposal_id>")
@bp.get("/comments/document/<int:proposal_id>")
@token_required
def get_document_comments(username=None, user_id=None, proposal_id=None):
    """Get all comments for a document with threaded structure and reactions"""
    try:
        section_id = request.args.get('section_id', type=int)
        block_id = request.args.get('block_id')
        block_type = request.args.get('block_type')
        status_filter = request.args.get('status')  # 'open', 'resolved', or None for all
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Resolve user_id if not from token (legacy username flow)
            current_user_id = user_id
            if current_user_id is None and username:
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                u = cursor.fetchone()
                current_user_id = u['id'] if u else None
            
            # Build WHERE clause
            where_clauses = ['dc.proposal_id = %s']
            params = [proposal_id]
            
            if section_id is not None:
                where_clauses.append('dc.section_index = %s')
                params.append(section_id)
            
            if block_id:
                where_clauses.append('dc.block_id = %s')
                params.append(block_id)
                if block_type:
                    where_clauses.append('dc.block_type = %s')
                    params.append(block_type)
            
            if status_filter:
                where_clauses.append('dc.status = %s')
                params.append(status_filter)
            
            where_sql = ' AND '.join(where_clauses)
            
            cursor.execute(f"""
                SELECT dc.id, dc.comment_text, dc.created_at, dc.created_by,
                       dc.section_index, dc.section_name, dc.highlighted_text,
                       dc.start_offset, dc.end_offset,
                       dc.status, dc.parent_id, dc.block_type, dc.block_id,
                       dc.resolved_by, dc.resolved_at, dc.updated_at,
                       u.full_name as author_name, u.email as author_email, u.username as author_username, u.role as author_role,
                       ru.full_name as resolver_name
                FROM document_comments dc
                LEFT JOIN users u ON dc.created_by = u.id
                LEFT JOIN users ru ON dc.resolved_by = ru.id
                WHERE {where_sql}
                ORDER BY dc.created_at ASC
            """, tuple(params))
            
            comments = cursor.fetchall()
            comment_ids = [c['id'] for c in comments]
            
            # Fetch reactions for all comments (table may not exist on old DBs)
            reactions_by_comment = {}
            if comment_ids:
                try:
                    placeholders = ','.join(['%s'] * len(comment_ids))
                    cursor.execute(f"""
                        SELECT cr.comment_id, cr.emoji, cr.user_id, u.full_name as reactor_name
                        FROM comment_reactions cr
                        LEFT JOIN users u ON cr.user_id = u.id
                        WHERE cr.comment_id IN ({placeholders})
                    """, tuple(comment_ids))
                    for row in cursor.fetchall():
                        cid = row['comment_id']
                        if cid not in reactions_by_comment:
                            reactions_by_comment[cid] = {}
                        emoji = row['emoji']
                        if emoji not in reactions_by_comment[cid]:
                            reactions_by_comment[cid][emoji] = {'user_ids': [], 'reactor_names': []}
                        reactions_by_comment[cid][emoji]['user_ids'].append(row['user_id'])
                        name = row['reactor_name'] or f"User #{row['user_id']}"
                        reactions_by_comment[cid][emoji]['reactor_names'].append(name)
                except Exception as re:
                    print(f"⚠️ Could not fetch reactions (table may not exist): {re}")
            
            # Build threaded structure (parent comments with nested replies)
            comments_dict = {}
            root_comments = []
            
            for comment in comments:
                comment_dict = dict(comment)
                comment_dict['replies'] = []
                # Add reactions as list of {emoji, count, user_ids, reactor_names, reacted_by_me}
                raw_reactions = reactions_by_comment.get(comment['id'], {})
                comment_dict['reactions'] = []
                for emoji, data in raw_reactions.items():
                    user_ids = data['user_ids']
                    reactor_names = data['reactor_names']
                    reacted_by_me = current_user_id in user_ids if current_user_id else False
                    comment_dict['reactions'].append({
                        'emoji': emoji,
                        'count': len(user_ids),
                        'user_ids': user_ids,
                        'reactor_names': reactor_names,
                        'reacted_by_me': reacted_by_me,
                    })
                comments_dict[comment['id']] = comment_dict
                
                if comment['parent_id']:
                    # This is a reply - add to parent's replies
                    if comment['parent_id'] in comments_dict:
                        comments_dict[comment['parent_id']]['replies'].append(comment_dict)
                else:
                    # This is a root comment
                    root_comments.append(comment_dict)
            
            # Sort root comments by created_at DESC (newest first)
            root_comments.sort(key=lambda x: x['created_at'], reverse=True)
            
            return {
                'comments': root_comments,
                'total': len(comments),
                'open_count': sum(1 for c in comments if c['status'] == 'open'),
                'resolved_count': sum(1 for c in comments if c['status'] == 'resolved')
            }, 200
            
    except Exception as e:
        print(f"❌ Error getting document comments: {e}")
        traceback.print_exc()
        # Return empty structure so UI can still load (e.g. table missing columns)
        return {
            'comments': [],
            'total': 0,
            'open_count': 0,
            'resolved_count': 0,
        }, 200

@bp.post("/comments/<int:comment_id>/reactions")
@bp.post("/api/comments/<int:comment_id>/reactions")
@token_required
def toggle_comment_reaction(username=None, user_id=None, comment_id=None):
    """Add or remove an emoji reaction on a comment (toggle)"""
    try:
        data = request.get_json() or {}
        emoji = (data.get('emoji') or '').strip()
        if not emoji or len(emoji) > 20:
            return {'detail': 'Valid emoji required (1-20 chars)'}, 400
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Resolve user_id
            current_user_id = user_id
            if current_user_id is None and username:
                cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
                u = cursor.fetchone()
                current_user_id = u['id'] if u else None
            
            if not current_user_id:
                return {'detail': 'User not found'}, 404
            
            # Verify comment exists and user has access (same proposal)
            cursor.execute("""
                SELECT id, proposal_id FROM document_comments WHERE id = %s
            """, (comment_id,))
            comment = cursor.fetchone()
            if not comment:
                return {'detail': 'Comment not found'}, 404
            
            # Check if reaction exists
            cursor.execute("""
                SELECT id FROM comment_reactions
                WHERE comment_id = %s AND user_id = %s AND emoji = %s
            """, (comment_id, current_user_id, emoji))
            existing = cursor.fetchone()
            
            if existing:
                # Remove reaction
                cursor.execute("""
                    DELETE FROM comment_reactions
                    WHERE comment_id = %s AND user_id = %s AND emoji = %s
                """, (comment_id, current_user_id, emoji))
                conn.commit()
                return {'action': 'removed', 'emoji': emoji}, 200
            else:
                # Add reaction
                cursor.execute("""
                    INSERT INTO comment_reactions (comment_id, user_id, emoji)
                    VALUES (%s, %s, %s)
                """, (comment_id, current_user_id, emoji))

                # Notify original comment author when someone reacts
                try:
                    cursor.execute("""
                        SELECT dc.created_by, dc.proposal_id, p.title AS proposal_title
                        FROM document_comments dc
                        LEFT JOIN proposals p ON p.id = dc.proposal_id
                        WHERE dc.id = %s
                    """, (comment_id,))
                    comment_owner = cursor.fetchone()

                    if comment_owner and comment_owner.get('created_by') and comment_owner['created_by'] != current_user_id:
                        cursor.execute(
                            "SELECT full_name, email FROM users WHERE id = %s",
                            (current_user_id,),
                        )
                        reactor = cursor.fetchone()
                        reactor_name = (
                            (reactor.get('full_name') if reactor else None)
                            or (reactor.get('email') if reactor else None)
                            or username
                            or 'Someone'
                        )
                        proposal_title = comment_owner.get('proposal_title') or f"Proposal #{comment_owner.get('proposal_id')}"
                        create_notification(
                            comment_owner['created_by'],
                            'comment_reaction_added',
                            'New reaction to your comment',
                            f"{reactor_name} reacted {emoji} to your comment on \"{proposal_title}\"",
                            proposal_id=comment_owner.get('proposal_id'),
                            metadata={
                                'comment_id': comment_id,
                                'emoji': emoji,
                                'reacted_by': current_user_id,
                                'proposal_title': proposal_title,
                            },
                        )
                except Exception as notify_error:
                    print(f"⚠️ Error notifying comment author on reaction: {notify_error}")

                conn.commit()
                return {'action': 'added', 'emoji': emoji}, 200
            
    except Exception as e:
        print(f"❌ Error toggling comment reaction: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500


@bp.patch("/api/comments/<int:comment_id>/resolve")
@token_required
def resolve_comment(username=None, comment_id=None):
    """Mark a comment and all its replies as resolved"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute('SELECT id, full_name FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user['id']
            
            # Get comment and check permissions
            cursor.execute("""
                SELECT id, proposal_id, status, parent_id
                FROM document_comments 
                WHERE id = %s
            """, (comment_id,))
            
            comment = cursor.fetchone()
            if not comment:
                return {'detail': 'Comment not found'}, 404
            
            if comment['status'] == 'resolved':
                return {'detail': 'Comment is already resolved'}, 400
            
            proposal_id = comment['proposal_id']
            
            # Resolve comment and all its replies recursively
            def resolve_comment_and_replies(cid):
                # Mark this comment as resolved
                cursor.execute("""
                    UPDATE document_comments
                    SET status = 'resolved', resolved_by = %s, resolved_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
                    WHERE id = %s
                """, (user_id, cid))
                
                # Get all replies to this comment
                cursor.execute("""
                    SELECT id FROM document_comments
                    WHERE parent_id = %s AND status = 'open'
                """, (cid,))
                
                replies = cursor.fetchall()
                for reply in replies:
                    resolve_comment_and_replies(reply['id'])
            
            resolve_comment_and_replies(comment_id)
            conn.commit()
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id,
                    user_id,
                    'comment_resolved',
                    f'Resolved comment #{comment_id}',
                    {'comment_id': comment_id}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return {'message': 'Comment resolved successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error resolving comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.patch("/api/comments/<int:comment_id>/reopen")
@token_required
def reopen_comment(username=None, comment_id=None):
    """Reopen a resolved comment"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get user ID
            cursor.execute('SELECT id FROM users WHERE username = %s', (username,))
            user = cursor.fetchone()
            
            if not user:
                return {'detail': 'User not found'}, 404
            
            user_id = user['id']
            
            # Get comment
            cursor.execute("""
                SELECT id, proposal_id, status
                FROM document_comments 
                WHERE id = %s
            """, (comment_id,))
            
            comment = cursor.fetchone()
            if not comment:
                return {'detail': 'Comment not found'}, 404
            
            if comment['status'] != 'resolved':
                return {'detail': 'Comment is not resolved'}, 400
            
            proposal_id = comment['proposal_id']
            
            # Reopen comment (does not reopen replies - they stay resolved)
            cursor.execute("""
                UPDATE document_comments
                SET status = 'open', resolved_by = NULL, resolved_at = NULL, updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (comment_id,))
            
            conn.commit()
            
            # Log activity
            try:
                from app import log_activity
                log_activity(
                    proposal_id,
                    user_id,
                    'comment_reopened',
                    f'Reopened comment #{comment_id}',
                    {'comment_id': comment_id}
                )
            except Exception as e:
                print(f"⚠️ Error logging activity: {e}")
            
            return {'message': 'Comment reopened successfully'}, 200
            
    except Exception as e:
        print(f"❌ Error reopening comment: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500

@bp.get("/api/users/search")
@token_required
def search_users(username=None):
    """Search users for @mention autocomplete"""
    try:
        query = request.args.get('q', '').strip()
        limit = request.args.get('limit', 10, type=int)
        
        if not query or len(query) < 2:
            return {'users': []}, 200
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Search users by username, email, or full_name
            search_pattern = f'%{query}%'
            cursor.execute("""
                SELECT id, username, email, full_name, role
                FROM users
                WHERE is_active = true 
                  AND (
                    username ILIKE %s 
                    OR email ILIKE %s 
                    OR full_name ILIKE %s
                  )
                ORDER BY 
                  CASE 
                    WHEN username ILIKE %s THEN 1
                    WHEN full_name ILIKE %s THEN 2
                    ELSE 3
                  END,
                  username
                LIMIT %s
            """, (search_pattern, search_pattern, search_pattern, f'{query}%', f'{query}%', limit))
            
            users = cursor.fetchall()
            
            return {
                'users': [
                    {
                        'id': u['id'],
                        'username': u['username'],
                        'email': u['email'],
                        'role': u.get('role'),
                        'mention_key': (
                            f"{u['username']}-{(u.get('role') or '').strip().lower().replace(' ', '_')}"
                            if (u.get('role') or '').strip()
                            else u['username']
                        ),
                        'full_name': u['full_name'] or u['username'],
                        'display_name': u['full_name'] or u['username']
                    }
                    for u in users
                ]
            }, 200
            
    except Exception as e:
        print(f"❌ Error searching users: {e}")
        traceback.print_exc()
        return {'detail': str(e)}, 500
