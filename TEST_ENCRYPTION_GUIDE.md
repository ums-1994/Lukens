# 🔒 How to Test Proposal Encryption

## ✅ Quick Test Results
The encryption system is **working correctly**! All core functions passed:
- ✅ Encryption/Decryption: **PASS**
- ✅ Token Generation: **PASS**  
- ✅ Password Hashing: **PASS**

## 🧪 Method 1: Run the Test Script

```bash
cd backend
python test_encryption.py
```

This will verify:
- Encryption/decryption works correctly
- Secure tokens are generated
- Password hashing works

## 🎯 Method 2: Test Through the UI (Real Flow)

### Step 1: Create/Find a Proposal
1. Open your Flutter app
2. Go to Proposals page
3. Create a new proposal OR select an existing draft proposal
4. Make sure it has:
   - Title
   - Content (some text)
   - Client email (important!)

### Step 2: Submit for Approval
1. Submit the proposal for approval
2. It should show up in the Approver Dashboard

### Step 3: Approve the Proposal
1. Go to **Approver Dashboard** (`/approver_dashboard`)
2. Find your proposal in the "Pending Approval" list
3. Click **"Approve & Send"**
4. This will:
   - ✅ Encrypt the proposal content automatically
   - ✅ Create a secure access token
   - ✅ Send email to client with secure link
   - ✅ Store encrypted content in database

### Step 4: Check the Database
You can verify encryption worked by checking:

```sql
-- Check if proposal was encrypted
SELECT * FROM encrypted_proposals WHERE proposal_id = YOUR_PROPOSAL_ID;

-- Check access token was created
SELECT * FROM proposal_access_tokens WHERE proposal_id = YOUR_PROPOSAL_ID;

-- Check audit log
SELECT * FROM proposal_access_audit WHERE proposal_id = YOUR_PROPOSAL_ID;
```

### Step 5: Test Client Access
1. Check the email sent to the client
2. Click the secure link (should be like: `/#/secure-proposal?token=...`)
3. The system will:
   - ✅ Validate the token
   - ✅ Decrypt the content
   - ✅ Show the proposal to the client
   - ✅ Log the access

## 🔍 Method 3: Test via API (Using Postman/curl)

### Test Encryption on Approval:
```bash
POST http://localhost:8000/proposals/1/approve
Headers:
  Authorization: Bearer YOUR_TOKEN
```

### Test Secure Access:
```bash
GET http://localhost:8000/api/secure-proposal?token=YOUR_ACCESS_TOKEN
```

### Check Access Tokens:
```bash
GET http://localhost:8000/api/proposals/1/access-tokens
Headers:
  Authorization: Bearer YOUR_TOKEN
```

### View Audit Log:
```bash
GET http://localhost:8000/api/proposals/1/access-audit
Headers:
  Authorization: Bearer YOUR_TOKEN
```

## 📊 What to Look For

### ✅ Success Indicators:
1. **On Approval:**
   - Console shows: `[ENCRYPTION] Proposal X content encrypted successfully`
   - Database has entry in `encrypted_proposals` table
   - Database has entry in `proposal_access_tokens` table
   - Email sent to client with secure link

2. **On Client Access:**
   - Console shows: `[DECRYPTION] Proposal X decrypted successfully`
   - Database has entry in `proposal_access_audit` table
   - Client can view the proposal content

3. **In Database:**
   - `encrypted_proposals.encrypted_content` is NOT readable (encrypted)
   - `proposal_access_tokens.access_token` is a long random string
   - `proposal_access_audit` shows access attempts

## 🐛 Troubleshooting

### If encryption fails:
- Check `.env` file has `PROPOSAL_ENCRYPTION_KEY` set
- Check backend logs for errors
- Verify database tables exist (run migrations)

### If client can't access:
- Check token hasn't expired
- Check `proposal_access_tokens.is_active = true`
- Check `proposal_access_audit` for failure reasons

### If content is not encrypted:
- Make sure proposal has `content` field populated
- Check approval endpoint is being called (not just status update)
- Verify encryption service is loaded correctly

## 🎉 You're Ready!

The encryption system is **fully functional** and will automatically:
- Encrypt proposals when approved
- Generate secure access tokens
- Track all access attempts
- Decrypt content for authorized clients

Just approve a proposal and watch it work! 🚀

























