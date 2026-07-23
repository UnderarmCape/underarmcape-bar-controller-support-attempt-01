using System;

internal enum BridgeTone
{
    Neutral,
    Good,
    Warning,
    Bad,
    Accent
}

internal static class BridgeConsole
{
    internal const int Width = 68;

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

    private static ConsoleColor ToneColor(BridgeTone tone)
    {
        switch (tone)
        {
            case BridgeTone.Good: return ConsoleColor.Green;
            case BridgeTone.Warning: return ConsoleColor.Yellow;
            case BridgeTone.Bad: return ConsoleColor.Red;
            case BridgeTone.Accent: return ConsoleColor.Cyan;
            default: return ConsoleColor.Gray;
        }
    }
}
