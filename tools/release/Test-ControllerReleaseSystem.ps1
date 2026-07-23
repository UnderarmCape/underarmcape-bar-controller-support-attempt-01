[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$PayloadInventoryPath,
    [Parameter(Mandatory = $true)][string]$BackupRoot,
    [string]$RepositoryRoot,
    [string]$BarDataPath = (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason\data'),
    [string]$CompanionInstallPath = (Join-Path $env:LOCALAPPDATA 'Programs\BARControllerCompanion'),
    [string]$StampPath,
    [switch]$AllowUnknownBase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$luaRegressionBaseCommit = 'c5c07603e3d6560ad057e35a021d0f5ffc8b1643'
$repository = 'UnderarmCape/underarmcape-bar-controller-support-attempt-01'
$passed = 0

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Check([int]$Number, [string]$Label) {
    $script:passed++
    if ($script:passed -ne $Number) { throw "Check sequence mismatch at ${Number}: $Label" }
    Write-Output ('[check {0:D3}] {1}' -f $Number, $Label)
}
function Invoke-Checked([string]$File, [string[]]$Arguments) {
    $output = @(& $File @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $File $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)" }
    return $output
}
function Get-Sha256([string]$Path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$ManifestPath = (Resolve-Path -LiteralPath $ManifestPath).Path
$PayloadInventoryPath = (Resolve-Path -LiteralPath $PayloadInventoryPath).Path
$BackupRoot = (Resolve-Path -LiteralPath $BackupRoot).Path
$BarDataPath = (Resolve-Path -LiteralPath $BarDataPath).Path
$CompanionInstallPath = (Resolve-Path -LiteralPath $CompanionInstallPath).Path
if ([string]::IsNullOrWhiteSpace($StampPath)) {
    $StampPath = Join-Path ([IO.Path]::GetDirectoryName($PackagePath)) 'controller-release-validation.json'
}
$StampPath = [IO.Path]::GetFullPath($StampPath)

$releaseTests = Invoke-Checked 'dotnet' @('run','--project',(Join-Path $RepositoryRoot 'tools\controller-companion\ReleaseTests\BARControllerReleaseTests.csproj'),'-c','Release')
Require (($releaseTests -join "`n") -match '75/75 focused checks') 'Focused release tests did not report 75/75.'
for ($number = 1; $number -le 75; $number++) { Check $number 'focused manifest/update/recovery/transaction test' }

$historical = @(
    [pscustomobject]@{ commit='fcf9fd2d1c7cd47bc7caeeede4a95be77f8613ee'; tag='controller-support-v0.8.0-native-hybrid-test'; package='artifacts\v0.8.0-native-hybrid-test\BAR_Controller_Support_v0.8.0_NATIVE_HYBRID_TEST.zip'; sha='d1c783f830ba37301448b7d73ec092576688753ee4fe0cefb1fc627ef06262b5'; sequence=800010 },
    [pscustomobject]@{ commit='8a6bd885c891e0f95749f2e5c033c3273007a214'; tag='controller-support-v0.8.0-native-hybrid-targeting-test'; package='artifacts\v0.8.0-native-hybrid-targeting-test\BAR_Controller_Support_v0.8.0_NATIVE_HYBRID_TARGETING_TEST.zip'; sha='5ab4640bf7d4f690221e6cf31d30bca35dcb6dc111cc704aff5105ee639d24a3'; sequence=800020 },
    [pscustomobject]@{ commit='b0078c48b73d27675a686115ddfc0fe29b721e6e'; tag='controller-support-v0.8.0-native-input-disassemble-test'; package='artifacts\v0.8.0-native-input-disassemble-test\BAR_Controller_Support_v0.8.0_NATIVE_INPUT_DISASSEMBLE_TEST.zip'; sha='745b5f9e980693ed005e127cc0b7b1dbc18e2fab970dd8d9725fa152146d5803'; sequence=800030 },
    [pscustomobject]@{ commit='95e4b907f73bc78c2944ed55dac2e53d82d7c7d1'; tag='controller-support-v0.8.0-native-input-polish-test'; package='artifacts\v0.8.0-native-input-polish-test\BAR_Controller_Support_v0.8.0_NATIVE_INPUT_POLISH_TEST.zip'; sha='94735439ba85bed2590a4f022a94827b1c15b792ea44160cd22fdde500f4cbac'; sequence=800040 },
    [pscustomobject]@{ commit='9ea4999031c2e0452a554f0b677f99d3ed817490'; tag='controller-support-v0.8.0-native-widget-unification-test'; package='artifacts\v0.8.0-native-widget-unification-test\BAR_Controller_Support_v0.8.0_NATIVE_WIDGET_UNIFICATION_TEST.zip'; sha='1d012c08a19f27321e42b9879797796b199f1cea5eebf5625ced94f885b90f6c'; sequence=800050 },
    [pscustomobject]@{ commit='dc76f42b9f09a42a3455b705ea3ca2f1ff372931'; tag='controller-support-v0.8.0-native-regression-repair-test'; package='artifacts\v0.8.0-native-regression-repair-test\BAR_Controller_Support_v0.8.0_NATIVE_REGRESSION_REPAIR_TEST.zip'; sha='db06b38db34b50ab2487b666753e23d97e7c07fc96c0a2f0fdf186590872e61b'; sequence=800060 },
    [pscustomobject]@{ commit='c680490f0aba001f2a51a2e367b8198d96dbab76'; tag='controller-support-v0.8.0-hybrid-area-idle-repair-test'; package='artifacts\v0.8.0-hybrid-area-idle-repair-test\BAR_Controller_Support_v0.8.0_HYBRID_AREA_IDLE_REPAIR_TEST.zip'; sha='2c06f11ed694033811941efacc9abab900c9a07187eb434844fd8a338e1a7c93'; sequence=800070 },
    [pscustomobject]@{ commit='c5c07603e3d6560ad057e35a021d0f5ffc8b1643'; tag='controller-support-v0.8.0-radial-tactical-idle-redesign-test'; package='artifacts\v0.8.0-radial-tactical-idle-redesign-test\BAR_Controller_Support_v0.8.0_RADIAL_TACTICAL_IDLE_REDESIGN_TEST.zip'; sha='845dc89eec1d3adc15443b51ca214a06a71c22ba14057efb40aa7af0394920de'; sequence=800080 }
)

$v7 = gh release view controller-support-v0.7.0-disassemble-mode --repo $repository --json tagName,assets | ConvertFrom-Json
$v7Assets = @($v7.assets | Where-Object name -eq 'BAR_Controller_Support_v0.7.0_Widget_Companion.zip')
Require ($v7.tagName -eq 'controller-support-v0.7.0-disassemble-mode' -and $v7Assets.Count -eq 1 -and
    ([string]$v7Assets[0].digest).Replace('sha256:','') -eq '18060e562950bbb98a85426d78f1290df5505b2766f57f901e2876460dfcb66b') 'Existing v0.7.0 release changed or duplicated.'
Check 76 'existing v0.7.0 release is preserved and unique'

foreach ($item in $historical) {
    Require ((& git -C $RepositoryRoot cat-file -t $item.commit 2>$null) -eq 'commit') "Historical commit missing: $($item.commit)"
    $localMatches = @(& git -C $RepositoryRoot tag --list $item.tag)
    $local = if ($localMatches.Count -eq 1) { ([string](& git -C $RepositoryRoot rev-list -n 1 $item.tag)).Trim() } else { '' }
    $remoteRows = @(& git -C $RepositoryRoot ls-remote --tags origin ('refs/tags/' + $item.tag) ('refs/tags/' + $item.tag + '^{}'))
    $peeled = @($remoteRows | Where-Object { $_ -match '\^\{\}$' })
    $remote = if ($peeled.Count) { ($peeled[0] -split '\s+')[0] } elseif ($remoteRows.Count) { ($remoteRows[0] -split '\s+')[0] } else { '' }
    Require ((-not $local -or $local -eq $item.commit) -and (-not $remote -or $remote -eq $item.commit)) "Historical tag points at the wrong commit: $($item.tag)"
}
Check 77 'historical tags are absent or point at exact historical commits'

foreach ($item in $historical) {
    $path = Join-Path $RepositoryRoot $item.package
    Require ((Test-Path -LiteralPath $path -PathType Leaf) -and (Get-Sha256 $path) -eq $item.sha) "Historical artifact hash mismatch: $($item.tag)"
}
Check 78 'all exact historical artifact SHA-256 values match'
Require (@($historical.sha | Sort-Object -Unique).Count -eq $historical.Count) 'Historical packages are not independently identified.'
Check 79 'historical packages retain distinct canonical identities and are not rebuilt'

$historicalScript = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'Publish-HistoricalControllerReleases.ps1')
Require ($historicalScript -match 'exact package missing' -and $historicalScript -match '(?s)exact package missing.*?continue') 'Missing-artifact isolation is absent.'
Check 80 'one missing historical asset skips only its milestone'
for ($index = 1; $index -lt $historical.Count; $index++) {
    Require ($historical[$index].sequence -gt $historical[$index - 1].sequence) 'Historical sequence is not oldest-first.'
}
Check 81 'historical publication sequence is oldest to newest'

$spec = Get-Content -Raw -Encoding UTF8 (Join-Path $RepositoryRoot 'tools\release\controller-release-payloads.json') | ConvertFrom-Json
Require ([long]$spec.release.releaseSequence -gt [long]$historical[-1].sequence) 'Current release is not sequenced last.'
Check 82 'current release is sequenced after all historical milestones'
Require ($spec.release.tag -eq 'controller-support-v0.8.0-v06-input-restore-ui-polish') 'Current Latest identity is wrong.'
Check 83 'current release is designated as the Latest candidate'
Require ($historicalScript -match '-Prerelease\s+-Historical' -and $historicalScript -notmatch '-Latest') 'Historical release flags could alter Latest.'
Check 84 'historical releases are prerelease recovery data and never Latest'

$localBefore = (@(& git -C $RepositoryRoot show-ref --tags 2>$null) | Sort-Object) -join "`n"
$remoteBefore = (@(& git -C $RepositoryRoot ls-remote --tags origin) | Sort-Object) -join "`n"
$releaseListBefore = gh release list --repo $repository --limit 100 --json tagName | ConvertFrom-Json
$releasesBefore = (@($releaseListBefore.tagName) | Sort-Object) -join "`n"
$null = & (Join-Path $PSScriptRoot 'Publish-HistoricalControllerReleases.ps1') -DryRun
$localAfter = (@(& git -C $RepositoryRoot show-ref --tags 2>$null) | Sort-Object) -join "`n"
$remoteAfter = (@(& git -C $RepositoryRoot ls-remote --tags origin) | Sort-Object) -join "`n"
$releaseListAfter = gh release list --repo $repository --limit 100 --json tagName | ConvertFrom-Json
$releasesAfter = (@($releaseListAfter.tagName) | Sort-Object) -join "`n"
Require ($localBefore -eq $localAfter -and $remoteBefore -eq $remoteAfter -and $releasesBefore -eq $releasesAfter) 'Dry run mutated GitHub or Git tags.'
Check 85 'publisher dry run performs no GitHub or tag mutation'

$publisher = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'Publish-ControllerRelease.ps1')
Require ($publisher -match 'if \(-not \$releaseExists\)' -and $publisher -match 'Existing release asset conflicts') 'Publisher idempotency contract is missing.'
Check 86 'existing correct releases are idempotent by remote digest'
Require ($publisher -match 'Remote tag .* points at' -and $publisher -match 'Tag .* points at') 'Wrong-tag hard stop is missing.'
Check 87 'wrong local or remote tag commit hard-stops'
Require ($publisher -match 'Existing release asset conflicts with local SHA-256') 'Conflicting-asset hard stop is missing.'
Check 88 'conflicting release asset hard-stops'
$builder = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'Build-ControllerPublicRelease.ps1')
Require ($builder -match 'foreach \(\$group in @\(\$spec.sourceGroups\)\)' -and $builder -match 'foreach \(\$build in @\(\$spec.builds\)\)') 'Builder payload model is not data-driven.'
Check 89 'new payload components require only payload-spec data changes'
Require ($publisher -match '\$assets = @\(\$PackagePath, \$packageSidecar, \$ManifestPath, \$manifestSidecar, \$PayloadInventoryPath, \$ReleaseNotesPath\)') 'Publisher sidecar set is incomplete.'
Check 90 'package, manifest, checksums, inventory, and notes upload together'
foreach ($item in $historical) {
    $notes = Join-Path (Join-Path (Split-Path -Parent (Join-Path $RepositoryRoot $item.package)) 'release-sidecars') 'RELEASE_NOTES.md'
    Require ((Test-Path -LiteralPath $notes -PathType Leaf) -and ([IO.File]::ReadAllText($notes).Contains($item.commit)) -and ([IO.File]::ReadAllText($notes).Contains($item.sha))) "Historical notes omit commit/hash: $($item.tag)"
}
Check 91 'historical release notes identify exact commit and package hash'
$policy = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'doc\controller-companion-v0.8.0\GITHUB_RELEASE_POLICY.md'))
Require ($policy -match 'Every successful controller-support milestone must be published' -and $policy -match 'Latest') 'Future mandatory publication policy is incomplete.'
Check 92 'future mandatory-release policy is durable and documented'

$companionTests = Invoke-Checked 'dotnet' @('run','--project',(Join-Path $RepositoryRoot 'tools\controller-companion\Tests\BARControllerCompanionUpdateTests.csproj'),'-c','Release')
$companionText = $companionTests -join "`n"
Require ($companionText -match 'central v0.8 Experimental metadata') 'Bridge version regression failed.'
Check 93 'bridge version remains v0.8.0 Experimental'
Require ($companionText -match 'attach/wait/transition/exit lifecycle') 'Bridge session tracking regression failed.'
Check 94 'bridge session tracking lifecycle passes'

$luaCases = @(
    @{ number=95; path='tools\controller-ui-tests\Test-ControllerV06InputRestore.lua'; label='tactical restoration' },
    @{ number=96; path='tools\controller-ui-tests\Test-ControllerHybridAreaIdleRepair.lua'; label='Area Mex route' },
    @{ number=97; path='tools\controller-ui-tests\Test-ControllerInputRestoration.lua'; label='selection tap' },
    @{ number=98; path='tools\controller-ui-tests\Test-ControllerV06InputRestore.lua'; label='idle navigation' },
    @{ number=99; path='tools\controller-ui-tests\Test-ControllerHybridRadials.lua'; label='radial behavior' },
    @{ number=100; path='tools\controller-ui-tests\Test-ControllerV06InputRestore.lua'; label='factory queue behavior' },
    @{ number=101; path='tools\controller-ui-tests\Test-ControllerNativeWidgetUnification.lua'; label='Distributed Grid' },
    @{ number=102; path='tools\controller-ui-tests\Test-ControllerV06InputRestore.lua'; label='control groups' },
    @{ number=103; path='tools\controller-ui-tests\Test-ControllerLBHintState.lua'; label='hint stability' },
    @{ number=104; path='tools\controller-ui-tests\Test-ControllerNativeRegressionRepair.lua'; label='panel hiding' },
    @{ number=105; path='tools\controller-ui-tests\Test-ControllerNativeUIIntegration.lua'; label='legacy fallback' }
)
foreach ($case in $luaCases) {
    $null = Invoke-Checked 'lua' @((Join-Path $RepositoryRoot $case.path), $RepositoryRoot)
    Check $case.number ($case.label + ' regression passes')
}

$changedLua = @(& git -C $RepositoryRoot diff --name-only $luaRegressionBaseCommit HEAD -- '*.lua')
foreach ($relative in $changedLua) {
    $null = Invoke-Checked 'luac' @('-p',(Join-Path $RepositoryRoot $relative))
}
Require ($changedLua.Count -gt 0) 'No changed Lua files were found for parse validation.'
Check 106 'all changed Lua files parse'

$projects = @(
    'tools\controller-companion\BarControllerCompanion.csproj',
    'tools\controller-companion\Launcher\BARControllerLauncher.csproj',
    'tools\controller-companion\Installer\BARControllerCompanionInstaller.csproj',
    'tools\controller-companion\Restore\BARControllerCompanionRestore.csproj',
    'tools\controller-companion\Updater\BARControllerUpdater.csproj',
    'tools\controller-companion\Tests\BARControllerCompanionUpdateTests.csproj',
    'tools\controller-companion\ReleaseTests\BARControllerReleaseTests.csproj'
)
foreach ($project in $projects) {
    $null = Invoke-Checked 'dotnet' @('build',(Join-Path $RepositoryRoot $project),'-c','Release','--nologo','-warnaserror')
}
Check 107 'all seven .NET projects build with zero errors and warnings'

$deployArguments = @{
    PackagePath=$PackagePath; ManifestPath=$ManifestPath; PayloadInventoryPath=$PayloadInventoryPath
    RepositoryRoot=$RepositoryRoot; BarDataPath=$BarDataPath; CompanionInstallPath=$CompanionInstallPath
    ValidateOnly=$true; AllowUnknownBase=[bool]$AllowUnknownBase
}
$null = & (Join-Path $PSScriptRoot 'Deploy-ControllerPublicRelease.ps1') @deployArguments
Check 108 'manifest-driven deployment validator passes'

$installedUpdater = Join-Path $CompanionInstallPath 'BARControllerUpdater.exe'
$null = Invoke-Checked $installedUpdater @('--validate-backup',$BackupRoot)
Check 109 'strict rollback validator passes'

$packageOutput = @(& (Join-Path $PSScriptRoot 'Test-ControllerRelease.ps1') -PackagePath $PackagePath -ManifestPath $ManifestPath -PayloadInventoryPath $PayloadInventoryPath)
Require (($packageOutput -join "`n") -match 'PAYLOAD_HASHES_VERIFIED=' -and ($packageOutput -join "`n") -match 'RELEASE_COMPONENTS_VERIFIED=') 'Final package inventory did not validate.'
Check 110 'final package inventory and component hashes pass'

Require ($passed -eq 110) "Expected exactly 110 checks, got $passed."
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
$stamp = [ordered]@{
    kind = 'bar-controller-release-validation'
    schemaVersion = 1
    passed = $true
    checksPassed = 110
    commitSha = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
    releaseTag = [string]$manifest.releaseTag
    packageSha256 = Get-Sha256 $PackagePath
    manifestSha256 = Get-Sha256 $ManifestPath
    backupRoot = $BackupRoot
    validatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
}
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($StampPath)) | Out-Null
[IO.File]::WriteAllText($StampPath, (($stamp | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
Write-Output 'CONTROLLER_RELEASE_TESTS=110/110'
Write-Output "VALIDATION_STAMP=$StampPath"
