<#
.SYNOPSIS
    Enables Windows Hello for Business and Biometrics registry keys.
.DESCRIPTION
    Sets registry keys to enable Windows Hello for Business, Biometrics,
    domain logon via biometrics, and facial/fingerprint features.
.EXAMPLE
    .\Set-WHBRegistry.ps1
    Sets all Windows Hello for Business and Biometrics registry keys.
.NOTES
    Author: W. Ford
    Date: 2025-05-21
    Version: 1.0

    Requirements:
    - Must be run as Administrator
    - Windows 10/11
#>

#Requires -RunAsAdministrator

# Enable Windows Hello for Business
$whbPath = "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork"
if (!(Test-Path $whbPath)) {
    New-Item -Path $whbPath -Force | Out-Null
}
Set-ItemProperty -Path $whbPath -Name "Enabled" -Value 1 -Type DWord
Write-Host "✅ Windows Hello for Business enabled" -ForegroundColor Green

# Enable Biometrics
$bioPath = "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics"
if (!(Test-Path $bioPath)) {
    New-Item -Path $bioPath -Force | Out-Null
}
Set-ItemProperty -Path $bioPath -Name "Enabled" -Value 1 -Type DWord
Write-Host "✅ Biometrics enabled" -ForegroundColor Green

# Allow domain users to log on using biometrics
Set-ItemProperty -Path $bioPath -Name "AllowDomainLogon" -Value 1 -Type DWord
Write-Host "✅ Domain logon via biometrics enabled" -ForegroundColor Green

# Enable Facial & Fingerprint features
$facePath = "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics\FacialFeatures"
if (!(Test-Path $facePath)) {
    New-Item -Path $facePath -Force | Out-Null
}
Set-ItemProperty -Path $facePath -Name "Enabled" -Value 1 -Type DWord
Write-Host "✅ Facial & Fingerprint features enabled" -ForegroundColor Green

Write-Host "`nAll Windows Hello for Business registry keys have been set." -ForegroundColor Cyan
