# Build and Factory Radial Compaction

Status: **EXPERIMENTAL — NATIVE CONTROLLER TARGETING AND COMPACT RADIAL TEST**

## Authoritative source

The patched vanilla Build Menu exports its already-authoritative current cells. The controller adapter never invents availability and never scans absent unit IDs. Any exported command remains a radial item even when it is unaffordable, temporarily disabled, queue-limited, or unavailable in the current state. A command absent from the vanilla export is absent from the radial.

## Builder algorithm

For each exported builder item, the adapter keeps the stable unit/command key, source index, availability metadata, cost, icon, and native cell identity. It classifies present items into the stable Economy, Combat, Defense, Utility, Build, Production, Special, or extra category sequence.

Each non-empty category is then packed independently in source order:

- compact position `n` maps to page `floor((n - 1) / 8) + 1`;
- slot maps to `((n - 1) % 8) + 1`;
- slot 1 remains the established top position;
- page count is `ceil(present category items / 8)`.

No empty category is emitted. No empty or trailing page is possible. No absent global canonical position reserves a blank slot. The model publishes exact `itemCount`, `categoryCounts`, and `pageCounts` invariants for validation.

## Factory/lab algorithm

Factories and labs use one non-empty `Factory` scope and retain vanilla source order. Present vanilla cell 1 is the first source item and therefore top radial slot 1. Later present cells fill consecutive slots and pages. Units the factory cannot produce reserve nothing.

## Focus and navigation

The adapter preserves `selectedStableKey` if that real command still exists after a rebuild. If it disappeared, focus moves directly to the first present item. The camera then sends that stable key back to the vanilla blue focus stroke. It never keeps an obsolete absolute slot.

D-pad/category and LB/RB navigation use the emitted non-empty category list. A direct D-pad category that does not exist is ignored; page cycling skips it because it is not in the model. Analog selection sees only real compact items.

## Invariants

- Radial item count equals the authoritative present-command count.
- Every radial item maps to one exported vanilla command/cell.
- Every exported item with a stable command identity maps to one radial item.
- Present items occupy consecutive slots within each page.
- No category or page has zero items.
- Page count is derived independently per category.
- Stable relative vanilla order is preserved within each category or factory.
- Disabled/unaffordable present entries remain visible and retain their availability reason.

Tactical Utility/Tactical categories are unchanged; this compaction applies only to Build and Factory/Lab models.
