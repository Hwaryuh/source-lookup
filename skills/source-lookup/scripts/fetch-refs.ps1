<#
.SYNOPSIS
Fetches reference data that package managers do not download, as listed in refs.json.

.DESCRIPTION
Each reference is stored in <cache>/refs/<name>@<ref>/ with a .source-lookup.json file that
records the repository, ref, commit, fetch time and version. Git references are shallow,
sparse clones. Raw references download single files at a pinned commit.
The cache is $env:SOURCE_LOOKUP_HOME, or a per-user cache folder when it is not set.

.EXAMPLE
fetch-refs.ps1 -List
fetch-refs.ps1 -Name roblox-api-dump
fetch-refs.ps1 -Name swift-foundation -Ref swift-6.1-RELEASE
#>
param(
    [string]$Name,
    [string]$Ref,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$refsFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'refs.json'
$entries = @((Get-Content -LiteralPath $refsFile -Raw -Encoding UTF8 | ConvertFrom-Json).refs)
$root = Join-Path (Get-SourceLookupHome) 'refs'
$metaName = '.source-lookup.json'

function Read-Meta {
    param([string]$Dir)
    $path = Join-Path $Dir $metaName
    if (Test-Path -LiteralPath $path) { return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json) }
    return $null
}

function Stop-Usage {
    param([string]$Message)
    Write-Output "error: $Message"
    exit 1
}

function Invoke-Git {
    param([string]$Directory, [string[]]$Arguments)
    $result = Invoke-Native -Directory $Directory -FilePath 'git' -Arguments $Arguments
    if ($result.ExitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $($result.Err)" }
    return $result.Out
}

function Resolve-RemoteCommit {
    param([string]$Url, [string]$RefName)
    $lines = (Invoke-Git -Directory $root -Arguments @('ls-remote', $Url, $RefName, "$RefName^{}")) -split "`n"
    foreach ($suffix in @("refs/heads/$RefName", "refs/tags/$RefName^{}", "refs/tags/$RefName")) {
        foreach ($line in $lines) {
            $fields = $line -split "`t"
            if ($fields.Count -eq 2 -and $fields[1] -eq $suffix) { return $fields[0] }
        }
    }
    throw "ref $RefName not found in $Url"
}

if ($List) {
    foreach ($entry in $entries) {
        $refText = if ($entry.ref) { $entry.ref } else { "(needs -Ref: $($entry.refHint))" }
        Write-Output "$($entry.name)  [$($entry.kind), $($entry.repo) $refText]"
        Write-Output "  $($entry.covers)"
        if (Test-Path -LiteralPath $root) {
            foreach ($dir in Get-ChildItem -LiteralPath $root -Directory -Filter "$($entry.name)@*") {
                $meta = Read-Meta $dir.FullName
                if ($meta) {
                    $versionText = if ($meta.version) { ", version $($meta.version)" } else { '' }
                    Write-Output "  cached: $($dir.FullName) (commit $($meta.commit.Substring(0, 12)), fetched $($meta.fetchedAt)$versionText)"
                }
            }
        }
    }
    exit 0
}

if (-not $Name) { Stop-Usage 'pass -Name <ref name> or -List' }
$entry = $entries | Where-Object { $_.name -eq $Name } | Select-Object -First 1
if (-not $entry) { Stop-Usage "unknown reference $Name; run with -List" }
$refName = if ($Ref) { $Ref } else { $entry.ref }
if (-not $refName) { Stop-Usage "$Name needs -Ref: $($entry.refHint)" }

New-Item -ItemType Directory -Force -Path $root | Out-Null
$dir = Join-Path $root ('{0}@{1}' -f $entry.name, ($refName -replace '[\\/:*?"<>|]', '-'))
$url = "https://github.com/$($entry.repo).git"
$before = Read-Meta $dir

if ($entry.kind -eq 'git') {
    if (Test-Path -LiteralPath (Join-Path $dir '.git')) {
        $oldCommit = (Invoke-Git -Directory $dir -Arguments @('rev-parse', 'HEAD')).Trim()
        try {
            Invoke-Git -Directory $dir -Arguments @('config', 'core.longpaths', 'true') | Out-Null
            Invoke-Git -Directory $dir -Arguments @('fetch', '-q', '--depth', '1', '--filter=blob:none', 'origin', $refName) | Out-Null
            Invoke-Git -Directory $dir -Arguments @('checkout', '-q', '--detach', 'FETCH_HEAD') | Out-Null
        } catch {
            $message = $_.Exception.Message
            try {
                Invoke-Git -Directory $dir -Arguments @('checkout', '-q', '-f', '--detach', $oldCommit) | Out-Null
                Stop-Usage "update failed, kept the previous checkout $($oldCommit.Substring(0, 12)): $message"
            } catch {
                Remove-Item -LiteralPath $dir -Recurse -Force
                Stop-Usage "update failed and the previous checkout could not be restored, so the cache entry was removed: $message"
            }
        }
    } else {
        # core.longpaths: some repositories have paths longer than the Windows MAX_PATH limit.
        $cloneArgs = @('clone', '-q', '-c', 'core.longpaths=true', '--depth', '1', '--filter=blob:none', '--branch', $refName)
        if ($entry.sparse) { $cloneArgs += '--sparse' }
        try {
            Invoke-Git -Directory $root -Arguments ($cloneArgs + @($url, $dir)) | Out-Null
            if ($entry.sparse) {
                Invoke-Git -Directory $dir -Arguments (@('sparse-checkout', 'set') + @($entry.sparse)) | Out-Null
            }
        } catch {
            # Do not leave a half-checked-out clone that a later run would treat as complete.
            if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
            Stop-Usage "fetch failed, nothing was kept: $($_.Exception.Message)"
        }
    }
    $commit = (Invoke-Git -Directory $dir -Arguments @('rev-parse', 'HEAD')).Trim()
} elseif ($entry.kind -eq 'raw') {
    $commit = Resolve-RemoteCommit -Url $url -RefName $refName
    $isNew = -not (Test-Path -LiteralPath $dir)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    # Download every file first, then replace them together, so a failure never mixes two commits.
    $partials = @()
    try {
        foreach ($file in $entry.files) {
            $partial = (Join-Path $dir $file) + '.part'
            $partials += $partial
            Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$($entry.repo)/$commit/$file" -OutFile $partial
        }
    } catch {
        foreach ($partial in $partials) { if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force } }
        if ($isNew) { Remove-Item -LiteralPath $dir -Recurse -Force }
        Stop-Usage "download failed, the cache was left as it was: $($_.Exception.Message)"
    }
    foreach ($partial in $partials) {
        Move-Item -LiteralPath $partial -Destination ($partial.Substring(0, $partial.Length - 5)) -Force
    }
} else {
    throw "unknown kind $($entry.kind) for $Name"
}

$versionText = $null
if ($entry.versionFile) {
    $versionPath = Join-Path $dir $entry.versionFile
    if (Test-Path -LiteralPath $versionPath) { $versionText = (@(Get-Content -LiteralPath $versionPath | Where-Object { $_.Trim() }) | ForEach-Object { $_.Trim() }) -join ' ' }
}
$meta = [ordered]@{
    name      = $entry.name
    repo      = $entry.repo
    ref       = $refName
    commit    = $commit
    fetchedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    version   = $versionText
    covers    = $entry.covers
}
$meta | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dir $metaName) -Encoding UTF8

if ($before -and $before.commit -eq $commit) { $change = 'unchanged' }
elseif ($before) { $change = "updated $($before.commit.Substring(0, 12)) -> $($commit.Substring(0, 12))" }
else { $change = 'new' }
Write-Output "$($entry.name)@$refName $change"
Write-Output "  path: $dir"
Write-Output "  commit: $commit"
if ($versionText) { Write-Output "  version: $versionText" }
