# Companion Console Update Prompt Repair (v0.8.5) — Root Cause Investigation

## Summary of Observed Failure

When an update (e.g., v0.8.5) is detected by an installed v0.8.0 companion bridge, the console displays the `CONTROLLER SUPPORT UPDATE FOUND` panel. However:
1. Pressing Enter or any unsupported key appends another full update panel to the console output.
2. Pressing unsupported keys also redraws the entire panel.
3. The panel can be appended repeatedly without limit.
4. The user cannot type a normal line response (e.g., `Update now`, `Not now`) and press Enter.
5. The console interface appears frozen or broken.
6. Background engine/controller status messages interleave with and corrupt prompt output.
7. Installed v0.8.0 bridge cannot reliably perform self-updates.

---

## Detailed Code Path & Root Cause Findings

### 1. `Console.ReadKey` + Loop Redraw Pattern in `ControllerUpdateCoordinator`
In `ControllerUpdateCoordinator.cs`:
```csharp
while (true)
{
    ConsoleKey choice = BridgeConsole.ReadUpdateChoice(...);
    switch (ControllerUpdatePolicy.ResolvePromptAction(choice))
    {
        case ControllerUpdatePromptAction.Update: ...
        case ControllerUpdatePromptAction.NotNow: return false;
        case ControllerUpdatePromptAction.ViewNotes: WriteDetails(latest); break;
        case ControllerUpdatePromptAction.Recovery: ...
    }
}
```
Inside `BridgeConsole.ReadUpdateChoice`:
```csharp
return RunExclusive(() =>
{
    WriteBoxTitle("CONTROLLER SUPPORT UPDATE FOUND", BridgeTone.Warning);
    WriteLine(FormatRow("Installed", installedVersion), BridgeTone.Good);
    ...
    WriteLine(FormatOption("[U] Update now"), BridgeTone.Good);
    ...
    return Console.ReadKey(intercept: true).Key;
});
```

**Mechanism**:
- `ReadUpdateChoice` writes the complete 12-line border box to `Console.Out` on *every* call.
- `Console.ReadKey(intercept: true)` reads a single raw key stroke.
- When the user presses `Enter` (`ConsoleKey.Enter`), `ResolvePromptAction` returns `ControllerUpdatePromptAction.None`.
- The `while (true)` loop hits `default`/fallthrough and executes the next iteration.
- The next iteration calls `ReadUpdateChoice` again, which outputs the full 12-line update panel *again*.
- Every Enter press appends another full update box to standard output.

---

### 2. Lack of Line-Based Input Processing
- `ReadUpdateChoice` relied exclusively on `Console.ReadKey(intercept: true).Key`.
- It did not support line-based input (`ReadLine`) or string trimming.
- Users typing full word responses (e.g., `Update now`, `Not now`, `Release notes`, `Recovery Mode`) or pressing Enter after `U`/`N`/`V`/`R` had their input fragmented into individual keystrokes, causing invalid choice evaluation and multiple panel redraws.

---

### 3. Competing Background Output
- `Program.cs` runs a 120Hz UDP and 500ms engine session monitoring loop.
- When engine status changes (e.g. Spring/Recoil process attach/detach) or controller connection status changes, `Program.cs` invokes `BridgeConsole.WriteStatus(...)`.
- `WriteStatus` writes directly to standard output while the user is sitting at a prompt, interleaving log lines into the middle of the prompt border box or after the prompt text.

---

### 4. Nested Input Readers in Recovery Mode and Release Notes
- Selecting `View Release Notes` (`V`) invoked `WriteDetails(latest)` and then looped back to `ReadUpdateChoice`, immediately appending another full update panel below the release notes.
- Selecting `Recovery Mode` (`R`) called `RunRecoveryModeAsync`, which invoked `BridgeConsole.ReadRecoveryChoice`. `ReadRecoveryChoice` ran its own `Console.ReadKey` loop (a secondary nested stdin reader). When Recovery Mode exited, `CheckAndPromptAsync` looped back and rendered another update panel.

---

### 5. Unsynchronized Background Check Spawning & Duplicate Prompts
- `UpdateService.StartBackgroundStartupCheck` launches `ControllerUpdateCoordinator.StartPeriodicCheck(requestCompanionExit)` (a 6-hour recurring timer).
- Additionally, CLI commands (`check`, startup options) trigger `CheckAndPromptAsync`.
- The simple `int promptActive` flag was insufficiently guarded against racing background/startup tasks, and there was no process-wide tracking of dismissed release tags (`dismissedReleaseTag`), allowing repeated checks to re-prompt for the same release within the same bridge session.

---

### 6. Failure in Noninteractive / Redirected Environments
- In automated test runs or headless environments where `Console.IsInputRedirected` or `Console.IsOutputRedirected` is true, attempting interactive `Console.ReadKey` calls threw `InvalidOperationException` or blocked execution.

---

## Former Stdin Readers Audit

| File | Method | Operation | Impact |
|---|---|---|---|
| `BridgeConsole.cs` | `ReadUpdateChoice` | `Console.ReadKey(intercept: true)` | Read single keystroke for update choice; forced full panel redraw on invalid/Enter key |
| `BridgeConsole.cs` | `ReadRecoveryChoice` | `Console.ReadKey(intercept: true)` | Read single keystroke for recovery menu; created nested reader |
| `BridgeConsole.cs` | `ConfirmReleaseAction` | `Console.ReadKey(intercept: true)` | Read single keystroke confirmation; uncoordinated output |
| `UpdateService.cs` | `UpdateApplicationAsync` | `Console.ReadLine()` | Read line input directly without coordinator |
