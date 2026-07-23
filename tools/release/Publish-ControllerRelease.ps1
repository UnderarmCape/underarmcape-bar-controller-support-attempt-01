[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Commit,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$DisplayVersion,
    [Parameter(Mandatory = $true)][string]$Tag,
    [Parameter(Mandatory = $true)][string]$Slug,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Channel,
    [Parameter(Mandatory = $true)][string]$ReleaseNotesPath,
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$PayloadInventoryPath,
    [Parameter(Mandatory = $true)][string]$ExpectedPackageSha256,
    [string]$ValidationStampPath,
    [switch]$Latest,
    [switch]$Prerelease,
    [switch]$Draft,
    [switch]$Rebuild,
    [switch]$Historical,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Repository = 'UnderarmCape/underarmcape-bar-controller-support-attempt-01'
$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Get-Sha256([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }

foreach ($pathName in @('PackagePath','ManifestPath','PayloadInventoryPath','ReleaseNotesPath')) {
    $value = Get-Variable -Name $pathName -ValueOnly
    if (-not (Test-Path -LiteralPath $value -PathType Leaf)) { throw "$pathName is missing: $value" }
    Set-Variable -Name $pathName -Value (Resolve-Path -LiteralPath $value).Path
}
if ($Commit -notmatch '^[a-fA-F0-9]{40}$' -or (& git -C $RepositoryRoot cat-file -t $Commit 2>$null) -ne 'commit') {
    throw "Release commit is unavailable: $Commit"
}
if ([string]::IsNullOrWhiteSpace($Tag) -or [string]::IsNullOrWhiteSpace($Slug) -or [string]::IsNullOrWhiteSpace($Channel)) {
    throw 'Release tag, slug, and channel are required.'
}
if (-not $DryRun -and @(& git -C $RepositoryRoot status --porcelain).Count -ne 0) {
    throw 'Publisher requires a clean worktree.'
}
if (-not $Historical) {
    if ([string]::IsNullOrWhiteSpace($ValidationStampPath) -or -not (Test-Path -LiteralPath $ValidationStampPath -PathType Leaf)) {
        throw 'Current publication requires a validation stamp.'
    }
    $stamp = Get-Content -Raw -Encoding UTF8 -LiteralPath $ValidationStampPath | ConvertFrom-Json
    if ($stamp.kind -ne 'bar-controller-release-validation' -or $stamp.commitSha -ne $Commit -or -not [bool]$stamp.passed) {
        throw 'Validation stamp does not authorize this commit.'
    }
}

$actualPackageHash = Get-Sha256 $PackagePath
if ($actualPackageHash -ne $ExpectedPackageSha256.ToLowerInvariant()) { throw 'Publisher package SHA-256 gate failed.' }
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
if ($manifest.releaseTag -ne $Tag -or $manifest.commitSha -ne $Commit -or
    $manifest.semanticVersion -ne $Version -or $manifest.displayVersion -ne $DisplayVersion -or
    $manifest.package.sha256 -ne $actualPackageHash) {
    throw 'Publisher metadata does not match the detached release manifest.'
}
& (Join-Path $PSScriptRoot 'Test-ControllerRelease.ps1') -PackagePath $PackagePath -ManifestPath $ManifestPath `
    -PayloadInventoryPath $PayloadInventoryPath -ExpectedPackageSha256 $actualPackageHash -Historical:$Historical
if ($LASTEXITCODE -ne 0) { throw 'Release-package validation gate failed.' }

& gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication gate failed.' }

$localMatches = @(& git -C $RepositoryRoot tag --list $Tag)
$localTag = if ($localMatches.Count -eq 1) { ([string](& git -C $RepositoryRoot rev-parse ('refs/tags/' + $Tag))).Trim() } else { '' }
$remoteRows = @(& git -C $RepositoryRoot ls-remote --tags origin ('refs/tags/' + $Tag) ('refs/tags/' + $Tag + '^{}'))
$tagCommit = ''
if ($localTag) { $tagCommit = (& git -C $RepositoryRoot rev-list -n 1 $Tag).Trim() }
if ($remoteRows.Count -gt 0) {
    $peeled = @($remoteRows | Where-Object { $_ -match '\^\{\}$' })
    $remoteCommit = if ($peeled.Count) { ($peeled[0] -split '\s+')[0] } else { ($remoteRows[0] -split '\s+')[0] }
    if (-not $tagCommit) { $tagCommit = $remoteCommit }
    if ($remoteCommit -ne $Commit) { throw "Remote tag $Tag points at $remoteCommit, not $Commit." }
}
if ($tagCommit -and $tagCommit -ne $Commit) { throw "Tag $Tag points at $tagCommit, not $Commit." }

$releaseExists = $false
$existing = $null
$savedErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$releaseProbe = @(& gh release view $Tag --repo $Repository --json tagName,name,isDraft,isPrerelease,assets 2>$null)
$releaseProbeExit = $LASTEXITCODE
$ErrorActionPreference = $savedErrorAction
if ($releaseProbeExit -eq 0) {
    $releaseExists = $true
    $existing = ($releaseProbe -join [Environment]::NewLine) | ConvertFrom-Json
    if ($existing.tagName -ne $Tag) { throw 'Existing release identity conflict.' }
    if ([bool]$existing.isDraft -ne [bool]$Draft -or [bool]$existing.isPrerelease -ne [bool]$Prerelease) {
        throw 'Existing release type conflicts with requested publication.'
    }
}

$packageSidecar = $PackagePath + '.sha256'
if (-not (Test-Path -LiteralPath $packageSidecar -PathType Leaf)) {
    $packageSidecar = Join-Path ([IO.Path]::GetDirectoryName($ManifestPath)) ([IO.Path]::GetFileName($PackagePath) + '.sha256')
}
$manifestSidecar = $ManifestPath + '.sha256'
foreach ($path in @($packageSidecar, $manifestSidecar)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required release sidecar missing: $path" }
}
$assets = @($PackagePath, $packageSidecar, $ManifestPath, $manifestSidecar, $PayloadInventoryPath, $ReleaseNotesPath)

if ($DryRun) {
    Write-Output "DRY_RUN=true"
    Write-Output "TAG=$Tag"
    Write-Output "COMMIT=$Commit"
    Write-Output "PACKAGE_SHA256=$actualPackageHash"
    Write-Output "RELEASE_EXISTS=$releaseExists"
    Write-Output "ASSETS=$($assets.Count)"
    return
}

if (-not $tagCommit) {
    & git -C $RepositoryRoot tag -a $Tag $Commit -m $Title
    if ($LASTEXITCODE -ne 0) { throw 'Annotated tag creation failed.' }
    & git -C $RepositoryRoot push origin ('refs/tags/' + $Tag)
    if ($LASTEXITCODE -ne 0) { throw 'Annotated tag push failed.' }
}

if (-not $releaseExists) {
    $arguments = @('release','create',$Tag,'--repo',$Repository,'--verify-tag','--title',$Title,'--notes-file',$ReleaseNotesPath)
    if ($Prerelease) { $arguments += '--prerelease' }
    if ($Draft) { $arguments += '--draft' }
    if ($Latest) { $arguments += '--latest' }
    $arguments += $assets
    & gh @arguments
    if ($LASTEXITCODE -ne 0) { throw 'GitHub release creation failed.' }
} else {
    foreach ($assetPath in $assets) {
        $assetName = [IO.Path]::GetFileName($assetPath)
        $remoteAsset = @($existing.assets | Where-Object { $_.name -eq $assetName })
        if ($remoteAsset.Count -eq 0) {
            & gh release upload $Tag $assetPath --repo $Repository
            if ($LASTEXITCODE -ne 0) { throw "Missing sidecar upload failed: $assetName" }
        } else {
            $remoteDigest = ([string]$remoteAsset[0].digest).Replace('sha256:', '').ToLowerInvariant()
            if ($remoteDigest -and $remoteDigest -ne (Get-Sha256 $assetPath)) {
                throw "Existing release asset conflicts with local SHA-256: $assetName"
            }
        }
    }
    if ($Latest) {
        & gh release edit $Tag --repo $Repository --latest
        if ($LASTEXITCODE -ne 0) { throw 'Could not mark the current release Latest.' }
    }
}

$verified = gh release view $Tag --repo $Repository --json tagName,name,isDraft,isPrerelease,assets,url | ConvertFrom-Json
foreach ($assetPath in $assets) {
    $name = [IO.Path]::GetFileName($assetPath)
    $remoteAsset = @($verified.assets | Where-Object { $_.name -eq $name })
    if ($remoteAsset.Count -ne 1) { throw "Published asset missing or duplicated: $name" }
    $digest = ([string]$remoteAsset[0].digest).Replace('sha256:', '').ToLowerInvariant()
    if ($digest -and $digest -ne (Get-Sha256 $assetPath)) { throw "Published asset digest mismatch: $name" }
}
Write-Output "PUBLISHED_TAG=$Tag"
Write-Output "PUBLISHED_URL=$($verified.url)"
Write-Output "PUBLISHED_PACKAGE_SHA256=$actualPackageHash"
