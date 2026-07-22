# Disassemble with Vanilla Selection

Disassemble entry caches only alive, owned, reclaim-capable non-factory builders. Commanders, mobile constructors, construction aircraft, scavenger constructors, and construction turrets qualify when BAR exposes those properties. Factories, labs, combat units, enemies, and other-player allies do not. Unsupported entry is silent.

## Shared Hold-A brush

Native Disassemble calls `ControllerCameraTestHandleNormalAInput(dt, true)`, the same live moving brush used by normal Hold-A selection. It uses the same hold threshold, current-reticle center, RS/D-pad radius adjustment, visible-unit scan, touch accumulation, and vanilla `Spring.SelectUnitArray` result. There is no native fixed anchor and no tactical-targeting geometry. The normal circle is blue; the same circle is green when its owner is Disassemble.

The Disassemble filter admits owned units and structures and excludes cached constructors. Normal selection filters remain unchanged.

## Additive selection

- A replaces the actual vanilla selection with the owned hovered target.
- RT+A toggles that target while retaining other valid selected targets.
- Hold A replaces with accumulated brush targets.
- RT+Hold A seeds the brush with the existing valid target selection and adds results.
- An empty additive brush leaves the sanitized target selection unchanged.

Constructors remain in the cache even while target outlines are selected. B cancellation and mode exit restore valid constructors.

## Lifetime and exit

The 30-second inactivity clock starts on entry and resets only after at least one reclaim command succeeds. Highlighting, selection, radius opening, cancellation, and Stop do not reset it. Timeout cancels substates, restores constructors, clears temporary state, exits, and shows one concise toast.

The first B cancels an active sub-operation or registers an idle tap without falling through to normal clear-selection. After B release, a second B within 0.35 seconds exits and restores constructors. LB+B Stop has priority.

Legacy Controller UI retains its legacy marked-target path. Native and Legacy owners are mutually exclusive and mode switches reset brushes, reclaim targeting, chords, double-B, active descriptors, and placement state.
