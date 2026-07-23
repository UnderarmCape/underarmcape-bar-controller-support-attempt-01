using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

internal static class ControllerReleaseSecurity
{
    public const int SupportedSchemaVersion = 1;
    public const string OfficialRepository = "UnderarmCape/underarmcape-bar-controller-support-attempt-01";
    public const string InstalledStateFileName = "installed-release.json";
    public const long MaximumExtractedBytes = 2L * 1024 * 1024 * 1024;
    public const int MaximumArchiveEntries = 10000;
    private static readonly HashSet<string> AllowedDestinationRoots = new HashSet<string>(
        new[] { "bar-data", "companion" },
        StringComparer.OrdinalIgnoreCase);

    public static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    public static ControllerReleaseManifest ReadManifest(
        string manifestPath,
        string? packageRoot = null,
        bool requireDetachedPackageIdentity = false)
    {
        if (!File.Exists(manifestPath))
        {
            throw new FileNotFoundException("Controller release manifest is missing.", manifestPath);
        }

        ControllerReleaseManifest manifest;
        try
        {
            manifest = JsonSerializer.Deserialize<ControllerReleaseManifest>(
                File.ReadAllText(manifestPath),
                JsonOptions) ?? throw new InvalidDataException("Controller release manifest is empty.");
        }
        catch (JsonException exception)
        {
            throw new InvalidDataException("Controller release manifest is malformed: " + exception.Message, exception);
        }

        ValidateManifest(manifest, packageRoot, requireDetachedPackageIdentity);
        return manifest;
    }

    public static void ValidateManifest(
        ControllerReleaseManifest manifest,
        string? packageRoot = null,
        bool requireDetachedPackageIdentity = false)
    {
        if (!string.Equals(manifest.Kind, "bar-controller-release-manifest", StringComparison.Ordinal)
            || manifest.SchemaVersion != SupportedSchemaVersion)
        {
            throw new InvalidDataException("Unsupported controller release manifest schema.");
        }
        if (string.IsNullOrWhiteSpace(manifest.ReleaseTag)
            || !Version.TryParse(NormalizeVersion(manifest.SemanticVersion), out _)
            || string.IsNullOrWhiteSpace(manifest.DisplayVersion)
            || manifest.ReleaseSequence <= 0
            || !IsSha1(manifest.CommitSha)
            || !string.Equals(manifest.Repository, OfficialRepository, StringComparison.OrdinalIgnoreCase)
            || string.IsNullOrWhiteSpace(manifest.Package.AssetName)
            || !string.Equals(manifest.Package.Format, "zip", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Controller release identity is incomplete or invalid.");
        }
        if (requireDetachedPackageIdentity && manifest.Package.DetachedIdentity)
        {
            throw new InvalidDataException("A detached release sidecar with an outer package digest is required.");
        }
        if (manifest.Package.DetachedIdentity)
        {
            if (!string.Equals(manifest.Package.Sha256, new string('0', 64), StringComparison.Ordinal)
                || manifest.Package.ByteLength != 0)
            {
                throw new InvalidDataException("Embedded manifests must use the explicit detached package identity sentinel.");
            }
        }
        else if (!IsSha256(manifest.Package.Sha256) || manifest.Package.ByteLength <= 0)
        {
            throw new InvalidDataException("Controller release package identity is invalid.");
        }
        if (!string.IsNullOrWhiteSpace(manifest.MinimumUpdaterVersion)
            && !Version.TryParse(NormalizeVersion(manifest.MinimumUpdaterVersion), out _))
        {
            throw new InvalidDataException("Minimum updater version is invalid.");
        }

        manifest.Components ??= new List<ControllerPayloadComponent>();
        manifest.ConfigurationPreservation ??= new List<ControllerPreservationRule>();
        if (manifest.Components.Count == 0)
        {
            throw new InvalidDataException("Controller release manifest has no payload components.");
        }

        var componentIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var destinations = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (ControllerPayloadComponent component in manifest.Components)
        {
            ValidateComponent(component, packageRoot);
            if (!componentIds.Add(component.ComponentId))
            {
                throw new InvalidDataException("Duplicate component ID: " + component.ComponentId);
            }
            string destinationKey = component.DestinationRoot + "/" + NormalizeRelativePath(component.DestinationPath);
            if (!destinations.Add(destinationKey))
            {
                throw new InvalidDataException("Duplicate component destination: " + destinationKey);
            }
        }

        var preservationIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (ControllerPreservationRule rule in manifest.ConfigurationPreservation)
        {
            if (string.IsNullOrWhiteSpace(rule.RuleId) || !preservationIds.Add(rule.RuleId)
                || !AllowedDestinationRoots.Contains(rule.DestinationRoot))
            {
                throw new InvalidDataException("Invalid or duplicate configuration-preservation rule.");
            }
            ValidateRelativePath(rule.RelativePath, "preservation path");
            if (!string.Equals(rule.Behavior, "preserve", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(rule.Behavior, "backup", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("Unsupported preservation behavior: " + rule.Behavior);
            }
        }
        foreach (ControllerPayloadComponent component in manifest.Components)
        {
            string componentPath = NormalizeRelativePath(component.DestinationPath);
            foreach (ControllerPreservationRule rule in manifest.ConfigurationPreservation.Where(item =>
                item.Behavior.Equals("preserve", StringComparison.OrdinalIgnoreCase)
                && item.DestinationRoot.Equals(component.DestinationRoot, StringComparison.OrdinalIgnoreCase)))
            {
                string preservedPath = NormalizeRelativePath(rule.RelativePath);
                if (componentPath.Equals(preservedPath, StringComparison.OrdinalIgnoreCase)
                    || (rule.Recursive && componentPath.StartsWith(preservedPath + "/", StringComparison.OrdinalIgnoreCase)))
                {
                    throw new InvalidDataException(
                        "Package-owned component overlaps preserved configuration: " + component.ComponentId);
                }
            }
        }
    }

    public static void ValidatePackageIdentity(
        string packagePath,
        ControllerReleaseManifest manifest)
    {
        if (manifest.Package.DetachedIdentity)
        {
            throw new InvalidDataException("Outer package validation requires the detached release manifest.");
        }
        FileInfo package = new FileInfo(packagePath);
        if (!package.Exists || package.Length != manifest.Package.ByteLength)
        {
            throw new InvalidDataException("Release package size does not match the manifest.");
        }
        string actual = ComputeSha256(packagePath);
        if (!FixedHashEquals(actual, manifest.Package.Sha256))
        {
            throw new InvalidDataException(
                "Release package SHA-256 mismatch; expected " + manifest.Package.Sha256 + ", got " + actual + ".");
        }
    }

    public static void ValidateComponent(ControllerPayloadComponent component, string? packageRoot)
    {
        if (string.IsNullOrWhiteSpace(component.ComponentId)
            || string.IsNullOrWhiteSpace(component.ComponentType)
            || !AllowedDestinationRoots.Contains(component.DestinationRoot))
        {
            throw new InvalidDataException("Payload component identity or destination root is invalid.");
        }
        ValidateRelativePath(component.DestinationPath, "component destination");
        bool remove = string.Equals(component.InstallPolicy, "remove", StringComparison.OrdinalIgnoreCase);
        bool replace = string.Equals(component.InstallPolicy, "replace", StringComparison.OrdinalIgnoreCase);
        if (!remove && !replace)
        {
            throw new InvalidDataException("Unsupported install policy: " + component.InstallPolicy);
        }
        if (remove)
        {
            if (!string.IsNullOrEmpty(component.SourcePath)
                || !string.IsNullOrEmpty(component.Sha256)
                || component.ByteLength != 0)
            {
                throw new InvalidDataException("Remove components cannot carry a payload.");
            }
        }
        else
        {
            ValidateRelativePath(component.SourcePath, "component source");
            if (!IsSha256(component.Sha256) || component.ByteLength < 0)
            {
                throw new InvalidDataException("Payload component hash or length is invalid: " + component.ComponentId);
            }
            if (packageRoot != null)
            {
                string source = ResolveInside(packageRoot, component.SourcePath);
                if (!File.Exists(source))
                {
                    if (!component.Optional)
                    {
                        throw new FileNotFoundException("Payload component is missing: " + component.SourcePath, source);
                    }
                }
                else
                {
                    FileInfo info = new FileInfo(source);
                    string hash = ComputeSha256(source);
                    if (info.Length != component.ByteLength || !FixedHashEquals(hash, component.Sha256))
                    {
                        throw new InvalidDataException("Payload component failed length/SHA-256 validation: " + component.ComponentId);
                    }
                }
            }
        }
        if (!string.Equals(component.Platform, "windows", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(component.Platform, "any", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Unsupported component platform: " + component.Platform);
        }
        if (!string.Equals(component.Architecture, "x64", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(component.Architecture, "any", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Unsupported component architecture: " + component.Architecture);
        }
    }

    public static string SafeExtractZip(string packagePath, string extractionRoot)
    {
        if (Directory.Exists(extractionRoot) || File.Exists(extractionRoot))
        {
            throw new IOException("Extraction destination must be a new, isolated path: " + extractionRoot);
        }
        Directory.CreateDirectory(extractionRoot);
        string root = Path.GetFullPath(extractionRoot).TrimEnd(Path.DirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        long extractedBytes = 0;
        int entryCount = 0;
        try
        {
            using ZipArchive archive = ZipFile.OpenRead(packagePath);
            foreach (ZipArchiveEntry entry in archive.Entries)
            {
                entryCount++;
                if (entryCount > MaximumArchiveEntries)
                {
                    throw new InvalidDataException("Archive contains too many entries.");
                }
                string rawName = entry.FullName.Replace('\\', '/');
                if (rawName.Length == 0 || rawName.StartsWith("/", StringComparison.Ordinal)
                    || Regex.IsMatch(rawName, @"^[A-Za-z]:")
                    || rawName.Split('/').Any(part => part == ".."))
                {
                    throw new InvalidDataException("Unsafe archive entry: " + entry.FullName);
                }
                string destination = Path.GetFullPath(Path.Combine(extractionRoot, rawName.Replace('/', Path.DirectorySeparatorChar)));
                if (!destination.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidDataException("Archive entry escapes staging: " + entry.FullName);
                }
                bool directory = rawName.EndsWith("/", StringComparison.Ordinal);
                if (directory)
                {
                    Directory.CreateDirectory(destination);
                    continue;
                }
                extractedBytes += entry.Length;
                if (extractedBytes > MaximumExtractedBytes)
                {
                    throw new InvalidDataException("Archive exceeds the extraction size limit.");
                }
                Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                using Stream input = entry.Open();
                using FileStream output = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None);
                input.CopyTo(output);
            }
        }
        catch
        {
            TryDeleteDirectory(extractionRoot);
            throw;
        }
        return extractionRoot;
    }

    public static string ResolveDestination(
        string destinationRoot,
        string relativePath,
        string barDataRoot,
        string companionRoot)
    {
        string root = destinationRoot.Equals("bar-data", StringComparison.OrdinalIgnoreCase)
            ? barDataRoot
            : destinationRoot.Equals("companion", StringComparison.OrdinalIgnoreCase)
                ? companionRoot
                : throw new InvalidDataException("Unsafe destination root: " + destinationRoot);
        return ResolveInside(root, relativePath);
    }

    public static string ResolveInside(string root, string relativePath)
    {
        ValidateRelativePath(relativePath, "relative path");
        string fullRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        string candidate = Path.GetFullPath(Path.Combine(root, relativePath.Replace('/', Path.DirectorySeparatorChar)));
        if (!candidate.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Path escapes its trusted root: " + relativePath);
        }
        return candidate;
    }

    public static string ComputeSha256(string path)
    {
        using SHA256 sha = SHA256.Create();
        using FileStream input = File.OpenRead(path);
        return BitConverter.ToString(sha.ComputeHash(input)).Replace("-", string.Empty).ToLowerInvariant();
    }

    public static string ComputeSha256(byte[] value)
    {
        using SHA256 sha = SHA256.Create();
        return BitConverter.ToString(sha.ComputeHash(value)).Replace("-", string.Empty).ToLowerInvariant();
    }

    public static bool FixedHashEquals(string actual, string expected)
    {
        if (!IsSha256(actual) || !IsSha256(expected)) return false;
        return CryptographicOperations.FixedTimeEquals(
            Encoding.ASCII.GetBytes(actual.ToLowerInvariant()),
            Encoding.ASCII.GetBytes(expected.ToLowerInvariant()));
    }

    public static void WriteJsonAtomic<T>(string path, T value)
    {
        WriteBytesAtomic(path, Encoding.UTF8.GetBytes(JsonSerializer.Serialize(value, JsonOptions)));
    }

    public static void WriteBytesAtomic(string path, byte[] value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path) ?? ".");
        string temporary = path + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            File.WriteAllBytes(temporary, value);
            File.Move(temporary, path, true);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    public static InstalledControllerReleaseState? ReadInstalledState(string companionRoot)
    {
        string path = Path.Combine(companionRoot, InstalledStateFileName);
        if (!File.Exists(path)) return null;
        try
        {
            InstalledControllerReleaseState? state = JsonSerializer.Deserialize<InstalledControllerReleaseState>(
                File.ReadAllText(path), JsonOptions);
            if (state == null || state.Kind != "bar-controller-installed-release" || state.SchemaVersion != 1
                || string.IsNullOrWhiteSpace(state.ReleaseTag) || !IsSha256(state.ManifestSha256))
            {
                return null;
            }
            state.Components ??= new List<InstalledControllerComponent>();
            return state;
        }
        catch
        {
            return null;
        }
    }

    public static LegacyControllerRelease? DetectLegacyInstall(
        string companionRoot,
        LegacyControllerReleaseCatalog catalog)
    {
        string legacyStatePath = Path.Combine(companionRoot, "install-state.json");
        if (!File.Exists(legacyStatePath)) return null;
        try
        {
            using JsonDocument document = JsonDocument.Parse(File.ReadAllText(legacyStatePath));
            string version = document.RootElement.TryGetProperty("Version", out JsonElement value)
                ? value.GetString() ?? string.Empty : string.Empty;
            return catalog.Releases.FirstOrDefault(release =>
                release.Available && Version.TryParse(NormalizeVersion(release.Version), out Version? releaseVersion)
                && Version.TryParse(NormalizeVersion(version), out Version? detected)
                && releaseVersion == detected);
        }
        catch
        {
            return null;
        }
    }

    public static bool IsBarRunning()
    {
        foreach (Process process in Process.GetProcesses())
        {
            try
            {
                string name = process.ProcessName;
                if (!process.HasExited && IsBarProcessName(name))
                {
                    return true;
                }
            }
            catch { }
            finally { process.Dispose(); }
        }
        return false;
    }

    public static bool IsBarProcessName(string name)
        => name.Equals("spring", StringComparison.OrdinalIgnoreCase)
            || name.Equals("spring-headless", StringComparison.OrdinalIgnoreCase)
            || name.Equals("recoil", StringComparison.OrdinalIgnoreCase)
            || name.Equals("Beyond-All-Reason", StringComparison.OrdinalIgnoreCase)
            || name.Equals("BAR", StringComparison.OrdinalIgnoreCase);

    public static string NormalizeVersion(string? value)
    {
        Match match = Regex.Match(value ?? string.Empty, @"(?<version>\d+\.\d+\.\d+)");
        return match.Success ? match.Groups["version"].Value : "0.0.0";
    }

    public static int CompareReleaseIdentity(ControllerReleaseCatalogItem first, ControllerReleaseCatalogItem second)
    {
        int sequence = first.ReleaseSequence.CompareTo(second.ReleaseSequence);
        if (sequence != 0) return sequence;
        int published = first.PublishedAtUtc.CompareTo(second.PublishedAtUtc);
        if (published != 0) return published;
        int tag = string.Compare(first.Tag, second.Tag, StringComparison.Ordinal);
        if (tag != 0) return tag;
        return string.Compare(first.CommitSha, second.CommitSha, StringComparison.Ordinal);
    }

    public static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, true);
        }
        catch { }
    }

    private static void ValidateRelativePath(string path, string label)
    {
        if (string.IsNullOrWhiteSpace(path) || Path.IsPathRooted(path)
            || Regex.IsMatch(path, @"^[A-Za-z]:")
            || path.IndexOf('\0') >= 0
            || path.Replace('\\', '/').Split('/').Any(part => part == ".." || part.Length == 0))
        {
            throw new InvalidDataException("Unsafe " + label + ": " + path);
        }
    }

    private static string NormalizeRelativePath(string path) => path.Replace('\\', '/').Trim('/');
    private static bool IsSha256(string value) => Regex.IsMatch(value ?? string.Empty, "^[a-fA-F0-9]{64}$");
    private static bool IsSha1(string value) => Regex.IsMatch(value ?? string.Empty, "^[a-fA-F0-9]{40}$");
}
