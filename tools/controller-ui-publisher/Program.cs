using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;

internal static class Program
{
    private const string DefaultRepository = "UnderarmCape/underarmcape-bar-controller-support-attempt-01";
    private const string DefaultBranch = "controller-ui-live-defaults";
    private const string DefaultsName = "shipping-defaults.json";
    private const string ManifestName = "shipping-defaults-manifest.json";
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private static readonly object RequestLock = new();
    private static readonly HashSet<string> ProcessedRequestIds = new(StringComparer.Ordinal);
    private static string? LastPublishedCommit;
    private static readonly HashSet<string> KnownComponents = new(StringComparer.Ordinal)
    {
        "hints", "bindingsButton", "radials", "buildRadial", "tacticalRadial", "selectionRadial", "visibleSelectionRadial", "factoryRadial",
        "pregame", "reticle", "notifications", "instructional", "hotSlots", "selectedStatus", "queueStatus",
        "placementStatus", "companionStatus", "debug", "gameplay", "editorLauncher", "editor",
    };
    private static readonly HashSet<string> KnownActions = new(StringComparer.Ordinal)
    {
        "select", "cancel", "smartAction", "buildRadial", "commandLayer", "insertNextCommandModifier",
        "appendQueueModifier", "controlGroupModifier", "pitchModifier", "removeQueuedCommand",
        "removeLastQueuedCommand", "radialSelect", "radialCancel", "radialQuick", "radialClose",
        "radialPrevPage", "radialNextPage", "place", "placeStay", "cancelPlacement", "rotateBuildingLeft",
        "rotateBuildingRight", "spacingUp", "spacingDown", "patternPrev", "patternNext", "tacticalSelect",
        "tacticalCancel", "tacticalClose", "commandUp", "commandDown", "commandLeft", "commandRight",
        "idlePrev", "idleNext", "groupSlotUp", "groupSlotDown", "groupRecallOrAssign", "groupAssign",
        "groupClear", "selectCommander",
    };
    private static readonly HashSet<string> KnownCategories = new(StringComparer.Ordinal)
    {
        "Selection", "Commands", "Camera", "Building", "Placement", "Factory", "Tactical", "Radials",
        "Groups / Hot Slots", "Mouse Mode", "Pregame", "Editor", "System", "Advanced",
    };
    private static readonly Dictionary<string, (double Minimum, double Maximum)> NumericRanges = new(StringComparer.Ordinal)
    {
        ["x"] = (0, 1), ["y"] = (0, 1), ["scale"] = (0.5, 2), ["opacity"] = (0, 1),
        ["fontScale"] = (0.5, 2), ["iconScale"] = (0.5, 2), ["backgroundOpacity"] = (0, 1),
        ["textOpacity"] = (0, 1), ["borderOpacity"] = (0, 1), ["slotCount"] = (1, 10),
        ["slotSize"] = (24, 84), ["slotWidth"] = (24, 120), ["slotHeight"] = (24, 100),
        ["rows"] = (1, 5), ["wrapLines"] = (2, 8), ["fontMinScale"] = (0.4, 1),
    };

    private static int Main(string[] args)
    {
        try
        {
            if (args.Length == 0 || IsHelp(args[0]))
            {
                PrintHelp();
                return 0;
            }

            string command = args[0].ToLowerInvariant();
            Options options = Options.Parse(args.Skip(1).ToArray());
            return command switch
            {
                "validate" => ValidateCommand(options),
                "prepare" => PrepareCommand(options),
                "dry-run" => DryRunCommand(options),
                "watch" => WatchCommand(options),
                "publish" => PublishCommand(options),
                _ => throw new ArgumentException("Unknown command: " + command),
            };
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine("[publisher] " + exception.Message);
            return 1;
        }
    }

    private static int ValidateCommand(Options options)
    {
        ValidatedPair pair = ValidatePair(options.DefaultsPath, options.ManifestPath, allowDraft: options.AllowDraft);
        Console.WriteLine($"[publisher] Valid {pair.Version} defaults pair; SHA-256 {pair.Sha256}.");
        return 0;
    }

    private static int PrepareCommand(Options options)
    {
        string version = options.Version ?? throw new ArgumentException("prepare requires --version.");
        if (string.IsNullOrWhiteSpace(options.DraftPath) || !File.Exists(options.DraftPath))
        {
            throw new FileNotFoundException("prepare requires an existing --draft file.", options.DraftPath);
        }

        using JsonDocument draftDocument = ParseDocument(options.DraftPath);
        JsonElement draft = draftDocument.RootElement;
        RequireString(draft, "kind", "bar-controller-ui-defaults");
        RequireSchema(draft);
        ValidateDefaultsStructure(draft);
        int schemaVersion = draft.GetProperty("schemaVersion").GetInt32();
        Directory.CreateDirectory(options.OutputDirectory);
        string defaultsPath = Path.Combine(options.OutputDirectory, DefaultsName);
        using (var stream = new MemoryStream())
        {
            using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true }))
            {
                writer.WriteStartObject();
                foreach (JsonProperty property in draft.EnumerateObject())
                {
                    if (property.NameEquals("defaultsVersion") || property.NameEquals("generatedAt") || property.NameEquals("draft")) continue;
                    property.WriteTo(writer);
                }
                writer.WriteString("defaultsVersion", version);
                writer.WriteString("generatedAt", DateTimeOffset.UtcNow.ToString("O"));
                writer.WriteEndObject();
            }
            WriteAtomic(defaultsPath, Encoding.UTF8.GetString(stream.ToArray()) + Environment.NewLine);
        }
        string sha = ComputeSha256(defaultsPath);
        var manifest = new Dictionary<string, object>
        {
            ["kind"] = "bar-controller-ui-defaults-manifest",
            ["manifestVersion"] = 1,
            ["schemaVersion"] = schemaVersion,
            ["revision"] = ParseRevision(version),
            ["defaultsVersion"] = version,
            ["defaultsFile"] = DefaultsName,
            ["sha256"] = sha,
            ["generatedAt"] = DateTimeOffset.UtcNow.ToString("O"),
            ["publishedAt"] = DateTimeOffset.UtcNow.ToString("O"),
            ["minimumCompanionVersion"] = options.MinimumCompanionVersion ?? "0.6.0",
            ["minimumModVersion"] = "0.6.0",
            ["sourceBranch"] = options.Branch,
            ["sourceCommit"] = "pending-publish",
            ["changeSummary"] = "Controller UI defaults " + version,
            ["releaseChannel"] = options.Channel ?? "stable",
        };
        string manifestPath = Path.Combine(options.OutputDirectory, ManifestName);
        WriteAtomic(manifestPath, JsonSerializer.Serialize(manifest, JsonOptions) + Environment.NewLine);
        ValidatePair(defaultsPath, manifestPath, allowDraft: false);
        Console.WriteLine($"[publisher] Prepared atomic defaults pair in {options.OutputDirectory}.");
        return 0;
    }

    private static int DryRunCommand(Options options)
    {
        ValidatedPair pair = ValidatePair(options.DefaultsPath, options.ManifestPath, allowDraft: options.AllowDraft);
        string repositoryPath = options.LocalRepository
            ?? throw new ArgumentException("dry-run requires --local-repository pointing to a disposable directory.");
        repositoryPath = Path.GetFullPath(repositoryPath);
        Directory.CreateDirectory(repositoryPath);
        if (!Directory.Exists(Path.Combine(repositoryPath, ".git")))
        {
            Run("git", new[] { "init", repositoryPath });
        }
        Run("git", new[] { "-C", repositoryPath, "config", "user.name", "BAR Controller UI Dry Run" });
        Run("git", new[] { "-C", repositoryPath, "config", "user.email", "bar-controller-ui-dry-run@invalid.local" });
        RunAllowFailure("git", new[] { "-C", repositoryPath, "checkout", "-B", options.Branch });
        CopyPair(pair, repositoryPath);
        Run("git", new[] { "-C", repositoryPath, "add", "--", DefaultsName, ManifestName });
        Run("git", new[] { "-C", repositoryPath, "commit", "--allow-empty", "-m", $"controller-ui defaults {pair.Version} (dry run)" });
        Console.WriteLine($"[publisher] Dry run committed both files atomically in {repositoryPath}; no remote was contacted.");
        return 0;
    }

    private static int WatchCommand(Options options)
    {
        string outbox = Path.GetFullPath(options.OutboxDirectory);
        Directory.CreateDirectory(outbox);
        Console.WriteLine("[publisher] Watching " + outbox);
        Console.WriteLine(options.ArmExplicitPublish
            ? "[publisher] Explicit publish-request processing is ARMED; ordinary drafts and saves are ignored."
            : "[publisher] Watch mode validates drafts only. It never publishes unless --arm-explicit-publish is supplied.");
        string draftName = Path.GetFileName(options.DraftPath ?? "shipping-defaults.draft.json");
        using var watcher = new FileSystemWatcher(outbox, draftName)
        {
            NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName | NotifyFilters.Size,
            EnableRaisingEvents = true,
        };
        watcher.Changed += (_, eventArgs) => ValidateDraftWithRetry(eventArgs.FullPath);
        watcher.Created += (_, eventArgs) => ValidateDraftWithRetry(eventArgs.FullPath);
        FileSystemWatcher? requestWatcher = null;
        if (options.ArmExplicitPublish)
        {
            requestWatcher = new FileSystemWatcher(outbox, "publish-request.json")
            {
                NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName | NotifyFilters.Size,
                EnableRaisingEvents = true,
            };
            requestWatcher.Changed += (_, eventArgs) => ProcessExplicitPublishRequest(options, eventArgs.FullPath);
            requestWatcher.Created += (_, eventArgs) => ProcessExplicitPublishRequest(options, eventArgs.FullPath);
        }
        Console.CancelKeyPress += (_, eventArgs) => { eventArgs.Cancel = true; Environment.Exit(0); };
        Thread.Sleep(Timeout.Infinite);
        requestWatcher?.Dispose();
        return 0;
    }

    private static void ProcessExplicitPublishRequest(Options watcherOptions, string requestPath)
    {
        string requestId = "unknown";
        try
        {
            Thread.Sleep(180);
            using JsonDocument requestDocument = ParseDocument(requestPath);
            JsonElement request = requestDocument.RootElement;
            RequireString(request, "kind", "bar-controller-ui-publish-request");
            if (!request.TryGetProperty("explicit", out JsonElement explicitElement) || explicitElement.ValueKind != JsonValueKind.True)
            {
                throw new InvalidDataException("Publish request is not explicitly approved.");
            }
            requestId = RequireString(request, "requestId");
            lock (RequestLock)
            {
                if (!ProcessedRequestIds.Add(requestId)) return;
            }
            string requestedVersion = RequireString(request, "requestedVersion");
            string repository = RequireString(request, "repository");
            string branch = RequireString(request, "branch");
            if (!string.Equals(repository, watcherOptions.Repository, StringComparison.Ordinal)
                || !string.Equals(branch, watcherOptions.Branch, StringComparison.Ordinal))
            {
                throw new InvalidDataException("Publish request target differs from the armed watcher target.");
            }
            string draftName = Path.GetFileName(RequireString(request, "draftFile"));
            string draftPath = Path.Combine(Path.GetDirectoryName(Path.GetFullPath(requestPath))!, draftName);
            using (JsonDocument draftDocument = ParseDocument(draftPath))
            {
                JsonElement draft = draftDocument.RootElement;
                if (!draft.TryGetProperty("draftMetadata", out JsonElement metadata)
                    || !string.Equals(RequireString(metadata, "authoringIntent"), "explicit", StringComparison.Ordinal))
                {
                    throw new InvalidDataException("Automatic/recovery drafts cannot be published.");
                }
            }
            string preparedDirectory = Path.Combine(Path.GetDirectoryName(draftPath)!, "prepared-" + requestId);
            var prepareOptions = new Options
            {
                DraftPath = draftPath,
                Version = requestedVersion,
                OutputDirectory = preparedDirectory,
                Branch = branch,
            };
            PrepareCommand(prepareOptions);
            var publishOptions = new Options
            {
                DefaultsPath = Path.Combine(preparedDirectory, DefaultsName),
                ManifestPath = Path.Combine(preparedDirectory, ManifestName),
                Repository = repository,
                Branch = branch,
                ConfirmPublish = true,
            };
            PublishCommand(publishOptions);
            WritePublishResult(requestPath, requestId, true, "Published " + requestedVersion + " at commit " + (LastPublishedCommit ?? "unknown") + ".");
        }
        catch (Exception exception)
        {
            lock (RequestLock) ProcessedRequestIds.Remove(requestId);
            WritePublishResult(requestPath, requestId, false, exception.Message);
            Console.Error.WriteLine("[publisher] Explicit request failed; request and draft retained: " + exception.Message);
        }
    }

    private static void WritePublishResult(string requestPath, string requestId, bool success, string message)
    {
        try
        {
            string resultPath = Path.Combine(Path.GetDirectoryName(Path.GetFullPath(requestPath))!, "publish-result.json");
            var result = new Dictionary<string, object>
            {
                ["kind"] = "bar-controller-ui-publish-result",
                ["requestId"] = requestId,
                ["success"] = success,
                ["message"] = message,
                ["completedAt"] = DateTimeOffset.UtcNow.ToString("O"),
            };
            WriteAtomic(resultPath, JsonSerializer.Serialize(result, JsonOptions) + Environment.NewLine);
        }
        catch { }
    }

    private static int PublishCommand(Options options)
    {
        if (!options.ConfirmPublish)
        {
            throw new InvalidOperationException("publish is disabled unless --confirm-publish is provided explicitly.");
        }
        ValidatedPair pair = ValidatePair(options.DefaultsPath, options.ManifestPath, allowDraft: false);
        Run("gh", new[] { "auth", "status" });
        string tempRoot = Path.Combine(Path.GetTempPath(), "bar-controller-ui-publish-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempRoot);
        try
        {
            Run("gh", new[] { "repo", "clone", options.Repository, tempRoot, "--", "--depth=1" });
            int checkout = RunAllowFailure("git", new[] { "-C", tempRoot, "checkout", options.Branch });
            if (checkout != 0)
            {
                Run("git", new[] { "-C", tempRoot, "checkout", "--orphan", options.Branch });
                RemoveWorkingFilesExceptGit(tempRoot);
            }
            CopyPair(pair, tempRoot);
            Run("git", new[] { "-C", tempRoot, "add", "--", DefaultsName, ManifestName });
            int diff = RunAllowFailure("git", new[] { "-C", tempRoot, "diff", "--cached", "--quiet" });
            if (diff == 0)
            {
                Console.WriteLine("[publisher] Remote defaults branch is already current.");
                return 0;
            }
            Run("git", new[] { "-C", tempRoot, "commit", "-m", $"controller-ui defaults {pair.Version}" });
            LastPublishedCommit = RunCapture("git", new[] { "-C", tempRoot, "rev-parse", "HEAD" });
            Run("git", new[] { "-C", tempRoot, "push", "origin", $"HEAD:refs/heads/{options.Branch}" });
            Console.WriteLine($"[publisher] Published defaults {pair.Version} at {LastPublishedCommit} to {options.Repository}:{options.Branch}.");
            return 0;
        }
        finally
        {
            if (Directory.Exists(tempRoot)) Directory.Delete(tempRoot, recursive: true);
        }
    }

    private static ValidatedPair ValidatePair(string defaultsPath, string manifestPath, bool allowDraft)
    {
        defaultsPath = Path.GetFullPath(defaultsPath);
        manifestPath = Path.GetFullPath(manifestPath);
        using JsonDocument defaultsDocument = ParseDocument(defaultsPath);
        using JsonDocument manifestDocument = ParseDocument(manifestPath);
        JsonElement defaults = defaultsDocument.RootElement;
        JsonElement manifest = manifestDocument.RootElement;
        RequireString(defaults, "kind", "bar-controller-ui-defaults");
        RequireString(manifest, "kind", "bar-controller-ui-defaults-manifest");
        RequireSchema(defaults);
        RequireSchema(manifest);
        if (!allowDraft && defaults.TryGetProperty("draft", out JsonElement draftElement) && draftElement.ValueKind == JsonValueKind.True)
        {
            throw new InvalidDataException("Draft defaults must be prepared before publishing.");
        }
        string version = RequireString(defaults, "defaultsVersion");
        if (!string.Equals(version, RequireString(manifest, "defaultsVersion"), StringComparison.Ordinal))
        {
            throw new InvalidDataException("Defaults and manifest versions do not match.");
        }
        RequireString(manifest, "defaultsFile", DefaultsName);
        ValidateDefaultsStructure(defaults);
        string actual = ComputeSha256(defaultsPath);
        string expected = RequireString(manifest, "sha256").ToLowerInvariant();
        if (!CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(actual), Encoding.ASCII.GetBytes(expected)))
        {
            throw new InvalidDataException($"Defaults SHA-256 mismatch; expected {expected}, got {actual}.");
        }
        return new ValidatedPair(defaultsPath, manifestPath, version, actual);
    }

    private static void ValidateDefaultsStructure(JsonElement defaults)
    {
        if (!defaults.TryGetProperty("settings", out JsonElement settingsElement) || settingsElement.ValueKind != JsonValueKind.Object
            || !defaults.TryGetProperty("enforcedSettings", out JsonElement enforcedElement) || enforcedElement.ValueKind != JsonValueKind.Object
            || !defaults.TryGetProperty("enforcedPaths", out JsonElement enforcedPathsElement) || enforcedPathsElement.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidDataException("Defaults document is missing settings/enforcement structures.");
        }
        ValidateSettings(settingsElement);
        ValidateHintProfile(defaults);
        ValidateComponentPresets(defaults);
        foreach (JsonElement pathElement in enforcedPathsElement.EnumerateArray())
        {
            string path = pathElement.ValueKind == JsonValueKind.String ? pathElement.GetString() ?? string.Empty : string.Empty;
            string scope = path.Split('.').FirstOrDefault() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(path) || (!KnownComponents.Contains(scope) && scope != "global" && scope != "theme" && scope != "authoring"))
            {
                throw new InvalidDataException("Unknown enforced path: " + path);
            }
            if (string.Equals(path, "authoring.developerAuthoring", StringComparison.Ordinal))
            {
                throw new InvalidDataException("Developer Authoring Mode cannot be remotely enforced.");
            }
        }
    }

    private static void ValidateSettings(JsonElement settings)
    {
        if (settings.TryGetProperty("authoring", out JsonElement authoring) && authoring.ValueKind == JsonValueKind.Object
            && authoring.TryGetProperty("developerAuthoring", out JsonElement developerMode) && developerMode.ValueKind == JsonValueKind.True)
        {
            throw new InvalidDataException("Remote defaults cannot enable Developer Authoring Mode.");
        }
        if (!settings.TryGetProperty("components", out JsonElement components) || components.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException("settings.components must be an object.");
        }
        foreach (JsonProperty component in components.EnumerateObject())
        {
            if (!KnownComponents.Contains(component.Name)) throw new InvalidDataException("Unknown component ID: " + component.Name);
            ValidateRanges(component.Value, "components." + component.Name);
        }
        ValidateRanges(settings, "settings");
    }

    private static void ValidateRanges(JsonElement element, string path)
    {
        if (element.ValueKind != JsonValueKind.Object) return;
        foreach (JsonProperty property in element.EnumerateObject())
        {
            string childPath = path + "." + property.Name;
            if (property.Value.ValueKind == JsonValueKind.Number && NumericRanges.TryGetValue(property.Name, out var range))
            {
                double value = property.Value.GetDouble();
                if (double.IsNaN(value) || double.IsInfinity(value) || value < range.Minimum || value > range.Maximum)
                {
                    throw new InvalidDataException($"Value outside range at {childPath}: {value}.");
                }
            }
            else if (property.Value.ValueKind == JsonValueKind.Object) ValidateRanges(property.Value, childPath);
        }
    }

    private static void ValidateHintProfile(JsonElement defaults)
    {
        if (!defaults.TryGetProperty("hintProfile", out JsonElement profile) || profile.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException("hintProfile must be an object.");
        }
        if (!profile.TryGetProperty("categories", out JsonElement categories) || categories.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidDataException("hintProfile.categories must be an array.");
        }
        var seenCategories = new HashSet<string>(StringComparer.Ordinal);
        foreach (JsonElement category in categories.EnumerateArray())
        {
            string id = RequireString(category, "id");
            if (!KnownCategories.Contains(id) || !seenCategories.Add(id)) throw new InvalidDataException("Unknown or duplicate category ID: " + id);
        }
        ValidateActionArray(profile, "actionOrdering", allowMissing: false);
        ValidateActionArray(profile, "hiddenActions", allowMissing: false);
        ValidateActionMap(profile, "defaultShortLabels", validateCategoryValues: false);
        ValidateActionMap(profile, "actionCategoryOverrides", validateCategoryValues: true);
    }

    private static void ValidateActionArray(JsonElement profile, string name, bool allowMissing)
    {
        if (!profile.TryGetProperty(name, out JsonElement values))
        {
            if (allowMissing) return;
            throw new InvalidDataException("hintProfile." + name + " must be an array.");
        }
        if (values.ValueKind != JsonValueKind.Array) throw new InvalidDataException("hintProfile." + name + " must be an array.");
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (JsonElement value in values.EnumerateArray())
        {
            string id = value.ValueKind == JsonValueKind.String ? value.GetString() ?? "" : "";
            if (!KnownActions.Contains(id) || !seen.Add(id)) throw new InvalidDataException($"Unknown or duplicate action ID in {name}: {id}");
        }
    }

    private static void ValidateActionMap(JsonElement profile, string name, bool validateCategoryValues)
    {
        if (!profile.TryGetProperty(name, out JsonElement values) || values.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException("hintProfile." + name + " must be an object.");
        }
        foreach (JsonProperty value in values.EnumerateObject())
        {
            if (!KnownActions.Contains(value.Name)) throw new InvalidDataException($"Unknown action ID in {name}: {value.Name}");
            if (validateCategoryValues && (value.Value.ValueKind != JsonValueKind.String || !KnownCategories.Contains(value.Value.GetString() ?? "")))
            {
                throw new InvalidDataException($"Unknown category in {name} for {value.Name}.");
            }
        }
    }

    private static void ValidateComponentPresets(JsonElement defaults)
    {
        if (!defaults.TryGetProperty("componentPresets", out JsonElement presets) || presets.ValueKind != JsonValueKind.Object)
        {
            throw new InvalidDataException("componentPresets must be an object.");
        }
        foreach (JsonProperty preset in presets.EnumerateObject())
        {
            string component = RequireString(preset.Value, "component");
            if (!KnownComponents.Contains(component)) throw new InvalidDataException("Unknown preset component ID: " + component);
            if (!preset.Value.TryGetProperty("settings", out JsonElement settings) || settings.ValueKind != JsonValueKind.Object)
            {
                throw new InvalidDataException("Preset settings must be an object: " + preset.Name);
            }
            ValidateRanges(settings, "componentPresets." + preset.Name);
        }
    }

    private static void RequireSchema(JsonElement document)
    {
        int schema = document.TryGetProperty("schemaVersion", out JsonElement value) && value.TryGetInt32(out int parsed) ? parsed : 0;
        if (schema < 1 || schema > 3) throw new InvalidDataException("Unsupported controller UI schema: " + schema);
    }

    private static string RequireString(JsonElement document, string name, string? expected = null)
    {
        string value = document.TryGetProperty(name, out JsonElement element) && element.ValueKind == JsonValueKind.String
            ? element.GetString() ?? throw new InvalidDataException("Missing string: " + name)
            : throw new InvalidDataException("Missing string: " + name);
        if (expected != null && !string.Equals(value, expected, StringComparison.Ordinal))
        {
            throw new InvalidDataException($"Unexpected {name}: {value}");
        }
        return value;
    }

    private static JsonDocument ParseDocument(string path)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("JSON file not found.", path);
        JsonDocument document = JsonDocument.Parse(File.ReadAllText(path));
        if (document.RootElement.ValueKind != JsonValueKind.Object)
        {
            document.Dispose();
            throw new InvalidDataException("JSON root must be an object: " + path);
        }
        return document;
    }

    private static string ComputeSha256(string path)
    {
        using SHA256 sha = SHA256.Create();
        byte[] digest = sha.ComputeHash(File.ReadAllBytes(path));
        return BitConverter.ToString(digest).Replace("-", string.Empty).ToLowerInvariant();
    }

    private static int ParseRevision(string version)
    {
        string suffix = version.Split('-').LastOrDefault() ?? "";
        return int.TryParse(suffix, out int revision) && revision > 0 ? revision : 1;
    }

    private static void CopyPair(ValidatedPair pair, string destination)
    {
        File.Copy(pair.DefaultsPath, Path.Combine(destination, DefaultsName), overwrite: true);
        File.Copy(pair.ManifestPath, Path.Combine(destination, ManifestName), overwrite: true);
    }

    private static void WriteAtomic(string path, string content)
    {
        string temporary = path + ".tmp-" + Guid.NewGuid().ToString("N");
        File.WriteAllText(temporary, content, new UTF8Encoding(false));
        File.Move(temporary, path, overwrite: true);
    }

    private static void ValidateDraftWithRetry(string path)
    {
        for (int attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                using JsonDocument draft = ParseDocument(path);
                RequireString(draft.RootElement, "kind", "bar-controller-ui-defaults");
                RequireSchema(draft.RootElement);
                ValidateDefaultsStructure(draft.RootElement);
                Console.WriteLine($"[publisher] Validated local draft at {DateTimeOffset.Now:T}; explicit prepare/publish still required.");
                return;
            }
            catch (IOException) { Thread.Sleep(80); }
            catch (JsonException) { Thread.Sleep(80); }
            catch (Exception exception) { Console.Error.WriteLine("[publisher] Draft invalid: " + exception.Message); return; }
        }
    }

    private static int RunAllowFailure(string fileName, IEnumerable<string> arguments)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo(fileName) { UseShellExecute = false },
        };
        foreach (string argument in arguments) process.StartInfo.ArgumentList.Add(argument);
        process.Start();
        process.WaitForExit();
        return process.ExitCode;
    }

    private static void Run(string fileName, IEnumerable<string> arguments)
    {
        int exitCode = RunAllowFailure(fileName, arguments);
        if (exitCode != 0) throw new InvalidOperationException($"{fileName} exited with code {exitCode}.");
    }

    private static string RunCapture(string fileName, IEnumerable<string> arguments)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo(fileName) { UseShellExecute = false, RedirectStandardOutput = true },
        };
        foreach (string argument in arguments) process.StartInfo.ArgumentList.Add(argument);
        process.Start();
        string output = process.StandardOutput.ReadToEnd();
        process.WaitForExit();
        if (process.ExitCode != 0) throw new InvalidOperationException($"{fileName} exited with code {process.ExitCode}.");
        return output.Trim();
    }

    private static void RemoveWorkingFilesExceptGit(string root)
    {
        foreach (string file in Directory.EnumerateFiles(root)) File.Delete(file);
        foreach (string directory in Directory.EnumerateDirectories(root))
        {
            if (!string.Equals(Path.GetFileName(directory), ".git", StringComparison.OrdinalIgnoreCase)) Directory.Delete(directory, recursive: true);
        }
    }

    private static bool IsHelp(string value) => value is "help" or "--help" or "-h";

    private static void PrintHelp()
    {
        Console.WriteLine("BAR Controller UI defaults publisher (developer-only)");
        Console.WriteLine("  validate [--defaults path] [--manifest path]");
        Console.WriteLine("  prepare --draft path --version X --output directory");
        Console.WriteLine("  dry-run --local-repository disposable-path");
        Console.WriteLine("  watch [--outbox directory] [--arm-explicit-publish]  # publish requests require explicit arming");
        Console.WriteLine("  publish --confirm-publish [--repository owner/name] [--branch name]");
        Console.WriteLine("No token is accepted. Live publish uses the existing gh authenticated session.");
    }

    private sealed record ValidatedPair(string DefaultsPath, string ManifestPath, string Version, string Sha256);

    private sealed class Options
    {
        public string DefaultsPath { get; set; } = Path.Combine("controller-ui", DefaultsName);
        public string ManifestPath { get; set; } = Path.Combine("controller-ui", ManifestName);
        public string? DraftPath { get; set; }
        public string OutputDirectory { get; set; } = Path.Combine("controller-ui", "outbox");
        public string OutboxDirectory { get; set; } = Path.Combine("LuaUI", "Config", "BARControllerSupport", "outbox");
        public string Repository { get; set; } = DefaultRepository;
        public string Branch { get; set; } = DefaultBranch;
        public string? LocalRepository { get; set; }
        public string? Version { get; set; }
        public string? MinimumCompanionVersion { get; set; }
        public string? Channel { get; set; }
        public bool ConfirmPublish { get; set; }
        public bool AllowDraft { get; set; }
        public bool ArmExplicitPublish { get; set; }

        public static Options Parse(string[] args)
        {
            var result = new Options();
            for (int index = 0; index < args.Length; index++)
            {
                string argument = args[index];
                string Next() => index + 1 < args.Length ? args[++index] : throw new ArgumentException("Missing value after " + argument);
                switch (argument)
                {
                    case "--defaults": result.DefaultsPath = Next(); break;
                    case "--manifest": result.ManifestPath = Next(); break;
                    case "--draft": result.DraftPath = Next(); break;
                    case "--output": result.OutputDirectory = Next(); break;
                    case "--outbox": result.OutboxDirectory = Next(); break;
                    case "--repository": result.Repository = Next(); break;
                    case "--branch": result.Branch = Next(); break;
                    case "--local-repository": result.LocalRepository = Next(); break;
                    case "--version": result.Version = Next(); break;
                    case "--minimum-companion-version": result.MinimumCompanionVersion = Next(); break;
                    case "--channel": result.Channel = Next(); break;
                    case "--confirm-publish": result.ConfirmPublish = true; break;
                    case "--allow-draft": result.AllowDraft = true; break;
                    case "--arm-explicit-publish": result.ArmExplicitPublish = true; break;
                    default: throw new ArgumentException("Unknown option: " + argument);
                }
            }
            return result;
        }
    }
}
