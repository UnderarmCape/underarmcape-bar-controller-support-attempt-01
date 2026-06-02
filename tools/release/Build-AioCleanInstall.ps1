[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [switch]$ReuseExistingPayload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path

$ReleaseTag = 'controller-support-v0.4.3-queue-polish-aio-clean-install'
$InstallerName = 'Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat'
$ReadmeName = 'README_AIO_CLEAN_INSTALL.txt'
$Payload1Name = 'BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_PAYLOAD_1_OF_2.zip'
$Payload2Name = 'BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_PAYLOAD_2_OF_2.zip'

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

$AssetDirectory = Join-Path $OutputDirectory 'release-assets'
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
$Payload1Stage = Join-Path $WorkRoot 'payload-asset-1-stage'
$Payload2Stage = Join-Path $WorkRoot 'payload-asset-2-stage'
$MetadataPath = Join-Path $OutputDirectory 'BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.asset-metadata.json'

$GitHubAssetLimit = 2147483648
$PreferredAssetSize = 1900000000

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
        [string[]]$ExcludeRegex = @(),
        [switch]$StoreNestedZipFiles
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
            if ($StoreNestedZipFiles -and $file.Extension -ieq '.zip' -and [Enum]::GetNames([System.IO.Compression.CompressionLevel]) -contains 'NoCompression') {
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

function Write-StandaloneInstaller {
    param([Parameter(Mandatory = $true)][string]$DestinationPath)

    $installerText = Get-Content -LiteralPath (Join-Path $RepoRoot $InstallerName) -Raw
    $installerText = $installerText -replace "`r?`n", "`r`n"
    Set-Content -LiteralPath $DestinationPath -Value $installerText -NoNewline -Encoding ASCII
}

function Assert-ReleaseAssetSize {
    param([Parameter(Mandatory = $true)][string]$Path)

    $item = Get-Item -LiteralPath $Path
    if ($item.Length -ge $GitHubAssetLimit) {
        throw "Release asset exceeds GitHub per-file limit: $($item.Name) = $($item.Length) bytes"
    }
    if ($item.Length -gt $PreferredAssetSize) {
        Write-Warning "Release asset is under the GitHub hard limit but above preferred size: $($item.Name) = $($item.Length) bytes"
    }
}

Write-Host "Building standalone BAT/README plus payload ZIP release assets"
Write-Host "Repository root: $RepoRoot"

if ($ReuseExistingPayload) {
    if (-not (Test-Path -LiteralPath $PayloadRoot)) {
        throw "Cannot reuse payload because it does not exist: $PayloadRoot"
    }
    Write-Host "Reusing existing payload root: $PayloadRoot"
}
else {
    Remove-DirectorySafe -Path $WorkRoot
    New-Item -ItemType Directory -Path $EnginePayload, $BarPayload, $LuaPayload -Force | Out-Null

    Write-Host "Downloading stable controller engine payload..."
    Invoke-External gh @(
        'release', 'download', $EngineReleaseTag,
        '--repo', $EngineRepo,
        '--pattern', $EngineAssetName,
        '--dir', $EnginePayload,
        '--clobber'
    )

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

    try {
        Invoke-External git @('fetch', '--depth=1', 'origin', $PreferredBarCommit) $BarSource
        Invoke-External git @('-c', 'advice.detachedHead=false', 'checkout', '--force', $PreferredBarCommit) $BarSource
    }
    catch {
        Write-Warning "Preferred BAR.sdd commit was not accessible: $($_.Exception.Message)"
        Write-Warning "Falling back to the official repository default branch HEAD."
        Invoke-External git @('fetch', '--depth=1', 'origin', 'HEAD') $BarSource
        Invoke-External git @('-c', 'advice.detachedHead=false', 'checkout', '--force', 'FETCH_HEAD') $BarSource
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
}

$engineZips = @(Get-ChildItem -LiteralPath $EnginePayload -Filter '*.zip' -File)
if ($engineZips.Count -ne 1) {
    throw "Expected exactly one engine ZIP, found $($engineZips.Count)."
}

$barZips = @(Get-ChildItem -LiteralPath $BarPayload -Filter '*.zip' -File)
if ($barZips.Count -ne 1) {
    throw "Expected exactly one BAR.sdd ZIP, found $($barZips.Count)."
}

$luaWidgets = @(Get-ChildItem -LiteralPath $LuaPayload -Filter '*.lua' -File | Sort-Object Name)
if ($luaWidgets.Count -lt 1) {
    throw "Expected at least one Lua widget, found none."
}

Remove-DirectorySafe -Path $AssetDirectory
Remove-DirectorySafe -Path $Payload1Stage
Remove-DirectorySafe -Path $Payload2Stage
New-Item -ItemType Directory -Path $AssetDirectory, (Join-Path $Payload1Stage 'payload\engine'), (Join-Path $Payload1Stage 'payload\lua_widgets'), (Join-Path $Payload2Stage 'payload\bar_sdd') -Force | Out-Null

Write-StandaloneInstaller -DestinationPath (Join-Path $AssetDirectory $InstallerName)
Copy-Item -LiteralPath (Join-Path $RepoRoot $ReadmeName) -Destination (Join-Path $AssetDirectory $ReadmeName) -Force

Copy-Item -LiteralPath $engineZips[0].FullName -Destination (Join-Path $Payload1Stage "payload\engine\$($engineZips[0].Name)") -Force
foreach ($widget in $luaWidgets) {
    Copy-Item -LiteralPath $widget.FullName -Destination (Join-Path $Payload1Stage "payload\lua_widgets\$($widget.Name)") -Force
}
Copy-Item -LiteralPath $barZips[0].FullName -Destination (Join-Path $Payload2Stage "payload\bar_sdd\$($barZips[0].Name)") -Force

$manifest = [ordered]@{
    releaseTag = $ReleaseTag
    payloadZipCount = 2
    payloadZipNames = @($Payload1Name, $Payload2Name)
    layout = 'standalone-bat-readme-plus-payload-zips'
    enginePayloadZip = $engineZips[0].Name
    barPayloadZip = $barZips[0].Name
    luaWidgets = @($luaWidgets | ForEach-Object { $_.Name })
    preferredBarCommit = $PreferredBarCommit
    controllerLuaTag = $ControllerTag
    builtAtUtc = (Get-Date).ToUniversalTime().ToString('o')
}
$manifestJson = $manifest | ConvertTo-Json -Depth 4
$manifestJson | Set-Content -LiteralPath (Join-Path $Payload1Stage 'payload\release-payload-manifest.json') -Encoding UTF8
$manifestJson | Set-Content -LiteralPath (Join-Path $Payload2Stage 'payload\release-payload-manifest.json') -Encoding UTF8

Write-Host "Creating PAYLOAD ZIP 1 of 2..."
New-ZipFromDirectory -SourceDirectory $Payload1Stage -ZipPath (Join-Path $AssetDirectory $Payload1Name) -ExcludeRegex @('(^|/)\.git(/|$)') -StoreNestedZipFiles

Write-Host "Creating PAYLOAD ZIP 2 of 2..."
New-ZipFromDirectory -SourceDirectory $Payload2Stage -ZipPath (Join-Path $AssetDirectory $Payload2Name) -ExcludeRegex @('(^|/)\.git(/|$)') -StoreNestedZipFiles

$assets = @(
    (Get-Item -LiteralPath (Join-Path $AssetDirectory $InstallerName)),
    (Get-Item -LiteralPath (Join-Path $AssetDirectory $ReadmeName)),
    (Get-Item -LiteralPath (Join-Path $AssetDirectory $Payload1Name)),
    (Get-Item -LiteralPath (Join-Path $AssetDirectory $Payload2Name))
)
foreach ($asset in $assets) {
    Assert-ReleaseAssetSize -Path $asset.FullName
}

$barCommitUsed = if (Test-Path -LiteralPath (Join-Path $BarSource '.git')) {
    Get-GitOutput @('rev-parse', 'HEAD') $BarSource
}
else {
    $PreferredBarCommit
}

$metadata = [ordered]@{
    releaseTag = $ReleaseTag
    assetDirectory = $AssetDirectory
    assets = @($assets | ForEach-Object { [ordered]@{ name = $_.Name; path = $_.FullName; bytes = $_.Length } })
    engineRepo = $EngineRepo
    engineReleaseTag = $EngineReleaseTag
    enginePayloadZip = $engineZips[0].Name
    officialBarRepo = $OfficialBarRepo
    preferredBarCommit = $PreferredBarCommit
    barCommitUsed = $barCommitUsed
    barPayloadZip = $barZips[0].Name
    controllerLuaTag = $ControllerTag
    luaWidgets = @($luaWidgets | ForEach-Object { $_.Name })
    builtAtUtc = (Get-Date).ToUniversalTime().ToString('o')
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $MetadataPath -Encoding UTF8

Write-Host "Release assets:"
foreach ($asset in $assets) {
    Write-Host ("  {0} ({1} bytes)" -f $asset.FullName, $asset.Length)
}
Write-Host "Build metadata: $MetadataPath"
