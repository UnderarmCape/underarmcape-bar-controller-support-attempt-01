[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$OutputDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $RepositoryRoot 'artifacts\v0.8.0-native-input-disassemble-test' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$stage = Join-Path $OutputDirectory ('.package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    $files = @(
        'luaui\Widgets\gui_controller_camera_test.lua',
        'luaui\Widgets\gui_controller_bindings_ui.lua',
        'luaui\Widgets\gui_controller_ui_runtime.lua',
        'luaui\Widgets\gui_controller_ui_layout.lua',
        'luaui\Include\controller_disassemble_behavior.lua',
        'luaui\Include\controller_input_chords.lua',
        'luaui\Include\controller_ui_runtime.lua',
        'luaui\Include\controller_ui_editor_workspace.lua',
        'luaui\Include\controller_ui_editor_input.lua',
        'luaui\Include\controller_ui_shared_renderers.lua',
        'luaui\Include\controller_native_radial_adapter.lua',
        'luaui\Include\controller_native_targeting.lua',
        'luaui\Include\controller_glyphs.lua',
        'luaui\images\controller-glyphs\controller_glyph_atlas.png',
        'luaui\images\controller-glyphs\controller_glyph_atlas_xbox.png',
        'luaui\images\controller-glyphs\controller_glyph_atlas_playstation.png',
        'luaui\images\controller-glyphs\asset-manifest.json',
        'luaui\images\controller-glyphs\LICENSE.md',
        'controller-ui\shipping-defaults.json',
        'controller-ui\shipping-defaults-manifest.json',
        'native-overrides\native-override-manifest.json',
        'native-overrides\99351e53d26f5e55fa007ca1e208b936f22bd3ab\luaui\Widgets\unit_smart_select.lua',
        'native-overrides\99351e53d26f5e55fa007ca1e208b936f22bd3ab\luaui\Widgets\unit_smart_area_reclaim.lua',
        'native-overrides\99351e53d26f5e55fa007ca1e208b936f22bd3ab\luaui\Widgets\gui_ordermenu.lua',
        'native-overrides\99351e53d26f5e55fa007ca1e208b936f22bd3ab\luaui\Widgets\gui_buildmenu.lua',
        'doc\controller-companion-v0.8.0\NATIVE_UI_INTEGRATION_AUDIT.md',
        'doc\controller-companion-v0.8.0\HYBRID_RADIAL_REPAIR_DESIGN.md',
        'doc\controller-companion-v0.8.0\RADIAL_VANILLA_MAPPING.md',
        'doc\controller-companion-v0.8.0\STABLE_SLOT_MAPPING.md',
        'doc\controller-companion-v0.8.0\LEGACY_SUNSET_MAP.md',
        'doc\controller-companion-v0.8.0\NATIVE_OVERRIDE_MAINTENANCE.md',
        'doc\controller-companion-v0.8.0\CONTROLLER_NATIVE_TARGETING.md',
        'doc\controller-companion-v0.8.0\FACTORY_CONTROLLER_SHORTCUTS.md',
        'doc\controller-companion-v0.8.0\DISASSEMBLE_VANILLA_SELECTION.md',
        'doc\controller-companion-v0.8.0\RADIAL_COMPACTION.md',
        'doc\controller-companion-v0.8.0\LIVE_TEST_CHECKLIST.md',
        'tools\controller-ui-tests\Test-ControllerHybridRadials.lua',
        'tools\controller-ui-tests\Test-ControllerNativeUIIntegration.lua',
        'tools\controller-ui-tests\Test-ControllerNativeTargeting.lua',
        'tools\controller-ui-tests\Test-ControllerDisassembleMode.lua',
        'tools\controller-ui-tests\Test-ControllerInputDisassemble.lua',
        'tools\dev-scripts\Deploy_v0.8.0_Native_Test.ps1',
        'tools\dev-scripts\Restore_v0.8.0_Native_Test.ps1',
        'tools\dev-scripts\Generate_Controller_Glyph_Atlases_v0.8.ps1'
    )
    foreach ($relative in $files) {
        $source = Join-Path $RepositoryRoot $relative
        $destination = Join-Path $stage $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination
    }
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'LICENSE.md') -Destination (Join-Path $stage 'LICENSE.md')
    $releaseRoot = Join-Path $RepositoryRoot 'tools\release\bar-controller-support-v0.8.0-native-test'
    foreach ($name in @('Install_v0.8.0_NATIVE_TEST.ps1', 'Restore_v0.8.0_NATIVE_TEST.ps1', 'README_EXPERIMENTAL.md', 'manifest.json')) {
        Copy-Item -LiteralPath (Join-Path $releaseRoot $name) -Destination (Join-Path $stage $name)
    }

    $payload = New-Object Collections.Generic.List[object]
    foreach ($file in @(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($stage.Length + 1).Replace('\', '/')
        if ($relative -ne 'payload-sha256.json') {
            $payload.Add([pscustomobject][ordered]@{ path = $relative; size = $file.Length; sha256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant() })
        }
    }
    [IO.File]::WriteAllText((Join-Path $stage 'payload-sha256.json'), (($payload | ConvertTo-Json -Depth 6) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))

    $zip = Join-Path $OutputDirectory 'BAR_Controller_Support_v0.8.0_NATIVE_INPUT_DISASSEMBLE_TEST.zip'
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(($zip + '.sha256'), ($hash + '  ' + [IO.Path]::GetFileName($zip) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    Write-Output ('PACKAGE=' + $zip)
    Write-Output ('SHA256=' + $hash)
}
finally {
    if (Test-Path -LiteralPath $stage) {
        $resolvedStage = [IO.Path]::GetFullPath($stage)
        $resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\') + '\'
        if (-not $resolvedStage.StartsWith($resolvedOutput, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to remove package staging path outside output directory.' }
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
