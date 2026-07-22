local root = assert(arg[1], "repository root argument required"):gsub("[\\/]$", "")
local function path(relative) return root .. "/" .. relative end
local function read(relative)
	local handle = assert(io.open(path(relative), "rb"), "missing file: " .. relative)
	local value = handle:read("*a"); handle:close(); return value
end
local checks = 0
local function expect(value, message)
	checks = checks + 1
	assert(value, string.format("validation %d failed: %s", checks, message))
end
local function contains(text, literal) return text:find(literal, 1, true) ~= nil end

local Adapter = assert(dofile(path("luaui/Include/controller_native_radial_adapter.lua")))
local adapter = Adapter.New()

local builder = adapter:BuildBuildModel({
	{ unitDefID = 101, cmdID = -101, name = "Solar", cell = 1 },
	{ unitDefID = 102, cmdID = -102, name = "Radar", cell = 2 },
	{ unitDefID = 109, cmdID = -109, name = "Fusion", cell = 9 },
}, {
	classify = function(item) return item.unitDefID == 102 and "Utility" or "Economy" end,
	previousStableKey = "build:109",
	revision = 7,
})
expect(builder.kind == "builder", "builder model kind")
expect(builder.selectedStableKey == "build:109", "build focus preserved by stable unit identity")
expect(builder.items[1].radialSlot == 1, "slot 1 is top/first")
expect(builder.items[2].radialPage == 2 and builder.items[2].radialSlot == 1, "vanilla cell 9 maps deterministically")
expect(#builder.categories == 2, "builder categories retained")

local changedBuilder = adapter:BuildBuildModel({
	{ unitDefID = 102, cmdID = -102, name = "Radar", cell = 1 },
}, { classify = function() return "Utility" end, previousStableKey = "build:102" })
expect(changedBuilder.items[1].radialSlot == 2, "missing earlier cells do not compact a familiar item")

local factory = adapter:BuildBuildModel({
	{ unitDefID = 201, cmdID = -201, name = "Peewee", cell = 1, queueCount = 3 },
	{ unitDefID = 202, cmdID = -202, name = "Rocko", cell = 2 },
}, { isFactory = true })
expect(factory.kind == "factory" and #factory.categories == 1 and factory.categories[1] == "Factory", "factory is uncategorized")
expect(factory.items[1].radialSlot == 1 and factory.items[2].radialSlot == 2, "factory follows vanilla cells")
expect(factory.items[1].queueCount == 3, "factory queue count is vanilla-backed")

local tactical = adapter:BuildTacticalModel({
	{ id = 20, name = "Fire State", action = "firestate", isState = true,
		params = { 2, "Hold Fire", "Return Fire", "Fire at Will" } },
	{ id = 50, name = "Move State", action = "movestate", isState = true,
		params = { 1, "Hold Position", "Maneuver", "Roam" } },
	{ id = 90, name = "Visible/Cloak", action = "cloak", isState = true,
		params = { 0, "Visible", "Cloaked" } },
	{ id = 25, name = "Guard", action = "guard" },
}, { previousCategory = "utility", previousStableKey = "cmd:50", revision = 11 })
expect(#tactical.byCategory.utility == 3, "Utility contains descriptor-backed states")
expect(#tactical.byCategory.tactical == 1, "Tactical contains target commands")
expect(tactical.selectedStableKey == "cmd:50", "tactical focus preserved by command ID")
expect(#tactical.byCategory.utility[1].states == 3, "Fire State exposes descriptor states")
expect(tactical.byCategory.utility[3].isBinaryState, "Visible/Cloak is a native binary toggle")

local camera = read("luaui/Widgets/gui_controller_camera_test.lua")
local renderer = read("luaui/Include/controller_ui_shared_renderers.lua")
local buildMenu = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_buildmenu.lua")
local orderMenu = read("native-overrides/99351e53d26f5e55fa007ca1e208b936f22bd3ab/luaui/Widgets/gui_ordermenu.lua")

expect(contains(camera, "ControllerCameraTestRebuildNativeBuildModel"), "shared build adapter production path")
expect(contains(camera, "ControllerCameraTestRebuildNativeTacticalModel"), "shared tactical adapter production path")
expect(not contains(camera, "native order panel opened"), "giant native tactical bypass removed")
expect(not contains(camera, "Native Build Menu: D-pad navigate"), "flat native build bypass removed")
expect(contains(renderer, "entry.slot or index"), "renderer honors canonical holes")
expect(contains(camera, "slotCount = ControllerCameraTestUsesNativeBARUI() and 8"), "fixed eight-slot hybrid wheel")
expect(contains(camera, "ControllerCameraTestOpenNativeStateSubradial"), "multi-state sub-radial")
expect(contains(camera, "ControllerCameraTestActivateNativeState"), "state activation delegates to vanilla")
expect(contains(camera, 'placement.placementPattern = "single"'), "placement resets to Single")
expect(contains(camera, 'pattern single (LB released)'), "LB release restores Single")
expect(not contains(camera, 'ControllerCameraTestTryConstructionShortcut("pattern", "cycle")'), "LB no longer latches/cycles placement mode")
expect(contains(camera, "showNativePanelWhileRadialOpen = true"), "native panel setting defaults on")
expect(contains(camera, "showNativeFocusStroke = true"), "native focus setting defaults on")
expect(contains(buildMenu, "controllerGetFocus"), "Build Menu exports two-way focus")
expect(contains(buildMenu, "controllerSetRadialOpen"), "Build Menu scopes synchronization")
expect(contains(orderMenu, "controllerGetFocus"), "Order Menu exports two-way focus")
expect(contains(orderMenu, "controllerActivateState"), "Order Menu owns state activation")
expect(contains(orderMenu, '"vanilla-mouse"'), "mouse hover reports vanilla focus")
expect(contains(buildMenu, '"vanilla-mouse"'), "build mouse hover reports vanilla focus")
expect(contains(camera, "option and option.stableKey ~= focusBefore"), "unchanged radial focus does not overwrite vanilla mouse focus")

print(string.format("Controller Hybrid Radial tests passed: %d validations.", checks))
