$body = @{
    username = "finance_user"
    password = "password123"
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/auth/login" -Method POST -Headers $headers -Body $body
    Write-Host "Login Status: $($response.StatusCode)"
    $data = $response.Content | ConvertFrom-Json
    $token = $data.token
    Write-Host "Got token: $($token.Substring(0, [Math]::Min(30, $token.Length)))..."
    
    if ($token) {
        $financeHeaders = @{
            "Authorization" = "Bearer $token"
        }
        
        $financeResponse = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/finance/proposals" -Method GET -Headers $financeHeaders
        Write-Host "`nFinance API Status: $($financeResponse.StatusCode)"
        
        $financeData = $financeResponse.Content | ConvertFrom-Json
        $proposals = $financeData.proposals
        Write-Host "Found $($proposals.Count) proposals"
        
        foreach ($p in $proposals[0..2]) {
            Write-Host "  - $($p.title) ($($p.status))"
        }
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Host "Status: $($_.Exception.Response.StatusCode)"
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody"
    }
}
