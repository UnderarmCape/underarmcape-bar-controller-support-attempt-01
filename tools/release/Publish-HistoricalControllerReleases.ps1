[CmdletBinding()]
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$milestones = @(
    [ordered]@{ commit='fcf9fd2d1c7cd47bc7caeeede4a95be77f8613ee'; tag='controller-support-v0.8.0-native-hybrid-test'; title='BAR Controller Support v0.8.0 — Native Hybrid Test'; package='artifacts\v0.8.0-native-hybrid-test\BAR_Controller_Support_v0.8.0_NATIVE_HYBRID_TEST.zip'; sha='d1c783f830ba37301448b7d73ec092576688753ee4fe0cefb1fc627ef06262b5'; sequence=800010; summary='Initial native hybrid UI integration and override experiment.'; limitations='Experimental hybrid ownership; later targeting and input repairs were not present.' },
    [ordered]@{ commit='8a6bd885c891e0f95749f2e5c033c3273007a214'; tag='controller-support-v0.8.0-native-hybrid-targeting-test'; title='BAR Controller Support v0.8.0 — Native Hybrid Targeting Test'; package='artifacts\v0.8.0-native-hybrid-targeting-test\BAR_Controller_Support_v0.8.0_NATIVE_HYBRID_TARGETING_TEST.zip'; sha='5ab4640bf7d4f690221e6cf31d30bca35dcb6dc111cc704aff5105ee639d24a3'; sequence=800020; summary='Native hybrid point and area targeting milestone.'; limitations='Pre-restoration targeting broker behavior and its known experimental risks remain.' },
    [ordered]@{ commit='b0078c48b73d27675a686115ddfc0fe29b721e6e'; tag='controller-support-v0.8.0-native-input-disassemble-test'; title='BAR Controller Support v0.8.0 — Native Input & Disassemble Test'; package='artifacts\v0.8.0-native-input-disassemble-test\BAR_Controller_Support_v0.8.0_NATIVE_INPUT_DISASSEMBLE_TEST.zip'; sha='745b5f9e980693ed005e127cc0b7b1dbc18e2fab970dd8d9725fa152146d5803'; sequence=800030; summary='Native controller input repairs and Disassemble interaction milestone.'; limitations='Later input polish, widget unification, and v0.6 behavior restoration were not present.' },
    [ordered]@{ commit='95e4b907f73bc78c2944ed55dac2e53d82d7c7d1'; tag='controller-support-v0.8.0-native-input-polish-test'; title='BAR Controller Support v0.8.0 — Native Input Polish Test'; package='artifacts\v0.8.0-native-input-polish-test\BAR_Controller_Support_v0.8.0_NATIVE_INPUT_POLISH_TEST.zip'; sha='94735439ba85bed2590a4f022a94827b1c15b792ea44160cd22fdde500f4cbac'; sequence=800040; summary='Controller input arbitration and presentation polish milestone.'; limitations='Native widget unification and later regression repairs were not present.' },
    [ordered]@{ commit='9ea4999031c2e0452a554f0b677f99d3ed817490'; tag='controller-support-v0.8.0-native-widget-unification-test'; title='BAR Controller Support v0.8.0 — Native Widget Unification Test'; package='artifacts\v0.8.0-native-widget-unification-test\BAR_Controller_Support_v0.8.0_NATIVE_WIDGET_UNIFICATION_TEST.zip'; sha='1d012c08a19f27321e42b9879797796b199f1cea5eebf5625ced94f885b90f6c'; sequence=800050; summary='Native widget ownership and UI integration unification milestone.'; limitations='Subsequent regression, area/idle, and tactical restoration fixes were not present.' },
    [ordered]@{ commit='dc76f42b9f09a42a3455b705ea3ca2f1ff372931'; tag='controller-support-v0.8.0-native-regression-repair-test'; title='BAR Controller Support v0.8.0 — Native Regression Repair Test'; package='artifacts\v0.8.0-native-regression-repair-test\BAR_Controller_Support_v0.8.0_NATIVE_REGRESSION_REPAIR_TEST.zip'; sha='db06b38db34b50ab2487b666753e23d97e7c07fc96c0a2f0fdf186590872e61b'; sequence=800060; summary='Focused native controller regression repair milestone.'; limitations='Hybrid area/idle repair and final v0.6 restoration were not present.' },
    [ordered]@{ commit='c680490f0aba001f2a51a2e367b8198d96dbab76'; tag='controller-support-v0.8.0-hybrid-area-idle-repair-test'; title='BAR Controller Support v0.8.0 — Hybrid Area & Idle Repair Test'; package='artifacts\v0.8.0-hybrid-area-idle-repair-test\BAR_Controller_Support_v0.8.0_HYBRID_AREA_IDLE_REPAIR_TEST.zip'; sha='2c06f11ed694033811941efacc9abab900c9a07187eb434844fd8a338e1a7c93'; sequence=800070; summary='Hybrid area targeting and controller idle navigation repair milestone.'; limitations='Radial/tactical redesign and final v0.6 state-machine restoration were not present.' },
    [ordered]@{ commit='c5c07603e3d6560ad057e35a021d0f5ffc8b1643'; tag='controller-support-v0.8.0-radial-tactical-idle-redesign-test'; title='BAR Controller Support v0.8.0 — Radial, Tactical & Idle Redesign Test'; package='artifacts\v0.8.0-radial-tactical-idle-redesign-test\BAR_Controller_Support_v0.8.0_RADIAL_TACTICAL_IDLE_REDESIGN_TEST.zip'; sha='845dc89eec1d3adc15443b51ca214a06a71c22ba14057efb40aa7af0394920de'; sequence=800080; summary='Radial, Tactical, Factory, and idle redesign milestone.'; limitations='The final v0.6 input restoration, selection taps, updater, and Recovery Mode were not present.' }
)

$existingV7 = gh release view controller-support-v0.7.0-disassemble-mode --repo UnderarmCape/underarmcape-bar-controller-support-attempt-01 --json tagName,name,assets | ConvertFrom-Json
if ($existingV7.tagName -ne 'controller-support-v0.7.0-disassemble-mode') { throw 'Existing v0.7.0 release is unavailable.' }
$v7Package = @($existingV7.assets | Where-Object { $_.name -eq 'BAR_Controller_Support_v0.7.0_Widget_Companion.zip' })
if ($v7Package.Count -ne 1 -or ([string]$v7Package[0].digest).Replace('sha256:','') -ne '18060e562950bbb98a85426d78f1290df5505b2766f57f901e2876460dfcb66b') {
    throw 'Existing v0.7.0 release package identity changed; refusing migration.'
}
Write-Output 'PRESERVED_EXISTING_RELEASE=controller-support-v0.7.0-disassemble-mode'

foreach ($milestone in $milestones) {
    $package = Join-Path $RepositoryRoot ([string]$milestone.package)
    if (-not (Test-Path -LiteralPath $package -PathType Leaf)) {
        Write-Warning "Historical release skipped; exact package missing: $($milestone.tag)"
        continue
    }
    $sidecarRoot = Join-Path ([IO.Path]::GetDirectoryName($package)) 'release-sidecars'
    [IO.Directory]::CreateDirectory($sidecarRoot) | Out-Null
    $publishedAt = (& git -C $RepositoryRoot show -s --format=%cI ([string]$milestone.commit)).Trim()
    & (Join-Path $PSScriptRoot 'New-ControllerReleaseManifest.ps1') -PackagePath $package `
        -ExpectedPackageSha256 ([string]$milestone.sha) -Tag ([string]$milestone.tag) -Version '0.8.0' `
        -DisplayVersion 'v0.8.0 Experimental' -ReleaseSequence ([long]$milestone.sequence) -Commit ([string]$milestone.commit) `
        -Title ([string]$milestone.title) -Summary ([string]$milestone.summary) -KnownLimitations ([string]$milestone.limitations) `
        -PublishedAtUtc $publishedAt -OutputRoot $sidecarRoot
    if ($LASTEXITCODE -ne 0) { Write-Warning "Historical sidecar generation failed: $($milestone.tag)"; continue }
    & (Join-Path $PSScriptRoot 'Publish-ControllerRelease.ps1') -Commit ([string]$milestone.commit) -Version '0.8.0' `
        -DisplayVersion 'v0.8.0 Experimental' -Tag ([string]$milestone.tag) -Slug ([string]$milestone.tag) `
        -Title ([string]$milestone.title) -Channel 'historical-experimental' -ReleaseNotesPath (Join-Path $sidecarRoot 'RELEASE_NOTES.md') `
        -PackagePath $package -ManifestPath (Join-Path $sidecarRoot 'controller-release-manifest.json') `
        -PayloadInventoryPath (Join-Path $sidecarRoot 'payload-sha256.json') -ExpectedPackageSha256 ([string]$milestone.sha) `
        -Prerelease -Historical -DryRun:$DryRun
    if ($LASTEXITCODE -ne 0) { Write-Warning "Historical publication failed: $($milestone.tag)"; continue }
}
