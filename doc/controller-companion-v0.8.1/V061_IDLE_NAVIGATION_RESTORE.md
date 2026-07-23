# v0.6.1 Idle Navigation Restore

The idle source remains `WG.idlebuilders.controllerGetLiveIdleEntries()`.

D-pad Right and D-pad Left now apply the v0.6.1-style ordered-index traversal directly against that live snapshot:

- Read the ordered live idle entries.
- Find `ControllerCameraTestIdleCycle.currentUnitID`.
- If stale or missing, repair deterministically from `currentIndex`.
- Wrap with modulo behavior.
- Select the exact unit ID.
- Focus camera on that unit.
- Remember `currentUnitID`, `currentUnitDefID`, and `currentIndex`.

No mouse click simulation, vanilla click callback, or failed adapter route is used.

The LB+D-pad Down extension remains separate: it uses the remembered `currentUnitDefID`, selects only matching entries currently present in the idle snapshot, excludes non-idle same-type units, and keeps a sensible representative focus.

