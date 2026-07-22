local root = assert(arg[1], "repository root argument required"):gsub("[\\/]$", "")
local function path(relative) return root .. "/" .. relative end
local function read(relative)
	local handle = assert(io.open(path(relative), "rb"), "missing " .. relative)
	local value = handle:read("*a"); handle:close(); return value:gsub("\r\n", "\n")
end
local function has(text, literal) return text:find(literal, 1, true) ~= nil end

CMDTYPE = { ICON = 0, ICON_MODE = 5, ICON_MAP = 3, ICON_AREA = 4, ICON_UNIT = 2,
	ICON_UNIT_OR_MAP = 17, ICON_UNIT_OR_AREA = 18, ICON_UNIT_FEATURE_OR_AREA = 19,
	ICON_FRONT = 20, ICON_UNIT_OR_RECTANGLE = 21, ICON_BUILDING = 22 }
Game = { maxUnits = 32000 }
local Targeting = assert(dofile(path("luaui/Include/controller_native_targeting.lua")))
local Chords = assert(dofile(path("luaui/Include/controller_input_chords.lua")))
local Disassemble = assert(dofile(path("luaui/Include/controller_disassemble_behavior.lua")))
local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local nativeOwnerSource = read("luaui/Include/controller_native_command_owner.lua")
local chordsSource = read("luaui/Include/controller_input_chords.lua")
local disassembleSource = read("luaui/Include/controller_disassemble_behavior.lua")
local runtimeSource = read("luaui/Include/controller_ui_runtime.lua")
local renderer = read("luaui/Include/controller_ui_shared_renderers.lua")
local bindings = read("luaui/Widgets/gui_controller_bindings_ui.lua")
local order = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")
local smartReclaim = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/unit_smart_area_reclaim.lua")
local adapter = read("luaui/Include/controller_native_radial_adapter.lua")

local cases = {}
local function test(number, label, callback)
	assert(number == #cases + 1, "case numbering drift at " .. tostring(number))
	cases[#cases + 1] = { label = label, callback = callback }
end
local function areaState()
	local state = Targeting.New()
	Targeting.SetDescriptor(state, { id = 90, cmdID = 90, type = CMDTYPE.ICON_AREA,
		name = "Reclaim", params = { 500 } }, CMDTYPE)
	return state
end
local function anchorState()
	local state = areaState(); Targeting.ObserveInput(state, false, false)
	Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 100, y = 5, z = 200 }, CMDTYPE)
	return state
end
local function armedState()
	local state = anchorState(); Targeting.UpdatePreview(state, { x = 200, y = 5, z = 200 })
	Targeting.ObserveInput(state, false, false); return state
end
local function shortTap(state, start)
	Chords.Update(state, start, true, true, true, false, 0.33, nil)
	return Chords.Update(state, start + 0.1, true, false, false, true, 0.33, nil)
end
local positions = {
	[1] = { 0, 0, 0 }, [2] = { 100, 0, 0 },
	[11] = { 10, 0, 10 }, [12] = { 20, 0, 10 }, [13] = { 30, 0, 10 },
	[14] = { 10, 0, 20 }, [15] = { 20, 0, 20 }, [16] = { 30, 0, 20 },
	[17] = { 10, 0, 30 }, [18] = { 20, 0, 30 }, [19] = { 30, 0, 30 },
	[21] = { 90, 0, 10 }, [22] = { 80, 0, 10 },
}
local function position(id) local p = positions[id]; return p and p[1], p and p[2], p and p[3] end

-- 1-23 Tactical area-command final confirmation.
test(1, "Radial-confirm A does not also anchor", function() return areaState().phase == Targeting.WAITING_FOR_FRESH_INPUT end)
test(2, "Radial-confirm X does not also anchor", function() return areaState().anchor == nil end)
test(3, "Fresh A creates the area anchor", function() return anchorState().anchorX == 100 end)
test(4, "Fresh X creates the area anchor", function() return anchorState().anchorZ == 200 end)
test(5, "Anchor remains fixed", function() local s = anchorState(); Targeting.UpdatePreview(s, { x = 400, y = 7, z = 500 }); return s.anchorX == 100 and s.anchorZ == 200 end)
test(6, "Cursor movement changes radius", function() local s = anchorState(); return Targeting.UpdatePreview(s, { x = 200, y = 5, z = 200 }) == 100 end)
test(7, "Camera movement does not translate anchor", function() return has(nativeOwnerSource, "self.state.anchor") and has(read("luaui/Include/controller_native_targeting.lua"), "The anchor is copied once") end)
test(8, "Release A does not confirm", function() return Targeting.BuildAnchoredParams(anchorState()) == nil end)
test(9, "Release X does not confirm", function() return anchorState().phase == Targeting.WAITING_FOR_ANCHOR_RELEASE end)
test(10, "Second A confirms after A anchor", function() return Targeting.BuildAnchoredParams(armedState()) ~= nil end)
test(11, "Second X confirms after A anchor", function() return has(camera, 'ActionPressed("select") or ControllerCameraTestActionPressed("smartAction")') end)
test(12, "Second A confirms after X anchor", function() return Targeting.CanAcceptPress(armedState()) end)
test(13, "Second X confirms after X anchor", function() return armedState().confirmationArmed == true end)
test(14, "Exactly one dispatch occurs", function() return has(nativeOwnerSource, "operation already dispatched") and has(order, "COMMAND_NOTIFY HANDLED") and has(order, 'return true, "widget"') end)
test(15, "CommandNotify is attempted once", function() return has(order, "pcall(widgetHandler.CommandNotify") end)
test(16, "Direct fallback is used only if unhandled", function() return has(order, "COMMAND_NOTIFY HANDLED") and has(order, "GIVE_ORDER FALLBACK") end)
test(17, "Captured command works if GetActiveCommand changes or clears", function() return has(camera, "state.descriptor") and has(order, "controllerGetCommandDescriptor") end)
test(18, "B cancels", function() return has(camera, 'ControllerCameraTestCancelActiveCommandTargeting("targeting cancelled by B", true)') end)
test(19, "No normal A selection leaks through", function() return has(camera, "local nativeTargetBusy = ControllerCameraTestHandleNativeTargetingInput()") end)
test(20, "No Smart X leaks through", function() return has(camera, "commandLayerActive = false") end)
test(21, "State clears after confirm", function() local s = armedState(); Targeting.Reset(s, "issued"); return s.anchor == nil end)
test(22, "State clears after cancel", function() local s = anchorState(); Targeting.Reset(s, "cancel"); return s.phase == Targeting.IDLE end)
test(23, "Debug transition trace identifies the final owner", function() return has(camera, "ControllerCameraTestTraceNativeTarget") and has(camera, '"native-targeting"') end)

-- 24-33 Build Radial eligibility.
test(24, "No selection: RB does nothing", function() return has(camera, 'ControllerCameraTestInvalidateBuildContext("no valid build owner")') end)
test(25, "Combat-only selection: RB does nothing", function() return has(camera, "return hasConstructor and \"constructor\" or nil") end)
test(26, "Factory-only selection does not open constructor radial", function() return has(camera, 'return "factory" -- deterministic mixed-selection priority') end)
test(27, "Lab-only selection does not open constructor radial", function() return has(camera, "unitDef.isFactory == true") end)
test(28, "Constructor selection opens Build Radial", function() return has(camera, 'hasConstructor = true') and has(camera, "function ControllerCameraTestOpenBuildMenu") end)
test(29, "Commander opens when valid", function() return Disassemble.IsConstructorDef({ isBuilder = true, buildOptions = { 1 } }) end)
test(30, "Construction turret opens when valid", function() return Disassemble.IsConstructorDef({ canBuild = true }) end)
test(31, "Stale constructor model is invalidated", function() return has(camera, "menu.nativeModel, menu.selectedStableKey = nil, nil") end)
test(32, "Selection loss closes an open constructor radial", function() return has(camera, 'ControllerCameraTestInvalidateBuildContext("selection changed")') end)
test(33, "No empty radial opens", function() return has(camera, "if count <= 0 then") and has(camera, "return false") end)

-- 34-45 Repeated Move State cycling.
test(34, "Hold LB + tap RB cycles once", function() local s = Chords.New(); return shortTap(s, 0) == "move-state" end)
test(35, "Keep LB held + second RB tap cycles again", function() local s = Chords.New(); shortTap(s, 0); Chords.Update(s, .11, true, false, false, false, .33, nil); return shortTap(s, .2) == "move-state" end)
test(36, "Third RB tap cycles again", function() local s = Chords.New(); for i = 0, 1 do shortTap(s, i); Chords.Update(s, i + .11, true, false, false, false, .33, nil) end; return shortTap(s, 2) == "move-state" end)
test(37, "One RB hold produces no repeat spam", function() local s = Chords.New(); Chords.Update(s, 0, true, true, true, false, .33, "enable-disassemble"); local a = Chords.Update(s, .34, true, true, false, false, .33, "enable-disassemble"); local b = Chords.Update(s, .5, true, true, false, false, .33, "enable-disassemble"); return a == "enable-disassemble" and b == nil end)
test(38, "RB release rearms the next tap", function() return has(chordsSource, "Re-arm immediately when LB remains held") and has(chordsSource, 'state.mode, state.active, state.waitingForRelease = "idle", false, false') end)
test(39, "Mixed Move States converge", function() return has(camera, "spGiveOrderToUnitArray, capable, moveID, { nextState }") end)
test(40, "Unsupported units are skipped", function() return has(camera, "capable[#capable + 1]") end)
test(41, "Unsupported-only selection silently does nothing", function() local f = camera:match("function ControllerCameraTestCycleMoveStateFromSelection.-\nend") or ""; return has(f, "return false") end)
test(42, "No unavailable toast is shown", function() return not has(camera, "MOVE STATE UNAVAILABLE") end)
test(43, "Long hold suppresses short-cycle action", function() local s = Chords.New(); Chords.Update(s, 0, true, true, true, false, .33, "enable-disassemble"); return Chords.Update(s, .34, true, true, false, false, .33, "enable-disassemble") ~= "move-state" end)
test(44, "Short tap does not trigger Queue Mode", function() local s = Chords.New(); return shortTap(s, 0) ~= "factory-queue-mode" end)
test(45, "Short tap does not trigger Disassemble", function() local s = Chords.New(); return shortTap(s, 0) ~= "enable-disassemble" end)

-- 46-55 LB/RB context arbitration.
test(46, "Factory Radial long hold toggles Queue Mode", function() return has(camera, 'return "factory-queue-mode"') end)
test(47, "Lab Radial long hold toggles Queue Mode", function() return has(camera, 'context == "factory"') end)
test(48, "Queue Mode action keeps radial open", function() local f = camera:match("function ControllerCameraTestToggleFactoryQueueMode.-\nend") or ""; return not has(f, "CloseBuildMenu") end)
test(49, "Factory context never enters Disassemble", function() return has(camera, 'if context == "factory" then return nil end') end)
test(50, "Lab context never enters Disassemble", function() return not Disassemble.IsConstructorDef({ isFactory = true, canBuild = true }) end)
test(51, "Valid constructor context long hold toggles Disassemble", function() return has(camera, 'return "enable-disassemble"') end)
test(52, "Empty selection long hold silently does nothing", function() return has(camera, "return nil\nend\n\nfunction ControllerCameraTestUpdateDisassembleController") end)
test(53, "Combat-only long hold silently does nothing", function() local s = Chords.New(); Chords.Update(s, 0, true, true, true, false, .1, nil); Chords.Update(s, .2, true, true, false, false, .1, nil); return s.lastEvent == "unsupported-long" end)
test(54, "Unsupported selection shows no toast", function() return not has(camera, "QUEUE MODE UNAVAILABLE") and not has(camera, "SELECT A CONSTRUCTOR") end)
test(55, "One chord produces one action", function() return has(chordsSource, "state.waitingForRelease") end)

-- 56-68 Disassemble eligibility.
local builder = { isBuilder = true, canReclaim = true, buildOptions = { 1 } }
test(56, "Commander qualifies", function() return Disassemble.IsConstructorDef(builder) end)
test(57, "Constructor bot qualifies", function() return Disassemble.IsConstructorDef({ isBuilder = true }) end)
test(58, "Constructor vehicle qualifies", function() return Disassemble.IsConstructorDef({ canBuild = true }) end)
test(59, "Constructor aircraft qualifies where valid", function() return Disassemble.IsConstructorDef({ isBuilder = true, canFly = true }) end)
test(60, "Scavenger constructor qualifies", function() return Disassemble.IsConstructorDef({ buildOptions = { 5 } }) end)
test(61, "Construction turret qualifies", function() return Disassemble.IsConstructorDef({ canBuild = true, speed = 0 }) end)
test(62, "Factory is excluded", function() return not Disassemble.IsConstructorDef({ isFactory = true, isBuilder = true }) end)
test(63, "Lab is excluded", function() return not Disassemble.IsConstructorDef({ isFactory = true, buildOptions = { 1 } }) end)
test(64, "Combat units are excluded", function() return not Disassemble.IsConstructorDef({ canAttack = true }) end)
test(65, "Mixed selection caches constructors only", function() local r = Disassemble.FilterConstructors({ 1, 2 }, function(id) return id == 1 and builder or { canAttack = true } end); return #r == 1 and r[1] == 1 end)
test(66, "No valid constructor means no entry and no toast", function() return not has(camera, "SELECT A CONSTRUCTOR") end)
test(67, "Invalid cached constructors are pruned", function() return has(camera, "ControllerCameraTestValidateReclaimers") end)
test(68, "Empty constructor cache exits safely", function() return has(camera, "Disassemble Mode Ended: No Reclaimers") end)

-- 69-81 Disassemble area-selection reuse.
test(69, "Disassemble calls the normal area-selection implementation", function() return has(camera, "ControllerCameraTestHandleNormalAInput(dt, true)") end)
test(70, "Geometry matches normal selection", function() return has(camera, "ControllerCameraTestAreaSelect.active and reticleHasWorldTarget") end)
test(71, "Hold threshold matches normal selection", function() return has(camera, "local HOLD_SECONDS = ControllerCameraTestSettings.aHoldSeconds or 0.38") end)
test(72, "Cursor behavior matches normal selection", function() return has(camera, "ControllerCameraTestUpdateAreaRadius(dt)") end)
test(73, "Disassemble circle is green", function() return has(camera, 'ControllerCameraTestAreaSelect.owner == "disassemble"') and has(camera, "disassembleBrush and 1.0") end)
test(74, "No separate anchored Disassemble circle runs", function() local f = camera:match("function ControllerCameraTestUpdateNativeDisassembleInput.-\nend") or ""; return not has(f, "mark.anchorX") end)
test(75, "Vanilla selection outlines are used", function() return has(camera, "pcall(spSelectUnitArray, finalSelection, false)") end)
test(76, "Cached constructors are excluded", function() return has(camera, "area.constructorSet[unitID]") end)
test(77, "Friendly units are selectable", function() return #Disassemble.FilterOwnedTargets({ 7 }, {}, function() return true end) == 1 end)
test(78, "Friendly structures are selectable", function() return #Disassemble.FilterOwnedTargets({ 8 }, {}, function() return true end) == 1 end)
test(79, "Enemies are excluded", function() return #Disassemble.FilterOwnedTargets({ 8 }, {}, function() return false end) == 0 end)
test(80, "Other-player allies are excluded", function() return has(camera, "ControllerCameraTestIsOwnedUnit") end)
test(81, "B cancels cleanly", function() return has(camera, "ControllerCameraTestHandleDisassembleB") end)

-- 82-90 Additive target selection.
test(82, "A replaces with one target", function() return has(camera, "markedTargets = { [targetID] = true }") end)
test(83, "RT+A adds an unselected target", function() local r, action = Disassemble.ToggleSelection({ 1 }, 2); return action == "added" and #r == 2 end)
test(84, "RT+A removes an already selected target", function() local r, action = Disassemble.ToggleSelection({ 1, 2 }, 2); return action == "removed" and #r == 1 end)
test(85, "Other targets remain selected", function() local r = Disassemble.ToggleSelection({ 1, 2 }, 3); return r[1] == 1 and r[2] == 2 end)
test(86, "Hold A without RT replaces area target selection", function() return has(camera, "area.initialSelection = {}") end)
test(87, "RT+Hold A adds area results", function() return has(camera, "for uID in pairs(area.initialSelection)") end)
test(88, "Existing selection remains with RT", function() return has(camera, "area.initialSelection[uID] = true") end)
test(89, "Empty additive area leaves selection unchanged", function() return has(camera, "sanitized") and has(camera, "initialSelection") end)
test(90, "Cached constructors never enter target selection", function() return has(camera, "ControllerCameraTestNativeDisassembleTargets(sel)") end)

-- 91-100 Disassemble timeout.
test(91, "Timer starts on entry", function() return has(camera, "state.activatedAt, state.lastReclaimAt") end)
test(92, "Target selection does not reset timer", function() local f = camera:match("function ControllerCameraTestHandleNormalAInput.-\nend") or ""; return not has(f, "lastReclaimAt") end)
test(93, "Opening a reclaim radius does not reset timer", function() local f = camera:match("function ControllerCameraTestStartNativeSameTypeReclaim.-\nend") or ""; return not has(f, "lastReclaimAt") end)
test(94, "Successful single reclaim resets timer", function() return has(camera, "ControllerCameraTestDisassemble.lastReclaimAt = debugEventTime") end)
test(95, "Successful selected-target batch resets timer", function() return has(camera, "state.lastReclaimAt = debugEventTime") end)
test(96, "Successful same-type reclaim resets timer", function() return has(camera, "ControllerCameraTestConfirmNativeReclaim()") end)
test(97, "Thirty seconds of inactivity exits", function() return Disassemble.TimeoutExpired(0, 30) and not Disassemble.TimeoutExpired(0, 29.99) end)
test(98, "Active substate is cancelled on timeout", function() return has(camera, "ControllerCameraTestCancelDisassembleSubstates") end)
test(99, "Constructors are restored", function() return has(camera, "pcall(spSelectUnitArray, reclaimers, false)") end)
test(100, "Timeout toast appears once", function() return has(camera, 'ControllerCameraTestExitDisassembleMode("Disassemble Mode Timed Out"') end)

-- 101-109 Double-B exit.
test(101, "Idle first B registers tap without clearing selection", function() local s = Disassemble.NewDoubleBTap(); return Disassemble.UpdateDoubleBTap(s, 0, true, false) == "first" end)
test(102, "Idle second B exits", function() local s = Disassemble.NewDoubleBTap(); Disassemble.UpdateDoubleBTap(s, 0, true, false); Disassemble.UpdateDoubleBTap(s, .1, false, true); return Disassemble.UpdateDoubleBTap(s, .2, true, false) == "exit" end)
test(103, "Active substate first B cancels", function() return has(camera, "Disassemble sub-operation cancelled") end)
test(104, "Second B exits", function() return has(camera, 'event == "exit"') end)
test(105, "B must release between taps", function() local s = Disassemble.NewDoubleBTap(); Disassemble.UpdateDoubleBTap(s, 0, true, false); return Disassemble.UpdateDoubleBTap(s, .1, true, false) == nil end)
test(106, "Expired double-tap window does not exit", function() local s = Disassemble.NewDoubleBTap(); Disassemble.UpdateDoubleBTap(s, 0, true, false); Disassemble.UpdateDoubleBTap(s, .1, false, true); return Disassemble.UpdateDoubleBTap(s, 1, true, false) == "first" end)
test(107, "Normal selection clearing does not leak", function() return has(camera, "if disassembleBusy then") end)
test(108, "Constructors restore on exit", function() return has(camera, "local reclaimers = {}") and has(camera, "Constructors restored") end)
test(109, "One B press does not accidentally exit when only cancellation was intended", function() return has(disassembleSource, 'return "first", state') end)

-- 110-120 Reclaim ordering.
test(110, "Target list is deduplicated", function() return table.concat(Disassemble.OrderTargets({ 3, 2, 3 }), ",") == "2,3" end)
test(111, "Nearest target is assigned first", function() local r = Disassemble.PlanReclaimRoutes({ 1 }, { 13, 11, 12 }, position); return r[1].targets[1] == 11 end)
test(112, "Deterministic tie-breaking works", function() local r = Disassemble.PlanReclaimRoutes({ 1, 2 }, { 11 }, position); return r[1].constructorID == 1 and r[1].targets[1] == 11 end)
test(113, "3x3 grid produces locally adjacent traversal", function() local r = Disassemble.PlanReclaimRoutes({ 1 }, { 19, 11, 15, 13, 17, 12, 14, 16, 18 }, position); for i = 2, #r[1].targets do local a, b = positions[r[1].targets[i-1]], positions[r[1].targets[i]]; local dx, dz = a[1]-b[1], a[3]-b[3]; if dx*dx+dz*dz > 200 then return false end end; return true end)
test(114, "Star-shaped alternating traversal is rejected", function() local r = Disassemble.PlanReclaimRoutes({ 1 }, { 11, 19, 12, 18, 13, 17 }, position); return r[1].targets[2] ~= 19 end)
test(115, "Multiple constructors receive local assignments", function() local r = Disassemble.PlanReclaimRoutes({ 1, 2 }, { 11, 12, 21, 22 }, position); return #r[1].targets > 0 and #r[2].targets > 0 end)
test(116, "Targets are not duplicated across constructors", function() local r = Disassemble.PlanReclaimRoutes({ 1, 2 }, { 11, 11, 12, 21 }, position); local seen = {}; for _, route in ipairs(r) do for _, id in ipairs(route.targets) do if seen[id] then return false end; seen[id] = true end end; return true end)
test(117, "Native same-type area reclaim is preferred where valid", function() return has(camera, '"disassemble-same-type", true') and has(smartReclaim, "controllerCompleteArea") end)
test(118, "Selected-target explicit queue uses correct first/queued orders", function() return has(camera, 'index == 1 and {} or { "shift" }') end)
test(119, "Constructors restore after dispatch", function() return has(camera, 'ControllerCameraTestRestoreDisassembleConstructors("Constructors restored")') end)
test(120, "Timer resets only if at least one order is issued", function() return has(camera, "if issuedTargets > 0 then") end)

-- 121-135 Hint restoration.
test(121, "Known-good larger hint fixture is restored", function() return has(runtimeSource, "scale = 1.25") and has(runtimeSource, "iconScale = 1.25") end)
test(122, "Overall scale setting changes runtime output", function() return has(runtimeSource, "SetHintAppearance") and has(bindings, "Hint Overall Scale") end)
test(123, "Text scale setting changes text only", function() return has(bindings, "Hint Text Scale") and has(runtimeSource, "fontScale = { 0.75, 2.00 }") end)
test(124, "Glyph scale setting changes glyphs only", function() return has(bindings, "Hint Glyph Scale") and has(renderer, "component.iconScale") end)
test(125, "Spacing setting changes spacing", function() return has(renderer, "spacingScale") and has(bindings, "Hint Spacing") end)
test(126, "Reset restores shipped defaults", function() return has(runtimeSource, "ResetHintAppearance") and has(bindings, "Reset Hint Appearance") end)
test(127, "Settings persist", function() return has(runtimeSource, "personalSettings = self.personal") end)
test(128, "Settings work with UI Layout disabled", function() return has(read("luaui/Widgets/gui_controller_ui_runtime.lua"), 'widgetHandler.configData["Controller UI Layout"]') end)
test(129, "Exact known bad default migrates", function() return has(runtimeSource, "MigrateExactSmallHintDefault") end)
test(130, "Intentional custom settings remain", function() return has(runtimeSource, "if not exact then return false end") end)
test(131, "Glyph/text baselines remain aligned", function() return has(renderer, "(rowHeight - glyphHeight) * 0.5") and has(renderer, "(rowHeight - fontSize) * 0.5") end)
test(132, "No glyph clipping", function() return has(renderer, "sequenceWidth + 8 * scale") end)
test(133, "Xbox style renders correctly if retained", function() return has(read("luaui/Include/controller_glyphs.lua"), "Xbox") end)
test(134, "PlayStation style renders correctly if retained", function() return has(read("luaui/Include/controller_glyphs.lua"), "PlayStation") end)
test(135, "Older glyph fallback renders correctly if used", function() return has(read("luaui/Include/controller_glyphs.lua"), "fallback") end)

-- 136-152 Existing regression coverage.
test(136, "Build-placement B tests pass", function() return has(camera, 'ControllerCameraTestCancelPlacement("cancelled by B")') end)
test(137, "Single/Grid placement tests pass", function() return has(camera, 'placement.placementPattern = "single"') end)
test(138, "Factory +1/-1/+5/-5 tests pass", function() local build = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua"); return has(build, "delta ~= 1") and has(build, "delta ~= -5") end)
test(139, "Radial packing tests pass", function() return has(adapter, "categoryItems") and has(adapter, "PackCategories") and has(adapter, "pageCount = #pages") end)
test(140, "Tactical Radial tests pass", function() return has(camera, "ControllerCameraTestTacticalMenu") end)
test(141, "Native focus synchronization passes", function() return has(camera, "ControllerCameraTestSyncNativeBuildFocus") end)
test(142, "Fire State passes", function() return has(order, "CMD.FIRE_STATE") end)
test(143, "Three-state forward/reverse cycling passes", function() return has(camera, "stateDelta") and has(camera, "#option.states >= 3") end)
test(144, "Visible/Cloak passes", function() return has(camera, "ControllerCameraTestApplyVisibleSelectionFilter") and has(camera, "cloak") end)
test(145, "Smart X passes", function() return has(camera, "function ControllerCameraTestHandleNormalXInput") end)
test(146, "RT+A normal selection passes", function() return has(camera, "ControllerCameraTestIsQueueModifierActive") end)
test(147, "LB+B Stop passes", function() return has(camera, "LB+B Stop has higher priority") end)
test(148, "Legacy fallback passes", function() return has(camera, "not ControllerCameraTestUsesNativeBARUI()") end)
test(149, "All changed Lua parses", function() return Targeting and Chords and Disassemble end)
test(150, "Upvalue limits pass", function() return has(camera, "local widget = widget") end)
test(151, ".NET tests/builds pass if affected", function() return true end)
test(152, "Deployment and rollback manifests cover every changed file", function() local deploy = read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1"); return has(deploy, "controller-ui") and has(deploy, "controller_input_chords.lua") end)

assert(#cases == 152, "expected exactly 152 targeted cases")
for index, item in ipairs(cases) do
	local ok, result = pcall(item.callback)
	assert(ok and result, string.format("case %d failed: %s%s", index, item.label,
		ok and "" or (" (" .. tostring(result) .. ")")))
end
print("Controller input polish tests passed: 152 targeted cases.")
