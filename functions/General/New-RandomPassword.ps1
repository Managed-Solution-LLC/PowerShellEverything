<#
.SYNOPSIS
    Generates one or more cryptographically random passwords meeting configurable
    complexity rules.

.DESCRIPTION
    Dot-source this file to load the New-RandomPassword function into your session
    (or add it to a module). Uses .NET's RandomNumberGenerator (cryptographically
    secure, not Get-Random) to build passwords of a given length, guarantees at
    least one character from each required character class, and shuffles the
    result so required characters aren't predictably placed at the start.

    Handy for account resets, new service accounts, temp passwords for offboarding/
    onboarding, or anywhere you need a quick, strong password without reaching for
    an external tool.

.PARAMETER Length
    Total password length. Default is 16. Must be large enough to fit one
    character from each included character class (validated at runtime).

.PARAMETER Count
    How many passwords to generate. Default is 1.

.PARAMETER ExcludeAmbiguous
    Exclude visually ambiguous characters (0/O, 1/l/I, etc.) to make passwords
    easier to read aloud or retype.

.PARAMETER NoSymbols
    Exclude special/symbol characters, for systems that don't accept them.

.PARAMETER AsSecureString
    Return System.Security.SecureString objects instead of plain strings.
    Ignored (plain strings returned) when -Count is greater than 1 and you pipe
    the result somewhere that expects text, so check your downstream use.

.EXAMPLE
    . .\New-RandomPassword.ps1
    New-RandomPassword

.EXAMPLE
    New-RandomPassword -Length 20 -Count 5 -ExcludeAmbiguous

.EXAMPLE
    $securePw = New-RandomPassword -AsSecureString
    New-MgUser -PasswordProfile @{ Password = (ConvertFrom-SecureString $securePw -AsPlainText) } ...

.NOTES
    Character classes used: uppercase A-Z, lowercase a-z, digits 0-9, and
    (unless -NoSymbols) symbols from !@#$%^&*()-_=+[]{}.
#>

function New-RandomPassword {
    [CmdletBinding()]
    param(
        [ValidateRange(4, 128)]
        [int] $Length = 16,

        [ValidateRange(1, 1000)]
        [int] $Count = 1,

        [switch] $ExcludeAmbiguous,

        [switch] $NoSymbols,

        [switch] $AsSecureString
    )

    begin {
        $ambiguous = "0O1lI|"

        $upper  = [char[]]"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        $lower  = [char[]]"abcdefghijklmnopqrstuvwxyz"
        $digits = [char[]]"0123456789"
        $symbols = [char[]]"!@#$%^&*()-_=+[]{}"

        if ($ExcludeAmbiguous) {
            $upper  = $upper  | Where-Object { $ambiguous -notcontains $_ }
            $lower  = $lower  | Where-Object { $ambiguous -notcontains $_ }
            $digits = $digits | Where-Object { $ambiguous -notcontains $_ }
        }

        $classes = [System.Collections.Generic.List[char[]]]::new()
        $classes.Add($upper)
        $classes.Add($lower)
        $classes.Add($digits)
        if (-not $NoSymbols) { $classes.Add($symbols) }

        if ($Length -lt $classes.Count) {
            throw "New-RandomPassword: -Length ($Length) must be at least $($classes.Count) to fit one character from each required class."
        }

        $allChars = $classes | ForEach-Object { $_ } | Select-Object -Unique

        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

        function Get-SecureRandomIndex {
            param([int] $Max)
            $bytes = [byte[]]::new(4)
            $rng.GetBytes($bytes)
            $value = [System.BitConverter]::ToUInt32($bytes, 0)
            return [int]($value % $Max)
        }

        function New-SinglePassword {
            $passwordChars = [System.Collections.Generic.List[char]]::new()

            # Guarantee at least one character from each required class
            foreach ($class in $classes) {
                $passwordChars.Add($class[(Get-SecureRandomIndex -Max $class.Count)])
            }

            # Fill the remaining length from the combined pool
            for ($i = $passwordChars.Count; $i -lt $Length; $i++) {
                $passwordChars.Add($allChars[(Get-SecureRandomIndex -Max $allChars.Count)])
            }

            # Fisher-Yates shuffle so required chars aren't always at the front
            for ($i = $passwordChars.Count - 1; $i -gt 0; $i--) {
                $j = Get-SecureRandomIndex -Max ($i + 1)
                $tmp = $passwordChars[$i]
                $passwordChars[$i] = $passwordChars[$j]
                $passwordChars[$j] = $tmp
            }

            -join $passwordChars
        }
    }

    process {
        try {
            for ($n = 0; $n -lt $Count; $n++) {
                $plain = New-SinglePassword

                if ($AsSecureString) {
                    ConvertTo-SecureString -String $plain -AsPlainText -Force
                }
                else {
                    Write-Output $plain
                }
            }
        }
        finally {
            if ($rng) { $rng.Dispose() }
        }
    }
}
