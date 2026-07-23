[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [string]$PayloadInventoryPath,
    [string]$ExpectedPackageSha256,
    [switch]$Historical,
    [switch]$KeepExtracted
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-RelativePath([string]$Path, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path) -or
        $Path -match '^[A-Za-z]:' -or @($Path.Replace('\', '/').Split('/') | Where-Object { $_ -eq '..' -or $_ -eq '' }).Count -gt 0) {
        throw "Unsafe $Label path: $Path"
    }
}

$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$ManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
if ($manifest.kind -ne 'bar-controller-release-manifest' -or $manifest.schemaVersion -ne 1) {
    throw 'Unsupported controller release manifest schema.'
}
if ($manifest.repository -ne 'UnderarmCape/underarmcape-bar-controller-support-attempt-01') {
    throw 'Unexpected controller release repository.'
}
if ($manifest.package.detachedIdentity -or [string]$manifest.package.sha256 -notmatch '^[a-fA-F0-9]{64}$') {
    throw 'Detached release sidecar must contain the outer package SHA-256.'
}
$packageHash = Get-Sha256 $PackagePath
if ($packageHash -ne ([string]$manifest.package.sha256).ToLowerInvariant()) {
    throw "Package SHA-256 mismatch; expected $($manifest.package.sha256), got $packageHash."
}
if ((Get-Item -LiteralPath $PackagePath).Length -ne [long]$manifest.package.byteLength) {
    throw 'Package byte length does not match the release manifest.'
}
if ($ExpectedPackageSha256 -and $packageHash -ne $ExpectedPackageSha256.ToLowerInvariant()) {
    throw "Package SHA-256 does not match the explicit publisher gate: $ExpectedPackageSha256"
}

$destinations = @{}
foreach ($component in @($manifest.components)) {
    if ([string]::IsNullOrWhiteSpace([string]$component.componentId)) { throw 'Component ID is empty.' }
    if ([string]$component.destinationRoot -notin @('bar-data', 'companion')) {
        throw "Unsafe destination root: $($component.destinationRoot)"
    }
    Assert-RelativePath ([string]$component.destinationPath) 'destination'
    $key = ([string]$component.destinationRoot + '/' + ([string]$component.destinationPath).Replace('\', '/')).ToLowerInvariant()
    if ($destinations.ContainsKey($key)) { throw "Duplicate destination: $key" }
    $destinations[$key] = $true
    if ([string]$component.installPolicy -eq 'remove') { continue }
    Assert-RelativePath ([string]$component.sourcePath) 'source'
    if ([string]$component.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or [long]$component.byteLength -lt 0) {
        throw "Invalid component identity: $($component.componentId)"
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$extractRoot = Join-Path ([IO.Path]::GetTempPath()) ('bar-controller-release-verify-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($extractRoot) | Out-Null
$rootPrefix = [IO.Path]::GetFullPath($extractRoot).TrimEnd('\') + '\'
$archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
try {
    if ($archive.Entries.Count -gt 10000) { throw 'Package contains too many entries.' }
    [long]$total = 0
    foreach ($entry in $archive.Entries) {
        $name = $entry.FullName.Replace('\', '/')
        if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or @($name.Split('/') | Where-Object { $_ -eq '..' }).Count -gt 0) {
            throw "Unsafe ZIP entry: $($entry.FullName)"
        }
        $destination = [IO.Path]::GetFullPath((Join-Path $extractRoot $name.Replace('/', '\')))
        if (-not $destination.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "ZIP entry escapes staging: $($entry.FullName)"
        }
        if ($name.EndsWith('/')) { [IO.Directory]::CreateDirectory($destination) | Out-Null; continue }
        $total += [long]$entry.Length
        if ($total -gt 2GB) { throw 'Package extraction exceeds 2 GiB.' }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
        $input = $entry.Open()
        try {
            $output = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $input.CopyTo($output) } finally { $output.Dispose() }
        } finally { $input.Dispose() }
    }
} finally { $archive.Dispose() }

try {
    foreach ($component in @($manifest.components)) {
        if ([string]$component.installPolicy -eq 'remove') { continue }
        $source = [IO.Path]::GetFullPath((Join-Path $extractRoot ([string]$component.sourcePath).Replace('/', '\')))
        if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Component escaped extraction root.' }
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            if ([bool]$component.optional) { continue }
            throw "Package component is missing: $($component.sourcePath)"
        }
        if ((Get-Item -LiteralPath $source).Length -ne [long]$component.byteLength -or
            (Get-Sha256 $source) -ne ([string]$component.sha256).ToLowerInvariant()) {
            throw "Package component failed SHA-256/length validation: $($component.componentId)"
        }
    }

    if (-not $Historical) {
        $embeddedPath = Join-Path $extractRoot 'controller-release-manifest.json'
        if (-not (Test-Path -LiteralPath $embeddedPath -PathType Leaf)) { throw 'Embedded release manifest is missing.' }
        $embedded = Get-Content -Raw -Encoding UTF8 -LiteralPath $embeddedPath | ConvertFrom-Json
        if (-not [bool]$embedded.package.detachedIdentity -or [string]$embedded.package.sha256 -ne ('0' * 64) -or
            [long]$embedded.package.byteLength -ne 0) {
            throw 'Embedded manifest does not use the detached outer-package identity sentinel.'
        }
        if (@($embedded.components).Count -ne @($manifest.components).Count) {
            throw 'Embedded and detached manifests have different component counts.'
        }
    }

    if ($PayloadInventoryPath) {
        $PayloadInventoryPath = (Resolve-Path -LiteralPath $PayloadInventoryPath).Path
        $inventory = @(Get-Content -Raw -Encoding UTF8 -LiteralPath $PayloadInventoryPath | ConvertFrom-Json)
        foreach ($record in $inventory) {
            Assert-RelativePath ([string]$record.path) 'inventory'
            $target = Join-Path $extractRoot ([string]$record.path).Replace('/', '\')
            if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or
                (Get-Item -LiteralPath $target).Length -ne [long]$record.size -or
                (Get-Sha256 $target) -ne ([string]$record.sha256).ToLowerInvariant()) {
                throw "Payload inventory mismatch: $($record.path)"
            }
        }
        Write-Output "PAYLOAD_HASHES_VERIFIED=$($inventory.Count)"
    }
    Write-Output "RELEASE_MANIFEST_SCHEMA=$($manifest.schemaVersion)"
    Write-Output "RELEASE_COMPONENTS_VERIFIED=$(@($manifest.components).Count)"
    Write-Output "PACKAGE_SHA256=$packageHash"
    Write-Output "PACKAGE_BYTES=$((Get-Item -LiteralPath $PackagePath).Length)"
    Write-Output "EXTRACTED_ROOT=$extractRoot"
} finally {
    if (-not $KeepExtracted -and [IO.Directory]::Exists($extractRoot)) {
        [IO.Directory]::Delete($extractRoot, $true)
    }
}
