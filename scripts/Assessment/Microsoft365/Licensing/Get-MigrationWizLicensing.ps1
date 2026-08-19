<#
.SYNOPSIS
    Calculate BitTitan MigrationWiz license requirements from assessment data.

.DESCRIPTION
    This script analyzes Microsoft 365 assessment data from an Excel file and calculates
    the required MigrationWiz and PowerSyncPro licenses based on BitTitan pricing.
    
    Supported License Types:
    - Mailbox ($14/user, up to 50GB)
    - User Migration Bundle ($17.50/user - mailbox + OneDrive + archives, unlimited data)
    - Tenant Migration Bundle ($57/user - includes Teams or SharePoint 100GB)
    - Teams Collaboration ($48/team, up to 100GB)
    - Shared Documents ($25 for 50GB, $48 for 100GB per library)
    - Public Folders ($114 per 10GB)
    - Active Directory/Entra ID SMB ($6.25/user for ≤1000 users)
    - Active Directory/Entra ID Enterprise ($8/user)
    - Directory Sync Enterprise ($8/user)
    - Migration Agent ($13.50/device)
    - PowerSyncPro Bundle ($20/user+device)

.PARAMETER InputExcelFile
    Path to the assessment Excel file containing mailbox, OneDrive, Teams, and SharePoint data.

.PARAMETER OutputDirectory
    Directory where the license calculation report will be saved. Default: C:\Temp\MigrationWiz

.PARAMETER OrganizationName
    Organization name for the report header. Default: "Organization"

.PARAMETER IncludeArchives
    Include archive mailboxes in license calculations (requires User Migration Bundle).

.PARAMETER IncludeTeams
    Include Microsoft Teams in license calculations.

.PARAMETER IncludeSharePoint
    Include SharePoint document libraries in license calculations.

.PARAMETER IncludePublicFolders
    Include public folders in license calculations.

.PARAMETER UseUserMigrationBundle
    Use User Migration Bundle ($17.50) instead of basic Mailbox license ($14).
    Recommended if users have >50GB mailboxes or need OneDrive migration.

.PARAMETER UseTenantMigrationBundle
    Use Tenant Migration Bundle ($57) for comprehensive migrations including Teams/SharePoint.
    Includes mailbox + OneDrive + choice of Teams or Shared Documents (100GB).

.EXAMPLE
    .\Get-MigrationWizLicensing.ps1 -InputExcelFile "C:\Assessments\Contoso_Assessment.xlsx"
    
    Basic mailbox-only license calculation using default $14/user pricing.

.EXAMPLE
    .\Get-MigrationWizLicensing.ps1 `
        -InputExcelFile "C:\Assessments\Contoso_Assessment.xlsx" `
        -UseUserMigrationBundle `
        -OrganizationName "Contoso Corporation"
    
    Calculate using User Migration Bundle ($17.50) for unlimited data.

.EXAMPLE
    .\Get-MigrationWizLicensing.ps1 `
        -InputExcelFile "C:\Assessments\Contoso_Assessment.xlsx" `
        -UseTenantMigrationBundle `
        -IncludeTeams `
        -IncludeArchives `
        -OrganizationName "Fabrikam Inc"
    
    Full tenant migration with Teams, archives, and comprehensive bundle.

.EXAMPLE
    .\Get-MigrationWizLicensing.ps1 `
        -InputExcelFile "C:\Assessments\Assessment.xlsx" `
        -UseUserMigrationBundle `
        -IncludeSharePoint `
        -IncludePublicFolders `
        -OutputDirectory "D:\Reports"
    
    Migration with SharePoint libraries and public folders included.

.NOTES
    Name: Get-MigrationWizLicensing
    Author: W. Ford
    Version: 1.1
    DateCreated: 2025-12-23
    
    Version History:
    - v1.1 (2025-12-23): Added shared mailbox distinction, SharePoint data filtering
    - v1.0 (2025-12-23): Initial release
    
    Requirements:
    - PowerShell 5.1 or later
    - ImportExcel module (auto-installed if missing)
    - Assessment Excel file with standardized worksheet names
    
    Expected Excel Worksheets:
    - "Mailboxes" or "Users" - User mailbox data
    - "Teams" - Microsoft Teams data (optional)
    - "SharePoint" - SharePoint sites/libraries (optional)
    - "OneDrive" - OneDrive data (optional)
    - "Public Folders" - Public folder data (optional)
    
    Pricing Reference (as of 2025-12-23):
    https://www.bittitan.com/pricing-bittitan-migrationwiz/

.LINK
    https://www.bittitan.com/pricing-bittitan-migrationwiz/
    https://www.bittitan.com/migrationwiz/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Path to assessment Excel file")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$InputExcelFile,
    
    [Parameter(Mandatory=$false, HelpMessage="Output directory for license report")]
    [string]$OutputDirectory = "C:\Temp\MigrationWiz",
    
    [Parameter(Mandatory=$false, HelpMessage="Organization name for report")]
    [string]$OrganizationName = "Organization",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeArchives,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeTeams,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeSharePoint,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludePublicFolders,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseUserMigrationBundle,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseTenantMigrationBundle
)

#region Pricing Constants
$PRICE_MAILBOX = 14.00
$PRICE_USER_BUNDLE = 17.50
$PRICE_TENANT_BUNDLE = 57.00
$PRICE_TEAMS = 48.00
$PRICE_SHARED_DOC_50GB = 25.00
$PRICE_SHARED_DOC_100GB = 48.00
$PRICE_PUBLIC_FOLDER_10GB = 114.00
$PRICE_AD_SMB = 6.25
$PRICE_AD_ENTERPRISE = 8.00
$PRICE_MIGRATION_AGENT = 13.50
$PRICE_PSP_BUNDLE = 20.00
#endregion

#region Prerequisites
Write-Host "`n+================================================================+" -ForegroundColor Cyan
Write-Host "|                                                                |" -ForegroundColor Cyan
Write-Host "|       MigrationWiz License Calculator                          |" -ForegroundColor Cyan
Write-Host "|                                                                |" -ForegroundColor Cyan
Write-Host "+================================================================+" -ForegroundColor Cyan
Write-Host ""

# Check ImportExcel module
if (-not (Get-Module -Name ImportExcel -ListAvailable)) {
    Write-Host "❌ ImportExcel module not installed" -ForegroundColor Red
    Write-Host "   Installing ImportExcel module..." -ForegroundColor Yellow
    try {
        Install-Module -Name ImportExcel -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        Write-Host "✅ ImportExcel module installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to install ImportExcel module: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Import-Module ImportExcel -ErrorAction Stop

# Create output directory
if (-not (Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
        Write-Host "✅ Created output directory: $OutputDirectory" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "✅ Output directory exists: $OutputDirectory" -ForegroundColor Green
}

Write-Host "✅ Input file validated: $InputExcelFile" -ForegroundColor Green
#endregion

#region Read Assessment Data
Write-Host "`nℹ️  Reading assessment data from Excel..." -ForegroundColor Cyan

$worksheets = Get-ExcelSheetInfo -Path $InputExcelFile
$availableSheets = $worksheets.Name

Write-Host "   Found worksheets: $($availableSheets -join ', ')" -ForegroundColor Gray

# Initialize counters
$userCount = 0
$mailboxCount = 0
$sharedMailboxCount = 0
$archiveCount = 0
$oneDriveCount = 0
$teamsCount = 0
$teamsWithDataCount = 0
$sharePointLibraries = 0
$sharePointLibrariesWithData = 0
$sharePointTeamsSites = 0
$sharePointSizeGB = 0
$publicFolderSizeGB = 0

# Read Mailboxes/Users
$mailboxSheet = $availableSheets | Where-Object { $_ -match '^(Mailboxes|Users|AD Users)$' } | Select-Object -First 1
if ($mailboxSheet) {
    Write-Host "   Reading mailbox data from '$mailboxSheet'..." -ForegroundColor Gray
    try {
        $mailboxData = Import-Excel -Path $InputExcelFile -WorksheetName $mailboxSheet
        $mailboxCount = $mailboxData.Count
        
        # Separate shared mailboxes from user mailboxes
        # Check for RecipientTypeDetails or IsShared column
        $sharedMailboxes = @()
        $userMailboxes = @()
        $emptyMailboxCount = 0
        
        foreach ($mailbox in $mailboxData) {
            # Check if mailbox has data
            $hasData = $true
            if ($mailbox.PSObject.Properties.Name -contains 'TotalSizeGB') {
                if ([double]$mailbox.TotalSizeGB -eq 0) {
                    $hasData = $false
                    $emptyMailboxCount++
                }
            }
            
            # Skip mailboxes with no data
            if (-not $hasData) {
                continue
            }
            
            $isShared = $false
            
            # Check various properties that indicate shared mailbox
            if ($mailbox.PSObject.Properties.Name -contains 'MailboxType') {
                if ($mailbox.MailboxType -match 'Shared') {
                    $isShared = $true
                }
            }
            elseif ($mailbox.PSObject.Properties.Name -contains 'RecipientTypeDetails') {
                if ($mailbox.RecipientTypeDetails -match 'Shared') {
                    $isShared = $true
                }
            }
            elseif ($mailbox.PSObject.Properties.Name -contains 'IsShared') {
                if ($mailbox.IsShared -eq $true -or $mailbox.IsShared -eq 'True' -or $mailbox.IsShared -eq 'Yes') {
                    $isShared = $true
                }
            }
            elseif ($mailbox.PSObject.Properties.Name -contains 'RecipientType') {
                if ($mailbox.RecipientType -match 'Shared') {
                    $isShared = $true
                }
            }
            
            if ($isShared) {
                $sharedMailboxes += $mailbox
            }
            else {
                $userMailboxes += $mailbox
            }
        }
        
        $userCount = $userMailboxes.Count
        $sharedMailboxCount = $sharedMailboxes.Count
        
        Write-Host "   [OK] Found $userCount user mailboxes" -ForegroundColor Green
        if ($sharedMailboxCount -gt 0) {
            Write-Host "   [OK] Found $sharedMailboxCount shared mailboxes - licensed separately" -ForegroundColor Green
        }
        if ($emptyMailboxCount -gt 0) {
            Write-Host "   [INFO] Excluded $emptyMailboxCount mailboxes with 0 GB data" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "   [WARN] Could not read mailbox data: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Read Archives (if included)
if ($IncludeArchives) {
    $archiveSheet = $availableSheets | Where-Object { $_ -match '^Archives?$' } | Select-Object -First 1
    if ($archiveSheet) {
        Write-Host "   Reading archive data from '$archiveSheet'..." -ForegroundColor Gray
        try {
            $archiveData = Import-Excel -Path $InputExcelFile -WorksheetName $archiveSheet
            $archiveCount = $archiveData.Count
            Write-Host "   [OK] Found $archiveCount archives" -ForegroundColor Green
        }
        catch {
            Write-Host "   [WARN] Could not read archive data: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Read OneDrive
$oneDriveSheet = $availableSheets | Where-Object { $_ -match '^OneDrive' } | Select-Object -First 1
if ($oneDriveSheet) {
    Write-Host "   Reading OneDrive data from '$oneDriveSheet'..." -ForegroundColor Gray
    try {
        $oneDriveData = Import-Excel -Path $InputExcelFile -WorksheetName $oneDriveSheet
        $oneDriveCount = $oneDriveData.Count
        Write-Host "   [OK] Found $oneDriveCount OneDrive sites" -ForegroundColor Green
    }
    catch {
        Write-Host "   [WARN] Could not read OneDrive data: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Read Teams (if included)
if ($IncludeTeams) {
    $teamsSheet = $availableSheets | Where-Object { $_ -match '^(Teams?|Teams Sites)$' } | Select-Object -First 1
    if ($teamsSheet) {
        Write-Host "   Reading Teams data from '$teamsSheet'..." -ForegroundColor Gray
        try {
            $teamsData = Import-Excel -Path $InputExcelFile -WorksheetName $teamsSheet
            
            # Filter Teams with actual data
            $teamsWithData = @()
            foreach ($team in $teamsData) {
                $hasData = $false
                
                # Check if this is an actual Teams site (HasTeamsIntegration = True)
                $isTeamsSite = $false
                if ($team.PSObject.Properties.Name -contains 'HasTeamsIntegration') {
                    if ($team.HasTeamsIntegration -eq $true -or $team.HasTeamsIntegration -eq 'True') {
                        $isTeamsSite = $true
                    }
                }
                
                # Check for data
                if ($team.PSObject.Properties.Name -contains 'StorageUsedGB') {
                    if ([double]$team.StorageUsedGB -gt 0) {
                        $hasData = $true
                    }
                }
                elseif ($team.PSObject.Properties.Name -contains 'UsedGB') {
                    if ([double]$team.UsedGB -gt 0) {
                        $hasData = $true
                    }
                }
                
                # Only count if it's an actual Teams site with data
                if ($isTeamsSite -and $hasData) {
                    $teamsWithData += $team
                }
            }
            
            $teamsCount = $teamsData.Count
            $teamsWithDataCount = $teamsWithData.Count
            
            Write-Host "   [OK] Found $teamsCount Teams Sites - $teamsWithDataCount with data and Teams integration" -ForegroundColor Green
            if ($teamsWithDataCount -lt $teamsCount) {
                Write-Host "   [INFO] Only Teams sites with data and Teams integration will be licensed" -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "   [WARN] Could not read Teams data: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Read SharePoint (if included)
if ($IncludeSharePoint) {
    $sharePointSheet = $availableSheets | Where-Object { $_ -match '^SharePoint' } | Select-Object -First 1
    if ($sharePointSheet) {
        Write-Host "   Reading SharePoint data from '$sharePointSheet'..." -ForegroundColor Gray
        try {
            $sharePointData = Import-Excel -Path $InputExcelFile -WorksheetName $sharePointSheet
            $sharePointLibraries = $sharePointData.Count
            
            # Filter libraries with actual data and track sizes
            $librariesWithData = @()
            foreach ($library in $sharePointData) {
                $hasData = $false
                $librarySizeGB = 0
                
                # Check if this is also a Teams site
                $isTeamsSite = $false
                if ($library.PSObject.Properties.Name -contains 'Template') {
                    if ($library.Template -eq 'GROUP#0') {
                        # This is an M365 Group site (potential Teams site)
                        $sharePointTeamsSites++
                    }
                }
                
                # Check for size indicators (UsedGB, SizeGB, SizeMB, ItemCount, StorageUsed, etc.)
                if ($library.PSObject.Properties.Name -contains 'UsedGB') {
                    if ([double]$library.UsedGB -gt 0) {
                        $hasData = $true
                        $librarySizeGB = [double]$library.UsedGB
                        $sharePointSizeGB += $librarySizeGB
                    }
                }
                elseif ($library.PSObject.Properties.Name -contains 'SizeGB') {
                    if ([double]$library.SizeGB -gt 0) {
                        $hasData = $true
                        $librarySizeGB = [double]$library.SizeGB
                        $sharePointSizeGB += $librarySizeGB
                    }
                }
                elseif ($library.PSObject.Properties.Name -contains 'SizeMB') {
                    if ([double]$library.SizeMB -gt 0) {
                        $hasData = $true
                        $librarySizeGB = [double]$library.SizeMB / 1024
                        $sharePointSizeGB += $librarySizeGB
                    }
                }
                elseif ($library.PSObject.Properties.Name -contains 'ItemCount') {
                    if ([int]$library.ItemCount -gt 0) {
                        $hasData = $true
                        # Can't determine size, assume under 50GB for cost estimation
                        $librarySizeGB = 25  # Mid-range estimate
                    }
                }
                elseif ($library.PSObject.Properties.Name -contains 'StorageUsed') {
                    if ($library.StorageUsed -and $library.StorageUsed -ne '0' -and $library.StorageUsed -ne '0 MB') {
                        $hasData = $true
                        # Can't determine size, assume under 50GB for cost estimation
                        $librarySizeGB = 25  # Mid-range estimate
                    }
                }
                
                if ($hasData) {
                    # Add library with size information
                    $librariesWithData += [PSCustomObject]@{
                        Library = $library
                        SizeGB = $librarySizeGB
                    }
                }
            }
            
            $sharePointLibrariesWithData = $librariesWithData.Count
            
            Write-Host "   [OK] Found $sharePointLibraries SharePoint libraries - $sharePointLibrariesWithData with data" -ForegroundColor Green
            if ($sharePointLibrariesWithData -lt $sharePointLibraries) {
                Write-Host "   [INFO] Only libraries with data will be licensed" -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "   [WARN] Could not read SharePoint data: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Read Public Folders (if included)
if ($IncludePublicFolders) {
    $pfSheet = $availableSheets | Where-Object { $_ -match '^Public.?Folder' } | Select-Object -First 1
    if ($pfSheet) {
        Write-Host "   Reading Public Folder data from '$pfSheet'..." -ForegroundColor Gray
        try {
            $pfData = Import-Excel -Path $InputExcelFile -WorksheetName $pfSheet
            # Try to calculate size
            if ($pfData[0].PSObject.Properties.Name -contains 'SizeGB') {
                $publicFolderSizeGB = ($pfData | Measure-Object -Property SizeGB -Sum).Sum
            }
            elseif ($pfData[0].PSObject.Properties.Name -contains 'TotalItemSize') {
                # Estimate from item size if available
                $publicFolderSizeGB = 10 # Default estimate
            }
            Write-Host "   [OK] Found public folders (approx. $publicFolderSizeGB GB)" -ForegroundColor Green
        }
        catch {
            Write-Host "   [WARN] Could not read Public Folder data: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
#endregion

#region Calculate Licenses
Write-Host "`nℹ️  Calculating license requirements..." -ForegroundColor Cyan

$licenses = @()
$totalCost = 0

# Determine bundle type
if ($UseTenantMigrationBundle) {
    $bundleType = "Tenant Migration Bundle"
    $pricePerUser = $PRICE_TENANT_BUNDLE
    $bundleFeatures = "Mailbox + OneDrive + Archives + Teams/SharePoint (100GB)"
}
elseif ($UseUserMigrationBundle -or $IncludeArchives -or $oneDriveCount -gt 0) {
    $bundleType = "User Migration Bundle"
    $pricePerUser = $PRICE_USER_BUNDLE
    $bundleFeatures = "Mailbox + OneDrive + Archives (Unlimited Data)"
}
else {
    $bundleType = "Mailbox"
    $pricePerUser = $PRICE_MAILBOX
    $bundleFeatures = "Mailbox only (up to 50GB per user)"
}

# User/Mailbox Licenses
if ($userCount -gt 0) {
    $userLicenseCost = $userCount * $pricePerUser
    $totalCost += $userLicenseCost
    
    $licenses += [PSCustomObject]@{
        LicenseType = $bundleType
        Quantity = $userCount
        Unit = "user"
        PricePerUnit = $pricePerUser
        TotalCost = $userLicenseCost
        Notes = $bundleFeatures
    }
    Write-Host "   [OK] $userCount x $bundleType at $pricePerUser each = $userLicenseCost total" -ForegroundColor Green
}

# Teams Licenses (if not included in Tenant Bundle)
if ($IncludeTeams -and $teamsWithDataCount -gt 0 -and -not $UseTenantMigrationBundle) {
    $teamsLicenseCost = $teamsWithDataCount * $PRICE_TEAMS
    $totalCost += $teamsLicenseCost
    
    $licenses += [PSCustomObject]@{
        LicenseType = "Teams Collaboration"
        Quantity = $teamsWithDataCount
        Unit = "team"
        PricePerUnit = $PRICE_TEAMS
        TotalCost = $teamsLicenseCost
        Notes = "Up to 100GB per team (Teams sites with data only)"
    }
    Write-Host "   [OK] $teamsWithDataCount x Teams Collaboration at $PRICE_TEAMS each = $teamsLicenseCost total" -ForegroundColor Green
}

# SharePoint Licenses (if not included in Tenant Bundle) - only libraries with data
if ($IncludeSharePoint -and $sharePointLibrariesWithData -gt 0 -and -not $UseTenantMigrationBundle) {
    # Separate libraries by size tier
    $libraries50GB = @($librariesWithData | Where-Object { $_.SizeGB -le 50 })
    $libraries100GB = @($librariesWithData | Where-Object { $_.SizeGB -gt 50 })
    
    # License libraries under 50GB at $25
    if ($libraries50GB.Count -gt 0) {
        $sp50Cost = $libraries50GB.Count * $PRICE_SHARED_DOC_50GB
        $totalCost += $sp50Cost
        
        $licenses += [PSCustomObject]@{
            LicenseType = "Shared Documents (50GB)"
            Quantity = $libraries50GB.Count
            Unit = "library"
            PricePerUnit = $PRICE_SHARED_DOC_50GB
            TotalCost = $sp50Cost
            Notes = "Up to 50GB per library"
        }
        Write-Host "   [OK] $($libraries50GB.Count) x Shared Documents 50GB at $PRICE_SHARED_DOC_50GB each = $sp50Cost total" -ForegroundColor Green
    }
    
    # License libraries over 50GB at $48
    if ($libraries100GB.Count -gt 0) {
        $sp100Cost = $libraries100GB.Count * $PRICE_SHARED_DOC_100GB
        $totalCost += $sp100Cost
        
        $licenses += [PSCustomObject]@{
            LicenseType = "Shared Documents (100GB)"
            Quantity = $libraries100GB.Count
            Unit = "library"
            PricePerUnit = $PRICE_SHARED_DOC_100GB
            TotalCost = $sp100Cost
            Notes = "Up to 100GB per library"
        }
        Write-Host "   [OK] $($libraries100GB.Count) x Shared Documents 100GB at $PRICE_SHARED_DOC_100GB each = $sp100Cost total" -ForegroundColor Green
    }
}

# Shared Mailbox Licenses (separate from user mailboxes)
if ($sharedMailboxCount -gt 0) {
    # Shared mailboxes use basic Mailbox license
    $sharedMBCost = $sharedMailboxCount * $PRICE_MAILBOX
    $totalCost += $sharedMBCost
    
    $licenses += [PSCustomObject]@{
        LicenseType = "Mailbox (Shared)"
        Quantity = $sharedMailboxCount
        Unit = "shared mailbox"
        PricePerUnit = $PRICE_MAILBOX
        TotalCost = $sharedMBCost
        Notes = "Shared mailboxes (up to 50GB each)"
    }
    Write-Host "   [OK] $sharedMailboxCount x Shared Mailbox at $PRICE_MAILBOX each = $sharedMBCost total" -ForegroundColor Green
}

# Public Folder Licenses
if ($IncludePublicFolders -and $publicFolderSizeGB -gt 0) {
    $pf10GBBlocks = [Math]::Ceiling($publicFolderSizeGB / 10)
    $pfLicenseCost = $pf10GBBlocks * $PRICE_PUBLIC_FOLDER_10GB
    $totalCost += $pfLicenseCost
    
    $licenses += [PSCustomObject]@{
        LicenseType = "Public Folders"
        Quantity = $pf10GBBlocks
        Unit = "10GB block"
        PricePerUnit = $PRICE_PUBLIC_FOLDER_10GB
        TotalCost = $pfLicenseCost
        Notes = "~$publicFolderSizeGB GB total size"
    }
    Write-Host "   [OK] $pf10GBBlocks x Public Folders 10GB at $PRICE_PUBLIC_FOLDER_10GB each = $pfLicenseCost total" -ForegroundColor Green
}
#endregion

#region Generate Report
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportFile = Join-Path $OutputDirectory "MigrationWiz_Licensing_$($OrganizationName -replace '[^a-zA-Z0-9]','_')_$timestamp.txt"

$report = @()
$report += "+================================================================+"
$report += "|                                                                |"
$report += "|       BitTitan MigrationWiz License Calculation                |"
$report += "|                                                                |"
$report += "+================================================================+"
$report += ""
$report += "Organization:     $OrganizationName"
$report += "Generated:        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Assessment File:  $(Split-Path $InputExcelFile -Leaf)"
$report += ""
$report += "==============================================================="
$report += "MIGRATION SCOPE"
$report += "==============================================================="
$report += "User Mailboxes:      $userCount"
if ($sharedMailboxCount -gt 0) { $report += "Shared Mailboxes:    $sharedMailboxCount" }
if ($archiveCount -gt 0) { $report += "Archives:            $archiveCount" }
if ($oneDriveCount -gt 0) { $report += "OneDrive Sites:      $oneDriveCount" }
if ($teamsCount -gt 0) { 
    $report += "Teams Sites:         $teamsCount total"
    if ($teamsWithDataCount -lt $teamsCount) {
        $report += "  (Licensed):        $teamsWithDataCount with data and Teams integration"
    }
}
if ($sharePointLibraries -gt 0) { 
    $report += "SharePoint Sites:    $sharePointLibraries total"
    if ($sharePointTeamsSites -gt 0) {
        $report += "  (M365 Groups):     $sharePointTeamsSites (potential Teams sites)"
    }
    if ($sharePointLibrariesWithData -lt $sharePointLibraries) {
        $report += "  (Licensed):        $sharePointLibrariesWithData with data"
    }
}
if ($publicFolderSizeGB -gt 0) { $report += "Public Folders:      ~$publicFolderSizeGB GB" }
$report += ""
$report += "==============================================================="
$report += "LICENSE REQUIREMENTS"
$report += "==============================================================="
$report += ""

# Create table header
$report += "+--------------------------------+----------+-------------+--------------+--------------+"
$report += "| License Type                   | Quantity | Unit        | Price/Unit   | Subtotal     |"
$report += "+--------------------------------+----------+-------------+--------------+--------------+"

# Add table rows
foreach ($license in $licenses) {
    $licenseType = $license.LicenseType.PadRight(30).Substring(0, 30)
    $quantity = $license.Quantity.ToString().PadLeft(8)
    $unit = $license.Unit.PadRight(11).Substring(0, 11)
    $pricePerUnit = ('$' + $license.PricePerUnit.ToString()).PadLeft(12)
    $subtotal = ('$' + $license.TotalCost.ToString()).PadLeft(12)
    
    $report += "| $licenseType | $quantity | $unit | $pricePerUnit | $subtotal |"
}

# Add table footer with total
$report += "+--------------------------------+----------+-------------+--------------+--------------+"
$report += "| TOTAL ESTIMATED COST                                                   | " + "$" + "$($totalCost.ToString('N2').PadLeft(12)) |"
$report += "+------------------------------------------------------------------------+--------------+"
$report += ""

# Add notes section after table
$report += "NOTES:"
foreach ($license in $licenses) {
    $report += "  • $($license.LicenseType): $($license.Notes)"
}
$report += ""
$report += "==============================================================="
$report += ""
$report += "NOTES:"
$report += "------"
$report += "• Prices based on BitTitan public pricing as of 2025-12-23"
$report += "• Volume discounts may be available - contact BitTitan sales"
$report += "• Educational and non-profit discounts available"
$report += "• All PowerSyncPro products require a Windows server to host"
$report += "• Tenant Migration Bundle includes unlimited data for mailbox/OneDrive"
$report += "• Teams and Shared Document limits are 100GB per item"
$report += "• Public Folder pricing is per 10GB block"
$report += ""
$report += "RECOMMENDATIONS:"
$report += "---------------"

if ($userCount -gt 0 -and -not $UseUserMigrationBundle -and -not $UseTenantMigrationBundle) {
    $report += "• Consider User Migration Bundle (`$17.50) for unlimited mailbox data"
}
if ($oneDriveCount -gt 0 -and -not $UseUserMigrationBundle -and -not $UseTenantMigrationBundle) {
    $report += "• OneDrive requires User Migration Bundle or Tenant Migration Bundle"
}
if ($teamsCount -gt 0 -and -not $UseTenantMigrationBundle) {
    $report += "• Consider Tenant Migration Bundle (`$57) if migrating Teams"
}
if ($userCount -gt 1000) {
    $report += "• Volume pricing available - contact BitTitan sales"
}
$report += "• Review full pricing at: https://www.bittitan.com/pricing-bittitan-migrationwiz/"
$report += ""
$report += "═══════════════════════════════════════════════════════════════"
$report += "For accurate quotes, please contact:"
$report += "• BitTitan Sales: https://www.bittitan.com/contactsales/"
$report += "• BitTitan Store: https://store.bittitan.com/"
$report += "═══════════════════════════════════════════════════════════════"

# Save report
$report | Out-File -FilePath $reportFile -Encoding UTF8 -Force

# Display report
Write-Host "`n" -NoNewline
foreach ($line in $report) {
    if ($line -match '^╔|^╚|^═') {
        Write-Host $line -ForegroundColor Cyan
    }
    elseif ($line -match 'TOTAL ESTIMATED COST') {
        Write-Host $line -ForegroundColor Green
    }
    elseif ($line -match '^•') {
        Write-Host $line -ForegroundColor Yellow
    }
    else {
        Write-Host $line -ForegroundColor White
    }
}

Write-Host "`n[OK] Report saved to: $reportFile" -ForegroundColor Green
#endregion