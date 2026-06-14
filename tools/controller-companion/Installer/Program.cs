using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net.Http;
using System.Text.Json;

internal sealed class InstallerOptions
{
    public bool CheckUpdates { get; set; }
    public bool NoPause { get; set; }
    public string PackageRoot { get; set; } = AppContext.BaseDirectory;
    public string BarDataPath { get; set; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Programs",
        "Beyond-All-Reason",
        "data");
    public string InstallRoot { get; set; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Programs",
        "BARControllerCompanion");
    public List<string> ShortcutPaths { get; } = new List<string>();
}

internal static class Program
{
    private const string OfficialRepository =
        "UnderarmCape/underarmcape-bar-controller-support-attempt-01";

    [STAThread]
    private static int Main(string[] args)
    {
        Console.Title = "BAR Controller Companion Installer v0.5.0";
        if (!TryParseArguments(args, out InstallerOptions options))
        {
            PrintUsage();
            return 2;
        }

        string? temporaryUpdateRoot = null;
        try
        {
            options.PackageRoot = ReleaseOperations.ExpandPath(options.PackageRoot);
            options.BarDataPath = ReleaseOperations.ExpandPath(options.BarDataPath);
            options.InstallRoot = ReleaseOperations.ExpandPath(options.InstallRoot);
            PackageManifest localManifest =
                ReleaseOperations.ReadAndValidateManifest(options.PackageRoot);
            string packageRoot = SelectPackageSource(
                options,
                localManifest,
                out temporaryUpdateRoot);
            PackageManifest manifest = ReleaseOperations.ReadAndValidateManifest(packageRoot);

            Directory.CreateDirectory(options.InstallRoot);
            string backupRoot = Path.Combine(
                options.InstallRoot,
                "backups",
                DateTime.Now.ToString("yyyyMMdd-HHmmssfff"));
            InstallState state = ReleaseOperations.ReadState(
                options.InstallRoot,
                manifest.Version);

            ReleaseOperations.InstallCompanionFiles(packageRoot, manifest, options.InstallRoot);
            ReleaseOperations.InstallLuaWidgets(
                packageRoot,
                manifest,
                options.BarDataPath,
                backupRoot,
                state);
            ReleaseOperations.EnableRequiredWidgets(options.BarDataPath, backupRoot, state);
            string settingsPath = Path.Combine(options.BarDataPath, "springsettings.cfg");
            bool cameraChanged = ReleaseOperations.EnsureCameraSetting(
                settingsPath,
                backupRoot,
                state);
            ReleaseOperations.InstallShortcuts(
                GetShortcutPaths(options),
                options.InstallRoot,
                settingsPath,
                backupRoot,
                state);
            ReleaseOperations.SaveState(options.InstallRoot, state);

            Console.WriteLine();
            Console.WriteLine("Installation complete.");
            Console.WriteLine("BAR was not launched.");
            Console.WriteLine("Use the normal Beyond-All-Reason shortcut.");
            if (cameraChanged)
            {
                Console.WriteLine("Restart BAR for the camera setting change to take effect.");
            }
            PauseIfNeeded(options.NoPause);
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine();
            Console.Error.WriteLine("Installation failed: " + exception.Message);
            PauseIfNeeded(options.NoPause);
            return 1;
        }
        finally
        {
            if (temporaryUpdateRoot != null && Directory.Exists(temporaryUpdateRoot))
            {
                try
                {
                    Directory.Delete(temporaryUpdateRoot, true);
                }
                catch
                {
                    // Temporary update cleanup must not change the installation result.
                }
            }
        }
    }

    private static string SelectPackageSource(
        InstallerOptions options,
        PackageManifest localManifest,
        out string? temporaryUpdateRoot)
    {
        temporaryUpdateRoot = null;
        ReleaseOperations.Status("Using bundled local package v" + localManifest.Version + ".");
        if (!options.CheckUpdates)
        {
            return options.PackageRoot;
        }

        try
        {
            ReleaseOperations.Status("Checking the official GitHub repository for a newer package...");
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
            client.DefaultRequestHeaders.UserAgent.ParseAdd(
                "BAR-Controller-Companion-Installer/0.5.0");
            string releaseJson = client.GetStringAsync(
                "https://api.github.com/repos/" + OfficialRepository + "/releases/latest")
                .GetAwaiter()
                .GetResult();
            using JsonDocument release = JsonDocument.Parse(releaseJson);
            JsonElement assets = release.RootElement.GetProperty("assets");
            JsonElement? asset = assets
                .EnumerateArray()
                .FirstOrDefault(item =>
                {
                    string name = item.GetProperty("name").GetString() ?? string.Empty;
                    return IsCurrentAssetName(name);
                });
            if (asset == null || asset.Value.ValueKind == JsonValueKind.Undefined)
            {
                asset = assets
                    .EnumerateArray()
                    .FirstOrDefault(item =>
                    {
                        string name = item.GetProperty("name").GetString() ?? string.Empty;
                        return RegexAssetName(name);
                    });
            }
            if (asset == null || asset.Value.ValueKind == JsonValueKind.Undefined)
            {
                ReleaseOperations.Status("No compatible release zip found; using bundled files.");
                return options.PackageRoot;
            }

            string assetName = asset.Value.GetProperty("name").GetString() ?? string.Empty;
            if (!TryGetAssetVersion(assetName, out Version? assetVersion)
                || !Version.TryParse(localManifest.Version, out Version? localVersion)
                || assetVersion <= localVersion)
            {
                ReleaseOperations.Status("Bundled package is current.");
                return options.PackageRoot;
            }

            Console.Write(
                "A newer BAR Controller Companion package is available. "
                + "Download and install it? [y/N] ");
            string answer = Console.ReadLine() ?? string.Empty;
            if (!answer.Equals("y", StringComparison.OrdinalIgnoreCase)
                && !answer.Equals("yes", StringComparison.OrdinalIgnoreCase))
            {
                ReleaseOperations.Status("Using bundled local package v" + localManifest.Version + ".");
                return options.PackageRoot;
            }

            temporaryUpdateRoot = Path.Combine(
                Path.GetTempPath(),
                "BARControllerCompanion-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(temporaryUpdateRoot);
            string zipPath = Path.Combine(temporaryUpdateRoot, assetName);
            string downloadUrl =
                asset.Value.GetProperty("browser_download_url").GetString()
                ?? throw new InvalidDataException("Release asset has no download URL.");
            byte[] zipBytes = client.GetByteArrayAsync(downloadUrl).GetAwaiter().GetResult();
            File.WriteAllBytes(zipPath, zipBytes);
            string extractRoot = Path.Combine(temporaryUpdateRoot, "extracted");
            ZipFile.ExtractToDirectory(zipPath, extractRoot);
            string? manifestPath = Directory.EnumerateFiles(
                extractRoot,
                "manifest.json",
                SearchOption.AllDirectories).FirstOrDefault();
            if (manifestPath == null)
            {
                throw new InvalidDataException("Downloaded package has no manifest.json.");
            }

            string onlineRoot = Path.GetDirectoryName(manifestPath)!;
            PackageManifest onlineManifest =
                ReleaseOperations.ReadAndValidateManifest(onlineRoot);
            if (!Version.TryParse(onlineManifest.Version, out Version? manifestVersion)
                || manifestVersion != assetVersion)
            {
                throw new InvalidDataException(
                    "Downloaded package version does not match its zip name.");
            }
            ReleaseOperations.Status("Validated downloaded package v" + onlineManifest.Version + ".");
            return onlineRoot;
        }
        catch (Exception exception)
        {
            ReleaseOperations.Status(
                "Online check failed; using bundled files: " + exception.Message);
            return options.PackageRoot;
        }
    }

    private static bool RegexAssetName(string name)
    {
        return TryGetAssetVersion(name, out _);
    }

    private static bool IsCurrentAssetName(string name)
    {
        return name.StartsWith(
            "BAR_Controller_Support_v",
            StringComparison.OrdinalIgnoreCase)
            && name.EndsWith(
                "_Widget_Companion.zip",
                StringComparison.OrdinalIgnoreCase)
            && TryGetAssetVersion(name, out _);
    }

    private static bool TryGetAssetVersion(string name, out Version? version)
    {
        const string currentPrefix = "BAR_Controller_Support_v";
        const string currentSuffix = "_Widget_Companion.zip";
        const string legacyPrefix = "BAR_Controller_Companion_v";
        const string legacySuffix = ".zip";

        string versionText;
        if (name.StartsWith(currentPrefix, StringComparison.OrdinalIgnoreCase)
            && name.EndsWith(currentSuffix, StringComparison.OrdinalIgnoreCase))
        {
            versionText = name.Substring(
                currentPrefix.Length,
                name.Length - currentPrefix.Length - currentSuffix.Length);
        }
        else if (name.StartsWith(legacyPrefix, StringComparison.OrdinalIgnoreCase)
            && name.EndsWith(legacySuffix, StringComparison.OrdinalIgnoreCase))
        {
            versionText = name.Substring(
                legacyPrefix.Length,
                name.Length - legacyPrefix.Length - legacySuffix.Length);
        }
        else
        {
            version = null;
            return false;
        }

        return Version.TryParse(versionText, out version);
    }

    private static IReadOnlyList<string> GetShortcutPaths(InstallerOptions options)
    {
        if (options.ShortcutPaths.Count > 0)
        {
            return options.ShortcutPaths;
        }
        return new[]
        {
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                "Beyond-All-Reason.lnk"),
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "Microsoft",
                "Windows",
                "Start Menu",
                "Programs",
                "Beyond-All-Reason.lnk"),
        };
    }

    private static bool TryParseArguments(string[] args, out InstallerOptions options)
    {
        options = new InstallerOptions();
        for (int index = 0; index < args.Length; index++)
        {
            string argument = args[index];
            if (argument == "--check-updates")
            {
                options.CheckUpdates = true;
            }
            else if (argument == "--no-pause")
            {
                options.NoPause = true;
            }
            else if (TryReadValue(args, ref index, "--package-root", out string? packageRoot))
            {
                options.PackageRoot = packageRoot!;
            }
            else if (TryReadValue(args, ref index, "--bar-data", out string? barData))
            {
                options.BarDataPath = barData!;
            }
            else if (TryReadValue(args, ref index, "--install-root", out string? installRoot))
            {
                options.InstallRoot = installRoot!;
            }
            else if (TryReadValue(args, ref index, "--shortcut", out string? shortcut))
            {
                options.ShortcutPaths.Add(shortcut!);
            }
            else
            {
                return false;
            }
        }
        return true;
    }

    private static bool TryReadValue(
        string[] args,
        ref int index,
        string expected,
        out string? value)
    {
        value = null;
        if (args[index] != expected)
        {
            return false;
        }
        if (index + 1 >= args.Length)
        {
            return false;
        }
        value = args[++index];
        return !string.IsNullOrWhiteSpace(value);
    }

    private static void PrintUsage()
    {
        Console.Error.WriteLine(
            "Usage: BAR_Controller_Companion_Installer_v0.5.0.exe "
            + "[--check-updates] [--no-pause] [--package-root path] "
            + "[--bar-data path] [--install-root path] [--shortcut path]");
    }

    private static void PauseIfNeeded(bool noPause)
    {
        if (!noPause)
        {
            Console.WriteLine();
            Console.Write("Press Enter to close.");
            Console.ReadLine();
        }
    }
}
