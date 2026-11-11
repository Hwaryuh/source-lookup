<#
.SYNOPSIS
Prints the resolved version and source folder of an external dependency.

.DESCRIPTION
Read-only. Wraps each ecosystem's own resolver. When the answer is not unique it prints
every candidate and exits with code 2 instead of guessing.
Exit codes: 0 found, 1 not found or error, 2 ambiguous, 3 ecosystem not supported.

.EXAMPLE
locate.ps1 -Package tokio
locate.ps1 -Lang java -Package org.jetbrains.kotlinx:kotlinx-coroutines-core
locate.ps1 -Lang node -Package react -ProjectDir packages/web
#>
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [ValidateSet('auto', 'java', 'rust', 'node', 'python', 'dotnet', 'luau', 'cpp', 'swift')]
    [string]$Lang = 'auto',
    [string]$ProjectDir = (Get-Location).Path,
    [string]$Version
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path

function Exit-With {
    param([string]$Status, [int]$Code, [string[]]$Notes = @())
    foreach ($note in $Notes) { if ($note) { Write-Output "note: $note" } }
    Write-Output "status: $Status"
    exit $Code
}

function Write-Match {
    param([string]$Name, [string]$MatchVersion, [string]$Source, [string[]]$Details = @())
    Write-Output "match: $Name $MatchVersion"
    Write-Output "  source: $Source"
    foreach ($detail in $Details) { if ($detail) { Write-Output "  $detail" } }
}

function Get-DetectedLanguages {
    $markers = [ordered]@{
        rust   = @('Cargo.toml')
        node   = @('package.json')
        python = @('pyproject.toml', 'requirements.txt', 'setup.py', 'setup.cfg', 'Pipfile')
        dotnet = @('*.csproj', '*.fsproj', '*.sln', '*.slnx')
        java   = @('build.gradle', 'build.gradle.kts', 'settings.gradle', 'settings.gradle.kts', 'pom.xml')
        swift  = @('Package.swift')
        luau   = @('default.project.json', 'wally.toml')
        cpp    = @('CMakeLists.txt', 'vcpkg.json', 'conanfile.txt', 'conanfile.py')
    }
    $dir = $ProjectDir
    while ($dir) {
        $found = @()
        foreach ($lang in $markers.Keys) {
            foreach ($pattern in $markers[$lang]) {
                if (Get-ChildItem -LiteralPath $dir -Filter $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1) {
                    $found += $lang
                    break
                }
            }
        }
        if ($found.Count -gt 0) { return , @($found) }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return , @()
}

function Find-Rust {
    # --locked keeps this read-only: cargo fails instead of writing Cargo.lock.
    $result = Invoke-Native -Directory $ProjectDir -FilePath 'cargo' -Arguments @('metadata', '--format-version', '1', '--locked')
    if ($result.ExitCode -ne 0 -or -not $result.Out) {
        Exit-With 'error' 1 @("cargo metadata --locked failed. Cargo.lock may be missing or out of date; ask the user before running cargo metadata without --locked. $($result.Err)")
    }
    $meta = $result.Out | ConvertFrom-Json
    $wanted = $Package -replace '_', '-'
    $crates = @($meta.packages | Where-Object { ($_.name -replace '_', '-') -eq $wanted })
    if ($Version) { $crates = @($crates | Where-Object { $_.version -eq $Version }) }
    if ($crates.Count -eq 0) { Exit-With 'not-found' 1 @("no package named $Package in the cargo metadata graph") }
    foreach ($pkg in $crates) {
        $kind = if (-not $pkg.source) { 'path' } elseif ($pkg.source -like 'git+*') { 'git' } else { 'registry' }
        Write-Match $pkg.name $pkg.version (Split-Path -Parent $pkg.manifest_path) @("kind: $kind")
    }
    if ($crates.Count -gt 1) {
        $first = $crates[0]
        Exit-With 'ambiguous' 2 @("several versions in the graph; see which crate uses which: cargo tree -i $($first.name)@$($first.version)")
    }
    Exit-With 'found' 0
}

function Find-Node {
    $script = Join-Path $PSScriptRoot 'resolve-node.js'
    $result = Invoke-Native -Directory $ProjectDir -FilePath 'node' -Arguments @($script, $Package)
    if (-not $result.Out) { Exit-With 'error' 1 @("node failed: $($result.Err)") }
    $info = $result.Out | ConvertFrom-Json
    if (-not $info.found) {
        Exit-With 'not-found' 1 @("$Package is not reachable from $ProjectDir by Node resolution. Run from the folder of the importing file, or check for Yarn Plug'n'Play.")
    }
    $typesText = if ($info.types) { $info.types } else { '(none in package.json)' }
    $details = @("types: $typesText")
    if ($info.typesPackage) { $details += "types package: $($info.typesPackage.name) $($info.typesPackage.version) at $($info.typesPackage.dir)" }
    Write-Match $info.name $info.version $info.dir $details
    if ($Version -and $info.version -ne $Version) {
        Exit-With 'found' 0 @("resolved version $($info.version) differs from the requested $Version")
    }
    Exit-With 'found' 0
}

function Get-PythonInterpreter {
    $candidates = @(
        '.venv\Scripts\python.exe', '.venv/bin/python',
        'venv\Scripts\python.exe', 'venv/bin/python',
        'env\Scripts\python.exe', 'env/bin/python'
    )
    foreach ($candidate in $candidates) {
        $path = Join-Path $ProjectDir $candidate
        if (Test-Path -LiteralPath $path -PathType Leaf) { return @{ Path = $path; Note = $null } }
    }
    foreach ($name in @('python', 'python3')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return @{ Path = $command.Source; Note = "no project virtual environment found; used $($command.Source). If the project uses uv, poetry or another interpreter, run resolve-python.py with that interpreter." }
        }
    }
    return $null
}

function Find-Python {
    $interpreter = Get-PythonInterpreter
    if (-not $interpreter) { Exit-With 'error' 1 @('no Python interpreter found') }
    $script = Join-Path $PSScriptRoot 'resolve-python.py'
    $result = Invoke-Native -Directory $ProjectDir -FilePath $interpreter.Path -Arguments @('-B', $script, $Package)
    if (-not $result.Out) { Exit-With 'error' 1 @("python failed: $($result.Err)") }
    $info = $result.Out | ConvertFrom-Json
    $notes = @($interpreter.Note)
    if (-not $info.found) {
        Exit-With 'not-found' 1 ($notes + @("$Package is not installed in $($info.python)"))
    }
    $dists = @($info.distributions | ForEach-Object { "$($_.name) $($_.version)" }) -join ', '
    foreach ($module in $info.modules) {
        $source = if ($module.searchLocations.Count -gt 0) { $module.searchLocations -join '; ' } else { $module.origin }
        Write-Match "module $($module.name)" "(distribution $dists)" $source @("python: $($info.python) ($($info.pythonVersion))")
    }
    Exit-With 'found' 0 $notes
}

function Find-Dotnet {
    $assets = @(Get-ChildItem -LiteralPath $ProjectDir -Recurse -Depth 6 -Filter 'project.assets.json' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -eq 'obj' })
    if ($assets.Count -eq 0) { Exit-With 'not-found' 1 @('no obj/project.assets.json found; run dotnet restore first') }
    $byVersion = [ordered]@{}
    foreach ($file in $assets) {
        $data = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $root = @($data.packageFolders.PSObject.Properties.Name)[0]
        foreach ($library in $data.libraries.PSObject.Properties) {
            $parts = $library.Name.Split('/')
            if ($parts[0] -ne $Package -or $library.Value.type -ne 'package') { continue }
            if ($Version -and $parts[1] -ne $Version) { continue }
            $key = $parts[1]
            if (-not $byVersion.Contains($key)) {
                $byVersion[$key] = @{ Id = $parts[0]; Dir = (Join-Path $root $library.Value.path); Projects = @() }
            }
            $byVersion[$key].Projects += $file.Directory.Parent.Name
        }
    }
    if ($byVersion.Count -eq 0) { Exit-With 'not-found' 1 @("$Package is not in any project.assets.json under $ProjectDir") }
    foreach ($key in $byVersion.Keys) {
        $entry = $byVersion[$key]
        $tfms = @()
        $lib = Join-Path $entry.Dir 'lib'
        if (Test-Path -LiteralPath $lib) { $tfms = @(Get-ChildItem -LiteralPath $lib -Directory | ForEach-Object Name) }
        Write-Match $entry.Id $key $entry.Dir @("lib: $($tfms -join ', ')", "used by: $(($entry.Projects | Sort-Object -Unique) -join ', ')")
    }
    if ($byVersion.Count -gt 1) { Exit-With 'ambiguous' 2 @('projects resolve different versions; use the one of the project you edit') }
    Exit-With 'found' 0
}

function Find-Java {
    $group = $null
    $artifact = $Package
    if ($Package.Contains(':')) {
        $parts = $Package.Split(':')
        $group = $parts[0]
        $artifact = $parts[1]
    }
    $base = Join-Path (Get-GradleUserHome) 'caches/modules-2/files-2.1'
    $artifactDirs = @()
    if (Test-Path -LiteralPath $base) {
        if ($group) {
            $dir = Join-Path (Join-Path $base $group) $artifact
            if (Test-Path -LiteralPath $dir) { $artifactDirs += Get-Item -LiteralPath $dir }
        } else {
            foreach ($groupDir in Get-ChildItem -LiteralPath $base -Directory) {
                $dir = Join-Path $groupDir.FullName $artifact
                if (Test-Path -LiteralPath $dir) { $artifactDirs += Get-Item -LiteralPath $dir }
            }
        }
    }
    $count = 0
    foreach ($artifactDir in $artifactDirs) {
        $groupName = $artifactDir.Parent.Name
        foreach ($versionDir in Get-ChildItem -LiteralPath $artifactDir.FullName -Directory) {
            if ($Version -and $versionDir.Name -ne $Version) { continue }
            $files = @(Get-ChildItem -LiteralPath $versionDir.FullName -Recurse -File -Filter '*.jar')
            $jar = $files | Where-Object { $_.Name -eq "$artifact-$($versionDir.Name).jar" } | Select-Object -First 1
            $sources = $files | Where-Object { $_.Name -eq "$artifact-$($versionDir.Name)-sources.jar" } | Select-Object -First 1
            $jarText = if ($jar) { $jar.FullName } else { '(none)' }
            $sourcesText = if ($sources) { $sources.FullName } else { '(none; see gradle-sources.init.gradle in references/java-kotlin.md)' }
            Write-Match "${groupName}:$artifact" $versionDir.Name $versionDir.FullName @("jar: $jarText", "sources: $sourcesText")
            $count++
        }
    }
    if ($group) {
        $m2 = Join-Path $HOME ('.m2/repository/' + ($group -replace '\.', '/') + "/$artifact")
        if (Test-Path -LiteralPath $m2) {
            foreach ($versionDir in Get-ChildItem -LiteralPath $m2 -Directory) {
                if ($Version -and $versionDir.Name -ne $Version) { continue }
                Write-Match "${group}:$artifact" $versionDir.Name $versionDir.FullName @('cache: maven')
                $count++
            }
        }
    }
    $notes = @('this lists cached versions only; confirm the resolved one with: gradlew -q dependencyInsight --dependency ' + $artifact + ' --configuration compileClasspath')
    if (-not $group) { $notes += 'pass -Package group:artifact to include the Maven cache and narrow the search' }
    if ($count -eq 0) { Exit-With 'not-found' 1 (@("no cached $Package") + $notes) }
    if ($count -gt 1) { Exit-With 'ambiguous' 2 $notes }
    Exit-With 'found' 0 $notes
}

if ($Lang -eq 'auto') {
    $detected = Get-DetectedLanguages
    if ($detected.Count -eq 0) { Exit-With 'error' 1 @("no project marker found in $ProjectDir or its parents; pass -Lang") }
    if ($detected.Count -gt 1) { Exit-With 'error' 1 @("several ecosystems found ($($detected -join ', ')); pass -Lang") }
    $Lang = $detected[0]
}
Write-Output "lang: $Lang"

switch ($Lang) {
    'rust'   { Find-Rust }
    'node'   { Find-Node }
    'python' { Find-Python }
    'dotnet' { Find-Dotnet }
    'java'   { Find-Java }
    default  { Exit-With 'unsupported' 3 @("locate.ps1 does not resolve $Lang. Follow references/$Lang.md.") }
}
