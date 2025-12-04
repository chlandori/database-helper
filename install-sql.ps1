
<#
.SYNOPSIS
    Runs SQL Server 2025 setup using a parameterized ConfigurationFile.ini path.

.DESCRIPTION
    This script allows you to pass in the path to a SQL Server ConfigurationFile.ini
    so you can reproduce installs across environments without hardcoding file locations.

.PARAMETER ConfigFilePath
    Full path to the ConfigurationFile.ini file.

.EXAMPLE
    .\Install-SqlServer.ps1 -ConfigFilePath "C:\Artifacts\SQL\Config\ConfigurationFile.ini"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$IsoFilePath,
    [string]$ConfigFilePath = "ConfigurationFile.ini"
)

# Validate file existence
if (-Not (Test-Path $ConfigFilePath)) {
    $ConfigFilePath = Join-Path -Path "$PSScriptRoot/conf" -ChildPath $ConfigFilePath
}
# Resolve path to avoid relative path issues
$resolvedPath = (Resolve-Path $ConfigFilePath).Path
Write-Host "Using Configuration File Path: $resolvedPath"
    
# Mount the ISO if not already mounted
if ( -not($(Get-DiskImage -ImagePath $IsoFilePath | Where-Object { $_.Attached -eq $true }).Attached) ) {
    Write-Host "Mounting ISO: $IsoFilePath"
    Mount-DiskImage -ImagePath $IsoFilePath
    Start-Sleep -Seconds 5 # Wait for mount to complete
} else {
    Write-Host "ISO already mounted: $IsoFilePath"
}

$volumes = Get-Volume
for ($i = 0; $i -lt $volumes.Length; $i++) {
    $volume = $volumes[$i]
    if ($volume.FileSystemLabel -like "SQLServer2025") {
        Write-Host "Found SQL Server 2025 volume at: $($volume.DriveLetter):"
        break
    }
}

$setupExe = "$($volume.DriveLetter):\setup.exe"
if (-Not (Test-Path $setupExe)) {
    Write-Error "SQL Server setup.exe not found at: $setupExe"
    exit 1
}

Write-Host "Found setup.exe at: $setupExe"
Write-Host "Starting SQL Server 2025 installation using configuration file: $resolvedPath"

# Run setup with the config file
Start-Process -FilePath $setupExe `
    -ArgumentList "/ConfigurationFile=$resolvedPath" `
    -Wait -NoNewWindow

Write-Host "SQL Server 2025 installation completed."
 
$response = Read-Host "would you like to dismount the ISO now? (Y/N)"
if ($response.ToLower() -eq "y") {
    Write-Host "Dismounting ISO..."
    Dismount-DiskImage -ImagePath $IsoFilePath
} else {
    Write-Host "ISO not dismounted."
}
