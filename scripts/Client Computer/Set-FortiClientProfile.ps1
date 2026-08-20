

<#
.SYNOPSIS
    Imports a FortiClient VPN configuration profile onto a target machine.
.DESCRIPTION
    Downloads an encrypted FortiClient configuration file from a URL and imports it
    using FCConfig.exe. The script stops FortiClient processes and services before
    import, then restarts them afterward to ensure a clean configuration load.

    Designed for deployment via Intune, SCCM, or manual execution on endpoints.

    EXPORTING A CONFIGURATION (prerequisite):
    ------------------------------------------
    Before using this script, export the FortiClient config from a reference machine:

    Option 1 - GUI:
      1. Open FortiClient and go to Settings.
      2. Under System, click Backup.
      3. Select the file destination.
      4. Enter a password to save the file in an encrypted format.
      5. Click OK.

    Option 2 - CLI (run as Administrator):
      FCConfig.exe -m all -f "C:\Temp\vpnconfig.conf" -o export -i 1 -p "YourPassword"

    Then host the exported .conf file at an accessible URL (Azure Blob, file share, etc.)
    and provide that URL as the -ConfigUrl parameter.
.PARAMETER ConfigUrl
    URL where the encrypted FortiClient configuration file is hosted.
.PARAMETER ConfigPassword
    Password used to encrypt the configuration file during export.
.PARAMETER FCConfigPath
    Path to FCConfig.exe. Defaults to the standard install location.
.PARAMETER LogFile
    Path to the import log file. Defaults to the user's TEMP directory.
.EXAMPLE
    .\Set-FortiClientProfile.ps1 -ConfigUrl "https://storage.blob.core.windows.net/configs/vpnconfig.conf" -ConfigPassword "ExportPass123"
    Downloads and imports the FortiClient configuration from the specified URL.
.EXAMPLE
    .\Set-FortiClientProfile.ps1 -ConfigUrl "\\fileserver\share\vpnconfig.conf" -ConfigPassword "ExportPass123" -LogFile "C:\Logs\fc-import.log"
    Imports configuration with a custom log file path.
.NOTES
    Author: W. Ford
    Date: 2026-08-20
    Version: 2.0

    Requirements:
    - FortiClient installed with FCConfig.exe available
    - Administrator privileges (to stop/start services)
    - Network access to the ConfigUrl

    FCConfig Exit Codes:
    - 0: Success
    - 5: Invalid configuration file (wrong password or corrupt file)
.LINK
    https://docs.fortinet.com/document/forticlient/
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "URL where the encrypted FortiClient .conf file is hosted")]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigUrl,

    [Parameter(Mandatory = $true, HelpMessage = "Password used when exporting the configuration file")]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPassword,

    [Parameter(Mandatory = $false, HelpMessage = "Path to FCConfig.exe")]
    [string]$FCConfigPath = "C:\Program Files\Fortinet\FortiClient\FCConfig.exe",

    [Parameter(Mandatory = $false, HelpMessage = "Path to the log file")]
    [string]$LogFile = "$env:TEMP\FCConfig-Import.log"
)

$confFile = "$env:TEMP\vpnconfig.conf"

"$(Get-Date) - Starting FortiClient config import as $env:USERNAME" | Out-File $LogFile

if (-not (Test-Path $FCConfigPath)) {
    "FCConfig.exe not found at $FCConfigPath" | Tee-Object -FilePath $LogFile -Append
    exit 1
}

Invoke-WebRequest -Uri $ConfigUrl -OutFile $confFile -UseBasicParsing

if (-not (Test-Path $confFile)) {
    "Download failed" | Tee-Object -FilePath $LogFile -Append
    exit 1
}

icacls $confFile /grant "Authenticated Users:(R)" | Out-Null

# Stop FortiClient processes and services before importing
$fcProcesses = 'FortiClient', 'FortiClientConsole', 'FortiTray', 'FortiSSLVPNdaemon', 'FortiESNAC', 'fcappdb'
$fcProcesses | ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }

$fcServices = Get-Service -Name 'Forti*', 'fortishield' -ErrorAction SilentlyContinue
$fcServices | Stop-Service -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
$fcServices | Start-Service -ErrorAction SilentlyContinue

"Running FCConfig..." | Tee-Object -FilePath $LogFile -Append
$output = & $FCConfigPath -m all -f $confFile -o import -i 1 -p $ConfigPassword 2>&1
$exitCode = $LASTEXITCODE
"FCConfig exit code: $exitCode" | Tee-Object -FilePath $LogFile -Append
"FCConfig output: $output" | Tee-Object -FilePath $LogFile -Append

if ($exitCode -eq 0) {
    "Config imported successfully" | Tee-Object -FilePath $LogFile -Append
} elseif ($exitCode -eq 5) {
    "FCConfig failed with exit code 5: Invalid configuration file" | Tee-Object -FilePath $LogFile -Append
} else {
    "FCConfig failed with exit code $exitCode" | Tee-Object -FilePath $LogFile -Append
}

Remove-Item $confFile -Force -ErrorAction SilentlyContinue
