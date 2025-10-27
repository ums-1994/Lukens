# 🔧 Approval Status Database Fix

## Problem

When trying to send proposals for approval, the system was failing with:

```
psycopg2.errors.CheckViolation: new row for relation "proposals" violates check constraint "proposals_status_check"
```

## Root Cause

The `proposals` table had a CHECK constraint that only allowed these status values:
- `'draft'`
- `'submitted'`
- `'approved'`
- `'rejected'`
- `'archived'`

But the approval workflow needed two additional statuses:
- `'Pending CEO Approval'` - When creator sends for review
- `'Sent to Client'` - When CEO approves and sends to client

## Solution

Updated the database CHECK constraint to include the new status values.

### SQL Migration

```sql
-- Drop old constraint
ALTER TABLE proposals 
DROP CONSTRAINT IF EXISTS proposals_status_check;

-- Add new constraint with additional statuses
ALTER TABLE proposals 
ADD CONSTRAINT proposals_status_check 
CHECK (status IN (
    'draft',
    'submitted',
    'approved',
    'rejected',
    'archived',
    'Pending CEO Approval',  -- NEW
    'Sent to Client'         -- NEW
));
```

## Status Values Reference

### Current Allowed Values

| Status | Description | Used By |
|--------|-------------|---------|
| `draft` | Initial state, being edited | Document Editor |
| `submitted` | Submitted for review | (Legacy) |
| `approved` | Approved | (Legacy) |
| `rejected` | Rejected | (Legacy) |
| `archived` | Archived | Document Management |
| `Pending CEO Approval` | Waiting for CEO approval | **New Approval Workflow** ⭐ |
| `Sent to Client` | Approved and sent to client | **New Approval Workflow** ⭐ |

## Workflow Integration

### Complete Status Flow

```
draft
  │
  ├─→ [Send for Approval] → Pending CEO Approval
  │                              │
  │                              ├─→ [CEO Approves] → Sent to Client
  │                              │
  │                              └─→ [CEO Rejects] → draft (back to editing)
  │
  └─→ [Archive] → archived
```

## Testing

After applying the fix, verify with:

```sql
-- Check the constraint
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'proposals'::regclass AND contype = 'c';

-- Test creating a proposal with new status
INSERT INTO proposals (title, user_id, status, client_name, client_email)
VALUES ('Test', 'test@example.com', 'Pending CEO Approval', 'Client', 'client@example.com');

-- Should succeed ✅
```

## Files Modified

- **Database**: `proposals` table constraint updated
- **Migration**: Executed via `update_status_constraint.py` (temporary script)

## Impact

✅ **Fixed**: Proposals can now be sent for approval
✅ **Fixed**: CEO approval workflow now works end-to-end
✅ **Maintained**: Backward compatibility with existing status values
✅ **No Data Loss**: Existing proposals remain unchanged

## Notes

- The constraint update was applied directly to the production database
- No data migration needed - only constraint update
- Existing proposals with old status values remain valid
- New status values are case-sensitive (must match exactly)

---

**Status**: ✅ Fixed
**Date**: October 27, 2025
**Related**: [Proposal Approval Workflow](../features/PROPOSAL_APPROVAL_WORKFLOW.md)

