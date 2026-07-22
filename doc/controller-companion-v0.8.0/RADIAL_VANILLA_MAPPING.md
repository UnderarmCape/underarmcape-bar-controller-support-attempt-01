# Radial and Vanilla Mapping

| Controller UI | Classification | Authority | Presentation | Activation / fallback | Status |
|---|---|---|---|---|---|
| Builder Build Radial | Vanilla cell-backed | Build Menu cells | exact v0.7 Build wheel/cards/center panel | `WG.buildmenu.controllerActivate`; Legacy v0.7 commands | repaired |
| Factory/Lab Queue Radial | Vanilla cell-backed | Build Menu cells and queue counts | exact v0.7 Factory wheel, direct pages | vanilla left/right cell activation; Legacy queue orders | repaired, uncategorized |
| Tactical Radial | Vanilla descriptor-backed | Order Menu filtered descriptors | exact v0.7 categorized Tactical wheel | `WG.ordermenu.controllerActivate`; Legacy tactical executor | repaired |
| Tactical state sub-radial | Vanilla descriptor-backed | descriptor params/current state | v0.7 Tactical wheel role | `controllerActivateState`; no duplicated state | added |
| Selection/area behavior radial | Native selection-backed | SmartSelect/engine selection | v0.7 selection renderer | Native SmartSelect; Legacy selection helper | preserved |
| Visible-selection filter radial | Controller visual + native selection | candidate state plus SmartSelect | v0.7 four-direction selection wheel | RB release confirms; B/LB-first cancels | preserved |
| Area selection | Native selection-backed | visible allied unit scan + SmartSelect | v0.7 world radius/feedback | Native SmartSelect; Legacy selector | preserved |
| Disassemble/reclaim | Native reclaim-backed | Smart Area Reclaim descriptors | v0.7 charge/radius feedback | Native reclaim only in Native mode; Legacy marked-target fallback | preserved |
| Control groups | Controller-only state UI | controller group state | v0.7 hot-slot overlay | controller group APIs | unchanged |
| Command-layer directional actions | Controller-only presentation over commands | active selection/command context | v0.7 hints and feedback | native paths where present; Legacy fallback | unchanged |
| Pregame controller UI | Controller-only menu/cursor | BAR pregame state | existing v0.7 presentation | existing pregame input | unchanged |
| Build placement pattern popup | Controller-only visual state | v0.7 placement state machine | existing v0.7 popup/preview | final selected build command originates in vanilla | repaired to momentary Grid |

The shared renderer remains `controller_ui_shared_renderers.lua`. Native selection and reclaim deliberately do not use a fake vanilla cell cursor because no corresponding panel cell exists.

## Tactical descriptor behavior

- Utility: visible/cloak, fire/move state, repeat, on/off, priority, wait, stop, clear-queue-like state/actions.
- Tactical: move, attack, fight, patrol, guard, repair, reclaim, restore, capture, set target, manual fire, Area Mex, and other live target descriptors.
- Three-or-more states: descriptor-backed nested radial.
- Two states: immediate descriptor-backed toggle.
- Target commands: activation selects the real vanilla descriptor; normal native target confirmation remains authoritative.

The optional debug panel reports the existing menu/action state. Focus revisions and sources are retained in `ControllerCameraTestNativeUI` and are not logged every frame.

