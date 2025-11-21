"""
Authentication utilities - token management and password hashing
"""
import os
import json
import secrets
from datetime import datetime, timedelta
from werkzeug.security import generate_password_hash, check_password_hash

# Token storage (in production, use Redis or session manager)
# File-based persistence to survive restarts
TOKEN_FILE = os.path.join(os.path.dirname(__file__), '..', '..', 'auth_tokens.json')


def load_tokens():
    """Load tokens from file"""
    try:
        if os.path.exists(TOKEN_FILE):
            with open(TOKEN_FILE, 'r', encoding='utf-8') as token_file:
                data = json.load(token_file)
                # Convert string timestamps back to datetime objects
                for token, token_data in data.items():
                    token_data['created_at'] = datetime.fromisoformat(token_data['created_at'])
                    token_data['expires_at'] = datetime.fromisoformat(token_data['expires_at'])
                print(f"[INFO] Loaded {len(data)} tokens from file")
                return data
    except Exception as exc:
        print(f"[WARN] Could not load tokens from file: {exc}")
    return {}


def save_tokens(valid_tokens):
    """Save tokens to file"""
    try:
        # Convert datetime objects to strings for JSON serialization
        data = {}
        for token, token_data in valid_tokens.items():
            data[token] = {
                'username': token_data['username'],
                'created_at': token_data['created_at'].isoformat(),
                'expires_at': token_data['expires_at'].isoformat(),
            }
        with open(TOKEN_FILE, 'w', encoding='utf-8') as token_file:
            json.dump(data, token_file, indent=2)
        print(f"[INFO] Saved {len(data)} tokens to file")
    except Exception as exc:
        print(f"[WARN] Could not save tokens to file: {exc}")


# Global token storage
valid_tokens = load_tokens()


def hash_password(password):
    """Hash a password using werkzeug"""
    return generate_password_hash(password)


def verify_password(stored_hash, password):
    """Verify a password against a stored hash"""
    return check_password_hash(stored_hash, password)


def generate_token(username):
    """Generate a new authentication token for a user"""
    token = secrets.token_urlsafe(32)
    valid_tokens[token] = {
        'username': username,
        'created_at': datetime.now(),
        'expires_at': datetime.now() + timedelta(days=7),
    }
    save_tokens(valid_tokens)  # Persist to file
    print(f"[TOKEN] Generated new token for user '{username}': {token[:20]}...{token[-10:]}")
    print(f"[TOKEN] Total valid tokens: {len(valid_tokens)}")
    return token


def verify_token(token):
    """Verify a token and return the username if valid"""
    # Dev bypass for testing
    if token == 'dev-bypass-token':
        print("[DEV] Using dev-bypass-token for username: admin")
        return 'admin'

    if token not in valid_tokens:
        return None
    token_data = valid_tokens[token]
    if datetime.now() > token_data['expires_at']:
        del valid_tokens[token]
        save_tokens(valid_tokens)  # Persist after deleting expired token
        return None
    return token_data['username']


def get_valid_tokens():
    """Get the current valid tokens dictionary"""
    return valid_tokens











