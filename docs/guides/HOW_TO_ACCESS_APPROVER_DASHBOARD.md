# 🎯 How to Access the Approver Dashboard

## Quick Navigation

### From Any Page in the App:

1. **Open the Sidebar Menu**
   - Click the **☰ hamburger icon** in the top-left corner
   
2. **Select "Reviewer / Approver"**
   - Look for the icon: 👁️ or approval icon
   - Click on **"Reviewer / Approver"**
   
3. **You're Now in the Approver Dashboard!** ✅

## Visual Guide

```
┌─────────────────────────────────────┐
│ ☰  Proposal & SOW Builder           │  ← Click hamburger menu
├─────────────────────────────────────┤
│                                     │
│  Sidebar Menu:                      │
│  ────────────────                   │
│  📊 Dashboard                       │
│  📝 Proposals                       │
│  📚 Content Library                 │
│  🤝 Collaboration                   │
│  ✅ Approvals                       │
│  📈 Analytics                       │
│  👁️ Reviewer / Approver  ← CLICK!  │
│  👤 Admin Dashboard                 │
│                                     │
└─────────────────────────────────────┘
```

## What You'll See

### Approver Dashboard Features:

#### 📋 My Approval Queue
- Shows all proposals with status **"Pending CEO Approval"**
- Displays:
  - Proposal title
  - Client name
  - Submitted by (creator)
  - Submission date
  
#### Action Buttons:
- **👁️ View Details** - Open the proposal to review
- **✅ Approve** - Approve and automatically send to client
- **❌ Reject** - Reject and return to creator for edits

#### 📈 My Approval Metrics
- Pending My Approval
- Avg. Response Time
- Approval Rate
- Rejected Proposals

#### ⏰ Recently Approved
- History of your recent approvals
- Current status (Sent to Client, Signed, etc.)

## Direct URL Access

You can also navigate directly:
```
http://localhost:8081/#/approver_dashboard
```

## Approval Workflow

### When Creator Sends for Approval:

1. Creator clicks **"Send for Approval"** on their proposal
2. Status changes to **"Pending CEO Approval"**
3. **Proposal appears in YOUR Approval Queue** ⭐
4. You receive notification (if enabled)

### Your Actions:

#### ✅ **Approve**
```
Pending CEO Approval
       ↓
   [APPROVE]
       ↓
Sent to Client (automatically)
```

#### ❌ **Reject**
```
Pending CEO Approval
       ↓
    [REJECT]
       ↓
draft (back to creator for edits)
```

## Quick Test

### To Test the Workflow:

1. **As Creator:**
   - Create a proposal
   - Add client info
   - Click "Send for Approval"
   
2. **As Approver:**
   - Click ☰ menu
   - Go to "Reviewer / Approver"
   - See the proposal in queue
   - Click "Approve" or "Reject"

3. **Result:**
   - If approved: Status → "Sent to Client"
   - If rejected: Status → "draft"

## Keyboard Shortcuts (Future)

- `Alt + A` - Open Approver Dashboard
- `Ctrl + Enter` - Approve selected
- `Ctrl + R` - Reject selected

## Tips

💡 **Bookmark the Approver Dashboard** if you're a frequent approver

💡 **Check the queue daily** to avoid delays

💡 **Add comments when rejecting** to help creators improve proposals

💡 **Review metrics** to track your approval performance

## Related Documentation

- [Proposal Approval Workflow](../features/PROPOSAL_APPROVAL_WORKFLOW.md)
- [Client Information Requirement](../features/CLIENT_INFO_REQUIREMENT.md)
- [Approver Dashboard Features](../features/APPROVER_DASHBOARD.md) *(coming soon)*

---

**Quick Answer**: Click ☰ menu → "Reviewer / Approver" 🎯

