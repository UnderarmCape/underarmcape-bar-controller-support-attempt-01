# Console Input Coordinator (`CONSOLE_INPUT_COORDINATOR.md`)

## Overview

The `ConsoleInteractionCoordinator` is the sole owner of stdin and synchronized stdout rendering across the entire BAR Controller Companion process.

## Key Abstractions

- `IConsoleInput`: Abstraction for reading input lines (`ReadLine()`) and checking stdin redirection.
- `IConsoleOutput`: Abstraction for writing output lines and formatted status text.
- `IConsoleSession`: Interface passed to prompt handlers and interactive subsystems to enforce single-owner interaction.
- `ConsoleInteractionCoordinator`: Process-wide singleton implementing `IConsoleSession` with locks for thread-safe input reading and status output pausing/flushing.

## Prompt States

State transitions are strictly serialized using `ConsolePromptState`:
- `None`
- `UpdateChoice`
- `ReleaseNotes`
- `RecoveryBrowser`
- `Confirmation`
- `Installing`
- `Restarting`
- `ShuttingDown`

While in an interactive state (`UpdateChoice`, `ReleaseNotes`, `RecoveryBrowser`, `Confirmation`, `Installing`), noncritical status output from background tasks (such as engine process polling or controller connection status) is buffered/coalesced. When returning to state `None`, status is flushed and normal output resumes cleanly.
