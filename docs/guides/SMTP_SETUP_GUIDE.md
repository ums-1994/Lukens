# 📧 SMTP Email Verification Setup Guide

This guide will help you set up SMTP email verification for the Proposal & SOW Builder application using the Python backend.

## 🚀 Quick Start

### 1. Start the Python Backend

```bash
# Navigate to the project directory
cd proposal_sow_builder_v2

# Start the Python backend
python start_python_backend.py
```

The server will start at `http://localhost:8000` with automatic reload enabled.

### 2. Start the Flutter Frontend

```bash
# Navigate to the Flutter directory
cd frontend_flutter

# Start the Flutter app
flutter run --hot
```

## 📧 SMTP Configuration

The Python backend is already configured with your Gmail SMTP settings:

- **SMTP Server:** smtp.gmail.com
- **Port:** 587
- **Email:** umsibanda.1994@gmail.com
- **App Password:** aozi xfgg mdcn ylae

### 🔧 Email Settings Location

The SMTP configuration is in `backend/app.py`:

```python
# Email configuration
MAIL_USERNAME = "umsibanda.1994@gmail.com"
MAIL_PASSWORD = "aozi xfgg mdcn ylae"  # Your Gmail App Password
MAIL_FROM = "umsibanda.1994@gmail.com"
MAIL_PORT = 587
MAIL_SERVER = "smtp.gmail.com"
MAIL_FROM_NAME = "Proposal & SOW Builder"
```

## 🔄 How Email Verification Works

### 1. User Registration
- User fills out registration form
- System creates account with `is_verified: false`
- Verification token is generated (24-hour expiry)
- Verification email is sent via SMTP

### 2. Email Verification
- User clicks verification link in email
- Link contains verification token
- System validates token and marks user as verified
- User can now log in

### 3. Login Process
- User attempts to log in
- System checks if email is verified
- If not verified, shows error message
- If verified, allows login

## 🛠️ API Endpoints

The Python backend provides these SMTP-related endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/register` | POST | Register new user (sends verification email) |
| `/login-email` | POST | Login with email and password |
| `/verify-email` | POST | Verify email with token |
| `/resend-verification` | POST | Resend verification email |
| `/me` | GET | Get current user profile |

## 📱 Flutter Integration

The Flutter app uses `SmtpAuthService` to communicate with the Python backend:

```dart
// Register user
final result = await SmtpAuthService.registerUser(
  email: email,
  password: password,
  firstName: firstName,
  lastName: lastName,
  role: role,
);

// Login user
final result = await SmtpAuthService.loginUser(
  email: email,
  password: password,
);

// Verify email
final result = await SmtpAuthService.verifyEmail(
  token: token,
);
```

## 🔍 Testing Email Verification

### 1. Register a New User
1. Open the Flutter app
2. Go to Registration page
3. Fill out the form with a valid email
4. Submit registration
5. Check your email for verification link

### 2. Verify Email
1. Click the verification link in the email
2. You should see a success message
3. Try logging in with the same credentials

### 3. Test Login
1. Go to Login page
2. Enter verified email and password
3. Should successfully log in

## 🐛 Troubleshooting

### Common Issues

1. **"Email not verified" error**
   - Check if verification email was sent
   - Verify the email link is clicked
   - Check if token has expired (24 hours)

2. **"Failed to send verification email"**
   - Check SMTP credentials in `backend/app.py`
   - Verify Gmail App Password is correct
   - Check internet connection

3. **"Invalid verification token"**
   - Token may have expired
   - Use "Resend Verification" feature
   - Check if token was already used

### Debug Steps

1. **Check Backend Logs**
   ```bash
   # Look for SMTP errors in terminal
   python start_python_backend.py
   ```

2. **Check Email Settings**
   - Verify Gmail App Password is correct
   - Ensure 2-Factor Authentication is enabled
   - Check if "Less secure app access" is enabled

3. **Test SMTP Connection**
   ```python
   # Add this to backend/app.py for testing
   import smtplib
   
   def test_smtp():
       server = smtplib.SMTP('smtp.gmail.com', 587)
       server.starttls()
       server.login("umsibanda.1994@gmail.com", "aozi xfgg mdcn ylae")
       print("SMTP connection successful!")
       server.quit()
   ```

## 🔒 Security Notes

- Gmail App Passwords are more secure than regular passwords
- Verification tokens expire after 24 hours
- Tokens are single-use only
- All passwords are hashed using bcrypt

## 📚 Additional Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Gmail SMTP Settings](https://support.google.com/mail/answer/7126229)
- [Flutter HTTP Package](https://pub.dev/packages/http)

## 🆘 Support

If you encounter issues:

1. Check the backend logs for error messages
2. Verify SMTP credentials are correct
3. Ensure all dependencies are installed
4. Check if ports 8000 and 3000 are available

---

**Happy Coding! 🚀**
