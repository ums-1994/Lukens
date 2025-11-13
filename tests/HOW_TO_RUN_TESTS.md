# How to Run Tests

## Quick Start

1. **Start the backend server first:**
   ```bash
   cd backend
   python app.py
   ```
   Keep this running in one terminal.

2. **In another terminal, run tests from the project root:**
   ```bash
   python tests/integration/backend/test_db_connection.py
   ```

## Test Categories

### Backend Service Tests
These test backend components directly (require backend directory in path):

- `test_ai_service.py` - AI integration
- `test_connection_pool.py` - Database connection pool
- `test_db_connection.py` - Database connectivity
- `test_docusign.py` - DocuSign configuration
- `test_docusign_sdk.py` - DocuSign SDK
- `test_proposal_signing.py` - Signing flow
- `test_comments_api.py` - Comments API
- `test_different_formats.py` - JWT format debugging
- `quick_test.py` - Quick DocuSign test

### API Endpoint Tests
These test API endpoints via HTTP (require backend server running):

- `test_login.py` - Authentication
- `test_upload_endpoint.py` - File uploads
- `test_content_endpoint.py` - Content library
- `test_client_dashboard.py` - Client portal
- `test_signature_flow.py` - Signature flow
- `test_cloudinary.py` - Cloudinary integration

## Running All Tests

### Option 1: Run individually
```bash
# From project root
python tests/integration/backend/test_ai_service.py
python tests/integration/backend/test_db_connection.py
# ... etc
```

### Option 2: Use a script (create this)
```bash
# Create run_all_tests.py in tests/ directory
# Then run: python tests/run_all_tests.py
```

## Prerequisites

1. **Backend server running** on `http://localhost:8000`
2. **Database configured** (PostgreSQL or SQLite)
3. **Environment variables set** (`.env` file in project root)
4. **Dependencies installed** (`pip install -r backend/requirements.txt`)

## Common Issues

### Import Errors
If you see import errors, make sure:
- You're running from the project root directory
- The backend directory exists and has the required modules
- Python path includes the backend directory (tests handle this automatically)

### Connection Errors
If tests can't connect:
- Check backend server is running
- Verify database is accessible
- Check environment variables in `.env` file

### DocuSign Tests Fail
- Ensure DocuSign credentials are set in `.env`
- Verify private key file exists
- Check DocuSign account is configured

## Notes

- Tests are **manual scripts**, not automated test suites
- Some tests may use **hardcoded credentials** - update for your environment
- Tests may create **test data** - clean up if needed
- **Backend server must be running** for API tests to work

