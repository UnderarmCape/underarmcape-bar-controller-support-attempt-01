# Double Tap Same Target

v0.8.3 keeps same-type selection expansion available when both taps are over the exact same owned unit ID.

- The first tap may change selection without invalidating the second tap candidate.
- A transient nil hover between the two taps does not clear the candidate inside the double-tap window.
- Expansion is still restricted to visible, alive, own-team units with the same UnitDefID.
- Units do not need to overlap on screen.

Manual check: single tap a visible own unit, then tap the same unit again within the double-tap window. All visible own units of that UnitDef should be selected.
