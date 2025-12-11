# SendGrid Email Setup Guide

## Overview

The application now supports SendGrid for email delivery, which is more reliable than SMTP in production environments. SendGrid is the preferred method, with SMTP as a fallback.

## Quick Setup

### 1. Create a SendGrid Account

1. Go to [https://sendgrid.com](https://sendgrid.com)
2. Sign up for a free account (100 emails/day free tier)
3. Verify your email address

### 2. Create an API Key

1. Log in to SendGrid dashboard
2. Go to **Settings** → **API Keys**
3. Click **Create API Key**
4. Give it a name (e.g., "Lukens Production")
5. Select **Full Access** or **Restricted Access** with **Mail Send** permissions
6. Click **Create & View**
7. **Copy the API key immediately** (you won't be able to see it again!)

### 3. Verify Your Sender Email

1. Go to **Settings** → **Sender Authentication**
2. Click **Verify a Single Sender**
3. Fill in your sender information:
   - **From Email**: The email address you want to send from
   - **From Name**: Your company name (e.g., "Khonology")
   - **Reply To**: Same as From Email (usually)
   - **Company Address**: Your business address
4. Click **Create**
5. Check your email and click the verification link

### 4. Configure Environment Variables

Add these to your `.env` file or production environment:

```bash
# SendGrid Configuration (Preferred)
SENDGRID_API_KEY=SG.your_api_key_here
SENDGRID_FROM_EMAIL=your-verified-email@domain.com
SENDGRID_FROM_NAME=Khonology

# SMTP Configuration (Optional - Fallback only)
# Only needed if you want SMTP as backup
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM_EMAIL=your-email@gmail.com
SMTP_FROM_NAME=Khonology
```

### 5. Install Dependencies

The SendGrid SDK is already in `requirements.txt`. Install it:

```bash
pip install sendgrid
```

Or install all requirements:

```bash
pip install -r requirements.txt
```

## Testing

### Test Email Configuration

Run the configuration check script:

```bash
cd backend
python check_smtp_config.py
```

This will:
- Check if SendGrid is configured
- Check if SMTP is configured (fallback)
- Allow you to send a test email

### Test via API

The email system will automatically:
1. Try SendGrid first if `SENDGRID_API_KEY` is set
2. Fall back to SMTP if SendGrid fails or is not configured

## How It Works

### Priority Order

1. **SendGrid** (if `SENDGRID_API_KEY` is set)
   - More reliable in production
   - Better deliverability
   - No port blocking issues

2. **SMTP** (fallback)
   - Used if SendGrid is not configured
   - Used if SendGrid fails
   - Requires SMTP server configuration

### Email Sending Flow

```
send_email() called
    ↓
Is SENDGRID_API_KEY set?
    ↓ YES
Try SendGrid
    ↓ Success? → Return True
    ↓ Failure? → Try SMTP
    ↓
Is SMTP configured?
    ↓ YES
Try SMTP
    ↓ Success? → Return True
    ↓ Failure? → Return False
```

## Production Deployment

### Render.com

1. Go to your Render dashboard
2. Select your backend service
3. Go to **Environment** tab
4. Add these environment variables:
   - `SENDGRID_API_KEY` = Your SendGrid API key
   - `SENDGRID_FROM_EMAIL` = Your verified sender email
   - `SENDGRID_FROM_NAME` = Your company name

### Other Platforms

Add the same environment variables to your hosting platform's environment configuration.

## Troubleshooting

### SendGrid Not Working

1. **Check API Key**: Make sure `SENDGRID_API_KEY` is set correctly
2. **Verify Sender**: Ensure your sender email is verified in SendGrid
3. **Check Permissions**: API key must have "Mail Send" permissions
4. **Check Logs**: Look for SendGrid error messages in your application logs

### Still Using SMTP

If emails are still going through SMTP:
- Check if `SENDGRID_API_KEY` is set in your environment
- Check application logs for SendGrid errors
- Verify SendGrid SDK is installed: `pip list | grep sendgrid`

### Rate Limits

SendGrid Free Tier:
- 100 emails/day
- Upgrade to paid plan for more

## Benefits of SendGrid

✅ **Reliability**: Better deliverability than SMTP  
✅ **No Port Issues**: No firewall/port blocking problems  
✅ **Analytics**: Track email opens, clicks, bounces  
✅ **Scalability**: Handles high volume easily  
✅ **Production Ready**: Designed for production use  

## Support

- SendGrid Documentation: [https://docs.sendgrid.com](https://docs.sendgrid.com)
- SendGrid Support: Available in dashboard
- Check application logs for detailed error messages


