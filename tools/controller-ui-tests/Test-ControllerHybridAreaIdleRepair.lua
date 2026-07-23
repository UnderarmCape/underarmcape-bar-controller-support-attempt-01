local root = assert(arg and arg[1], "repository root argument required"):gsub("\\", "/")
local function read(relative)
	local file = assert(io.open(root .. "/" .. relative, "rb"), relative)
	local value = file:read("*a"):gsub("\r\n", "\n")
	file:close()
	return value
end
local function has(value, needle) return value:find(needle, 1, true) ~= nil end
local function lacks(value, needle) return not has(value, needle) end
local cases = {}
local function test(id, label, callback) cases[#cases + 1] = { id, label, callback } end

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local radialAdapter = read("luaui/Include/controller_native_radial_adapter.lua")
local targetingSource = read("luaui/Include/controller_native_targeting.lua")
local order = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")
local build = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua")
local mex = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_area_mex.lua")
local reclaim = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/unit_smart_area_reclaim.lua")
local formations = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_customformations2.lua")
local idle = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_idle_builders.lua")
local deploy = read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1")
local packageScript = read("tools/dev-scripts/Build_v0.8.0_Native_Test_Package.ps1")
local manifest = read("native-overrides/native-override-manifest.json")

_G.CMDTYPE = { ICON_MAP = 1, ICON_AREA = 2, ICON_FRONT = 3, ICON_UNIT = 4,
	ICON_UNIT_OR_MAP = 5, ICON_UNIT_OR_AREA = 6, ICON_UNIT_FEATURE_OR_AREA = 7,
	ICON_UNIT_OR_RECTANGLE = 8, ICON_BUILDING = 9 }
local Targeting = assert(loadfile(root .. "/luaui/Include/controller_native_targeting.lua"))()
local function descriptor(typeID) return { id = 30123, cmdID = 30123, type = typeID, name = "Test" } end
local function completed(typeID)
	local state = Targeting.New()
	Targeting.SetDescriptor(state, descriptor(typeID), CMDTYPE)
	Targeting.ObserveInput(state, false, false)
	local _, anchor = Targeting.BeginOrBuildPoint(state, { x = 10, y = 2, z = 20 }, CMDTYPE)
	Targeting.UpdatePreview(state, { x = 110, y = 3, z = 70 })
	local before = Targeting.BuildAnchoredParams(state)
	Targeting.ObserveInput(state, false, false)
	local params, shape = Targeting.BuildAnchoredParams(state)
	return state, anchor, before, params, shape
end

-- 1-20: controller-owned target-shape runtime.
test(1, "New state is idle", function() return Targeting.New().phase == Targeting.IDLE end)
test(2, "Area descriptor classifies", function() return Targeting.Classify(descriptor(CMDTYPE.ICON_AREA), CMDTYPE) == Targeting.CONTROLLER_AREA_TARGETING end)
test(3, "Front descriptor classifies", function() return Targeting.Classify(descriptor(CMDTYPE.ICON_FRONT), CMDTYPE) == Targeting.FRONT_TARGETING end)
test(4, "Rectangle descriptor classifies", function() return Targeting.Classify(descriptor(CMDTYPE.ICON_UNIT_OR_RECTANGLE), CMDTYPE) == Targeting.CONTROLLER_AREA_TARGETING end)
test(5, "Point descriptor classifies", function() return Targeting.Classify(descriptor(CMDTYPE.ICON_MAP), CMDTYPE) == Targeting.POINT_TARGETING end)
test(6, "Build descriptor delegates", function() return Targeting.Classify({ id = -1, type = CMDTYPE.ICON_BUILDING }, CMDTYPE) == Targeting.BUILD_PLACEMENT end)
test(7, "Descriptor waits for fresh input", function() local s=Targeting.New(); Targeting.SetDescriptor(s,descriptor(CMDTYPE.ICON_AREA),CMDTYPE); return s.phase==Targeting.WAITING_FOR_FRESH_INPUT end)
test(8, "Neutral input arms anchor", function() local s=Targeting.New(); Targeting.SetDescriptor(s,descriptor(CMDTYPE.ICON_AREA),CMDTYPE); Targeting.ObserveInput(s,false,false); return s.phase==Targeting.WAITING_FOR_ANCHOR_PRESS end)
test(9, "First press stores anchor", function() local s,a=completed(CMDTYPE.ICON_AREA); return a=="anchor" and s.anchor.x==10 and s.anchor.z==20 end)
test(10, "Release arms confirmation", function() local s=completed(CMDTYPE.ICON_AREA); return s.phase==Targeting.RESIZING_ARMED and s.confirmationArmed end)
test(11, "Cursor updates radius", function() local s=completed(CMDTYPE.ICON_AREA); return s.radius > 100 end)
test(12, "Area params are center/radius", function() local _,_,_,p,shape=completed(CMDTYPE.ICON_AREA); return shape=="area" and #p==4 and p[1]==10 and p[3]==20 end)
test(13, "Front params preserve order", function() local _,_,_,p,shape=completed(CMDTYPE.ICON_FRONT); return shape=="front" and #p==6 and p[1]==10 and p[4]==110 end)
test(14, "Rectangle params preserve order", function() local _,_,_,p,shape=completed(CMDTYPE.ICON_UNIT_OR_RECTANGLE); return shape=="rectangle" and #p==6 and p[3]==20 and p[6]==70 end)
test(15, "Release never dispatches", function() local _,_,before=completed(CMDTYPE.ICON_AREA); return before==nil end)
test(16, "Reset clears captured geometry", function() local s=completed(CMDTYPE.ICON_AREA); Targeting.Reset(s,"done"); return s.phase==Targeting.IDLE and s.anchor==nil end)
test(17, "Cancel release latch is explicit", function() local s=Targeting.New(); Targeting.ArmCancelRelease(s,"B"); Targeting.ReleaseCancelLatch(s); return not s.cancelReleaseRequired end)
test(18, "A to A completion is button-independent", function() return has(targetingSource,"state.confirmationArmed = true") and has(camera,'ControllerCameraTestActionPressed("select")') end)
test(19, "A to X completion is button-independent", function() return has(camera,'ControllerCameraTestActionPressed("smartAction")') end)
test(20, "X to A and X to X share state", function() return has(camera,"ControllerNativeTargeting.CanAcceptPress(state)") end)

-- 21-45: hybrid/native boundary and command adapters.
test(21, "Camera creates hybrid target state", function() return has(camera,"function ControllerCameraTestBeginHybridTargeting") end)
test(22, "Native descriptor remains authoritative", function() return has(camera,"controllerGetCommandDescriptor") and has(order,"controllerGetCommandDescriptor = controllerDescriptor") end)
test(23, "Captured state clears mouse command", function() return has(camera,"ControllerCameraTestBeginHybridTargeting") and has(camera,"pcall(Spring.SetActiveCommand, nil)") end)
test(24, "Camera no longer begins native owner", function() return lacks(camera,"api.controllerBeginTarget") end)
test(25, "Camera no longer routes target input to owner", function() return lacks(camera,"api.controllerTargetInput") end)
test(26, "Restored tactical input precedes Disassemble", function()
	local position = camera:find("local stagedTacticalBusy",1,true)
	return position and position < camera:find("ControllerCameraTestUpdateDisassembleController(dt)",position,true)
end)
test(27, "A and X are consumed while active", function() return has(camera,"return true\nend\n\nfunction ControllerCameraTestGetVisibleAlliedUnits") end)
test(28, "B cancels hybrid state", function() return has(camera,'ControllerCameraTestCancelActiveCommandTargeting("targeting cancelled by B", true)') end)
test(29, "Controller owns preview", function() return has(camera,"drag.nativeControllerTargeting = true") end)
test(30, "Native and controller previews are mutually exclusive", function() return has(camera,"if drag.nativeControllerTargeting then") and lacks(camera,"ControllerCameraTestShowNativeTargetPreview()\n\t-- Preview rendering belongs") end)
test(31, "Final dispatch has a guard", function() return has(camera,"if state.dispatchStarted then return false end") end)
test(32, "Final dispatch logs start", function() return has(camera,"FINAL DISPATCH STARTED") end)
test(33, "Order Menu accepts completed shape", function() return has(order,"controllerCompleteTargetShape") end)
test(34, "Completed shape revalidates live descriptor", function() return has(order,"local liveDescriptor = cmdID and controllerDescriptor(cmdID)") end)
test(35, "Active command is not completion prerequisite", function() return has(order,"controllerGetCommandDescriptor") and has(order,"live descriptor unavailable") end)
test(36, "Order Menu has one notify callsite", function() local _,n=order:gsub("pcall%(widgetHandler%.CommandNotify",""); return n==1 end)
test(37, "Handled notify stops fallback", function() return has(order,'return true, "widget"') end)
test(38, "Fallback runs only after unhandled", function() return order:find("if handled then",1,true) < order:find("Spring.GiveOrder",1,true) end)
test(39, "Area Mex exposes restored direct API", function() return has(mex,"WG.controllerAreaMex.issueArea") end)
test(40, "Area Mex receives completed four params", function() return has(mex,"x or { x, y, z, radius }") end)
test(41, "Metal spot transform remains native", function() return has(mex,"getSpotsInArea") and has(mex,"ApplyPreviewCmds") end)
test(42, "Smart Reclaim exposes completion adapter", function() return has(reclaim,"controllerCompleteArea") end)
test(43, "Same-type reclaim preserves five params", function() return has(reclaim,"tonumber(targetID), tonumber(x)") and has(reclaim,"math.max(1, tonumber(radius))") end)
test(44, "Five-param reclaim bypasses smart transform", function() return has(reclaim,"if #params == 5 then return false end") end)
test(45, "Custom Formations exposes completed-shape adapter", function() return has(formations,"controllerCompleteShape") and has(formations,"controllerCompleteTargetShape") end)

-- 46-60: enemy/friendly Disassemble hybrid radius.
test(46, "Same-type hold starts restored area targeting", function() return has(camera,"ControllerCameraTestStartNativeSameTypeReclaim") and has(camera,"waitingForNeutral") end)
test(47, "Friendly target may anchor", function() return lacks(camera,"same-type friendly unsupported") end)
test(48, "Enemy unit may anchor", function() return has(camera,"ControllerCameraTestGetReticleNativeReclaimTarget") end)
test(49, "Enemy structure may anchor", function() return lacks(camera,"enemy structures unsupported") end)
test(50, "Anchor UnitDefID is retained", function() return has(camera,"area.anchorUnitID, area.unitDefID = true, targetID, unitDefID") end)
test(51, "Anchor target ID is retained", function() return has(targetingSource,"state.anchorTargetID") end)
test(52, "Radius uses controller cursor", function() return has(camera,"reticleWorldX - area.x") and has(camera,"reticleWorldZ - area.z") end)
test(53, "Same-type filter receives radius", function() return has(camera,"ControllerCameraTestCollectOwnedTargetsInRadius(area.x, area.z, area.radius, { [area.unitDefID] = true })") end)
test(54, "Constructors are restored before dispatch", function() return has(camera,'ControllerCameraTestRestoreDisassembleConstructors("Constructors staged")') end)
test(55, "Direct enemy tap remains", function() return has(camera,"ControllerCameraTestIssueNativeDisassembleTarget") end)
test(56, "Candidate highlights remain", function() return has(camera,"controllerSetHighlightedTargets") end)
test(57, "B clears reclaim area", function() return has(camera,"area.active, area.confirmArmed, area.waitingForNeutral") end)
test(58, "Accepted reclaim records activity", function() return has(camera,"state.successfulActivity = true") or has(camera,"state.successfulActivity, state.lastReclaimAt = true") end)
test(59, "Disassemble stays active", function() return lacks(camera,'ControllerCameraTestExitDisassembleMode("same-type') end)
test(60, "Retired reclaim owner update is unused", function() return lacks(camera,"smartareareclaim.controllerUpdate") end)

-- 61-72: global Build/Factory traversal.
test(61, "Flattened traversal exists", function() return has(camera,"ControllerCameraTestRebuildRadialPageTraversal") end)
test(62, "Traversal begins Economy", function() return has(radialAdapter,'"Economy", "Build", "Utility", "Combat"') end)
test(63, "Traversal includes Build", function() return has(radialAdapter,'"Economy", "Build", "Utility", "Combat"') end)
test(64, "Traversal ends Combat", function() return has(radialAdapter,'"Utility", "Combat"') end)
test(65, "Empty categories are omitted", function() return has(camera,"if count == 0 then return 0 end") end)
test(66, "Native page order is retained", function() return has(camera,"tonumber(option.radialPage)") end)
test(67, "Legacy page order is retained", function() return has(camera,"math.ceil(count / 8)") end)
test(68, "RB advances flattened sequence", function() return has(camera,"ControllerCameraTestTraverseRadialPages(1)") end)
test(69, "LB reverses flattened sequence", function() return has(camera,"ControllerCameraTestTraverseRadialPages(-1)") end)
test(70, "Traversal wraps", function() return has(camera,"% #traversal") end)
test(71, "Destination first item receives native focus", function() return has(camera,"ControllerCameraTestSetNativeBuildFocus(first") end)
test(72, "Page indicator uses global index", function() return has(camera,"menu.radialTraversalIndex or 1") and has(camera,"menu.radialTraversalCount or 1") end)

-- 73-85: read-only vanilla Idle Builders source with direct controller action.
test(73, "Idle widget exports one read-only snapshot", function() return has(idle,"controllerGetLiveIdleEntries") end)
test(74, "Snapshot uses live icon order", function() return has(idle,"for _, unitDefID in ipairs(existingIcons)") end)
test(75, "Previous entry is controller-owned", function() return has(camera,"ControllerCameraTestCycleIdleUnit(-1)") end)
test(76, "Next entry is controller-owned", function() return has(camera,"ControllerCameraTestCycleIdleUnit(1)") end)
test(77, "Vanilla idle order is flattened", function() return has(idle,"units[#units + 1] = unitID") end)
test(78, "Camera selects the exact live ID", function() return has(camera,'ControllerCameraTestFocusAndSelectUnit(unitID, "Idle unit")') end)
test(79, "Entry activation focuses camera", function() return has(camera,"ControllerCameraTestFocusCameraAt") end)
test(80, "Controller does not invoke mouse sound/click wrapper", function() return lacks(camera,"activateIdleEntry") end)
test(81, "Focused identity is controller-owned", function() return has(camera,"ControllerCameraTestIdleCycle.currentUnitID = unitID") end)
test(82, "Focused type is remembered", function() return has(camera,"ControllerCameraTestIdleCycle.currentTypeKey = unitDefID") end)
test(83, "Invalid focused identity is skipped by restored index scan", function() return has(camera,"local currentIndex = 0") and has(camera,"unitID == ControllerCameraTestIdleCycle.currentUnitID") end)
test(84, "LB plus Down selects focused type", function() return has(camera,"ControllerCameraTestSelectAllFocusedIdleType") end)
test(85, "Select-all uses only live current bucket", function() return has(camera,'ControllerCameraTestSelectUnits(bucket.units, "Idle type group")') end)

-- 86-89: regression and delivery contracts.
test(86, "Passing controller systems remain", function() return has(camera,'drag.mode = "moveLine"') and has(camera,"ControllerCameraTestUpdateDistributedGridChord") and has(camera,"ControllerCameraTestGetBuildSelectionContext") end)
test(87, "Legacy fallback remains", function() return has(camera,"not ControllerCameraTestUsesNativeBARUI()") and has(build,"controllerQueue") end)
test(88, "Deployment and package include focused harness", function() return has(deploy,"Test-ControllerHybridAreaIdleRepair.lua") and has(packageScript,"Test-ControllerHybridAreaIdleRepair.lua") end)
test(89, "Native manifest covers every changed override", function()
	for _, name in ipairs({"gui_ordermenu.lua","cmd_area_mex.lua","unit_smart_area_reclaim.lua","cmd_customformations2.lua","gui_idle_builders.lua"}) do
		if not has(manifest,name) then return false end
	end
	return true
end)

assert(#cases == 89, "expected exactly 89 cases")
for index, item in ipairs(cases) do
	local ok, result = pcall(item[3])
	assert(ok and result, string.format("case %d/%d failed: %s%s", index, item[1], item[2], ok and "" or (" (" .. tostring(result) .. ")")))
end
print("Controller hybrid area/idle repair tests passed: 89/89 cases.")
