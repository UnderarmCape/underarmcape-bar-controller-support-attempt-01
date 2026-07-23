# Context-Aware Hints

v0.8.1 adds a command-capability summary to the context snapshot instead of hiding hints with unit-name lists.

`ControllerCameraTestCommandCapabilitiesFromDescs(descs, hasSelection)` derives:

- build availability
- smart action availability
- tactical command availability
- stop, move, fight, patrol, guard, reclaim, repair, and attack command availability

The cache key combines selection revision and active command signature, so the summary is rebuilt when selected units or command descriptors change.

Hint cleanup:

- Back/View hold no longer advertises Guard/Patrol, Reclaim, Attack/Attack-Move, or Stop Selected.
- Toggle Mouse Mode remains.
- Normal Smart Action, Move/Build Path, Tactical Radial, and LB tactical hints check the capability fields before rendering.

This hides irrelevant movement, combat, reclaim, and build hints for inert structures while preserving valid builder, factory, combat, control-group, clear-selection, and mouse-mode hints.

