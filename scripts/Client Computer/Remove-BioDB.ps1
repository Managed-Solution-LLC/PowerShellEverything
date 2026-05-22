<#
.SYNOPSIS
    Resets the Windows Biometric Database by removing all .dat files.
.DESCRIPTION
    Stops the Windows Biometric Service (WbioSrvc), deletes all .dat files
    from C:\Windows\System32\WinBioDatabase, then restarts the service.
    Useful for resolving fingerprint/facial recognition enrollment issues.
.EXAMPLE
    .\Remove-BioDB.ps1
    Stops the biometric service, clears the database, and restarts the service.
.NOTES
    Author: W. Ford
    Date: 2025-05-21
    Version: 1.0

    Requirements:
    - Must be run as Administrator
    - Windows 10/11
#>

#Requires -RunAsAdministrator

$ServiceName = "WbioSrvc"
$DatabasePath = "C:\Windows\System32\WinBioDatabase"

# Stop Windows Biometric Service
Write-Host "Stopping Windows Biometric Service..." -ForegroundColor Yellow
Stop-Service -Name $ServiceName -Force -ErrorAction Stop

# Confirm service stopped
$service = Get-Service -Name $ServiceName
if ($service.Status -ne 'Stopped') {
    Write-Host "❌ Service did not stop. Current status: $($service.Status)" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Windows Biometric Service stopped" -ForegroundColor Green

# Delete all .dat files
$datFiles = Get-ChildItem -Path $DatabasePath -Filter "*.dat" -ErrorAction Stop
if ($datFiles.Count -eq 0) {
    Write-Host "⚠️  No .dat files found in $DatabasePath" -ForegroundColor Yellow
}
else {
    $datFiles | Remove-Item -Force -ErrorAction Stop
    Write-Host "✅ Removed $($datFiles.Count) .dat file(s) from $DatabasePath" -ForegroundColor Green
}

# Restart the service
Write-Host "Starting Windows Biometric Service..." -ForegroundColor Yellow
Start-Service -Name $ServiceName -ErrorAction Stop

$service = Get-Service -Name $ServiceName
if ($service.Status -eq 'Running') {
    Write-Host "✅ Windows Biometric Service is running" -ForegroundColor Green
}
else {
    Write-Host "❌ Service failed to start. Current status: $($service.Status)" -ForegroundColor Red
    exit 1
}

Write-Host "`nBiometric database reset complete." -ForegroundColor Cyan
