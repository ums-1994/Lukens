# PowerShell script to migrate database schema to Render
# This creates all missing tables

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "🔄 Render Database Schema Migration" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# Set Render database environment variables
$env:DB_HOST = "dpg-d4iq5fa4d50c73d9m3n0-a.oregon-postgres.render.com"
$env:DB_NAME = "proposal_sow_builder"
$env:DB_USER = "proposal_sow_builder_user"
$env:DB_PASSWORD = "LTpIcMC2QUY3bd4DezTU4lmWroOxr8ez"
$env:DB_PORT = "5432"
$env:DB_SSLMODE = "prefer"

Write-Host "📋 Environment variables set:" -ForegroundColor Yellow
Write-Host "   DB_HOST: $env:DB_HOST" -ForegroundColor Gray
Write-Host "   DB_NAME: $env:DB_NAME" -ForegroundColor Gray
Write-Host "   DB_USER: $env:DB_USER" -ForegroundColor Gray
Write-Host "   DB_PORT: $env:DB_PORT" -ForegroundColor Gray
Write-Host "   DB_SSLMODE: $env:DB_SSLMODE" -ForegroundColor Gray
Write-Host ""

Write-Host "🚀 Running schema migration..." -ForegroundColor Green
Write-Host "   (This will create all missing tables)" -ForegroundColor Gray
Write-Host ""

# Run the migration
python migrate_db.py

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Schema migration completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step: Run data migration:" -ForegroundColor Yellow
    Write-Host "   python migrate_postgres_to_postgres.py" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "❌ Schema migration failed!" -ForegroundColor Red
    Write-Host '   Check the error messages above' -ForegroundColor Yellow
}
