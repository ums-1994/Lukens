"""
Helper functions for activity logging, notifications, and mentions
"""
import json
import re
import traceback
import psycopg2.extras
from api.utils.database import get_db_connection

def log_activity(proposal_id, user_id, action_type, description, metadata=None):
    """
    Log an activity to the activity timeline
    
    Args:
        proposal_id: ID of the proposal
        user_id: ID of the user performing the action (can be None for system actions)
        action_type: Type of action (e.g., 'comment_added', 'suggestion_created', 'proposal_edited')
        description: Human-readable description of the action
        metadata: Optional dict with additional data
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO activity_log (proposal_id, user_id, action_type, action_description, metadata)
                VALUES (%s, %s, %s, %s, %s)
            """, (proposal_id, user_id, action_type, description, json.dumps(metadata) if metadata else None))
            conn.commit()
    except Exception as e:
        print(f"[WARN] Failed to log activity: {e}")
        # Don't raise - activity logging should not break main functionality

def create_notification(user_id, notification_type, title, message, proposal_id=None, metadata=None):
    """
    Create a notification for a user
    
    Args:
        user_id: ID of the user to notify
        notification_type: Type of notification (e.g., 'comment_added', 'suggestion_created')
        title: Notification title
        message: Notification message
        proposal_id: Optional proposal ID
        metadata: Optional dict with additional data
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO notifications (user_id, proposal_id, notification_type, title, message, metadata)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (user_id, proposal_id, notification_type, title, message, json.dumps(metadata) if metadata else None))
            conn.commit()
            print(f"[OK] Notification created for user {user_id}: {title}")
    except Exception as e:
        print(f"[WARN] Failed to create notification: {e}")
        # Don't raise - notification should not break main functionality

def notify_proposal_collaborators(proposal_id, notification_type, title, message, exclude_user_id=None, metadata=None):
    """
    Notify all collaborators on a proposal
    
    Args:
        proposal_id: ID of the proposal
        notification_type: Type of notification
        title: Notification title
        message: Notification message
        exclude_user_id: Optional user ID to exclude from notifications (e.g., the person who made the change)
        metadata: Optional dict with additional data
    """
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get proposal owner
            cursor.execute("SELECT user_id FROM proposals WHERE id = %s", (proposal_id,))
            proposal = cursor.fetchone()
            if not proposal:
                return
            
            # Get owner's user ID
            cursor.execute("SELECT id FROM users WHERE username = %s", (proposal['user_id'],))
            owner = cursor.fetchone()
            if owner and owner['id'] != exclude_user_id:
                create_notification(owner['id'], notification_type, title, message, proposal_id, metadata)
            
            # Get all collaborators
            cursor.execute("""
                SELECT DISTINCT u.id
                FROM collaboration_invitations ci
                JOIN users u ON ci.invited_email = u.email
                WHERE ci.proposal_id = %s AND ci.status = 'accepted'
            """, (proposal_id,))
            
            collaborators = cursor.fetchall()
            for collab in collaborators:
                if collab['id'] != exclude_user_id:
                    create_notification(collab['id'], notification_type, title, message, proposal_id, metadata)
                    
    except Exception as e:
        print(f"[WARN] Failed to notify collaborators: {e}")

def extract_mentions(text):
    """
    Extract @mentions from text
    Returns list of mentioned usernames/emails
    
    Supports:
    - @username
    - @email@domain.com
    """
    # Pattern to match @username or @email
    pattern = r'@([a-zA-Z0-9_.+-]+(?:@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)?)'
    mentions = re.findall(pattern, text)
    return list(set(mentions))  # Remove duplicates

def process_mentions(comment_id, comment_text, mentioned_by_user_id, proposal_id):
    """
    Process @mentions in a comment
    - Extract mentions from text
    - Find mentioned users
    - Create mention records
    - Send notifications
    
    Args:
        comment_id: ID of the comment containing mentions
        comment_text: Text of the comment
        mentioned_by_user_id: ID of user who created the comment
        proposal_id: ID of the proposal
    """
    try:
        mentions = extract_mentions(comment_text)
        if not mentions:
            return
        
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get the commenter's name
            cursor.execute("SELECT full_name FROM users WHERE id = %s", (mentioned_by_user_id,))
            commenter = cursor.fetchone()
            commenter_name = commenter['full_name'] if commenter else 'Someone'
            
            for mention in mentions:
                # Try to find user by username or email
                cursor.execute("""
                    SELECT id, full_name, email FROM users 
                    WHERE username = %s OR email = %s OR email LIKE %s
                """, (mention, mention, f'{mention}@%'))
                
                mentioned_user = cursor.fetchone()
                if not mentioned_user:
                    print(f"[WARN] Mentioned user not found: @{mention}")
                    continue
                
                # Don't mention yourself
                if mentioned_user['id'] == mentioned_by_user_id:
                    continue
                
                # Create mention record
                cursor.execute("""
                    INSERT INTO comment_mentions 
                    (comment_id, mentioned_user_id, mentioned_by_user_id)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                """, (comment_id, mentioned_user['id'], mentioned_by_user_id))
                
                # Send notification
                create_notification(
                    mentioned_user['id'],
                    'mentioned',
                    'You were mentioned',
                    f"{commenter_name} mentioned you in a comment",
                    proposal_id,
                    {'comment_id': comment_id, 'mentioned_by': mentioned_by_user_id}
                )
                
                print(f"[OK] Notified @{mentioned_user['email']} about mention")
            
            conn.commit()
            
    except Exception as e:
        print(f"[WARN] Failed to process mentions: {e}")
        traceback.print_exc()

