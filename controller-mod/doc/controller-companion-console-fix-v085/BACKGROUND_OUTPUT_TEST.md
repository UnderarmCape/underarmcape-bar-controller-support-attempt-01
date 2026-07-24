# Background Output Collision Test Evidence

- Active Prompt State: `ConsolePromptState.UpdateChoice`
- Triggered Events: Controller connected, Engine attached (PID 101), Engine exited.
- Result: 0 status lines interleaved during prompt. Coalesced status flushed once upon prompt exit.
