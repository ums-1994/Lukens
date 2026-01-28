# 🧪 Cycle Time Widget Testing Guide

## Quick Test Steps

### 1. Create a Test Proposal

**Option A: Via UI (Recommended)**
1. Navigate to **Creator Dashboard** or **My Proposals**
2. Click **"New Proposal"** or **"Create Proposal"**
3. Fill in:
   - Title: "Test Cycle Time Proposal"
   - Client: "Test Client"
4. Save/Create the proposal

**Option B: Via API (Quick)**
```bash
# Using PowerShell
$token = "YOUR_JWT_TOKEN"
$body = @{
    title = "Test Cycle Time Proposal"
    client_name = "Test Client"
    status = "Draft"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/proposals" `
    -Method POST `
    -Headers @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" } `
    -Body $body
```

### 2. Update Proposal Status Through Stages

The Cycle Time widget calculates: `updated_at - created_at` for each status.

**To see cycle time data, update the proposal status multiple times:**

#### Step 1: Draft → In Review
```bash
# Update status to "In Review"
$proposalId = "YOUR_PROPOSAL_ID"
$body = @{ status = "In Review" } | ConvertTo-Json

Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/proposals/$proposalId/status" `
    -Method PATCH `
    -Headers @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" } `
    -Body $body
```

#### Step 2: In Review → Released
```bash
# Wait a few seconds, then update to "Released"
$body = @{ status = "Released" } | ConvertTo-Json

Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/proposals/$proposalId/status" `
    -Method PATCH `
    -Headers @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" } `
    -Body $body
```

#### Step 3: Released → Signed
```bash
# Wait a few seconds, then update to "Signed"
$body = @{ status = "Signed" } | ConvertTo-Json

Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/proposals/$proposalId/status" `
    -Method PATCH `
    -Headers @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" } `
    -Body $body
```

### 3. Check the Cycle Time Widget

1. Navigate to **Analytics Dashboard** (`/#/analytics`)
2. Scroll down to **"Cycle Time by Stage"** card
3. You should see:
   - **Stage cards** showing average days per stage
   - **Current Bottleneck** (stage with longest average time)
   - **Sample counts** for each stage

### 4. Test Filters

**Date Range Filter:**
- Click the date range picker
- Select a date range
- Widget should reload with filtered data

**Status Filter:**
- Select a status from dropdown (e.g., "Draft")
- Widget should show only that status's cycle time

**Proposal Type Filter:**
- Select a type (Proposal, SOW, RFI)
- Widget should filter by `template_type`

**Clear Filters:**
- Click the "X" button to clear all filters

## Expected Behavior

### With No Data:
- Shows: "No cycle time data available yet. Start sending proposals to see stage metrics here."

### With Data:
- Shows horizontal cards for each stage (Draft, In Review, Released, Signed)
- Each card displays:
  - Stage name
  - Average time (formatted as min/h/d)
  - Sample count
- Bottleneck is highlighted at the top

## Troubleshooting

**Widget shows empty state:**
- Ensure proposals have `created_at` and `updated_at` timestamps
- Check that proposals belong to your user (`owner_id` matches your user ID)
- Verify backend endpoint returns 200 OK (check Network tab)

**Filters not working:**
- Check browser console for errors
- Verify backend is running and accepts query params
- Ensure date format is `YYYY-MM-DD`

**No bottleneck shown:**
- Bottleneck only appears if there's at least one stage with data
- It's the stage with the highest `avg_days`

## Quick Test Script

```powershell
# Full test script (PowerShell)
$token = "YOUR_JWT_TOKEN"
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# 1. Create proposal
$createBody = @{
    title = "Cycle Time Test $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    client_name = "Test Client"
    status = "Draft"
} | ConvertTo-Json

$createResponse = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/proposals" `
    -Method POST -Headers $headers -Body $createBody

$proposal = $createResponse.Content | ConvertFrom-Json
$proposalId = $proposal.id

Write-Host "✅ Created proposal: $proposalId"

# 2. Update to In Review
Start-Sleep -Seconds 2
$statusBody = @{ status = "In Review" } | ConvertTo-Json
Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/proposals/$proposalId/status" `
    -Method PATCH -Headers $headers -Body $statusBody
Write-Host "✅ Updated to In Review"

# 3. Update to Released
Start-Sleep -Seconds 2
$statusBody = @{ status = "Released" } | ConvertTo-Json
Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/proposals/$proposalId/status" `
    -Method PATCH -Headers $headers -Body $statusBody
Write-Host "✅ Updated to Released"

# 4. Update to Signed
Start-Sleep -Seconds 2
$statusBody = @{ status = "Signed" } | ConvertTo-Json
Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/proposals/$proposalId/status" `
    -Method PATCH -Headers $headers -Body $statusBody
Write-Host "✅ Updated to Signed"

Write-Host "`n🎉 Test complete! Check Analytics Dashboard for Cycle Time data."
```

## Notes

- **Cycle Time** = `updated_at - created_at` for each status
- Each status change updates `updated_at`, creating a new cycle time measurement
- The widget groups by `status` and calculates average/max days per stage
- Filters apply to the query, so only matching proposals are included in calculations
