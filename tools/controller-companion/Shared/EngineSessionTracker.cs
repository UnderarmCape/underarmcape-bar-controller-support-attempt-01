using System;
using System.Collections.Generic;
using System.Linq;

internal sealed class EngineProcessSnapshot
{
    public int ProcessId { get; set; }
    public string ProcessName { get; set; } = string.Empty;
    public DateTime StartedUtc { get; set; }
}

internal sealed class EngineSessionTracker
{
    private readonly TimeSpan transitionGrace;
    private int? trackedProcessId;
    private DateTime trackedStartedUtc;
    private DateTime? missingSinceUtc;

    public EngineSessionTracker(TimeSpan transitionGrace)
    {
        this.transitionGrace = transitionGrace;
    }

    public bool HasAttached { get; private set; }
    public bool ShouldStop { get; private set; }
    public int? TrackedProcessId => trackedProcessId;

    public string Observe(DateTime nowUtc, IEnumerable<EngineProcessSnapshot> snapshots)
    {
        if (ShouldStop) return "session already closed";
        List<EngineProcessSnapshot> engines = snapshots
            .Where(item => IsEngineName(item.ProcessName))
            .OrderByDescending(item => item.StartedUtc)
            .ThenByDescending(item => item.ProcessId)
            .ToList();

        if (!HasAttached)
        {
            EngineProcessSnapshot? first = engines.FirstOrDefault();
            if (first == null) return "waiting for Spring/Recoil";
            Attach(first);
            return "attached to " + first.ProcessName + " PID " + first.ProcessId;
        }

        EngineProcessSnapshot? tracked = engines.FirstOrDefault(
            item => item.ProcessId == trackedProcessId);
        if (tracked != null)
        {
            missingSinceUtc = null;
            return "tracking PID " + trackedProcessId;
        }

        if (missingSinceUtc == null) missingSinceUtc = nowUtc;
        EngineProcessSnapshot? replacement = engines.FirstOrDefault(
            item => item.StartedUtc >= trackedStartedUtc);
        if (replacement != null)
        {
            Attach(replacement);
            return "followed Spring/Recoil transition to PID " + replacement.ProcessId;
        }

        if (nowUtc - missingSinceUtc.Value < transitionGrace)
        {
            return "tracked engine exited; waiting for bounded transition";
        }

        ShouldStop = true;
        return "tracked Spring/Recoil session exited";
    }

    public static bool IsEngineName(string processName)
    {
        string name = processName ?? string.Empty;
        return name.IndexOf("spring", StringComparison.OrdinalIgnoreCase) >= 0
            || name.IndexOf("recoil", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private void Attach(EngineProcessSnapshot process)
    {
        trackedProcessId = process.ProcessId;
        trackedStartedUtc = process.StartedUtc;
        missingSinceUtc = null;
        HasAttached = true;
    }
}
