<#
.SYNOPSIS
    Writes a standardized, timestamped log entry to the console and/or a log file.

.DESCRIPTION
    Dot-source this file to load the Write-Log function into your session
    (or add it to a module), then call it anywhere you would normally use
    Write-Host/Write-Output. Every entry is timestamped and tagged with a
    severity level (Info, Warning, Error, Success, Debug), color-coded on
    the console, and optionally appended to a log file with automatic
    rollover once the file passes a size threshold.

    Designed to be dropped into any script so that all of your day-to-day
    tooling produces consistent, greppable log output instead of ad-hoc
    Write-Host calls.

.PARAMETER Message
    The message text to log. Accepts pipeline input.

.PARAMETER Level
    Severity level for the entry. One of: Info, Warning, Error, Success, Debug.
    Default is Info.

.PARAMETER LogPath
    Optional path to a log file. If provided, the formatted entry is appended
    to this file (the parent folder is created automatically if it doesn't
    exist). If omitted, only console output is produced.

.PARAMETER MaxSizeMB
    When -LogPath is used, if the existing log file is at or above this size
    (in megabytes) the file is rolled over to "<name>.<timestamp>.log" before
    the new entry is written. Default is 10. Set to 0 to disable rollover.

.PARAMETER NoConsole
    Suppress console output; only write to -LogPath (useful for noisy loops
    where you still want a full file record).

.PARAMETER PassThru
    Return the formatted log line as a string in addition to writing it out,
    so it can be captured or forwarded elsewhere.

.EXAMPLE
    . .\Write-Log.ps1
    Write-Log "Starting tenant export"

.EXAMPLE
    Write-Log -Message "License sync failed for $upn" -Level Error -LogPath C:\Logs\LicenseSync.log

.EXAMPLE
    "Step 1 complete", "Step 2 complete" | Write-Log -Level Success -LogPath .\run.log

.EXAMPLE
    1..5 | ForEach-Object {
        Write-Log "Processing item $_" -LogPath .\batch.log -NoConsole
    }

.NOTES
    Colors used: Info = Gray, Warning = Yellow, Error = Red, Success = Green, Debug = DarkCyan.
#>

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]] $Message,

        [ValidateSet("Info", "Warning", "Error", "Success", "Debug")]
        [string] $Level = "Info",

        [string] $LogPath,

        [double] $MaxSizeMB = 10,

        [switch] $NoConsole,

        [switch] $PassThru
    )

    begin {
        $colorMap = @{
            Info    = "Gray"
            Warning = "Yellow"
            Error   = "Red"
            Success = "Green"
            Debug   = "DarkCyan"
        }

        if ($LogPath) {
            $logFolder = Split-Path -Path $LogPath -Parent
            if ($logFolder -and -not (Test-Path -LiteralPath $logFolder)) {
                New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
            }

            if ($MaxSizeMB -gt 0 -and (Test-Path -LiteralPath $LogPath)) {
                $existing = Get-Item -LiteralPath $LogPath
                if (($existing.Length / 1MB) -ge $MaxSizeMB) {
                    $rolloverName = "{0}.{1}{2}" -f `
                        [System.IO.Path]::GetFileNameWithoutExtension($existing.Name), `
                        (Get-Date -Format "yyyyMMddHHmmss"), `
                        $existing.Extension
                    $rolloverPath = Join-Path -Path $existing.DirectoryName -ChildPath $rolloverName
                    Rename-Item -LiteralPath $LogPath -NewName $rolloverName -ErrorAction SilentlyContinue
                    Write-Verbose "Rolled over log file to $rolloverPath"
                }
            }
        }
    }

    process {
        foreach ($line in $Message) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $formatted = "[$timestamp] [$Level] $line"

            if (-not $NoConsole) {
                Write-Host $formatted -ForegroundColor $colorMap[$Level]
            }

            if ($LogPath) {
                try {
                    Add-Content -LiteralPath $LogPath -Value $formatted -Encoding UTF8
                }
                catch {
                    Write-Warning "Write-Log: failed to write to '$LogPath' - $($_.Exception.Message)"
                }
            }

            if ($PassThru) {
                Write-Output $formatted
            }
        }
    }
}
