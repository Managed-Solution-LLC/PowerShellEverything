# =============================
# VALIDATED FOR PUBLIC RELEASE
# Date: 2025-06-25
# =============================
<#
.SYNOPSIS
    Backup all BitLocker recovery keys from Azure AD devices using Microsoft Graph.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves all Azure AD devices, and exports all BitLocker recovery keys for each device.
    The results are saved as a CSV file. The script will install the Microsoft.Graph module if it is not already present.

.PARAMETER None
    All configuration is handled within the script. You may edit the export path as needed.

.NOTES
    Author: William Ford
    Date: 2025-06-25
    Version: 1.0
    Required Permissions: BitlockerKey.Read.All, Device.Read.All, Directory.ReadWrite.All, Directory.Read.All, Device.ReadWrite.All
    Required Modules: Microsoft.Graph
    Output: C:\temp\BitLockerKeys.csv

.EXAMPLE
    .\Backup-MgGraphBitLockerKeys.ps1
    Connects to Microsoft Graph, retrieves all BitLocker recovery keys, and exports them to CSV.
#>

# Backup-MgGraphBitLockerKeys

# Install needed modules:
# Microsoft.Graph.Identity.SignIns
# Microsoft.Graph.Devices
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    Install-Module -Name Microsoft.Graph -Force -AllowClobber
}

# Connect to Microsoft Graph
# Permissions needed: 
# BitlockerKey.Read.All, Device.Read.All, Directory.ReadWrite.All, Directory.Read.All
Connect-MgGraph -Scopes "BitlockerKey.Read.All", "Device.Read.All", "Directory.ReadWrite.All", "Directory.Read.All", "Device.ReadWrite.All"


# Get all Devices
$devices = Get-MgDevice -All

# Initialize an empty array to store results
$allBitlockerKeys = @()

# Get BitLocker keys for each device
foreach ($device in $devices) {
    try {
        # Get BitLocker key IDs for this device
        $bitlockerKeyIds = Get-MgInformationProtectionBitlockerRecoveryKey -All | 
                          Where-Object { $_.DeviceId -eq $device.DeviceId } |
                          Select-Object -ExpandProperty Id
        
        Write-Host "Found $($bitlockerKeyIds.Count) key ids for device $($device.DisplayName)"
        
        if ($bitlockerKeyIds) {
            foreach ($keyId in $bitlockerKeyIds) {
                # Retrieve the full key info including the recovery key value
                $keyInfo = Get-MgInformationProtectionBitlockerRecoveryKey -BitlockerRecoveryKeyId $keyId -Property "key"
                
                $keyDetails = [PSCustomObject]@{
                    DeviceName = $device.DisplayName
                    DeviceId = $device.Id
                    RecoveryKeyId = $keyId
                    CreatedDateTime = $keyInfo.CreatedDateTime
                    RecoveryKey = $keyInfo.Key  # This is the actual recovery password
                    VolumeType = $keyInfo.VolumeType
                }
                Write-Host "$keyDetails"
                $allBitlockerKeys += $keyDetails
            }
        }
    }
    catch {
        Write-Warning "Error retrieving BitLocker keys for device $($device.DisplayName): $_"
    }
}

$allBitlockerKeys | Export-Csv -Path "C:\temp\BitLockerKeys.csv" -NoTypeInformation