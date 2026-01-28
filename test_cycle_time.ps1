# Cycle Time Widget Test Script
$baseUrl = "http://127.0.0.1:8000"

Write-Host ""
Write-Host "Step 1: Getting authentication token..." -ForegroundColor Cyan
$token = Read-Host "Enter your JWT token (or press Enter to use dev bypass)"

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "No token provided. Make sure DEV_BYPASS_AUTH=true in backend/.env" -ForegroundColor Yellow
    $useDevBypass = $true
} else {
    $useDevBypass = $false
}

$headers = @{
    "Content-Type" = "application/json"
}

if (-not $useDevBypass) {
    $headers["Authorization"] = "Bearer $token"
}

Write-Host ""
Write-Host "Step 2: Creating test proposal..." -ForegroundColor Cyan

$proposalTitle = "Cycle Time Test $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$createBody = @{
    title = $proposalTitle
    client_name = "Test Client"
    status = "Draft"
} | ConvertTo-Json

try {
    $createResponse = Invoke-WebRequest -Uri "$baseUrl/api/proposals" -Method POST -Headers $headers -Body $createBody -ErrorAction Stop
    $proposal = $createResponse.Content | ConvertFrom-Json
    $proposalId = $proposal.id
    Write-Host "Proposal created successfully! ID: $proposalId" -ForegroundColor Green
} catch {
    Write-Host "Failed to create proposal!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "Step 3: Moving proposal through stages..." -ForegroundColor Cyan

$stages = @("In Review", "Released", "Signed")

foreach ($stage in $stages) {
    Start-Sleep -Seconds 2
    $statusBody = @{ status = $stage } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "$baseUrl/api/proposals/$proposalId/status" -Method PATCH -Headers $headers -Body $statusBody -ErrorAction Stop | Out-Null
        Write-Host "Updated to: $stage" -ForegroundColor Green
    } catch {
        Write-Host "Failed to update to $stage" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 4: Checking Cycle Time analytics..." -ForegroundColor Cyan

try {
    $cycleTimeUrl = "$baseUrl/api/analytics/cycle-time"
    if (-not $useDevBypass) {
        $cycleTimeResponse = Invoke-WebRequest -Uri $cycleTimeUrl -Method GET -Headers $headers -ErrorAction Stop
    } else {
        $cycleTimeResponse = Invoke-WebRequest -Uri $cycleTimeUrl -Method GET -Headers @{"Content-Type" = "application/json"} -ErrorAction Stop
    }
    $cycleTimeData = $cycleTimeResponse.Content | ConvertFrom-Json
    Write-Host "Cycle Time endpoint working! Stages found: $($cycleTimeData.by_stage.Count)" -ForegroundColor Green
    if ($cycleTimeData.by_stage.Count -gt 0) {
        foreach ($stageData in $cycleTimeData.by_stage) {
            Write-Host "  - $($stageData.stage): $($stageData.avg_days) days avg ($($stageData.samples) samples)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "Failed to fetch cycle time data: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test Complete! Check Analytics Dashboard for Cycle Time widget." -ForegroundColor Green
