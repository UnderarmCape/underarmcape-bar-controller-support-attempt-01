[CmdletBinding()]
param([string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
Add-Type -AssemblyName System.Drawing

$assetRoot = Join-Path $RepositoryRoot 'luaui\images\controller-glyphs'
$manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $assetRoot 'asset-manifest.json') | ConvertFrom-Json
if ($manifest.version -ne 2) { throw 'Expected glyph manifest version 2.' }

$legacy = New-Object Drawing.Bitmap (Join-Path $assetRoot 'controller_glyph_atlas.png')
$xbox = New-Object Drawing.Bitmap (Join-Path $assetRoot 'controller_glyph_atlas_xbox.png')
$playstation = New-Object Drawing.Bitmap (Join-Path $assetRoot 'controller_glyph_atlas_playstation.png')
try {
    foreach ($bitmap in @($legacy, $xbox, $playstation)) {
        if ($bitmap.Width -ne 512 -or $bitmap.Height -ne 320) { throw 'Atlas dimensions are not 512x320.' }
    }
    foreach ($index in 12..16) {
        $left = ($index % 8) * 64; $top = [Math]::Floor($index / 8) * 64
        foreach ($candidate in @($xbox, $playstation)) {
            for ($y = $top; $y -lt $top + 64; $y++) {
                for ($x = $left; $x -lt $left + 64; $x++) {
                    if ($legacy.GetPixel($x, $y).ToArgb() -ne $candidate.GetPixel($x, $y).ToArgb()) {
                        throw "D-pad zero-based cell $index changed at $x,$y."
                    }
                }
            }
        }
    }
    $xboxDifference = $false; $playstationDifference = $false
    for ($y = 0; $y -lt 320; $y++) {
        for ($x = 0; $x -lt 512; $x++) {
            $cellIndex = ([Math]::Floor($y / 64) * 8) + [Math]::Floor($x / 64)
            if ($cellIndex -lt 12 -or $cellIndex -gt 16) {
                $xboxDifference = $xboxDifference -or ($legacy.GetPixel($x, $y).ToArgb() -ne $xbox.GetPixel($x, $y).ToArgb())
                $playstationDifference = $playstationDifference -or ($legacy.GetPixel($x, $y).ToArgb() -ne $playstation.GetPixel($x, $y).ToArgb())
            }
        }
    }
    if (-not $xboxDifference -or -not $playstationDifference) { throw 'Non-D-pad family artwork was not replaced.' }
}
finally { $legacy.Dispose(); $xbox.Dispose(); $playstation.Dispose() }

foreach ($family in @('Xbox', 'PlayStation')) {
    $entry = $manifest.atlases.$family
    $path = Join-Path $assetRoot ([string]$entry.file)
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($hash -ne [string]$entry.sha256) { throw "$family atlas manifest hash mismatch." }
}
Write-Output 'Controller glyph-family tests passed: dimensions, manifest hashes, distinct family artwork, and pixel-identical v0.7 D-pad zero-based cells 12-16.'
