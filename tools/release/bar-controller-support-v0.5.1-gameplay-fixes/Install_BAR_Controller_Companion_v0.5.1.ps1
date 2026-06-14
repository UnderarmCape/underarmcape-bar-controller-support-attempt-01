[CmdletBinding()]
param(
    [switch]$CheckForUpdates,
    [string]$BarDataPath = (Join-Path $env:LOCALAPPDATA "Programs\Beyond-All-Reason\data"),
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "Programs\BARControllerCompanion"),
    [string[]]$ShortcutPaths = @(
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Beyond-All-Reason.lnk"),
        (Join-Path ([Environment]::GetFolderPath("Desktop")) "Beyond-All-Reason.lnk")
    )
)

$ErrorActionPreference = "Stop"
$BundledPackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$OfficialRepository = "UnderarmCape/underarmcape-bar-controller-support-attempt-01"
$ExpectedPackageName = "BAR Controller Companion"
$CameraSettingName = "CamSpringLockCardinalDirections"
$CameraSettingLine = "$CameraSettingName = 0"
$TemporaryUpdateRoot = $null

function Write-Status {
    param([string]$Message)
    Write-Host "[BAR Controller Companion] $Message"
}

function Read-PackageManifest {
    param([string]$PackageRoot)

    $manifestPath = Join-Path $PackageRoot "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Package manifest is missing: $manifestPath"
    }

    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ($manifest.packageName -ne $ExpectedPackageName) {
        throw "Unexpected package name in manifest: $($manifest.packageName)"
    }

    $required = @($manifest.requiredLuaFiles) + @($manifest.requiredCompanionFiles)
    foreach ($relativePath in $required) {
        $candidate = Join-Path $PackageRoot ([string]$relativePath)
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "Required package file is missing: $relativePath"
        }
    }

    return $manifest
}

function Select-PackageSource {
    param(
        [string]$LocalPackageRoot,
        [object]$LocalManifest
    )

    if (-not $CheckForUpdates) {
        Write-Status "Using bundled local package v$($LocalManifest.version)."
        return $LocalPackageRoot
    }

    try {
        Write-Status "Checking the official GitHub repository for a newer package..."
        $headers = @{
            "User-Agent" = "BAR-Controller-Companion-Installer"
            "Accept" = "application/vnd.github+json"
        }
        $release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/$OfficialRepository/releases/latest" `
            -Headers $headers `
            -Method Get `
            -TimeoutSec 15

        $asset = @($release.assets) |
            Where-Object { $_.name -like "BAR_Controller_Support_v*_Widget_Companion.zip" } |
            Select-Object -First 1
        if (-not $asset) {
            $asset = @($release.assets) |
                Where-Object { $_.name -like "BAR_Controller_Companion_v*.zip" } |
                Select-Object -First 1
        }
        if (-not $asset) {
            Write-Status "No compatible versioned release asset was found; using bundled files."
            return $LocalPackageRoot
        }

        $assetVersionText = [regex]::Match(
            [string]$asset.name,
            "(?:BAR_Controller_Support_v|BAR_Controller_Companion_v)" +
                "(?<version>\d+\.\d+\.\d+)" +
                "(?:_Widget_Companion)?\.zip"
        ).Groups["version"].Value
        if (-not $assetVersionText) {
            Write-Status "The release asset version could not be read; using bundled files."
            return $LocalPackageRoot
        }

        $localVersion = [version]$LocalManifest.version
        $assetVersion = [version]$assetVersionText
        if ($assetVersion -le $localVersion) {
            Write-Status "Bundled package v$localVersion is current."
            return $LocalPackageRoot
        }

        $answer = Read-Host "A newer BAR Controller Companion package is available. Download and install it? [y/N]"
        if ($answer -notmatch "^(?i:y|yes)$") {
            Write-Status "Using bundled local package v$localVersion."
            return $LocalPackageRoot
        }

        $script:TemporaryUpdateRoot = Join-Path `
            ([System.IO.Path]::GetTempPath()) `
            ("BARControllerCompanion-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $script:TemporaryUpdateRoot | Out-Null
        $zipPath = Join-Path $script:TemporaryUpdateRoot $asset.name
        Invoke-WebRequest `
            -Uri $asset.browser_download_url `
            -Headers $headers `
            -OutFile $zipPath `
            -TimeoutSec 60 `
            -UseBasicParsing

        $extractPath = Join-Path $script:TemporaryUpdateRoot "extracted"
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
        $onlineManifestPath = Get-ChildItem `
            -LiteralPath $extractPath `
            -Filter "manifest.json" `
            -File `
            -Recurse |
            Select-Object -First 1
        if (-not $onlineManifestPath) {
            throw "Downloaded package does not contain manifest.json."
        }

        $onlineRoot = Split-Path -Parent $onlineManifestPath.FullName
        $onlineManifest = Read-PackageManifest -PackageRoot $onlineRoot
        if ([version]$onlineManifest.version -ne $assetVersion) {
            throw "Downloaded package version does not match its asset name."
        }

        Write-Status "Validated downloaded package v$($onlineManifest.version)."
        return $onlineRoot
    }
    catch {
        Write-Warning "Online package check failed: $($_.Exception.Message)"
        Write-Status "Falling back to bundled local files."
        return $LocalPackageRoot
    }
}

function New-InstallState {
    param([string]$Version)
    return [ordered]@{
        Version = $Version
        LastInstalled = $null
        Shortcuts = @()
        LuaWidgets = @()
        CameraSettings = $null
    }
}

function Read-InstallState {
    param(
        [string]$StatePath,
        [string]$Version
    )

    $state = New-InstallState -Version $Version
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
        return $state
    }

    try {
        $existing = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
        $state.Version = $Version
        $state.LastInstalled = $existing.LastInstalled
        $state.Shortcuts = @($existing.Shortcuts)
        $state.LuaWidgets = @($existing.LuaWidgets)
        $state.CameraSettings = $existing.CameraSettings
    }
    catch {
        Write-Warning "Existing install state could not be read; new state will be written."
    }
    return $state
}

function Save-InstallState {
    param(
        [object]$State,
        [string]$StatePath
    )
    $State.LastInstalled = (Get-Date).ToString("o")
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Ensure-CameraSetting {
    param(
        [string]$SettingsPath,
        [object]$State
    )

    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        Write-Status "Failed to find settings file: $SettingsPath"
        return
    }

    $content = Get-Content -Raw -LiteralPath $SettingsPath
    $pattern = "(?im)^[ \t]*CamSpringLockCardinalDirections[ \t]*=[ \t]*(?<value>[^\r\n]*?)[ \t]*(?=\r?$)"
    $matches = [regex]::Matches($content, $pattern)
    $alreadyOk = $matches.Count -gt 0
    foreach ($match in $matches) {
        if ($match.Groups["value"].Value.Trim() -ne "0") {
            $alreadyOk = $false
            break
        }
    }
    if ($alreadyOk) {
        Write-Status "Camera setting already OK: $CameraSettingLine"
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $backupPath = "$SettingsPath.bar-controller-backup-$timestamp"
    Copy-Item -LiteralPath $SettingsPath -Destination $backupPath
    if (-not $State.CameraSettings) {
        $State.CameraSettings = [pscustomobject]@{
            SettingsPath = $SettingsPath
            BackupPath = $backupPath
        }
    }

    if ($matches.Count -eq 0) {
        $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
        $separator = if ($content.Length -eq 0 -or $content.EndsWith("`n")) { "" } else { $newline }
        [System.IO.File]::WriteAllText(
            $SettingsPath,
            $content + $separator + $CameraSettingLine + $newline,
            (New-Object System.Text.UTF8Encoding($false))
        )
        Write-Status "Added missing camera setting: $CameraSettingLine"
    }
    else {
        $updated = [regex]::Replace($content, $pattern, $CameraSettingLine)
        [System.IO.File]::WriteAllText(
            $SettingsPath,
            $updated,
            (New-Object System.Text.UTF8Encoding($false))
        )
        Write-Status "Changed existing camera setting: $CameraSettingLine"
    }
    Write-Status "Camera settings backup: $backupPath"
}

function Install-LuaWidgets {
    param(
        [string]$PackageRoot,
        [object]$Manifest,
        [string]$DestinationRoot,
        [string]$BackupRoot,
        [object]$State
    )

    New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null
    foreach ($relativePath in @($Manifest.requiredLuaFiles)) {
        $source = Join-Path $PackageRoot ([string]$relativePath)
        $destination = Join-Path $DestinationRoot ([System.IO.Path]::GetFileName($relativePath))
        $existingState = @($State.LuaWidgets) |
            Where-Object { $_.Destination -eq $destination } |
            Select-Object -First 1

        if (-not $existingState) {
            $existed = Test-Path -LiteralPath $destination -PathType Leaf
            $backupPath = $null
            if ($existed) {
                $widgetBackupRoot = Join-Path $BackupRoot "LuaUI\Widgets"
                New-Item -ItemType Directory -Force -Path $widgetBackupRoot | Out-Null
                $backupPath = Join-Path $widgetBackupRoot ([System.IO.Path]::GetFileName($destination))
                Copy-Item -LiteralPath $destination -Destination $backupPath
            }
            $State.LuaWidgets = @($State.LuaWidgets) + [pscustomobject]@{
                Destination = $destination
                BackupPath = $backupPath
                ExistedBeforeInstall = $existed
            }
        }

        Copy-Item -LiteralPath $source -Destination $destination -Force
        Write-Status "Installed Lua widget: $destination"
    }
}

function Test-IsBarShortcutTarget {
    param([string]$TargetPath)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        return $false
    }
    return $TargetPath -match "(?i)Beyond-All-Reason"
}

function Get-DefaultLaunchMetadata {
    $target = Join-Path `
        $env:LOCALAPPDATA `
        "Programs\Beyond-All-Reason\Beyond-All-Reason.exe"
    return [pscustomobject]@{
        TargetPath = $target
        Arguments = ""
        WorkingDirectory = Split-Path -Parent $target
        IconLocation = "$target,0"
    }
}

function Install-Shortcuts {
    param(
        [string[]]$Paths,
        [string]$LauncherPath,
        [string]$BridgePath,
        [string]$SettingsPath,
        [string]$BackupRoot,
        [string]$ConfigPath,
        [object]$State
    )

    $shell = New-Object -ComObject WScript.Shell
    $launchMetadata = $null
    if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
        try {
            $existingConfig = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
            $launchMetadata = [pscustomobject]@{
                TargetPath = $existingConfig.OriginalTargetPath
                Arguments = $existingConfig.OriginalArguments
                WorkingDirectory = $existingConfig.OriginalWorkingDirectory
                IconLocation = $existingConfig.OriginalIconLocation
            }
        }
        catch {
            Write-Warning "Existing launcher config could not be read and will be rebuilt."
        }
    }

    foreach ($shortcutPath in $Paths) {
        if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
            Write-Status "Shortcut not found; skipped: $shortcutPath"
            continue
        }

        $shortcut = $shell.CreateShortcut($shortcutPath)
        $targetPath = [string]$shortcut.TargetPath
        if (-not [string]::IsNullOrWhiteSpace($targetPath) -and
            [System.IO.Path]::GetFullPath($targetPath) -eq [System.IO.Path]::GetFullPath($LauncherPath)) {
            Write-Status "Shortcut already patched: $shortcutPath"
            continue
        }
        if (-not (Test-IsBarShortcutTarget -TargetPath $targetPath)) {
            Write-Warning "Shortcut does not appear to point to BAR; skipped: $shortcutPath -> $targetPath"
            continue
        }

        if (-not $launchMetadata) {
            $launchMetadata = [pscustomobject]@{
                TargetPath = $targetPath
                Arguments = [string]$shortcut.Arguments
                WorkingDirectory = [string]$shortcut.WorkingDirectory
                IconLocation = [string]$shortcut.IconLocation
            }
        }

        $stateEntry = @($State.Shortcuts) |
            Where-Object { $_.ShortcutPath -eq $shortcutPath } |
            Select-Object -First 1
        if (-not $stateEntry) {
            $shortcutBackupRoot = Join-Path $BackupRoot "Shortcuts"
            New-Item -ItemType Directory -Force -Path $shortcutBackupRoot | Out-Null
            $safeName = ([System.IO.Path]::GetFileNameWithoutExtension($shortcutPath) -replace "[^A-Za-z0-9_.-]", "_")
            $backupPath = Join-Path $shortcutBackupRoot ($safeName + "-" + [guid]::NewGuid().ToString("N") + ".lnk")
            Copy-Item -LiteralPath $shortcutPath -Destination $backupPath
            $State.Shortcuts = @($State.Shortcuts) + [pscustomobject]@{
                ShortcutPath = $shortcutPath
                BackupPath = $backupPath
                OriginalTargetPath = $targetPath
                OriginalArguments = [string]$shortcut.Arguments
                OriginalWorkingDirectory = [string]$shortcut.WorkingDirectory
                OriginalIconLocation = [string]$shortcut.IconLocation
                OriginalDescription = [string]$shortcut.Description
            }
        }

        $originalIcon = [string]$shortcut.IconLocation
        $originalDescription = [string]$shortcut.Description
        $shortcut.TargetPath = $LauncherPath
        $shortcut.Arguments = ""
        $shortcut.WorkingDirectory = Split-Path -Parent $LauncherPath
        if (-not [string]::IsNullOrWhiteSpace($originalIcon)) {
            $shortcut.IconLocation = $originalIcon
        }
        $shortcut.Description = $originalDescription
        $shortcut.Save()
        Write-Status "Patched BAR shortcut: $shortcutPath"
    }

    if (-not $launchMetadata) {
        $launchMetadata = Get-DefaultLaunchMetadata
        Write-Status "No readable BAR shortcut metadata was found; using the standard BAR launcher path."
    }

    $launcherConfig = [ordered]@{
        OriginalTargetPath = [string]$launchMetadata.TargetPath
        OriginalArguments = [string]$launchMetadata.Arguments
        OriginalWorkingDirectory = [string]$launchMetadata.WorkingDirectory
        OriginalIconLocation = [string]$launchMetadata.IconLocation
        BridgePath = $BridgePath
        SettingsPath = $SettingsPath
        BridgeStartupDelayMilliseconds = 900
    }
    $launcherConfig | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    Write-Status "Wrote launcher config: $ConfigPath"
}

try {
    $localManifest = Read-PackageManifest -PackageRoot $BundledPackageRoot
    $PackageRoot = Select-PackageSource `
        -LocalPackageRoot $BundledPackageRoot `
        -LocalManifest $localManifest
    $manifest = Read-PackageManifest -PackageRoot $PackageRoot

    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $backupRoot = Join-Path $InstallRoot "backups\$timestamp"
    $statePath = Join-Path $InstallRoot "install-state.json"
    $state = Read-InstallState -StatePath $statePath -Version ([string]$manifest.version)

    foreach ($relativePath in @($manifest.requiredCompanionFiles)) {
        $source = Join-Path $PackageRoot ([string]$relativePath)
        $destination = Join-Path $InstallRoot ([System.IO.Path]::GetFileName($relativePath))
        Copy-Item -LiteralPath $source -Destination $destination -Force
        Write-Status "Installed companion file: $destination"
    }

    foreach ($supportFile in @(
        "Restore_BAR_Controller_Companion_v0.5.1.ps1",
        "manifest.json"
    )) {
        $source = Join-Path $PackageRoot $supportFile
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $InstallRoot $supportFile) -Force
        }
    }

    $widgetsPath = Join-Path $BarDataPath "LuaUI\Widgets"
    Install-LuaWidgets `
        -PackageRoot $PackageRoot `
        -Manifest $manifest `
        -DestinationRoot $widgetsPath `
        -BackupRoot $backupRoot `
        -State $state

    Ensure-CameraSetting `
        -SettingsPath (Join-Path $BarDataPath "springsettings.cfg") `
        -State $state

    $launcherPath = Join-Path $InstallRoot "BARControllerLauncher.exe"
    $bridgePath = Join-Path $InstallRoot "BARControllerBridge.exe"
    $configPath = Join-Path $InstallRoot "launcher-config.json"
    Install-Shortcuts `
        -Paths $ShortcutPaths `
        -LauncherPath $launcherPath `
        -BridgePath $bridgePath `
        -SettingsPath (Join-Path $BarDataPath "springsettings.cfg") `
        -BackupRoot $backupRoot `
        -ConfigPath $configPath `
        -State $state

    Save-InstallState -State $state -StatePath $statePath
    Write-Status "Installation complete. BAR was not launched."
    Write-Status "Use the normal Beyond-All-Reason shortcut; it now starts the bridge minimized first."
}
finally {
    if ($TemporaryUpdateRoot -and (Test-Path -LiteralPath $TemporaryUpdateRoot)) {
        Remove-Item -LiteralPath $TemporaryUpdateRoot -Recurse -Force
    }
}
