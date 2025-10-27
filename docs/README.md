# 📚 Lukens Documentation

Welcome to the comprehensive documentation for the Lukens Proposal & SOW Builder platform.

---

## 📂 Documentation Structure

### 🌟 [Features](./features/)
Documentation for major platform features and capabilities.

**Key Documents:**
- **[AI Assistant Implementation](./features/AI_ASSISTANT_IMPLEMENTATION_SUMMARY.md)** - Complete AI-powered proposal generation system
- **[Collaboration & Invitations](./features/COLLABORATION_INVITATION_FEATURE.md)** - Email invitation system for external collaborators
- **[Collaboration Quick Start](./features/COLLABORATION_QUICK_START.md)** - Quick guide to invite and manage collaborators
- **[Versioning & Comments](./features/VERSIONING_COMMENTS_INTEGRATION_COMPLETE.md)** - Document versioning and commenting system

### 📖 [Guides](./guides/)
Setup instructions, configuration guides, and how-tos.

**Setup & Configuration:**
- **[Quick Start Guide](./guides/QUICK_START.md)** - Get started quickly
- **[Quick Setup](./guides/QUICK_SETUP.md)** - Fast installation guide
- **[Setup Without Docker](./guides/SETUP_WITHOUT_DOCKER.md)** - Manual installation
- **[Database Setup](./guides/DATABASE_SETUP.md)** - PostgreSQL configuration
- **[SMTP Setup](./guides/SMTP_SETUP_GUIDE.md)** - Email configuration
- **[Port Configuration](./guides/PORT_CONFIGURATION.md)** - Port allocation and conflicts

**Feature Configuration:**
- **[Cloudinary Setup](./guides/CLOUDINARY_SETUP.md)** - Image storage configuration
- **[Content Library Guide](./guides/CONTENT_LIBRARY_GUIDE.md)** - Managing content templates
- **[Content Library Quick Reference](./guides/CONTENT_LIBRARY_QUICK_REF.md)** - Quick reference guide
- **[Currency Configuration](./guides/CURRENCY_CONFIGURATION_GUIDE.md)** - Multi-currency setup
- **[Document Upload Guide](./guides/DOCUMENT_UPLOAD_GUIDE.md)** - File upload configuration
- **[UI Integration Guide](./guides/UI_INTEGRATION_GUIDE.md)** - Frontend integration guide

### 🔧 [Fixes](./fixes/)
Bug fix summaries and troubleshooting documentation.

**Backend Fixes:**
- **[Authentication Fix](./fixes/AUTHENTICATION_FIX_SUMMARY.md)** - Auth system fixes
- **[Auto-save Authentication](./fixes/AUTO_SAVE_AUTHENTICATION_FIX.md)** - Auto-save with auth
- **[Connection Pool Fix](./fixes/CONNECTION_POOL_FIX_SUMMARY.md)** - Database connection pool
- **[Server Fix Guide](./fixes/SERVER_FIX_GUIDE.md)** - Server troubleshooting

**Feature Fixes:**
- **[Content Library Fix](./fixes/CONTENT_LIBRARY_FIX.md)** - Content library issues
- **[Document Auto-save](./fixes/DOCUMENT_AUTOSAVE_AND_BACKEND_INTEGRATION.md)** - Auto-save backend integration
- **[Document Upload Fix](./fixes/DOCUMENT_UPLOAD_FIX_SUMMARY.md)** - Upload functionality fixes
- **[Duplicate Proposals Fix](./fixes/DUPLICATE_PROPOSALS_FIX.md)** - Duplicate prevention
- **[Proposals Fix](./fixes/PROPOSALS_FIX_SUMMARY.md)** - General proposal fixes
- **[Quick Fix Checklist](./fixes/QUICK_FIX_CHECKLIST.md)** - Common fixes checklist

### 📊 [Status](./status/)
Implementation status, progress tracking, and summaries.

**Implementation Status:**
- **[Implementation Status](./status/IMPLEMENTATION_STATUS.md)** - Overall project status
- **[JIRA Tickets Status](./status/JIRA_TICKETS_STATUS.md)** - Ticket tracking
- **[Today's Implementation](./status/TODAYS_IMPLEMENTATION_SUMMARY.md)** - Daily progress
- **[Ticket 4 Enhancement](./status/TICKET_4_ENHANCEMENT_COMPLETE.md)** - Specific ticket completion

**Feature Status:**
- **[Content Library Summary](./status/CONTENT_LIBRARY_SUMMARY.md)** - Content library status
- **[Content Library Inventory](./status/CONTENT_LIBRARY_INVENTORY.md)** - Available content
- **[Currency Update Summary](./status/CURRENCY_UPDATE_SUMMARY.md)** - Currency feature status
- **[Versioning & Comments Status](./status/VERSIONING_AND_COMMENTS_STATUS.md)** - Version control status
- **[Test Document Upload](./status/test_document_upload.md)** - Upload testing status

---

## 🚀 Quick Links

### For New Users
1. Start with **[Quick Start Guide](./guides/QUICK_START.md)**
2. Set up database: **[Database Setup](./guides/DATABASE_SETUP.md)**
3. Configure email: **[SMTP Setup](./guides/SMTP_SETUP_GUIDE.md)**
4. Learn about features: **[Features Directory](./features/)**

### For Developers
1. Review **[Implementation Status](./status/IMPLEMENTATION_STATUS.md)**
2. Check **[JIRA Tickets](./status/JIRA_TICKETS_STATUS.md)**
3. Read **[Server Fix Guide](./fixes/SERVER_FIX_GUIDE.md)** for troubleshooting
4. Explore **[API Documentation](./features/)** in feature docs

### For Administrators
1. **[Setup Without Docker](./guides/SETUP_WITHOUT_DOCKER.md)** - Production setup
2. **[Database Setup](./guides/DATABASE_SETUP.md)** - Database configuration
3. **[SMTP Setup](./guides/SMTP_SETUP_GUIDE.md)** - Email configuration
4. **[Cloudinary Setup](./guides/CLOUDINARY_SETUP.md)** - File storage

---

## 🎯 Key Features Documentation

### 🤖 AI Assistant
The AI-powered proposal generation system using Claude 3.5 Sonnet.

**Features:**
- Generate individual proposal sections
- Generate complete 12-section proposals
- Improve existing content
- Multi-currency support (ZAR default)
- Usage analytics and tracking

**Read:** [AI Assistant Implementation](./features/AI_ASSISTANT_IMPLEMENTATION_SUMMARY.md)

### 👥 Collaboration System
Email-based collaboration with external users (no account required).

**Features:**
- Email invitations with secure tokens
- View-only or comment permissions
- Guest access without login
- Real-time commenting
- Collaborator management

**Read:** 
- [Collaboration Feature](./features/COLLABORATION_INVITATION_FEATURE.md)
- [Quick Start Guide](./features/COLLABORATION_QUICK_START.md)

### 📝 Versioning & Comments
Document version control and collaborative commenting.

**Features:**
- Automatic version creation
- Version history tracking
- Section-specific comments
- Comment status (open/resolved)
- Comment threading

**Read:** [Versioning & Comments](./features/VERSIONING_COMMENTS_INTEGRATION_COMPLETE.md)

---

## 🛠️ System Architecture

### Backend Stack
- **Python/Flask** - REST API
- **PostgreSQL** - Primary database
- **OpenRouter/Claude** - AI services
- **Cloudinary** - Image storage
- **SMTP** - Email delivery

### Frontend Stack
- **Flutter Web** - UI framework
- **HTTP Client** - API communication
- **Provider** - State management
- **Firebase** - Real-time features

### Key Endpoints
```
Authentication:
  POST /register
  POST /login
  GET  /me

Proposals:
  GET    /proposals
  POST   /proposals
  PUT    /proposals/{id}
  DELETE /proposals/{id}

AI Features:
  POST /ai/generate
  POST /ai/improve
  POST /ai/generate-full-proposal
  GET  /ai/analytics/summary

Collaboration:
  POST   /api/proposals/{id}/invite
  GET    /api/proposals/{id}/collaborators
  DELETE /api/collaborations/{id}
  GET    /api/collaborate?token={token}
  POST   /api/collaborate/comment

Comments:
  POST /api/comments/document/{id}
  GET  /api/comments/proposal/{id}
```

---

## 📈 Project Statistics

**Total Documentation Files:** 30+

**Categories:**
- 🌟 Features: 4 documents
- 📖 Guides: 11 documents
- 🔧 Fixes: 10 documents
- 📊 Status: 8 documents

**Last Updated:** October 2025

---

## 🤝 Contributing

When adding new documentation:

1. **Choose the right category:**
   - New feature? → `features/`
   - Setup guide? → `guides/`
   - Bug fix? → `fixes/`
   - Status update? → `status/`

2. **Follow naming conventions:**
   - Use UPPERCASE for major docs
   - Use descriptive names
   - End with `.md`

3. **Update this README:**
   - Add your document to the appropriate section
   - Update quick links if relevant
   - Increment statistics

---

## 📞 Support

**Need Help?**
1. Check **[Quick Start Guide](./guides/QUICK_START.md)**
2. Review **[Fixes](./fixes/)** for common issues
3. Check **[Status](./status/)** for known issues
4. Review feature-specific docs in **[Features](./features/)**

**Found a Bug?**
- Document the fix in `fixes/`
- Update relevant status docs in `status/`
- Update this README if it affects setup

---

## 🏆 Highlights

✅ **Comprehensive Coverage** - All major features documented  
✅ **Well Organized** - Easy to find what you need  
✅ **Up to Date** - Regularly maintained  
✅ **Developer Friendly** - Clear examples and code snippets  
✅ **User Focused** - Guides for all skill levels  

---

## 📝 Document Templates

When creating new documentation, follow these templates:

### Feature Documentation
```markdown
# Feature Name

## Overview
Brief description

## Key Features
- Feature 1
- Feature 2

## Architecture
Technical details

## Usage
How to use

## API Reference
Endpoints and examples

## Configuration
Setup instructions
```

### Setup Guide
```markdown
# Setup Guide: Topic

## Prerequisites
What you need

## Step-by-Step Instructions
1. Step one
2. Step two

## Configuration
Config details

## Verification
How to test

## Troubleshooting
Common issues
```

### Fix Documentation
```markdown
# Fix: Issue Name

## Problem Description
What was broken

## Root Cause
Why it broke

## Solution
How we fixed it

## Verification
How to verify the fix

## Prevention
How to avoid in future
```

---

## 🎓 Learning Path

### Beginner
1. Read [Quick Start](./guides/QUICK_START.md)
2. Set up [Database](./guides/DATABASE_SETUP.md)
3. Configure [SMTP](./guides/SMTP_SETUP_GUIDE.md)
4. Try creating proposals

### Intermediate
1. Learn [AI Assistant](./features/AI_ASSISTANT_IMPLEMENTATION_SUMMARY.md)
2. Set up [Collaboration](./features/COLLABORATION_QUICK_START.md)
3. Configure [Content Library](./guides/CONTENT_LIBRARY_GUIDE.md)
4. Explore [Versioning](./features/VERSIONING_COMMENTS_INTEGRATION_COMPLETE.md)

### Advanced
1. Review [Architecture](./status/IMPLEMENTATION_STATUS.md)
2. Study [API Endpoints](./features/)
3. Understand [Database Schema](./guides/DATABASE_SETUP.md)
4. Optimize [Performance](./fixes/)

---

**Last Updated:** October 27, 2025  
**Version:** 2.0  
**Maintainers:** Development Team

