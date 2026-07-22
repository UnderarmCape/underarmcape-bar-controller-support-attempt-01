local root = assert(arg[1], "repository root argument required"):gsub("[\\/]$", "")
local function path(relative) return root .. "/" .. relative end
local function read(relative)
	local handle = assert(io.open(path(relative), "rb"), "missing file: " .. relative)
	local value = handle:read("*a"); handle:close(); return value:gsub("\r\n", "\n")
end
local checks = 0
local function expect(value, message)
	checks = checks + 1
	assert(value, string.format("validation %d failed: %s", checks, message))
end
local function contains(text, literal) return text:find(literal, 1, true) ~= nil end

CMDTYPE = {
	ICON = 0, ICON_MODE = 5, ICON_MAP = 3, ICON_AREA = 4, ICON_UNIT = 2,
	ICON_UNIT_OR_MAP = 17, ICON_UNIT_OR_AREA = 18, ICON_UNIT_FEATURE_OR_AREA = 19,
	ICON_FRONT = 20, ICON_UNIT_OR_RECTANGLE = 21, ICON_BUILDING = 22,
}
Game = { maxUnits = 32000 }
local Targeting = assert(dofile(path("luaui/Include/controller_native_targeting.lua")))

expect(Targeting.IDLE == "IDLE", "named idle state")
expect(Targeting.POINT_TARGETING == "POINT_TARGETING", "named point state")
expect(Targeting.CONTROLLER_AREA_TARGETING == "CONTROLLER_AREA_TARGETING", "named area state")
expect(Targeting.BUILD_PLACEMENT == "BUILD_PLACEMENT", "named build state")

local state = Targeting.New()
local function activate(descriptor)
	Targeting.SetDescriptor(state, descriptor, CMDTYPE)
	if state.phase == Targeting.WAITING_FOR_FRESH_INPUT then
		Targeting.ObserveInput(state, false, false)
	end
end
activate({ id = 10, type = CMDTYPE.ICON_MAP, name = "Move" })
expect(state.phase == Targeting.POINT_TARGETING and state.cmdID == 10, "map command enters point targeting")
local params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 11, y = 2, z = 19 }, CMDTYPE)
expect(kind == "ground" and #params == 3 and params[1] == 11 and params[3] == 19, "map target encodes xyz")

activate({ id = 20, type = CMDTYPE.ICON_UNIT, name = "Guard" })
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "unit", targetID = 7, x = 1, y = 2, z = 3 }, CMDTYPE,
	function(unitID) return unitID == 7 end)
expect(kind == "unit" and #params == 1 and params[1] == 7, "unit target encodes ID")
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 1, y = 2, z = 3 }, CMDTYPE)
expect(params == nil and kind == "unit target required", "unit-only command rejects ground")
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "unit", targetID = 8 }, CMDTYPE,
	function() return false end)
expect(kind == "unit" and params[1] == 8, "native owner defers unit eligibility to engine")

activate({ id = 25, type = CMDTYPE.ICON_UNIT_OR_MAP, name = "Attack" })
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "unit", targetID = 55 }, CMDTYPE)
expect(kind == "unit" and params[1] == 55, "unit-or-map prefers direct unit")
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 4, y = 5, z = 6 }, CMDTYPE)
expect(kind == "ground" and #params == 3, "unit-or-map accepts ground")

activate({ id = 90, type = CMDTYPE.ICON_UNIT_FEATURE_OR_AREA, name = "Reclaim" })
params, kind = Targeting.BeginOrBuildPoint(state,
	{ targetType = "feature", targetID = 9, commandID = 32009, x = 7, y = 0, z = 8 }, CMDTYPE)
expect(kind == "anchor" and state.anchorTargetID == 32009, "area descriptor anchors over feature")
Targeting.Reset(state); activate({ id = 90, type = CMDTYPE.ICON_UNIT_FEATURE_OR_AREA, name = "Reclaim" })
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "unit", targetID = 12, x = 7, y = 0, z = 8 }, CMDTYPE)
expect(kind == "anchor" and state.anchorTargetID == 12, "area descriptor anchors over unit")

activate({ id = 90, type = CMDTYPE.ICON_AREA, name = "Reclaim", params = { 500 } })
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 100, y = 3, z = 100 }, CMDTYPE)
expect(params == nil and kind == "anchor", "first area press latches anchor")
expect(state.phase == Targeting.WAITING_FOR_ANCHOR_RELEASE and state.shape == "area", "anchor release gate is explicit")
expect(Targeting.UpdatePreview(state, { x = 700, y = 4, z = 100 }) == 600, "area preview tracks raw reticle radius")
params, kind = Targeting.BuildAnchoredParams(state)
expect(params == nil and kind == "release anchor input before confirming", "release cannot confirm and press is not armed")
Targeting.ObserveInput(state, false, false)
expect(state.phase == Targeting.RESIZING_ARMED and state.confirmationArmed, "neutral A/X arms second press")
params, kind = Targeting.BuildAnchoredParams(state)
expect(kind == "area" and #params == 4, "second area press emits xyz-radius")
expect(params[1] == 100 and params[4] == 500, "area radius respects descriptor maximum")

activate({ id = 16, type = CMDTYPE.ICON_FRONT, name = "Fight" })
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 0, y = 1, z = 0 }, CMDTYPE)
expect(kind == "anchor" and state.targetMode == Targeting.FRONT_TARGETING, "front command latches first point")
Targeting.UpdatePreview(state, { x = 20, y = 1, z = 30 })
Targeting.ObserveInput(state, false, false)
params, kind = Targeting.BuildAnchoredParams(state)
expect(kind == "front" and #params == 6 and params[6] == 30, "front command emits two xyz points")

activate({ id = 30, type = CMDTYPE.ICON_UNIT_OR_RECTANGLE, name = "Select rectangle" })
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "unit", targetID = 77, x = 2, y = 0, z = 3 }, CMDTYPE)
expect(kind == "anchor" and state.anchorTargetID == 77, "unit-or-rectangle anchors over direct unit")
Targeting.Reset(state); activate({ id = 30, type = CMDTYPE.ICON_UNIT_OR_RECTANGLE, name = "Select rectangle" })
params, kind = Targeting.BeginOrBuildPoint(state, { targetType = "ground", x = 2, y = 0, z = 3 }, CMDTYPE)
expect(kind == "anchor" and state.shape == "rectangle", "unit-or-rectangle latches ground corner")
Targeting.UpdatePreview(state, { x = 8, y = 0, z = 9 })
Targeting.ObserveInput(state, false, false)
params = Targeting.BuildAnchoredParams(state)
expect(#params == 6, "rectangle emits two xyz corners")

activate({ id = -101, type = CMDTYPE.ICON_BUILDING, name = "Solar" })
expect(state.phase == Targeting.BUILD_PLACEMENT, "negative building descriptor is delegated to placement")
activate({ id = 5, type = CMDTYPE.ICON_MODE, name = "Fire State" })
expect(state.phase == Targeting.IDLE, "non-target state command does not capture A/X")
Targeting.ArmCancelRelease(state, "B")
expect(state.cancelReleaseRequired == true, "cancel release latch arms")
Targeting.ReleaseCancelLatch(state)
expect(state.cancelReleaseRequired == false, "cancel release latch clears only explicitly")

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local orders = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")
local adapter = read("luaui/Include/controller_native_radial_adapter.lua")
local targetingDoc = read("doc/controller-companion-v0.8.0/CONTROLLER_NATIVE_TARGETING.md")
local compactionDoc = read("doc/controller-companion-v0.8.0/RADIAL_COMPACTION.md")
local checklist = read("doc/controller-companion-v0.8.0/LIVE_TEST_CHECKLIST.md")
expect(contains(camera, "function widget:ActiveCommandChanged"), "descriptor cache refreshes on active-command change")
expect(contains(camera, "ControllerCameraTestHandleNativeTargetingInput()"), "native target handler is in production input path")
expect(camera:find("ControllerCameraTestHandleNativeTargetingInput%(%).-[\n\r]+%s*commandLayerActive = false") ~= nil,
	"native targeting outranks command layer")
expect(contains(camera, "ControllerCameraTestRestoreSelectionIfChanged"), "cancel paths explicitly preserve selection")
expect(contains(camera, "ControllerCameraTestArmCancelRelease"), "B release latch is shared across modes")
expect(contains(camera, "function ControllerCameraTestPlacementShouldExit(button)\n\treturn false"), "A and X keep build placement active")
expect(contains(orders, "controllerActiveTargetAPI"), "registered native widget is the controller preview owner")
expect(not contains(camera, "mouse_event"), "no OS mouse emulation")
expect(contains(orders, "controllerGetActiveTargetDescriptor"), "Order Menu exposes real active descriptor")
expect(contains(orders, "widgetHandler.CommandNotify"), "controller dispatch preserves LuaUI command transformations")
expect(contains(orders, "if handled then return true, \"widget\" end"), "handled widget command cannot fall through to duplicate order")
expect(contains(orders, "Spring.GiveOrder, cmdID"), "unhandled command reaches engine exactly once")
expect(contains(orders, "CMD.INSERT"), "front insertion uses engine insert command")
expect(contains(adapter, "for position, item in ipairs(categoryItems)"), "radials compact from present category items")
expect(not contains(adapter, "claimPosition"), "stale hole-preserving allocator removed")

-- Production ownership, persistence, selection, and model invariants.  These
-- source-level guards complement the pure state-machine transitions above and
-- keep every requested gameplay edge represented without launching BAR.
local targetHandler = camera:match("function ControllerCameraTestHandleNativeTargetingInput%(%)\n(.-)\nend") or ""
local ownerSource = read("luaui/Include/controller_native_command_owner.lua")
expect(contains(targetHandler, "ControllerCameraTestUsesNativeBARUI()"), "target bridge is Native Experimental only")
expect(contains(targetHandler, 'ActionPressed("select")'), "A owns active command confirmation")
expect(contains(targetHandler, 'ActionPressed("smartAction")'), "X owns active command confirmation")
expect(contains(targetHandler, 'ActionPressed("cancel")'), "B owns active command cancellation")
expect(not contains(targetHandler, "ActionReleased"), "A/X release never confirms native targeting")
expect(contains(ownerSource, "BeginOrBuildPoint"), "first press resolves direct target or anchor")
expect(contains(ownerSource, "BuildAnchoredParams"), "second press confirms anchored geometry")
expect(contains(ownerSource, "UpdatePreview"), "cursor movement updates latched geometry")
expect(contains(ownerSource, "return self:_issue(params, input)"), "owner emits one logical target dispatch")
expect(contains(ownerSource, "persistentUntilQueueRelease"), "queued persistence has explicit ownership")
expect(contains(ownerSource, 'self:Cancel("queue modifier released")'), "RT release ends repeated targeting")
expect(contains(camera, "pcall(Spring.SetActiveCommand, nil)"), "non-persistent completion clears active command")
expect(contains(camera, "function ControllerCameraTestHandleNormalXInput"), "normal Smart X path remains present")
expect(contains(camera, "function ControllerCameraTestCancelPlacement(reason)"), "build placement has explicit cancel owner")
expect(contains(camera, "Preserved after placement cancel"), "build cancel verifies constructor selection")
expect(contains(camera, "placement cancelled by B"), "build cancel arms shared B release latch")
expect(contains(camera, 'placement.placementPattern = "single"'), "placement cancellation resets Grid to Single")
expect(contains(camera, "pattern single (LB released)"), "LB release restores Single")
expect(contains(camera, "function ControllerCameraTestResetHybridRadials"), "mode switch has one exclusivity reset")
expect(contains(camera, "integration-mode-switch"), "native/legacy setting invokes exclusivity reset")
expect(contains(camera, "drag.nativeControllerTargeting = false"), "mode switch clears native anchor preview")
expect(contains(camera, "ControllerCameraTestTacticalMenu.stagedOption = nil"), "mode switch clears legacy target stage")
expect(contains(camera, "Preserved across UI mode switch"), "mode switch verifies vanilla selection")
expect(contains(orders, "Spring.GetActiveCommand()"), "active detection uses real engine command")
expect(contains(orders, "Spring.GetActiveCmdDesc(cmdIndex)"), "active type comes from real descriptor")
expect(contains(orders, "for i = 1, #commands do"), "active descriptor reconciles against authoritative panel")
expect(contains(orders, "source.disabled ~= true"), "disabled/stale active descriptor rejected")
expect(contains(orders, "controllerCommandOptions"), "queue modifiers normalize for native and LuaUI paths")
expect(contains(orders, "pcall(widgetHandler.CommandNotify"), "CommandNotify failure cannot duplicate into engine")
expect(contains(orders, "issuedOK and accepted ~= false"), "engine dispatch result is checked")
expect(contains(orders, 'dispatchMode == "insert-front"'), "existing insertion modifier is retained")
expect(contains(adapter, "itemCount = #result"), "exact authoritative radial count is exported")
expect(contains(adapter, "categoryCounts = categoryCounts"), "non-empty category counts are exported")
expect(contains(adapter, "pageCounts = pageCounts"), "page counts are derived from compact items")
expect(contains(adapter, "if categoriesSeen[category]"), "zero-item categories are omitted")
expect(contains(adapter, "if item.stableKey == selectedKey"), "focus follows stable command identity")
expect(contains(adapter, "selectedIndex, selectedKey = 1"), "missing focus falls back to first present item")
expect(contains(adapter, "item.disabled = item.disabled == true"), "present disabled entries remain visible")
expect(contains(adapter, "item.queueCount = tonumber(item.queueCount) or 0"), "factory queue metadata survives compaction")
expect(contains(targetingDoc, "Press-to-Anchor, Press-to-Confirm Controller Targeting"), "targeting workflow is documented")
expect(contains(targetingDoc, "engine/widget legality is authoritative"), "native eligibility boundary is documented")
expect(contains(compactionDoc, "No empty category is emitted"), "empty-category rule is documented")
expect(contains(checklist, "59. Watch for duplicate commands"), "59-step live checklist covers duplicate/performance watch")

print(string.format("Controller Native Targeting tests passed: %d validations.", checks))
