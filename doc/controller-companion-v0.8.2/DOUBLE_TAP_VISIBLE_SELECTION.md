# Double Tap Visible Selection

Double-tap A no longer depends on cursor proximity or overlapping unit models.

`ControllerCameraTestCollectVisibleOwnedSameType(unitDefID)` enumerates the local player's authoritative team units, filters by matching UnitDefID, intersects the visible list when available, checks on-screen placement, sorts IDs, and selects the resulting set.

Enemies, allied teammate units, off-screen units, and different UnitDefIDs are excluded.
