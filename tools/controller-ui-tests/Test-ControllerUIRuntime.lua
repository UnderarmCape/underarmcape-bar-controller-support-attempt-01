local root = (arg and arg[1]) or "."
local function read(path) local file = assert(io.open(path, "rb")); local value = file:read("*a"); file:close(); return value end
local function equal(actual, expected, label) if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end end
local function truthy(value, label) if not value then error(label .. ": expected true", 2) end end

loadstring = loadstring or load
Json = dofile(root .. "/common/luaUtilities/json.lua")
Spring = { GetViewGeometry = function() return 1920, 1080 end }
GL = { TRIANGLE_FAN = 1, LINE_LOOP = 2 }
gl = setmetatable({ GetTextWidth = function(value) return #tostring(value) * 0.55 end,
	BeginEnd = function(_, callback) callback() end }, { __index = function() return function() end end })
VFS = {
	RAW_FIRST = 1,
	LoadFile = function(path) if path == "controller-ui/shipping-defaults.json" then return read(root .. "/controller-ui/shipping-defaults.json") end end,
	Include = function(path)
		if path == "LuaUI/Include/controller_ui_shared_renderers.lua" then return dofile(root .. "/luaui/Include/controller_ui_shared_renderers.lua") end
		if path == "LuaUI/Include/controller_glyphs.lua" then return dofile(root .. "/luaui/Include/controller_glyphs.lua") end
	end,
}
WG = {}
local Runtime = dofile(root .. "/luaui/Include/controller_ui_runtime.lua")
local service = Runtime.New()
local api = service:PublicAPI()
local fixture = Json.decode(read(root .. "/tools/controller-ui-tests/fixtures/controller-ui-v0.6.1-hints.json"))

equal(service.activeVersion, "0.7.0-1", "shipping version")
for key, value in pairs(fixture.component) do equal(api.GetComponent("hints")[key], value, "v0.6.1 visual fixture " .. key) end
for key, value in pairs(fixture.bindingsButton) do equal(api.GetComponent("bindingsButton")[key], value, "bindings fixture " .. key) end

local personalX, personalY = 0.90958327, 0.82051295
service:SetConfigData({ schemaVersion = 3,
	personalSettings = { components = { bindingsButton = { x = personalX, y = personalY } } },
	authorData = { favorites = { preserved = true } }, editorChrome = { tab = 4 } })
equal(api.GetComponent("bindingsButton").x, personalX, "personal bindings x")
equal(api.GetComponent("bindingsButton").y, personalY, "personal bindings y")
local saved = service:GetConfigData()
truthy(saved.authorData.favorites.preserved, "author data passthrough")
equal(saved.editorChrome.tab, 4, "chrome passthrough")

local context = { disassembleToggleCharge = true }
WG.BARControllerSupport = {
	GetContextSnapshot = function() return context end,
	GetBindingRevision = function() return 1 end,
	GetBinding = function(action) return ({ select = "A", cancel = "B", smartAction = "X", buildRadial = "RB", controlGroupModifier = "RT" })[action] or action end,
}
service:Update(0.1)
equal(#service.visibleHints, 0, "charge owns hint surface")
context = { disassembleMode = true }
service:Update(0.05)
equal(#service.visibleHints, 0, "confirmed-modal exit grace")
service:Update(0.13)
truthy(#service.visibleHints >= 5, "Disassemble hints visible")
local definitions = service:HintAPI().GetDefinitions()
truthy(definitions["normal-selection-toggle"] ~= nil, "RT+A definition")
truthy(definitions["lb-tactical-primary"] ~= nil, "v0.6.1 LB tactical hint retained")
truthy(definitions["factory-queue-one"] ~= nil, "v0.6.1 factory hint retained")
truthy(definitions["normal-visible-select"] ~= nil, "v0.6.1 quick visible-selection hint retained")

local layout = read(root .. "/luaui/Widgets/gui_controller_ui_layout.lua")
truthy(layout:find("enabled = false", 1, true) ~= nil, "authoring disabled")
print("Controller UI runtime tests passed: v0.6.1 visual fixture parity, context stabilization, personal migration, hint ownership, and authoring retirement.")
