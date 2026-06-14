using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Threading;

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

internal static class Program
{
    private const string ConfigFileName = "launcher-config.json";
    private const string LogFileName = "launcher.log";

    [STAThread]
    private static int Main()
    {
        string baseDirectory = AppContext.BaseDirectory;
        string logPath = Path.Combine(baseDirectory, LogFileName);

        try
        {
            LauncherConfig config = LoadConfig(Path.Combine(baseDirectory, ConfigFileName));
            string bridgePath = ResolvePath(
                baseDirectory,
                string.IsNullOrWhiteSpace(config.BridgePath)
                    ? "BARControllerBridge.exe"
                    : config.BridgePath);
            string barTarget = Environment.ExpandEnvironmentVariables(config.OriginalTargetPath);

            if (string.IsNullOrWhiteSpace(barTarget) || !File.Exists(barTarget))
            {
                return Fail(
                    logPath,
                    "The original BAR launch target is missing: " + barTarget);
            }

            string launcherPath = GetCurrentExecutablePath();
            if (Path.GetFullPath(barTarget).Equals(
                Path.GetFullPath(launcherPath),
                StringComparison.OrdinalIgnoreCase))
            {
                return Fail(logPath, "Launcher configuration points back to BARControllerLauncher.exe.");
            }

            if (!IsBridgeRunning())
            {
                if (!File.Exists(bridgePath))
                {
                    return Fail(logPath, "Controller bridge is missing: " + bridgePath);
                }

                var bridgeStart = new ProcessStartInfo
                {
                    FileName = bridgePath,
                    Arguments = string.IsNullOrWhiteSpace(config.SettingsPath)
                        ? string.Empty
                        : "--settings-file " + QuoteArgument(config.SettingsPath),
                    WorkingDirectory = Path.GetDirectoryName(bridgePath) ?? baseDirectory,
                    UseShellExecute = true,
                    WindowStyle = ProcessWindowStyle.Minimized,
                };
                Process.Start(bridgeStart);
                Log(logPath, "Started controller bridge minimized: " + bridgePath);
                Thread.Sleep(Math.Max(0, Math.Min(config.BridgeStartupDelayMilliseconds, 5000)));
            }
            else
            {
                Log(logPath, "Controller bridge is already running.");
            }

            var barStart = new ProcessStartInfo
            {
                FileName = barTarget,
                Arguments = config.OriginalArguments ?? string.Empty,
                WorkingDirectory = ResolveWorkingDirectory(config, barTarget),
                UseShellExecute = true,
            };
            Process.Start(barStart);
            Log(logPath, "Launched BAR: " + barTarget);
            return 0;
        }
        catch (Exception exception)
        {
            return Fail(logPath, "Failed to launch BAR: " + exception.Message);
        }
    }

    private static LauncherConfig LoadConfig(string configPath)
    {
        if (!File.Exists(configPath))
        {
            throw new FileNotFoundException("Launcher config is missing.", configPath);
        }

        string json = File.ReadAllText(configPath);
        LauncherConfig? config = JsonSerializer.Deserialize<LauncherConfig>(
            json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        if (config == null)
        {
            throw new InvalidDataException("Launcher config is invalid.");
        }
        return config;
    }

    private static string ResolvePath(string baseDirectory, string path)
    {
        string expanded = Environment.ExpandEnvironmentVariables(path);
        return Path.IsPathRooted(expanded)
            ? Path.GetFullPath(expanded)
            : Path.GetFullPath(Path.Combine(baseDirectory, expanded));
    }

    private static string ResolveWorkingDirectory(LauncherConfig config, string barTarget)
    {
        string workingDirectory =
            Environment.ExpandEnvironmentVariables(config.OriginalWorkingDirectory ?? string.Empty);
        if (!string.IsNullOrWhiteSpace(workingDirectory) && Directory.Exists(workingDirectory))
        {
            return workingDirectory;
        }
        return Path.GetDirectoryName(barTarget) ?? AppContext.BaseDirectory;
    }

    private static string QuoteArgument(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static string GetCurrentExecutablePath()
    {
        using Process current = Process.GetCurrentProcess();
        return current.MainModule?.FileName ?? string.Empty;
    }

    private static bool IsBridgeRunning()
    {
        Process[] processes = Process.GetProcessesByName("BARControllerBridge");
        try
        {
            return processes.Length > 0;
        }
        finally
        {
            foreach (Process process in processes)
            {
                process.Dispose();
            }
        }
    }

    private static int Fail(string logPath, string message)
    {
        Log(logPath, "ERROR: " + message);
        MessageBox(
            IntPtr.Zero,
            message + "\n\nSee " + logPath,
            "BAR Controller Launcher",
            0x00000010);
        return 1;
    }

    private static void Log(string logPath, string message)
    {
        try
        {
            File.AppendAllText(
                logPath,
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + message + Environment.NewLine);
        }
        catch
        {
            // Launching BAR should not fail only because the diagnostic log is unwritable.
        }
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "MessageBoxW")]
    private static extern int MessageBox(
        IntPtr windowHandle,
        string text,
        string caption,
        uint type);
}
