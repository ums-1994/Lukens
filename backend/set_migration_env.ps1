# PowerShell script to set migration environment variables
# This sets up source (local) and destination (Render) database connections

Write-Host "🔧 Setting up PostgreSQL Migration Environment Variables" -ForegroundColor Cyan
Write-Host ""

# SOURCE DATABASE (Local PostgreSQL)
Write-Host "📥 Source Database (Local PostgreSQL):" -ForegroundColor Yellow
$env:SOURCE_DB_HOST = Read-Host "   Host (default: localhost)" 
if ([string]::IsNullOrWhiteSpace($env:SOURCE_DB_HOST)) { $env:SOURCE_DB_HOST = "localhost" }

$env:SOURCE_DB_NAME = Read-Host "   Database Name (default: proposal_sow_builder)"
if ([string]::IsNullOrWhiteSpace($env:SOURCE_DB_NAME)) { $env:SOURCE_DB_NAME = "proposal_sow_builder" }

$env:SOURCE_DB_USER = Read-Host "   Username (default: postgres)"
if ([string]::IsNullOrWhiteSpace($env:SOURCE_DB_USER)) { $env:SOURCE_DB_USER = "postgres" }

$env:SOURCE_DB_PASSWORD = Read-Host "   Password" -AsSecureString
$env:SOURCE_DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($env:SOURCE_DB_PASSWORD)
)

$env:SOURCE_DB_PORT = Read-Host "   Port (default: 5432)"
if ([string]::IsNullOrWhiteSpace($env:SOURCE_DB_PORT)) { $env:SOURCE_DB_PORT = "5432" }

Write-Host ""
Write-Host "📤 Destination Database (Render PostgreSQL):" -ForegroundColor Yellow
$env:DEST_DB_HOST = Read-Host "   Host (e.g., dpg-xxxxx-a.render.com)"
$env:DEST_DB_NAME = Read-Host "   Database Name"
$env:DEST_DB_USER = Read-Host "   Username"
$env:DEST_DB_PASSWORD = Read-Host "   Password" -AsSecureString
$env:DEST_DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($env:DEST_DB_PASSWORD)
)
$env:DEST_DB_PORT = Read-Host "   Port (default: 5432)"
if ([string]::IsNullOrWhiteSpace($env:DEST_DB_PORT)) { $env:DEST_DB_PORT = "5432" }
$env:DEST_DB_SSLMODE = "require"

Write-Host ""
Write-Host "✅ Environment variables set!" -ForegroundColor Green
Write-Host ""
Write-Host "Source: $env:SOURCE_DB_HOST`:$env:SOURCE_DB_PORT/$env:SOURCE_DB_NAME" -ForegroundColor Cyan
Write-Host "Destination: $env:DEST_DB_HOST`:$env:DEST_DB_PORT/$env:DEST_DB_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now run: python migrate_postgres_to_postgres.py" -ForegroundColor Yellow

