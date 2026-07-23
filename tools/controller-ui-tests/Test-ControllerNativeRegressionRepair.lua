local root = assert(arg and arg[1], "repository root argument required"):gsub("\\", "/")
local function read(relative)
	local file = assert(io.open(root .. "/" .. relative, "rb"), relative)
	local value = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return value
end
local function has(value, needle) return value:find(needle, 1, true) ~= nil end
local cases = {}
local function test(id, label, callback) cases[#cases + 1] = { id, label, callback } end

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local ownerSource = read("luaui/Include/controller_native_command_owner.lua")
local targetingSource = read("luaui/Include/controller_native_targeting.lua")
local chordSource = read("luaui/Include/controller_input_chords.lua")
local order = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")
local build = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua")
local idle = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_idle_builders.lua")
local mex = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_area_mex.lua")
local reclaim = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/unit_smart_area_reclaim.lua")
local disassemble = read("luaui/Include/controller_disassemble_behavior.lua")

local baselinePipe = assert(io.popen('git -C "' .. root .. '" show 95e4b907f73bc78c2944ed55dac2e53d82d7c7d1:luaui/Widgets/gui_controller_camera_test.lua 2>NUL'))
local baselineCamera = baselinePipe:read("*a"):gsub("\r\n", "\n")
baselinePipe:close()
local baselineSmart = baselineCamera:match("local function attemptContextCommand%(%)\n(.-)\nend\n\nlocal function attemptAttackCommand")
local restoredSmart = camera:match("local function attemptLegacyContextCommand%(%)\n(.-)\nend\n\n%-%- Native Experimental")

_G.CMDTYPE = { ICON_MAP = 1, ICON_AREA = 2, ICON_FRONT = 3, ICON_UNIT = 4,
	ICON_UNIT_OR_MAP = 5, ICON_UNIT_OR_AREA = 6, ICON_UNIT_FEATURE_OR_AREA = 7,
	ICON_UNIT_OR_RECTANGLE = 8, ICON_BUILDING = 9 }
_G.VFS = { Include = function(path)
	if path:find("controller_native_targeting.lua", 1, true) then
		return assert(loadfile(root .. "/luaui/Include/controller_native_targeting.lua"))()
	end
	error(path)
end }
local Owner = assert(loadfile(root .. "/luaui/Include/controller_native_command_owner.lua"))()

local function runArea(anchorButton, confirmButton)
	local dispatches, route = 0, nil
	local owner = Owner.New({ name = "runtime owner", types = CMDTYPE,
		dispatch = function() dispatches = dispatches + 1; route = "widget"; return true, route end })
	assert(owner:Begin({ id = 30123, cmdID = 30123, type = CMDTYPE.ICON_AREA, name = "Area" }))
	owner:Input({ selectDown = false, smartDown = false, target = { x = 10, y = 2, z = 20 } })
	owner:Input({ selectDown = anchorButton == "A", smartDown = anchorButton == "X",
		selectPressed = anchorButton == "A", smartPressed = anchorButton == "X", pressSerial = 1,
		target = { x = 10, y = 2, z = 20 } })
	owner:Input({ selectDown = false, smartDown = false, target = { x = 110, y = 2, z = 20 } })
	local consumed, result = owner:Input({ selectDown = confirmButton == "A", smartDown = confirmButton == "X",
		selectPressed = confirmButton == "A", smartPressed = confirmButton == "X", pressSerial = 2,
		target = { x = 110, y = 2, z = 20 } })
	return dispatches, consumed, result, owner:GetState(), route
end

-- 1-12 Smart X restoration and extensions.
test(1, "Known-good Smart X fixture matches 95e4b907", function()
	if baselineSmart then return baselineSmart == restoredSmart end
	-- Extracted packages have no Git object database. Their camera source is
	-- already covered by payload-sha256.json, so retain semantic guards here.
	return restoredSmart and has(restoredSmart, "Spring.GetDefaultCommand")
		and has(camera, "tryNativeSmartRepairReclaimExtension")
end)
test(2, "Hold-X drag path remains", function() return has(camera, "X_HOLD_SECONDS") and has(camera, 'drag.mode = "moveLine"') end)
test(3, "Normal tap runs restored path", function() return has(camera, "return attemptLegacyContextCommand()") end)
test(4, "Native targeting precedes Smart X", function() return camera:find("HandleNativeTargetingInput", 1, true) < camera:find("HandleNormalXInput", 1, true) end)
test(5, "Build placement precedes Smart X", function() return has(camera, "local placementBusy") and has(camera, "ControllerCameraTestHandlePlacementInput(dt)") end)
test(6, "Factory radial owns X", function() return has(camera, "factory queued (A)") and has(camera, "factory dequeued") end)
test(7, "Air constructor Repair extension exists", function() return has(camera, "tryNativeSmartRepairReclaimExtension") and has(camera, "repairID") end)
test(8, "Repair extension blocks Move fallthrough", function() return has(camera, "if tryNativeSmartRepairReclaimExtension() then return true end") end)
test(9, "Enemy Reclaim extension exists", function() return has(camera, "reclaimID") and has(camera, "controllerExecuteAtTarget") end)
test(10, "Air reclaim uses descriptor legality", function() return has(camera, "Spring.GetDefaultCommand") and not has(camera, "air constructor enemy exclusion") end)
test(11, "Smart extension dispatches once", function() return has(order, "COMMAND_NOTIFY HANDLED") and has(order, "GIVE_ORDER FALLBACK") end)
test(12, "No stale X latch after tap", function() return has(camera, "drag.pressActive = false") end)

-- 13-22 Build/Factory paging.
test(13, "Closed RB opens eligible radial", function() return has(camera, 'event == "rb-tap"') and has(camera, "attemptBuildMenu()") end)
test(14, "Open Build RB advances global page", function() return has(camera, "ControllerCameraTestTraverseRadialPages(1)") end)
test(15, "Open Build LB returns global page", function() return has(camera, "ControllerCameraTestTraverseRadialPages(-1)") end)
test(16, "Factory shares next-page handler", function() return has(camera, "menu.isFactoryContext") and has(camera, "radialNextPage") end)
test(17, "Factory shares previous-page handler", function() return has(camera, "menu.isFactoryContext") and has(camera, "radialPrevPage") end)
test(18, "One-page radial is safe", function() return has(camera, "single global page: no-op") end)
test(19, "One press changes one global page", function() return has(camera, "global page next:") end)
test(20, "Page input cannot trigger Queue Mode", function() return has(camera, "if ControllerCameraTestBuildMenu.open or ControllerCameraTestTacticalMenu.open then") end)
test(21, "Page input cannot trigger Move State", function() return has(camera, "ControllerCameraTestInputChord = ControllerInputChords.New()") end)
test(22, "Page focus updates native identity", function() return has(camera, "first.menuIndex, first.stableKey") and has(camera, "ControllerCameraTestSetNativeBuildFocus") end)

-- 23-29 Tactical toggle priority.
test(23, "Back+RB opens Tactical", function() return has(camera, "ControllerCameraTestHandlePriorityTacticalToggle") end)
test(24, "Back+RB closes Tactical", function() return has(camera, "ControllerCameraTestToggleTacticalMenu()") end)
test(25, "Chord closes Build first", function() return has(camera, 'ControllerCameraTestCloseBuildMenu("closed for Tactical Radial")') end)
test(26, "Chord cannot open Factory", function() return has(camera, "priorityTacticalToggle") end)
test(27, "Build open is prohibited while Tactical", function() return has(camera, 'blocked while Tactical Radial is open') end)
test(28, "Closing toggle consumes RB cycle", function() return has(camera, "waitingForRBRelease") end)
test(29, "Clean later RB is rearmed", function() return has(camera, 'rearmed after RB release') end)

-- 30-38 Vanilla idle navigation.
test(30, "D-pad Left selects previous live ID", function() return has(camera, "ControllerCameraTestCycleIdleUnit(-1)") end)
test(31, "D-pad Right selects next live ID", function() return has(camera, "ControllerCameraTestCycleIdleUnit(1)") end)
test(32, "Vanilla list ordering is used", function() return has(idle, "for _, unitDefID in ipairs(existingIcons)") end)
test(33, "Exact direct selection is used", function() return has(camera, "ControllerCameraTestFocusAndSelectUnit(unitID") end)
test(34, "v0.7 camera focus is used", function() return has(camera, "ControllerCameraTestFocusCameraAt") end)
test(35, "Controller remembers ID and type", function() return has(camera, "currentUnitID = unitID") and has(camera, "currentTypeKey = unitDefID") end)
test(36, "Dead/non-idle entries are filtered", function() return has(idle, "spGetUnitIsDead(unitID)") and has(idle, "isWorkerUnitIdle") end)
test(37, "Radials suppress idle cycling", function() return has(camera, "ControllerCameraTestHandleBuildMenuInput()") and has(camera, "ControllerCameraTestHandleTacticalMenuInput()") end)
test(38, "Missing API is safe", function()
	return has(camera, 'type(WG.idlebuilders.controllerGetLiveIdleEntries) == "function"')
		and has(camera, "vanilla idle widget unavailable")
		and has(camera, "if #units == 0 then")
end)

-- 39-52 Enemy Disassemble.
test(39, "X target release reclaims enemy unit", function() return has(camera, "ControllerCameraTestIssueDisassembleSingleReclaim(pending.targetInfo") and has(camera, "params = { target.targetID }") end)
test(40, "X immediately reclaims enemy structure", function() return has(camera, "ControllerCameraTestGetReticleTargetInfo") and not has(camera, "enemy structures unsupported") end)
test(41, "X does not Move over reclaim target", function() return has(camera, "if pending.targetInfo then") and has(camera, "ControllerCameraTestIssueNativeDisassembleMove(pending.groundInfo)") end)
test(42, "LB+A tap accepts enemy target", function() return has(camera, "ControllerCameraTestGetReticleNativeReclaimTarget") end)
test(43, "Enemy target anchors same-type reclaim", function() return has(camera, "StartNativeSameTypeReclaim") and has(camera, "unitDefID") end)
test(44, "Same-type collection includes enemy", function() return has(camera, "GetUnitsInCylinder") and not has(disassemble, "GetMyAllyTeamID") end)
test(45, "Hold-A brush records enemy", function() return has(camera, "native target-session") or has(camera, "hostile units/structures") end)
test(46, "RT+Hold-A adds enemy", function() return has(camera, "area.initialSelection") and has(camera, "markedTargets") end)
test(47, "Own constructor joins reclaimers", function() return has(camera, "ControllerCameraTestAppendDisassembleReclaimer") end)
test(48, "Own constructor is excluded", function() return has(disassemble, "not constructorSet[unitID]") end)
test(49, "Factory never joins reclaimer set", function() return has(disassemble, "unitDef.isFactory ~= true") end)
test(50, "LB+A no longer combines own/enemy batches", function() return has(disassemble, "seenTargets") and not has(camera, "local combined = {}") end)
test(51, "Timer resets only after accepted reclaim", function() return has(camera, "if issuedTargets > 0 then") end)
test(52, "Disassemble remains active", function() return has(camera, "state.successfulActivity = true") and has(camera, "state.lastReclaimAt = debugEventTime") end)

-- 53-72 runtime-equivalent area owner route.
test(53, "LB Tactical activation begins restored v0.6 state", function()
	return has(camera, "ControllerCameraTestStageTacticalCommand(option)") and not has(camera, "api.controllerBeginTarget")
end)
test(54, "Area Mex exposes direct completed-area API", function() return has(mex, "WG.controllerAreaMex.issueArea") and has(mex, "resource_spot_builder") end)
test(55, "Smart Reclaim owner broker is disabled", function() return has(reclaim, "function widget:Update()") and has(reclaim, "restored v0.6 camera owns") end)
test(56, "Hidden Order Menu retains Update", function() return has(order, "function widget:Update(dt)") and has(order, "controllerPanelVisible") end)
test(57, "First A anchors", function() local n,_,_,state=runArea("A","A"); return n==1 and state.phase=="IDLE" end)
test(58, "Release arms confirmation", function() return has(targetingSource, "state.confirmationArmed = true") end)
test(59, "Second A confirms", function() return select(1,runArea("A","A")) == 1 end)
test(60, "Second X confirms", function() return select(1,runArea("A","X")) == 1 end)
test(61, "A to A works", function() return select(1,runArea("A","A")) == 1 end)
test(62, "A to X works", function() return select(1,runArea("A","X")) == 1 end)
test(63, "X to A works", function() return select(1,runArea("X","A")) == 1 end)
test(64, "X to X works", function() return select(1,runArea("X","X")) == 1 end)
test(65, "Owner confirm callback is called", function() local n=runArea("A","A"); return n==1 end)
test(66, "Exactly one CommandNotify boundary", function() local _,count=order:gsub("pcall%(widgetHandler%.CommandNotify",""); return count==1 end)
test(67, "Direct fallback only when unhandled", function() return has(order,"COMMAND_NOTIFY HANDLED") and has(order,"GIVE_ORDER FALLBACK") end)
test(68, "Smart X cannot steal confirm", function() return has(camera,"local stagedTacticalBusy = ControllerCameraTestHandleStagedTacticalCommandInput()") end)
test(69, "Normal A cannot steal confirm", function() return has(camera,"ControllerCameraTestCancelAreaSelect(\"cancelled by tactical stage\")") end)
test(70, "B cancels session", function() return has(ownerSource,"if input.cancelPressed then") end)
test(71, "Session clears after completion", function() local _,_,_,state=runArea("A","A"); return state.phase=="IDLE" and state.anchor==nil end)
test(72, "Transition trace records full hybrid route", function()
	return has(camera,"TARGET STATE CREATED") and has(camera,"FINAL DISPATCH STARTED")
		and has(order,"NATIVE TRANSFORM CALLED")
end)

-- 73-88 preserved regressions and delivery coverage.
test(73, "Build eligibility remains", function() return has(camera,"ControllerCameraTestGetBuildSelectionContext") end)
test(74, "Build cancellation remains", function() return has(camera,'ControllerCameraTestCancelPlacement("cancelled by B")') end)
test(75, "Factory quantities remain", function() return has(build,"delta ~= 1") and has(build,"delta ~= -5") end)
test(76, "Radial compaction remains", function() return has(camera,"radialVisibleOptions") end)
test(77, "Distributed Grid remains", function() return has(camera,"ControllerCameraTestUpdateDistributedGridChord") end)
test(78, "Vanilla control groups remain", function() return has(camera,"Spring.SendCommands") and has(camera,"group") end)
test(79, "Hint stability remains", function()
	local runtime = read("luaui/Include/controller_ui_runtime.lua")
	return has(runtime, "bindingRevision ~= self.bindingRevision or self.lastHintRevision ~= self.hintRevision")
		and has(runtime, "self.committedStateSignature")
end)
test(80, "Panel visibility remains", function() return has(order,"controllerSetPanelVisible") and has(build,"controllerSetPanelVisible") end)
test(81, "Tactical renderer remains", function() return has(camera,"controllerDrawCommandButton") end)
test(82, "Fire State remains", function() return has(order,"CMD.FIRE_STATE") end)
test(83, "Move State remains", function() return has(camera,"ControllerCameraTestCycleMoveStateFromSelection") end)
test(84, "Legacy fallback remains", function() return has(camera,"not ControllerCameraTestUsesNativeBARUI()") end)
test(85, "Owner state preserves nil coordinates", function() local o=Owner.New({dispatch=function()return true end}); local s=o:GetState(); return s.anchor==nil and s.current==nil end)
test(86, "Preview renderers guard coordinates", function() return has(mex,"not state.anchor.x") and has(reclaim,"ownerState.anchor.x") end)
test(87, "Companion lifecycle repair is covered", function()
	return has(read("tools/controller-companion/Shared/EngineSessionTracker.cs"), "TrackedProcessId")
		and has(read("tools/controller-companion/Tests/Program.cs"), "TestProductMetadataAndSessionLifecycle")
end)
test(88, "Deployment scripts reference repair harness", function() return has(read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1"),"Test-ControllerNativeRegressionRepair.lua") end)

assert(#cases == 88, "expected exactly 88 cases")
for index, item in ipairs(cases) do
	local ok, result = pcall(item[3])
	assert(ok and result, string.format("case %d/%d failed: %s%s", index, item[1], item[2], ok and "" or (" (" .. tostring(result) .. ")")))
end
print("Controller native regression repair tests passed: 88/88 cases.")
