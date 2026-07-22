# Deterministic controller single selection

The intermittent mass-selection bug came from the normal A release handler retaining a rapid-double-tap branch. Two ordinary taps could call the same-type selector; the native attempt could also enter Smart Select. That made the result depend on tap timing and input-mode transitions.

Normal A now traces the friendly unit under the controller reticle and calls `Spring.SelectUnitArray({ unitID }, false)` exactly once. It never emits mouse input, invokes vanilla double-click handling, or calls a same-type helper. The obsolete ordinary same-type helpers were removed. Optional `selectionTransitionDebug` logs only DOWN/UP transitions with edge ID, hovered ID/definition, modal mode, additive flag, brush flag, mouse-path flag, helper, hold time, and final IDs.

Hold-A still owns the area brush. RT+A still toggles exactly one friendly ID. Targeting, placement, radials, and Disassemble consume A before the normal handler. The only normal-gameplay all-idle-same-type action is LB+D-pad Down.
