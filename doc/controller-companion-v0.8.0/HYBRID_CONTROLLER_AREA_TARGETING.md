# Hybrid controller area targeting

Status: **EXPERIMENTAL — HYBRID AREA TARGETING, GLOBAL RADIAL PAGING, AND VANILLA IDLE CONTROL TEST**

The restored gesture is based on the controller-owned staged targeting introduced in commit `3e2be6a738` (`ControllerCameraTestStagedTacticalCommand`, `ControllerCameraTestStartAreaReclaim`, and their update/confirm paths). Its proven anchor → release → resize → fresh-confirm behavior was retained. The obsolete command-specific dispatch code and pre-native radial models were not restored.

Current Native Experimental mode uses one state machine in `controller_native_targeting.lua` for circular areas, fronts, and rectangles. The camera captures a currently valid BAR descriptor, clears the engine mouse command, owns A/X, stores immutable anchor coordinates, waits until A and X are neutral, updates geometry from the reticle, and accepts a fresh A or X as confirmation. B resets the state. Release cannot dispatch. Build placement remains delegated to its existing path.

Ownership is intentionally split:

| Controller owns | BAR/native widgets own |
| --- | --- |
| input edges, anchor, release gate, geometry, preview, cancel | descriptors, availability, validation, command parameter semantics |
| second A/X and the one-shot dispatch guard | Area Mex and Smart Reclaim transformations, `CommandNotify`, engine fallback |

`gui_ordermenu.lua:controllerCompleteTargetShape` is the final boundary. It revalidates the captured command ID against the current Order Menu model, calls `widgetHandler:CommandNotify` once, and calls `Spring.GiveOrder` or `CMD.INSERT` once only if unhandled. The retired controller-to-mouse owner APIs remain for compatibility but the camera never starts or feeds them.

The camera draws the only active controller preview. Area previews use the completed center/radius; front and rectangle previews use the completed two endpoints. Disassemble same-type uses the green reclaim profile. Because the native owners are never started, their mouse previews remain inactive.

Transition diagnostics are edge-only: `TARGET STATE CREATED`, `CONTROLLER OWNS SHAPE`, `ANCHORED`, `FINAL DISPATCH STARTED`, `NATIVE TRANSFORM CALLED`, accepted/rejected completion, and cancellation. There is no per-frame log.

Limitations: final target legality remains intentionally native, so an engine or widget may reject a geometrically valid controller shape. Runtime gameplay still needs the 43-step live checklist; static tests prove state and dispatch structure, not map-specific command acceptance.
