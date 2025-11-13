# Collaboration vs Client Dashboard Routing - Fix

## Problem
When inviting a **collaborator** to review a proposal, they were being shown the **Client Dashboard** instead of the **Guest Collaboration Page**.

## Root Cause
When I implemented the Client Dashboard, I changed the routing so that ALL collaboration tokens (`/collaborate?token=...`) went to the Client Dashboard. However, there are actually **two different use cases**:

1. **Collaborators** (team members invited to comment) → Should see **Guest Collaboration Page**
2. **Clients** (external stakeholders approving/rejecting) → Should see **Client Dashboard**

## Solution Implemented

Created a smart router that checks the invitation type and routes to the appropriate page.

### New Component: `CollaborationRouter`

**Location:** `frontend_flutter/lib/pages/shared/collaboration_router.dart`

**How it works:**
1. Shows loading screen
2. Makes API call to `/api/collaborate?token=xxx`
3. Checks the `permission_level` in response:
   - **`view`** → Routes to **Client Dashboard** (view-only client access)
   - **`comment`** → Routes to **Guest Collaboration Page** (collaborator access)
4. If collaborate endpoint fails, tries `/api/client/proposals` (client portal)
5. Shows appropriate page based on invitation type

**Logic:**
```
Token detected
    ↓
Check /api/collaborate endpoint
    ↓
permission_level = 'view'? 
    YES → Client Dashboard (clients who can only view/approve/reject)
    NO  → Guest Collaboration Page (team members who can comment)
```

## Files Modified

### 1. `frontend_flutter/lib/main.dart`
Changed routing from direct navigation to using the router:
```dart
// BEFORE:
return MaterialPageRoute(
  builder: (context) => const ClientDashboardHome(),
);

// AFTER:
return MaterialPageRoute(
  builder: (context) => CollaborationRouter(token: token),
);
```

### 2. `frontend_flutter/lib/pages/shared/collaboration_router.dart` (NEW)
Smart router component that determines which page to show based on invitation type.

## How It Works Now

### Scenario 1: Inviting a Collaborator
```
1. User clicks "Invite Collaborator" in app
2. Email sent with permission_level = 'comment'
3. Collaborator clicks link → /collaborate?token=abc123
4. CollaborationRouter checks invitation
5. Sees permission_level = 'comment'
6. Routes to Guest Collaboration Page ✓
```

### Scenario 2: Sending to Client
```
1. CEO approves proposal → Sent to client
2. Backend creates invitation with permission_level = 'view'
3. Client clicks link → /collaborate?token=xyz789
4. CollaborationRouter checks invitation
5. Sees permission_level = 'view'
6. Routes to Client Dashboard ✓
```

## Permission Levels

| Level | Purpose | Page Shown | Can Do |
|-------|---------|------------|--------|
| `comment` | Collaborators | Guest Collaboration | View + Comment |
| `view` | Clients | Client Dashboard | View + Approve/Reject |

## Backend Context

The backend already differentiates between these in the `collaboration_invitations` table:

```sql
CREATE TABLE collaboration_invitations (
  ...
  permission_level VARCHAR(50) DEFAULT 'comment',
  -- 'view' = client access
  -- 'comment' = collaborator access
  ...
)
```

## Testing

### Test Collaborator Access:
1. Go to a proposal
2. Click "Invite Collaborator" button
3. Enter an email
4. Copy the collaboration link
5. Open in incognito → Should see **Guest Collaboration Page**

### Test Client Access:
1. Create a proposal with client email
2. Get it approved by CEO
3. Copy the link from the approval email
4. Open in incognito → Should see **Client Dashboard**

## Debug Logs

The router provides helpful console output:
```
🔍 Checking collaboration type for token: xyz...
✅ Collaboration invitation found
   Permission level: comment
   Can comment: true
→ Routing to Guest Collaboration Page (collaborator)
```

Or:
```
🔍 Checking collaboration type for token: abc...
✅ Collaboration invitation found
   Permission level: view
   Can comment: false
→ Routing to Client Dashboard (view-only)
```

## Error Handling

If the token is invalid or expired:
```
❌ Error determining route: Exception: Invalid or expired token
```

Shows error screen with:
- Clear error message
- Retry button
- Professional error UI

## Benefits

✅ **Smart routing** - Automatically determines correct page
✅ **No user confusion** - Right people see right interface
✅ **Backwards compatible** - Works with existing invitations
✅ **Clear separation** - Clients vs Collaborators use different workflows
✅ **Debug friendly** - Extensive logging for troubleshooting

## Status

✅ **FIXED** - Collaborators now see the Guest Collaboration Page, while clients see the Client Dashboard.

---

**Fixed:** October 28, 2025
**Issue:** Routing conflict between client and collaborator access
**Solution:** Smart router based on permission level

