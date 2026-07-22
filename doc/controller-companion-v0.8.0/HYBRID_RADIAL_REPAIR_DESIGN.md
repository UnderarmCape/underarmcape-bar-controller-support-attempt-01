# v0.8.0 Hybrid Radial Repair Design

Status: experimental native-integration test. Public v0.7.0 remains unchanged.

## Known-good visual source

The visual fixture is commit `858321fabf34c4e167f44f89ca63e53fbd7cc847` (`controller-support-v0.7.0-disassemble-mode`). Its production presentation lives in `gui_controller_camera_test.lua` and `controller_ui_shared_renderers.lua`. The v0.8 branch had not replaced the renderer: the shared renderer remained byte-for-byte unchanged from v0.7 before this repair.

## Regression root causes

The v0.8 experiment added early Native-mode branches to Build/Factory and Tactical open/input/update paths. Those branches displayed and navigated the vanilla panels directly, but returned before the v0.7 model, categories, analog selection, cards, center metadata, pages, and placement transition ran.

- Build and Factory cards disappeared because the Native open path never populated `menu.options` or `radialVisibleOptions`.
- Center descriptions, costs, health, queue metadata, categories, and pages disappeared for the same reason: no render model reached the intact v0.7 renderer.
- Factory behavior inherited the same flat native bypass and lost the direct paged wheel.
- Tactical became one flat ring because `controllerGetCommands()` was treated as a final render list; D-pad cycled command indexes instead of categories.
- Build placement stopped because Native A only set the vanilla active command and closed the panel; it never entered the v0.7 controller placement state machine.
- Focus was held as an array index for Tactical and as a transient unit ID for Build, with no revision/source protocol or vanilla-to-radial path.
- Visual state and authoritative state were conflated in the bypass. Native data was not incorrectly rendered; it was never supplied to the custom renderer.

Other controller-owned radials were not structurally replaced by v0.8. Selection/reclaim backend changes were intentional and remain Native-only.

## Chosen model

`controller_native_radial_adapter.lua` is a pure, cached model adapter. Patched vanilla widgets export authoritative descriptors and own activation. The controller camera widget owns presentation, category/page navigation, and placement.

```text
vanilla Build/Order descriptor + model revision
  -> pure adapter (stable key, category, page, slot, state labels)
  -> unchanged v0.7 shared radial renderer
  -> controller selection sets vanilla focus only
  -> A/X calls the vanilla widget activation API
```

The adapter never calls Spring, WG, or gameplay command APIs. Build keys are `build:<unitDefID>`; Tactical keys are `cmd:<cmdID>`. Focus survives a rebuild by stable key, not array index.

The Build Menu exports all current cells, including vanilla index, page, row/column, costs, restriction, queue count, tooltip, selected state, and model revision. The Order Menu exports its filtered live descriptors, state params, current state, and model revision.

## Focus synchronization

Both vanilla widgets expose `controllerSetFocus`, `controllerGetFocus`, `controllerSetRadialOpen`, and a monotonic focus revision. Radial changes are tagged with a source and move the blue vanilla stroke. While the radial is open, vanilla mouse hover reports `vanilla-mouse`; the controller consumes a new revision and updates category/page/selection. Identical stable keys are acknowledged without writing focus back, preventing oscillation.

Model getters are called only when the vanilla model revision changes or a menu opens. The per-frame operation is the small focus snapshot. There is no per-frame full descriptor rebuild or logging.

## Categories and slots

Builders retain the v0.7 classifier (Economy, Combat, Utility, Build) when BAR supplies no category metadata. Adapter category ordering also accepts Defense, Production, and Special. Factories/labs use the sole internal `Factory` scope and render no builder category layer.

Eight canonical positions are used, with slot 1 at the top and increasing clockwise in the v0.7 direction. Vanilla cell order seeds the canonical position. Missing cells remain holes instead of compacting familiar items. Factory cell 1 therefore maps to radial slot 1; cells 9, 17, and so on start later pages.

The first position observed for a stable item is cached for the widget session. After reload it is rebuilt deterministically from vanilla cell order. If BAR presents conflicting positions for the same item or two remembered items collide, vanilla order wins for the first item and the collision moves to the next free position; `slotException` records that case.

## Tactical model

The actual Order Menu descriptors are separated into Utility and Tactical. D-pad Up/Down changes those categories; the left stick selects within the category. Commands unavailable to the current selection are absent because the vanilla Order Menu already filtered them.

State labels are read from descriptor params. Three-or-more-state commands open a nested state radial. Binary states activate immediately. State confirmation is handled inside the patched Order Menu (`controllerActivateState`); the controller does not keep a parallel state value.

## Placement

A first activates the authoritative vanilla build cell, then enters the existing v0.7 placement implementation. Terrain height, snapping, facing, shoreline handling, previews, validation, queue options, and final build orders remain the stable controller placement code.

Every entry and exit forces `single`. LB press changes to `grid`; LB release immediately restores `single`. Tap-to-cycle and latched grid behavior were removed. X keeps Quick Place and factory dequeue context.

## Native panels and fallback

`Show Native Panel While Radial Is Open` and `Show Native Focus Stroke` default to enabled. The experimental branch deliberately leaves the vanilla Build/Order panels visible; the focus-stroke setting is wired into both vanilla APIs. Panel hiding is deferred until live synchronization approval.

Native and Legacy execution are mutually exclusive. Changing integration mode closes both radials, closes any state sub-radial, clears native focus/capture, resets placement to Single, and invalidates cached models without changing the selected units. Legacy continues to use the v0.7 data/execution path.

## Remaining risks

- BAR exposes ordering but not a universal cross-faction builder category/slot table. Cross-builder consistency therefore depends on stable vanilla cell order and the session canonical cache.
- Some modded state descriptors may expose non-label params. They remain activatable through vanilla but may need label-specific normalization after live evidence.
- Mouse-to-radial synchronization requires the radial to remain open while mouse input is accepted by BAR's input-mode transition.
- The native panels remain deliberately visible and may overlap custom layouts at unusual UI scales.

