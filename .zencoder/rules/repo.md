---
description: Repository Information Overview
alwaysApply: true
---

# Lukens - Proposal & SOW Builder

## Repository Summary

Lukens is a comprehensive AI-powered proposal and Statement of Work (SOW) builder with collaboration features, version control, and intelligent content generation. The system comprises a Python/Flask backend API and a Flutter web frontend, with PostgreSQL as the primary database.

## Repository Structure

### Main Components
- **backend/**: Python/Flask REST API - core application logic, proposal management, AI integration, and DocuSign e-signature
- **frontend_flutter/**: Flutter web application - user interface for proposal creation, editing, and collaboration
- **backend_api/**: Alternative Node.js backend implementation (not primary)
- **docs/**: Comprehensive documentation organized by category (guides, features, fixes, status)
- **.env** & **.env.example**: Environment configuration files

## Projects

### Backend (Python/Flask)
**Configuration File**: requirements.txt

#### Language & Runtime
**Language**: Python
**Version**: Python 3.9+ (currently 3.13.3)
**Build System**: Flask/FastAPI
**Package Manager**: pip

#### Dependencies
**Main Dependencies**:
- Flask 2.3.3, Flask-SQLAlchemy 3.0.3, Flask-Cors 3.0.10
- FastAPI 0.115.0, Uvicorn 0.30.6, Pydantic 2.9.2
- psycopg2-binary 2.9.9 (PostgreSQL adapter)
- ReportLab 4.0.9 (PDF generation)
- python-jose 3.3.0 (JWT tokens), passlib 1.7.4 (password hashing)
- docusign-esign 5.4.0+ (e-signature), cryptography 41.0.7
- cloudinary 1.36.0 (image storage)
- fastapi-mail 1.4.1 (email delivery)
- PyPDF2 4.0.1, python-docx 0.8.11 (document processing)

**Development Dependencies**:
- python-dotenv 1.0.0 (environment variables)
- requests 2.31.0 (HTTP client)

#### Build & Installation
`ash
cd backend
pip install -r requirements.txt
python app.py
`

#### Main Files & Architecture
**Entry Point**: backend/app.py (Flask application, ~4000+ lines)
**Key Modules**:
- app.py - Main application with all routes and API endpoints
- ai_service.py - AI integration (Claude 3.5 Sonnet via OpenRouter)
- models_compatible.py - SQLAlchemy database models
- cloudinary_config.py - Image storage configuration

**Database**: PostgreSQL with connection pooling
**API Base URL**: http://localhost:8000

#### Key Endpoints
- **Auth**: POST /register, POST /login, GET /me
- **Proposals**: GET/POST /proposals, PUT/DELETE /proposals/{id}
- **Content**: GET/POST /content, DELETE /content/{id}
- **DocuSign**: POST /api/proposals/{id}/docusign/send
- **Collaboration**: POST /api/proposals/{id}/invite, GET /api/collaborate?token=
- **Comments**: POST/GET /api/comments/document/{id}
- **AI**: POST /proposals/ai-analysis, /ai/generate

### Frontend (Flutter Web)
**Configuration File**: pubspec.yaml

#### Language & Runtime
**Language**: Dart
**Version**: Dart SDK 3.3.0+
**Framework**: Flutter 3.0+
**Build System**: Flutter build system

#### Dependencies
**Main Dependencies**:
- http 1.2.2 (API communication)
- provider 6.1.2 (state management)
- firebase_core 3.6.0, firebase_auth 5.3.1 (authentication)
- cloud_firestore 5.4.3 (real-time data)
- signature 5.0.0 (e-signature capture)
- cloudinary_flutter 1.3.0 (image management)
- google_fonts 6.2.1 (typography)
- flutter_riverpod 2.4.9 (reactive state management)
- file_picker 6.1.1, image_picker 1.0.4 (file handling)
- dio 5.3.1 (HTTP client)

**Development Dependencies**:
- flutter_test (testing framework)

#### Build & Installation
`ash
cd frontend_flutter
flutter pub get
flutter run -d chrome
`

#### Main Files & Architecture
**Entry Point**: frontend_flutter/lib/main.dart
**Key Structure**:
- **lib/pages/**: UI pages (creator, approver, admin, guest, shared)
- **lib/services/**: API services, authentication, role management
- **lib/widgets/**: Reusable UI components
- **lib/api.dart**: AppState provider and API client
- **web/**: Web-specific files (index.html, firebase-config.js)

**State Management**: Provider + Riverpod
**Firebase Config**: Embedded in main.dart (Project: lukens-e17d6)

## Configuration

### Environment Variables (.env)
**Database**:
- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

**AI Services**:
- OPENROUTER_API_KEY

**Email (SMTP)**:
- SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS

**Cloud Storage**:
- CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET

**Frontend**:
- FRONTEND_URL (default: http://localhost:8081)

**DocuSign**:
- DOCUSIGN_CLIENT_ID, DOCUSIGN_USER_ID, DOCUSIGN_PRIVATE_KEY, DOCUSIGN_RSA_KEY

**Security**:
- ENCRYPTION_KEY (32-char encryption key)
- JWT_SECRET

### Database
**Type**: PostgreSQL 12+
**Initialization**: backend/setup_compatible.py
**Schema Files**: backend/compatible_schema.sql, backend/database_schema.sql

## Build & Deployment

### Backend Build
`ash
cd backend
pip install -r requirements.txt
python app.py  # Development
# Production: uvicorn asgi:asgi_app --host 0.0.0.0 --port 8000
`

### Frontend Build
`ash
cd frontend_flutter
flutter pub get
flutter build web  # Production build
`

## Testing

### Backend Testing
**Framework**: pytest (implicit, test files present)
**Test Files**: backend/test_*.py files
`ash
python -m pytest
`

**Manual Tests**:
- test_login.py - Authentication tests
- test_upload_endpoint.py - File upload tests
- test_signature_flow.py - DocuSign workflow tests
- test_content_endpoint.py - Content management tests

### Frontend Testing
**Framework**: flutter_test
**Test Location**: Not explicitly organized, uses standard Flutter patterns

## Notes
- Primary backend: Python/Flask (backend/)
- Alternative backend: Node.js/Express (backend_api/ - not primary)
- Database: PostgreSQL (primary), SQLite (fallback/legacy)
- AI: Claude 3.5 Sonnet via OpenRouter
- Email: SMTP (Gmail-compatible)
- Image Storage: Cloudinary
- E-Signature: DocuSign REST API
