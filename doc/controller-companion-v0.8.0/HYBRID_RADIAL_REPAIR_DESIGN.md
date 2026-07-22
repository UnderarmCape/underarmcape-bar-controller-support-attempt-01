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

Builders use BAR metadata and a small ambiguity table to classify the authoritative cells in Economy, Build, Utility, Combat order. Factories/labs classify the same authoritative command list in Constructors, Utility, Combat order.

Pages contain at most eight positions, with slot 1 at the top and increasing clockwise in the v0.7 direction. Present items are compacted without holes. A deterministic minimal-page packer preserves fixed category order and vanilla order within each category while balancing legal page boundaries and avoiding one-item mixed wedges where possible. Mixed pages publish explicit slot-aligned sector runs.

## Tactical model

The actual Order Menu descriptors are separated into Utility and Tactical. D-pad Up/Down changes those categories; the left stick selects within the category. Commands unavailable to the current selection are absent because the vanilla Order Menu already filtered them.

State labels are read from descriptor params. Three-or-more-state commands cycle directly: A moves forward and X moves backward. Binary states activate immediately. State changes are handled inside the patched Order Menu (`controllerActivateState`); the controller does not keep a parallel state value.

## Placement

A first activates the authoritative vanilla build cell, then enters the existing v0.7 placement implementation. Terrain height, snapping, facing, shoreline handling, previews, validation, queue options, and final build orders remain the stable controller placement code.

Every entry and exit forces `single`. LB press changes to `grid`; LB release immediately restores `single`. Tap-to-cycle and latched grid behavior were removed. X keeps Quick Place and factory dequeue context.

## Native panels and fallback

Stable controller-mode hysteresis hides the native Build/Order panels and their mouse interception while leaving descriptors, queue state, and focus identity live. Mouse mode restores the panels. The debug visibility override remains explicit.

Native and Legacy execution are mutually exclusive. Changing integration mode closes both radials, clears native focus/capture, resets placement to Single, and invalidates cached models without changing the selected units. Legacy continues to use the v0.7 data/execution path.

## Remaining risks

- BAR exposes role metadata but not a universal cross-faction semantic category table. Genuinely ambiguous units may require a documented exact-name override after live evidence.
- Some modded state descriptors may expose non-label params. They remain activatable through vanilla but may need label-specific normalization after live evidence.
- Mouse-to-radial synchronization requires the radial to remain open while mouse input is accepted by BAR's input-mode transition.
- Visual and gameplay behavior still require the 58-step live checklist; automated coverage does not establish live-input success.
