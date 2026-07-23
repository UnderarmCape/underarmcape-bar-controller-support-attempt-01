# Controller Double-Tap Selection

Root cause: the double-tap candidate could be cleared by transient empty controller reticle observations between the first release and the second press. Live reticle updates can briefly report nil even while the visible cursor still rests on the intended unit.

Repair:

- `controller_selection_taps.lua` now ignores nil/empty observations instead of resetting the pending candidate.
- Normal A captures `area.pressTargetID` and `area.pressUnitDefID` on press.
- A release uses the captured unit when the release trace is empty.
- `attemptReticleSelection(forcedUnitID)` still applies friendly ownership and safe-selectability checks before selecting.

Rules:

- Single A selects the exact hovered owned unit.
- Double-tap A within the configured window expands to visible same-type owned units.
- Off-screen units, enemy units, allied teammate units, invalid units, dead units, and different UnitDefIDs are excluded.
- Hold-A area select and RT+A additive/toggle selection do not enter the double-tap expansion path.

