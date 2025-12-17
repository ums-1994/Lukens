# Tests Directory

This directory contains integration and manual test scripts for the ProposalHub application.

**All test files have been moved here from the `backend/` directory and root level to keep the codebase organized.**

## Directory Structure

```
tests/
├── integration/          # Integration tests
│   ├── backend/         # Backend service tests (9 files)
│   │   ├── test_ai_service.py
│   │   ├── test_comments_api.py
│   │   ├── test_connection_pool.py
│   │   ├── test_db_connection.py
│   │   ├── test_different_formats.py
│   │   ├── test_docusign.py
│   │   ├── test_docusign_sdk.py
│   │   ├── test_proposal_signing.py
│   │   └── quick_test.py
│   └── api/             # API endpoint tests (6 files)
│       ├── test_client_dashboard.py
│       ├── test_cloudinary.py
│       ├── test_content_endpoint.py
│       ├── test_login.py
│       ├── test_signature_flow.py
│       └── test_upload_endpoint.py
└── README.md            # This file
```

## Test Categories

### Backend Integration Tests
Tests that verify backend services and components:
- Database connections
- Connection pooling
- AI service integration
- DocuSign integration
- File format handling

### API Integration Tests
Tests that verify API endpoints:
- Authentication
- File uploads
- Content library
- Comments API
- Client dashboard
- Signature flow

## Running Tests

### Prerequisites
1. Backend server must be running: `python backend/app.py`
2. Database must be configured and accessible
3. Environment variables must be set (`.env` file)

### Individual Test Execution

```bash
# Backend tests
cd backend
python test_ai_service.py
python test_db_connection.py
python test_connection_pool.py
python test_docusign.py
python test_proposal_signing.py

# API tests (from root)
python test_login.py
python test_upload_endpoint.py
python test_content_endpoint.py
python test_client_dashboard.py
python test_signature_flow.py
```

## Test Status

See [TEST_FILES_SUMMARY.md](../docs/TEST_FILES_SUMMARY.md) for detailed information about each test file.

## Future Improvements

1. **Convert to pytest**: Use proper test framework with fixtures
2. **Add unit tests**: Test individual functions in isolation
3. **Automated testing**: Add CI/CD integration
4. **Test data management**: Use fixtures and test databases
5. **Coverage reporting**: Track which code is tested

## Notes

- Most tests are manual scripts, not automated test suites
- Tests may use hardcoded credentials - update for your environment
- Some tests require specific services to be running (DocuSign, Cloudinary, etc.)

