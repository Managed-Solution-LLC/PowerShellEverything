<#
.SYNOPSIS
    Exports pipeline objects to a timestamped CSV, JSON, or Excel file, creating
    the output folder if needed.

.DESCRIPTION
    Dot-source this file to load the Export-ResultToFile function into your
    session (or add it to a module). Accepts any object(s) via the pipeline and
    writes them to disk with a consistent, timestamped filename, so ad-hoc
    reporting scripts don't each reinvent "build a filename, make sure the folder
    exists, export it" boilerplate.

    Excel export requires the community ImportExcel module (Install-Module
    ImportExcel); if it isn't available, -Format Excel falls back to CSV with a
    warning rather than failing outright.

.PARAMETER InputObject
    The object(s) to export. Accepts pipeline input.

.PARAMETER Path
    Folder to write the file into. Created automatically if it doesn't exist.
    Default is the current directory.

.PARAMETER Name
    Base file name (without extension or timestamp), e.g. "LicenseReport".
    Default is "Export".

.PARAMETER Format
    Output format: Csv, Json, or Excel. Default is Csv.

.PARAMETER NoTimestamp
    Skip appending a timestamp to the filename (will overwrite an existing
    file of the same name).

.PARAMETER PassThru
    Return a FileInfo object for the file that was written, so it can be
    piped onward (e.g. to Send-MailMessage as an attachment).

.EXAMPLE
    . .\Export-ResultToFile.ps1
    Get-Process | Export-ResultToFile -Path C:\Reports -Name ProcessSnapshot

.EXAMPLE
    $licenseSummary | Export-ResultToFile -Name LicenseSummary -Format Json -PassThru

.EXAMPLE
    Get-MgUser -All | Export-ResultToFile -Path .\Reports -Name AllUsers -Format Excel

.NOTES
    Resulting filename pattern: "<Name>_<yyyyMMdd_HHmmss>.<ext>" unless -NoTimestamp
    is used, in which case it is just "<Name>.<ext>".
#>

function Export-ResultToFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]] $InputObject,

        [string] $Path = ".",

        [string] $Name = "Export",

        [ValidateSet("Csv", "Json", "Excel")]
        [string] $Format = "Csv",

        [switch] $NoTimestamp,

        [switch] $PassThru
    )

    begin {
        $collected = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            $collected.Add($item)
        }
    }

    end {
        if ($collected.Count -eq 0) {
            Write-Warning "Export-ResultToFile: no input objects were received; nothing to export."
            return
        }

        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }

        $timestamp = if ($NoTimestamp) { "" } else { "_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss") }
        $effectiveFormat = $Format

        if ($Format -eq "Excel" -and -not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Warning "Export-ResultToFile: ImportExcel module not found (Install-Module ImportExcel). Falling back to CSV."
            $effectiveFormat = "Csv"
        }

        $extension = switch ($effectiveFormat) {
            "Csv"   { "csv" }
            "Json"  { "json" }
            "Excel" { "xlsx" }
        }

        $fileName = "{0}{1}.{2}" -f $Name, $timestamp, $extension
        $fullPath = Join-Path -Path $Path -ChildPath $fileName

        try {
            switch ($effectiveFormat) {
                "Csv" {
                    $collected | Export-Csv -Path $fullPath -NoTypeInformation -Encoding UTF8
                }
                "Json" {
                    $collected | ConvertTo-Json -Depth 10 | Set-Content -Path $fullPath -Encoding UTF8
                }
                "Excel" {
                    Import-Module ImportExcel -ErrorAction Stop
                    $collected | Export-Excel -Path $fullPath -AutoSize -FreezeTopRow -BoldTopRow
                }
            }
        }
        catch {
            Write-Error "Export-ResultToFile: failed to write '$fullPath' - $($_.Exception.Message)"
            return
        }

        Write-Verbose "Export-ResultToFile: wrote $($collected.Count) record(s) to $fullPath"

        if ($PassThru) {
            Get-Item -LiteralPath $fullPath
        }
    }
}
