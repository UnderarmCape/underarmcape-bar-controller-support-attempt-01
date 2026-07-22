# Vanilla control groups

Controller hot slots are projections of Recoil control groups 1–9 and 0 (slot
10). Membership is read with `Spring.GetGroupUnits`; replace, add, remove, and
clear use `Spring.SetUnitGroup`. Keyboard-created groups therefore appear in
controller overlays and controller-created groups remain available to keyboard
hotkeys.

The former controller-only membership table is no longer authoritative and
finished units are not auto-added. A one-time migration reads legacy saved
memberships only when the corresponding native group is empty. Populated
native groups are never overwritten. Migration completion and status are
persisted for diagnostics.
