<#
<#
apply_firebase_uid_index_fix.ps1

Checks for duplicate users.firebase_uid values in the Postgres container and applies
`backend/migrations/001_create_unique_index_firebase_uid.sql` if no duplicates are found.

Usage (from repo root or backend folder):
  PowerShell> .\backend\scripts\apply_firebase_uid_index_fix.ps1
  or
  PowerShell> .\backend\scripts\apply_firebase_uid_index_fix.ps1 -Container unathi-postgres -MigrationFile ..\migrations\001_create_unique_index_firebase_uid.sql

This script assumes Docker is available and the Postgres container is running.
#>

param(
    [string]$Container = "unathi-postgres",
    [string]$MigrationFile = "..\migrations\001_create_unique_index_firebase_uid.sql"
)

function FailExit($msg) {
    Write-Error $msg
    exit 1
}

Write-Output "Inspecting container '$Container'..."

# Ensure container exists / running
$dockerPs = docker ps --format "{{.Names}}" 2>$null
if (-not $dockerPs) {
    FailExit "Docker does not appear to be running or 'docker' is not on PATH."
}

if (-not ($dockerPs -split "`n" | Where-Object { $_ -eq $Container })) {
    Write-Warning "Container '$Container' not found in 'docker ps' output. Available containers:"
    Write-Output $dockerPs
    FailExit "Set the -Container parameter to the Postgres container name shown above."
}

# Read environment variables from container to find DB user/name
$envDump = docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' $Container 2>&1
if ($LASTEXITCODE -ne 0 -or -not $envDump) {
    FailExit "Failed to inspect container '$Container'. Output:`n$envDump"
}

# Parse POSTGRES_USER and POSTGRES_DB
$pgUser = ($envDump -split "`n" | Where-Object { $_ -match '^POSTGRES_USER=' } | ForEach-Object { ($_ -split '=',2)[1] }) -join ''
if (-not $pgUser) { $pgUser = "postgres" }
$pgDb = ($envDump -split "`n" | Where-Object { $_ -match '^POSTGRES_DB=' } | ForEach-Object { ($_ -split '=',2)[1] }) -join ''
if (-not $pgDb) { $pgDb = $pgUser }

Write-Output "Using DB user: $pgUser   DB name: $pgDb"

$dupQuery = "SELECT firebase_uid, COUNT(*) FROM users WHERE firebase_uid IS NOT NULL GROUP BY firebase_uid HAVING COUNT(*) > 1;"
Write-Output "Checking for duplicate firebase_uid entries..."

$dups = docker exec -i $Container psql -U $pgUser -d $pgDb -t -c "$dupQuery" 2>&1
if ($dups -match "ERROR|FATAL") {
    FailExit "psql error while checking duplicates:`n$dups"
}

$dupsTrim = $dups.Trim()
if ($dupsTrim -eq "") {
    # No duplicates found -> apply migration
    Write-Output "No duplicates found. Applying the unique index migration."
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $fullPath = Join-Path $scriptDir $MigrationFile
    if (-not (Test-Path $fullPath)) {
        FailExit "Migration file not found: $fullPath"
    }
    Write-Output "Applying migration file: $fullPath"
    Get-Content $fullPath -Raw | docker exec -i $Container psql -U $pgUser -d $pgDb -v ON_ERROR_STOP=1 -q 2>&1 | ForEach-Object { Write-Output $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-Output "✅ Unique index created (or already existed)."
    } else {
        FailExit "psql returned non-zero exit code while applying migration. Inspect output above."
    }
} else {
    # Duplicates found -> report and exit
    Write-Output "Duplicates detected — do NOT apply the unique index. Results:"
    Write-Output $dupsTrim
    $msg = @'
Resolve duplicates manually before applying the migration. You can inspect users with duplicate firebase_uid with a query like:
  SELECT id, username, email, firebase_uid FROM users WHERE firebase_uid = '<problematic-uid>';
'@
    Write-Output $msg
    exit 2
}
