# Disassemble Reclaim Ordering

The star path came from sorting targets by unit ID and sending every target, in that same order, to every cached constructor. IDs carry no spatial meaning and duplicate the entire route across builders.

Selected-target batches now use deterministic constructor-aware nearest-frontier planning:

1. Constructors and targets are deduplicated; invalid and cached-constructor targets are excluded.
2. Every route starts at its constructor position.
3. The globally nearest route-frontier/remaining-target pair is selected.
4. Ties use constructor ID, then target ID.
5. The target is assigned once, the route frontier moves to it, and planning repeats.
6. Each constructor receives its own first order without Shift and only its later local orders with Shift.

This begins near each constructor, walks adjacent targets, distributes work, and prevents duplicate full sequences.

Same-type area reclaim does not enumerate units. It uses Smart Area Reclaim’s native five-parameter same-type area command through the exact native helper, allowing Recoil/BuilderCAI to own area ordering. A successful native or explicit dispatch resets the inactivity clock; zero accepted orders do not. Constructors are restored after dispatch.
