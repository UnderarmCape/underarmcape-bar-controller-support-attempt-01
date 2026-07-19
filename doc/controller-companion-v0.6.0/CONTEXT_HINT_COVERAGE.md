# Context hint coverage

## Architecture

`WG.ControllerHintRegistry` stores stable IDs, action/shortcut resolvers, labels, tap/hold form, availability predicates, priority, and group. The overlay resolves action controls through live `WG.BARControllerSupport.GetBinding`; binding changes increment a revision and invalidate the cached list. Physical shortcut and fixed analog controls use the gameplay shortcut/input resolver. The overlay recomputes at most every 0.12 seconds and only rebuilds when context, registry/settings revision, or binding revision changes.

## Covered contexts

- Normal/no selection/unit hover/single/multiple selection.
- Builder and factory selection; transport state is present in the context snapshot for extensions.
- Build/factory radial, build placement, tactical radial, selection filter radial.
- Smart action and hold-path availability.
- Controller Mouse Mode.
- Pregame cursor/start-position flow.
- Full Bindings UI.
- Controller UI Layout Editor.
- Area selection, staged tactical, command layer, control-group layer, LB/pitch layer, DGUN, world-target, and special-mode flags are exposed in the context snapshot.

## Covered action groups

- Select, hold selection radial, cancel/clear, Smart X, hold Smart X path.
- Build/factory radial, command layer, pitch, idle cycling, control groups.
- Radial select/quick/cancel/close/page controls.
- Placement confirm/place-stay/cancel/rotation/spacing/pattern tap+hold/append/insert.
- Tactical choose/cancel/close/guard-patrol/reclaim.
- Pregame click/place/camera modifier and Mouse Mode click/cursor.
- Bindings navigation and editor navigation.
- Group slot/recall/assign/clear and LB idle-type/pitch layer controls.
- Short Back+Start Mouse Mode and held Back+Start UI settings.

Readable text chips are the fallback; no glyph is required for a binding to remain understandable.
