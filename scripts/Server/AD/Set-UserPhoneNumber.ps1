<#
.SYNOPSIS
    Sets the AD telephoneNumber attribute for users matched by EmailAddress.

.DESCRIPTION
    Uses a hash table of Email -> PhoneNumber to look up each AD user by their
    EmailAddress attribute and set their telephoneNumber (OfficePhone) field.
    Users with no phone number entry are skipped. Results are written to a CSV report.

.PARAMETER DomainController
    Optional. Target a specific DC. Defaults to environment auto-discovery.

.PARAMETER WhatIf
    Simulates changes without writing to AD.

.PARAMETER ReportPath
    Directory to write the results CSV. Defaults to current directory.

.NOTES
    Author  : Managed Solution - Will Ford
    Date    : 2026-04-03
    Requires: ActiveDirectory module (RSAT)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$DomainController,

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "."
)

# ------------------------------------------------------------------------------
# HASH TABLE  —  Email (lowercase) -> Phone Number
# lcarrillo@sdl-az.com has no phone number in source data and is intentionally omitted.
# ------------------------------------------------------------------------------
$userPhoneMap = @{
    "acarrillo@sdl-az.com"  = "4809602061"
    "aperalta@sdl-az.com"   = "6024991674"
    "aahernandez@sdl-az.com"= "4809383726"
    "ahernandez@sdl-az.com" = "4809789802"
    "aparra@sdl-az.com"     = "4809529787"
    "alopez@sdl-az.com"     = "6025258477"
    "bmena@sdl-az.com"      = "4809100449"
    "cmaldonado@sdl-az.com" = "4809604834"
    "ccortiz@sdl-az.com"    = "4805994141"
    "dwinkler@sdl-az.com"   = "4805995851"
    "dthompson@sdl-az.com"  = "4809389856"
    "emiranda@sdl-az.com"   = "6023199218"
    "enavarro@sdl-az.com"   = "4809438664"
    "emacias@sdl-az.com"    = "4809572570"
    "enolea@sdl-az.com"     = "4809573979"
    "eolea@sdl-az.com"      = "4809578316"
    "eflores@sdl-az.com"    = "6023191548"
    "emyers@sdl-az.com"     = "4809575932"
    "emartinez@sdl-az.com"  = "4809602268"
    "faragon@sdl-az.com"    = "4803285105"
    "fbrown@sdl-az.com"     = "4809604457"
    "grendon@sdl-az.com"    = "4805990151"
    "jpasciolla@sdl-az.com" = "4809574993"
    "jcera@sdl-az.com"      = "4809571366"
    "jcmendoza@sdl-az.com"  = "4802020359"
    "jsolis@sdl-az.com"     = "4809389163"
    "jsalas@sdl-az.com"     = "6023971596"
    "jrivera@sdl-az.com"    = "6025010854"
    "jamezcua@sdl-az.com"   = "4809387769"
    "jcmartinez@sdl-az.com" = "6023293132"
    "jrodriguez@sdl-az.com" = "4809606143"
    "jsalvador@sdl-az.com"  = "6234998758"
    "lbowen@sdl-az.com"     = "4809438973"
    "lmendoza@sdl-az.com"   = "4809602635"
    "mlewis@sdl-az.com"     = "4809573129"
    "mgaspar@sdl-az.com"    = "4809388876"
    "mrodriguez@sdl-az.com" = "4809438962"
    "mramirez@sdl-az.com"   = "4809603714"
    "rsmith@sdl-az.com"     = "4809574202"
    "rgamez@sdl-az.com"     = "6023999363"
    "rdeaver@sdl-az.com"    = "4806866550"
    "revans@sdl-az.com"     = "4809382747"
    "scarrillo@sdl-az.com"  = "4809602622"
    "smontano@sdl-az.com"   = "4809572632"
    "shayes@sdl-az.com"     = "4809576587"
    "sstoll@sdl-az.com"     = "4805996523"
    "tsullivan@sdl-az.com"  = "4809382593"
    "welasco@sdl-az.com"    = "6233099359"
    "vacuna@sdl-az.com"     = "6023613606"
    "ymelchor@sdl-az.com"   = "4809388753"
    "zcleland@sdl-az.com"   = "4809574118"
}

# ------------------------------------------------------------------------------
# PRE-FLIGHT
# ------------------------------------------------------------------------------
if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
    Write-Host "ActiveDirectory module not found. Install RSAT or run from a domain-joined machine." -ForegroundColor Red
    exit 1
}
Import-Module ActiveDirectory -ErrorAction Stop

$adParams = @{}
if ($DomainController) { $adParams.Server = $DomainController }

if (-not (Test-Path $ReportPath -PathType Container)) {
    New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
}

$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $ReportPath "Set-UserPhoneNumber_$timestamp.csv"

# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Set-UserPhoneNumber   |   $($userPhoneMap.Count) users in map" -ForegroundColor Cyan
if ($WhatIfPreference) {
    Write-Host "  *** WHATIF MODE — no changes will be written ***" -ForegroundColor Yellow
}
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$results  = @()
$updated  = 0
$notFound = 0
$failed   = 0

foreach ($email in ($userPhoneMap.Keys | Sort-Object)) {
    $phone = $userPhoneMap[$email]

    # Look up AD user by EmailAddress attribute (case-insensitive LDAP filter)
    try {
        $user = Get-ADUser -Filter "EmailAddress -eq '$email'" `
                    -Properties EmailAddress, telephoneNumber, DisplayName `
                    @adParams -ErrorAction Stop |
                Select-Object -First 1
    }
    catch {
        Write-Host "  [ERROR]     $email — AD query failed: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Email         = $email
            Phone         = $phone
            DisplayName   = ""
            SamAccountName= ""
            PreviousPhone = ""
            Status        = "Error"
            Detail        = $_.Exception.Message
        }
        $failed++
        continue
    }

    if (-not $user) {
        Write-Host "  [NOT FOUND] $email" -ForegroundColor Yellow
        $results += [PSCustomObject]@{
            Email         = $email
            Phone         = $phone
            DisplayName   = ""
            SamAccountName= ""
            PreviousPhone = ""
            Status        = "NotFound"
            Detail        = "No AD user with EmailAddress = $email"
        }
        $notFound++
        continue
    }

    $previousPhone = $user.telephoneNumber

    try {
        if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Set telephoneNumber to $phone")) {
            Set-ADUser -Identity $user.SamAccountName `
                       -OfficePhone $phone `
                       @adParams -ErrorAction Stop
        }

        $status      = if ($WhatIfPreference) { "WhatIf" } else { "Updated" }
        $prevDisplay = if ($previousPhone) { $previousPhone } else { "(none)" }
        Write-Host ("  [{0}]  {1} ({2})  {3} -> {4}" -f `
            $status.PadRight(8),
            $user.DisplayName,
            $user.SamAccountName,
            $prevDisplay,
            $phone
        ) -ForegroundColor Green

        $results += [PSCustomObject]@{
            Email         = $email
            Phone         = $phone
            DisplayName   = $user.DisplayName
            SamAccountName= $user.SamAccountName
            PreviousPhone = $previousPhone
            Status        = $status
            Detail        = ""
        }
        $updated++
    }
    catch {
        Write-Host "  [ERROR]     $($user.SamAccountName) — Set-ADUser failed: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Email         = $email
            Phone         = $phone
            DisplayName   = $user.DisplayName
            SamAccountName= $user.SamAccountName
            PreviousPhone = $previousPhone
            Status        = "Error"
            Detail        = $_.Exception.Message
        }
        $failed++
    }
}

# ------------------------------------------------------------------------------
# EXPORT REPORT
# ------------------------------------------------------------------------------
$results | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SUMMARY"                                                    -ForegroundColor Cyan
Write-Host "  Updated   : $updated"                                       -ForegroundColor Green
Write-Host "  Not Found : $notFound"                                      -ForegroundColor Yellow
Write-Host "  Errors    : $failed" -ForegroundColor $(if ($failed) { "Red" } else { "Gray" })
Write-Host "  Report    : $reportFile"                                    -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
