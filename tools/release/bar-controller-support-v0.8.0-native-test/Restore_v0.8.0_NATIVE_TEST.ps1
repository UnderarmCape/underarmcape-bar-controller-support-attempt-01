[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BackupRoot,
    [switch]$ValidateOnly,
    [switch]$AllowModifiedInstalledFiles
)
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'tools\dev-scripts\Restore_v0.8.0_Native_Test.ps1'), '-BackupRoot', $BackupRoot)
if ($ValidateOnly) { $arguments += '-ValidateOnly' }
if ($AllowModifiedInstalledFiles) { $arguments += '-AllowModifiedInstalledFiles' }
& powershell @arguments
exit $LASTEXITCODE
