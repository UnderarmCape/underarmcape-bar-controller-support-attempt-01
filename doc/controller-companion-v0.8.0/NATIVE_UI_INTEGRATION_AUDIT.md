# Native BAR UI integration audit

Status: v0.8.0 experimental implementation basis  
BAR game: `Beyond All Reason test-30714-2a9339d`  
BAR upstream commit: `2a9339d0c587c1444b2b839ba29dc954f1a13b17` (`Release 2026.07-20-2`)  
Recoil: `2026.06.12`

## Runtime source of truth

The live game is supplied by Rapid package `8e6cde29c0b28e0fa2c4c97789382bb7.sdp`; the production LuaUI files are inside that package, not ordinary loose files. A loose file below `data/LuaUI` has higher VFS priority and is therefore an override. The v0.8.0 deployment must only install tracked, base-hash-pinned overrides and must remove or restore them on rollback.

The exact official GitHub sources at the commit above were compared with the Rapid build identity. Relevant base SHA-256 values are:

| File | Base SHA-256 |
|---|---|
| `luaui/Include/select_api.lua` | `eb92e31bd86e1df4cd12b2dca721b67e3e505a419ea1ed3b57dc66c690d243e7` |
| `luaui/Include/ordermenu_firestate.lua` | `340731d73126ac797244885476044377427757712599c5418a7ca2b796e24e22` |
| `luaui/Include/user_firestate_commands.lua` | `9681f5210c7ddda205ac3ec5978d996b51b3fab6537b711f63535726f1b86bdb` |
| `luaui/Widgets/unit_smart_area_reclaim.lua` | `53241a515f92f73f061e253b49dff76e0327994178833067802b4409b434ef73` |
| `luaui/Widgets/unit_area_reclaim_enemy.lua` | `4cee1d83121bc6ccdbb7d67fb103007633f137f2415042d83db1bb99ef93d071` |
| `luaui/Widgets/gui_ordermenu.lua` | `cac5b7ba1a224fd104662c3a39dd7132ec6a48d4f9e1e4b5076a430225be5892` |
| `luaui/Widgets/gui_gridmenu.lua` | `8e843226250995cb20a9b6ec1f79a71040e6624ca45e41fc546f003780699be5` |
| `luaui/Widgets/gui_buildmenu.lua` | `fc2056fc99bf7f49ab0eeb18f23308850b35380359331d61948361638017de5a` |
| `luaui/Widgets/gui_selectionbox.lua` | `365e281398d5c66135904d6fedb8512a25372a6896a7232daec3850ff7812595` |
| `luaui/Widgets/gui_selectedunits_gl4.lua` | `56a3a86176765e294d2ee42de31d43ff89a5d44062056436090bf5098ccb73e2` |
| `luaui/Widgets/gui_controller_test.lua` | `bb4b4fb55064bef731cf68e297ba5f12562d37b9dfec7fc60d3a9c5a4e648c2` |
| `luaui/Widgets/api_shared_state.lua` | `21561e2c26cea4e7703ebfdd11337eefb83a0012c867c8184f4a0e66f0af99b3` |
| `luaui/Widgets/gui_commands_fx.lua` | `f3ff2458d2d81ff12567bf988363899629582f79e43d09bc7072c69366f62e93` |
| `luaui/Widgets/unit_stateprefs.lua` | `baab22045eed7f9bfa14c52a74ffef8c2b33eb0bb9efc8ce3cf5210f69f6b9e0` |
| `luaui/Widgets/unit_smart_select.lua` | `b0442a5549a8a74bffba7c77be536b90b81a6d77d2551664ce796235ce3d39e7` |

## Integration map

| Current controller system | Vanilla BAR candidate | Integration method | Vanilla file/widget | Legacy fallback |
|---|---|---|---|---|
| A reticle selection | Smart Select plus engine selection | Add deterministic controller entry points beside the existing mouse helper; both end at `Spring.SelectUnitArray` | `unit_smart_select.lua`, `select_api.lua` | Existing reticle selection |
| RT+A additive/toggle | Engine selection with Smart Select eligibility | Reuse Smart Select unit filtering and apply a toggle to the current native selection | `unit_smart_select.lua` | Existing RT+A path |
| Disassemble marked targets/outlines | Engine selection and BAR selected-unit renderer | Disable controller marked-target storage/drawing in native mode | `gui_selectedunits_gl4.lua` | v0.7 marked-target implementation |
| Single friendly reclaim | Native `CMD.RECLAIM` descriptor and one-target command | Activate the selected-units command descriptor; controller confirmation uses the same command ID and target encoding | Recoil `GuiHandler`, `BuilderCAI`; `unit_smart_area_reclaim.lua` controller entry point | v0.7 per-target queue |
| Same-type area reclaim | Recoil targeted-area reclaim | Issue the native five-parameter form `{targetUnitID,x,y,z,radius}`; target unit definition remains authoritative in `BuilderCAI` | `BuilderCAI`, `unit_area_reclaim_enemy.lua`, shared controller extension in `unit_smart_area_reclaim.lua` | v0.7 area-reclaim modal |
| Any-type area reclaim | Recoil four-parameter area reclaim | Expose `{x,y,z,radius}` through the same shared reclaim API; leave unbound in this pass | `GuiHandler`, `BuilderCAI`, `unit_smart_area_reclaim.lua` | None required |
| Reclaim command feedback | Active command cursor plus BAR command FX | Keep `Spring.SetActiveCommand` authoritative; do not render the v0.7 radial | Recoil GUI, `gui_commands_fx.lua` | v0.7 radial |
| Tactical radial templates | Actual selected-unit command descriptors | Expose ordered visible commands and cycling/activation from the native order menu | `gui_ordermenu.lua`, `ordermenu_firestate.lua`, `user_firestate_commands.lua` | v0.7 tactical radial |
| Cloak, fire/move state, repeat, on/off, priority, factory and transport states | `CMDTYPE.ICON_MODE` descriptors | Read `id`, `params`, `disabled`, `action`, icon and tooltip from current descriptors; cycle with the native SetActiveCommand path | `gui_ordermenu.lua` | v0.7 command templates |
| Stop and wait | Actual command descriptors | Activate/issue current native descriptor only when available | `gui_ordermenu.lua` | v0.7 direct command |
| Build radial | Vanilla Build Menu cells | Expose current page/cells, native focus highlight, navigation and native activation; retain icon/cost/availability/tooltip ownership | `gui_buildmenu.lua` | v0.7 build radial |
| Alternate Grid Menu | Vanilla Grid Menu | Documented future conversion; Build Menu is the enabled production path and disables Grid Menu | `gui_gridmenu.lua` | v0.7 build radial |
| Controller UI state | BAR shared `WG` APIs | Camera widget is only an input/context layer; native widgets own focus and command data | patched widgets plus `api_shared_state.lua` | Native/legacy setting |

## Selection findings

`unit_smart_select.lua` owns the production selection filters. Its mouse box path obtains units with `Spring.GetUnitsInScreenRectangle`, applies builder/resurrector/mobile/building/team filters and ends in `Spring.SelectUnitArray`. `select_api.lua` owns selection actions such as select-all/type and previous selection. Native selection outlines are driven by the engine selection and `gui_selectedunits_gl4.lua`; no separate controller target table is needed.

The public Smart Select `WG` method used real keyboard modifier state and could not express a deterministic controller toggle. The selected implementation adds a small API that reuses the widget's eligibility data and always updates the actual engine selection. Mouse/keyboard code remains unchanged.

## Reclaim findings and engine boundary

Recoil `GuiHandler.cpp` creates a one-target `CMD.RECLAIM` or the four-parameter area form `{x,y,z,radius}` for `CMDTYPE_ICON_UNIT_OR_AREA`/`CMDTYPE_ICON_UNIT_FEATURE_OR_AREA`. `BuilderCAI.cpp` also recognizes the five-parameter targeted-area form `{targetUnitID,x,y,z,radius}`, which filters to the anchor unit's type. BAR's `unit_area_reclaim_enemy.lua` uses this exact five-parameter representation. `unit_smart_area_reclaim.lua` intercepts ordinary feature-area reclaim to retain BAR's metal/energy and stationary/mobile sorting behavior.

Lua can activate a native command (`Spring.SetActiveCommand`) but Recoil exposes no API to synthesize or hold the engine's `activeMousePress` drag structure. Consequently a controller cannot literally drive the private C++ mouse-drag object. The minimal adapter lives in BAR's reclaim widget, retains the native command descriptor and command encodings, and draws the controller-adjusted radius there. It does not keep a parallel target set or radial menu. Mouse input still uses the unmodified engine path. This is the one material deviation from an exact mouse-call-in reuse.

## Tactical and build findings

`gui_ordermenu.lua` already consumes `Spring.GetActiveCmdDescs()`, excludes hidden commands, honors descriptor disabled/availability fields, and delegates virtual fire-state handling to BAR's `ordermenu_firestate.lua`. Its mouse path cycles state values and calls `Spring.SetActiveCommand`. The controller API is placed in this widget so controller and mouse see the same command list.

`gui_buildmenu.lua` owns build icons, costs, restrictions, pages, tooltips, active-command state and selection. It already exposes highlight functions. The controller extension adds focus and navigation over the current native cells and calls the same active-command operation as mouse. A stable controller-active flag enlarges spacing only after hysteresis; standard mouse/keyboard layout values are retained when inactive.

## Candidate systems not overridden

`gui_selectionbox.lua`, `gui_selectedunits_gl4.lua`, `gui_commands_fx.lua`, `select_api.lua`, `ordermenu_firestate.lua`, `user_firestate_commands.lua`, `gui_gridmenu.lua`, `unit_area_reclaim_enemy.lua`, `api_shared_state.lua`, and `unit_stateprefs.lua` remain unmodified. They were audited to establish ownership and are reached through engine/native state. Keeping the override set small reduces BAR-update risk.
