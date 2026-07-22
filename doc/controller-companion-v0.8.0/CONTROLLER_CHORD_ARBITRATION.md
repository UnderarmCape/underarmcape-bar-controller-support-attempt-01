# Controller Chord Arbitration

LB-held + RB owns one press/release candidate at a time. RB release, not release of both shoulders, rearms the state machine. The user may therefore keep LB held and repeatedly tap RB; every distinct RB cycle advances Move State once. Held RB cannot repeat, every press restarts the timer, and a completed long action suppresses the short action.

The long action is latched from context when RB is pressed:

1. An open Factory/Lab radial owns Queue Mode.
2. Active Disassemble owns disable unless Factory/Lab has already claimed the context.
3. A valid selected reclaim-capable non-factory constructor owns enable Disassemble.
4. Empty, combat-only, factory-without-radial, and other unsupported contexts own no long action and remain silent.

Move State reads the first selected unit with a real Move State descriptor, computes one next state, and applies it to every capable selected unit without changing selection. Unsupported units are skipped and `Move State Unavailable` is never shown. LB+B Stop retains higher priority than Disassemble double-B.
