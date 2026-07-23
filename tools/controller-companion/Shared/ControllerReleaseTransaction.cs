using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

internal sealed class ControllerTransactionResult
{
    public bool Succeeded { get; set; }
    public bool RolledBack { get; set; }
    public string BackupRoot { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public InstalledControllerReleaseState? InstalledState { get; set; }
}

internal static class ControllerReleaseTransaction
{
    public const string MarkerFileName = "validated-staging.json";
    public const string JournalFileName = "transaction-journal.json";

    public static ControllerUpdateTransactionPlan CreateValidatedPlan(
        string packagePath,
        string stagingRoot,
        string manifestPath,
        string barDataRoot,
        string companionRoot,
        string backupRoot,
        bool barWasRunning,
        int waitForProcessId = 0,
        string? waitForProcessPath = null,
        bool restartCompanion = true,
        string? restartExecutable = null,
        string? restartArguments = null)
    {
        stagingRoot = Path.GetFullPath(stagingRoot);
        manifestPath = Path.GetFullPath(manifestPath);
        packagePath = Path.GetFullPath(packagePath);
        ControllerReleaseManifest manifest = ControllerReleaseSecurity.ReadManifest(
            manifestPath, stagingRoot, requireDetachedPackageIdentity: true);
        ControllerReleaseSecurity.ValidatePackageIdentity(packagePath, manifest);
        string transactionId = Guid.NewGuid().ToString("N");
        string manifestHash = ControllerReleaseSecurity.ComputeSha256(manifestPath);
        string packageHash = ControllerReleaseSecurity.ComputeSha256(packagePath);
        var marker = new ControllerValidatedStaging
        {
            TransactionId = transactionId,
            ManifestSha256 = manifestHash,
            PackageSha256 = packageHash,
            ValidatedAtUtc = DateTimeOffset.UtcNow,
        };
        ControllerReleaseSecurity.WriteJsonAtomic(Path.Combine(stagingRoot, MarkerFileName), marker);
        return new ControllerUpdateTransactionPlan
        {
            TransactionId = transactionId,
            StagingRoot = stagingRoot,
            ManifestPath = manifestPath,
            ManifestSha256 = manifestHash,
            PackagePath = packagePath,
            PackageSha256 = packageHash,
            BarDataRoot = Path.GetFullPath(barDataRoot),
            CompanionRoot = Path.GetFullPath(companionRoot),
            BackupRoot = Path.GetFullPath(backupRoot),
            ExpectedRepository = ControllerReleaseSecurity.OfficialRepository,
            BarWasRunning = barWasRunning,
            RestartCompanion = restartCompanion,
            RestartExecutable = restartExecutable ?? Path.Combine(companionRoot, "BARControllerBridge.exe"),
            RestartArguments = restartArguments ?? string.Empty,
            WaitForProcessId = waitForProcessId,
            WaitForProcessPath = waitForProcessPath ?? string.Empty,
        };
    }

    public static ControllerReleaseManifest ValidatePlan(ControllerUpdateTransactionPlan plan)
    {
        if (plan.Kind != "bar-controller-update-transaction-plan" || plan.SchemaVersion != 1
            || string.IsNullOrWhiteSpace(plan.TransactionId)
            || !string.Equals(plan.ExpectedRepository, ControllerReleaseSecurity.OfficialRepository, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException("Update transaction plan identity is invalid.");
        }
        if (!Path.IsPathRooted(plan.StagingRoot) || !Path.IsPathRooted(plan.ManifestPath)
            || !Path.IsPathRooted(plan.PackagePath) || !Path.IsPathRooted(plan.BarDataRoot)
            || !Path.IsPathRooted(plan.CompanionRoot) || !Path.IsPathRooted(plan.BackupRoot))
        {
            throw new InvalidDataException("Update transaction paths must be absolute.");
        }
        if (!File.Exists(plan.ManifestPath) || !File.Exists(plan.PackagePath)
            || !ControllerReleaseSecurity.FixedHashEquals(
                ControllerReleaseSecurity.ComputeSha256(plan.ManifestPath), plan.ManifestSha256)
            || !ControllerReleaseSecurity.FixedHashEquals(
                ControllerReleaseSecurity.ComputeSha256(plan.PackagePath), plan.PackageSha256))
        {
            throw new InvalidDataException("Update transaction package or manifest changed after validation.");
        }
        string markerPath = Path.Combine(plan.StagingRoot, MarkerFileName);
        ControllerValidatedStaging marker = JsonSerializer.Deserialize<ControllerValidatedStaging>(
            File.ReadAllText(markerPath), ControllerReleaseSecurity.JsonOptions)
            ?? throw new InvalidDataException("Validated staging marker is empty.");
        if (marker.Kind != "bar-controller-validated-staging" || marker.SchemaVersion != 1
            || marker.TransactionId != plan.TransactionId
            || !ControllerReleaseSecurity.FixedHashEquals(marker.ManifestSha256, plan.ManifestSha256)
            || !ControllerReleaseSecurity.FixedHashEquals(marker.PackageSha256, plan.PackageSha256))
        {
            throw new InvalidDataException("Validated staging marker does not match the transaction plan.");
        }
        ControllerReleaseManifest manifest = ControllerReleaseSecurity.ReadManifest(
            plan.ManifestPath, plan.StagingRoot, requireDetachedPackageIdentity: true);
        ControllerReleaseSecurity.ValidatePackageIdentity(plan.PackagePath, manifest);
        return manifest;
    }

    public static ControllerTransactionResult Execute(ControllerUpdateTransactionPlan plan)
    {
        ControllerReleaseManifest manifest = ValidatePlan(plan);
        return ExecuteValidated(plan, manifest);
    }

    public static ControllerTransactionResult ExecuteLocalPackage(
        string manifestPath,
        string packageRoot,
        string barDataRoot,
        string companionRoot,
        string backupRoot,
        bool barWasRunning)
    {
        manifestPath = Path.GetFullPath(manifestPath);
        packageRoot = Path.GetFullPath(packageRoot);
        ControllerReleaseManifest manifest = ControllerReleaseSecurity.ReadManifest(manifestPath, packageRoot);
        var plan = new ControllerUpdateTransactionPlan
        {
            TransactionId = Guid.NewGuid().ToString("N"),
            StagingRoot = packageRoot,
            ManifestPath = manifestPath,
            ManifestSha256 = ControllerReleaseSecurity.ComputeSha256(manifestPath),
            PackageSha256 = manifest.Package.Sha256,
            BarDataRoot = Path.GetFullPath(barDataRoot),
            CompanionRoot = Path.GetFullPath(companionRoot),
            BackupRoot = Path.GetFullPath(backupRoot),
            ExpectedRepository = ControllerReleaseSecurity.OfficialRepository,
            BarWasRunning = barWasRunning,
        };
        return ExecuteValidated(plan, manifest);
    }

    private static ControllerTransactionResult ExecuteValidated(
        ControllerUpdateTransactionPlan plan,
        ControllerReleaseManifest manifest)
    {
        if (Directory.Exists(plan.BackupRoot) || File.Exists(plan.BackupRoot))
        {
            throw new IOException("Transaction backup already exists: " + plan.BackupRoot);
        }
        Directory.CreateDirectory(plan.BackupRoot);
        var journal = new ControllerTransactionJournal
        {
            TransactionId = plan.TransactionId,
            ReleaseTag = manifest.ReleaseTag,
            StartedAtUtc = DateTimeOffset.UtcNow,
            Status = "backing-up",
        };
        string journalPath = Path.Combine(plan.BackupRoot, JournalFileName);
        ControllerReleaseSecurity.WriteJsonAtomic(journalPath, journal);
        try
        {
            CapturePreservedSnapshots(plan, manifest, journal);
            CaptureInstalledState(plan, journal);
            CapturePayloadBackups(plan, manifest, journal);
            journal.Status = "installing";
            ControllerReleaseSecurity.WriteJsonAtomic(journalPath, journal);

            int applied = 0;
            int simulatedFailureAfter = ReadSimulatedFailureCount();
            foreach (ControllerPayloadComponent component in manifest.Components)
            {
                if (component.Optional
                    && component.InstallPolicy.Equals("replace", StringComparison.OrdinalIgnoreCase)
                    && !File.Exists(ControllerReleaseSecurity.ResolveInside(plan.StagingRoot, component.SourcePath)))
                {
                    continue;
                }
                ApplyComponent(plan, component, journal);
                applied++;
                if (simulatedFailureAfter > 0 && applied >= simulatedFailureAfter)
                {
                    throw new IOException("Simulated transaction failure after " + applied + " components.");
                }
            }

            ValidateInstalledComponents(plan, manifest);
            InstalledControllerReleaseState state = WriteInstalledState(plan, manifest);
            journal.Status = "complete";
            journal.CompletedAtUtc = DateTimeOffset.UtcNow;
            ControllerReleaseSecurity.WriteJsonAtomic(journalPath, journal);
            return new ControllerTransactionResult
            {
                Succeeded = true,
                BackupRoot = plan.BackupRoot,
                InstalledState = state,
                Message = "Installed " + manifest.DisplayVersion + " (" + manifest.ReleaseTag + ").",
            };
        }
        catch (Exception installFailure)
        {
            journal.Status = "rolling-back";
            journal.Failure = installFailure.Message;
            ControllerReleaseSecurity.WriteJsonAtomic(journalPath, journal);
            try
            {
                Rollback(journal);
                journal.Status = "rolled-back";
                journal.CompletedAtUtc = DateTimeOffset.UtcNow;
                ControllerReleaseSecurity.WriteJsonAtomic(journalPath, journal);
                return new ControllerTransactionResult
                {
                    Succeeded = false,
                    RolledBack = true,
                    BackupRoot = plan.BackupRoot,
                    Message = "Installation failed and the previous state was restored: " + installFailure.Message,
                };
            }
            catch (Exception rollbackFailure)
            {
                journal.Status = "rollback-failed";
                journal.CompletedAtUtc = DateTimeOffset.UtcNow;
                journal.Failure = installFailure.Message + " | rollback: " + rollbackFailure.Message;
                ControllerReleaseSecurity.WriteJsonAtomic(journalPath, journal);
                throw new AggregateException(
                    "Installation failed and automatic rollback could not be validated.",
                    installFailure,
                    rollbackFailure);
            }
        }
    }

    public static void ValidateRollbackBackup(string backupRoot)
    {
        string journalPath = Path.Combine(backupRoot, JournalFileName);
        ControllerTransactionJournal journal = JsonSerializer.Deserialize<ControllerTransactionJournal>(
            File.ReadAllText(journalPath), ControllerReleaseSecurity.JsonOptions)
            ?? throw new InvalidDataException("Transaction journal is empty.");
        if (journal.Kind != "bar-controller-update-transaction-journal" || journal.SchemaVersion != 1
            || journal.Files.Count == 0)
        {
            throw new InvalidDataException("Transaction journal is invalid.");
        }
        foreach (ControllerTransactionFile file in journal.Files.Where(item => item.ExistedBefore))
        {
            if (!File.Exists(file.BackupPath)
                || !ControllerReleaseSecurity.FixedHashEquals(
                    ControllerReleaseSecurity.ComputeSha256(file.BackupPath), file.PreSha256))
            {
                throw new InvalidDataException("Recovery backup hash mismatch: " + file.BackupPath);
            }
        }
        foreach (ControllerPreservedSnapshot snapshot in journal.Preserved)
        {
            if (snapshot.IsDirectory ? !Directory.Exists(snapshot.BackupPath) : !File.Exists(snapshot.BackupPath))
            {
                throw new InvalidDataException("Preserved recovery snapshot is missing: " + snapshot.BackupPath);
            }
        }
    }

    private static void CapturePreservedSnapshots(
        ControllerUpdateTransactionPlan plan,
        ControllerReleaseManifest manifest,
        ControllerTransactionJournal journal)
    {
        foreach (ControllerPreservationRule rule in manifest.ConfigurationPreservation)
        {
            string source = ControllerReleaseSecurity.ResolveDestination(
                rule.DestinationRoot, rule.RelativePath, plan.BarDataRoot, plan.CompanionRoot);
            if (!File.Exists(source) && !Directory.Exists(source)) continue;
            string sourcePrefix = Path.GetFullPath(source).TrimEnd(Path.DirectorySeparatorChar)
                + Path.DirectorySeparatorChar;
            if (Path.GetFullPath(plan.BackupRoot).StartsWith(sourcePrefix, StringComparison.OrdinalIgnoreCase))
            {
                // Recovery archives are append-only infrastructure. Snapshotting the parent into its own
                // new child would recurse; leaving every pre-existing backup untouched is the preservation.
                continue;
            }
            string backup = Path.Combine(
                plan.BackupRoot,
                "preserved",
                rule.DestinationRoot,
                rule.RelativePath.Replace('/', Path.DirectorySeparatorChar));
            if (File.Exists(source))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(backup)!);
                File.Copy(source, backup, false);
            }
            else
            {
                CopyDirectory(source, backup, rule.Recursive);
            }
            journal.Preserved.Add(new ControllerPreservedSnapshot
            {
                RuleId = rule.RuleId,
                OriginalPath = source,
                BackupPath = backup,
                IsDirectory = Directory.Exists(source),
            });
        }
    }

    private static void CaptureInstalledState(
        ControllerUpdateTransactionPlan plan,
        ControllerTransactionJournal journal)
    {
        string statePath = Path.Combine(plan.CompanionRoot, ControllerReleaseSecurity.InstalledStateFileName);
        CaptureFile(
            "installed-release-state",
            statePath,
            Path.Combine(plan.BackupRoot, "state", ControllerReleaseSecurity.InstalledStateFileName),
            "state",
            journal);
    }

    private static void CapturePayloadBackups(
        ControllerUpdateTransactionPlan plan,
        ControllerReleaseManifest manifest,
        ControllerTransactionJournal journal)
    {
        foreach (ControllerPayloadComponent component in manifest.Components)
        {
            string destination = ControllerReleaseSecurity.ResolveDestination(
                component.DestinationRoot, component.DestinationPath, plan.BarDataRoot, plan.CompanionRoot);
            string backup = Path.Combine(
                plan.BackupRoot,
                "files",
                component.DestinationRoot,
                component.DestinationPath.Replace('/', Path.DirectorySeparatorChar));
            CaptureFile(component.ComponentId, destination, backup, component.InstallPolicy, journal);
        }
    }

    private static void CaptureFile(
        string componentId,
        string destination,
        string backup,
        string installPolicy,
        ControllerTransactionJournal journal)
    {
        bool exists = File.Exists(destination);
        string preHash = exists ? ControllerReleaseSecurity.ComputeSha256(destination) : string.Empty;
        if (exists)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(backup)!);
            File.Copy(destination, backup, false);
            if (!ControllerReleaseSecurity.FixedHashEquals(
                ControllerReleaseSecurity.ComputeSha256(backup), preHash))
            {
                throw new InvalidDataException("Recovery backup hash mismatch: " + destination);
            }
        }
        journal.Files.Add(new ControllerTransactionFile
        {
            ComponentId = componentId,
            Destination = destination,
            BackupPath = backup,
            ExistedBefore = exists,
            PreSha256 = preHash,
            InstallPolicy = installPolicy,
        });
    }

    private static void ApplyComponent(
        ControllerUpdateTransactionPlan plan,
        ControllerPayloadComponent component,
        ControllerTransactionJournal journal)
    {
        ControllerTransactionFile record = journal.Files.First(item => item.ComponentId == component.ComponentId);
        if (component.InstallPolicy.Equals("remove", StringComparison.OrdinalIgnoreCase))
        {
            if (File.Exists(record.Destination)) File.Delete(record.Destination);
            record.PostSha256 = string.Empty;
            record.Applied = true;
            return;
        }
        string source = ControllerReleaseSecurity.ResolveInside(plan.StagingRoot, component.SourcePath);
        Directory.CreateDirectory(Path.GetDirectoryName(record.Destination)!);
        string temporary = record.Destination + ".update-" + plan.TransactionId;
        try
        {
            File.Copy(source, temporary, false);
            if (!ControllerReleaseSecurity.FixedHashEquals(
                ControllerReleaseSecurity.ComputeSha256(temporary), component.Sha256))
            {
                throw new InvalidDataException("Staged component changed during install: " + component.ComponentId);
            }
            File.Move(temporary, record.Destination, true);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
        record.PostSha256 = ControllerReleaseSecurity.ComputeSha256(record.Destination);
        record.Applied = true;
    }

    private static void ValidateInstalledComponents(
        ControllerUpdateTransactionPlan plan,
        ControllerReleaseManifest manifest)
    {
        foreach (ControllerPayloadComponent component in manifest.Components)
        {
            string destination = ControllerReleaseSecurity.ResolveDestination(
                component.DestinationRoot, component.DestinationPath, plan.BarDataRoot, plan.CompanionRoot);
            if (component.InstallPolicy.Equals("remove", StringComparison.OrdinalIgnoreCase))
            {
                if (File.Exists(destination)) throw new InvalidDataException("Removed component still exists: " + component.ComponentId);
            }
            else if (!File.Exists(destination)
                || !ControllerReleaseSecurity.FixedHashEquals(
                    ControllerReleaseSecurity.ComputeSha256(destination), component.Sha256))
            {
                throw new InvalidDataException("Installed component hash mismatch: " + component.ComponentId);
            }
        }
    }

    private static InstalledControllerReleaseState WriteInstalledState(
        ControllerUpdateTransactionPlan plan,
        ControllerReleaseManifest manifest)
    {
        var state = new InstalledControllerReleaseState
        {
            ReleaseTag = manifest.ReleaseTag,
            SemanticVersion = manifest.SemanticVersion,
            DisplayVersion = manifest.DisplayVersion,
            ReleaseSequence = manifest.ReleaseSequence,
            CommitSha = manifest.CommitSha,
            PackageSha256 = manifest.Package.Sha256,
            ManifestSha256 = plan.ManifestSha256,
            InstalledAtUtc = DateTimeOffset.UtcNow,
            Repository = manifest.Repository,
            PreviousBackupPath = plan.BackupRoot,
            InstalledWhileBarRunning = plan.BarWasRunning,
            Components = manifest.Components
                .Where(component => !component.InstallPolicy.Equals("remove", StringComparison.OrdinalIgnoreCase))
                .Select(component => new InstalledControllerComponent
                {
                    ComponentId = component.ComponentId,
                    DestinationRoot = component.DestinationRoot,
                    DestinationPath = component.DestinationPath,
                    Sha256 = component.Sha256,
                }).ToList(),
        };
        ControllerReleaseSecurity.WriteJsonAtomic(
            Path.Combine(plan.CompanionRoot, ControllerReleaseSecurity.InstalledStateFileName), state);
        return state;
    }

    private static void Rollback(ControllerTransactionJournal journal)
    {
        foreach (ControllerTransactionFile file in journal.Files.AsEnumerable().Reverse())
        {
            if (!file.Applied && file.ComponentId != "installed-release-state") continue;
            if (file.ExistedBefore)
            {
                if (!File.Exists(file.BackupPath))
                {
                    throw new FileNotFoundException("Rollback backup is missing.", file.BackupPath);
                }
                Directory.CreateDirectory(Path.GetDirectoryName(file.Destination)!);
                string temporary = file.Destination + ".rollback-" + journal.TransactionId;
                File.Copy(file.BackupPath, temporary, true);
                File.Move(temporary, file.Destination, true);
                if (!ControllerReleaseSecurity.FixedHashEquals(
                    ControllerReleaseSecurity.ComputeSha256(file.Destination), file.PreSha256))
                {
                    throw new InvalidDataException("Restored file hash mismatch: " + file.Destination);
                }
            }
            else if (File.Exists(file.Destination))
            {
                File.Delete(file.Destination);
            }
        }
    }

    private static void CopyDirectory(string source, string destination, bool recursive)
    {
        Directory.CreateDirectory(destination);
        foreach (string file in Directory.EnumerateFiles(source))
        {
            File.Copy(file, Path.Combine(destination, Path.GetFileName(file)), false);
        }
        if (!recursive) return;
        foreach (string directory in Directory.EnumerateDirectories(source))
        {
            CopyDirectory(directory, Path.Combine(destination, Path.GetFileName(directory)), true);
        }
    }

    private static int ReadSimulatedFailureCount()
    {
        return int.TryParse(Environment.GetEnvironmentVariable("BAR_CONTROLLER_TEST_FAIL_AFTER_COMPONENTS"), out int value)
            ? Math.Max(0, value) : 0;
    }
}
