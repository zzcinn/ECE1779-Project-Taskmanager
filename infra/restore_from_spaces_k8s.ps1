# Kubernetes Database Restore Script
# Restores PostgreSQL from DigitalOcean Spaces backup

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupFile = ""
)

$infraDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $infraDir

$backupDir = Join-Path $infraDir "backups"

# DigitalOcean Spaces configuration
$spacesRegion   = "tor1"                                
$spacesEndpoint = "https://tor1.digitaloceanspaces.com"   
$spacesBucket   = "taskmanager-backups"           

# Kubernetes configuration
$namespace = "taskmanager"
$podName   = "postgres-0"
$dbUser    = "taskapp"
$dbName    = "taskdb"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Kubernetes Database Restore" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# If no backup file specified, list available backups
if ([string]::IsNullOrEmpty($BackupFile)) {
    Write-Host "Available backups in Spaces:" -ForegroundColor Yellow
    Write-Host ""
    
    $backups = aws s3 ls "s3://$spacesBucket/db-backups/" --endpoint-url $spacesEndpoint --region $spacesRegion
    
    if ($backups) {
        $backups | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "  No backups found!" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Usage: .\restore_from_spaces_k8s.ps1 -BackupFile <filename.sql>" -ForegroundColor Cyan
    Write-Host "Example: .\restore_from_spaces_k8s.ps1 -BackupFile taskdb_20251207-223000.sql" -ForegroundColor Gray
    exit 0
}

# Create backup directory if needed
if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

$localBackupPath = Join-Path $backupDir $BackupFile
$remoteKey = "db-backups/$BackupFile"

# Download backup if not exists locally
if (!(Test-Path $localBackupPath)) {
    Write-Host "Downloading backup from Spaces..." -ForegroundColor Yellow
    
    try {
        aws s3 cp "s3://$spacesBucket/$remoteKey" $localBackupPath --endpoint-url $spacesEndpoint --region $spacesRegion
        
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed"
        }
        
        Write-Host "[OK] Downloaded: $localBackupPath" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to download backup: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Using local backup: $localBackupPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "WARNING: This will OVERWRITE the current database!" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type 'yes' to confirm restore"

if ($confirm -ne "yes") {
    Write-Host "Restore cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Restoring database..." -ForegroundColor Yellow

try {
    # Drop and recreate database
    kubectl exec $podName -n $namespace -- psql -U $dbUser -d postgres -c "DROP DATABASE IF EXISTS $dbName;"
    kubectl exec $podName -n $namespace -- psql -U $dbUser -d postgres -c "CREATE DATABASE $dbName;"
    
    # Restore from backup
    Get-Content $localBackupPath | kubectl exec -i $podName -n $namespace -- psql -U $dbUser -d $dbName
    
    if ($LASTEXITCODE -ne 0) {
        throw "Restore failed"
    }
    
    Write-Host ""
    Write-Host "[OK] Database restored successfully!" -ForegroundColor Green
    
    # Restart API pods to reconnect
    Write-Host ""
    Write-Host "Restarting API pods..." -ForegroundColor Yellow
    kubectl rollout restart deployment/taskmanager-api -n $namespace
    
    Write-Host "[OK] API pods restarting" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Restore failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Restore Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
