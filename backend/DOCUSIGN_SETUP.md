# DocuSign Setup Guide

## Prerequisites

1. **DocuSign Account**: You need a DocuSign Developer account (free at https://developers.docusign.com)
2. **Integration Key**: Create an app in DocuSign Admin to get your Integration Key
3. **RSA Key Pair**: Generate RSA key pair for JWT authentication

## Environment Variables Required

Add these to your `.env` file:

```bash
# DocuSign Integration Key (from DocuSign Admin → Apps & Keys)
DOCUSIGN_INTEGRATION_KEY=your-integration-key-here

# DocuSign User ID (from DocuSign Admin → Settings → My Account Information)
DOCUSIGN_USER_ID=your-user-id-here

# DocuSign Account ID (from DocuSign Admin → Settings → My Account Information)
DOCUSIGN_ACCOUNT_ID=your-account-id-here

# Auth Server (use 'account-d.docusign.com' for demo, 'account.docusign.com' for production)
DOCUSIGN_AUTH_SERVER=account-d.docusign.com

# Base URL (use 'https://demo.docusign.net/restapi' for demo, 'https://www.docusign.net/restapi' for production)
DOCUSIGN_BASE_URL=https://demo.docusign.net/restapi

# Path to your private key file
DOCUSIGN_PRIVATE_KEY_PATH=./docusign_private.key
```

## Step-by-Step Setup

### 1. Create DocuSign Developer Account
- Go to https://developers.docusign.com
- Sign up for a free developer account
- Log in to DocuSign Admin

### 2. Create Integration (App)
1. Go to **Admin** → **Apps and Keys**
2. Click **Add App and Integration Key**
3. Name your app (e.g., "ProposalHub")
4. Copy the **Integration Key** (this is your `DOCUSIGN_INTEGRATION_KEY`)

### 3. Get Your User ID
1. Go to **Admin** → **Settings** → **My Account Information**
2. Copy your **User ID** (this is your `DOCUSIGN_USER_ID`)
3. Copy your **Account ID** (this is your `DOCUSIGN_ACCOUNT_ID`)

### 4. Generate RSA Key Pair
1. In DocuSign Admin, go to **Apps and Keys**
2. Click on your app
3. Under **Authentication**, click **Generate RSA**
4. Download the **private key** (save as `docusign_private.key` in your backend folder)
5. Copy the **public key** and click **Add** to upload it to DocuSign

### 5. Grant Consent (IMPORTANT!)
1. Construct the consent URL:
   ```
   https://account-d.docusign.com/oauth/auth?response_type=code&scope=signature%20impersonation&client_id=YOUR_INTEGRATION_KEY&redirect_uri=https://www.docusign.com
   ```
   Replace `YOUR_INTEGRATION_KEY` with your actual integration key.

2. Open this URL in your browser
3. Log in with your DocuSign account
4. Click **Allow** to grant consent
5. You should see "Consent granted" message

### 6. Install Python Package
```bash
pip install docusign-esign
```

### 7. Test the Setup
Run the backend and try to create a signing URL for a proposal. Check the console logs for any errors.

## Troubleshooting

### Error: "DocuSign consent required"
- You need to grant consent (see Step 5 above)
- The consent URL will be printed in the error message

### Error: "Invalid grant"
- Verify your Integration Key, User ID, and Account ID are correct
- Ensure the private key matches the public key uploaded to DocuSign
- Make sure consent has been granted

### Error: "Private key file not found"
- Check that `DOCUSIGN_PRIVATE_KEY_PATH` points to the correct file
- Ensure the file exists and is readable

### Error: "Account ID not set"
- Get your Account ID from DocuSign Admin → Settings → My Account Information
- Add it to your `.env` file

## Testing

Once set up, test by:
1. Sending a proposal to a client
2. Client clicks "Sign Proposal"
3. The system should create a DocuSign envelope and return a signing URL
4. Client can sign the document in the embedded modal

## Production vs Demo

- **Demo**: Use `account-d.docusign.com` and `https://demo.docusign.net/restapi`
- **Production**: Use `account.docusign.com` and `https://www.docusign.net/restapi`

Make sure to update your environment variables when moving to production.


