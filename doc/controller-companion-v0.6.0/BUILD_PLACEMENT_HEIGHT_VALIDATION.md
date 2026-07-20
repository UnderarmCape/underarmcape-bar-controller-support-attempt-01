# Build-placement terrain-height validation

## Root cause and fix

Placement used several Y sources: screen-ray Y, native blueprint output, fallback-generated terrain Y, and `Pos2BuildPos` output. This allowed preview and final issue paths to disagree and did not guarantee that the snapped X/Z position was paired with the terrain height at that snapped location.

`ControllerCameraTestResolveBuildPosition` is now the common resolver. It:

1. validates a negative build command and numeric X/Z;
2. resolves `Spring.GetGroundHeight(x, z)`;
3. snaps with `Spring.Pos2BuildPos` using that terrain Y;
4. resolves ground height again at snapped X/Z;
5. validates with `Spring.TestBuildOrder` when available;
6. returns one X/Y/Z/facing source for preview and final issue.

Negative underwater ground heights are intentionally retained. No `max(0, y)` or sea-level substitution is used, preserving water, floating, shoreline, and underwater build definitions.

## Manual cases

- Flat elevated land: preview and completed order are on the terrain.
- Hill/slope and plateau: snapped preview and issued footprint agree.
- Shoreline: land-only and water-only validity matches BAR.
- Valid water building: negative underwater terrain Y is accepted.
- Invalid footprint: confirmation fails safely and issues no controller order.
- Single placement: final command uses the common resolver.
- Line/grid/border/split: every native or fallback point is normalized and validated before preview and issue.
- Rotation: re-resolution and validation use the current facing.
