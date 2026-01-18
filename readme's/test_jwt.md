# JWT Token Testing Guide

## Local Setup Complete ✅

Your app is now configured for local development with JWT token decryption.

## Configuration Changes Made:

### 1. Frontend (Flutter)
- ✅ JWT secrets updated in `lib/config/jwt_config.dart`
- ✅ AuthService configured to use `http://localhost:8000`
- ✅ JWT decryption service with detailed logging
- ✅ CORS support for Flutter web (port 3000)

### 2. Backend (Flask)
- ✅ CORS updated to allow `http://localhost:3000` and `http://127.0.0.1:3000`
- ✅ JWT secrets from your .env file are ready

## How to Test:

### 1. Start Backend Server
```bash
cd backend
python app.py
```
Backend will run on: `http://localhost:8000`

### 2. Start Flutter App
```bash
cd frontend_flutter
flutter run -d chrome --web-port=3000
```
Flutter web will run on: `http://localhost:3000`

### 3. Test JWT Token
1. Generate a JWT token from your backend (or use an existing one)
2. Go to the landing screen
3. Paste the JWT token in the input field
4. Click "Open"
5. Check the browser console for detailed logs

## Expected Console Logs:
```
🔑 Attempting to decrypt JWT token locally...
🔑 Parsing JWT token...
✅ JWT payload decoded successfully
✅ JWT token validation successful
👤 User email: user@example.com
🔑 User role: admin
```

## Troubleshooting:

### "Invalid JWT format"
- Make sure the token has 3 parts separated by dots (header.payload.signature)
- Check for extra spaces or newline characters

### "JWT signature verification failed"
- Verify the JWT_SECRET in your backend .env matches the one in `jwt_config.dart`
- Current secret: `PudwjIQa-kMPoQ8KCE9OqN3-HnIu2P12Dkf2U6rFH8I=`

### "Token has expired"
- Generate a fresh JWT token from your backend
- Check the `exp` claim in the token payload

### "Failed to fetch" (Backend connection)
- Ensure backend is running on `http://localhost:8000`
- Check CORS configuration in `app.py`

### CORS Errors
- Verify backend CORS includes `http://localhost:3000`
- Check browser network tab for CORS preflight requests

## JWT Token Format:
Your JWT tokens should look like:
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

## Next Steps:
1. Start both servers
2. Test with a real JWT token
3. Check console logs for debugging
4. Verify role-based navigation works correctly
