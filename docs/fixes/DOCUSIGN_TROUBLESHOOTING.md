# 🔧 DocuSign Troubleshooting Guide

## Quick Fix Applied ✅

The **Account ID issue has been fixed**. The system now extracts `account_id` from DocuSign's JWT response instead of requiring it in `.env`.

## Common Issues & Solutions

### 1. "DocuSign SDK not installed" Error

**Error:**
```
DocuSign SDK not installed
```

**Solution:**
```bash
cd backend
pip install docusign-esign
```

**Verify:**
```python
python -c "from docusign_esign import ApiClient; print('✅ SDK installed')"
```

---

### 2. "DocuSign credentials not configured" Error

**Error:**
```
DOCUSIGN_INTEGRATION_KEY not set in environment variables
DOCUSIGN_USER_ID not set in environment variables
```

**Solution:**
Add to your `.env` file in `backend/`:
```env
DOCUSIGN_INTEGRATION_KEY=your-integration-key
DOCUSIGN_USER_ID=your-user-id
DOCUSIGN_PRIVATE_KEY_PATH=./docusign_private.key
# Optional - will be extracted from JWT if not set
DOCUSIGN_ACCOUNT_ID=your-account-id
```

**How to get credentials:**
1. Go to https://developers.docusign.com/
2. Create/select an Integration
3. Get Integration Key (Client ID)
4. Get User ID (API Username)
5. Generate RSA keypair and upload public key
6. Save private key to `docusign_private.key`

---

### 3. "Private key file not found" Error

**Error:**
```
DocuSign private key file not found: ./docusign_private.key
```

**Solution:**
1. Place your private key file at `backend/docusign_private.key`
2. Or set `DOCUSIGN_PRIVATE_KEY_PATH` in `.env` to point to your key file
3. Or set `DOCUSIGN_PRIVATE_KEY` in `.env` with the key content (use `\n` for newlines)

**Key format should be:**
```
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

---

### 4. "Consent required" Error

**Error:**
```
DocuSign consent required
```

**Solution:**
1. Visit the consent URL provided in the error message
2. Log in with your DocuSign account
3. Grant consent for the integration
4. Try again

**Manual consent URL format:**
```
https://account-d.docusign.com/oauth/auth?response_type=code&scope=signature%20impersonation&client_id=YOUR_INTEGRATION_KEY&redirect_uri=https://www.docusign.com
```

---

### 5. "Account ID" Error (FIXED ✅)

**Error (OLD):**
```
Invalid value specified for accountId
DOCUSIGN_ACCOUNT_ID is required
```

**Status:** ✅ **FIXED** - Account ID is now extracted from JWT response automatically.

**If you still see this error:**
1. Check backend logs for: `✅ DocuSign authentication successful` and `Account ID: [UUID]`
2. If Account ID is not shown, the JWT response might not include accounts array
3. Fallback: Set `DOCUSIGN_ACCOUNT_ID` in `.env` as temporary workaround

---

### 6. "Could not determine DocuSign Account ID" Error

**Error:**
```
Could not determine DocuSign Account ID from JWT response
```

**Possible causes:**
1. JWT response doesn't include `accounts` array
2. User doesn't have access to any accounts
3. Integration key doesn't have proper permissions

**Solution:**
1. Check DocuSign integration settings
2. Ensure integration has "signature" and "impersonation" scopes
3. Verify user has access to at least one account
4. Set `DOCUSIGN_ACCOUNT_ID` in `.env` as fallback

---

### 7. "Failed to create envelope" Error

**Error:**
```
DocuSign API error: [error details]
```

**Common causes:**
1. Invalid signer email format
2. PDF generation failed
3. Network/connectivity issues
4. DocuSign API rate limits

**Solution:**
1. Check signer email is valid format
2. Verify PDF generation works: `generate_proposal_pdf()` returns valid bytes
3. Check network connectivity to DocuSign API
4. Review DocuSign API error message for specific issue

---

### 8. Frontend: "DocuSign send failed" Error

**Error in browser console:**
```
DocuSign send failed: 500 - [error message]
```

**Solution:**
1. Check backend logs for detailed error
2. Verify backend is running and accessible
3. Check authentication token is valid
4. Verify proposal exists and user has permission

---

## Diagnostic Steps

### Step 1: Check SDK Installation
```bash
cd backend
python -c "from docusign_esign import ApiClient; print('✅ SDK OK')"
```

### Step 2: Check Environment Variables
```bash
cd backend
python test_docusign_fix.py
```

### Step 3: Test JWT Authentication
```python
from api.utils.docusign_utils import get_docusign_jwt_token
auth_data = get_docusign_jwt_token()
print(f"Token: {auth_data['access_token'][:30]}...")
print(f"Account ID: {auth_data['account_id']}")
```

### Step 4: Test Envelope Creation
```bash
# Use the API endpoint
POST /api/proposals/{id}/docusign/send
{
  "signer_name": "Test User",
  "signer_email": "test@example.com",
  "return_url": "http://localhost:8081"
}
```

---

## Expected Log Output (When Working)

When DocuSign is working correctly, you should see:

```
🔐 Authenticating with DocuSign...
   Integration Key: abc12345...xyz9
   User ID: user@example.com
   Auth Server: account-d.docusign.com
✅ DocuSign authentication successful
   Account ID: 12345678-1234-1234-1234-123456789abc
   Account Name: My Account
ℹ️  Using account_id from JWT response: 12345678-1234-1234-1234-123456789abc
✅ DocuSign envelope created: abc123-def456-ghi789
✅ Redirect signing URL created (works on HTTP)
```

---

## Quick Test Script

Run this to test the fix:

```bash
cd backend
python test_docusign_fix.py
```

This will check:
- ✅ SDK installation
- ✅ Environment variables
- ✅ Private key file
- ✅ JWT authentication
- ✅ Account ID extraction

---

## Still Not Working?

If DocuSign still doesn't work after checking all above:

1. **Check backend logs** - Look for detailed error messages
2. **Verify credentials** - Double-check all DocuSign credentials are correct
3. **Test JWT manually** - Use the test script to isolate the issue
4. **Check DocuSign dashboard** - Verify integration is active and has consent
5. **Review error details** - The specific error message will indicate the exact problem

---

## Files Modified (Fix Applied)

1. ✅ `backend/api/utils/docusign_utils.py` - Extracts account_id from JWT
2. ✅ `backend/api/utils/helpers.py` - Uses account_id from JWT
3. ✅ `backend/app.py` - Updated to use utils version
4. ✅ `tests/integration/backend/test_proposal_signing.py` - Updated test

---

**Last Updated:** After Account ID fix
**Status:** Account ID extraction fixed - other issues may require credential configuration
