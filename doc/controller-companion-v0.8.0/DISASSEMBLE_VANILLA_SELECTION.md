# Disassemble with Vanilla Selection

Status: **EXPERIMENTAL — INPUT STATE, FACTORY SHORTCUT, AND VANILLA DISASSEMBLE TEST**

## Eligibility and constructor cache

Disassemble entry filters the current selection using BAR builder properties (`isBuilder`, `canBuild`, or build options), excludes factories, and verifies reclaim command capability. Commanders, mobile constructors, and construction turrets qualify when BAR classifies them as builders. A reclaim-capable non-builder does not. Mixed selections are accepted, but only valid constructors enter the internal cache. Rejection leaves selection unchanged and shows `Select a Constructor`.

The cache is pruned for death, transfer, or lost capability. Target selection never replaces the cache. If it becomes empty, the mode exits safely.

## Workflow A: actual vanilla target selection

Hold A without LB to capture a fixed ground anchor. Moving the cursor resizes the circle from that anchor; no full-map scan runs per frame. Releasing A queries owned-team units once, filters dead/invalid units, excludes cached constructors, sorts and deduplicates the result, and calls `Spring.SelectUnitArray`. BAR's normal selection outlines are the only target outlines; the Native path does not populate or render the legacy marked-target table.

An empty result or B cancellation restores the valid cached constructors and keeps Disassemble active.

Hold LB and tap A before the same-type threshold to reclaim the actual vanilla-selected target set. Invalid, transferred, enemy/allied-other-team, duplicate, and cached-constructor targets are excluded. If no valid set exists, the captured owned hover target is the single-target fallback. Cached constructors issue the first reclaim immediately and subsequent deterministic targets with Shift as one logical batch. Constructors are immediately restored as vanilla selection, successful use is recorded, and the mode remains active.

## Workflow B: same-type native area reclaim

Hold LB+A over an owned non-constructor target. Crossing the hold threshold suppresses tap reclaim, captures its UnitDefID and fixed world position, restores the constructor command source, and starts the Smart Area Reclaim native controller API for eligible-target feedback. Cursor distance changes only the radius.

Releasing LB or A sets a neutral gate and never confirms. After A and X are both observed released, a fresh A or X press performs one owned-team cylinder query, filters to the captured UnitDefID, excludes constructors, issues the reclaim batch, restores constructors, and exits only the area substate. B cancels the substate, restores constructors, consumes its cycle, and leaves Disassemble active.

## Priorities and performance

Active same-type confirmation/cancel owns input first, followed by active A-area selection, LB+A tap/hold, ordinary A-area selection, X Move, LB+B Stop, and B target restoration. The centralized LB/RB chord remains the outer owner for mode exit. Descriptor models are cached, target scans occur only at release/confirmation, held buttons do not repeat queue actions, and Native/Legacy paths never render or dispatch simultaneously.

