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
