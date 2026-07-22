# Controller Native Targeting

Status: **EXPERIMENTAL — AREA CONFIRMATION, DISASSEMBLE, AND HINT POLISH TEST**

## Proven failure

The surviving area-confirmation failure was not another A/X release-latch problem. The first press produced a valid immutable anchor and the neutral transition armed `RESIZING_ARMED`. BAR could then clear `Spring.GetActiveCommand`. On the second A/X press, the camera still had the correct descriptor, anchor, cursor endpoint, and radius, but Order Menu re-ran `controllerGetActiveTargetDescriptor()` and rejected the dispatch as `active command changed`. The rejected path deliberately retained the preview, which is why the radius remained forever until B.

## Authoritative owner and cached descriptor

While an area operation is anchored, the camera targeting bridge is the highest-priority A/X owner. `ActiveCommandChanged` is recorded but cannot replace the already validated controller descriptor. Final A/X calls Order Menu once with the cached descriptor and encoded parameters. Order Menu accepts that cache only when its current authoritative command model still contains the same enabled command ID.

Dispatch has one boundary:

1. `widgetHandler:CommandNotify` is attempted once, preserving Area Mex, Smart Area Reclaim, Commands FX, and other widget transformations.
2. If handled, dispatch stops.
3. Otherwise one `Spring.GiveOrder` (or one `CMD.INSERT`) fallback is attempted.

The anchor is copied once. Cursor and camera movement update only the endpoint/radius. Release only changes phase; it never issues. This remains **Press-to-Anchor, Press-to-Confirm Controller Targeting**.

## Transition trace

When Controller Debug is explicitly enabled, `ControllerCameraTestTraceNativeTarget` stores the last 16 transitions and emits one line per transition. Each line includes phase, engine-active ID, cached ID, A/X down and fresh-press state, owner, anchor, confirmation arm, and result. Events cover descriptor refresh/cache retention, anchor creation, confirm press, dispatch attempt/route, rejection, and cancellation. No per-frame logging occurs.

## Remaining native boundary

Target validation still depends on BAR/Recoil command descriptors and the Order Menu command model. Recoil's deeper `GuiHandler::GetCommand` validation remains an engine boundary rather than a Lua API. A command removed or disabled after anchoring is rejected safely. OS mouse emulation is not used. Point/unit/feature, area, front, rectangle, queue, and queue-front forms retain their existing encodings.
