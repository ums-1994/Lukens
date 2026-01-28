# Simple Cycle Time Test - No interactive prompts
$baseUrl = "http://127.0.0.1:8000"

# Check if backend is running
Write-Host "Checking if backend is running..." -ForegroundColor Cyan
try {
    $testResponse = Invoke-WebRequest -Uri "$baseUrl/" -Method GET -TimeoutSec 2 -ErrorAction Stop
    Write-Host "Backend is running!" -ForegroundColor Green
} catch {
    Write-Host "Backend is NOT running!" -ForegroundColor Red
    Write-Host "Please start backend: cd backend; python app.py" -ForegroundColor Yellow
    exit 1
}

# Get token from auth_tokens.json (first token)
$tokenFile = "backend\auth_tokens.json"
if (Test-Path $tokenFile) {
    $tokens = Get-Content $tokenFile | ConvertFrom-Json
    $token = ($tokens.PSObject.Properties | Select-Object -First 1).Name
    Write-Host "Using token from auth_tokens.json" -ForegroundColor Gray
} else {
    Write-Host "No token found. Using dev bypass (make sure DEV_BYPASS_AUTH=true)" -ForegroundColor Yellow
    $token = $null
}

$headers = @{
    "Content-Type" = "application/json"
}

if ($token) {
    $headers["Authorization"] = "Bearer $token"
}

# Create proposal
Write-Host ""
Write-Host "Creating test proposal..." -ForegroundColor Cyan
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
    Write-Host "Proposal created! ID: $proposalId" -ForegroundColor Green
} catch {
    Write-Host "Failed to create proposal: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
    exit 1
}

# Update through stages
Write-Host ""
Write-Host "Moving proposal through stages..." -ForegroundColor Cyan
$stages = @("In Review", "Released", "Signed")

foreach ($stage in $stages) {
    Start-Sleep -Seconds 2
    $statusBody = @{ status = $stage } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "$baseUrl/api/proposals/$proposalId/status" -Method PATCH -Headers $headers -Body $statusBody -ErrorAction Stop | Out-Null
        Write-Host "  Updated to: $stage" -ForegroundColor Green
    } catch {
        Write-Host "  Failed to update to $stage" -ForegroundColor Yellow
    }
}

# Check cycle time
Write-Host ""
Write-Host "Checking Cycle Time endpoint..." -ForegroundColor Cyan
try {
    $cycleTimeResponse = Invoke-WebRequest -Uri "$baseUrl/api/analytics/cycle-time" -Method GET -Headers $headers -ErrorAction Stop
    $cycleTimeData = $cycleTimeResponse.Content | ConvertFrom-Json
    Write-Host "Cycle Time endpoint working!" -ForegroundColor Green
    Write-Host "Stages found: $($cycleTimeData.by_stage.Count)" -ForegroundColor Gray
    if ($cycleTimeData.by_stage.Count -gt 0) {
        foreach ($stageData in $cycleTimeData.by_stage) {
            Write-Host "  - $($stageData.stage): $($stageData.avg_days) days avg" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Done! Check Analytics Dashboard for the Cycle Time widget." -ForegroundColor Green
