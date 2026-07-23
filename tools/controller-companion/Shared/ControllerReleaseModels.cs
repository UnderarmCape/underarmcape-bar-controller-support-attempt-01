using System;
using System.Collections.Generic;

internal sealed class ControllerReleaseManifest
{
    public string Kind { get; set; } = "bar-controller-release-manifest";
    public int SchemaVersion { get; set; } = 1;
    public string ReleaseTag { get; set; } = string.Empty;
    public string SemanticVersion { get; set; } = string.Empty;
    public string DisplayVersion { get; set; } = string.Empty;
    public long ReleaseSequence { get; set; }
    public string ReleaseChannel { get; set; } = string.Empty;
    public string CommitSha { get; set; } = string.Empty;
    public DateTimeOffset PublishedAtUtc { get; set; }
    public string Repository { get; set; } = string.Empty;
    public ControllerPackageIdentity Package { get; set; } = new ControllerPackageIdentity();
    public string MinimumUpdaterVersion { get; set; } = string.Empty;
    public ControllerBarCompatibility BarCompatibility { get; set; } = new ControllerBarCompatibility();
    public string CompatibilityNotes { get; set; } = string.Empty;
    public bool RequiresLuaUiReset { get; set; }
    public string ReleaseSummary { get; set; } = string.Empty;
    public string ReleaseNotesAsset { get; set; } = string.Empty;
    public List<ControllerPreservationRule> ConfigurationPreservation { get; set; } = new List<ControllerPreservationRule>();
    public ControllerInstallLifecycle InstallLifecycle { get; set; } = new ControllerInstallLifecycle();
    public List<ControllerPayloadComponent> Components { get; set; } = new List<ControllerPayloadComponent>();
}

internal sealed class ControllerPackageIdentity
{
    public string AssetName { get; set; } = string.Empty;
    public string Sha256 { get; set; } = string.Empty;
    public long ByteLength { get; set; }
    public string Format { get; set; } = "zip";
    public bool DetachedIdentity { get; set; }
}

internal sealed class ControllerBarCompatibility
{
    public string BuildManifest { get; set; } = string.Empty;
    public string UpstreamCommit { get; set; } = string.Empty;
    public bool NativeOverrideRebaseMayBeRequired { get; set; }
}

internal sealed class ControllerInstallLifecycle
{
    public bool BackupBeforeInstall { get; set; } = true;
    public bool TransactionalRollback { get; set; } = true;
    public bool AllowWhileBarRunning { get; set; } = true;
    public bool RestartCompanion { get; set; } = true;
    public string ReloadInstruction { get; set; } = "/luaui reset";
}

internal sealed class ControllerPreservationRule
{
    public string RuleId { get; set; } = string.Empty;
    public string DestinationRoot { get; set; } = string.Empty;
    public string RelativePath { get; set; } = string.Empty;
    public bool Recursive { get; set; }
    public string Behavior { get; set; } = "preserve";
}

internal sealed class ControllerPayloadComponent
{
    public string ComponentId { get; set; } = string.Empty;
    public string ComponentType { get; set; } = string.Empty;
    public string SourcePath { get; set; } = string.Empty;
    public string DestinationRoot { get; set; } = string.Empty;
    public string DestinationPath { get; set; } = string.Empty;
    public string Sha256 { get; set; } = string.Empty;
    public long ByteLength { get; set; }
    public string InstallPolicy { get; set; } = "replace";
    public string ReplaceBehavior { get; set; } = "replace";
    public bool MayBeLockedByCompanion { get; set; }
    public bool CompanionMustRestart { get; set; }
    public bool BarMustRunLuaUiReset { get; set; }
    public bool Optional { get; set; }
    public string Platform { get; set; } = "windows";
    public string Architecture { get; set; } = "x64";
    public string ConfigurationBehavior { get; set; } = "package-owned";
}

internal sealed class InstalledControllerReleaseState
{
    public string Kind { get; set; } = "bar-controller-installed-release";
    public int SchemaVersion { get; set; } = 1;
    public string ReleaseTag { get; set; } = string.Empty;
    public string SemanticVersion { get; set; } = string.Empty;
    public string DisplayVersion { get; set; } = string.Empty;
    public long ReleaseSequence { get; set; }
    public string CommitSha { get; set; } = string.Empty;
    public string PackageSha256 { get; set; } = string.Empty;
    public string ManifestSha256 { get; set; } = string.Empty;
    public DateTimeOffset InstalledAtUtc { get; set; }
    public string Repository { get; set; } = string.Empty;
    public string PreviousBackupPath { get; set; } = string.Empty;
    public bool InstalledWhileBarRunning { get; set; }
    public List<InstalledControllerComponent> Components { get; set; } = new List<InstalledControllerComponent>();
}

internal sealed class InstalledControllerComponent
{
    public string ComponentId { get; set; } = string.Empty;
    public string DestinationRoot { get; set; } = string.Empty;
    public string DestinationPath { get; set; } = string.Empty;
    public string Sha256 { get; set; } = string.Empty;
}

internal sealed class LegacyControllerReleaseCatalog
{
    public string Kind { get; set; } = "bar-controller-legacy-release-catalog";
    public int SchemaVersion { get; set; } = 1;
    public string Repository { get; set; } = string.Empty;
    public string MinimumVersion { get; set; } = "0.6.0";
    public List<LegacyControllerRelease> Releases { get; set; } = new List<LegacyControllerRelease>();
}

internal sealed class LegacyControllerRelease
{
    public string Tag { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Version { get; set; } = string.Empty;
    public string DisplayVersion { get; set; } = string.Empty;
    public long ReleaseSequence { get; set; }
    public string CommitSha { get; set; } = string.Empty;
    public DateTimeOffset PublishedAtUtc { get; set; }
    public string AssetName { get; set; } = string.Empty;
    public string AssetSha256 { get; set; } = string.Empty;
    public long AssetByteLength { get; set; }
    public string InstallAdapter { get; set; } = "legacy-dynamic";
    public bool RequiresLuaUiReset { get; set; } = true;
    public bool Available { get; set; } = true;
    public string UnavailableReason { get; set; } = string.Empty;
    public List<ControllerPreservationRule> ConfigurationPreservation { get; set; } = new List<ControllerPreservationRule>();
}

internal sealed class ControllerUpdateTransactionPlan
{
    public string Kind { get; set; } = "bar-controller-update-transaction-plan";
    public int SchemaVersion { get; set; } = 1;
    public string TransactionId { get; set; } = string.Empty;
    public string StagingRoot { get; set; } = string.Empty;
    public string ManifestPath { get; set; } = string.Empty;
    public string ManifestSha256 { get; set; } = string.Empty;
    public string PackagePath { get; set; } = string.Empty;
    public string PackageSha256 { get; set; } = string.Empty;
    public string BarDataRoot { get; set; } = string.Empty;
    public string CompanionRoot { get; set; } = string.Empty;
    public string BackupRoot { get; set; } = string.Empty;
    public string ExpectedRepository { get; set; } = string.Empty;
    public bool BarWasRunning { get; set; }
    public bool RestartCompanion { get; set; }
    public string RestartExecutable { get; set; } = string.Empty;
    public string RestartArguments { get; set; } = string.Empty;
    public int WaitForProcessId { get; set; }
    public string WaitForProcessPath { get; set; } = string.Empty;
}

internal sealed class ControllerValidatedStaging
{
    public string Kind { get; set; } = "bar-controller-validated-staging";
    public int SchemaVersion { get; set; } = 1;
    public string TransactionId { get; set; } = string.Empty;
    public string ManifestSha256 { get; set; } = string.Empty;
    public string PackageSha256 { get; set; } = string.Empty;
    public DateTimeOffset ValidatedAtUtc { get; set; }
}

internal sealed class ControllerTransactionJournal
{
    public string Kind { get; set; } = "bar-controller-update-transaction-journal";
    public int SchemaVersion { get; set; } = 1;
    public string TransactionId { get; set; } = string.Empty;
    public string ReleaseTag { get; set; } = string.Empty;
    public DateTimeOffset StartedAtUtc { get; set; }
    public DateTimeOffset? CompletedAtUtc { get; set; }
    public string Status { get; set; } = "preparing";
    public string Failure { get; set; } = string.Empty;
    public List<ControllerTransactionFile> Files { get; set; } = new List<ControllerTransactionFile>();
    public List<ControllerPreservedSnapshot> Preserved { get; set; } = new List<ControllerPreservedSnapshot>();
}

internal sealed class ControllerTransactionFile
{
    public string ComponentId { get; set; } = string.Empty;
    public string Destination { get; set; } = string.Empty;
    public string BackupPath { get; set; } = string.Empty;
    public bool ExistedBefore { get; set; }
    public string PreSha256 { get; set; } = string.Empty;
    public string PostSha256 { get; set; } = string.Empty;
    public string InstallPolicy { get; set; } = string.Empty;
    public bool Applied { get; set; }
}

internal sealed class ControllerPreservedSnapshot
{
    public string RuleId { get; set; } = string.Empty;
    public string OriginalPath { get; set; } = string.Empty;
    public string BackupPath { get; set; } = string.Empty;
    public bool IsDirectory { get; set; }
}

internal sealed class ControllerReleaseCatalogItem
{
    public string Tag { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string SemanticVersion { get; set; } = string.Empty;
    public string DisplayVersion { get; set; } = string.Empty;
    public long ReleaseSequence { get; set; }
    public string CommitSha { get; set; } = string.Empty;
    public DateTimeOffset PublishedAtUtc { get; set; }
    public bool IsPrerelease { get; set; }
    public bool IsLegacy { get; set; }
    public bool IsLatest { get; set; }
    public bool IsInstalled { get; set; }
    public bool IsAvailable { get; set; }
    public string UnavailableReason { get; set; } = string.Empty;
    public string ReleaseUrl { get; set; } = string.Empty;
    public string Summary { get; set; } = string.Empty;
    public string PackageAssetName { get; set; } = string.Empty;
    public string PackageSha256 { get; set; } = string.Empty;
    public long PackageByteLength { get; set; }
    public string PackageDownloadUrl { get; set; } = string.Empty;
    public string ManifestDownloadUrl { get; set; } = string.Empty;
    public ControllerReleaseManifest? Manifest { get; set; }
}
