# Email Debugging Guide

## Issue: Client emails not being sent after CEO approval

## Steps to Debug:

### 1. Check if client_email is being found
When you approve a proposal, check the server logs for:
- `[EMAIL DEBUG] Initial client_email from proposal: ...`
- `[EMAIL DEBUG] Final client email check: ...`

If you see `client_email=None` or empty, the email won't be sent.

### 2. Test SMTP Configuration
Use the test endpoint:
```bash
POST /api/test-email
Headers: Authorization: Bearer YOUR_TOKEN
Body: {"test_email": "your-email@example.com"}
```

This will test if your SMTP settings work independently.

### 3. Check Server Logs
When approving a proposal, look for these log messages:
- `[EMAIL] ========================================`
- `[EMAIL] Attempting to send email to: ...`
- `[EMAIL] SMTP Configuration:`
- `[SUCCESS] ✅✅✅ Email sent successfully` OR `[ERROR] ❌❌❌ Email sending FAILED`

### 4. Verify .env File Location
The `.env` file must be in the `backend/` directory (same directory as `app.py`).

### 5. Common Issues:

#### Issue: SMTP Authentication Error
**Solution:** 
- Make sure you're using a Gmail App Password (not your regular password)
- Go to: https://myaccount.google.com/apppasswords
- Generate a new app password
- Update `SMTP_PASS` in `.env`

#### Issue: client_email is None
**Solution:**
- Make sure the proposal has a `client_email` field set
- Or link the proposal to a client in the `clients` table
- The system will try to find the email from:
  1. `proposals.client_email` column
  2. `clients.email` via `proposals.client_id`
  3. `clients.email` via `client_proposals` link table
  4. `clients.email` via company/contact name lookup

#### Issue: Email sent but not received
**Check:**
- Spam/Junk folder
- Email provider's filters
- Gmail may delay emails from new senders

### 6. Manual Test
Run the standalone SMTP test:
```bash
cd backend
python test_smtp.py
```

Enter your email when prompted to test the SMTP connection.

## Current SMTP Configuration (from .env):
- Host: smtp.gmail.com
- Port: 587
- User: mokgaxikgothatso@gmail.com
- From: Khonology_2 <mokgaxikgothatso@gmail.com>

## Next Steps:
1. Restart your Flask server after changing .env
2. Try approving a proposal and watch the logs
3. Use `/api/test-email` endpoint to verify SMTP works
4. Check that the proposal has a client_email or is linked to a client






## Issue: Client emails not being sent after CEO approval

## Steps to Debug:

### 1. Check if client_email is being found
When you approve a proposal, check the server logs for:
- `[EMAIL DEBUG] Initial client_email from proposal: ...`
- `[EMAIL DEBUG] Final client email check: ...`

If you see `client_email=None` or empty, the email won't be sent.

### 2. Test SMTP Configuration
Use the test endpoint:
```bash
POST /api/test-email
Headers: Authorization: Bearer YOUR_TOKEN
Body: {"test_email": "your-email@example.com"}
```

This will test if your SMTP settings work independently.

### 3. Check Server Logs
When approving a proposal, look for these log messages:
- `[EMAIL] ========================================`
- `[EMAIL] Attempting to send email to: ...`
- `[EMAIL] SMTP Configuration:`
- `[SUCCESS] ✅✅✅ Email sent successfully` OR `[ERROR] ❌❌❌ Email sending FAILED`

### 4. Verify .env File Location
The `.env` file must be in the `backend/` directory (same directory as `app.py`).

### 5. Common Issues:

#### Issue: SMTP Authentication Error
**Solution:** 
- Make sure you're using a Gmail App Password (not your regular password)
- Go to: https://myaccount.google.com/apppasswords
- Generate a new app password
- Update `SMTP_PASS` in `.env`

#### Issue: client_email is None
**Solution:**
- Make sure the proposal has a `client_email` field set
- Or link the proposal to a client in the `clients` table
- The system will try to find the email from:
  1. `proposals.client_email` column
  2. `clients.email` via `proposals.client_id`
  3. `clients.email` via `client_proposals` link table
  4. `clients.email` via company/contact name lookup

#### Issue: Email sent but not received
**Check:**
- Spam/Junk folder
- Email provider's filters
- Gmail may delay emails from new senders

### 6. Manual Test
Run the standalone SMTP test:
```bash
cd backend
python test_smtp.py
```

Enter your email when prompted to test the SMTP connection.

## Current SMTP Configuration (from .env):
- Host: smtp.gmail.com
- Port: 587
- User: mokgaxikgothatso@gmail.com
- From: Khonology_2 <mokgaxikgothatso@gmail.com>

## Next Steps:
1. Restart your Flask server after changing .env
2. Try approving a proposal and watch the logs
3. Use `/api/test-email` endpoint to verify SMTP works
4. Check that the proposal has a client_email or is linked to a client





















