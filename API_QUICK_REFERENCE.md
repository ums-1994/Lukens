# 🚀 Collaboration API - Quick Reference

Copy-paste ready API calls for testing!

---

## 🔐 Authentication
All endpoints (except guest collaboration) require authentication header:
```
Authorization: Bearer YOUR_TOKEN_HERE
```

---

## 1️⃣ Suggestions

### Create Suggestion
```bash
POST http://localhost:8000/api/proposals/1/suggestions
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "section_id": "section-pricing",
  "original_text": "Total: $50,000",
  "suggestion_text": "Total: $45,000 (10% early bird discount)"
}
```

### Get All Suggestions
```bash
GET http://localhost:8000/api/proposals/1/suggestions
Authorization: Bearer YOUR_TOKEN
```

### Accept Suggestion
```bash
POST http://localhost:8000/api/proposals/1/suggestions/5/resolve
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "action": "accept"
}
```

### Reject Suggestion
```bash
POST http://localhost:8000/api/proposals/1/suggestions/5/resolve
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "action": "reject"
}
```

---

## 2️⃣ Section Locking

### Lock a Section
```bash
POST http://localhost:8000/api/proposals/1/sections/section-2/lock
Authorization: Bearer YOUR_TOKEN
```

**Response:**
```json
{
  "locked": true,
  "locked_by": "John Doe",
  "expires_at": "2025-10-28T15:35:00"
}
```

### Get All Locks
```bash
GET http://localhost:8000/api/proposals/1/sections/locks
Authorization: Bearer YOUR_TOKEN
```

### Unlock Section
```bash
POST http://localhost:8000/api/proposals/1/sections/section-2/unlock
Authorization: Bearer YOUR_TOKEN
```

---

## 3️⃣ Activity Timeline

### Get Activity Feed
```bash
GET http://localhost:8000/api/proposals/1/activity
Authorization: Bearer YOUR_TOKEN
```

**Response:**
```json
{
  "activities": [
    {
      "id": 15,
      "action_type": "comment_added",
      "action_description": "Jane Smith added a comment on section 3",
      "user_name": "Jane Smith",
      "user_email": "jane@company.com",
      "created_at": "2025-10-28T14:30:00",
      "metadata": {
        "comment_id": 45,
        "section_index": 3
      }
    }
  ]
}
```

---

## 4️⃣ Notifications

### Get All Notifications
```bash
GET http://localhost:8000/api/notifications
Authorization: Bearer YOUR_TOKEN
```

**Response:**
```json
{
  "notifications": [
    {
      "id": 123,
      "notification_type": "suggestion_created",
      "title": "New Suggestion",
      "message": "John Doe suggested a change to section-pricing",
      "proposal_title": "Cloud Migration Proposal",
      "is_read": false,
      "created_at": "2025-10-28T14:30:00"
    }
  ],
  "unread_count": 5
}
```

### Mark as Read
```bash
POST http://localhost:8000/api/notifications/123/mark-read
Authorization: Bearer YOUR_TOKEN
```

### Mark All as Read
```bash
POST http://localhost:8000/api/notifications/mark-all-read
Authorization: Bearer YOUR_TOKEN
```

---

## 5️⃣ Diff View (Version Comparison)

### Compare Two Versions
```bash
GET http://localhost:8000/api/proposals/1/versions/compare?version1=1&version2=2
Authorization: Bearer YOUR_TOKEN
```

**Response:**
```json
{
  "version1": {
    "version_number": 1,
    "created_at": "2025-10-28T10:00:00",
    "created_by": "John Doe"
  },
  "version2": {
    "version_number": 2,
    "created_at": "2025-10-28T14:30:00",
    "created_by": "Jane Smith"
  },
  "diff": "--- Version 1\n+++ Version 2\n@@ -15,7 +15,7 @@\n-Total: $50,000\n+Total: $45,000",
  "html_diff": "<table class='diff'>...</table>",
  "changes": {
    "additions": 12,
    "deletions": 8
  }
}
```

---

## 6️⃣ @Mentions

### Create Comment with Mention
```bash
POST http://localhost:8000/api/comments/document/1
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "comment_text": "Hey @jane, can you review this pricing section? Also @manager please approve.",
  "section_index": 3,
  "highlighted_text": "Total: $45,000"
}
```

**What Happens:**
- Extracts: `["jane", "manager"]`
- Creates mention records
- Sends notifications to both users

### Get My Mentions
```bash
GET http://localhost:8000/api/mentions
Authorization: Bearer YOUR_TOKEN
```

**Response:**
```json
{
  "mentions": [
    {
      "id": 456,
      "comment_id": 789,
      "comment_text": "Hey @jane, can you review this pricing?",
      "mentioned_by_name": "John Doe",
      "mentioned_by_email": "john@company.com",
      "proposal_title": "Cloud Migration Proposal",
      "proposal_id": 1,
      "section_index": 3,
      "created_at": "2025-10-28T14:30:00",
      "is_read": false
    }
  ],
  "unread_count": 3
}
```

### Mark Mention as Read
```bash
POST http://localhost:8000/api/mentions/456/mark-read
Authorization: Bearer YOUR_TOKEN
```

---

## 7️⃣ Comments (Enhanced)

### Add Section-Level Comment
```bash
POST http://localhost:8000/api/comments/document/1
Authorization: Bearer YOUR_TOKEN
Content-Type: application/json

{
  "comment_text": "This pricing looks great!",
  "section_index": 3,
  "highlighted_text": "Total: $45,000"
}
```

### Get All Comments
```bash
GET http://localhost:8000/api/comments/proposal/1
Authorization: Bearer YOUR_TOKEN
```

---

## 🧪 Testing Workflow

### Test 1: Full Suggestion Workflow
```bash
# Step 1: Create suggestion
POST /api/proposals/1/suggestions
Body: {
  "section_id": "section-pricing",
  "suggestion_text": "Updated pricing: $45,000",
  "original_text": "Original pricing: $50,000"
}

# Step 2: Check activity
GET /api/proposals/1/activity
→ Should see: "User suggested a change to section-pricing"

# Step 3: Check notifications
GET /api/notifications
→ Proposal owner should have notification

# Step 4: Get suggestions
GET /api/proposals/1/suggestions
→ Should see the pending suggestion

# Step 5: Accept it
POST /api/proposals/1/suggestions/1/resolve
Body: { "action": "accept" }

# Step 6: Verify activity updated
GET /api/proposals/1/activity
→ Should see: "User accepted a suggestion"
```

### Test 2: @Mention Workflow
```bash
# Step 1: Add comment with mention
POST /api/comments/document/1
Body: {
  "comment_text": "Hey @jane, thoughts on this?"
}

# Step 2: Check Jane's mentions (as Jane)
GET /api/mentions
→ Should see the mention with unread_count = 1

# Step 3: Check Jane's notifications
GET /api/notifications
→ Should have notification: "John mentioned you"

# Step 4: Mark as read
POST /api/mentions/1/mark-read
```

### Test 3: Diff View
```bash
# Step 1: Create version 1
POST /api/proposals
Body: { "content": { "title": "v1" } }

# Step 2: Update to version 2
PUT /api/proposals/1
Body: { "content": { "title": "v2 - updated" } }

# Step 3: Compare
GET /api/proposals/1/versions/compare?version1=1&version2=2
→ Should see diff showing title change
```

---

## 📋 Response Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (missing parameters) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 409 | Conflict (e.g., section already locked) |
| 500 | Server Error |

---

## 🔗 Postman Collection

Import this JSON into Postman:

```json
{
  "info": {
    "name": "Collaboration API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Suggestions",
      "item": [
        {
          "name": "Create Suggestion",
          "request": {
            "method": "POST",
            "header": [
              {"key": "Authorization", "value": "Bearer {{token}}"},
              {"key": "Content-Type", "value": "application/json"}
            ],
            "body": {
              "mode": "raw",
              "raw": "{\"section_id\":\"section-1\",\"suggestion_text\":\"New text\",\"original_text\":\"Old text\"}"
            },
            "url": "{{baseUrl}}/api/proposals/{{proposalId}}/suggestions"
          }
        }
      ]
    }
  ],
  "variable": [
    {"key": "baseUrl", "value": "http://localhost:8000"},
    {"key": "token", "value": "YOUR_TOKEN_HERE"},
    {"key": "proposalId", "value": "1"}
  ]
}
```

---

## ⚡ Quick Copy-Paste

**Get notifications:**
```
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8000/api/notifications
```

**Create suggestion:**
```
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" -H "Content-Type: application/json" \
  -d '{"section_id":"section-1","suggestion_text":"New","original_text":"Old"}' \
  http://localhost:8000/api/proposals/1/suggestions
```

**Get mentions:**
```
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8000/api/mentions
```

**Compare versions:**
```
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://localhost:8000/api/proposals/1/versions/compare?version1=1&version2=2"
```

---

**🎉 Ready to test! All endpoints are live and functional.**


