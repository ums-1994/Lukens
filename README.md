# 📝 Lukens - Proposal & SOW Builder

A comprehensive, AI-powered proposal and Statement of Work (SOW) builder with collaboration features, version control, and intelligent content generation.

---

## ✨ Key Features

### 🤖 AI-Powered Content Generation
- Generate complete proposals in seconds using Claude 3.5 Sonnet
- Improve existing content with AI suggestions
- Support for 13+ section types
- Multi-currency support (ZAR default)
- Usage analytics and tracking

### 👥 Collaboration System
- Email-based invitations (no account required for guests)
- View-only or comment permissions
- Secure token-based access
- Real-time commenting
- Manage collaborators easily

### 📋 Document Management
- Rich text editor with formatting
- Auto-save functionality
- Version control with history
- Section-based organization
- PDF export capabilities

### 💬 Comments & Feedback
- Section-specific commenting
- Comment status tracking (open/resolved)
- Highlighted text references
- Real-time updates

### 📚 Content Library
- Template management
- Reusable content snippets
- Image asset storage (Cloudinary)
- Category organization

### ✅ Workflow & Governance
- Approval workflows
- Risk assessment gates
- Compound risk scoring
- Mock e-signature support
- Status tracking

---

## 🚀 Quick Start

### Prerequisites
- Python 3.9+
- PostgreSQL 12+
- Node.js 16+ (for Flutter web)
- Flutter SDK 3.0+

### 1. Backend Setup
```bash
cd backend
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run backend
python app.py
```

### 2. Frontend Setup
```bash
cd frontend_flutter
flutter pub get
flutter run -d chrome
```

### 3. Configuration
See detailed setup guides in [`docs/guides/`](./docs/guides/):
- [Quick Setup Guide](./docs/guides/QUICK_SETUP.md)
- [Database Setup](./docs/guides/DATABASE_SETUP.md)
- [SMTP Configuration](./docs/guides/SMTP_SETUP_GUIDE.md)

---

## 📚 Documentation

### 📂 [Complete Documentation](./docs/)

**Organized by category:**

- **[Features](./docs/features/)** - Major platform capabilities
  - [AI Assistant](./docs/features/AI_ASSISTANT_IMPLEMENTATION_SUMMARY.md)
  - [Collaboration System](./docs/features/COLLABORATION_INVITATION_FEATURE.md)
  - [Versioning & Comments](./docs/features/VERSIONING_COMMENTS_INTEGRATION_COMPLETE.md)

- **[Guides](./docs/guides/)** - Setup and configuration
  - [Quick Start](./docs/guides/QUICK_START.md)
  - [Database Setup](./docs/guides/DATABASE_SETUP.md)
  - [SMTP Setup](./docs/guides/SMTP_SETUP_GUIDE.md)
  - [Content Library](./docs/guides/CONTENT_LIBRARY_GUIDE.md)

- **[Fixes](./docs/fixes/)** - Troubleshooting and bug fixes
  - [Authentication Fixes](./docs/fixes/AUTHENTICATION_FIX_SUMMARY.md)
  - [Quick Fix Checklist](./docs/fixes/QUICK_FIX_CHECKLIST.md)
  - [Server Issues](./docs/fixes/SERVER_FIX_GUIDE.md)

- **[Status](./docs/status/)** - Implementation progress
  - [Overall Status](./docs/status/IMPLEMENTATION_STATUS.md)
  - [JIRA Tickets](./docs/status/JIRA_TICKETS_STATUS.md)

---

## 🏗️ Architecture

### Tech Stack

**Backend:**
- Python/Flask - REST API
- PostgreSQL - Primary database
- OpenRouter/Claude - AI services
- Cloudinary - Image storage
- SMTP - Email delivery

**Frontend:**
- Flutter Web - UI framework
- Provider - State management
- HTTP Client - API communication
- Firebase - Real-time features

### Project Structure
```
lukens/
├── backend/                 # Python/Flask API
│   ├── app.py              # Main application
│   ├── ai_service.py       # AI integration
│   ├── models_*.py         # Database models
│   └── requirements.txt    # Python dependencies
│
├── frontend_flutter/        # Flutter web app
│   ├── lib/
│   │   ├── pages/          # UI pages
│   │   ├── services/       # API services
│   │   └── widgets/        # Reusable components
│   └── pubspec.yaml        # Flutter dependencies
│
├── backend_api/            # Alternative Node.js backend
│   └── server.js
│
└── docs/                   # Documentation
    ├── features/           # Feature docs
    ├── guides/             # Setup guides
    ├── fixes/              # Fix summaries
    └── status/             # Progress tracking
```

---

## 🔑 Environment Configuration

Create a `.env` file in the `backend/` directory:

```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=proposal_db
DB_USER=postgres
DB_PASSWORD=your_password

# AI Services
OPENROUTER_API_KEY=your_openrouter_key

# Email (SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_app_password

# Cloudinary (Image Storage)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Frontend URL (use 8081, port 8080 is PostgreSQL)
FRONTEND_URL=http://localhost:8081

# Security
ENCRYPTION_KEY=your_32_char_encryption_key
```

---

## 🎯 Main Features

### 1. AI Assistant
Generate proposals and improve content with AI.

**Usage:**
1. Open document editor
2. Click "✨ AI Assistant" button
3. Choose action (Generate/Improve)
4. Enter requirements
5. AI generates content instantly

**[Read More](./docs/features/AI_ASSISTANT_IMPLEMENTATION_SUMMARY.md)**

### 2. Collaboration
Invite external users to view and comment.

**Usage:**
1. Open proposal
2. Click "Share" button
3. Enter email and permission level
4. Collaborator receives email with secure link
5. They can view and comment (no account needed)

**[Read More](./docs/features/COLLABORATION_INVITATION_FEATURE.md)**

### 3. Version Control
Track document changes over time.

**Features:**
- Automatic version creation
- Version history tracking
- Restore previous versions
- Change descriptions

**[Read More](./docs/features/VERSIONING_COMMENTS_INTEGRATION_COMPLETE.md)**

---

## 📊 API Endpoints

### Authentication
```
POST /register          - Create new account
POST /login            - User login
GET  /me               - Get current user
```

### Proposals
```
GET    /proposals            - List all proposals
POST   /proposals            - Create new proposal
PUT    /proposals/{id}       - Update proposal
DELETE /proposals/{id}       - Delete proposal
```

### AI Features
```
POST /ai/generate              - Generate section
POST /ai/improve               - Improve content
POST /ai/generate-full-proposal - Generate full proposal
GET  /ai/analytics/summary     - Usage analytics
```

### Collaboration
```
POST   /api/proposals/{id}/invite       - Send invitation
GET    /api/proposals/{id}/collaborators - List collaborators
DELETE /api/collaborations/{id}         - Remove collaborator
GET    /api/collaborate?token={token}   - Guest access
POST   /api/collaborate/comment         - Guest comment
```

### Comments
```
POST /api/comments/document/{id}  - Create comment
GET  /api/comments/proposal/{id}  - Get comments
```

---

## 🧪 Testing

### Run Backend Tests
```bash
cd backend
python -m pytest
```

### Test AI Integration
```bash
cd backend
python test_ai_service.py
```

### Manual Testing
See [Testing Checklist](./docs/status/test_document_upload.md)

---

## 🛠️ Development

### Backend Development
```bash
cd backend
python app.py  # Development server with auto-reload
```

### Frontend Development
```bash
cd frontend_flutter
flutter run -d chrome  # Hot reload enabled
```

### Database Migrations
```bash
cd backend
python setup_database.py  # Initialize schema
```

---

## 🐛 Troubleshooting

### Common Issues

**"Database connection failed"**
- Check PostgreSQL is running
- Verify `.env` database credentials
- Ensure database exists: `createdb proposal_db`

**"Email not sending"**
- Verify SMTP configuration in `.env`
- Check firewall/network settings
- Use app-specific password for Gmail

**"AI generation failing"**
- Verify `OPENROUTER_API_KEY` is set
- Check API key is valid
- Monitor usage limits

**More Solutions:**
- [Quick Fix Checklist](./docs/fixes/QUICK_FIX_CHECKLIST.md)
- [Server Fix Guide](./docs/fixes/SERVER_FIX_GUIDE.md)
- [Authentication Fixes](./docs/fixes/AUTHENTICATION_FIX_SUMMARY.md)

---

## 📈 Status

**Current Version:** 2.0  
**Status:** ✅ Production Ready

**Completed Features:**
- ✅ AI-powered content generation
- ✅ Collaboration with email invitations
- ✅ Version control and comments
- ✅ Content library management
- ✅ Auto-save functionality
- ✅ PDF export
- ✅ Approval workflows
- ✅ Analytics tracking

**See:** [Implementation Status](./docs/status/IMPLEMENTATION_STATUS.md)

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

---

## 📄 License

This project is proprietary software owned by Khonology/Lukens.

---

## 🙏 Acknowledgments

- **OpenRouter** - AI API access
- **Anthropic/Claude** - AI model
- **Cloudinary** - Image hosting
- **Flutter** - UI framework
- **PostgreSQL** - Database

---

## 📞 Support

**Need Help?**
1. Check [Documentation](./docs/)
2. Review [Quick Start Guide](./docs/guides/QUICK_START.md)
3. See [Troubleshooting](./docs/fixes/)
4. Contact development team

---

## 🎯 Quick Links

- [Complete Documentation](./docs/)
- [AI Assistant Guide](./docs/features/AI_ASSISTANT_IMPLEMENTATION_SUMMARY.md)
- [Collaboration Guide](./docs/features/COLLABORATION_QUICK_START.md)
- [Setup Without Docker](./docs/guides/SETUP_WITHOUT_DOCKER.md)
- [Implementation Status](./docs/status/IMPLEMENTATION_STATUS.md)

---

**Built with ❤️ by the Khonology Team**
