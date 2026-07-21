using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

internal static class ReleaseOperations
{
    public const string ExpectedPackageName = "BAR Controller Companion";
    public const string InstallerFileName = "BAR_Controller_Companion_Installer_v0.6.1.exe";
    public const string RestoreFileName = "BAR_Controller_Companion_Restore_v0.6.1.exe";
    public const string StateFileName = "install-state.json";
    private const string CameraSettingLine = "CamSpringLockCardinalDirections = 0";
    private static readonly string[] RequiredWidgetNames =
    {
        "Controller Camera Test",
        "Controller Bindings UI",
        "Controller UI Layout",
    };
    private static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    public static PackageManifest ReadAndValidateManifest(string packageRoot)
    {
        string manifestPath = Path.Combine(packageRoot, "manifest.json");
        if (!File.Exists(manifestPath))
        {
            throw new FileNotFoundException("Package manifest is missing.", manifestPath);
        }

        PackageManifest? manifest = JsonSerializer.Deserialize<PackageManifest>(
            File.ReadAllText(manifestPath),
            JsonOptions);
        if (manifest == null || !string.Equals(
            manifest.PackageName,
            ExpectedPackageName,
            StringComparison.Ordinal))
        {
            throw new InvalidDataException("The package manifest has an unexpected package name.");
        }
        if (!Version.TryParse(manifest.Version, out _))
        {
            throw new InvalidDataException("The package manifest version is invalid.");
        }

        foreach (string relativePath in manifest.RequiredLuaFiles
            .Concat(manifest.RequiredBarDataFiles)
            .Concat(manifest.RequiredCompanionFiles)
            .Concat(manifest.RequiredPublicFiles))
        {
            string candidate = ResolveInside(packageRoot, relativePath);
            if (!File.Exists(candidate))
            {
                throw new FileNotFoundException(
                    "Required package file is missing: " + relativePath,
                    candidate);
            }
        }

        return manifest;
    }

    public static InstallState ReadState(string installRoot, string version)
    {
        string statePath = Path.Combine(installRoot, StateFileName);
        if (File.Exists(statePath))
        {
            try
            {
                InstallState? existing = JsonSerializer.Deserialize<InstallState>(
                    File.ReadAllText(statePath),
                    JsonOptions);
                if (existing != null)
                {
                    existing.Shortcuts ??= new List<ShortcutBackup>();
                    existing.LuaWidgets ??= new List<FileBackup>();
                    existing.BarDataFiles ??= new List<FileBackup>();
                    existing.CompanionFiles ??= new List<FileBackup>();
                    existing.Version = version;
                    return existing;
                }
            }
            catch (Exception exception)
            {
                Status("Existing install state could not be read: " + exception.Message);
            }
        }

        return new InstallState { Version = version };
    }

    public static void SaveState(string installRoot, InstallState state)
    {
        state.LastInstalled = DateTimeOffset.Now;
        File.WriteAllText(
            Path.Combine(installRoot, StateFileName),
            JsonSerializer.Serialize(state, JsonOptions),
            new UTF8Encoding(false));
    }

    public static void InstallCompanionFiles(
        string packageRoot,
        PackageManifest manifest,
        string installRoot,
        string backupRoot,
        InstallState state)
    {
        Directory.CreateDirectory(installRoot);
        foreach (string relativePath in manifest.RequiredCompanionFiles)
        {
            string source = ResolveInside(packageRoot, relativePath);
            string destination = Path.Combine(installRoot, Path.GetFileName(relativePath));
            FileBackup? existing = state.CompanionFiles.FirstOrDefault(
                item => PathsEqual(item.Destination, destination));
            if (existing == null)
            {
                existing = CaptureFileBackup(destination, Path.Combine(backupRoot, "Companion"));
                state.CompanionFiles.Add(existing);
            }
            File.Copy(source, destination, true);
            Status("Installed companion file: " + destination);
        }

        string restoreSource = Path.Combine(packageRoot, RestoreFileName);
        if (File.Exists(restoreSource))
        {
            File.Copy(restoreSource, Path.Combine(installRoot, RestoreFileName), true);
            Status("Installed restore tool: " + Path.Combine(installRoot, RestoreFileName));
        }
    }

    public static void InstallLuaWidgets(
        string packageRoot,
        PackageManifest manifest,
        string barDataPath,
        string backupRoot,
        InstallState state)
    {
        string destinationRoot = Path.Combine(barDataPath, "LuaUI", "Widgets");
        Directory.CreateDirectory(destinationRoot);

        foreach (string relativePath in manifest.RequiredLuaFiles)
        {
            string source = ResolveInside(packageRoot, relativePath);
            string destination = Path.Combine(destinationRoot, Path.GetFileName(relativePath));
            FileBackup? existing = state.LuaWidgets.FirstOrDefault(
                item => PathsEqual(item.Destination, destination));
            if (existing == null)
            {
                existing = CaptureFileBackup(destination, Path.Combine(backupRoot, "LuaUI", "Widgets"));
                state.LuaWidgets.Add(existing);
            }
            File.Copy(source, destination, true);
            Status("Installed Lua widget: " + destination);
        }
    }

    public static void InstallBarDataFiles(
        string packageRoot,
        PackageManifest manifest,
        string barDataPath,
        string backupRoot,
        InstallState state)
    {
        string destinationRoot = Path.GetFullPath(barDataPath).TrimEnd(Path.DirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        foreach (string relativePath in manifest.RequiredBarDataFiles)
        {
            string source = ResolveInside(packageRoot, relativePath);
            string normalized = relativePath.Replace('/', Path.DirectorySeparatorChar);
            string destination = Path.GetFullPath(Path.Combine(barDataPath, normalized));
            if (!destination.StartsWith(destinationRoot, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException(
                    "BAR data payload escapes its destination: " + relativePath);
            }
            FileBackup? existing = state.BarDataFiles.FirstOrDefault(
                item => PathsEqual(item.Destination, destination));
            if (existing == null)
            {
                string backupDirectory = Path.Combine(
                    backupRoot,
                    "BARData",
                    Path.GetDirectoryName(normalized) ?? string.Empty);
                existing = CaptureFileBackup(destination, backupDirectory);
                state.BarDataFiles.Add(existing);
            }
            Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
            File.Copy(source, destination, true);
            Status("Installed BAR data file: " + destination);
        }
    }

    public static void EnableRequiredWidgets(
        string barDataPath,
        string backupRoot,
        InstallState state)
    {
        string configPath = Path.Combine(barDataPath, "LuaUI", "Config", "BYAR.lua");
        Directory.CreateDirectory(Path.GetDirectoryName(configPath)!);
        if (state.WidgetConfig == null)
        {
            state.WidgetConfig = CaptureFileBackup(
                configPath,
                Path.Combine(backupRoot, "LuaUI", "Config"));
        }

        string content = File.Exists(configPath)
            ? File.ReadAllText(configPath)
            : "return {\n\tallowUserWidgets = true,\n\tdata = {},\n\torder = {\n\t},\n}\n";
        string updated = PatchWidgetOrder(content, RequiredWidgetNames);
        File.WriteAllText(configPath, updated, new UTF8Encoding(false));

        foreach (string widgetName in RequiredWidgetNames)
        {
            Status("Enabled " + widgetName);
        }
    }

    public static bool EnsureCameraSetting(
        string settingsPath,
        string backupRoot,
        InstallState state)
    {
        const string pattern =
            @"^[ \t]*CamSpringLockCardinalDirections[ \t]*=[ \t]*(?<value>[^\r\n]*?)[ \t]*(?=\r?$)";
        Directory.CreateDirectory(Path.GetDirectoryName(settingsPath)!);
        string content = File.Exists(settingsPath) ? File.ReadAllText(settingsPath) : string.Empty;
        MatchCollection matches = Regex.Matches(
            content,
            pattern,
            RegexOptions.IgnoreCase | RegexOptions.Multiline);
        bool alreadyOk = matches.Count > 0
            && matches.Cast<Match>().All(match => match.Groups["value"].Value.Trim() == "0");
        if (alreadyOk)
        {
            Status("Camera setting already OK: " + CameraSettingLine);
            return false;
        }

        if (state.CameraSettings == null)
        {
            state.CameraSettings = CaptureFileBackup(
                settingsPath,
                Path.Combine(backupRoot, "Camera"));
        }

        string updated;
        if (matches.Count == 0)
        {
            string newline = content.Contains("\r\n", StringComparison.Ordinal) ? "\r\n" : "\n";
            string separator = content.Length == 0 || content.EndsWith("\n", StringComparison.Ordinal)
                ? string.Empty
                : newline;
            updated = content + separator + CameraSettingLine + newline;
            Status("Added missing camera setting: " + CameraSettingLine);
        }
        else
        {
            updated = Regex.Replace(
                content,
                pattern,
                CameraSettingLine,
                RegexOptions.IgnoreCase | RegexOptions.Multiline);
            Status("Changed existing camera setting: " + CameraSettingLine);
        }

        File.WriteAllText(settingsPath, updated, new UTF8Encoding(false));
        if (state.CameraSettings.BackupPath != null)
        {
            Status("Camera settings backup: " + state.CameraSettings.BackupPath);
        }
        return true;
    }

    public static void InstallShortcuts(
        IReadOnlyList<string> shortcutPaths,
        string installRoot,
        string settingsPath,
        string backupRoot,
        InstallState state)
    {
        string launcherPath = Path.Combine(installRoot, "BARControllerLauncher.exe");
        string bridgePath = Path.Combine(installRoot, "BARControllerBridge.exe");
        string configPath = Path.Combine(installRoot, "launcher-config.json");
        state.LauncherConfig ??= CaptureFileBackup(
            configPath,
            Path.Combine(backupRoot, "Companion"));
        ShortcutMetadata? launchMetadata = ReadExistingLauncherMetadata(configPath);
        Type shellType = Type.GetTypeFromProgID("WScript.Shell")
            ?? throw new PlatformNotSupportedException("WScript.Shell is unavailable.");
        dynamic shell = Activator.CreateInstance(shellType)
            ?? throw new InvalidOperationException("Could not create WScript.Shell.");

        foreach (string rawPath in shortcutPaths)
        {
            string shortcutPath = ExpandPath(rawPath);
            if (!File.Exists(shortcutPath))
            {
                Status("Shortcut not found; skipped: " + shortcutPath);
                continue;
            }

            dynamic shortcut = shell.CreateShortcut(shortcutPath);
            string targetPath = Convert.ToString(shortcut.TargetPath) ?? string.Empty;
            if (PathsEqual(targetPath, launcherPath))
            {
                Status("Shortcut already patched: " + shortcutPath);
                continue;
            }
            if (targetPath.IndexOf("Beyond-All-Reason", StringComparison.OrdinalIgnoreCase) < 0)
            {
                Status("Shortcut does not point to BAR; skipped: " + shortcutPath);
                continue;
            }

            string arguments = Convert.ToString(shortcut.Arguments) ?? string.Empty;
            string workingDirectory = Convert.ToString(shortcut.WorkingDirectory) ?? string.Empty;
            string iconLocation = Convert.ToString(shortcut.IconLocation) ?? string.Empty;
            string description = Convert.ToString(shortcut.Description) ?? string.Empty;
            launchMetadata ??= new ShortcutMetadata
            {
                TargetPath = targetPath,
                Arguments = arguments,
                WorkingDirectory = workingDirectory,
                IconLocation = iconLocation,
            };

            if (!state.Shortcuts.Any(item => PathsEqual(item.ShortcutPath, shortcutPath)))
            {
                string shortcutBackupRoot = Path.Combine(backupRoot, "Shortcuts");
                Directory.CreateDirectory(shortcutBackupRoot);
                string backupPath = Path.Combine(
                    shortcutBackupRoot,
                    SanitizeFileName(Path.GetFileNameWithoutExtension(shortcutPath))
                        + "-" + Guid.NewGuid().ToString("N") + ".lnk");
                File.Copy(shortcutPath, backupPath, false);
                state.Shortcuts.Add(new ShortcutBackup
                {
                    ShortcutPath = shortcutPath,
                    BackupPath = backupPath,
                    OriginalTargetPath = targetPath,
                    OriginalArguments = arguments,
                    OriginalWorkingDirectory = workingDirectory,
                    OriginalIconLocation = iconLocation,
                    OriginalDescription = description,
                });
            }

            shortcut.TargetPath = launcherPath;
            shortcut.Arguments = string.Empty;
            shortcut.WorkingDirectory = installRoot;
            if (!string.IsNullOrWhiteSpace(iconLocation))
            {
                shortcut.IconLocation = iconLocation;
            }
            shortcut.Description = description;
            shortcut.Save();
            Status("Patched BAR shortcut: " + shortcutPath);
        }

        launchMetadata ??= DefaultLaunchMetadata();
        var config = new LauncherConfig
        {
            OriginalTargetPath = launchMetadata.TargetPath,
            OriginalArguments = launchMetadata.Arguments,
            OriginalWorkingDirectory = launchMetadata.WorkingDirectory,
            OriginalIconLocation = launchMetadata.IconLocation,
            BridgePath = bridgePath,
            SettingsPath = settingsPath,
            BridgeStartupDelayMilliseconds = 900,
        };
        File.WriteAllText(
            configPath,
            JsonSerializer.Serialize(config, JsonOptions),
            new UTF8Encoding(false));
        Status("Wrote launcher config: " + configPath);
    }

    public static void Restore(string installRoot, bool restoreCamera)
    {
        string statePath = Path.Combine(installRoot, StateFileName);
        if (!File.Exists(statePath))
        {
            Status("Install state not found; nothing was restored: " + statePath, true);
            return;
        }

        InstallState state = JsonSerializer.Deserialize<InstallState>(
            File.ReadAllText(statePath),
            JsonOptions) ?? throw new InvalidDataException("Install state is invalid.");
        state.Shortcuts ??= new List<ShortcutBackup>();
        state.LuaWidgets ??= new List<FileBackup>();
        state.BarDataFiles ??= new List<FileBackup>();
        state.CompanionFiles ??= new List<FileBackup>();

        foreach (ShortcutBackup shortcut in state.Shortcuts)
        {
            if (File.Exists(shortcut.BackupPath))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(shortcut.ShortcutPath)!);
                File.Copy(shortcut.BackupPath, shortcut.ShortcutPath, true);
                Status("Restored shortcut: " + shortcut.ShortcutPath, true);
            }
            else
            {
                Status("Shortcut backup missing; skipped: " + shortcut.ShortcutPath, true);
            }
        }

        foreach (FileBackup widget in state.LuaWidgets)
        {
            RestoreFileBackup(widget, "Lua widget");
        }
        foreach (FileBackup payload in state.BarDataFiles)
        {
            RestoreFileBackup(payload, "BAR data file");
        }
        foreach (FileBackup companion in state.CompanionFiles)
        {
            RestoreFileBackup(companion, "companion file");
        }
        if (state.LauncherConfig != null)
        {
            RestoreFileBackup(state.LauncherConfig, "launcher config");
        }
        if (state.WidgetConfig != null)
        {
            RestoreFileBackup(state.WidgetConfig, "widget config");
        }
        else
        {
            Status("No widget config backup was recorded; skipped.", true);
        }

        if (restoreCamera)
        {
            if (state.CameraSettings != null)
            {
                RestoreFileBackup(state.CameraSettings, "camera settings");
                Status("Restart BAR for restored camera settings to take effect.", true);
            }
            else
            {
                Status("No camera settings backup was recorded; skipped.", true);
            }
        }
        else
        {
            Status("Camera setting left at CamSpringLockCardinalDirections = 0.", true);
        }

        Status("Restore complete. Recorded shortcuts, UI payload, companion files, and widgets were restored.", true);
    }

    public static string ExpandPath(string path)
    {
        return Path.GetFullPath(Environment.ExpandEnvironmentVariables(path));
    }

    public static void Status(string message, bool restore = false)
    {
        Console.WriteLine(
            restore
                ? "[BAR Controller Companion Restore] " + message
                : "[BAR Controller Companion] " + message);
    }

    private static string PatchWidgetOrder(string content, IEnumerable<string> widgetNames)
    {
        Match orderMatch = Regex.Match(content, @"(?m)^[ \t]*order[ \t]*=[ \t]*\{");
        if (!orderMatch.Success)
        {
            throw new InvalidDataException("BYAR.lua does not contain an order table.");
        }

        int openingBrace = content.IndexOf('{', orderMatch.Index);
        int closingBrace = FindMatchingBrace(content, openingBrace);
        string body = content.Substring(openingBrace + 1, closingBrace - openingBrace - 1);
        string newline = content.Contains("\r\n", StringComparison.Ordinal) ? "\r\n" : "\n";
        string indent = DetectOrderIndent(body) ?? "\t\t";

        foreach (string widgetName in widgetNames)
        {
            string pattern =
                @"(?m)^(?<indent>[ \t]*)\[""" + Regex.Escape(widgetName)
                + @"""\][ \t]*=[ \t]*-?\d+[ \t]*,?[ \t]*(?=\r?$)";
            if (Regex.IsMatch(body, pattern))
            {
                body = Regex.Replace(
                    body,
                    pattern,
                    match => match.Groups["indent"].Value + "[\"" + widgetName + "\"] = 1,");
            }
            else
            {
                string entry = indent + "[\"" + widgetName + "\"] = 1,";
                Match closingIndent = Regex.Match(body, @"(?<tail>\r?\n[ \t]*)\z");
                if (closingIndent.Success)
                {
                    body = body.Substring(0, closingIndent.Index)
                        + newline
                        + entry
                        + body.Substring(closingIndent.Index);
                }
                else
                {
                    string separator = body.Length == 0 || body.EndsWith("\n", StringComparison.Ordinal)
                        ? string.Empty
                        : newline;
                    body += separator + entry + newline;
                }
            }
        }

        return content.Substring(0, openingBrace + 1)
            + body
            + content.Substring(closingBrace);
    }

    private static int FindMatchingBrace(string content, int openingBrace)
    {
        int depth = 0;
        bool inSingle = false;
        bool inDouble = false;
        bool inLineComment = false;
        bool escaped = false;

        for (int index = openingBrace; index < content.Length; index++)
        {
            char current = content[index];
            char next = index + 1 < content.Length ? content[index + 1] : '\0';
            if (inLineComment)
            {
                if (current == '\n')
                {
                    inLineComment = false;
                }
                continue;
            }
            if (!inSingle && !inDouble && current == '-' && next == '-')
            {
                inLineComment = true;
                index++;
                continue;
            }
            if (escaped)
            {
                escaped = false;
                continue;
            }
            if ((inSingle || inDouble) && current == '\\')
            {
                escaped = true;
                continue;
            }
            if (!inDouble && current == '\'')
            {
                inSingle = !inSingle;
                continue;
            }
            if (!inSingle && current == '"')
            {
                inDouble = !inDouble;
                continue;
            }
            if (inSingle || inDouble)
            {
                continue;
            }
            if (current == '{')
            {
                depth++;
            }
            else if (current == '}' && --depth == 0)
            {
                return index;
            }
        }

        throw new InvalidDataException("BYAR.lua has an unterminated order table.");
    }

    private static string? DetectOrderIndent(string body)
    {
        Match match = Regex.Match(body, @"(?m)^(?<indent>[ \t]*)\[""");
        return match.Success ? match.Groups["indent"].Value : null;
    }

    private static FileBackup CaptureFileBackup(string destination, string backupDirectory)
    {
        bool existed = File.Exists(destination);
        string? backupPath = null;
        if (existed)
        {
            Directory.CreateDirectory(backupDirectory);
            backupPath = Path.Combine(backupDirectory, Path.GetFileName(destination));
            File.Copy(destination, backupPath, false);
        }
        return new FileBackup
        {
            Destination = destination,
            BackupPath = backupPath,
            ExistedBeforeInstall = existed,
        };
    }

    private static void RestoreFileBackup(FileBackup backup, string label)
    {
        if (!backup.ExistedBeforeInstall)
        {
            if (File.Exists(backup.Destination))
            {
                File.Delete(backup.Destination);
                Status("Removed newly installed " + label + ": " + backup.Destination, true);
            }
            else
            {
                Status(
                    char.ToUpperInvariant(label[0]) + label.Substring(1)
                        + " was already absent: " + backup.Destination,
                    true);
            }
            return;
        }
        if (backup.BackupPath != null && File.Exists(backup.BackupPath))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(backup.Destination)!);
            File.Copy(backup.BackupPath, backup.Destination, true);
            Status("Restored " + label + ": " + backup.Destination, true);
        }
        else
        {
            Status(char.ToUpperInvariant(label[0]) + label.Substring(1)
                + " backup missing; skipped: " + backup.Destination, true);
        }
    }

    private static ShortcutMetadata? ReadExistingLauncherMetadata(string configPath)
    {
        if (!File.Exists(configPath))
        {
            return null;
        }
        try
        {
            LauncherConfig? config = JsonSerializer.Deserialize<LauncherConfig>(
                File.ReadAllText(configPath),
                JsonOptions);
            return config == null ? null : new ShortcutMetadata
            {
                TargetPath = config.OriginalTargetPath,
                Arguments = config.OriginalArguments,
                WorkingDirectory = config.OriginalWorkingDirectory,
                IconLocation = config.OriginalIconLocation,
            };
        }
        catch
        {
            return null;
        }
    }

    private static ShortcutMetadata DefaultLaunchMetadata()
    {
        string target = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs",
            "Beyond-All-Reason",
            "Beyond-All-Reason.exe");
        Status("No readable BAR shortcut metadata found; using the standard BAR path.");
        return new ShortcutMetadata
        {
            TargetPath = target,
            WorkingDirectory = Path.GetDirectoryName(target) ?? string.Empty,
            IconLocation = target + ",0",
        };
    }

    private static string ResolveInside(string root, string relativePath)
    {
        string fullRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        string candidate = Path.GetFullPath(Path.Combine(root, relativePath));
        if (!candidate.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Manifest path escapes the package root: " + relativePath);
        }
        return candidate;
    }

    private static bool PathsEqual(string first, string second)
    {
        if (string.IsNullOrWhiteSpace(first) || string.IsNullOrWhiteSpace(second))
        {
            return false;
        }
        return string.Equals(
            Path.GetFullPath(first),
            Path.GetFullPath(second),
            StringComparison.OrdinalIgnoreCase);
    }

    private static string SanitizeFileName(string value)
    {
        foreach (char invalid in Path.GetInvalidFileNameChars())
        {
            value = value.Replace(invalid, '_');
        }
        return value;
    }
}
