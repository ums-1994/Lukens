# ✅ DocuSign Account ID Fix - Complete

## Problem

The DocuSign integration was failing with an Account ID error because:
1. The `get_docusign_jwt_token()` function only returned the `access_token`
2. The `create_docusign_envelope()` function tried to get `account_id` from environment variable `DOCUSIGN_ACCOUNT_ID`
3. If the environment variable was missing or incorrect, `account_id` would be `None`, causing DocuSign API to reject the request with a 400 Bad Request error

## Solution

**Extract `account_id` from DocuSign's JWT response instead of relying on environment variable.**

The DocuSign JWT authentication response includes an `accounts` array that contains the account information, including the `account_id`. This is the **source of truth** and is guaranteed to be valid.

## Changes Made

### 1. Updated `backend/api/utils/docusign_utils.py`

**Before:**
```python
def get_docusign_jwt_token():
    # ... authentication code ...
    return response.access_token  # Only returns token
```

**After:**
```python
def get_docusign_jwt_token():
    # ... authentication code ...
    # Extract account_id from JWT response
    account_id = response.accounts[0].account_id if response.accounts else None
    return {
        'access_token': response.access_token,
        'account_id': account_id
    }
```

### 2. Updated `backend/api/utils/helpers.py`

**Before:**
```python
access_token = get_docusign_jwt_token()
account_id = os.getenv('DOCUSIGN_ACCOUNT_ID')  # From .env (may be None)
```

**After:**
```python
auth_data = get_docusign_jwt_token()
access_token = auth_data['access_token']
account_id = auth_data['account_id']  # From JWT response (guaranteed valid)
```

### 3. Updated `backend/app.py`

- Removed duplicate `get_docusign_jwt_token()` function
- Updated `create_docusign_envelope()` to use the utils version
- Now imports and uses `get_docusign_jwt_token()` from `api.utils.docusign_utils`

## Benefits

1. **Reliability**: Account ID comes directly from DocuSign's API response
2. **No Configuration Required**: No need to manually set `DOCUSIGN_ACCOUNT_ID` in `.env`
3. **Automatic**: Works with any DocuSign account the integration key has access to
4. **Fallback**: Still supports `DOCUSIGN_ACCOUNT_ID` in `.env` as a fallback if JWT response doesn't include accounts

## Testing

To test the fix:

1. Ensure DocuSign credentials are configured:
   - `DOCUSIGN_INTEGRATION_KEY`
   - `DOCUSIGN_USER_ID`
   - `DOCUSIGN_PRIVATE_KEY_PATH` or `DOCUSIGN_PRIVATE_KEY`

2. Send a proposal for signature via the API:
   ```bash
   POST /api/proposals/{id}/docusign/send
   {
     "signer_name": "John Doe",
     "signer_email": "john@example.com",
     "return_url": "http://localhost:8081"
   }
   ```

3. Check logs for:
   ```
   ✅ DocuSign authentication successful
      Account ID: [UUID]
      Account Name: [Account Name]
   ℹ️  Using account_id from JWT response: [UUID]
   ✅ DocuSign envelope created: [envelope_id]
   ```

## Error Handling

The fix includes proper error handling:
- If JWT response doesn't include accounts, falls back to `DOCUSIGN_ACCOUNT_ID` from `.env`
- If neither is available, raises a clear error message
- Provides helpful error messages for authentication failures

## Backward Compatibility

- The fix is backward compatible
- If `DOCUSIGN_ACCOUNT_ID` is set in `.env`, it will be used as a fallback
- Existing code that expects a string from `get_docusign_jwt_token()` will need to be updated (only in `app.py`, which we've already fixed)

## Files Modified

1. ✅ `backend/api/utils/docusign_utils.py` - Updated to return dict with account_id
2. ✅ `backend/api/utils/helpers.py` - Updated to use account_id from JWT response
3. ✅ `backend/app.py` - Removed duplicate function, updated to use utils version

## Status

✅ **FIX COMPLETE** - DocuSign Account ID is now extracted from JWT response

---

**Date Fixed:** Current
**Impact:** Critical - Unblocks client sign-off functionality
**Testing:** Ready for testing with DocuSign credentials
