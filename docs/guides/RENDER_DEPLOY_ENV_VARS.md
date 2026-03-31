---
description: Render deployment environment variables
---

# Render Deployment: Environment Variables

This document lists the environment variables that must be configured in Render for the Lukens Proposal & SOW Builder.

## Backend (Render Web Service: `lukens-backend`)

### Required

- `DATABASE_URL`
  - Use Render Postgres `connectionString`.

- `FRONTEND_URL`
  - Public frontend base URL (no trailing slash recommended).
  - Example: `https://lukens-frontend.onrender.com`

- `ENCRYPTION_KEY`
  - 32 url-safe base64 bytes for Fernet.

### DocuSign (required for production signing)

- `ENABLE_DOCUSIGN`
  - `true` or `false`

- `DOCUSIGN_INTEGRATION_KEY`
- `DOCUSIGN_USER_ID`
- `DOCUSIGN_ACCOUNT_ID`
- `DOCUSIGN_PRIVATE_KEY`
  - Private key content (recommended), OR use `DOCUSIGN_PRIVATE_KEY_PATH` if your deploy process mounts a file.

- `DOCUSIGN_OAUTH_BASE_PATH`
  - Demo: `account-d.docusign.com`
  - Prod: `account.docusign.com`

- `DOCUSIGN_BASE_PATH`
  - Demo: `https://demo.docusign.net/restapi`
  - Prod: `https://www.docusign.net/restapi`

### Email (SMTP)

- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASS`
- `SMTP_FROM`
  - Example: `Khonology <noreply@yourdomain.com>`

### Firebase Auth (admin portal)

Provide the Firebase credentials expected by the backend’s Firebase verification logic (exact key names depend on the current implementation). Configure the same values used in local dev.

### Optional

- `CORS_ALLOWED_ORIGINS`
  - Comma-separated origin allowlist overrides.
  - Example: `https://lukens-frontend.onrender.com,https://your-custom-domain.com`

- `DEV_BYPASS_CLIENT_IDENTITY`
  - `true` only for development.
  - Keep `false` in production.

## Frontend (Render Static Site: `lukens-frontend`)

### Required

- `APP_API_URL`
  - Must be set to the backend public URL.
  - Example: `https://lukens-backend.onrender.com`

## Notes / Common Pitfalls

- DocuSign redirect/return URLs must match the deployed frontend URL. The backend builds a return URL of the form:
  - `FRONTEND_URL + '/#/client/proposals?token=...&signed=true'`

- If DocuSign credentials are missing or invalid, the app may still email the client link, but the signing link may not be created.

- Ensure both frontend and backend are HTTPS in production.
