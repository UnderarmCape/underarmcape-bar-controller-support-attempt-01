# Build and Factory Radial Compaction

Status: **EXPERIMENTAL — V0.7 TACTICAL RESTORE, MIXED RADIAL SECTORS, NATIVE CELLS, AND IDLE CONTROL TEST**

## Authoritative source

The patched vanilla Build Menu exports its already-authoritative current cells. The controller adapter never invents availability and never scans absent unit IDs. Any exported command remains a radial item even when it is unaffordable, temporarily disabled, queue-limited, or unavailable in the current state. A command absent from the vanilla export is absent from the radial.

## Builder algorithm

For each exported builder item, the adapter keeps the stable unit/command key, source index, availability metadata, cost, icon, and native cell identity. It classifies present items into the fixed Economy, Build, Utility, Combat sequence.

The ordered category runs are concatenated and packed globally. Dynamic programming fixes the minimal page count first, then chooses deterministic boundaries that avoid one-item mixed sectors and extremely uneven sparse pages when possible. Slot 1 remains the established top position. No empty category is emitted, no page is empty, and the model publishes exact `itemCount`, `categoryCounts`, `pageCount`, page entries, and sector boundaries.

## Factory/lab algorithm

Factories and labs classify the unmodified vanilla command list into Constructors, Utility, and Combat. Mobile builders are Constructors; scouts, transports, sensors, and unarmed support are Utility; direct-combat units are Combat. Units the factory cannot produce reserve nothing.

## Focus and navigation

The adapter preserves `selectedStableKey` if that real command still exists after a rebuild. If it disappeared, focus moves directly to the first present item. The camera then sends that stable key back to the vanilla blue focus stroke. It never keeps an obsolete absolute slot.

RB/LB use the global page list and wrap. Analog selection sees only real compact items. Every page change focuses its first valid slot and synchronizes the native stable key.

## Invariants

- Radial item count equals the authoritative present-command count.
- Every radial item maps to one exported vanilla command/cell.
- Every exported item with a stable command identity maps to one radial item.
- Present items occupy consecutive slots within each page.
- No category or page has zero items.
- Page count is the global minimum `ceil(itemCount / 8)`.
- Stable relative vanilla order is preserved within each category.
- Disabled/unaffordable present entries remain visible and retain their availability reason.

Tactical Utility/Tactical categories are unchanged; this compaction applies only to Build and Factory/Lab models.
