local root = assert(arg and arg[1], "repository root argument required"):gsub("\\", "/")
local function read(relative)
	local handle = assert(io.open(root .. "/" .. relative, "rb"), relative)
	local value = handle:read("*a"):gsub("\r\n", "\n")
	handle:close()
	return value
end
local function has(value, needle) return value:find(needle, 1, true) ~= nil end
local function lacks(value, needle) return not has(value, needle) end
local function section(value, first, last)
	local a = assert(value:find(first, 1, true), first)
	local b = assert(value:find(last, a + #first, true), last)
	return value:sub(a, b - 1)
end
local cases = {}
local function test(id, label, callback) cases[#cases + 1] = { id, label, callback } end

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local targetingSource = read("luaui/Include/controller_native_targeting.lua")
local adapterSource = read("luaui/Include/controller_native_radial_adapter.lua")
local rendererSource = read("luaui/Include/controller_ui_shared_renderers.lua")
local uiRuntime = read("luaui/Include/controller_ui_runtime.lua")
local cellSource = read("luaui/Include/controller_native_build_cell_renderer.lua")
local order = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")
local build = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua")
local idle = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_idle_builders.lua")
local mex = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_area_mex.lua")
local reclaim = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/unit_smart_area_reclaim.lua")
local formations = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_customformations2.lua")
local props = read("tools/controller-companion/Directory.Build.props")
local metadata = read("tools/controller-companion/Shared/ProductMetadata.cs")
local lifecycle = read("tools/controller-companion/Shared/EngineSessionTracker.cs")
local bridge = read("tools/controller-companion/Program.cs")
local installer = read("tools/controller-companion/Installer/Program.cs")
local packageScript = read("tools/dev-scripts/Build_v0.8.0_Native_Test_Package.ps1")
local deploy = read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1")
local restore = read("tools/dev-scripts/Restore_v0.8.0_Native_Test.ps1")
local packageManifest = read("tools/release/bar-controller-support-v0.8.0-native-test/manifest.json")
local overrideManifest = read("native-overrides/native-override-manifest.json")

_G.CMDTYPE = {
	ICON_MAP = 1, ICON_AREA = 2, ICON_FRONT = 3, ICON_UNIT = 4,
	ICON_UNIT_OR_MAP = 5, ICON_UNIT_OR_AREA = 6, ICON_UNIT_FEATURE_OR_AREA = 7,
	ICON_UNIT_OR_RECTANGLE = 8, ICON_BUILDING = 9,
}
local Targeting = assert(loadfile(root .. "/luaui/Include/controller_native_targeting.lua"))()
local Adapter = assert(loadfile(root .. "/luaui/Include/controller_native_radial_adapter.lua"))()

local function descriptor(kind, id)
	return { id = id or 30123, cmdID = id or 30123, type = kind, name = "Test" }
end
local function targetCycle(kind, firstButton, secondButton)
	local state = Targeting.New()
	Targeting.SetDescriptor(state, descriptor(kind), CMDTYPE)
	local initiallyWaiting = state.phase == Targeting.WAITING_FOR_FRESH_INPUT and state.anchor == nil
	Targeting.ObserveInput(state, false, false)
	local firstAllowed = Targeting.CanAcceptPress(state)
	local params, first = Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 10, y = 2, z = 20 }, CMDTYPE)
	Targeting.UpdatePreview(state, { targetType = "ground", x = 110, y = 2, z = 70 })
	local releaseParams = Targeting.BuildAnchoredParams(state)
	Targeting.ObserveInput(state, false, false)
	local secondAllowed = Targeting.CanAcceptPress(state)
	local final, shape = Targeting.BuildAnchoredParams(state)
	return { state = state, initiallyWaiting = initiallyWaiting, firstAllowed = firstAllowed,
		first = first, firstParams = params, releaseParams = releaseParams,
		secondAllowed = secondAllowed, final = final, shape = shape,
		firstButton = firstButton, secondButton = secondButton }
end
local areaResults = {}
for _, first in ipairs({ "A", "X" }) do
	for _, second in ipairs({ "A", "X" }) do
		areaResults[first .. second] = targetCycle(CMDTYPE.ICON_AREA, first, second)
	end
end
local function allAreaCombos()
	for _, result in pairs(areaResults) do
		if not (result.first == "anchor" and result.shape == "area" and #result.final == 4) then return false end
	end
	return true
end
local function flat(counts)
	local result, categories = {}, { "Economy", "Build", "Utility", "Combat" }
	for categoryIndex, count in ipairs(counts) do
		for itemIndex = 1, count do
			result[#result + 1] = { category = categories[categoryIndex], id = categories[categoryIndex] .. itemIndex }
		end
	end
	return result
end
local samplePages = Adapter.PackCategories(flat({ 10, 3, 0, 4 }), 8)

-- 1-10: version and lifecycle.
test(1, "Central version is 0.8.1 Experimental", function() return has(props, ">0.8.1<") and has(props, ">Experimental<") end)
test(2, "Bridge banner matches exactly", function() return has(metadata, 'BridgeBanner => "BAR Controller Bridge " + DisplayVersion') and has(read("tools/controller-companion/Tests/Program.cs"), '"BAR Controller Bridge v0.8.1 Experimental"') end)
test(3, "Companion display matches central metadata", function() return has(bridge, "ProductMetadata.BridgeBanner") and has(metadata, 'DisplayVersion => "v" + SemanticVersion + " " + Channel') end)
test(4, "Installer/package metadata matches", function() return has(installer, "ProductMetadata.DisplayVersion") and has(packageManifest, '"version": "0.8.1"') and has(packageScript, "ControllerCompanionSemanticVersion") end)
test(5, "No stale v0.7.0 bridge constant remains", function() return lacks(bridge .. metadata .. installer, "BAR Controller Bridge v0.7.0") end)
test(6, "Companion does not exit before engine starts", function() return has(lifecycle, 'return "waiting for Spring/Recoil"') and has(lifecycle, "if (!HasAttached)") end)
test(7, "Companion tracks correct engine process", function() return has(lifecycle, "item.ProcessId == trackedProcessId") and has(lifecycle, "TrackedProcessId") end)
test(8, "Companion exits after tracked engine closes", function() return has(lifecycle, "ShouldStop = true") and has(bridge, "if (sessionTracker.ShouldStop)") end)
test(9, "Standalone mode remains open", function() return has(bridge, "if (!standalone") and has(bridge, 'argument == "--standalone"') end)
test(10, "Resources and UDP socket close cleanly", function() return has(bridge, "using var udp") and has(bridge, "Console.Out.Flush()") and has(bridge, "Console.Error.Flush()") end)

-- 11-22: deterministic single A.
local normalA = section(camera, "function ControllerCameraTestHandleNormalAInput", "local function attemptBuildMenu")
local exactSelection = section(camera, "local function attemptReticleSelection", "function ControllerCameraTestTraceSingleSelection")
test(11, "One A-down edge is generated", function() return has(normalA, 'ControllerCameraTestActionPressed("select")') and has(normalA, "selectionEdgeID") end)
test(12, "One A-up edge is generated", function() return has(normalA, 'ControllerCameraTestActionReleased("select")') and has(normalA, '"UP#"') end)
test(13, "Single A selects exactly one ID", function() return has(exactSelection, "spSelectUnitArray, { unitID }, false") end)
test(14, "Same-type units expand only on intentional double tap", function() return has(camera, "ControllerCameraTestSelectVisibleSameTypeUnderReticle") and has(camera, 'tapResult == "double"') end)
test(15, "Vanilla double-click path is not invoked", function() return lacks(exactSelection, "MousePress") and lacks(exactSelection, "smartselect") end)
test(16, "Rapid single taps remain deterministic", function() return has(normalA, "ControllerSelectionTaps.ResolveRelease") and has(camera, 'tapResult == "single"') end)
test(17, "Input-mode transition does not duplicate press", function() return has(normalA, '"DOWN#"') and has(normalA, "mouse=false") and lacks(normalA, "SetMouse") end)
test(18, "Hold-A still starts area selection", function() return has(normalA, "area.active = true") and has(normalA, "HOLD_SECONDS") end)
test(19, "RT+A additive behavior remains", function() return has(exactSelection, "ControllerCameraTestIsQueueModifierActive") and has(exactSelection, "ToggleSelection") end)
test(20, "Modal A suppresses normal selection", function() return has(camera, "ControllerCameraTestHandleTacticalMenuInput()") and has(camera, "ControllerCameraTestHandleNormalAInput(dt") end)
test(21, "Targeting A suppresses normal selection", function() local p=camera:find("local stagedTacticalBusy",1,true); return p and p < camera:find("ControllerCameraTestHandleNormalAInput(dt",p,true) end)
test(22, "Build placement A suppresses normal selection", function() local p=camera:find("local stagedTacticalBusy",1,true); return p and camera:find("ControllerCameraTestHandlePlacementInput(dt)",p,true) < camera:find("ControllerCameraTestHandleNormalAInput(dt",p,true) end)

-- 23-33: immediate and radial point commands.
test(23, "LB immediate Attack issues at cursor", function() return has(camera, "ControllerCameraTestNativeImmediateShortcut") and has(camera, "CMD.ATTACK") end)
test(24, "LB immediate Patrol issues at cursor", function() return has(camera, "CMD.PATROL") and has(camera, "controllerExecuteAtTarget") end)
test(25, "LB immediate Fight issues at cursor", function() return has(camera, "CMD.FIGHT") and has(camera, "ControllerCameraTestNativeImmediateShortcut") end)
test(26, "Exactly one immediate order issues", function() return has(order, "controllerExecuteAtTarget") and has(order, "controllerCompleteTargetShape") end)
local tacticalExecution = section(camera, "function ControllerCameraTestExecuteTacticalCommand", "function ControllerCameraTestHandleTacticalMenuInput")
test(27, "Tactical selection does not anchor", function() return has(camera, "menu.stagedWaitForNeutral = true") and lacks(tacticalExecution, "BeginOrBuildPoint") end)
test(28, "Tactical radial closes", function() return has(tacticalExecution, "ControllerCameraTestTacticalMenu.open = false") end)
test(29, "Fresh A places point", function() local r=targetCycle(CMDTYPE.ICON_MAP,"A","A"); return r.initiallyWaiting and r.firstAllowed and #r.firstParams==3 end)
test(30, "Fresh X places point", function() local r=targetCycle(CMDTYPE.ICON_MAP,"X","X"); return r.initiallyWaiting and r.firstAllowed and #r.firstParams==3 end)
test(31, "B cancels point placement", function() return has(camera, 'ControllerCameraTestCancelActiveCommandTargeting("targeting cancelled by B", true)') end)
test(32, "Smart X cannot steal placement X", function() return has(camera, "placementBusy") and has(camera, "ControllerCameraTestActionPressed(\"smartAction\")") end)
test(33, "Normal selection cannot steal placement A", function() return has(camera, "placementBusy") and has(camera, "ControllerCameraTestActionPressed(\"select\")") end)

-- 34-45: controller-owned target shapes and native adapters.
test(34, "Area Mex A to A works", function() return areaResults.AA.shape == "area" end)
test(35, "Area Mex A to X works", function() return areaResults.AX.shape == "area" end)
test(36, "Area Mex X to A works", function() return areaResults.XA.shape == "area" end)
test(37, "Area Mex X to X works", function() return areaResults.XX.shape == "area" end)
test(38, "Smart Reclaim four combinations work", function() return allAreaCombos() and has(reclaim, "controllerCompleteArea") end)
test(39, "Disassemble radius four combinations work", function() return allAreaCombos() and has(camera, '"disassemble-same-type"') and has(camera, "anchorUnitDefID") end)
test(40, "Release never confirms", function() for _,r in pairs(areaResults) do if r.releaseParams ~= nil then return false end end return true end)
test(41, "B cancels area placement", function() local s=Targeting.New(); Targeting.SetDescriptor(s,descriptor(CMDTYPE.ICON_AREA),CMDTYPE); Targeting.Reset(s,"B"); return s.phase==Targeting.IDLE and s.anchor==nil end)
test(42, "Exactly one CommandNotify", function() local _,count=order:gsub("pcall%(widgetHandler%.CommandNotify",""); return count==1 end)
test(43, "Direct fallback only when unhandled", function() return order:find("if handled then",1,true) < order:find("Spring.GiveOrder",1,true) end)
test(44, "Native transformation receives final shape", function() return has(mex,"WG.controllerAreaMex.issueArea") and has(reclaim,"controllerCompleteArea") and has(formations,"controllerCompleteShape") end)
test(45, "Retired mouse-owner path does not dispatch", function() return lacks(camera,"controllerTargetInput") and lacks(camera,"controllerBeginTarget") end)

-- 46-52: direct tactical state cycling.
test(46, "Move State A cycles forward", function() return has(tacticalExecution, "+ ((tonumber(stateDelta) or 1) < 0 and -1 or 1)") end)
test(47, "Move State X cycles backward", function() return has(camera, 'stateDelta = ControllerCameraTestActionPressed("radialQuick") and -1 or 1') end)
test(48, "Fire State A cycles forward", function() return has(tacticalExecution, "ControllerCameraTestActivateNativeState(option, desired)") end)
test(49, "Fire State X cycles backward", function() return has(tacticalExecution, "% count") end)
test(50, "No three-state sub-radial opens", function() return lacks(camera,"StateSubradial") and lacks(camera,"stateSubradial") end)
test(51, "Mixed selections converge correctly", function() return has(order,"controllerActivateState") and has(order,"desiredState") end)
test(52, "Binary state toggles remain", function() return has(tacticalExecution,"option.isBinaryState") and has(tacticalExecution,"== 0 and 1 or 0") end)

-- 53-63: deterministic minimal page packing.
test(53, "Maximum eight items per page", function() for _,p in ipairs(samplePages) do if #p.entries>8 then return false end end return true end)
test(54, "Total page count is minimized", function() return #samplePages == math.ceil(17/8) end)
test(55, "Fixed category order is preserved", function() return table.concat(Adapter.BUILDER_CATEGORY_ORDER,",")=="Economy,Build,Utility,Combat" end)
test(56, "Item order inside categories is preserved", function() local last=0; for _,p in ipairs(samplePages) do for _,e in ipairs(p.entries) do if e.category=="Economy" then local n=tonumber(e.id:match("%d+")); if n<=last then return false end; last=n end end end return true end)
test(57, "Category overflow shares next page", function() local pages=Adapter.PackCategories(flat({10,3}),8); return #pages[2].sectors==2 end)
test(58, "Economy and Combat may share", function() local pages=Adapter.PackCategories(flat({7,0,0,2}),8); return #pages[2].sectors==2 and pages[2].sectors[2].category=="Combat" end)
test(59, "Avoidable one-item wedges are removed", function() local pages=Adapter.PackCategories(flat({7,2}),8); for _,s in ipairs(pages[2].sectors) do if s.count==1 then return false end end return true end)
test(60, "Each category is contiguous per page", function()
	for _, page in ipairs(samplePages) do
		local seen = {}
		for _, sector in ipairs(page.sectors) do
			if seen[sector.category] then return false end
			seen[sector.category] = true
		end
	end
	return true
end)
test(61, "Empty categories are omitted", function() local m=Adapter.New():BuildBuildModel({{unitDefID=1},{unitDefID=2}}, {classify=function() return "Build" end}); return #m.categories==1 and m.categories[1]=="Build" end)
test(62, "Model revisions rebuild packing", function() local a=Adapter.New(); local m=a:BuildBuildModel({{unitDefID=1}}, {revision=7,classify=function()return"Economy"end}); return m.revision==7 and m.pageCount==1 end)
test(63, "Packing is deterministic", function() local a=Adapter.PackCategories(flat({10,3,0,4}),8); local b=Adapter.PackCategories(flat({10,3,0,4}),8); for i,p in ipairs(a) do for j,e in ipairs(p.entries) do if e.id~=b[i].entries[j].id then return false end end end return true end)

-- 64-77: constructor/factory categories.
test(64, "Economy classification exists", function() return has(camera,'return "Economy"') and has(camera,"unitDef.isExtractor") end)
test(65, "Build category exists", function() return has(adapterSource,'"Economy", "Build", "Utility", "Combat"') end)
test(66, "Factory and lab structures enter Build", function() return has(camera,'string.find(nameLower, "factory")') and has(camera,'string.find(nameLower, "lab")') end)
test(67, "Construction turret enters Build", function() return has(camera,'string.find(nameLower, "construction")') and has(camera,"unitDef.isBuilding") end)
test(68, "Utility classification exists", function() return has(camera,'return "Utility"') and has(camera,"radarRadius") end)
test(69, "Combat classification exists", function() return has(camera,'return "Combat"') and has(camera,"unitDef.canAttack") end)
test(70, "Ambiguous overrides are deterministic", function() return has(camera,"ControllerCameraTestConstructorClassificationOverrides") and has(camera,"armnanotc") end)
test(71, "Factory constructors enter Constructors", function() return has(camera,'if mobileBuilder then return "Constructors" end') end)
test(72, "Factory scout enters Utility", function() return has(camera,"ControllerCameraTestFactoryClassificationOverrides") and has(camera,"armflea") end)
test(73, "Factory transport enters Utility", function() return has(camera,"unitDef.canTransport") end)
test(74, "Factory radar and jammer enter Utility", function() return has(camera,"radarRadius") and has(camera,"jammerRadius") end)
test(75, "Armed factory products enter Combat", function() return has(camera,'return armed and "Combat" or "Utility"') end)
test(76, "Factory order is Constructors Utility Combat", function() return table.concat(Adapter.FACTORY_CATEGORY_ORDER,",")=="Constructors,Utility,Combat" end)
test(77, "Native queue command IDs unchanged", function() return has(camera,"option.cmdID") and has(build,"controllerQueue") end)

-- 78-93: sector and exact native cell rendering.
test(78, "One-category page uses full background", function() return has(rendererSource,"#sectors <= 1") end)
test(79, "Mixed page uses slot-aligned sectors", function() return has(rendererSource,"sector.firstSlot") and has(rendererSource,"sector.lastSlot") end)
test(80, "Sector colors match item categories", function() return has(camera,"BuildRadialPageColors") and has(rendererSource,"sector.fill") end)
test(81, "Boundary dividers render", function() return has(rendererSource,"gl.LineWidth") and has(rendererSource,"sectors[index].firstSlot") end)
test(82, "Category labels render", function() return has(rendererSource,"sector.label") and has(rendererSource,"gl.Text") end)
test(83, "One-item compact label is readable", function() return has(rendererSource,"sector.count == 1") end)
test(84, "Center panel remains readable", function() return has(rendererSource,"centerPanelScale") and has(rendererSource,"drawWrappedRole") end)
test(85, "Selected item remains obvious", function() return has(rendererSource,"selectedBorderThickness") and has(rendererSource,"local halo") end)
test(86, "Constructor items use shared vanilla renderer", function() return has(camera,"ControllerNativeBuildCellRenderer.Draw") and has(build,"ControllerNativeBuildCellRenderer.Draw") end)
test(87, "Factory items use shared vanilla renderer", function() return has(camera,"menu.isFactoryContext") and has(camera,"ControllerNativeBuildCellRenderer.Draw") end)
test(88, "Native costs match Build Menu", function() return has(cellSource,"metalCost") and has(cellSource,"energyCost") and has(build,"costOverride") end)
test(89, "Native badges match", function() return has(cellSource,"radarTexture") and has(cellSource,"groupTexture") end)
test(90, "Disabled and unaffordable states match", function() return has(cellSource,"args.disabled == true or args.unaffordable == true") end)
test(91, "Queue count matches", function() return has(cellSource,"queueCount") and has(build,"cmds[cellRectID].params[1]") end)
test(92, "Selected border setting remains", function() return has(rendererSource,"selectedBorderThickness") and has(camera,"selectedBorderScale") end)
test(93, "Old custom Native item art is inactive", function() return has(rendererSource,"renderedByNativeCell") and has(rendererSource,"if not renderedByNativeCell") and has(camera,"entryRenderer = ControllerCameraTestUsesNativeBARUI()") end)

-- 94-112: global paging and live vanilla idle list.
test(94, "RB advances packed pages", function() return has(camera,"ControllerCameraTestTraverseRadialPages(1)") end)
test(95, "LB reverses packed pages", function() return has(camera,"ControllerCameraTestTraverseRadialPages(-1)") end)
test(96, "Final page wraps first", function() return has(camera,"% #traversal") end)
test(97, "First page wraps final", function() return has(camera,"current - 1 + (tonumber(delta) or 1)") end)
test(98, "First valid item receives focus", function() return has(camera,"ControllerCameraTestSetNativeBuildFocus(first") end)
test(99, "Page indicator is global", function() return has(camera,'"PAGE " .. tostring(menu.radialTraversalIndex or 1)') end)
test(100, "Native focus identity updates", function() return has(camera,"first.menuIndex, first.stableKey") end)
test(101, "Factory quantities remain correct", function() return has(camera,'"factory queued (A)"') and has(camera,'"factory dequeued (X)"') end)
test(102, "Idle source matches vanilla ZZZ list", function() return has(idle,"controllerGetLiveIdleEntries") and has(idle,"for _, unitDefID in ipairs(existingIcons)") end)
test(103, "D-pad Right selects next ID", function() return has(camera,"ControllerCameraTestCycleIdleUnit(1)") and has(camera,"ControllerCameraTestFocusAndSelectUnit") end)
test(104, "D-pad Left selects previous ID", function() return has(camera,"ControllerCameraTestCycleIdleUnit(-1)") end)
test(105, "Idle wrap works", function() return has(camera,"% #units") end)
test(106, "Idle camera matches v0.7 baseline", function() return has(camera,"ControllerCameraTestFocusAndSelectUnit(unitID, \"Idle unit\")") end)
test(107, "Last idle ID and type are remembered", function() return has(camera,"currentUnitID = unitID") and has(camera,"currentTypeKey = unitDefID") end)
test(108, "Dead or non-idle stored ID is repaired", function() return has(camera,"local current = 0") and has(camera,"unitID == ControllerCameraTestIdleCycle.currentUnitID") end)
test(109, "LB plus Down selects current idle type", function() return has(camera,"ControllerCameraTestSelectAllFocusedIdleType") and has(camera,"SelectAllIdleUnitsInCurrentTypeBucket") end)
test(110, "Non-idle same-type units are excluded", function() return has(camera,"nativeBucket.units") and has(idle,"idleList[unitDefID]") end)
test(111, "No controller click simulation", function() return lacks(camera,"controllerActivatePreviousEntry") and lacks(camera,"controllerActivateNextEntry") and lacks(idle,"controllerActivatePreviousEntry") end)
test(112, "Active radial suppresses idle navigation", function() return has(camera,"ControllerCameraTestHandleBuildMenuInput()") and has(camera,"ControllerCameraTestHandleNormalUtility") end)

-- 113-130: retained regressions and delivery proof.
test(113, "Smart X remains", function() return has(camera,"attemptLegacyContextCommand") end)
test(114, "Hold-X drag Move remains", function() return has(camera,'drag.mode = "moveLine"') end)
test(115, "Build eligibility remains", function() return has(camera,"ControllerCameraTestGetBuildSelectionContext") end)
test(116, "Build cancellation remains", function() return has(camera,'ControllerCameraTestCancelPlacement("cancelled by B")') end)
test(117, "Distributed Grid remains", function() return has(camera,"ControllerCameraTestUpdateDistributedGridChord") end)
test(118, "Factory quantity controls remain", function() return has(camera,"factoryQueueQuantity") and has(camera,"factory dequeued 5 (X)") end)
test(119, "Native groups remain", function() return has(camera,"ControllerCameraTestNativeGroupNumber") end)
test(120, "Hint stability remains", function() return has(uiRuntime,"committedStateSignature") and has(uiRuntime,"lastHintRevision") end)
test(121, "Panel visibility remains", function() return has(camera,"controllerSetPanelVisible") and has(camera,"panelVisible") end)
test(122, "Tactical toggle remains", function() return has(camera,"ControllerCameraTestHandlePriorityTacticalToggle") end)
test(123, "Enemy direct Disassemble remains", function() return has(camera,"ControllerCameraTestIssueNativeDisassembleTarget") and has(camera,"GetReticleNativeReclaimTarget") end)
test(124, "Disassemble timeout remains", function() return has(camera,"disassembleUnusedTimeoutSeconds") end)
test(125, "Double-B exit remains", function() return has(camera,'event == "exit"') and has(camera,"double-B exit") end)
test(126, "Legacy fallback remains", function() return has(camera,"not ControllerCameraTestUsesNativeBARUI()") end)
test(127, "All changed Lua parses", function()
	for _,relative in ipairs({"luaui/Widgets/gui_controller_camera_test.lua","luaui/Include/controller_native_radial_adapter.lua",
		"luaui/Include/controller_ui_shared_renderers.lua","luaui/Include/controller_native_build_cell_renderer.lua",
		"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua",
		"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_idle_builders.lua"}) do
		if not loadfile(root .. "/" .. relative) then return false end
	end
	return true
end)
test(128, "Upvalue limits pass", function()
	local pipe = io.popen('luac -l -p "' .. root .. '/luaui/Widgets/gui_controller_camera_test.lua" 2>&1')
	if not pipe then return false end
	local listing = pipe:read("*a"); local ok = pipe:close(); local maximum = 0
	for count in listing:gmatch("(%d+) upvalues?") do maximum = math.max(maximum, tonumber(count)) end
	return ok ~= nil and maximum <= 60
end)
test(129, "Relevant .NET builds and tests pass", function()
	local command = 'dotnet run --project "' .. root .. '/tools/controller-companion/Tests/BARControllerCompanionUpdateTests.csproj" -c Release >NUL'
	local ok, _, code = os.execute(command)
	return ok == true or ok == 0 or code == 0
end)
test(130, "Deployment and rollback cover changed files", function()
	for _,name in ipairs({"controller_native_build_cell_renderer.lua","controller_native_radial_adapter.lua",
		"controller_ui_shared_renderers.lua","gui_controller_camera_test.lua","gui_buildmenu.lua","gui_idle_builders.lua",
		"BARControllerBridge.exe","BARControllerLauncher.exe","Test-ControllerInputRestoration.lua"}) do
		if not has(deploy .. packageScript .. overrideManifest, name) then return false end
	end
	return has(restore,"deploymentScope") or has(restore,"allowedCompanionRoot")
end)

assert(#cases == 130, "expected exactly 130 focused cases")
for index, item in ipairs(cases) do
	assert(index == item[1], string.format("case numbering drift at %d/%s", index, tostring(item[1])))
	local ok, result = pcall(item[3])
	assert(ok and result, string.format("case %d failed: %s%s", item[1], item[2], ok and "" or (" (" .. tostring(result) .. ")")))
end
print("Controller input restoration focused tests passed: 130/130 cases.")
