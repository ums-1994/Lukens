# 🔐 Token Persistence Fix

## Problem

Users were losing authentication when the backend restarted. Symptoms:
- "Token validation failed" errors
- Cannot invite collaborators
- Need to re-login after every backend restart
- `valid_tokens has 0 tokens` in logs

```
❌ Token validation failed - token not found or expired
📋 Current valid tokens: []...
```

## Root Cause

Authentication tokens were stored in-memory only:
```python
valid_tokens = {}  # Lost on restart!
```

When the Flask backend restarted (due to code changes or server restarts), all active user sessions were lost.

## Solution

Implemented **file-based token persistence** that survives restarts.

### Implementation

#### 1. Token File Storage
```python
TOKEN_FILE = os.path.join(os.path.dirname(__file__), 'auth_tokens.json')
```

#### 2. Load Tokens on Startup
```python
def load_tokens():
    """Load tokens from file"""
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, 'r') as f:
            data = json.load(f)
            # Convert string timestamps back to datetime objects
            for token, token_data in data.items():
                token_data['created_at'] = datetime.fromisoformat(token_data['created_at'])
                token_data['expires_at'] = datetime.fromisoformat(token_data['expires_at'])
            return data
    return {}

valid_tokens = load_tokens()  # Load on startup
```

#### 3. Save Tokens After Changes
```python
def save_tokens():
    """Save tokens to file"""
    data = {}
    for token, token_data in valid_tokens.items():
        data[token] = {
            'username': token_data['username'],
            'created_at': token_data['created_at'].isoformat(),
            'expires_at': token_data['expires_at'].isoformat()
        }
    with open(TOKEN_FILE, 'w') as f:
        json.dump(data, f, indent=2)
```

#### 4. Auto-Save on Token Operations

**When generating new token:**
```python
def generate_token(username):
    token = secrets.token_urlsafe(32)
    valid_tokens[token] = {...}
    save_tokens()  # ✅ Persist immediately
    return token
```

**When removing expired token:**
```python
def verify_token(token):
    if datetime.now() > token_data['expires_at']:
        del valid_tokens[token]
        save_tokens()  # ✅ Persist after cleanup
        return None
```

## Benefits

✅ **Session Persistence**: Tokens survive backend restarts
✅ **Better UX**: Users don't need to re-login constantly
✅ **Development Friendly**: Code changes don't kick out users
✅ **Simple Implementation**: No external dependencies (Redis, etc.)
✅ **Automatic Cleanup**: Expired tokens are automatically removed

## File Structure

```
backend/
  ├── app.py
  └── auth_tokens.json  (auto-generated, gitignored)
```

**auth_tokens.json format:**
```json
{
  "xIIZyL3I4V9i8774...": {
    "username": "user@example.com",
    "created_at": "2025-10-27T17:00:00",
    "expires_at": "2025-11-03T17:00:00"
  }
}
```

## Security Considerations

### Current Implementation (Development)
- ✅ Tokens stored locally
- ✅ File ignored by git (`.gitignore`)
- ✅ 7-day expiration
- ✅ Server-side validation

### Production Recommendations
For production environments, consider upgrading to:
1. **Redis**: Fast, distributed token storage
2. **JWT**: Stateless tokens (no server-side storage needed)
3. **Database**: Store tokens in PostgreSQL with user sessions
4. **Session Manager**: Use Flask-Session or similar

### Rotation & Security
- Tokens expire after 7 days
- Expired tokens automatically removed
- File permissions should be restricted (not world-readable)
- In production, use HTTPS only

## Testing

### Verify the Fix

1. **Login to app**
   ```
   POST /auth/login
   → Receive token
   → Check: auth_tokens.json created
   ```

2. **Restart backend**
   ```bash
   # Stop Flask
   # Start Flask again
   ```

3. **Make authenticated request**
   ```
   GET /api/proposals
   Authorization: Bearer <your_token>
   → Should work! ✅
   ```

4. **Check logs**
   ```
   🔄 Loaded 1 tokens from file
   ✅ Token validated for user: user@example.com
   ```

## Migration Impact

- **Existing users**: Need to login once after this update
- **New users**: Tokens automatically persisted
- **No data loss**: Only affects active sessions
- **No schema changes**: File-based, no database migration

## Files Modified

- ✅ `backend/app.py`
  - Added `load_tokens()` function
  - Added `save_tokens()` function
  - Modified `generate_token()` to save
  - Modified `verify_token()` to save on cleanup
  - Added `TOKEN_FILE` constant

- ✅ `.gitignore`
  - Added `auth_tokens.json` to ignored files

## Rollback

If needed, remove the changes:
```python
# Revert to in-memory only
valid_tokens = {}

def generate_token(username):
    # Remove save_tokens() call
    ...

def verify_token(token):
    # Remove save_tokens() call
    ...
```

## Future Enhancements

- [ ] Token refresh mechanism
- [ ] Logout endpoint to invalidate tokens
- [ ] Token rotation on activity
- [ ] Rate limiting per token
- [ ] IP binding for extra security
- [ ] Multiple device management
- [ ] Redis integration for scale

---

**Status**: ✅ Fixed
**Date**: October 27, 2025
**Impact**: All authenticated users
**Downtime**: None (automatic on next restart)

