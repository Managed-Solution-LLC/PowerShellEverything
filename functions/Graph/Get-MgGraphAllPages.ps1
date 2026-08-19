<#
.SYNOPSIS
    Automatically pages through a Microsoft Graph API result set and returns
    every item across all pages.

.DESCRIPTION
    Dot-source this file to load the Get-MgGraphAllPages function into your
    session (or add it to a module). Microsoft Graph returns large result sets
    in pages of ~100-999 items with an "@odata.nextLink" pointing to the next
    page. This function calls Invoke-MgGraphRequest against the given URI and
    keeps following @odata.nextLink until every page has been retrieved,
    returning a single flat array of the "value" items - so you stop writing
    the same do/while pagination loop in every reporting script.

.PARAMETER Uri
    The Graph request URI to start from, e.g.
    "https://graph.microsoft.com/v1.0/users?$select=displayName,userPrincipalName".
    Can be relative ("/users") or absolute.

.PARAMETER Method
    HTTP method for the initial and subsequent requests. Default is GET.
    (Pagination is only meaningful for GET-style list responses.)

.PARAMETER Headers
    Optional extra headers hashtable to pass to Invoke-MgGraphRequest
    (e.g. @{ ConsistencyLevel = "eventual" } for advanced query support).

.PARAMETER MaxPages
    Safety cap on the number of pages to follow. Default is 1000 (effectively
    unbounded for normal tenant sizes, but prevents runaway loops on
    unexpected responses).

.EXAMPLE
    . .\Get-MgGraphAllPages.ps1
    Get-MgGraphAllPages -Uri "/users?`$select=displayName,userPrincipalName,accountEnabled"

.EXAMPLE
    Get-MgGraphAllPages -Uri "/groups?`$filter=startswith(displayName,'Sales')" |
        Select-Object displayName, id

.EXAMPLE
    Get-MgGraphAllPages -Uri "/auditLogs/signIns" -Headers @{ ConsistencyLevel = "eventual" }

.NOTES
    Requires an active Microsoft Graph connection (Connect-MgGraph) and the
    Microsoft.Graph.Authentication module for Invoke-MgGraphRequest. See also
    Connect-GraphWithScopes and Test-MgGraphConnection in this repo.
#>

function Get-MgGraphAllPages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Uri,

        [ValidateSet("GET")]
        [string] $Method = "GET",

        [hashtable] $Headers,

        [int] $MaxPages = 1000
    )

    if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw "Get-MgGraphAllPages: Invoke-MgGraphRequest is not available. Install/import the Microsoft.Graph.Authentication module and run Connect-MgGraph first."
    }

    $allItems = [System.Collections.Generic.List[object]]::new()
    $nextUri = $Uri
    $pageCount = 0

    do {
        $pageCount++
        if ($pageCount -gt $MaxPages) {
            Write-Warning "Get-MgGraphAllPages: reached -MaxPages ($MaxPages) limit; stopping early. Increase -MaxPages if more data is expected."
            break
        }

        $requestParams = @{
            Uri    = $nextUri
            Method = $Method
        }
        if ($Headers) { $requestParams["Headers"] = $Headers }

        try {
            $response = Invoke-MgGraphRequest @requestParams
        }
        catch {
            throw "Get-MgGraphAllPages: request to '$nextUri' failed - $($_.Exception.Message)"
        }

        if ($null -ne $response.value) {
            foreach ($item in $response.value) {
                $allItems.Add($item)
            }
        }
        elseif ($response) {
            # Single-object (non-collection) response; return it as-is
            $allItems.Add($response)
        }

        $nextUri = $response.'@odata.nextLink'
        Write-Verbose "Get-MgGraphAllPages: page $pageCount retrieved, $($allItems.Count) item(s) so far."

    } while ($nextUri)

    return $allItems
}
