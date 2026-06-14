using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

internal enum CameraSettingStatus
{
    AlreadyOk,
    Added,
    Changed,
    NotFound,
    Failed,
}

internal sealed class CameraSettingResult
{
    public CameraSettingResult(
        CameraSettingStatus status,
        string message,
        string? settingsPath = null,
        string? backupPath = null)
    {
        Status = status;
        Message = message;
        SettingsPath = settingsPath;
        BackupPath = backupPath;
    }

    public CameraSettingStatus Status { get; }
    public string Message { get; }
    public string? SettingsPath { get; }
    public string? BackupPath { get; }
    public bool WasModified =>
        Status == CameraSettingStatus.Added || Status == CameraSettingStatus.Changed;
}

internal static class CameraSettings
{
    private const string SettingName = "CamSpringLockCardinalDirections";
    private const string DesiredLine = SettingName + " = 0";
    private static readonly Regex SettingLine = new Regex(
        @"^[ \t]*CamSpringLockCardinalDirections[ \t]*=[ \t]*(?<value>[^\r\n]*?)[ \t]*(?=\r?$)",
        RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.Multiline);

    public static CameraSettingResult EnsureCardinalDirectionLockDisabled(string? explicitSettingsPath)
    {
        string settingsPath = ResolveSettingsPath(explicitSettingsPath);
        if (!File.Exists(settingsPath))
        {
            return new CameraSettingResult(
                CameraSettingStatus.NotFound,
                "Failed to find springsettings.cfg. Expected: " + settingsPath,
                settingsPath);
        }

        try
        {
            string content = File.ReadAllText(settingsPath);
            MatchCollection matches = SettingLine.Matches(content);
            if (matches.Count > 0)
            {
                bool allAlreadyZero = true;
                foreach (Match match in matches)
                {
                    if (!string.Equals(match.Groups["value"].Value.Trim(), "0", StringComparison.Ordinal))
                    {
                        allAlreadyZero = false;
                        break;
                    }
                }

                if (allAlreadyZero)
                {
                    return new CameraSettingResult(
                        CameraSettingStatus.AlreadyOk,
                        "Camera setting already OK: " + DesiredLine,
                        settingsPath);
                }

                string backupPath = CreateBackup(settingsPath);
                string updated = SettingLine.Replace(content, DesiredLine);
                File.WriteAllText(settingsPath, updated, new UTF8Encoding(false));
                return new CameraSettingResult(
                    CameraSettingStatus.Changed,
                    "Changed existing camera setting: " + DesiredLine,
                    settingsPath,
                    backupPath);
            }

            string addedBackupPath = CreateBackup(settingsPath);
            string newline = content.Contains("\r\n", StringComparison.Ordinal) ? "\r\n" : "\n";
            string separator = content.Length == 0 || content.EndsWith("\n", StringComparison.Ordinal)
                ? string.Empty
                : newline;
            File.WriteAllText(
                settingsPath,
                content + separator + DesiredLine + newline,
                new UTF8Encoding(false));
            return new CameraSettingResult(
                CameraSettingStatus.Added,
                "Added missing camera setting: " + DesiredLine,
                settingsPath,
                addedBackupPath);
        }
        catch (Exception exception)
        {
            return new CameraSettingResult(
                CameraSettingStatus.Failed,
                "Failed to update camera setting: " + exception.Message,
                settingsPath);
        }
    }

    public static bool IsBarRunning()
    {
        foreach (Process process in Process.GetProcesses())
        {
            try
            {
                string name = process.ProcessName;
                if (name.IndexOf("Beyond-All-Reason", StringComparison.OrdinalIgnoreCase) >= 0
                    || name.IndexOf("spring", StringComparison.OrdinalIgnoreCase) >= 0
                    || name.IndexOf("recoil", StringComparison.OrdinalIgnoreCase) >= 0
                    || name.IndexOf("chobby", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
            catch
            {
                // A protected process can disappear while the process list is inspected.
            }
            finally
            {
                process.Dispose();
            }
        }

        return false;
    }

    private static string ResolveSettingsPath(string? explicitSettingsPath)
    {
        if (!string.IsNullOrWhiteSpace(explicitSettingsPath))
        {
            return Path.GetFullPath(Environment.ExpandEnvironmentVariables(explicitSettingsPath));
        }

        string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string workspacePathFile = Path.Combine(
            userProfile,
            "Dev",
            "BAR_Controller_Companion",
            "BAR_DATA_PATH.txt");
        string? configuredDataPath = ReadDataPath(workspacePathFile);
        if (configuredDataPath == null)
        {
            configuredDataPath = ReadDataPath(Path.Combine(AppContext.BaseDirectory, "BAR_DATA_PATH.txt"));
        }
        if (configuredDataPath != null)
        {
            return Path.GetFileName(configuredDataPath).Equals(
                "springsettings.cfg",
                StringComparison.OrdinalIgnoreCase)
                ? configuredDataPath
                : Path.Combine(configuredDataPath, "springsettings.cfg");
        }

        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(
            localAppData,
            "Programs",
            "Beyond-All-Reason",
            "data",
            "springsettings.cfg");
    }

    private static string? ReadDataPath(string pathFile)
    {
        if (!File.Exists(pathFile))
        {
            return null;
        }

        try
        {
            foreach (string sourceLine in File.ReadAllLines(pathFile))
            {
                string line = Environment.ExpandEnvironmentVariables(sourceLine.Trim().Trim('"'));
                if (line.Length > 0 && !line.StartsWith("#", StringComparison.Ordinal) && Path.IsPathRooted(line))
                {
                    return Path.GetFullPath(line);
                }
            }
        }
        catch
        {
            return null;
        }

        return null;
    }

    private static string CreateBackup(string settingsPath)
    {
        string timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmssfff");
        string backupPath = settingsPath + ".bar-controller-backup-" + timestamp;
        int suffix = 1;
        while (File.Exists(backupPath))
        {
            backupPath = settingsPath + ".bar-controller-backup-" + timestamp + "-" + suffix;
            suffix++;
        }

        File.Copy(settingsPath, backupPath, false);
        return backupPath;
    }
}
