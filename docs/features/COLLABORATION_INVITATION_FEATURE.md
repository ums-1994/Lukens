# Collaboration Invitation Feature

## 📧 Overview

A comprehensive collaboration system that allows proposal creators to invite external collaborators via email. Invited users receive a secure link to view the proposal and add comments **without requiring an account**.

---

## ✨ Key Features

### 1. **Email Invitations**
- Send collaboration invitations directly from the document editor
- Customizable permission levels: **View Only** or **Can Comment**
- Automatic email delivery with secure access link
- 30-day expiration on invitation links

### 2. **Guest Access**
- No account registration required for invited collaborators
- Secure token-based authentication
- Read-only access to proposal content
- Ability to add comments (if permission granted)

### 3. **Collaboration Management**
- View all active collaborators for a proposal
- See invitation status (Pending/Active)
- Remove collaborator access at any time
- Track when collaborators first accessed the proposal

---

## 🏗️ Architecture

### Backend Components

#### Database Schema
```sql
CREATE TABLE collaboration_invitations (
    id SERIAL PRIMARY KEY,
    proposal_id INTEGER NOT NULL,
    invited_email VARCHAR(255) NOT NULL,
    invited_by INTEGER NOT NULL,
    access_token VARCHAR(500) UNIQUE NOT NULL,
    permission_level VARCHAR(50) DEFAULT 'comment',
    status VARCHAR(50) DEFAULT 'pending',
    invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    accessed_at TIMESTAMP,
    expires_at TIMESTAMP,
    FOREIGN KEY (proposal_id) REFERENCES proposals(id) ON DELETE CASCADE,
    FOREIGN KEY (invited_by) REFERENCES users(id)
);
```

#### API Endpoints

**1. Send Invitation**
```http
POST /api/proposals/{proposal_id}/invite
Authorization: Bearer {token}
Content-Type: application/json

{
  "email": "colleague@example.com",
  "permission_level": "comment"
}
```

**2. Get Collaborators**
```http
GET /api/proposals/{proposal_id}/collaborators
Authorization: Bearer {token}
```

**3. Remove Collaborator**
```http
DELETE /api/collaborations/{invitation_id}
Authorization: Bearer {token}
```

**4. Guest Access (No Auth Required)**
```http
GET /api/collaborate?token={access_token}
```

**5. Guest Comment (No Auth Required)**
```http
POST /api/collaborate/comment
Content-Type: application/json

{
  "token": "{access_token}",
  "comment_text": "This looks great!",
  "section_index": 0,
  "highlighted_text": "specific text"
}
```

---

## 🎨 Frontend Components

### 1. Collaboration Dialog (Editor)
**Location:** `frontend_flutter/lib/pages/creator/blank_document_editor_page.dart`

**Features:**
- Email input with validation
- Permission level dropdown
- Real-time invitation sending with loading state
- List of current collaborators with status badges
- Remove collaborator functionality

**Usage:**
```dart
// Click "Share" button in document editor
// Opens collaboration dialog
_showCollaborationDialog();
```

### 2. Guest Collaboration Page
**Location:** `frontend_flutter/lib/pages/guest/guest_collaboration_page.dart`

**Features:**
- Token-based access (no login required)
- Read-only proposal viewer
- Comments sidebar
- Add comments (if permitted)
- Real-time comment submission
- Beautiful, clean UI

**Route:** `/#/collaborate?token={access_token}`

---

## 📧 Email Template

Invited users receive a beautiful HTML email with:
- Proposal title
- Inviter's name/email
- Permission level (Comment/View)
- Secure access link (button + copyable URL)
- Expiration date
- Professional branding

**Example:**
```
Subject: You've been invited to collaborate on 'Q4 Marketing Proposal'

Hi there,

john@company.com has invited you to collaborate on the proposal:

┌─────────────────────────────────┐
│ Q4 Marketing Proposal           │
│ Permission: Can Comment         │
└─────────────────────────────────┘

You can view the proposal and add comments using the link below:

        [Open Proposal Button]

This invitation will expire on November 26, 2025 at 03:45 PM.
```

---

## 🔒 Security Features

### 1. **Token-Based Access**
- Unique, cryptographically secure tokens (32 bytes)
- Tokens stored in database, never exposed
- No password required for guests

### 2. **Expiration**
- Default 30-day expiration
- Configurable per invitation
- Automatic rejection of expired tokens

### 3. **Permission Levels**
- **View Only**: Can only read the proposal
- **Can Comment**: Can read and add comments
- Fine-grained access control

### 4. **Ownership Verification**
- Only proposal owners can send invitations
- Only owners can remove collaborators
- Cascading delete on proposal removal

---

## 🚀 Usage Flow

### For Proposal Creators

1. **Open Document Editor**
   - Navigate to any proposal in edit mode
   - Save the proposal first (required)

2. **Click "Share" Button**
   - Located in the top toolbar
   - Opens collaboration dialog

3. **Invite Collaborator**
   - Enter email address
   - Select permission level
   - Click "Send Invite"
   - Invitation email sent automatically

4. **Manage Collaborators**
   - View all invited users
   - See status (Pending/Active)
   - Remove access as needed

### For Invited Collaborators

1. **Receive Email**
   - Check inbox for invitation email
   - Click "Open Proposal" button

2. **View Proposal**
   - Opens in browser (no login needed)
   - See full proposal content
   - View existing comments

3. **Add Comments** (if permitted)
   - Type comment in sidebar
   - Click send icon
   - Comment appears immediately

---

## 📊 Benefits

### 1. **Seamless Collaboration**
- No account barriers
- Instant access via email
- Simple, focused interface

### 2. **Secure**
- Token-based authentication
- Time-limited access
- Permission controls

### 3. **Professional**
- Beautiful email templates
- Clean guest interface
- Real-time updates

### 4. **Efficient**
- Quick feedback loops
- Centralized comments
- Easy management

---

## 🎯 User Experience Highlights

### For Document Owners
✅ One-click invitation sending  
✅ Real-time status updates  
✅ Full control over access  
✅ Professional email delivery  

### For Invited Guests
✅ Zero friction access  
✅ No registration required  
✅ Clean, focused interface  
✅ Easy commenting  

---

## 🛠️ Technical Implementation

### Email Integration
- Uses existing SMTP configuration
- HTML email templates
- Secure token embedding
- Error handling with fallback

### Database Integration
- PostgreSQL with proper indexing
- Foreign key constraints
- Cascade delete protection
- Transaction safety

### Frontend Architecture
- Stateful Flutter widgets
- HTTP client for API calls
- Real-time UI updates
- Error boundary handling

### Backend Architecture
- RESTful API endpoints
- Token authentication
- Permission middleware
- Connection pooling

---

## 📝 Configuration

### Environment Variables
```env
# Required for email invitations
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# Frontend URL for link generation
# Note: Port 8080 is used by PostgreSQL, use 8081 for Flutter frontend
FRONTEND_URL=http://localhost:8081
```

### Database Setup
```bash
# Backend will auto-create tables on first run
# Or manually run:
python backend/app.py
```

---

## 🔧 Future Enhancements

### Potential Additions
- [ ] Collaboration expiration reminders
- [ ] In-app notifications for comments
- [ ] Multiple document sharing
- [ ] Team-based invitations
- [ ] Export comments to PDF
- [ ] Comment threading
- [ ] @mention functionality
- [ ] File attachments in comments
- [ ] Activity logs
- [ ] Custom expiration dates

---

## 🧪 Testing

### Manual Testing Steps

**1. Test Invitation Flow**
```
✓ Open document editor
✓ Save a proposal
✓ Click "Share" button
✓ Enter email address
✓ Select permission level
✓ Click "Send Invite"
✓ Verify email received
✓ Check invitation appears in list
```

**2. Test Guest Access**
```
✓ Click link in email
✓ Verify proposal loads
✓ Check permission level displayed
✓ Try adding comment (if permitted)
✓ Verify comment appears
```

**3. Test Access Control**
```
✓ Try accessing with expired token
✓ Try accessing removed invitation
✓ Verify view-only cannot comment
✓ Verify comment permission works
```

---

## 📚 API Reference

### Invite Collaborator
```javascript
POST /api/proposals/{proposal_id}/invite

Request:
{
  "email": "string",
  "permission_level": "comment" | "view"
}

Response (201):
{
  "id": number,
  "message": "Invitation sent successfully",
  "email_sent": boolean,
  "collaboration_url": "string",
  "expires_at": "ISO 8601 datetime"
}
```

### Get Collaboration Access
```javascript
GET /api/collaborate?token={access_token}

Response (200):
{
  "proposal": {
    "id": number,
    "title": "string",
    "content": "string",
    "owner_email": "string",
    "owner_name": "string"
  },
  "permission_level": "comment" | "view",
  "invited_email": "string",
  "comments": [...],
  "can_comment": boolean
}
```

### Add Guest Comment
```javascript
POST /api/collaborate/comment

Request:
{
  "token": "string",
  "comment_text": "string",
  "section_index": number | null,
  "highlighted_text": "string" | null
}

Response (201):
{
  "id": number,
  "proposal_id": number,
  "comment_text": "string",
  "created_by": "string",
  "created_at": "ISO 8601 datetime",
  "section_index": number | null,
  "highlighted_text": "string" | null,
  "status": "open"
}
```

---

## ✅ Implementation Complete!

All features are now fully implemented and ready to use:

✅ Database schema created  
✅ Backend API endpoints functional  
✅ Email invitation system working  
✅ Frontend collaboration dialog integrated  
✅ Guest view page complete  
✅ Comment system operational  
✅ Security measures in place  

**Start collaborating today!** 🎉

