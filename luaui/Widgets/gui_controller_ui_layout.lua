--------------------------------------------------------------------------------
-- BAR Controller Support - shared UI settings, contextual hints, layout editor
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Controller UI Layout",
		desc = "Resolution-aware controller UI settings, live hints, and layout editor",
		author = "Kailil / Codex",
		date = "2026-07-19",
		license = "GNU GPL, v2 or later",
		layer = 1000001,
		enabled = true,
		handler = true,
	}
end

local SCHEMA_VERSION = 2
local REFERENCE_WIDTH, REFERENCE_HEIGHT = 1920, 1080
local MIN_EDITOR_W, MIN_EDITOR_H = 460, 360
local spGetViewGeometry = Spring.GetViewGeometry
local glColor, glRect, glText = gl.Color, gl.Rect, gl.Text

local function clamp(value, low, high)
	value = tonumber(value) or low
	return math.max(low, math.min(high, value))
end

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = deepCopy(child) end
	return result
end

local DEFAULTS = {
	global = {
		enabled = true, scale = 1, opacity = 1, fontScale = 1,
		safeMargin = 16, resolutionAware = true,
	},
	components = {
		hints = {
			enabled = true, x = 0.018, y = 0.035, scale = 1, opacity = 1, fontScale = 1,
			iconScale = 1, rowSpacing = 5, columnSpacing = 18, iconTextSpacing = 8,
			padding = 12, maxWidth = 0.52, columns = 2, backgroundOpacity = 0.72,
			textOpacity = 0.96, borderOpacity = 0.72, fadeDuration = 0.18,
			compact = false, anchor = "bottomleft",
		},
		bindingsButton = {
			enabled = true, x = 1360 / 1920, y = 1044 / 1080, scale = 1,
			opacity = 1, fontScale = 1, anchor = "bottomleft",
		},
		radials = { enabled = true, scale = 1, opacity = 1, fontScale = 1, iconScale = 1 },
		buildRadial = { enabled = true, scale = 1, opacity = 1, fontScale = 1, iconScale = 1 },
		tacticalRadial = { enabled = true, scale = 1, opacity = 1, fontScale = 1, iconScale = 1 },
		selectionRadial = { enabled = true, scale = 1, opacity = 1, fontScale = 1, iconScale = 1 },
		factoryRadial = { enabled = true, scale = 1, opacity = 1, fontScale = 1, iconScale = 1 },
		pregame = { enabled = true, scale = 1, opacity = 1, fontScale = 1 },
		reticle = { enabled = true, scale = 1, opacity = 1 },
		notifications = { enabled = true, scale = 1, opacity = 1, fontScale = 1 },
		instructional = { enabled = true, scale = 1, opacity = 1, fontScale = 1 },
		editorLauncher = { enabled = true, x = 0.79, y = 1044 / 1080, scale = 1, opacity = 0.9, fontScale = 1 },
		editor = { enabled = true, x = 0.58, y = 0.18, width = 0.36, height = 0.70, scale = 1, opacity = 1 },
	},
}

local settings = deepCopy(DEFAULTS)
local revision = 1
local viewX, viewY = 1, 1
local automaticScale = 1
local migratedLegacyLauncher = false

local editor = {
	open = false, tab = 1, row = 1, dragging = false, resizing = false,
	dragBindings = false, dragDX = 0, dragDY = 0, startX = 0, startY = 0,
	startW = 0, startH = 0, hits = {}, tabs = {}, close = nil, resetSection = nil,
	resetAll = nil, resize = nil, launcher = nil, bounds = nil,
}

local tabs = { "General", "Button Hints", "Bindings Button", "Radials", "Other UI", "Reset / Defaults" }

local definitions = {
	["General"] = {
		{ "global", "enabled", "Controller UI enabled", "bool" },
		{ "global", "resolutionAware", "Resolution-aware scaling", "bool" },
		{ "global", "scale", "Global scale", "number", 0.60, 2.00, 0.05 },
		{ "global", "opacity", "Global opacity", "number", 0.10, 1.00, 0.05 },
		{ "global", "fontScale", "Global font scale", "number", 0.60, 2.00, 0.05 },
		{ "global", "safeMargin", "Safe-screen margin", "number", 0, 100, 2 },
	},
	["Button Hints"] = {
		{ "hints", "enabled", "Hints visible", "bool" },
		{ "hints", "x", "X position", "number", 0, 1, 0.01 },
		{ "hints", "y", "Y position", "number", 0, 1, 0.01 },
		{ "hints", "scale", "Overall scale", "number", 0.50, 2.00, 0.05 },
		{ "hints", "iconScale", "Button chip size", "number", 0.50, 2.00, 0.05 },
		{ "hints", "fontScale", "Action-label size", "number", 0.60, 2.00, 0.05 },
		{ "hints", "rowSpacing", "Row spacing", "number", 0, 24, 1 },
		{ "hints", "columnSpacing", "Column spacing", "number", 0, 60, 2 },
		{ "hints", "iconTextSpacing", "Chip-to-text spacing", "number", 0, 30, 1 },
		{ "hints", "padding", "Panel padding", "number", 2, 40, 1 },
		{ "hints", "maxWidth", "Maximum screen width", "number", 0.20, 0.95, 0.02 },
		{ "hints", "columns", "Columns (0 = automatic)", "number", 0, 4, 1 },
		{ "hints", "backgroundOpacity", "Background opacity", "number", 0, 1, 0.05 },
		{ "hints", "textOpacity", "Text opacity", "number", 0.10, 1, 0.05 },
		{ "hints", "borderOpacity", "Border opacity", "number", 0, 1, 0.05 },
		{ "hints", "fadeDuration", "Transition duration", "number", 0, 1, 0.05 },
		{ "hints", "compact", "Compact descriptions", "bool" },
	},
	["Bindings Button"] = {
		{ "bindingsButton", "enabled", "Bindings button visible", "bool" },
		{ "bindingsButton", "x", "X position", "number", 0, 1, 0.01 },
		{ "bindingsButton", "y", "Y position", "number", 0, 1, 0.01 },
		{ "bindingsButton", "scale", "Button scale", "number", 0.50, 2.00, 0.05 },
		{ "bindingsButton", "opacity", "Button opacity", "number", 0.10, 1, 0.05 },
		{ "bindingsButton", "fontScale", "Button font scale", "number", 0.60, 2.00, 0.05 },
	},
	["Radials"] = {
		{ "radials", "scale", "All radial scale", "number", 0.50, 2.00, 0.05 },
		{ "radials", "opacity", "All radial opacity", "number", 0.10, 1, 0.05 },
		{ "radials", "fontScale", "Radial label scale", "number", 0.50, 2.00, 0.05 },
		{ "radials", "iconScale", "Radial icon scale", "number", 0.50, 2.00, 0.05 },
		{ "buildRadial", "scale", "Build radial scale", "number", 0.50, 2.00, 0.05 },
		{ "tacticalRadial", "scale", "Tactical radial scale", "number", 0.50, 2.00, 0.05 },
		{ "selectionRadial", "scale", "Selection radial scale", "number", 0.50, 2.00, 0.05 },
		{ "factoryRadial", "scale", "Factory radial scale", "number", 0.50, 2.00, 0.05 },
	},
	["Other UI"] = {
		{ "reticle", "scale", "Reticle scale", "number", 0.50, 2.00, 0.05 },
		{ "notifications", "scale", "Notification scale", "number", 0.50, 2.00, 0.05 },
		{ "notifications", "opacity", "Notification opacity", "number", 0.10, 1, 0.05 },
		{ "pregame", "scale", "Pregame prompt scale", "number", 0.50, 2.00, 0.05 },
		{ "instructional", "scale", "Instructional text scale", "number", 0.50, 2.00, 0.05 },
	},
	["Reset / Defaults"] = {},
}

local ranges = {
	enabled = { false, true }, resolutionAware = { false, true }, compact = { false, true },
	x = { 0, 1 }, y = { 0, 1 }, width = { 0.20, 0.90 }, height = { 0.25, 0.90 },
	scale = { 0.50, 2.00 }, opacity = { 0, 1 }, fontScale = { 0.50, 2.00 }, iconScale = { 0.50, 2.00 },
	rowSpacing = { 0, 24 }, columnSpacing = { 0, 60 }, iconTextSpacing = { 0, 30 }, padding = { 2, 40 },
	maxWidth = { 0.20, 0.95 }, columns = { 0, 4 }, backgroundOpacity = { 0, 1 },
	textOpacity = { 0.10, 1 }, borderOpacity = { 0, 1 }, fadeDuration = { 0, 1 }, safeMargin = { 0, 100 },
}

local function validateValue(key, value, fallback)
	if key == "enabled" or key == "resolutionAware" or key == "compact" then return value == true end
	if key == "anchor" then return type(value) == "string" and value or fallback end
	local range = ranges[key]
	if range then return clamp(value, range[1], range[2]) end
	return type(value) == type(fallback) and value or fallback
end

local function mergeValidated(target, source, defaults)
	if type(source) ~= "table" then return end
	for key, fallback in pairs(defaults) do
		if source[key] ~= nil then target[key] = validateValue(key, source[key], fallback) end
	end
end

local function recalculateScale()
	viewX, viewY = spGetViewGeometry()
	viewX, viewY = math.max(1, viewX or 1), math.max(1, viewY or 1)
	if settings.global.resolutionAware then
		automaticScale = clamp(math.min(viewX / REFERENCE_WIDTH, viewY / REFERENCE_HEIGHT), 0.62, 1.60)
	else
		automaticScale = 1
	end
end

local function touch()
	revision = revision + 1
	recalculateScale()
end

local function getScope(scope)
	if scope == "global" then return settings.global, DEFAULTS.global end
	return settings.components[scope], DEFAULTS.components[scope]
end

local function setValue(scope, key, value)
	local target, defaultsForScope = getScope(scope)
	if not target or defaultsForScope[key] == nil then return nil end
	target[key] = validateValue(key, value, defaultsForScope[key])
	touch()
	return target[key]
end

local function resetComponent(scope)
	if scope == "global" then settings.global = deepCopy(DEFAULTS.global)
	elseif DEFAULTS.components[scope] then settings.components[scope] = deepCopy(DEFAULTS.components[scope]) end
	touch()
end

local function resetAll()
	settings = deepCopy(DEFAULTS)
	migratedLegacyLauncher = false
	touch()
end

local function effectiveScale(component)
	local item = settings.components[component] or {}
	return automaticScale * settings.global.scale * (item.scale or 1)
end

local function effectiveOpacity(component)
	local item = settings.components[component] or {}
	return settings.global.opacity * (item.opacity or 1)
end

local function effectiveFontScale(component)
	local item = settings.components[component] or {}
	return automaticScale * settings.global.scale * settings.global.fontScale * (item.fontScale or 1)
end

local function componentBounds(component, baseWidth, baseHeight)
	local item = settings.components[component]
	if not item then return nil end
	local scale = effectiveScale(component)
	local width, height = baseWidth * scale, baseHeight * scale
	local margin = settings.global.safeMargin * automaticScale
	local x1 = clamp(item.x * viewX, margin, math.max(margin, viewX - margin - width))
	local y1 = clamp(item.y * viewY, margin, math.max(margin, viewY - margin - height))
	return { x1 = x1, y1 = y1, x2 = x1 + width, y2 = y1 + height, width = width, height = height, scale = scale }
end

local function pointInside(hit, x, y)
	return hit and x >= hit.x1 and x <= hit.x2 and y >= hit.y1 and y <= hit.y2
end

local function support()
	return WG and WG.BARControllerSupport
end

local inputLabels = {
	back = "Back", start = "Start", dpadUp = "D-pad Up", dpadDown = "D-pad Down",
	dpadLeft = "D-pad Left", dpadRight = "D-pad Right", leftStickClick = "L3", rightStickClick = "R3",
	leftStick = "Left Stick", rightStick = "Right Stick", none = "Unbound",
}

local function inputLabel(input)
	return inputLabels[input] or tostring(input or "Unbound")
end

local hintRegistry = {}
local hintRevision = 1
local visibleHints = {}
local lastContextSignature, lastBindingRevision = "", -1
local hintRefreshElapsed = 0
local hintAlpha = 1

local function addHint(def)
	if type(def) == "table" and type(def.id) == "string" then
		hintRegistry[def.id] = def
		hintRevision = hintRevision + 1
	end
end

local function bind(action, label, when, priority, options)
	options = options or {}
	addHint({ id = options.id or action .. ":" .. label, action = action, label = label,
		compactLabel = options.compactLabel, when = when, priority = priority or 100,
		hold = options.hold, group = options.group or "gameplay" })
end

local function isEditor(c) return c.layoutEditorOpen end
local function isBindings(c) return c.bindingsOpen and not c.layoutEditorOpen end
local function isPregame(c) return c.pregame and not c.bindingsOpen and not c.layoutEditorOpen end
local function isMouse(c) return c.mouseMode and not c.bindingsOpen and not c.layoutEditorOpen end
local function isPlacement(c) return c.buildPlacement and not c.bindingsOpen and not c.layoutEditorOpen end
local function isBuild(c) return c.buildMenuOpen and not c.buildPlacement and not c.bindingsOpen and not c.layoutEditorOpen end
local function isFactoryBuild(c) return isBuild(c) and c.factoryRadialOpen end
local function isConstructorBuild(c) return isBuild(c) and not c.factoryRadialOpen end
local function isTactical(c) return c.tacticalRadialOpen and not c.bindingsOpen and not c.layoutEditorOpen end
local function isSelectionRadial(c) return c.selectionRadialOpen and not c.bindingsOpen and not c.layoutEditorOpen end
local function isDgun(c) return c.dgunMode and not c.bindingsOpen and not c.layoutEditorOpen end
local function isStaged(c) return c.stagedTactical and not c.bindingsOpen and not c.layoutEditorOpen end
local function isAreaSelection(c) return c.areaSelection and not c.selectionRadialOpen and not c.bindingsOpen and not c.layoutEditorOpen end
local function isCommandLayer(c) return c.commandLayer and not c.bindingsOpen and not c.layoutEditorOpen end
local function hasModalGameplayContext(c)
	return c.buildPlacement or c.buildMenuOpen or c.tacticalRadialOpen or c.selectionRadialOpen
		or c.dgunMode or c.stagedTactical or c.areaSelection or c.pregame or c.mouseMode
end
local function isGroupLayer(c) return c.controlGroupLayer and not c.commandLayer and not hasModalGameplayContext(c) and not c.bindingsOpen and not c.layoutEditorOpen end
local function isPitchLayer(c) return c.pitchLayer and not c.commandLayer and not c.controlGroupLayer and not hasModalGameplayContext(c) and not c.bindingsOpen and not c.layoutEditorOpen end
local function isNormal(c)
	return not c.pregame and not c.mouseMode and not c.bindingsOpen and not c.layoutEditorOpen
		and not c.buildPlacement and not c.buildMenuOpen and not c.tacticalRadialOpen and not c.selectionRadialOpen
		and not c.dgunMode and not c.stagedTactical and not c.areaSelection
		and not c.commandLayer
		and not c.controlGroupLayer and not c.pitchLayer
end

bind("cancel", "Close Layout Editor", isEditor, 1)
addHint({ id = "editor-nav", inputs = { "dpadUp", "dpadDown", "dpadLeft", "dpadRight" }, label = "Navigate / Adjust", when = isEditor, priority = 2 })
addHint({ id = "editor-tabs", inputs = { "LB", "RB" }, label = "Change Section", when = isEditor, priority = 3 })
bind("select", "Edit Binding", isBindings, 1)
bind("cancel", "Close Bindings", isBindings, 2)
bind("radialPrevPage", "Previous Category", isBindings, 3)
bind("radialNextPage", "Next Category", isBindings, 4)
bind("controlGroupModifier", "Bindings / Settings Tab", isBindings, 5)
bind("select", "Click / Set Start", isPregame, 1)
bind("smartAction", "Click / Set Start", isPregame, 2)
bind("pitchModifier", "Camera Tilt / Rotate", isPregame, 3)
addHint({ id = "pregame-stick", inputs = { "rightStick" }, label = "Move Cursor", when = isPregame, priority = 4 })
bind("select", "Mouse Click", isMouse, 1)
bind("smartAction", "Mouse Click", isMouse, 2)
addHint({ id = "mouse-stick", inputs = { "rightStick" }, label = "Move Cursor", when = isMouse, priority = 3 })
bind("place", "Confirm Placement", isPlacement, 1)
bind("placeStay", "Place and Continue", isPlacement, 2)
bind("cancelPlacement", "Cancel Placement", isPlacement, 3)
bind("rotateBuildingLeft", "Rotate Left", isPlacement, 4)
bind("rotateBuildingRight", "Rotate Right", isPlacement, 5)
bind("spacingUp", "Increase Spacing", isPlacement, 6)
bind("spacingDown", "Decrease Spacing", isPlacement, 7)
bind("patternPrev", "Cycle Pattern", isPlacement, 8)
bind("patternPrev", "Force Grid Pattern", isPlacement, 9, { hold = true, id = "placement-pattern-hold" })
bind("appendQueueModifier", "Append to Queue", isPlacement, 10)
bind("insertNextCommandModifier", "Insert Next", isPlacement, 11)
bind("radialSelect", "Choose / Place", isConstructorBuild, 1)
bind("radialQuick", "Quick Place", isConstructorBuild, 2)
bind("radialCancel", "Close Build Radial", isConstructorBuild, 3)
bind("radialPrevPage", "Previous Page", isConstructorBuild, 4)
bind("radialNextPage", "Next Page", isConstructorBuild, 5)
bind("radialSelect", "Queue +1", isFactoryBuild, 1, { id = "factory-queue-one" })
bind("appendQueueModifier", "Queue +5 Modifier", isFactoryBuild, 2, { id = "factory-queue-five" })
bind("radialQuick", "Dequeue -1", isFactoryBuild, 3, { id = "factory-dequeue-one" })
bind("radialCancel", "Close Factory Radial", isFactoryBuild, 4, { id = "factory-close" })
bind("radialPrevPage", "Previous Page", isFactoryBuild, 5, { id = "factory-prev" })
bind("radialNextPage", "Next Page", isFactoryBuild, 6, { id = "factory-next" })
bind("tacticalSelect", "Choose Command", isTactical, 1)
bind("tacticalCancel", "Close Tactical Radial", isTactical, 2)
bind("tacticalClose", "Close Tactical Radial", isTactical, 3)
bind("commandUp", "Guard / Patrol", isTactical, 4)
bind("commandDown", "Reclaim", isTactical, 5)
bind("radialSelect", "Choose Selection Filter", isSelectionRadial, 1)
bind("radialCancel", "Cancel Selection", isSelectionRadial, 2)
bind("radialPrevPage", "Previous Filter", isSelectionRadial, 3)
bind("radialNextPage", "Next Filter", isSelectionRadial, 4)
addHint({ id = "dgun-fire", inputs = { "RT" }, label = "Fire DGUN", when = isDgun, priority = 1 })
bind("cancel", "Exit DGUN", isDgun, 2)
addHint({ id = "dgun-aim", inputs = { "rightStick" }, label = "Aim", when = isDgun, priority = 3 })
bind("place", "Confirm Tactical Target", isStaged, 1)
bind("cancelPlacement", "Cancel Tactical Target", isStaged, 2)
bind("appendQueueModifier", "Repeat / Append", isStaged, 3)
bind("select", "Release to Select Area", isAreaSelection, 1)
bind("cancel", "Cancel Area Selection", isAreaSelection, 2)
addHint({ id = "area-radius", inputs = { "rightStick" }, label = "Adjust Radius / Filter", when = isAreaSelection, priority = 3 })
bind("commandUp", "Guard / Patrol", isCommandLayer, 1)
bind("commandDown", "Reclaim", isCommandLayer, 2)
bind("smartAction", "Attack / Attack-Move", isCommandLayer, 3)
bind("cancel", "Stop Selected", isCommandLayer, 4)
bind("buildRadial", "Tactical Radial", isCommandLayer, 5)
bind("groupSlotUp", "Next Group Slot", isGroupLayer, 1)
bind("groupSlotDown", "Previous Group Slot", isGroupLayer, 2)
bind("groupRecallOrAssign", "Recall Group", isGroupLayer, 3)
bind("groupAssign", "Assign Type / Future Units", isGroupLayer, 4)
bind("groupClear", "Clear Group", isGroupLayer, 5)
bind("idlePrev", "Previous Idle Unit Type", isPitchLayer, 1)
bind("idleNext", "Next Idle Unit Type", isPitchLayer, 2)
bind("pitchModifier", "Camera Pitch Modifier", isPitchLayer, 3)
bind("select", "Select Unit", isNormal, 1)
bind("select", "Selection Radial", isNormal, 2, { hold = true, id = "normal-select-hold" })
bind("smartAction", "Smart Action", function(c) return isNormal(c) and not c.hasTransport end, 3)
bind("smartAction", "Load / Move Transport", function(c) return isNormal(c) and c.hasTransport end, 3, { id = "normal-transport-smart" })
bind("smartAction", "Draw Move / Build Path", function(c) return isNormal(c) and c.hasSelection end, 4, { hold = true, id = "normal-smart-hold" })
bind("cancel", "Clear Selection", function(c) return isNormal(c) and c.hasSelection end, 5)
bind("buildRadial", "Build / Factory Radial", function(c) return isNormal(c) and (c.hasBuilder or c.hasFactory) end, 6)
bind("commandLayer", "Tactical Command Layer", function(c) return isNormal(c) and c.hasSelection end, 7)
bind("pitchModifier", "Camera Pitch", isNormal, 8)
bind("idlePrev", "Previous Idle Unit", isNormal, 9)
bind("idleNext", "Next Idle Unit", isNormal, 10)
bind("controlGroupModifier", "Control Groups", isNormal, 11)

addHint({ id = "shortcut-mouse", shortcut = "mouseMode", label = "Toggle Mouse Mode", priority = 900,
	when = function(c) return not c.bindingsOpen and not c.layoutEditorOpen end })
addHint({ id = "shortcut-editor", shortcut = "uiSettings", label = "Controller UI Settings", hold = true, priority = 901,
	when = function(c) return not c.bindingsOpen end })

local function contextSignature(context)
	local keys = { "pregame", "mouseMode", "bindingsOpen", "layoutEditorOpen", "buildMenuOpen", "buildPlacement",
		"factoryRadialOpen", "tacticalRadialOpen", "selectionRadialOpen", "areaSelection", "stagedTactical", "dgunMode",
		"selectedCount", "hasBuilder", "hasFactory", "hasTransport", "hasWorldTarget", "hoverTargetType", "smartTargetType",
		"commandLayer", "controlGroupLayer", "pitchLayer" }
	local parts = {}
	for i, key in ipairs(keys) do parts[i] = tostring(context[key]) end
	return table.concat(parts, "|")
end

local function resolveInputs(def, api)
	if def.action and type(api.GetBinding) == "function" then return { api.GetBinding(def.action) } end
	if def.shortcut and type(api.GetShortcutBinding) == "function" then return api.GetShortcutBinding(def.shortcut) end
	return def.inputs
end

local function rebuildHints(context, api)
	visibleHints = {}
	hintAlpha = settings.components.hints.fadeDuration > 0 and 0 or 1
	for _, def in pairs(hintRegistry) do
		local available = type(def.when) ~= "function" or def.when(context)
		if available then
			local inputs = resolveInputs(def, api)
			if type(inputs) == "table" and #inputs > 0 and inputs[1] ~= "none" then
				visibleHints[#visibleHints + 1] = {
					id = def.id, inputs = inputs, label = def.label, compactLabel = def.compactLabel,
					hold = def.hold, priority = def.priority or 100, group = def.group,
				}
			end
		end
	end
	table.sort(visibleHints, function(a, b) return a.priority < b.priority end)
end

local function formatInputs(hint)
	local labels = {}
	for i, input in ipairs(hint.inputs) do labels[i] = inputLabel(input) end
	local prefix = hint.hold and "Hold " or ""
	return prefix .. table.concat(labels, " + ")
end

local function currentRows()
	return definitions[tabs[editor.tab]] or {}
end

local function currentRow()
	local rows = currentRows()
	editor.row = math.max(1, math.min(math.max(1, #rows), editor.row))
	return rows[editor.row]
end

local function adjustRow(delta)
	local row = currentRow()
	if not row then return end
	local target = getScope(row[1])
	local current = target and target[row[2]]
	if row[4] == "bool" then setValue(row[1], row[2], not current)
	else setValue(row[1], row[2], clamp((tonumber(current) or 0) + delta * row[7], row[5], row[6])) end
end

local function setEditorOpen(open)
	editor.open = not not open
	local api = support()
	if api and type(api.SetLayoutEditorOpen) == "function" then api.SetLayoutEditorOpen(editor.open) end
end

local function toggleEditor() setEditorOpen(not editor.open) end

local function drawOutline(x1, y1, x2, y2, color)
	glColor(color[1], color[2], color[3], color[4])
	glRect(x1, y1, x2, y1 + 1); glRect(x1, y2 - 1, x2, y2)
	glRect(x1, y1, x1 + 1, y2); glRect(x2 - 1, y1, x2, y2)
end

local function drawHints()
	if not settings.global.enabled or not settings.components.hints.enabled or #visibleHints == 0 then return end
	local component = settings.components.hints
	local scale = effectiveScale("hints")
	local fontScale = effectiveFontScale("hints")
	local fontSize = 14 * fontScale
	local rowHeight = math.max(22 * scale, fontSize + component.rowSpacing * scale)
	local columns = math.floor(component.columns or 0)
	if columns <= 0 then columns = viewX < 1100 and 1 or 2 end
	columns = math.max(1, math.min(columns, #visibleHints))
	local rows = math.ceil(#visibleHints / columns)
	local maxWidth = component.maxWidth * viewX
	local panelWidth = math.min(maxWidth, math.max(300 * scale, columns * 285 * scale))
	local panelHeight = component.padding * 2 * scale + rows * rowHeight
	local margin = settings.global.safeMargin * automaticScale
	local x1 = clamp(component.x * viewX, margin, math.max(margin, viewX - margin - panelWidth))
	local y1 = clamp(component.y * viewY, margin, math.max(margin, viewY - margin - panelHeight))
	local opacity = effectiveOpacity("hints") * hintAlpha
	glColor(0.018, 0.028, 0.04, component.backgroundOpacity * opacity)
	glRect(x1, y1, x1 + panelWidth, y1 + panelHeight)
	drawOutline(x1, y1, x1 + panelWidth, y1 + panelHeight, { 0.28, 0.68, 0.78, component.borderOpacity * opacity })
	local columnWidth = (panelWidth - component.padding * 2 * scale - (columns - 1) * component.columnSpacing * scale) / columns
	for index, hint in ipairs(visibleHints) do
		local col = math.floor((index - 1) / rows)
		local row = (index - 1) % rows
		local rx = x1 + component.padding * scale + col * (columnWidth + component.columnSpacing * scale)
		local ry = y1 + panelHeight - component.padding * scale - (row + 1) * rowHeight
		local chip = formatInputs(hint)
		local chipWidth = math.min(columnWidth * 0.46, math.max(38 * scale, (#chip * 7 + 14) * scale * component.iconScale))
		glColor(0.08, 0.18, 0.23, 0.94 * opacity)
		glRect(rx, ry + 2 * scale, rx + chipWidth, ry + rowHeight - 2 * scale)
		drawOutline(rx, ry + 2 * scale, rx + chipWidth, ry + rowHeight - 2 * scale, { 0.36, 0.82, 0.92, 0.9 * opacity })
		glColor(0.76, 0.96, 1, component.textOpacity * opacity)
		glText(chip, rx + chipWidth * 0.5, ry + (rowHeight - fontSize) * 0.5, fontSize * 0.82 * component.iconScale, "oc")
		local label = component.compact and (hint.compactLabel or hint.label) or hint.label
		glColor(0.94, 0.98, 1, component.textOpacity * opacity)
		glText(label, rx + chipWidth + component.iconTextSpacing * scale, ry + (rowHeight - fontSize) * 0.5, fontSize, "o")
	end
end

local function drawHoldProgress()
	local api = support()
	if not api or type(api.GetBackStartHoldProgress) ~= "function" then return end
	local progress = api.GetBackStartHoldProgress()
	if type(progress) ~= "number" or progress < 0.12 or progress >= 1 then return end
	local width, height = math.min(320, viewX * 0.28), 12
	local x1, y1 = (viewX - width) * 0.5, viewY * 0.18
	glColor(0.02, 0.03, 0.04, 0.72); glRect(x1, y1, x1 + width, y1 + height)
	glColor(0.34, 0.86, 0.92, 0.94); glRect(x1 + 2, y1 + 2, x1 + 2 + (width - 4) * progress, y1 + height - 2)
end

local function drawEditorLauncher()
	local component = settings.components.editorLauncher
	if not settings.global.enabled or not component.enabled then editor.launcher = nil; return end
	local hit = componentBounds("editorLauncher", 116, 28)
	editor.launcher = hit
	local opacity = effectiveOpacity("editorLauncher")
	glColor(editor.open and 0.12 or 0.035, editor.open and 0.38 or 0.07, editor.open and 0.42 or 0.09, 0.88 * opacity)
	glRect(hit.x1, hit.y1, hit.x2, hit.y2)
	drawOutline(hit.x1, hit.y1, hit.x2, hit.y2, { 0.34, 0.78, 0.86, 0.9 * opacity })
	glColor(0.82, 0.96, 1, opacity)
	glText("UI Layout", (hit.x1 + hit.x2) * 0.5, hit.y1 + 7 * hit.scale, 12 * effectiveFontScale("editorLauncher"), "oc")
end

local function editorBounds()
	local component = settings.components.editor
	local margin = math.min(settings.global.safeMargin, math.max(0, math.min(viewX, viewY) * 0.08))
	local availableW, availableH = math.max(100, viewX - margin * 2), math.max(100, viewY - margin * 2)
	local minW, minH = math.min(MIN_EDITOR_W, availableW), math.min(MIN_EDITOR_H, availableH)
	local width = clamp(component.width * viewX, minW, availableW)
	local height = clamp(component.height * viewY, minH, availableH)
	local x1 = clamp(component.x * viewX, margin, math.max(margin, viewX - margin - width))
	local y1 = clamp(component.y * viewY, margin, math.max(margin, viewY - margin - height))
	return { x1 = x1, y1 = y1, x2 = x1 + width, y2 = y1 + height, width = width, height = height }
end

local function drawEditor()
	if not editor.open then editor.bounds = nil; return end
	local b = editorBounds(); editor.bounds = b
	local opacity = effectiveOpacity("editor")
	glColor(0.018, 0.026, 0.036, 0.96 * opacity); glRect(b.x1, b.y1, b.x2, b.y2)
	drawOutline(b.x1, b.y1, b.x2, b.y2, { 0.34, 0.82, 0.9, opacity })
	local headerH = 42
	glColor(0.055, 0.13, 0.16, 0.98 * opacity); glRect(b.x1, b.y2 - headerH, b.x2, b.y2)
	glColor(0.92, 0.99, 1, opacity); glText("Controller UI Layout Editor", b.x1 + 16, b.y2 - 28, 20, "o")
	editor.close = { x1 = b.x2 - 38, y1 = b.y2 - 34, x2 = b.x2 - 10, y2 = b.y2 - 8 }
	glColor(0.22, 0.07, 0.07, 0.95); glRect(editor.close.x1, editor.close.y1, editor.close.x2, editor.close.y2)
	glColor(1, 0.82, 0.8, 1); glText("X", (editor.close.x1 + editor.close.x2) * 0.5, editor.close.y1 + 6, 16, "oc")

	editor.tabs = {}
	local tabY2, tabY1 = b.y2 - headerH - 8, b.y2 - headerH - 42
	local tabW = (b.width - 20) / #tabs
	for i, name in ipairs(tabs) do
		local x1 = b.x1 + 10 + (i - 1) * tabW
		local hit = { x1 = x1, y1 = tabY1, x2 = x1 + tabW - 3, y2 = tabY2, index = i }
		editor.tabs[i] = hit
		glColor(i == editor.tab and 0.12 or 0.045, i == editor.tab and 0.30 or 0.08, i == editor.tab and 0.34 or 0.10, 0.96)
		glRect(hit.x1, hit.y1, hit.x2, hit.y2)
		glColor(0.82, 0.96, 1, 1); glText(name, (hit.x1 + hit.x2) * 0.5, hit.y1 + 8, 12, "oc")
	end

	editor.hits = {}
	local rows = currentRows()
	local rowY, rowH = tabY1 - 14, 34
	if #rows == 0 then
		glColor(0.85, 0.94, 0.98, 1)
		glText("Reset the current section or all controller UI settings below.", b.x1 + 22, rowY - 36, 16, "o")
	end
	for i, row in ipairs(rows) do
		local y2 = rowY - (i - 1) * (rowH + 3)
		local y1 = y2 - rowH
		if y1 < b.y1 + 62 then break end
		local selected = i == editor.row
		glColor(selected and 0.10 or 0.035, selected and 0.24 or 0.06, selected and 0.28 or 0.08, 0.94)
		glRect(b.x1 + 16, y1, b.x2 - 16, y2)
		if selected then drawOutline(b.x1 + 16, y1, b.x2 - 16, y2, { 0.36, 0.86, 0.94, 0.9 }) end
		local scope = getScope(row[1]); local value = scope and scope[row[2]]
		local valueText = row[4] == "bool" and (value and "ON" or "OFF") or string.format(row[7] >= 1 and "%.0f" or "%.2f", value or 0)
		glColor(0.92, 0.97, 1, 1); glText(row[3], b.x1 + 28, y1 + 9, 14, "o")
		local minus = { x1 = b.x2 - 154, y1 = y1 + 4, x2 = b.x2 - 120, y2 = y2 - 4 }
		local plus = { x1 = b.x2 - 50, y1 = y1 + 4, x2 = b.x2 - 16, y2 = y2 - 4 }
		glColor(0.08, 0.16, 0.19, 0.96); glRect(minus.x1, minus.y1, minus.x2, minus.y2); glRect(plus.x1, plus.y1, plus.x2, plus.y2)
		glColor(0.72, 0.93, 0.98, 1); glText(row[4] == "bool" and "" or "−", (minus.x1 + minus.x2) * 0.5, minus.y1 + 6, 16, "oc")
		glText(valueText, b.x2 - 85, y1 + 9, 14, "oc")
		glText(row[4] == "bool" and "Toggle" or "+", (plus.x1 + plus.x2) * 0.5, plus.y1 + 6, row[4] == "bool" and 10 or 16, "oc")
		editor.hits[#editor.hits + 1] = { x1 = b.x1 + 16, y1 = y1, x2 = b.x2 - 16, y2 = y2, index = i, minus = minus, plus = plus }
	end

	editor.resetSection = { x1 = b.x1 + 18, y1 = b.y1 + 16, x2 = b.x1 + 178, y2 = b.y1 + 48 }
	editor.resetAll = { x1 = b.x1 + 190, y1 = b.y1 + 16, x2 = b.x1 + 320, y2 = b.y1 + 48 }
	for _, button in ipairs({ editor.resetSection, editor.resetAll }) do glColor(0.12, 0.18, 0.21, 0.98); glRect(button.x1, button.y1, button.x2, button.y2) end
	glColor(0.86, 0.96, 1, 1); glText("Reset Section", 98 + b.x1, b.y1 + 25, 13, "oc"); glText("Reset All", b.x1 + 255, b.y1 + 25, 13, "oc")
	editor.resize = { x1 = b.x2 - 22, y1 = b.y1, x2 = b.x2, y2 = b.y1 + 22 }
	glColor(0.35, 0.78, 0.86, 0.8); glRect(b.x2 - 16, b.y1 + 4, b.x2 - 4, b.y1 + 7); glRect(b.x2 - 10, b.y1 + 10, b.x2 - 4, b.y1 + 13)

	local bb = componentBounds("bindingsButton", 110, 28)
	if bb then drawOutline(bb.x1 - 3, bb.y1 - 3, bb.x2 + 3, bb.y2 + 3, { 0.35, 0.95, 0.65, 0.95 }) end
end

function widget:Initialize()
	recalculateScale()
	WG.ControllerUISettings = {
		SCHEMA_VERSION = SCHEMA_VERSION, REFERENCE_WIDTH = REFERENCE_WIDTH, REFERENCE_HEIGHT = REFERENCE_HEIGHT,
		Get = function(scope, key) local target = getScope(scope); return target and target[key] end,
		Set = setValue, GetComponent = function(name) return settings.components[name] end,
		GetGlobal = function() return settings.global end, GetEffectiveScale = effectiveScale,
		GetEffectiveOpacity = effectiveOpacity, GetEffectiveFontScale = effectiveFontScale,
		GetComponentBounds = componentBounds, GetRevision = function() return revision end,
		ResetComponent = resetComponent, ResetAll = resetAll, ToggleEditor = toggleEditor,
		OpenEditor = function() setEditorOpen(true) end, CloseEditor = function() setEditorOpen(false) end,
		IsEditorOpen = function() return editor.open end,
		MigrateLegacyBindingsButton = function(rightOffset, topOffset)
			if migratedLegacyLauncher then return false end
			local x = (viewX - (tonumber(rightOffset) or 560)) / viewX
			local y = (viewY - (tonumber(topOffset) or 8) - 28) / viewY
			settings.components.bindingsButton.x = clamp(x, 0, 1)
			settings.components.bindingsButton.y = clamp(y, 0, 1)
			migratedLegacyLauncher = true; touch(); return true
		end,
	}
	WG.ControllerHintRegistry = {
		Register = addHint,
		Unregister = function(id) hintRegistry[id] = nil; hintRevision = hintRevision + 1 end,
		GetVisibleActions = function() return visibleHints end,
		Invalidate = function() lastContextSignature = "" end,
	}
	if widgetHandler and widgetHandler.AddAction then widgetHandler:AddAction("bar_controller_ui", toggleEditor, nil, "t") end
end

function widget:Shutdown()
	setEditorOpen(false)
	if widgetHandler and widgetHandler.RemoveAction then widgetHandler:RemoveAction("bar_controller_ui") end
	WG.ControllerUISettings = nil; WG.ControllerHintRegistry = nil
end

function widget:ViewResize(vsx, vsy)
	viewX, viewY = math.max(1, vsx or 1), math.max(1, vsy or 1)
	recalculateScale()
	local b = editorBounds()
	settings.components.editor.x, settings.components.editor.y = b.x1 / viewX, b.y1 / viewY
	local bb = componentBounds("bindingsButton", 110, 28)
	if bb then settings.components.bindingsButton.x, settings.components.bindingsButton.y = bb.x1 / viewX, bb.y1 / viewY end
end

function widget:Update(dt)
	local api = support()
	local fadeDuration = settings.components.hints.fadeDuration or 0
	if fadeDuration <= 0 then hintAlpha = 1 else hintAlpha = math.min(1, hintAlpha + (dt or 0) / fadeDuration) end
	if api and type(api.SetLayoutEditorOpen) == "function" then api.SetLayoutEditorOpen(editor.open) end
	if editor.open and api and type(api.IsInputPressed) == "function" then
		if api.IsInputPressed(api.GetBinding and api.GetBinding("cancel") or "B") then setEditorOpen(false)
		elseif api.IsInputPressed("LB") then editor.tab = ((editor.tab - 2) % #tabs) + 1; editor.row = 1
		elseif api.IsInputPressed("RB") then editor.tab = (editor.tab % #tabs) + 1; editor.row = 1
		elseif api.IsInputPressed("dpadUp") then editor.row = math.max(1, editor.row - 1)
		elseif api.IsInputPressed("dpadDown") then editor.row = math.min(math.max(1, #currentRows()), editor.row + 1)
		elseif api.IsInputPressed("dpadLeft") then adjustRow(-1)
		elseif api.IsInputPressed("dpadRight") then adjustRow(1) end
	end

	hintRefreshElapsed = hintRefreshElapsed + (dt or 0)
	if hintRefreshElapsed < 0.12 or not api or type(api.GetContextSnapshot) ~= "function" then return end
	hintRefreshElapsed = 0
	local context = api.GetContextSnapshot()
	if type(context) ~= "table" then return end
	local signature = contextSignature(context) .. "|" .. tostring(hintRevision) .. "|" .. tostring(revision)
	local bindingRevision = type(api.GetBindingRevision) == "function" and api.GetBindingRevision() or 0
	if signature ~= lastContextSignature or bindingRevision ~= lastBindingRevision then
		lastContextSignature, lastBindingRevision = signature, bindingRevision
		rebuildHints(context, api)
	end
end

function widget:DrawScreen()
	drawHints(); drawHoldProgress(); drawEditorLauncher(); drawEditor(); glColor(1, 1, 1, 1)
end

function widget:MousePress(x, y, button)
	if button ~= 1 then return false end
	if pointInside(editor.launcher, x, y) then toggleEditor(); return true end
	if not editor.open then return false end
	if pointInside(editor.close, x, y) then setEditorOpen(false); return true end
	for _, hit in ipairs(editor.tabs) do if pointInside(hit, x, y) then editor.tab = hit.index; editor.row = 1; return true end end
	if pointInside(editor.resetSection, x, y) then
		local tab = tabs[editor.tab]
		if tab == "General" then resetComponent("global")
		elseif tab == "Button Hints" then resetComponent("hints")
		elseif tab == "Bindings Button" then resetComponent("bindingsButton")
		elseif tab == "Radials" then for _, name in ipairs({ "radials", "buildRadial", "tacticalRadial", "selectionRadial", "factoryRadial" }) do resetComponent(name) end
		elseif tab == "Other UI" then for _, name in ipairs({ "reticle", "notifications", "pregame", "instructional" }) do resetComponent(name) end
		end
		return true
	end
	if pointInside(editor.resetAll, x, y) then resetAll(); return true end
	for _, hit in ipairs(editor.hits) do
		if pointInside(hit, x, y) then
			editor.row = hit.index
			if pointInside(hit.minus, x, y) then adjustRow(-1) elseif pointInside(hit.plus, x, y) then adjustRow(1) end
			return true
		end
	end
	local bb = componentBounds("bindingsButton", 110, 28)
	if pointInside(bb, x, y) then editor.dragBindings = true; editor.dragDX = x - bb.x1; editor.dragDY = y - bb.y1; return true end
	if pointInside(editor.resize, x, y) then
		editor.resizing = true; editor.startX, editor.startY = x, y
		editor.startW, editor.startH = editor.bounds.width, editor.bounds.height; return true
	end
	if editor.bounds and y >= editor.bounds.y2 - 42 and pointInside(editor.bounds, x, y) then
		editor.dragging = true; editor.dragDX = x - editor.bounds.x1; editor.dragDY = y - editor.bounds.y1; return true
	end
	return pointInside(editor.bounds, x, y)
end

function widget:MouseMove(x, y)
	if editor.dragBindings then
		local scale = effectiveScale("bindingsButton")
		local margin = settings.global.safeMargin * automaticScale
		local px = clamp(x - editor.dragDX, margin, viewX - margin - 110 * scale)
		local py = clamp(y - editor.dragDY, margin, viewY - margin - 28 * scale)
		settings.components.bindingsButton.x, settings.components.bindingsButton.y = px / viewX, py / viewY; touch(); return true
	elseif editor.dragging then
		local b = editorBounds(); local margin = settings.global.safeMargin
		local px = clamp(x - editor.dragDX, margin, viewX - margin - b.width)
		local py = clamp(y - editor.dragDY, margin, viewY - margin - b.height)
		settings.components.editor.x, settings.components.editor.y = px / viewX, py / viewY; touch(); return true
	elseif editor.resizing then
		local maxW = math.max(100, viewX - editor.bounds.x1 - settings.global.safeMargin)
		local maxH = math.max(100, viewY - editor.bounds.y1 - settings.global.safeMargin)
		local width = clamp(editor.startW + (x - editor.startX), math.min(MIN_EDITOR_W, maxW), maxW)
		local height = clamp(editor.startH - (y - editor.startY), math.min(MIN_EDITOR_H, maxH), maxH)
		settings.components.editor.width, settings.components.editor.height = width / viewX, height / viewY; touch(); return true
	end
	return editor.open and pointInside(editor.bounds, x, y) or false
end

function widget:MouseRelease()
	local handled = editor.dragBindings or editor.dragging or editor.resizing
	editor.dragBindings, editor.dragging, editor.resizing = false, false, false
	return handled
end

function widget:KeyPress()
	if not editor.open then return false end
	return true
end

function widget:TextCommand(command)
	local normalized = string.lower(tostring(command or "")):gsub("[%s_%-]", "")
	if normalized == "barcontrollerui" then toggleEditor(); return true end
	return false
end

function widget:GetConfigData()
	return { schemaVersion = SCHEMA_VERSION, settings = settings, editorOpen = false,
		migratedLegacyLauncher = migratedLegacyLauncher }
end

function widget:SetConfigData(data)
	if type(data) ~= "table" or type(data.settings) ~= "table" then return end
	local savedSchema = tonumber(data.schemaVersion)
	if savedSchema ~= nil and savedSchema ~= 1 and savedSchema ~= SCHEMA_VERSION then
		settings = deepCopy(DEFAULTS); migratedLegacyLauncher = false; touch(); return
	end
	-- Schema 1 used the same global/components shape; known fields are merged
	-- through current validators and newly introduced fields retain defaults.
	local saved = data.settings
	mergeValidated(settings.global, saved.global, DEFAULTS.global)
	if type(saved.components) == "table" then
		for name, componentDefaults in pairs(DEFAULTS.components) do
			mergeValidated(settings.components[name], saved.components[name], componentDefaults)
		end
	end
	migratedLegacyLauncher = data.migratedLegacyLauncher == true
	touch()
end
