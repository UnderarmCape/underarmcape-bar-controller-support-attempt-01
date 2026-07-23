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
        WriteLine("[" + ToAscii(label) + "] " + ToAscii(value), tone);
    }

    public static T RunExclusive<T>(Func<T> action)
    {
        lock (Sync) return action();
    }

    public static ConsoleKey ReadUpdateChoice(
        string installedVersion,
        string installedTag,
        string availableVersion,
        string availableTag,
        DateTimeOffset publishedAt)
    {
        return RunExclusive(() =>
        {
            WriteBoxTitle("CONTROLLER SUPPORT UPDATE FOUND", BridgeTone.Warning);
            WriteLine(FormatRow("Installed", installedVersion), BridgeTone.Good);
            WriteLine(FormatDetail(installedTag), BridgeTone.Good);
            WriteLine(FormatRow("Available", availableVersion), BridgeTone.Warning);
            WriteLine(FormatDetail(availableTag), BridgeTone.Warning);
            WriteLine(FormatRow("Published", publishedAt.ToString("yyyy-MM-dd")), BridgeTone.Neutral);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
            WriteLine(FormatOption("[U] Update now"), BridgeTone.Good);
            WriteLine(FormatOption("[N] Not now"), BridgeTone.Neutral);
            WriteLine(FormatOption("[V] View release notes"), BridgeTone.Accent);
            WriteLine(FormatOption("[R] Recovery Mode"), BridgeTone.Caution);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
            return Console.ReadKey(intercept: true).Key;
        });
    }

    public static ConsoleKey ReadRecoveryChoice(
        IReadOnlyList<string> rows,
        int page,
        int pageCount)
    {
        return RunExclusive(() =>
        {
            WriteBoxTitle("RECOVERY MODE", BridgeTone.Accent);
            WriteLine(FormatOption("Select a release to install or restore."), BridgeTone.Neutral);
            WriteLine(FormatOption("Versions older than v0.6.0 are intentionally hidden."), BridgeTone.Neutral);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
            foreach (string row in rows) WriteLine(FormatOption(row), ToneForIndicator(row));
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
            WriteLine(FormatOption("Page " + page + "/" + pageCount), BridgeTone.Neutral);
            WriteLine(FormatOption("[Number] Details  [N] Next  [P] Previous  [B] Back  [Q] Quit"), BridgeTone.Neutral);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
            return Console.ReadKey(intercept: true).Key;
        });
    }

    public static bool ConfirmReleaseAction(string action, string displayVersion, string tag, bool warning)
    {
        return RunExclusive(() =>
        {
            WriteBoxTitle(action.ToUpperInvariant(), warning ? BridgeTone.Caution : BridgeTone.Accent);
            WriteLine(FormatRow("Release", displayVersion), warning ? BridgeTone.Caution : BridgeTone.Neutral);
            WriteLine(FormatDetail(tag), BridgeTone.Neutral);
            WriteLine(FormatOption("Press Y to confirm or any other key to cancel."), BridgeTone.Warning);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
            return Console.ReadKey(intercept: true).Key == ConsoleKey.Y;
        });
    }

    public static void WriteReleaseDetails(
        string displayVersion,
        string tag,
        string title,
        DateTimeOffset publishedAt,
        string summary,
        string indicators)
    {
        RunExclusive(() =>
        {
            WriteBoxTitle("RELEASE DETAILS", BridgeTone.Accent);
            WriteLine(FormatRow("Version", displayVersion), BridgeTone.Neutral);
            WriteLine(FormatRow("Tag", tag), BridgeTone.Neutral);
            WriteLine(FormatRow("Date", publishedAt.ToString("yyyy-MM-dd")), BridgeTone.Neutral);
            WriteLine(FormatRow("Status", indicators), ToneForIndicator(indicators));
            WriteLine(FormatRow("Title", title), BridgeTone.Neutral);
            foreach (string line in Wrap(summary, Width - 4)) WriteLine(FormatOption(line), BridgeTone.Neutral);
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
            return true;
        });
    }

    public static void WriteLuaUiResetWarning(bool nativeOverrideChanged)
    {
        RunExclusive(() =>
        {
            WriteBoxTitle("UPDATE INSTALLED WHILE BEYOND ALL REASON IS RUNNING", BridgeTone.Warning);
            WriteLine(FormatOption("Enter the following command in the in-game chat/console:"), BridgeTone.Warning);
            WriteLine(FormatCentered("/luaui reset"), BridgeTone.Good);
            WriteLine(FormatOption("This reloads the updated controller widgets."), BridgeTone.Warning);
            WriteLine(FormatOption("Active controller menus, selections, or commands may reset."), BridgeTone.Warning);
            if (nativeOverrideChanged)
            {
                WriteLine(FormatOption("Native overrides were replaced; non-Lua content may need an engine restart."), BridgeTone.Caution);
            }
            WriteLine("+" + new string('-', Width - 2) + "+", BridgeTone.Accent);
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

    private static void WriteLine(string value, BridgeTone tone)
    {
        lock (Sync)
        {
            bool useColor = SupportsColor(Console.IsOutputRedirected, Environment.GetEnvironmentVariable("NO_COLOR"));
            if (!useColor)
            {
                Console.WriteLine(ToAscii(value));
                return;
            }

            ConsoleColor previous = Console.ForegroundColor;
            try
            {
                Console.ForegroundColor = ToneColor(tone);
                Console.WriteLine(ToAscii(value));
            }
            catch (Exception)
            {
                Console.WriteLine(ToAscii(value));
            }
            finally
            {
                try { Console.ForegroundColor = previous; } catch (Exception) { }
            }
        }
    }

    private static void WriteBoxTitle(string title, BridgeTone tone)
    {
        WriteLine("+" + new string('-', Width - 2) + "+", tone);
        WriteLine(FormatCentered(title), tone);
        WriteLine("+" + new string('-', Width - 2) + "+", tone);
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

    private static ConsoleColor ToneColor(BridgeTone tone)
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
