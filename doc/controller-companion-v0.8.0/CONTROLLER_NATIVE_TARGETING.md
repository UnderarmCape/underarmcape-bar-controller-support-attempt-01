# Controller native targeting

Native Experimental uses hybrid targeting. BAR's current Order Menu descriptor is captured while it is live; after capture, `Spring.GetActiveCommand()` is not a prerequisite. The camera owns first A/X, the neutral release barrier, reticle geometry, second A/X, preview, and B cancellation.

The pure `controller_native_targeting.lua` state machine classifies point, circular area, front, rectangle, and build descriptors. Areas encode `{x,y,z,r}`. Fronts and rectangles encode `{x1,y1,z1,x2,y2,z2}`. A five-parameter same-type reclaim is assembled only by the Smart Reclaim adapter. Build descriptors remain in the existing placement system.

On completion, Order Menu revalidates command identity against its current command model, calls `CommandNotify` once, and performs one direct fallback only when unhandled. The one-shot camera guard prevents Smart X, normal A selection, or a retired owner session from also issuing.

Input priority is controller target → placement → radials → Disassemble → normal A/X. Native panel visibility does not affect the retained descriptor or controller preview. B clears geometry, preview, highlights, and Disassemble substate and arms the normal cancel-release latch.
