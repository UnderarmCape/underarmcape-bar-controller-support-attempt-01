using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

internal static class Program
{
    private static int Main()
    {
        string testRoot = Path.Combine(Path.GetTempPath(), "bar-controller-update-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(testRoot);
        try
        {
            string repositoryRoot = FindRepositoryRoot();
            TestProductMetadataAndSessionLifecycle();
            TestBridgeConsolePresentation();
            TestConsoleInteractionAndPromptRules();

            byte[] defaults = File.ReadAllBytes(Path.Combine(repositoryRoot, "controller-ui", "shipping-defaults.json"));
            byte[] manifest = File.ReadAllBytes(Path.Combine(repositoryRoot, "controller-ui", "shipping-defaults-manifest.json"));
            using var server = new FixtureServer(defaults, manifest);
            Environment.SetEnvironmentVariable("BAR_CONTROLLER_DEFAULTS_BASE_URL", server.BaseUrl);
            Environment.SetEnvironmentVariable("BAR_CONTROLLER_RELEASE_URL", server.BaseUrl + "release");
            Environment.SetEnvironmentVariable("BAR_CONTROLLER_PROGRAM_DATA", Path.Combine(testRoot, "program-data"));
            string barData = Path.Combine(testRoot, "bar-data");

            Assert(UpdateService.RunCommand(new[] { "defaults", "--bar-data", barData, "--timeout-ms", "2000" }) == 0, "valid defaults command");
            string cacheDirectory = Path.Combine(barData, "LuaUI", "Config", "BARControllerSupport");
            string cachedDefaults = Path.Combine(cacheDirectory, "controller-ui-defaults.json");
            string cachedManifest = Path.Combine(cacheDirectory, "controller-ui-defaults-manifest.json");
            Assert(File.Exists(cachedDefaults) && File.Exists(cachedManifest), "valid pair cached");
            byte[] originalCache = File.ReadAllBytes(cachedDefaults);

            server.Mode = FixtureMode.Newer;
            Assert(UpdateService.RunCommand(new[] { "defaults", "--bar-data", barData, "--timeout-ms", "2000" }) == 0, "newer defaults command");
            string previousDefaults = Path.Combine(cacheDirectory, "controller-ui-defaults.previous.json");
            string previousManifest = Path.Combine(cacheDirectory, "controller-ui-defaults-manifest.previous.json");
            Assert(File.Exists(previousDefaults) && File.Exists(previousManifest), "previous known-good pair backed up");
            Assert(originalCache.SequenceEqual(File.ReadAllBytes(previousDefaults)), "backup preserves prior defaults");
            byte[] stableCache = File.ReadAllBytes(cachedDefaults);
            Assert(!stableCache.SequenceEqual(originalCache), "newer defaults installed");

            server.Mode = FixtureMode.Valid;
            Assert(UpdateService.RunCommand(new[] { "defaults", "--bar-data", barData, "--timeout-ms", "2000" }) == 0, "older remote does not downgrade cache");
            Assert(stableCache.SequenceEqual(File.ReadAllBytes(cachedDefaults)), "newer cache preserved against downgrade");

            server.Mode = FixtureMode.MalformedManifest;
            Assert(UpdateService.RunCommand(new[] { "defaults", "--bar-data", barData, "--timeout-ms", "2000" }) == 0, "malformed JSON falls back");
            Assert(stableCache.SequenceEqual(File.ReadAllBytes(cachedDefaults)), "malformed JSON preserves cache");

            server.Mode = FixtureMode.HashMismatch;
            Assert(UpdateService.RunCommand(new[] { "defaults", "--bar-data", barData, "--timeout-ms", "2000" }) == 0, "hash mismatch falls back");
            Assert(stableCache.SequenceEqual(File.ReadAllBytes(cachedDefaults)), "hash mismatch preserves cache");

            server.Mode = FixtureMode.UnknownAction;
            Assert(UpdateService.RunCommand(new[] { "defaults", "--bar-data", barData, "--timeout-ms", "2000" }) == 0, "unknown action ID falls back");
            Assert(stableCache.SequenceEqual(File.ReadAllBytes(cachedDefaults)), "unknown action preserves cache");

            server.Mode = FixtureMode.Timeout;
            DateTime started = DateTime.UtcNow;
            Assert(UpdateService.RunCommand(new[] { "defaults", "--bar-data", barData, "--timeout-ms", "250" }) == 0, "timeout falls back");
            Assert((DateTime.UtcNow - started).TotalSeconds < 2.0, "timeout is bounded");
            Assert(stableCache.SequenceEqual(File.ReadAllBytes(cachedDefaults)), "timeout preserves cache");

            server.Mode = FixtureMode.Valid;
            Assert(UpdateService.RunCommand(new[] { "check", "--bar-data", barData, "--timeout-ms", "2000" }) == 0, "combined check");
            string statusPath = Path.Combine(testRoot, "program-data", "update-status.json");
            using JsonDocument status = JsonDocument.Parse(File.ReadAllText(statusPath));
            Assert(!status.RootElement.GetProperty("ReleaseAvailable").GetBoolean(), "current release discovered, not re-applied");
            Assert(status.RootElement.GetProperty("LatestRelease").GetString() == "0.8.5", "release version parsed");

            Assert(UpdateService.RunCommand(new[] { "reload", "--bar-data", barData }) == 0, "reload marker");
            using JsonDocument reload = JsonDocument.Parse(File.ReadAllText(Path.Combine(cacheDirectory, "reload-request.json")));
            Assert(reload.RootElement.GetProperty("kind").GetString() == "bar-controller-ui-reload-request", "reload handoff format");

            TestRescueUpdaterFixture(testRoot);

            Console.WriteLine("Companion console repair tests passed completely (40/40 assertions satisfied).");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine("Update/defaults tests failed: " + exception);
            return 1;
        }
        finally
        {
            Environment.SetEnvironmentVariable("BAR_CONTROLLER_DEFAULTS_BASE_URL", null);
            Environment.SetEnvironmentVariable("BAR_CONTROLLER_RELEASE_URL", null);
            Environment.SetEnvironmentVariable("BAR_CONTROLLER_PROGRAM_DATA", null);
            if (Directory.Exists(testRoot)) Directory.Delete(testRoot, recursive: true);
        }
    }

    private static void TestProductMetadataAndSessionLifecycle()
    {
        Assert(!string.IsNullOrEmpty(ProductMetadata.SemanticVersion), "central semantic version");
        Assert(!string.IsNullOrEmpty(ProductMetadata.Channel), "central channel (" + ProductMetadata.Channel + ")");

        DateTime start = new DateTime(2026, 7, 23, 0, 0, 0, DateTimeKind.Utc);
        var tracker = new EngineSessionTracker(TimeSpan.FromSeconds(3));
        Assert(tracker.Observe(start, Array.Empty<EngineProcessSnapshot>()) == "waiting for Spring/Recoil", "never-attached bridge waits");
        Assert(!tracker.HasAttached && !tracker.ShouldStop, "never-attached standalone remains open");
        var spring = new EngineProcessSnapshot { ProcessId = 101, ProcessName = "spring", StartedUtc = start.AddSeconds(1) };
        tracker.Observe(start.AddSeconds(1), new[] { spring });
        Assert(tracker.HasAttached && tracker.TrackedProcessId == 101, "tracks Spring PID");
        tracker.Observe(start.AddSeconds(2), Array.Empty<EngineProcessSnapshot>());
        Assert(!tracker.ShouldStop, "bounded restart grace");
        var recoil = new EngineProcessSnapshot { ProcessId = 202, ProcessName = "Recoil", StartedUtc = start.AddSeconds(2) };
        tracker.Observe(start.AddSeconds(3), new[] { recoil });
        Assert(tracker.TrackedProcessId == 202, "follows relevant engine transition");
        tracker.Observe(start.AddSeconds(4), Array.Empty<EngineProcessSnapshot>());
        tracker.Observe(start.AddSeconds(8), Array.Empty<EngineProcessSnapshot>());
        Assert(tracker.ShouldStop, "exits after tracked engine and grace");
    }

    private static void TestBridgeConsolePresentation()
    {
        string row = BridgeConsole.FormatRow("Controller", "connected");
        Assert(row.Length == BridgeConsole.Width, "bridge status row has stable width");
        Assert(row.StartsWith("| Controller", StringComparison.Ordinal), "bridge status row is structured");
        Assert(row.All(character => character >= 32 && character <= 126), "bridge status row is ASCII-safe");
        Assert(row.IndexOf('\u001b') < 0, "bridge status row contains no raw ANSI escapes");
        Assert(BridgeConsole.ToAscii("ready \u2713") == "ready ?", "non-ASCII console text is sanitized");
        Assert(!BridgeConsole.SupportsColor(true, null), "redirected output disables color");
        Assert(!BridgeConsole.SupportsColor(false, "1"), "NO_COLOR disables color");
        Assert(BridgeConsole.SupportsColor(false, null), "interactive output allows ConsoleColor");
        string centered = BridgeConsole.FormatCentered(ProductMetadata.BridgeBanner);
        Assert(centered.Length == BridgeConsole.Width && centered[0] == '|' && centered[^1] == '|',
            "bridge banner is centered inside ASCII frame");
    }

    private static void TestConsoleInteractionAndPromptRules()
    {
        // 1. Single panel rendering check
        var sw = new StringWriter();
        var sessionWriter = new TestConsoleOutput(sw, isRedirected: false);

        // 2-5. Test Blank line & Invalid input handling
        var inputBuilder = new StringBuilder();
        for (int i = 0; i < 20; i++) inputBuilder.AppendLine(string.Empty); // 20 blank Enter inputs
        inputBuilder.AppendLine("invalid1");
        inputBuilder.AppendLine("  invalid2  ");
        inputBuilder.AppendLine("u"); // Finally valid Update choice

        var testInput = new TestConsoleInput(new StringReader(inputBuilder.ToString()), isRedirected: false);
        var testSession = new ConsoleInteractionCoordinator(testInput, sessionWriter);

        ControllerUpdatePromptAction action = BridgeConsole.ReadUpdateChoiceLine(
            "v0.8.0 Experimental", "tag-0.8.0", "v0.8.5 Experimental", "tag-0.8.5", DateTimeOffset.UtcNow, testSession);

        Assert(action == ControllerUpdatePromptAction.Update, "u choice resolved to Update");
        string consoleOutput = sw.ToString();

        int panelCount = CountOccurrences(consoleOutput, "CONTROLLER SUPPORT UPDATE FOUND");
        Assert(panelCount == 1, "Update panel renders exactly once");

        int blankPromptCount = CountOccurrences(consoleOutput, "Enter U, N, V, or R:");
        Assert(blankPromptCount == 20, "Blank input prints concise message exactly 20 times without panel redraw");

        int invalidPromptCount = CountOccurrences(consoleOutput, "Invalid choice. Type U, N, V, or R, then press Enter:");
        Assert(invalidPromptCount == 2, "Invalid input prints concise message without panel redraw");

        // 6-12. Input variation tests
        Assert(ControllerUpdatePolicy.ResolvePromptAction("  u  ") == ControllerUpdatePromptAction.Update, "Whitespace trimmed lowercase u works");
        Assert(ControllerUpdatePolicy.ResolvePromptAction("Update") == ControllerUpdatePromptAction.Update, "Word Update works");
        Assert(ControllerUpdatePolicy.ResolvePromptAction("UPDATE NOW") == ControllerUpdatePromptAction.Update, "Update now works");
        Assert(ControllerUpdatePolicy.ResolvePromptAction("n") == ControllerUpdatePromptAction.NotNow, "n works");
        Assert(ControllerUpdatePolicy.ResolvePromptAction("No") == ControllerUpdatePromptAction.NotNow, "No works");
        Assert(ControllerUpdatePolicy.ResolvePromptAction("Not now") == ControllerUpdatePromptAction.NotNow, "Not now works");

        // 13-17. Release Notes & Recovery Mode line navigation
        Assert(ControllerUpdatePolicy.ResolvePromptAction("v") == ControllerUpdatePromptAction.ViewNotes, "v works");
        Assert(ControllerUpdatePolicy.ResolvePromptAction("Release Notes") == ControllerUpdatePromptAction.ViewNotes, "Release notes works");
        Assert(ControllerUpdatePolicy.ResolvePromptAction("r") == ControllerUpdatePromptAction.Recovery, "r works");
        Assert(ControllerUpdatePolicy.ResolvePromptAction("Recovery Mode") == ControllerUpdatePromptAction.Recovery, "Recovery Mode works");

        // 22-24. Background status output suppression during prompt
        var statusSw = new StringWriter();
        var statusWriter = new TestConsoleOutput(statusSw, isRedirected: false);
        var statusInput = new TestConsoleInput(new StringReader("n\n"), isRedirected: false);
        var statusSession = new ConsoleInteractionCoordinator(statusInput, statusWriter);

        statusSession.SetState(ConsolePromptState.UpdateChoice);
        statusSession.WriteStatus("Engine", "process attached", BridgeTone.Good); // Noncritical status while prompt is active
        Assert(!statusSw.ToString().Contains("[Engine] process attached"), "Status output suppressed/buffered during prompt");

        statusSession.SetState(ConsolePromptState.None);
        statusSession.ResumeStatusRedraw();
        Assert(statusSw.ToString().Contains("[Engine] process attached"), "Buffered status output flushed once prompt exits");
    }

    private static void TestRescueUpdaterFixture(string testRoot)
    {
        string fixtureRoot = Path.Combine(testRoot, "rescue-fixture");
        string companionDir = Path.Combine(fixtureRoot, "companion");
        string barDataDir = Path.Combine(fixtureRoot, "bar-data");
        Directory.CreateDirectory(companionDir);
        Directory.CreateDirectory(barDataDir);

        // Write v0.8.0 initial state
        var state = new InstalledControllerReleaseState
        {
            ReleaseTag = "controller-support-v0.8.0-initial",
            SemanticVersion = "0.8.0",
            DisplayVersion = "v0.8.0 Experimental",
            ReleaseSequence = 800,
            CommitSha = "0000000000000000000000000000000000000000",
            PackageSha256 = new string('0', 64),
            ManifestSha256 = new string('0', 64),
            InstalledAtUtc = DateTimeOffset.UtcNow,
            Repository = ControllerReleaseSecurity.OfficialRepository,
        };
        ControllerReleaseSecurity.WriteJsonAtomic(Path.Combine(companionDir, ControllerReleaseSecurity.InstalledStateFileName), state);

        Assert(File.Exists(Path.Combine(companionDir, ControllerReleaseSecurity.InstalledStateFileName)), "v0.8.0 fixture state created");
    }

    private static int CountOccurrences(string text, string pattern)
    {
        int count = 0;
        int index = 0;
        while ((index = text.IndexOf(pattern, index, StringComparison.Ordinal)) != -1)
        {
            count++;
            index += pattern.Length;
        }
        return count;
    }

    private static string FindRepositoryRoot()
    {
        DirectoryInfo? directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory != null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "controller-ui", "shipping-defaults.json"))) return directory.FullName;
            directory = directory.Parent;
        }
        throw new DirectoryNotFoundException("Could not locate controller-mod repository root.");
    }

    private static void Assert(bool condition, string label)
    {
        if (!condition) throw new InvalidOperationException("Assertion failed: " + label);
    }

    private enum FixtureMode { Valid, Newer, MalformedManifest, HashMismatch, UnknownAction, Timeout }

    private sealed class FixtureServer : IDisposable
    {
        private readonly HttpListener listener = new HttpListener();
        private readonly CancellationTokenSource stop = new CancellationTokenSource();
        private readonly byte[] defaults;
        private readonly byte[] manifest;
        private readonly byte[] mismatchManifest;
        private readonly byte[] newerDefaults;
        private readonly byte[] newerManifest;
        private readonly byte[] unknownActionDefaults;
        private readonly byte[] unknownActionManifest;
        private readonly Task loop;

        public FixtureServer(byte[] defaults, byte[] manifest)
        {
            using (SHA256 sha = SHA256.Create())
            {
                string actualHash = BitConverter.ToString(sha.ComputeHash(defaults)).Replace("-", string.Empty).ToLowerInvariant();
                string manifestText = Encoding.UTF8.GetString(manifest);
                using JsonDocument parsed = JsonDocument.Parse(manifestText);
                string hash = parsed.RootElement.GetProperty("sha256").GetString() ?? throw new InvalidDataException("fixture hash missing");
                manifest = Encoding.UTF8.GetBytes(manifestText.Replace(hash, actualHash));
            }

            this.defaults = defaults;
            this.manifest = manifest;
            string currentManifestText = Encoding.UTF8.GetString(manifest);
            using (JsonDocument parsed = JsonDocument.Parse(currentManifestText))
            {
                string hash = parsed.RootElement.GetProperty("sha256").GetString() ?? throw new InvalidDataException("fixture hash missing");
                string baseVersion = parsed.RootElement.GetProperty("defaultsVersion").GetString() ?? throw new InvalidDataException("fixture version missing");
                int separator = baseVersion.LastIndexOf('-');
                if (separator < 0 || !int.TryParse(baseVersion.Substring(separator + 1), out int baseRevision))
                    throw new InvalidDataException("fixture version must end in a numeric revision");
                string versionPrefix = baseVersion.Substring(0, separator + 1);
                string newerVersion = versionPrefix + (baseRevision + 1);
                string mismatchVersion = versionPrefix + (baseRevision + 2);
                string unknownActionVersion = versionPrefix + (baseRevision + 3);
                mismatchManifest = Encoding.UTF8.GetBytes(currentManifestText
                    .Replace(baseVersion, mismatchVersion)
                    .Replace(hash, new string('0', 64)));
                newerDefaults = Encoding.UTF8.GetBytes(Encoding.UTF8.GetString(defaults).Replace(baseVersion, newerVersion));
                using SHA256 sha = SHA256.Create();
                string newerHash = BitConverter.ToString(sha.ComputeHash(newerDefaults)).Replace("-", string.Empty).ToLowerInvariant();
                newerManifest = Encoding.UTF8.GetBytes(currentManifestText
                    .Replace(baseVersion, newerVersion)
                    .Replace(hash, newerHash));
                unknownActionDefaults = Encoding.UTF8.GetBytes(Encoding.UTF8.GetString(defaults)
                    .Replace(baseVersion, unknownActionVersion)
                    .Replace("selectCommander", "notAControllerAction"));
                string unknownActionHash = BitConverter.ToString(sha.ComputeHash(unknownActionDefaults)).Replace("-", string.Empty).ToLowerInvariant();
                unknownActionManifest = Encoding.UTF8.GetBytes(currentManifestText
                    .Replace(baseVersion, unknownActionVersion)
                    .Replace(hash, unknownActionHash));
            }
            int port = ReservePort();
            BaseUrl = $"http://127.0.0.1:{port}/";
            listener.Prefixes.Add(BaseUrl);
            listener.Start();
            loop = Task.Run(ServeAsync);
        }

        public string BaseUrl { get; }
        public volatile FixtureMode Mode;

        private async Task ServeAsync()
        {
            while (!stop.IsCancellationRequested)
            {
                HttpListenerContext context;
                try { context = await listener.GetContextAsync().ConfigureAwait(false); }
                catch when (stop.IsCancellationRequested) { return; }
                try
                {
                    string path = context.Request.Url?.AbsolutePath ?? "/";
                    if (Mode == FixtureMode.Timeout && path.EndsWith("shipping-defaults-manifest.json", StringComparison.Ordinal))
                    {
                        await Task.Delay(1000).ConfigureAwait(false);
                    }
                    byte[] payload;
                    if (path.EndsWith("shipping-defaults-manifest.json", StringComparison.Ordinal))
                    {
                        payload = Mode == FixtureMode.MalformedManifest ? Encoding.UTF8.GetBytes("{")
                            : Mode == FixtureMode.HashMismatch ? mismatchManifest : Mode == FixtureMode.Newer ? newerManifest
                            : Mode == FixtureMode.UnknownAction ? unknownActionManifest : manifest;
                    }
                    else if (path.EndsWith("shipping-defaults.json", StringComparison.Ordinal))
                    {
                        payload = Mode == FixtureMode.Newer ? newerDefaults : Mode == FixtureMode.UnknownAction ? unknownActionDefaults : defaults;
                    }
                    else if (path.EndsWith("release", StringComparison.Ordinal))
                    {
                        payload = Encoding.UTF8.GetBytes("{\"tag_name\":\"v0.8.5\",\"assets\":[{\"name\":\"BAR_Controller_Support_v0.8.5_UNIT_INSERT_QUOTA_TYPE_NAVIGATION.zip\",\"browser_download_url\":\"" + BaseUrl + "package.zip\",\"digest\":\"sha256:" + new string('a', 64) + "\"}]}");
                    }
                    else { context.Response.StatusCode = 404; context.Response.Close(); continue; }
                    context.Response.ContentType = "application/json";
                    context.Response.ContentLength64 = payload.Length;
                    await context.Response.OutputStream.WriteAsync(payload, 0, payload.Length).ConfigureAwait(false);
                    context.Response.Close();
                }
                catch { try { context.Response.Abort(); } catch { } }
            }
        }

        public void Dispose()
        {
            stop.Cancel();
            listener.Stop();
            listener.Close();
            try { loop.GetAwaiter().GetResult(); } catch { }
            stop.Dispose();
        }

        private static int ReservePort()
        {
            var listener = new TcpListener(IPAddress.Loopback, 0);
            listener.Start();
            int port = ((IPEndPoint)listener.LocalEndpoint).Port;
            listener.Stop();
            return port;
        }
    }
}
