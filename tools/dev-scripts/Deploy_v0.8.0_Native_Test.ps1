[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$BarDataPath = (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason\data'),
    [string]$CompanionInstallPath = (Join-Path $env:LOCALAPPDATA 'Programs\BARControllerCompanion'),
    [switch]$AllowUnknownBase,
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RequiredBranch = 'controller/v0.8.0-native-ui-integration-test'
$ExpectedBuild = 'Beyond All Reason test-30735-bf9c7bf'
$OverrideManifestRelative = 'native-overrides\native-override-manifest.json'
$WidgetFiles = @(
    'gui_controller_camera_test.lua',
    'gui_controller_bindings_ui.lua',
    'gui_controller_ui_runtime.lua',
    'gui_controller_ui_layout.lua'
)
$IncludeFiles = @(
    'controller_disassemble_behavior.lua',
    'controller_input_chords.lua',
    'controller_ui_runtime.lua',
    'controller_ui_editor_workspace.lua',
    'controller_ui_editor_input.lua',
    'controller_ui_shared_renderers.lua',
    'controller_native_radial_adapter.lua',
    'controller_native_targeting.lua',
    'controller_native_command_owner.lua',
    'controller_glyphs.lua'
)
$GlyphFiles = @(
    'controller_glyph_atlas.png',
    'controller_glyph_atlas_xbox.png',
    'controller_glyph_atlas_playstation.png',
    'asset-manifest.json',
    'LICENSE.md'
)
$ControllerUIFiles = @(
    'shipping-defaults.json',
    'shipping-defaults-manifest.json'
)

function Write-Step([string]$Message) { Write-Host ('[native-test-deploy] ' + $Message) }
function Get-Sha256([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Get-RelativeBarPath([string]$Path) {
    $root = [IO.Path]::GetFullPath($BarDataPath).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escaped BAR data: $Path" }
    return $full.Substring($root.Length)
}

function Write-JsonAtomic([string]$Path, [object]$Value) {
    $temporary = $Path + '.tmp'
    [IO.File]::WriteAllText($temporary, (($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary, $Path, ($Path + '.previous')) }
    else { Move-Item -LiteralPath $temporary -Destination $Path }
}

function Set-NativeBuildMenuMode([string]$ConfigPath, [string]$SafetyBackupPath) {
    $content = [IO.File]::ReadAllText($ConfigPath)
    $updated = $content
    $orders = [ordered]@{ 'Build menu' = 165; 'Grid menu' = 0 }
    foreach ($name in $orders.Keys) {
        $pattern = '(?m)^(?<prefix>[ \t]*(?:\["' + [regex]::Escape($name) + '"\]|' + [regex]::Escape($name) + ')[ \t]*=[ \t]*)-?\d+(?<suffix>[ \t]*,[ \t]*\r?$)'
        if (-not [regex]::IsMatch($updated, $pattern)) { throw "BYAR.lua has no numeric order entry for $name." }
        $replacement = '${prefix}' + [string]$orders[$name] + '${suffix}'
        $updated = [regex]::Replace($updated, $pattern, $replacement)
    }
    if ($updated -eq $content) { return $false }
    $temporary = $ConfigPath + '.native-test.tmp'
    [IO.File]::WriteAllText($temporary, $updated, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::Replace($temporary, $ConfigPath, $SafetyBackupPath)
    return $true
}

function Assert-NativeBuildMenuEntries([string]$ConfigPath) {
    $content = [IO.File]::ReadAllText($ConfigPath)
    foreach ($name in @('Build menu', 'Grid menu')) {
        $pattern = '(?m)^[ \t]*(?:\["' + [regex]::Escape($name) + '"\]|' + [regex]::Escape($name) + ')[ \t]*=[ \t]*-?\d+[ \t]*,[ \t]*\r?$'
        if (-not [regex]::IsMatch($content, $pattern)) { throw "BYAR.lua has no numeric order entry for $name." }
    }
}

function Stop-RuntimesSafely {
    $all = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher|BARControllerCompanionInstaller|BARControllerCompanionRestore|BARControllerUIDefaultsPublisher|spring|spring-headless|Beyond-All-Reason|BAR)\.exe$'
    })
    $bar = @($all | Where-Object { $_.Name -match '^(?i)(spring|spring-headless|Beyond-All-Reason|BAR)\.exe$' })
    if ($bar.Count -gt 0) {
        $bar | Select-Object ProcessId, Name, ExecutablePath | Format-List
        throw 'BAR is running. Close it manually; this tool never force-kills BAR.'
    }
    foreach ($item in @($all | Where-Object { $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher)\.exe$' })) {
        $process = Get-Process -Id $item.ProcessId -ErrorAction Stop
        if (-not $process.CloseMainWindow()) { throw "$($item.Name) has no closeable window. Close it manually and retry." }
        for ($attempt = 0; $attempt -lt 50 -and (Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue); $attempt++) {
            Start-Sleep -Milliseconds 200
        }
        if (Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue) { throw "$($item.Name) did not exit cleanly." }
    }
    $remaining = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher|BARControllerCompanionInstaller|BARControllerCompanionRestore|BARControllerUIDefaultsPublisher|spring|spring-headless|Beyond-All-Reason|BAR)\.exe$'
    })
    if ($remaining.Count -gt 0) { throw 'A BAR/controller deployment process remains active.' }
}

function Assert-Lua([string]$Path) {
    & luac -p $Path
    if ($LASTEXITCODE -ne 0) { throw "Lua parse failed: $Path" }
    $listing = @(& luac -l -p $Path 2>&1)
    $maximum = 0
    foreach ($line in $listing) {
        if ($line -match '(\d+) upvalues?') { $maximum = [Math]::Max($maximum, [int]$matches[1]) }
    }
    if ($maximum -gt 60) { throw "BAR's 60-upvalue limit is exceeded ($maximum): $Path" }
}

function Assert-LuaHarness([string]$RelativePath) {
    & lua (Join-Path $RepositoryRoot $RelativePath) $RepositoryRoot
    if ($LASTEXITCODE -ne 0) { throw "Lua harness failed: $RelativePath" }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$BarDataPath = (Resolve-Path -LiteralPath $BarDataPath).Path
$CompanionInstallPath = (Resolve-Path -LiteralPath $CompanionInstallPath).Path
$overrideManifestPath = Join-Path $RepositoryRoot $OverrideManifestRelative
if (-not (Test-Path -LiteralPath $overrideManifestPath -PathType Leaf)) { throw 'Native override manifest is missing.' }
$overrideManifest = Get-Content -Raw -Encoding UTF8 $overrideManifestPath | ConvertFrom-Json
if ($overrideManifest.kind -ne 'bar-controller-native-override-manifest' -or $overrideManifest.upstreamCommit -ne 'bf9c7bfdba26704832157bba47f3653ba8bdd8d2') {
    throw 'Unexpected native override manifest identity.'
}

$sourceCommit = 'packaged-experimental-source-see-payload-sha256'
if (Test-Path -LiteralPath (Join-Path $RepositoryRoot '.git')) {
    $branch = (& git -C $RepositoryRoot branch --show-current).Trim()
    if ($branch -ne $RequiredBranch) { throw "Expected branch $RequiredBranch, found $branch." }
    if (@(& git -C $RepositoryRoot status --porcelain).Count -ne 0) { throw 'Repository worktree must be clean before live deployment.' }
    $sourceCommit = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
}

Stop-RuntimesSafely
$infolog = Join-Path $BarDataPath 'infolog.txt'
$widgetConfigPath = Join-Path $BarDataPath 'LuaUI\Config\BYAR.lua'
if (-not (Test-Path -LiteralPath $widgetConfigPath -PathType Leaf)) { throw 'BAR widget configuration is missing.' }
Assert-NativeBuildMenuEntries $widgetConfigPath
$buildMatches = (Test-Path -LiteralPath $infolog) -and ([IO.File]::ReadAllText($infolog).Contains($ExpectedBuild))
if (-not $buildMatches -and -not $AllowUnknownBase) {
    throw "Live BAR build identity does not contain '$ExpectedBuild'. Rebase first, or use -AllowUnknownBase only for an audited development override."
}

$deployMap = New-Object Collections.Generic.List[object]
foreach ($name in $WidgetFiles) {
    $deployMap.Add([pscustomobject]@{ source = (Join-Path $RepositoryRoot ('luaui\Widgets\' + $name)); destination = (Join-Path $BarDataPath ('LuaUI\Widgets\' + $name)); native = $false })
}
foreach ($name in $IncludeFiles) {
    $deployMap.Add([pscustomobject]@{ source = (Join-Path $RepositoryRoot ('luaui\Include\' + $name)); destination = (Join-Path $BarDataPath ('LuaUI\Include\' + $name)); native = $false })
}
foreach ($name in $GlyphFiles) {
    $deployMap.Add([pscustomobject]@{ source = (Join-Path $RepositoryRoot ('luaui\images\controller-glyphs\' + $name)); destination = (Join-Path $BarDataPath ('LuaUI\Images\controller-glyphs\' + $name)); native = $false })
}
foreach ($name in $ControllerUIFiles) {
    $deployMap.Add([pscustomobject]@{ source = (Join-Path $RepositoryRoot ('controller-ui\' + $name)); destination = (Join-Path $BarDataPath ('controller-ui\' + $name)); native = $false })
}
foreach ($entry in @($overrideManifest.entries)) {
    $previousPatchedSha256 = ''
    if ($null -ne $entry.PSObject.Properties['previousPatchedSha256']) {
        $previousPatchedSha256 = [string]$entry.previousPatchedSha256
    }
    $deployMap.Add([pscustomobject]@{ source = (Join-Path $RepositoryRoot ([string]$entry.sourcePath)); destination = (Join-Path $BarDataPath ([string]$entry.livePath)); native = $true; baseSha256 = [string]$entry.baseSha256; previousPatchedSha256 = $previousPatchedSha256; patchedSha256 = [string]$entry.patchedSha256 })
}

$destinations = @{}
foreach ($item in $deployMap) {
    if (-not (Test-Path -LiteralPath $item.source -PathType Leaf)) { throw "Deployment source is missing: $($item.source)" }
    $fullDestination = [IO.Path]::GetFullPath($item.destination)
    if ($destinations.ContainsKey($fullDestination)) { throw "Duplicate deployment destination: $fullDestination" }
    $destinations[$fullDestination] = $true
    if ([IO.Path]::GetExtension($item.source) -eq '.lua') { Assert-Lua $item.source }
    $sourceHash = Get-Sha256 $item.source
    if ($item.native -and $sourceHash -ne $item.patchedSha256) { throw "Tracked patched hash is stale: $($item.source)" }
    if ($item.native -and (Test-Path -LiteralPath $item.destination -PathType Leaf)) {
        $liveHash = Get-Sha256 $item.destination
        if ($liveHash -ne $item.baseSha256 -and $liveHash -ne $item.previousPatchedSha256 -and $liveHash -ne $item.patchedSha256 -and -not $AllowUnknownBase) {
            throw "Unknown loose vanilla override ($liveHash): $($item.destination). Rebase or explicitly use -AllowUnknownBase after inspection."
        }
    }
}

Assert-LuaHarness 'tools\controller-ui-tests\Test-ControllerNativeUIIntegration.lua'
Assert-LuaHarness 'tools\controller-ui-tests\Test-ControllerHybridRadials.lua'
Assert-LuaHarness 'tools\controller-ui-tests\Test-ControllerNativeTargeting.lua'
Assert-LuaHarness 'tools\controller-ui-tests\Test-ControllerDisassembleMode.lua'
Assert-LuaHarness 'tools\controller-ui-tests\Test-ControllerInputDisassemble.lua'
Assert-LuaHarness 'tools\controller-ui-tests\Test-ControllerInputPolish.lua'
Assert-LuaHarness 'tools\controller-ui-tests\Test-ControllerNativeWidgetUnification.lua'
Assert-LuaHarness 'tools\controller-ui-tests\Test-ControllerNativeRegressionRepair.lua'

if ($ValidateOnly) {
    Write-Step "Validation passed for $($deployMap.Count) files; BAR build and native base policy are compatible."
    return
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $CompanionInstallPath ('deployment-backups\v0.8.0-native-regression-repair-test-' + $timestamp)
if (Test-Path -LiteralPath $backupRoot) { throw "Backup path already exists: $backupRoot" }
New-Item -ItemType Directory -Path (Join-Path $backupRoot 'live-before') -Force | Out-Null
$records = New-Object Collections.Generic.List[object]

foreach ($item in $deployMap) {
    $existed = Test-Path -LiteralPath $item.destination -PathType Leaf
    $preHash = if ($existed) { Get-Sha256 $item.destination } else { $null }
    $backup = $null
    if ($existed) {
        $relative = Get-RelativeBarPath $item.destination
        $backup = Join-Path (Join-Path $backupRoot 'live-before') $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
        Copy-Item -LiteralPath $item.destination -Destination $backup
        if ((Get-Sha256 $backup) -ne $preHash) { throw "Backup hash mismatch: $backup" }
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $item.destination) -Force | Out-Null
    Copy-Item -LiteralPath $item.source -Destination $item.destination -Force
    $postHash = Get-Sha256 $item.destination
    if ($postHash -ne (Get-Sha256 $item.source)) { throw "Installed hash mismatch: $($item.destination)" }
    $records.Add([pscustomobject][ordered]@{
        source = $item.source; destination = $item.destination; nativeOverride = $item.native
        existedBefore = $existed; preSha256 = $preHash; backup = $backup; postSha256 = $postHash
    })
}

$preserved = New-Object Collections.Generic.List[object]
foreach ($path in @((Join-Path $BarDataPath 'LuaUI\Config\BYAR.lua'), (Join-Path $BarDataPath 'springsettings.cfg'))) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $relative = Get-RelativeBarPath $path
        $backup = Join-Path (Join-Path $backupRoot 'live-before') $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
        Copy-Item -LiteralPath $path -Destination $backup -Force
        $hash = Get-Sha256 $path
        if ((Get-Sha256 $backup) -ne $hash) { throw "Preserved-file backup hash mismatch: $path" }
        $preserved.Add([pscustomobject]@{ destination = $path; backup = $backup; sha256 = $hash; postSha256 = $hash })
    }
}

$widgetConfigChanged = Set-NativeBuildMenuMode -ConfigPath $widgetConfigPath -SafetyBackupPath (Join-Path $backupRoot 'BYAR.replace-safety.lua')
$widgetConfigPostHash = Get-Sha256 $widgetConfigPath
foreach ($record in $preserved) {
    if ([IO.Path]::GetFullPath([string]$record.destination).Equals([IO.Path]::GetFullPath($widgetConfigPath), [StringComparison]::OrdinalIgnoreCase)) {
        $record.postSha256 = $widgetConfigPostHash
    }
}

$manifest = [ordered]@{
    kind = 'bar-controller-native-regression-repair-test-deployment-backup'; schemaVersion = 1
    experiment = ('EXPERIMENTAL ' + [char]0x2014 + ' SMART X, RADIAL ROUTING, ENEMY DISASSEMBLE, AND AREA CONFIRMATION TEST'); deployedAt = (Get-Date).ToString('o')
    repositoryRoot = $RepositoryRoot; sourceCommit = $sourceCommit
    barDataPath = $BarDataPath; companionInstallPath = $CompanionInstallPath; backupRoot = $backupRoot
    expectedBarBuild = $ExpectedBuild; buildIdentityMatched = $buildMatches; explicitUnknownBaseOverride = [bool]$AllowUnknownBase
    widgetConfigChanged = $widgetConfigChanged; widgetConfigPostSha256 = $widgetConfigPostHash
    nativeBuildMenuOrder = 165; disabledGridMenuOrder = 0
    deployedFiles = $records; preservedFiles = $preserved
}
$manifestPath = Join-Path $backupRoot 'deployment-manifest.json'
Write-JsonAtomic -Path $manifestPath -Value $manifest

foreach ($record in $records) {
    if ((Get-Sha256 $record.destination) -ne $record.postSha256) { throw "Post-manifest verification failed: $($record.destination)" }
}
Stop-RuntimesSafely
Write-Step 'Experimental native widget, Smart Action, and UI unification test deployed. BAR was not launched.'
Write-Output ('BACKUP_ROOT=' + $backupRoot)
Write-Output ('ROLLBACK_COMMAND=powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $RepositoryRoot 'tools\dev-scripts\Restore_v0.8.0_Native_Test.ps1') + '" -BackupRoot "' + $backupRoot + '"')
