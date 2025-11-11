# Twilio SMS Verification Setup Guide

## Step 1: Get Your Twilio Credentials

1. **Log into Twilio Console**: https://console.twilio.com/

2. **Get Your Account SID and Auth Token**:
   - Go to: https://console.twilio.com/us1/account/settings/credentials
   - Copy your **Account SID** (starts with `AC...`)
   - Copy your **Auth Token** (click "View" to reveal it)

3. **Get Your Phone Number** (Choose ONE option):

   **Option A: Use Messaging Service (Recommended for Production)**
   - Go to: https://console.twilio.com/us1/sms/services
   - Click "Create Messaging Service"
   - Give it a name (e.g., "Khonology SMS")
   - Add a phone number to the service (you'll need to buy one first, see Option B)
   - Copy the **Messaging Service SID** (starts with `MG...`)
   - Use this SID instead of a phone number in your code
   
   **Option B: Buy a Phone Number**
   - Go to: https://console.twilio.com/us1/develop/phone-numbers/manage/search
   - Click "Buy a number"
   - Select a number that supports SMS
   - Cost: ~$1/month + per-SMS charges
   - Copy the phone number (this is your **FROM** number)
   
   **Option C: Use Trial Number (If Available)**
   - Go to: https://console.twilio.com/us1/develop/phone-numbers/manage/incoming
   - Check if you have a free trial number
   - If available, copy this number
   - Note: Not available in all regions

4. **Verify Your Personal Phone Number** (for testing):
   - Go to: https://console.twilio.com/us1/develop/phone-numbers/manage/verified
   - Click "Add a new number"
   - Enter your personal phone number
   - Twilio will send you a verification code
   - Enter the code to verify
   - **Note**: Trial accounts can ONLY send SMS to verified numbers

## Step 2: Add Twilio Credentials to .env

Add these lines to your `backend/.env` file:

```env
# Twilio SMS Configuration
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here

# Choose ONE of these options:
# Option 1: Use Messaging Service (Recommended)
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Option 2: Use Direct Phone Number
TWILIO_FROM_NUMBER=+15551234567
```

Replace:
- `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` with your Account SID
- `your_auth_token_here` with your Auth Token
- **If using Messaging Service**: Set `TWILIO_MESSAGING_SERVICE_SID` (starts with `MG...`)
- **If using Direct Number**: Set `TWILIO_FROM_NUMBER` (include the + and country code)
- **Note**: Only set ONE of the last two options (Messaging Service OR From Number)

## Step 3: Install Twilio Python Library

Run this command in your terminal:

```bash
pip install twilio
```

Or add to `requirements.txt`:
```
twilio>=8.0.0
```

## Step 4: Test Twilio Setup

You can test if Twilio is working by running this Python script:

```python
from twilio.rest import Client
import os

account_sid = os.getenv('TWILIO_ACCOUNT_SID')
auth_token = os.getenv('TWILIO_AUTH_TOKEN')
from_number = os.getenv('TWILIO_FROM_NUMBER')
to_number = '+27XXXXXXXXX'  # Your verified phone number

client = Client(account_sid, auth_token)

message = client.messages.create(
    body='Test message from Khonology!',
    from_=from_number,
    to=to_number
)

print(f"Message sent! SID: {message.sid}")
```

## Important Notes:

1. **Trial Account Limitations**:
   - Can only send SMS to **verified phone numbers**
   - Messages include "Sent from your Twilio trial account" banner
   - Limited number of messages per day

2. **Upgrading to Paid Account**:
   - Remove verification requirement
   - Send to any phone number
   - No message banner
   - Pay per message (very cheap, ~$0.01-0.05 per SMS)

3. **Phone Number Format**:
   - Always use E.164 format: `+[country code][number]`
   - Example: `+27123456789` (South Africa)
   - Example: `+15551234567` (USA)

