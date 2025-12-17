# Run the backend locally with local env overrides
# Usage: Open PowerShell in repo root and run: .\backend\run_local.ps1

# Load .env.local into this shell
Get-Content .\backend\.env.local | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$') {
    $name = $matches[1]; $value = $matches[2].Trim('"')
    Write-Host "Setting $name" -ForegroundColor Gray
    Set-Item -Path env:$name -Value $value
  }
}

# Activate venv
. .\backend\.venv\Scripts\Activate.ps1

# Start the app
python .\backend\app.py
