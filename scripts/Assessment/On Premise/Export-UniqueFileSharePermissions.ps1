<#
.SYNOPSIS
    Extract unique permissions from file share assessment RawData folder.

.DESCRIPTION
    Processes all permissions_*.csv files in a RawData folder and creates a consolidated
    list of unique permissions (Identity + Rights + Type combinations). This is useful for:
    - Security audits and reviews
    - Permission cleanup planning
    - Identifying all groups/users with access
    - Understanding permission inheritance patterns
    
    This script can process existing RawData from previous assessments without requiring
    a full rescan of the file shares.

.PARAMETER RawDataPath
    Path to the RawData folder containing permissions_*.csv files.
    Default: .\RawData

.PARAMETER OutputDirectory
    Directory where the unique permissions report will be saved.
    Default: Same directory as RawDataPath

.PARAMETER Domain
    Domain name for report naming. If not specified, uses parent folder name.

.EXAMPLE
    .\Export-UniqueFileSharePermissions.ps1 -RawDataPath "C:\Reports\RawData"
    
    Processes all permissions CSV files in C:\Reports\RawData and creates unique permissions list.

.EXAMPLE
    .\Export-UniqueFileSharePermissions.ps1 -RawDataPath ".\RawData" -Domain "Contoso"
    
    Processes RawData folder and names output file with "Contoso" prefix.

.EXAMPLE
    Get-ChildItem -Directory | ForEach-Object { 
        .\Export-UniqueFileSharePermissions.ps1 -RawDataPath "$($_.FullName)\RawData" 
    }
    
    Process multiple RawData folders (useful for multiple assessment runs).

.NOTES
    Author: W. Ford
    Company: Managed Solution LLC
    Date: 2026-01-12
    Version: 1.0
    
    Requirements:
    - PowerShell 5.1 or later
    - Read access to RawData folder
    
    Performance:
    - Processes large permission datasets efficiently
    - Deduplicates in memory for speed
    - Typical processing: 100,000+ permission entries in under 1 minute

.LINK
    https://github.com/Managed-Solution-LLC/PowerShellEveryting
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Path to RawData folder with permissions CSV files")]
    [string]$RawDataPath = ".\RawData",
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for report")]
    [string]$OutputDirectory,
    
    [Parameter(Mandatory=$false, HelpMessage="Domain name for report naming")]
    [string]$Domain
)

# Initialize
$ErrorActionPreference = 'Stop'
$StartTime = Get-Date
$Separator = "=" * 80

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Level) {
        'Error'   { Write-Host "[$timestamp] ❌ $Message" -ForegroundColor Red }
        'Warning' { Write-Host "[$timestamp] ⚠️  $Message" -ForegroundColor Yellow }
        'Success' { Write-Host "[$timestamp] ✅ $Message" -ForegroundColor Green }
        'Info'    { Write-Host "[$timestamp] ℹ️  $Message" -ForegroundColor Cyan }
    }
}

# Display header
Clear-Host
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "UNIQUE FILE SHARE PERMISSIONS EXTRACTOR" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

# Validate RawData path
if (-not (Test-Path $RawDataPath)) {
    Write-Log "RawData folder not found: $RawDataPath" -Level Error
    Write-Host "`nPlease specify the correct path to the RawData folder containing permissions_*.csv files" -ForegroundColor Yellow
    exit 1
}

$RawDataPath = Resolve-Path $RawDataPath
Write-Log "Processing RawData folder: $RawDataPath" -Level Info

# Determine output directory
if (-not $OutputDirectory) {
    $OutputDirectory = Split-Path $RawDataPath -Parent
}

if (-not (Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        Write-Log "Created output directory: $OutputDirectory" -Level Success
    }
    catch {
        Write-Log "Failed to create output directory: $($_.Exception.Message)" -Level Error
        exit 1
    }
}

# Determine domain name if not specified
if (-not $Domain) {
    $parentFolder = Split-Path (Split-Path $RawDataPath -Parent) -Leaf
    if ($parentFolder -match '^(.+?)_File_Share') {
        $Domain = $Matches[1]
    }
    else {
        $Domain = $parentFolder
    }
    Write-Log "Using domain name from folder structure: $Domain" -Level Info
}

# Find all permissions CSV files
Write-Log "Scanning for permissions CSV files..." -Level Info
$permissionFiles = Get-ChildItem -Path $RawDataPath -Filter "permissions_*.csv" -File -ErrorAction SilentlyContinue

if ($permissionFiles.Count -eq 0) {
    Write-Log "No permissions CSV files found in $RawDataPath" -Level Error
    Write-Host "`nExpected files matching pattern: permissions_*.csv" -ForegroundColor Yellow
    exit 1
}

Write-Log "Found $($permissionFiles.Count) permission files to process" -Level Success

# Process all permission files and collect unique permissions
Write-Log "Extracting unique permissions..." -Level Info

$allPermissions = @()
$fileCount = 0

foreach ($file in $permissionFiles) {
    $fileCount++
    $percentComplete = [math]::Round(($fileCount / $permissionFiles.Count) * 100, 1)
    Write-Progress -Activity "Processing permission files" -Status "$percentComplete% Complete" -PercentComplete $percentComplete -CurrentOperation "Processing $($file.Name)"
    
    try {
        $data = Import-Csv -Path $file.FullName -ErrorAction Stop
        
        if ($data) {
            $allPermissions += $data
            Write-Log "  Processed $($file.Name): $($data.Count) entries" -Level Info
        }
        else {
            Write-Log "  Skipped $($file.Name): Empty file" -Level Warning
        }
    }
    catch {
        Write-Log "  Failed to process $($file.Name): $($_.Exception.Message)" -Level Warning
    }
}

Write-Progress -Activity "Processing permission files" -Completed

if ($allPermissions.Count -eq 0) {
    Write-Log "No permissions data found in CSV files" -Level Error
    exit 1
}

Write-Log "Total permission entries collected: $($allPermissions.Count)" -Level Success

# Extract unique permissions based on Identity + Rights + Type
Write-Log "Identifying unique permission combinations..." -Level Info

# Group by key fields to find unique combinations
$uniquePermissions = $allPermissions | 
    Select-Object IdentityReference, FileSystemRights, AccessControlType, IsInherited, InheritanceFlags, PropagationFlags |
    Sort-Object IdentityReference, FileSystemRights, AccessControlType -Unique

Write-Log "Unique permission combinations: $($uniquePermissions.Count)" -Level Success

# Analyze folder-level permissions for SharePoint mapping
Write-Log "Analyzing folder hierarchy for SharePoint mapping..." -Level Info

# Combine SharePath and FolderName to get full path, group permissions by folder
$folderPermissions = $allPermissions | Where-Object { 
    -not [string]::IsNullOrWhiteSpace($_.SharePath) -and 
    -not [string]::IsNullOrWhiteSpace($_.FolderName) 
} | ForEach-Object {
    # Create full path
    $_ | Add-Member -NotePropertyName "FullPath" -NotePropertyValue "$($_.SharePath)\$($_.FolderName)" -Force -PassThru
} | Group-Object FullPath | ForEach-Object {
    $folderPath = $_.Name
    $folderPerms = $_.Group
    
    # Get share name from path
    $pathParts = $folderPath -split '\\'
    $shareName = if ($pathParts.Count -gt 2) { $pathParts[2] } else { "Unknown" }
    
    # Create permission signature for this folder (non-inherited permissions)
    $explicitPerms = $folderPerms | Where-Object { $_.IsInherited -eq 'False' -or $_.IsInherited -eq $false }
    
    if ($explicitPerms) {
        $permSignature = ($explicitPerms | 
            Sort-Object IdentityReference, FileSystemRights, AccessControlType | 
            ForEach-Object { "$($_.IdentityReference)|$($_.FileSystemRights)|$($_.AccessControlType)" }) -join ';'
    } else {
        $permSignature = "INHERITED_ONLY"
    }
    
    [PSCustomObject]@{
        FullPath = $folderPath
        ShareName = $shareName
        FolderName = $folderPerms[0].FolderName
        Depth = ($folderPath -split '\\').Count
        PermissionSignature = $permSignature
        ExplicitPermissionCount = $explicitPerms.Count
        TotalPermissionCount = $folderPerms.Count
        UniqueIdentities = ($explicitPerms | Select-Object -ExpandProperty IdentityReference -Unique | Measure-Object).Count
    }
}

Write-Log "Analyzed $($folderPermissions.Count) unique folder paths" -Level Info

# Find folders with unique permission boundaries (lowest level with explicit permissions)
$uniquePermissionBoundaries = @()
$processedSignatures = @{}

# Sort by depth (deepest first) to find lowest level permissions
foreach ($folder in ($folderPermissions | Sort-Object Depth -Descending)) {
    if ($folder.ExplicitPermissionCount -gt 0 -and $folder.PermissionSignature -ne "INHERITED_ONLY") {
        # Track unique permission signatures - we want the DEEPEST folder for each unique signature
        $sigKey = "$($folder.ShareName)|$($folder.PermissionSignature)"
        
        if (-not $processedSignatures.ContainsKey($sigKey)) {
            $uniquePermissionBoundaries += $folder
            $processedSignatures[$sigKey] = @{
                Path = $folder.FullPath
                Depth = $folder.Depth
            }
        } elseif ($folder.Depth > $processedSignatures[$sigKey].Depth) {
            # Found a deeper folder with same permissions - replace with this one
            $uniquePermissionBoundaries = @($uniquePermissionBoundaries | Where-Object { 
                -not ("$($_.ShareName)|$($_.PermissionSignature)" -eq $sigKey)
            })
            $uniquePermissionBoundaries += $folder
            $processedSignatures[$sigKey] = @{
                Path = $folder.FullPath
                Depth = $folder.Depth
            }
        }
    }
}

Write-Log "Identified $($uniquePermissionBoundaries.Count) unique permission boundaries for SharePoint mapping" -Level Success

# Create summary by identity
$identitySummary = $allPermissions | 
    Group-Object IdentityReference | 
    Select-Object @{
        Name='Identity'; Expression={$_.Name}
    }, @{
        Name='TotalOccurrences'; Expression={$_.Count}
    }, @{
        Name='UniqueRightsCombinations'; Expression={
            ($_.Group | Select-Object FileSystemRights, AccessControlType -Unique).Count
        }
    } |
    Sort-Object TotalOccurrences -Descending

# Create detailed unique permissions list
$detailedUniquePermissions = $allPermissions |
    Group-Object IdentityReference, FileSystemRights, AccessControlType |
    Select-Object @{
        Name='Identity'; Expression={($_.Name -split ', ')[0]}
    }, @{
        Name='FileSystemRights'; Expression={($_.Name -split ', ')[1]}
    }, @{
        Name='AccessControlType'; Expression={($_.Name -split ', ')[2]}
    }, @{
        Name='Occurrences'; Expression={$_.Count}
    }, @{
        Name='SamplePath'; Expression={$_.Group[0].Path}
    }, @{
        Name='IsInherited'; Expression={$_.Group[0].IsInherited}
    }, @{
        Name='InheritanceFlags'; Expression={$_.Group[0].InheritanceFlags}
    }, @{
        Name='PropagationFlags'; Expression={$_.Group[0].PropagationFlags}
    } |
    Sort-Object Identity, FileSystemRights

# Create SharePoint mapping recommendations
$sharepointMapping = @(foreach ($boundary in $uniquePermissionBoundaries) {
    $boundaryPath = $boundary.FullPath
    $perms = $allPermissions | Where-Object { 
        "$($_.SharePath)\$($_.FolderName)" -eq $boundaryPath -and 
        ($_.IsInherited -eq 'False' -or $_.IsInherited -eq $false)
    }
    
    $identityList = ($perms | Select-Object -ExpandProperty IdentityReference -Unique | Sort-Object) -join '; '
    $rightsList = ($perms | Select-Object FileSystemRights, AccessControlType -Unique | 
        ForEach-Object { "$($_.AccessControlType): $($_.FileSystemRights)" }) -join '; '
    
    # Calculate relative path from share root
    $pathParts = $boundary.FolderName -split '\\'
    $relativePath = if ($pathParts.Count -gt 1) { 
        $pathParts -join '/'
    } else { 
        $boundary.FolderName
    }
    
    [PSCustomObject]@{
        ShareName = $boundary.ShareName
        FolderPath = $boundary.FolderName
        FullPath = $boundaryPath
        RelativePath = $relativePath
        FolderDepth = $boundary.Depth
        UniqueIdentities = $boundary.UniqueIdentities
        ExplicitPermissionCount = $boundary.ExplicitPermissionCount
        Identities = $identityList
        Permissions = $rightsList
        PermissionSignature = $boundary.PermissionSignature
        RecommendedAction = if ($boundary.Depth -le 5) { 
            "Create as SharePoint Document Library or Top-Level Folder" 
        } else { 
            "Set as folder-level permission in SharePoint" 
        }
    }
}) | Sort-Object ShareName, FolderDepth -Descending

# Export results
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$uniquePermissionsFile = Join-Path $OutputDirectory "$($Domain)_Unique_Permissions_Detailed_$timestamp.csv"
$identitySummaryFile = Join-Path $OutputDirectory "$($Domain)_Unique_Identities_Summary_$timestamp.csv"
$simpleUniqueFile = Join-Path $OutputDirectory "$($Domain)_Unique_Permissions_Simple_$timestamp.csv"
$sharepointMappingFile = Join-Path $OutputDirectory "$($Domain)_SharePoint_Permission_Mapping_$timestamp.csv"
$folderPermissionsFile = Join-Path $OutputDirectory "$($Domain)_Folder_Permissions_Analysis_$timestamp.csv"

try {
    # Detailed unique permissions
    $detailedUniquePermissions | Export-Csv -Path $uniquePermissionsFile -NoTypeInformation -Encoding UTF8
    Write-Log "Exported detailed unique permissions: $uniquePermissionsFile" -Level Success
    
    # Identity summary
    $identitySummary | Export-Csv -Path $identitySummaryFile -NoTypeInformation -Encoding UTF8
    Write-Log "Exported identity summary: $identitySummaryFile" -Level Success
    
    # Simple unique list (just Identity + Rights + Type)
    $uniquePermissions | Export-Csv -Path $simpleUniqueFile -NoTypeInformation -Encoding UTF8
    Write-Log "Exported simple unique permissions: $simpleUniqueFile" -Level Success
    
    # SharePoint mapping recommendations
    if ($sharepointMapping) {
        $sharepointMapping | Export-Csv -Path $sharepointMappingFile -NoTypeInformation -Encoding UTF8
        Write-Log "Exported SharePoint mapping: $sharepointMappingFile" -Level Success
    }
    
    # Folder-level permissions analysis
    $folderPermissions | Export-Csv -Path $folderPermissionsFile -NoTypeInformation -Encoding UTF8
    Write-Log "Exported folder permissions analysis: $folderPermissionsFile" -Level Success
}
catch {
    Write-Log "Failed to export results: $($_.Exception.Message)" -Level Error
    exit 1
}

# Generate summary report
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

$report = @()
$report += $Separator
$report += "UNIQUE FILE SHARE PERMISSIONS REPORT"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += $Separator
$report += ""
$report += "SOURCE DATA"
$report += "-" * 60
$report += "RawData Path: $RawDataPath"
$report += "Permission Files Processed: $($permissionFiles.Count)"
$report += "Total Permission Entries: $($allPermissions.Count)"
$report += ""
$report += "UNIQUE PERMISSIONS ANALYSIS"
$report += "-" * 60
$report += "Unique Permission Combinations: $($detailedUniquePermissions.Count)"
$report += "Unique Identities (Users/Groups): $($identitySummary.Count)"
$report += "Unique Folder Paths Analyzed: $($folderPermissions.Count)"
$report += "Permission Boundaries (Lowest Level): $($uniquePermissionBoundaries.Count)"
$report += ""
$report += "SHAREPOINT MIGRATION RECOMMENDATIONS"
$report += "-" * 60
$report += "Folders Requiring Unique Permissions: $($sharepointMapping.Count)"
$report += "  (These represent the lowest folder levels where permissions change)"
$report += ""
if ($sharepointMapping) {
    $report += "Top 10 Permission Boundaries by Depth:"
    foreach ($mapping in ($sharepointMapping | Sort-Object FolderDepth -Descending | Select-Object -First 10)) {
        $report += "  Depth $($mapping.FolderDepth): $($mapping.RelativePath) ($($mapping.UniqueIdentities) identities)"
    }
}
$report += ""
$report += "TOP 10 IDENTITIES BY OCCURRENCE"
$report += "-" * 60
foreach ($identity in ($identitySummary | Select-Object -First 10)) {
    $report += "  $($identity.Identity): $($identity.TotalOccurrences) occurrences"
}
$report += ""
$report += "PERMISSION TYPES BREAKDOWN"
$report += "-" * 60
$permissionTypes = $detailedUniquePermissions | Group-Object FileSystemRights | Sort-Object Count -Descending
foreach ($type in $permissionTypes) {
    $report += "  $($type.Name): $($type.Count) unique combinations"
}
$report += ""
$report += "ACCESS CONTROL TYPES"
$report += "-" * 60
$accessTypes = $detailedUniquePermissions | Group-Object AccessControlType
foreach ($type in $accessTypes) {
    $report += "  $($type.Name): $($type.Count) unique combinations"
}
$report += ""
$report += "OUTPUT FILES"
$report += "-" * 60
$report += "Detailed Permissions: $uniquePermissionsFile"
$report += "Identity Summary: $identitySummaryFile"
$report += "Simple List: $simpleUniqueFile"
$report += "SharePoint Mapping: $sharepointMappingFile"
$report += "Folder Analysis: $folderPermissionsFile"
$report += ""
$report += "PROCESSING TIME"
$report += "-" * 60
$report += "Duration: $($Duration.ToString('mm\:ss'))"
$report += $Separator

# Save report
$reportFile = Join-Path $OutputDirectory "$($Domain)_Unique_Permissions_Report_$timestamp.txt"
$report | Out-File -FilePath $reportFile -Encoding UTF8

# Display summary
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "PROCESSING COMPLETE" -ForegroundColor Green
Write-Host $Separator -ForegroundColor Cyan
Write-Host "Processed $($permissionFiles.Count) permission files" -ForegroundColor White
Write-Host "Total permission entries: $($allPermissions.Count)" -ForegroundColor White
Write-Host "Unique permission combinations: $($detailedUniquePermissions.Count)" -ForegroundColor Green
Write-Host "Unique identities: $($identitySummary.Count)" -ForegroundColor Green
Write-Host "`n📍 SharePoint Migration Planning:" -ForegroundColor Yellow
Write-Host "Folder paths analyzed: $($folderPermissions.Count)" -ForegroundColor White
Write-Host "Permission boundaries (lowest level): $($sharepointMapping.Count)" -ForegroundColor Cyan
Write-Host "  └─ These represent folders needing unique SharePoint permissions" -ForegroundColor Gray
Write-Host "`nDuration: $($Duration.ToString('mm\:ss'))" -ForegroundColor Cyan
Write-Host "`n📊 Output Files:" -ForegroundColor Yellow
Write-Host "  • $uniquePermissionsFile" -ForegroundColor White
Write-Host "  • $identitySummaryFile" -ForegroundColor White
Write-Host "  • $simpleUniqueFile" -ForegroundColor White
Write-Host "  • $sharepointMappingFile" -ForegroundColor Cyan
Write-Host "  • $folderPermissionsFile" -ForegroundColor Cyan
Write-Host "  • $reportFile" -ForegroundColor White
Write-Host $Separator -ForegroundColor Cyan

# Offer to open output directory
$openFolder = Read-Host "`nOpen output folder? (Y/N)"
if ($openFolder -eq 'Y' -or $openFolder -eq 'y') {
    Start-Process explorer.exe -ArgumentList $OutputDirectory
}
