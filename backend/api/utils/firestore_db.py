"""
Firestore database utilities
Provides Firestore operations compatible with existing PostgreSQL structure
"""
import os
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from typing import Optional, Dict, List, Any, Union
from contextlib import contextmanager
import json

# Initialize Firestore client
_db_client = None

def get_firestore_client():
    """Get or create Firestore client"""
    global _db_client
    
    if _db_client is not None:
        return _db_client
    
    # Initialize Firebase Admin SDK if not already initialized
    try:
        firebase_admin.get_app()
    except ValueError:
        # Initialize Firebase Admin SDK
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        if not cred_path:
            backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
            default_path = os.path.join(backend_dir, 'firebase-service-account.json')
            if os.path.exists(default_path):
                cred_path = default_path
        
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            print(f"[OK] Firebase Admin SDK initialized from: {cred_path}")
        else:
            # Try environment variable
            service_account_json = os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON')
            if service_account_json:
                import json
                cred_info = json.loads(service_account_json)
                cred = credentials.Certificate(cred_info)
                firebase_admin.initialize_app(cred)
                print("[OK] Firebase Admin SDK initialized from environment variable")
            else:
                raise Exception("Firebase credentials not found. Set FIREBASE_CREDENTIALS_PATH or FIREBASE_SERVICE_ACCOUNT_JSON")
    
    _db_client = firestore.client()
    print("[OK] Firestore client initialized")
    return _db_client


def timestamp_now():
    """Get current timestamp"""
    return firestore.SERVER_TIMESTAMP


def to_dict(doc_snapshot):
    """Convert Firestore document snapshot to dict"""
    if not doc_snapshot.exists:
        return None
    data = doc_snapshot.to_dict()
    data['id'] = doc_snapshot.id
    return data


def to_dict_list(query_snapshot):
    """Convert Firestore query snapshot to list of dicts"""
    return [to_dict(doc) for doc in query_snapshot]


# Collection references
def users_collection():
    """Get users collection reference"""
    return get_firestore_client().collection('users')

def proposals_collection():
    """Get proposals collection reference"""
    return get_firestore_client().collection('proposals')

def clients_collection():
    """Get clients collection reference"""
    return get_firestore_client().collection('clients')

def content_collection():
    """Get content collection reference"""
    return get_firestore_client().collection('content')

def settings_collection():
    """Get settings collection reference"""
    return get_firestore_client().collection('settings')

def notifications_collection():
    """Get notifications collection reference"""
    return get_firestore_client().collection('notifications')

def client_invitations_collection():
    """Get client invitations collection reference"""
    return get_firestore_client().collection('client_invitations')

def verification_events_collection():
    """Get verification events collection reference"""
    return get_firestore_client().collection('verification_events')


# ============================================================================
# USERS OPERATIONS
# ============================================================================

def create_user(user_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new user document"""
    users_ref = users_collection()
    user_id = user_data.get('id') or user_data.get('uid')
    
    if not user_id:
        raise ValueError("User ID (id or uid) is required")
    
    # Prepare user data
    user_doc = {
        'username': user_data.get('username'),
        'email': user_data.get('email'),
        'password_hash': user_data.get('password_hash', ''),
        'full_name': user_data.get('full_name'),
        'role': user_data.get('role', 'user'),
        'department': user_data.get('department'),
        'is_active': user_data.get('is_active', True),
        'is_email_verified': user_data.get('is_email_verified', True),
        'created_at': timestamp_now(),
        'updated_at': timestamp_now()
    }
    
    users_ref.document(user_id).set(user_doc)
    user_doc['id'] = user_id
    return user_doc


def get_user(user_id: str) -> Optional[Dict[str, Any]]:
    """Get user by ID"""
    doc = users_collection().document(user_id).get()
    return to_dict(doc)


def get_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    """Get user by email"""
    query = users_collection().where('email', '==', email).limit(1)
    docs = query.stream()
    for doc in docs:
        return to_dict(doc)
    return None


def get_user_by_username(username: str) -> Optional[Dict[str, Any]]:
    """Get user by username"""
    query = users_collection().where('username', '==', username).limit(1)
    docs = query.stream()
    for doc in docs:
        return to_dict(doc)
    return None


def update_user(user_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
    """Update user document"""
    updates['updated_at'] = timestamp_now()
    users_collection().document(user_id).update(updates)
    return get_user(user_id)


# ============================================================================
# PROPOSALS OPERATIONS
# ============================================================================

def create_proposal(proposal_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new proposal"""
    proposals_ref = proposals_collection()
    doc_ref = proposals_ref.document()
    
    proposal_doc = {
        'title': proposal_data.get('title'),
        'client': proposal_data.get('client'),
        'owner_id': proposal_data.get('owner_id'),
        'status': proposal_data.get('status', 'Draft'),
        'created_at': timestamp_now(),
        'updated_at': timestamp_now(),
        'template_key': proposal_data.get('template_key'),
        'content': proposal_data.get('content'),
        'sections': proposal_data.get('sections'),
        'pdf_url': proposal_data.get('pdf_url'),
        'client_can_edit': proposal_data.get('client_can_edit', False)
    }
    
    doc_ref.set(proposal_doc)
    proposal_doc['id'] = doc_ref.id
    return proposal_doc


def get_proposal(proposal_id: str) -> Optional[Dict[str, Any]]:
    """Get proposal by ID"""
    doc = proposals_collection().document(proposal_id).get()
    return to_dict(doc)


def get_proposals_by_owner(owner_id: str, limit: int = 100) -> List[Dict[str, Any]]:
    """Get proposals by owner ID"""
    query = proposals_collection().where('owner_id', '==', owner_id).order_by('created_at', direction=firestore.Query.DESCENDING).limit(limit)
    return to_dict_list(query.stream())


def get_proposals_by_status(status: str, limit: int = 100) -> List[Dict[str, Any]]:
    """Get proposals by status"""
    query = proposals_collection().where('status', '==', status).order_by('created_at', direction=firestore.Query.DESCENDING).limit(limit)
    return to_dict_list(query.stream())


def update_proposal(proposal_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
    """Update proposal document"""
    updates['updated_at'] = timestamp_now()
    proposals_collection().document(proposal_id).update(updates)
    return get_proposal(proposal_id)


def delete_proposal(proposal_id: str) -> bool:
    """Delete proposal and all subcollections"""
    proposal_ref = proposals_collection().document(proposal_id)
    
    # Delete subcollections
    subcollections = ['versions', 'comments', 'collaborations', 'suggestions', 'locks', 'activity', 'signatures']
    for subcol in subcollections:
        subcol_ref = proposal_ref.collection(subcol)
        batch = get_firestore_client().batch()
        count = 0
        for doc in subcol_ref.stream():
            batch.delete(doc.reference)
            count += 1
            if count == 500:  # Firestore batch limit
                batch.commit()
                batch = get_firestore_client().batch()
                count = 0
        if count > 0:
            batch.commit()
    
    # Delete proposal
    proposal_ref.delete()
    return True


# ============================================================================
# PROPOSAL SUBCOLLECTIONS
# ============================================================================

def create_proposal_version(proposal_id: str, version_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a proposal version"""
    versions_ref = proposals_collection().document(proposal_id).collection('versions')
    doc_ref = versions_ref.document()
    
    version_doc = {
        'proposal_id': proposal_id,
        'version_number': version_data.get('version_number'),
        'content': version_data.get('content'),
        'created_at': timestamp_now(),
        'created_by': version_data.get('created_by')
    }
    
    doc_ref.set(version_doc)
    version_doc['id'] = doc_ref.id
    return version_doc


def get_proposal_versions(proposal_id: str) -> List[Dict[str, Any]]:
    """Get all versions for a proposal"""
    versions_ref = proposals_collection().document(proposal_id).collection('versions')
    query = versions_ref.order_by('version_number', direction=firestore.Query.DESCENDING)
    return to_dict_list(query.stream())


def create_document_comment(proposal_id: str, comment_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a document comment"""
    comments_ref = proposals_collection().document(proposal_id).collection('comments')
    doc_ref = comments_ref.document()
    
    comment_doc = {
        'proposal_id': proposal_id,
        'comment_text': comment_data.get('comment_text'),
        'created_by': comment_data.get('created_by'),
        'created_at': timestamp_now(),
        'section_index': comment_data.get('section_index'),
        'highlighted_text': comment_data.get('highlighted_text'),
        'status': comment_data.get('status', 'open'),
        'updated_at': timestamp_now(),
        'resolved_by': comment_data.get('resolved_by'),
        'resolved_at': comment_data.get('resolved_at')
    }
    
    doc_ref.set(comment_doc)
    comment_doc['id'] = doc_ref.id
    return comment_doc


def get_proposal_comments(proposal_id: str) -> List[Dict[str, Any]]:
    """Get all comments for a proposal"""
    comments_ref = proposals_collection().document(proposal_id).collection('comments')
    query = comments_ref.order_by('created_at', direction=firestore.Query.DESCENDING)
    return to_dict_list(query.stream())


# ============================================================================
# CLIENTS OPERATIONS
# ============================================================================

def create_client(client_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new client"""
    clients_ref = clients_collection()
    doc_ref = clients_ref.document()
    
    client_doc = {
        'company_name': client_data.get('company_name'),
        'contact_person': client_data.get('contact_person'),
        'email': client_data.get('email'),
        'phone': client_data.get('phone'),
        'industry': client_data.get('industry'),
        'company_size': client_data.get('company_size'),
        'location': client_data.get('location'),
        'business_type': client_data.get('business_type'),
        'project_needs': client_data.get('project_needs'),
        'budget_range': client_data.get('budget_range'),
        'timeline': client_data.get('timeline'),
        'additional_info': client_data.get('additional_info'),
        'status': client_data.get('status', 'active'),
        'onboarding_token': client_data.get('onboarding_token'),
        'created_by': client_data.get('created_by'),
        'created_at': timestamp_now(),
        'updated_at': timestamp_now()
    }
    
    doc_ref.set(client_doc)
    client_doc['id'] = doc_ref.id
    return client_doc


def get_client(client_id: str) -> Optional[Dict[str, Any]]:
    """Get client by ID"""
    doc = clients_collection().document(client_id).get()
    return to_dict(doc)


def get_client_by_email(email: str) -> Optional[Dict[str, Any]]:
    """Get client by email"""
    query = clients_collection().where('email', '==', email).limit(1)
    docs = query.stream()
    for doc in docs:
        return to_dict(doc)
    return None


def get_all_clients(limit: int = 100) -> List[Dict[str, Any]]:
    """Get all clients"""
    query = clients_collection().order_by('created_at', direction=firestore.Query.DESCENDING).limit(limit)
    return to_dict_list(query.stream())


def update_client(client_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
    """Update client document"""
    updates['updated_at'] = timestamp_now()
    clients_collection().document(client_id).update(updates)
    return get_client(client_id)


def delete_client(client_id: str) -> bool:
    """Delete client document"""
    clients_collection().document(client_id).delete()
    return True


# ============================================================================
# CONTENT OPERATIONS
# ============================================================================

def create_content(content_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create content library item"""
    content_ref = content_collection()
    key = content_data.get('key')
    
    if not key:
        raise ValueError("Content key is required")
    
    content_doc = {
        'key': key,
        'label': content_data.get('label'),
        'content': content_data.get('content'),
        'category': content_data.get('category', 'Templates'),
        'is_folder': content_data.get('is_folder', False),
        'parent_id': content_data.get('parent_id'),
        'public_id': content_data.get('public_id'),
        'created_at': timestamp_now(),
        'updated_at': timestamp_now(),
        'is_deleted': content_data.get('is_deleted', False)
    }
    
    content_ref.document(key).set(content_doc)
    content_doc['id'] = key
    return content_doc


def get_content(key: str) -> Optional[Dict[str, Any]]:
    """Get content by key"""
    doc = content_collection().document(key).get()
    return to_dict(doc)


def get_content_by_category(category: str) -> List[Dict[str, Any]]:
    """Get content by category"""
    query = content_collection().where('category', '==', category).where('is_deleted', '==', False)
    return to_dict_list(query.stream())


def get_all_content(include_deleted: bool = False) -> List[Dict[str, Any]]:
    """Get all content items"""
    if include_deleted:
        query = content_collection().order_by('created_at', direction=firestore.Query.DESCENDING)
    else:
        query = content_collection().where('is_deleted', '==', False).order_by('created_at', direction=firestore.Query.DESCENDING)
    return to_dict_list(query.stream())


def update_content(key: str, updates: Dict[str, Any]) -> Dict[str, Any]:
    """Update content item"""
    updates['updated_at'] = timestamp_now()
    content_collection().document(key).update(updates)
    return get_content(key)


def delete_content(key: str) -> bool:
    """Soft delete content item"""
    updates = {
        'is_deleted': True,
        'updated_at': timestamp_now()
    }
    content_collection().document(key).update(updates)
    return True


def restore_content(key: str) -> bool:
    """Restore deleted content item"""
    updates = {
        'is_deleted': False,
        'updated_at': timestamp_now()
    }
    content_collection().document(key).update(updates)
    return True


def permanently_delete_content(key: str) -> bool:
    """Permanently delete content item"""
    content_collection().document(key).delete()
    return True


def get_trash_content() -> List[Dict[str, Any]]:
    """Get all deleted content items"""
    query = content_collection().where('is_deleted', '==', True).order_by('created_at', direction=firestore.Query.DESCENDING)
    return to_dict_list(query.stream())


# ============================================================================
# SETTINGS OPERATIONS
# ============================================================================

def get_setting(key: str) -> Optional[Dict[str, Any]]:
    """Get setting by key"""
    doc = settings_collection().document(key).get()
    return to_dict(doc)


def set_setting(key: str, value: Any) -> Dict[str, Any]:
    """Set or update a setting"""
    setting_doc = {
        'key': key,
        'value': value,
        'updated_at': timestamp_now()
    }
    
    # Check if exists
    doc_ref = settings_collection().document(key)
    doc = doc_ref.get()
    
    if not doc.exists:
        setting_doc['created_at'] = timestamp_now()
    
    doc_ref.set(setting_doc)
    setting_doc['id'] = key
    return setting_doc


# ============================================================================
# NOTIFICATIONS OPERATIONS
# ============================================================================

def create_notification(notification_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a notification"""
    notifications_ref = notifications_collection()
    doc_ref = notifications_ref.document()
    
    notification_doc = {
        'user_id': notification_data.get('user_id'),
        'proposal_id': notification_data.get('proposal_id'),
        'notification_type': notification_data.get('notification_type'),
        'title': notification_data.get('title'),
        'message': notification_data.get('message'),
        'metadata': notification_data.get('metadata'),
        'is_read': notification_data.get('is_read', False),
        'created_at': timestamp_now(),
        'read_at': notification_data.get('read_at')
    }
    
    doc_ref.set(notification_doc)
    notification_doc['id'] = doc_ref.id
    return notification_doc


def get_user_notifications(user_id: str, unread_only: bool = False, limit: int = 50) -> List[Dict[str, Any]]:
    """Get notifications for a user"""
    query = notifications_collection().where('user_id', '==', user_id)
    
    if unread_only:
        query = query.where('is_read', '==', False)
    
    query = query.order_by('created_at', direction=firestore.Query.DESCENDING).limit(limit)
    return to_dict_list(query.stream())


def mark_notification_read(notification_id: str) -> Dict[str, Any]:
    """Mark notification as read"""
    updates = {
        'is_read': True,
        'read_at': timestamp_now()
    }
    notifications_collection().document(notification_id).update(updates)
    doc = notifications_collection().document(notification_id).get()
    return to_dict(doc)


def mark_all_notifications_read(user_id: str) -> int:
    """Mark all notifications as read for a user"""
    notifications = get_user_notifications(user_id, unread_only=True, limit=1000)
    count = 0
    
    if not notifications:
        return 0
    
    batch = get_firestore_client().batch()
    for notif in notifications:
        notif_ref = notifications_collection().document(notif['id'])
        batch.update(notif_ref, {
            'is_read': True,
            'read_at': timestamp_now()
        })
        count += 1
        
        # Firestore batch limit is 500
        if count % 500 == 0:
            batch.commit()
            batch = get_firestore_client().batch()
    
    if count % 500 != 0:
        batch.commit()
    
    return count

