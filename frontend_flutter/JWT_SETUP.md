# JWT Token Decryption Setup

This document explains how to configure JWT token decryption on the landing screen.

## Overview
The app now supports local JWT token decryption using the secret key and encryption key from your backend .env file. This allows users to paste a JWT token directly on the landing screen and have it decrypted locally for instant authentication.

## Configuration Steps

### 1. Update JWT Configuration
Edit `lib/config/jwt_config.dart` and replace the placeholder values with your actual secrets:

```dart
class JwtConfig {
  // Replace these with your actual backend .env values
  static const String jwtSecret = 'your-actual-jwt-secret-key';
  static const String encryptionKey = 'your-actual-32-character-encryption-key';
}
```

### 2. Backend .env Values
Make sure your backend `.env` file contains:
```
JWT_SECRET=your-super-secret-jwt-key
ENCRYPTION_KEY=your-32-character-encryption-key
```

### 3. How It Works

1. **Local Decryption**: When a user pastes a JWT token on the landing screen, the app first tries to decrypt it locally using the configured secret key.

2. **Token Validation**: The app verifies:
   - Token signature using HMAC SHA256
   - Token expiration
   - Token structure

3. **Fallback**: If local decryption fails, it falls back to backend verification at `/khonobuzz/jwt-login`

4. **User Session**: Upon successful decryption, the app creates a session and redirects to the appropriate dashboard based on the user's role.

## Security Notes

- **Never commit actual secrets to version control**
- For production, consider using:
  - Environment variables
  - Secure storage (flutter_secure_storage)
  - Build-time configuration

## Testing

1. Generate a JWT token using your backend
2. Paste it into the JWT input field on the landing screen
3. Click "Open" to test decryption
4. Check the console for decryption logs

## Troubleshooting

- **"Invalid token signature"**: Check that the JWT secret matches your backend
- **"Token has expired"**: Generate a fresh token
- **"Failed to decrypt JWT token"**: Verify the token format and secret key

## Features

- ✅ Local JWT decryption
- ✅ Token signature verification
- ✅ Expiration checking
- ✅ Fallback to backend verification
- ✅ Role-based routing
- ✅ Error handling with user feedback
