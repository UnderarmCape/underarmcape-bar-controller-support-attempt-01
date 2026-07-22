# Controller Native Targeting

Status: **EXPERIMENTAL — NATIVE CONTROLLER TARGETING AND COMPACT RADIAL TEST**

## Root cause

The hybrid Tactical Radial correctly called BAR's Order Menu activation API, which selected a real Recoil command descriptor with `Spring.SetActiveCommand`. The remaining confirmation path was engine mouse input: Recoil's C++ `GuiHandler::MousePress`/`MouseRelease` resolves a target, constructs command-type-specific parameters, calls LuaUI `CommandNotify`, gives the command, and finishes or persists the active command. Controller A/X never entered that mouse path, so the native cursor was active but no target could be placed.

Recoil does not expose `GuiHandler::GetCommand` or safe synthetic engine mouse presses to Lua. This experiment therefore does not emulate an operating-system mouse. It uses the real active descriptor, mirrors Recoil's documented command parameter shapes, preserves the LuaUI `CommandNotify` boundary, and lets the synchronized unit command AI remain the final authority on target acceptance.

## Architecture

The production path has three owners:

1. BAR's patched Order Menu activates a real descriptor and exports the descriptor returned by `Spring.GetActiveCommand`/`Spring.GetActiveCmdDesc`. The export is reconciled against the current non-disabled Order Menu command list.
2. `controller_native_targeting.lua` is a Spring-independent state machine. It classifies the descriptor and builds point, unit, feature, area, front, or rectangle parameters from the controller reticle.
3. The camera widget owns A/X/B only while that targetable descriptor is active. It asks the Order Menu to dispatch once. The Order Menu first calls `widgetHandler:CommandNotify`; a handling widget such as Area Mex or Smart Area Reclaim prevents engine fall-through. Otherwise it calls `Spring.GiveOrder` once.

This keeps vanilla availability, descriptor identity, cursor state, command widgets, Commands FX, selected units, and synchronized command AI authoritative. The active descriptor is refreshed on `ActiveCommandChanged` and explicit activation, not reconstructed every frame.

## States and controls

- `IDLE`: normal A selection, Smart X, and normal B clear-selection behavior.
- `POINT_TARGETING`: A or X confirms the current unit, feature, or ground target. B cancels without altering selection.
- `CONTROLLER_AREA_TARGETING`: the first A/X press latches the ground center; cursor distance updates the radius; the second A/X press confirms. Button release never confirms.
- `FRONT_TARGETING`: the first A/X press latches point one and the second emits two XYZ points.
- `BUILD_PLACEMENT`: delegated to the existing v0.7 placement flow.

For unit-or-map and unit-or-area descriptors, a real unit hit keeps the unit-ID form. Unit-feature-area descriptors use Recoil's feature-ID convention selected by the live engine capability. Guard and Repair reject non-allied direct unit hits before dispatch. Other command-specific rules are enforced by the command widget or synchronized command AI.

## Area targeting

The workflow is **Press-to-Anchor, Press-to-Confirm Controller Targeting**:

1. Select an area descriptor in Tactical with A or X.
2. Move the native controller cursor to the center and press A or X once.
3. Release the button; no command is emitted.
4. Move the cursor. The anchor stays fixed and the sole controller-owned circle/line preview follows the exact stored radius/end point. The engine's active command cursor and native target highlights remain active.
5. Press A or X again. One command reaches either its `CommandNotify` handler or Recoil.

For descriptors with one numeric parameter, the radius is capped at that descriptor maximum, matching Recoil's `ICON_AREA` construction rule. A zero-size area/front/rectangle is rejected and remains active. B clears the anchor, preview, and active descriptor while preserving the vanilla selection.

## Persistence and modifiers

Without RT, a successful target clears the active descriptor and A/X ownership immediately. The next clean X press is Smart X. With RT append held, `shift` is passed to the command and the real descriptor remains active for repeated placement; releasing RT ends controller persistence. The existing insert modifier dispatches one `CMD.INSERT` order when no widget consumes the original command. A widget-consumed command remains single-dispatch and owns its native semantics.

## B priority and selection

B is evaluated in this order: controller area target, native point/unit target, build placement, Tactical sub-radial, parent radial/menu, then normal selection clearing. Cancellation snapshots the safe vanilla selection, performs the cancellation, compares the resulting selection, and restores only if it changed. A shared release latch prevents one B cycle from both cancelling and later clearing selection.

Build placement also snapshots selection. A and X both place while placement remains active; B exits, resets Grid to Single, restores constructors if necessary, and requires B release before normal clear-selection is eligible.

## Native and Legacy modes

The bridge runs only in `Native Experimental`. `Legacy Controller UI` retains the v0.7 path. Switching modes cancels the engine command and controller anchor, closes both radials, resets placement and input latches, and preserves selection, so the two paths cannot issue the same order.

## Exceptions and limitations

- Negative build descriptors stay in the existing build-placement adapter; the Order Menu bridge does not recreate build placement.
- Immediate state commands (`ICON_MODE`, Fire State, Move State, Visible/Cloak) remain descriptor-owned Order Menu operations and never capture target input.
- Recoil's C++ pre-command `GuiHandler::GetCommand` validator is not callable from Lua. Lua performs structural and obvious alliance validation; BAR `CommandNotify` widgets and synchronized command AI provide the authoritative final rejection. An invalid target leaves targeting active when it can be rejected before dispatch.
- Front and unit-or-rectangle descriptor shapes are supported, but must be manually exercised if a live selected unit exposes them. No known vanilla command is intentionally left mouse-only.

Engine references: [Recoil Lua API](https://recoilengine.org/docs/lua-api/), [Spring command types](https://springrts.com/wiki/Lua_CMDs).
