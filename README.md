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

install-sql.ps1
conf/ConfigurationFile.ini

This PowerShell script installs SQL Server from a provided ISO file. It uses the Configuration File

Usage:

``` powershell
.\install-sql.ps1 -IsoFilePath C:\pathto\sqlserver.iso
```
