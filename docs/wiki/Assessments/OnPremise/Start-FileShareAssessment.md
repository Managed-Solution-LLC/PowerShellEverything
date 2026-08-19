# Start-FileShareAssessment.ps1

## Overview
Comprehensive file share assessment tool that analyzes SMB shares on a Windows file server and generates a formatted Excel report. This all-in-one script automatically discovers shares, analyzes storage usage, examines NTFS permissions, identifies SharePoint/OneDrive compatibility issues, and consolidates all findings into a professional Excel workbook.

Designed to run directly on the file server with administrative privileges, this tool provides complete visibility into file share infrastructure for migration planning, security audits, and capacity management.

## Features
- **Automatic Share Discovery**: Identifies all non-administrative SMB shares on the local server
- **Storage Analysis**: Calculates folder sizes, file counts, and total storage consumption
- **Permission Analysis**: Complete NTFS ACL inheritance mapping for all folders
- **Compatibility Scanning**: Identifies files with SharePoint/OneDrive unsupported characters
- **Excel Report Generation**: Creates formatted Excel workbook with auto-sizing, filtering, and frozen headers
- **Performance Optimization**: Configurable parallel processing for large environments
- **Detailed Logging**: Color-coded console output with error and warning tracking
- **Long Path Support**: Automatic detection and enablement of long path support

## Prerequisites

### PowerShell Requirements
- **PowerShell 5.1 or later** (included in Windows Server 2016+)
- **Administrator privileges** on the file server
- **Execution Policy**: RemoteSigned or Unrestricted

### Modules
- **ImportExcel** - Auto-installed by script if missing

### System Requirements
- Must be run directly on the file server (not remote execution)
- Sufficient disk space for CSV exports and Excel report
- Network shares must be accessible via local paths

## Parameters

### Required Parameters

#### -Domain
The domain or organization name for the assessment. Used in report naming and identification.

**Type**: String  
**Mandatory**: Yes  
**Example**: `"contoso"`, `"Lawson"`

### Optional Parameters

#### -OutputDirectory
Directory where CSV files and Excel report will be saved.

**Type**: String  
**Default**: Current directory (`.`)  
**Example**: `"C:\Reports"`, `".\FileShareAssessment"`

#### -ExcludeShares
Array of share names to exclude from assessment. Administrative shares are excluded by default.

**Type**: String[]  
**Default**: `@("ADMIN$", "IPC$", "C$", "D$", "E$", "F$")`  
**Example**: `@("Backup$", "Archive$", "ADMIN$")`

#### -SkipPermissions
Skip the permissions analysis phase. Use this for faster execution when only storage analysis is needed.

**Type**: Switch  
**Default**: False

#### -Workers
Number of parallel workers for permission scanning. Increase for better performance on servers with many folders.

**Type**: Int  
**Default**: 50  
**Range**: 1-500  
**Example**: `100`, `200`

## Usage Examples

### Example 1: Basic Assessment
```powershell
.\Start-FileShareAssessment.ps1 -Domain "Contoso"
```
Runs complete assessment on all shares and creates `Contoso_File_Share_Assessment.xlsx` in current directory.

### Example 2: Custom Output Location
```powershell
.\Start-FileShareAssessment.ps1 -Domain "Contoso" -OutputDirectory "C:\Reports\FileShares"
```
Saves all output to specified directory.

### Example 3: Exclude Specific Shares
```powershell
.\Start-FileShareAssessment.ps1 -Domain "Contoso" -ExcludeShares "Backup$","Archive$","IPC$"
```
Excludes backup and archive shares from assessment.

### Example 4: Quick Storage-Only Assessment
```powershell
.\Start-FileShareAssessment.ps1 -Domain "Contoso" -SkipPermissions
```
Skips permission analysis for faster execution. Only analyzes storage and compatibility.

### Example 5: High-Performance Assessment
```powershell
.\Start-FileShareAssessment.ps1 -Domain "Contoso" -Workers 200 -OutputDirectory "D:\Assessments"
```
Uses 200 parallel workers for faster permission scanning on large environments.

### Example 6: Remote Execution via PowerShell Remoting
```powershell
Invoke-Command -ComputerName FileServer01 -ScriptBlock {
    & "C:\Scripts\Start-FileShareAssessment.ps1" -Domain "Contoso" -OutputDirectory "C:\Temp\Reports"
}
```
Runs assessment on remote server via PowerShell remoting.

## Output

### Output File Structure
```
OutputDirectory/
├── Contoso_File_Share_Assessment.xlsx    # Main Excel report
├── fileaudit_ShareName.csv                # Size analysis per share
├── unsupported_filenames_ShareName.csv    # Compatibility issues per share
└── RawData/
    └── permissions_ShareName_Folder.csv   # Permission details per top-level folder
```

### Output File Naming
**Pattern**: `{Category}_{ShareName}_{YYYYMMDD_HHmmss}.{ext}`

**Examples**:
- `fileaudit_Data.csv` - Storage analysis for "Data" share
- `unsupported_filenames_Users.csv` - Compatibility report for "Users" share
- `permissions_Projects_Engineering.csv` - Permissions for "Engineering" folder in "Projects" share

### Excel Workbook Structure

#### Share Analysis Worksheets
One worksheet per share containing:
- **FolderName**: Top-level folder or "Root"
- **FolderSizeGB**: Size in gigabytes (rounded to 2 decimals)
- **TotalFolders**: Number of subfolders
- **TotalFiles**: Number of files
- **Total row**: Aggregate statistics for entire share

#### Unsupported Characters Worksheets (USC - ShareName)
One worksheet per share (if issues found) containing:
- **Name**: Filename with unsupported character
- **Directory**: Parent directory path
- **FullName**: Complete file path

**Unsupported Characters**: `~ # % & * { } \ : < > ? / | "`

#### Permission Worksheets
One worksheet per top-level folder containing:
- **SharePath**: Root share path
- **FolderName**: Relative folder path
- **IdentityReference**: User or group (DOMAIN\User)
- **FileSystemRights**: Permission level (Read, Modify, FullControl, etc.)
- **AccessControlType**: Allow or Deny
- **IsInherited**: True if inherited from parent

## Execution Workflow

### Phase 1: Prerequisites Check
1. Validates administrator privileges
2. Checks long path support (enables if needed)
3. Verifies output directory exists or creates it
4. Installs ImportExcel module if missing

### Phase 2: Share Discovery
1. Enumerates all SMB shares on local server
2. Filters out administrative and excluded shares
3. Displays share list for verification

### Phase 3: Share Analysis (Per Share)
1. **Storage Analysis**: Calculates size for each top-level folder
2. **Permission Analysis**: Maps NTFS ACLs for all subfolders (if enabled)
3. **Compatibility Scan**: Identifies files with unsupported characters

### Phase 4: Report Generation
1. Imports all generated CSV files
2. Creates Excel workbook with separate worksheets
3. Applies formatting (auto-size, filters, frozen headers)
4. Displays summary statistics

### Phase 5: Completion
1. Shows execution duration and statistics
2. Prompts to open Excel report
3. Provides final error and warning counts

## Performance Considerations

### Small Environments (< 100 GB)
- **Typical Duration**: 5-15 minutes
- **Recommended Workers**: 50 (default)
- **Memory Usage**: < 2 GB

### Medium Environments (100 GB - 1 TB)
- **Typical Duration**: 15-60 minutes
- **Recommended Workers**: 100-150
- **Memory Usage**: 2-4 GB
- **Optimization**: Consider `-SkipPermissions` for initial assessment

### Large Environments (> 1 TB)
- **Typical Duration**: 1-4 hours
- **Recommended Workers**: 150-200
- **Memory Usage**: 4-8 GB
- **Optimization**: 
  - Use `-SkipPermissions` initially
  - Run during off-hours
  - Break into multiple executions per share
  - Increase disk I/O priority

### Bottlenecks
- **Permission scanning** is most time-intensive
- **Deep folder structures** slow enumeration
- **Network shares** (UNC paths) slower than local paths
- **Antivirus scanning** can impact file enumeration

## Common Issues & Troubleshooting

### Issue: "Access to path is denied"
**Cause**: Insufficient permissions to access certain folders

**Solution**: 
- Run as Domain Admin or with appropriate delegated permissions
- Use account with "Take Ownership" rights
- Check share and NTFS permissions

### Issue: "Long paths are not enabled"
**Cause**: Windows long path support not configured

**Solution**: 
- Script will prompt to enable automatically
- Manual: `Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1`
- Restart may be required for full effect

### Issue: "Failed to install ImportExcel module"
**Cause**: PowerShell Gallery connectivity or permissions issue

**Solution**:
```powershell
# Manual installation
Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber

# If behind proxy
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
Install-Module ImportExcel -Scope CurrentUser -Force
```

### Issue: Slow permission scanning
**Cause**: Too many folders or insufficient workers

**Solution**:
- Increase workers: `-Workers 200`
- Skip permissions: `-SkipPermissions`
- Run during off-hours
- Process shares individually

### Issue: Excel file is locked
**Cause**: Excel application has file open

**Solution**:
- Close Excel before re-running script
- Delete existing Excel file manually
- Use different output directory

### Issue: Missing shares in output
**Cause**: Share excluded by filter or inaccessible

**Solution**:
- Check `-ExcludeShares` parameter
- Verify share exists: `Get-SmbShare`
- Check share permissions
- Review console output for errors

## Security Considerations

### Required Permissions
- **Local Administrator** on file server
- **Read access** to all shares and folders
- **Modify access** to output directory

### Data Sensitivity
- **Permission exports** contain security group mappings
- **Excel reports** show folder structures and file names
- **Store reports securely** - they contain sensitive information
- **Delete CSV files** after Excel generation if needed

### Best Practices
- Run from secure workstation or server
- Use encrypted file shares for output
- Restrict access to generated reports
- Delete temporary CSV files after review
- Audit script execution

## Integration Examples

### Schedule as Task
```powershell
# Create scheduled task for monthly assessment
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Start-FileShareAssessment.ps1 -Domain 'Contoso' -OutputDirectory 'D:\Reports'"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2AM

Register-ScheduledTask -TaskName "FileShareAssessment" -Action $action -Trigger $trigger -User "DOMAIN\ServiceAccount" -RunLevel Highest
```

### Email Report After Completion
```powershell
.\Start-FileShareAssessment.ps1 -Domain "Contoso" -OutputDirectory "C:\Temp"

$excelFile = "C:\Temp\Contoso_File_Share_Assessment.xlsx"
Send-MailMessage -To "admin@contoso.com" -From "reports@contoso.com" `
    -Subject "File Share Assessment - $(Get-Date -Format 'yyyy-MM-dd')" `
    -Body "Attached is the latest file share assessment." `
    -Attachments $excelFile -SmtpServer "mail.contoso.com"
```

### Compare Reports Over Time
```powershell
# Generate monthly reports with timestamps
$reportDate = Get-Date -Format "yyyyMM"
.\Start-FileShareAssessment.ps1 -Domain "Contoso" -OutputDirectory "C:\Reports\$reportDate"

# Compare current vs previous month
$currentReport = Import-Excel "C:\Reports\$reportDate\Contoso_File_Share_Assessment.xlsx" -WorksheetName "Data"
$previousDate = (Get-Date).AddMonths(-1).ToString("yyyyMM")
$previousReport = Import-Excel "C:\Reports\$previousDate\Contoso_File_Share_Assessment.xlsx" -WorksheetName "Data"

Compare-Object $previousReport $currentReport -Property FolderName, FolderSizeGB
```

## Related Scripts
- [Start-WindowsServerAssessment.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Start-WindowsServerAssessment) - Complete server infrastructure assessment
- [Export-ADUsersAndGroups.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Export-ADUsersAndGroups) - Active Directory user and group export
- [Get-MailboxPermissionsReport.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-MailboxPermissionsReport) - Office 365 mailbox permissions

## Version History
- **v1.0** (2026-01-05): Initial release
  - Automatic share discovery
  - Storage and permission analysis
  - Unsupported character detection
  - Excel report generation with formatting

## See Also
- [On-Premise Assessment Overview](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/README)
- [File Share Migration Planning Guide](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/FileShareMigration)
- [Microsoft Docs: SMB Share Management](https://docs.microsoft.com/en-us/windows-server/storage/file-server/file-server-smb-overview)
- [ImportExcel Module Documentation](https://github.com/dfinke/ImportExcel)
