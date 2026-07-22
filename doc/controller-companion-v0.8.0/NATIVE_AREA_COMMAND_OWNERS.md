# Native completed-shape adapters

Controller confirmation no longer depends on BAR's private mouse press/drag/release lifecycle. Native ownership begins after the controller has completed the shape.

| Command family | Completed-shape adapter | Native work retained |
| --- | --- | --- |
| Area Mex | `WG.areamex.controllerCompleteArea` | metal spots, filtering, queue/build split, preview-command application |
| Smart Area Reclaim | `WG.smartareareclaim.controllerCompleteArea` | four-parameter feature filtering and transformed reclaim batches |
| Same-type Reclaim | same Smart Reclaim adapter with five params | Recoil's native `{targetID,x,y,z,r}` semantics |
| Front/rectangle | `WG.customformations.controllerCompleteShape` | live descriptor and six-coordinate native semantics |
| Other point/area shapes | `WG.ordermenu.controllerCompleteTargetShape` | validation, notify, engine fallback |

Smart Area Reclaim explicitly returns unhandled for five parameters so the same-type order reaches Recoil unchanged rather than being misread as `{x,y,z,r}`. Every adapter converges on Order Menu's one `CommandNotify` callsite. Handled commands stop there; unhandled commands receive exactly one `GiveOrder`/`CMD.INSERT` fallback.

The earlier registered mouse-owner APIs remain dormant compatibility surfaces. The camera has no `controllerBeginTarget` or `controllerTargetInput` call, so there is no duplicate confirm or preview path.
