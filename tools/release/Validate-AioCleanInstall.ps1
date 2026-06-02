[CmdletBinding()]
param(
    [string]$AssetsDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path

$InstallerName = 'Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat'
$ReadmeName = 'README_AIO_CLEAN_INSTALL.txt'
$PayloadPattern = 'BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_PAYLOAD_*.zip'
$ExpectedLuaWidgets = @(
    'gui_controller_camera_test.lua',
    'gui_controller_bindings_ui.lua',
    'gui_controller_smartx_mouse_audit.lua',
    'camera_joystick.lua',
    'gui_controller_test.lua'
)
$GitHubAssetLimit = 2147483648

if (-not $AssetsDirectory) {
    $AssetsDirectory = Join-Path $RepoRoot 'build\dist\release-assets'
}
$AssetsDirectory = [System.IO.Path]::GetFullPath($AssetsDirectory)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Results = New-Object System.Collections.Generic.List[string]
function Add-Pass {
    param([string]$Message)
    $Results.Add("PASS: $Message") | Out-Null
    Write-Host "PASS: $Message"
}
function Add-Fail {
    param([string]$Message)
    $Results.Add("FAIL: $Message") | Out-Null
    throw $Message
}

function Get-ZipEntryNames {
    param([Parameter(Mandatory = $true)][string]$Path)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        return @($zip.Entries | Where-Object { $_.FullName -and -not $_.FullName.EndsWith('/') } | ForEach-Object { $_.FullName -replace '\\', '/' })
    }
    finally {
        $zip.Dispose()
    }
}

function Test-NoBadNames {
    param(
        [Parameter(Mandatory = $true)][string[]]$Names,
        [Parameter(Mandatory = $true)][string]$Scope
    )

    if ($Names | Where-Object { $_ -match '(?i)BYAR[ -]Chobby\.sdd' }) {
        Add-Fail "$Scope contains BYAR Chobby.sdd."
    }
    if ($Names | Where-Object { $_ -match '(^|/)\.git(/|$)' }) {
        Add-Fail "$Scope contains a .git folder."
    }
    if ($Names | Where-Object { $_ -match '(?i)(attempt[\s_-]*0?2|stutter[\s_-]*fix)' }) {
        Add-Fail "$Scope contains Attempt 02 or stutter-fix naming."
    }
    if ($Names | Where-Object { $_ -match '(?i)(backed[\s_-]*up|backup).*BAR\.sdd' }) {
        Add-Fail "$Scope contains old backed-up BAR.sdd naming."
    }
}

function Test-EngineZip {
    param([Parameter(Mandatory = $true)][string]$Path)
    $names = Get-ZipEntryNames -Path $Path
    Test-NoBadNames -Names $names -Scope 'Engine payload ZIP'
    $spring = @($names | Where-Object {
        $parts = $_.Split('/')
        ($parts.Count -eq 1 -and $parts[0] -ieq 'spring.exe') -or
            ($parts.Count -eq 2 -and $parts[1] -ieq 'spring.exe')
    })
    if ($spring.Count -lt 1) {
        Add-Fail "Engine payload ZIP does not contain spring.exe at root or one nested top-level folder."
    }
    Add-Pass "Engine payload ZIP contains spring.exe."
}

function Test-BarZip {
    param([Parameter(Mandatory = $true)][string]$Path)
    $names = Get-ZipEntryNames -Path $Path
    Test-NoBadNames -Names $names -Scope 'BAR.sdd payload ZIP'
    $prefixes = New-Object System.Collections.Generic.List[string]

    foreach ($name in $names) {
        $parts = $name.Split('/')
        if ($parts.Count -eq 1 -and $parts[0] -ieq 'modinfo.lua') {
            $prefixes.Add('') | Out-Null
        }
        elseif ($parts.Count -eq 2 -and $parts[1] -ieq 'modinfo.lua') {
            $prefixes.Add($parts[0]) | Out-Null
        }
    }

    $valid = $false
    foreach ($prefix in $prefixes) {
        if ($prefix -eq '') {
            if ($names | Where-Object { $_ -match '(?i)^luaui/' }) {
                $valid = $true
            }
        }
        else {
            $escaped = [Regex]::Escape($prefix)
            if ($names | Where-Object { $_ -match "(?i)^$escaped/luaui/" }) {
                $valid = $true
            }
        }
    }

    if (-not $valid) {
        Add-Fail "BAR.sdd payload ZIP does not contain modinfo.lua and luaui at root or one nested top-level folder."
    }
    Add-Pass "BAR.sdd payload ZIP contains modinfo.lua and luaui."
}

function Test-BarFolder {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'modinfo.lua'))) {
        Add-Fail "BAR.sdd folder payload is missing modinfo.lua."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'luaui'))) {
        Add-Fail "BAR.sdd folder payload is missing luaui."
    }
    $names = @(Get-ChildItem -LiteralPath $Path -Recurse -Force -File | ForEach-Object { $_.FullName.Substring($Path.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/' })
    Test-NoBadNames -Names $names -Scope 'BAR.sdd folder payload'
    Add-Pass "BAR.sdd folder payload contains modinfo.lua and luaui."
}

function Test-BatchLabels {
    param([Parameter(Mandatory = $true)][string]$InstallerPath)
    $content = Get-Content -LiteralPath $InstallerPath -Raw
    $labels = @{}
    foreach ($match in [Regex]::Matches($content, '(?m)^:([A-Za-z0-9_]+)\s*$')) {
        $labels[$match.Groups[1].Value.ToUpperInvariant()] = $true
    }
    foreach ($match in [Regex]::Matches($content, '(?im)\bgoto\s+([A-Za-z0-9_]+)')) {
        $target = $match.Groups[1].Value.ToUpperInvariant()
        if (-not $labels.ContainsKey($target)) {
            Add-Fail "Batch file has a goto target without a matching label: $target"
        }
    }
    Add-Pass "Batch labels and goto targets are internally consistent."
}

function Get-PayloadArchiveInfo {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo[]]$PayloadZips)

    $info = foreach ($file in $PayloadZips) {
        if ($file.Name -notmatch 'PAYLOAD_(\d+)_OF_(\d+)\.zip$') {
            Add-Fail "Invalid PAYLOAD ZIP name: $($file.Name)"
        }
        [pscustomobject]@{
            Index = [int]$matches[1]
            Total = [int]$matches[2]
            File = $file
        }
    }

    $totals = @($info.Total | Sort-Object -Unique)
    if ($totals.Count -ne 1) {
        Add-Fail "PAYLOAD ZIP files disagree about expected count."
    }
    $total = [int]$totals[0]
    if ($PayloadZips.Count -ne $total) {
        Add-Fail "Partial PAYLOAD ZIP set: expected $total file(s), found $($PayloadZips.Count)."
    }
    for ($i = 1; $i -le $total; $i++) {
        if (-not @($info | Where-Object { $_.Index -eq $i }).Count) {
            Add-Fail "Missing PAYLOAD ZIP $i of $total."
        }
    }
    return @($info | Sort-Object Index)
}

if (-not (Test-Path -LiteralPath $AssetsDirectory)) {
    Add-Fail "Release asset directory does not exist: $AssetsDirectory"
}
Add-Pass "Release asset directory exists: $AssetsDirectory"

$installerPath = Join-Path $AssetsDirectory $InstallerName
$readmePath = Join-Path $AssetsDirectory $ReadmeName

if (-not (Test-Path -LiteralPath $installerPath)) {
    Add-Fail "Standalone installer BAT is missing."
}
Add-Pass "Standalone installer BAT exists."

if (-not (Test-Path -LiteralPath $readmePath)) {
    Add-Fail "Standalone README is missing."
}
Add-Pass "Standalone README exists."

$payloadZips = @(Get-ChildItem -LiteralPath $AssetsDirectory -Filter $PayloadPattern -File | Sort-Object Name)
if ($payloadZips.Count -lt 1) {
    Add-Fail "No PAYLOAD ZIP files found."
}
$payloadInfo = Get-PayloadArchiveInfo -PayloadZips $payloadZips
Add-Pass "Found complete PAYLOAD ZIP set with $($payloadZips.Count) file(s)."

$allAssets = @((Get-Item -LiteralPath $installerPath), (Get-Item -LiteralPath $readmePath)) + $payloadZips
foreach ($asset in $allAssets) {
    if ($asset.Length -ge $GitHubAssetLimit) {
        Add-Fail "Release asset exceeds GitHub per-file size limit: $($asset.Name) = $($asset.Length) bytes."
    }
    Add-Pass "Release asset is under GitHub per-file limit: $($asset.Name) ($($asset.Length) bytes)."
}

foreach ($payloadZip in $payloadZips) {
    $names = Get-ZipEntryNames -Path $payloadZip.FullName
    Test-NoBadNames -Names $names -Scope $payloadZip.Name
}
Add-Pass "PAYLOAD ZIP entries contain no BYAR Chobby.sdd, .git folders, Attempt 02 naming, or old backed-up BAR.sdd naming."

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "BAR_AIO_VALIDATE_$([Guid]::NewGuid().ToString('N'))"
$CombinedPayloadRoot = Join-Path $TempRoot 'combined'
New-Item -ItemType Directory -Path $CombinedPayloadRoot -Force | Out-Null

try {
    foreach ($payload in $payloadInfo) {
        Expand-Archive -LiteralPath $payload.File.FullName -DestinationPath $CombinedPayloadRoot -Force
    }

    $payloadRoot = Join-Path $CombinedPayloadRoot 'payload'
    $engineRoot = Join-Path $payloadRoot 'engine'
    $barRoot = Join-Path $payloadRoot 'bar_sdd'
    $luaRoot = Join-Path $payloadRoot 'lua_widgets'

    foreach ($required in @($engineRoot, $barRoot, $luaRoot)) {
        if (-not (Test-Path -LiteralPath $required)) {
            Add-Fail "Combined extracted payload is missing: $required"
        }
    }
    Add-Pass "Combined extracted payload reconstructs payload\\engine, payload\\bar_sdd, and payload\\lua_widgets."

    $enginePayloadZips = @(Get-ChildItem -LiteralPath $engineRoot -Filter '*.zip' -File)
    if ($enginePayloadZips.Count -ne 1) {
        Add-Fail "Expected exactly one engine ZIP in combined payload, found $($enginePayloadZips.Count)."
    }
    Add-Pass "Combined payload contains exactly one engine ZIP."

    $barPayloadZips = @(Get-ChildItem -LiteralPath $barRoot -Filter '*.zip' -File)
    $barFolderCandidates = @(
        (Join-Path $barRoot 'BAR.sdd'),
        $barRoot
    ) | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_ 'modinfo.lua')) -and
        (Test-Path -LiteralPath (Join-Path $_ 'luaui'))
    }
    if ($barPayloadZips.Count -eq 1) {
        Add-Pass "Combined payload contains one BAR.sdd ZIP."
        Test-BarZip -Path $barPayloadZips[0].FullName
    }
    elseif ($barPayloadZips.Count -eq 0 -and $barFolderCandidates.Count -ge 1) {
        Add-Pass "Combined payload contains a reconstructed BAR.sdd folder."
        Test-BarFolder -Path $barFolderCandidates[0]
    }
    else {
        Add-Fail "Combined payload must contain exactly one BAR.sdd ZIP or one reconstructed BAR.sdd folder."
    }

    $luaPayloadFiles = @(Get-ChildItem -LiteralPath $luaRoot -Filter '*.lua' -File)
    if ($luaPayloadFiles.Count -lt 1) {
        Add-Fail "Combined payload contains no Lua widget files."
    }
    Add-Pass "Combined payload contains $($luaPayloadFiles.Count) Lua widget file(s)."
    foreach ($widget in $ExpectedLuaWidgets) {
        if ($luaPayloadFiles | Where-Object { $_.Name -eq $widget }) {
            Add-Pass "Lua payload includes $widget."
        }
        elseif ($widget -in @('gui_controller_camera_test.lua', 'gui_controller_bindings_ui.lua', 'gui_controller_smartx_mouse_audit.lua')) {
            Add-Fail "Lua payload is missing expected controller widget: $widget"
        }
    }

    Test-BatchLabels -InstallerPath $installerPath
    Test-EngineZip -Path $enginePayloadZips[0].FullName

    $payloadCheckOut = Join-Path $TempRoot 'payload-check.stdout.txt'
    $payloadCheckErr = Join-Path $TempRoot 'payload-check.stderr.txt'
    $cmd = "/d /c `"$installerPath`" --payload-check"
    $process = Start-Process -FilePath $env:ComSpec -ArgumentList $cmd -WorkingDirectory $AssetsDirectory -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $payloadCheckOut -RedirectStandardError $payloadCheckErr
    if ($process.ExitCode -ne 0) {
        $stdout = if (Test-Path -LiteralPath $payloadCheckOut) { Get-Content -LiteralPath $payloadCheckOut -Raw } else { '' }
        $stderr = if (Test-Path -LiteralPath $payloadCheckErr) { Get-Content -LiteralPath $payloadCheckErr -Raw } else { '' }
        Add-Fail "Installer --payload-check failed with exit code $($process.ExitCode). STDOUT: $stdout STDERR: $stderr"
    }
    Add-Pass "Installer --payload-check found and extracted sibling PAYLOAD ZIPs without touching live BAR files."
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

$ValidationOutput = Join-Path $RepoRoot 'build\dist\BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.asset-validation-results.txt'
New-Item -ItemType Directory -Path (Split-Path -Parent $ValidationOutput) -Force | Out-Null
$Results | Set-Content -LiteralPath $ValidationOutput -Encoding UTF8
Write-Host "Validation results written to $ValidationOutput"
