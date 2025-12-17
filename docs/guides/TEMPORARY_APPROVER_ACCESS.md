# 🚀 How to Access Approver Dashboard (Current Workaround)

## The Issue
The role switcher is having trouble maintaining authentication tokens during navigation.

## ✅ **Working Solution: Use the Hamburger Menu**

### Steps:

1. **Click the ☰ hamburger menu** (top-left corner)

2. **Scroll down** and find **"Reviewer / Approver"**

3. **Click it** ✅

This navigation method preserves your authentication and will show your pending proposals!

## What You'll See

```
┌──────────────────────────────────────┐
│ 📋 My Approval Queue (2 pending)     │
├──────────────────────────────────────┤
│ ⏳ ent                               │
│ 🏢 Client Name                       │
│          [Approve]  [Reject]         │
├──────────────────────────────────────┤
│ ⏳ Untitled Document                 │
│ 🏢 Client Name                       │
│          [Approve]  [Reject]         │
└──────────────────────────────────────┘
```

## Why This Works

The hamburger menu uses the existing page index system (`idx = 9`) which keeps you in the same app shell with the same authentication context, unlike the role switcher which was trying to navigate to a new route.

## Fix Coming Soon

We're working on fixing the role switcher to properly maintain authentication tokens during navigation. For now, please use the hamburger menu method.

---

**Quick**: ☰ Menu → Reviewer / Approver → See your proposals! 🎉

