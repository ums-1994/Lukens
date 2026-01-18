# Render Deployment URLs

This document records the production URLs used for the Render deployment.

## Services
- **Backend (Flask)**: https://backend-sow.onrender.com
- **Frontend (Flutter Web)**: https://frontend-sow.onrender.com

## Environment Configuration

### Backend (.env on Render)
- `FRONTEND_URL=https://frontend-sow.onrender.com`
- `BACKEND_URL=https://backend-sow.onrender.com`
- `JWT_SECRET_KEY=PudwjIQa-kMPoQ8KCE9OqN3-HnIu2P12Dkf2U6rFH8I=`
- `ENCRYPTION_KEY=50g5j-Pa1SXyyABDbrghP0Spo1lZnQIGoWAIZBM_zZ0=`
- `FIREBASE_AUTH_ENABLED=false`
- `FIREBASE_LOGS_ENABLED=false`
- `DEV_BYPASS_AUTH=false`

### Frontend (web/config.js)
- `API_URL` defaults to `https://backend-sow.onrender.com` when hostname includes `onrender.com`

## Usage
- Access the app: https://frontend-sow.onrender.com
- Direct API: https://backend-sow.onrender.com/api/...
- JWT login endpoint: https://backend-sow.onrender.com/api/khonobuzz/jwt-login

## Token-based login flow
1. Navigate to https://frontend-sow.onrender.com/?token=YOUR_KHONOBUZZ_TOKEN
2. Landing page extracts token, calls backend, creates session, and redirects to the appropriate dashboard.
