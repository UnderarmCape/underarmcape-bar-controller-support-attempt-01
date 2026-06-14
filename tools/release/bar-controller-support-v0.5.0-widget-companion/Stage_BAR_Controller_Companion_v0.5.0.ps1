[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (
        Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
    ).Path
)

$ErrorActionPreference = "Stop"
$packageRoot = Join-Path $WorkspaceRoot "package"
$target = Join-Path $packageRoot "BAR_Controller_Companion_v0.5.0"
$zipPath = Join-Path $packageRoot "BAR_Controller_Support_v0.5.0_Widget_Companion.zip"
$checksumPath = "$zipPath.sha256"
$legacyZipPath = Join-Path $packageRoot "BAR_Controller_Companion_v0.5.0.zip"
$legacyChecksumPath = "$legacyZipPath.sha256"
$targetFullPath = [System.IO.Path]::GetFullPath($target)
$packageFullPath = [System.IO.Path]::GetFullPath($packageRoot)

if (-not $targetFullPath.StartsWith($packageFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to stage outside the workspace package directory: $targetFullPath"
}

if (Test-Path -LiteralPath $targetFullPath) {
    Remove-Item -LiteralPath $targetFullPath -Recurse -Force
}

$directories = @(
    $targetFullPath,
    (Join-Path $targetFullPath "companion"),
    (Join-Path $targetFullPath "luaui\Widgets"),
    (Join-Path $targetFullPath "docs"),
    (Join-Path $targetFullPath "tools\dev-scripts")
)
foreach ($directory in $directories) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$copies = [ordered]@{
    (Join-Path $WorkspaceRoot "tools\controller-companion\publish\installer\BAR_Controller_Companion_Installer_v0.5.0.exe") =
        (Join-Path $targetFullPath "BAR_Controller_Companion_Installer_v0.5.0.exe")
    (Join-Path $WorkspaceRoot "tools\controller-companion\publish\restore\BAR_Controller_Companion_Restore_v0.5.0.exe") =
        (Join-Path $targetFullPath "BAR_Controller_Companion_Restore_v0.5.0.exe")
    (Join-Path $PSScriptRoot "Install_BAR_Controller_Companion_v0.5.0.ps1") =
        (Join-Path $targetFullPath "tools\dev-scripts\Install_BAR_Controller_Companion_v0.5.0.ps1")
    (Join-Path $PSScriptRoot "Restore_BAR_Controller_Companion_v0.5.0.ps1") =
        (Join-Path $targetFullPath "tools\dev-scripts\Restore_BAR_Controller_Companion_v0.5.0.ps1")
    (Join-Path $PSScriptRoot "manifest.json") =
        (Join-Path $targetFullPath "manifest.json")
    (Join-Path $WorkspaceRoot "tools\controller-companion\publish\bridge\BARControllerBridge.exe") =
        (Join-Path $targetFullPath "companion\BARControllerBridge.exe")
    (Join-Path $WorkspaceRoot "tools\controller-companion\publish\launcher\BARControllerLauncher.exe") =
        (Join-Path $targetFullPath "companion\BARControllerLauncher.exe")
    (Join-Path $WorkspaceRoot "doc\controller-companion-v0.5.0\README.md") =
        (Join-Path $targetFullPath "docs\README.md")
    (Join-Path $WorkspaceRoot "doc\controller-companion-v0.5.0\RELEASE_NOTES_v0.5.0.md") =
        (Join-Path $targetFullPath "docs\RELEASE_NOTES_v0.5.0.md")
    (Join-Path $WorkspaceRoot "doc\controller-companion-v0.5.0\PACKAGE_INVENTORY_v0.5.0.md") =
        (Join-Path $targetFullPath "docs\PACKAGE_INVENTORY_v0.5.0.md")
    (Join-Path $WorkspaceRoot "doc\controller-companion-v0.5.0\VALIDATION_NOTES_v0.5.0.md") =
        (Join-Path $targetFullPath "docs\v0.5.0-companion-bridge-poc.md")
}

$widgetNames = @(
    "controller_socket_bridge.lua",
    "gui_controller_camera_test.lua",
    "gui_pregameui.lua",
    "cmd_area_mex.lua",
    "gui_controller_bindings_ui.lua",
    "gui_controller_smartx_mouse_audit.lua"
)
foreach ($widgetName in $widgetNames) {
    $copies[(Join-Path $WorkspaceRoot "luaui\Widgets\$widgetName")] =
        (Join-Path $targetFullPath "luaui\Widgets\$widgetName")
}

foreach ($source in $copies.Keys) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Staging source is missing: $source"
    }
    Copy-Item -LiteralPath $source -Destination $copies[$source] -Force
}

$manifest = Get-Content -Raw -LiteralPath (Join-Path $targetFullPath "manifest.json") |
    ConvertFrom-Json
$required = @($manifest.requiredPublicFiles) +
    @($manifest.requiredLuaFiles) +
    @($manifest.requiredCompanionFiles)
foreach ($relativePath in $required) {
    $candidate = Join-Path $targetFullPath ([string]$relativePath)
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Staged package validation failed; missing: $relativePath"
    }
}

foreach ($artifact in @($zipPath, $checksumPath, $legacyZipPath, $legacyChecksumPath)) {
    if (Test-Path -LiteralPath $artifact) {
        Remove-Item -LiteralPath $artifact -Force
    }
}
Compress-Archive -LiteralPath $targetFullPath -DestinationPath $zipPath -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([System.IO.Path]::GetFileName($zipPath))" |
    Set-Content -LiteralPath $checksumPath -Encoding ASCII

Write-Host "Staged BAR Controller Companion package:"
Write-Host $targetFullPath
Write-Host "Created zip:"
Write-Host $zipPath
Write-Host "SHA256: $hash"
