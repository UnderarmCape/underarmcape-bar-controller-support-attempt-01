using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

internal static class Program
{
    public static async Task<int> Main(string[] args)
    {
        ConsoleInteractionCoordinator session = ConsoleInteractionCoordinator.Instance;
        session.WriteLine("==================================================================", BridgeTone.Accent);
        session.WriteLine("    BAR CONTROLLER SUPPORT — STANDALONE RESCUE UPDATE BOOTSTRAP   ", BridgeTone.Accent);
        session.WriteLine("==================================================================", BridgeTone.Accent);
        session.WriteLine("Target: Repair/upgrade v0.8.0+ companion bridge installations", BridgeTone.Neutral);
        session.WriteLine(string.Empty);

        try
        {
            string companionRoot = GetCompanionRoot();
            string barDataRoot = GetBarDataRoot();

            session.WriteLine("Companion Directory: " + companionRoot, BridgeTone.Neutral);
            session.WriteLine("BAR Data Directory:  " + barDataRoot, BridgeTone.Neutral);

            InstalledControllerReleaseState? installed = ControllerReleaseSecurity.ReadInstalledState(companionRoot);
            string currentVersion = installed?.DisplayVersion ?? "v0.8.0 (Legacy / Unknown state)";
            session.WriteLine("Installed Version:   " + currentVersion, BridgeTone.Good);
            session.WriteLine(string.Empty);

            session.WriteLine("[1/5] Fetching GitHub Latest release catalog...", BridgeTone.Neutral);
            using var client = new ControllerGitHubReleaseClient(Path.Combine(companionRoot, "release-cache"));
            ControllerGitHubRelease latestRelease = await client.GetLatestAsync().ConfigureAwait(false);

            session.WriteLine($"[1/5] Latest Release: {latestRelease.Name} ({latestRelease.TagName})", BridgeTone.Good);

            ControllerReleaseManifest? manifest = await client.TryGetManifestAsync(latestRelease).ConfigureAwait(false);
            if (manifest == null)
            {
                session.WriteLine("ERROR: Latest release is missing a detached controller manifest identity.", BridgeTone.Bad);
                return 1;
            }

            ControllerGitHubAsset? packageAsset = latestRelease.Assets.FirstOrDefault(a => a.Name.Equals(manifest.Package.AssetName, StringComparison.Ordinal));
            if (packageAsset == null)
            {
                session.WriteLine($"ERROR: Package asset '{manifest.Package.AssetName}' missing from GitHub release.", BridgeTone.Bad);
                return 1;
            }

            session.WriteLine(string.Empty);
            session.WriteLine($"Do you want to rescue update to {manifest.DisplayVersion} ({manifest.ReleaseTag})? [y/N]", BridgeTone.Warning);
            session.Output.Write("Choice [y/N]: ");

            string? confirm = session.ReadLine()?.Trim();
            if (!string.Equals(confirm, "y", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(confirm, "yes", StringComparison.OrdinalIgnoreCase))
            {
                session.WriteLine("Operation cancelled by user. No files modified.", BridgeTone.Neutral);
                return 0;
            }

            session.WriteLine(string.Empty);
            session.WriteLine("[2/5] Stopping running bridge processes if present...", BridgeTone.Neutral);
            StopRunningBridgeProcesses();

            session.WriteLine("[3/5] Downloading release package & validating hashes...", BridgeTone.Neutral);
            string transactionDir = Path.Combine(companionRoot, "updates", manifest.ReleaseTag, Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(transactionDir);
            string packagePath = Path.Combine(transactionDir, manifest.Package.AssetName);

            await client.DownloadPackageAsync(packageAsset, packagePath, manifest).ConfigureAwait(false);

            string actualHash = ComputeSha256(packagePath);
            if (!ControllerReleaseSecurity.FixedHashEquals(actualHash, manifest.Package.Sha256))
            {
                session.WriteLine($"ERROR: Package SHA-256 hash mismatch! Expected {manifest.Package.Sha256}, got {actualHash}.", BridgeTone.Bad);
                return 1;
            }
            session.WriteLine("✓ Package SHA-256 hash verified.", BridgeTone.Good);

            string stagingDir = Path.Combine(transactionDir, "staging");
            ControllerReleaseSecurity.SafeExtractZip(packagePath, stagingDir);

            string manifestPath = Path.Combine(transactionDir, "controller-release-manifest.json");
            ControllerReleaseSecurity.WriteJsonAtomic(manifestPath, manifest);
            ControllerReleaseSecurity.ReadManifest(manifestPath, stagingDir, requireDetachedPackageIdentity: true);
            session.WriteLine("✓ Manifest and extracted component inventory verified.", BridgeTone.Good);

            session.WriteLine(string.Empty);
            session.WriteLine("[4/5] Creating transactional backup...", BridgeTone.Neutral);
            string backupDir = Path.Combine(companionRoot, "recovery-backups", DateTime.Now.ToString("yyyyMMdd-HHmmssfff") + "-bootstrap-" + manifest.ReleaseTag);
            
            int currentPid = Process.GetCurrentProcess().Id;
            string currentPath = Process.GetCurrentProcess().MainModule?.FileName ?? string.Empty;

            ControllerUpdateTransactionPlan plan = ControllerReleaseTransaction.CreateValidatedPlan(
                packagePath,
                stagingDir,
                manifestPath,
                barDataRoot,
                companionRoot,
                backupDir,
                barWasRunning: ControllerReleaseSecurity.IsBarRunning(),
                waitForProcessId: currentPid,
                waitForProcessPath: currentPath,
                restartCompanion: false,
                restartExecutable: Path.Combine(companionRoot, "BARControllerBridge.exe"));

            session.WriteLine("✓ Transaction plan created and validated.", BridgeTone.Good);

            session.WriteLine(string.Empty);
            session.WriteLine("[5/5] Executing transactional file deployment...", BridgeTone.Neutral);
            ControllerTransactionResult result = ControllerReleaseTransaction.Execute(plan);

            if (!result.Succeeded)
            {
                session.WriteLine("ERROR: Transaction failed! Rollback status: " + (result.RolledBack ? "Restored" : "Failed"), BridgeTone.Bad);
                session.WriteLine("Details: " + result.Message, BridgeTone.Bad);
                return 1;
            }

            session.WriteLine(string.Empty);
            session.WriteLine("==================================================================", BridgeTone.Good);
            session.WriteLine($"    RESCUE UPDATE SUCCESSFUL — UPGRADED TO {manifest.DisplayVersion}   ", BridgeTone.Good);
            session.WriteLine("==================================================================", BridgeTone.Good);
            session.WriteLine("Installed State Tag: " + manifest.ReleaseTag, BridgeTone.Neutral);
            session.WriteLine("Backup Path:         " + backupDir, BridgeTone.Neutral);
            session.WriteLine(string.Empty);
            return 0;
        }
        catch (Exception ex)
        {
            session.WriteLine("ERROR: Rescue update encountered exception: " + ex.Message, BridgeTone.Bad);
            return 1;
        }
    }

    private static void StopRunningBridgeProcesses()
    {
        foreach (Process process in Process.GetProcessesByName("BARControllerBridge"))
        {
            try
            {
                if (!process.HasExited)
                {
                    process.Kill();
                    process.WaitForExit(3000);
                }
            }
            catch { }
        }
    }

    private static string ComputeSha256(string file)
    {
        using SHA256 sha = SHA256.Create();
        using FileStream stream = File.OpenRead(file);
        return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", string.Empty).ToLowerInvariant();
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
}
