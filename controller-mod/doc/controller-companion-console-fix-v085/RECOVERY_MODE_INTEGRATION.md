# Recovery Mode Integration (`RECOVERY_MODE_INTEGRATION.md`)

## Design & Single Reader Rules

- Recovery Mode uses the shared `ConsoleInteractionCoordinator` instance (`IConsoleSession`).
- It does **not** create a second or nested stdin reader (`Console.ReadKey`).
- When opened from the update choice prompt (`R`), prompt state transitions to `ConsolePromptState.RecoveryBrowser`.
- Page navigation (`N` for next, `P` for previous) and option selection (numbers 1-9) operate via line input.
- Exiting Recovery Mode (`B` for back, `Q` for quit) returns session state to `ConsolePromptState.UpdateChoice` (or `ConsolePromptState.None` if exiting entirely), without recursively appending update panels or restarting network checks.
