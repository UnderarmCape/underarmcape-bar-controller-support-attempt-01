# Controller Selection Taps

`luaui/Include/controller_selection_taps.lua` owns the 0.35-second controller tap candidate. It records the exact unit and UnitDefID and never reads mouse click state.

- Single A selects the exact owned unit under the reticle.
- A second compatible A selects currently visible, on-screen, locally owned units with the same UnitDefID.
- Enemy, allied-teammate, different-type, and off-screen units are excluded.
- Hold A resets the candidate and continues into the area brush.
- RT+A resets the candidate and preserves exact-unit additive/toggle behavior.

Pregame/mouse mode, modals, targeting, modifiers, selection cancellation, incompatible targets, and timeout reset or expire the candidate.
