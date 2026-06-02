[CmdletBinding()]
param(
    [string]$ZipPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..\..')).Path

$AioZipName = 'BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.zip'
$InstallerName = 'Install_BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.bat'
$ReadmeName = 'README_AIO_CLEAN_INSTALL.txt'
$ExpectedLuaWidgets = @(
    'gui_controller_camera_test.lua',
    'gui_controller_bindings_ui.lua',
    'gui_controller_smartx_mouse_audit.lua',
    'camera_joystick.lua',
    'gui_controller_test.lua'
)

if (-not $ZipPath) {
    $ZipPath = Join-Path $RepoRoot "build\dist\$AioZipName"
}

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

function Test-EngineZip {
    param([Parameter(Mandatory = $true)][string]$Path)
    $names = Get-ZipEntryNames -Path $Path
    $spring = @($names | Where-Object {
        $parts = $_.Split('/')
        ($parts.Count -eq 1 -and $parts[0] -ieq 'spring.exe') -or
            ($parts.Count -eq 2 -and $parts[1] -ieq 'spring.exe')
    })
    if ($spring.Count -lt 1) {
        Add-Fail "Engine payload ZIP does not contain spring.exe at root or one nested top-level folder."
    }
    if ($names -match '(?i)(attempt[\s_-]*0?2|stutter[\s_-]*fix)') {
        Add-Fail "Engine payload ZIP appears to contain Attempt 02 or stutter-fix naming."
    }
    Add-Pass "Engine payload ZIP contains spring.exe."
}

function Test-BarZip {
    param([Parameter(Mandatory = $true)][string]$Path)
    $names = Get-ZipEntryNames -Path $Path
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
    if ($names | Where-Object { $_ -match '(^|/)\.git(/|$)' }) {
        Add-Fail "BAR.sdd payload ZIP contains a .git folder."
    }
    if ($names | Where-Object { $_ -match '(?i)BYAR[ -]Chobby\.sdd' }) {
        Add-Fail "BAR.sdd payload ZIP contains BYAR Chobby.sdd."
    }
    Add-Pass "BAR.sdd payload ZIP contains modinfo.lua and luaui and has no .git folder."
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

if (-not (Test-Path -LiteralPath $ZipPath)) {
    Add-Fail "AIO ZIP does not exist: $ZipPath"
}
Add-Pass "AIO ZIP exists: $ZipPath"

$entryNames = Get-ZipEntryNames -Path $ZipPath

if ($entryNames -notcontains $InstallerName) {
    Add-Fail "AIO ZIP is missing $InstallerName."
}
Add-Pass "AIO ZIP contains installer BAT."

if ($entryNames -notcontains $ReadmeName) {
    Add-Fail "AIO ZIP is missing $ReadmeName."
}
Add-Pass "AIO ZIP contains README_AIO_CLEAN_INSTALL.txt."

$enginePayloadZips = @($entryNames | Where-Object { $_ -match '^payload/engine/[^/]+\.zip$' })
$barPayloadZips = @($entryNames | Where-Object { $_ -match '^payload/bar_sdd/[^/]+\.zip$' })
$luaPayloadFiles = @($entryNames | Where-Object { $_ -match '^payload/lua_widgets/[^/]+\.lua$' })

if ($enginePayloadZips.Count -ne 1) {
    Add-Fail "Expected exactly one engine ZIP in payload/engine, found $($enginePayloadZips.Count)."
}
Add-Pass "AIO ZIP contains exactly one engine ZIP."

if ($barPayloadZips.Count -ne 1) {
    Add-Fail "Expected exactly one BAR.sdd ZIP in payload/bar_sdd, found $($barPayloadZips.Count)."
}
Add-Pass "AIO ZIP contains exactly one BAR.sdd ZIP."

if ($luaPayloadFiles.Count -lt 1) {
    Add-Fail "AIO ZIP contains no Lua widgets in payload/lua_widgets."
}
Add-Pass "AIO ZIP contains $($luaPayloadFiles.Count) Lua widget file(s)."

foreach ($widget in $ExpectedLuaWidgets) {
    if ($luaPayloadFiles | Where-Object { (Split-Path -Leaf $_) -eq $widget }) {
        Add-Pass "Lua payload includes $widget."
    }
    elseif ($widget -in @('gui_controller_camera_test.lua', 'gui_controller_bindings_ui.lua', 'gui_controller_smartx_mouse_audit.lua')) {
        Add-Fail "Lua payload is missing expected controller widget: $widget"
    }
}

if ($entryNames | Where-Object { $_ -match '(?i)BYAR[ -]Chobby\.sdd' }) {
    Add-Fail "AIO ZIP contains BYAR Chobby.sdd."
}
Add-Pass "AIO ZIP does not contain BYAR Chobby.sdd."

if ($entryNames | Where-Object { $_ -match '(^|/)\.git(/|$)' }) {
    Add-Fail "AIO ZIP contains a .git folder."
}
Add-Pass "AIO ZIP does not contain .git folders."

if ($entryNames | Where-Object { $_ -match '(?i)(attempt[\s_-]*0?2|stutter[\s_-]*fix)' }) {
    Add-Fail "AIO ZIP contains Attempt 02 or stutter-fix naming."
}
Add-Pass "AIO ZIP does not include Attempt 02 naming."

$allZipEntries = @($entryNames | Where-Object { $_ -match '\.zip$' })
$allowedZipEntries = @($enginePayloadZips + $barPayloadZips)
$unexpectedZipEntries = @($allZipEntries | Where-Object { $_ -notin $allowedZipEntries })
if ($unexpectedZipEntries.Count -gt 0) {
    Add-Fail "AIO ZIP contains unexpected ZIP archive(s): $($unexpectedZipEntries -join ', ')"
}
Add-Pass "AIO ZIP contains no unrelated release archives."

$unexpectedDocs = @($entryNames | Where-Object { $_ -match '(?i)(diagnostic|dump|continuation|stale).*\.(md|txt)$' })
if ($unexpectedDocs.Count -gt 0) {
    Add-Fail "AIO ZIP contains obvious stale diagnostic dump(s): $($unexpectedDocs -join ', ')"
}
Add-Pass "AIO ZIP contains no obvious stale diagnostic markdown dumps."

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "BAR_AIO_VALIDATE_$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
try {
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $TempRoot -Force
    $installerPath = Join-Path $TempRoot $InstallerName
    Test-BatchLabels -InstallerPath $installerPath

    $engineZipPath = Join-Path $TempRoot $enginePayloadZips[0]
    $barZipPath = Join-Path $TempRoot $barPayloadZips[0]
    Test-EngineZip -Path $engineZipPath
    Test-BarZip -Path $barZipPath

    $payloadCheckOut = Join-Path $TempRoot 'payload-check.stdout.txt'
    $payloadCheckErr = Join-Path $TempRoot 'payload-check.stderr.txt'
    $cmd = "/d /c call `"$installerPath`" --payload-check"
    $process = Start-Process -FilePath $env:ComSpec -ArgumentList $cmd -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $payloadCheckOut -RedirectStandardError $payloadCheckErr
    if ($process.ExitCode -ne 0) {
        $stdout = if (Test-Path -LiteralPath $payloadCheckOut) { Get-Content -LiteralPath $payloadCheckOut -Raw } else { '' }
        $stderr = if (Test-Path -LiteralPath $payloadCheckErr) { Get-Content -LiteralPath $payloadCheckErr -Raw } else { '' }
        Add-Fail "Installer --payload-check failed with exit code $($process.ExitCode). STDOUT: $stdout STDERR: $stderr"
    }
    Add-Pass "Installer --payload-check completed without touching live BAR files."
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

$ValidationOutput = Join-Path $RepoRoot 'build\dist\BAR_Controller_Support_v0.4.3_QUEUE_POLISH_AIO_CLEAN_INSTALL.validation-results.txt'
New-Item -ItemType Directory -Path (Split-Path -Parent $ValidationOutput) -Force | Out-Null
$Results | Set-Content -LiteralPath $ValidationOutput -Encoding UTF8
Write-Host "Validation results written to $ValidationOutput"
