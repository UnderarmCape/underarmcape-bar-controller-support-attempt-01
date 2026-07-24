using System;
using System.Collections.Generic;
using System.IO;

internal enum ControllerUpdatePromptAction
{
    None,
    Update,
    NotNow,
    ViewNotes,
    Recovery,
    BlankInput,
    Invalid,
}

internal static class ControllerUpdatePolicy
{
    public static ControllerUpdatePromptAction ResolvePromptAction(ConsoleKey key)
    {
        return key switch
        {
            ConsoleKey.U => ControllerUpdatePromptAction.Update,
            ConsoleKey.N => ControllerUpdatePromptAction.NotNow,
            ConsoleKey.V => ControllerUpdatePromptAction.ViewNotes,
            ConsoleKey.R => ControllerUpdatePromptAction.Recovery,
            _ => ControllerUpdatePromptAction.None,
        };
    }

    public static ControllerUpdatePromptAction ResolvePromptAction(string? line)
    {
        if (line == null) return ControllerUpdatePromptAction.None;
        string trimmed = line.Trim();
        if (trimmed.Length == 0) return ControllerUpdatePromptAction.BlankInput;

        if (string.Equals(trimmed, "u", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "update", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "update now", StringComparison.OrdinalIgnoreCase))
        {
            return ControllerUpdatePromptAction.Update;
        }
        if (string.Equals(trimmed, "n", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "no", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "not now", StringComparison.OrdinalIgnoreCase))
        {
            return ControllerUpdatePromptAction.NotNow;
        }
        if (string.Equals(trimmed, "v", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "view", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "view notes", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "release notes", StringComparison.OrdinalIgnoreCase))
        {
            return ControllerUpdatePromptAction.ViewNotes;
        }
        if (string.Equals(trimmed, "r", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "recovery", StringComparison.OrdinalIgnoreCase)
            || string.Equals(trimmed, "recovery mode", StringComparison.OrdinalIgnoreCase))
        {
            return ControllerUpdatePromptAction.Recovery;
        }

        return ControllerUpdatePromptAction.Invalid;
    }

    public static bool CanPrompt(bool interactive, bool inputRedirected, bool outputRedirected)
        => interactive && !inputRedirected && !outputRedirected;

    public static bool IsAtOrAboveRecoveryFloor(string version)
        => Version.Parse(ControllerReleaseSecurity.NormalizeVersion(version)) >= new Version(0, 6, 0);

    public static string Indicators(ControllerReleaseCatalogItem item)
    {
        var values = new List<string>();
        if (item.IsLatest) values.Add("[Latest]");
        if (item.IsInstalled) values.Add("[Installed]");
        if (item.IsPrerelease) values.Add("[Prerelease]");
        if (item.IsLegacy) values.Add("[Legacy]");
        if (!item.IsAvailable) values.Add("[Unavailable]");
        return string.Join(" ", values);
    }

    public static bool RequiresConfirmation(
        InstalledControllerReleaseState? installed,
        ControllerReleaseCatalogItem target)
        => installed != null && (installed.ReleaseTag == target.Tag
            || target.ReleaseSequence <= installed.ReleaseSequence);

    public static string RunningBarGuidance(bool barRunning, bool luaChanged, bool nativeOverrideChanged)
    {
        if (!barRunning || !luaChanged) return string.Empty;
        return nativeOverrideChanged
            ? "/luaui reset; native overrides changed, so non-Lua content may still require an engine restart."
            : "/luaui reset";
    }
}

internal static class ControllerUpdaterGuard
{
    public static bool ProcessPathMatches(string actualPath, string expectedPath)
    {
        if (string.IsNullOrWhiteSpace(actualPath) || string.IsNullOrWhiteSpace(expectedPath)) return false;
        return Path.GetFullPath(actualPath).Equals(
            Path.GetFullPath(expectedPath), StringComparison.OrdinalIgnoreCase);
    }

    public static bool WaitsForBarProcess => false;
}
