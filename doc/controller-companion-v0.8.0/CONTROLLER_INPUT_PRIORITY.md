# Controller input priority

A consumed press is never reconsidered by a lower layer.

| Input | Highest to lowest priority |
| --- | --- |
| A / X | active controller-owned point/area/front/rectangle target; build placement; Factory/Lab radial; Tactical radial/sub-radial; Disassemble direct target; normal selection/Smart X |
| B | hybrid target cancellation; placement cancellation; active radial close; Disassemble sub-operation/double-B; normal clear selection |
| RB / LB with Build/Factory open | Back/View+RB Tactical toggle where applicable; global radial traversal; modal quantity action; shoulder chord only when explicitly permitted |
| D-pad | settings/modal or active radial; build-placement controls; normal-gameplay Idle Builders navigation |

The root update services hybrid targeting before `ControllerCameraTestUpdateDisassembleController`, so a same-type reclaim's second A/X cannot fall into Disassemble or normal handlers. Build/Factory traversal consumes its shoulder edge before queue/move/disassemble chords. Idle actions are reached only after placement and both radials decline input.
