using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

internal sealed class ControllerPreparedUpdate
{
    public ControllerReleaseCatalogItem Release { get; set; } = new ControllerReleaseCatalogItem();
    public ControllerUpdateTransactionPlan Plan { get; set; } = new ControllerUpdateTransactionPlan();
    public string PlanPath { get; set; } = string.Empty;
    public string HelperPath { get; set; } = string.Empty;
}

internal static class ControllerUpdateCoordinator
{
    public static readonly TimeSpan CheckInterval = TimeSpan.FromHours(6);
    private const int RecoveryPageSize = 8;
    private static readonly SemaphoreSlim PromptSemaphore = new SemaphoreSlim(1, 1);
    private static string? activePromptTag;
    private static string? lastPromptedTag;
    private static string? dismissedReleaseTag;
    private static bool updateTransactionActive;

    public static void ResetStateForTest()
    {
        activePromptTag = null;
        lastPromptedTag = null;
        dismissedReleaseTag = null;
        updateTransactionActive = false;
    }

    public static void StartPeriodicCheck(Action requestCompanionExit)
    {
        Task.Run(async () =>
        {
            while (true)
            {
                try
                {
                    await CheckAndPromptAsync(requestCompanionExit, interactive: true).ConfigureAwait(false);
                }
                catch (Exception exception)
                {
                    BridgeConsole.WriteStatus("Updates", "offline/cache mode: " + exception.Message, BridgeTone.Warning);
                }
                await Task.Delay(CheckInterval).ConfigureAwait(false);
            }
        });
    }

    public static async Task<bool> CheckAndPromptAsync(
        Action? requestCompanionExit,
        bool interactive,
        IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        if (updateTransactionActive) return false;
        if (!ControllerUpdatePolicy.CanPrompt(interactive, session.Input.IsRedirected, session.Output.IsRedirected))
        {
            return false;
        }

        string companionRoot = GetCompanionRoot();
        using var client = CreateClient(companionRoot);
        List<ControllerReleaseCatalogItem> catalog = await GetCatalogAsync(client, companionRoot).ConfigureAwait(false);
        ControllerReleaseCatalogItem? latest = catalog.FirstOrDefault(item => item.IsLatest);
        InstalledControllerReleaseState? installed = ControllerReleaseSecurity.ReadInstalledState(companionRoot);
        if (latest == null || !latest.IsAvailable || !IsNewer(latest, installed)) return false;

        if (string.Equals(latest.Tag, dismissedReleaseTag, StringComparison.Ordinal)
            || string.Equals(latest.Tag, activePromptTag, StringComparison.Ordinal))
        {
            return false;
        }

        if (!await PromptSemaphore.WaitAsync(0).ConfigureAwait(false))
        {
            return false;
        }

        try
        {
            activePromptTag = latest.Tag;
            lastPromptedTag = latest.Tag;
            session.SetState(ConsolePromptState.UpdateChoice);
            string installedVersion = installed?.DisplayVersion ?? "Unknown installation";
            string installedTag = installed?.ReleaseTag ?? "legacy state not adopted";

            while (true)
            {
                ControllerUpdatePromptAction action = BridgeConsole.ReadUpdateChoiceLine(
                    installedVersion, installedTag, latest.DisplayVersion, latest.Tag, latest.PublishedAtUtc, session);
                switch (action)
                {
                    case ControllerUpdatePromptAction.Update:
                        updateTransactionActive = true;
                        session.SetState(ConsolePromptState.Installing);
                        if (await InstallReleaseAsync(client, latest, requestCompanionExit, session).ConfigureAwait(false)) return true;
                        updateTransactionActive = false;
                        break;
                    case ControllerUpdatePromptAction.NotNow:
                        dismissedReleaseTag = latest.Tag;
                        session.SetState(ConsolePromptState.None);
                        BridgeConsole.WriteStatus(session, "Updates", "dismissed for this session", BridgeTone.Neutral);
                        return false;
                    case ControllerUpdatePromptAction.ViewNotes:
                        session.SetState(ConsolePromptState.ReleaseNotes);
                        WriteDetails(latest, session);
                        session.SetState(ConsolePromptState.UpdateChoice);
                        break;
                    case ControllerUpdatePromptAction.Recovery:
                        session.SetState(ConsolePromptState.RecoveryBrowser);
                        if (await RunRecoveryModeAsync(client, companionRoot, catalog, requestCompanionExit, session).ConfigureAwait(false)) return true;
                        session.SetState(ConsolePromptState.UpdateChoice);
                        break;
                }
            }
        }
        finally
        {
            activePromptTag = null;
            if (session.State != ConsolePromptState.Installing)
            {
                session.SetState(ConsolePromptState.None);
            }
            PromptSemaphore.Release();
        }
    }

    public static async Task<bool> UpdateLatestAsync(Action? requestCompanionExit, bool assumeYes, IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        if (updateTransactionActive) return false;
        string companionRoot = GetCompanionRoot();
        using var client = CreateClient(companionRoot);
        List<ControllerReleaseCatalogItem> catalog = await GetCatalogAsync(client, companionRoot).ConfigureAwait(false);
        ControllerReleaseCatalogItem latest = catalog.FirstOrDefault(item => item.IsLatest)
            ?? throw new InvalidDataException("GitHub Latest did not resolve to a compatible controller release.");
        InstalledControllerReleaseState? installed = ControllerReleaseSecurity.ReadInstalledState(companionRoot);
        if (!IsNewer(latest, installed))
        {
            BridgeConsole.WriteStatus(session, "Updates", "installed release is already GitHub Latest", BridgeTone.Good);
            return false;
        }
        if (!assumeYes && !BridgeConsole.ConfirmReleaseAction("Update now", latest.DisplayVersion, latest.Tag, false, session))
        {
            BridgeConsole.WriteStatus(session, "Updates", "cancelled; no files changed", BridgeTone.Neutral);
            return false;
        }
        updateTransactionActive = true;
        session.SetState(ConsolePromptState.Installing);
        return await InstallReleaseAsync(client, latest, requestCompanionExit, session).ConfigureAwait(false);
    }

    public static async Task<bool> RunRecoveryModeAsync(Action? requestCompanionExit, IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        string companionRoot = GetCompanionRoot();
        using var client = CreateClient(companionRoot);
        List<ControllerReleaseCatalogItem> catalog = await GetCatalogAsync(client, companionRoot).ConfigureAwait(false);
        return await RunRecoveryModeAsync(client, companionRoot, catalog, requestCompanionExit, session).ConfigureAwait(false);
    }

    public static async Task PrintCatalogAsync(IConsoleSession? session = null)
    {
        session ??= ConsoleInteractionCoordinator.Instance;
        string companionRoot = GetCompanionRoot();
        using var client = CreateClient(companionRoot);
        List<ControllerReleaseCatalogItem> catalog = await GetCatalogAsync(client, companionRoot).ConfigureAwait(false);
        foreach (ControllerReleaseCatalogItem item in catalog)
        {
            session.WriteLine(item.DisplayVersion + " | " + item.Tag + " " + ControllerUpdatePolicy.Indicators(item));
        }
    }

    public static async Task<List<ControllerReleaseCatalogItem>> GetCatalogAsync(
        ControllerGitHubReleaseClient client,
        string companionRoot)
    {
        ControllerGitHubRelease latest = await client.GetLatestAsync().ConfigureAwait(false);
        List<ControllerGitHubRelease> releases = await client.GetAllAsync().ConfigureAwait(false);
        LegacyControllerReleaseCatalog legacy = LoadLegacyCatalog(companionRoot);
        InstalledControllerReleaseState? installed = ControllerReleaseSecurity.ReadInstalledState(companionRoot);
        return await BuildCatalogAsync(client, releases, latest.TagName, installed, legacy).ConfigureAwait(false);
    }

    internal static async Task<List<ControllerReleaseCatalogItem>> BuildCatalogAsync(
        ControllerGitHubReleaseClient client,
        IEnumerable<ControllerGitHubRelease> releases,
        string latestTag,
        InstalledControllerReleaseState? installed,
        LegacyControllerReleaseCatalog legacy)
    {
        var result = new List<ControllerReleaseCatalogItem>();
        Version floor = Version.Parse(ControllerReleaseSecurity.NormalizeVersion(legacy.MinimumVersion));
        foreach (ControllerGitHubRelease release in releases.Where(item => !item.Draft))
        {
            Version version = Version.Parse(ControllerReleaseSecurity.NormalizeVersion(release.TagName));
            if (version < floor) continue;
            ControllerReleaseManifest? manifest = null;
            string unavailable = string.Empty;
            try
            {
                manifest = await client.TryGetManifestAsync(release).ConfigureAwait(false);
            }
            catch (Exception exception)
            {
                unavailable = exception.Message;
            }
            if (manifest != null)
            {
                ControllerGitHubAsset? package = release.Assets.FirstOrDefault(asset =>
                    asset.Name.Equals(manifest.Package.AssetName, StringComparison.Ordinal));
                result.Add(new ControllerReleaseCatalogItem
                {
                    Tag = manifest.ReleaseTag,
                    Title = release.Name,
                    SemanticVersion = manifest.SemanticVersion,
                    DisplayVersion = manifest.DisplayVersion,
                    ReleaseSequence = manifest.ReleaseSequence,
                    CommitSha = manifest.CommitSha,
                    PublishedAtUtc = release.PublishedAt == default ? manifest.PublishedAtUtc : release.PublishedAt,
                    IsPrerelease = release.Prerelease,
                    IsLatest = release.TagName == latestTag,
                    IsInstalled = installed?.ReleaseTag == release.TagName,
                    IsAvailable = package != null && unavailable.Length == 0,
                    UnavailableReason = package == null ? "package asset missing" : unavailable,
                    ReleaseUrl = release.HtmlUrl,
                    Summary = manifest.ReleaseSummary,
                    PackageAssetName = manifest.Package.AssetName,
                    PackageSha256 = manifest.Package.Sha256,
                    PackageByteLength = manifest.Package.ByteLength,
                    PackageDownloadUrl = package?.DownloadUrl ?? string.Empty,
                    Manifest = manifest,
                });
                continue;
            }

            LegacyControllerRelease? entry = legacy.Releases.FirstOrDefault(item => item.Tag == release.TagName);
            if (entry == null) continue;
            ControllerGitHubAsset? legacyPackage = release.Assets.FirstOrDefault(asset =>
                asset.Name.Equals(entry.AssetName, StringComparison.Ordinal));
            bool available = entry.Available && legacyPackage != null;
            result.Add(new ControllerReleaseCatalogItem
            {
                Tag = entry.Tag,
                Title = entry.Title,
                SemanticVersion = entry.Version,
                DisplayVersion = entry.DisplayVersion,
                ReleaseSequence = entry.ReleaseSequence,
                CommitSha = entry.CommitSha,
                PublishedAtUtc = release.PublishedAt == default ? entry.PublishedAtUtc : release.PublishedAt,
                IsPrerelease = release.Prerelease,
                IsLegacy = true,
                IsLatest = release.TagName == latestTag,
                IsInstalled = installed?.ReleaseTag == release.TagName,
                IsAvailable = available,
                UnavailableReason = available ? unavailable : entry.UnavailableReason.Length > 0
                    ? entry.UnavailableReason : "verified package asset unavailable",
                ReleaseUrl = release.HtmlUrl,
                Summary = "Trusted manifestless compatibility release.",
                PackageAssetName = entry.AssetName,
                PackageSha256 = entry.AssetSha256,
                PackageByteLength = entry.AssetByteLength > 0 ? entry.AssetByteLength : legacyPackage?.Size ?? 0,
                PackageDownloadUrl = legacyPackage?.DownloadUrl ?? string.Empty,
            });
        }
        result.Sort((left, right) => ControllerReleaseSecurity.CompareReleaseIdentity(right, left));
        return result;
    }

    public static async Task<ControllerPreparedUpdate> PrepareUpdateAsync(
        ControllerGitHubReleaseClient client,
        ControllerReleaseCatalogItem release,
        string companionRoot,
        string barDataRoot,
        int waitForProcessId,
        string waitForProcessPath)
    {
        if (!release.IsAvailable) throw new InvalidOperationException("Release is unavailable: " + release.UnavailableReason);
        string transactionRoot = Path.Combine(
            companionRoot, "updates", release.Tag, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(transactionRoot);
        string packagePath = Path.Combine(transactionRoot, release.PackageAssetName);
        ControllerReleaseManifest downloadIdentity = release.Manifest ?? CreateLegacyPackageIdentity(release);
        ControllerGitHubAsset asset = new ControllerGitHubAsset
        {
            Name = release.PackageAssetName,
            DownloadUrl = release.PackageDownloadUrl,
            Size = release.PackageByteLength,
            Digest = "sha256:" + release.PackageSha256,
        };
        await client.DownloadPackageAsync(asset, packagePath, downloadIdentity).ConfigureAwait(false);
        string stagingRoot = Path.Combine(transactionRoot, "staging");
        ControllerReleaseSecurity.SafeExtractZip(packagePath, stagingRoot);
        ControllerReleaseManifest manifest = release.Manifest
            ?? LegacyControllerManifestAdapter.Create(release, stagingRoot);
        string manifestPath = Path.Combine(transactionRoot, "controller-release-manifest.json");
        ControllerReleaseSecurity.WriteJsonAtomic(manifestPath, manifest);
        ControllerReleaseSecurity.ReadManifest(manifestPath, stagingRoot, requireDetachedPackageIdentity: true);

        string backupRoot = Path.Combine(
            companionRoot,
            "recovery-backups",
            DateTime.Now.ToString("yyyyMMdd-HHmmssfff") + "-" + release.Tag);
        ControllerUpdateTransactionPlan plan = ControllerReleaseTransaction.CreateValidatedPlan(
            packagePath,
            stagingRoot,
            manifestPath,
            barDataRoot,
            companionRoot,
            backupRoot,
            ControllerReleaseSecurity.IsBarRunning(),
            waitForProcessId,
            waitForProcessPath,
            restartCompanion: waitForProcessId > 0,
            restartExecutable: Path.Combine(companionRoot, "BARControllerBridge.exe"));
        string planPath = Path.Combine(transactionRoot, "transaction-plan.json");
        ControllerReleaseSecurity.WriteJsonAtomic(planPath, plan);
        string helperPath = CopyValidatedHelper(companionRoot, stagingRoot, transactionRoot);
        return new ControllerPreparedUpdate
        {
            Release = release,
            Plan = plan,
            PlanPath = planPath,
            HelperPath = helperPath,
        };
    }

    private static async Task<bool> InstallReleaseAsync(
        ControllerGitHubReleaseClient client,
        ControllerReleaseCatalogItem release,
        Action? requestCompanionExit,
        IConsoleSession session)
    {
        string companionRoot = GetCompanionRoot();
        int pid = Process.GetCurrentProcess().Id;
        string processPath = Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty;
        ControllerPreparedUpdate prepared = await PrepareUpdateAsync(
            client, release, companionRoot, GetBarDataRoot(), pid, processPath).ConfigureAwait(false);
        Process.Start(new ProcessStartInfo
        {
            FileName = prepared.HelperPath,
            Arguments = "--plan " + Quote(prepared.PlanPath),
            WorkingDirectory = Path.GetDirectoryName(prepared.HelperPath) ?? companionRoot,
            UseShellExecute = true,
            WindowStyle = ProcessWindowStyle.Normal,
        });
        BridgeConsole.WriteStatus(session, "Updates", "validated transaction handed to external updater", BridgeTone.Good);
        requestCompanionExit?.Invoke();
        return true;
    }

    private static async Task<bool> RunRecoveryModeAsync(
        ControllerGitHubReleaseClient client,
        string companionRoot,
        List<ControllerReleaseCatalogItem> catalog,
        Action? requestCompanionExit,
        IConsoleSession session)
    {
        if (session.Input.IsRedirected || session.Output.IsRedirected) return false;
        int page = 0;
        int pageCount = Math.Max(1, (catalog.Count + RecoveryPageSize - 1) / RecoveryPageSize);
        while (true)
        {
            page = Math.Max(0, Math.Min(page, pageCount - 1));
            List<ControllerReleaseCatalogItem> items = catalog.Skip(page * RecoveryPageSize).Take(RecoveryPageSize).ToList();
            var rows = new List<string>();
            for (int index = 0; index < items.Count; index++)
            {
                ControllerReleaseCatalogItem item = items[index];
                rows.Add((index + 1) + ". " + item.DisplayVersion + " - " + TrimTitle(item.Title, 24) + " " + ControllerUpdatePolicy.Indicators(item));
            }
            ConsoleKey key = BridgeConsole.ReadRecoveryChoice(rows, page + 1, pageCount, session);
            if (key == ConsoleKey.N && page + 1 < pageCount) { page++; continue; }
            if (key == ConsoleKey.P && page > 0) { page--; continue; }
            if (key == ConsoleKey.B || key == ConsoleKey.Q || key == ConsoleKey.Escape) return false;
            int selected = KeyNumber(key);
            if (selected < 1 || selected > items.Count) continue;
            ControllerReleaseCatalogItem release = items[selected - 1];
            WriteDetails(release, session);
            if (!release.IsAvailable)
            {
                BridgeConsole.WriteStatus(session, "Recovery", release.UnavailableReason, BridgeTone.Bad);
                continue;
            }
            InstalledControllerReleaseState? installed = ControllerReleaseSecurity.ReadInstalledState(companionRoot);
            bool reinstall = installed?.ReleaseTag == release.Tag;
            bool downgrade = installed != null && !reinstall
                && release.ReleaseSequence <= installed.ReleaseSequence;
            string action = reinstall ? "Reinstall release" : downgrade ? "Downgrade release" : "Install release";
            if (!BridgeConsole.ConfirmReleaseAction(action, release.DisplayVersion, release.Tag, downgrade || reinstall, session)) continue;
            return await InstallReleaseAsync(client, release, requestCompanionExit, session).ConfigureAwait(false);
        }
    }

    private static ControllerReleaseManifest CreateLegacyPackageIdentity(ControllerReleaseCatalogItem release)
    {
        return new ControllerReleaseManifest
        {
            ReleaseTag = release.Tag,
            SemanticVersion = release.SemanticVersion,
            DisplayVersion = release.DisplayVersion,
            ReleaseSequence = release.ReleaseSequence,
            ReleaseChannel = "legacy",
            CommitSha = release.CommitSha,
            PublishedAtUtc = release.PublishedAtUtc,
            Repository = ControllerReleaseSecurity.OfficialRepository,
            Package = new ControllerPackageIdentity
            {
                AssetName = release.PackageAssetName,
                Sha256 = release.PackageSha256,
                ByteLength = release.PackageByteLength,
                Format = "zip",
            },
        };
    }

    private static string CopyValidatedHelper(string companionRoot, string stagingRoot, string transactionRoot)
    {
        string installed = Path.Combine(companionRoot, "BARControllerUpdater.exe");
        string staged = Directory.EnumerateFiles(stagingRoot, "BARControllerUpdater.exe", SearchOption.AllDirectories).FirstOrDefault()
            ?? string.Empty;
        string source = File.Exists(installed) ? installed : staged;
        if (!File.Exists(source)) throw new FileNotFoundException("External updater helper is unavailable.");
        InstalledControllerReleaseState? state = ControllerReleaseSecurity.ReadInstalledState(companionRoot);
        InstalledControllerComponent? record = state?.Components.FirstOrDefault(component =>
            component.DestinationRoot.Equals("companion", StringComparison.OrdinalIgnoreCase)
            && component.DestinationPath.Equals("BARControllerUpdater.exe", StringComparison.OrdinalIgnoreCase));
        if (source == installed && record != null && !ControllerReleaseSecurity.FixedHashEquals(
            ControllerReleaseSecurity.ComputeSha256(source), record.Sha256))
        {
            throw new InvalidDataException("Installed updater helper hash no longer matches installed-release state.");
        }
        string destination = Path.Combine(transactionRoot, "helper", "BARControllerUpdater.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        File.Copy(source, destination, false);
        if (!ControllerReleaseSecurity.FixedHashEquals(
            ControllerReleaseSecurity.ComputeSha256(source), ControllerReleaseSecurity.ComputeSha256(destination)))
        {
            throw new InvalidDataException("Updater helper copy failed validation.");
        }
        return destination;
    }

    private static ControllerGitHubReleaseClient CreateClient(string companionRoot)
    {
        return new ControllerGitHubReleaseClient(Path.Combine(companionRoot, "release-cache"));
    }

    private static LegacyControllerReleaseCatalog LoadLegacyCatalog(string companionRoot)
    {
        foreach (string path in new[]
        {
            Path.Combine(companionRoot, "legacy-release-catalog.json"),
            Path.Combine(AppContext.BaseDirectory, "legacy-release-catalog.json"),
        })
        {
            if (!File.Exists(path)) continue;
            LegacyControllerReleaseCatalog catalog = JsonSerializer.Deserialize<LegacyControllerReleaseCatalog>(
                File.ReadAllText(path), ControllerReleaseSecurity.JsonOptions)
                ?? throw new InvalidDataException("Legacy release catalog is empty.");
            if (catalog.Kind != "bar-controller-legacy-release-catalog" || catalog.SchemaVersion != 1
                || !catalog.Repository.Equals(ControllerReleaseSecurity.OfficialRepository, StringComparison.OrdinalIgnoreCase)
                || ControllerReleaseSecurity.NormalizeVersion(catalog.MinimumVersion) != "0.6.0")
            {
                throw new InvalidDataException("Legacy release catalog identity is invalid.");
            }
            catalog.Releases ??= new List<LegacyControllerRelease>();
            return catalog;
        }
        throw new FileNotFoundException("Trusted legacy release catalog is missing.");
    }

    private static bool IsNewer(ControllerReleaseCatalogItem latest, InstalledControllerReleaseState? installed)
    {
        if (installed == null) return true;
        if (latest.Tag == installed.ReleaseTag) return false;
        if (latest.ReleaseSequence != installed.ReleaseSequence) return latest.ReleaseSequence > installed.ReleaseSequence;
        if (latest.PublishedAtUtc != default && latest.CommitSha != installed.CommitSha) return true;
        return string.Compare(latest.Tag, installed.ReleaseTag, StringComparison.Ordinal) > 0;
    }

    private static void WriteDetails(ControllerReleaseCatalogItem release, IConsoleSession session)
    {
        BridgeConsole.WriteReleaseDetails(
            release.DisplayVersion,
            release.Tag,
            release.Title,
            release.PublishedAtUtc,
            release.Summary,
            ControllerUpdatePolicy.Indicators(release),
            session);
    }

    private static string TrimTitle(string value, int width)
    {
        string normalized = value.Replace("BAR Controller Support ", string.Empty);
        return normalized.Length <= width ? normalized : normalized.Substring(0, width - 3) + "...";
    }

    private static int KeyNumber(ConsoleKey key)
    {
        if (key >= ConsoleKey.D1 && key <= ConsoleKey.D9) return key - ConsoleKey.D0;
        if (key >= ConsoleKey.NumPad1 && key <= ConsoleKey.NumPad9) return key - ConsoleKey.NumPad0;
        return 0;
    }

    private static string GetCompanionRoot()
    {
        string? test = Environment.GetEnvironmentVariable("BAR_CONTROLLER_PROGRAM_DATA");
        return !string.IsNullOrWhiteSpace(test) ? Path.GetFullPath(test) : Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs", "BARControllerCompanion");
    }

    private static string GetBarDataRoot()
    {
        string? test = Environment.GetEnvironmentVariable("BAR_CONTROLLER_BAR_DATA");
        return !string.IsNullOrWhiteSpace(test) ? Path.GetFullPath(test) : Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs", "Beyond-All-Reason", "data");
    }

    private static string Quote(string value) => "\"" + value.Replace("\"", "\\\"") + "\"";
}

internal static class LegacyControllerManifestAdapter
{
    public static ControllerReleaseManifest Create(ControllerReleaseCatalogItem release, string stagingRoot)
    {
        var components = new List<ControllerPayloadComponent>();
        var destinations = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (string file in Directory.EnumerateFiles(stagingRoot, "*", SearchOption.AllDirectories))
        {
            string source = Path.GetRelativePath(stagingRoot, file).Replace('\\', '/');
            int luaIndex = source.IndexOf("luaui/", StringComparison.OrdinalIgnoreCase);
            if (luaIndex < 0) continue;
            string luaPath = source.Substring(luaIndex);
            if (!luaPath.StartsWith("luaui/Widgets/", StringComparison.OrdinalIgnoreCase)
                && !luaPath.StartsWith("luaui/Include/", StringComparison.OrdinalIgnoreCase)
                && !luaPath.StartsWith("luaui/images/", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }
            string destination = "LuaUI/" + luaPath.Substring("luaui/".Length);
            if (!destinations.Add(destination)) continue;
            FileInfo info = new FileInfo(file);
            components.Add(new ControllerPayloadComponent
            {
                ComponentId = "legacy-" + components.Count.ToString("D3"),
                ComponentType = destination.EndsWith(".lua", StringComparison.OrdinalIgnoreCase)
                    ? destination.IndexOf("/Include/", StringComparison.OrdinalIgnoreCase) >= 0 ? "lua-include" : "lua-widget"
                    : "lua-asset",
                SourcePath = source,
                DestinationRoot = "bar-data",
                DestinationPath = destination,
                Sha256 = ControllerReleaseSecurity.ComputeSha256(file),
                ByteLength = info.Length,
                BarMustRunLuaUiReset = true,
                Platform = "any",
                Architecture = "any",
            });
        }
        if (components.Count == 0)
        {
            throw new InvalidDataException("Legacy package contains no compatible LuaUI payload.");
        }
        var manifest = new ControllerReleaseManifest
        {
            ReleaseTag = release.Tag,
            SemanticVersion = release.SemanticVersion,
            DisplayVersion = release.DisplayVersion,
            ReleaseSequence = release.ReleaseSequence,
            ReleaseChannel = "legacy",
            CommitSha = release.CommitSha,
            PublishedAtUtc = release.PublishedAtUtc,
            Repository = ControllerReleaseSecurity.OfficialRepository,
            Package = new ControllerPackageIdentity
            {
                AssetName = release.PackageAssetName,
                Sha256 = release.PackageSha256,
                ByteLength = release.PackageByteLength,
                Format = "zip",
            },
            MinimumUpdaterVersion = "0.8.0",
            RequiresLuaUiReset = true,
            ReleaseSummary = "Trusted legacy compatibility install; the modern update/recovery companion is preserved.",
            Components = components,
            ConfigurationPreservation = StandardPreservationRules(),
        };
        ControllerReleaseSecurity.ValidateManifest(manifest, stagingRoot, requireDetachedPackageIdentity: true);
        return manifest;
    }

    internal static List<ControllerPreservationRule> StandardPreservationRules()
    {
        return new List<ControllerPreservationRule>
        {
            new ControllerPreservationRule { RuleId = "bar-luaui-config", DestinationRoot = "bar-data", RelativePath = "LuaUI/Config", Recursive = true },
            new ControllerPreservationRule { RuleId = "bar-spring-settings", DestinationRoot = "bar-data", RelativePath = "springsettings.cfg" },
            new ControllerPreservationRule { RuleId = "companion-launcher-config", DestinationRoot = "companion", RelativePath = "launcher-config.json" },
            new ControllerPreservationRule { RuleId = "companion-user-data", DestinationRoot = "companion", RelativePath = "user-data", Recursive = true },
        };
    }
}
