[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path,
    [string]$PackageArtifactsRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path 'package'),
    [string]$LegacyPackageRoot,
    [string]$PublicV060PackageRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = Join-Path $PackageArtifactsRoot 'BAR_Controller_Support_v0.6.1_Widget_Companion'
$zipPath = Join-Path $PackageArtifactsRoot 'BAR_Controller_Support_v0.6.1_Widget_Companion.zip'
$checksumPath = $zipPath + '.sha256'
if ([string]::IsNullOrWhiteSpace($LegacyPackageRoot)) {
    $LegacyPackageRoot = Join-Path $PackageArtifactsRoot 'BAR_Controller_Support_v0.5.1_Widget_Companion'
}
if ([string]::IsNullOrWhiteSpace($PublicV060PackageRoot)) {
    $PublicV060PackageRoot = Join-Path $PackageArtifactsRoot 'BAR_Controller_Support_v0.6.0_Widget_Companion'
}
$installer = Join-Path $packageRoot 'BAR_Controller_Companion_Installer_v0.6.1.exe'
$restore = Join-Path $packageRoot 'BAR_Controller_Companion_Restore_v0.6.1.exe'
$runtimeManifestPath = Join-Path $packageRoot 'frozen-runtime-manifest.json'
$testRoot = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot 'test-output\v0.6.1-release-isolated'))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot 'test-output')).TrimEnd('\') + '\'
if (-not $testRoot.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to prepare a test outside test-output: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path $testRoot | Out-Null

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-Exe([string]$Path, [string[]]$Arguments, [string]$Label) {
    & $Path @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
}

function New-FakeEnvironment([string]$Name) {
    $root = Join-Path $testRoot $Name
    $barRoot = Join-Path $root 'fake-bar'
    $barData = Join-Path $barRoot 'data'
    $config = Join-Path $barData 'LuaUI\Config\BYAR.lua'
    $widgets = Join-Path $barData 'LuaUI\Widgets'
    $install = Join-Path $root 'companion-install'
    $shortcut = Join-Path $root 'Beyond-All-Reason.lnk'
    $fakeBar = Join-Path $barRoot 'Beyond-All-Reason.exe'
    foreach ($directory in @((Split-Path -Parent $config), $widgets, $install)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    [IO.File]::WriteAllText($config, @'
return {
    allowUserWidgets = true,
    data = { ["Controller UI Layout"] = { personal = "keep" }, unrelated = { value = 17 } },
    order = {
        ["Unrelated Widget"] = 7,
        ["Controller Camera Test"] = -1,
        ["Controller Bindings UI"] = -1,
        ["Controller UI Layout"] = -1,
    },
}
'@, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $barData 'springsettings.cfg'), "OtherSetting = keep`r`nCamSpringLockCardinalDirections = 1`r`n", (New-Object Text.UTF8Encoding($false)))
    Copy-Item -LiteralPath (Join-Path $env:WINDIR 'System32\cmd.exe') -Destination $fakeBar
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcut)
    $link.TargetPath = $fakeBar; $link.Arguments = '/c exit 0'; $link.WorkingDirectory = $barRoot
    $link.IconLocation = "$fakeBar,0"; $link.Description = 'Isolated BAR test shortcut'; $link.Save()
    return [pscustomobject]@{ Root = $root; BarRoot = $barRoot; BarData = $barData; Config = $config; Widgets = $widgets;
        Settings = (Join-Path $barData 'springsettings.cfg'); Install = $install; Shortcut = $shortcut; FakeBar = $fakeBar }
}

function Assert-Installed([object]$Environment) {
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'manifest.json') | ConvertFrom-Json
    foreach ($relative in @($manifest.requiredLuaFiles) + @($manifest.requiredBarDataFiles)) {
        $destination = Join-Path $Environment.BarData ([string]$relative)
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Missing installed BAR payload: $relative" }
    }
    foreach ($relative in $manifest.requiredCompanionFiles) {
        $destination = Join-Path $Environment.Install (Split-Path -Leaf ([string]$relative))
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Missing installed companion payload: $relative" }
    }
    $configText = [IO.File]::ReadAllText($Environment.Config)
    foreach ($name in @('Controller Camera Test', 'Controller Bindings UI', 'Controller UI Layout')) {
        if ($configText -notmatch ('(?m)^\s*\["' + [regex]::Escape($name) + '"\]\s*=\s*[1-9]\d*\s*,')) {
            throw "Required widget is not enabled: $name"
        }
    }
    if ($configText -notmatch '(?m)^\s*\["Unrelated Widget"\]\s*=\s*7\s*,') { throw 'Unrelated widget order changed.' }
    if ([IO.File]::ReadAllText($Environment.Settings) -notmatch '(?m)^CamSpringLockCardinalDirections = 0(?=\r?$)') {
        throw 'Camera setting was not changed to zero.'
    }
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($Environment.Shortcut)
    $expectedLauncher = Join-Path $Environment.Install 'BARControllerLauncher.exe'
    if (-not [IO.Path]::GetFullPath([string]$link.TargetPath).Equals([IO.Path]::GetFullPath($expectedLauncher), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Shortcut does not target the installed launcher.'
    }
    if (Get-ChildItem -LiteralPath $Environment.BarData -Recurse -File | Where-Object Name -match '(?i)(spring\.exe|recoil.*\.exe)') {
        throw 'A custom engine was unexpectedly installed.'
    }
}

if (-not (Test-Path -LiteralPath $installer -PathType Leaf) -or -not (Test-Path -LiteralPath $restore -PathType Leaf)) {
    throw 'v0.6.1 package must be staged before running release tests.'
}
$runtimeManifest = Get-Content -Raw -LiteralPath $runtimeManifestPath | ConvertFrom-Json
$sourceCommit = (& git -C $WorkspaceRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]$runtimeManifest.sourceCommit -ne $sourceCommit -or [string]$runtimeManifest.version -ne '0.6.1') {
    throw 'Frozen runtime manifest does not match the tested source commit and version.'
}
foreach ($runtime in $runtimeManifest.artifacts) {
    $runtimePath = if ([string]$runtime.filename -eq 'BARControllerBridge.exe' -or [string]$runtime.filename -eq 'BARControllerLauncher.exe') {
        Join-Path $packageRoot ('companion\' + [string]$runtime.filename)
    } else {
        Join-Path $packageRoot ([string]$runtime.filename)
    }
    if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf) -or
        (Get-Item -LiteralPath $runtimePath).Length -ne [long]$runtime.size -or
        (Get-Sha256 $runtimePath) -ne [string]$runtime.sha256) {
        throw "Packaged runtime does not match its frozen manifest: $($runtime.filename)"
    }
}
$expectedZipHash = ([regex]::Match([IO.File]::ReadAllText($checksumPath), '\b[a-fA-F0-9]{64}\b').Value).ToLowerInvariant()
if ($expectedZipHash -ne (Get-Sha256 $zipPath)) { throw 'ZIP checksum sidecar mismatch.' }

$extractRoot = Join-Path $testRoot 'independent-extract'
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot
$extractedPackage = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
if (-not $extractedPackage) { throw 'Independent ZIP extraction has no package root.' }
$payload = Get-Content -Raw -LiteralPath (Join-Path $extractedPackage.FullName 'payload-sha256.json') | ConvertFrom-Json
foreach ($entry in $payload.files) {
    $candidate = Join-Path $extractedPackage.FullName ([string]$entry.path)
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "Payload entry is missing: $($entry.path)" }
    if ((Get-Item -LiteralPath $candidate).Length -ne [long]$entry.length -or (Get-Sha256 $candidate) -ne [string]$entry.sha256) {
        throw "Payload integrity mismatch: $($entry.path)"
    }
}
if (Get-ChildItem -LiteralPath $extractedPackage.FullName -Recurse -Force | Where-Object Name -match '(?i)(publisher|\.pdb$|^\.git$)') {
    throw 'Developer publisher, PDB, or Git metadata was packaged.'
}
foreach ($exeName in @('BAR_Controller_Companion_Installer_v0.6.1.exe', 'BAR_Controller_Companion_Restore_v0.6.1.exe',
    'companion\BARControllerBridge.exe', 'companion\BARControllerLauncher.exe')) {
    $version = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $extractedPackage.FullName $exeName)).FileVersion
    if ($version -ne '0.6.1.0') { throw "$exeName has unexpected file version $version" }
}

$clean = New-FakeEnvironment 'clean-install'
$personalDirectory = Join-Path $clean.BarData 'LuaUI\Config\BARControllerSupport'
New-Item -ItemType Directory -Force -Path $personalDirectory | Out-Null
$personalFiles = [ordered]@{
    (Join-Path $personalDirectory 'personal-ui-settings.json') = '{"bindings":"keep","favorites":["hints.scale"],"theme":"personal"}'
    (Join-Path $personalDirectory 'recovery-draft.json') = '{"recovery":"keep"}'
    (Join-Path $personalDirectory 'controller-ui-defaults.json') = '{"kind":"cached-personal-placeholder","revision":99}'
}
foreach ($path in $personalFiles.Keys) { [IO.File]::WriteAllText($path, $personalFiles[$path], (New-Object Text.UTF8Encoding($false))) }
$personalHashes = @{}; foreach ($path in $personalFiles.Keys) { $personalHashes[$path] = Get-Sha256 $path }
$originalConfig = [IO.File]::ReadAllText($clean.Config); $originalSettings = [IO.File]::ReadAllText($clean.Settings)
[IO.File]::WriteAllText((Join-Path $clean.Widgets 'gui_controller_camera_test.lua'), "-- original camera widget`n", (New-Object Text.UTF8Encoding($false)))
$arguments = @('--package-root', $packageRoot, '--bar-data', $clean.BarData, '--install-root', $clean.Install, '--shortcut', $clean.Shortcut, '--no-pause')
Invoke-Exe $installer $arguments 'Clean installer'
Assert-Installed $clean
foreach ($path in $personalFiles.Keys) { if ((Get-Sha256 $path) -ne $personalHashes[$path]) { throw "Personal file changed: $path" } }
$statePath = Join-Path $clean.Install 'install-state.json'
$firstState = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
$firstStateSnapshot = [pscustomobject]@{ Shortcuts = $firstState.Shortcuts.Count; Lua = $firstState.LuaWidgets.Count;
    Data = $firstState.BarDataFiles.Count; Companion = $firstState.CompanionFiles.Count;
    ShortcutBackup = [string]$firstState.Shortcuts[0].BackupPath; WidgetBackup = [string]$firstState.WidgetConfig.BackupPath }
Invoke-Exe $installer $arguments 'Idempotent second installer'
Assert-Installed $clean
$secondState = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
if ($secondState.Shortcuts.Count -ne $firstStateSnapshot.Shortcuts -or $secondState.LuaWidgets.Count -ne $firstStateSnapshot.Lua -or
    $secondState.BarDataFiles.Count -ne $firstStateSnapshot.Data -or $secondState.CompanionFiles.Count -ne $firstStateSnapshot.Companion -or
    [string]$secondState.Shortcuts[0].BackupPath -ne $firstStateSnapshot.ShortcutBackup -or [string]$secondState.WidgetConfig.BackupPath -ne $firstStateSnapshot.WidgetBackup) {
    throw 'Second install stacked backups or duplicated installed records.'
}

Invoke-Exe $restore @('--install-root', $clean.Install, '--no-pause') 'Default restore'
$shell = New-Object -ComObject WScript.Shell
$restoredLink = $shell.CreateShortcut($clean.Shortcut)
if (-not [IO.Path]::GetFullPath([string]$restoredLink.TargetPath).Equals([IO.Path]::GetFullPath($clean.FakeBar), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Shortcut target was not restored.'
}
if ([IO.File]::ReadAllText($clean.Config) -cne $originalConfig) { throw 'Widget config was not restored exactly.' }
if ([IO.File]::ReadAllText((Join-Path $clean.Widgets 'gui_controller_camera_test.lua')) -cne "-- original camera widget`n") {
    throw 'Overwritten widget was not restored.'
}
if (Test-Path -LiteralPath (Join-Path $clean.BarData 'LuaUI\Include\controller_ui_shared_renderers.lua')) {
    throw 'Newly installed Include payload was not removed by restore.'
}
if ([IO.File]::ReadAllText($clean.Settings) -notmatch '(?m)^CamSpringLockCardinalDirections = 0(?=\r?$)') {
    throw 'Default restore unexpectedly changed the recommended camera setting.'
}
Invoke-Exe $restore @('--install-root', $clean.Install, '--restore-camera', '--no-pause') 'Camera restore'
if ([IO.File]::ReadAllText($clean.Settings) -cne $originalSettings) { throw 'Camera settings were not restored exactly.' }

function Test-LegacyUpgrade([string]$LegacyVersion, [string]$LegacyRoot) {
    if (-not (Test-Path -LiteralPath $LegacyRoot -PathType Container)) {
        throw "Public v$LegacyVersion package missing: $LegacyRoot"
    }
    $legacyInstaller = Join-Path $LegacyRoot "BAR_Controller_Companion_Installer_v$LegacyVersion.exe"
    if (-not (Test-Path -LiteralPath $legacyInstaller -PathType Leaf)) {
        throw "Public v$LegacyVersion installer missing: $legacyInstaller"
    }
    $upgrade = New-FakeEnvironment "upgrade-v$LegacyVersion"
    $legacyArguments = @('--package-root', $LegacyRoot, '--bar-data', $upgrade.BarData, '--install-root', $upgrade.Install, '--shortcut', $upgrade.Shortcut, '--no-pause')
    Invoke-Exe $legacyInstaller $legacyArguments "Public v$LegacyVersion installer"
    $upgradePersonal = Join-Path $upgrade.BarData 'LuaUI\Config\BARControllerSupport\personal-ui-settings.json'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $upgradePersonal) | Out-Null
    $personalJson = '{"bindings":"v' + $LegacyVersion + '-custom","positions":{"buildRadial":[0.2,0.3]},"radialColors":{"energy":"#FEDC00"},"themes":["mine"],"favoriteColors":["#336699"],"recentColors":["#AA5500"],"presets":["compact"],"profiles":["mine"]}'
    [IO.File]::WriteAllText($upgradePersonal, $personalJson, (New-Object Text.UTF8Encoding($false)))
    $upgradeHash = Get-Sha256 $upgradePersonal
    $upgradeArguments = @('--package-root', $packageRoot, '--bar-data', $upgrade.BarData, '--install-root', $upgrade.Install, '--shortcut', $upgrade.Shortcut, '--no-pause')
    Invoke-Exe $installer $upgradeArguments "v$LegacyVersion to v0.6.1 upgrade"
    Assert-Installed $upgrade
    if ((Get-Sha256 $upgradePersonal) -ne $upgradeHash) { throw "v$LegacyVersion upgrade changed personal controller state." }
    $upgradeState = Get-Content -Raw -LiteralPath (Join-Path $upgrade.Install 'install-state.json') | ConvertFrom-Json
    if ([string]$upgradeState.Version -ne '0.6.1') { throw "v$LegacyVersion upgrade state version is not 0.6.1." }
}

Test-LegacyUpgrade '0.6.0' $PublicV060PackageRoot
Test-LegacyUpgrade '0.5.1' $LegacyPackageRoot

Write-Host 'PASS: v0.6.1 clean install, public v0.6.0/v0.5.1 upgrades, idempotency, restore, payload hashes, executable versions, and package exclusions'
Write-Host "Test root: $testRoot"
