<#
.SYNOPSIS
Finds an installed decompiler. Optionally downloads Vineflower into the cache.

.DESCRIPTION
Vineflower: reuses the newest release jar from the source-lookup cache or the Gradle cache.
With -Fetch, downloads the latest release from Maven Central and checks its SHA-1.
ilspycmd: reports the installed command. It never installs it, because that changes the
user's global .NET tools.

.EXAMPLE
decompiler.ps1 -Tool vineflower
decompiler.ps1 -Tool vineflower -Fetch
decompiler.ps1 -Tool ilspycmd
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet('vineflower', 'ilspycmd')][string]$Tool,
    [switch]$Fetch
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$toolsDir = Join-Path (Get-SourceLookupHome) 'tools'

function Get-ReleaseJars {
    $jars = @()
    if (Test-Path -LiteralPath $toolsDir) {
        $jars += Get-ChildItem -LiteralPath $toolsDir -File -Filter 'vineflower-*.jar'
    }
    $gradleDir = Join-Path (Get-GradleUserHome) 'caches/modules-2/files-2.1/org.vineflower/vineflower'
    if (Test-Path -LiteralPath $gradleDir) {
        $jars += Get-ChildItem -LiteralPath $gradleDir -Recurse -File -Filter 'vineflower-*.jar'
    }
    $releases = @()
    foreach ($jar in $jars) {
        if ($jar.Name -match '^vineflower-(\d+\.\d+\.\d+)\.jar$') {
            $releases += [pscustomobject]@{ Version = [version]$Matches[1]; Path = $jar.FullName }
        }
    }
    return @($releases | Sort-Object Version -Descending)
}

function Save-Vineflower {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $base = 'https://repo1.maven.org/maven2/org/vineflower/vineflower'
    $metadata = [xml](Invoke-WebRequest -UseBasicParsing -Uri "$base/maven-metadata.xml").Content
    $release = $metadata.metadata.versioning.release
    if (-not $release) { throw 'Maven Central metadata has no release version for Vineflower' }
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    $target = Join-Path $toolsDir "vineflower-$release.jar"
    $partial = "$target.part"
    Invoke-WebRequest -UseBasicParsing -Uri "$base/$release/vineflower-$release.jar" -OutFile $partial
    $expected = ((Invoke-WebRequest -UseBasicParsing -Uri "$base/$release/vineflower-$release.jar.sha1").Content -split '\s+')[0].Trim().ToLowerInvariant()
    $actual = (Get-FileHash -LiteralPath $partial -Algorithm SHA1).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        Remove-Item -LiteralPath $partial -Force
        throw "SHA-1 mismatch for vineflower-$release.jar"
    }
    Move-Item -LiteralPath $partial -Destination $target -Force
    return [pscustomobject]@{ Version = [version]$release; Path = $target }
}

if ($Tool -eq 'vineflower') {
    $best = Get-ReleaseJars | Select-Object -First 1
    if (-not $best -and $Fetch) { $best = Save-Vineflower }
    if (-not $best) {
        Write-Output "vineflower: not found in $toolsDir or the Gradle cache."
        Write-Output "  Ask the user, then run this script with -Fetch to download it from Maven Central into $toolsDir."
        exit 1
    }
    Write-Output "vineflower: $($best.Version)"
    Write-Output "  jar: $($best.Path)"
    Write-Output "  run: java -jar `"$($best.Path)`" <class or jar> <output dir>"
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) { Write-Output '  note: java is not on PATH' }
    exit 0
}

$command = Get-Command ilspycmd -ErrorAction SilentlyContinue
if (-not $command) {
    $candidate = Join-Path $HOME '.dotnet/tools/ilspycmd'
    foreach ($path in @("$candidate.exe", $candidate)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { $command = Get-Item -LiteralPath $path; break }
    }
}
if (-not $command) {
    Write-Output 'ilspycmd: not installed.'
    Write-Output '  Ask the user before installing it: dotnet tool install -g ilspycmd'
    if ($Fetch) { Write-Output '  -Fetch does not install global tools.' }
    exit 1
}
$path = if ($command.Source) { $command.Source } else { $command.FullName }
Write-Output "ilspycmd: $path"
exit 0
