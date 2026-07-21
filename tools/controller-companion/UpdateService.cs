using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

internal static class UpdateService
{
    private const string CurrentVersion = "0.6.1";
    private const string Repository = "UnderarmCape/underarmcape-bar-controller-support-attempt-01";
    private const string DefaultsBranch = "controller-ui-live-defaults";
    private const string DefaultsFileName = "shipping-defaults.json";
    private const string DefaultsManifestFileName = "shipping-defaults-manifest.json";
    private const string CacheDefaultsFileName = "controller-ui-defaults.json";
    private const string CacheManifestFileName = "controller-ui-defaults-manifest.json";
    private const string PreviousDefaultsFileName = "controller-ui-defaults.previous.json";
    private const string PreviousManifestFileName = "controller-ui-defaults-manifest.previous.json";
    private const string StatusFileName = "update-status.json";
    private const string ReloadRequestFileName = "reload-request.json";
    private const int StartupTimeoutMilliseconds = 2500;
    private const int ManualTimeoutMilliseconds = 12000;
    private const int MaximumDefaultsBytes = 2 * 1024 * 1024;
    private const int MaximumReleaseBytes = 256 * 1024 * 1024;
    private static string DefaultsBaseUrl => Environment.GetEnvironmentVariable("BAR_CONTROLLER_DEFAULTS_BASE_URL")
        ?? $"https://raw.githubusercontent.com/{Repository}/{DefaultsBranch}/";
    private static string LatestReleaseUrl => Environment.GetEnvironmentVariable("BAR_CONTROLLER_RELEASE_URL")
        ?? $"https://api.github.com/repos/{Repository}/releases/latest";
    private static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };
    private static readonly HashSet<string> Commands = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "check", "defaults", "update", "status", "reload", "help",
    };
    private static readonly HashSet<string> KnownComponents = new HashSet<string>(StringComparer.Ordinal)
    {
        "hints", "bindingsButton", "radials", "buildRadial", "tacticalRadial", "selectionRadial", "visibleSelectionRadial", "factoryRadial",
        "pregame", "reticle", "notifications", "instructional", "hotSlots", "selectedStatus", "queueStatus",
        "placementStatus", "companionStatus", "debug", "editorLauncher", "editor",
    };
    private static readonly HashSet<string> KnownActions = new HashSet<string>(StringComparer.Ordinal)
    {
        "select", "cancel", "smartAction", "buildRadial", "commandLayer", "insertNextCommandModifier",
        "appendQueueModifier", "controlGroupModifier", "pitchModifier", "removeQueuedCommand", "removeLastQueuedCommand",
        "radialSelect", "radialCancel", "radialQuick", "radialClose", "radialPrevPage", "radialNextPage", "place",
        "placeStay", "cancelPlacement", "rotateBuildingLeft", "rotateBuildingRight", "spacingUp", "spacingDown",
        "patternPrev", "patternNext", "tacticalSelect", "tacticalCancel", "tacticalClose", "commandUp", "commandDown",
        "commandLeft", "commandRight", "idlePrev", "idleNext", "groupSlotUp", "groupSlotDown", "groupRecallOrAssign",
        "groupAssign", "groupClear", "selectCommander",
    };
    private static readonly HashSet<string> KnownCategories = new HashSet<string>(StringComparer.Ordinal)
    {
        "Selection", "Commands", "Camera", "Building", "Placement", "Factory", "Tactical", "Radials",
        "Groups / Hot Slots", "Mouse Mode", "Pregame", "Editor", "System", "Advanced",
    };

    public static bool IsCommand(string[] args) => args.Length > 0 && Commands.Contains(args[0]);

    public static int RunCommand(string[] args)
    {
        try
        {
            string command = args[0].ToLowerInvariant();
            CommandOptions options = CommandOptions.Parse(args.Skip(1).ToArray());
            switch (command)
            {
                case "check":
                    CheckNowAsync(options, syncDefaults: true, checkRelease: true).GetAwaiter().GetResult();
                    return 0;
                case "defaults":
                    CheckNowAsync(options, syncDefaults: true, checkRelease: false).GetAwaiter().GetResult();
                    return 0;
                case "update":
                    return UpdateApplicationAsync(options).GetAwaiter().GetResult();
                case "status":
                    PrintStatus(options);
                    return 0;
                case "reload":
                    WriteReloadRequest(options);
                    return 0;
                default:
                    PrintHelp();
                    return 0;
            }
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine("[updates] " + exception.Message);
            return 1;
        }
    }

    public static void StartBackgroundStartupCheck()
    {
        Task.Run(async () =>
        {
            try
            {
                var options = new CommandOptions { TimeoutMilliseconds = StartupTimeoutMilliseconds, Quiet = true };
                await CheckNowAsync(options, syncDefaults: true, checkRelease: true).ConfigureAwait(false);
            }
            catch (Exception exception)
            {
                Console.WriteLine("[updates] Offline or unavailable; cached defaults remain active: " + exception.Message);
            }
        });
    }

    private static async Task CheckNowAsync(CommandOptions options, bool syncDefaults, bool checkRelease)
    {
        UpdateStatus state = ReadStatus();
        state.LastCheckUtc = DateTimeOffset.UtcNow;
        try
        {
            if (syncDefaults)
            {
                DefaultsSyncResult result = await SyncDefaultsAsync(options).ConfigureAwait(false);
                state.DefaultsVersion = result.Version;
                state.DefaultsStatus = result.Message;
                if (!options.Quiet) Console.WriteLine("[defaults] " + result.Message);
            }
            if (checkRelease)
            {
                ReleaseInfo release = await GetLatestReleaseAsync(options).ConfigureAwait(false);
                state.LatestRelease = release.Version;
                state.ReleaseAvailable = CompareVersions(release.Version, CurrentVersion) > 0;
                state.ReleaseStatus = state.ReleaseAvailable
                    ? $"Application {release.Version} is available; run 'BARControllerBridge update' to approve download."
                    : $"Application {CurrentVersion} is current.";
                if (!options.Quiet) Console.WriteLine("[release] " + state.ReleaseStatus);
                else if (state.ReleaseAvailable) Console.WriteLine("[updates] " + state.ReleaseStatus);
            }
            state.LastError = null;
        }
        catch (Exception exception)
        {
            state.LastError = exception.Message;
            if (!options.Quiet) Console.WriteLine("[updates] Offline fallback: " + exception.Message);
            else throw;
        }
        finally
        {
            SaveStatus(state);
        }
    }

    private static async Task<DefaultsSyncResult> SyncDefaultsAsync(CommandOptions options)
    {
        using HttpClient client = CreateClient(options.TimeoutMilliseconds);
        byte[] manifestBytes = await GetLimitedBytesAsync(
            client,
            DefaultsBaseUrl + DefaultsManifestFileName,
            MaximumDefaultsBytes).ConfigureAwait(false);
        DefaultsManifest manifest = Deserialize<DefaultsManifest>(manifestBytes, "defaults manifest");
        ValidateManifest(manifest);
        string cacheDirectory = ResolveHandoffDirectory(options.BarDataPath);
        Directory.CreateDirectory(cacheDirectory);
        string defaultsPath = Path.Combine(cacheDirectory, CacheDefaultsFileName);
        string manifestPath = Path.Combine(cacheDirectory, CacheManifestFileName);
        byte[]? previousDefaults = null;
        byte[]? previousManifest = null;
        if (File.Exists(defaultsPath) && File.Exists(manifestPath))
        {
            try
            {
                previousDefaults = File.ReadAllBytes(defaultsPath);
                previousManifest = File.ReadAllBytes(manifestPath);
                DefaultsManifest local = JsonSerializer.Deserialize<DefaultsManifest>(previousManifest, JsonOptions)
                    ?? throw new InvalidDataException("Cached defaults manifest is empty.");
                ValidateManifest(local);
                DefaultsDocument localDefaults = Deserialize<DefaultsDocument>(previousDefaults, "cached controller UI defaults");
                bool localValid = localDefaults.Kind == "bar-controller-ui-defaults" && localDefaults.SchemaVersion == local.SchemaVersion
                    && localDefaults.DefaultsVersion == local.DefaultsVersion && localDefaults.Settings.ValueKind == JsonValueKind.Object
                    && FixedHashEquals(ComputeSha256(previousDefaults), local.Sha256);
                if (localValid) ValidateDefaultsDocument(localDefaults);
                if (!localValid) throw new InvalidDataException("Cached defaults pair is invalid.");
                if (CompareDefaultsVersions(local.DefaultsVersion, manifest.DefaultsVersion) >= 0)
                {
                    return new DefaultsSyncResult(local.DefaultsVersion, "Cached controller UI defaults are current (" + local.DefaultsVersion + ").");
                }
            }
            catch
            {
                // A malformed or interrupted pair is replaced atomically below.
                previousDefaults = null;
                previousManifest = null;
            }
        }

        byte[] defaultsBytes = await GetLimitedBytesAsync(
            client,
            DefaultsBaseUrl + manifest.DefaultsFile,
            MaximumDefaultsBytes).ConfigureAwait(false);
        string actualHash = ComputeSha256(defaultsBytes);
        if (!FixedHashEquals(actualHash, manifest.Sha256))
        {
            throw new InvalidDataException($"Defaults SHA-256 mismatch; expected {manifest.Sha256}, got {actualHash}.");
        }
        DefaultsDocument defaults = Deserialize<DefaultsDocument>(defaultsBytes, "controller UI defaults");
        if (defaults.Kind != "bar-controller-ui-defaults" || defaults.SchemaVersion != manifest.SchemaVersion
            || defaults.DefaultsVersion != manifest.DefaultsVersion || defaults.Settings.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException("Defaults payload does not match its manifest.");
        }
        ValidateDefaultsDocument(defaults);
        if (previousDefaults != null && previousManifest != null)
        {
            WriteAtomic(Path.Combine(cacheDirectory, PreviousDefaultsFileName), previousDefaults);
            WriteAtomic(Path.Combine(cacheDirectory, PreviousManifestFileName), previousManifest);
        }
        WriteAtomic(defaultsPath, defaultsBytes);
        WriteAtomic(manifestPath, manifestBytes); // manifest-last makes the pair visible only after the payload is durable
        return new DefaultsSyncResult(manifest.DefaultsVersion, "Controller UI defaults updated: revision " + manifest.DefaultsVersion);
    }

    private static async Task<ReleaseInfo> GetLatestReleaseAsync(CommandOptions options)
    {
        using HttpClient client = CreateClient(options.TimeoutMilliseconds);
        byte[] bytes = await GetLimitedBytesAsync(client, LatestReleaseUrl, MaximumDefaultsBytes).ConfigureAwait(false);
        GitHubRelease release = Deserialize<GitHubRelease>(bytes, "GitHub release response");
        string version = NormalizeVersion(release.TagName);
        if (version == "0.0.0") throw new InvalidDataException("Latest release has no semantic version tag.");
        return new ReleaseInfo(version, release);
    }

    private static async Task<int> UpdateApplicationAsync(CommandOptions options)
    {
        ReleaseInfo releaseInfo = await GetLatestReleaseAsync(options).ConfigureAwait(false);
        if (CompareVersions(releaseInfo.Version, CurrentVersion) <= 0)
        {
            Console.WriteLine("[release] BAR Controller Companion " + CurrentVersion + " is current.");
            return 0;
        }
        GitHubAsset? package = releaseInfo.Release.Assets.FirstOrDefault(asset =>
            Regex.IsMatch(asset.Name ?? string.Empty, @"^BAR_Controller_Support_v[0-9]+\.[0-9]+\.[0-9]+_Widget_Companion\.zip$", RegexOptions.IgnoreCase));
        if (package == null || string.IsNullOrWhiteSpace(package.BrowserDownloadUrl))
        {
            throw new InvalidDataException("Latest release does not contain a compatible companion package asset.");
        }
        if (!options.Yes)
        {
            Console.Write($"Download verified BAR Controller Companion {releaseInfo.Version}? [y/N] ");
            if (!IsYes(Console.ReadLine()))
            {
                Console.WriteLine("[release] Update cancelled; no files changed.");
                return 0;
            }
        }

        using HttpClient client = CreateClient(Math.Max(options.TimeoutMilliseconds, 30000));
        byte[] packageBytes = await GetLimitedBytesAsync(client, package.BrowserDownloadUrl, MaximumReleaseBytes).ConfigureAwait(false);
        string expectedHash = ParseAssetDigest(package.Digest);
        if (expectedHash.Length == 0)
        {
            GitHubAsset? sidecar = releaseInfo.Release.Assets.FirstOrDefault(asset =>
                string.Equals(asset.Name, package.Name + ".sha256", StringComparison.OrdinalIgnoreCase));
            if (sidecar == null || string.IsNullOrWhiteSpace(sidecar.BrowserDownloadUrl))
            {
                throw new InvalidDataException("Release package has no SHA-256 digest or sidecar; refusing download.");
            }
            byte[] sidecarBytes = await GetLimitedBytesAsync(client, sidecar.BrowserDownloadUrl, 64 * 1024).ConfigureAwait(false);
            expectedHash = Regex.Match(Encoding.UTF8.GetString(sidecarBytes), @"\b[a-fA-F0-9]{64}\b").Value.ToLowerInvariant();
        }
        string actualHash = ComputeSha256(packageBytes);
        if (!FixedHashEquals(actualHash, expectedHash))
        {
            throw new InvalidDataException($"Release SHA-256 mismatch; expected {expectedHash}, got {actualHash}.");
        }
        string updateDirectory = Path.Combine(GetProgramDataDirectory(), "updates", releaseInfo.Version);
        Directory.CreateDirectory(updateDirectory);
        string packagePath = Path.Combine(updateDirectory, package.Name ?? "controller-companion-update.zip");
        WriteAtomic(packagePath, packageBytes);
        Console.WriteLine("[release] Verified package cached at " + packagePath);

        bool apply = options.Apply;
        if (!apply && !options.Yes)
        {
            Console.Write("Launch the verified installer now? [y/N] ");
            apply = IsYes(Console.ReadLine());
        }
        if (apply)
        {
            string extracted = Path.Combine(updateDirectory, "extracted");
            if (Directory.Exists(extracted)) Directory.Delete(extracted, recursive: true);
            ZipFile.ExtractToDirectory(packagePath, extracted);
            string? installer = Directory.EnumerateFiles(extracted, "BAR_Controller_Companion_Installer*.exe", SearchOption.AllDirectories).FirstOrDefault();
            if (installer == null) throw new InvalidDataException("Verified package does not contain the companion installer.");
            Process.Start(new ProcessStartInfo(installer) { UseShellExecute = true });
            Console.WriteLine("[release] Verified installer launched with user approval.");
        }
        else
        {
            Console.WriteLine("[release] Update was downloaded but not applied.");
        }
        return 0;
    }

    private static void PrintStatus(CommandOptions options)
    {
        UpdateStatus state = ReadStatus();
        Console.WriteLine("BAR Controller Companion " + CurrentVersion);
        Console.WriteLine("Defaults cache: " + ResolveHandoffDirectory(options.BarDataPath));
        Console.WriteLine("Defaults: " + (state.DefaultsStatus ?? "not checked"));
        Console.WriteLine("Release: " + (state.ReleaseStatus ?? "not checked"));
        Console.WriteLine("Last check: " + (state.LastCheckUtc?.ToString("O") ?? "never"));
        if (!string.IsNullOrWhiteSpace(state.LastError)) Console.WriteLine("Last offline/error fallback: " + state.LastError);
    }

    private static void WriteReloadRequest(CommandOptions options)
    {
        string directory = ResolveHandoffDirectory(options.BarDataPath);
        Directory.CreateDirectory(directory);
        byte[] bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new
        {
            kind = "bar-controller-ui-reload-request",
            token = Guid.NewGuid().ToString("N"),
            requestedAt = DateTimeOffset.UtcNow,
        }, JsonOptions));
        string path = Path.Combine(directory, ReloadRequestFileName);
        WriteAtomic(path, bytes);
        Console.WriteLine("[defaults] Wrote reload request: " + path);
    }

    private static string ResolveHandoffDirectory(string? explicitBarDataPath)
    {
        string dataPath = ResolveBarDataPath(explicitBarDataPath);
        return Path.Combine(dataPath, "LuaUI", "Config", "BARControllerSupport");
    }

    private static string ResolveBarDataPath(string? explicitPath)
    {
        if (!string.IsNullOrWhiteSpace(explicitPath)) return Path.GetFullPath(Environment.ExpandEnvironmentVariables(explicitPath));
        foreach (string pathFile in new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Dev", "BAR_Controller_Companion", "BAR_DATA_PATH.txt"),
            Path.Combine(AppContext.BaseDirectory, "BAR_DATA_PATH.txt"),
        })
        {
            string? configured = ReadFirstPath(pathFile);
            if (configured != null) return configured;
        }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Beyond-All-Reason", "data");
    }

    private static string? ReadFirstPath(string pathFile)
    {
        if (!File.Exists(pathFile)) return null;
        try
        {
            foreach (string sourceLine in File.ReadAllLines(pathFile))
            {
                string line = Environment.ExpandEnvironmentVariables(sourceLine.Trim().Trim('"'));
                if (line.Length > 0 && !line.StartsWith("#", StringComparison.Ordinal) && Path.IsPathRooted(line)) return Path.GetFullPath(line);
            }
        }
        catch { }
        return null;
    }

    private static HttpClient CreateClient(int timeoutMilliseconds)
    {
        var client = new HttpClient { Timeout = TimeSpan.FromMilliseconds(Math.Max(250, timeoutMilliseconds)) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("BARControllerCompanion/" + CurrentVersion);
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        return client;
    }

    private static async Task<byte[]> GetLimitedBytesAsync(HttpClient client, string url, int maximumBytes)
    {
        using HttpResponseMessage response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength > maximumBytes) throw new InvalidDataException("Remote response exceeds size limit.");
        using Stream stream = await response.Content.ReadAsStreamAsync().ConfigureAwait(false);
        using var output = new MemoryStream();
        var buffer = new byte[81920];
        int total = 0;
        while (true)
        {
            int read = await stream.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false);
            if (read == 0) break;
            total += read;
            if (total > maximumBytes) throw new InvalidDataException("Remote response exceeds size limit.");
            output.Write(buffer, 0, read);
        }
        return output.ToArray();
    }

    private static T Deserialize<T>(byte[] bytes, string label)
    {
        try { return JsonSerializer.Deserialize<T>(bytes, JsonOptions) ?? throw new InvalidDataException(label + " is empty."); }
        catch (JsonException exception) { throw new InvalidDataException(label + " is malformed: " + exception.Message, exception); }
    }

    private static void ValidateManifest(DefaultsManifest manifest)
    {
        if (manifest.Kind != "bar-controller-ui-defaults-manifest" || manifest.ManifestVersion != 1
            || manifest.SchemaVersion < 1 || manifest.SchemaVersion > 3
            || manifest.DefaultsFile != DefaultsFileName || string.IsNullOrWhiteSpace(manifest.DefaultsVersion)
            || (!string.IsNullOrWhiteSpace(manifest.MinimumCompanionVersion)
                && CompareVersions(manifest.MinimumCompanionVersion, CurrentVersion) > 0)
            || !Regex.IsMatch(manifest.Sha256 ?? string.Empty, "^[a-fA-F0-9]{64}$"))
        {
            throw new InvalidDataException("Controller UI defaults manifest is invalid or unsupported.");
        }
    }

    private static void ValidateDefaultsDocument(DefaultsDocument defaults)
    {
        if (defaults.Settings.TryGetProperty("authoring", out JsonElement authoring) && authoring.ValueKind == JsonValueKind.Object
            && authoring.TryGetProperty("developerAuthoring", out JsonElement developerMode) && developerMode.ValueKind == JsonValueKind.True)
        {
            throw new InvalidDataException("Remote defaults cannot enable Developer Authoring Mode.");
        }
        if (!defaults.Settings.TryGetProperty("components", out JsonElement components) || components.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException("Controller UI defaults settings.components is missing.");
        }
        foreach (JsonProperty component in components.EnumerateObject())
        {
            if (!KnownComponents.Contains(component.Name)) throw new InvalidDataException("Unknown controller UI component ID: " + component.Name);
            ValidateValueRanges(component.Value, "components." + component.Name);
        }
        if (defaults.HintProfile.ValueKind != JsonValueKind.Object
            || !defaults.HintProfile.TryGetProperty("categories", out JsonElement categories) || categories.ValueKind != JsonValueKind.Array
            || !defaults.HintProfile.TryGetProperty("actionOrdering", out JsonElement actionOrdering) || actionOrdering.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidDataException("Controller UI hint profile is missing.");
        }
        var categoryIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (JsonElement category in categories.EnumerateArray())
        {
            string id = category.TryGetProperty("id", out JsonElement idElement) && idElement.ValueKind == JsonValueKind.String
                ? idElement.GetString() ?? string.Empty : string.Empty;
            if (!KnownCategories.Contains(id) || !categoryIds.Add(id)) throw new InvalidDataException("Unknown or duplicate hint category ID: " + id);
        }
        ValidateActionArray(actionOrdering, "actionOrdering");
        if (defaults.HintProfile.TryGetProperty("hiddenActions", out JsonElement hiddenActions)) ValidateActionArray(hiddenActions, "hiddenActions");
        ValidateActionMap(defaults.HintProfile, "defaultShortLabels", categoryValues: false);
        ValidateActionMap(defaults.HintProfile, "actionCategoryOverrides", categoryValues: true);
        if (defaults.ComponentPresets.ValueKind != JsonValueKind.Object) throw new InvalidDataException("componentPresets must be an object.");
        foreach (JsonProperty preset in defaults.ComponentPresets.EnumerateObject())
        {
            string component = preset.Value.TryGetProperty("component", out JsonElement componentElement)
                && componentElement.ValueKind == JsonValueKind.String ? componentElement.GetString() ?? string.Empty : string.Empty;
            if (!KnownComponents.Contains(component)) throw new InvalidDataException("Unknown preset component ID: " + component);
        }
        if (defaults.EnforcedPaths.ValueKind != JsonValueKind.Array) throw new InvalidDataException("enforcedPaths must be an array.");
        foreach (JsonElement pathElement in defaults.EnforcedPaths.EnumerateArray())
        {
            string path = pathElement.ValueKind == JsonValueKind.String ? pathElement.GetString() ?? string.Empty : string.Empty;
            string scope = path.Split('.').FirstOrDefault() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(path) || (!KnownComponents.Contains(scope) && scope != "global" && scope != "theme" && scope != "authoring"))
            {
                throw new InvalidDataException("Unknown enforced controller UI path: " + path);
            }
            if (string.Equals(path, "authoring.developerAuthoring", StringComparison.Ordinal))
            {
                throw new InvalidDataException("Developer Authoring Mode cannot be remotely enforced.");
            }
        }
    }

    private static void ValidateActionArray(JsonElement values, string label)
    {
        if (values.ValueKind != JsonValueKind.Array) throw new InvalidDataException(label + " must be an array.");
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (JsonElement value in values.EnumerateArray())
        {
            string id = value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;
            if (!KnownActions.Contains(id) || !seen.Add(id)) throw new InvalidDataException("Unknown or duplicate action ID in " + label + ": " + id);
        }
    }

    private static void ValidateActionMap(JsonElement profile, string name, bool categoryValues)
    {
        if (!profile.TryGetProperty(name, out JsonElement values) || values.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException(name + " must be an object.");
        }
        foreach (JsonProperty value in values.EnumerateObject())
        {
            if (!KnownActions.Contains(value.Name)) throw new InvalidDataException("Unknown action ID in " + name + ": " + value.Name);
            if (categoryValues && (value.Value.ValueKind != JsonValueKind.String || !KnownCategories.Contains(value.Value.GetString() ?? string.Empty)))
            {
                throw new InvalidDataException("Unknown category in " + name + ".");
            }
        }
    }

    private static void ValidateValueRanges(JsonElement value, string path)
    {
        if (value.ValueKind != JsonValueKind.Object) return;
        foreach (JsonProperty property in value.EnumerateObject())
        {
            if (property.Value.ValueKind == JsonValueKind.Number)
            {
                double number = property.Value.GetDouble();
                bool normalized = property.Name == "x" || property.Name == "y" || property.Name.EndsWith("Opacity", StringComparison.Ordinal);
                bool positiveScale = property.Name == "scale" || property.Name == "fontScale" || property.Name == "iconScale";
                if ((normalized && (number < 0 || number > 1)) || (positiveScale && (number < 0.5 || number > 2)))
                {
                    throw new InvalidDataException($"Controller UI value outside range at {path}.{property.Name}: {number}.");
                }
            }
            else if (property.Value.ValueKind == JsonValueKind.Object) ValidateValueRanges(property.Value, path + "." + property.Name);
        }
    }

    private static void WriteAtomic(string path, byte[] content)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path) ?? ".");
        string temporary = path + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            File.WriteAllBytes(temporary, content);
            File.Move(temporary, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    private static string ComputeSha256(byte[] content)
    {
        using SHA256 sha = SHA256.Create();
        return BitConverter.ToString(sha.ComputeHash(content)).Replace("-", string.Empty).ToLowerInvariant();
    }

    private static bool FixedHashEquals(string actual, string expected)
    {
        if (actual.Length != 64 || expected.Length != 64) return false;
        return CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(actual.ToLowerInvariant()), Encoding.ASCII.GetBytes(expected.ToLowerInvariant()));
    }

    private static string ParseAssetDigest(string? digest)
    {
        Match match = Regex.Match(digest ?? string.Empty, @"(?:sha256:)?(?<hash>[a-fA-F0-9]{64})");
        return match.Success ? match.Groups["hash"].Value.ToLowerInvariant() : string.Empty;
    }

    private static string NormalizeVersion(string? value)
    {
        Match match = Regex.Match(value ?? string.Empty, @"(?<version>\d+\.\d+\.\d+)");
        return match.Success ? match.Groups["version"].Value : "0.0.0";
    }

    private static int CompareVersions(string first, string second)
    {
        return Version.Parse(NormalizeVersion(first)).CompareTo(Version.Parse(NormalizeVersion(second)));
    }

    private static int CompareDefaultsVersions(string first, string second)
    {
        int[] firstParts = Regex.Matches(first ?? string.Empty, @"\d+").Cast<Match>().Select(match => int.Parse(match.Value)).ToArray();
        int[] secondParts = Regex.Matches(second ?? string.Empty, @"\d+").Cast<Match>().Select(match => int.Parse(match.Value)).ToArray();
        for (int index = 0; index < Math.Max(firstParts.Length, secondParts.Length); index++)
        {
            int firstValue = index < firstParts.Length ? firstParts[index] : 0;
            int secondValue = index < secondParts.Length ? secondParts[index] : 0;
            if (firstValue != secondValue) return firstValue.CompareTo(secondValue);
        }
        return 0;
    }

    private static bool IsYes(string? value) => string.Equals(value?.Trim(), "y", StringComparison.OrdinalIgnoreCase)
        || string.Equals(value?.Trim(), "yes", StringComparison.OrdinalIgnoreCase);

    private static string GetProgramDataDirectory()
    {
        string? testOverride = Environment.GetEnvironmentVariable("BAR_CONTROLLER_PROGRAM_DATA");
        if (!string.IsNullOrWhiteSpace(testOverride)) return Path.GetFullPath(testOverride);
        string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(local, "Programs", "BARControllerCompanion");
    }

    private static string GetStatusPath() => Path.Combine(GetProgramDataDirectory(), StatusFileName);

    private static UpdateStatus ReadStatus()
    {
        try
        {
            string path = GetStatusPath();
            return File.Exists(path)
                ? JsonSerializer.Deserialize<UpdateStatus>(File.ReadAllText(path), JsonOptions) ?? new UpdateStatus()
                : new UpdateStatus();
        }
        catch { return new UpdateStatus(); }
    }

    private static void SaveStatus(UpdateStatus state)
    {
        try { WriteAtomic(GetStatusPath(), Encoding.UTF8.GetBytes(JsonSerializer.Serialize(state, JsonOptions))); }
        catch (Exception exception) { Console.WriteLine("[updates] Could not persist update status: " + exception.Message); }
    }

    private static void PrintHelp()
    {
        Console.WriteLine("BAR Controller Companion update/defaults commands:");
        Console.WriteLine("  check                 Sync defaults and check the latest public release");
        Console.WriteLine("  defaults              Sync only controller UI shipping defaults");
        Console.WriteLine("  update [--yes] [--apply]  Approve a hash-verified application download/apply");
        Console.WriteLine("  status                Show cached defaults, release, and offline state");
        Console.WriteLine("  reload                Request a running UI layout widget to reload its cache");
        Console.WriteLine("Options: --bar-data path --timeout-ms N");
        Console.WriteLine("Startup checks are short, fail soft, preserve valid caches, and never apply releases.");
    }

    internal sealed class CommandOptions
    {
        public string? BarDataPath { get; set; }
        public int TimeoutMilliseconds { get; set; } = ManualTimeoutMilliseconds;
        public bool Yes { get; set; }
        public bool Apply { get; set; }
        public bool Quiet { get; set; }

        public static CommandOptions Parse(string[] args)
        {
            var result = new CommandOptions();
            for (int index = 0; index < args.Length; index++)
            {
                string argument = args[index];
                if (argument == "--bar-data" && index + 1 < args.Length) result.BarDataPath = args[++index];
                else if (argument == "--timeout-ms" && index + 1 < args.Length
                    && int.TryParse(args[++index], out int timeout) && timeout >= 250 && timeout <= 120000) result.TimeoutMilliseconds = timeout;
                else if (argument == "--yes") result.Yes = true;
                else if (argument == "--apply") result.Apply = true;
                else throw new ArgumentException("Unknown update option: " + argument);
            }
            if (result.Apply && !result.Yes) throw new ArgumentException("--apply requires explicit --yes approval.");
            return result;
        }
    }

    private sealed class DefaultsManifest
    {
        public string? Kind { get; set; }
        public int ManifestVersion { get; set; }
        public int SchemaVersion { get; set; }
        public string DefaultsVersion { get; set; } = string.Empty;
        public string DefaultsFile { get; set; } = string.Empty;
        public string Sha256 { get; set; } = string.Empty;
        public string? MinimumCompanionVersion { get; set; }
    }

    private sealed class DefaultsDocument
    {
        public string? Kind { get; set; }
        public int SchemaVersion { get; set; }
        public string? DefaultsVersion { get; set; }
        public JsonElement Settings { get; set; }
        public JsonElement HintProfile { get; set; }
        public JsonElement ComponentPresets { get; set; }
        public JsonElement EnforcedPaths { get; set; }
    }

    private sealed class GitHubRelease
    {
        [JsonPropertyName("tag_name")]
        public string? TagName { get; set; }

        [JsonPropertyName("assets")]
        public List<GitHubAsset> Assets { get; set; } = new List<GitHubAsset>();
    }

    private sealed class GitHubAsset
    {
        [JsonPropertyName("name")]
        public string? Name { get; set; }

        [JsonPropertyName("browser_download_url")]
        public string? BrowserDownloadUrl { get; set; }

        [JsonPropertyName("digest")]
        public string? Digest { get; set; }
    }

    private sealed class UpdateStatus
    {
        public DateTimeOffset? LastCheckUtc { get; set; }
        public string? DefaultsVersion { get; set; }
        public string? DefaultsStatus { get; set; }
        public string? LatestRelease { get; set; }
        public bool ReleaseAvailable { get; set; }
        public string? ReleaseStatus { get; set; }
        public string? LastError { get; set; }
    }

    private sealed class DefaultsSyncResult
    {
        public DefaultsSyncResult(string version, string message) { Version = version; Message = message; }
        public string Version { get; }
        public string Message { get; }
    }

    private sealed class ReleaseInfo
    {
        public ReleaseInfo(string version, GitHubRelease release) { Version = version; Release = release; }
        public string Version { get; }
        public GitHubRelease Release { get; }
    }
}
