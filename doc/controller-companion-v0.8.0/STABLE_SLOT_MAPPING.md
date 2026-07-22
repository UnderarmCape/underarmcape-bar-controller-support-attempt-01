# Stable Slot Mapping

The hybrid wheel has eight positions. Slot 1 is top; 2-8 continue clockwise in the established v0.7 radial direction.

## Build/factory algorithm

1. Read the vanilla cell index and stable identity (`build:<unitDefID>`).
2. Choose the builder category, or the single `Factory` scope.
3. Seed the category's canonical position with the vanilla cell index.
4. Compute `page = floor((position - 1) / 8) + 1` and `slot = ((position - 1) % 8) + 1`.
5. Preserve empty positions. Never compact later familiar items merely because a selected builder lacks an earlier item.
6. Preserve focus by stable identity. If absent, choose the first valid item without retaining an old array index.

Factory/lab cell 1 always maps to page 1, slot 1. Builder contents retain vanilla order within the v0.7 category fallback.

## Conflicts and exceptions

BAR does not currently export a universal category/position table across every faction, constructor, and lab. The adapter caches the first vanilla position observed during the widget session. On a collision, it assigns the next free canonical position and marks `slotException`. On reload the cache is rebuilt deterministically from the active vanilla order.

Consequently, a unit whose vanilla position itself conflicts across labs may move after a reload that begins with a different lab. It never reshuffles frame-to-frame, and normal builder changes preserve the position already learned in that session.

## Tactical

Tactical items retain authoritative vanilla descriptor order inside Utility/Tactical. Tactical pages use the same eight-entry limit. Stable `cmd:<cmdID>` identity preserves focus across descriptor revisions; state choices use descriptor order and do not persist a separate mapping.

