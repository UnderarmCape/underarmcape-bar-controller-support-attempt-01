# Controller Native Targeting

Status: **EXPERIMENTAL — INPUT STATE, FACTORY SHORTCUT, AND VANILLA DISASSEMBLE TEST**

## Root cause and repair

BAR's Tactical Radial correctly activated a real Recoil command descriptor. The controller bridge, however, modeled target geometry without modeling input ownership. The same A/X edge domain selected the radial command, anchored an area, and confirmed it. There was no proof that the radial-confirm press had been released and no explicit neutral transition after anchoring. Consequently the active command could inherit stale A/X ownership and the second press was never reliably armed. The area preview also relied only on a mutable anchor table, which made the fixed-center contract difficult to verify.

The repaired state machine separates command mode from input phase:

- `WAITING_FOR_FRESH_INPUT` rejects the radial-confirm cycle until both A and X are observed neutral.
- `WAITING_FOR_ANCHOR_PRESS` accepts the first fresh A or X press.
- `WAITING_FOR_ANCHOR_RELEASE` stores immutable `anchorX`, `anchorY`, and `anchorZ` and rejects confirmation.
- `RESIZING_ARMED` is entered only after neither A nor X is held.
- `POINT_TARGETING` handles fresh point, unit, and feature presses.
- `BUILD_PLACEMENT` remains delegated to the existing placement owner.

This is **Press-to-Anchor, Press-to-Confirm Controller Targeting**. Release is only a state transition; it never dispatches.

## Fixed-anchor semantics

The first fresh A/X press copies the current controller-cursor world coordinates once. Preview radius is always the distance from those stored coordinates to the current cursor. Camera motion may move the cursor and therefore resize the radius, but cannot translate the stored center. The preview and eventual command parameters read the same anchor and radius fields.

After anchoring, both buttons must be neutral once. A new A or X edge may then confirm, independent of which button anchored. A→A, A→X, X→X, and X→A are equivalent. One accepted confirmation passes through the Order Menu dispatch boundary exactly once.

## Native dispatch boundary

The patched Order Menu exports the descriptor reconciled from `Spring.GetActiveCommand`, `Spring.GetActiveCmdDesc`, and the authoritative visible command list. `controller_native_targeting.lua` builds the native point, unit, feature, area, front, or rectangle parameter form. Dispatch first calls `widgetHandler:CommandNotify`; a handling widget prevents engine fall-through. Otherwise one `Spring.GiveOrder` is issued.

Recoil does not expose the internal C++ `GuiHandler::GetCommand` resolver to Lua, so the bridge performs structural and alliance checks while BAR command widgets and synced command AI remain authoritative. It never uses OS mouse emulation.

## B and build-placement priority

Active targeting and placement own B before generic selection clearing. Target cancellation clears the command, anchor, and preview, snapshots and verifies vanilla selection, and arms a B-release latch.

The build-placement failure had a separate native cause: `Spring.SetActiveCommand(0)` treats zero as a real command-descriptor index, not a cancellation sentinel. Because that call succeeded, the fallback cancellation never ran. Placement now always calls `Spring.SetActiveCommand(nil)`, clears all preview/drag/rotation/Grid state, resets to Single, restores the constructor snapshot only if needed, and consumes the entire B cycle.

## Persistence and mode exclusivity

Without RT, successful targeting clears the active descriptor. With RT append held, the descriptor is rearmed behind a new fresh-input gate and remains active until RT release. Native Experimental alone owns this bridge. Switching to Legacy cancels targeting, resets A/X/B and LB/RB gates, closes radials, resets placement, clears stale anchors, and preserves selection.

## Command coverage and exceptions

Attack, Guard, Repair, Reclaim, Restore, Capture, Set Target, Move, Patrol, Fight, Manual Fire, Area Mex, Smart Area Reclaim, and exposed point/unit/feature/area/front/rectangle descriptors retain native dispatch. Negative build descriptors remain in build placement. Immediate state commands such as Fire State, Move State, Queue Mode, and Visible/Cloak remain state-command operations and do not capture world targeting.
