# SMTP Email Verification Setup

Email verification has been integrated into the authentication system using SMTP. This document explains how to configure and use it.

## What Was Added

1. ✅ **Email verification function** - `send_verification_email()` in `backend/api/utils/email.py`
2. ✅ **Database table** - `user_email_verification_tokens` for storing verification tokens
3. ✅ **Registration endpoint** - Now sends verification emails automatically
4. ✅ **Verification endpoint** - `/api/auth/verify-email` (GET and POST)
5. ✅ **Resend endpoint** - `/api/auth/resend-verification` for resending verification emails

## Setup Instructions

### 1. Configure SMTP Settings

Add the following environment variables to your `.env` file in the `backend/` directory:

```env
# SMTP Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM_EMAIL=your-email@gmail.com
SMTP_FROM_NAME=Khonology

# Frontend URL (for verification links)
FRONTEND_URL=http://localhost:8080
```

### 2. Gmail Setup (Example)

If using Gmail:

1. **Enable 2-Step Verification** on your Google account
2. **Generate an App Password**:
   - Go to [Google Account Settings](https://myaccount.google.com/)
   - Security → 2-Step Verification → App passwords
   - Generate a password for "Mail"
   - Use this password as `SMTP_PASS` (not your regular Gmail password)

3. **Configure `.env`**:
   ```env
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USER=your-email@gmail.com
   SMTP_PASS=your-16-char-app-password
   SMTP_FROM_EMAIL=your-email@gmail.com
   SMTP_FROM_NAME=Khonology
   ```

### 3. Other Email Providers

#### Outlook/Office 365
```env
SMTP_HOST=smtp.office365.com
SMTP_PORT=587
SMTP_USER=your-email@outlook.com
SMTP_PASS=your-password
```

#### SendGrid
```env
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=your-sendgrid-api-key
SMTP_FROM_EMAIL=noreply@yourdomain.com
```

#### Mailgun
```env
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USER=your-mailgun-username
SMTP_PASS=your-mailgun-password
SMTP_FROM_EMAIL=noreply@yourdomain.com
```

### 4. Database Schema

The system automatically creates the `user_email_verification_tokens` table when the database is initialized. The table structure:

```sql
CREATE TABLE user_email_verification_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

## API Endpoints

### POST `/api/auth/register`

Register a new user. Automatically sends a verification email.

**Request:**
```json
{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "securepassword123",
  "full_name": "John Doe",
  "role": "user"
}
```

**Response (200):**
```json
{
  "detail": "Registration successful. Please check your email to verify your account.",
  "email": "john@example.com",
  "email_sent": true
}
```

**Note:** New users are created with `is_email_verified = false`. They must verify their email before full access.

### GET/POST `/api/auth/verify-email`

Verify email address using a verification token.

**GET Request (from email link):**
```
GET /api/auth/verify-email?token=verification-token-here
```

Returns an HTML page with success message.

**POST Request (from frontend):**
```json
{
  "token": "verification-token-here"
}
```

**Response (200):**
```json
{
  "detail": "Email verified successfully",
  "email": "john@example.com"
}
```

**Error Responses:**
- `400` - Invalid or missing token
- `400` - Token already used
- `400` - Token expired

### POST `/api/auth/resend-verification`

Resend verification email to an unverified user.

**Request:**
```json
{
  "email": "john@example.com"
}
```

**Response (200):**
```json
{
  "detail": "Verification email sent successfully",
  "email": "john@example.com"
}
```

**Error Responses:**
- `400` - Email is already verified
- `500` - Failed to send email

## Email Template

The verification email includes:
- Khonology branding (logo)
- Personalized greeting
- Verification button/link
- Expiration notice (24 hours)
- Plain text link as fallback

The email uses the same styling as other Khonology emails (dark theme with red accents).

## Verification Flow

1. **User registers** → Account created with `is_email_verified = false`
2. **System generates token** → Stored in `user_email_verification_tokens` table
3. **Verification email sent** → Contains link with token
4. **User clicks link** → GET request to `/api/auth/verify-email?token=...`
5. **System verifies token** → Checks expiration and usage
6. **Email marked as verified** → `is_email_verified = true` in users table
7. **Token marked as used** → `used_at` timestamp set

## Security Features

- ✅ **Token expiration** - Tokens expire after 24 hours
- ✅ **One-time use** - Tokens are marked as used after verification
- ✅ **Automatic invalidation** - Old tokens are invalidated when new ones are generated
- ✅ **Database storage** - Tokens stored securely in PostgreSQL
- ✅ **Email validation** - Only unverified emails can request resend

## Frontend Integration

### Check Email Verification Status

When a user logs in, check their verification status:

```dart
final response = await http.get(
  Uri.parse('http://localhost:8000/api/auth/me'),
  headers: {'Authorization': 'Bearer $token'},
);

final user = jsonDecode(response.body);
if (!user['is_email_verified']) {
  // Show "Please verify your email" message
  // Provide link to resend verification
}
```

### Resend Verification Email

```dart
final response = await http.post(
  Uri.parse('http://localhost:8000/api/auth/resend-verification'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'email': userEmail}),
);
```

### Handle Verification Link

When user clicks email link, redirect to:
```
http://localhost:8000/api/auth/verify-email?token=TOKEN
```

Or make a POST request from your frontend:
```dart
final response = await http.post(
  Uri.parse('http://localhost:8000/api/auth/verify-email'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'token': verificationToken}),
);
```

## Testing

### Test SMTP Configuration

The email utility will log detailed information about email sending:

```
[EMAIL] Attempting to send email to user@example.com
[EMAIL] SMTP Config - Host: smtp.gmail.com, Port: 587, User: your-email@gmail.com
[EMAIL] From: Khonology <your-email@gmail.com>
[EMAIL] Connecting to SMTP server...
[EMAIL] Starting TLS...
[EMAIL] Logging in...
[EMAIL] Sending message...
[SUCCESS] Email sent to user@example.com
```

### Test Registration Flow

1. Register a new user:
   ```bash
   curl -X POST http://localhost:8000/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{
       "username": "testuser",
       "email": "test@example.com",
       "password": "testpass123"
     }'
   ```

2. Check email inbox for verification link

3. Click link or use token:
   ```bash
   curl "http://localhost:8000/api/auth/verify-email?token=TOKEN_HERE"
   ```

4. Verify user status:
   ```bash
   curl http://localhost:8000/api/auth/me \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

## Troubleshooting

### "SMTP configuration incomplete"

- Check that all required environment variables are set:
  - `SMTP_HOST`
  - `SMTP_USER`
  - `SMTP_PASS`
- Verify `.env` file is in the `backend/` directory
- Restart the backend server after changing `.env`

### "Failed to send verification email"

- Check SMTP credentials are correct
- For Gmail, ensure you're using an App Password (not regular password)
- Check firewall/network allows SMTP connections
- Verify SMTP port (587 for TLS, 465 for SSL)
- Check email provider's sending limits

### "Verification link expired"

- Tokens expire after 24 hours
- Use `/api/auth/resend-verification` to get a new token

### "Token already used"

- Each token can only be used once
- Request a new verification email if needed

## Environment Variables Summary

```env
# Required
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-password

# Optional (defaults shown)
SMTP_FROM_EMAIL=your-email@gmail.com
SMTP_FROM_NAME=Khonology
FRONTEND_URL=http://localhost:8080
```

## Next Steps

1. ✅ Configure SMTP settings in `.env`
2. ✅ Test registration and email sending
3. ✅ Update frontend to handle unverified users
4. ✅ Add UI for resending verification emails
5. ✅ Consider requiring email verification before login (optional)

