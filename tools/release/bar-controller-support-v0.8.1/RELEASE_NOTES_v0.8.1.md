# BAR Controller Support v0.8.1

Experimental repair release for controller input on the native BAR UI integration branch.

## Fixes

- Disassemble Mode now uses the same one-shot Reclaim executor as Back/View + D-pad Down for target units and features.
- Disassemble X uses pending short/hold behavior: short release reclaims a valid target, while hold still starts Move path/line behavior.
- Disassemble LB+A no longer builds a separate multi-target reclaim route for a single target.
- B cancel/clear actions no longer accidentally arm or trigger double-B exit.
- A double-tap selection ignores transient empty reticle observations and keeps exact single-tap selection deterministic.
- Idle unit next/previous navigation remembers the current live-list index so removed or busy units repair predictably.
- Hints are capability-aware and no longer advertise inconsistent Back/View-held Guard/Reclaim/Attack/Stop commands.
- Self Destruct remains routed through the protected safety implementation and is represented as a disabled radial item when unavailable.
- Mixed build/factory radial sector labels have brighter category colors and a dark shadow for readability.
- Build/factory radial center affordability text is smoothed once per second, while disabled and unaffordable overlays remain immediate.

## Validation

This package is validated through Lua parse checks, focused controller UI harnesses including `Test-ControllerV081DisassembleIdleHints.lua`, .NET companion/update/release tests, manifest/package SHA-256 verification, public deployment validation, and strict rollback validation.

Native overrides remain pinned to the tested BAR build family and may require rebasing after upstream BAR UI changes.
