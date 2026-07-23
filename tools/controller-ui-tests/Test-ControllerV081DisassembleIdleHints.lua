local root = assert(arg and arg[1], "repository root argument required"):gsub("\\", "/")
local function read(relative)
	local file = assert(io.open(root .. "/" .. relative, "rb"), relative)
	local value = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return value
end
local function has(value, needle) return value:find(needle, 1, true) ~= nil end
local function lacks(value, needle) return not has(value, needle) end
local function ordered(value, ...)
	local cursor = 1
	for _, needle in ipairs({ ... }) do
		local found = value:find(needle, cursor, true)
		if not found then return false end
		cursor = found + #needle
	end
	return true
end
local function section(value, first, last)
	local a = assert(value:find(first, 1, true), first)
	local b = assert(value:find(last, a + #first, true), last)
	return value:sub(a, b - 1)
end

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local tapsSource = read("luaui/Include/controller_selection_taps.lua")
local runtime = read("luaui/Include/controller_ui_runtime.lua")
local renderer = read("luaui/Include/controller_ui_shared_renderers.lua")
local deploy = read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1")
local packageScript = read("tools/dev-scripts/Build_v0.8.0_Native_Test_Package.ps1")
local releaseSpec = read("tools/release/controller-release-payloads.json")
local releaseBuilder = read("tools/release/Build-ControllerPublicRelease.ps1")
local releaseSystem = read("tools/release/Test-ControllerReleaseSystem.ps1")
local props = read("tools/controller-companion/Directory.Build.props")
local defaultsManifest = read("controller-ui/shipping-defaults-manifest.json")
local Taps = assert(dofile(root .. "/luaui/Include/controller_selection_taps.lua"))

local cases = {}
local function test(id, label, fn) cases[#cases + 1] = { id = id, label = label, fn = fn } end

local normalA = section(camera, "function ControllerCameraTestHandleNormalAInput", "local function attemptBuildMenu")
local nativeDisassemble = section(camera, "function ControllerCameraTestUpdateNativeDisassembleInput", "function ControllerCameraTestSelectionsContainSameUnits")
local legacyDisassemble = section(camera, "function ControllerCameraTestUpdateDisassembleModeInput", "function ControllerCameraTestUpdateDisassembleLifecycle")
local disassembleX = section(camera, "function ControllerCameraTestHandleDisassembleXInput", "function ControllerCameraTestIssueNativeDisassembleStop")
local disassembleB = section(camera, "function ControllerCameraTestHandleDisassembleB", "function ControllerCameraTestStartNativeSameTypeReclaim")
local commandHints = section(runtime, 'bind("buildRadial", "Tactical Radial", command, 5)', 'bind("groupSlotUp", "Next Group Slot", groups, 1)')

test(1, "nil reticle observation keeps double-tap candidate", function()
	local state = Taps.New(0.35)
	Taps.ResolveRelease(state, 1.0, 11, 22, false)
	return Taps.ObserveTarget(state, nil, nil) == false
		and Taps.ResolveRelease(state, 1.2, 12, 22, false) == "double"
end)
test(2, "concrete incompatible unit still clears candidate", function()
	local state = Taps.New(0.35)
	Taps.ResolveRelease(state, 1.0, 11, 22, false)
	return Taps.ObserveTarget(state, 99, 33) == true
		and state.resetReason == "incompatible cursor target"
end)
test(3, "tap helper explicitly ignores empty target", function() return has(tapsSource, "if not unitID or not unitDefID then return false end") end)
test(4, "A press captures exact owned target", function() return has(normalA, "area.pressTargetID = pressTargetID") and has(normalA, "area.pressUnitDefID = pressUnitDefID") end)
test(5, "A release can use captured target identity", function() return has(normalA, "if not targetID and area.pressTargetID then") and has(normalA, "attemptReticleSelection(targetID)") end)
test(6, "single A still selects one exact unit", function() return has(camera, "local function attemptReticleSelection(forcedUnitID)") and has(camera, "spSelectUnitArray, { unitID }, false") end)

test(7, "native reclaim command target accepts units", function() return has(camera, 'target.targetType, target.targetID = "unit", targetID') end)
test(8, "native reclaim command target accepts features", function() return has(camera, 'target.targetType, target.targetID = "feature", targetID') end)
test(9, "native reclaim command target rejects constructor set", function() return has(camera, "if ControllerCameraTestConstructorSet()[targetID] then return nil end") end)
test(10, "one-shot disassemble uses tactical executor", function() return has(camera, "ControllerCameraTestIssueDisassembleSingleReclaim") and has(camera, "ControllerCameraTestExecuteTacticalCommand(option, false, nil, target)") end)
test(11, "one-shot disassemble no longer calls native order owner directly", function()
	local oneShot = section(camera, "function ControllerCameraTestIssueDisassembleSingleReclaim", "function ControllerCameraTestIssueNativeDisassembleTarget")
	return lacks(oneShot, "controllerIssueCommand")
end)
test(12, "legacy wrapper also routes to one-shot helper", function() return has(camera, "return ControllerCameraTestIssueDisassembleSingleReclaim(\n\t\tControllerCameraTestGetReticleNativeReclaimCommandTarget(), \"Native Disassemble\")") end)
test(13, "native X is pending rather than immediate", function() return has(nativeDisassemble, "ControllerCameraTestHandleDisassembleXInput(dt)") and lacks(nativeDisassemble, 'ControllerCameraTestActionPressed("smartAction") then\n\t\tControllerCameraTestIssueNativeDisassembleTarget()') end)
test(14, "disassemble X short release reclaims only on release", function() return ordered(disassembleX, 'ControllerCameraTestActionReleased("smartAction")', "ControllerCameraTestIssueDisassembleSingleReclaim") end)
test(15, "disassemble X hold keeps Move", function() return has(disassembleX, "ControllerCameraTestStartSingleUnitPath") and has(disassembleX, 'drag.mode = "moveLine"') end)
test(16, "native LB+A release uses one-shot helper", function() return has(nativeDisassemble, 'ControllerCameraTestIssueDisassembleSingleReclaim(\n\t\t\t\tstate.lbA.targetInfo, "Native Disassemble LB+A")') end)
test(17, "native LB+A no longer combines selected targets", function() return lacks(nativeDisassemble, "local combined = {}") and lacks(nativeDisassemble, "ControllerCameraTestIssueDisassembleReclaim(targets)") end)
test(18, "legacy LB+A release uses one-shot helper", function() return has(legacyDisassemble, 'ControllerCameraTestIssueDisassembleSingleReclaim(\n\t\t\t\tstate.lbA.targetInfo, "Disassemble LB+A")') end)

test(19, "B cancel paths reset double-B state first", function() return ordered(disassembleB, "if consumed then", "ControllerDisassembleBehavior.NewDoubleBTap()", "return true") end)
test(20, "B clear only consumes non-reclaimer native selection", function() return has(disassembleB, "not ControllerCameraTestSelectionsEqual(selected") and has(disassembleB, "native selection cleared") end)
test(21, "plain B can still enter double-B flow", function() return ordered(disassembleB, "UpdateDoubleBTap", 'event == "exit"', "double-B exit") end)
test(22, "cancel clears pending X state", function() return has(camera, "state.pendingX = { pressActive = false, startedAt = 0, holdFired = false, targetInfo = nil, groundInfo = nil }") end)
test(23, "cancel clears disassemble X drag", function() return has(camera, 'ControllerCameraTestDragCommand.pressButton == "disassemble-smartAction"') and has(camera, "ControllerCameraTestCancelDrag(reason or \"Disassemble X cancelled\")") end)

test(24, "idle cycle stores current index", function() return has(camera, "ControllerCameraTestIdleCycle.currentIndex = nextIndex") end)
test(25, "idle cycle restores v0.6 own-team enumeration", function() return has(camera, "ControllerCameraTestGetOwnTeamUnits()") and has(camera, "local builders, fallback = {}, {}") end)
test(26, "idle no-units reports no idle units", function() return has(camera, 'latchSelectionDebugMessage("Idle cycle: no idle units")') end)
test(27, "idle type cycle stores current type index", function() return has(camera, "ControllerCameraTestIdleCycle.currentTypeIndex = nextIndex") end)

test(28, "context snapshot builds command capabilities", function() return has(camera, "ControllerCameraTestCommandCapabilitiesFromDescs") and has(camera, "capabilityCache.activeSignature") end)
test(29, "context snapshot exports smart and tactical capability flags", function() return has(camera, "canSmartAction = commandCaps.canSmartAction == true") and has(camera, "canTacticalCommand = commandCaps.canTacticalCommand == true") end)
test(30, "normal smart hint is capability-aware", function() return has(runtime, "normal(c) and not c.hasTransport and c.canSmartAction") end)
test(31, "normal hold move hint is capability-aware", function() return has(runtime, "normal(c) and c.hasSelection and c.canMoveCommand") end)
test(32, "normal command layer hint is capability-aware", function() return has(runtime, "normal(c) and c.hasSelection and c.canTacticalCommand") end)
test(33, "Back-hold command hints no longer advertise direct commands", function()
	return lacks(commandHints, "Guard / Patrol") and lacks(commandHints, "Reclaim")
		and lacks(commandHints, "Attack / Attack-Move") and lacks(commandHints, "Stop Selected")
end)
test(34, "Toggle Mouse Mode hint remains globally available", function() return has(runtime, 'shortcut = "mouseMode"') and has(runtime, "Toggle Mouse Mode") end)
test(35, "hint signatures include capability keys", function() return has(runtime, '"canSmartAction", "canTacticalCommand", "canMoveCommand"') and has(runtime, '"canReclaimCommand", "canRepairCommand", "canAttackCommand"') end)

test(36, "self destruct finder can include disabled descriptors", function() return has(camera, "function ControllerCameraTestFindSelfDestructCommandID(includeDisabled)") and has(camera, "includeDisabled == true") end)
test(37, "self destruct command is ensured for native model", function() return ordered(camera, "local nativeCommands = {}", "ControllerCameraTestEnsureSelfDestructCommand(nativeCommands)", "BuildTacticalModel(nativeCommands") end)
test(38, "self destruct command is ensured for legacy model", function() return has(camera, "ControllerCameraTestEnsureSelfDestructCommand(commands)") end)
test(39, "self destruct enters protected flow before disabled gate", function() return ordered(camera, 'if option.kind == "self_destruct" then', "ControllerCameraTestArmProtectedSelfDestruct()", "if option.disabled then") end)
test(40, "self destruct added item is disabled-aware", function() return has(camera, "disabled = not enabled") and has(camera, "Protected Self Destruct unavailable") end)

test(41, "mixed radial sector labels use label color", function() return has(renderer, "sector.labelColor or sector.accent or accent") end)
test(42, "mixed radial sector labels have dark shadow", function() return has(renderer, "0, 0, 0, 0.72 * opacity") and has(renderer, "labelX + 1.2 * values.fontScale") end)
test(43, "camera passes label colors into renderer", function() return has(camera, "labelColor = colors.label or colors.accent") end)
test(44, "combat and utility category accents are brighter", function() return has(camera, "accent = { 1.0, 0.42, 0.24, 1.0 }") and has(camera, "accent = { 0.76, 0.64, 1.0, 1.0 }") end)

test(45, "affordability center text uses one-second smoothing", function() return has(camera, "local AFFORDABILITY_DISPLAY_SAMPLE_SECONDS = 1.0") and has(camera, "entry.nextSampleAt = now + AFFORDABILITY_DISPLAY_SAMPLE_SECONDS") end)
test(46, "affordability smoothing alpha is explicit", function() return has(camera, "local AFFORDABILITY_DISPLAY_ALPHA = 0.35") end)
test(47, "affordability display rounds to nearest ten", function() return has(camera, "ControllerCameraTestRoundBuildDeficitToNearest10") and has(camera, "math.floor((value / 10) + 0.5) * 10") end)
test(48, "affordability clears immediately when affordable", function() return has(camera, "menu.affordabilityDisplay[key] = nil") end)
test(49, "draw overlays use raw affordability", function() return has(camera, "local affordable = ControllerCameraTestCanAffordBuildOption(option)") and has(camera, "local affordable = ControllerCameraTestCanAffordBuildOption(currentOption)") end)
test(50, "center text uses smoothed availability only", function() return has(camera, "return ControllerCameraTestGetSmoothedBuildAvailability(option)") end)

test(51, "central companion version is 0.8.3 Experimental", function() return has(props, ">0.8.3<") and has(props, ">Experimental<") end)
test(52, "release spec names v0.8.3 repair package", function() return has(releaseSpec, "controller-support-v0.8.3-smartx-insert-tactical-repair") and has(releaseSpec, "BAR_Controller_Support_v0.8.3_SMARTX_INSERT_TACTICAL_REPAIR.zip") end)
test(53, "public builder defaults to v0.8.3 output", function() return has(releaseBuilder, "artifacts\\v0.8.3-public-release") and has(releaseBuilder, "Install_v0.8.3.ps1") end)
test(54, "release system expects v0.8.3 latest", function() return has(releaseSystem, "controller-support-v0.8.3-smartx-insert-tactical-repair") and has(releaseSystem, "bridge version remains v0.8.3 Experimental") end)
test(55, "shipping defaults manifest tracks v0.8.3", function() return has(defaultsManifest, "0.8.3-smartx-insert-tactical-repair") and has(defaultsManifest, '"minimumCompanionVersion": "0.8.3"') end)
test(56, "dev deployment runs the v0.8.1 harness", function() return has(deploy, "Test-ControllerV081DisassembleIdleHints.lua") end)
test(57, "dev package includes the v0.8.1 harness", function() return has(packageScript, "Test-ControllerV081DisassembleIdleHints.lua") end)

test(58, "tactical executor honors captured target override", function() return has(camera, "local target = type(targetOverride) == \"table\" and targetOverride or ControllerCameraTestGetReticleTargetInfo()") end)
test(59, "disassemble X open ground uses Move branch", function() return has(disassembleX, "pending.groundInfo = ControllerCameraTestGetReticleTargetInfo()") and has(disassembleX, "ControllerCameraTestIssueNativeDisassembleMove(pending.groundInfo)") end)
test(60, "LB+A stores captured one-shot target", function() return has(nativeDisassemble, "targetInfo = targetInfo") and has(legacyDisassemble, "targetInfo = targetInfo") end)

assert(#cases == 60, "expected exactly 60 focused cases")
for index, item in ipairs(cases) do
	assert(index == item.id, string.format("case numbering drift at %d/%d", index, item.id))
	local ok, result = pcall(item.fn)
	assert(ok and result, string.format("case %d failed: %s%s", item.id, item.label, ok and "" or (" (" .. tostring(result) .. ")")))
end
print("Controller v0.8.1 disassemble/idle/hints tests passed: 60/60 cases.")
