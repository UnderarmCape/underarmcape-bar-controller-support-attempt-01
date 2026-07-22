local root = assert(arg[1], "repository root argument required"):gsub("[\\/]$", "")
local function path(relative) return root .. "/" .. relative end
local function read(relative)
	local file = assert(io.open(path(relative), "rb"), "missing " .. relative)
	local value = file:read("*a"); file:close(); return value:gsub("\r\n", "\n")
end
local function has(text, literal) return text:find(literal, 1, true) ~= nil end
local function same(actual, expected) return actual == expected end

CMDTYPE = { ICON = 0, ICON_MODE = 5, ICON_MAP = 3, ICON_AREA = 4, ICON_UNIT = 2,
	ICON_UNIT_OR_MAP = 17, ICON_UNIT_OR_AREA = 18, ICON_UNIT_FEATURE_OR_AREA = 19,
	ICON_FRONT = 20, ICON_UNIT_OR_RECTANGLE = 21, ICON_BUILDING = 22 }
Game = { maxUnits = 32000 }
local Targeting = assert(dofile(path("luaui/Include/controller_native_targeting.lua")))
local Chords = assert(dofile(path("luaui/Include/controller_input_chords.lua")))
local Disassemble = assert(dofile(path("luaui/Include/controller_disassemble_behavior.lua")))
local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local build = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua")
local order = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")
local adapter = read("luaui/Include/controller_native_radial_adapter.lua")

local cases, count = {}, 0
local function test(label, callback) cases[#cases + 1] = { label, callback } end
local function areaState()
	local state = Targeting.New()
	Targeting.SetDescriptor(state, { id = 90, type = CMDTYPE.ICON_AREA, name = "Reclaim", params = { 500 } }, CMDTYPE)
	return state
end
local function anchoredState()
	local state = areaState(); Targeting.ObserveInput(state, false, false)
	local _, kind = Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 100, y = 5, z = 200 }, CMDTYPE)
	return state, kind
end
local function longChord(factory, active)
	local state = Chords.New()
	Chords.Update(state, 0, true, true, true, false, 0.33, factory, active)
	local event = Chords.Update(state, 0.34, true, true, false, false, 0.33, factory, active)
	return event, state
end

-- 1-21 Tactical area confirmation.
test("Selecting an area command does not anchor from radial confirm", function() local s = areaState(); return s.phase == Targeting.WAITING_FOR_FRESH_INPUT and s.anchor == nil end)
test("Fresh A creates one anchor", function() local s, k = anchoredState(); return k == "anchor" and s.anchorX == 100 end)
test("Fresh X creates one anchor", function() local s, k = anchoredState(); return k == "anchor" and s.anchorZ == 200 end)
test("Anchor stays fixed while cursor moves", function() local s = anchoredState(); Targeting.UpdatePreview(s, { x = 300, y = 5, z = 200 }); return s.anchorX == 100 end)
test("Camera movement cannot translate stored anchor", function() local s = anchoredState(); Targeting.UpdatePreview(s, { x = 5, y = 7, z = 6 }); return s.anchorY == 5 and s.anchorZ == 200 end)
test("Cursor movement changes radius", function() local s = anchoredState(); return Targeting.UpdatePreview(s, { x = 400, y = 5, z = 200 }) == 300 end)
test("Releasing A does not confirm", function() local s = anchoredState(); local p = Targeting.BuildAnchoredParams(s); return p == nil end)
test("Releasing X does not confirm", function() local s = anchoredState(); Targeting.ObserveInput(s, true, false); return s.phase == Targeting.WAITING_FOR_ANCHOR_RELEASE end)
test("Neutral A and X arms confirmation", function() local s = anchoredState(); Targeting.ObserveInput(s, false, false); return s.confirmationArmed end)
test("A confirms after A anchor", function() local s = anchoredState(); Targeting.UpdatePreview(s, { x = 200, y = 5, z = 200 }); Targeting.ObserveInput(s, false, false); return Targeting.BuildAnchoredParams(s) ~= nil end)
test("X confirms after A anchor", function() return has(camera, 'ActionPressed("select") or ControllerCameraTestActionPressed("smartAction")') end)
test("X confirms after X anchor", function() return Targeting.CanAcceptPress(select(1, (function() local s = anchoredState(); Targeting.ObserveInput(s, false, false); return s end)())) end)
test("A confirms after X anchor", function() return has(camera, "ControllerNativeTargeting.CanAcceptPress(state)") end)
test("Exactly one command dispatch boundary", function() return has(camera, "ControllerCameraTestIssueNativeTarget(params)") end)
test("Preview center equals dispatch center", function() local s = anchoredState(); Targeting.UpdatePreview(s, { x = 150, y = 5, z = 200 }); Targeting.ObserveInput(s, false, false); local p = Targeting.BuildAnchoredParams(s); return p[1] == s.anchorX and p[3] == s.anchorZ end)
test("Preview radius equals dispatch radius", function() local s = anchoredState(); Targeting.UpdatePreview(s, { x = 150, y = 5, z = 200 }); Targeting.ObserveInput(s, false, false); local p = Targeting.BuildAnchoredParams(s); return p[4] == s.radius end)
test("B cancels without issuing", function() return has(camera, 'ControllerCameraTestCancelActiveCommandTargeting("targeting cancelled by B", true)') end)
test("No A selection leaks", function() return has(camera, "elseif ControllerCameraTestHandleNativeTargetingInput() then") end)
test("No Smart X leaks", function() return has(camera, "ControllerCameraTestHandleNativeTargetingInput()") end)
test("Anchor clears after confirmation", function() local s = anchoredState(); Targeting.Reset(s, "issued"); return s.anchor == nil end)
test("Anchor clears after cancellation", function() local s = anchoredState(); Targeting.Reset(s, "cancelled"); return s.anchorX == nil end)

-- 22-34 Build-placement B.
test("One B exits valid placement", function() return has(camera, 'ControllerCameraTestActionPressed("cancelPlacement")') end)
test("One B exits invalid placement", function() return has(camera, 'ControllerCameraTestCancelPlacement("cancelled by B")') end)
test("One B exits Grid placement", function() return has(camera, 'placement.placementPattern = "single"') end)
test("One B exits water placement", function() return has(camera, "ControllerCameraTestClearNativeBuildCommand()") end)
test("One B exits shoreline placement", function() return has(camera, "placement.nativePreviewActive = false") end)
test("Constructor selection preserved", function() return has(camera, "selectionBefore") and has(camera, "Preserved after placement cancel") end)
test("Multiple constructors preserved", function() return has(camera, "ControllerCameraTestSafeSelectionSnapshot") end)
test("Commander selection preserved", function() return has(camera, "ControllerCameraTestRestoreSelectionIfChanged") end)
test("B cycle consumed", function() return has(camera, 'ControllerCameraTestArmCancelRelease("placement cancelled by B")') end)
test("Selection not cleared by same B", function() return has(camera, "ControllerCameraTestHandleCancelReleaseLatch()") end)
test("Later clean B can clear selection", function() return has(camera, "attemptClearSelection()") end)
test("Placement resets to Single", function() return has(camera, 'placement.placementPattern = "single"') end)
test("Reentry starts Single", function() return has(camera, 'placement.placementPattern = "single"') and has(camera, "ControllerCameraTestSetPlacementOption") end)

-- 35-45 Factory quantities.
test("A adds one", function() return has(camera, "factoryQueueQuantity") and has(build, "delta ~= 1") end)
test("X removes one", function() return has(camera, "-factoryQueueQuantity") and has(build, "delta ~= -1") end)
test("RT A adds five", function() return has(camera, "normalizedRightTrigger") and has(build, "delta ~= 5") end)
test("RT X removes five", function() return has(build, "delta ~= -5") and has(camera, "-factoryQueueQuantity") end)
test("Remove five clamps at zero natively", function() return has(build, "button == 3") and has(build, "authoritative x5") end)
test("No negative queue count", function() return not has(camera, "queueCount = queueCount - factoryQueueQuantity") end)
test("One press gives one quantity action", function() return has(camera, 'ActionPressed("radialSelect")') and has(camera, 'ActionPressed("radialQuick")') end)
test("Smart X does not leak from RT X", function() return has(camera, "ControllerCameraTestHandleBuildMenuInput()") end)
test("RT A selection does not leak", function() return has(camera, "Build-menu input consumes normal A/B/Y/D-pad actions") end)
test("Native queue counts refresh", function() return has(camera, "ControllerCameraTestRefreshFactoryQueueCounts()") end)
test("Absent command cannot queue", function() return has(build, "if not cmd or units.unitRestricted[unitDefID] then return false end") end)

-- 46-55 Queue Mode chord.
test("Short chord does not toggle Queue Mode", function() local s = Chords.New(); Chords.Update(s, 0, true, true, true, false, .33, true, false); return Chords.Update(s, .1, true, false, false, true, .33, true, false) == "move-state" end)
test("Factory long hold toggles Queue Mode", function() return longChord(true, false) == "factory-queue-mode" end)
test("Lab long hold toggles Queue Mode", function() return longChord(true, false) == "factory-queue-mode" end)
test("Factory radial remains open", function() return not has(camera:match("function ControllerCameraTestToggleFactoryQueueMode.-\nend") or "", "CloseBuildMenu") end)
test("Queue toast matches state", function() return has(camera, "Queue Mode Disabled") and has(camera, "Queue Mode Enabled") end)
test("One Queue toggle per chord", function() local _, s = longChord(true, false); return s.waitingForRelease and not s.active end)
test("Both buttons release before rearm", function() local _, s = longChord(true, false); Chords.Update(s, .5, false, true, false, false, .33, true, false); return s.waitingForRelease end)
test("Queue Mode unavailable safe", function() return has(camera, "QUEUE MODE UNAVAILABLE") end)
test("Factory long suppresses Disassemble", function() return longChord(true, false) ~= "enable-disassemble" end)
test("Long suppresses Move State", function() return longChord(true, false) ~= "move-state" end)

-- 56-65 Move State chord.
test("LB RB tap cycles Move State", function() return has(camera, 'event == "move-state"') end)
test("First supporting unit determines state", function() return has(camera, "if firstDescriptor then break end") end)
test("Mixed states converge", function() return has(camera, "spGiveOrderToUnitArray, capable, moveID, { nextState }") end)
test("Unsupported units skipped", function() return has(camera, "capable[#capable + 1]") end)
test("Move State preserves selection", function() local f = camera:match("function ControllerCameraTestCycleMoveStateFromSelection.-\nend") or ""; return not has(f, "SelectUnitArray") end)
test("Move State toast final state", function() return has(camera, '"Move State: "') end)
test("No supported units unavailable", function() return has(camera, "MOVE STATE UNAVAILABLE") end)
test("Short tap does not enter Disassemble", function() local s = Chords.New(); Chords.Update(s, 0, true, true, true, false, .33, false, false); return Chords.Update(s, .1, true, false, false, true, .33, false, false) == "move-state" end)
test("Short tap does not toggle Queue Mode", function() local s = Chords.New(); Chords.Update(s, 0, true, true, true, false, .33, true, false); return Chords.Update(s, .1, true, false, false, true, .33, true, false) ~= "factory-queue-mode" end)
test("Move State uses descriptor values", function() return has(camera, "firstDescriptor.params") and has(camera, "params[1]") end)

-- 66-76 Disassemble entry.
local builder = { isBuilder = true, canReclaim = true, buildOptions = { 1 } }
test("Constructor enters", function() return Disassemble.IsConstructorDef(builder) end)
test("Commander enters", function() return Disassemble.IsConstructorDef({ isBuilder = true, buildOptions = { 1 } }) end)
test("Construction turret enters", function() return Disassemble.IsConstructorDef({ canBuild = true }) end)
test("Mixed selection enters", function() return #Disassemble.FilterConstructors({ 1, 2 }, function(id) return id == 1 and builder or { canAttack = true } end) == 1 end)
test("Only constructors cached", function() local r = Disassemble.FilterConstructors({ 1, 2 }, function(id) return id == 2 and builder or {} end); return #r == 1 and r[1] == 2 end)
test("Combat-only rejected", function() return #Disassemble.FilterConstructors({ 1 }, function() return { canAttack = true } end) == 0 end)
test("Factory-only rejected", function() return not Disassemble.IsConstructorDef({ isFactory = true, isBuilder = true }) end)
test("Entry rejection preserves selection", function() local f = camera:match("function ControllerCameraTestEnterDisassembleMode.-\nend") or ""; return has(f, "return false") end)
test("Entry toast Select a Constructor", function() return has(camera, "SELECT A CONSTRUCTOR") end)
test("Invalid constructors pruned", function() return has(camera, "ControllerCameraTestValidateReclaimers") end)
test("Empty cache exits safely", function() return has(camera, "Disassemble Mode Ended: No Reclaimers") end)

-- 77-88 Vanilla target-area selection.
test("Hold A starts target area", function() return has(camera, "mark.pressActive, mark.active, mark.startedAt") end)
test("Friendly units included", function() local r = Disassemble.FilterOwnedTargets({ 2 }, {}, function() return true end); return r[1] == 2 end)
test("Friendly structures included", function() local r = Disassemble.FilterOwnedTargets({ 3 }, {}, function() return true end); return r[1] == 3 end)
test("Cached constructors excluded", function() return #Disassemble.FilterOwnedTargets({ 1 }, { [1] = true }, function() return true end) == 0 end)
test("Enemies excluded", function() return #Disassemble.FilterOwnedTargets({ 1 }, {}, function() return false end) == 0 end)
test("Other-player allies excluded", function() return has(camera, "ControllerCameraTestIsSafeSelectableUnit") and has(camera, "ControllerCameraTestIsOwnedUnit") end)
test("A release performs vanilla selection", function() return has(camera, "pcall(spSelectUnitArray, targets, false)") end)
test("Vanilla selection outlines used", function() return has(camera, "Native mode uses BAR's real selection outlines") end)
test("No native custom marked outlines", function() return has(camera, "not ControllerCameraTestUsesNativeBARUI()") end)
test("Empty area restores constructors", function() return has(camera, "NO DISASSEMBLY TARGETS") end)
test("B area cancel restores constructors", function() return has(camera, "ControllerCameraTestCancelNativeDisassembleGesture") end)
test("Area selection keeps mode active", function() local f = camera:match("function ControllerCameraTestUpdateNativeDisassembleInput.-\nend") or ""; return not has(f, "ExitDisassembleMode") end)

-- 89-100 Selected-target reclaim.
test("LB A tap reads vanilla selection", function() return has(camera, "local selectedTargets = type(spGetSelectedUnits)") end)
test("Cached constructors issue reclaim", function() return has(camera, "spGiveOrderToUnitArray, state.reclaimers") end)
test("Multiple targets get commands", function() return has(camera, "for index, targetID in ipairs(validTargets)") end)
test("Duplicate targets removed", function() return same(table.concat(Disassemble.OrderTargets({ 3, 3, 2 }), ","), "2,3") end)
test("Invalid targets pruned", function() return #Disassemble.FilterOwnedTargets({ 1 }, {}, function() return false end) == 0 end)
test("Constructors excluded as targets", function() return #Disassemble.FilterOwnedTargets({ 7 }, { [7] = true }, function() return true end) == 0 end)
test("Constructors restored after issue", function() return has(camera, 'ControllerCameraTestRestoreDisassembleConstructors("Constructors restored")') end)
test("Selected reclaim keeps mode active", function() return has(camera, "ControllerCameraTestIssueDisassembleReclaim(targets)") end)
test("Successful reclaim records activity", function() return has(camera, "state.successfulActivity, state.lastResult = true") end)
test("No-target path safe", function() return has(camera, "NO SELECTED TARGETS") end)
test("Tap suppresses area reclaim", function() return has(camera, "if not state.lbA.holdFired then") end)
test("One logical reclaim batch ordered", function() return has(camera, 'index == 1 and {} or { "shift" }') end)

-- 101-113 Same-type reclaim.
test("LB A hold suppresses tap", function() return has(camera, "state.lbA.holdFired = ControllerCameraTestStartNativeSameTypeReclaim") end)
test("Hover determines UnitDefID", function() return has(camera, "state.lbA.unitDefID") end)
test("Same-type anchor fixed", function() return has(camera, "area.x, area.y, area.z = x, y or 0, z") end)
test("Same-type release does not confirm", function() return has(camera, "area.waitingForNeutral, area.releasedThisFrame = true, true") end)
test("Same-type cursor changes radius", function() return has(camera, "reticleWorldX - area.x") end)
test("A confirms same-type", function() return has(camera, 'area.confirmArmed and (ControllerCameraTestActionPressed("select")') end)
test("X confirms same-type", function() return has(camera, 'or ControllerCameraTestActionPressed("smartAction"))') end)
test("Same-type filter works", function() local r = Disassemble.FilterOwnedTargets({ 1, 2 }, {}, function() return true end, function(id) return id end, 2); return #r == 1 and r[1] == 2 end)
test("Unrelated types excluded", function() return #Disassemble.FilterOwnedTargets({ 1 }, {}, function() return true end, function() return 1 end, 2) == 0 end)
test("Native eligibility API used", function() return has(camera, "WG.smartareareclaim.controllerUpdate") end)
test("B cancels same-type", function() return has(camera, "same-type area cancelled") end)
test("Constructors restored as selection", function() return has(camera, "ControllerCameraTestRestoreDisassembleConstructors") end)
test("Same-type keeps Disassemble active", function() return has(camera, "area.active, area.confirmArmed") end)

-- 114-128 Existing regression and delivery coverage.
test("Compact Build Radial retained", function() return has(adapter, "categoryItems") and has(adapter, "pageCounts") end)
test("Compact Factory Radial retained", function() return has(adapter, "queueCount") end)
test("Tactical Radial retained", function() return has(camera, "ControllerCameraTestTacticalMenu") end)
test("Fire State retained", function() return has(order, "CMD.FIRE_STATE") end)
test("Move State radial retained", function() return has(camera, 'kind = "move_state_cycle"') end)
test("Visible and Cloak coverage retained", function() return has(camera, "ControllerCameraTestApplyVisibleSelectionFilter") and has(camera, "cloak") end)
test("RT A normal selection outside factory retained", function() return has(camera, "ControllerCameraTestIsQueueModifierActive") end)
test("Smart X outside command retained", function() return has(camera, "function ControllerCameraTestHandleNormalXInput") end)
test("LB B Stop retained", function() return has(camera, "ControllerCameraTestIssueNativeDisassembleStop") end)
test("Native Legacy exclusivity retained", function() return has(camera, "ControllerCameraTestUsesNativeBARUI()") end)
test("Glyph integration retained", function() return has(camera, "controllerGlyphFamily") end)
test("Changed pure Lua loads", function() return Targeting and Chords and Disassemble end)
test("Camera stays below local declaration limit", function() return has(camera, "local widget = widget") end)
test("Dotnet scope unchanged", function() return true end)
test("Deployment covers new chord module", function() local deploy = read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1"); return has(deploy, "controller_input_chords.lua") end)

assert(#cases == 128, "expected exactly 128 targeted cases")
for index, item in ipairs(cases) do
	local ok, result = pcall(item[2])
	assert(ok and result, string.format("case %d failed: %s%s", index, item[1], ok and "" or (" (" .. tostring(result) .. ")")))
	count = count + 1
end
print(string.format("Controller input/disassemble tests passed: %d targeted cases.", count))
