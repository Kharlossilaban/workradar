# Workradar Database Backup Script
# Runs automatic database backups with rotation

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "C:\myradar\backups",
    
    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$DbHost = "localhost",
    
    [Parameter(Mandatory=$false)]
    [string]$DbPort = "3306",
    
    [Parameter(Mandatory=$false)]
    [string]$DbUser = "root",
    
    [Parameter(Mandatory=$false)]
    [string]$DbName = "workradar"
)

# Configuration
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = "$BackupPath\workradar_backup_$timestamp.sql"
$mysqldumpPath = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Workradar Database Backup Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Create backup directory if not exists
if (-not (Test-Path $BackupPath)) {
    Write-Host "Creating backup directory: $BackupPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
}

# Check if mysqldump exists
if (-not (Test-Path $mysqldumpPath)) {
    Write-Host "ERROR: mysqldump not found at $mysqldumpPath" -ForegroundColor Red
    Write-Host "Please install MySQL or update the path in the script" -ForegroundColor Red
    exit 1
}

Write-Host "Starting backup..." -ForegroundColor Green
Write-Host "Database: $DbName@$DbHost" -ForegroundColor White
Write-Host "Backup file: $backupFile" -ForegroundColor White
Write-Host ""

# Prompt for password securely
$securePassword = Read-Host "Enter MySQL password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    # Perform backup
    $arguments = @(
        "--host=$DbHost",
        "--port=$DbPort",
        "--user=$DbUser",
        "--password=$password",
        "--databases", $DbName,
        "--result-file=$backupFile",
        "--single-transaction",
        "--quick",
        "--lock-tables=false",
        "--routines",
        "--triggers"
    )
    
    & $mysqldumpPath $arguments
    
    if ($LASTEXITCODE -eq 0) {
        $fileSize = (Get-Item $backupFile).Length / 1MB
        Write-Host ""
        Write-Host "✅ Backup completed successfully!" -ForegroundColor Green
        Write-Host "File: $backupFile" -ForegroundColor White
        Write-Host "Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
        
        # Compress backup
        Write-Host ""
        Write-Host "Compressing backup..." -ForegroundColor Yellow
        $zipFile = "$backupFile.zip"
        Compress-Archive -Path $backupFile -DestinationPath $zipFile -Force
        Remove-Item $backupFile
        
        $zipSize = (Get-Item $zipFile).Length / 1MB
        Write-Host "✅ Compressed to: $zipFile" -ForegroundColor Green
        Write-Host "Size: $([math]::Round($zipSize, 2)) MB" -ForegroundColor White
        
        # Cleanup old backups
        Write-Host ""
        Write-Host "Cleaning up old backups (older than $RetentionDays days)..." -ForegroundColor Yellow
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $oldBackups = Get-ChildItem -Path $BackupPath -Filter "workradar_backup_*.zip" | 
                     Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        if ($oldBackups.Count -gt 0) {
            foreach ($oldBackup in $oldBackups) {
                Remove-Item $oldBackup.FullName -Force
                Write-Host "Deleted: $($oldBackup.Name)" -ForegroundColor Gray
            }
            Write-Host "✅ Deleted $($oldBackups.Count) old backup(s)" -ForegroundColor Green
        } else {
            Write-Host "No old backups to delete" -ForegroundColor Gray
        }
        
        # Show backup statistics
        Write-Host ""
        Write-Host "=====================================" -ForegroundColor Cyan
        Write-Host "Backup Statistics:" -ForegroundColor Cyan
        Write-Host "=====================================" -ForegroundColor Cyan
        $allBackups = Get-ChildItem -Path $BackupPath -Filter "workradar_backup_*.zip"
        $totalSize = ($allBackups | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "Total backups: $($allBackups.Count)" -ForegroundColor White
        Write-Host "Total size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor White
        Write-Host "Oldest backup: $($allBackups | Sort-Object LastWriteTime | Select-Object -First 1 | Select-Object -ExpandProperty LastWriteTime)" -ForegroundColor White
        Write-Host "Newest backup: $($allBackups | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty LastWriteTime)" -ForegroundColor White
        
    } else {
        Write-Host ""
        Write-Host "❌ Backup failed with error code: $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ Error during backup: $_" -ForegroundColor Red
    exit 1
} finally {
    # Clear password from memory
    $password = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Backup completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
