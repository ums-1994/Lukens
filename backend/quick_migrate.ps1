# Quick migration script - sets variables and runs migration
# Uses your Render database credentials from the image

Write-Host "🚀 Quick Migration Setup" -ForegroundColor Cyan
Write-Host ""

# Set destination (Render) database from your credentials
# Using full domain (short hostname doesn't work from outside Render)
$env:DEST_DB_HOST = "dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com"
$env:DEST_DB_NAME = "proposal_sow_builder"
$env:DEST_DB_USER = "proposal_sow_builder_user"
$env:DEST_DB_PASSWORD = "LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez"  # Updated from connection string
$env:DEST_DB_PORT = "5432"
$env:DEST_DB_SSLMODE = "prefer"  # Changed to 'prefer' (tested and works)

Write-Host "✅ Destination (Render) configured:" -ForegroundColor Green
Write-Host "   Host: $env:DEST_DB_HOST"
Write-Host "   Database: $env:DEST_DB_NAME"
Write-Host ""

# Source (Local PostgreSQL) - your local database
Write-Host "📥 Source (Local PostgreSQL):" -ForegroundColor Yellow
$env:SOURCE_DB_HOST = "localhost"
$env:SOURCE_DB_NAME = "proposal_sow_builder"
$env:SOURCE_DB_USER = "postgres"
$env:SOURCE_DB_PASSWORD = "Password123"
$env:SOURCE_DB_PORT = "5432"

Write-Host "   Host: $env:SOURCE_DB_HOST"
Write-Host "   Database: $env:SOURCE_DB_NAME"
Write-Host "   User: $env:SOURCE_DB_USER"
Write-Host ""

Write-Host "🔄 Running migration..." -ForegroundColor Cyan
Write-Host ""

python migrate_postgres_to_postgres.py

