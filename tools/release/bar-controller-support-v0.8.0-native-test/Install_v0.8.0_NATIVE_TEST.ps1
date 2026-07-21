[CmdletBinding()]
param(
    [string]$BarDataPath = (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason\data'),
    [string]$CompanionInstallPath = (Join-Path $env:LOCALAPPDATA 'Programs\BARControllerCompanion'),
    [switch]$AllowUnknownBase,
    [switch]$ValidateOnly
)
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'tools\dev-scripts\Deploy_v0.8.0_Native_Test.ps1'),
    '-RepositoryRoot', $PSScriptRoot, '-BarDataPath', $BarDataPath, '-CompanionInstallPath', $CompanionInstallPath)
if ($AllowUnknownBase) { $arguments += '-AllowUnknownBase' }
if ($ValidateOnly) { $arguments += '-ValidateOnly' }
& powershell @arguments
exit $LASTEXITCODE
