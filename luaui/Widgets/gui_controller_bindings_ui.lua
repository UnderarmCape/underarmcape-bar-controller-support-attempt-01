--------------------------------------------------------------------------------
-- BAR Xbox Controller Support - Binding editor pre-alpha
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Controller Bindings UI",
		desc = "Pre-alpha Xbox controller binding editor for BAR Controller Support",
		author = "Kailil / Codex",
		date = "2026-05-29",
		license = "GNU GPL, v2 or later",
		layer = 1000000,
		enabled = true,
	}
end

local spGetViewGeometry = Spring.GetViewGeometry
local spGetGameSeconds = Spring.GetGameSeconds
local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local GL_LINE_LOOP = GL.LINE_LOOP
local ControllerBindingsUIGlyphs = VFS.Include("luaui/Include/controller_glyphs.lua")

local USE_SAFE_AREA_LAYOUT = true
local SAFE_MAX_X_MARGIN = 120
local SAFE_MAX_Y_MARGIN = 300
local SAFE_X_MARGIN_RATIO = 0.06
local SAFE_Y_MARGIN_RATIO = 0.18

local TOGGLE_BUTTON_WIDTH = 110
local TOGGLE_BUTTON_HEIGHT = 28
local TOGGLE_BUTTON_RIGHT_OFFSET = 560
local TOGGLE_BUTTON_TOP_OFFSET = 8

local ControllerBindingsUILayoutDefaults = {
	useSafeArea = true,
	maxXMargin = 600,
	maxYMargin = 300,
	xMarginRatio = 0.15,
	yMarginRatio = 0.10,
	toggleButtonVisible = true,
	toggleButtonRightOffset = 560,
	toggleButtonTopOffset = 8,
}

local ControllerBindingsUILayoutSettings = {}
for k, v in pairs(ControllerBindingsUILayoutDefaults) do
	ControllerBindingsUILayoutSettings[k] = v
end

local ControllerBindingsUILauncherBounds = nil
local ControllerBindingsUILayoutGetSetting
local ControllerBindingsUILegacyMigrationAttempted = false

local function ControllerBindingsUIGetLauncherBounds(vsx, vsy)
	local shared = WG and WG.ControllerUISettings
	if shared and type(shared.GetComponent) == "function" and type(shared.GetComponentBounds) == "function" then
		local component = shared.GetComponent("bindingsButton")
		local global = type(shared.GetGlobal) == "function" and shared.GetGlobal() or nil
		if component and component.enabled ~= false and (not global or global.enabled ~= false) then
			return shared.GetComponentBounds("bindingsButton", TOGGLE_BUTTON_WIDTH, TOGGLE_BUTTON_HEIGHT), component, shared
		end
		return nil, component, shared
	end
	if not ControllerBindingsUILayoutGetSetting("toggleButtonVisible") then return nil end
	local x1 = vsx - ControllerBindingsUILayoutGetSetting("toggleButtonRightOffset")
	local y2 = vsy - ControllerBindingsUILayoutGetSetting("toggleButtonTopOffset")
	return { x1 = x1, y1 = y2 - TOGGLE_BUTTON_HEIGHT, x2 = x1 + TOGGLE_BUTTON_WIDTH, y2 = y2, scale = 1 }, nil, nil
end

local function ControllerBindingsUITryMigrateLauncher()
	if ControllerBindingsUILegacyMigrationAttempted then return end
	local shared = WG and WG.ControllerUISettings
	if shared and type(shared.MigrateLegacyBindingsButton) == "function" then
		shared.MigrateLegacyBindingsButton(
			ControllerBindingsUILayoutGetSetting("toggleButtonRightOffset"),
			ControllerBindingsUILayoutGetSetting("toggleButtonTopOffset")
		)
		ControllerBindingsUILegacyMigrationAttempted = true
	end
end

local function ControllerBindingsUILayoutClampSetting(key, value)
	if key == "useSafeArea" or key == "toggleButtonVisible" then
		if type(value) == "boolean" then
			return value
		end
		return value == 1 or value == "true" or value == true
	elseif key == "maxXMargin" then
		local num = tonumber(value) or 600
		return math.max(0, math.min(600, math.floor(num)))
	elseif key == "maxYMargin" then
		local num = tonumber(value) or 300
		return math.max(0, math.min(600, math.floor(num)))
	elseif key == "xMarginRatio" then
		local num = tonumber(value) or 0.15
		return math.max(0.00, math.min(0.30, num))
	elseif key == "yMarginRatio" then
		local num = tonumber(value) or 0.10
		return math.max(0.00, math.min(0.30, num))
	elseif key == "toggleButtonRightOffset" then
		local num = tonumber(value) or 560
		return math.max(200, math.min(1000, math.floor(num)))
	elseif key == "toggleButtonTopOffset" then
		local num = tonumber(value) or 8
		return math.max(0, math.min(120, math.floor(num)))
	end
	return value
end

local function ControllerBindingsUILayoutResetAll()
	for k, v in pairs(ControllerBindingsUILayoutDefaults) do
		ControllerBindingsUILayoutSettings[k] = v
	end
end

local function ControllerBindingsUILayoutResetSetting(key)
	if ControllerBindingsUILayoutDefaults[key] ~= nil then
		ControllerBindingsUILayoutSettings[key] = ControllerBindingsUILayoutDefaults[key]
	end
end

ControllerBindingsUILayoutGetSetting = function(key)
	local val = ControllerBindingsUILayoutSettings[key]
	if val == nil then
		return ControllerBindingsUILayoutDefaults[key]
	end
	return val
end

local function ControllerBindingsUILayoutSetSetting(key, value)
	ControllerBindingsUILayoutSettings[key] = ControllerBindingsUILayoutClampSetting(key, value)
end

local ControllerBindingsUI = {
	open = false,
	categoryIndex = 1,
	actionIndex = 1,
	categories = {},
	missing = {},
	toast = "Closed",
	modal = nil,
	captureAction = nil,
	captureStartTime = 0,
	captureGateReleased = false,
	pendingInput = nil,
	conflictAction = nil,
	layout = {
		tabs = {},
		rows = {},
		close = nil,
		modalButtons = {},
		modeTabs = {},
	},
	mode = "bindings",
	settingsList = {},
	settingsPages = { "Camera", "Input", "Radials", "Selection", "Placement", "Hints", "UI" },
	settingsPageIndex = 1,
	settingsItemIndex = 1,
	currentPreset = "Build-First Commander",
	pendingPresetName = nil,
}

local ControllerBindingsUIRequiredAPI = {
	"GetBindingDefinitions",
	"GetBinding",
	"SetBinding",
	"ResetBinding",
	"ResetAllBindings",
	"GetPressedBindingInput",
	"IsInputPressed",
	"IsInputDown",
	"SetBindingUIOpen",
	"IsBindingUIOpen",
}

local ControllerBindingsUIGroupOrder = {
	["Core"] = 1,
	["Camera"] = 2,
	["Build"] = 3,
	["Placement"] = 4,
	["Tactical"] = 5,
	["Queue"] = 6,
	["Idle / Groups"] = 7,
	["Advanced"] = 8,
}

local ControllerBindingsUIReadOnlyCameraDefs = {
	{
		action = "cameraPan",
		label = "Camera Pan",
		default = "Left Stick",
		group = "Camera",
		readOnly = true,
		description = "Fixed camera pan axis. This is shown for layout preview and is not remappable through the current gameplay API.",
	},
	{
		action = "cameraRotate",
		label = "Rotate Camera",
		default = "Right Stick X",
		group = "Camera",
		readOnly = true,
		description = "Fixed camera rotation axis. This is shown for layout preview and is not remappable through the current gameplay API.",
	},
	{
		action = "cameraZoom",
		label = "Zoom Camera",
		default = "Right Stick Y",
		group = "Camera",
		readOnly = true,
		description = "Fixed camera zoom axis. This is shown for layout preview and is not remappable through the current gameplay API.",
	},
}

local ControllerBindingsUIDescriptions = {
	select = "Select hovered units, confirm radial choices, and accept primary UI actions.",
	cancel = "Cancel current modes, close menus, or clear selection in normal play.",
	smartAction = "Context-sensitive action. Tap for smart action, hold for path or line behavior.",
	buildRadial = "Open constructor build options or factory radial controls.",
	commandLayer = "Hold Back/View to open the tactical command layer for guard, attack, stop, tactical radial, and selection cycling commands.",
	insertNextCommandModifier = "Hold to insert the next compatible order at the front of the selected unit's queue without clearing the rest.",
	appendQueueModifier = "Hold to append commands and build placements to the end of the queue, like Shift. This does not interrupt the current build.",
	controlGroupModifier = "Hold Start/Menu to use the controller group layer with D-pad and L3 inputs.",
	pitchModifier = "Hold LB to access camera pitch / tilt behavior.",
	removeQueuedCommand = "Removes the selected unit's current or next queued command. LT is reserved for camera speed only.",
	removeLastQueuedCommand = "Removes the selected unit's final queued command. LT is reserved for camera speed only.",
	radialSelect = "Select the highlighted radial item.",
	radialCancel = "Cancel or close the current radial.",
	radialQuick = "Quick-place a radial item when supported.",
	radialClose = "Close the current radial.",
	radialPrevPage = "Move to the previous radial page or category.",
	radialNextPage = "Move to the next radial page or category.",
	place = "Place the current building and exit placement when appropriate.",
	placeStay = "Place the current building and keep placement active when supported.",
	cancelPlacement = "Cancel current build placement.",
	rotateBuildingLeft = "Rotate building facing left.",
	rotateBuildingRight = "Rotate building facing right.",
	spacingUp = "Increase build spacing during placement.",
	spacingDown = "Decrease build spacing during placement.",
	patternPrev = "Tap to cycle placement pattern. Hold to force Grid placement.",
	patternNext = "Reserved. Placement pattern cycling is disabled so RB stays free for preset duties.",
	tacticalSelect = "Confirm highlighted tactical radial command.",
	tacticalCancel = "Cancel the tactical radial.",
	tacticalClose = "Close the tactical radial.",
	commandUp = "RT layer D-pad Up command slot.",
	commandDown = "RT layer D-pad Down command slot.",
	commandLeft = "RT layer previous command or selection cycle.",
	commandRight = "RT layer next command or selection cycle.",
	idlePrev = "Cycle to the previous idle unit.",
	idleNext = "Cycle to the next idle unit.",
	groupSlotUp = "Move to the next controller control-group slot while Start/Menu is held.",
	groupSlotDown = "Move to the previous controller control-group slot while Start/Menu is held.",
	groupRecallOrAssign = "Recall the active controller group slot while Start/Menu is held.",
	groupAssign = "Assign all units of the selected same type, plus future units of that type when available, to the active group slot while Start/Menu is held.",
	groupClear = "Clear the active controller control-group slot with Start/Menu + L3.",
}

local ControllerBindingsUILabelOverrides = {
	pitchModifier = "Camera Pitch Modifier",
}

local ControllerBindingsUIBindingLabels = {
	A = "A",
	B = "B",
	X = "X",
	Y = "Y",
	LB = "LB",
	RB = "RB",
	LT = "LT",
	RT = "RT",
	back = "Back/View",
	start = "Menu/Start",
	dpadUp = "D-pad Up",
	dpadDown = "D-pad Down",
	dpadLeft = "D-pad Left",
	dpadRight = "D-pad Right",
	leftStickClick = "Left Stick Click",
	rightStickClick = "Right Stick Click",
	none = "Unbound",
}

local ControllerBindingsUIControlIdMap = {
	a = "a",
	b = "b",
	x = "x",
	y = "y",
	lb = "lb",
	rb = "rb",
	lt = "lt",
	rt = "rt",
	back = "backView",
	backview = "backView",
	view = "backView",
	start = "menuStart",
	menu = "menuStart",
	menustart = "menuStart",
	startmenu = "menuStart",
	leftstick = "leftStick",
	leftstickx = "leftStickX",
	leftsticky = "leftStickY",
	leftstickclick = "leftStick",
	rightstick = "rightStick",
	rightstickx = "rightStickX",
	rightsticky = "rightStickY",
	rightstickclick = "rightStick",
	dpadup = "dpadUp",
	dpaddown = "dpadDown",
	dpadleft = "dpadLeft",
	dpadright = "dpadRight",
}

local ControllerBindingsUICaptureInputs = {
	"A", "B", "X", "Y", "back", "start", "LB", "RB",
	"dpadUp", "dpadDown", "dpadLeft", "dpadRight", "LT", "RT",
	"leftStickClick", "rightStickClick",
}

local function ControllerBindingsUISupport()
	return WG and WG.BARControllerSupport
end

local function ControllerBindingsUISafeCall(name, ...)
	local support = ControllerBindingsUISupport()
	local fn = support and support[name]
	if type(fn) ~= "function" then
		return false, nil
	end
	return pcall(fn, ...)
end

local ControllerBindingsUILayoutDefinitionsList = {
	{
		key = "bindingsUILayout.useSafeArea",
		label = "Bindings UI safe area",
		type = "boolean",
		default = true,
		value = true,
		min = 0,
		max = 1,
		step = 1,
		group = "UI",
		source = "bindingsUI",
		description = "Keeps the bindings editor inside a centered safe window instead of fullscreen.",
	},
	{
		key = "bindingsUILayout.maxXMargin",
		label = "Bindings UI max horizontal margin",
		type = "integer",
		min = 0,
		max = 600,
		step = 10,
		default = 600,
		value = 600,
		decimals = 0,
		group = "UI",
		source = "bindingsUI",
		description = "Maximum left/right safe margin in pixels.",
	},
	{
		key = "bindingsUILayout.maxYMargin",
		label = "Bindings UI max vertical margin",
		type = "integer",
		min = 0,
		max = 600,
		step = 10,
		default = 300,
		value = 300,
		decimals = 0,
		group = "UI",
		source = "bindingsUI",
		description = "Maximum top/bottom safe margin in pixels.",
	},
	{
		key = "bindingsUILayout.xMarginRatio",
		label = "Bindings UI horizontal margin ratio",
		type = "number",
		min = 0.00,
		max = 0.30,
		step = 0.01,
		default = 0.15,
		value = 0.15,
		decimals = 2,
		group = "UI",
		source = "bindingsUI",
		description = "Screen-width ratio used for left/right safe margins before max clamp.",
	},
	{
		key = "bindingsUILayout.yMarginRatio",
		label = "Bindings UI vertical margin ratio",
		type = "number",
		min = 0.00,
		max = 0.30,
		step = 0.01,
		default = 0.10,
		value = 0.10,
		decimals = 2,
		group = "UI",
		source = "bindingsUI",
		description = "Screen-height ratio used for top/bottom safe margins before max clamp.",
	},
	{
		key = "bindingsUILayout.toggleButtonVisible",
		label = "Bindings button visible",
		type = "boolean",
		default = true,
		value = true,
		min = 0,
		max = 1,
		step = 1,
		group = "UI",
		source = "bindingsUI",
		description = "Shows the top Bindings button used to open this editor with the mouse.",
	},
	{
		key = "bindingsUILayout.toggleButtonRightOffset",
		label = "Bindings button right offset",
		type = "integer",
		min = 200,
		max = 1000,
		step = 10,
		default = 560,
		value = 560,
		decimals = 0,
		group = "UI",
		source = "bindingsUI",
		description = "Moves the top Bindings button left/right relative to the right edge.",
	},
	{
		key = "bindingsUILayout.toggleButtonTopOffset",
		label = "Bindings button top offset",
		type = "integer",
		min = 0,
		max = 120,
		step = 2,
		default = 8,
		value = 8,
		decimals = 0,
		group = "UI",
		source = "bindingsUI",
		description = "Moves the top Bindings button downward from the top edge.",
	},
	{
		key = "bindingsUILayout.resetLayout",
		label = "Reset Bindings UI layout",
		type = "action",
		default = "Reset",
		value = "Reset",
		min = 0,
		max = 0,
		step = 0,
		decimals = 0,
		group = "UI",
		source = "bindingsUI",
		description = "Restores only the Bindings UI layout settings to default values.",
	},
}

local ControllerBindingsUIHintDefinitionsList = {
	{ key = "scale", label = "Hint Overall Scale", type = "number", min = 0.75, max = 2.50,
		step = 0.05, default = 1.25, value = 1.25, decimals = 2, group = "Hints", source = "controllerUI",
		description = "Scales the complete controller hint presentation." },
	{ key = "fontScale", label = "Hint Text Scale", type = "number", min = 0.75, max = 2.00,
		step = 0.05, default = 1.15, value = 1.15, decimals = 2, group = "Hints", source = "controllerUI",
		description = "Scales action text without changing button glyph size." },
	{ key = "iconScale", label = "Hint Glyph Scale", type = "number", min = 0.75, max = 2.00,
		step = 0.05, default = 1.25, value = 1.25, decimals = 2, group = "Hints", source = "controllerUI",
		description = "Scales Xbox, PlayStation, and fallback input glyphs without changing action text." },
	{ key = "spacingScale", label = "Hint Spacing", type = "number", min = 0.75, max = 1.75,
		step = 0.05, default = 1.10, value = 1.10, decimals = 2, group = "Hints", source = "controllerUI",
		description = "Adjusts row, column, padding, and glyph-to-text spacing from compact to wide." },
	{ key = "resetHintAppearance", label = "Reset Hint Appearance", type = "action",
		default = "Reset", value = "Reset", min = 0, max = 0, step = 0, decimals = 0,
		group = "Hints", source = "controllerUI",
		description = "Restores the readable experimental shipped hint defaults." },
}

local malformedLogged = {}
local function ControllerBindingsUIIsRowMalformed(item)
	if not item or type(item) ~= "table" or not item.key or not item.label or not item.type then
		local itemStr = tostring(item)
		if type(item) == "table" then
			itemStr = "table: " .. tostring(item.key or "nil") .. ", " .. tostring(item.label or "nil")
		end
		if not malformedLogged[itemStr] then
			if Spring and Spring.Echo then
				Spring.Echo("[Controller Bindings UI] Malformed setting row ignored: " .. itemStr)
			end
			malformedLogged[itemStr] = true
		end
		return true
	end
	return false
end

local function ControllerBindingsUIGetSettingValue(item)
	if not item or ControllerBindingsUIIsRowMalformed(item) then return nil end
	if item.source == "controllerUI" then
		if item.type == "action" then return nil end
		local shared = WG and WG.ControllerUISettings
		return shared and type(shared.Get) == "function" and shared.Get("hints", item.key) or item.value
	elseif item.source == "bindingsUI" then
		if item.type == "action" then
			return nil
		end
		local key = item.key
		if string.sub(key, 1, 17) == "bindingsUILayout." then
			key = string.sub(key, 18)
		end
		return ControllerBindingsUILayoutGetSetting(key)
	else
		local ok, val = ControllerBindingsUISafeCall("GetSetting", item.key)
		if ok and val ~= nil then
			return val
		end
		return item.value
	end
end

local function ControllerBindingsUISetSettingValue(item, value)
	if not item or ControllerBindingsUIIsRowMalformed(item) then return end
	if item.source == "controllerUI" then
		local shared = WG and WG.ControllerUISettings
		if not shared then return end
		if item.type == "action" and type(shared.ResetHintAppearance) == "function" then
			shared.ResetHintAppearance()
			ControllerBindingsUISetToast("Hint appearance reset")
		elseif type(shared.SetHintAppearance) == "function" then
			shared.SetHintAppearance(item.key, value)
		end
	elseif item.source == "bindingsUI" then
		if item.type == "action" then
			if item.key == "bindingsUILayout.resetLayout" then
				ControllerBindingsUILayoutResetAll()
				ControllerBindingsUISetToast("Layout settings reset")
			end
		else
			local key = item.key
			if string.sub(key, 1, 17) == "bindingsUILayout." then
				key = string.sub(key, 18)
			end
			ControllerBindingsUILayoutSetSetting(key, value)
		end
	else
		ControllerBindingsUISafeCall("SetSetting", item.key, value)
	end
end

local function ControllerBindingsUIResetSettingValue(item)
	if not item or type(item) ~= "table" or ControllerBindingsUIIsRowMalformed(item) then return end
	if item.source == "controllerUI" then
		local shared = WG and WG.ControllerUISettings
		if shared and type(shared.ResetHintAppearance) == "function" then
			shared.ResetHintAppearance(item.type == "action" and nil or item.key)
			ControllerBindingsUISetToast(item.type == "action" and "Hint appearance reset" or ("Reset " .. item.label))
		end
	elseif item.source == "bindingsUI" then
		if item.type == "action" then
			if item.key == "bindingsUILayout.resetLayout" then
				ControllerBindingsUILayoutResetAll()
				ControllerBindingsUISetToast("Layout settings reset")
			end
		else
			local key = item.key
			if string.sub(key, 1, 17) == "bindingsUILayout." then
				key = string.sub(key, 18)
			end
			ControllerBindingsUILayoutResetSetting(key)
			ControllerBindingsUISetToast("Reset " .. item.label)
		end
	else
		ControllerBindingsUISafeCall("ResetSetting", item.key)
		ControllerBindingsUISetToast("Reset " .. item.label)
	end
end

local function ControllerBindingsUIRefreshMissingAPI()
	local missing = {}
	local support = ControllerBindingsUISupport()
	if type(support) ~= "table" then
		for i = 1, #ControllerBindingsUIRequiredAPI do
			missing[#missing + 1] = ControllerBindingsUIRequiredAPI[i]
		end
	else
		for i = 1, #ControllerBindingsUIRequiredAPI do
			local name = ControllerBindingsUIRequiredAPI[i]
			if type(support[name]) ~= "function" then
				missing[#missing + 1] = name
			end
		end
	end
	ControllerBindingsUI.missing = missing
	return #missing == 0
end

local function ControllerBindingsUISetGameplayBlocked(blocked)
	ControllerBindingsUISafeCall("SetBindingUIOpen", blocked == true)
end

local function ControllerBindingsUIDisplayBinding(binding)
	if binding == nil or binding == "" then
		return "Unbound"
	end
	return ControllerBindingsUIBindingLabels[binding] or tostring(binding)
end

local function ControllerBindingsUINormalizeBindingName(binding)
	local text = string.lower(tostring(binding or ""))
	text = string.gsub(text, "[%s%-%_/]", "")
	return text
end

function ControllerBindingsUIBindingToControlId(bindingName)
	return ControllerBindingsUIControlIdMap[ControllerBindingsUINormalizeBindingName(bindingName)]
end

local function ControllerBindingsUIBindingToControlIds(bindingName)
	local ids = {}
	local text = tostring(bindingName or "")
	for part in string.gmatch(text, "[^+]+") do
		local controlId = ControllerBindingsUIBindingToControlId(part)
		if controlId then
			ids[controlId] = true
			if controlId == "leftStickX" or controlId == "leftStickY" then
				ids.leftStick = true
			elseif controlId == "rightStickX" or controlId == "rightStickY" then
				ids.rightStick = true
			end
		end
	end
	return ids
end

local function ControllerBindingsUIDisplayGroup(def)
	if def.action == "pitchModifier" then
		return "Camera"
	elseif def.action == "commandLayer" then
		return "Tactical"
	elseif def.action == "insertNextCommandModifier" then
		return "Queue"
	elseif def.action == "appendQueueModifier" then
		return "Queue"
	elseif def.action == "controlGroupModifier" then
		return "Idle / Groups"
	elseif def.group == "Radials" then
		return "Build"
	end
	return def.group or "Advanced"
end

local function ControllerBindingsUIDisplayLabel(def)
	return ControllerBindingsUILabelOverrides[def.action] or def.label or def.action or "Unknown"
end

local function ControllerBindingsUIAddAction(groupsByName, def)
	local groupName = ControllerBindingsUIDisplayGroup(def)
	local group = groupsByName[groupName]
	if not group then
		group = { name = groupName, actions = {} }
		groupsByName[groupName] = group
	end
	group.actions[#group.actions + 1] = {
		action = def.action,
		label = ControllerBindingsUIDisplayLabel(def),
		default = def.default,
		group = groupName,
		sourceGroup = def.group,
		readOnly = def.readOnly == true,
		description = def.description or ControllerBindingsUIDescriptions[def.action] or "No help text yet.",
	}
end

local function ControllerBindingsUIRebuildSettings()
	local ok, defs = ControllerBindingsUISafeCall("GetSettingsDefinitions")
	local newList = {}
	if ok and type(defs) == "table" then
		for i = 1, #defs do
			local def = defs[i]
			if not ControllerBindingsUIIsRowMalformed(def) then
				newList[#newList + 1] = def
			end
		end
	end
	for i = 1, #ControllerBindingsUILayoutDefinitionsList do
		newList[#newList + 1] = ControllerBindingsUILayoutDefinitionsList[i]
	end
	for i = 1, #ControllerBindingsUIHintDefinitionsList do
		newList[#newList + 1] = ControllerBindingsUIHintDefinitionsList[i]
	end
	ControllerBindingsUI.settingsList = newList
end

local function ControllerBindingsUISelectedSetting()
	local pageName = ControllerBindingsUI.settingsPages[ControllerBindingsUI.settingsPageIndex]
	if not pageName then return nil end
	local items = {}
	for i = 1, #ControllerBindingsUI.settingsList do
		local def = ControllerBindingsUI.settingsList[i]
		if def.group == pageName and not ControllerBindingsUIIsRowMalformed(def) then
			table.insert(items, def)
		end
	end
	return items[ControllerBindingsUI.settingsItemIndex]
end

local function ControllerBindingsUIAdjustSelectedSetting(delta, fast)
	local item = ControllerBindingsUISelectedSetting()
	if not item or ControllerBindingsUIIsRowMalformed(item) then return end

	local current = ControllerBindingsUIGetSettingValue(item)

	if item.type == "boolean" then
		if delta ~= 0 then
			ControllerBindingsUISetSettingValue(item, not current)
		end
	elseif item.type == "action" then
		ControllerBindingsUISetSettingValue(item, nil)
	else
		local step = item.step or 1
		if fast then
			step = step * 4
		end
		local newVal = (tonumber(current) or 0) + step * delta
		ControllerBindingsUISetSettingValue(item, newVal)
	end
	ControllerBindingsUIRebuildSettings()
end

local function ControllerBindingsUIResetSelectedSetting()
	local item = ControllerBindingsUISelectedSetting()
	if not item or ControllerBindingsUIIsRowMalformed(item) then return end
	ControllerBindingsUIResetSettingValue(item)
	ControllerBindingsUIRebuildSettings()
end

local function ControllerBindingsUIResetAllSettings()
	ControllerBindingsUISafeCall("ResetAllSettings")
	ControllerBindingsUIRebuildSettings()
	ControllerBindingsUISetToast("All settings reset")
end

local function ControllerBindingsUIRebuildCategories()
	local groupsByName = {}
	for i = 1, #ControllerBindingsUIReadOnlyCameraDefs do
		ControllerBindingsUIAddAction(groupsByName, ControllerBindingsUIReadOnlyCameraDefs[i])
	end

	local ok, defs = ControllerBindingsUISafeCall("GetBindingDefinitions")
	if ok and type(defs) == "table" then
		for i = 1, #defs do
			if type(defs[i]) == "table" and defs[i].action then
				ControllerBindingsUIAddAction(groupsByName, defs[i])
			end
		end
	end

	local categories = {}
	for _, group in pairs(groupsByName) do
		categories[#categories + 1] = group
	end
	table.sort(categories, function(a, b)
		local orderA = ControllerBindingsUIGroupOrder[a.name] or 100
		local orderB = ControllerBindingsUIGroupOrder[b.name] or 100
		if orderA == orderB then
			return a.name < b.name
		end
		return orderA < orderB
	end)

	local presetsGroup = {
		name = "Presets",
		actions = {
			{
				action = "preset_buildfirst",
				label = "Build-First Commander",
				actionLabel = "Build-First Commander",
				default = "",
				group = "Presets",
				sourceGroup = "Presets",
				readOnly = true,
				description = "Base-building and constructor-heavy layout with build layer on RB.",
			},
		}
	}
	table.insert(categories, 1, presetsGroup)

	ControllerBindingsUI.categories = categories

	local totalLoaded = 0
	for _, cat in ipairs(categories) do
		totalLoaded = totalLoaded + #cat.actions
	end
	ControllerBindingsUI.totalBindingsCount = totalLoaded

	if ControllerBindingsUI.categoryIndex > #categories then
		ControllerBindingsUI.categoryIndex = math.max(1, #categories)
	end
	local category = categories[ControllerBindingsUI.categoryIndex]
	if category and ControllerBindingsUI.actionIndex > #category.actions then
		ControllerBindingsUI.actionIndex = math.max(1, #category.actions)
	end
end

local function ControllerBindingsUISelectedCategory()
	return ControllerBindingsUI.categories[ControllerBindingsUI.categoryIndex]
end

local function ControllerBindingsUISelectedAction()
	local category = ControllerBindingsUISelectedCategory()
	return category and category.actions[ControllerBindingsUI.actionIndex]
end

local function ControllerBindingsUIGetCurrentBinding(action)
	if not action then
		return nil
	end
	if action.readOnly then
		return action.default
	end
	local ok, binding = ControllerBindingsUISafeCall("GetBinding", action.action)
	if ok then
		return binding
	end
	return nil
end

local function ControllerBindingsUIFindConflict(inputName, targetActionName)
	for i = 1, #ControllerBindingsUI.categories do
		local category = ControllerBindingsUI.categories[i]
		for j = 1, #category.actions do
			local action = category.actions[j]
			if not action.readOnly and action.action ~= targetActionName then
				local binding = ControllerBindingsUIGetCurrentBinding(action)
				if binding == inputName then
					return action
				end
			end
		end
	end
	return nil
end

local function ControllerBindingsUISetToast(text)
	ControllerBindingsUI.toast = tostring(text or "")
end

local function ControllerBindingsUIConfirmApplyPreset()
	local presetName = ControllerBindingsUI.pendingPresetName
	if not presetName then
		ControllerBindingsUI.modal = nil
		return
	end

	local ok, applied = ControllerBindingsUISafeCall("ApplyBindingPreset", presetName)
	if not ok or applied ~= true then
		ControllerBindingsUI.modal = nil
		ControllerBindingsUI.pendingPresetName = nil
		ControllerBindingsUISetToast("Preset unavailable")
		return
	end
	ControllerBindingsUI.currentPreset = presetName
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.pendingPresetName = nil
	ControllerBindingsUISetToast("Applied preset: " .. presetName)
end

local function ControllerBindingsUIApplyBinding(action, inputName, allowDuplicate)
	if not action then
		return
	end
	if action.readOnly then
		ControllerBindingsUISetToast("Read-only camera axis")
		return
	end
	local conflict = (not allowDuplicate) and ControllerBindingsUIFindConflict(inputName, action.action) or nil
	if conflict then
		ControllerBindingsUI.modal = "conflict"
		ControllerBindingsUI.pendingInput = inputName
		ControllerBindingsUI.conflictAction = conflict
		ControllerBindingsUISetToast("Binding conflict")
		return
	end
	local ok = ControllerBindingsUISafeCall("SetBinding", action.action, inputName)
	if ok then
		ControllerBindingsUI.currentPreset = "Custom"
	end
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.captureAction = nil
	ControllerBindingsUI.pendingInput = nil
	ControllerBindingsUI.conflictAction = nil
	ControllerBindingsUISetToast(ok and ("Bound " .. action.label .. " to " .. ControllerBindingsUIDisplayBinding(inputName)) or "SetBinding failed")
end

local function ControllerBindingsUIOpen()
	ControllerBindingsUI.open = true
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.captureAction = nil
	ControllerBindingsUI.mode = "bindings"
	ControllerBindingsUI.settingsPageIndex = 1
	ControllerBindingsUI.settingsItemIndex = 1
	ControllerBindingsUISetGameplayBlocked(true)
	ControllerBindingsUIRefreshMissingAPI()
	ControllerBindingsUIRebuildCategories()
	ControllerBindingsUIRebuildSettings()
	ControllerBindingsUISetToast("Binding editor open")
end

local function ControllerBindingsUIClose()
	ControllerBindingsUI.open = false
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.captureAction = nil
	ControllerBindingsUI.pendingInput = nil
	ControllerBindingsUI.conflictAction = nil
	ControllerBindingsUISetGameplayBlocked(false)
	ControllerBindingsUISetToast("Closed")
end

local function ControllerBindingsUIToggle()
	if ControllerBindingsUI.open then
		ControllerBindingsUIClose()
	else
		ControllerBindingsUIOpen()
	end
end

local function ControllerBindingsUISelectCategory(index)
	local count = #ControllerBindingsUI.categories
	if count <= 0 then
		ControllerBindingsUI.categoryIndex = 1
		ControllerBindingsUI.actionIndex = 1
		return
	end
	ControllerBindingsUI.categoryIndex = ((index - 1) % count) + 1
	ControllerBindingsUI.actionIndex = 1
end

local function ControllerBindingsUISelectAction(index)
	local category = ControllerBindingsUISelectedCategory()
	local count = category and #category.actions or 0
	if count <= 0 then
		ControllerBindingsUI.actionIndex = 1
		return
	end
	ControllerBindingsUI.actionIndex = ((index - 1) % count) + 1
end

local function ControllerBindingsUIStartCapture()
	local category = ControllerBindingsUISelectedCategory()
	if category and category.name == "Presets" then
		local action = ControllerBindingsUISelectedAction()
		if action then
			ControllerBindingsUI.modal = "applyPreset"
			ControllerBindingsUI.pendingPresetName = action.label
			ControllerBindingsUISetToast("Confirm preset: " .. action.label)
		end
		return
	end
	local action = ControllerBindingsUISelectedAction()
	if not action then
		return
	end
	if action.readOnly then
		ControllerBindingsUISetToast("Read-only camera axis")
		return
	end
	ControllerBindingsUI.captureAction = action
	ControllerBindingsUI.captureStartTime = spGetGameSeconds and spGetGameSeconds() or os.clock()
	ControllerBindingsUI.captureGateReleased = false
	ControllerBindingsUI.modal = "capture"
	ControllerBindingsUISetToast("Listening for input")
end

local function ControllerBindingsUICancelModal()
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.captureAction = nil
	ControllerBindingsUI.pendingInput = nil
	ControllerBindingsUI.conflictAction = nil
	ControllerBindingsUISetToast("Cancelled")
end

local function ControllerBindingsUIResetSelected()
	local action = ControllerBindingsUISelectedAction()
	if not action or type(action) ~= "table" or not action.action then
		return
	end
	if action.group == "Presets" then
		ControllerBindingsUISetToast("Cannot reset a preset layout")
		return
	end
	if action.readOnly then
		ControllerBindingsUISetToast("Read-only camera axis")
		return
	end
	local ok = ControllerBindingsUISafeCall("ResetBinding", action.action)
	if ok then
		ControllerBindingsUI.currentPreset = "Custom"
	end
	ControllerBindingsUISetToast(ok and ("Reset " .. (action.label or action.action or "binding")) or "ResetBinding failed")
end

local function ControllerBindingsUIResetAll()
	ControllerBindingsUI.modal = "resetAll"
	ControllerBindingsUISetToast("Confirm reset all")
end

local function ControllerBindingsUIConfirmResetAll()
	local ok = ControllerBindingsUISafeCall("ResetAllBindings")
	if ok then
		ControllerBindingsUI.currentPreset = "Custom"
	end
	ControllerBindingsUI.modal = nil
	ControllerBindingsUISetToast(ok and "All bindings reset" or "ResetAllBindings failed")
end

local function ControllerBindingsUIIsPressed(inputName)
	local ok, pressed = ControllerBindingsUISafeCall("IsInputPressed", inputName)
	return ok and pressed == true
end

local function ControllerBindingsUIIsDown(inputName)
	local ok, down = ControllerBindingsUISafeCall("IsInputDown", inputName)
	return ok and down == true
end

local function ControllerBindingsUIAnyCaptureInputDown()
	for i = 1, #ControllerBindingsUICaptureInputs do
		if ControllerBindingsUIIsDown(ControllerBindingsUICaptureInputs[i]) then
			return true
		end
	end
	return false
end

local function ControllerBindingsUIHandleCaptureInput()
	if ControllerBindingsUIIsPressed("B") then
		ControllerBindingsUICancelModal()
		return true
	end

	local now = spGetGameSeconds and spGetGameSeconds() or os.clock()
	if not ControllerBindingsUI.captureGateReleased then
		if not ControllerBindingsUIAnyCaptureInputDown() and (now - ControllerBindingsUI.captureStartTime) >= 0.15 then
			ControllerBindingsUI.captureGateReleased = true
		end
		return true
	end

	local ok, inputName = ControllerBindingsUISafeCall("GetPressedBindingInput")
	if ok and inputName then
		ControllerBindingsUIApplyBinding(ControllerBindingsUI.captureAction, inputName, false)
	end
	return true
end

local function ControllerBindingsUIHandleConflictInput()
	if ControllerBindingsUIIsPressed("B") then
		ControllerBindingsUICancelModal()
	elseif ControllerBindingsUIIsPressed("X") then
		ControllerBindingsUIApplyBinding(ControllerBindingsUI.captureAction, ControllerBindingsUI.pendingInput, true)
	elseif ControllerBindingsUIIsPressed("A") then
		ControllerBindingsUISetToast("Replace unsupported by current API; use X to allow duplicate")
	end
	return true
end

local function ControllerBindingsUIHandleResetAllInput()
	if ControllerBindingsUIIsPressed("A") then
		if ControllerBindingsUI.mode == "settings" then
			ControllerBindingsUIResetAllSettings()
			ControllerBindingsUI.modal = nil
		else
			ControllerBindingsUIConfirmResetAll()
		end
	elseif ControllerBindingsUIIsPressed("B") then
		ControllerBindingsUICancelModal()
	end
	return true
end

local function ControllerBindingsUIHandleControllerInput()
	if not ControllerBindingsUI.open or #ControllerBindingsUI.missing > 0 then
		return false
	end
	if ControllerBindingsUI.modal == "capture" then
		return ControllerBindingsUIHandleCaptureInput()
	elseif ControllerBindingsUI.modal == "conflict" then
		return ControllerBindingsUIHandleConflictInput()
	elseif ControllerBindingsUI.modal == "resetAll" then
		return ControllerBindingsUIHandleResetAllInput()
	end

	if ControllerBindingsUIIsPressed("start") then
		if ControllerBindingsUI.mode == "settings" then
			ControllerBindingsUI.mode = "bindings"
			ControllerBindingsUISetToast("Switched to Bindings")
		else
			ControllerBindingsUI.mode = "settings"
			ControllerBindingsUIRebuildSettings()
			ControllerBindingsUISetToast("Switched to Settings")
		end
		return true
	end

	if ControllerBindingsUI.mode == "settings" then
		local items = {}
		local pageName = ControllerBindingsUI.settingsPages[ControllerBindingsUI.settingsPageIndex]
		for i = 1, #ControllerBindingsUI.settingsList do
			local def = ControllerBindingsUI.settingsList[i]
			if def.group == pageName then
				table.insert(items, def)
			end
		end

		if ControllerBindingsUIIsPressed("B") then
			ControllerBindingsUIClose()
		elseif ControllerBindingsUIIsPressed("A") then
			ControllerBindingsUIAdjustSelectedSetting(1, false)
		elseif ControllerBindingsUIIsPressed("X") then
			ControllerBindingsUIResetSelectedSetting()
		elseif ControllerBindingsUIIsPressed("Y") then
			ControllerBindingsUI.modal = "resetAll"
			ControllerBindingsUISetToast("Confirm reset all settings")
		elseif ControllerBindingsUIIsPressed("dpadUp") then
			if #items > 0 then
				ControllerBindingsUI.settingsItemIndex = ((ControllerBindingsUI.settingsItemIndex - 2) % #items) + 1
			end
		elseif ControllerBindingsUIIsPressed("dpadDown") then
			if #items > 0 then
				ControllerBindingsUI.settingsItemIndex = (ControllerBindingsUI.settingsItemIndex % #items) + 1
			end
		elseif ControllerBindingsUIIsPressed("dpadLeft") then
			ControllerBindingsUIAdjustSelectedSetting(-1, false)
		elseif ControllerBindingsUIIsPressed("dpadRight") then
			ControllerBindingsUIAdjustSelectedSetting(1, false)
		elseif ControllerBindingsUIIsPressed("LB") then
			local count = #ControllerBindingsUI.settingsPages
			ControllerBindingsUI.settingsPageIndex = ((ControllerBindingsUI.settingsPageIndex - 2) % count) + 1
			ControllerBindingsUI.settingsItemIndex = 1
		elseif ControllerBindingsUIIsPressed("RB") then
			local count = #ControllerBindingsUI.settingsPages
			ControllerBindingsUI.settingsPageIndex = (ControllerBindingsUI.settingsPageIndex % count) + 1
			ControllerBindingsUI.settingsItemIndex = 1
		end
	else
		if ControllerBindingsUIIsPressed("B") then
			ControllerBindingsUIClose()
		elseif ControllerBindingsUIIsPressed("A") then
			ControllerBindingsUIStartCapture()
		elseif ControllerBindingsUIIsPressed("X") then
			ControllerBindingsUIResetSelected()
		elseif ControllerBindingsUIIsPressed("Y") then
			ControllerBindingsUIResetAll()
		elseif ControllerBindingsUIIsPressed("dpadUp") then
			ControllerBindingsUISelectAction(ControllerBindingsUI.actionIndex - 1)
		elseif ControllerBindingsUIIsPressed("dpadDown") then
			ControllerBindingsUISelectAction(ControllerBindingsUI.actionIndex + 1)
		elseif ControllerBindingsUIIsPressed("dpadLeft") or ControllerBindingsUIIsPressed("LB") then
			ControllerBindingsUISelectCategory(ControllerBindingsUI.categoryIndex - 1)
		elseif ControllerBindingsUIIsPressed("dpadRight") or ControllerBindingsUIIsPressed("RB") then
			ControllerBindingsUISelectCategory(ControllerBindingsUI.categoryIndex + 1)
		end
	end
	return true
end

local function ControllerBindingsUINormalizeKeyName(value)
	local text = string.lower(tostring(value or ""))
	text = string.gsub(text, "[%s%-%_]", "")
	return text
end

local function ControllerBindingsUIKeyMatches(key, label, candidates)
	local normalizedLabel = ControllerBindingsUINormalizeKeyName(label)
	for i = 1, #candidates do
		local candidate = candidates[i]
		if type(candidate) == "number" and key == candidate then
			return true
		elseif type(candidate) == "string" then
			if normalizedLabel ~= "" and normalizedLabel == ControllerBindingsUINormalizeKeyName(candidate) then
				return true
			end
			if KEYSYMS then
				local keySym = KEYSYMS[candidate] or KEYSYMS[string.upper(candidate)]
				if keySym ~= nil and key == keySym then
					return true
				end
			end
			if type(Spring.GetKeyCode) == "function" then
				local ok, keyCode = pcall(Spring.GetKeyCode, candidate)
				if ok and keyCode ~= nil and key == keyCode then
					return true
				end
			end
		end
	end
	return false
end

local function ControllerBindingsUIDrawRect(x1, y1, x2, y2, color)
	glColor(color[1], color[2], color[3], color[4])
	glRect(x1, y1, x2, y2)
end

local function ControllerBindingsUIDrawOutline(x1, y1, x2, y2, color)
	glColor(color[1], color[2], color[3], color[4])
	glLineWidth(1.5)
	glBeginEnd(GL_LINE_LOOP, function()
		glVertex(x1, y1)
		glVertex(x2, y1)
		glVertex(x2, y2)
		glVertex(x1, y2)
	end)
	glLineWidth(1)
end

local function ControllerBindingsUIDrawText(text, x, y, size, color, opts)
	glColor(0, 0, 0, 0.55)
	glText(tostring(text or ""), x + 1, y - 1, size, opts or "")
	glColor(color[1], color[2], color[3], color[4])
	glText(tostring(text or ""), x, y, size, opts or "")
end

local function ControllerBindingsUIDrawPanel(x1, y1, x2, y2, title)
	ControllerBindingsUIDrawRect(x1, y1, x2, y2, { 0.045, 0.06, 0.075, 0.88 })
	ControllerBindingsUIDrawOutline(x1, y1, x2, y2, { 0.26, 0.37, 0.45, 0.95 })
	if title then
		ControllerBindingsUIDrawText(title, x1 + 18, y2 - 31, 18, { 0.84, 0.93, 0.98, 1 }, "o")
	end
end

local ControllerBindingsUIControlGlyph = {
	a = "A", b = "B", x = "X", y = "Y", lb = "LB", rb = "RB", lt = "LT", rt = "RT",
	backView = "back", menuStart = "start", leftStick = "leftStick", rightStick = "rightStick",
	leftStickX = "leftStickX", leftStickY = "leftStickY", rightStickX = "rightStickX", rightStickY = "rightStickY",
	dpadUp = "dpadUp", dpadDown = "dpadDown", dpadLeft = "dpadLeft", dpadRight = "dpadRight", close = "X",
}

local function ControllerBindingsUIDrawXboxBinding(binding, x, y, size, alignment, maxWidth, opacity)
	if not ControllerBindingsUIGlyphs then return false end
	ControllerBindingsUIGlyphs.SetStyle("Xbox", "Xbox")
	local sequence = ControllerBindingsUIGlyphs.BuildSequence({ binding })
	ControllerBindingsUIGlyphs.DrawSequence(sequence, x, y, {
		size = size or 24, spacing = 3, alignment = alignment or "left", maxWidth = maxWidth,
		colorMode = "Color-friendly", opacity = opacity or 1,
	})
	return true
end

local function ControllerBindingsUIDrawChip(controlId, label, x1, y1, x2, y2, activeIds)
	local active = activeIds and activeIds[controlId]
	local fill = active and { 0.15, 0.45, 0.48, 0.96 } or { 0.085, 0.105, 0.13, 0.94 }
	local outline = active and { 0.55, 0.96, 0.92, 1 } or { 0.28, 0.36, 0.44, 0.9 }
	ControllerBindingsUIDrawRect(x1, y1, x2, y2, fill)
	ControllerBindingsUIDrawOutline(x1, y1, x2, y2, outline)
	local glyph = ControllerBindingsUIControlGlyph[controlId]
	local size = math.max(18, math.min(y2 - y1 - 6, 34))
	if not glyph or not ControllerBindingsUIDrawXboxBinding(glyph, (x1 + x2) * 0.5,
			(y1 + y2 - size) * 0.5, size, "center", math.max(18, x2 - x1 - 8)) then
		ControllerBindingsUIDrawText(label, (x1 + x2) * 0.5, (y1 + y2) * 0.5 - 5, 15, { 0.94, 0.98, 1, 1 }, "oc")
	end
end

local function ControllerBindingsUIDrawModalButton(id, label, x1, y1, x2, y2)
	ControllerBindingsUIDrawRect(x1, y1, x2, y2, { 0.09, 0.13, 0.16, 0.96 })
	ControllerBindingsUIDrawOutline(x1, y1, x2, y2, { 0.34, 0.48, 0.58, 0.95 })
	ControllerBindingsUIDrawText(label, (x1 + x2) * 0.5, (y1 + y2) * 0.5 - 5, 14, { 0.9, 0.97, 1, 1 }, "oc")
	ControllerBindingsUI.layout.modalButtons[#ControllerBindingsUI.layout.modalButtons + 1] = { id = id, x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

local function ControllerBindingsUIDrawHeader(x1, y2_header, x2, vsx, vsy)
	local USE_SAFE_AREA_LAYOUT = ControllerBindingsUILayoutGetSetting("useSafeArea")
	local SAFE_MAX_X_MARGIN = ControllerBindingsUILayoutGetSetting("maxXMargin")
	local SAFE_MAX_Y_MARGIN = ControllerBindingsUILayoutGetSetting("maxYMargin")
	local SAFE_X_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("xMarginRatio")
	local SAFE_Y_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("yMarginRatio")

	local infoText = "Xbox Controller Support v0.4.0 pre-alpha"
	if ControllerBindingsUI.totalBindingsCount then
		infoText = infoText .. "  |  Bindings loaded: " .. ControllerBindingsUI.totalBindingsCount
	end

	if USE_SAFE_AREA_LAYOUT then
		local h = 70
		ControllerBindingsUIDrawRect(x1, y2_header - h, x2, y2_header, { 0.025, 0.035, 0.047, 0.96 })
		ControllerBindingsUIDrawOutline(x1, y2_header - h, x2, y2_header, { 0.26, 0.37, 0.45, 0.95 })
		ControllerBindingsUIDrawText("BAR Controller Bindings", x1 + 20, y2_header - 30, 22, { 0.93, 0.98, 1, 1 }, "o")
		ControllerBindingsUIDrawText(infoText, x1 + 22, y2_header - 52, 13, { 0.62, 0.75, 0.84, 1 }, "o")

		-- Mode Tabs (Bindings / Settings)
		local mX2 = x2 - 80
		local mW = 120
		local mH = 34
		local mY1 = y2_header - 52
		local mY2 = mY1 + mH

		-- Bindings Mode Tab
		local bActive = ControllerBindingsUI.mode == "bindings"
		local bX1 = mX2 - mW * 2 - 10
		local bX2 = bX1 + mW
		ControllerBindingsUIDrawRect(bX1, mY1, bX2, mY2, bActive and { 0.15, 0.45, 0.48, 0.9 } or { 0.045, 0.06, 0.075, 0.85 })
		ControllerBindingsUIDrawOutline(bX1, mY1, bX2, mY2, bActive and { 0.55, 0.96, 0.92, 1 } or { 0.26, 0.37, 0.45, 0.8 })
		ControllerBindingsUIDrawText("Bindings", (bX1 + bX2) * 0.5, (mY1 + mY2) * 0.5 - 5, 14, bActive and { 0.55, 0.96, 0.92, 1 } or { 0.84, 0.93, 0.98, 1 }, "oc")
		ControllerBindingsUI.layout.modeTabs.bindings = { x1 = bX1, y1 = mY1, x2 = bX2, y2 = mY2 }

		-- Settings Mode Tab
		local sActive = ControllerBindingsUI.mode == "settings"
		local sX1 = mX2 - mW
		local sX2 = sX1 + mW
		ControllerBindingsUIDrawRect(sX1, mY1, sX2, mY2, sActive and { 0.15, 0.45, 0.48, 0.9 } or { 0.045, 0.06, 0.075, 0.85 })
		ControllerBindingsUIDrawOutline(sX1, mY1, sX2, mY2, sActive and { 0.55, 0.96, 0.92, 1 } or { 0.26, 0.37, 0.45, 0.8 })
		ControllerBindingsUIDrawText("Settings", (sX1 + sX2) * 0.5, (mY1 + mY2) * 0.5 - 5, 14, sActive and { 0.55, 0.96, 0.92, 1 } or { 0.84, 0.93, 0.98, 1 }, "oc")
		ControllerBindingsUI.layout.modeTabs.settings = { x1 = sX1, y1 = mY1, x2 = sX2, y2 = mY2 }

		ControllerBindingsUIDrawText(ControllerBindingsUI.toast or "", bX1 - 15, y2_header - 35, 14, { 0.78, 0.92, 0.98, 1 }, "or")
	else
		ControllerBindingsUIDrawRect(0, vsy - 92, vsx, vsy, { 0.025, 0.035, 0.047, 0.96 })
		ControllerBindingsUIDrawText("BAR Controller Bindings", 54, vsy - 42, 30, { 0.93, 0.98, 1, 1 }, "o")
		ControllerBindingsUIDrawText(infoText, 56, vsy - 72, 16, { 0.62, 0.75, 0.84, 1 }, "o")

		-- Mode Tabs in Fullscreen Mode
		local mX2 = vsx - 120
		local mW = 120
		local mH = 38
		local mY1 = vsy - 66
		local mY2 = mY1 + mH

		-- Bindings Mode Tab
		local bActive = ControllerBindingsUI.mode == "bindings"
		local bX1 = mX2 - mW * 2 - 10
		local bX2 = bX1 + mW
		ControllerBindingsUIDrawRect(bX1, mY1, bX2, mY2, bActive and { 0.15, 0.45, 0.48, 0.9 } or { 0.045, 0.06, 0.075, 0.85 })
		ControllerBindingsUIDrawOutline(bX1, mY1, bX2, mY2, bActive and { 0.55, 0.96, 0.92, 1 } or { 0.26, 0.37, 0.45, 0.8 })
		ControllerBindingsUIDrawText("Bindings", (bX1 + bX2) * 0.5, (mY1 + mY2) * 0.5 - 5, 15, bActive and { 0.55, 0.96, 0.92, 1 } or { 0.84, 0.93, 0.98, 1 }, "oc")
		ControllerBindingsUI.layout.modeTabs.bindings = { x1 = bX1, y1 = mY1, x2 = bX2, y2 = mY2 }

		-- Settings Mode Tab
		local sActive = ControllerBindingsUI.mode == "settings"
		local sX1 = mX2 - mW
		local sX2 = sX1 + mW
		ControllerBindingsUIDrawRect(sX1, mY1, sX2, mY2, sActive and { 0.15, 0.45, 0.48, 0.9 } or { 0.045, 0.06, 0.075, 0.85 })
		ControllerBindingsUIDrawOutline(sX1, mY1, sX2, mY2, sActive and { 0.55, 0.96, 0.92, 1 } or { 0.26, 0.37, 0.45, 0.8 })
		ControllerBindingsUIDrawText("Settings", (sX1 + sX2) * 0.5, (mY1 + mY2) * 0.5 - 5, 15, sActive and { 0.55, 0.96, 0.92, 1 } or { 0.84, 0.93, 0.98, 1 }, "oc")
		ControllerBindingsUI.layout.modeTabs.settings = { x1 = sX1, y1 = mY1, x2 = sX2, y2 = mY2 }

		ControllerBindingsUIDrawText(ControllerBindingsUI.toast or "", bX1 - 20, vsy - 56, 15, { 0.78, 0.92, 0.98, 1 }, "or")
	end
end

local function ControllerBindingsUIDrawTabs(x1, y2_header, x2, vsx, vsy)
	local USE_SAFE_AREA_LAYOUT = ControllerBindingsUILayoutGetSetting("useSafeArea")
	local SAFE_MAX_X_MARGIN = ControllerBindingsUILayoutGetSetting("maxXMargin")
	local SAFE_MAX_Y_MARGIN = ControllerBindingsUILayoutGetSetting("maxYMargin")
	local SAFE_X_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("xMarginRatio")
	local SAFE_Y_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("yMarginRatio")

	local tabs = ControllerBindingsUI.layout.tabs
	for i = 1, #tabs do
		tabs[i] = nil
	end

	local start_x = 54
	local y_tab_top = y2_header - 15
	local h = 38

	if USE_SAFE_AREA_LAYOUT then
		start_x = x1 + 10
		y_tab_top = y2_header - 8
	end

	local x = start_x
	local y1 = y_tab_top - h
	local lowest_y = y1

	if ControllerBindingsUI.mode == "settings" then
		for i = 1, #ControllerBindingsUI.settingsPages do
			local pageName = ControllerBindingsUI.settingsPages[i]
			local w = math.max(96, math.min(168, 42 + string.len(pageName) * 8))

			if USE_SAFE_AREA_LAYOUT and (x + w > x2 - 10) then
				x = start_x
				y_tab_top = y_tab_top - h - 6
				y1 = y_tab_top - h
				if y1 < lowest_y then
					lowest_y = y1
				end
			end

			local active = i == ControllerBindingsUI.settingsPageIndex
			ControllerBindingsUIDrawRect(x, y1, x + w, y1 + h, active and { 0.12, 0.26, 0.34, 0.96 } or { 0.06, 0.075, 0.095, 0.9 })
			ControllerBindingsUIDrawOutline(x, y1, x + w, y1 + h, active and { 0.46, 0.78, 0.95, 1 } or { 0.22, 0.30, 0.37, 0.9 })
			ControllerBindingsUIDrawText(pageName, x + w * 0.5, y1 + 12, 14, { 0.9, 0.97, 1, 1 }, "oc")
			tabs[#tabs + 1] = { x1 = x, y1 = y1, x2 = x + w, y2 = y1 + h, index = i }
			x = x + w + 8
		end
	else
		for i = 1, #ControllerBindingsUI.categories do
			local category = ControllerBindingsUI.categories[i]
			local w = math.max(96, math.min(168, 42 + string.len(category.name) * 8))

			if USE_SAFE_AREA_LAYOUT and (x + w > x2 - 10) then
				x = start_x
				y_tab_top = y_tab_top - h - 6
				y1 = y_tab_top - h
				if y1 < lowest_y then
					lowest_y = y1
				end
			end

			local active = i == ControllerBindingsUI.categoryIndex
			ControllerBindingsUIDrawRect(x, y1, x + w, y1 + h, active and { 0.12, 0.26, 0.34, 0.96 } or { 0.06, 0.075, 0.095, 0.9 })
			ControllerBindingsUIDrawOutline(x, y1, x + w, y1 + h, active and { 0.46, 0.78, 0.95, 1 } or { 0.22, 0.30, 0.37, 0.9 })
			ControllerBindingsUIDrawText(category.name, x + w * 0.5, y1 + 12, 14, { 0.9, 0.97, 1, 1 }, "oc")
			tabs[#tabs + 1] = { x1 = x, y1 = y1, x2 = x + w, y2 = y1 + h, index = i }
			x = x + w + 8
		end
	end

	return lowest_y
end

local function ControllerBindingsUIDrawControllerOverview(x1, y1, x2, y2)
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, "Controller Overview")
	local activeIds = {}
	if ControllerBindingsUI.mode == "settings" then
		local setting = ControllerBindingsUISelectedSetting()
		if setting then
			local key = setting.key
			if key == "panSpeed" or key == "fastPanMultiplier" or key == "stickCurve" or key == "stickDeadzone" then
				activeIds.leftStick = true
			elseif key == "zoomSpeed" or key == "zoomBoostMultiplier" or key == "rotationSpeed" or key == "pitchSpeed" then
				activeIds.rightStick = true
				if key == "zoomSpeed" or key == "zoomBoostMultiplier" then
					activeIds.rightStickY = true
				elseif key == "rotationSpeed" then
					activeIds.rightStickX = true
				end
			elseif key == "triggerCurve" or key == "triggerDeadzone" then
				activeIds.lt = true
				activeIds.rt = true
			end
		end
	else
		local action = ControllerBindingsUISelectedAction()
		local binding = ControllerBindingsUIGetCurrentBinding(action) or action and action.default
		activeIds = ControllerBindingsUIBindingToControlIds(binding)
	end
	local cx = (x1 + x2) * 0.5
	local cy = (y1 + y2) * 0.5 - 10
	local w = x2 - x1

	ControllerBindingsUIDrawChip("lt", "LT", x1 + 42, y2 - 86, x1 + 152, y2 - 50, activeIds)
	ControllerBindingsUIDrawChip("lb", "LB", x1 + 52, y2 - 130, x1 + 162, y2 - 94, activeIds)
	ControllerBindingsUIDrawChip("rt", "RT", x2 - 152, y2 - 86, x2 - 42, y2 - 50, activeIds)
	ControllerBindingsUIDrawChip("rb", "RB", x2 - 162, y2 - 130, x2 - 52, y2 - 94, activeIds)

	ControllerBindingsUIDrawChip("backView", "Back/View", cx - 150, y2 - 160, cx - 44, y2 - 126, activeIds)
	ControllerBindingsUIDrawChip("menuStart", "Menu/Start", cx + 44, y2 - 160, cx + 150, y2 - 126, activeIds)

	ControllerBindingsUIDrawChip("leftStick", "Left Stick", x1 + w * 0.17, cy - 10, x1 + w * 0.34, cy + 55, activeIds)
	ControllerBindingsUIDrawChip("rightStick", "Right Stick", x1 + w * 0.59, cy - 80, x1 + w * 0.78, cy - 15, activeIds)
	ControllerBindingsUIDrawChip("rightStickX", "Right Stick X", x1 + w * 0.58, cy - 128, x1 + w * 0.79, cy - 94, activeIds)
	ControllerBindingsUIDrawChip("rightStickY", "Right Stick Y", x1 + w * 0.58, cy - 170, x1 + w * 0.79, cy - 136, activeIds)

	local dx = x1 + w * 0.20
	local dy = cy - 150
	ControllerBindingsUIDrawChip("dpadUp", "D-pad Up", dx + 46, dy + 68, dx + 134, dy + 102, activeIds)
	ControllerBindingsUIDrawChip("dpadLeft", "D-pad Left", dx - 4, dy + 30, dx + 94, dy + 64, activeIds)
	ControllerBindingsUIDrawChip("dpadRight", "D-pad Right", dx + 94, dy + 30, dx + 198, dy + 64, activeIds)
	ControllerBindingsUIDrawChip("dpadDown", "D-pad Down", dx + 42, dy - 8, dx + 142, dy + 26, activeIds)

	local fx = x2 - 220
	local fy = cy + 10
	ControllerBindingsUIDrawChip("y", "Y", fx + 70, fy + 72, fx + 122, fy + 124, activeIds)
	ControllerBindingsUIDrawChip("x", "X", fx + 14, fy + 18, fx + 66, fy + 70, activeIds)
	ControllerBindingsUIDrawChip("b", "B", fx + 126, fy + 18, fx + 178, fy + 70, activeIds)
	ControllerBindingsUIDrawChip("a", "A", fx + 70, fy - 36, fx + 122, fy + 16, activeIds)
end

local function ControllerBindingsUIDrawActionList(x1, y1, x2, y2)
	local rows = ControllerBindingsUI.layout.rows
	for i = 1, #rows do
		rows[i] = nil
	end
	local category = ControllerBindingsUISelectedCategory()
	local title = "Actions"
	if category then
		title = category.name .. " — " .. #category.actions .. " actions"
	end
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, title)
	if not category then
		return
	end
	local rowH = 34
	local rowY = y2 - 70
	for i = 1, #category.actions do
		local action = category.actions[i]
		if rowY < y1 + 18 then
			break
		end
		local selected = i == ControllerBindingsUI.actionIndex
		local binding = ControllerBindingsUIGetCurrentBinding(action)
		if binding == nil then
			binding = action.default
		end
		ControllerBindingsUIDrawRect(x1 + 12, rowY - rowH + 4, x2 - 12, rowY + 3, selected and { 0.13, 0.28, 0.34, 0.95 } or { 0.07, 0.085, 0.105, 0.72 })
		if selected then
			ControllerBindingsUIDrawOutline(x1 + 12, rowY - rowH + 4, x2 - 12, rowY + 3, { 0.46, 0.88, 0.96, 1 })
		end
		ControllerBindingsUIDrawText(action.label, x1 + 24, rowY - 19, 14, { 0.92, 0.97, 1, 1 }, "o")
		local rightText = ""
		if category.name == "Presets" then
			if ControllerBindingsUI.currentPreset == action.actionLabel then
				rightText = "Active"
			else
				rightText = "Apply"
			end
		else
			local suffix = action.readOnly and " (view)" or ""
			rightText = ControllerBindingsUIDisplayBinding(binding) .. suffix
		end
		if category.name ~= "Presets" then
			ControllerBindingsUIDrawXboxBinding(binding or "Unbound", x2 - 24, rowY - 27, 24, "right", 150)
			if action.readOnly then ControllerBindingsUIDrawText("view", x2 - 182, rowY - 19, 11, { 0.62, 0.75, 0.82, 1 }, "or") end
		else
			ControllerBindingsUIDrawText(rightText, x2 - 24, rowY - 19, 13, { 0.78, 0.9, 0.96, 1 }, "or")
		end
		rows[#rows + 1] = { x1 = x1 + 12, y1 = rowY - rowH + 4, x2 = x2 - 12, y2 = rowY + 3, index = i }
		rowY = rowY - rowH - 3
	end
end

local function ControllerBindingsUIDrawDetails(x1, y1, x2, y2)
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, "Selected Action")
	local action = ControllerBindingsUISelectedAction()
	if not action then
		ControllerBindingsUIDrawText("No action selected", x1 + 20, y2 - 74, 16, { 0.92, 0.96, 1, 1 }, "o")
		return
	end
	if action.group == "Presets" then
		local y = y2 - 76
		ControllerBindingsUIDrawText(action.label .. " Preset", x1 + 20, y, 21, { 0.94, 0.99, 1, 1 }, "o")
		y = y - 36
		local presetStatus = "Custom"
		if ControllerBindingsUI.currentPreset == action.actionLabel then
			presetStatus = "Active"
		else
			presetStatus = "Inactive"
		end
		ControllerBindingsUIDrawText("Status: " .. presetStatus, x1 + 20, y, 15, { 0.72, 0.84, 0.9, 1 }, "o")
		y = y - 24
		ControllerBindingsUIDrawText(action.description or "", x1 + 20, y, 13, { 0.82, 0.9, 0.94, 1 }, "o")
		y = y - 28
		ControllerBindingsUIDrawText("Preset Mapping:", x1 + 20, y, 15, { 0.9, 0.97, 1, 1 }, "o")
		y = y - 20

		local lines = {}
		local presetOk, presetMap = ControllerBindingsUISafeCall("GetBindingPreset", action.actionLabel)
		local defsOk, bindingDefs = ControllerBindingsUISafeCall("GetBindingDefinitions")
		if presetOk and defsOk and type(presetMap) == "table" and type(bindingDefs) == "table" then
			for _, def in ipairs(bindingDefs) do
				local assigned = presetMap[def.action]
				if assigned and assigned ~= "none" then
					lines[#lines + 1] = ControllerBindingsUIDisplayBinding(assigned) .. " = " .. tostring(def.label)
				end
			end
		end

		for _, line in ipairs(lines) do
			if y < y1 + 54 then break end
			ControllerBindingsUIDrawText("  - " .. line, x1 + 20, y, 12, { 0.78, 0.9, 0.96, 1 }, "o")
			y = y - 16
		end

		y = y - 10
		ControllerBindingsUIDrawText("Press A/Enter or click to apply this preset layout.", x1 + 20, y, 12, { 1, 0.84, 0.46, 1 }, "o")
		return
	end
	local binding = ControllerBindingsUIGetCurrentBinding(action)
	if binding == nil then
		binding = action.default
	end
	local y = y2 - 76
	ControllerBindingsUIDrawText(action.label, x1 + 20, y, 21, { 0.94, 0.99, 1, 1 }, "o")
	y = y - 42
	ControllerBindingsUIDrawText("Action: " .. tostring(action.action), x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	y = y - 28
	ControllerBindingsUIDrawText("Group: " .. tostring(action.group), x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	y = y - 28
	ControllerBindingsUIDrawText("Default:", x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	ControllerBindingsUIDrawXboxBinding(action.default or "Unbound", x1 + 102, y - 8, 24, "left", x2 - x1 - 130)
	y = y - 28
	ControllerBindingsUIDrawText("Current:", x1 + 20, y, 16, { 0.86, 0.98, 1, 1 }, "o")
	ControllerBindingsUIDrawXboxBinding(binding or "Unbound", x1 + 102, y - 8, 24, "left", x2 - x1 - 130)
	y = y - 34
	ControllerBindingsUIDrawText("Control ID: " .. tostring(ControllerBindingsUIBindingToControlId(binding) or "none"), x1 + 20, y, 13, { 0.62, 0.75, 0.82, 1 }, "o")
	y = y - 45
	ControllerBindingsUIDrawText(action.description or "", x1 + 20, y, 13, { 0.82, 0.9, 0.94, 1 }, "o")
	y = y - 34
	if action.readOnly then
		ControllerBindingsUIDrawText("Read-only display row. Not remappable yet.", x1 + 20, y, 13, { 1, 0.78, 0.46, 1 }, "o")
	end
end

local function ControllerBindingsUIDrawFooter(x1, y1, x2, vsx)
	local USE_SAFE_AREA_LAYOUT = ControllerBindingsUILayoutGetSetting("useSafeArea")
	local SAFE_MAX_X_MARGIN = ControllerBindingsUILayoutGetSetting("maxXMargin")
	local SAFE_MAX_Y_MARGIN = ControllerBindingsUILayoutGetSetting("maxYMargin")
	local SAFE_X_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("xMarginRatio")
	local SAFE_Y_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("yMarginRatio")

	if USE_SAFE_AREA_LAYOUT then
		ControllerBindingsUIDrawRect(x1, y1, x2, y1 + 40, { 0.025, 0.035, 0.047, 0.96 })
		ControllerBindingsUIDrawOutline(x1, y1, x2, y1 + 40, { 0.26, 0.37, 0.45, 0.95 })
		local category = ControllerBindingsUISelectedCategory()
		if ControllerBindingsUI.mode == "settings" then
			ControllerBindingsUIDrawText("A/Enter Toggle Bool  |  Left/Right Adjust Number  |  X/R Reset  |  Y Reset All  |  B/Esc Close  |  LB/RB or Left/Right Tab  |  Start/Menu Mode Toggle", (x1 + x2) * 0.5, y1 + 13, 13, { 0.78, 0.9, 0.96, 1 }, "oc")
		elseif category and category.name == "Presets" then
			ControllerBindingsUIDrawText("A/Enter Apply Preset  |  B/Esc Close  |  LB/RB or Left/Right Category  |  Start/Menu Mode Toggle", (x1 + x2) * 0.5, y1 + 13, 13, { 0.78, 0.9, 0.96, 1 }, "oc")
		else
			ControllerBindingsUIDrawText("A/Enter Rebind  |  X/R Reset  |  Y Reset All  |  B/Esc Close  |  LB/RB or Left/Right Category  |  Start/Menu Mode Toggle", (x1 + x2) * 0.5, y1 + 13, 13, { 0.78, 0.9, 0.96, 1 }, "oc")
		end
	else
		ControllerBindingsUIDrawRect(0, 0, vsx, 50, { 0.025, 0.035, 0.047, 0.96 })
		local category = ControllerBindingsUISelectedCategory()
		if ControllerBindingsUI.mode == "settings" then
			ControllerBindingsUIDrawText("A/Enter Toggle Bool  |  Left/Right Adjust Number  |  X/R Reset  |  Y Reset All  |  B/Esc Close  |  LB/RB or Left/Right Tab  |  Start/Menu Mode Toggle", vsx * 0.5, 18, 14, { 0.78, 0.9, 0.96, 1 }, "oc")
		elseif category and category.name == "Presets" then
			ControllerBindingsUIDrawText("A/Enter Apply Preset  |  B/Esc Close  |  LB/RB or Left/Right Category  |  Start/Menu Mode Toggle", vsx * 0.5, 18, 14, { 0.78, 0.9, 0.96, 1 }, "oc")
		else
			ControllerBindingsUIDrawText("A/Enter Rebind  |  X/R Reset  |  Y Reset All  |  B/Esc Close  |  LB/RB or Left/Right Category  |  Start/Menu Mode Toggle", vsx * 0.5, 18, 14, { 0.78, 0.9, 0.96, 1 }, "oc")
		end
	end
end

local function ControllerBindingsUIDrawWarning(vsx, vsy)
	local USE_SAFE_AREA_LAYOUT = ControllerBindingsUILayoutGetSetting("useSafeArea")
	local SAFE_MAX_X_MARGIN = ControllerBindingsUILayoutGetSetting("maxXMargin")
	local SAFE_MAX_Y_MARGIN = ControllerBindingsUILayoutGetSetting("maxYMargin")
	local SAFE_X_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("xMarginRatio")
	local SAFE_Y_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("yMarginRatio")

	ControllerBindingsUIDrawRect(0, 0, vsx, vsy, { 0, 0, 0, 0.68 })
	local w = math.min(760, vsx - 140)
	if USE_SAFE_AREA_LAYOUT then
		local safeX = math.min(SAFE_MAX_X_MARGIN, math.floor(vsx * SAFE_X_MARGIN_RATIO))
		w = math.min(760, (vsx - safeX - safeX) - 40)
	end
	local h = 240
	local x1, y1
	if USE_SAFE_AREA_LAYOUT then
		local safeX = math.min(SAFE_MAX_X_MARGIN, math.floor(vsx * SAFE_X_MARGIN_RATIO))
		local safeY = math.min(SAFE_MAX_Y_MARGIN, math.floor(vsy * SAFE_Y_MARGIN_RATIO))
		local cx = (safeX + vsx - safeX) * 0.5
		local cy = (safeY + vsy - safeY) * 0.5
		x1 = cx - w * 0.5
		y1 = cy - h * 0.5
	else
		x1 = (vsx - w) * 0.5
		y1 = (vsy - h) * 0.5
	end
	ControllerBindingsUIDrawPanel(x1, y1, x1 + w, y1 + h, "Controller Support API Missing")
	if not WG or not WG.BARControllerSupport then
		ControllerBindingsUIDrawText("Controller support API not available. Enable gui_controller_camera_test.lua first.", x1 + 24, y1 + h - 82, 17, { 1, 0.83, 0.62, 1 }, "o")
	else
		ControllerBindingsUIDrawText("Controller support API is incomplete. Missing:", x1 + 24, y1 + h - 82, 17, { 1, 0.83, 0.62, 1 }, "o")
		ControllerBindingsUIDrawText(table.concat(ControllerBindingsUI.missing, ", "), x1 + 24, y1 + h - 122, 14, { 0.9, 0.95, 1, 1 }, "o")
	end
	ControllerBindingsUIDrawText("Esc or B closes this editor.", x1 + 24, y1 + 34, 14, { 0.72, 0.84, 0.9, 1 }, "o")
end

local function ControllerBindingsUIDrawModal(vsx, vsy)
	if not ControllerBindingsUI.modal then
		return
	end
	local USE_SAFE_AREA_LAYOUT = ControllerBindingsUILayoutGetSetting("useSafeArea")
	local SAFE_MAX_X_MARGIN = ControllerBindingsUILayoutGetSetting("maxXMargin")
	local SAFE_MAX_Y_MARGIN = ControllerBindingsUILayoutGetSetting("maxYMargin")
	local SAFE_X_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("xMarginRatio")
	local SAFE_Y_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("yMarginRatio")

	ControllerBindingsUIDrawRect(0, 0, vsx, vsy, { 0, 0, 0, 0.62 })
	local w = 560
	local h = 250
	local x1, y1, x2, y2
	if USE_SAFE_AREA_LAYOUT then
		local safeX = math.min(SAFE_MAX_X_MARGIN, math.floor(vsx * SAFE_X_MARGIN_RATIO))
		local safeY = math.min(SAFE_MAX_Y_MARGIN, math.floor(vsy * SAFE_Y_MARGIN_RATIO))
		local cx = (safeX + vsx - safeX) * 0.5
		local cy = (safeY + vsy - safeY) * 0.5
		x1 = cx - w * 0.5
		y1 = cy - h * 0.5
		x2 = x1 + w
		y2 = y1 + h
	else
		x1 = (vsx - w) * 0.5
		y1 = (vsy - h) * 0.5
		x2 = x1 + w
		y2 = y1 + h
	end
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, "Controller Bindings")
	ControllerBindingsUI.layout.modalButtons = {}

	if ControllerBindingsUI.modal == "capture" then
		local action = ControllerBindingsUI.captureAction
		ControllerBindingsUIDrawText("Rebind: " .. tostring(action and action.label or "Unknown"), x1 + 28, y2 - 78, 21, { 0.94, 0.99, 1, 1 }, "o")
		ControllerBindingsUIDrawText("Current: " .. ControllerBindingsUIDisplayBinding(action and ControllerBindingsUIGetCurrentBinding(action)), x1 + 28, y2 - 118, 15, { 0.76, 0.88, 0.94, 1 }, "o")
		ControllerBindingsUIDrawText("Press a controller input...", x1 + 28, y2 - 162, 18, { 0.72, 0.98, 0.95, 1 }, "o")
		ControllerBindingsUIDrawText("B / Escape: Cancel", x1 + 28, y1 + 34, 14, { 0.74, 0.84, 0.9, 1 }, "o")
		ControllerBindingsUIDrawModalButton("cancel", "Cancel", x2 - 148, y1 + 22, x2 - 28, y1 + 58)
	elseif ControllerBindingsUI.modal == "conflict" then
		ControllerBindingsUIDrawText("This input is already assigned to " .. tostring(ControllerBindingsUI.conflictAction and ControllerBindingsUI.conflictAction.label or "another action") .. ".", x1 + 28, y2 - 82, 16, { 1, 0.84, 0.64, 1 }, "o")
		ControllerBindingsUIDrawText("Input: " .. ControllerBindingsUIDisplayBinding(ControllerBindingsUI.pendingInput), x1 + 28, y2 - 122, 16, { 0.9, 0.98, 1, 1 }, "o")
		ControllerBindingsUIDrawText("Replace needs a clear-binding API and is not enabled yet.", x1 + 28, y2 - 156, 13, { 0.72, 0.84, 0.9, 1 }, "o")
		ControllerBindingsUIDrawModalButton("replace", "Replace", x1 + 28, y1 + 22, x1 + 158, y1 + 58)
		ControllerBindingsUIDrawModalButton("duplicate", "Allow Duplicate", x1 + 174, y1 + 22, x1 + 344, y1 + 58)
		ControllerBindingsUIDrawModalButton("cancel", "Cancel", x2 - 148, y1 + 22, x2 - 28, y1 + 58)
	elseif ControllerBindingsUI.modal == "resetAll" then
		local titleText = "Reset all controller bindings?"
		if ControllerBindingsUI.mode == "settings" then
			titleText = "Reset all controller settings?"
		end
		ControllerBindingsUIDrawText(titleText, x1 + 28, y2 - 92, 22, { 0.94, 0.99, 1, 1 }, "o")
		ControllerBindingsUIDrawText("A / Enter confirms. B / Escape cancels.", x1 + 28, y2 - 136, 16, { 0.76, 0.88, 0.94, 1 }, "o")
		ControllerBindingsUIDrawModalButton("resetAll", "Reset All", x1 + 28, y1 + 22, x1 + 158, y1 + 58)
		ControllerBindingsUIDrawModalButton("cancel", "Cancel", x2 - 148, y1 + 22, x2 - 28, y1 + 58)
	elseif ControllerBindingsUI.modal == "applyPreset" then
		local presetName = ControllerBindingsUI.pendingPresetName
		ControllerBindingsUIDrawText("Apply " .. tostring(presetName or "") .. " preset?", x1 + 28, y2 - 92, 22, { 0.94, 0.99, 1, 1 }, "o")
		ControllerBindingsUIDrawText("Warning: This will replace selected build/tactical/queue/group bindings only.", x1 + 28, y2 - 136, 15, { 1, 0.84, 0.64, 1 }, "o")
		ControllerBindingsUIDrawModalButton("applyPreset", "Apply Preset", x1 + 28, y1 + 22, x1 + 178, y1 + 58)
		ControllerBindingsUIDrawModalButton("cancel", "Cancel", x2 - 148, y1 + 22, x2 - 28, y1 + 58)
	end
end

local function ControllerBindingsUIDrawSettingsList(x1, y1, x2, y2)
	local rows = ControllerBindingsUI.layout.rows
	for i = 1, #rows do
		rows[i] = nil
	end
	local pageName = ControllerBindingsUI.settingsPages[ControllerBindingsUI.settingsPageIndex]
	if not pageName then
		ControllerBindingsUIDrawPanel(x1, y1, x2, y2, "Settings")
		return
	end

	local items = {}
	for i = 1, #ControllerBindingsUI.settingsList do
		local def = ControllerBindingsUI.settingsList[i]
		if def.group == pageName then
			table.insert(items, def)
		end
	end

	local title = pageName .. " — " .. #items .. " settings"
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, title)

	if #items == 0 then
		ControllerBindingsUIDrawText("No settings in this category", x1 + 24, y2 - 70, 14, { 0.72, 0.84, 0.9, 1 }, "o")
		return
	end

	local rowH = 34
	local rowY = y2 - 70
	for i = 1, #items do
		local item = items[i]
		if rowY < y1 + 18 then
			break
		end
		local selected = i == ControllerBindingsUI.settingsItemIndex
		local val = ControllerBindingsUIGetSettingValue(item)
		if val == nil and item.type ~= "action" then
			val = item.value or item.default or 0
		end

		ControllerBindingsUIDrawRect(x1 + 12, rowY - rowH + 4, x2 - 12, rowY + 3, selected and { 0.13, 0.28, 0.34, 0.95 } or { 0.07, 0.085, 0.105, 0.72 })
		if selected then
			ControllerBindingsUIDrawOutline(x1 + 12, rowY - rowH + 4, x2 - 12, rowY + 3, { 0.46, 0.88, 0.96, 1 })
		end

		ControllerBindingsUIDrawText(item.label, x1 + 24, rowY - 19, 14, { 0.92, 0.97, 1, 1 }, "o")

		local valStr = ""
		if item.type == "boolean" then
			valStr = val and "ON" or "OFF"
		elseif item.type == "action" then
			valStr = "RESET"
		else
			local fmt = (item.decimals == 0 or not item.decimals) and "%.0f" or string.format("%%.%df", item.decimals)
			valStr = string.format(fmt, tonumber(val) or 0)
		end

		ControllerBindingsUIDrawText(valStr, x2 - 24, rowY - 19, 13, { 0.78, 0.9, 0.96, 1 }, "or")
		rows[#rows + 1] = { x1 = x1 + 12, y1 = rowY - rowH + 4, x2 = x2 - 12, y2 = rowY + 3, index = i }
		rowY = rowY - rowH - 3
	end
end

local function ControllerBindingsUIDrawSettingsDetails(x1, y1, x2, y2)
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, "Setting Details")
	local item = ControllerBindingsUISelectedSetting()
	if not item or ControllerBindingsUIIsRowMalformed(item) then
		ControllerBindingsUIDrawText("No setting selected", x1 + 20, y2 - 74, 16, { 0.92, 0.96, 1, 1 }, "o")
		return
	end

	local val = ControllerBindingsUIGetSettingValue(item)
	if val == nil and item.type ~= "action" then
		val = item.value or item.default or 0
	end

	local y = y2 - 76
	ControllerBindingsUIDrawText(item.label, x1 + 20, y, 21, { 0.94, 0.99, 1, 1 }, "o")
	y = y - 42

	ControllerBindingsUIDrawText("Key: " .. tostring(item.key), x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	y = y - 28
	ControllerBindingsUIDrawText("Page: " .. tostring(item.group), x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	y = y - 28

	local defValStr = ""
	local valStr = ""
	if item.type == "boolean" then
		defValStr = item.default and "ON" or "OFF"
		valStr = val and "ON" or "OFF"
	elseif item.type == "action" then
		defValStr = "N/A"
		valStr = "ACTIVATE"
	else
		local fmt = (item.decimals == 0 or not item.decimals) and "%.0f" or string.format("%%.%df", item.decimals)
		defValStr = string.format(fmt, tonumber(item.default) or 0)
		valStr = string.format(fmt, tonumber(val) or 0)
	end

	ControllerBindingsUIDrawText("Default: " .. defValStr, x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	y = y - 28
	ControllerBindingsUIDrawText("Current: " .. valStr, x1 + 20, y, 16, { 0.86, 0.98, 1, 1 }, "o")
	y = y - 34

	if item.type ~= "boolean" and item.type ~= "action" then
		local minVal = tonumber(item.min) or 0
		local maxVal = tonumber(item.max) or 1
		local numericVal = tonumber(val) or minVal
		local pct = 0
		if maxVal > minVal then
			pct = math.max(0, math.min(1, (numericVal - minVal) / (maxVal - minVal)))
		end
		local sx1, sx2 = x1 + 20, x2 - 28
		local sy1, sy2 = y - 8, y + 2
		ControllerBindingsUIDrawRect(sx1, sy1, sx2, sy2, { 0.035, 0.055, 0.07, 0.95 })
		ControllerBindingsUIDrawRect(sx1, sy1, sx1 + ((sx2 - sx1) * pct), sy2, { 0.26, 0.78, 0.88, 0.95 })
		ControllerBindingsUIDrawOutline(sx1, sy1, sx2, sy2, { 0.22, 0.44, 0.52, 0.9 })
		y = y - 24
		local fmt = (item.decimals == 0 or not item.decimals) and "%.0f" or string.format("%%.%df", item.decimals)
		local minStr = string.format(fmt, tonumber(item.min) or 0)
		local maxStr = string.format(fmt, tonumber(item.max) or 0)
		ControllerBindingsUIDrawText("Range: " .. minStr .. " to " .. maxStr .. " (step " .. tostring(item.step) .. ")", x1 + 20, y, 13, { 0.62, 0.75, 0.82, 1 }, "o")
		y = y - 34
	end

	local desc = item.description or ""
	if desc == "" then
		if item.key == "panSpeed" then
			desc = "Controls the camera movement speed when panning."
		elseif item.key == "fastPanMultiplier" then
			desc = "Speed multiplier when holding LT while panning."
		elseif item.key == "zoomSpeed" then
			desc = "Controls camera zooming speed."
		elseif item.key == "zoomBoostMultiplier" then
			desc = "Zoom speed multiplier when holding LT."
		elseif item.key == "rotationSpeed" then
			desc = "Controls camera horizontal rotation speed."
		elseif item.key == "pitchSpeed" then
			desc = "Controls camera vertical pitch speed."
		elseif item.key == "cameraSmoothing" then
			desc = "Smooths stick movement to prevent sudden camera jumps."
		elseif item.key == "stickCurve" then
			desc = "Exponent curve for sticks. Higher values give finer control."
		elseif item.key == "triggerCurve" then
			desc = "Exponent curve for triggers. Higher values give finer control."
		elseif item.key == "stickDeadzone" then
			desc = "Minimum stick movement required to register input."
		elseif item.key == "triggerDeadzone" then
			desc = "Minimum trigger pull required to register input."
		elseif item.key == "xHoldSeconds" then
			desc = "Duration to hold X button for holding actions."
		elseif item.key == "aHoldSeconds" then
			desc = "Duration to hold A button for holding actions."
		elseif item.key == "controlGroupAssignHoldSeconds" then
			desc = "Legacy duration for hold-to-assign group behavior if that shortcut is rebound."
		elseif item.key == "singlePathSpacing" then
			desc = "Minimum distance between queued waypoints."
		elseif item.key == "singlePathInterval" then
			desc = "Minimum time between issued waypoints."
		elseif item.key == "radialScale" then
			desc = "Size scale multiplier for the radial menus."
		elseif item.key == "compactSelectedStatus" then
			desc = "Shows a compact selection status panel."
		elseif item.key == "hideCompactStatusWhenRadialOpen" then
			desc = "Automatically hide status panel when a radial menu is open."
		elseif item.key == "areaSelectRadius" then
			desc = "Default radius for selecting multiple units."
		elseif item.key == "smartAssistScale" then
			desc = "Scales Smart X assisted targeting down from the current maximum radius. 1.00 is full size; 0 disables assist."
		elseif item.key == "reticleSize" then
			desc = "Visual size of the gameplay reticle."
		elseif item.key == "placementPopupEnabled" then
			desc = "Shows helper tooltip popup during build placement."
		elseif item.key == "preferNativeBlueprint" then
			desc = "Enables native BAR blueprint grid placement."
		elseif item.key == "debugPanelVisible" then
			desc = "Renders the controller support developer debug panel."
		elseif item.key == "helpOverlayVisible" then
			desc = "Renders controller support gameplay guide overlays."
		elseif item.key == "buildRadialScale" then
			desc = "Overall size scale of the build radial menu."
		elseif item.key == "buildIconScale" then
			desc = "Scale factor for unit photos/icons inside the build radial."
		elseif item.key == "buildTextScale" then
			desc = "Scale factor for unit/cost text inside the build radial."
		elseif item.key == "buildPageLabelScale" then
			desc = "Scale factor for category/page labels inside the build radial."
		elseif item.key == "buildFillAlpha" then
			desc = "Opacity of the translucent build radial category fill."
		elseif item.key == "buildSelectedBorderScale" then
			desc = "Scale factor for the border/highlight of the selected item."
		elseif item.key == "buildItemSpacing" then
			desc = "Item spacing distance factor in the build radial."
		end
	end
	ControllerBindingsUIDrawText(desc, x1 + 20, y, 13, { 0.82, 0.9, 0.94, 1 }, "o")
end

local function ControllerBindingsUIDrawToggleButton(vsx, vsy)
	local bounds, component, shared = ControllerBindingsUIGetLauncherBounds(vsx, vsy)
	ControllerBindingsUILauncherBounds = bounds
	if not bounds then return end
	local x1, y1, x2, y2 = bounds.x1, bounds.y1, bounds.x2, bounds.y2
	local opacity = shared and shared.GetEffectiveOpacity("bindingsButton") or 1
	local fontScale = shared and shared.GetEffectiveFontScale("bindingsButton") or 1

	local open = ControllerBindingsUI.open
	local fill = open and { 0.15, 0.45, 0.48, 0.9 * opacity } or { 0.045, 0.06, 0.075, 0.85 * opacity }
	local outline = open and { 0.55, 0.96, 0.92, opacity } or { 0.26, 0.37, 0.45, 0.8 * opacity }
	local textCol = open and { 0.55, 0.96, 0.92, opacity } or { 0.84, 0.93, 0.98, opacity }

	ControllerBindingsUIDrawRect(x1, y1, x2, y2, fill)
	ControllerBindingsUIDrawOutline(x1, y1, x2, y2, outline)
	ControllerBindingsUIDrawText("Bindings", (x1 + x2) * 0.5, (y1 + y2) * 0.5 - (5 * (bounds.scale or 1)), 12 * fontScale, textCol, "oc")
end

local function ControllerBindingsUIDrawMain()
	local vsx, vsy = spGetViewGeometry()
	local USE_SAFE_AREA_LAYOUT = ControllerBindingsUILayoutGetSetting("useSafeArea")
	local SAFE_MAX_X_MARGIN = ControllerBindingsUILayoutGetSetting("maxXMargin")
	local SAFE_MAX_Y_MARGIN = ControllerBindingsUILayoutGetSetting("maxYMargin")
	local SAFE_X_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("xMarginRatio")
	local SAFE_Y_MARGIN_RATIO = ControllerBindingsUILayoutGetSetting("yMarginRatio")

	local safe_x1 = 54
	local safe_x2 = vsx - 54
	local safe_y1 = 0
	local safe_y2 = vsy

	if USE_SAFE_AREA_LAYOUT then
		local safeX = math.min(SAFE_MAX_X_MARGIN, math.floor(vsx * SAFE_X_MARGIN_RATIO))
		local safeY = math.min(SAFE_MAX_Y_MARGIN, math.floor(vsy * SAFE_Y_MARGIN_RATIO))
		safe_x1 = safeX
		safe_x2 = vsx - safeX
		safe_y1 = safeY
		safe_y2 = vsy - safeY
	end

	local close_x1, close_y1, close_x2, close_y2
	if USE_SAFE_AREA_LAYOUT then
		close_x1 = safe_x2 - 60
		close_y1 = safe_y2 - 53
		close_x2 = safe_x2 - 10
		close_y2 = safe_y2 - 13
	else
		close_x1 = vsx - 104
		close_y1 = vsy - 78
		close_x2 = vsx - 54
		close_y2 = vsy - 32
	end
	ControllerBindingsUI.layout.close = { x1 = close_x1, y1 = close_y1, x2 = close_x2, y2 = close_y2 }

	ControllerBindingsUIDrawRect(0, 0, vsx, vsy, { 0.012, 0.018, 0.026, 0.94 })
	ControllerBindingsUIDrawHeader(safe_x1, safe_y2, safe_x2, vsx, vsy)
	ControllerBindingsUIDrawChip("close", "X", close_x1, close_y1, close_x2, close_y2, {})

	if #ControllerBindingsUI.missing > 0 then
		ControllerBindingsUIDrawWarning(vsx, vsy)
		return
	end

	local lowest_y = ControllerBindingsUIDrawTabs(safe_x1, USE_SAFE_AREA_LAYOUT and (safe_y2 - 70) or (vsy - 92), safe_x2, vsx, vsy)

	local top = lowest_y - 15
	local bottom = 66
	local gap = 18

	if USE_SAFE_AREA_LAYOUT then
		bottom = safe_y1 + 50
	end

	local leftW = math.min(850, (safe_x2 - safe_x1) * 0.44)
	local actionW = math.min(500, (safe_x2 - safe_x1) * 0.25)

	local x1 = safe_x1
	local x2 = x1 + leftW
	local ax1 = x2 + gap
	local ax2 = ax1 + actionW
	local dx1 = ax2 + gap
	local dx2 = safe_x2

	if dx2 - dx1 < 330 then
		leftW = math.max(450, (safe_x2 - safe_x1) * 0.38)
		x2 = x1 + leftW
		ax1 = x2 + gap
		ax2 = math.min(safe_x2 - 300, ax1 + actionW)
		dx1 = ax2 + gap
	end

	ControllerBindingsUIDrawControllerOverview(x1, bottom, x2, top)
	if ControllerBindingsUI.mode == "settings" then
		ControllerBindingsUIDrawSettingsList(ax1, bottom, ax2, top)
		ControllerBindingsUIDrawSettingsDetails(dx1, bottom, dx2, top)
	else
		ControllerBindingsUIDrawActionList(ax1, bottom, ax2, top)
		ControllerBindingsUIDrawDetails(dx1, bottom, dx2, top)
	end
	ControllerBindingsUIDrawFooter(safe_x1, safe_y1, safe_x2, vsx)
	ControllerBindingsUIDrawModal(vsx, vsy)
end

local function ControllerBindingsUIPointInside(hit, x, y)
	return hit and x >= hit.x1 and x <= hit.x2 and y >= hit.y1 and y <= hit.y2
end

local function ControllerBindingsUIAction()
	ControllerBindingsUIToggle()
	return true
end

function widget:Initialize()
	if ControllerBindingsUIGlyphs then ControllerBindingsUIGlyphs.SetStyle("Xbox", "Xbox") end
	if widgetHandler and widgetHandler.AddAction then
		widgetHandler:AddAction("bar_controller_bindings", ControllerBindingsUIAction, nil, "t")
	end
	WG.BARControllerBindingsUI = WG.BARControllerBindingsUI or {}
	WG.BARControllerBindingsUI.Toggle = ControllerBindingsUIToggle
	WG.BARControllerBindingsUI.Open = ControllerBindingsUIOpen
	WG.BARControllerBindingsUI.Close = ControllerBindingsUIClose
	WG.BARControllerBindingsUI.IsOpen = function() return ControllerBindingsUI.open == true end
	WG.BARControllerBindingsUI.GetLauncherBounds = function() return ControllerBindingsUILauncherBounds end
	ControllerBindingsUITryMigrateLauncher()
	local presetOk, presetName = ControllerBindingsUISafeCall("GetActiveBindingPreset")
	if presetOk and type(presetName) == "string" then
		ControllerBindingsUI.currentPreset = presetName
	end
	ControllerBindingsUIRefreshMissingAPI()
	ControllerBindingsUIRebuildCategories()
end

function widget:Shutdown()
	ControllerBindingsUISetGameplayBlocked(false)
	if widgetHandler and widgetHandler.RemoveAction then
		widgetHandler:RemoveAction("bar_controller_bindings")
	end
	if WG and WG.BARControllerBindingsUI then
		WG.BARControllerBindingsUI.Toggle = nil
		WG.BARControllerBindingsUI.Open = nil
		WG.BARControllerBindingsUI.Close = nil
		WG.BARControllerBindingsUI.IsOpen = nil
		WG.BARControllerBindingsUI.GetLauncherBounds = nil
		WG.BARControllerBindingsUI = nil
	end
end

function widget:TextCommand(command)
	local normalized = ControllerBindingsUINormalizeKeyName(command)
	if normalized == "barcontrollerbindings" then
		ControllerBindingsUIToggle()
		return true
	end
	return false
end

function widget:Update()
	if not ControllerBindingsUI.open then
		return
	end
	ControllerBindingsUISetGameplayBlocked(true)
	ControllerBindingsUIRefreshMissingAPI()
	ControllerBindingsUIHandleControllerInput()
end

function widget:KeyPress(key, mods, isRepeat, label)
	if not ControllerBindingsUI.open or isRepeat then
		return false
	end
	if ControllerBindingsUI.modal == "capture" then
		if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
			ControllerBindingsUICancelModal()
			return true
		end
		return true
	elseif ControllerBindingsUI.modal == "conflict" then
		if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
			ControllerBindingsUICancelModal()
		elseif ControllerBindingsUIKeyMatches(key, label, { "D", "d" }) then
			ControllerBindingsUIApplyBinding(ControllerBindingsUI.captureAction, ControllerBindingsUI.pendingInput, true)
		elseif ControllerBindingsUIKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", 13, 271 }) then
			ControllerBindingsUISetToast("Replace unsupported by current API; press D to allow duplicate")
		end
		return true
	elseif ControllerBindingsUI.modal == "resetAll" then
		if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
			ControllerBindingsUICancelModal()
		elseif ControllerBindingsUIKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", 13, 271 }) then
			if ControllerBindingsUI.mode == "settings" then
				ControllerBindingsUIResetAllSettings()
				ControllerBindingsUI.modal = nil
			else
				ControllerBindingsUIConfirmResetAll()
			end
		end
		return true
	elseif ControllerBindingsUI.modal == "applyPreset" then
		if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
			ControllerBindingsUICancelModal()
		elseif ControllerBindingsUIKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", 13, 271 }) then
			ControllerBindingsUIConfirmApplyPreset()
		end
		return true
	end

	if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
		ControllerBindingsUIClose()
		return true
	elseif ControllerBindingsUIKeyMatches(key, label, { "tab", "TAB", 9 }) or ControllerBindingsUIKeyMatches(key, label, { "S", "s", "Start", "start", "Menu", "menu" }) then
		if ControllerBindingsUI.mode == "settings" then
			ControllerBindingsUI.mode = "bindings"
			ControllerBindingsUISetToast("Switched to Bindings")
		else
			ControllerBindingsUI.mode = "settings"
			ControllerBindingsUIRebuildSettings()
			ControllerBindingsUISetToast("Switched to Settings")
		end
		return true
	end

	if ControllerBindingsUI.mode == "settings" then
		local items = {}
		local pageName = ControllerBindingsUI.settingsPages[ControllerBindingsUI.settingsPageIndex]
		for i = 1, #ControllerBindingsUI.settingsList do
			local def = ControllerBindingsUI.settingsList[i]
			if def.group == pageName then
				table.insert(items, def)
			end
		end

		if ControllerBindingsUIKeyMatches(key, label, { "UP", "Up", "up", 273 }) then
			if #items > 0 then
				ControllerBindingsUI.settingsItemIndex = ((ControllerBindingsUI.settingsItemIndex - 2) % #items) + 1
			end
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "DOWN", "Down", "down", 274 }) then
			if #items > 0 then
				ControllerBindingsUI.settingsItemIndex = (ControllerBindingsUI.settingsItemIndex % #items) + 1
			end
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "LEFT", "Left", "left", 276 }) then
			ControllerBindingsUIAdjustSelectedSetting(-1, mods.shift)
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "RIGHT", "Right", "right", 275 }) then
			ControllerBindingsUIAdjustSelectedSetting(1, mods.shift)
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", 13, 271 }) then
			ControllerBindingsUIAdjustSelectedSetting(1, false)
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "R", "r" }) then
			ControllerBindingsUIResetSelectedSetting()
			return true
		end
	else
		if ControllerBindingsUIKeyMatches(key, label, { "UP", "Up", "up", 273 }) then
			ControllerBindingsUISelectAction(ControllerBindingsUI.actionIndex - 1)
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "DOWN", "Down", "down", 274 }) then
			ControllerBindingsUISelectAction(ControllerBindingsUI.actionIndex + 1)
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "LEFT", "Left", "left", 276 }) then
			ControllerBindingsUISelectCategory(ControllerBindingsUI.categoryIndex - 1)
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "RIGHT", "Right", "right", 275 }) then
			ControllerBindingsUISelectCategory(ControllerBindingsUI.categoryIndex + 1)
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", 13, 271 }) then
			ControllerBindingsUIStartCapture()
			return true
		elseif ControllerBindingsUIKeyMatches(key, label, { "R", "r" }) then
			ControllerBindingsUIResetSelected()
			return true
		end
	end
	return true
end

function widget:MousePress(x, y, button)
	local vsx, vsy = spGetViewGeometry()
	local shared = WG and WG.ControllerUISettings
	if shared and type(shared.IsEditorOpen) == "function" and shared.IsEditorOpen() then
		return false
	end
	local launcher = ControllerBindingsUIGetLauncherBounds(vsx, vsy)
	if launcher and button == 1 and ControllerBindingsUIPointInside(launcher, x, y) then
		ControllerBindingsUIToggle()
		return true
	end

	if not ControllerBindingsUI.open or button ~= 1 then
		return false
	end

	if ControllerBindingsUIPointInside(ControllerBindingsUI.layout.close, x, y) then
		ControllerBindingsUIClose()
		return true
	end

	if ControllerBindingsUI.layout.modeTabs then
		if ControllerBindingsUIPointInside(ControllerBindingsUI.layout.modeTabs.bindings, x, y) then
			ControllerBindingsUI.mode = "bindings"
			ControllerBindingsUISetToast("Switched to Bindings")
			return true
		elseif ControllerBindingsUIPointInside(ControllerBindingsUI.layout.modeTabs.settings, x, y) then
			ControllerBindingsUI.mode = "settings"
			ControllerBindingsUIRebuildSettings()
			ControllerBindingsUISetToast("Switched to Settings")
			return true
		end
	end

	for i = 1, #ControllerBindingsUI.layout.modalButtons do
		local hit = ControllerBindingsUI.layout.modalButtons[i]
		if ControllerBindingsUIPointInside(hit, x, y) then
			if hit.id == "cancel" then
				ControllerBindingsUICancelModal()
			elseif hit.id == "duplicate" then
				ControllerBindingsUIApplyBinding(ControllerBindingsUI.captureAction, ControllerBindingsUI.pendingInput, true)
			elseif hit.id == "replace" then
				ControllerBindingsUISetToast("Replace unsupported by current API; use Allow Duplicate")
			elseif hit.id == "resetAll" then
				if ControllerBindingsUI.mode == "settings" then
					ControllerBindingsUIResetAllSettings()
					ControllerBindingsUI.modal = nil
				else
					ControllerBindingsUIConfirmResetAll()
				end
			elseif hit.id == "applyPreset" then
				ControllerBindingsUIConfirmApplyPreset()
			end
			return true
		end
	end

	for i = 1, #ControllerBindingsUI.layout.tabs do
		local hit = ControllerBindingsUI.layout.tabs[i]
		if ControllerBindingsUIPointInside(hit, x, y) then
			if ControllerBindingsUI.mode == "settings" then
				ControllerBindingsUI.settingsPageIndex = hit.index
				ControllerBindingsUI.settingsItemIndex = 1
			else
				ControllerBindingsUISelectCategory(hit.index)
			end
			return true
		end
	end

	if ControllerBindingsUI.mode == "settings" then
		for i = 1, #ControllerBindingsUI.layout.rows do
			local hit = ControllerBindingsUI.layout.rows[i]
			if ControllerBindingsUIPointInside(hit, x, y) then
				ControllerBindingsUI.settingsItemIndex = hit.index
				local selectedItem = ControllerBindingsUISelectedSetting()
				if selectedItem and (selectedItem.type == "boolean" or selectedItem.type == "action") then
					ControllerBindingsUIAdjustSelectedSetting(1, false)
				end
				return true
			end
		end
	else
		for i = 1, #ControllerBindingsUI.layout.rows do
			local hit = ControllerBindingsUI.layout.rows[i]
			if ControllerBindingsUIPointInside(hit, x, y) then
				if ControllerBindingsUI.actionIndex == hit.index then
					ControllerBindingsUIStartCapture()
				else
					ControllerBindingsUISelectAction(hit.index)
				end
				return true
			end
		end
	end
	return true
end

function widget:DrawScreen()
	if ControllerBindingsUIGlyphs then ControllerBindingsUIGlyphs.SetStyle("Xbox", "Xbox") end
	ControllerBindingsUITryMigrateLauncher()
	local vsx, vsy = spGetViewGeometry()
	ControllerBindingsUIDrawToggleButton(vsx, vsy)
	if not ControllerBindingsUI.open then
		return
	end
	ControllerBindingsUIDrawMain()
	glColor(1, 1, 1, 1)
end

function widget:GetConfigData()
	return {
		layoutSettings = ControllerBindingsUILayoutSettings,
	}
end

function widget:SetConfigData(data)
	if data and type(data.layoutSettings) == "table" then
		for k, v in pairs(data.layoutSettings) do
			ControllerBindingsUILayoutSettings[k] = ControllerBindingsUILayoutClampSetting(k, v)
		end
	end
end
