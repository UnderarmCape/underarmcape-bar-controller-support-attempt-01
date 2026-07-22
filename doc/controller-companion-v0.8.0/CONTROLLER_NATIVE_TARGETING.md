# Controller Native Targeting

Status: **EXPERIMENTAL — NATIVE WIDGET, SMART ACTION, AND UI UNIFICATION TEST**

## Proven failure

The surviving area-confirmation failure was not another A/X release-latch problem. The first press produced a valid immutable anchor and the neutral transition armed `RESIZING_ARMED`. BAR could then clear `Spring.GetActiveCommand`. On the second A/X press, the camera still had the correct descriptor, anchor, cursor endpoint, and radius, but Order Menu re-ran `controllerGetActiveTargetDescriptor()` and rejected the dispatch as `active command changed`. The rejected path deliberately retained the preview, which is why the radius remained forever until B.

## Authoritative owner and cached descriptor

While a target operation is active, its registered command widget is the highest-priority A/X owner. Smart Area Reclaim owns Reclaim, Area Mex owns Area Mex, and Custom Formations owns its formation-capable commands; Order Menu is the explicit generic fallback. The camera only forwards buttons and the reticle hit. `ActiveCommandChanged` cannot replace an already validated owner descriptor.

Dispatch has one boundary:

1. `widgetHandler:CommandNotify` is attempted once, preserving Area Mex, Smart Area Reclaim, Commands FX, and other widget transformations.
2. If handled, dispatch stops.
3. Otherwise one `Spring.GiveOrder` (or one `CMD.INSERT`) fallback is attempted.

The owner copies the anchor once. Cursor and camera movement update only the endpoint/radius. Release only changes phase; it never issues. A→A, A→X, X→A, and X→X share the same release barriers and exactly-once dispatch guard. This remains **Press-to-Anchor, Press-to-Confirm Controller Targeting**.

## Transition trace

When Controller Debug is explicitly enabled, `ControllerCameraTestTraceNativeTarget` stores the last 16 transitions and emits one line per transition. Each line includes phase, engine-active ID, cached ID, A/X down and fresh-press state, owner, anchor, confirmation arm, and result. Events cover descriptor refresh/cache retention, anchor creation, confirm press, dispatch attempt/route, rejection, and cancellation. No per-frame logging occurs.

## Remaining native boundary

Target validation depends on BAR/Recoil command descriptors and the registered native owner. Controller routing applies no allegiance filter; engine/widget legality is authoritative. A command removed or disabled after anchoring is rejected safely. OS mouse emulation is not used. Point/unit/feature, area, front, rectangle, queue, and queue-front forms retain their native encodings.
