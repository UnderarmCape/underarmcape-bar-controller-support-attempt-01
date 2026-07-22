# Build Radial Eligibility

The RB Build/Factory radial now begins with the actual live vanilla selection.

- Any alive, owned selected factory or lab gives the existing Factory/Lab context. Mixed selections deterministically prefer this context.
- Constructor context requires an alive, owned, selected, non-factory builder and at least one current authoritative Build Menu item.
- Empty, combat-only, stale, or non-builder selections return a silent no-op.

`widget:SelectionChanged` closes an open radial, clears native focus, removes the cached model and stable key, and invalidates the model revision. The next valid open rebuilds from `WG.buildmenu.controllerGetItems`. Negative build IDs alone never classify a factory as a constructor. Existing compact categories, queue quantities, disabled entries, and factory controls remain unchanged.
