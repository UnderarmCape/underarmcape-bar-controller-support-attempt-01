# LB native-command mapping

In Native Experimental mode, LB shortcuts resolve live Order Menu descriptors:

| Context | Input | Native action |
| --- | --- | --- |
| Any eligible selection | LB+B / LB+B×2 / hold LB+B | Stop / Repeat state / Wait |
| Builder | LB+A / LB+X / LB+Y | Repair Area / Reclaim Area / Patrol |
| Builder | LB+Y×2 | Area Mex targeting |
| Air transport | LB+X / LB+A | Load Unit / Unload |
| Air transport hold | LB+X / LB+A | Load Area / Unload Area |
| Factory | LB+A or LB+X / LB+Y | Fight / Patrol |
| Combat | LB+A / LB+X / LB+Y | Context Attack-or-Fight / Attack / Patrol |

Immediate commands, state commands, and staged target commands all use Order
Menu's descriptor pipeline. RT append and queue-front insertion are retained.
Legacy mode continues to call the legacy dispatcher.
