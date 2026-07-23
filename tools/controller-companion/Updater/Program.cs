using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;

internal static class Program
{
    private static int Main(string[] args)
    {
        if (args.Length == 2 && args[0] == "--validate-backup")
        {
            try
            {
                ControllerReleaseTransaction.ValidateRollbackBackup(Path.GetFullPath(args[1]));
                BridgeConsole.WriteStatus("Rollback", "backup and hashes are valid", BridgeTone.Good);
                Console.WriteLine("ROLLBACK_VALID=" + Path.GetFullPath(args[1]));
                return 0;
            }
            catch (Exception exception)
            {
                BridgeConsole.WriteStatus("Rollback", exception.Message, BridgeTone.Bad);
                return 1;
            }
        }
        if (args.Contains("--package", StringComparer.Ordinal))
        {
            return RunPackageMode(args);
        }
        if (!TryParse(args, out string planPath, out bool validateOnly, out int waitTimeoutMilliseconds))
        {
            WriteUsage();
            return 2;
        }
        try
        {
            ControllerUpdateTransactionPlan plan = JsonSerializer.Deserialize<ControllerUpdateTransactionPlan>(
                File.ReadAllText(Path.GetFullPath(planPath)), ControllerReleaseSecurity.JsonOptions)
                ?? throw new InvalidDataException("Update plan is empty.");
            ControllerReleaseManifest manifest = ControllerReleaseTransaction.ValidatePlan(plan);
            BridgeConsole.WriteStatus("Updater", "validated " + manifest.ReleaseTag, BridgeTone.Good);
            if (validateOnly)
            {
                BridgeConsole.WriteStatus("Updater", "transaction plan is safe; no files changed", BridgeTone.Good);
                return 0;
            }

            WaitForCompanion(plan, waitTimeoutMilliseconds);
            ControllerTransactionResult result = ControllerReleaseTransaction.Execute(plan);
            if (!result.Succeeded)
            {
                BridgeConsole.WriteStatus("Updater", result.Message,
                    result.RolledBack ? BridgeTone.Warning : BridgeTone.Bad);
                return 1;
            }

            BridgeConsole.WriteStatus("Updater", result.Message, BridgeTone.Good);
            BridgeConsole.WriteStatus("Backup", result.BackupRoot, BridgeTone.Neutral);
            if (plan.BarWasRunning && manifest.RequiresLuaUiReset)
            {
                BridgeConsole.WriteLuaUiResetWarning(
                    manifest.Components.Exists(component =>
                        component.ComponentType.Equals("native-override", StringComparison.OrdinalIgnoreCase)));
            }
            if (plan.RestartCompanion)
            {
                RestartCompanion(plan);
            }
            return 0;
        }
        catch (Exception exception)
        {
            BridgeConsole.WriteStatus("Updater", exception.Message, BridgeTone.Bad);
            return 1;
        }
    }

    private static int RunPackageMode(string[] args)
    {
        try
        {
            string packagePath = RequiredOption(args, "--package");
            string manifestPath = RequiredOption(args, "--manifest");
            string stagingRoot = RequiredOption(args, "--staging");
            string barDataRoot = RequiredOption(args, "--bar-data");
            string companionRoot = RequiredOption(args, "--companion");
            string backupRoot = RequiredOption(args, "--backup");
            bool validateOnly = args.Contains("--validate-only", StringComparer.Ordinal);
            bool barWasRunning = args.Contains("--bar-was-running", StringComparer.Ordinal);
            bool restartCompanion = args.Contains("--restart-companion", StringComparer.Ordinal);
            EnsureOnlyPackageOptions(args);

            ControllerUpdateTransactionPlan plan = ControllerReleaseTransaction.CreateValidatedPlan(
                packagePath,
                stagingRoot,
                manifestPath,
                barDataRoot,
                companionRoot,
                backupRoot,
                barWasRunning,
                restartCompanion: restartCompanion);
            ControllerReleaseManifest manifest = ControllerReleaseTransaction.ValidatePlan(plan);
            BridgeConsole.WriteStatus("Updater", "validated " + manifest.ReleaseTag, BridgeTone.Good);
            if (validateOnly)
            {
                BridgeConsole.WriteStatus("Updater", "package transaction is safe; no installed files changed", BridgeTone.Good);
                return 0;
            }
            ControllerTransactionResult result = ControllerReleaseTransaction.Execute(plan);
            if (!result.Succeeded)
            {
                BridgeConsole.WriteStatus("Updater", result.Message,
                    result.RolledBack ? BridgeTone.Warning : BridgeTone.Bad);
                return 1;
            }
            BridgeConsole.WriteStatus("Updater", result.Message, BridgeTone.Good);
            BridgeConsole.WriteStatus("Backup", result.BackupRoot, BridgeTone.Neutral);
            Console.WriteLine("BACKUP_ROOT=" + result.BackupRoot);
            if (restartCompanion) RestartCompanion(plan);
            return 0;
        }
        catch (Exception exception)
        {
            BridgeConsole.WriteStatus("Updater", exception.Message, BridgeTone.Bad);
            return 1;
        }
    }

    private static string RequiredOption(string[] args, string name)
    {
        int index = Array.IndexOf(args, name);
        if (index < 0 || index + 1 >= args.Length || args[index + 1].StartsWith("--", StringComparison.Ordinal))
            throw new ArgumentException("Missing required updater option: " + name);
        return Path.GetFullPath(args[index + 1]);
    }

    private static void EnsureOnlyPackageOptions(string[] args)
    {
        string[] values = { "--package", "--manifest", "--staging", "--bar-data", "--companion", "--backup" };
        string[] flags = { "--validate-only", "--bar-was-running", "--restart-companion" };
        for (int index = 0; index < args.Length; index++)
        {
            string argument = args[index];
            if (values.Contains(argument, StringComparer.Ordinal))
            {
                index++;
                if (index >= args.Length) throw new ArgumentException("Missing value for " + argument);
            }
            else if (!flags.Contains(argument, StringComparer.Ordinal))
            {
                throw new ArgumentException("Unknown updater option: " + argument);
            }
        }
    }

    private static void WriteUsage()
    {
        Console.Error.WriteLine("Usage: BARControllerUpdater --plan path [--validate-only] [--wait-timeout-ms N]");
        Console.Error.WriteLine("   or: BARControllerUpdater --package zip --manifest json --staging dir --bar-data dir --companion dir --backup dir [--validate-only] [--bar-was-running] [--restart-companion]");
        Console.Error.WriteLine("   or: BARControllerUpdater --validate-backup backup-dir");
    }

    private static void WaitForCompanion(
        ControllerUpdateTransactionPlan plan,
        int timeoutMilliseconds)
    {
        if (plan.WaitForProcessId <= 0) return;
        using Process process = Process.GetProcessById(plan.WaitForProcessId);
        string actualPath;
        try
        {
            actualPath = process.MainModule?.FileName ?? string.Empty;
        }
        catch (Exception exception)
        {
            throw new InvalidOperationException("Cannot verify the companion process identity: " + exception.Message, exception);
        }
        if (!ControllerUpdaterGuard.ProcessPathMatches(actualPath, plan.WaitForProcessPath))
        {
            throw new InvalidOperationException("Updater refused to wait for an unrelated process.");
        }
        BridgeConsole.WriteStatus("Updater", "waiting for companion PID " + plan.WaitForProcessId, BridgeTone.Warning);
        if (!process.WaitForExit(timeoutMilliseconds))
        {
            throw new TimeoutException("Companion did not exit voluntarily before the updater timeout.");
        }
    }

    private static void RestartCompanion(ControllerUpdateTransactionPlan plan)
    {
        if (string.IsNullOrWhiteSpace(plan.RestartExecutable)
            || !File.Exists(plan.RestartExecutable))
        {
            throw new FileNotFoundException("Restart executable is unavailable.", plan.RestartExecutable);
        }
        Process.Start(new ProcessStartInfo
        {
            FileName = plan.RestartExecutable,
            Arguments = plan.RestartArguments,
            WorkingDirectory = Path.GetDirectoryName(plan.RestartExecutable) ?? plan.CompanionRoot,
            UseShellExecute = true,
        });
        BridgeConsole.WriteStatus("Updater", "companion restart requested", BridgeTone.Good);
    }

    private static bool TryParse(
        string[] args,
        out string planPath,
        out bool validateOnly,
        out int waitTimeoutMilliseconds)
    {
        planPath = string.Empty;
        validateOnly = false;
        waitTimeoutMilliseconds = 300000;
        for (int index = 0; index < args.Length; index++)
        {
            if (args[index] == "--plan" && index + 1 < args.Length)
            {
                planPath = args[++index];
            }
            else if (args[index] == "--validate-only")
            {
                validateOnly = true;
            }
            else if (args[index] == "--wait-timeout-ms" && index + 1 < args.Length
                && int.TryParse(args[++index], out int timeout) && timeout >= 1000 && timeout <= 1800000)
            {
                waitTimeoutMilliseconds = timeout;
            }
            else
            {
                return false;
            }
        }
        return !string.IsNullOrWhiteSpace(planPath);
    }
}
