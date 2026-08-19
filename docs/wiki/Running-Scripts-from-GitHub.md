# Running Scripts Directly from GitHub

## Overview
PowerShell scripts in this repository can be executed directly from GitHub without downloading them first. This approach uses PowerShell's `Invoke-Expression` and `Invoke-RestMethod` cmdlets to download and run scripts in a single command, making deployment and testing faster and more convenient.

This method is particularly useful for:
- Remote troubleshooting and support
- Quick testing without file system access
- Automated deployments via Intune or GPO
- Emergency fixes and hotfixes
- Training and demonstrations

## The Invoke Pattern

### Basic Syntax
```powershell
Invoke-Expression "& {$(Invoke-RestMethod 'URL_TO_SCRIPT')}"
```

### Short Form (Using Aliases)
```powershell
iex "& {$(irm 'URL_TO_SCRIPT')}"
```

**Where**:
- `iex` = Alias for `Invoke-Expression`
- `irm` = Alias for `Invoke-RestMethod`
- `URL_TO_SCRIPT` = Raw GitHub URL to the PowerShell script

## How It Works

### Step-by-Step Execution
1. **`Invoke-RestMethod`** downloads the script content from GitHub as text
2. **`$()`** captures the downloaded script text
3. **`& {}`** creates a script block from the text
4. **`Invoke-Expression`** executes the script block

### Why the `& {}` Wrapper?
The `& {}` script block wrapper allows you to pass parameters to the downloaded script:
```powershell
iex "& {$(irm 'URL')} -Parameter1 'Value1' -Parameter2"
```

## Getting the GitHub Raw URL

### Manual Method
1. Navigate to the script file on GitHub
2. Click the **"Raw"** button
3. Copy the URL from the browser address bar

### URL Pattern
```
https://raw.githubusercontent.com/[Owner]/[Repo]/[Branch]/[Path]/[ScriptName].ps1
```

### Example URLs for This Repository
**Pattern**:
```
https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/[Category]/[ScriptName].ps1
```

**Examples**:
- Intune Enrollment: `https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1`
- File Share Assessment: `https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/On%20Premise/Start-FileShareAssessment.ps1`
- Lync CSV Exporter: `https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Lync/Start-LyncCsvExporter.ps1`

**Note**: Spaces in paths must be URL-encoded as `%20`

## Usage Examples

### Example 1: Basic Script Execution (No Parameters)
```powershell
# Start Lync CSV Exporter
iex "& {$(irm https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Lync/Start-LyncCsvExporter.ps1)}"
```

### Example 2: Script with Parameters
```powershell
# File Share Assessment with parameters
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/On%20Premise/Start-FileShareAssessment.ps1"
iex "& {$(irm $url)} -Domain 'Contoso' -OutputDirectory 'C:\Reports'"
```

### Example 3: Intune Enrollment with Force and Sync
```powershell
# Force Intune enrollment with sync
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
Invoke-Expression "& {$(Invoke-RestMethod $url)} -ForceReenroll -SyncAfterEnroll"
```

### Example 4: Using Variable for Readability
```powershell
# Store URL in variable for cleaner syntax
$script = Invoke-RestMethod "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Teams/Get-ComprehensiveTeamsReport.ps1"
Invoke-Expression $script
```

### Example 5: Multiple Parameters
```powershell
# Teams assessment with multiple options
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Teams/Get-ComprehensiveTeamsReport.ps1"
iex "& {$(irm $url)} -OrganizationName 'Contoso' -IncludeVoiceAnalysis -ExportToCSV"
```

### Example 6: Pre-Download for Inspection
```powershell
# Download first to review before execution
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
$scriptContent = Invoke-RestMethod $url

# Review the script
$scriptContent | Out-File -FilePath "C:\Temp\Review.ps1" -Encoding UTF8
notepad "C:\Temp\Review.ps1"

# Execute after review
Invoke-Expression $scriptContent
```

## Deployment Scenarios

### Intune Remediation Script
**Detection Script**:
```powershell
# Check if device is enrolled in Intune
$enrolled = Test-Path "HKLM:\SOFTWARE\Microsoft\Enrollments\*\MS DM Server"
if ($enrolled) {
    Write-Output "Compliant"
    exit 0
} else {
    Write-Output "Not Compliant"
    exit 1
}
```

**Remediation Script**:
```powershell
# Set execution policy for this process
Set-ExecutionPolicy Bypass -Scope Process -Force

# Run enrollment script from GitHub
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
iex "& {$(irm $url)} -SyncAfterEnroll -NoRestart"
```

### Intune Win32 App (PowerShell Script Wrapper)
```powershell
# Install.ps1
Set-ExecutionPolicy Bypass -Scope Process -Force
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
try {
    iex "& {$(irm $url)} -SyncAfterEnroll -NoRestart"
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
```

### Group Policy Startup Script
```powershell
# GPO-StartupScript.ps1
# Computer Configuration > Policies > Windows Settings > Scripts > Startup

# Set execution policy
Set-ExecutionPolicy Bypass -Scope Process -Force

# Execute script from GitHub
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1"
Start-Transcript -Path "C:\Windows\Temp\IntuneEnrollment.log" -Append
try {
    Invoke-Expression "& {$(Invoke-RestMethod $url)} -SyncAfterEnroll -NoRestart"
} catch {
    Write-Error "Enrollment failed: $($_.Exception.Message)"
} finally {
    Stop-Transcript
}
```

### Scheduled Task for Recurring Execution
```powershell
# Create scheduled task that runs script from GitHub
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument @"
-NoProfile -ExecutionPolicy Bypass -Command "iex '& {`$(irm https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Lync/Start-LyncCsvExporter.ps1)} -OrganizationName \"Contoso\"'"
"@

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2AM
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "Weekly Lync Assessment" -Action $action -Trigger $trigger -Principal $principal
```

### Remote Execution via PowerShell Remoting
```powershell
# Execute on remote computer
Invoke-Command -ComputerName Server01 -ScriptBlock {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    $url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/On%20Premise/Start-FileShareAssessment.ps1"
    Invoke-Expression "& {$(Invoke-RestMethod $url)} -Domain 'Contoso' -OutputDirectory 'C:\Reports'"
}
```

### Azure Automation Runbook
```powershell
# Azure Automation runbook to run assessment
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Microsoft365/Get-QuickO365Report.ps1"

# Download script
$script = Invoke-RestMethod -Uri $url

# Connect to services (using Automation account credentials)
Connect-ExchangeOnline -CertificateThumbprint $thumbprint -AppId $appId -Organization $org

# Execute script
Invoke-Expression "& {$script} -TenantDomain 'contoso'"
```

## Execution Policy Considerations

### Why Execution Policy Matters
By default, Windows blocks script execution for security. When running scripts directly from the internet, you need to temporarily bypass the execution policy.

### Method 1: Process-Level Bypass (Recommended)
```powershell
# Only affects current PowerShell session
Set-ExecutionPolicy Bypass -Scope Process -Force
iex "& {$(irm 'URL')}"
```

### Method 2: One-Liner with Bypass
```powershell
# PowerShell.exe bypass flag
powershell.exe -ExecutionPolicy Bypass -Command "iex '& {`$(irm \"URL\")}'"
```

### Method 3: Within Script Block
```powershell
# Set policy, run script, policy resets when session closes
& {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    iex "& {$(irm 'URL')}"
}
```

### Permanent Policy Change (Not Recommended for Production)
```powershell
# Changes system-wide setting - use cautiously
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Security Considerations

### ⚠️ Important Security Notes

**1. Source Trust**: Only execute scripts from trusted repositories
```powershell
# ✅ GOOD: Official repository
iex "& {$(irm 'https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/...')}"

# ❌ BAD: Untrusted source
iex "& {$(irm 'https://random-website.com/script.ps1')}"
```

**2. Repository Verification**: Verify the repository owner before execution
- Check the repository is owned by **Managed-Solution-LLC**
- Verify the branch is **main** (not a fork or untrusted branch)

**3. Script Review**: For sensitive operations, download and review first
```powershell
# Download for review
$script = irm 'URL'
$script | Out-File 'Review.ps1'
# Review manually
notepad 'Review.ps1'
# Execute after approval
Invoke-Expression $script
```

**4. Use Specific Commits for Production**
```powershell
# Instead of 'main' branch (which changes), use specific commit hash
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/abc123def456/scripts/..."
```

**5. Network Security**: Scripts download over HTTPS, but validate certificates
```powershell
# PowerShell validates SSL certificates by default
# To verify:
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

**6. Audit Trail**: Log script executions in production environments
```powershell
Start-Transcript -Path "C:\Logs\ScriptExecution_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
iex "& {$(irm 'URL')}"
Stop-Transcript
```

### Risk Mitigation Strategies

**For Production Environments**:
1. ✅ Download scripts to a secure location first
2. ✅ Scan with antivirus before execution
3. ✅ Code review by security team
4. ✅ Version control - use commit hashes instead of branch names
5. ✅ Test in non-production environment first
6. ✅ Implement logging and monitoring
7. ✅ Use least-privilege accounts for execution

**For Testing/Development**:
- Running directly from GitHub is acceptable for rapid testing
- Use `-WhatIf` or `-Verbose` parameters when available
- Monitor for unexpected behavior

## Troubleshooting

### Issue: "Access to the path is denied"
**Cause**: Insufficient permissions

**Solution**: Run PowerShell as Administrator
```powershell
# Right-click PowerShell > Run as Administrator
# Or from elevated prompt:
Start-Process PowerShell -Verb RunAs
```

### Issue: "Invoke-WebRequest: The request was aborted"
**Cause**: TLS/SSL protocol version mismatch

**Solution**: Enable TLS 1.2
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
iex "& {$(irm 'URL')}"
```

### Issue: "Cannot be loaded because running scripts is disabled"
**Cause**: Execution policy restriction

**Solution**: Bypass execution policy for the session
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### Issue: "404 Not Found"
**Cause**: Incorrect URL or script moved

**Solution**: Verify URL format and check repository
```powershell
# Test URL in browser first
# Ensure 'raw.githubusercontent.com' is used (not 'github.com')
# Check for spaces in path (use %20)
```

### Issue: Script runs but parameters ignored
**Cause**: Incorrect parameter syntax

**Solution**: Use proper quote escaping
```powershell
# ❌ WRONG
iex "& {$(irm 'URL')} -Param "Value""

# ✅ CORRECT
iex "& {$(irm 'URL')} -Param 'Value'"
```

### Issue: "Cannot find path" errors within script
**Cause**: Working directory is user profile, not script directory

**Solution**: Scripts should use absolute paths or create directories as needed
```powershell
# Most repository scripts handle this automatically
# If issues persist, set working directory first:
Set-Location "C:\Temp"
iex "& {$(irm 'URL')}"
```

### Issue: Proxy/Firewall blocking GitHub access
**Cause**: Corporate proxy or firewall

**Solution**: Configure proxy settings
```powershell
# Set proxy
$proxy = [System.Net.WebProxy]::new('http://proxy.company.com:8080')
$proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
[System.Net.WebRequest]::DefaultWebProxy = $proxy

# Then execute script
iex "& {$(irm 'URL')}"
```

## Best Practices

### ✅ DO
- Use full URL in production scripts (avoid relying on branch names)
- Set execution policy at Process scope only
- Log executions in production environments
- Test in non-production first
- Review scripts before first-time execution
- Use parameters to customize behavior
- Handle errors with try/catch blocks
- Run with appropriate permissions (least privilege)

### ❌ DON'T
- Execute scripts from untrusted sources
- Disable execution policy permanently on production systems
- Ignore security warnings
- Run scripts you haven't reviewed
- Execute with unnecessary elevated privileges
- Hardcode sensitive data in command lines
- Assume scripts are safe just because they're on GitHub

## Quick Reference

### Common Scripts from This Repository

#### Intune Enrollment
```powershell
iex "& {$(irm https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Intune/Start-IntuneEnrollment.ps1)} -SyncAfterEnroll"
```

#### File Share Assessment
```powershell
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/On%20Premise/Start-FileShareAssessment.ps1"
iex "& {$(irm $url)} -Domain 'YourOrg'"
```

#### Lync CSV Export
```powershell
iex "& {$(irm https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Lync/Start-LyncCsvExporter.ps1)}"
```

#### Teams Assessment
```powershell
$url = "https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Teams/Get-ComprehensiveTeamsReport.ps1"
iex "& {$(irm $url)} -OrganizationName 'YourOrg' -IncludeVoiceAnalysis"
```

#### Microsoft 365 Quick Report
```powershell
iex "& {$(irm https://raw.githubusercontent.com/Managed-Solution-LLC/PowerShellEveryting/main/scripts/Assessment/Microsoft365/Get-QuickO365Report.ps1)} -TenantDomain 'contoso'"
```

## Alternative Methods

### Method 1: Save to File First
```powershell
# Download to file
Invoke-WebRequest -Uri 'URL' -OutFile 'C:\Temp\Script.ps1'

# Review
notepad 'C:\Temp\Script.ps1'

# Execute
& 'C:\Temp\Script.ps1' -Parameter1 'Value'
```

### Method 2: Using Start-Process
```powershell
# Download and execute in new window
$script = irm 'URL'
$script | Out-File 'C:\Temp\temp.ps1'
Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File C:\Temp\temp.ps1"
```

### Method 3: Remote Jobs
```powershell
# Execute as background job
$job = Start-Job -ScriptBlock {
    param($url)
    iex "& {$(irm $url)}"
} -ArgumentList 'URL'

Wait-Job $job
Receive-Job $job
```

## Related Documentation

- [Start-IntuneEnrollment.ps1](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Start-IntuneEnrollment) - Examples of GitHub execution with parameters
- [PowerShell Execution Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
- [Invoke-Expression Documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-expression)
- [Invoke-RestMethod Documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-restmethod)

## Support

For issues or questions about running scripts from GitHub:
- Review this guide thoroughly
- Check the troubleshooting section
- Verify URL format and permissions
- Test with simple scripts first
- Report issues: [GitHub Issues](https://github.com/Managed-Solution-LLC/PowerShellEveryting/issues)

---

**Last Updated**: 2026-01-05  
**Version**: 1.0
