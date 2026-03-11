# Quick migration script - sets variables and runs migration
# Uses your Render database credentials from the image

Write-Host "🚀 Quick Migration Setup" -ForegroundColor Cyan
Write-Host ""

# Set destination (Render) database from your credentials
# Using full domain (short hostname doesn't work from outside Render)
$env:DEST_DB_HOST = "dpg-d6n7nqjh46gs73c4bd9g-a.oregon-postgres.render.com"
$env:DEST_DB_NAME = "sowbuilder_b88j"
$env:DEST_DB_USER = "sowbuilder_b88j_user"
$env:DEST_DB_PASSWORD = "F0aStJeARRclMbzSod8GNrbt3KHgboX9"  # Updated from connection string
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

