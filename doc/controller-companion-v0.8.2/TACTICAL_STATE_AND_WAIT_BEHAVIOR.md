# Tactical State And Wait Behavior

Move State/Hold Position is classified as `move_state_cycle`, matching Fire State's non-closing state family.

A cycles forward through Hold Position, Maneuver, Roam. X sends a reverse state delta. After each activation, Tactical remains open and the native model is refreshed.

Wait is classified as `wait_toggle`. It issues one Wait command, shows WAIT feedback, keeps Tactical open, and refreshes item state.
