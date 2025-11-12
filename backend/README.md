# Backend (FastAPI) for Proposal & SOW Builder v2

Run:
```
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```
DB: Uses SQLite at `backend/content.db` for content library and a `storage.json` for proposals (simple demo).

## Local setup (teammates)

1) Environment
```
cd backend
python -m venv .venv
.venv\Scripts\activate  # PowerShell on Windows
python -m pip install -r requirements.txt
```
Copy `env_template.txt` to `.env` and fill:
- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
- SENDGRID_API_KEY (or your email provider key)
- FRONTEND_URL (e.g. http://localhost:3000)
- KHONOLOGY_LOGO_URL (Cloudinary secure URL for the logo)

2) Database
```
cd backend
python create_client_tables.py
python apply_email_verification_migration.py
```

3) Run backend
```
cd backend
python app.py
```

4) Frontend (in a separate terminal)
```
cd frontend_flutter
flutter pub get
flutter run -d chrome --web-port 3000
```

## Email verification flow
- Send invitation from Client Management
- Recipient opens link, requests email code, enters code, proceeds to form
- Admin can re-send a verification code from Client Management

Endpoints used:
- GET /clients/invitations (includes email verification fields)
- POST /clients/invitations/:id/send-code (admin action)
- Public: POST /onboard/:token/verify-email and /onboard/:token/verify-code