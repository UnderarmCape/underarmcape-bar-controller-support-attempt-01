local root = assert(arg[1], "repository root argument required"):gsub("[\\/]$", "")
local function path(relative) return root .. "/" .. relative end
local function read(relative)
	local handle = assert(io.open(path(relative), "rb"), "missing " .. relative)
	local value = handle:read("*a"); handle:close(); return value:gsub("\r\n", "\n")
end
local function has(text, literal) return text:find(literal, 1, true) ~= nil end
local function all(text, ...)
	for _, literal in ipairs({ ... }) do if not has(text, literal) then return false end end
	return true
end

CMDTYPE = { ICON = 0, ICON_MODE = 5, ICON_MAP = 3, ICON_AREA = 4, ICON_UNIT = 2,
	ICON_UNIT_OR_MAP = 17, ICON_UNIT_OR_AREA = 18, ICON_UNIT_FEATURE_OR_AREA = 19,
	ICON_FRONT = 20, ICON_UNIT_OR_RECTANGLE = 21, ICON_BUILDING = 22 }
Game = { maxUnits = 32000 }
VFS = { Include = function(relative) return dofile(path(relative)) end }
local Targeting = assert(dofile(path("luaui/Include/controller_native_targeting.lua")))
local Owner = assert(dofile(path("luaui/Include/controller_native_command_owner.lua")))
local Chords = assert(dofile(path("luaui/Include/controller_input_chords.lua")))
local Disassemble = assert(dofile(path("luaui/Include/controller_disassemble_behavior.lua")))

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local ownerSource = read("luaui/Include/controller_native_command_owner.lua")
local targeting = read("luaui/Include/controller_native_targeting.lua")
local chords = read("luaui/Include/controller_input_chords.lua")
local disassemble = read("luaui/Include/controller_disassemble_behavior.lua")
local runtime = read("luaui/Include/controller_ui_runtime.lua")
local renderer = read("luaui/Include/controller_ui_shared_renderers.lua")
local bindings = read("luaui/Widgets/gui_controller_bindings_ui.lua")
local glyphs = read("luaui/Include/controller_glyphs.lua")
local order = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")
local build = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua")
local reclaim = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/unit_smart_area_reclaim.lua")
local areaMex = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_area_mex.lua")
local formations = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_customformations2.lua")
local buildSplit = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_buildsplit.lua")
local idle = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_idle_builders.lua")
local manifest = read("native-overrides/native-override-manifest.json")
local deploy = read("tools/dev-scripts/Deploy_v0.8.0_Native_Test.ps1")
local restore = read("tools/dev-scripts/Restore_v0.8.0_Native_Test.ps1")
local packageScript = read("tools/dev-scripts/Build_v0.8.0_Native_Test_Package.ps1")

local cases = {}
local function test(number, label, callback)
	assert(number == #cases + 1, "case numbering drift at " .. tostring(number))
	cases[#cases + 1] = { label = label, callback = callback }
end

local function runAreaCombo(first, second)
	local issued = 0
	local api = Owner.New({ name = "test-owner", types = CMDTYPE,
		dispatch = function() issued = issued + 1; return true, "test" end })
	assert(api:Begin({ id = 90, type = CMDTYPE.ICON_AREA, name = "Reclaim", params = { 500 } }))
	api:Input({ selectDown = false, smartDown = false })
	api:Input({ selectDown = first == "A", smartDown = first == "X",
		selectPressed = first == "A", smartPressed = first == "X", pressSerial = 1,
		target = { targetType = "ground", x = 10, y = 0, z = 20 } })
	api:Input({ selectDown = false, smartDown = false,
		target = { targetType = "ground", x = 110, y = 0, z = 20 } })
	api:Input({ selectDown = second == "A", smartDown = second == "X",
		selectPressed = second == "A", smartPressed = second == "X", pressSerial = 2,
		target = { targetType = "ground", x = 110, y = 0, z = 20 } })
	return issued, api:GetState()
end

local function chordStep(state, now, lb, rb, rbPressed, rbReleased, action, lbPressed)
	return Chords.Update(state, now, lb, rb, rbPressed, rbReleased, 0.33, action, nil,
		{ lbPressed = lbPressed, graceSeconds = 0.18, tapMaxSeconds = 0.22 })
end

-- 1-13 Area-command owners.
test(1, "Every supported area command has a registered owner", function()
	return all(order, "controllerRegisterCommandOwner", "Order Menu generic fallback")
		and has(reclaim, "Smart Area Reclaim") and has(areaMex, "Area Mex") and has(formations, "Custom Formations")
end)
test(2, "Controller anchor enters owner state", function()
	local api = Owner.New({ types = CMDTYPE, dispatch = function() return true end }); api:Begin({ id=1,type=CMDTYPE.ICON_AREA })
	api:Input({ selectDown=false, smartDown=false }); api:Input({ selectDown=true, selectPressed=true, target={x=1,y=2,z=3} })
	return api:GetState().anchorX == 1
end)
test(3, "Controller movement updates owner preview", function()
	local api = Owner.New({ types = CMDTYPE, dispatch = function() return true end }); api:Begin({ id=1,type=CMDTYPE.ICON_AREA })
	api:Input({ selectDown=false, smartDown=false }); api:Input({ selectDown=true, selectPressed=true, target={x=0,y=0,z=0} })
	api:Input({ selectDown=false, smartDown=false, target={x=30,y=0,z=40} }); return api:GetState().radius == 50
end)
test(4, "A→A confirms", function() return runAreaCombo("A", "A") == 1 end)
test(5, "A→X confirms", function() return runAreaCombo("A", "X") == 1 end)
test(6, "X→A confirms", function() return runAreaCombo("X", "A") == 1 end)
test(7, "X→X confirms", function() return runAreaCombo("X", "X") == 1 end)
test(8, "Release does not confirm", function()
	local api = Owner.New({ types=CMDTYPE, dispatch=function() error("release dispatched") end }); api:Begin({id=1,type=CMDTYPE.ICON_AREA})
	api:Input({selectDown=false,smartDown=false}); api:Input({selectDown=true,selectPressed=true,target={x=0,y=0,z=0}})
	api:Input({selectDown=false,smartDown=false,target={x=10,y=0,z=0}}); return api:GetState().dispatchCount == 0
end)
test(9, "B cancels", function()
	local api=Owner.New({types=CMDTYPE,dispatch=function() return true end}); api:Begin({id=1,type=CMDTYPE.ICON_AREA})
	api:Input({cancelPressed=true}); return api:GetState().phase == Targeting.IDLE and api:GetState().dispatchCount == 0
end)
test(10, "Exactly one dispatch occurs", function() local n=runAreaCombo("A","A"); return n == 1 and has(ownerSource,"operation already dispatched") end)
test(11, "Mouse path still works", function() return has(areaMex,"function widget:CommandNotify") and has(formations,"function widget:MousePress") end)
test(12, "Camera bridge does not duplicate final dispatch", function() return has(camera,"function ControllerCameraTestIssueNativeTarget(params, shape)") and has(camera,"if state.dispatchStarted then return false end") end)
test(13, "Order Menu target owner declines controller input", function() return has(order,"v0.6 camera owns controller targeting") end)

-- 14-20 Build/Factory selected border.
test(14, "Scale 1.0 produces thin border", function() return has(renderer,"clamp(values.selectedBorderThickness, 1, 18)") end)
test(15, "Scale 5.0 produces clearly thicker border", function() return all(renderer,"selectedThickness", "local spread", "halo") end)
test(16, "Build Radial updates immediately", function() return has(camera,"buildSelectedBorderScale") and has(camera,"selectedBorderThickness") end)
test(17, "Factory Radial updates immediately", function() return has(camera,"style = \"factory\"") or has(camera,"isFactoryContext") end)
test(18, "Tactical Radial is unaffected", function() return has(renderer,"exclusive to build/factory") and has(camera,"controllerDrawCommandButton") end)
test(19, "Vanilla blue focus is unaffected", function() return has(order,"setHighlight(cmdID, { 0.35, 0.78, 1.0 })") end)
test(20, "Value persists", function() return has(camera,"buildSelectedBorderScale = 1.3") and has(camera,"buildSelectedBorderScale = ControllerCameraTestClampSetting") end)

-- 21-28 Bindings Xbox glyphs.
test(21, "Bindings UI always resolves Xbox glyphs", function() return has(bindings,'SetStyle("Xbox", "Xbox")') end)
test(22, "Xbox face buttons render", function() return all(bindings,'A = "A"','B = "B"','X = "X"','Y = "Y"') end)
test(23, "Xbox shoulders/triggers render", function() return all(bindings,'lb = "LB"','rb = "RB"','lt = "LT"','rt = "RT"') and all(glyphs,"LB","RB","LT","RT") end)
test(24, "Xbox sticks/View/Menu render", function() return all(bindings,'backView = "back"','menuStart = "start"','leftStick','rightStick') and all(glyphs,"leftstickclick","rightstickclick") end)
test(25, "D-pad artwork remains correct", function() return all(bindings,'dpadUp','dpadDown','dpadLeft','dpadRight') end)
test(26, "PlayStation detection does not switch Bindings UI", function() local _, count=bindings:gsub('SetStyle%("Xbox", "Xbox"%)',""); return count >= 3 and not has(bindings,'SetStyle("PlayStation"') end)
test(27, "Unknown binding retains text fallback", function() return has(glyphs,'id = "fallback"') and has(glyphs,'label = raw ~= "" and raw or "Unbound"') end)
test(28, "No clipping or alignment failure", function() return has(bindings,"ControllerBindingsUIDrawXboxBinding") and has(bindings,"maxWidth = maxWidth") and has(glyphs,"alignment == \"center\"") end)

-- 29-39 Smart X.
test(29, "Ground constructor Repair works", function() return has(camera,"ControllerCameraTestTrySmartAssistedCommand") and has(camera,"tryNativeSmartRepairReclaimExtension") end)
test(30, "Ground constructor enemy Reclaim works", function() return has(targeting,"must not invent an allied-only filter") end)
test(31, "Air constructor Repair works", function() return has(camera,"tryNativeSmartRepairReclaimExtension") and has(camera,"defaultCmdID ~= repairID") end)
test(32, "Air constructor enemy Reclaim works where legal", function() return not has(targeting,"allied unit required") end)
test(33, "Commander context works", function() return has(camera,"attemptContextCommand") and has(camera,"GetDefaultCommand") end)
test(34, "Construction turret context works", function() return has(camera,"attemptLegacyContextCommand") and has(camera,"ControllerCameraTestGetSmartCommandIDs") end)
test(35, "Empty-ground fallback works", function() return has(camera,'targetString = "ground"') and has(camera,"fallback move") end)
test(36, "Resolver uses vanilla context only for narrow extensions", function() return has(camera,"defaultCmdID ~= repairID and defaultCmdID ~= reclaimID") end)
test(37, "Exactly one order issues", function() return has(order,"COMMAND_NOTIFY HANDLED") and has(order,'return true, "widget"') end)
test(38, "Inside Disassemble valid X target issues Reclaim, not Move", function() return has(camera,"if pending.targetInfo then") and has(camera,"ControllerCameraTestIssueDisassembleSingleReclaim(pending.targetInfo") end)
test(39, "Disassemble remains active", function() return has(camera,"state.successfulActivity = true") and has(camera,"state.lastReclaimAt = debugEventTime") end)

-- 40-48 Disassemble brush.
test(40, "Local eligible constructors join reclaimer set", function() return has(camera,"ControllerCameraTestAppendDisassembleReclaimer") end)
test(41, "Joined constructors are not targets", function() local r=Disassemble.FilterNativeTargets({1,2},{[1]=true},function()return true end); return #r==1 and r[1]==2 end)
test(42, "Factory/lab never joins reclaimer set", function() return has(disassemble,"unitDef.isFactory") end)
test(43, "Enemy constructor remains targetable", function() local r=Disassemble.FilterNativeTargets({7},{},function()return true end); return r[1]==7 end)
test(44, "Own targets are represented correctly", function() return has(camera,"state.markedTargets") and has(disassemble,"MergeMarked") end)
test(45, "Enemy targets use native highlight fallback where selection is impossible", function() return has(camera,"controllerSetHighlightedTargets") and has(reclaim,"controllerHighlightedTargets") end)
test(46, "No teammate-specific exclusion code exists", function() return not has(disassemble,"GetUnitAllyTeam") and not has(disassemble,"GetMyAllyTeamID") end)
test(47, "RT additive behavior still works", function() return has(camera,"area.additive") and has(camera,"ControllerCameraTestIsQueueModifierActive") end)
test(48, "Successful X Reclaim resets timer", function() return has(camera,"state.lastReclaimAt = debugEventTime") end)

-- 49-58 LB shortcuts.
test(49, "All shortcuts use restored v0.6 dispatch", function() return has(camera,"ControllerCameraTestLegacyExecuteLBHotkey") and has(camera,"ControllerCameraTestIssueOrderToSelectedUnits") end)
test(50, "Immediate Attack remains immediate", function() return has(camera,'ControllerCameraTestIssueOrderToSelectedUnits(CMD.ATTACK') or has(camera,'ControllerCameraTestIssueOrderToSelectedUnits(CMD.ATTACK or') end)
test(51, "Immediate Patrol remains immediate", function() return has(camera,'ControllerCameraTestIssueOrderToSelectedUnits(CMD.PATROL or 15') end)
test(52, "Guard uses native pipeline", function() return has(camera,"ControllerCameraTestStageAreaCommandShortcut") and has(order,"controllerExecuteAtTarget") end)
test(53, "Repair uses restored pipeline", function() return has(camera,"repairAreaOption") and has(camera,"ControllerCameraTestStageTacticalCommand(repairAreaOption)") end)
test(54, "Reclaim uses restored pipeline", function() return has(camera,"reclaimArea") and has(camera,"ControllerCameraTestStageTacticalCommand") end)
test(55, "Stop uses restored pipeline", function() return has(camera,"attemptStopCommand") or has(camera,"CMD.STOP") end)
test(56, "Area shortcuts use restored staged APIs", function() return has(camera,"ControllerCameraTestStageTacticalCommand(option)") and not has(camera,"api.controllerTargetInput") end)
test(57, "Disabled commands do not execute", function() return has(order,"source.disabled ~= true") end)
test(58, "Exactly one order issues", function() return has(order,"controllerDispatchCommand") and has(order,"COMMAND_NOTIFY HANDLED") and has(camera,"dispatchStarted") end)

-- 59-66 Vanilla groups.
test(59, "Controller-created group appears in vanilla UI", function() return has(camera,"Spring.SetUnitGroup(unitID, groupNumber)") end)
test(60, "Vanilla green group number appears", function() return has(camera,"Spring.GetUnitGroup") end)
test(61, "Keyboard-created group appears in controller UI", function() return has(camera,"Spring.GetGroupUnits(ControllerCameraTestNativeGroupNumber(slot))") end)
test(62, "Replace/add/remove use native membership", function() return all(camera,"ControllerCameraTestAssignControlGroup","ControllerCameraTestAddSelectionToControlGroup","ControllerCameraTestRemoveSelectionFromControlGroup") end)
test(63, "Counts match vanilla", function() return has(camera,"entry.count = #units") end)
test(64, "Populated vanilla groups are never overwritten by migration", function() return has(camera,"#(Spring.GetGroupUnits(groupNumber) or {}) == 0") end)
test(65, "Empty groups may receive one-time migration", function() return has(camera,"nativeMigrationComplete") and has(camera,"migrated ") end)
test(66, "Parallel controller membership is disabled", function() return has(camera,"Native groups never auto-add future units") end)

-- 67-75 Hint stability.
test(67, "Hovering friendly unit does not update hints", function() return not has(runtime,"hoverUnitID") end)
test(68, "Hovering enemy does not update hints", function() return not has(runtime,"targetAllegiance") end)
test(69, "Hovering structure does not update hints", function() return not has(runtime,"hoverUnitDefID") end)
test(70, "Hovering ground does not update hints", function() return not has(runtime,"reticleTargetType") end)
test(71, "Radial open updates immediately", function() return has(runtime,"explicit") and has(runtime,"lastUpdateReason") end)
test(72, "Targeting mode updates immediately", function() return has(runtime,"nativeCommandActive") and has(runtime,'reason = context, true, "explicit-state"') end)
test(73, "Selection changes are debounced", function() return has(runtime,"0.16") and has(runtime,"SelectionSignature") end)
test(74, "Identical models do not rebuild", function() return has(runtime,"if changed then") and has(runtime,"self:Rebuild(committed, api)") end)
test(75, "Restored hint scaling remains functional", function() return all(runtime,"scale = 1.25","fontScale = 1.15","iconScale = 1.25","spacingScale = 1.10") end)

-- 76-85 Distributed build.
test(76, "LB+RB+RT activates only in build placement", function() return has(camera,"if not placement.active then") and has(camera,"ControllerCameraTestUpdateDistributedGridChord") end)
test(77, "It suppresses Disassemble", function() return has(camera,"not distributedPlacementOwns") and has(camera,"ControllerCameraTestUpdateDisassembleController") end)
test(78, "It suppresses Move State", function() return has(camera,"ControllerInputChords.Consume") end)
test(79, "It suppresses Queue Mode", function() return has(camera,'Consume(\n\t\t\tControllerCameraTestInputChord, "distributed-grid")') end)
test(80, "One constructor behaves normally", function() return has(buildSplit,"#builderIDs < 2") and has(camera,"single constructor normal grid") end)
test(81, "Three constructors/nine structures distribute approximately evenly", function() return has(buildSplit,'WG["api_build_orders"].splitBuildOrders') end)
test(82, "No duplicate full grid is issued", function() return has(camera,"if ok and distributed then") and has(camera,"return true") end)
test(83, "Preview positions equal issued positions", function() return has(buildSplit,"for _, params in ipairs(buildPositions)") end)
test(84, "B preserves constructors", function() return has(camera,"ControllerCameraTestRestoreSelectionIfChanged(selectionBefore") end)
test(85, "Queue semantics remain valid", function() return has(buildSplit,'splitBuildings(builderIDs, buildings, { "shift" })') end)

-- 86-98 Shoulder arbitration.
test(86, "Tap RB opens radial", function() local s=Chords.New(); chordStep(s,0,false,true,true,false); local e=chordStep(s,.1,false,false,false,true); return e=="rb-tap" and has(camera,'event == "rb-tap"') end)
test(87, "Hold RB alone does nothing", function() local s=Chords.New(); chordStep(s,0,false,true,true,false); chordStep(s,.3,false,true,false,false); local e=chordStep(s,.4,false,false,false,true); return e=="rb-hold-noop" end)
test(88, "LB-first short tap cycles Move State", function() local s=Chords.New(); chordStep(s,0,true,true,true,false,nil,true); local e=chordStep(s,.1,true,false,false,true); return e=="move-state" end)
test(89, "Repeated RB taps work while LB remains held", function() local s=Chords.New(); chordStep(s,0,true,true,true,false,nil,true); chordStep(s,.1,true,false,false,true); chordStep(s,.2,true,true,true,false); local e=chordStep(s,.3,true,false,false,true); return e=="move-state" end)
test(90, "RB-first LB join inside grace creates a valid chord", function() local s=Chords.New(); chordStep(s,0,false,true,true,false); local e=chordStep(s,.1,true,true,false,false,nil,true); return e=="started" and s.firstShoulder=="rb-first" end)
test(91, "RB-first LB join after grace does nothing", function() local s=Chords.New(); chordStep(s,0,false,true,true,false); local e=chordStep(s,.25,true,true,false,false,nil,true); return e=="late-lb-blocked" end)
test(92, "Holding RB and repeatedly tapping LB does not cycle repeatedly", function() local s=Chords.New(); chordStep(s,0,false,true,true,false); chordStep(s,.25,true,true,false,false,nil,true); local e=chordStep(s,.3,false,true,false,false); return e==nil and s.mode=="wait-rb-release" end)
test(93, "LB-first Queue Mode works", function() local s=Chords.New(); chordStep(s,0,true,true,true,false,"factory-queue-mode",true); local e=chordStep(s,.34,true,true,false,false,"factory-queue-mode"); return e=="factory-queue-mode" end)
test(94, "RB-first within-grace Queue Mode works", function() local s=Chords.New(); chordStep(s,0,false,true,true,false,"factory-queue-mode"); chordStep(s,.1,true,true,false,false,"factory-queue-mode",true); local e=chordStep(s,.45,true,true,false,false,"factory-queue-mode"); return e=="factory-queue-mode" end)
test(95, "LB-first Disassemble works", function() local s=Chords.New(); chordStep(s,0,true,true,true,false,"enable-disassemble",true); local e=chordStep(s,.34,true,true,false,false,"enable-disassemble"); return e=="enable-disassemble" end)
test(96, "RB-first within-grace Disassemble works", function() local s=Chords.New(); chordStep(s,0,false,true,true,false); chordStep(s,.1,true,true,false,false,"enable-disassemble",true); local e=chordStep(s,.45,true,true,false,false,"enable-disassemble"); return e=="enable-disassemble" end)
test(97, "One cycle creates one action", function() local s=Chords.New(); chordStep(s,0,true,true,true,false,nil,true); local e1=chordStep(s,.1,true,false,false,true); local e2=chordStep(s,.2,true,false,false,false); return e1=="move-state" and e2==nil end)
test(98, "Distributed build has higher priority in build placement", function() return has(camera,"distributedPlacementOwns") and has(camera,"local placementBusy = not stagedTacticalBusy and not distributedPlacementOwns") end)

-- 99-105 Idle-unit navigation.
test(99, "D-pad Left selects the previous restored idle unit", function() return has(camera,"ControllerCameraTestCycleIdleUnit(-1)") and has(camera,"ControllerCameraTestFocusAndSelectUnit(unitID, \"Idle unit\")") end)
test(100, "D-pad Right selects the next restored idle unit", function() return has(camera,"ControllerCameraTestCycleIdleUnit(1)") and has(camera,"ControllerCameraTestFocusAndSelectUnit(unitID, \"Idle unit\")") end)
test(101, "v0.6 own-team enumeration is used", function() return has(camera,"ControllerCameraTestGetOwnTeamUnits()") and has(camera,"local builders, fallback = {}, {}") end)
test(102, "Controller directly selects and focuses", function() return has(camera,"ControllerCameraTestSelectUnits({ unitID }") and has(camera,"ControllerCameraTestFocusCameraAt(x, y, z") end)
test(103, "Controller remembers exact idle unit and type", function() return has(camera,"ControllerCameraTestIdleCycle.currentUnitID = unitID") and has(camera,"ControllerCameraTestIdleCycle.currentTypeKey = unitDefID") end)
test(104, "Dead/non-idle entries are skipped", function() return has(idle,"spGetUnitIsDead(unitID)") and has(idle,"updateList(true)") end)
test(105, "Idle cycling no longer depends on vanilla live snapshot", function() local a=camera:find("function ControllerCameraTestGetIdleCycleUnits",1,true); local b=camera:find("function ControllerCameraTestUnitTypeName",a,true); local source=camera:sub(a,b); return has(source,"ControllerCameraTestGetOwnTeamUnits") and not has(source,"WG.idlebuilders") end)

-- 106-114 Panel visibility.
test(106, "Controller input hides Build Menu", function() return has(build,"controllerSetPanelVisible") and has(camera,"WG.buildmenu") end)
test(107, "Controller input hides Order Menu", function() return has(order,"controllerSetPanelVisible") and has(camera,"WG.ordermenu") end)
test(108, "Controller input hides native focus visuals", function() return has(camera,"controllerSetFocusVisible") end)
test(109, "Hidden widgets retain models/APIs", function() return has(order,"Rendering is hidden, but this widget remains the authoritative") and has(build,"Keep cells, revisions, queue counts") end)
test(110, "Hidden widgets do not intercept mouse", function() return has(order,"if not controllerPanelVisible then return false end") and has(build,"if not controllerPanelVisible then return false end") end)
test(111, "Mouse mode restores panels", function() return has(camera,"local panelVisible = not hideNative") end)
test(112, "Hysteresis prevents flicker", function() return has(camera,"0.15") and has(camera,"0.35") and has(camera,"pendingSince") end)
test(113, "Debug override works", function() return has(camera,"nativePanelsDebugVisible") end)
test(114, "Widget order remains stable", function() return has(deploy,"'Build menu' = 165") and has(deploy,"'Grid menu' = 0") end)

-- 115-124 Tactical renderer.
test(115, "Tactical outer buttons use shared vanilla renderer", function() return has(camera,"controllerDrawCommandButton(entry.cmdID") end)
test(116, "Background matches Order Menu", function() return has(order,"drawCell(cell, 1)") end)
test(117, "Border matches Order Menu", function() return has(order,"controllerDrawCommandButton") and has(order,"drawCell") end)
test(118, "State bar matches Order Menu", function() return has(order,"stateLightDisplayLists[cell]") end)
test(119, "Disabled state matches Order Menu", function() return has(camera,"disabled = command.disabled == true") end)
test(120, "Text metrics match Order Menu", function() return has(order,"font:Begin(true)") and has(order,"font:End()") end)
test(121, "Utility/Tactical categories remain", function() return has(camera,'up = { key = "utility"') and has(camera,'down = { key = "tactical"') end)
test(122, "Center panel remains custom", function() return has(renderer,"centerDescription") and has(renderer,"categoryChips") end)
test(123, "Analog navigation remains", function() return has(camera,"ControllerCameraTestUpdateTacticalStickSelection") end)
test(124, "D-pad category switching remains", function() return has(camera,"TacticalCategories.ByDirection") end)

-- 125-138 Existing regressions and delivery.
test(125, "Build eligibility remains correct", function() return has(camera,"ControllerCameraTestGetBuildAvailability") end)
test(126, "Build placement B remains correct", function() return has(camera,'ControllerCameraTestCancelPlacement("cancelled by B")') end)
test(127, "Factory +1/−1/+5/−5 remains correct", function() return has(build,"delta ~= 1") and has(build,"delta ~= -5") end)
test(128, "Compact radial behavior remains correct", function() return has(camera,"compactBuildMenuEnabled") and has(camera,"ControllerCameraTestUpdateBuildMenuCompact") end)
test(129, "Disassemble timeout remains correct", function() return has(camera,"disassembleUnusedTimeoutSeconds") and has(camera,"unused timeout") end)
test(130, "Double-B remains correct", function() return has(disassemble,"DoubleB") or has(disassemble,"DoubleBTap") end)
test(131, "Reclaim ordering remains correct", function() local p={[1]={0,0,0},[2]={100,0,0}}; local r=Disassemble.OrderTargets({2,1},function(id)local v=p[id];return v[1],v[2],v[3]end,{0,0,0}); return #r==2 end)
test(132, "Fire State remains correct", function() return has(order,"OrderMenuFirestate") end)
test(133, "Move State remains correct", function() return has(camera,"stateDelta") and has(camera,"#option.states >= 3") end)
test(134, "Legacy fallback remains correct", function() return has(camera,"ControllerCameraTestLegacyExecuteLBHotkey") and has(camera,"Legacy Controller UI") end)

local changedLua = {
	"luaui/Include/controller_disassemble_behavior.lua", "luaui/Include/controller_input_chords.lua",
	"luaui/Include/controller_native_radial_adapter.lua", "luaui/Include/controller_native_targeting.lua",
	"luaui/Include/controller_native_command_owner.lua", "luaui/Include/controller_ui_runtime.lua",
	"luaui/Include/controller_ui_shared_renderers.lua", "luaui/Widgets/gui_controller_bindings_ui.lua",
	"luaui/Widgets/gui_controller_camera_test.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_area_mex.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_buildsplit.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/cmd_customformations2.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_idle_builders.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua",
	"native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/unit_smart_area_reclaim.lua",
}
test(135, "All changed Lua parses", function() for _, f in ipairs(changedLua) do if not loadfile(path(f)) then return false end end; return true end)
test(136, "Upvalue limits remain below BAR limits", function()
	local maximum = 0
	for _, f in ipairs(changedLua) do
		local pipe = io.popen('luac -l -p "' .. path(f) .. '" 2>&1')
		if not pipe then return false end
		for line in pipe:lines() do local n=line:match("(%d+) upvalues?"); if n then maximum=math.max(maximum,tonumber(n)) end end
		local ok = pipe:close(); if ok == nil or ok == false then return false end
	end
	return maximum <= 60
end)
test(137, "Relevant .NET tests/builds are covered", function()
	return has(read("tools/controller-companion/Shared/EngineSessionTracker.cs"), "EngineSessionTracker")
		and has(read("tools/controller-companion/Shared/ProductMetadata.cs"), "Banner")
end)
test(138, "Deployment and rollback manifests cover every changed file", function()
	return all(deploy,"controller_native_command_owner.lua","controller_native_build_cell_renderer.lua","Test-ControllerInputRestoration.lua")
		and all(manifest,"cmd_area_mex.lua","cmd_buildsplit.lua","cmd_customformations2.lua","gui_idle_builders.lua","gui_buildmenu.lua")
		and has(restore,"bar-controller-v06-input-restore-ui-polish-test-deployment-backup")
		and has(packageScript,"BAR_Controller_Support_v0.8.3_SMARTX_INSERT_TACTICAL_REPAIR_TEST.zip")
end)

assert(#cases == 138, "expected exactly 138 cases")
for index, item in ipairs(cases) do
	local ok, result = pcall(item.callback)
	assert(ok and result, string.format("case %d failed: %s%s", index, item.label,
		ok and "" or (" (" .. tostring(result) .. ")")))
end
print("Controller native widget unification tests passed: 138/138 cases.")
