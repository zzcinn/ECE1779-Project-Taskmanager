# Kubernetes Database Backup Script
# Backs up PostgreSQL from Kubernetes to DigitalOcean Spaces

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

# Create backup directory if it doesn't exist
if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

$timestamp       = Get-Date -Format "yyyyMMdd-HHmmss"
$localBackupName = "{0}_{1}.sql" -f $dbName, $timestamp
$localBackupPath = Join-Path $backupDir $localBackupName

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Kubernetes Database Backup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[$timestamp] Creating backup from Kubernetes..." -ForegroundColor Yellow

# Create backup using kubectl exec
try {
    kubectl exec $podName -n $namespace -- pg_dump -U $dbUser $dbName > $localBackupPath
    
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl exec failed with exit code $LASTEXITCODE"
    }
    
    $fileSize = (Get-Item $localBackupPath).Length / 1KB
    $fileSizeRounded = [math]::Round($fileSize, 2)
    Write-Host "[OK] Local backup created: $localBackupPath ($fileSizeRounded KB)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Backup failed: $_" -ForegroundColor Red
    exit 1
}

# Upload to Spaces
$remoteKey = "db-backups/$localBackupName"

Write-Host ""
Write-Host "Uploading to Spaces: s3://$spacesBucket/$remoteKey ..." -ForegroundColor Yellow

try {
    aws s3 cp $localBackupPath "s3://$spacesBucket/$remoteKey" --endpoint-url $spacesEndpoint --region $spacesRegion
    
    if ($LASTEXITCODE -ne 0) {
        throw "aws s3 cp failed with exit code $LASTEXITCODE"
    }
    
    Write-Host "[OK] Upload complete!" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Upload failed: $_" -ForegroundColor Red
    Write-Host "  Backup is still available locally at: $localBackupPath" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Backup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Local:  $localBackupPath"
Write-Host "Remote: s3://$spacesBucket/$remoteKey"
Write-Host ""

# Optional: Clean up old local backups (keep last 5)
$oldBackups = Get-ChildItem $backupDir -Filter "*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5
if ($oldBackups) {
    Write-Host "Cleaning up old local backups..." -ForegroundColor Yellow
    $oldBackups | Remove-Item -Force
    Write-Host "[OK] Removed $($oldBackups.Count) old backup(s)" -ForegroundColor Green
}
