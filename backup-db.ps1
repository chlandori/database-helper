<#
.SYNOPSIS
    Backs up one or more SQL Server databases to a parameterized location.

.DESCRIPTION
    This script allows you to backup SQL Server databases to a specified location.
    You can backup a single database or multiple databases, and choose the backup type
    (FULL, DIFFERENTIAL, or LOG).

.PARAMETER DatabaseName
    Name of the database(s) to backup. Can be a single database name or an array of database names.
    Use "ALL" to backup all user databases (excludes system databases).

.PARAMETER BackupPath
    Full path to the directory where backup files will be saved.
    The directory will be created if it doesn't exist.

.PARAMETER BackupType
    Type of backup to perform: FULL, DIFFERENTIAL, or LOG.
    Default is FULL.

.PARAMETER ServerInstance
    SQL Server instance to connect to.
    Default is "localhost".

.PARAMETER Compress
    Enable backup compression.
    Default is $true.

.EXAMPLE
    .\backup-db.ps1 -DatabaseName "MyDatabase" -BackupPath "C:\Backups"
    Performs a full backup of MyDatabase to C:\Backups

.EXAMPLE
    .\backup-db.ps1 -DatabaseName @("DB1", "DB2") -BackupPath "D:\SQLBackups" -BackupType "DIFFERENTIAL"
    Performs a differential backup of DB1 and DB2 to D:\SQLBackups

.EXAMPLE
    .\backup-db.ps1 -DatabaseName "ALL" -BackupPath "C:\Backups\Daily"
    Performs a full backup of all user databases to C:\Backups\Daily

.EXAMPLE
    .\backup-db.ps1 -DatabaseName "MyDatabase" -BackupPath "C:\Backups" -BackupType "LOG"
    Performs a transaction log backup of MyDatabase to C:\Backups
#>

param (
    [Parameter(Mandatory=$true)]
    [string[]]$DatabaseName,
    
    [Parameter(Mandatory=$true)]
    [string]$BackupPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("FULL", "DIFFERENTIAL", "LOG")]
    [string]$BackupType = "FULL",
    
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = "localhost",
    
    [Parameter(Mandatory=$false)]
    [bool]$Compress = $true
)

# Function to ensure backup directory exists
function Ensure-BackupDirectory {
    param([string]$Path)
    
    if (-Not (Test-Path $Path)) {
        Write-Host "Creating backup directory: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    } else {
        Write-Host "Using existing backup directory: $Path"
    }
}

# Function to validate database name
function Test-ValidDatabaseName {
    param([string]$Name)
    
    # Check if name is empty or only whitespace
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Error "Database name cannot be empty or contain only whitespace."
        return $false
    }
    
    # Check length (SQL Server limit is 128 characters)
    if ($Name.Length -gt 128) {
        Write-Error "Database name '$Name' exceeds maximum length of 128 characters."
        return $false
    }
    
    # Database names should not contain brackets, quotes, or other SQL special characters
    # Allow only alphanumeric, underscore, hyphen, and space
    # Spaces are supported because we use bracket notation [$Database] in SQL queries
    if ($Name -match '^[a-zA-Z0-9_\s-]+$') {
        return $true
    }
    
    Write-Error "Invalid database name: '$Name'. Database names should only contain alphanumeric characters, underscores, hyphens, or spaces."
    return $false
}

# Function to validate server instance name
function Test-ValidServerInstance {
    param([string]$Server)
    
    # Server instance names should follow pattern: servername or servername\instancename
    # Server name: alphanumeric, underscore, hyphen, period (for FQDNs)
    # Optional instance name after a single backslash
    # Examples: localhost, SERVER1, server.domain.com, SERVER\INSTANCE
    if ($Server -match '^[a-zA-Z0-9_.-]+(?:\\[a-zA-Z0-9_-]+)?$') {
        return $true
    }
    
    Write-Error "Invalid server instance name: '$Server'. Expected format: servername or servername\instancename"
    return $false
}

# Function to get all user databases
function Get-UserDatabases {
    param([string]$Server)
    
    $query = @"
SELECT name 
FROM sys.databases 
WHERE database_id > 4 
  AND state_desc = 'ONLINE'
ORDER BY name
"@
    
    try {
        $result = Invoke-Sqlcmd -ServerInstance $Server -Query $query -ErrorAction Stop
        return $result | Select-Object -ExpandProperty name
    } catch {
        Write-Error "Failed to retrieve database list: $_"
        return @()
    }
}

# Function to perform database backup
function Backup-Database {
    param(
        [string]$Server,
        [string]$Database,
        [string]$Path,
        [string]$Type,
        [bool]$UseCompression
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Use appropriate file extension based on backup type
    $fileExtension = switch ($Type) {
        "LOG"  { "trn" }
        default { "bak" }
    }
    
    $backupFileName = "${Database}_${Type}_${timestamp}.${fileExtension}"
    $backupFilePath = Join-Path -Path $Path -ChildPath $backupFileName
    
    # Escape single quotes in file path for SQL query
    $escapedBackupFilePath = $backupFilePath -replace "'", "''"
    
    Write-Host "`nBacking up database: $Database"
    Write-Host "  Type: $Type"
    Write-Host "  Destination: $backupFilePath"
    
    $backupTypeClause = switch ($Type) {
        "FULL"         { "DATABASE" }
        "DIFFERENTIAL" { "DATABASE" }
        "LOG"          { "LOG" }
    }
    
    # Build the WITH clause
    $withClauses = @()
    if ($UseCompression) {
        $withClauses += "COMPRESSION"
    } else {
        $withClauses += "NO_COMPRESSION"
    }
    
    if ($Type -eq "DIFFERENTIAL") {
        $withClauses += "DIFFERENTIAL"
    }
    
    $withClause = "WITH " + ($withClauses -join ", ")
    
    $backupQuery = @"
BACKUP $backupTypeClause [$Database]
TO DISK = N'$escapedBackupFilePath'
$withClause
"@
    
    try {
        $startTime = Get-Date
        # QueryTimeout 0 allows for unlimited time, necessary for large database backups
        Invoke-Sqlcmd -ServerInstance $Server -Query $backupQuery -QueryTimeout 0 -ErrorAction Stop
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        $fileInfo = Get-Item $backupFilePath
        $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        
        Write-Host "  ✓ Backup completed successfully" -ForegroundColor Green
        Write-Host "  Duration: $([math]::Round($duration, 2)) seconds"
        Write-Host "  File size: $fileSizeMB MB"
        
        return $true
    } catch {
        Write-Error "  ✗ Backup failed for database '$Database': $_"
        return $false
    }
}

# Main execution
Write-Host "=== SQL Server Database Backup Script ===" -ForegroundColor Cyan
Write-Host "Server Instance: $ServerInstance"
Write-Host "Backup Type: $BackupType"
Write-Host "Compression: $Compress"
Write-Host ""

# Validate server instance name
if (-not (Test-ValidServerInstance -Server $ServerInstance)) {
    exit 1
}

# Ensure backup directory exists
Ensure-BackupDirectory -Path $BackupPath

# Determine which databases to backup
$databasesToBackup = @()

if ($DatabaseName.Count -eq 1 -and $DatabaseName[0] -eq "ALL") {
    Write-Host "Retrieving list of all user databases..."
    $databasesToBackup = Get-UserDatabases -Server $ServerInstance
    
    if ($databasesToBackup.Count -eq 0) {
        Write-Error "No user databases found or failed to retrieve database list."
        exit 1
    }
    
    Write-Host "Found $($databasesToBackup.Count) user database(s) to backup"
} else {
    $databasesToBackup = $DatabaseName
    Write-Host "Databases to backup: $($databasesToBackup -join ', ')"
    
    # Validate database names to prevent SQL injection
    foreach ($db in $databasesToBackup) {
        if (-not (Test-ValidDatabaseName -Name $db)) {
            exit 1
        }
    }
}

# Perform backups
$successCount = 0
$failureCount = 0

foreach ($db in $databasesToBackup) {
    $result = Backup-Database -Server $ServerInstance -Database $db -Path $BackupPath -Type $BackupType -UseCompression $Compress
    
    if ($result) {
        $successCount++
    } else {
        $failureCount++
    }
}

# Summary
Write-Host "`n=== Backup Summary ===" -ForegroundColor Cyan
Write-Host "Total databases processed: $($successCount + $failureCount)"
Write-Host "Successful backups: $successCount" -ForegroundColor Green
if ($failureCount -gt 0) {
    Write-Host "Failed backups: $failureCount" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All backups completed successfully!" -ForegroundColor Green
    exit 0
}
