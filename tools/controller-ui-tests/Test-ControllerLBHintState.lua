local root = (arg and arg[1]) or "."

local function read(path)
	local file = assert(io.open(path, "rb")); local content = file:read("*a"); file:close(); return content
end

local function equal(actual, expected, label)
	if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function truthy(value, label)
	if not value then error(label .. ": expected true", 2) end
end

local function contains(source, value, label)
	truthy(string.find(source, value, 1, true) ~= nil, label)
end

gl = setmetatable({}, { __index = function() return function() end end })
GL = { TRIANGLE_FAN = 1, LINE_LOOP = 2 }
local shared = dofile(root .. "/luaui/Include/controller_ui_shared_renderers.lua")
local behavior = assert(shared.SelectionBehavior)
local camera = read(root .. "/luaui/Widgets/gui_controller_camera_test.lua")
local layout = read(root .. "/luaui/Widgets/gui_controller_ui_layout.lua")
local defaults = read(root .. "/controller-ui/shipping-defaults.json")
local tests = 0
local function test(label, fn) tests = tests + 1; local ok, err = pcall(fn); if not ok then error(label .. ": " .. tostring(err), 0) end end

test("1 A-tap transient does not commit Hold-A context", function()
	local state = behavior.NewHintContextState()
	local normal = { selectedCount = 0 }; behavior.AdvanceHintContext(state, normal, "normal", 0, false)
	local committed, changed = behavior.AdvanceHintContext(state, { areaSelection = true }, "area", 0.04, false)
	equal(committed, normal, "transient context"); equal(changed, false, "transient change")
	committed = behavior.AdvanceHintContext(state, { selectedCount = 1 }, "selected", 0.08, false)
	equal(committed, normal, "final selection still debounced")
	contains(camera, 'areaSelection = ControllerCameraTestAreaSelect.active == true', "unconfirmed A press hidden")
	truthy(not string.find(layout, 'id = "normal-select-hold"', 1, true), "normal Hold-A hint removed")
end)

test("2 confirmed Hold-A radial is immediate", function()
	local state = behavior.NewHintContextState(); behavior.AdvanceHintContext(state, {}, "normal", 0, false)
	local radial, changed = behavior.AdvanceHintContext(state, { selectionRadialOpen = true }, "radial", 0.01, true)
	truthy(radial.selectionRadialOpen and changed, "confirmed radial")
end)

test("3 ordinary hint debounce settles final selection", function()
	local state = behavior.NewHintContextState(); behavior.AdvanceHintContext(state, {}, "normal", 0, false)
	behavior.AdvanceHintContext(state, { selectedCount = 1 }, "one", 0.02, false)
	behavior.AdvanceHintContext(state, { selectedCount = 8 }, "eight", 0.08, false)
	local committed, changed = behavior.AdvanceHintContext(state, { selectedCount = 8 }, "eight", 0.23, false, 0.14, 0.12)
	equal(committed.selectedCount, 8, "settled count"); truthy(changed, "settled transition")
end)

test("4 LB tactical hints resolve the live modifier", function()
	contains(camera, 'pitchModifier = "LB"', "default LB binding")
	contains(layout, 'chordActions = { "pitchModifier", "cancel" }', "live stop chord")
	truthy(not string.find(layout, 'inputs = { "back", "B" }', 1, true), "no Back+B tactical hint")
end)

test("5 quick LB tap is eligible", function()
	local state = behavior.NewLBCycle(); behavior.PressLB(state, 1)
	truthy(behavior.ReleaseLB(state, 1.10, 0.20, 0.20), "quick tap")
end)

test("6 LB hold release does not select", function()
	local state = behavior.NewLBCycle(); behavior.PressLB(state, 1); behavior.UpdateLB(state, 1.21, 0.20)
	equal(behavior.ReleaseLB(state, 1.22, 0.20, 0.20), false, "held release")
end)

test("7 LB+B consumes tap selection", function()
	local state = behavior.NewLBCycle(); behavior.PressLB(state, 2); behavior.ConsumeLB(state, "tactical chord cancel")
	equal(behavior.ReleaseLB(state, 2.08, 0.20, 0.20), false, "consumed chord")
	contains(camera, 'ControllerCameraTestConsumeLBCycle("tactical chord " .. action)', "dispatcher consumption")
end)

test("8 abandoned chord remains consumed", function()
	local state = behavior.NewLBCycle(); behavior.PressLB(state, 3); behavior.ConsumeLB(state, "chord started")
	behavior.UpdateLB(state, 3.05, 0.20); equal(behavior.ReleaseLB(state, 3.06, 0.20, 0.20), false, "abandoned chord")
end)

test("9 LB+LT opens the filter radial", function()
	contains(camera, 'ControllerCameraTestBindingPressed("LT") then ControllerCameraTestOpenVisibleSelectionRadial()', "LB+LT open")
end)

test("10 left-stick sectors map all four filters", function()
	equal(behavior.FilterFromStick(0, 1), "Last Selected", "up")
	equal(behavior.FilterFromStick(-1, 0), "Builders", "left")
	equal(behavior.FilterFromStick(1, 0), "Air", "right")
	equal(behavior.FilterFromStick(0, -1), "Combat", "down")
	equal(behavior.FilterFromStick(0.1, 0.1), nil, "deadzone")
end)

test("11 releasing LT confirms", function()
	contains(camera, 'ControllerCameraTestBindingReleased("LT")', "LT release")
	contains(camera, 'ControllerCameraTestSettings.visibleSelectionFilter = selected', "filter confirmation")
end)

test("12 B cancels the filter radial", function()
	contains(camera, 'ControllerCameraTestActionPressed("cancel")', "cancel binding")
	contains(camera, 'ControllerCameraTestCancelVisibleSelectionRadial("cancel action")', "cancel action")
end)

test("13 releasing LB first cancels", function()
	contains(camera, 'ControllerCameraTestCancelVisibleSelectionRadial("modifier released first")', "modifier-first cancel")
end)

test("14 radial confirmation consumes the LB cycle", function()
	contains(camera, 'ControllerCameraTestConsumeLBCycle("filter radial confirmed")', "confirmation consumption")
end)

local facts = {
	[1] = { safe = true, mobile = true, combat = true, builder = false },
	[2] = { safe = true, mobile = true, combat = true, builder = true, combatRole = false },
	[3] = { safe = true, mobile = true, combat = true, builder = true, combatRole = true },
	[4] = { safe = true, mobile = true, air = true, combat = false, builder = false },
	[5] = { safe = false, mobile = true, combat = true, air = true, builder = true },
}
local function classify(id) return facts[id] end

test("15 Builders filter selects constructors", function()
	local result = behavior.FilterVisibleUnits({ 5, 3, 2, 1 }, "Builders", classify)
	equal(table.concat(result, ","), "2,3", "builder set")
end)

test("16 Air filter selects visible air", function()
	local result = behavior.FilterVisibleUnits({ 1, 4, 5 }, "Air", classify)
	equal(table.concat(result, ","), "4", "air set")
end)

test("17 Combat excludes unrelated builders", function()
	local result = behavior.FilterVisibleUnits({ 1, 2, 3, 4, 5 }, "Combat", classify)
	equal(table.concat(result, ","), "1,3", "combat set")
end)

test("18 Last Selected restores a previous snapshot", function()
	contains(camera, 'ControllerCameraTestSelectSnapshot(previous, "Restored last selection", true)', "last-selection restore")
	contains(camera, 'history.previousSelection = current', "safe previous swap")
end)

test("19 invalid/dead Last Selected units are removed", function()
	contains(camera, 'Spring.GetUnitIsDead', "dead-unit validation")
	contains(camera, 'ControllerCameraTestSafeSelectionSnapshot(history.previousSelection)', "previous validation")
end)

test("20 empty Last Selected preserves selection", function()
	contains(camera, 'if #previous == 0 then return false end', "empty previous guard")
end)

test("21 filter persists through personal config", function()
	contains(camera, 'visibleSelectionFilter = "Combat"', "clean-install default")
	contains(camera, 'if type(value) ~= "table" and key ~= "debugPanelVisible"', "scalar config save")
	contains(camera, 'ControllerSelectionBehavior.IsValidFilter(settings.visibleSelectionFilter)', "migration validation")
	local setterSource = assert(string.match(camera,
		'(function ControllerCameraTestSetSetting.-%s+end)%s+function ControllerCameraTestResetSetting'))
	ControllerSelectionBehavior = behavior
	ControllerCameraTestSettings = { visibleSelectionFilter = "Combat" }
	ControllerCameraTestApplySettingsDefaults = function() end
	assert((loadstring or load)(setterSource))()
	equal(ControllerCameraTestSetSetting("visibleSelectionFilter", "Builders"), "Builders", "valid filter persisted")
	equal(ControllerCameraTestSetSetting("visibleSelectionFilter", "invalid"), "Builders", "invalid filter rejected")
end)

test("22 existing area-selection radial is unchanged", function()
	contains(camera, 'local labels = { "All Mobile", "Air", "Combat", "Builders" }', "area radial labels")
	contains(camera, 'area.currentFilter = area.currentFilter or "All Mobile"', "area default")
end)

test("23 production and preview share the radial renderer", function()
	contains(camera, 'ControllerUISharedRenderers.DrawRadial({', "production shared renderer")
	contains(layout, 'extra.SharedRenderers.DrawRadial({', "preview shared renderer")
	contains(layout, '"Visible Selection Filter Radial"', "preview context")
end)

test("24 selection path has no periodic logging or pass-through", function()
	local segment = assert(string.match(camera, 'function ControllerCameraTestApplyVisibleSelectionFilter.-function ControllerCameraTestSelectCombatUnitsOnScreen'))
	truthy(not string.find(segment, "Spring.Echo", 1, true), "no echo")
	contains(camera, 'ControllerCameraTestVisibleSelection.radial.open then return false', "radial dispatcher block")
end)

test("25 shipping defaults enable tested stabilization", function()
	contains(defaults, '"defaultsVersion": "0.6.1-1"', "defaults revision")
	contains(defaults, '"contextEnterDebounce": 0.14', "enter timing")
	contains(defaults, '"contextExitGrace": 0.12', "exit timing")
	contains(camera, 'lbTacticalHoldSeconds = 0.20', "hold timing")
end)

print("Controller LB/hint-state focused tests passed: " .. tests .. "/25 behaviors validated.")
