using System;
using System.Collections.Generic;

internal sealed class PackageManifest
{
    public string PackageName { get; set; } = string.Empty;
    public string Version { get; set; } = string.Empty;
    public string Repository { get; set; } = string.Empty;
    public List<string> RequiredLuaFiles { get; set; } = new List<string>();
    public List<string> RequiredBarDataFiles { get; set; } = new List<string>();
    public List<string> RequiredCompanionFiles { get; set; } = new List<string>();
    public List<string> RequiredPublicFiles { get; set; } = new List<string>();
}

internal sealed class InstallState
{
    public string Version { get; set; } = string.Empty;
    public DateTimeOffset LastInstalled { get; set; }
    public List<ShortcutBackup> Shortcuts { get; set; } = new List<ShortcutBackup>();
    public List<FileBackup> LuaWidgets { get; set; } = new List<FileBackup>();
    public List<FileBackup> BarDataFiles { get; set; } = new List<FileBackup>();
    public List<FileBackup> CompanionFiles { get; set; } = new List<FileBackup>();
    public FileBackup? WidgetConfig { get; set; }
    public FileBackup? LauncherConfig { get; set; }
    public FileBackup? CameraSettings { get; set; }
}

internal sealed class FileBackup
{
    public string Destination { get; set; } = string.Empty;
    public string? BackupPath { get; set; }
    public bool ExistedBeforeInstall { get; set; }
}

internal sealed class ShortcutBackup
{
    public string ShortcutPath { get; set; } = string.Empty;
    public string BackupPath { get; set; } = string.Empty;
    public string OriginalTargetPath { get; set; } = string.Empty;
    public string OriginalArguments { get; set; } = string.Empty;
    public string OriginalWorkingDirectory { get; set; } = string.Empty;
    public string OriginalIconLocation { get; set; } = string.Empty;
    public string OriginalDescription { get; set; } = string.Empty;
}

internal sealed class LauncherConfig
{
    public string OriginalTargetPath { get; set; } = string.Empty;
    public string OriginalArguments { get; set; } = string.Empty;
    public string OriginalWorkingDirectory { get; set; } = string.Empty;
    public string OriginalIconLocation { get; set; } = string.Empty;
    public string BridgePath { get; set; } = string.Empty;
    public string SettingsPath { get; set; } = string.Empty;
    public int BridgeStartupDelayMilliseconds { get; set; } = 900;
}

internal sealed class ShortcutMetadata
{
    public string TargetPath { get; set; } = string.Empty;
    public string Arguments { get; set; } = string.Empty;
    public string WorkingDirectory { get; set; } = string.Empty;
    public string IconLocation { get; set; } = string.Empty;
}
