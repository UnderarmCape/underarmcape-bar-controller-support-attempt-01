[CmdletBinding()]
param(
    [switch]$RestoreLuaWidgets,
    [switch]$RestoreCameraSetting,
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "Programs\BARControllerCompanion")
)

$ErrorActionPreference = "Stop"
$statePath = Join-Path $InstallRoot "install-state.json"

function Write-Status {
    param([string]$Message)
    Write-Host "[BAR Controller Companion Restore] $Message"
}

if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    Write-Status "Install state not found; nothing was restored: $statePath"
    exit 0
}

$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json

foreach ($shortcut in @($state.Shortcuts)) {
    if (-not $shortcut.ShortcutPath) {
        Write-Status "Skipped shortcut entry with no destination path."
        continue
    }
    if ($shortcut.BackupPath -and (Test-Path -LiteralPath $shortcut.BackupPath -PathType Leaf)) {
        $parent = Split-Path -Parent $shortcut.ShortcutPath
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        Copy-Item -LiteralPath $shortcut.BackupPath -Destination $shortcut.ShortcutPath -Force
        Write-Status "Restored shortcut: $($shortcut.ShortcutPath)"
    }
    else {
        Write-Status "Shortcut backup missing; skipped: $($shortcut.ShortcutPath)"
    }
}

if ($RestoreLuaWidgets) {
    foreach ($widget in @($state.LuaWidgets)) {
        if (-not $widget.ExistedBeforeInstall) {
            Write-Status "Widget did not exist before installation; left in place: $($widget.Destination)"
            continue
        }
        if ($widget.BackupPath -and (Test-Path -LiteralPath $widget.BackupPath -PathType Leaf)) {
            Copy-Item -LiteralPath $widget.BackupPath -Destination $widget.Destination -Force
            Write-Status "Restored Lua widget: $($widget.Destination)"
        }
        else {
            Write-Status "Lua widget backup missing; skipped: $($widget.Destination)"
        }
    }
}
else {
    Write-Status "Lua widgets were left installed. Use -RestoreLuaWidgets to restore recorded backups."
}

if ($RestoreCameraSetting) {
    $camera = $state.CameraSettings
    if ($camera -and $camera.BackupPath -and
        (Test-Path -LiteralPath $camera.BackupPath -PathType Leaf)) {
        Copy-Item -LiteralPath $camera.BackupPath -Destination $camera.SettingsPath -Force
        Write-Status "Restored springsettings.cfg from: $($camera.BackupPath)"
        Write-Status "Restart BAR for the restored camera setting to take effect."
    }
    else {
        Write-Status "No camera settings backup was recorded; skipped."
    }
}
else {
    Write-Status "Camera setting was left at CamSpringLockCardinalDirections = 0."
    Write-Status "Use -RestoreCameraSetting only if you intentionally want the recorded settings backup restored."
}

Write-Status "Restore operation complete. Installed companion files were left in place."
