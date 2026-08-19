# PowerShellEveryting - AI Coding Agent Instructions

## Project Overview
Enterprise PowerShell toolkit for Microsoft 365, Azure AD, Teams, Lync/Skype for Business, and Intune management. Scripts are production-ready tools used by IT professionals for assessments, migrations, reporting, and automation.

**IMPORTANT: Client-Agnostic Development**
- Never hardcode organization names, tenant IDs, or client-specific identifiers
- Always use parameters for organization/tenant identification
- Default to generic names like "Organization", "Contoso", or placeholder patterns
- Customer-specific scripts belong in `.prep/` directories only
- Public scripts must work for any customer without modification

## Architecture & Organization

### Folder Structure
```
scripts/
├── Assessment/          # Comprehensive environment assessments
│   ├── Lync/           # Lync/Skype for Business assessment tools
│   ├── Microsoft365/   # Microsoft 365 assessment tools
│   ├── Teams/          # Teams infrastructure assessments
│   ├── Security/       # Security posture assessments
│   └── Office365/      # O365 assessments (legacy location)
├── Azure/              # Azure and M365 automation
├── Graph Commands/     # Microsoft Graph API helpers
├── Intune/             # Intune management and assessment
│   └── Assessment/     # Intune assessment scripts
├── Office365/          # O365 user/mailbox management
├── Defender/           # Microsoft Defender scripts
├── Data Processing/    # Data analysis and reporting tools
└── Security/           # Security-related scripts and CVE fixes
build/                  # Build automation (in development)
docs/                   # Project documentation and change logs
├── wiki/               # Detailed script documentation
│   ├── Assessments/    # Assessment script documentation
│   │   ├── Lync/       # Lync/Skype documentation
│   │   ├── Microsoft365/ # M365 assessment documentation
│   │   ├── Teams/      # Teams documentation
│   │   └── Security/   # Security assessment documentation
│   └── Azure/          # Azure script documentation
└── *.md                # General guides and project docs
```

### Script Lifecycle: `.prep` Directories
- **`.prep/` folders** contain work-in-progress or customer-specific scripts
- Scripts in `.prep/` are NOT validated for public release
- Ready scripts move from `.prep/` to parent directory after validation
- Public scripts include `# VALIDATED FOR PUBLIC RELEASE` header with date
- **Customer-specific adaptations stay in `.prep/`** - never promote client-specific logic to public folders

## Code Standards & Patterns

### Comment-Based Help (MANDATORY)
Every public script MUST include comprehensive comment-based help:
```powershell
<#
.SYNOPSIS
    Brief one-line description
.DESCRIPTION
    Detailed multi-paragraph description including:
    - What the script does
    - Key features and capabilities
    - Data analysis provided
.PARAMETER ParameterName
    Detailed parameter description including defaults and validation rules
.EXAMPLE
    .\Script.ps1 -Param "Value"
    Description of what this example does
.NOTES
    Author: W. Ford (or William Ford, or Managed Solution LLC)
    Date: YYYY-MM-DD (actual dates, not placeholders)
    Version: X.Y
    
    Requirements:
    - Required PowerShell modules (specific versions if needed)
    - Required permissions/roles
    - PowerShell version requirements
    
    Additional context about dependencies, prerequisites, outputs
.LINK
    https://docs.microsoft.com/... (relevant Microsoft documentation)
#>
```

### Parameter Patterns
```powershell
# Use [CmdletBinding()] for advanced functions
[CmdletBinding()]
param(
    # Mandatory with validation
    [Parameter(Mandatory=$true, HelpMessage="Descriptive help text")]
    [ValidateNotNullOrEmpty()]
    [string]$RequiredParam,
    
    # Optional with defaults - use realistic defaults
    [Parameter(Mandatory=$false, HelpMessage="Help text")]
    [string]$OutputDirectory = "C:\Reports\CSV_Exports",
    
    # Optional with validation range
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 168)]
    [int]$Hours = 24,
    
    # Organization name - always parameterize, never hardcode
    [Parameter(Mandatory=$false, HelpMessage="Organization name for reports")]
    [string]$OrganizationName = "Organization",
    
    # Switch parameters for features
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDetails
)
```

**Client-Agnostic Parameter Guidelines:**
- Use `$OrganizationName` parameter with default "Organization" or "Contoso"
- Never hardcode tenant IDs - make them parameters
- Avoid customer-specific pattern matching (e.g., specific SBA patterns) in public scripts
- Use generic examples in help text and documentation

### Reporting & Output Standards

#### File Naming Convention
All exports use timestamps: `{Category}_{Type}_{YYYYMMDD_HHmmss}.{ext}`
```powershell
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$OutputFile = "$OutputDirectory\Lync_Users_Summary_$Timestamp.csv"
```

#### Report Headers
Text reports use consistent separator patterns:
```powershell
$Separator = "=" * 80
$SubSeparator = "-" * 60
$Report += "$OrganizationName - REPORT TITLE"
$Report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$Report += $Separator
```

#### Status Messages
Use colored console output for user feedback:
```powershell
# Success with checkmark
Write-Host "✅ Exported $($Data.Count) records to: $OutputFile" -ForegroundColor Green

# Error with X
Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red

# Warning
Write-Host "⚠️  Warning: No data found" -ForegroundColor Yellow

# Info during processing
Write-Host "Exporting users..." -ForegroundColor Yellow
Write-Host "Processing $count items..." -ForegroundColor Cyan
```

### Error Handling Patterns

#### Safe Command Execution with Detailed Verification
Large assessment scripts use wrapper functions with comprehensive error handling:
```powershell
function Invoke-SafeCommand {
    param(
        [scriptblock]$Command,
        [string]$ErrorMessage = "Command execution failed",
        [switch]$ContinueOnError
    )
    try {
        Write-Verbose "Executing command: $($Command.ToString().Substring(0, [Math]::Min(50, $Command.ToString().Length)))..."
        $result = & $Command
        
        # Validate result
        if ($null -eq $result) {
            Write-Warning "Command returned null result"
        }
        
        return $result
    }
    catch {
        $errorDetails = "$ErrorMessage - $($_.Exception.Message)"
        Write-Host "❌ $errorDetails" -ForegroundColor Red
        
        # Log stack trace for debugging
        Write-Verbose "Stack Trace: $($_.ScriptStackTrace)"
        
        if (-not $ContinueOnError) {
            throw
        }
        return $null
    }
}

# Example usage with verification
$users = Invoke-SafeCommand -Command { 
    Get-CsUser -ErrorAction Stop 
} -ErrorMessage "Failed to retrieve Lync users" -ContinueOnError

if ($null -eq $users -or $users.Count -eq 0) {
    Write-Host "⚠️  No users found or command failed" -ForegroundColor Yellow
    # Decide how to proceed
}
```

#### Status Tracking
```powershell
$ErrorCount = 0
$WarningCount = 0

function Write-StatusMessage {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        "Error" { Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor Red; $script:ErrorCount++ }
        "Warning" { Write-Host "[$timestamp] WARNING: $Message" -ForegroundColor Yellow; $script:WarningCount++ }
        "Success" { Write-Host "[$timestamp] SUCCESS: $Message" -ForegroundColor Green }
        default { Write-Host "[$timestamp] INFO: $Message" -ForegroundColor Cyan }
    }
}
```

## Microsoft Module Patterns

### Module Installation & Verification (CRITICAL)
Always check module availability before use. Never assume modules are installed:

```powershell
# Pattern 1: Check and install if missing
$RequiredModules = @('MicrosoftTeams', 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users')
foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -Name $Module -ListAvailable)) {
        Write-Host "Installing required module: $Module" -ForegroundColor Yellow
        try {
            Install-Module -Name $Module -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Write-Host "✅ Successfully installed $Module" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Failed to install $Module - $($_.Exception.Message)" -ForegroundColor Red
            throw "Required module $Module could not be installed"
        }
    }
    else {
        Write-Host "✅ Module $Module is already installed" -ForegroundColor Green
    }
}

# Pattern 2: Import with error handling
try {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop
}
catch {
    Write-Host "❌ Failed to import module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Pattern 3: PowerShell 7 compatibility for legacy modules (MSOnline, AzureAD)
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # MSOnline doesn't work natively in PS7, use compatibility mode
    Import-Module MSOnline -UseWindowsPowerShell -ErrorAction Stop
}
else {
    Import-Module MSOnline -ErrorAction Stop
}
```

### Connection Patterns with Verification
Always verify connections before proceeding with operations:

```powershell
# Microsoft Graph - specify exact scopes needed, verify connection
try {
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All" -NoWelcome -ErrorAction Stop
    $context = Get-MgContext
    if ($context) {
        Write-Host "✅ Connected to Microsoft Graph as $($context.Account)" -ForegroundColor Green
    }
}
catch {
    Write-Host "❌ Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Exchange Online - suppress progress, verify connection
try {
    Connect-ExchangeOnline -ShowProgress $false -ErrorAction Stop
    # Verify with a simple command
    $null = Get-OrganizationConfig -ErrorAction Stop
    Write-Host "✅ Connected to Exchange Online" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to connect to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Teams - check module availability before connecting
if (-not (Get-Module -Name MicrosoftTeams -ListAvailable)) {
    Write-Host "❌ MicrosoftTeams module not installed. Run: Install-Module MicrosoftTeams" -ForegroundColor Red
    exit 1
}
try {
    Connect-MicrosoftTeams -ErrorAction Stop
    Write-Host "✅ Connected to Microsoft Teams" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to connect to Teams: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Lync/Skype - verify cmdlets are available
if (-not (Get-Command Get-CsUser -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Lync/Skype PowerShell cmdlets not available. Run this from Lync Management Shell" -ForegroundColor Red
    exit 1
}
```

### Command Verification Pattern
Before running critical cmdlets, verify they exist:

```powershell
# Verify command exists before use
$CmdletName = 'Get-CsUser'
if (-not (Get-Command $CmdletName -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Required cmdlet '$CmdletName' is not available" -ForegroundColor Red
    Write-Host "   Ensure you're running from the appropriate management shell" -ForegroundColor Yellow
    exit 1
}

# For multiple cmdlets
$RequiredCmdlets = @('Get-CsUser', 'Get-CsPool', 'Get-CsVoicePolicy')
$MissingCmdlets = $RequiredCmdlets | Where-Object { 
    -not (Get-Command $_ -ErrorAction SilentlyContinue) 
}
if ($MissingCmdlets) {
    Write-Host "❌ Missing required cmdlets: $($MissingCmdlets -join ', ')" -ForegroundColor Red
    exit 1
}
```

### Graph API Pagination
Use the custom `Get-AzureResourcePaging` function for OData pagination:
```powershell
# See scripts/Graph Commands/Get-AzureResourcePaging.ps1
function Get-AzureResourcePaging {
    param($URL, $AuthHeader)
    $Response = Invoke-RestMethod -Method GET -Uri $URL -Headers $AuthHeader
    $Resources = $Response.value
    $ResponseNextLink = $Response."@odata.nextLink"
    while ($ResponseNextLink -ne $null) {
        $Response = Invoke-RestMethod -Uri $ResponseNextLink -Headers $AuthHeader -Method Get
        $ResponseNextLink = $Response."@odata.nextLink"
        $Resources += $Response.value
    }
    return $Resources
}
```

## Key Utilities & Reusable Functions

### Graph Authentication (`scripts/Graph Commands/`)
- **`Get-GraphToken.ps1`**: OAuth2 token acquisition using MSAL.PS (client secret or interactive)
- **`Get-GraphHeaders.ps1`**: Format authorization headers for Graph API calls
- **`Get-AzureResourcePaging.ps1`**: Handle OData pagination in Graph API responses

### Module Development (`scripts/Assessment/Teams/TeamsInfrastructureAssessment.psm1`)
When creating `.psm1` modules:
- Export functions explicitly at module level
- Include module-level synopsis and description
- Provide logging helper functions (`Write-TeamsLog`)
- Include safe command execution wrappers (`Invoke-TeamsCommand`)

## Assessment Script Patterns

### Menu-Based Interactive Tools
Reference: `scripts/Assessment/Lync/Start-LyncCsvExporter.ps1`
```powershell
# Interactive menu with categorized options
function Show-Menu {
    Write-Host "`n$Separator" -ForegroundColor Cyan
    Write-Host "EXPORT MENU" -ForegroundColor Cyan
    Write-Host $Separator -ForegroundColor Cyan
    Write-Host " [1] Export Option 1" -ForegroundColor White
    Write-Host " [Q] Quit" -ForegroundColor Gray
}

# Process menu selections
do {
    Show-Menu
    $choice = Read-Host "`nSelect option"
    switch ($choice) {
        "1" { Export-Function -Type "TypeName" }
        "Q" { break }
    }
} while ($choice -ne "Q")
```

### Comprehensive Reports
Reference: `scripts/Assessment/Teams/Get-ComprehensiveTeamsReport.ps1`

Complete assessment script structure:
```powershell
# 1. Module dependency checks (FIRST THING)
$RequiredModules = @('MicrosoftTeams', 'Microsoft.Graph.Authentication')
foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -Name $Module -ListAvailable)) {
        Write-Host "❌ Required module '$Module' not installed" -ForegroundColor Red
        Write-Host "   Install with: Install-Module $Module -Scope CurrentUser" -ForegroundColor Yellow
        exit 1
    }
}

# 2. Initialize tracking variables
$StartTime = Get-Date
$ErrorCount = 0
$WarningCount = 0

# 3. Connect to services with verification
try {
    Connect-MicrosoftTeams -ErrorAction Stop
    Write-Host "✅ Connected to Microsoft Teams" -ForegroundColor Green
}
catch {
    Write-Host "❌ Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 4. Use switch parameters for optional detailed sections
if ($IncludeVoiceAnalysis) {
    # Verify voice cmdlets available
    if (Get-Command Get-CsOnlineVoiceRoute -ErrorAction SilentlyContinue) {
        $voiceRoutes = Invoke-SafeCommand { Get-CsOnlineVoiceRoute }
    }
}

# 5. Generate reports with error counting
# (see Write-StatusMessage pattern above)

# 6. Summary with execution time
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "Assessment completed in $($Duration.ToString('mm\:ss'))" -ForegroundColor Green
Write-Host "Errors: $ErrorCount | Warnings: $WarningCount" -ForegroundColor $(if($ErrorCount -gt 0){'Red'}else{'Green'})

# 7. Cleanup (ALWAYS in finally block)
try {
    Disconnect-MicrosoftTeams -ErrorAction SilentlyContinue
}
finally {
    # Ensure cleanup happens even if errors occur
}
```

Key Patterns:
- Start with module dependency checks
- Use switch parameters for optional detailed sections (`-IncludeVoiceAnalysis`, `-IncludeComplianceAnalysis`)
- Track execution time and error counts
- Generate executive summary sections
- Support CSV export alongside text reports
- Always cleanup connections in finally blocks

## Data Processing Conventions

### CSV Exports
Always use UTF8 encoding and NoTypeInformation:
```powershell
$Data | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
```

### Calculated Properties
Use consistent calculated property syntax:
```powershell
$Users | Select-Object @{
    Name = 'DisplayName'; Expression = { $_.DisplayName }
}, @{
    Name = 'VoiceEnabled'; Expression = { $_.EnterpriseVoiceEnabled }
}, @{
    Name = 'LineURI'; Expression = { $_.LineURI }
}
```

## Environment-Specific Patterns

### Lync/Skype for Business
- Use `Get-CsUser`, `Get-CsPool`, `Get-CsCommonAreaPhone`, etc.
- Extract site info from pool names: `($_.RegistrarPool -split '-')[0]`
- Handle Survivable Branch Appliances (SBA) with pattern matching

### Teams/Modern Workloads
- Teams cmdlets: `Get-CsTeamsCallingPolicy`, `Get-CsOnlineVoiceRoute`
- Combine Teams + Graph for comprehensive analysis
- Include voice config (Direct Routing, Calling Plans)

### Security & Compliance
- Reference: `scripts/Assessment/Security/Check-PriveledgeRolestoPIM.ps1`
- Identify privileged roles requiring PIM conversion
- Export compliance reports with risk levels

## Testing & Validation

Scripts are tested in production IT environments. When modifying:

### Pre-Execution Checks (MANDATORY)
```powershell
# 1. Validate PowerShell version if needed
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "❌ This script requires PowerShell 5.1 or later" -ForegroundColor Red
    exit 1
}

# 2. Check execution policy
$execPolicy = Get-ExecutionPolicy
if ($execPolicy -eq 'Restricted') {
    Write-Host "❌ Execution policy is Restricted. Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Red
    exit 1
}

# 3. Validate required modules BEFORE starting work
$RequiredModules = @('Microsoft.Graph.Users', 'ExchangeOnlineManagement')
$MissingModules = $RequiredModules | Where-Object { 
    -not (Get-Module -Name $_ -ListAvailable) 
}
if ($MissingModules) {
    Write-Host "❌ Missing required modules: $($MissingModules -join ', ')" -ForegroundColor Red
    Write-Host "   Install with: Install-Module $($MissingModules -join ', ') -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# 4. Verify output directory exists or can be created
if (!(Test-Path $OutputDirectory)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop | Out-Null
        Write-Host "✅ Created output directory: $OutputDirectory" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Cannot create output directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# 5. Test write permissions
$testFile = Join-Path $OutputDirectory "test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
try {
    "test" | Out-File -FilePath $testFile -ErrorAction Stop
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Write permissions verified" -ForegroundColor Green
}
catch {
    Write-Host "❌ No write permission to output directory" -ForegroundColor Red
    exit 1
}
```

### Validation Checklist When Modifying Scripts:
1. **Preserve parameter validation and mandatory flags** - critical for production use
2. **Test all module availability checks** - verify error messages guide users correctly
3. **Verify CSV exports maintain column structure** - existing automation depends on consistent columns
4. **Ensure console output uses correct color coding** - users rely on color patterns
5. **Validate file paths work with spaces** - use quotes: `"$OutputDirectory\file.csv"`
6. **Test cmdlet availability** - especially for Lync/Skype cmdlets
7. **Verify error handling doesn't silently fail** - users must know when operations fail
8. **Check disconnection cleanup** - always disconnect from services in finally blocks

## Common Module Dependencies
- **Microsoft.Graph** (various submodules)
- **MicrosoftTeams**
- **ExchangeOnlineManagement**
- **Microsoft.Online.SharePoint.PowerShell**
- **MSOnline** (legacy, being phased out)
- **MSAL.PS** (for custom Graph auth)
- **Lync/Skype PowerShell** (for Lync scripts)

## File Encoding & Line Endings
- UTF8 for CSV exports
- Use Windows line endings (CRLF) for PowerShell scripts
- Avoid BOM where possible unless required by Excel imports
## Documentation Requirements

### In-Script Documentation (ALWAYS REQUIRED)
When adding new scripts:
1. Include comprehensive comment-based help (see Comment-Based Help section)
2. Use real dates in version history (not "TBD" or placeholders)
3. **Ensure examples use generic organization names** (Contoso, Fabrikam, Organization)
4. **Remove any client-specific references** before promoting to public folders

### Wiki Documentation (REQUIRED FOR PUBLIC RELEASE)
Once a script is finalized, tested, and approved for public release, create detailed documentation:

**Location Pattern**: `docs/wiki/<CategoryPath>/<ScriptName>.md`

**Examples**:
- `docs/wiki/Assessments/Lync/Start-LyncCsvExporter.md`
- `docs/wiki/Assessments/Microsoft365/Get-MailboxPermissionsReport.md`
- `docs/wiki/Assessments/Teams/Get-ComprehensiveTeamsReport.md`
- `docs/wiki/Azure/Backup-MgGraphBitLockerKeys.md`

**Documentation Structure**:
```markdown
# Script Name

## Overview
Brief description of what the script does and its primary purpose.

## Features
- Key feature 1
- Key feature 2
- Data analysis provided

## Prerequisites
- Required PowerShell version
- Required modules with versions
- Required permissions/roles
- Network/connectivity requirements

## Parameters
### Required Parameters
- **ParameterName**: Description, validation rules, examples

### Optional Parameters
- **ParameterName**: Description, default value, validation rules

## Usage Examples

### Example 1: Basic Usage
\`\`\`powershell
.\ScriptName.ps1 -RequiredParam "Value"
\`\`\`
Description of what this example does.

### Example 2: Advanced Usage
\`\`\`powershell
.\ScriptName.ps1 -RequiredParam "Value" -OptionalParam -IncludeDetails
\`\`\`
Description of advanced features.

## Output
Description of what the script produces:
- CSV files (with column descriptions)
- Text reports (with section descriptions)
- Console output patterns

### Output File Locations
Default: `C:\Reports\CSV_Exports\` (or specify custom path)

### Output File Naming
Pattern: `{Category}_{Type}_{YYYYMMDD_HHmmss}.{ext}`

Example: `Teams_Users_Report_20251223_143052.csv`

## Common Issues & Troubleshooting

### Issue: Module Not Found
**Solution**: Install required modules:
\`\`\`powershell
Install-Module ModuleName -Scope CurrentUser
\`\`\`

### Issue: Connection Failed
**Solution**: Ensure you have appropriate permissions and MFA is configured correctly.

## Related Scripts
- Link to related assessment scripts
- Link to complementary tools

## Version History
- **v1.0** (2025-12-23): Initial release - Core functionality
- **v1.1** (YYYY-MM-DD): Description of changes

## See Also
- [Microsoft Documentation Link](https://docs.microsoft.com/...)
- [Related Internal Documentation](../RelatedDoc.md)
```

### Documentation Workflow
1. **During Development**: Include comprehensive comment-based help in script
2. **Move from `.prep/`**: When promoting script to public folder, validate it's client-agnostic
3. **Testing Complete**: After production testing and approval
4. **Create Wiki Doc**: Create markdown file in `docs/wiki/<CategoryPath>/`
5. **Update/Create Folder README**: Update or create `README.md` in script's folder (e.g., `scripts/Assessment/Lync/README.md`) that:
   - Lists all scripts in the folder with brief descriptions
   - Links to wiki documentation for each script
   - Provides quick start examples
   - Documents common prerequisites
   - Includes troubleshooting tips
6. **Update Root README**: Add entry to main `README.md` if new capability or major script
7. **Update Category Guides**: Update relevant `docs/*.md` guides if applicable

### GitHub Wiki Link Structure
When documenting scripts, use proper link formats that work with GitHub's wiki workflow (files in `docs/wiki/` are synced to the repo's wiki):

**Wiki Base URL:** `https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/`

Wiki page links use the filename (without `.md` extension) appended to the base URL.

**Link Types:**

1. **Wiki Page Links** (for wiki documentation pages):
   ```markdown
   [New-Office365Accounts](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/New-Office365Accounts)
   [Start Here](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Start-Here)
   [Get-ComprehensiveTeamsReport](https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/Get-ComprehensiveTeamsReport)
   ```

2. **Links to Repository Files** (scripts, templates, format guides):
   ```markdown
   [Script Name](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Path/To/Script.ps1)
   [CSV Template](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Office365/templates/ContactList_Template.csv)
   [Format Guide](https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/scripts/Office365/.prep/ContactList_Format.md)
   ```

3. **External Documentation Links**:
   ```markdown
   [Microsoft Graph Contacts API](https://docs.microsoft.com/graph/api/resources/contact)
   ```

**Do NOT use:**
- ❌ `[[PageName]]` wiki-style syntax (use full URLs instead)
- ❌ Relative paths like `../../templates/file.csv` (breaks in wiki)
- ❌ `file://` or `vscode://` URI schemes
- ❌ Path-only links like `../../../scripts/file.ps1` (not accessible from wiki)
- ❌ `.md` extension in wiki URLs (GitHub wiki strips it automatically)

**Best Practice:**
- Use `https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/PageName` for all wiki page links
- Use `https://github.com/Managed-Solution-LLC/PowerShellEverything/blob/main/...` for repository file links
- Wiki page name = filename without `.md` extension (e.g., `Start-Here.md` → `wiki/Start-Here`)
- Include a note like "(wiki documentation coming soon)" for related scripts without wiki pages yet

### Documentation Validation Checklist
Before considering script documentation complete:
- [ ] Comment-based help includes all sections (SYNOPSIS, DESCRIPTION, PARAMETERS, EXAMPLES, NOTES, LINK)
- [ ] Real dates used throughout (no placeholders)
- [ ] All examples use generic organization names
- [ ] Wiki documentation created in correct location (`docs/wiki/<CategoryPath>/<ScriptName>.md`)
- [ ] **All file links use full GitHub URLs** (https://github.com/...), not relative paths
- [ ] **Wiki links use full URL format** (`https://github.com/Managed-Solution-LLC/PowerShellEverything/wiki/PageName`) without `.md` extension
- [ ] Folder-level README.md updated or created in script's directory
- [ ] Folder README links to wiki articles for all scripts
- [ ] Prerequisites clearly documented with versions
- [ ] Output formats and file naming explained
- [ ] Common troubleshooting scenarios included
- [ ] Related scripts cross-referenced
- [ ] Root README.md updated if new capability or featured script

## Current Development Focus
Based on folder structure and recent changes:
- Assessment scripts for Teams and Lync environments
- Graph API integration for modern workloads
- Security assessment and PIM conversion tools
- Data processing for Windows 11 readiness and similar analyses
