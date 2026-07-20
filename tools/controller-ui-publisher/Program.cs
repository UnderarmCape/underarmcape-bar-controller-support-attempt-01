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
            ["defaultsVersion"] = version,
            ["defaultsFile"] = DefaultsName,
            ["sha256"] = sha,
            ["generatedAt"] = DateTimeOffset.UtcNow.ToString("O"),
            ["minimumCompanionVersion"] = options.MinimumCompanionVersion ?? "0.6.0",
            ["sourceBranch"] = options.Branch,
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
        Console.WriteLine("[publisher] Watch mode validates drafts only. It never publishes.");
        string draftName = Path.GetFileName(options.DraftPath ?? "shipping-defaults.draft.json");
        using var watcher = new FileSystemWatcher(outbox, draftName)
        {
            NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName | NotifyFilters.Size,
            EnableRaisingEvents = true,
        };
        watcher.Changed += (_, eventArgs) => ValidateDraftWithRetry(eventArgs.FullPath);
        watcher.Created += (_, eventArgs) => ValidateDraftWithRetry(eventArgs.FullPath);
        Console.CancelKeyPress += (_, eventArgs) => { eventArgs.Cancel = true; Environment.Exit(0); };
        Thread.Sleep(Timeout.Infinite);
        return 0;
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
            Run("git", new[] { "-C", tempRoot, "push", "origin", $"HEAD:refs/heads/{options.Branch}" });
            Console.WriteLine($"[publisher] Published defaults {pair.Version} to {options.Repository}:{options.Branch}.");
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
        if (!defaults.TryGetProperty("settings", out JsonElement settingsElement) || settingsElement.ValueKind != JsonValueKind.Object
            || !defaults.TryGetProperty("enforcedSettings", out JsonElement enforcedElement) || enforcedElement.ValueKind != JsonValueKind.Object
            || !defaults.TryGetProperty("enforcedPaths", out JsonElement enforcedPathsElement) || enforcedPathsElement.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidDataException("Defaults document is missing settings/enforcement structures.");
        }
        string actual = ComputeSha256(defaultsPath);
        string expected = RequireString(manifest, "sha256").ToLowerInvariant();
        if (!CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(actual), Encoding.ASCII.GetBytes(expected)))
        {
            throw new InvalidDataException($"Defaults SHA-256 mismatch; expected {expected}, got {actual}.");
        }
        return new ValidatedPair(defaultsPath, manifestPath, version, actual);
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
        Console.WriteLine("  watch [--outbox directory]  # validation only; never publishes");
        Console.WriteLine("  publish --confirm-publish [--repository owner/name] [--branch name]");
        Console.WriteLine("No token is accepted. Live publish uses the existing gh authenticated session.");
    }

    private sealed record ValidatedPair(string DefaultsPath, string ManifestPath, string Version, string Sha256);

    private sealed class Options
    {
        public string DefaultsPath { get; private set; } = Path.Combine("controller-ui", DefaultsName);
        public string ManifestPath { get; private set; } = Path.Combine("controller-ui", ManifestName);
        public string? DraftPath { get; private set; }
        public string OutputDirectory { get; private set; } = Path.Combine("controller-ui", "outbox");
        public string OutboxDirectory { get; private set; } = Path.Combine("LuaUI", "Config", "BARControllerSupport", "outbox");
        public string Repository { get; private set; } = DefaultRepository;
        public string Branch { get; private set; } = DefaultBranch;
        public string? LocalRepository { get; private set; }
        public string? Version { get; private set; }
        public string? MinimumCompanionVersion { get; private set; }
        public string? Channel { get; private set; }
        public bool ConfirmPublish { get; private set; }
        public bool AllowDraft { get; private set; }

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
                    default: throw new ArgumentException("Unknown option: " + argument);
                }
            }
            return result;
        }
    }
}
