# Firebase Authentication Setup

Firebase authentication has been integrated into the backend. This document explains how to set it up and use it.

## What Was Changed

1. ✅ **Fixed bug** - `save_tokens()` call on line 167 now passes required argument
2. ✅ **Added Firebase Admin SDK** - Added `firebase-admin` to requirements.txt
3. ✅ **Created Firebase auth utility** - `backend/api/utils/firebase_auth.py`
4. ✅ **New auth endpoints** - `/auth/firebase` and `/auth/firebase/verify`
5. ✅ **Updated decorators** - `token_required` now supports both Firebase and legacy tokens

## Setup Instructions

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

This will install `firebase-admin>=6.2.0`.

### 2. Get Firebase Service Account Credentials

You need to download your Firebase service account JSON file:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `lukens-e17d6`
3. Go to **Project Settings** (gear icon)
4. Go to **Service Accounts** tab
5. Click **Generate New Private Key**
6. Save the JSON file (e.g., `firebase-service-account.json`)

### 3. Configure Credentials

**Option A: Automatic (Already Done! ✅)**

The Firebase credentials file has been placed in `backend/firebase-service-account.json`. 
The system will automatically find it - no configuration needed!

**Option B: Custom path (Optional)**

If you want to use a different location, add to your `.env` file:
```env
FIREBASE_CREDENTIALS_PATH=./path/to/your/firebase-credentials.json
```

**Option B: Use environment variable**

Add the entire JSON content to `.env`:
```env
FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"lukens-e17d6",...}'
```

**Option C: Default credentials (for Google Cloud environments)**

If running on Google Cloud, Firebase Admin SDK can use default credentials automatically.

## API Endpoints

### POST `/api/auth/firebase`

Authenticate with Firebase ID token. Creates or updates user in database.

**Request:**
```json
{
  "idToken": "firebase-id-token-from-frontend"
}
```

**Response (200/201):**
```json
{
  "token": "firebase-id-token",
  "user": {
    "id": 1,
    "username": "user123",
    "email": "user@example.com",
    "full_name": "User Name",
    "role": "user",
    "department": null,
    "firebase_uid": "firebase-uid-here"
  }
}
```

### GET `/api/auth/firebase/verify`

Verify Firebase token and get user info. Requires valid Firebase token in Authorization header.

**Headers:**
```
Authorization: Bearer <firebase-id-token>
```

**Response (200):**
```json
{
  "user": {
    "id": 1,
    "username": "user123",
    "email": "user@example.com",
    "full_name": "User Name",
    "role": "user",
    "department": null,
    "is_active": true,
    "firebase_uid": "firebase-uid-here"
  }
}
```

## Frontend Integration

Your Flutter app already uses Firebase. Update your login flow to:

1. **Sign in with Firebase** (already done):
```dart
final userCredential = await FirebaseService.signInWithEmailAndPassword(
  email: email,
  password: password,
);
```

2. **Get Firebase ID token**:
```dart
final idToken = await userCredential.user?.getIdToken();
```

3. **Send to backend**:
```dart
final response = await http.post(
  Uri.parse('http://localhost:8000/api/auth/firebase'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'idToken': idToken}),
);
```

4. **Use Firebase token for API calls**:
```dart
final headers = {
  'Authorization': 'Bearer $idToken',
  'Content-Type': 'application/json',
};
```

## How It Works

### Authentication Flow

1. User signs in with Firebase on frontend
2. Frontend gets Firebase ID token
3. Frontend sends token to `/api/auth/firebase`
4. Backend verifies token with Firebase Admin SDK
5. Backend creates/updates user in PostgreSQL database
6. Backend returns user info
7. Frontend uses Firebase token for all API calls

### Token Verification

The `@token_required` decorator now:
1. First tries to verify as Firebase token
2. If that fails, falls back to legacy JWT token
3. Extracts username from database (Firebase) or token (legacy)

## Database Schema

The system will try to add a `firebase_uid` column to the `users` table if it doesn't exist. This is optional and won't break if the column doesn't exist.

To add it manually:
```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(255);
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);
```

## Migration from Legacy Auth

The system supports both authentication methods:

- **Firebase tokens** - New, recommended
- **Legacy JWT tokens** - Still works for backward compatibility

You can gradually migrate:
1. Keep both systems working
2. Update frontend to use Firebase tokens
3. Eventually remove legacy token generation

## Testing Setup

Run the test script to verify Firebase is set up correctly:

```bash
cd backend
python test_firebase_setup.py
```

This will check:
- ✅ Firebase Admin SDK is installed
- ✅ Credentials file is found
- ✅ Firebase can be initialized

## Troubleshooting

### "Firebase Admin SDK not initialized"

- Run `python backend/test_firebase_setup.py` to diagnose
- Check that `firebase-service-account.json` exists in `backend/` directory
- Verify the JSON file is valid (should have `type`, `project_id`, `private_key`, etc.)
- Make sure firebase-admin is installed: `pip install firebase-admin`
- Check file permissions (file should be readable)

### "Invalid or expired Firebase token"

- Token may have expired (Firebase tokens expire after 1 hour)
- Frontend should refresh tokens automatically
- Check that Firebase project ID matches

### "User not found in database"

- User authenticated with Firebase but doesn't exist in PostgreSQL
- The `/auth/firebase` endpoint will create the user automatically
- Make sure the endpoint is called after Firebase sign-in

## Security Notes

- Firebase tokens are verified server-side using Firebase Admin SDK
- Tokens expire after 1 hour (Firebase default)
- Frontend should refresh tokens before they expire
- Never expose Firebase service account credentials in client code

