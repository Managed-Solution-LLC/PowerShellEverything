<#
.SYNOPSIS
    Connects to Microsoft Graph only if needed, ensuring the current session
    has (at least) the requested scopes.

.DESCRIPTION
    Dot-source this file to load the Connect-GraphWithScopes function into
    your session (or add it to a module). Wraps Connect-MgGraph so that
    scripts don't blindly call Connect-MgGraph (and force a re-auth prompt)
    every single run: it first checks for an existing connection via
    Get-MgContext, and only (re)connects if there is no connection, the
    connected tenant doesn't match -TenantId, or the current scopes don't
    cover everything in -Scopes.

.PARAMETER Scopes
    One or more Graph permission scopes required for the calling script,
    e.g. "User.Read.All","Group.ReadWrite.All".

.PARAMETER TenantId
    Optional tenant ID or verified domain to connect against. If the current
    connection is to a different tenant, this forces a reconnect.

.PARAMETER Force
    Always reconnect, even if the current connection already covers the
    requested scopes and tenant.

.PARAMETER NoWelcome
    Passed through to Connect-MgGraph to suppress its banner, if supported
    by the installed module version.

.EXAMPLE
    . .\Connect-GraphWithScopes.ps1
    Connect-GraphWithScopes -Scopes "User.Read.All","AuditLog.Read.All"

.EXAMPLE
    Connect-GraphWithScopes -Scopes "Group.ReadWrite.All" -TenantId contoso.onmicrosoft.com -Force

.NOTES
    Requires the Microsoft.Graph.Authentication module. Pairs well with
    Test-MgGraphConnection (in this repo) for a read-only status check, and
    Get-MgGraphAllPages for paging through subsequent API calls.
#>

function Connect-GraphWithScopes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Scopes,

        [string] $TenantId,

        [switch] $Force,

        [switch] $NoWelcome
    )

    if (-not (Get-Command -Name Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw "Connect-GraphWithScopes: Connect-MgGraph is not available. Install the Microsoft.Graph.Authentication module first (Install-Module Microsoft.Graph.Authentication)."
    }

    $context = $null
    try {
        $context = Get-MgContext
    }
    catch {
        $context = $null
    }

    $needsConnect = $Force -or (-not $context)

    if ($context -and -not $Force) {
        $currentScopes = @($context.Scopes)
        $missingScopes = $Scopes | Where-Object { $_ -notin $currentScopes }

        if ($missingScopes.Count -gt 0) {
            Write-Verbose "Connect-GraphWithScopes: missing scope(s): $($missingScopes -join ', ')"
            $needsConnect = $true
        }

        if ($TenantId -and $context.TenantId -ne $TenantId) {
            Write-Verbose "Connect-GraphWithScopes: connected tenant '$($context.TenantId)' does not match requested '$TenantId'."
            $needsConnect = $true
        }
    }

    if (-not $needsConnect) {
        Write-Verbose "Connect-GraphWithScopes: already connected as $($context.Account) with required scopes."
        return [PSCustomObject]@{
            Connected    = $true
            Reconnected  = $false
            Account      = $context.Account
            TenantId     = $context.TenantId
            Scopes       = @($context.Scopes)
        }
    }

    $connectParams = @{ Scopes = $Scopes }
    if ($TenantId) { $connectParams["TenantId"] = $TenantId }
    if ($NoWelcome -and (Get-Command Connect-MgGraph).Parameters.ContainsKey("NoWelcome")) {
        $connectParams["NoWelcome"] = $true
    }

    try {
        Connect-MgGraph @connectParams -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Connect-GraphWithScopes: Connect-MgGraph failed - $($_.Exception.Message)"
    }

    $newContext = Get-MgContext
    if (-not $newContext) {
        throw "Connect-GraphWithScopes: Connect-MgGraph completed but no context was established."
    }

    return [PSCustomObject]@{
        Connected   = $true
        Reconnected = $true
        Account     = $newContext.Account
        TenantId    = $newContext.TenantId
        Scopes      = @($newContext.Scopes)
    }
}
