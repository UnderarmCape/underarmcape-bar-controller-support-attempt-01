using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

internal sealed class ControllerGitHubAsset
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    [JsonPropertyName("browser_download_url")]
    public string DownloadUrl { get; set; } = string.Empty;
    [JsonPropertyName("size")]
    public long Size { get; set; }
    [JsonPropertyName("digest")]
    public string Digest { get; set; } = string.Empty;
}

internal sealed class ControllerGitHubRelease
{
    [JsonPropertyName("tag_name")]
    public string TagName { get; set; } = string.Empty;
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
    [JsonPropertyName("published_at")]
    public DateTimeOffset PublishedAt { get; set; }
    [JsonPropertyName("prerelease")]
    public bool Prerelease { get; set; }
    [JsonPropertyName("draft")]
    public bool Draft { get; set; }
    [JsonPropertyName("html_url")]
    public string HtmlUrl { get; set; } = string.Empty;
    [JsonPropertyName("target_commitish")]
    public string TargetCommitish { get; set; } = string.Empty;
    [JsonPropertyName("body")]
    public string Body { get; set; } = string.Empty;
    [JsonPropertyName("assets")]
    public List<ControllerGitHubAsset> Assets { get; set; } = new List<ControllerGitHubAsset>();
}

internal class ControllerGitHubCacheMetadata
{
    public string ETag { get; set; } = string.Empty;
    public DateTimeOffset StoredAtUtc { get; set; }
}

internal sealed class ControllerGitHubReleaseClient : IDisposable
{
    private const int MaximumMetadataBytes = 4 * 1024 * 1024;
    private readonly HttpClient client;
    private readonly bool ownsClient;
    private readonly string cacheRoot;
    private readonly string apiRoot;

    public ControllerGitHubReleaseClient(
        string cacheRoot,
        HttpClient? client = null,
        string? apiRoot = null)
    {
        this.cacheRoot = Path.GetFullPath(cacheRoot);
        this.apiRoot = (apiRoot
            ?? Environment.GetEnvironmentVariable("BAR_CONTROLLER_RELEASE_API_ROOT")
            ?? "https://api.github.com/repos/" + ControllerReleaseSecurity.OfficialRepository).TrimEnd('/');
        if (!Uri.TryCreate(this.apiRoot, UriKind.Absolute, out Uri? apiUri)
            || apiUri.Scheme != Uri.UriSchemeHttps)
        {
            throw new InvalidDataException("GitHub release API must use HTTPS.");
        }
        this.client = client ?? new HttpClient { Timeout = TimeSpan.FromSeconds(20) };
        ownsClient = client == null;
        if (!this.client.DefaultRequestHeaders.UserAgent.Any())
        {
            this.client.DefaultRequestHeaders.UserAgent.ParseAdd("BARControllerCompanion/" + ProductMetadata.SemanticVersion);
        }
        if (!this.client.DefaultRequestHeaders.Accept.Any())
        {
            this.client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
        }
        this.client.DefaultRequestHeaders.TryAddWithoutValidation("X-GitHub-Api-Version", "2022-11-28");
    }

    public async Task<ControllerGitHubRelease> GetLatestAsync()
    {
        byte[] content = await GetCachedPageAsync(apiRoot + "/releases/latest").ConfigureAwait(false);
        return Deserialize<ControllerGitHubRelease>(content, "latest GitHub release");
    }

    public async Task<List<ControllerGitHubRelease>> GetAllAsync()
    {
        var releases = new List<ControllerGitHubRelease>();
        string? url = apiRoot + "/releases?per_page=100&page=1";
        int pages = 0;
        while (url != null)
        {
            pages++;
            if (pages > 20) throw new InvalidDataException("GitHub release pagination exceeded the safety limit.");
            CachedHttpPage page = await GetCachedPageWithHeadersAsync(url).ConfigureAwait(false);
            releases.AddRange(Deserialize<List<ControllerGitHubRelease>>(page.Content, "GitHub release page"));
            url = GetNextLink(page.LinkHeader);
        }
        return releases.Where(release => !release.Draft).ToList();
    }

    public async Task<byte[]> DownloadSmallAssetAsync(ControllerGitHubAsset asset, int maximumBytes = MaximumMetadataBytes)
    {
        EnsureTrustedAsset(asset);
        using HttpResponseMessage response = await client.GetAsync(
            asset.DownloadUrl, HttpCompletionOption.ResponseHeadersRead).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength > maximumBytes)
        {
            throw new InvalidDataException("Release metadata asset exceeds its size limit: " + asset.Name);
        }
        byte[] content = await response.Content.ReadAsByteArrayAsync().ConfigureAwait(false);
        if (content.Length > maximumBytes || (asset.Size > 0 && content.LongLength != asset.Size))
        {
            throw new InvalidDataException("Release metadata asset is incomplete or oversized: " + asset.Name);
        }
        ValidateGitHubDigest(asset, content);
        return content;
    }

    public async Task<string> DownloadPackageAsync(
        ControllerGitHubAsset asset,
        string destination,
        ControllerReleaseManifest manifest)
    {
        EnsureTrustedAsset(asset);
        if (!string.Equals(asset.Name, manifest.Package.AssetName, StringComparison.Ordinal)
            || (asset.Size > 0 && asset.Size != manifest.Package.ByteLength))
        {
            throw new InvalidDataException("GitHub package asset does not match the release manifest.");
        }
        string githubDigest = ParseDigest(asset.Digest);
        if (githubDigest.Length > 0 && !ControllerReleaseSecurity.FixedHashEquals(githubDigest, manifest.Package.Sha256))
        {
            throw new InvalidDataException("GitHub asset digest conflicts with the release manifest.");
        }
        EnsureFreeSpace(destination, manifest.Package.ByteLength);
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        string temporary = destination + ".part-" + Guid.NewGuid().ToString("N");
        try
        {
            using HttpResponseMessage response = await client.GetAsync(
                asset.DownloadUrl, HttpCompletionOption.ResponseHeadersRead).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
            long? contentLength = response.Content.Headers.ContentLength;
            if (contentLength.HasValue && contentLength.Value != manifest.Package.ByteLength)
            {
                throw new InvalidDataException("Release package Content-Length does not match the manifest.");
            }
            long total = 0;
            using (Stream input = await response.Content.ReadAsStreamAsync().ConfigureAwait(false))
            using (FileStream output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                var buffer = new byte[81920];
                while (true)
                {
                    int read = await input.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false);
                    if (read == 0) break;
                    total += read;
                    if (total > manifest.Package.ByteLength)
                    {
                        throw new InvalidDataException("Release package exceeded its declared length.");
                    }
                    await output.WriteAsync(buffer, 0, read).ConfigureAwait(false);
                }
            }
            if (total != manifest.Package.ByteLength)
            {
                throw new InvalidDataException("Partial release package download was rejected.");
            }
            if (!ControllerReleaseSecurity.FixedHashEquals(
                ControllerReleaseSecurity.ComputeSha256(temporary), manifest.Package.Sha256))
            {
                throw new InvalidDataException("Downloaded release package SHA-256 mismatch.");
            }
            File.Move(temporary, destination, true);
            return destination;
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    public async Task<ControllerReleaseManifest?> TryGetManifestAsync(ControllerGitHubRelease release)
    {
        ControllerGitHubAsset? manifestAsset = release.Assets.FirstOrDefault(asset =>
            asset.Name.Equals("controller-release-manifest.json", StringComparison.OrdinalIgnoreCase));
        if (manifestAsset == null) return null;
        ControllerGitHubAsset? hashAsset = release.Assets.FirstOrDefault(asset =>
            asset.Name.Equals("controller-release-manifest.json.sha256", StringComparison.OrdinalIgnoreCase));
        if (hashAsset == null)
        {
            throw new InvalidDataException("Release manifest has no SHA-256 sidecar: " + release.TagName);
        }
        byte[] manifestBytes = await DownloadSmallAssetAsync(manifestAsset).ConfigureAwait(false);
        byte[] hashBytes = await DownloadSmallAssetAsync(hashAsset, 65536).ConfigureAwait(false);
        string expected = Regex.Match(Encoding.UTF8.GetString(hashBytes), @"\b[a-fA-F0-9]{64}\b").Value.ToLowerInvariant();
        string actual = ControllerReleaseSecurity.ComputeSha256(manifestBytes);
        if (!ControllerReleaseSecurity.FixedHashEquals(actual, expected))
        {
            throw new InvalidDataException("Release manifest SHA-256 sidecar mismatch: " + release.TagName);
        }
        ControllerReleaseManifest manifest = JsonSerializer.Deserialize<ControllerReleaseManifest>(
            manifestBytes, ControllerReleaseSecurity.JsonOptions)
            ?? throw new InvalidDataException("Release manifest is empty: " + release.TagName);
        ControllerReleaseSecurity.ValidateManifest(manifest, requireDetachedPackageIdentity: true);
        if (!manifest.ReleaseTag.Equals(release.TagName, StringComparison.Ordinal))
        {
            throw new InvalidDataException("Release manifest tag does not match GitHub: " + release.TagName);
        }
        ControllerGitHubAsset? package = release.Assets.FirstOrDefault(asset =>
            asset.Name.Equals(manifest.Package.AssetName, StringComparison.Ordinal));
        if (package == null || package.Size != manifest.Package.ByteLength)
        {
            throw new InvalidDataException("Release package asset is unavailable or has the wrong length: " + release.TagName);
        }
        string digest = ParseDigest(package.Digest);
        if (digest.Length > 0 && !ControllerReleaseSecurity.FixedHashEquals(digest, manifest.Package.Sha256))
        {
            throw new InvalidDataException("Release package digest conflicts with its manifest: " + release.TagName);
        }
        EnsureTrustedAsset(package);
        return manifest;
    }

    public void Dispose()
    {
        if (ownsClient) client.Dispose();
    }

    private async Task<byte[]> GetCachedPageAsync(string url)
    {
        return (await GetCachedPageWithHeadersAsync(url).ConfigureAwait(false)).Content;
    }

    private async Task<CachedHttpPage> GetCachedPageWithHeadersAsync(string url)
    {
        Directory.CreateDirectory(cacheRoot);
        string key = ComputeCacheKey(url);
        string dataPath = Path.Combine(cacheRoot, key + ".json");
        string metadataPath = Path.Combine(cacheRoot, key + ".metadata.json");
        ControllerGitHubCacheMetadata metadata = ReadCacheMetadata(metadataPath);
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        if (!string.IsNullOrWhiteSpace(metadata.ETag))
        {
            request.Headers.TryAddWithoutValidation("If-None-Match", metadata.ETag);
        }
        try
        {
            using HttpResponseMessage response = await client.SendAsync(
                request, HttpCompletionOption.ResponseHeadersRead).ConfigureAwait(false);
            if (response.StatusCode == HttpStatusCode.NotModified)
            {
                if (!File.Exists(dataPath)) throw new InvalidDataException("GitHub returned 304 without a cached response.");
                return new CachedHttpPage(File.ReadAllBytes(dataPath), ReadCachedLink(metadataPath));
            }
            if ((int)response.StatusCode == 403 && response.Headers.TryGetValues("X-RateLimit-Remaining", out IEnumerable<string>? remaining)
                && remaining.Contains("0"))
            {
                if (File.Exists(dataPath)) return new CachedHttpPage(File.ReadAllBytes(dataPath), ReadCachedLink(metadataPath));
                throw new HttpRequestException("GitHub API rate limit reached and no cache is available.");
            }
            response.EnsureSuccessStatusCode();
            byte[] bytes = await ReadLimitedAsync(response, MaximumMetadataBytes).ConfigureAwait(false);
            string etag = response.Headers.ETag?.ToString() ?? string.Empty;
            string link = response.Headers.TryGetValues("Link", out IEnumerable<string>? links)
                ? string.Join(",", links) : string.Empty;
            ControllerReleaseSecurity.WriteBytesAtomic(dataPath, bytes);
            ControllerReleaseSecurity.WriteJsonAtomic(metadataPath, new CachedPageMetadata
            {
                ETag = etag,
                StoredAtUtc = DateTimeOffset.UtcNow,
                LinkHeader = link,
            });
            return new CachedHttpPage(bytes, link);
        }
        catch when (File.Exists(dataPath))
        {
            return new CachedHttpPage(File.ReadAllBytes(dataPath), ReadCachedLink(metadataPath));
        }
    }

    private static async Task<byte[]> ReadLimitedAsync(HttpResponseMessage response, int maximumBytes)
    {
        if (response.Content.Headers.ContentLength > maximumBytes)
        {
            throw new InvalidDataException("GitHub response exceeds the metadata size limit.");
        }
        using Stream input = await response.Content.ReadAsStreamAsync().ConfigureAwait(false);
        using var output = new MemoryStream();
        var buffer = new byte[81920];
        while (true)
        {
            int read = await input.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false);
            if (read == 0) break;
            if (output.Length + read > maximumBytes) throw new InvalidDataException("GitHub response exceeds the metadata size limit.");
            output.Write(buffer, 0, read);
        }
        return output.ToArray();
    }

    private static void ValidateGitHubDigest(ControllerGitHubAsset asset, byte[] content)
    {
        string expected = ParseDigest(asset.Digest);
        if (expected.Length > 0 && !ControllerReleaseSecurity.FixedHashEquals(
            ControllerReleaseSecurity.ComputeSha256(content), expected))
        {
            throw new InvalidDataException("GitHub asset digest mismatch: " + asset.Name);
        }
    }

    internal static void EnsureTrustedAsset(ControllerGitHubAsset asset)
    {
        if (!Uri.TryCreate(asset.DownloadUrl, UriKind.Absolute, out Uri? uri)
            || uri.Scheme != Uri.UriSchemeHttps
            || !uri.Host.Equals("github.com", StringComparison.OrdinalIgnoreCase)
            || !uri.AbsolutePath.StartsWith(
                "/" + ControllerReleaseSecurity.OfficialRepository + "/releases/download/",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Release asset is not from the configured official repository: " + asset.Name);
        }
    }

    private static void EnsureFreeSpace(string destination, long requiredBytes)
    {
        string root = Path.GetPathRoot(Path.GetFullPath(destination)) ?? throw new IOException("Cannot resolve destination volume.");
        var drive = new DriveInfo(root);
        if (drive.AvailableFreeSpace < Math.Max(requiredBytes * 3, requiredBytes + 256L * 1024 * 1024))
        {
            throw new IOException("Insufficient disk space for download, staging, and recovery backup.");
        }
    }

    private static string? GetNextLink(string? linkHeader)
    {
        if (string.IsNullOrWhiteSpace(linkHeader)) return null;
        foreach (string part in linkHeader.Split(','))
        {
            Match match = Regex.Match(part, @"<(?<url>https://[^>]+)>;\s*rel=""(?<rel>[^""]+)""");
            if (match.Success && match.Groups["rel"].Value == "next") return match.Groups["url"].Value;
        }
        return null;
    }

    private static string ParseDigest(string? digest)
    {
        Match match = Regex.Match(digest ?? string.Empty, @"(?:sha256:)?(?<hash>[a-fA-F0-9]{64})");
        return match.Success ? match.Groups["hash"].Value.ToLowerInvariant() : string.Empty;
    }

    private static string ComputeCacheKey(string value)
    {
        using SHA256 sha = SHA256.Create();
        return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(value)))
            .Replace("-", string.Empty).ToLowerInvariant();
    }

    private static T Deserialize<T>(byte[] content, string label)
    {
        try
        {
            return JsonSerializer.Deserialize<T>(content, ControllerReleaseSecurity.JsonOptions)
                ?? throw new InvalidDataException(label + " is empty.");
        }
        catch (JsonException exception)
        {
            throw new InvalidDataException(label + " is malformed: " + exception.Message, exception);
        }
    }

    private static ControllerGitHubCacheMetadata ReadCacheMetadata(string path)
    {
        try
        {
            return File.Exists(path)
                ? JsonSerializer.Deserialize<CachedPageMetadata>(
                    File.ReadAllText(path), ControllerReleaseSecurity.JsonOptions) ?? new CachedPageMetadata()
                : new CachedPageMetadata();
        }
        catch { return new CachedPageMetadata(); }
    }

    private static string ReadCachedLink(string path)
    {
        try
        {
            return JsonSerializer.Deserialize<CachedPageMetadata>(
                File.ReadAllText(path), ControllerReleaseSecurity.JsonOptions)?.LinkHeader ?? string.Empty;
        }
        catch { return string.Empty; }
    }

    private sealed class CachedPageMetadata : ControllerGitHubCacheMetadata
    {
        public string LinkHeader { get; set; } = string.Empty;
    }

    private sealed class CachedHttpPage
    {
        public CachedHttpPage(byte[] content, string linkHeader)
        {
            Content = content;
            LinkHeader = linkHeader;
        }
        public byte[] Content { get; }
        public string LinkHeader { get; }
    }
}
