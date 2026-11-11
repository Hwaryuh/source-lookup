# Shared helpers for the source-lookup scripts. Dot-source this file.
# Keep this file ASCII-only and compatible with Windows PowerShell 5.1.

function Get-SourceLookupHome {
    if ($env:SOURCE_LOOKUP_HOME) { return $env:SOURCE_LOOKUP_HOME }
    if ($env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA 'source-lookup') }
    if ($env:XDG_CACHE_HOME) { return (Join-Path $env:XDG_CACHE_HOME 'source-lookup') }
    return (Join-Path (Join-Path $HOME '.cache') 'source-lookup')
}

function Get-GradleUserHome {
    if ($env:GRADLE_USER_HOME) { return $env:GRADLE_USER_HOME }
    return (Join-Path $HOME '.gradle')
}

# Runs a native command in a directory and returns its exit code, stdout and stderr.
# Windows PowerShell 5.1 turns redirected stderr into errors under -ErrorAction Stop,
# and decodes native output with the OEM code page, so both are handled here.
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )
    $previousPreference = $ErrorActionPreference
    $previousEncoding = $null
    try { $previousEncoding = [Console]::OutputEncoding; [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $Directory
    try {
        $lines = & $FilePath @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
        $ErrorActionPreference = $previousPreference
        if ($previousEncoding) { try { [Console]::OutputEncoding = $previousEncoding } catch { } }
    }
    $out = New-Object System.Collections.Generic.List[string]
    $err = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -is [System.Management.Automation.ErrorRecord]) { $err.Add($line.ToString()) }
        else { $out.Add([string]$line) }
    }
    return [pscustomobject]@{
        ExitCode = $code
        Out      = ($out -join "`n")
        Err      = ($err -join "`n")
    }
}
