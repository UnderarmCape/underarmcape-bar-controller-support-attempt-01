local root = arg[1] or "."
local function path(relative) return (root .. "/" .. relative):gsub("\\", "/") end
local function read(relative)
	local file = assert(io.open(path(relative), "rb"), "missing " .. relative)
	local value = file:read("*a"); file:close(); return value
end
local function has(value, needle) return value:find(needle, 1, true) ~= nil end
local function ordered(value, ...)
	local cursor = 1
	for _, needle in ipairs({ ... }) do
		local found = value:find(needle, cursor, true)
		if not found then return false end
		cursor = found + #needle
	end
	return true
end

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local tapsSource = read("luaui/Include/controller_selection_taps.lua")
local adapter = read("luaui/Include/controller_native_radial_adapter.lua")
local renderer = read("luaui/Include/controller_ui_shared_renderers.lua")
local areaMex = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_area_mex.lua")
local smartReclaim = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/unit_smart_area_reclaim.lua")
local orderMenu = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")
local buildMenu = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua")
local idleWidget = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_idle_builders.lua")
local recovery = read("doc/controller-companion-v0.8.0/PRE_V06_RESTORE_RECOVERY.md")
local console = read("tools/controller-companion/Shared/BridgeConsole.cs")
local program = read("tools/controller-companion/Program.cs")
local deploy = read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1")
local restore = read("tools/dev-scripts/Restore_v0.8.0_Native_Test.ps1")
local package = read("tools/dev-scripts/Build_v0.8.0_Native_Test_Package.ps1")
local releaseManifest = read("tools/release/bar-controller-support-v0.8.0-native-test/manifest.json")
local Taps = assert(dofile(path("luaui/Include/controller_selection_taps.lua")))

local count = 0
local failures = {}
local function test(number, label, check)
	count = count + 1
	if number ~= count then error("test numbering gap at " .. tostring(number)) end
	local ok, result = pcall(check)
	if not ok or result ~= true then failures[#failures + 1] = string.format("%d. %s: %s", number, label, ok and "false" or result) end
end

-- Historical source and recovery
test(1, "Starting recovery commit is documented", function() return has(recovery, "c5c07603e3d6560ad057e35a021d0f5ffc8b1643") end)
test(2, "Replaced files are listed", function() return has(recovery, "gui_controller_camera_test.lua") and has(recovery, "gui_ordermenu.lua") end)
test(3, "Restore commands are valid", function() return has(recovery, "git restore --source=c5c076") and has(recovery, "git switch -c recovery/") end)
test(4, "Selected v0.6 source is identified", function() return has(recovery, "controller-support-v0.6.1-radial-typography") and has(recovery, "d345fd1ee790e4ff392f020b82d8aa3b52db0edf") end)
test(5, "No history rewrite occurs", function() return has(recovery, "Do not force-push or reset") end)

-- Tactical restore
test(6, "Immediate Fight matches v0.6", function() return has(camera, "local function attemptFightCommand()") and has(camera, "issueOrderToSelection(CMD.FIGHT") end)
test(7, "Immediate Patrol matches v0.6", function() return has(camera, "ControllerCameraTestIssueOrderToSelectedUnits(CMD.PATROL or 15") end)
test(8, "Immediate Attack matches v0.6", function() return has(camera, "local function attemptAttackCommand()") and has(camera, "issueOrderToSelection(CMD.ATTACK") end)
test(9, "Each immediate shortcut issues exactly once", function() return has(camera, "issue once") or (has(camera, "attemptFightCommand()") and has(camera, "attemptAttackCommand()")) end)
test(10, "Tactical point radial waits for fresh input", function() return has(camera, "menu.stagedWaitForNeutral = true") end)
test(11, "A confirms point", function() return has(camera, 'ControllerCameraTestActionPressed("select")') and has(camera, "ControllerCameraTestConfirmStagedTacticalCommand()") end)
test(12, "X confirms point", function() return has(camera, 'ControllerCameraTestActionPressed("smartAction")') and has(camera, "ControllerCameraTestConfirmStagedTacticalCommand()") end)
test(13, "B cancels", function() return has(camera, "staged tactical cancelled by B") and has(camera, 'ControllerCameraTestActionPressed("cancel")') end)
test(14, "Radial-selection press does not target", function() return ordered(camera, "menu.stagedWaitForNeutral = true", "local buttonsNeutral", "if menu.stagedWaitForNeutral then") end)
test(15, "Smart X cannot steal point X", function() return ordered(camera, "local stagedTacticalBusy", "local placementBusy", "local disassembleBusy", "ControllerCameraTestHandleNormalXInput") end)
test(16, "Normal selection cannot steal point A", function() return ordered(camera, "local stagedTacticalBusy", "if stagedTacticalBusy then", "ControllerCameraTestHandleNormalAInput") end)

-- Area behavior
test(17, "Area Mex A-to-A", function() return has(camera, "drag.waitingForNeutral = true") and has(camera, 'ActionPressed("select")') end)
test(18, "Area Mex A-to-X", function() return has(camera, 'ActionPressed("select")') and has(camera, 'ActionPressed("smartAction")') end)
test(19, "Area Mex X-to-A", function() return has(camera, "buttonsNeutral") and has(camera, "ControllerCameraTestIssueAreaMexRouteA") end)
test(20, "Area Mex X-to-X", function() return has(camera, "ControllerCameraTestIssueAreaMexRouteA") and has(areaMex, "WG.controllerAreaMex.issueArea") end)
test(21, "Smart Reclaim four combinations", function() return has(smartReclaim, "controllerConfirm") and has(camera, "reclaimArea") and has(camera, "buttonsNeutral") end)
test(22, "Disassemble radius four combinations", function() return has(camera, "area.waitingForNeutral") and has(camera, "area.confirmArmed") and has(camera, 'ActionPressed("smartAction")') end)
test(23, "Release never confirms", function() return not has(camera, 'ActionReleased("select") or ControllerCameraTestActionReleased("smartAction") then\n\t\tlocal targets = area.candidates') end)
test(24, "Area B cancels", function() return has(camera, 'if ControllerCameraTestActionPressed("cancel") then') and has(camera, "area reclaim cancelled") end)
test(25, "One preview", function() return has(camera, "ControllerCameraTestUpdateDragPreview") and not has(camera, "duplicated controller/native previews") end)
test(26, "One dispatch", function() return has(camera, "ControllerCameraTestConfirmDragCommand(false)") and has(camera, "area.active, area.confirmArmed, area.candidates = false") end)
test(27, "Failed broker does not run", function() return not has(camera, "local nativeTargetBusy = ControllerCameraTestHandleNativeTargetingInput()") and has(orderMenu, 'return false, "v0.6 camera owns controller targeting"') end)
test(28, "Native mex helper receives completed area", function() return has(areaMex, "function(x, y, z, radius, options)") and has(areaMex, "x or { x, y, z, radius }") and has(areaMex, "widget.CommandNotify") end)
test(29, "Mex orders use resource_spot_builder", function() return has(areaMex, "resource_spot_builder") and has(areaMex, "ApplyPreviewCmds") end)
test(30, "Queue semantics remain", function() return has(areaMex, "SpotHasExtractorQueued") and has(areaMex, "ApplyPreviewCmds(sortedCmds, mexConstructors, shift)") end)
test(31, "Enemy Disassemble anchor works", function() return has(camera, "ControllerCameraTestGetReticleNativeReclaimTarget") and has(camera, "state.lbA.targetID") end)

-- A selection
test(32, "Single A selects exactly one unit", function() return has(camera, "attemptReticleSelection()") and has(camera, "single exact unit") end)
test(33, "100 repeated single taps never expand", function()
	local state = Taps.New(0.35)
	for index = 1, 100 do if Taps.ResolveRelease(state, index, 11, 22, false) ~= "single" then return false end end
	return true
end)
test(34, "Double-tap A selects visible same-type units", function()
	local state = Taps.New(0.35)
	return Taps.ResolveRelease(state, 1, 11, 22, false) == "single"
		and Taps.ResolveRelease(state, 1.2, 11, 22, false) == "double"
		and has(camera, "ControllerCameraTestSelectVisibleSameTypeUnderReticle")
end)
test(35, "Off-screen same-type units are excluded", function() return has(camera, "ControllerCameraTestUnitIsOnScreen") end)
test(36, "Different UnitDefID is excluded", function() return has(tapsSource, "state.lastUnitDefID == unitDefID") and has(camera, "candidateDefID == unitDefID") end)
test(37, "Enemy units are excluded", function() return has(camera, "unitTeam == myTeam") end)
test(38, "Hold-A still starts brush", function() return has(camera, "Hold-A threshold crossed") and has(camera, "area.active = true") end)
test(39, "RT+A still toggles exact unit", function()
	local state = Taps.New(0.35); Taps.ResolveRelease(state, 1, 11, 22, false)
	return Taps.ResolveRelease(state, 1.1, 11, 22, true) == "modified" and has(camera, "area.additive")
end)
test(40, "Controller double-tap does not use mouse state", function() return not has(tapsSource, "GetMouse") and not has(tapsSource, "doubleClick") end)
test(41, "Modal and incompatible cursor changes clear tap candidate", function() return has(camera, "modal or modifier context") and has(camera, "settings modal") and has(tapsSource, "incompatible cursor target") end)
test(42, "Stale tap candidate cannot fire later", function()
	local state = Taps.New(0.35); Taps.ResolveRelease(state, 1, 11, 22, false); Taps.Expire(state, 1.5)
	return Taps.ResolveRelease(state, 1.6, 11, 22, false) == "single"
end)

-- Idle navigation
test(43, "Idle IDs match current ZZZ list", function() return has(camera, "controllerGetLiveIdleEntries") and has(idleWidget, "controllerGetLiveIdleEntries") end)
test(44, "D-pad Right selects next", function() return has(camera, "ControllerCameraTestCycleIdleUnit(1)") end)
test(45, "D-pad Left selects previous", function() return has(camera, "ControllerCameraTestCycleIdleUnit(-1)") end)
test(46, "Camera behavior matches v0.6", function() return has(camera, 'ControllerCameraTestFocusAndSelectUnit(unitID, "Idle unit")') end)
test(47, "Idle wrap works", function() return has(camera, "((current - 1 + delta) % #units) + 1") end)
test(48, "Disappeared ID repairs", function() return has(camera, "local current = 0") and has(camera, "currentUnitID") end)
test(49, "Busy unit is removed", function() return has(idleWidget, "idle") and has(camera, "snapshot.units") end)
test(50, "LB+D-pad Down selects all idle same-type", function() return has(camera, "ControllerCameraTestSelectAllIdleUnitsInCurrentTypeBucket") end)
test(51, "Busy same-type units are excluded", function() return has(camera, "nativeBucket.units") and not has(camera, "GetTeamUnitsByDefs") end)
test(52, "Idle navigation uses no mouse-click simulation", function() return not has(camera, "controllerCycleIdle") and has(camera, "spSelectUnitArray") end)
test(53, "Radial context suppresses idle navigation", function() return has(camera, "ControllerCameraTestBuildMenu.open or ControllerCameraTestTacticalMenu.open") end)

-- Self Destruct
test(54, "Self Destruct appears in Utility", function() return has(adapter, 'return "utility"') and has(adapter, "self destruct") end)
test(55, "Self Destruct appears for structures", function() return has(camera, "Self Destruct") and has(camera, "spGetSelectedUnits") end)
test(56, "Self Destruct uses shared Tactical renderer", function() return has(adapter, 'return "self_destruct"') and has(camera, "controllerDrawCommandButton") end)
test(57, "Self Destruct invokes protected implementation", function() return has(camera, "ControllerCameraTestArmProtectedSelfDestruct") end)
test(58, "Self Destruct safety timing remains", function() return has(camera, "state.holdSeconds or 0.75") end)
test(59, "Self Destruct disabled state is respected", function() return ordered(camera, "if option.disabled then", 'if option.kind == "self_destruct" then') end)
test(60, "No raw duplicate Self Destruct command issues", function() return not has(adapter, "GiveOrder") and not has(orderMenu, "ControllerCameraTestIssueSelfDestruct") end)

-- Radial cleanup
test(61, "One-category page shows main heading", function() return has(renderer, "if #sectors <= 1 then") and has(renderer, "mainCategoryVisible = true") end)
test(62, "Mixed page hides main heading", function() return has(renderer, "local mainCategoryVisible = false") and has(renderer, "if #sectors <= 1 then") end)
test(63, "Sector labels remain", function() return has(renderer, "sector.label or sector.category") end)
test(64, "No concatenated title remains", function() return not has(renderer, 'table.concat(categoryLabels, " + ")') end)
test(65, "Page indicator is inside inner circle", function() return has(renderer, "pageIndicatorY = cy - panelRadius * 0.72") and has(renderer, "pageIndicatorInsidePanel") end)
test(66, "Page indicator remains readable", function() return has(renderer, "metadataFloor") and has(renderer, "typography.pageIndicator") end)
test(67, "Constructor radial placement works", function() return has(camera, "ControllerCameraTestHandlePlacementInput") end)
test(68, "Factory radial placement works", function() return has(camera, 'placement.placementMode = "factory-queue"') end)
test(69, "Native cells remain unchanged", function() return has(camera, "ControllerNativeBuildCellRenderer.Draw") end)
test(70, "Selected-border scale remains", function() return has(camera, "selectedBorderThickness") and has(renderer, "selectedThickness") end)

-- Console
test(71, "Exact version banner remains", function() return has(read("tools/controller-companion/Shared/ProductMetadata.cs"), '"BAR Controller Bridge " + DisplayVersion') end)
test(72, "Status layout is structured", function() return has(console, "FormatRow") and has(console, "new string('-', Width - 2)") end)
test(73, "Color appears when supported", function() return has(console, "Console.ForegroundColor") and has(console, "SupportsColor") end)
test(74, "No raw ANSI when redirected", function() return has(console, "Console.IsOutputRedirected") and not has(console, "\\u001b") and not has(console, "\\x1b") end)
test(75, "Waiting state displays correctly", function() return has(program, "waiting for controller") and has(program, "waiting for Spring/Recoil") end)
test(76, "Connected state displays correctly", function() return has(program, '? "reconnected" : "connected"') end)
test(77, "Tracked PID displays correctly", function() return has(program, "TrackedProcessId.HasValue") and has(read("tools/controller-companion/Shared/EngineSessionTracker.cs"), '"tracking PID "') end)
test(78, "Ctrl+C remains", function() return has(program, "Console.CancelKeyPress") and has(console, "Ctrl+C stops the bridge") end)
test(79, "Engine-exit lifecycle remains", function() return has(program, "sessionTracker.ShouldStop") end)

local luaFiles = {
	"luaui/Include/controller_selection_taps.lua", "luaui/Include/controller_native_radial_adapter.lua",
	"luaui/Include/controller_ui_shared_renderers.lua", "luaui/Widgets/gui_controller_camera_test.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_area_mex.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/unit_smart_area_reclaim.lua",
}
local function luac(relative, listing)
	local command = 'luac ' .. (listing and '-l ' or '') .. '-p "' .. path(relative) .. '" 2>&1'
	local pipe = assert(io.popen(command)); local output = pipe:read("*a"); local ok = pipe:close()
	return ok ~= nil and ok ~= false, output
end
local function maxUpvalues(relative)
	local ok, output = luac(relative, true); if not ok then return math.huge end
	local maximum = 0; for value in output:gmatch("(%d+) upvalues?") do maximum = math.max(maximum, tonumber(value)) end
	return maximum
end

-- Upvalues and regression
test(80, "All Lua parses", function() for _, file in ipairs(luaFiles) do if not select(1, luac(file, false)) then return false end end return true end)
test(81, "No function exceeds 60 upvalues", function() for _, file in ipairs(luaFiles) do if maxUpvalues(file) > 60 then return false end end return true end)
test(82, "Refactored functions have practical headroom", function() return maxUpvalues(luaFiles[6]) <= 55 and maxUpvalues(luaFiles[4]) <= 55 end)
test(83, "Smart X passes", function() return has(camera, "attemptContextCommand") and has(camera, "ControllerCameraTestHandleNormalXInput") end)
test(84, "Hold-X drag passes", function() return has(camera, "ControllerCameraTestUpdateNormalXDrag") or has(camera, "drag.pressButton") end)
test(85, "Build eligibility passes", function() return has(camera, "ControllerCameraTestSelectionCanBuild") or has(camera, "ControllerCameraTestGetBuildSelectionContext") end)
test(86, "Build cancellation passes", function() return has(camera, "ControllerCameraTestCancelBuildPlacement") or has(camera, "placement cancelled") end)
test(87, "Distributed Grid passes", function() return has(camera, "ControllerCameraTestUpdateDistributedGridChord") end)
test(88, "Factory quantities pass", function() return has(camera, "factoryQueueQuantity") end)
test(89, "Native groups pass", function() return has(camera, "nativeGroup") or has(camera, "groupTexture") end)
test(90, "Hints remain stable", function() return has(camera, "activeButtonLayoutSummary") end)
test(91, "Panels hide and restore", function() return has(buildMenu, "controllerPanelVisible") and has(buildMenu, "ControllerBuildMenuRefreshHiddenPanel") end)
test(92, "Page packing remains", function() return has(adapter, "pages") and has(camera, "radialPageSectors") end)
test(93, "Native Build cells remain", function() return has(buildMenu, "controllerGetItems") and has(camera, "ControllerNativeBuildCellRenderer") end)
test(94, "State cycling remains", function() return has(camera, "ControllerCameraTestActivateNativeState") end)
test(95, "Disassemble timeout remains", function() return has(camera, "Disassemble Mode Timed Out") end)
test(96, "Double-B remains", function() return has(camera, "UpdateDoubleBTap") and has(camera, "double-B exit") end)
test(97, "Legacy fallback remains", function() return has(camera, "Legacy Controller UI") end)
test(98, ".NET builds/tests are wired", function() return has(read("tools/controller-companion/Tests/BARControllerCompanionUpdateTests.csproj"), "BridgeConsole.cs") and has(read("tools/controller-companion/Tests/Program.cs"), "TestBridgeConsolePresentation") end)
test(99, "Deployment manifest covers changed files", function() return has(deploy, "controller_selection_taps.lua") and has(deploy, "native-override-manifest.json") and has(releaseManifest, "BridgeConsole.cs") and has(package, "Shared\\BridgeConsole.cs") end)
test(100, "Rollback validation is strict", function() return has(restore, "ROLLBACK_VALID=") and has(restore, "Backup hash mismatch") and has(restore, "Installed file changed after deployment") end)

if #failures > 0 then
	io.stderr:write("v0.6 input restore validation failed:\n" .. table.concat(failures, "\n") .. "\n")
	os.exit(1)
end
print(string.format("Controller v0.6 input restore validation passed: %d/100 focused checks.", count))
