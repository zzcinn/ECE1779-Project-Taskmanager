$infraDir = "C:\Users\whati\Desktop\ECE1779\ECE1779-Project-Taskmanager\infra"
Set-Location $infraDir

$backupDir = Join-Path $infraDir "backups"

$spacesRegion   = "tor1"                                
$spacesEndpoint = "https://tor1.digitaloceanspaces.com"   
$spacesBucket   = "ece1779-taskmanager-backups"           

$dbService = "db"       
$dbName    = "taskdb"   

if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

$timestamp       = Get-Date -Format "yyyyMMdd-HHmmss"
$localBackupName = "{0}_{1}.sql" -f $dbName, $timestamp
$localBackupPath = Join-Path $backupDir $localBackupName

Write-Host "[$timestamp] Creating local backup at $localBackupPath ..."

docker compose exec -T $dbService bash -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > $localBackupPath

Write-Host "Local backup finished: $localBackupPath"

$remoteKey = "db-backups/$localBackupName"

Write-Host "Uploading to Spaces: s3://$spacesBucket/$remoteKey ..."

aws s3 cp $localBackupPath "s3://$spacesBucket/$remoteKey" `
  --endpoint-url $spacesEndpoint `
  --region $spacesRegion

Write-Host "Upload finished."
Write-Host "Backup stored at s3://$spacesBucket/$remoteKey"
