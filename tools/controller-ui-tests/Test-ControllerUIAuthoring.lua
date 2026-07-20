local root = (arg and arg[1]) or "."
local virtualFiles = {}
local currentContext = {}
local mouseX, mouseY = 0, 0

local function readFile(path)
	local file = assert(io.open(path, "rb"))
	local content = file:read("*a")
	file:close()
	return content
end

local function assertEqual(actual, expected, label)
	if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function assertTrue(value, label)
	if not value then error(label .. ": expected true", 2) end
end

widget = {}
WG = {}
GL = { LINE_LOOP = 1, LINES = 2 }
gl = setmetatable({
	Color = function() end, Rect = function() end, Text = function() end,
	GetTextWidth = function(text) return #tostring(text) * 0.55 end,
}, { __index = function() return function() end end })
Spring = {
	GetViewGeometry = function() return 1920, 1080 end,
	GetMouseState = function() return mouseX, mouseY end,
	GetModKeyState = function() return false, false, false, false end,
	GetGameFrame = function() return 1 end,
	CreateDir = function() end,
	Echo = function() end,
}
widgetHandler = { AddAction = function() end, RemoveAction = function() end }
KEYSYMS = { BACKSPACE = 8, TAB = 9, RETURN = 13, ESCAPE = 27, SPACE = 32, DELETE = 127,
	UP = 273, DOWN = 274, RIGHT = 275, LEFT = 276, HOME = 278, END = 279, PAGEUP = 280, PAGEDOWN = 281, F1 = 282 }
VFS = {
	RAW_FIRST = 1,
	Include = function(path)
		if path == "LuaUI/Include/controller_ui_editor_workspace.lua" then
			return dofile(root .. "/luaui/Include/controller_ui_editor_workspace.lua")
		end
		if path == "LuaUI/Include/controller_glyphs.lua" then
			return dofile(root .. "/luaui/Include/controller_glyphs.lua")
		end
		return nil
	end,
	LoadFile = function(path)
		if virtualFiles[path] ~= nil then return virtualFiles[path] end
		if path == "controller-ui/shipping-defaults.json" then return readFile(root .. "/controller-ui/shipping-defaults.json") end
		return nil
	end,
}
loadstring = loadstring or load
Json = dofile(root .. "/common/luaUtilities/json.lua")

local actions = {
	"select", "cancel", "smartAction", "buildRadial", "commandLayer", "insertNextCommandModifier",
	"appendQueueModifier", "controlGroupModifier", "pitchModifier", "removeQueuedCommand",
	"removeLastQueuedCommand", "radialSelect", "radialCancel", "radialQuick", "radialClose",
	"radialPrevPage", "radialNextPage", "place", "placeStay", "cancelPlacement",
	"rotateBuildingLeft", "rotateBuildingRight", "spacingUp", "spacingDown", "patternPrev", "patternNext",
	"tacticalSelect", "tacticalCancel", "tacticalClose", "commandUp", "commandDown", "commandLeft",
	"commandRight", "idlePrev", "idleNext", "groupSlotUp", "groupSlotDown", "groupRecallOrAssign",
	"groupAssign", "groupClear", "selectCommander",
}
local bindingDefinitions = {}
for _, action in ipairs(actions) do bindingDefinitions[#bindingDefinitions + 1] = { action = action, label = action, group = "test" } end
WG.BARControllerSupport = {
	GetBinding = function() return "A" end,
	GetBindingRevision = function() return 1 end,
	GetBindingDefinitions = function() return bindingDefinitions end,
	GetShortcutBinding = function() return { "back", "start" } end,
	GetContextSnapshot = function() return currentContext end,
	GetBackStartHoldProgress = function() return 0 end,
	IsInputPressed = function() return false end,
	SetLayoutEditorOpen = function() end,
}

dofile(root .. "/luaui/Widgets/gui_controller_ui_layout.lua")
widget:Initialize()

local api = assert(WG.ControllerUISettings)
assertEqual(api.SCHEMA_VERSION, 3, "schema")
assertEqual(api.GetPropertySource("hints", "mode"), "bundled shipping", "bundled precedence")

widget:SetConfigData({
	schemaVersion = 2,
	settings = { global = { scale = 1.1 }, components = { hints = { mode = "Minimal" } } },
})
assertEqual(api.Get("global", "scale"), 1.1, "schema-2 personal migration")
assertEqual(api.Get("hints", "mode"), "Minimal", "personal precedence")
assertEqual(api.GetPropertySource("hints", "mode"), "personal", "personal source")

currentContext = { buildPlacement = true, hasSelection = true, hasBuilder = true }
api.Set("hints", "mode", "Contextual")
widget:Update(0.2)
local contextualCount = #WG.ControllerHintRegistry.GetVisibleActions()
api.Set("hints", "mode", "Layered")
widget:Update(0.2)
local layeredHints = WG.ControllerHintRegistry.GetVisibleActions()
assertTrue(#layeredHints > contextualCount, "layered mode adds the underlying normal layer")
local foundUnderlyingLayer = false
for _, hint in ipairs(layeredHints) do if hint.layer == 1 then foundUnderlyingLayer = true; break end end
assertTrue(foundUnderlyingLayer, "layered mode marks underlying actions")
api.Save()
currentContext = {}

assertEqual(#api.GetHintCategories(), 14, "shipping hint categories")
api.Set("authoring", "contextPreview", "Normal Gameplay")
widget:Update(0.2)
local commanderVisible = false
for _, hint in ipairs(WG.ControllerHintRegistry.GetVisibleActions()) do if hint.action == "selectCommander" then commanderVisible = true end end
assertTrue(commanderVisible, "select Commander hint is visible in normal gameplay")
api.SetActionHidden("selectCommander", true)
widget:Update(0.2)
for _, hint in ipairs(WG.ControllerHintRegistry.GetVisibleActions()) do assertTrue(hint.action ~= "selectCommander", "hidden action removed") end
assertTrue(api.Undo(), "action organization undo")
widget:Update(0.2)
commanderVisible = false
for _, hint in ipairs(WG.ControllerHintRegistry.GetVisibleActions()) do if hint.action == "selectCommander" then commanderVisible = true end end
assertTrue(commanderVisible, "action organization restored by undo")

api.Set("authoring", "contextPreview", "Long Binding Stress Test")
for _, presentation in ipairs({ "Glyph + Action Text", "Text Chip + Action", "Button Chip Only", "Action Text Only",
	"Background Only", "Minimal Glyph", "Compact", "Full Descriptive", "Custom" }) do
	api.Set("hints", "presentation", presentation)
	widget:Update(0.2)
	widget:DrawScreen()
end
local stressVisible = 0
for _, hint in ipairs(WG.ControllerHintRegistry.GetVisibleActions()) do if string.find(hint.id, "stress%-long") then stressVisible = stressVisible + 1 end end
assertEqual(stressVisible, 3, "long binding stress preview")
api.Set("authoring", "contextPreview", "Live")
api.Save()

api.Set("theme", "colorTarget", "Accent")
api.Set("theme", "colorHex", "#FF0000")
assertEqual(api.Get("theme", "accentR"), 1, "hex color red")
assertEqual(api.Get("theme", "accentG"), 0, "hex color green")
assertTrue(#api.GetRecentColors() >= 1, "recent color recorded")
api.Set("theme", "colorHue", 120)
assertTrue(api.Get("theme", "accentG") > api.Get("theme", "accentR"), "HSV color editing")
api.Save()

local cached = Json.decode(readFile(root .. "/controller-ui/shipping-defaults.json"))
cached.defaultsVersion = "0.6.0-2"
cached.settings.components.hints.mode = "Everything"
cached.enforcedSettings = { components = { hints = { mode = "Layered" } } }
cached.enforcedPaths = { "hints.mode" }
virtualFiles["LuaUI/Config/BARControllerSupport/controller-ui-defaults.json"] = Json.encode(cached)
virtualFiles["LuaUI/Config/BARControllerSupport/controller-ui-defaults-manifest.json"] = Json.encode({
	kind = "bar-controller-ui-defaults-manifest", defaultsVersion = "0.6.0-2",
})
api.ReloadDefaults()
assertEqual(api.Get("hints", "mode"), "Layered", "enforced remote precedence")
assertEqual(api.GetPropertySource("hints", "mode"), "enforced remote", "enforced source")
api.Set("hints", "mode", "Contextual")
assertEqual(api.Get("hints", "mode"), "Layered", "enforced property lock")

api.Set("global", "scale", 1.4)
assertEqual(api.Get("global", "scale"), 1.4, "preview edit")
assertTrue(api.Undo(), "undo available")
assertEqual(api.Get("global", "scale"), 1.1, "undo restored")
assertTrue(api.Redo(), "redo available")
assertEqual(api.Get("global", "scale"), 1.4, "redo restored")
api.Save()
api.Set("global", "scale", 1.5)
local recovery = widget:GetConfigData()
assertTrue(recovery.recovery.dirty, "dirty recovery emitted")
widget:SetConfigData(recovery)
assertEqual(api.Get("global", "scale"), 1.5, "unsaved recovery precedence")
assertTrue(api.GetLayerStatus().dirty, "recovery remains dirty")

local audit = WG.ControllerHintRegistry.GetAuditReport()
assertEqual(#audit.missingBindings, 0, "complete action coverage")
assertEqual(#audit.unregisteredActions, 0, "no orphan hint actions")
assertEqual(audit.bindingCount, 41, "binding audit count")

api.OpenEditor()
widget:DrawScreen()
assertEqual(widgetHandler.textOwner, widget, "editor owns keyboard input before gameplay actions")
assertTrue(widget:KeyPress(string.byte("f"), { ctrl = true }, false, "f"), "search shortcut captured")
widget:TextInput("Global scale")
widget:KeyPress(KEYSYMS.RETURN, {}, false, "return")
widget:DrawScreen()
local beforeHold = api.Get("global", "scale")
assertTrue(widget:KeyPress(KEYSYMS.RIGHT, {}, false, "right"), "keyboard adjustment captured")
widget:Update(0.45)
widget:KeyRelease(KEYSYMS.RIGHT, {}, "right")
assertTrue(api.Get("global", "scale") >= beforeHold + 0.099, "hold repeat advanced value")
mouseX, mouseY = 1800, 420
assertTrue(widget:MouseWheel(false), "mouse wheel consumed over inspector")
for _ = 1, 12 do assertTrue(widget:KeyPress(KEYSYMS.TAB, {}, false, "tab"), "tab focus captured") end
assertTrue(widget:KeyPress(KEYSYMS.F1, {}, false, "f1"), "context help captured")
widget:DrawScreen()
assertTrue(widget:KeyPress(KEYSYMS.ESCAPE, {}, false, "escape"), "modal escape captured")
api.CloseEditor()
assertTrue(widgetHandler.textOwner == nil, "editor releases keyboard ownership")

for index = 1, 500 do
	api.Set("hints", "x", (index % 100) / 100)
	api.Set("hints", "y", ((index * 3) % 100) / 100)
end
local stress = api.GetLayerStatus()
assertTrue(stress.undo <= 60, "bounded undo under stress")
assertTrue(api.Get("hints", "x") >= 0 and api.Get("hints", "x") <= 1, "stress x clamped")
assertTrue(api.Get("hints", "y") >= 0 and api.Get("hints", "y") <= 1, "stress y clamped")

api.SetActionHidden("selectCommander", true)
api.Set("authoring", "developerAuthoring", true)
assertTrue(api.SetShippingEnforcement("hotSlots", "slotGap", true), "local shipping enforcement")
local authorRecovery = widget:GetConfigData().recovery
assertTrue(authorRecovery.dirty and authorRecovery.authorData.hiddenActions.selectCommander, "action organization recovery")
assertTrue(authorRecovery.authorData.shippingEnforcedPaths["hotSlots.slotGap"], "enforcement recovery")
widget:SetConfigData(widget:GetConfigData())
assertTrue(widget:GetConfigData().recovery.authorData.hiddenActions.selectCommander, "authoring recovery restored")

print("Controller UI authoring tests passed: migration, precedence/enforcement, hint modes/categories, long-label previews, undo/redo, recovery, action audit, hold repeat, stress bounds.")
