using System;
using System.Collections.Generic;

internal enum BridgeTone
{
    Neutral,
    Good,
    Warning,
    Caution,
    Bad,
    Accent
}

internal static class BridgeConsole
{
    internal const int Width = 68;
    private static readonly object Sync = new object();

    public static void WriteHeader(
        string banner,
        string cameraStatus,
        string udpEndpoint,
        string controllerStatus,
        string engineStatus)
    {
        WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
        WriteLine(FormatCentered(banner), BridgeTone.Accent);
        WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
        WriteLine(FormatRow("Camera", cameraStatus), CameraTone(cameraStatus));
        WriteLine(FormatRow("UDP", udpEndpoint), BridgeTone.Neutral);
        WriteLine(FormatRow("Controller", controllerStatus), BridgeTone.Warning);
        WriteLine(FormatRow("Engine", engineStatus), BridgeTone.Warning);
        WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
        WriteStatus("Control", "Ctrl+C stops the bridge", BridgeTone.Neutral);
    }

    public static void WriteStatus(string label, string value, BridgeTone tone = BridgeTone.Neutral)
    {
        ConsoleInteractionCoordinator.Instance.WriteStatus(label, value, tone);
    }

    public static void WriteStatus(IConsoleSession session, string label, string value, BridgeTone tone = BridgeTone.Neutral)
    {
        session.WriteStatus(label, value, tone);
    }

    public static T RunExclusive<T>(Func<T> action)
    {
        lock (Sync) return action();
    }

    public static void RenderUpdatePanelOnce(
        string installedVersion,
        string installedTag,
        string availableVersion,
        string availableTag,
        DateTimeOffset publishedAt,
        IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        RunExclusive(() =>
        {
            WriteBoxTitle("CONTROLLER SUPPORT UPDATE FOUND", BridgeTone.Warning, session);
            WriteLine(FormatRow("Installed", installedVersion), BridgeTone.Good, session);
            WriteLine(FormatDetail(installedTag), BridgeTone.Good, session);
            WriteLine(FormatRow("Available", availableVersion), BridgeTone.Warning, session);
            WriteLine(FormatDetail(availableTag), BridgeTone.Warning, session);
            WriteLine(FormatRow("Published", publishedAt.ToString("yyyy-MM-dd")), BridgeTone.Neutral, session);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent, session);
            WriteLine(FormatOption("[U] Update now"), BridgeTone.Good, session);
            WriteLine(FormatOption("[N] Not now"), BridgeTone.Neutral, session);
            WriteLine(FormatOption("[V] View release notes"), BridgeTone.Accent, session);
            WriteLine(FormatOption("[R] Recovery Mode"), BridgeTone.Caution, session);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent, session);
            WriteLine("Type U, N, V, or R, then press Enter.", BridgeTone.Neutral, session);
            session.Output.Write("Choice [U/N/V/R]: ");
            return true;
        });
    }

    public static ControllerUpdatePromptAction ReadUpdateChoiceLine(
        string installedVersion,
        string installedTag,
        string availableVersion,
        string availableTag,
        DateTimeOffset publishedAt,
        IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        RenderUpdatePanelOnce(installedVersion, installedTag, availableVersion, availableTag, publishedAt, session);

        while (true)
        {
            string? line = session.ReadLine();
            ControllerUpdatePromptAction action = ControllerUpdatePolicy.ResolvePromptAction(line);
            if (action == ControllerUpdatePromptAction.BlankInput)
            {
                session.Output.Write("Enter U, N, V, or R: ");
                continue;
            }
            if (action == ControllerUpdatePromptAction.Invalid)
            {
                session.Output.Write("Invalid choice. Type U, N, V, or R, then press Enter: ");
                continue;
            }
            return action;
        }
    }

    public static ConsoleKey ReadUpdateChoice(
        string installedVersion,
        string installedTag,
        string availableVersion,
        string availableTag,
        DateTimeOffset publishedAt)
    {
        ControllerUpdatePromptAction action = ReadUpdateChoiceLine(
            installedVersion, installedTag, availableVersion, availableTag, publishedAt);
        return action switch
        {
            ControllerUpdatePromptAction.Update => ConsoleKey.U,
            ControllerUpdatePromptAction.NotNow => ConsoleKey.N,
            ControllerUpdatePromptAction.ViewNotes => ConsoleKey.V,
            ControllerUpdatePromptAction.Recovery => ConsoleKey.R,
            _ => ConsoleKey.NoName,
        };
    }

    public static ConsoleKey ReadRecoveryChoice(
        IReadOnlyList<string> rows,
        int page,
        int pageCount,
        IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        return RunExclusive(() =>
        {
            WriteBoxTitle("RECOVERY MODE", BridgeTone.Accent, session);
            WriteLine(FormatOption("Select a release to install or restore."), BridgeTone.Neutral, session);
            WriteLine(FormatOption("Versions older than v0.6.0 are intentionally hidden."), BridgeTone.Neutral, session);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent, session);
            foreach (string row in rows) WriteLine(FormatOption(row), ToneForIndicator(row), session);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent, session);
            WriteLine(FormatOption("Page " + page + "/" + pageCount), BridgeTone.Neutral, session);
            WriteLine(FormatOption("[Number] Details  [N] Next  [P] Previous  [B] Back  [Q] Quit"), BridgeTone.Neutral, session);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent, session);
            WriteLine("Type option number or N/P/B/Q, then press Enter.", BridgeTone.Neutral, session);
            session.Output.Write("Choice: ");

            while (true)
            {
                string? line = session.ReadLine()?.Trim();
                if (string.IsNullOrEmpty(line))
                {
                    session.Output.Write("Enter option number or N/P/B/Q: ");
                    continue;
                }
                if (int.TryParse(line, out int number) && number >= 1 && number <= 9)
                {
                    return (ConsoleKey)((int)ConsoleKey.D0 + number);
                }
                if (string.Equals(line, "n", StringComparison.OrdinalIgnoreCase) || string.Equals(line, "next", StringComparison.OrdinalIgnoreCase)) return ConsoleKey.N;
                if (string.Equals(line, "p", StringComparison.OrdinalIgnoreCase) || string.Equals(line, "prev", StringComparison.OrdinalIgnoreCase) || string.Equals(line, "previous", StringComparison.OrdinalIgnoreCase)) return ConsoleKey.P;
                if (string.Equals(line, "b", StringComparison.OrdinalIgnoreCase) || string.Equals(line, "back", StringComparison.OrdinalIgnoreCase)) return ConsoleKey.B;
                if (string.Equals(line, "q", StringComparison.OrdinalIgnoreCase) || string.Equals(line, "quit", StringComparison.OrdinalIgnoreCase)) return ConsoleKey.Q;
                session.Output.Write("Invalid choice. Type option number or N/P/B/Q, then press Enter: ");
            }
        });
    }

    public static bool ConfirmReleaseAction(string action, string displayVersion, string tag, bool warning, IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        return RunExclusive(() =>
        {
            WriteBoxTitle(action.ToUpperInvariant(), warning ? BridgeTone.Caution : BridgeTone.Accent, session);
            WriteLine(FormatRow("Release", displayVersion), warning ? BridgeTone.Caution : BridgeTone.Neutral, session);
            WriteLine(FormatDetail(tag), BridgeTone.Neutral, session);
            WriteLine(FormatOption("Confirm action? [y/N]"), BridgeTone.Warning, session);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent, session);
            session.Output.Write("Choice [y/N]: ");
            string? line = session.ReadLine()?.Trim();
            return string.Equals(line, "y", StringComparison.OrdinalIgnoreCase)
                || string.Equals(line, "yes", StringComparison.OrdinalIgnoreCase);
        });
    }

    public static void WriteReleaseDetails(
        string displayVersion,
        string tag,
        string title,
        DateTimeOffset publishedAt,
        string summary,
        string indicators,
        IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        RunExclusive(() =>
        {
            WriteBoxTitle("RELEASE DETAILS", BridgeTone.Accent, session);
            WriteLine(FormatRow("Version", displayVersion), BridgeTone.Neutral, session);
            WriteLine(FormatRow("Tag", tag), BridgeTone.Neutral, session);
            WriteLine(FormatRow("Date", publishedAt.ToString("yyyy-MM-dd")), BridgeTone.Neutral, session);
            WriteLine(FormatRow("Status", indicators), ToneForIndicator(indicators), session);
            WriteLine(FormatRow("Title", title), BridgeTone.Neutral, session);
            foreach (string line in Wrap(summary, Width - 4)) WriteLine(FormatOption(line), BridgeTone.Neutral, session);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent, session);
            WriteLine("Press Enter to return to the update choices.", BridgeTone.Neutral, session);
            session.ReadLine();
            return true;
        });
    }

    public static void WriteLuaUiResetWarning(bool nativeOverrideChanged, IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        RunExclusive(() =>
        {
            WriteBoxTitle("UPDATE INSTALLED WHILE BEYOND ALL REASON IS RUNNING", BridgeTone.Warning, session);
            WriteLine(FormatOption("Enter the following command in the in-game chat/console:"), BridgeTone.Warning, session);
            WriteLine(FormatCentered("/luaui reset"), BridgeTone.Good, session);
            WriteLine(FormatOption("This reloads the updated controller widgets."), BridgeTone.Warning, session);
            WriteLine(FormatOption("Active controller menus, selections, or commands may reset."), BridgeTone.Warning, session);
            if (nativeOverrideChanged)
            {
                WriteLine(FormatOption("Native overrides were replaced; non-Lua content may need an engine restart."), BridgeTone.Caution, session);
            }
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent, session);
            return true;
        });
    }

    internal static string FormatRow(string label, string value)
    {
        string prefix = "| " + ToAscii(label).PadRight(12) + " | ";
        int contentWidth = Width - prefix.Length - 2;
        string content = Fit(ToAscii(value), contentWidth);
        return prefix + content.PadRight(contentWidth) + " |";
    }

    internal static string FormatCentered(string value)
    {
        string content = Fit(ToAscii(value), Width - 4);
        int remaining = Width - 2 - content.Length;
        int left = remaining / 2;
        int right = remaining - left;
        return "|" + new string(' ', left) + content + new string(' ', right) + "|";
    }

    internal static string FormatDetail(string value) => FormatOption("  " + value);

    internal static string FormatOption(string value)
    {
        string content = Fit(ToAscii(value), Width - 4);
        return "| " + content.PadRight(Width - 4) + " |";
    }

    internal static bool SupportsColor(bool outputRedirected, string? noColor)
    {
        return !outputRedirected && string.IsNullOrEmpty(noColor);
    }

    internal static string ToAscii(string? value)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        char[] chars = value.ToCharArray();
        for (int index = 0; index < chars.Length; index++)
        {
            if (chars[index] < 32 || chars[index] > 126) chars[index] = '?';
        }
        return new string(chars);
    }

    private static string Fit(string value, int width)
    {
        if (value.Length <= width) return value;
        if (width <= 3) return value.Substring(0, Math.Max(0, width));
        return value.Substring(0, width - 3) + "...";
    }

    private static BridgeTone CameraTone(string status)
    {
        if (status.IndexOf("failed", StringComparison.OrdinalIgnoreCase) >= 0) return BridgeTone.Bad;
        if (status.IndexOf("ready", StringComparison.OrdinalIgnoreCase) >= 0
            || status.IndexOf("disabled", StringComparison.OrdinalIgnoreCase) >= 0) return BridgeTone.Good;
        return BridgeTone.Warning;
    }

    private static void WriteLine(string value, BridgeTone tone, IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        session.WriteLine(value, tone);
    }

    private static void WriteBoxTitle(string title, BridgeTone tone, IConsoleSession? session = null)
    {
        WriteLine("+" + new string('-', Width - 2) + "+", tone, session);
        WriteLine(FormatCentered(title), tone, session);
        WriteLine("+" + new string('-', Width - 2) + "+", tone, session);
    }

    private static BridgeTone ToneForIndicator(string value)
    {
        if (value.IndexOf("Unavailable", StringComparison.OrdinalIgnoreCase) >= 0) return BridgeTone.Bad;
        if (value.IndexOf("Installed", StringComparison.OrdinalIgnoreCase) >= 0) return BridgeTone.Good;
        if (value.IndexOf("Latest", StringComparison.OrdinalIgnoreCase) >= 0) return BridgeTone.Warning;
        if (value.IndexOf("Legacy", StringComparison.OrdinalIgnoreCase) >= 0
            || value.IndexOf("Prerelease", StringComparison.OrdinalIgnoreCase) >= 0) return BridgeTone.Caution;
        return BridgeTone.Neutral;
    }

    private static string[] Wrap(string value, int width)
    {
        string ascii = ToAscii(value);
        if (ascii.Length == 0) return new[] { string.Empty };
        var result = new System.Collections.Generic.List<string>();
        while (ascii.Length > width)
        {
            int split = ascii.LastIndexOf(' ', width);
            if (split <= 0) split = width;
            result.Add(ascii.Substring(0, split).Trim());
            ascii = ascii.Substring(split).TrimStart();
        }
        result.Add(ascii);
        return result.ToArray();
    }

    internal static ConsoleColor ToneColor(BridgeTone tone)
    {
        switch (tone)
        {
            case BridgeTone.Good: return ConsoleColor.Green;
            case BridgeTone.Warning: return ConsoleColor.Yellow;
            case BridgeTone.Caution: return ConsoleColor.DarkYellow;
            case BridgeTone.Bad: return ConsoleColor.Red;
            case BridgeTone.Accent: return ConsoleColor.Cyan;
            default: return ConsoleColor.Gray;
        }
    }
}
