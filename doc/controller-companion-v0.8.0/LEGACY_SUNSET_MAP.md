# Legacy sunset map

The v0.8.0 experiment defaults to **Native Experimental** but retains **Legacy Controller UI** as a persisted Bindings UI setting. The camera widget is the single switch owner. Native and legacy handlers are mutually exclusive; changing the setting never enables two command emitters or two renderers for the same interaction.

| Capability | Native Experimental | Legacy Controller UI | Candidate deletion after play-test approval |
|---|---|---|---|
| A / RT+A selection | `WG.smartselect` updates Recoil's selected-unit array | v0.7 reticle selection functions | Controller-only selection mutation helpers once every selection profile is confirmed |
| Area selection | Smart Select filter plus engine selection | v0.7 controller area collector/filter | Redundant selection application and outline plumbing |
| Disassemble target visuals | BAR selected-unit outlines; no marked target set is populated or drawn | `markedTargets` and custom world outlines | Marked-target storage, pruning, and custom outline draw block |
| Single reclaim | Patched Smart Area Reclaim controller entry; native one-target `CMD.RECLAIM` | v0.7 per-target queue | Legacy reclaim queue and marked-target confirmation |
| Same-type area reclaim | Native five-parameter target-area command | v0.7 controller area modal | Legacy candidate discovery, area modal, and radial renderer |
| Tactical controls | Current `gui_ordermenu` descriptors, availability, state and highlight | v0.7 template-driven tactical radial | Command templates and controller-only tactical renderer |
| Build/factory controls | Current `gui_buildmenu` cells, costs, queue, availability, focus, and enlarged stable gamepad grid | v0.7 build radial | Build option gathering and controller-only build radial |
| Hints | Native command and selection context | v0.7 custom-modal context | Obsolete marked-target hint branches |

## Switch behavior

`Native BAR UI Integration` is stored with the normal controller settings. `Native Experimental` is the v0.8.0 default. Existing v0.7 configuration without the key migrates to that default. Selecting `Legacy Controller UI` routes selection, reclaim, tactical, build, drawing, and hint state back to the retained v0.7 paths.

The experimental setting does not alter public shipping-default documents. It is branch-local widget behavior for Kailil's test deployment.

## Approval gate

Do not delete the retained legacy branches until manual gameplay verifies friendly units and structures, multi-selection, reclaim-capable mixed selections, factory queues, uncommon command descriptors, spectator transitions, and both controller families. A later cleanup can then remove the rows marked as candidates and drop the override switch in a separate milestone.
