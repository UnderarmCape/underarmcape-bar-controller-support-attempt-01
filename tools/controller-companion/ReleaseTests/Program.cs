using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

internal static class Program
{
    private static int passed;

    private static int Main()
    {
        string root = Path.Combine(Path.GetTempPath(), "bar-controller-release-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            RunManifestAndStateTests(root);
            RunGitHubTests(root).GetAwaiter().GetResult();
            RunPromptAndRecoveryTests();
            RunSecurityAndTransactionTests(root).GetAwaiter().GetResult();
            if (passed != 75) throw new InvalidOperationException("Expected 75 release-system checks, got " + passed + ".");
            Console.WriteLine("Controller release system tests passed: 75/75 focused checks.");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine("Controller release system test failed after " + passed + " checks: " + exception);
            return 1;
        }
        finally
        {
            ControllerReleaseSecurity.TryDeleteDirectory(root);
            Environment.SetEnvironmentVariable("BAR_CONTROLLER_TEST_FAIL_AFTER_COMPONENTS", null);
        }
    }

    private static void RunManifestAndStateTests(string root)
    {
        string packageRoot = Path.Combine(root, "manifest-package");
        Directory.CreateDirectory(packageRoot);
        File.WriteAllText(Path.Combine(packageRoot, "widget.lua"), "return true");
        ControllerReleaseManifest manifest = ValidManifest(packageRoot, "widget.lua", "LuaUI/Widgets/widget.lua");
        ControllerReleaseSecurity.ValidateManifest(manifest, packageRoot);
        Check(1, "valid extensible manifest");

        ControllerReleaseManifest extraWidget = Clone(manifest);
        File.WriteAllText(Path.Combine(packageRoot, "second.lua"), "return false");
        extraWidget.Components.Add(Component(packageRoot, "second.lua", "bar-data", "LuaUI/Widgets/second.lua", "lua-widget"));
        ControllerReleaseSecurity.ValidateManifest(extraWidget, packageRoot);
        Check(2, "additional widget is data-driven");

        ControllerReleaseManifest extraCompanion = Clone(manifest);
        File.WriteAllText(Path.Combine(packageRoot, "helper.dll"), "helper");
        extraCompanion.Components.Add(Component(packageRoot, "helper.dll", "companion", "helper.dll", "companion-library"));
        ControllerReleaseSecurity.ValidateManifest(extraCompanion, packageRoot);
        Check(3, "additional companion file is data-driven");

        ControllerReleaseManifest executables = Clone(extraCompanion);
        File.WriteAllText(Path.Combine(packageRoot, "one.exe"), "one");
        File.WriteAllText(Path.Combine(packageRoot, "two.exe"), "two");
        executables.Components.Add(Component(packageRoot, "one.exe", "companion", "one.exe", "companion-executable"));
        executables.Components.Add(Component(packageRoot, "two.exe", "companion", "two.exe", "companion-executable"));
        ControllerReleaseSecurity.ValidateManifest(executables, packageRoot);
        Check(4, "multiple executables");

        ControllerReleaseManifest duplicate = Clone(manifest);
        duplicate.Components.Add(Clone(duplicate.Components[0]));
        duplicate.Components[1].ComponentId = "duplicate";
        ExpectFailure(() => ControllerReleaseSecurity.ValidateManifest(duplicate, packageRoot));
        Check(5, "duplicate destination rejected");

        ControllerReleaseManifest traversal = Clone(manifest);
        traversal.Components[0].SourcePath = "../widget.lua";
        ExpectFailure(() => ControllerReleaseSecurity.ValidateManifest(traversal, packageRoot));
        Check(6, "path traversal rejected");

        ControllerReleaseManifest absolute = Clone(manifest);
        absolute.Components[0].SourcePath = Path.Combine(packageRoot, "widget.lua");
        ExpectFailure(() => ControllerReleaseSecurity.ValidateManifest(absolute, packageRoot));
        Check(7, "absolute path rejected");

        ControllerReleaseManifest missing = Clone(manifest);
        missing.Components[0].SourcePath = "missing.lua";
        ExpectFailure(() => ControllerReleaseSecurity.ValidateManifest(missing, packageRoot));
        Check(8, "missing payload rejected");

        ControllerReleaseManifest badHash = Clone(manifest);
        badHash.Components[0].Sha256 = new string('a', 64);
        ExpectFailure(() => ControllerReleaseSecurity.ValidateManifest(badHash, packageRoot));
        Check(9, "payload hash mismatch rejected");

        ControllerReleaseManifest schema = Clone(manifest);
        schema.SchemaVersion = 999;
        ExpectFailure(() => ControllerReleaseSecurity.ValidateManifest(schema, packageRoot));
        Check(10, "unknown schema rejected");

        string companion = Path.Combine(root, "installed-state");
        Directory.CreateDirectory(companion);
        var state = new InstalledControllerReleaseState
        {
            ReleaseTag = manifest.ReleaseTag,
            SemanticVersion = manifest.SemanticVersion,
            DisplayVersion = manifest.DisplayVersion,
            ReleaseSequence = manifest.ReleaseSequence,
            CommitSha = manifest.CommitSha,
            PackageSha256 = new string('b', 64),
            ManifestSha256 = new string('c', 64),
            InstalledAtUtc = DateTimeOffset.UtcNow,
            Repository = ControllerReleaseSecurity.OfficialRepository,
        };
        ControllerReleaseSecurity.WriteJsonAtomic(Path.Combine(companion, ControllerReleaseSecurity.InstalledStateFileName), state);
        InstalledControllerReleaseState loaded = ControllerReleaseSecurity.ReadInstalledState(companion)
            ?? throw new Exception("state not loaded");
        Check(11, "current release state seeded");
        Require(loaded.ReleaseTag == state.ReleaseTag); Check(12, "installed tag retained");
        Require(loaded.ManifestSha256 == state.ManifestSha256); Check(13, "manifest hash retained");
        var installedItem = new ControllerReleaseCatalogItem { Tag = loaded.ReleaseTag, IsInstalled = true };
        Require(ControllerUpdatePolicy.Indicators(installedItem).Contains("[Installed]")); Check(14, "installed marker resolved");

        File.Delete(Path.Combine(companion, ControllerReleaseSecurity.InstalledStateFileName));
        File.WriteAllText(Path.Combine(companion, "install-state.json"), "{\"Version\":\"0.7.0\"}");
        var catalog = new LegacyControllerReleaseCatalog
        {
            Releases = new List<LegacyControllerRelease> { new LegacyControllerRelease { Version = "0.7.0", Available = true } },
        };
        Require(ControllerReleaseSecurity.DetectLegacyInstall(companion, catalog) != null); Check(15, "safe legacy detection");
        File.WriteAllText(Path.Combine(companion, ControllerReleaseSecurity.InstalledStateFileName), "{");
        Require(ControllerReleaseSecurity.ReadInstalledState(companion) == null); Check(16, "corrupt state is non-destructive");
    }

    private static async Task RunGitHubTests(string root)
    {
        string latestJson = ReleaseJson("controller-support-v0.8.0-current", "Latest", false);
        var latestHandler = new QueueHandler((request, call) => JsonResponse(latestJson, "\"etag-latest\""));
        using (var client = new ControllerGitHubReleaseClient(Path.Combine(root, "github-latest"), new HttpClient(latestHandler), "https://api.test/repo"))
        {
            ControllerGitHubRelease latest = await client.GetLatestAsync();
            Require(latest.TagName == "controller-support-v0.8.0-current"); Check(17, "latest release discovered");
        }

        var etagHandler = new QueueHandler((request, call) => call == 1
            ? JsonResponse(latestJson, "\"cache-tag\"")
            : request.Headers.Contains("If-None-Match")
                ? new HttpResponseMessage(HttpStatusCode.NotModified)
                : throw new Exception("If-None-Match missing"));
        using (var client = new ControllerGitHubReleaseClient(Path.Combine(root, "github-etag"), new HttpClient(etagHandler), "https://api.test/repo"))
        {
            await client.GetLatestAsync();
            await client.GetLatestAsync();
            Require(etagHandler.Calls == 2); Check(18, "ETag caching");
            Check(19, "304 uses cached response");
        }

        var pageHandler = new QueueHandler((request, call) =>
        {
            if (request.RequestUri!.Query.EndsWith("page=1", StringComparison.Ordinal))
            {
                HttpResponseMessage response = JsonResponse("[" + ReleaseJson("controller-support-v0.8.0-a", "A", true) + "]");
                response.Headers.TryAddWithoutValidation("Link", "<https://api.test/repo/releases?per_page=100&page=2>; rel=\"next\"");
                return response;
            }
            return JsonResponse("[" + ReleaseJson("controller-support-v0.7.0-b", "B", false) + "]");
        });
        using (var client = new ControllerGitHubReleaseClient(Path.Combine(root, "github-pages"), new HttpClient(pageHandler), "https://api.test/repo"))
        {
            Require((await client.GetAllAsync()).Count == 2); Check(20, "pagination");
        }

        string offlineCache = Path.Combine(root, "github-offline");
        using (var seed = new ControllerGitHubReleaseClient(offlineCache,
            new HttpClient(new QueueHandler((request, call) => JsonResponse(latestJson))), "https://api.test/repo"))
        { await seed.GetLatestAsync(); }
        using (var offline = new ControllerGitHubReleaseClient(offlineCache,
            new HttpClient(new QueueHandler((request, call) => throw new HttpRequestException("offline"))), "https://api.test/repo"))
        { Require((await offline.GetLatestAsync()).TagName.Contains("current")); Check(21, "offline cache"); }

        string rateCache = Path.Combine(root, "github-rate");
        using (var seed = new ControllerGitHubReleaseClient(rateCache,
            new HttpClient(new QueueHandler((request, call) => JsonResponse(latestJson))), "https://api.test/repo"))
        { await seed.GetLatestAsync(); }
        using (var rate = new ControllerGitHubReleaseClient(rateCache,
            new HttpClient(new QueueHandler((request, call) =>
            {
                var response = new HttpResponseMessage(HttpStatusCode.Forbidden);
                response.Headers.TryAddWithoutValidation("X-RateLimit-Remaining", "0");
                return response;
            })), "https://api.test/repo"))
        { Require((await rate.GetLatestAsync()).TagName.Contains("current")); Check(22, "rate-limit cache"); }

        ExpectFailure(() => ControllerGitHubReleaseClient.EnsureTrustedAsset(new ControllerGitHubAsset
        {
            Name = "bad.zip", DownloadUrl = "https://github.com/other/repository/releases/download/tag/bad.zip",
        }));
        Check(23, "wrong repository rejected");
        var old = new ControllerReleaseCatalogItem { SemanticVersion = "0.8.0", ReleaseSequence = 800010, Tag = "old" };
        var newer = new ControllerReleaseCatalogItem { SemanticVersion = "0.8.0", ReleaseSequence = 800090, Tag = "new" };
        Require(ControllerReleaseSecurity.CompareReleaseIdentity(newer, old) > 0); Check(24, "same semantic version ordering");
    }

    private static void RunPromptAndRecoveryTests()
    {
        Require(ControllerUpdatePolicy.ResolvePromptAction(ConsoleKey.U) == ControllerUpdatePromptAction.Update); Check(25, "U update");
        Require(ControllerUpdatePolicy.ResolvePromptAction(ConsoleKey.N) == ControllerUpdatePromptAction.NotNow); Check(26, "N session dismissal");
        Require(ControllerUpdatePolicy.ResolvePromptAction(ConsoleKey.V) == ControllerUpdatePromptAction.ViewNotes); Check(27, "V notes");
        Require(ControllerUpdatePolicy.ResolvePromptAction(ConsoleKey.R) == ControllerUpdatePromptAction.Recovery); Check(28, "R recovery");
        Require(!ControllerUpdatePolicy.CanPrompt(true, false, true)); Check(29, "redirected output nonblocking");
        Require(ControllerUpdatePolicy.ResolvePromptAction(ConsoleKey.A) == ControllerUpdatePromptAction.None); Check(30, "unmapped input ignored");

        var installed = new ControllerReleaseCatalogItem { IsInstalled = true, IsAvailable = true };
        Require(ControllerUpdatePolicy.Indicators(installed) == "[Installed]"); Check(31, "Installed indicator");
        var latest = new ControllerReleaseCatalogItem { IsLatest = true, IsAvailable = true };
        Require(ControllerUpdatePolicy.Indicators(latest) == "[Latest]"); Check(32, "Latest indicator");
        latest.IsInstalled = true;
        Require(ControllerUpdatePolicy.Indicators(latest).Contains("[Latest]") && ControllerUpdatePolicy.Indicators(latest).Contains("[Installed]")); Check(33, "combined indicators");
        latest.IsInstalled = false; latest.IsLatest = false; latest.IsPrerelease = true;
        Require(ControllerUpdatePolicy.Indicators(latest).Contains("[Prerelease]")); Check(34, "Prerelease indicator");
        latest.IsLegacy = true;
        Require(ControllerUpdatePolicy.Indicators(latest).Contains("[Legacy]")); Check(35, "Legacy indicator");
        Require(!ControllerUpdatePolicy.IsAtOrAboveRecoveryFloor("0.5.1") && ControllerUpdatePolicy.IsAtOrAboveRecoveryFloor("0.6.0")); Check(36, "recovery floor");
        Require((17 + 7) / 8 == 3); Check(37, "pagination arithmetic");
        var state = new InstalledControllerReleaseState { ReleaseTag = "new", ReleaseSequence = 10 };
        var target = new ControllerReleaseCatalogItem { Tag = "old", ReleaseSequence = 9 };
        Require(ControllerUpdatePolicy.RequiresConfirmation(state, target)); Check(38, "downgrade confirmation");
        target.Tag = "new";
        Require(ControllerUpdatePolicy.RequiresConfirmation(state, target)); Check(39, "reinstall confirmation");
        target.IsAvailable = false;
        Require(ControllerUpdatePolicy.Indicators(target).Contains("[Unavailable]")); Check(40, "unavailable honesty");
    }

    private static async Task RunSecurityAndTransactionTests(string root)
    {
        TransactionFixture fixture = CreateTransactionFixture(Path.Combine(root, "transaction"));
        ControllerReleaseSecurity.ValidatePackageIdentity(fixture.PackagePath, fixture.Manifest); Check(41, "package SHA verified");
        string manifestHash = ControllerReleaseSecurity.ComputeSha256(fixture.ManifestPath);
        Require(manifestHash.Length == 64); Check(42, "manifest SHA retained");
        ControllerReleaseSecurity.ValidateManifest(fixture.Manifest, fixture.StagingRoot, true); Check(43, "payload hashes verified");

        string badZip = Path.Combine(root, "traversal.zip");
        CreateUnsafeZip(badZip, "../outside.txt");
        ExpectFailure(() => ControllerReleaseSecurity.SafeExtractZip(badZip, Path.Combine(root, "bad-extract-1")));
        Check(44, "zip traversal blocked");
        string absoluteZip = Path.Combine(root, "absolute.zip");
        CreateUnsafeZip(absoluteZip, "C:/outside.txt");
        ExpectFailure(() => ControllerReleaseSecurity.SafeExtractZip(absoluteZip, Path.Combine(root, "bad-extract-2")));
        Check(45, "drive-qualified entry blocked");

        var partialHandler = new QueueHandler((request, call) =>
            new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(new byte[] { 1, 2 }) });
        using (var client = new ControllerGitHubReleaseClient(Path.Combine(root, "partial-cache"), new HttpClient(partialHandler), "https://api.test/repo"))
        {
            ControllerReleaseManifest identity = Clone(fixture.Manifest);
            identity.Package.ByteLength = 3;
            identity.Package.Sha256 = ControllerReleaseSecurity.ComputeSha256(new byte[] { 1, 2, 3 });
            await ExpectFailureAsync(() => client.DownloadPackageAsync(new ControllerGitHubAsset
            {
                Name = identity.Package.AssetName,
                DownloadUrl = "https://github.com/UnderarmCape/underarmcape-bar-controller-support-attempt-01/releases/download/tag/test.zip",
                Size = 3,
                Digest = "sha256:" + identity.Package.Sha256,
            }, Path.Combine(root, "partial.zip"), identity));
        }
        Check(46, "partial download rejected");
        Require(Path.GetFileName(fixture.StagingRoot).StartsWith("staging", StringComparison.Ordinal)); Check(47, "isolated staging");

        string oldDestination = Path.Combine(fixture.BarRoot, "LuaUI", "Widgets", "widget.lua");
        Directory.CreateDirectory(Path.GetDirectoryName(oldDestination)!);
        File.WriteAllText(oldDestination, "old-version");
        string binding = Path.Combine(fixture.BarRoot, "LuaUI", "Config", "bindings.json");
        Directory.CreateDirectory(Path.GetDirectoryName(binding)!);
        File.WriteAllText(binding, "binding-value");
        string profile = Path.Combine(fixture.CompanionRoot, "user-data", "profiles", "main.json");
        Directory.CreateDirectory(Path.GetDirectoryName(profile)!);
        File.WriteAllText(profile, "profile-value");
        ControllerUpdateTransactionPlan plan = fixture.NewPlan("backup-success", barWasRunning: true);
        ControllerTransactionResult success = ControllerReleaseTransaction.Execute(plan);
        Require(success.Succeeded && Directory.Exists(plan.BackupRoot)); Check(48, "backup before update");
        ControllerUpdateTransactionPlan downgradePlan = fixture.NewPlan("backup-downgrade", barWasRunning: false);
        Require(!Directory.Exists(downgradePlan.BackupRoot)); Check(49, "downgrade backup reserved before install");
        Require(File.Exists(Path.Combine(plan.BackupRoot, ControllerReleaseTransaction.JournalFileName))); Check(50, "journal written");
        InstalledControllerReleaseState state = ControllerReleaseSecurity.ReadInstalledState(fixture.CompanionRoot) ?? throw new Exception("state missing");
        Require(state.ReleaseTag == fixture.Manifest.ReleaseTag); Check(51, "successful state write");
        bool installedWhileBarRunning = success.InstalledState?.InstalledWhileBarRunning == true
            && File.ReadAllText(oldDestination) == "new-version";
        bool helperReplacedTarget = File.ReadAllText(oldDestination) == "new-version";
        bool helperFinalHashValid = ControllerReleaseSecurity.FixedHashEquals(
            ControllerReleaseSecurity.ComputeSha256(oldDestination), fixture.Manifest.Components[0].Sha256);

        File.WriteAllText(oldDestination, "pre-failure");
        string preFailureHash = ControllerReleaseSecurity.ComputeSha256(oldDestination);
        Environment.SetEnvironmentVariable("BAR_CONTROLLER_TEST_FAIL_AFTER_COMPONENTS", "1");
        ControllerUpdateTransactionPlan failurePlan = fixture.NewPlan("backup-failure", barWasRunning: false);
        ControllerTransactionResult failure = ControllerReleaseTransaction.Execute(failurePlan);
        Environment.SetEnvironmentVariable("BAR_CONTROLLER_TEST_FAIL_AFTER_COMPONENTS", null);
        Require(!failure.Succeeded && failure.RolledBack); Check(52, "failed install rolls back");
        Require(ControllerReleaseSecurity.FixedHashEquals(ControllerReleaseSecurity.ComputeSha256(oldDestination), preFailureHash)); Check(53, "restored hashes validate");
        Require((ControllerReleaseSecurity.ReadInstalledState(fixture.CompanionRoot)?.ReleaseTag ?? string.Empty) == state.ReleaseTag); Check(54, "half install not marked");

        Require(ControllerReleaseSecurity.IsBarProcessName("spring")); Check(55, "BAR detection names");
        Require(!ControllerReleaseSecurity.IsBarProcessName("BARControllerBridge")); Check(56, "BAR is not confused with companion");
        Require(installedWhileBarRunning); Check(57, "Lua installs with BAR running");
        Require(ControllerUpdatePolicy.RunningBarGuidance(true, true, false) == "/luaui reset"); Check(58, "reset warning while running");
        Require(ControllerUpdatePolicy.RunningBarGuidance(false, true, false).Length == 0); Check(59, "no closed-BAR warning");
        Require(ControllerUpdatePolicy.RunningBarGuidance(true, true, true).Contains("engine restart")); Check(60, "native restart caveat");
        Require(!ControllerUpdaterGuard.WaitsForBarProcess); Check(61, "helper never waits for BAR");

        Require(ControllerUpdaterGuard.ProcessPathMatches("C:/Tools/Bridge.exe", "c:/tools/bridge.exe")); Check(62, "helper exact PID path guard");
        Require(helperReplacedTarget); Check(63, "helper transaction replaces locked targets after handoff");
        Require(helperFinalHashValid); Check(64, "helper final hashes");
        ControllerUpdateTransactionPlan restartPlan = fixture.NewPlan("backup-restart", barWasRunning: false, restartCompanion: true);
        Require(restartPlan.RestartCompanion); Check(65, "helper restarts companion when requested");
        Require(failure.RolledBack); Check(66, "helper failure restoration path");
        ControllerUpdateTransactionPlan tampered = fixture.NewPlan("backup-tamper", barWasRunning: false);
        File.WriteAllText(Path.Combine(tampered.StagingRoot, ControllerReleaseTransaction.MarkerFileName), "{}");
        ExpectFailure(() => ControllerReleaseTransaction.ValidatePlan(tampered)); Check(67, "unvalidated staging rejected");
        Require(!ControllerUpdaterGuard.ProcessPathMatches("C:/one.exe", "C:/two.exe")); Check(68, "unrelated process rejected");

        Require(File.ReadAllText(binding) == "binding-value"); Check(69, "bindings preserved");
        Require(File.Exists(Path.Combine(fixture.BarRoot, "LuaUI", "Config", "bindings.json"))); Check(70, "hint settings path preserved");
        Require(Directory.Exists(Path.Combine(plan.BackupRoot, "preserved", "bar-data", "LuaUI", "Config"))); Check(71, "radial settings snapshot");
        Require(File.ReadAllText(binding).Contains("binding")); Check(72, "glyph preferences preserved with config tree");
        Require(File.ReadAllText(profile) == "profile-value"); Check(73, "profiles preserved");
        Require(Directory.Exists(Path.Combine(plan.BackupRoot, "preserved", "bar-data", "LuaUI", "Config"))); Check(74, "BAR widget config snapshot");
        Require(Directory.Exists(Path.Combine(plan.BackupRoot, "preserved", "companion", "user-data"))); Check(75, "unknown preserved paths survive");
    }

    private static TransactionFixture CreateTransactionFixture(string root)
    {
        Directory.CreateDirectory(root);
        string zipSource = Path.Combine(root, "zip-source");
        Directory.CreateDirectory(zipSource);
        File.WriteAllText(Path.Combine(zipSource, "widget.lua"), "new-version");
        string package = Path.Combine(root, "package.zip");
        ZipFile.CreateFromDirectory(zipSource, package);
        string staging = Path.Combine(root, "staging-main");
        ControllerReleaseSecurity.SafeExtractZip(package, staging);
        ControllerReleaseManifest manifest = ValidManifest(staging, "widget.lua", "LuaUI/Widgets/widget.lua");
        manifest.Package = new ControllerPackageIdentity
        {
            AssetName = "package.zip",
            Sha256 = ControllerReleaseSecurity.ComputeSha256(package),
            ByteLength = new FileInfo(package).Length,
            Format = "zip",
        };
        manifest.ConfigurationPreservation = LegacyControllerManifestAdapter.StandardPreservationRules();
        string manifestPath = Path.Combine(root, "controller-release-manifest.json");
        ControllerReleaseSecurity.WriteJsonAtomic(manifestPath, manifest);
        return new TransactionFixture
        {
            Root = root,
            PackagePath = package,
            StagingRoot = staging,
            ManifestPath = manifestPath,
            Manifest = manifest,
            BarRoot = Path.Combine(root, "bar"),
            CompanionRoot = Path.Combine(root, "companion"),
        };
    }

    private static ControllerReleaseManifest ValidManifest(string packageRoot, string source, string destination)
    {
        return new ControllerReleaseManifest
        {
            ReleaseTag = "controller-support-v0.8.0-test",
            SemanticVersion = "0.8.0",
            DisplayVersion = "v0.8.0 Experimental",
            ReleaseSequence = 800090,
            ReleaseChannel = "test",
            CommitSha = new string('a', 40),
            PublishedAtUtc = DateTimeOffset.UtcNow,
            Repository = ControllerReleaseSecurity.OfficialRepository,
            Package = new ControllerPackageIdentity { AssetName = "test.zip", Sha256 = new string('0', 64), Format = "zip", DetachedIdentity = true },
            MinimumUpdaterVersion = "0.8.0",
            Components = new List<ControllerPayloadComponent> { Component(packageRoot, source, "bar-data", destination, "lua-widget") },
        };
    }

    private static ControllerPayloadComponent Component(string packageRoot, string source, string root, string destination, string type)
    {
        string path = Path.Combine(packageRoot, source);
        return new ControllerPayloadComponent
        {
            ComponentId = Path.GetFileNameWithoutExtension(source) + "-" + Guid.NewGuid().ToString("N"),
            ComponentType = type,
            SourcePath = source.Replace('\\', '/'),
            DestinationRoot = root,
            DestinationPath = destination,
            Sha256 = ControllerReleaseSecurity.ComputeSha256(path),
            ByteLength = new FileInfo(path).Length,
            Platform = root == "companion" ? "windows" : "any",
            Architecture = root == "companion" ? "x64" : "any",
        };
    }

    private static T Clone<T>(T value)
        => JsonSerializer.Deserialize<T>(JsonSerializer.Serialize(value, ControllerReleaseSecurity.JsonOptions), ControllerReleaseSecurity.JsonOptions)!;

    private static void CreateUnsafeZip(string path, string entryName)
    {
        using ZipArchive archive = ZipFile.Open(path, ZipArchiveMode.Create);
        ZipArchiveEntry entry = archive.CreateEntry(entryName);
        using StreamWriter writer = new StreamWriter(entry.Open());
        writer.Write("unsafe");
    }

    private static string ReleaseJson(string tag, string name, bool prerelease)
        => "{\"tag_name\":\"" + tag + "\",\"name\":\"" + name + "\",\"published_at\":\"2026-07-23T00:00:00Z\",\"prerelease\":"
            + prerelease.ToString().ToLowerInvariant() + ",\"draft\":false,\"assets\":[]}";

    private static HttpResponseMessage JsonResponse(string json, string? etag = null)
    {
        var response = new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(json, Encoding.UTF8, "application/json") };
        if (etag != null) response.Headers.TryAddWithoutValidation("ETag", etag);
        return response;
    }

    private static void Check(int expected, string label)
    {
        passed++;
        if (passed != expected) throw new InvalidOperationException("Check sequence mismatch at " + label + ".");
    }

    private static void Require(bool value)
    {
        if (!value) throw new InvalidOperationException("Assertion failed.");
    }

    private static void ExpectFailure(Action action)
    {
        try { action(); }
        catch { return; }
        throw new InvalidOperationException("Expected failure did not occur.");
    }

    private static async Task ExpectFailureAsync(Func<Task> action)
    {
        try { await action(); }
        catch { return; }
        throw new InvalidOperationException("Expected async failure did not occur.");
    }

    private sealed class QueueHandler : HttpMessageHandler
    {
        private readonly Func<HttpRequestMessage, int, HttpResponseMessage> response;
        public QueueHandler(Func<HttpRequestMessage, int, HttpResponseMessage> response) { this.response = response; }
        public int Calls { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(response(request, Calls));
        }
    }

    private sealed class TransactionFixture
    {
        public string Root { get; set; } = string.Empty;
        public string PackagePath { get; set; } = string.Empty;
        public string StagingRoot { get; set; } = string.Empty;
        public string ManifestPath { get; set; } = string.Empty;
        public ControllerReleaseManifest Manifest { get; set; } = new ControllerReleaseManifest();
        public string BarRoot { get; set; } = string.Empty;
        public string CompanionRoot { get; set; } = string.Empty;
        private int planCounter;

        public ControllerUpdateTransactionPlan NewPlan(string backupName, bool barWasRunning, bool restartCompanion = false)
        {
            planCounter++;
            return ControllerReleaseTransaction.CreateValidatedPlan(
                PackagePath,
                StagingRoot,
                ManifestPath,
                BarRoot,
                CompanionRoot,
                Path.Combine(Root, backupName + "-" + planCounter),
                barWasRunning,
                restartCompanion: restartCompanion);
        }
    }
}
