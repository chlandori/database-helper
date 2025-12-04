# Database Helper

Database Helper is a lightweight collection of scripts designed for SQL Server 2025 on Windows Server 2025 to make working with databases easier. It includes utilities for setup, installation, and maintenance tasks, with a focus on simplicity and reproducibility.

## Features

- 📜 Helpful scripts for database setup and management
- ⚡ Quick installation of SQL Server from ISO images
- 🛠 Easy to extend with your own scripts

## Getting Started

Clone the repository:

```bash
git clone https://github.com/chlandori/database-helper.git
cd database-helper
```

## Scripts

### install-sql.ps1

This PowerShell script installs SQL Server from a provided ISO file. It uses the Configuration File located in the `conf` directory.

Usage:

``` powershell
.\install-sql.ps1 -IsoFilePath C:\pathto\sqlserver.iso
```

### backup-db.ps1

This PowerShell script backs up one or more SQL Server databases to a parameterized location. It supports FULL, DIFFERENTIAL, and LOG backups with optional compression.

Usage:

``` powershell
# Backup a single database
.\backup-db.ps1 -DatabaseName "MyDatabase" -BackupPath "C:\Backups"

# Backup multiple databases
.\backup-db.ps1 -DatabaseName @("DB1", "DB2") -BackupPath "D:\SQLBackups"

# Backup all user databases
.\backup-db.ps1 -DatabaseName "ALL" -BackupPath "C:\Backups\Daily"

# Perform a differential backup
.\backup-db.ps1 -DatabaseName "MyDatabase" -BackupPath "C:\Backups" -BackupType "DIFFERENTIAL"

# Perform a transaction log backup
.\backup-db.ps1 -DatabaseName "MyDatabase" -BackupPath "C:\Backups" -BackupType "LOG"

# Specify a different server instance
.\backup-db.ps1 -DatabaseName "MyDatabase" -BackupPath "C:\Backups" -ServerInstance "SERVER\INSTANCE"
```

**Parameters:**
- `DatabaseName` (required): Name of database(s) to backup. Use "ALL" for all user databases.
- `BackupPath` (required): Directory path where backup files will be saved.
- `BackupType` (optional): Type of backup - FULL (default), DIFFERENTIAL, or LOG.
- `ServerInstance` (optional): SQL Server instance to connect to (default: localhost).
- `Compress` (optional): Enable backup compression (default: true).
