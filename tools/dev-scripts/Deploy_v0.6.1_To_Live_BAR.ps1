[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$BarDataPath = (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason\data'),
    [string]$CompanionInstallPath = (Join-Path $env:LOCALAPPDATA 'Programs\BARControllerCompanion'),
    [string]$RuntimeArtifactsRoot,
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
if ([string]::IsNullOrWhiteSpace($RuntimeArtifactsRoot)) {
    $RuntimeArtifactsRoot = Join-Path $RepositoryRoot 'artifacts\v0.6.1\win-x64'
}

$RequiredBranch = 'controller/v0.6.1-radial-typography'
$RequiredWidgets = @(
    'Controller Camera Test',
    'Controller Bindings UI',
    'Controller UI Layout'
)
$WidgetFiles = @(
    'gui_controller_camera_test.lua',
    'gui_controller_bindings_ui.lua',
    'gui_controller_ui_layout.lua'
)
$LuaSupportFiles = @(
    'controller_ui_editor_workspace.lua',
    'controller_ui_editor_input.lua',
    'controller_ui_shared_renderers.lua',
    'controller_glyphs.lua'
)
$GlyphAssetFiles = @(
    'controller_glyph_atlas.png',
    'asset-manifest.json',
    'LICENSE.md'
)

function Write-Step([string]$Message) {
    Write-Host ('[dev-deploy] ' + $Message)
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Get-ControllerRuntimeProcesses {
    return @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher|BARControllerCompanionInstaller|BARControllerCompanionRestore|BARControllerUIDefaultsPublisher|spring|spring-headless|Beyond-All-Reason|BAR)\.exe$' -or
        $_.ExecutablePath -like ((Split-Path -Parent $BarDataPath) + '\*')
    })
}

function Stop-CompanionWindowCleanly([uint32]$ProcessId, [string]$ExpectedName) {
    $process = Get-Process -Id $ProcessId -ErrorAction Stop
    if ($process.ProcessName -ne $ExpectedName) {
        throw "Process $ProcessId is no longer $ExpectedName."
    }
    if (-not $process.CloseMainWindow()) {
        throw "$ExpectedName has no closeable window. Close it manually and retry."
    }
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
            Write-Step "Stopped $ExpectedName cleanly."
            return
        }
        Start-Sleep -Milliseconds 200
    }
    throw "$ExpectedName did not exit after a clean window-close request."
}

function Assert-RuntimeStopped {
    $processes = @(Get-ControllerRuntimeProcesses)
    $barProcesses = @($processes | Where-Object {
        $_.Name -match '^(?i)(spring|spring-headless|Beyond-All-Reason|BAR)\.exe$' -or
        ($_.ExecutablePath -like ((Split-Path -Parent $BarDataPath) + '\*') -and
            $_.Name -notmatch '^(?i)(BARControllerBridge|BARControllerLauncher)\.exe$')
    })
    if ($barProcesses.Count -gt 0) {
        $barProcesses | Select-Object ProcessId, Name, ExecutablePath | Format-List
        throw 'BAR is running. Close BAR manually; this script never force-kills it.'
    }

    foreach ($item in @($processes | Where-Object { $_.Name -match '^(?i)(BARControllerBridge|BARControllerLauncher)\.exe$' })) {
        Stop-CompanionWindowCleanly -ProcessId $item.ProcessId -ExpectedName ([IO.Path]::GetFileNameWithoutExtension($item.Name))
    }

    $remaining = @(Get-ControllerRuntimeProcesses)
    if ($remaining.Count -gt 0) {
        $remaining | Select-Object ProcessId, Name, ExecutablePath | Format-List
        throw 'A controller installer, restore tool, publisher, or other runtime process is still active.'
    }
}

function Get-MaxLuaUpvalues([string]$Path) {
    $listing = @(& luac -l -p $Path 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "luac listing failed for $Path"
    }
    $maximum = 0
    $expectMetadata = $false
    foreach ($line in $listing) {
        if ($line -match '^function <') {
            $expectMetadata = $true
        }
        elseif ($expectMetadata -and $line -match '(\d+) upvalues?') {
            $count = [int]$matches[1]
            if ($count -gt $maximum) { $maximum = $count }
            $expectMetadata = $false
        }
    }
    return $maximum
}

function Find-MatchingBrace([string]$Content, [int]$OpeningBrace) {
    $depth = 0
    $inSingle = $false
    $inDouble = $false
    $inComment = $false
    $escaped = $false
    for ($index = $OpeningBrace; $index -lt $Content.Length; $index++) {
        $current = $Content[$index]
        $next = if ($index + 1 -lt $Content.Length) { $Content[$index + 1] } else { [char]0 }
        if ($inComment) {
            if ($current -eq "`n") { $inComment = $false }
            continue
        }
        if (-not $inSingle -and -not $inDouble -and $current -eq '-' -and $next -eq '-') {
            $inComment = $true
            $index++
            continue
        }
        if ($escaped) { $escaped = $false; continue }
        if (($inSingle -or $inDouble) -and $current -eq '\') { $escaped = $true; continue }
        if (-not $inDouble -and $current -eq "'") { $inSingle = -not $inSingle; continue }
        if (-not $inSingle -and $current -eq '"') { $inDouble = -not $inDouble; continue }
        if ($inSingle -or $inDouble) { continue }
        if ($current -eq '{') { $depth++ }
        elseif ($current -eq '}') {
            $depth--
            if ($depth -eq 0) { return $index }
        }
    }
    throw 'BYAR.lua has an unterminated order table.'
}

function Enable-RequiredWidgets([string]$ConfigPath, [string]$ReplacementBackupPath) {
    $content = [IO.File]::ReadAllText($ConfigPath)
    $original = $content
    $orderMatch = [regex]::Match($content, '(?m)^[ \t]*order[ \t]*=[ \t]*\{')
    if (-not $orderMatch.Success) { throw 'BYAR.lua does not contain an order table.' }
    $openingBrace = $content.IndexOf('{', $orderMatch.Index)
    $closingBrace = Find-MatchingBrace -Content $content -OpeningBrace $openingBrace
    $body = $content.Substring($openingBrace + 1, $closingBrace - $openingBrace - 1)
    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $indentMatch = [regex]::Match($body, '(?m)^(?<indent>[ \t]*)\["')
    $indent = if ($indentMatch.Success) { $indentMatch.Groups['indent'].Value } else { "`t`t" }

    foreach ($widgetName in $RequiredWidgets) {
        $pattern = '(?m)^(?<indent>[ \t]*)\["' + [regex]::Escape($widgetName) + '"\][ \t]*=[ \t]*(?<value>-?\d+)[ \t]*,?[ \t]*(?=\r?$)'
        $match = [regex]::Match($body, $pattern)
        if ($match.Success) {
            if ([int]$match.Groups['value'].Value -le 0) {
                $replacement = $match.Groups['indent'].Value + '["' + $widgetName + '"] = 1,'
                $body = $body.Substring(0, $match.Index) + $replacement + $body.Substring($match.Index + $match.Length)
            }
        }
        else {
            $entry = $indent + '["' + $widgetName + '"] = 1,'
            $body = $body.TrimEnd("`r", "`n") + $newline + $entry + $newline
        }
    }

    $content = $content.Substring(0, $openingBrace + 1) + $body + $content.Substring($closingBrace)
    if ($content -ne $original) {
        $temporary = $ConfigPath + '.bar-controller-deploy.tmp'
        [IO.File]::WriteAllText($temporary, $content, (New-Object Text.UTF8Encoding($false)))
        [IO.File]::Replace($temporary, $ConfigPath, $ReplacementBackupPath)
        return $true
    }
    return $false
}

function Write-JsonAtomic([string]$Path, [object]$Value) {
    $temporary = $Path + '.tmp'
    $json = $Value | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($temporary, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary, $Path, ($Path + '.previous')) }
    else { Move-Item -LiteralPath $temporary -Destination $Path }
}

$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$RuntimeArtifactsRoot = (Resolve-Path -LiteralPath $RuntimeArtifactsRoot).Path
$BarDataPath = (Resolve-Path -LiteralPath $BarDataPath).Path
$CompanionInstallPath = (Resolve-Path -LiteralPath $CompanionInstallPath).Path
$WidgetDirectory = Join-Path $BarDataPath 'LuaUI\Widgets'
$WidgetConfigPath = Join-Path $BarDataPath 'LuaUI\Config\BYAR.lua'
$SettingsPath = Join-Path $BarDataPath 'springsettings.cfg'

Write-Step 'Running repository and live-install preflight.'
if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot '.git'))) { throw 'RepositoryRoot is not a Git worktree.' }
if (-not (Test-Path -LiteralPath $WidgetDirectory -PathType Container)) { throw 'BAR widget directory is missing.' }
if (-not (Test-Path -LiteralPath $WidgetConfigPath -PathType Leaf)) { throw 'BAR widget configuration is missing.' }
if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) { throw 'BAR settings file is missing.' }

$branch = (& git -C $RepositoryRoot branch --show-current).Trim()
$commit = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($branch -ne $RequiredBranch) { throw "Expected branch $RequiredBranch, found $branch." }
$status = @(& git -C $RepositoryRoot status --porcelain)
if ($status.Count -ne 0) { $status; throw 'Worktree is not clean.' }
Invoke-NativeChecked -FilePath 'git' -Arguments @('-C', $RepositoryRoot, 'diff', '--check') -Label 'git diff --check'

foreach ($widgetFile in $WidgetFiles) {
    $source = Join-Path $RepositoryRoot ('luaui\Widgets\' + $widgetFile)
    Invoke-NativeChecked -FilePath 'luac' -Arguments @('-p', $source) -Label ('Lua parse ' + $widgetFile)
}
$LuaIncludeDirectory = Join-Path $BarDataPath 'LuaUI\Include'
$GlyphAssetDirectory = Join-Path $BarDataPath 'LuaUI\Images\controller-glyphs'
foreach ($supportFile in $LuaSupportFiles) {
    $source = Join-Path $RepositoryRoot ('luaui\Include\' + $supportFile)
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Lua support module is missing: $source" }
    Invoke-NativeChecked -FilePath 'luac' -Arguments @('-p', $source) -Label ('Lua parse ' + $supportFile)
    $supportUpvalues = Get-MaxLuaUpvalues -Path $source
    if ($supportUpvalues -gt 60) { throw "$supportFile captures $supportUpvalues upvalues; BAR permits 60." }
}
foreach ($assetFile in $GlyphAssetFiles) {
    $source = Join-Path $RepositoryRoot ('luaui\images\controller-glyphs\' + $assetFile)
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Controller glyph asset is missing: $source" }
}
$layoutSource = Join-Path $RepositoryRoot 'luaui\Widgets\gui_controller_ui_layout.lua'
$maximumUpvalues = Get-MaxLuaUpvalues -Path $layoutSource
if ($maximumUpvalues -gt 60) { throw "Controller UI Layout captures $maximumUpvalues upvalues; BAR permits 60." }
Assert-RuntimeStopped

Write-Step 'Running deployment test gates.'
Invoke-NativeChecked -FilePath 'lua' -Arguments @((Join-Path $RepositoryRoot 'tools\controller-ui-tests\Test-ControllerUIAuthoring.lua'), $RepositoryRoot) -Label 'Controller UI authoring harness'
Invoke-NativeChecked -FilePath 'lua' -Arguments @((Join-Path $RepositoryRoot 'tools\controller-ui-tests\Test-ControllerUIWorkspace.lua'), $RepositoryRoot) -Label 'Controller UI workspace navigation/scrolling harness'
Invoke-NativeChecked -FilePath 'lua' -Arguments @((Join-Path $RepositoryRoot 'tools\controller-ui-tests\Test-ControllerUIModalInput.lua'), $RepositoryRoot) -Label 'Controller UI modal input/inspector harness'
Invoke-NativeChecked -FilePath 'lua' -Arguments @((Join-Path $RepositoryRoot 'tools\controller-ui-tests\Test-ControllerUISharedRenderers.lua'), $RepositoryRoot) -Label 'Controller UI production/shared preview renderer harness'
Invoke-NativeChecked -FilePath 'lua' -Arguments @((Join-Path $RepositoryRoot 'tools\controller-ui-tests\Test-ControllerGlyphs.lua'), $RepositoryRoot) -Label 'Controller glyph resolution/asset harness'
Invoke-NativeChecked -FilePath 'lua' -Arguments @((Join-Path $RepositoryRoot 'tools\controller-ui-tests\Test-ControllerUIReleaseQuality.lua'), $RepositoryRoot) -Label 'Controller UI v0.6.1 release-quality harness'
Invoke-NativeChecked -FilePath 'lua' -Arguments @((Join-Path $RepositoryRoot 'tools\controller-ui-tests\Test-ControllerLBHintState.lua'), $RepositoryRoot) -Label 'Controller LB/hint-state focused harness'
Invoke-NativeChecked -FilePath 'lua' -Arguments @((Join-Path $RepositoryRoot 'tools\controller-ui-tests\Test-ControllerRadialTypography.lua'), $RepositoryRoot) -Label 'Controller radial typography/color wiring harness'
Invoke-NativeChecked -FilePath 'dotnet' -Arguments @('run', '--project', (Join-Path $RepositoryRoot 'tools\controller-companion\Tests\BARControllerCompanionUpdateTests.csproj'), '-c', 'Release', '--no-build', '--no-restore') -Label 'Companion update/defaults tests'
$publisherProject = Join-Path $RepositoryRoot 'tools\controller-ui-publisher\BARControllerUIDefaultsPublisher.csproj'
$sourceDefaults = Join-Path $RepositoryRoot 'controller-ui\shipping-defaults.json'
$sourceDefaultsManifest = Join-Path $RepositoryRoot 'controller-ui\shipping-defaults-manifest.json'
Invoke-NativeChecked -FilePath 'dotnet' -Arguments @('run', '--project', $publisherProject, '-c', 'Release', '--no-build', '--', 'validate', '--defaults', $sourceDefaults, '--manifest', $sourceDefaultsManifest) -Label 'Shipping defaults validation'

$runtimeManifestPath = Join-Path $RuntimeArtifactsRoot 'frozen-runtime-manifest.json'
if (-not (Test-Path -LiteralPath $runtimeManifestPath -PathType Leaf)) { throw "Frozen runtime manifest is missing: $runtimeManifestPath" }
$runtimeManifest = Get-Content -Raw -LiteralPath $runtimeManifestPath | ConvertFrom-Json
if ([string]$runtimeManifest.version -ne '0.6.1' -or [string]$runtimeManifest.sourceCommit -ne $commit) {
    throw 'Frozen runtime manifest does not match v0.6.1 and the checked-out source commit.'
}
foreach ($artifact in $runtimeManifest.artifacts) {
    $artifactPath = Join-Path $RuntimeArtifactsRoot ([string]$artifact.relativePath)
    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf) -or
        (Get-Item -LiteralPath $artifactPath).Length -ne [long]$artifact.size -or
        (Get-Sha256 $artifactPath) -ne [string]$artifact.sha256) {
        throw "Frozen runtime artifact integrity failed: $($artifact.relativePath)"
    }
}
$publishedBridge = Join-Path $RuntimeArtifactsRoot 'bridge\BARControllerBridge.exe'
$publishedLauncher = Join-Path $RuntimeArtifactsRoot 'launcher\BARControllerLauncher.exe'
$publishedRestore = Join-Path $RuntimeArtifactsRoot 'restore\BAR_Controller_Companion_Restore_v0.6.1.exe'
foreach ($output in @($publishedBridge, $publishedLauncher, $publishedRestore)) {
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) { throw "Published runtime output is missing: $output" }
}
Invoke-NativeChecked -FilePath $publishedBridge -Arguments @('help') -Label 'Published bridge help smoke test'
Invoke-NativeChecked -FilePath $publishedBridge -Arguments @('status', '--bar-data', $BarDataPath) -Label 'Published bridge status smoke test'

if ($ValidateOnly) {
    Write-Step "Validation-only pass succeeded for $branch at $commit (max Lua upvalues: $maximumUpvalues)."
    return
}

Write-Step 'Creating timestamped backup.'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $CompanionInstallPath ('deployment-backups\v0.6.1-' + $timestamp)
if (Test-Path -LiteralPath $backupRoot) { throw 'Timestamped backup path already exists.' }
New-Item -ItemType Directory -Path $backupRoot | Out-Null
$backupPrefix = (Join-Path $CompanionInstallPath 'deployment-backups') + '\'
if (-not (Resolve-Path -LiteralPath $backupRoot).Path.StartsWith($backupPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Backup path escaped the companion deployment-backups directory.'
}
$backupRecords = New-Object Collections.Generic.List[object]
function Backup-LiveFile([string]$Source, [string]$Relative, [string]$Purpose) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    $destination = Join-Path $backupRoot $Relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $destination
    $backupRecords.Add([pscustomobject][ordered]@{
        source = $Source; backup = $destination; purpose = $Purpose
        length = (Get-Item -LiteralPath $Source).Length; sha256 = Get-Sha256 $Source
    })
}
foreach ($widgetFile in $WidgetFiles) {
    Backup-LiveFile (Join-Path $WidgetDirectory $widgetFile) (Join-Path 'live-before\LuaUI\Widgets' $widgetFile) 'live Lua widget'
}
foreach ($supportFile in $LuaSupportFiles) {
    Backup-LiveFile (Join-Path $LuaIncludeDirectory $supportFile) (Join-Path 'live-before\LuaUI\Include' $supportFile) 'live Lua support module'
}
foreach ($assetFile in $GlyphAssetFiles) {
    Backup-LiveFile (Join-Path $GlyphAssetDirectory $assetFile) (Join-Path 'live-before\LuaUI\Images\controller-glyphs' $assetFile) 'controller glyph asset'
}
Backup-LiveFile $WidgetConfigPath 'live-before\LuaUI\Config\BYAR.lua' 'widget enablement and personal widget settings'
Backup-LiveFile $SettingsPath 'live-before\springsettings.cfg' 'BAR settings'
Get-ChildItem -LiteralPath $CompanionInstallPath -File -Force | ForEach-Object {
    Backup-LiveFile $_.FullName (Join-Path 'live-before\companion' $_.Name) 'installed companion top-level file'
}
foreach ($defaultsPath in @(
    (Join-Path $BarDataPath 'controller-ui\shipping-defaults.json'),
    (Join-Path $BarDataPath 'controller-ui\shipping-defaults-manifest.json'),
    (Join-Path $BarDataPath 'LuaUI\Config\BARControllerSupport\controller-ui-defaults.json'),
    (Join-Path $BarDataPath 'LuaUI\Config\BARControllerSupport\controller-ui-defaults-manifest.json')
)) {
    $bucket = if ($defaultsPath -like '*BARControllerSupport*') { 'live-before\cached-defaults' } else { 'live-before\bundled-defaults' }
    Backup-LiveFile $defaultsPath (Join-Path $bucket (Split-Path -Leaf $defaultsPath)) 'shipping defaults'
}
$shortcutPaths = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Beyond-All-Reason.lnk'),
    (Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\Beyond-All-Reason.lnk')
)
for ($shortcutIndex = 0; $shortcutIndex -lt $shortcutPaths.Count; $shortcutIndex++) {
    Backup-LiveFile $shortcutPaths[$shortcutIndex] (Join-Path 'live-before\shortcuts' ('shortcut-' + ($shortcutIndex + 1) + '-Beyond-All-Reason.lnk')) 'BAR shortcut'
}

$relocatedBackups = New-Object Collections.Generic.List[object]
$relocatedRoot = Join-Path $backupRoot 'relocated-widget-backups'
New-Item -ItemType Directory -Path $relocatedRoot | Out-Null
$widgetRootResolved = (Resolve-Path -LiteralPath $WidgetDirectory).Path
foreach ($directory in @(Get-ChildItem -LiteralPath $WidgetDirectory -Directory -Force | Where-Object Name -like 'v060_backup_*')) {
    $sourceResolved = (Resolve-Path -LiteralPath $directory.FullName).Path
    if (-not $sourceResolved.StartsWith($widgetRootResolved + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Widget backup source escaped the widget directory.' }
    $destination = Join-Path $relocatedRoot $directory.Name
    if (Test-Path -LiteralPath $destination) { throw "Relocated backup destination exists: $destination" }
    $files = @(Get-ChildItem -LiteralPath $sourceResolved -Recurse -File -Force | ForEach-Object {
        [pscustomobject]@{ relative = $_.FullName.Substring($sourceResolved.Length + 1); length = $_.Length; sha256 = Get-Sha256 $_.FullName }
    })
    Move-Item -LiteralPath $sourceResolved -Destination $destination
    $relocatedBackups.Add([pscustomobject]@{ source = $sourceResolved; backup = $destination; files = $files })
}

$manifestPath = Join-Path $backupRoot 'deployment-manifest.json'
$manifest = [ordered]@{
    kind = 'bar-controller-local-deployment-backup'; schemaVersion = 1
    timestamp = (Get-Date).ToString('o'); sourceCommit = $commit; sourceBranch = $branch
    sourceRoot = $RepositoryRoot; barDataPath = $BarDataPath; companionInstallPath = $CompanionInstallPath
    backupRoot = $backupRoot; backedUpFiles = $backupRecords; relocatedWidgetBackups = $relocatedBackups
    deployedFiles = @(); postDeploymentHashes = @(); runtimeSupportFiles = @(); widgetConfigChanged = $false; cameraSettingChanged = $false
    rollbackScript = (Join-Path $backupRoot 'Rollback-Deployment.ps1')
}
Write-JsonAtomic -Path $manifestPath -Value $manifest

Write-Step 'Validating and preserving any downloaded defaults cache.'
$cacheDefaults = Join-Path $BarDataPath 'LuaUI\Config\BARControllerSupport\controller-ui-defaults.json'
$cacheManifest = Join-Path $BarDataPath 'LuaUI\Config\BARControllerSupport\controller-ui-defaults-manifest.json'
if ((Test-Path -LiteralPath $cacheDefaults) -or (Test-Path -LiteralPath $cacheManifest)) {
    if (-not ((Test-Path -LiteralPath $cacheDefaults) -and (Test-Path -LiteralPath $cacheManifest))) { throw 'Cached defaults pair is incomplete.' }
    Invoke-NativeChecked -FilePath 'dotnet' -Arguments @('run', '--project', $publisherProject, '-c', 'Release', '--no-build', '--', 'validate', '--defaults', $cacheDefaults, '--manifest', $cacheManifest) -Label 'Existing cached defaults validation'
}

Write-Step 'Deploying widgets, runtime executables, and bundled defaults.'
$deployMap = @(
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\Widgets\gui_controller_camera_test.lua'); destination = (Join-Path $WidgetDirectory 'gui_controller_camera_test.lua') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\Widgets\gui_controller_bindings_ui.lua'); destination = (Join-Path $WidgetDirectory 'gui_controller_bindings_ui.lua') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\Widgets\gui_controller_ui_layout.lua'); destination = (Join-Path $WidgetDirectory 'gui_controller_ui_layout.lua') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\Include\controller_ui_editor_workspace.lua'); destination = (Join-Path $LuaIncludeDirectory 'controller_ui_editor_workspace.lua') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\Include\controller_ui_editor_input.lua'); destination = (Join-Path $LuaIncludeDirectory 'controller_ui_editor_input.lua') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\Include\controller_ui_shared_renderers.lua'); destination = (Join-Path $LuaIncludeDirectory 'controller_ui_shared_renderers.lua') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\Include\controller_glyphs.lua'); destination = (Join-Path $LuaIncludeDirectory 'controller_glyphs.lua') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\images\controller-glyphs\controller_glyph_atlas.png'); destination = (Join-Path $GlyphAssetDirectory 'controller_glyph_atlas.png') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\images\controller-glyphs\asset-manifest.json'); destination = (Join-Path $GlyphAssetDirectory 'asset-manifest.json') },
    [pscustomobject]@{ source = (Join-Path $RepositoryRoot 'luaui\images\controller-glyphs\LICENSE.md'); destination = (Join-Path $GlyphAssetDirectory 'LICENSE.md') },
    [pscustomobject]@{ source = $publishedBridge; destination = (Join-Path $CompanionInstallPath 'BARControllerBridge.exe') },
    [pscustomobject]@{ source = $publishedLauncher; destination = (Join-Path $CompanionInstallPath 'BARControllerLauncher.exe') },
    [pscustomobject]@{ source = $publishedRestore; destination = (Join-Path $CompanionInstallPath 'BAR_Controller_Companion_Restore_v0.6.1.exe') },
    [pscustomobject]@{ source = $sourceDefaults; destination = (Join-Path $BarDataPath 'controller-ui\shipping-defaults.json') },
    [pscustomobject]@{ source = $sourceDefaultsManifest; destination = (Join-Path $BarDataPath 'controller-ui\shipping-defaults-manifest.json') }
)
$deployedRecords = New-Object Collections.Generic.List[object]
foreach ($item in $deployMap) {
    $existed = Test-Path -LiteralPath $item.destination -PathType Leaf
    $preHash = if ($existed) { Get-Sha256 $item.destination } else { $null }
    $sourceHash = Get-Sha256 $item.source
    if ($existed -and $preHash -eq $sourceHash) {
        Write-Step ('Unchanged; preserving installed file: ' + $item.destination)
        continue
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $item.destination) -Force | Out-Null
    Copy-Item -LiteralPath $item.source -Destination $item.destination -Force
    $destinationHash = Get-Sha256 $item.destination
    if ($sourceHash -ne $destinationHash) { throw "Deployment hash mismatch: $($item.destination)" }
    $deployedRecords.Add([pscustomobject][ordered]@{ source = $item.source; destination = $item.destination; existedBefore = $existed; preSha256 = $preHash; postSha256 = $destinationHash })
}

$widgetConfigBefore = Get-Sha256 $WidgetConfigPath
$widgetConfigChanged = Enable-RequiredWidgets -ConfigPath $WidgetConfigPath -ReplacementBackupPath (Join-Path $backupRoot 'live-before\LuaUI\Config\BYAR.replace-safety.lua')
$widgetConfigAfter = Get-Sha256 $WidgetConfigPath
$cameraBefore = Get-Sha256 $SettingsPath
Invoke-NativeChecked -FilePath (Join-Path $CompanionInstallPath 'BARControllerBridge.exe') -Arguments @('--configure-only', '--settings-file', $SettingsPath) -Label 'Installed bridge camera validation'
$cameraAfter = Get-Sha256 $SettingsPath

foreach ($widgetFile in $WidgetFiles) {
    $copies = @(Get-ChildItem -LiteralPath $WidgetDirectory -Recurse -File -Force -Filter $widgetFile)
    if ($copies.Count -ne 1) { throw "Expected exactly one live $widgetFile, found $($copies.Count)." }
    Invoke-NativeChecked -FilePath 'luac' -Arguments @('-p', $copies[0].FullName) -Label ('Installed Lua parse ' + $widgetFile)
}
foreach ($supportFile in $LuaSupportFiles) {
    $installedSupport = Join-Path $LuaIncludeDirectory $supportFile
    Invoke-NativeChecked -FilePath 'luac' -Arguments @('-p', $installedSupport) -Label ('Installed Lua parse ' + $supportFile)
    if ((Get-MaxLuaUpvalues -Path $installedSupport) -gt 60) { throw "Installed $supportFile exceeds BAR upvalue limit." }
}
$installedGlyphManifest = Get-Content -Raw -Encoding UTF8 (Join-Path $GlyphAssetDirectory 'asset-manifest.json') | ConvertFrom-Json
if ($installedGlyphManifest.kind -ne 'bar-controller-original-glyph-atlas' -or @($installedGlyphManifest.glyphs).Count -lt 40) {
    throw 'Installed controller glyph asset manifest is invalid or incomplete.'
}
$installedGlyphLicense = [IO.File]::ReadAllText((Join-Path $GlyphAssetDirectory 'LICENSE.md'))
if ($installedGlyphLicense -notmatch 'original generic controller/input artwork' -or $installedGlyphLicense -notmatch 'GPL-2.0-or-later') {
    throw 'Installed controller glyph license/source declaration is incomplete.'
}
if ((Get-Item -LiteralPath (Join-Path $GlyphAssetDirectory 'controller_glyph_atlas.png')).Length -lt 1024) {
    throw 'Installed controller glyph atlas is unexpectedly small.'
}
if ((Get-MaxLuaUpvalues -Path (Join-Path $WidgetDirectory 'gui_controller_ui_layout.lua')) -gt 60) { throw 'Installed layout widget exceeds BAR upvalue limit.' }
Invoke-NativeChecked -FilePath 'dotnet' -Arguments @('run', '--project', $publisherProject, '-c', 'Release', '--no-build', '--', 'validate', '--defaults', (Join-Path $BarDataPath 'controller-ui\shipping-defaults.json'), '--manifest', (Join-Path $BarDataPath 'controller-ui\shipping-defaults-manifest.json')) -Label 'Installed defaults validation'
Invoke-NativeChecked -FilePath (Join-Path $CompanionInstallPath 'BARControllerBridge.exe') -Arguments @('help') -Label 'Installed bridge help smoke test'
Invoke-NativeChecked -FilePath (Join-Path $CompanionInstallPath 'BARControllerBridge.exe') -Arguments @('status', '--bar-data', $BarDataPath) -Label 'Installed bridge status smoke test'

$configText = [IO.File]::ReadAllText($WidgetConfigPath)
foreach ($widgetName in $RequiredWidgets) {
    $match = [regex]::Match($configText, '\["' + [regex]::Escape($widgetName) + '"\]\s*=\s*(?<order>\d+)')
    if (-not $match.Success -or [int]$match.Groups['order'].Value -le 0) { throw "Widget is not enabled: $widgetName" }
}
$launcherConfig = Get-Content -Raw -Encoding UTF8 (Join-Path $CompanionInstallPath 'launcher-config.json') | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $launcherConfig.OriginalTargetPath -PathType Leaf)) { throw 'Original BAR launch target is missing.' }
if (-not (Test-Path -LiteralPath $launcherConfig.BridgePath -PathType Leaf)) { throw 'Launcher bridge target is missing.' }
$shell = New-Object -ComObject WScript.Shell
$expectedLauncher = Join-Path $CompanionInstallPath 'BARControllerLauncher.exe'
foreach ($shortcutPath in $shortcutPaths) {
    if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) { throw "Required BAR shortcut is missing: $shortcutPath" }
    $shortcut = $shell.CreateShortcut($shortcutPath)
    if (-not [IO.Path]::GetFullPath($shortcut.TargetPath).Equals([IO.Path]::GetFullPath($expectedLauncher), [StringComparison]::OrdinalIgnoreCase)) {
        throw "Shortcut no longer targets the installed launcher: $shortcutPath"
    }
}
Assert-RuntimeStopped

$manifest.deployedFiles = $deployedRecords
$manifest.postDeploymentHashes = $deployedRecords
$manifest.runtimeSupportFiles = @($deployedRecords | Where-Object { $_.destination -like '*\LuaUI\Include\controller_*' -or $_.destination -like '*\LuaUI\Images\controller-glyphs\*' })
$manifest.widgetConfigChanged = $widgetConfigChanged
$manifest.widgetConfigPreSha256 = $widgetConfigBefore
$manifest.widgetConfigPostSha256 = $widgetConfigAfter
$manifest.cameraSettingChanged = ($cameraBefore -ne $cameraAfter)
$manifest.cameraSettingPreSha256 = $cameraBefore
$manifest.cameraSettingPostSha256 = $cameraAfter
$manifest.completedAt = (Get-Date).ToString('o')
Write-JsonAtomic -Path $manifestPath -Value $manifest

Write-Step "Deployment succeeded for $branch at $commit."
Write-Output ('Backup root: ' + $backupRoot)
Write-Output ('Rollback: powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $RepositoryRoot 'tools\dev-scripts\Rollback_v0.6.1_Live_BAR.ps1') + '" -BackupRoot "' + $backupRoot + '"')

