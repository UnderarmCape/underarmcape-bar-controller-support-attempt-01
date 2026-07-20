# Hint and binding action audit

## Result

The gameplay binding registry contains 41 stable action IDs. Static and runtime audits report:

- gameplay actions without any registered contextual hint: 0;
- registered action IDs without a gameplay binding: 0;
- hint definitions that never match the representative context suite: 0.

The hint registry intentionally has more definitions than bindings because one action can have different wording in normal, factory, placement, radial, or staged contexts, and stick/system hints do not map to gameplay actions. Three additional actionless definitions exist only in the simulated Long Binding Stress Test.

The previously physical-only interaction is now registered as:

```text
D-pad Down — Select Commander
action ID: selectCommander
category: Groups / Hot Slots
```

It participates in Build-First defaults, config validation/migration, conflict handling, the Bindings UI, live binding resolution, organization overrides, and the developer audit.

## Categories and coverage

Default categories are Selection, Commands, Camera, Building, Placement, Factory, Tactical, Radials, Groups / Hot Slots, Mouse Mode, Pregame, Editor, System, and Advanced. The Actions tab can hide/show, recategorize, relabel, and reorder actions or whole categories without duplicating physical button labels.

The representative audit suite includes no selection; builder/factory/transport; constructor/factory/tactical/selection radials; placement; area selection; staged tactical target; DGUN; command/group/pitch layers; pregame; Mouse Mode; Bindings; Layout Editor; and the long-binding stress context.

Developers can print the live report without normal-gameplay spam:

```text
/luaui bar_controller_ui audit
```
