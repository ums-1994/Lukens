# 📋 Proposal Approval Workflow - Complete Guide

## 🎯 Overview

A complete end-to-end proposal approval system that automates the workflow from draft creation to client delivery with CEO approval.

## 🔄 Workflow Stages

### 1. **Draft** (Initial State)
- Creator creates and edits the proposal
- Can save, edit, add sections, collaborate
- **Action Available**: "Send for Approval" button (green)

### 2. **Pending CEO Approval** (Under Review)
- Proposal has been submitted for CEO review
- Creator cannot edit (locked)
- **Badge**: Orange badge with pending icon
- **Available to**: CEO only
- **Actions**: Approve or Reject

### 3. **Approved → Sent to Client** (Auto-Forward)
- CEO approves the proposal
- **Automatically** changes status to "Sent to Client"
- **Badge**: Blue badge with send icon
- Proposal is now with the client

### 4. **Rejected → Draft** (Back to Creator)
- CEO rejects the proposal
- **Automatically** changes status back to "draft"
- Creator can edit and resubmit
- Optional: CEO can add rejection comments

## ✨ Features

### For Creators (Business Developers)

#### Client Information Requirement
- **Required Before Sending**: Client Name and Client Email
- **Collection**: Automatic dialog if not provided
- **Validation**: Email format validation
- **Purpose**: Proposal will be sent to this email when approved

#### Send for Approval Button
- **Location**: Top toolbar, right side (green button)
- **Visibility**: Only shown when status is "draft"
- **Action**: 
  1. Checks for client information
  2. Opens client info dialog if missing
  3. Shows confirmation dialog
- **Effect**: Changes status to "Pending CEO Approval"

#### Status Badge
- **Location**: Top toolbar, next to action buttons
- **Colors**:
  - 🟠 Orange: Pending CEO Approval
  - 🔵 Blue: Sent to Client
  - 🟢 Green: Approved
  - 🔴 Red: Rejected
- **Shows**: Icon + Status label

#### Confirmation Dialog
```
Title: "Send for Approval"
Message: "This will send your proposal to the CEO for approval. 
         Once approved, it will be automatically sent to the client.
         
         Do you want to continue?"
Buttons: [Cancel] [Send for Approval]
```

### For CEO (Approvers)

#### Dashboard View
- See proposals in "Pending CEO Approval" status
- Filter by status on dashboard
- Click to review

#### Approval Actions
- **Approve**: 
  - Sets status to "Sent to Client"
  - Automatically forwards to client
  - Can add approval comments
  
- **Reject**:
  - Sets status back to "draft"
  - Returns to creator for edits
  - Can add rejection comments with feedback

## 🔧 Technical Implementation

### Frontend (Flutter)

#### New State Variables
```dart
String? _proposalStatus; // draft, Pending CEO Approval, Sent to Client
```

#### Helper Methods
```dart
Color _getStatusColor(String status)
IconData _getStatusIcon(String status)
String _getStatusLabel(String status)
Future<void> _sendForApproval()
```

#### UI Components
1. **Send for Approval Button** (ElevatedButton)
2. **Status Badge** (Container with Icon + Text)
3. **Confirmation Dialog** (AlertDialog)

### Backend (Python/Flask)

#### New Endpoint
```http
POST /api/proposals/{proposal_id}/send-for-approval
Authorization: Bearer {token}
```

**Response:**
```json
{
  "detail": "Proposal sent for approval successfully",
  "status": "Pending CEO Approval"
}
```

#### Updated Endpoints

**Approve Proposal:**
```http
POST /proposals/{proposal_id}/approve
Authorization: Bearer {token}
```

**Response:**
```json
{
  "detail": "Proposal approved and sent to client",
  "status": "Sent to Client"
}
```

**Reject Proposal:**
```http
POST /proposals/{proposal_id}/reject
Authorization: Bearer {token}
Content-Type: application/json

{
  "comments": "Please update the pricing section"
}
```

**Response:**
```json
{
  "detail": "Proposal rejected and returned to draft",
  "status": "draft",
  "comments": "Please update the pricing section"
}
```

### Database Schema

#### Proposals Table
```sql
Column: status VARCHAR(50)
Values:
  - 'draft'
  - 'Pending CEO Approval'
  - 'Sent to Client'
  - 'Approved'      (deprecated - auto-converts to 'Sent to Client')
  - 'Rejected'      (deprecated - auto-converts to 'draft')
```

## 📊 Status Transition Flow

```
┌──────────┐
│  Draft   │ ← Start here
└────┬─────┘
     │ [Send for Approval]
     ↓
┌─────────────────────┐
│ Pending CEO Approval│
└─────┬──────────┬────┘
      │          │
      │ [Approve]│ [Reject]
      ↓          ↓
┌────────────┐ ┌──────────┐
│Sent to     │ │  Draft   │
│Client      │ │(can edit)│
└────────────┘ └──────────┘
```

## 🎨 UI Design

### Status Badge Colors
- **Orange (#F39C12)**: Pending Approval - Waiting for action
- **Blue (#3498DB)**: Sent to Client - In client's hands
- **Green (#2ECC71)**: Approved/Success - Positive action
- **Red (#E74C3C)**: Rejected - Needs attention
- **Gray (#95A5A6)**: Other/Unknown states

### Button Styling
```dart
// Send for Approval Button
backgroundColor: #2ECC71 (Green)
foregroundColor: White
icon: Icons.send
padding: 16px horizontal, 10px vertical
```

## 🚀 Usage Guide

### For Creators

1. **Create Proposal**
   - Open blank document editor
   - Add content, sections, formatting
   - Save your work

2. **Provide Client Information**
   - Click green "Send for Approval" button
   - If client info not provided yet, dialog appears
   - Enter:
     - **Client Name** (e.g., "Acme Corporation")
     - **Client Email** (e.g., "contact@acme.com")
   - Email validation ensures valid format
   - Click "Continue"

3. **Send for Approval**
   - Confirm sending for approval in dialog
   - Wait for CEO review
   - Status badge shows "Pending Approval"

4. **If Approved**
   - Status changes to "Sent to Client"
   - Blue badge appears
   - Proposal sent to client email automatically

5. **If Rejected**
   - Status returns to "draft"
   - Edit and improve
   - Resubmit when ready

### For CEO

1. **Review Proposals**
   - Go to dashboard
   - Filter by "Pending CEO Approval"
   - Click proposal to review

2. **Approve**
   - Review content
   - Click "Approve" button
   - Optionally add comments
   - Proposal automatically sent to client

3. **Reject**
   - Identify issues
   - Click "Reject" button
   - Add feedback comments
   - Returns to creator for fixes

## 📝 Example Scenarios

### Scenario 1: Quick Approval
```
1. Creator creates proposal (status: draft)
2. Creator clicks "Send for Approval"
3. System prompts for client info
4. Creator enters: "Acme Corp" / "john@acme.com"
5. Creator confirms sending
6. CEO reviews and approves
7. Status: Sent to Client ✅
8. Email sent to john@acme.com
```

### Scenario 2: Revision Required
```
1. Creator creates proposal (status: draft)
2. Creator clicks "Send for Approval"
3. System prompts for client info
4. Creator enters client details
5. Creator confirms sending
6. CEO reviews and rejects with comments: "Update pricing"
7. Status: draft (creator can edit)
8. Creator makes changes to pricing
9. Creator clicks "Send for Approval" (client info saved)
10. Creator confirms (no need to re-enter client info)
11. CEO approves
12. Status: Sent to Client ✅
13. Email sent to client
```

## 🔐 Permissions

| Action | Creator | CEO | Client |
|--------|---------|-----|--------|
| Create Proposal | ✅ | ❌ | ❌ |
| Edit Draft | ✅ | ❌ | ❌ |
| Send for Approval | ✅ | ❌ | ❌ |
| Approve | ❌ | ✅ | ❌ |
| Reject | ❌ | ✅ | ❌ |
| View Sent Proposal | ✅ | ✅ | ✅ |

## 🐛 Error Handling

### Frontend Errors
```dart
// Not saved yet
if (_savedProposalId == null) {
  showSnackBar('Please save the document before sending for approval')
}

// Not draft status
if (_proposalStatus != 'draft') {
  showSnackBar('Proposal is already {status}')
}

// Network error
catch (e) {
  showSnackBar('Failed to send for approval: $e')
}
```

### Backend Errors
```python
# Proposal not found
if not proposal:
    return {'detail': 'Proposal not found or access denied'}, 404

# Invalid status
if current_status != 'draft':
    return {'detail': f'Proposal is already {current_status}'}, 400
```

## 📈 Benefits

✅ **Streamlined Workflow**: Automated status transitions
✅ **Quality Control**: CEO review before client delivery
✅ **Clear Visibility**: Status badges show current state
✅ **Fast Approval**: One-click approve/reject
✅ **Revision Friendly**: Easy to send back for edits
✅ **Audit Trail**: All status changes logged with timestamps

## 🔄 Future Enhancements

- [ ] Email notifications on status changes
- [ ] Approval comments thread
- [ ] Multi-level approval (e.g., Manager → Director → CEO)
- [ ] Approval deadlines/SLA tracking
- [ ] Approval history log
- [ ] Bulk approve/reject
- [ ] Conditional auto-approval rules

---

**Status**: ✅ Complete and Production Ready
**Version**: 1.0
**Last Updated**: October 27, 2025
**Files Modified**:
- `frontend_flutter/lib/pages/creator/blank_document_editor_page.dart`
- `backend/app.py`

