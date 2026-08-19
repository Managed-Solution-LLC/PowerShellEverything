<#
.SYNOPSIS
    Reports whether the current session already has an active Microsoft Graph
    connection, and to which tenant/account/scopes.

.DESCRIPTION
    Dot-source this file to load the Test-MgGraphConnection function into your
    session (or add it to a module). A lightweight check to run at the top of
    any Graph-dependent script before making API calls, so you can branch on
    "already connected with what I need" vs. "need to connect" without
    triggering an interactive sign-in prompt just to find out.

.PARAMETER RequiredScopes
    Optional list of scopes to verify are present on the current connection
    (e.g. "User.Read.All","Group.ReadWrite.All"). If any are missing, the
    returned object's HasRequiredScopes property is $false and MissingScopes
    lists what's absent.

.EXAMPLE
    . .\Test-MgGraphConnection.ps1
    Test-MgGraphConnection

.EXAMPLE
    $status = Test-MgGraphConnection -RequiredScopes "User.Read.All","Directory.Read.All"
    if (-not $status.Connected -or -not $status.HasRequiredScopes) {
        Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All"
    }

.NOTES
    Requires the Microsoft.Graph.Authentication module (for Get-MgContext).
    Never triggers a sign-in itself - it only inspects the existing context.
#>

function Test-MgGraphConnection {
    [CmdletBinding()]
    param(
        [string[]] $RequiredScopes
    )

    if (-not (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{
            Connected         = $false
            Account           = $null
            TenantId          = $null
            Scopes            = @()
            HasRequiredScopes = $false
            MissingScopes     = $RequiredScopes
            Error             = "Microsoft.Graph.Authentication module not loaded (Get-MgContext not found)."
        }
    }

    $context = $null
    try {
        $context = Get-MgContext
    }
    catch {
        $context = $null
    }

    if (-not $context) {
        return [PSCustomObject]@{
            Connected         = $false
            Account           = $null
            TenantId          = $null
            Scopes            = @()
            HasRequiredScopes = $false
            MissingScopes     = $RequiredScopes
            Error             = "Not connected. Run Connect-MgGraph (or Connect-GraphWithScopes) first."
        }
    }

    $currentScopes = @($context.Scopes)
    $missing = @()
    $hasAll = $true

    if ($RequiredScopes) {
        $missing = $RequiredScopes | Where-Object { $_ -notin $currentScopes }
        $hasAll = ($missing.Count -eq 0)
    }

    return [PSCustomObject]@{
        Connected         = $true
        Account           = $context.Account
        TenantId          = $context.TenantId
        Scopes            = $currentScopes
        HasRequiredScopes = $hasAll
        MissingScopes     = $missing
        Error             = $null
    }
}
