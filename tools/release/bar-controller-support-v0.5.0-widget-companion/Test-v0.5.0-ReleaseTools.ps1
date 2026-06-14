[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (
        Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
    ).Path,
    [string]$WidgetConfigSource = (Join-Path $env:LOCALAPPDATA "Programs\Beyond-All-Reason\data\LuaUI\Config\BYAR.lua")
)

$ErrorActionPreference = "Stop"
$testRoot = Join-Path $WorkspaceRoot "test-output\release-tools-isolated"
$testRootFull = [System.IO.Path]::GetFullPath($testRoot)
$allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $WorkspaceRoot "test-output"))
if (-not $testRootFull.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to prepare a test outside test-output: $testRootFull"
}
if (Test-Path -LiteralPath $testRootFull) {
    Remove-Item -LiteralPath $testRootFull -Recurse -Force
}

$packageRoot = Join-Path $WorkspaceRoot "package\BAR_Controller_Companion_v0.5.0"
$installer = Join-Path $packageRoot "BAR_Controller_Companion_Installer_v0.5.0.exe"
$restore = Join-Path $packageRoot "BAR_Controller_Companion_Restore_v0.5.0.exe"
$barRoot = Join-Path $testRootFull "fake-bar"
$barData = Join-Path $barRoot "data"
$configPath = Join-Path $barData "LuaUI\Config\BYAR.lua"
$widgetsPath = Join-Path $barData "LuaUI\Widgets"
$settingsPath = Join-Path $barData "springsettings.cfg"
$installRoot = Join-Path $testRootFull "companion-install"
$shortcutPath = Join-Path $testRootFull "Beyond-All-Reason.lnk"
$fakeBarExe = Join-Path $barRoot "Beyond-All-Reason.exe"

foreach ($directory in @(
    $barRoot,
    (Split-Path -Parent $configPath),
    $widgetsPath,
    $installRoot
)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

if (-not (Test-Path -LiteralPath $WidgetConfigSource -PathType Leaf)) {
    throw "Widget config test source is missing: $WidgetConfigSource"
}
Copy-Item -LiteralPath $WidgetConfigSource -Destination $configPath
Copy-Item -LiteralPath (Join-Path $env:WINDIR "System32\cmd.exe") -Destination $fakeBarExe
[System.IO.File]::WriteAllText(
    $settingsPath,
    "OtherSetting = keep`r`nCamSpringLockCardinalDirections = 1`r`n",
    (New-Object System.Text.UTF8Encoding($false))
)
$originalWidgetText = "-- isolated original widget`nreturn false`n"
[System.IO.File]::WriteAllText(
    (Join-Path $widgetsPath "gui_controller_camera_test.lua"),
    $originalWidgetText,
    (New-Object System.Text.UTF8Encoding($false))
)

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $fakeBarExe
$shortcut.Arguments = "/c exit 0"
$shortcut.WorkingDirectory = $barRoot
$shortcut.IconLocation = "$fakeBarExe,0"
$shortcut.Description = "Isolated BAR test shortcut"
$shortcut.Save()

$originalConfig = Get-Content -Raw -LiteralPath $configPath
$originalSettings = Get-Content -Raw -LiteralPath $settingsPath
$expectedConfig = $originalConfig
foreach ($name in @("Controller Camera Test", "Controller Bindings UI")) {
    $pattern = '(?m)^(?<indent>[ \t]*)\["' + [regex]::Escape($name) + '"\][ \t]*=[ \t]*-?\d+[ \t]*,?[ \t]*(?=\r?$)'
    $expectedConfig = [regex]::Replace(
        $expectedConfig,
        $pattern,
        { param($match) $match.Groups["indent"].Value + '["' + $name + '"] = 1,' }
    )
}

$installArguments = @(
    "--package-root", $packageRoot,
    "--bar-data", $barData,
    "--install-root", $installRoot,
    "--shortcut", $shortcutPath,
    "--no-pause"
)
& $installer @installArguments
if ($LASTEXITCODE -ne 0) {
    throw "First isolated installer run failed with exit code $LASTEXITCODE."
}

$installedConfig = Get-Content -Raw -LiteralPath $configPath
if ($installedConfig -cne $expectedConfig) {
    throw "Widget config changed outside the two exact required widget entries."
}
foreach ($name in @("Controller Camera Test", "Controller Bindings UI")) {
    if ($installedConfig -notmatch ('(?m)^\s*\["' + [regex]::Escape($name) + '"\]\s*=\s*[1-9]\d*\s*,')) {
        throw "Required widget was not enabled: $name"
    }
}
if ((Get-Content -Raw -LiteralPath $settingsPath) -notmatch '(?m)^CamSpringLockCardinalDirections = 0(?=\r?$)') {
    throw "Camera setting was not changed to 0."
}

$patchedShortcut = $shell.CreateShortcut($shortcutPath)
$launcherPath = Join-Path $installRoot "BARControllerLauncher.exe"
if ([System.IO.Path]::GetFullPath([string]$patchedShortcut.TargetPath) -ne
    [System.IO.Path]::GetFullPath($launcherPath)) {
    throw "Shortcut was not patched to the installed launcher."
}
$firstState = Get-Content -Raw -LiteralPath (Join-Path $installRoot "install-state.json") |
    ConvertFrom-Json
$firstShortcutBackup = [string]$firstState.Shortcuts[0].BackupPath
$firstConfigBackup = [string]$firstState.WidgetConfig.BackupPath

& $installer @installArguments
if ($LASTEXITCODE -ne 0) {
    throw "Second isolated installer run failed with exit code $LASTEXITCODE."
}
$secondState = Get-Content -Raw -LiteralPath (Join-Path $installRoot "install-state.json") |
    ConvertFrom-Json
if ($secondState.Shortcuts.Count -ne 1 -or
    [string]$secondState.Shortcuts[0].BackupPath -ne $firstShortcutBackup -or
    [string]$secondState.WidgetConfig.BackupPath -ne $firstConfigBackup) {
    throw "Second installer run stacked or replaced first-install backups."
}

& $restore --install-root $installRoot --no-pause
if ($LASTEXITCODE -ne 0) {
    throw "Default isolated restore failed with exit code $LASTEXITCODE."
}
$restoredShortcut = $shell.CreateShortcut($shortcutPath)
if ([System.IO.Path]::GetFullPath([string]$restoredShortcut.TargetPath) -ne
    [System.IO.Path]::GetFullPath($fakeBarExe)) {
    throw "Shortcut target was not restored."
}
if ((Get-Content -Raw -LiteralPath $configPath) -cne $originalConfig) {
    throw "Widget config was not restored exactly."
}
if ((Get-Content -Raw -LiteralPath (Join-Path $widgetsPath "gui_controller_camera_test.lua")) -cne
    $originalWidgetText) {
    throw "Overwritten widget was not restored."
}
if ((Get-Content -Raw -LiteralPath $settingsPath) -notmatch '(?m)^CamSpringLockCardinalDirections = 0(?=\r?$)') {
    throw "Default restore unexpectedly changed the camera setting."
}

& $restore --install-root $installRoot --restore-camera --no-pause
if ($LASTEXITCODE -ne 0) {
    throw "Camera restore failed with exit code $LASTEXITCODE."
}
if ((Get-Content -Raw -LiteralPath $settingsPath) -cne $originalSettings) {
    throw "Camera settings backup was not restored exactly."
}

Write-Host "PASS: isolated installer and restore validation"
Write-Host "Test root: $testRootFull"
