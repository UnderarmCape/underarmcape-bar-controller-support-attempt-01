# Native area-command owners

This experiment keeps the camera widget as an input/reticle adapter. The widget
that owns a BAR command owns its descriptor, target lifecycle, preview, and
final confirmation through `controller_native_command_owner.lua`. Final orders
cross one Order Menu boundary: `CommandNotify` once, then `Spring.GiveOrder`
only when no widget handled the command.

| Command family | Authoritative owner | Controller behavior |
| --- | --- | --- |
| Reclaim unit/feature/area | Smart Area Reclaim | Native eligibility, native area preview, one confirmation |
| Area Mex | Area Mex | Native spot/build executor receives `{x,y,z,radius}` |
| Move/Fight/Attack/Patrol/Unload/Set Target/Manual Launch fronts | Custom Formations | Native formation dots and assignment algorithm |
| Repair/Resurrect/Restore/Capture/Guard/Load/Unload/Attack areas | Order Menu generic owner | Live descriptor type drives anchor and params |
| Point/unit/map commands | Order Menu generic owner | Live descriptor and engine legality remain authoritative |

All four confirmation combinations are valid after the release barrier: A→A,
A→X, X→A, and X→X. A command-radial confirmation cannot leak into the first
world anchor. Queue persistence recreates the same descriptor only after a
successful dispatch and ends when RT is released. B cancels without issuing.

Fallback ownership is explicit: if no registered command widget claims the
live command ID, Order Menu owns the operation. The camera never reconstructs
the final command parameters or sends a duplicate fallback order.
