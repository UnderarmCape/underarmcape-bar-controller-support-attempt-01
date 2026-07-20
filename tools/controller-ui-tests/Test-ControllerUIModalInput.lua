local root = (arg and arg[1]) or "."

local function assertTrue(value, label)
	if not value then error(label .. ": expected true", 2) end
end

local function assertEqual(actual, expected, label)
	if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function readFile(path)
	local file = assert(io.open(path, "rb")); local value = file:read("*a"); file:close(); return value
end

local Input = dofile(root .. "/luaui/Include/controller_ui_editor_input.lua")
local input = Input.New()
assertTrue(Input.Open(input), "input opens")
assertTrue(Input.Press(input, 1, 10, 20), "press owned")
assertTrue(Input.Capture(input, "slider", { id = "scale" }, 1, 10, 20) ~= nil, "slider captured")
assertEqual(Input.Move(input, 40, 50).kind, "slider", "move remains with captured slider")
assertTrue(Input.Release(input, 1) ~= false, "release owned")
assertTrue(Input.Pointer(input) == nil, "capture clears on release")
Input.Capture(input, "divider", {}, 1, 0, 0); Input.LostFocus(input)
assertTrue(Input.Pointer(input) == nil, "focus loss clears capture")
Input.Close(input); assertTrue(not input.open, "input closes")

local texts, mouseX, mouseY = {}, 0, 0
local sdlStarts, sdlStops = 0, 0
widget, WG = {}, {}
GL = { LINE_LOOP = 1, LINES = 2, TRIANGLE_FAN = 3 }
gl = setmetatable({
	Color = function() end, Rect = function() end, Scissor = function() end, Texture = function() end,
	TexRect = function() end, Vertex = function() end, LineWidth = function() end,
	Text = function(value) texts[#texts + 1] = tostring(value) end,
	GetTextWidth = function(value) return #tostring(value) * 0.55 end,
	BeginEnd = function(_, callback) callback() end,
}, { __index = function() return function() end end })
Spring = {
	GetViewGeometry = function() return 1280, 720 end,
	GetMouseState = function() return mouseX, mouseY, false, false, false, false end,
	GetModKeyState = function() return false, false, false, false end,
	GetKeyState = function() return false end,
	GetGameFrame = function() return 1 end, GetGameSeconds = function() return 1 end,
	CreateDir = function() end, Echo = function() end,
	SDLStartTextInput = function() sdlStarts = sdlStarts + 1 end,
	SDLStopTextInput = function() sdlStops = sdlStops + 1 end,
	SetClipboard = function() end, GetClipboard = function() return "" end,
}
widgetHandler = {
	textOwner = nil, mouseOwner = nil,
	AddAction = function() end, RemoveAction = function() end,
	RaiseWidget = function() end,
}
KEYSYMS = { BACKSPACE = 8, TAB = 9, RETURN = 13, ESCAPE = 27, SPACE = 32, DELETE = 127,
	UP = 273, DOWN = 274, RIGHT = 275, LEFT = 276, HOME = 278, END = 279, PAGEUP = 280, PAGEDOWN = 281, F1 = 282 }
Json = dofile(root .. "/common/luaUtilities/json.lua")
VFS = {
	RAW_FIRST = 1,
	Include = function(path)
		local include = {
			["LuaUI/Include/controller_ui_editor_workspace.lua"] = "/luaui/Include/controller_ui_editor_workspace.lua",
			["LuaUI/Include/controller_ui_editor_input.lua"] = "/luaui/Include/controller_ui_editor_input.lua",
			["LuaUI/Include/controller_ui_shared_renderers.lua"] = "/luaui/Include/controller_ui_shared_renderers.lua",
			["LuaUI/Include/controller_glyphs.lua"] = "/luaui/Include/controller_glyphs.lua",
		}
		return include[path] and dofile(root .. include[path]) or nil
	end,
	LoadFile = function(path)
		if path == "controller-ui/shipping-defaults.json" then return readFile(root .. "/controller-ui/shipping-defaults.json") end
		return nil
	end,
}
WG.BARControllerSupport = {
	GetBinding = function() return "A" end, GetBindingRevision = function() return 1 end,
	GetBindingDefinitions = function() return {} end, GetShortcutBinding = function() return nil end,
	GetContextSnapshot = function() return {} end, GetBackStartHoldProgress = function() return 0 end,
	IsInputPressed = function() return false end, SetLayoutEditorOpen = function() end,
}

dofile(root .. "/luaui/Widgets/gui_controller_ui_layout.lua")
widget:Initialize()
local api = assert(WG.ControllerUISettings)
api.OpenEditor()
assertTrue(widgetHandler.textOwner == widget, "BAR text ownership claimed")
assertTrue(sdlStarts > 0, "SDL text input started")
assertTrue(widget:IsAbove(0, 0), "full viewport reports UI above world")

assertTrue(widget:MousePress(10, 10, 3), "right click outside consumed")
assertTrue(widget:MouseRelease(10, 10, 3), "right release consumed")
assertTrue(widget:MousePress(10, 10, 1), "left click outside consumed")
assertTrue(widget:MouseRelease(10, 10, 1), "left release consumed")
mouseX, mouseY = 10, 10
assertTrue(widget:MouseWheel(true, 1), "wheel outside consumed")
assertTrue(widget:KeyPress(KEYSYMS.TAB, {}, false, "tab"), "keyboard event consumed")
assertTrue(widget:KeyRelease(KEYSYMS.TAB), "keyboard release consumed")

texts = {}; widget:DrawScreen()
local beforeEnabled = api.Get("global", "enabled")
assertTrue(widget:MousePress(1080, 430, 1), "toggle press consumed")
widget:MouseRelease(1080, 430, 1)
assertTrue(api.Get("global", "enabled") ~= beforeEnabled, "real toggle changes selected property")

assertTrue(widget:MousePress(1180, 325, 1), "numeric field press consumed")
widget:MouseRelease(1180, 325, 1)
widget:KeyPress(65, { ctrl = true }, false, "a")
widget:TextInput("1.25")
widget:KeyPress(KEYSYMS.RETURN, {}, false, "return")
assertEqual(api.Get("global", "scale"), 1.25, "direct numeric entry applies")

local beforeSlider = api.Get("global", "scale")
widget:MousePress(1000, 325, 1); widget:MouseMove(1100, 325); widget:MouseRelease(1100, 325, 1)
assertTrue(api.Get("global", "scale") ~= beforeSlider, "slider drag applies")
local beforeWheel = api.Get("global", "scale"); mouseX, mouseY = 1000, 325; widget:MouseWheel(true, 1)
assertTrue(api.Get("global", "scale") ~= beforeWheel, "numeric wheel applies")
local beforeArrow = api.Get("global", "scale"); widget:KeyPress(KEYSYMS.RIGHT, {}, false, "right"); widget:KeyRelease(KEYSYMS.RIGHT)
assertTrue(api.Get("global", "scale") ~= beforeArrow, "arrow adjustment applies")

texts = {}; widget:DrawScreen(); widget:MousePress(800, 580, 1); widget:MouseRelease(800, 580, 1)
texts = {}; widget:DrawScreen(); local menuLabels = {}
for _, value in ipairs(texts) do menuLabels[value] = true end
assertTrue(menuLabels.GAMEPLAY and menuLabels.BUILDING and menuLabels["STRESS TESTS"], "preview menu is categorized")
assertTrue(widget:KeyPress(KEYSYMS.ESCAPE, {}, false, "escape"), "preview menu closes from keyboard")

texts = {}; widget:DrawScreen(); widget:MousePress(1220, 580, 1); widget:MouseRelease(1220, 580, 1)
texts = {}; widget:DrawScreen(); local debugOn = false
for _, value in ipairs(texts) do if value == "Debug ON" then debugOn = true end end
assertTrue(debugOn, "debug toggle becomes visible only after click")

texts = {}; widget:DrawScreen()
local hintBounds = api.GetComponentBounds("hints", 570, 150)
local hintXBefore = api.Get("hints", "x")
local hintCenterX, hintCenterY = (hintBounds.x1 + hintBounds.x2) * 0.5, (hintBounds.y1 + hintBounds.y2) * 0.5
assertTrue(widget:MousePress(hintCenterX, hintCenterY, 1), "live component drag press consumed")
widget:MouseMove(hintCenterX + 80, hintCenterY + 40)
widget:MouseRelease(hintCenterX + 80, hintCenterY + 40, 1)
assertTrue(api.Get("hints", "x") ~= hintXBefore, "live component drag changes real selected component")
api.Undo()
assertEqual(api.Get("hints", "x"), hintXBefore, "live component drag remains a mod UI authoring change")

local resizeConfig = widget:GetConfigData()
resizeConfig.editorChrome.selectedComponent = "selectedStatus"
widget:SetConfigData(resizeConfig)
api.Set("selectedStatus", "x", 0.16); api.Set("selectedStatus", "y", 0.18)
texts = {}; widget:DrawScreen()
local selectedBounds = api.GetComponentBounds("selectedStatus", 294, 104)
local selectedWidthBefore = api.Get("selectedStatus", "width")
local resizeX, resizeY = selectedBounds.x2 - 2, selectedBounds.y2 - 2
assertTrue(widget:MousePress(resizeX, resizeY, 1), "live component resize press consumed")
widget:MouseMove(resizeX + 45, resizeY + 30)
widget:MouseRelease(resizeX + 45, resizeY + 30, 1)
assertTrue(api.Get("selectedStatus", "width") ~= selectedWidthBefore, "live component resize changes real selected component")
api.Undo()
assertEqual(api.Get("selectedStatus", "width"), selectedWidthBefore, "live component resize is one authoring history entry")

local chromeBefore = widget:GetConfigData().editorChrome.window
api.Set("hints", "scale", 1.5)
texts = {}; widget:DrawScreen()
widget:MousePress(700, 620, 1); widget:MouseMove(650, 600); widget:MouseRelease(650, 600, 1)
texts = {}; widget:DrawScreen()
widget:MousePress(1195, 95, 1); widget:MouseMove(1195, 120); widget:MouseRelease(1195, 120, 1)
local chromeAfter = widget:GetConfigData().editorChrome.window
assertTrue(chromeAfter.x ~= chromeBefore.x and chromeAfter.height ~= chromeBefore.height, "editor movement and resizing update chrome")
api.Undo()
assertTrue(api.Get("hints", "scale") ~= 1.5, "undo skips editor window movement")
local chromeAfterUndo = widget:GetConfigData().editorChrome.window
assertEqual(chromeAfterUndo.x, chromeAfter.x, "undo preserves editor window position")
assertEqual(chromeAfterUndo.height, chromeAfter.height, "undo preserves editor window size")

api.CloseEditor(); assertTrue(not widget:IsAbove(0, 0), "world ownership restored after close")
assertTrue(widgetHandler.textOwner ~= widget, "BAR text ownership released")
assertTrue(sdlStops > 0, "SDL text input stopped")
api.OpenEditor(); texts = {}; widget:DrawScreen(); debugOn = false
for _, value in ipairs(texts) do if value == "Debug ON" then debugOn = true end end
assertTrue(not debugOn, "debug hidden on reopen")
api.CloseEditor(); widget:Shutdown()

print("Controller UI modal input tests passed: full-screen mouse and wheel shield, BAR text ownership, capture lifecycle, live component drag/resize, real controls, numeric typing/drag/wheel/arrow input, categorized preview menu, chrome-only move/resize, and hidden debug state.")
