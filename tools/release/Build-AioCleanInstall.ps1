[CmdletBinding()]
param(
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path

$ReleaseTag = 'controller-support-v0.4.3-queue-polish-aio-clean-install'
$AioZipName = 'BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.zip'
$InstallerName = 'Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat'
$ReadmeName = 'README_AIO_CLEAN_INSTALL.txt'

$EngineRepo = 'UnderarmCape/controllersupport-RecoilEngine-attempt-01'
$EngineReleaseTag = 'controller-support-recoil-2025-06-24-compat'
$EngineAssetName = 'recoil_2025.06.24-controller-support-pr2985-win64.zip'

$ControllerTag = 'controller-support-v0.4.3-queue-polish'
$OfficialBarRepo = 'https://github.com/beyond-all-reason/Beyond-All-Reason.git'
$PreferredBarCommit = 'c79bc770f57788a58e7700bcbc3d5aa1406cc8fb'

$LuaWidgetPaths = @(
    'luaui/Widgets/camera_joystick.lua',
    'luaui/Widgets/gui_controller_bindings_ui.lua',
    'luaui/Widgets/gui_controller_camera_test.lua',
    'luaui/Widgets/gui_controller_smartx_mouse_audit.lua',
    'luaui/Widgets/gui_controller_test.lua'
)

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $RepoRoot 'build\dist'
}

$WorkRoot = Join-Path $RepoRoot 'build\aio-clean-install'
$StageRoot = Join-Path $WorkRoot 'stage'
$PayloadRoot = Join-Path $StageRoot 'payload'
$EnginePayload = Join-Path $PayloadRoot 'engine'
$BarPayload = Join-Path $PayloadRoot 'bar_sdd'
$LuaPayload = Join-Path $PayloadRoot 'lua_widgets'
$BarSource = Join-Path $WorkRoot 'official-bar-source'
$WidgetExtract = Join-Path $WorkRoot 'widgets-from-tag'
$WidgetArchive = Join-Path $WorkRoot 'widgets-from-tag.zip'
$BarZipName = "BAR_sdd_official_$($PreferredBarCommit.Substring(0, 12))_clean.zip"
$BarZipPath = Join-Path $BarPayload $BarZipName
$AioZipPath = Join-Path $OutputDirectory $AioZipName
$MetadataPath = Join-Path $OutputDirectory 'BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.build-metadata.json'

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingDirectory = $RepoRoot
    )

    Push-Location $WorkingDirectory
    try {
        Write-Host ">> $FilePath $($Arguments -join ' ')"
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
        }
    }
    finally {
        Pop-Location
    }
}

function Remove-DirectorySafe {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRepo = [System.IO.Path]::GetFullPath($RepoRoot)
    if (-not $fullPath.StartsWith($fullRepo, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a directory outside the repository: $fullPath"
    }

    Remove-Item -LiteralPath $fullPath -Recurse -Force
}

function New-ZipFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$ZipPath,
        [string[]]$ExcludeRegex = @()
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    $zipDir = Split-Path -Parent $ZipPath
    if (-not (Test-Path -LiteralPath $zipDir)) {
        New-Item -ItemType Directory -Path $zipDir -Force | Out-Null
    }

    $sourceFull = [System.IO.Path]::GetFullPath($SourceDirectory).TrimEnd([char[]]@('\', '/'))
    $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = Get-ChildItem -LiteralPath $sourceFull -Recurse -File -Force
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($sourceFull.Length).TrimStart([char[]]@('\', '/'))
            $entryName = $relative -replace '\\', '/'
            $skip = $false
            foreach ($regex in $ExcludeRegex) {
                if ($entryName -match $regex) {
                    $skip = $true
                    break
                }
            }
            if ($skip) {
                continue
            }

            $level = [System.IO.Compression.CompressionLevel]::Optimal
            if ($file.Extension -ieq '.zip' -and [Enum]::GetNames([System.IO.Compression.CompressionLevel]) -contains 'NoCompression') {
                $level = [System.IO.Compression.CompressionLevel]::NoCompression
            }
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName, $level) | Out-Null
        }
    }
    finally {
        $zip.Dispose()
    }
}

function Get-GitOutput {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingDirectory = $RepoRoot
    )

    Push-Location $WorkingDirectory
    try {
        $output = & git @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
        }
        return ($output -join "`n").Trim()
    }
    finally {
        Pop-Location
    }
}

Write-Host "Building $AioZipName"
Write-Host "Repository root: $RepoRoot"

Remove-DirectorySafe -Path $WorkRoot
New-Item -ItemType Directory -Path $EnginePayload, $BarPayload, $LuaPayload, $OutputDirectory -Force | Out-Null

$installerText = Get-Content -LiteralPath (Join-Path $RepoRoot $InstallerName) -Raw
$installerText = $installerText -replace "`r?`n", "`r`n"
Set-Content -LiteralPath (Join-Path $StageRoot $InstallerName) -Value $installerText -NoNewline -Encoding ASCII
Copy-Item -LiteralPath (Join-Path $RepoRoot $ReadmeName) -Destination (Join-Path $StageRoot $ReadmeName) -Force

Write-Host "Downloading stable controller engine payload..."
Invoke-External gh @(
    'release', 'download', $EngineReleaseTag,
    '--repo', $EngineRepo,
    '--pattern', $EngineAssetName,
    '--dir', $EnginePayload,
    '--clobber'
)
$engineZips = @(Get-ChildItem -LiteralPath $EnginePayload -Filter '*.zip' -File)
if ($engineZips.Count -ne 1) {
    throw "Expected exactly one engine ZIP after download, found $($engineZips.Count)."
}

Write-Host "Extracting v0.4.3 Queue Polish LuaUI widgets from tag $ControllerTag..."
if (Test-Path -LiteralPath $WidgetArchive) {
    Remove-Item -LiteralPath $WidgetArchive -Force
}
Invoke-External git (@('archive', '--format=zip', '-o', $WidgetArchive, $ControllerTag) + $LuaWidgetPaths)
Expand-Archive -LiteralPath $WidgetArchive -DestinationPath $WidgetExtract -Force
foreach ($widgetPath in $LuaWidgetPaths) {
    $source = Join-Path $WidgetExtract $widgetPath
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing expected widget from tag ${ControllerTag}: $widgetPath"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $LuaPayload (Split-Path -Leaf $widgetPath)) -Force
}

Write-Host "Cloning official BAR.sdd source from $OfficialBarRepo..."
Invoke-External git @('clone', '--filter=blob:none', '--no-checkout', $OfficialBarRepo, $BarSource)

$BarCommitUsed = $null
$BarCommitSource = $null
try {
    Invoke-External git @('fetch', '--depth=1', 'origin', $PreferredBarCommit) $BarSource
    Invoke-External git @('-c', 'advice.detachedHead=false', 'checkout', '--force', $PreferredBarCommit) $BarSource
    $BarCommitUsed = Get-GitOutput @('rev-parse', 'HEAD') $BarSource
    $BarCommitSource = 'preferred'
}
catch {
    Write-Warning "Preferred BAR.sdd commit was not accessible: $($_.Exception.Message)"
    Write-Warning "Falling back to the official repository default branch HEAD."
    Invoke-External git @('fetch', '--depth=1', 'origin', 'HEAD') $BarSource
    Invoke-External git @('-c', 'advice.detachedHead=false', 'checkout', '--force', 'FETCH_HEAD') $BarSource
    $BarCommitUsed = Get-GitOutput @('rev-parse', 'HEAD') $BarSource
    $BarCommitSource = 'official-default-head'
}

try {
    Invoke-External git @('submodule', 'update', '--init', '--recursive', '--depth=1') $BarSource
}
catch {
    Write-Warning "Depth-limited submodule update failed; retrying without --depth."
    Invoke-External git @('submodule', 'update', '--init', '--recursive') $BarSource
}

if (-not (Test-Path -LiteralPath (Join-Path $BarSource 'modinfo.lua'))) {
    throw "Official BAR.sdd source is missing modinfo.lua."
}
if (-not (Test-Path -LiteralPath (Join-Path $BarSource 'luaui'))) {
    throw "Official BAR.sdd source is missing luaui."
}

Write-Host "Packaging clean official BAR.sdd payload ZIP..."
New-ZipFromDirectory -SourceDirectory $BarSource -ZipPath $BarZipPath -ExcludeRegex @('(^|/)\.git(/|$)')

$barZips = @(Get-ChildItem -LiteralPath $BarPayload -Filter '*.zip' -File)
if ($barZips.Count -ne 1) {
    throw "Expected exactly one BAR.sdd ZIP after packaging, found $($barZips.Count)."
}

Write-Host "Creating final AIO ZIP..."
if (Test-Path -LiteralPath $AioZipPath) {
    Remove-Item -LiteralPath $AioZipPath -Force
}
New-ZipFromDirectory -SourceDirectory $StageRoot -ZipPath $AioZipPath -ExcludeRegex @('(^|/)\.git(/|$)')

$metadata = [ordered]@{
    releaseTag = $ReleaseTag
    aioZipPath = $AioZipPath
    engineRepo = $EngineRepo
    engineReleaseTag = $EngineReleaseTag
    enginePayloadZip = $engineZips[0].Name
    officialBarRepo = $OfficialBarRepo
    preferredBarCommit = $PreferredBarCommit
    barCommitUsed = $BarCommitUsed
    barCommitSource = $BarCommitSource
    barPayloadZip = $barZips[0].Name
    controllerLuaTag = $ControllerTag
    luaWidgets = @(Get-ChildItem -LiteralPath $LuaPayload -Filter '*.lua' -File | Sort-Object Name | ForEach-Object { $_.Name })
    builtAtUtc = (Get-Date).ToUniversalTime().ToString('o')
}

$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $MetadataPath -Encoding UTF8

Write-Host "AIO ZIP: $AioZipPath"
Write-Host "Build metadata: $MetadataPath"
Write-Host "Official BAR.sdd commit used: $BarCommitUsed ($BarCommitSource)"
