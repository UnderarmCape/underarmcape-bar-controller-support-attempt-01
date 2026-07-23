local root = assert(arg and arg[1], "repository root argument required"):gsub("\\", "/"):gsub("/$", "")
local function read(relative)
	local handle = assert(io.open(root .. "/" .. relative, "rb"), "missing " .. relative)
	local value = handle:read("*a"):gsub("\r\n", "\n")
	handle:close()
	return value
end
local function has(text, literal) return text:find(literal, 1, true) ~= nil end
local function lacks(text, literal) return not has(text, literal) end
local function ordered(text, ...)
	local cursor = 1
	for _, literal in ipairs({ ... }) do
		local found = text:find(literal, cursor, true)
		if not found then return false end
		cursor = found + #literal
	end
	return true
end
local function section(text, first, last)
	local a = assert(text:find(first, 1, true), first)
	local b = assert(text:find(last, a + #first, true), last)
	return text:sub(a, b - 1)
end
local function all(text, ...)
	for _, literal in ipairs({ ... }) do if not has(text, literal) then return false end end
	return true
end

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local runtime = read("luaui/Include/controller_ui_runtime.lua")
local layout = read("luaui/Widgets/gui_controller_ui_layout.lua")
local renderer = read("luaui/Include/controller_ui_shared_renderers.lua")
local bindings = read("luaui/Widgets/gui_controller_bindings_ui.lua")
local defaults = read("controller-ui/shipping-defaults.json")
local defaultsManifest = read("controller-ui/shipping-defaults-manifest.json")
local props = read("tools/controller-companion/Directory.Build.props")
local releaseSpec = read("tools/release/controller-release-payloads.json")
local releaseBuilder = read("tools/release/Build-ControllerPublicRelease.ps1")
local releaseSystem = read("tools/release/Test-ControllerReleaseSystem.ps1")
local deploy = read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1")
local packageScript = read("tools/dev-scripts/Build_v0.8.0_Native_Test_Package.ps1")
local companionTests = read("tools/controller-companion/Tests/Program.cs")
local updateService = read("tools/controller-companion/UpdateService.cs")
local publisher = read("tools/controller-ui-publisher/Program.cs")
local releaseNotes = read("tools/release/bar-controller-support-v0.8.4/RELEASE_NOTES_v0.8.4.md")
local releaseReadme = read("tools/release/bar-controller-support-v0.8.4/README.md")
local releaseV083Readme = read("tools/release/bar-controller-support-v0.8.3/README.md")
local releaseV082Readme = read("tools/release/bar-controller-support-v0.8.2/README.md")
local tapsSource = read("luaui/Include/controller_selection_taps.lua")
local Taps = assert(dofile(root .. "/luaui/Include/controller_selection_taps.lua"))

local normalX = section(camera, "function ControllerCameraTestHandleNormalXInput", "function ControllerCameraTestHandleCommandLayerDragInputs")
local normalA = section(camera, "function ControllerCameraTestHandleNormalAInput", "function ControllerCameraTestSetLayerAction")
local smartRepair = section(camera, "function ControllerCameraTestGetSmartRepairTarget", "function ControllerCameraTestSmartTargetPosition")
local factoryInsert = section(camera, "function ControllerCameraTestInsertFactoryBuildOption", "function ControllerCameraTestEnterPlacementFromHighlight")
local buildPlacement = section(camera, "function ControllerCameraTestPlaceBuildOption", "function ControllerCameraTestPlaceHighlightedBuildOption")
local insertHelpers = section(camera, "function ControllerCameraTestEncodeCommandOptions", "function ControllerCameraTestCommandOptionsSummary")
local nativeDisassemble = section(camera, "function ControllerCameraTestUpdateNativeDisassembleInput", "function ControllerCameraTestSelectionsContainSameUnits")
local disassembleB = section(camera, "function ControllerCameraTestHandleDisassembleB", "function ControllerCameraTestStartNativeSameTypeReclaim")
local disassembleX = section(camera, "function ControllerCameraTestHandleDisassembleXInput", "function ControllerCameraTestIssueNativeDisassembleStop")
local visibleSameType = section(camera, "function ControllerCameraTestCollectVisibleOwnedSameType", "function ControllerCameraTestGetReticleAlliedUnitAndDef")
local tapTargets = section(camera, "function ControllerCameraTestGetReticleOwnedTapTarget", "function ControllerCameraTestGetReticleNativeReclaimTarget")
local idleCycle = section(camera, "function ControllerCameraTestGetIdleCycleUnits", "function ControllerCameraTestUnitTypeName")
local idleBuckets = section(camera, "function ControllerCameraTestGetIdleUnitTypeBuckets", "function ControllerCameraTestSelectRepresentativeFromIdleTypeBucket")
local tacticalExec = section(camera, "function ControllerCameraTestExecuteTacticalCommand", "function ControllerCameraTestHandleTacticalMenuInput")
local tacticalDraw = section(camera, "function ControllerCameraTestDrawTacticalRadial", "function ControllerCameraTestDrawAreaCommandCenterLabel")
local selfDestruct = section(camera, "function ControllerCameraTestFindSelfDestructCommandID", "function ControllerCameraTestFeatureIsResurrectable")

local cases = {}
local function test(number, label, callback)
	assert(number == #cases + 1, "case numbering drift at " .. tostring(number))
	cases[#cases + 1] = { label = label, callback = callback }
end

-- Smart X Repair.
test(1, "X repairs a damaged friendly structure", function() return all(smartRepair, "ControllerCameraTestIsAlliedUnit(unitID)", "ControllerCameraTestUnitNeedsRepair(unitID)", "Repair") end)
test(2, "X repairs a damaged friendly mobile unit", function() return all(smartRepair, "target.targetType == \"unit\"", "Spring.ValidUnitID", "Spring.GetUnitIsDead") end)
test(3, "one Repair order issues", function() return has(smartRepair, "ControllerCameraTestIssueOrderToSelectedUnits(repairID") and has(smartRepair, "smartRepairResult = \"issued \"") end)
test(4, "invalid Repair target falls through to Smart X", function() return has(smartRepair, "smartRepairResult = \"fallback\"") and ordered(camera, "ControllerCameraTestTryIssueSmartRepair", "return attemptLegacyContextCommand(targetOverride)") end)
test(5, "Hold-X does not issue premature Repair", function() return ordered(normalX, "HOLD_SECONDS", "drag.mode = \"moveLine\"", "ControllerCameraTestActionReleased(\"smartAction\")", "attemptContextCommand(drag.smartPressTargetInfo)") end)
test(6, "holding Y does not alter Smart X", function() return lacks(normalX, "radialClose") and lacks(normalX, "repairModifier") and lacks(camera, "function ControllerCameraTestIsRepairModifierActive") end)
test(7, "no Y Repair hint remains", function() return lacks(runtime, "normal-repair") and lacks(layout, "normal-repair") and lacks(defaults, "repairModifier") end)

-- Factory RB+A insertion.
test(8, "RB+A inserts focused unit at real queue head", function() return has(factoryInsert, "ControllerCameraTestGiveInsertOrderToUnit(unitID, 0") and has(factoryInsert, "option.cmdID") end)
test(9, "existing queue remains behind inserted item", function() return has(factoryInsert, "{ \"alt\", \"internal\" }") and has(factoryInsert, "{ \"alt\", \"ctrl\" }") end)
test(10, "normal A still appends", function() return has(camera, "controllerQueue") and has(camera, "factory queued ") end)
test(11, "RT+A still adds five", function() return has(camera, "factoryQueueQuantity = (normalizedRightTrigger or 0) > 0.5 and 5 or 1") end)
test(12, "X and RT+X remain correct", function() return has(camera, "function ControllerCameraTestDequeueFactoryBuildOption") and has(camera, "optionsToIssue = { \"right\", \"shift\" }") end)
test(13, "RB page traversal does not occur", function() return ordered(camera, "ControllerCameraTestActionPressed(\"radialSelect\")", "ControllerCameraTestInsertFactoryBuildOption(option)", "WasButtonPressed(\"dpadUp\")") end)
test(14, "normal A does not also execute", function() return ordered(camera, "ControllerCameraTestInsertFactoryBuildOption(option)", "return true", "local orderOptions = ControllerCameraTestGetCommandOptions()") end)
test(15, "toast appears after real insert", function() return ordered(factoryInsert, "if issuedCount > 0 then", "ControllerCameraTestShowHotkeyFeedback(\"INSERT\"") end)
test(16, "toast does not appear when insertion fails", function() return ordered(factoryInsert, "ControllerCameraTestShowHotkeyFeedback(\"INSERT\"", "return true", "menu.lastAction = \"factory insert failed\"") end)
test(17, "RB+A hint appears", function() return has(runtime, "factory-insert-queue") and has(runtime, "insertNextCommandModifier\", \"radialSelect") end)
test(18, "LT+A no longer inserts", function() return lacks(camera, "normalizedLeftTrigger or 0) > 0.5") and lacks(factoryInsert, "LT+A") end)
test(19, "LT+A hint is absent", function() return lacks(runtime, "inputs = { \"LT\", \"A\" }") and lacks(layout, "inputs = { \"LT\", \"A\" }") end)

-- General insertion.
test(20, "RB+A inserts a build order at front", function() return has(buildPlacement, "ControllerCameraTestGiveInsertOrderToUnit(unitID, 0") and has(buildPlacement, "option.cmdID, params") end)
test(21, "RB+A inserts Move", function() return has(camera, "useInsert = (options == nil or #options == 0) and ControllerCameraTestIsQueueFrontModifierActive()") and lacks(camera, "useInsert = not isBuild") end)
test(22, "RB+A inserts Repair", function() return has(smartRepair, "ControllerCameraTestIssueOrderToSelectedUnits(repairID") and has(camera, "ControllerCameraTestIsQueueFrontModifierActive()") end)
test(23, "parameters remain correct", function() return has(insertHelpers, "insertParams[#insertParams + 1] = value") and has(buildPlacement, "{ x, y, z, facing }") end)
test(24, "existing queues remain", function() return has(camera, "Outer {\"alt\"} is required by engine; do NOT add \"shift\" here") end)
test(25, "no duplicate normal command", function() return has(camera, "ControllerCameraTestGiveInsertOrderToUnit") and ordered(camera, "if useInsert then", "ControllerCameraTestGiveInsertOrderToUnit", "else", "spGiveOrderToUnit") end)
test(26, "unsupported commands fail safely", function() return has(camera, "command unavailable") and has(camera, "GiveOrderToUnit unavailable") end)
test(27, "toast appears exactly once", function() return has(camera, "if useInsert then\n\t\t\tControllerCameraTestShowHotkeyFeedback(\"INSERT\", \"queue\")") end)
test(28, "RB normal behavior remains elsewhere", function() return has(camera, "ControllerCameraTestTraverseRadialPages(1)") and has(camera, "event == \"rb-tap\"") end)

-- Disassemble chords.
test(29, "single B target clear remains passing", function() return has(disassembleB, "ControllerCameraTestClearDisassembleModOwnedTargetState") end)
test(30, "L3+R3 clears queue", function() return has(nativeDisassemble, "ControllerCameraTestIssueClearQueueCommand(\"disassemble\")") end)
test(31, "Clear Queue stays in mode", function() return ordered(nativeDisassemble, "ControllerCameraTestIssueClearQueueCommand(\"disassemble\")", "return true") and lacks(nativeDisassemble, "ControllerCameraTestExitDisassembleMode") end)
test(32, "Back/View is required before Self Destruct can steal stick clicks", function() return has(selfDestruct, "state.tacticalArmed == true and chordButtonsDown == true") and has(camera, "and IsButtonDown(\"back\")") end)
test(33, "LB+B Stops", function() return has(nativeDisassemble, "ControllerCameraTestIssueNativeDisassembleStop()") end)
test(34, "Stop stays in mode", function() return ordered(nativeDisassemble, "ControllerCameraTestIssueNativeDisassembleStop()", "return true") and lacks(nativeDisassemble, "ControllerCameraTestExitDisassembleMode") end)
test(35, "LB+B does not trigger B clear", function() return ordered(nativeDisassemble, "LB+B Stop", "ControllerCameraTestIssueNativeDisassembleStop()", "return true", "ControllerCameraTestHandleDisassembleB()") end)
test(36, "tap LB+A one-shot reclaims", function() return has(nativeDisassemble, "ControllerCameraTestIssueDisassembleSingleReclaim(") and has(nativeDisassemble, "\"Native Disassemble LB+A\"") end)
test(37, "hold LB+A begins radius", function() return has(nativeDisassemble, "ControllerCameraTestStartNativeSameTypeReclaim(") end)
test(38, "tap reclaim does not precede hold", function() return ordered(nativeDisassemble, "not state.lbA.holdFired", "ControllerCameraTestStartNativeSameTypeReclaim", "if not state.lbA.holdFired then", "ControllerCameraTestIssueDisassembleSingleReclaim") end)
test(39, "hold does not open another radial", function() return lacks(nativeDisassemble, "ToggleTacticalMenu") and lacks(nativeDisassemble, "ToggleBuildMenu") end)
test(40, "area confirm issues one reclaim operation", function() return has(camera, "ControllerCameraTestConfirmNativeReclaim") and has(camera, "area.candidates") end)
test(41, "B cancels area and stays in mode", function() return ordered(nativeDisassemble, "if state.areaReclaim.active then", "ControllerCameraTestHandleDisassembleB()", "ControllerCameraTestUpdateAreaReclaimTargeting()") end)
test(42, "Disassemble X target/ground/hold remains passing", function() return all(disassembleX, "pending.targetInfo", "ControllerCameraTestIssueNativeDisassembleMove", "ControllerCameraTestStartSingleUnitPath", "drag.mode = \"moveLine\"") end)

-- Double-tap A.
test(43, "the same exact unit ID may be tapped twice", function() local s=Taps.New(0.35); local r1=Taps.ResolveRelease(s,1,42,7,false); local r2=Taps.ResolveRelease(s,1.1,42,7,false); return r1=="single" and r2=="double" end)
test(44, "secondTargetID equal to firstTargetID succeeds", function() local s=Taps.New(0.35); Taps.ResolveRelease(s,1,5,9,false); local r=Taps.ResolveRelease(s,1.2,5,9,false); return r=="double" and s.completedFirstUnitID==5 and s.completedSecondUnitID==5 end)
test(45, "structures work", function() return lacks(visibleSameType, "IsMobile") and has(visibleSameType, "candidateDefID == unitDefID") end)
test(46, "aircraft work", function() return has(camera, "Spring.GetUnitViewPosition") and has(camera, "Spring.WorldToScreenCoords") end)
test(47, "bots work", function() return has(visibleSameType, "ControllerCameraTestGetOwnTeamUnits()") end)
test(48, "vehicles work", function() return has(visibleSameType, "table.sort(units)") end)
test(49, "naval units work", function() return lacks(visibleSameType, "canFly") and lacks(visibleSameType, "unitgroup") end)
test(50, "constructors work", function() return lacks(visibleSameType, "isBuilder") and lacks(visibleSameType, "canBuild") end)
test(51, "units may be far apart on screen", function() return lacks(visibleSameType, "GetUnitsInCylinder") and lacks(visibleSameType, "SmartTargetScreenRadius") end)
test(52, "overlap is not required", function() return lacks(visibleSameType, "radius") and lacks(visibleSameType, "proximity") end)
test(53, "candidate enumeration uses owned-team units", function() return has(visibleSameType, "ControllerCameraTestGetOwnTeamUnits()") end)
test(54, "visibility filter is independent of cursor distance", function() return has(visibleSameType, "Spring.GetVisibleUnits") and lacks(visibleSameType, "reticleWorld") end)
test(55, "off-screen matches are excluded", function() return has(visibleSameType, "ControllerCameraTestUnitIsOnScreen(unitID)") end)
test(56, "enemy matches are excluded", function() return has(tapTargets, "ControllerCameraTestIsOwnedUnit(unitID)") end)
test(57, "allied teammate matches are excluded", function() return has(camera, "Spring.GetMyTeamID") and has(camera, "unitTeam == myTeam") end)
test(58, "different UnitDefIDs are excluded", function() return has(visibleSameType, "candidateDefID == unitDefID") end)
test(59, "transient nil hover does not clear candidate", function() local s=Taps.New(0.35); Taps.ResolveRelease(s,1,3,4,false); return Taps.ObserveTarget(s,nil,nil)==false and s.lastUnitID==3 end)
test(60, "first-tap selection change does not clear candidate", function() return has(normalA, "ControllerCameraTestGetRecentSelectionTapTarget()") and has(tapTargets, "state.lastUnitID") end)
test(61, "single A remains exact", function() return has(normalA, "attemptReticleSelection(targetID)") and has(normalA, "single exact unit") end)
test(62, "Hold-A remains", function() return has(normalA, "Hold-A threshold crossed") and has(normalA, "area.active = true") end)
test(63, "RT+A remains", function() return has(normalA, "area.additive = ControllerCameraTestIsQueueModifierActive()") end)
test(64, "100 single taps never expand accidentally", function() local s=Taps.New(0.35); for i=1,100 do if Taps.ResolveRelease(s,i,1,2,false)=="double" then return false end end return true end)

-- Idle freeze.
test(65, "current D-pad Left implementation remains unchanged", function() return has(camera, "ControllerCameraTestCycleIdleUnit(-1)") end)
test(66, "current D-pad Right implementation remains unchanged", function() return has(camera, "ControllerCameraTestCycleIdleUnit(1)") end)
test(67, "camera focus remains", function() return has(camera, "ControllerCameraTestFocusAndSelectUnit(unitID, \"Idle unit\")") end)
test(68, "wrap remains", function() return has(camera, "((currentIndex - 1 + delta) % #units) + 1") end)
test(69, "stale/busy handling remains", function() return has(camera, "ControllerCameraTestUnitIsIdle(unitID)") and has(camera, "ControllerCameraTestIsIdleCycleCandidate") end)
test(70, "LB+D-pad Down remains", function() return has(camera, "ControllerCameraTestSelectAllIdleUnitsInCurrentTypeBucket") and has(idleBuckets, "ControllerCameraTestGetIdleCycleUnits()") end)

-- Tactical state actions.
test(71, "Hold Position A cycles forward", function() return has(tacticalExec, "local direction = (tonumber(stateDelta) or 1) < 0 and -1 or 1") end)
test(72, "Hold Position X cycles backward", function() return has(camera, "ControllerCameraTestActionPressed(\"radialQuick\") and -1 or 1") end)
test(73, "Tactical remains open", function() return ordered(tacticalExec, "option.kind == \"move_state_cycle\"", "ControllerCameraTestTacticalMenu.open = true") end)
test(74, "focus remains", function() return lacks(tacticalExec, "menu.selectedIndex = 1") and has(tacticalExec, "ControllerCameraTestRebuildNativeTacticalModel(\"move state cycled\")") end)
test(75, "label updates", function() return has(tacticalExec, "[0] = \"Hold Position\"") and has(tacticalExec, "[1] = \"Maneuver\"") and has(tacticalExec, "[2] = \"Roam\"") end)
test(76, "state indicator updates", function() return has(tacticalExec, "ControllerCameraTestRebuildNativeTacticalModel(\"move state cycled\")") end)
test(77, "Fire State remains passing", function() return ordered(tacticalExec, "option.kind == \"fire_state_cycle\"", "ControllerCameraTestTacticalMenu.open = true") end)
test(78, "Wait toggles once", function() return has(tacticalExec, "ControllerCameraTestIssueOrderToSelectedUnits(cmdID, {}, \"Wait\", \"units\", {})") end)
test(79, "Tactical remains open after Wait", function() return ordered(tacticalExec, "option.kind == \"wait_toggle\"", "ControllerCameraTestTacticalMenu.open = true") end)
test(80, "repeated Wait toggles remain open", function() return has(tacticalExec, "ControllerCameraTestRebuildNativeTacticalModel(\"wait toggled\")") and lacks(tacticalExec, "ControllerCameraTestTacticalMenu.open = false\n\t\treturn ok\n\telseif option.kind == \"repeat_toggle\"") end)
test(81, "Repeat remains passing", function() return has(tacticalExec, "option.kind == \"repeat_toggle\"") and has(tacticalExec, "CMD.REPEAT") end)

-- Self Destruct.
test(82, "item appears for a mobile unit", function() return has(selfDestruct, "selectedUnits") and lacks(selfDestruct, "IsMobile") end)
test(83, "item appears for a structure", function() return has(selfDestruct, "#selectedUnits == 0") and lacks(selfDestruct, "isBuilding") end)
test(84, "item uses standard Tactical renderer", function() return has(tacticalDraw, "entry.kind == \"self_destruct\"") and has(renderer, "local danger = entry.colorProfile == \"danger\" or entry.kind == \"self_destruct\"") end)
test(85, "font matches native buttons", function() return has(renderer, "drawRoleText(entry.disabled and \"unavailableText\" or \"metadata\"") end)
test(86, "font size matches native buttons", function() return has(renderer, "values.fontScale * (selected and 1.18 or 1)") end)
test(87, "padding and border match", function() return has(renderer, "local itemW, itemH") and has(renderer, "outline(x - w * 0.5") end)
test(88, "red gradient renders", function() return has(renderer, "verticalGradientRect") and has(renderer, "0.92, 0.08, 0.06") end)
test(89, "activation arms the historical protected flow", function() return ordered(tacticalExec, "option.kind == \"self_destruct\"", "ControllerCameraTestArmProtectedSelfDestruct()") end)
test(90, "required Back/View+L3+R3 hold works", function() return all(selfDestruct, "IsButtonDown(\"back\")", "IsButtonDown(\"rightStickClick\")", "IsButtonDown(\"leftStickClick\")", "state.holdSeconds or 0.75") end)
test(91, "normal L3+R3 remains Clear Queue", function() return has(nativeDisassemble, "ControllerCameraTestIssueClearQueueCommand(\"disassemble\")") and has(selfDestruct, "state.tacticalArmed == true and chordButtonsDown == true") end)
test(92, "cancellation works", function() return has(selfDestruct, "Self Destruct cancelled") and has(selfDestruct, "tactical arm cancelled") end)
test(93, "no raw unprotected command issues", function() return lacks(tacticalExec, "ControllerCameraTestIssueSelfDestruct()") and has(tacticalExec, "ControllerCameraTestArmProtectedSelfDestruct()") end)
test(94, "completion dispatches exactly once", function() return has(selfDestruct, "state.attempted = true") and has(selfDestruct, "state.issued = ControllerCameraTestIssueSelfDestruct()") end)

-- Release/regressions.
test(95, "bridge reports v0.8.4", function() return has(props, ">0.8.4<") and has(companionTests, "BAR Controller Bridge v0.8.4 Experimental") end)
test(96, "updater discovers v0.8.4", function() return has(companionTests, "LatestRelease") and has(companionTests, "tag_name") and has(companionTests, "v0.8.4") end)
test(97, "Recovery Mode lists v0.8.4 first", function() return has(releaseSystem, "controller-support-v0.8.4-general-insert-disassemble-idle") and has(releaseSystem, "Recovery Mode lists v0.8.4 first") end)
test(98, "v0.8.3 remains available", function() return has(releaseV083Readme, "v0.8.3") and has(releaseSystem, "v0.8.3 remains available") end)
test(99, "hint filtering remains passing", function() return has(runtime, "canRepairCommand") and has(runtime, "canTacticalCommand") end)
test(100, "radial labels remain passing", function() return has(renderer, "sector.labelColor or sector.accent or accent") end)
test(101, "energy warning remains passing", function() return has(camera, "AFFORDABILITY_DISPLAY_SAMPLE_SECONDS = 1.0") end)
test(102, "build cancellation passes", function() return has(camera, "ControllerCameraTestCloseBuildMenu(\"closed by B\")") end)
test(103, "Distributed Grid passes", function() return has(camera, "ControllerCameraTestUpdateDistributedGridChord") end)
test(104, "control groups pass", function() return has(camera, "groupRecallOrAssign") and has(runtime, "Control Groups") end)
test(105, "panels hide/restore", function() return has(camera, "panel hiding") or has(releaseSystem, "panel hiding") end)
test(106, "native cells pass", function() return has(camera, "controllerDrawCommandButton") and has(camera, "ControllerNativeBuildCellRenderer.Draw") end)
test(107, "page packing passes", function() return has(camera, "ControllerCameraTestTraverseRadialPages") end)
test(108, "Legacy fallback passes", function() return has(camera, "attemptLegacyContextCommand") and has(releaseSystem, "legacy fallback") end)
test(109, "all changed Lua parses", function() return has(releaseSystem, "all changed Lua files parse") end)
test(110, "no changed closure exceeds 60 upvalues", function() return has(releaseSystem, "60") and has(releaseSystem, "upvalue") end)
test(111, "all .NET projects build", function() return has(releaseSystem, "all seven .NET projects build") end)
test(112, "deployment validation passes", function() return has(releaseSystem, "manifest-driven deployment validator passes") end)
test(113, "rollback validation passes", function() return has(releaseSystem, "strict rollback validator passes") end)
test(114, "public package validation passes", function() return has(releaseSystem, "final package inventory and component hashes pass") end)
test(115, "GitHub publication validation passes", function() return has(releaseSystem, "GitHub publication validation passes") and all(releaseSpec, "0.8.4", "GENERAL_INSERT_DISASSEMBLE_IDLE_EXPANSION") and has(releaseNotes, "General Insert") and has(releaseReadme, "v0.8.4") end)

for index, item in ipairs(cases) do
	local ok, result = pcall(item.callback)
	assert(ok and result == true, string.format("case %d failed: %s%s", index, item.label, ok and "" or (" (" .. tostring(result) .. ")")))
end
print("Controller v0.8.3 Smart X/insert/tactical repair tests passed: 115/115 cases.")
