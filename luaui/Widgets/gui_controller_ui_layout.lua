--------------------------------------------------------------------------------
-- BAR Controller Support - shared UI settings, contextual hints, layout editor
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Controller UI Layout",
		desc = "Optional controller UI authoring workspace (disabled during normal gameplay)",
		author = "Kailil / Codex",
		date = "2026-07-19",
		license = "GNU GPL, v2 or later",
		-- BAR dispatches interactive call-ins from lower layers first. Keep the
		-- authoring modal alongside native modal windows such as Options.
		layer = -99991,
		enabled = false,
		handler = true,
	}
end

local SCHEMA_VERSION = 3
local REFERENCE_WIDTH, REFERENCE_HEIGHT = 1920, 1080
local MIN_EDITOR_W, MIN_EDITOR_H = 720, 480
local MAX_UNDO = 60
local DEFAULTS_BUNDLED_PATH = "controller-ui/shipping-defaults.json"
local DEFAULTS_CACHE_PATH = "LuaUI/Config/BARControllerSupport/controller-ui-defaults.json"
local DEFAULTS_CACHE_MANIFEST_PATH = "LuaUI/Config/BARControllerSupport/controller-ui-defaults-manifest.json"
local RELOAD_REQUEST_PATH = "LuaUI/Config/BARControllerSupport/reload-request.json"
local AUTHORING_OUTBOX_PATH = "LuaUI/Config/BARControllerSupport/outbox/shipping-defaults.draft.json"
local PUBLISH_RESULT_PATH = "LuaUI/Config/BARControllerSupport/outbox/publish-result.json"
local PERSONAL_PROFILE_EXPORT_PATH = "LuaUI/Config/BARControllerSupport/outbox/controller-ui-profile.json"
local PROFILE_BACKUP_PATH = "LuaUI/Config/BARControllerSupport/outbox/controller-ui-profile-backup.json"
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

local extra = {}

do
	local ok, result = false, nil
	if VFS and type(VFS.Include) == "function" then ok, result = pcall(VFS.Include, "LuaUI/Include/controller_ui_editor_workspace.lua") end
	if ok and type(result) == "table" then extra.EditorWorkspace = result end
	local inputOK, inputResult = false, nil
	if VFS and type(VFS.Include) == "function" then inputOK, inputResult = pcall(VFS.Include, "LuaUI/Include/controller_ui_editor_input.lua") end
	if inputOK and type(inputResult) == "table" then extra.EditorInput = inputResult end
	local glyphOK, glyphResult = false, nil
	if VFS and type(VFS.Include) == "function" then glyphOK, glyphResult = pcall(VFS.Include, "LuaUI/Include/controller_glyphs.lua") end
	if glyphOK and type(glyphResult) == "table" then extra.Glyphs = glyphResult end
	local rendererOK, rendererResult = false, nil
	if VFS and type(VFS.Include) == "function" then rendererOK, rendererResult = pcall(VFS.Include, "LuaUI/Include/controller_ui_shared_renderers.lua") end
	if rendererOK and type(rendererResult) == "table" then extra.SharedRenderers = rendererResult end
end

local DEFAULTS = {
	global = {
		enabled = true, scale = 1, opacity = 1, fontScale = 1,
		safeMargin = 16, resolutionAware = true,
	},
	theme = {
		preset = "Ocean", backgroundR = 0.018, backgroundG = 0.028, backgroundB = 0.040,
		foregroundR = 0.94, foregroundG = 0.98, foregroundB = 1.00,
		accentR = 0.34, accentG = 0.82, accentB = 0.92,
		mutedR = 0.36, mutedG = 0.52, mutedB = 0.60,
		dangerR = 0.92, dangerG = 0.28, dangerB = 0.24,
		advancedColorEditor = false, colorTarget = "Accent", colorHex = "#57D1EB",
		colorHue = 190, colorSaturation = 0.63, colorValue = 0.92,
	},
	authoring = {
		snapEnabled = true, snapGrid = 8, snapThreshold = 8, showSafeArea = true,
		showOutlines = true, filterMode = "Basic", contextPreview = "Live",
		shortcutUndo = "Ctrl+Z", shortcutRedo = "Ctrl+Y", shortcutSave = "Ctrl+S",
		shortcutDraft = "Ctrl+Shift+S", shortcutPublish = "Ctrl+Alt+S", shortcutSearch = "Ctrl+F",
		shortcutClose = "Escape", shortcutNext = "Tab", shortcutPrevious = "Shift+Tab",
		shortcutFine = "Ctrl", shortcutCoarse = "Shift", developerAuthoring = false,
		actionTarget = "select", actionVisible = true, actionCategory = "Selection", actionOrder = 100,
		actionShortLabel = "", categoryTarget = "Selection", categoryVisible = true, categorySortOrder = 10,
	},
	components = {
		hints = {
			enabled = true, x = 0.018, y = 0.035, scale = 1, opacity = 1, fontScale = 1,
			iconScale = 1, rowSpacing = 5, columnSpacing = 18, iconTextSpacing = 8,
			padding = 12, maxWidth = 0.52, columns = 2, backgroundOpacity = 0,
			textOpacity = 1, borderOpacity = 0, fadeDuration = 0.18,
			contextEnterDebounce = 0.14, contextExitGrace = 0.12,
			confirmedModalImmediate = true,
			compact = false, anchor = "bottomleft", mode = "Contextual", overflow = "Wrap",
			presentation = "Glyph + Action Text", showChip = true,
			showActionText = true, showRowBackground = false, showCategoryHeaders = false,
			showContextHeader = false, showSeparators = false, borderThickness = 0, wrapLines = 2,
			chordLayout = "Horizontal", priorityHiding = true,
			marqueeSpeed = 28, marqueeDelay = 0.8, marqueeGap = 36, maxItems = 14, expanded = false,
			glyphColorMode = "Color-friendly", glyphSpacing = 4, glyphOpacity = 1,
			glyphBackgroundEnabled = false, glyphBackgroundOpacity = 0, glyphBorderEnabled = false, glyphBorderOpacity = 0,
			textShadowEnabled = true, textShadowOpacity = 0.82, textShadowOffsetX = 2, textShadowOffsetY = -2,
			textShadowSpread = 1, textShadowR = 0, textShadowG = 0, textShadowB = 0,
			glyphShadowEnabled = true, glyphShadowOpacity = 0.74, glyphShadowOffsetX = 2, glyphShadowOffsetY = -2,
			glyphShadowSpread = 1, glyphShadowR = 0, glyphShadowG = 0, glyphShadowB = 0,
			textGlowEnabled = false, textGlowOpacity = 0.34, textGlowSize = 2, textGlowIntensity = 1,
			textGlowR = 0.34, textGlowG = 0.82, textGlowB = 0.92,
			glyphGlowEnabled = false, glyphGlowOpacity = 0.28, glyphGlowSize = 2, glyphGlowIntensity = 1,
			glyphGlowR = 0.34, glyphGlowG = 0.82, glyphGlowB = 0.92,
			textBackgroundEnabled = false, textBackgroundOpacity = 0.62, textBackgroundPaddingX = 5,
			textBackgroundPaddingY = 2, textBackgroundBorderOpacity = 0, textBackgroundBorderThickness = 1,
			textBackgroundR = 0.018, textBackgroundG = 0.028, textBackgroundB = 0.040,
			showHoldIndicator = true, holdStyle = "Bold HOLD", holdLabelScale = 1.08, holdLabelSpacing = 7,
			holdOpacity = 1, holdColorR = 1, holdColorG = 0.72, holdColorB = 0.22,
			holdGlyphThickness = 2, holdGlyphOpacity = 0.9,
		},
		bindingsButton = {
			enabled = true, x = 1360 / 1920, y = 1044 / 1080, scale = 1,
			opacity = 1, fontScale = 1, anchor = "bottomleft", width = 110 / 1920,
			height = 28 / 1080, backgroundOpacity = 0.85,
		},
		radials = { enabled = true, scale = 1, opacity = 1, fontScale = 1, iconScale = 1,
			centerTextScale = 1, selectedScale = 1.06, selectedBorderThickness = 3,
			itemSpacing = 1, legacyThemeOpacity = 1, pageStatusVisible = true },
		buildRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		tacticalRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		selectionRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		factoryRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		visibleSelectionRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		pregame = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, anchor = "center" },
		reticle = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, anchor = "center" },
		notifications = { enabled = true, x = 0.5, y = 0.35, scale = 1, opacity = 1, fontScale = 1, anchor = "center" },
		instructional = { enabled = true, x = 0.5, y = 0.73, scale = 1, opacity = 1, fontScale = 1, anchor = "center" },
		hotSlots = { enabled = true, x = 0.5, y = 0.08, scale = 1, opacity = 1, fontScale = 1,
			iconScale = 1, slotSize = 42, slotWidth = 42, slotHeight = 42, slotGap = 5,
			slotCount = 10, orientation = "Horizontal", rows = 1, panelPadding = 12,
			showLabel = true, headerLabel = "Controller Groups", showStatus = true,
			showCounts = true, showAuto = true, showRole = false, hideEmpty = false,
			selectedBorderThickness = 2.5, emptyOpacity = 0.74, backgroundOpacity = 0.72,
			autoCollapse = false, autoCollapseDelay = 2.5, animationDuration = 0.18,
			scrollBehavior = "Follow Active", anchor = "bottomcenter", themeOverride = "Global" },
		selectedStatus = { enabled = true, x = 0.992, y = 0.046, scale = 1, opacity = 1,
			fontScale = 1, iconScale = 1, width = 294 / 1920, height = 104 / 1080, anchor = "bottomright" },
		queueStatus = { enabled = true, x = 0.5, y = 0.537, scale = 1, opacity = 1, fontScale = 1, anchor = "center" },
		placementStatus = { enabled = true, x = 0.5, y = 0.405, scale = 1, opacity = 1, fontScale = 1, anchor = "center" },
		companionStatus = { enabled = true, x = 0.5, y = 0.73, scale = 1, opacity = 1, fontScale = 1, anchor = "center" },
		debug = { enabled = true },
		editorLauncher = { enabled = false, x = 0.79, y = 1044 / 1080, scale = 1, opacity = 0.9,
			fontScale = 1, width = 116 / 1920, height = 28 / 1080, padding = 7, backgroundOpacity = 0.88, anchor = "bottomleft" },
		editor = { enabled = true, x = 0.55, y = 0.14, width = 0.42, height = 0.76, scale = 1, opacity = 1 },
	},
}

-- Keep the persisted schema flat so schema-1/2/3 personal documents merge
-- without loss. The shared renderer resolves these keys into semantic roles.
local radialStyleAPI = extra.SharedRenderers and extra.SharedRenderers.RadialStyle
local radialTypographyDefaults = radialStyleAPI and radialStyleAPI.DEFAULTS or {}
for key, value in pairs(radialTypographyDefaults) do DEFAULTS.components.radials[key] = deepCopy(value) end
for _, componentName in ipairs({ "buildRadial", "factoryRadial", "tacticalRadial", "selectionRadial", "visibleSelectionRadial" }) do
	DEFAULTS.components[componentName].typographyOverride = false
	for key, value in pairs(radialTypographyDefaults) do DEFAULTS.components[componentName][key] = deepCopy(value) end
end

local settings = deepCopy(DEFAULTS)
local shippingBaseline = deepCopy(DEFAULTS)
local personalSettings = nil
local layerSources = {}
local enforcedPaths = {}
local shipping = { bundled = nil, cached = nil, manifest = nil, activeVersion = "fallback", status = "fallback defaults",
	lastPublishResult = nil }
local function newAuthorData()
	return { favorites = {}, savedValues = {}, componentPresets = {}, recent = {}, hiddenActions = {},
		actionOrder = {}, actionCategoryOverrides = {}, shortLabels = {}, categoryVisibility = {}, categoryOrder = {},
		shippingEnforcedPaths = {}, shippingEnforcedSettings = {}, recentColors = {}, favoriteColors = {} }
end
local authorData = newAuthorData()
local history = { undo = {}, redo = {}, active = nil, dirty = false, lastSaved = deepCopy(DEFAULTS),
	lastSavedAuthorData = newAuthorData(), suppress = false }
local lastReloadToken = nil
local reloadPollElapsed = 0
local revision = 1
local viewX, viewY = 1, 1
local automaticScale = 1
local migratedLegacyLauncher = false
local ownsSettingsAPI = false
local ownsHintRegistry = false

local editor = {
	open = false, tab = 1, row = 1, dragging = false, resizing = false,
	dragBindings = false, dragComponent = nil, dragDX = 0, dragDY = 0, startX = 0, startY = 0,
	startW = 0, startH = 0, resizeComponent = nil, hits = {}, tabs = {}, close = nil, resetSection = nil,
	resetAll = nil, resize = nil, launcher = nil, bounds = nil, componentHits = {},
	selectedComponent = "hints", filterHits = {}, search = "", searchActive = false,
	scroll = 0,
	held = nil, guides = {}, status = "Ready", recoveryAvailable = false,
	favorite = nil, saveValue = nil, applyValue = nil, savePreset = nil, applyPreset = nil,
	undo = nil, redo = nil, save = nil, context = nil, draft = nil, publish = nil, reload = nil,
	propertyDrag = nil, activeText = nil, selectAll = false, previousTextOwner = nil,
	wheelEditId = nil, wheelEditRow = nil,
	textBuffer = "", textOriginal = "", textNumeric = false, composition = "", pointerCapture = nil,
	previewContext = "Normal Gameplay",
	filterMode = "Basic",
	chrome = { x = 0.55, y = 0.14, width = 0.42, height = 0.76 },
}

extra.workspace = extra.EditorWorkspace and extra.EditorWorkspace.New() or nil
extra.input = extra.EditorInput and extra.EditorInput.New() or nil

local tabs = { "General", "Hints", "Actions", "Hot Slots", "Launchers", "Radials", "Status", "Other", "Theme", "Authoring", "Recovery" }
local filterModes = { "Basic", "Advanced", "All", "Favorites", "Recent", "Modified" }

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
		{ "visibleSelectionRadial", "scale", "Visible-selection radial scale", "number", 0.50, 2.00, 0.05 },
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

-- Schema-3 extends the proven schema-2 property rows in place. Keeping the
-- original rows also makes every schema-2 value discoverable after migration.
definitions["Hints"] = definitions["Button Hints"]
definitions["Actions"] = {}
definitions["Launchers"] = definitions["Bindings Button"]
definitions["Hot Slots"] = {}
definitions["Status"] = {}
definitions["Other"] = definitions["Other UI"]
definitions["Theme"] = {}
definitions["Authoring"] = {}
definitions["Recovery"] = {}

local function addProperty(tab, scope, key, label, kind, low, high, step, level, options)
	definitions[tab][#definitions[tab] + 1] = { scope, key, label, kind, low, high, step, level or "Basic", options }
end

addProperty("Hints", "hints", "mode", "Display mode", "enum", nil, nil, nil, "Basic", { "Contextual", "Layered", "Minimal", "Everything" })
addProperty("Hints", "hints", "presentation", "Visual presentation", "enum", nil, nil, nil, "Basic", {
	"Glyph + Action Text", "Button Chip Only", "Action Text Only",
	"Background Only", "Minimal Glyph", "Compact", "Full Descriptive", "Custom",
})
addProperty("Hints", "hints", "overflow", "Long-label strategy", "enum", nil, nil, nil, "Basic", { "Wrap", "Clip", "Marquee", "Ping Pong" })
addProperty("Hints", "hints", "expanded", "Always expanded", "bool")
addProperty("Hints", "hints", "maxItems", "Collapsed item limit", "number", 3, 40, 1)
addProperty("Hints", "hints", "contextEnterDebounce", "Context enter debounce", "number", 0, 0.50, 0.01, "Advanced")
addProperty("Hints", "hints", "contextExitGrace", "Context exit grace", "number", 0, 0.50, 0.01, "Advanced")
addProperty("Hints", "hints", "confirmedModalImmediate", "Confirmed modal transition", "bool", nil, nil, nil, "Advanced")
addProperty("Hints", "gameplay", "lbTapMaxSeconds", "Input / LB tap maximum", "number", 0.08, 0.50, 0.01, "Advanced")
addProperty("Hints", "gameplay", "lbTacticalHoldSeconds", "Input / LB tactical hold", "number", 0.08, 0.50, 0.01, "Advanced")
addProperty("Hints", "gameplay", "visibleSelectionFilter", "Input / quick LB filter", "enum", nil, nil, nil, "Advanced",
	{ "Combat", "Builders", "Air", "Last Selected" })
for _, row in ipairs({
	{ "showChip", "Show button chip layer", "bool" }, { "showActionText", "Show action-text layer", "bool" },
	{ "showRowBackground", "Show row backgrounds", "bool" }, { "showCategoryHeaders", "Show category headings", "bool" },
	{ "showContextHeader", "Show context heading", "bool" }, { "showSeparators", "Show separators", "bool" },
	{ "borderThickness", "Border thickness", "number", 0, 5, 0.25 },
	{ "wrapLines", "Maximum wrapped lines", "number", 2, 8, 1 },
	{ "chordLayout", "Chord layout", "enum", nil, nil, nil, { "Horizontal", "Vertical", "Stacked" } },
	{ "priorityHiding", "Hide low priority when constrained", "bool" },
	{ "marqueeSpeed", "Marquee speed", "number", 1, 120, 1 },
	{ "marqueeDelay", "Marquee delay", "number", 0, 5, 0.1 },
	{ "marqueeGap", "Marquee loop gap", "number", 8, 100, 2 },
	{ "glyphColorMode", "Glyph color mode", "enum", nil, nil, nil, { "Color-friendly", "Monochrome", "Theme Accent" } },
	{ "glyphSpacing", "Glyph chord spacing", "number", 0, 16, 1 },
	{ "glyphOpacity", "Glyph opacity", "number", 0.1, 1, 0.05 },
}) do
	local options = type(row[7]) == "table" and row[7] or nil
	addProperty("Hints", "hints", row[1], row[2], row[3], row[4], row[5], row[6], "Advanced", options)
end

for _, row in ipairs({
	{ "glyphBackgroundEnabled", "Glyph background", "bool" }, { "glyphBackgroundOpacity", "Glyph background opacity", "number", 0, 1, 0.05 },
	{ "glyphBorderEnabled", "Glyph border", "bool" }, { "glyphBorderOpacity", "Glyph border opacity", "number", 0, 1, 0.05 },
	{ "textShadowEnabled", "Text drop shadow", "bool" }, { "textShadowOpacity", "Text shadow opacity", "number", 0, 1, 0.05 },
	{ "textShadowOffsetX", "Text shadow X offset", "number", -8, 8, 0.5 }, { "textShadowOffsetY", "Text shadow Y offset", "number", -8, 8, 0.5 },
	{ "textShadowSpread", "Text shadow spread", "number", 0, 2, 1 },
	{ "glyphShadowEnabled", "Glyph drop shadow", "bool" }, { "glyphShadowOpacity", "Glyph shadow opacity", "number", 0, 1, 0.05 },
	{ "glyphShadowOffsetX", "Glyph shadow X offset", "number", -8, 8, 0.5 }, { "glyphShadowOffsetY", "Glyph shadow Y offset", "number", -8, 8, 0.5 },
	{ "glyphShadowSpread", "Glyph shadow spread", "number", 0, 2, 1 },
	{ "textGlowEnabled", "Text glow", "bool" }, { "textGlowOpacity", "Text glow opacity", "number", 0, 1, 0.05 },
	{ "textGlowSize", "Text glow size", "number", 1, 6, 1 }, { "textGlowIntensity", "Text glow intensity", "number", 0.1, 3, 0.1 },
	{ "glyphGlowEnabled", "Glyph glow", "bool" }, { "glyphGlowOpacity", "Glyph glow opacity", "number", 0, 1, 0.05 },
	{ "glyphGlowSize", "Glyph glow size", "number", 1, 6, 1 }, { "glyphGlowIntensity", "Glyph glow intensity", "number", 0.1, 3, 0.1 },
	{ "textBackgroundEnabled", "Action-label background", "bool" }, { "textBackgroundOpacity", "Label background opacity", "number", 0, 1, 0.05 },
	{ "textBackgroundPaddingX", "Label background horizontal padding", "number", 0, 20, 1 },
	{ "textBackgroundPaddingY", "Label background vertical padding", "number", 0, 12, 1 },
	{ "textBackgroundBorderOpacity", "Label background border opacity", "number", 0, 1, 0.05 },
	{ "textBackgroundBorderThickness", "Label background border thickness", "number", 1, 4, 1 },
	{ "showHoldIndicator", "Show hold treatment", "bool" },
	{ "holdStyle", "Hold style", "enum", nil, nil, nil, { "Bold HOLD", "Hold Glyph" } },
	{ "holdLabelScale", "HOLD label scale", "number", 0.7, 2, 0.05 }, { "holdLabelSpacing", "HOLD label spacing", "number", 0, 24, 1 },
	{ "holdOpacity", "Hold treatment opacity", "number", 0.1, 1, 0.05 },
	{ "holdGlyphThickness", "Hold glyph outline", "number", 1, 6, 0.5 }, { "holdGlyphOpacity", "Hold glyph outline opacity", "number", 0.1, 1, 0.05 },
}) do
	local options = type(row[7]) == "table" and row[7] or nil
	addProperty("Hints", "hints", row[1], row[2], row[3], row[4], row[5], row[6], "Advanced", options)
end

for _, prefix in ipairs({ "textShadow", "glyphShadow", "textGlow", "glyphGlow", "textBackground", "holdColor" }) do
	for _, channel in ipairs({ "R", "G", "B" }) do
		addProperty("Hints", "hints", prefix .. channel, prefix .. " " .. string.lower(channel), "number", 0, 1, 0.02, "Advanced")
	end
end

local ACTION_IDS = {
	"select", "cancel", "smartAction", "buildRadial", "commandLayer", "insertNextCommandModifier", "appendQueueModifier",
	"controlGroupModifier", "pitchModifier", "removeQueuedCommand", "removeLastQueuedCommand", "radialSelect", "radialCancel",
	"radialQuick", "radialClose", "radialPrevPage", "radialNextPage", "place", "placeStay", "cancelPlacement",
	"rotateBuildingLeft", "rotateBuildingRight", "spacingUp", "spacingDown", "patternPrev", "patternNext", "tacticalSelect",
	"tacticalCancel", "tacticalClose", "commandUp", "commandDown", "commandLeft", "commandRight", "idlePrev", "idleNext",
	"groupSlotUp", "groupSlotDown", "groupRecallOrAssign", "groupAssign", "groupClear", "selectCommander",
}
local CATEGORY_IDS = { "Selection", "Commands", "Camera", "Building", "Placement", "Factory", "Tactical", "Radials",
	"Groups / Hot Slots", "Mouse Mode", "Pregame", "Editor", "System", "Advanced" }
addProperty("Actions", "authoring", "actionTarget", "Selected hint action", "enum", nil, nil, nil, "Basic", ACTION_IDS)
addProperty("Actions", "authoring", "actionVisible", "Selected action visible", "bool")
addProperty("Actions", "authoring", "actionCategory", "Selected action category", "enum", nil, nil, nil, "Basic", CATEGORY_IDS)
addProperty("Actions", "authoring", "actionOrder", "Selected action order", "number", -1000, 2000, 1)
addProperty("Actions", "authoring", "actionShortLabel", "Selected action short label", "text", nil, nil, nil, "Advanced")
addProperty("Actions", "authoring", "categoryTarget", "Selected category", "enum", nil, nil, nil, "Basic", CATEGORY_IDS)
addProperty("Actions", "authoring", "categoryVisible", "Selected category visible", "bool")
addProperty("Actions", "authoring", "categorySortOrder", "Selected category order", "number", 0, 1000, 1, "Advanced")

for _, row in ipairs({
	{ "enabled", "Unit hot-slot strip visible", "bool" }, { "x", "X position", "number", 0, 1, 0.005 },
	{ "y", "Y position", "number", 0, 1, 0.005 }, { "scale", "Strip scale", "number", 0.5, 2, 0.05 },
	{ "slotSize", "Square slot size", "number", 24, 84, 2 },
	{ "slotWidth", "Slot width", "number", 24, 120, 2, "Advanced" },
	{ "slotHeight", "Slot height", "number", 24, 100, 2, "Advanced" },
	{ "slotGap", "Slot gap", "number", 0, 24, 1 },
	{ "slotCount", "Visible slots", "number", 1, 10, 1 }, { "showLabel", "Show shortcut label", "bool" },
	{ "showCounts", "Show unit counts", "bool" }, { "showAuto", "Show auto-add marker", "bool" },
	{ "orientation", "Orientation", "enum", nil, nil, nil, "Basic", { "Horizontal", "Vertical", "Grid" } },
	{ "rows", "Grid rows", "number", 1, 5, 1, "Basic" },
	{ "panelPadding", "Panel padding", "number", 0, 32, 1, "Advanced" },
	{ "headerLabel", "Concise header", "text", nil, nil, nil, "Advanced" },
	{ "showStatus", "Show active status", "bool" }, { "showRole", "Show assigned role/type", "bool", nil, nil, nil, "Advanced" },
	{ "hideEmpty", "Hide empty slots", "bool", nil, nil, nil, "Advanced" },
	{ "selectedBorderThickness", "Selected border thickness", "number", 1, 6, 0.25, "Advanced" },
	{ "emptyOpacity", "Empty slot opacity", "number", 0, 1, 0.05, "Advanced" },
	{ "autoCollapse", "Auto-collapse after input", "bool", nil, nil, nil, "Advanced" },
	{ "autoCollapseDelay", "Auto-collapse delay", "number", 0.5, 10, 0.25, "Advanced" },
	{ "animationDuration", "Animation duration", "number", 0, 1.5, 0.05, "Advanced" },
	{ "scrollBehavior", "Slot overflow behavior", "enum", nil, nil, nil, "Advanced", { "Follow Active", "Fixed", "Wrap" } },
	{ "themeOverride", "Component theme", "enum", nil, nil, nil, "Advanced", { "Global", "BAR Default", "Minimal", "Compact", "Large Accessibility", "Transparent", "High Contrast" } },
	{ "opacity", "Strip opacity", "number", 0.1, 1, 0.05, "Advanced" },
	{ "fontScale", "Label scale", "number", 0.5, 2, 0.05, "Advanced" },
	{ "iconScale", "Unit icon scale", "number", 0.5, 2, 0.05, "Advanced" },
	{ "backgroundOpacity", "Background opacity", "number", 0, 1, 0.05, "Advanced" },
}) do addProperty("Hot Slots", "hotSlots", row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8]) end

local function addComponentProperties(tab, scope, label, positioned)
	addProperty(tab, scope, "enabled", label .. " visible", "bool")
	if positioned ~= false then
		addProperty(tab, scope, "x", label .. " X", "number", 0, 1, 0.005)
		addProperty(tab, scope, "y", label .. " Y", "number", 0, 1, 0.005)
	end
	addProperty(tab, scope, "scale", label .. " scale", "number", 0.5, 2, 0.05)
	addProperty(tab, scope, "opacity", label .. " opacity", "number", 0.1, 1, 0.05, "Advanced")
	if DEFAULTS.components[scope].fontScale then addProperty(tab, scope, "fontScale", label .. " text scale", "number", 0.5, 2, 0.05, "Advanced") end
	if DEFAULTS.components[scope].iconScale then addProperty(tab, scope, "iconScale", label .. " icon scale", "number", 0.5, 2, 0.05, "Advanced") end
	if DEFAULTS.components[scope].anchor and DEFAULTS.components[scope].width and DEFAULTS.components[scope].height then
		addProperty(tab, scope, "anchor", label .. " anchor", "enum", nil, nil, nil, "Advanced",
		{ "bottomleft", "bottomcenter", "bottomright", "center" }) end
end

addComponentProperties("Launchers", "editorLauncher", "UI Layout launcher")
addProperty("Launchers", "bindingsButton", "width", "Bindings width", "number", 0.03, 0.30, 0.005, "Advanced")
addProperty("Launchers", "bindingsButton", "height", "Bindings height", "number", 0.02, 0.15, 0.005, "Advanced")
addProperty("Launchers", "bindingsButton", "anchor", "Bindings anchor", "enum", nil, nil, nil, "Advanced",
	{ "bottomleft", "bottomcenter", "bottomright", "center" })
addProperty("Launchers", "editorLauncher", "width", "UI Layout width", "number", 0.03, 0.30, 0.005, "Advanced")
addProperty("Launchers", "editorLauncher", "height", "UI Layout height", "number", 0.02, 0.15, 0.005, "Advanced")
addProperty("Launchers", "editorLauncher", "padding", "UI Layout padding", "number", 2, 24, 1, "Advanced")
addProperty("Launchers", "editorLauncher", "backgroundOpacity", "UI Layout background opacity", "number", 0, 1, 0.05, "Advanced")
addProperty("Hot Slots", "hotSlots", "anchor", "Hot-slot anchor", "enum", nil, nil, nil, "Advanced",
	{ "bottomleft", "bottomcenter", "bottomright", "center" })
addComponentProperties("Radials", "radials", "All radials", false)
addProperty("Radials", "radials", "centerTextScale", "Center text scale", "number", 0.5, 2, 0.05, "Advanced")
addProperty("Radials", "radials", "selectedScale", "Selected item scale", "number", 1, 1.3, 0.01, "Advanced")
addProperty("Radials", "radials", "selectedBorderThickness", "Selected border thickness", "number", 1, 6, 0.25, "Advanced")
addProperty("Radials", "radials", "itemSpacing", "Radial item spacing", "number", 0.75, 1.2, 0.01, "Advanced")
addProperty("Radials", "radials", "legacyThemeOpacity", "Legacy color layering", "number", 0.2, 1, 0.05, "Advanced")
addProperty("Radials", "radials", "pageStatusVisible", "Page and status labels", "bool", nil, nil, nil, "Advanced")
for _, item in ipairs({ { "buildRadial", "Build radial" }, { "factoryRadial", "Factory radial" },
	{ "tacticalRadial", "Tactical radial" }, { "selectionRadial", "Selection radial" },
	{ "visibleSelectionRadial", "Visible selection filter radial" } }) do
	addComponentProperties("Radials", item[1], item[2])
end

local radialComponentScopes = { "buildRadial", "factoryRadial", "tacticalRadial", "selectionRadial", "visibleSelectionRadial" }
local radialRoleLabels = {
	categoryLabel = "Category labels", centerTitle = "Center title", centerDescription = "Center description",
	metalCost = "Metal cost", energyCost = "Energy cost", healthStat = "Health", availabilityText = "Availability",
	metadata = "Metadata", footer = "Footer instructions",
	pageIndicator = "Page indicator", slotNumber = "Slot / hotkey number", unavailableText = "Unavailable text",
}
local radialRoleProperties = {
	categoryLabel = {
		{ "Size", "Font size", "number", 7, 42, 1 }, { "ColorR", "Color / HSV and swatches", "color" },
		{ "ShadowEnabled", "Text shadow", "bool" }, { "ShadowColorR", "Shadow color", "color" }, { "OutlineEnabled", "Text outline", "bool" },
		{ "Alignment", "Alignment", "enum", nil, nil, nil, { "Left", "Center", "Right" } },
		{ "OffsetX", "Horizontal offset", "number", -80, 80, 1 }, { "OffsetY", "Vertical offset", "number", -80, 80, 1 },
		{ "LetterSpacing", "Letter spacing", "number", -1, 8, 0.25 },
	},
	centerTitle = {
		{ "Size", "Font size", "number", 7, 42, 1 }, { "ColorR", "Color / HSV and swatches", "color" },
		{ "Emphasis", "Weight / emphasis", "number", 0.75, 1.5, 0.05 }, { "ShadowEnabled", "Text shadow", "bool" },
		{ "ShadowColorR", "Shadow color", "color" }, { "OutlineEnabled", "Text outline", "bool" },
		{ "MaxWidth", "Maximum width", "number", 0.6, 2, 0.05 }, { "WrapMode", "Overflow mode", "enum", nil, nil, nil, { "Truncate", "Wrap" } },
		{ "SpacingAfter", "Title-to-body spacing", "number", 0, 30, 1 }, { "OffsetY", "Vertical offset", "number", -80, 80, 1 },
	},
	centerDescription = {
		{ "Size", "Font size", "number", 6, 32, 1 }, { "ColorR", "Color / HSV and swatches", "color" },
		{ "LineSpacing", "Line spacing", "number", 0, 20, 1 }, { "MaxWidth", "Maximum width", "number", 0.5, 2, 0.05 },
		{ "WrapEnabled", "Wrap text", "bool" }, { "MaxLines", "Maximum lines", "number", 1, 8, 1 },
		{ "SpacingBefore", "Spacing before description", "number", 0, 30, 1 }, { "SpacingAfter", "Spacing after description", "number", 0, 30, 1 },
		{ "ShadowEnabled", "Text shadow", "bool" }, { "ShadowColorR", "Shadow color", "color" }, { "OutlineEnabled", "Text outline", "bool" },
		{ "OffsetY", "Vertical offset", "number", -80, 80, 1 },
	},
	metalCost = {
		{ "Size", "Font size", "number", 6, 32, 1 }, { "ColorR", "Color / HSV and swatches", "color" },
		{ "IconSize", "Resource icon size", "number", 4, 32, 1 }, { "IconSpacing", "Icon-to-text spacing", "number", 0, 20, 1 },
		{ "ShadowEnabled", "Text shadow", "bool" }, { "OutlineEnabled", "Text outline", "bool" },
		{ "Alignment", "Alignment", "enum", nil, nil, nil, { "Left", "Center", "Right" } },
	},
	energyCost = {
		{ "Size", "Font size", "number", 6, 32, 1 }, { "ColorR", "Color / HSV and swatches", "color" },
		{ "IconSize", "Resource icon size", "number", 4, 32, 1 }, { "IconSpacing", "Icon-to-text spacing", "number", 0, 20, 1 },
		{ "ShadowEnabled", "Text shadow", "bool" }, { "OutlineEnabled", "Text outline", "bool" },
		{ "Alignment", "Alignment", "enum", nil, nil, nil, { "Left", "Center", "Right" } },
	},
	healthStat = {
		{ "Size", "Font size", "number", 6, 32, 1 }, { "ColorR", "Color / HSV and swatches", "color" },
		{ "IconSize", "Health icon size", "number", 4, 32, 1 }, { "IconSpacing", "Icon-to-text spacing", "number", 0, 20, 1 },
		{ "ShadowEnabled", "Text shadow", "bool" }, { "OutlineEnabled", "Text outline", "bool" },
		{ "Alignment", "Alignment", "enum", nil, nil, nil, { "Left", "Center", "Right" } },
	},
	availabilityText = {
		{ "Size", "Font size", "number", 6, 30, 1 }, { "ColorR", "Color / HSV and swatches", "color" },
		{ "LineSpacing", "Line spacing", "number", 0, 20, 1 }, { "ShadowEnabled", "Text shadow", "bool" },
		{ "OutlineEnabled", "Text outline", "bool" },
	},
	metadata = {
		{ "Size", "Font size", "number", 6, 30, 1 }, { "ColorR", "Color / HSV and swatches", "color" },
		{ "LineSpacing", "Line spacing", "number", 0, 20, 1 }, { "Alignment", "Alignment", "enum", nil, nil, nil, { "Left", "Center", "Right" } },
		{ "ShadowEnabled", "Text shadow", "bool" }, { "OutlineEnabled", "Text outline", "bool" },
	},
	footer = { { "Size", "Font size", "number", 6, 30, 1 }, { "ColorR", "Color / HSV and swatches", "color" }, { "ShadowEnabled", "Text shadow", "bool" } },
	pageIndicator = { { "Size", "Font size", "number", 6, 30, 1 }, { "ColorR", "Color / HSV and swatches", "color" }, { "ShadowEnabled", "Text shadow", "bool" } },
	slotNumber = { { "Size", "Font size", "number", 6, 30, 1 }, { "ColorR", "Color / HSV and swatches", "color" }, { "ShadowEnabled", "Text shadow", "bool" } },
	unavailableText = { { "Size", "Font size", "number", 6, 30, 1 }, { "ColorR", "Color / HSV and swatches", "color" }, { "ShadowEnabled", "Text shadow", "bool" } },
}

local function addRadialStyleProperties(scope, prefix)
	if scope ~= "radials" then addProperty("Radials", scope, "typographyOverride", prefix .. " / Use custom typography", "bool") end
	for _, property in ipairs({
		{ "radiusScale", "Layout / Radius", "number", 0.6, 1.4, 0.02 }, { "innerRadiusScale", "Layout / Inner radius", "number", 0.6, 1.5, 0.02 },
		{ "segmentSpacing", "Layout / Segment spacing", "number", 0.75, 1.25, 0.01 }, { "segmentAnglePadding", "Layout / Segment angle padding", "number", 0, 8, 0.25 },
		{ "centerPanelScale", "Layout / Center-panel size", "number", 0.7, 1.4, 0.02 }, { "safeScreenMargin", "Layout / Safe-screen margin", "number", 0, 80, 1 },
		{ "resourceSpacing", "Resource costs / Spacing", "number", 0, 40, 1 },
		{ "resourceRowSpacing", "Resource costs / Row spacing", "number", 0, 30, 1 },
		{ "resourceLayout", "Resource costs / Layout", "enum", nil, nil, nil, { "Row", "Column" } },
		{ "resourceAlignment", "Resource costs / Alignment", "enum", nil, nil, nil, { "Left", "Center", "Right" } },
	}) do addProperty("Radials", scope, property[1], prefix .. " / " .. property[2], property[3], property[4], property[5], property[6], "Basic", property[7]) end
	for _, roleName in ipairs(radialStyleAPI and radialStyleAPI.ROLES or {}) do
		for _, property in ipairs(radialRoleProperties[roleName]) do
			local options = type(property[7]) == "table" and property[7] or nil
			addProperty("Radials", scope, roleName .. property[1], prefix .. " / " .. radialRoleLabels[roleName] .. " / " .. property[2],
				property[3], property[4], property[5], property[6], property[3] == "color" and "Basic" or "Advanced", options)
		end
	end
	for _, property in ipairs({
		{ "selectedBackgroundR", "Selected state / Background", "color" }, { "selectedBorderR", "Selected state / Border", "color" },
		{ "selectedLabelR", "Selected state / Segment label", "color" }, { "selectedTitleR", "Selected state / Center title", "color" },
		{ "selectedIconOpacity", "Selected state / Icon opacity", "number", 0.1, 1, 0.05 },
		{ "unavailableIconOpacity", "Selected state / Unavailable icon opacity", "number", 0.1, 1, 0.05 },
	}) do addProperty("Radials", scope, property[1], prefix .. " / " .. property[2], property[3], property[4], property[5], property[6], "Advanced") end
end

addRadialStyleProperties("radials", "All radials")
for _, scope in ipairs(radialComponentScopes) do
	local label = scope == "buildRadial" and "Build" or scope == "factoryRadial" and "Factory" or scope == "tacticalRadial" and "Tactical"
		or scope == "selectionRadial" and "Selection" or "Visible selection filter"
	addRadialStyleProperties(scope, label)
end
for _, item in ipairs({ { "selectedStatus", "Selected status" }, { "queueStatus", "Queue indicator" },
	{ "placementStatus", "Placement status" } }) do addComponentProperties("Status", item[1], item[2]) end
addProperty("Status", "selectedStatus", "width", "Selected status width", "number", 0.08, 0.50, 0.005, "Advanced")
addProperty("Status", "selectedStatus", "height", "Selected status height", "number", 0.05, 0.40, 0.005, "Advanced")
for _, item in ipairs({ { "reticle", "Reticle" }, { "notifications", "Notifications" }, { "pregame", "Pregame prompt" },
	{ "instructional", "Instructional text" }, { "companionStatus", "Companion status" } }) do
	addComponentProperties("Other", item[1], item[2])
end
addProperty("Other", "debug", "enabled", "Developer debug panel allowed", "bool", nil, nil, nil, "Advanced")

addProperty("Theme", "theme", "preset", "Theme preset", "enum", nil, nil, nil, "Basic", {
	"BAR Default", "Minimal", "Compact", "Large Accessibility", "Transparent", "High Contrast", "Custom", "Ocean", "Soft", "Colorblind",
})
for _, item in ipairs({ { "backgroundR", "Background color" }, { "foregroundR", "Foreground color" }, { "accentR", "Accent color" },
	{ "mutedR", "Muted color" }, { "dangerR", "Danger color" } }) do addProperty("Theme", "theme", item[1], item[2] .. " / HSV and swatches", "color") end
addProperty("Theme", "theme", "advancedColorEditor", "Advanced color editor", "bool")
addProperty("Theme", "theme", "colorTarget", "Color target", "enum", nil, nil, nil, "Advanced",
	{ "Background", "Foreground", "Accent", "Muted", "Danger" })
addProperty("Theme", "theme", "colorHex", "Hex color (copy / paste)", "text", nil, nil, nil, "Advanced")
addProperty("Theme", "theme", "colorHue", "Hue", "number", 0, 360, 1, "Advanced")
addProperty("Theme", "theme", "colorSaturation", "Saturation", "number", 0, 1, 0.02, "Advanced")
addProperty("Theme", "theme", "colorValue", "Value", "number", 0, 1, 0.02, "Advanced")
for _, prefix in ipairs({ "background", "foreground", "accent", "muted", "danger" }) do
	for _, channel in ipairs({ "R", "G", "B" }) do
		addProperty("Theme", "theme", prefix .. channel, prefix .. " " .. string.lower(channel), "number", 0, 1, 0.02, "Advanced")
	end
end

for _, row in ipairs({
	{ "snapEnabled", "Snap while dragging", "bool" }, { "snapGrid", "Snap grid (pixels)", "number", 1, 64, 1 },
	{ "snapThreshold", "Alignment threshold", "number", 1, 32, 1, "Advanced" },
	{ "showSafeArea", "Show safe-screen area", "bool" }, { "showOutlines", "Show component outlines", "bool" },
	{ "shortcutUndo", "Undo shortcut", "text", nil, nil, nil, "Advanced" },
	{ "shortcutRedo", "Redo shortcut", "text", nil, nil, nil, "Advanced" },
	{ "shortcutSave", "Save shortcut", "text", nil, nil, nil, "Advanced" },
	{ "shortcutDraft", "Save draft shortcut", "text", nil, nil, nil, "Advanced" },
	{ "shortcutPublish", "Publish request shortcut", "text", nil, nil, nil, "Advanced" },
	{ "shortcutSearch", "Search shortcut", "text", nil, nil, nil, "Advanced" },
	{ "shortcutClose", "Close shortcut", "text", nil, nil, nil, "Advanced" },
	{ "shortcutNext", "Next control shortcut", "text", nil, nil, nil, "Advanced" },
	{ "shortcutPrevious", "Previous control shortcut", "text", nil, nil, nil, "Advanced" },
}) do addProperty("Authoring", "authoring", row[1], row[2], row[3], row[4], row[5], row[6], row[7]) end

local ranges = {
	enabled = { false, true }, resolutionAware = { false, true }, compact = { false, true },
	x = { 0, 1 }, y = { 0, 1 }, width = { 0.02, 0.95 }, height = { 0.02, 0.95 },
	scale = { 0.50, 2.00 }, opacity = { 0, 1 }, fontScale = { 0.50, 2.00 }, iconScale = { 0.50, 2.00 },
	rowSpacing = { 0, 24 }, columnSpacing = { 0, 60 }, iconTextSpacing = { 0, 30 }, padding = { 2, 40 },
	maxWidth = { 0.20, 0.95 }, columns = { 0, 4 }, backgroundOpacity = { 0, 1 },
	textOpacity = { 0.10, 1 }, borderOpacity = { 0, 1 }, fadeDuration = { 0, 1 }, safeMargin = { 0, 100 },
	contextEnterDebounce = { 0, 0.50 }, contextExitGrace = { 0, 0.50 },
	lbTapMaxSeconds = { 0.08, 0.50 }, lbTacticalHoldSeconds = { 0.08, 0.50 },
	maxItems = { 3, 40 }, slotSize = { 24, 84 }, slotGap = { 0, 24 }, slotCount = { 1, 10 },
	slotWidth = { 24, 120 }, slotHeight = { 24, 100 }, panelPadding = { 0, 32 }, rows = { 1, 5 },
	selectedBorderThickness = { 1, 6 }, emptyOpacity = { 0, 1 }, autoCollapseDelay = { 0.5, 10 },
	animationDuration = { 0, 1.5 }, borderThickness = { 0, 5 }, wrapLines = { 2, 8 },
	marqueeSpeed = { 1, 120 }, marqueeDelay = { 0, 5 }, marqueeGap = { 8, 100 },
	actionOrder = { -1000, 2000 }, categorySortOrder = { 0, 1000 },
	snapGrid = { 1, 64 }, snapThreshold = { 1, 32 },
	backgroundR = { 0, 1 }, backgroundG = { 0, 1 }, backgroundB = { 0, 1 },
	foregroundR = { 0, 1 }, foregroundG = { 0, 1 }, foregroundB = { 0, 1 },
	accentR = { 0, 1 }, accentG = { 0, 1 }, accentB = { 0, 1 },
	mutedR = { 0, 1 }, mutedG = { 0, 1 }, mutedB = { 0, 1 },
	dangerR = { 0, 1 }, dangerG = { 0, 1 }, dangerB = { 0, 1 },
	colorHue = { 0, 360 }, colorSaturation = { 0, 1 }, colorValue = { 0, 1 },
}

local function validateValue(key, value, fallback)
	if type(fallback) == "boolean" then return value == true end
	if key == "anchor" then return type(value) == "string" and value or fallback end
	local range = ranges[key]
	if range then return clamp(value, range[1], range[2]) end
	return type(value) == type(fallback) and value or fallback
end

local function propertyID(scope, key) return tostring(scope) .. "." .. tostring(key) end
local touch

local function mergeValidated(target, source, defaults)
	if type(source) ~= "table" then return end
	for key, fallback in pairs(defaults) do
		if source[key] ~= nil then target[key] = validateValue(key, source[key], fallback) end
	end
end

local function mergeSettingsLayer(target, source, sourceName)
	if type(source) ~= "table" then return end
	for _, scope in ipairs({ "global", "theme", "authoring" }) do
		if type(source[scope]) == "table" then
			mergeValidated(target[scope], source[scope], DEFAULTS[scope])
			for key in pairs(DEFAULTS[scope]) do if source[scope][key] ~= nil then layerSources[propertyID(scope, key)] = sourceName end end
		end
	end
	if type(source.components) == "table" then
		for name, componentDefaults in pairs(DEFAULTS.components) do
			if type(source.components[name]) == "table" then
				mergeValidated(target.components[name], source.components[name], componentDefaults)
				for key in pairs(componentDefaults) do
					if source.components[name][key] ~= nil then layerSources[propertyID(name, key)] = sourceName end
				end
			end
		end
	end
end

local function decodeJSONFile(path, mode)
	if not VFS or type(VFS.LoadFile) ~= "function" or not Json or type(Json.decode) ~= "function" then return nil, "JSON API unavailable" end
	local okRead, content = pcall(VFS.LoadFile, path, mode)
	if not okRead or type(content) ~= "string" or content == "" then return nil, "not found" end
	local okDecode, decoded = pcall(Json.decode, content)
	if not okDecode or type(decoded) ~= "table" then return nil, "malformed JSON" end
	return decoded, nil
end

local function defaultsDocumentValid(document)
	return type(document) == "table"
		and document.kind == "bar-controller-ui-defaults"
		and tonumber(document.schemaVersion) ~= nil
		and tonumber(document.schemaVersion) <= SCHEMA_VERSION
		and type(document.settings) == "table"
end

local function versionParts(value)
	local parts = {}
	for number in tostring(value or "0"):gmatch("%d+") do parts[#parts + 1] = tonumber(number) or 0 end
	return parts
end

local function compareVersions(a, b)
	local ap, bp = versionParts(a), versionParts(b)
	for index = 1, math.max(#ap, #bp) do
		local av, bv = ap[index] or 0, bp[index] or 0
		if av ~= bv then return av < bv and -1 or 1 end
	end
	return 0
end

local function loadShippingDocuments()
	local rawFirst = VFS and VFS.RAW_FIRST or nil
	local bundled, bundledError = decodeJSONFile(DEFAULTS_BUNDLED_PATH, rawFirst)
	shipping.bundled = defaultsDocumentValid(bundled) and bundled or nil
	local cached, cachedError = decodeJSONFile(DEFAULTS_CACHE_PATH, rawFirst)
	local manifest, manifestError = decodeJSONFile(DEFAULTS_CACHE_MANIFEST_PATH, rawFirst)
	local cachePairValid = defaultsDocumentValid(cached) and type(manifest) == "table"
		and manifest.kind == "bar-controller-ui-defaults-manifest"
		and tostring(manifest.defaultsVersion or "") == tostring(cached.defaultsVersion or "")
	shipping.cached = cachePairValid and cached or nil
	shipping.manifest = cachePairValid and manifest or nil
	if shipping.cached and (not shipping.bundled or compareVersions(shipping.cached.defaultsVersion, shipping.bundled.defaultsVersion) >= 0) then
		shipping.activeVersion = tostring(shipping.cached.defaultsVersion or "cached")
		shipping.status = "cached shipping defaults " .. shipping.activeVersion
	elseif shipping.bundled then
		shipping.activeVersion = tostring(shipping.bundled.defaultsVersion or "bundled")
		shipping.status = "bundled shipping defaults " .. shipping.activeVersion
	else
		shipping.activeVersion = "fallback"
		shipping.status = "fallback defaults (bundled=" .. tostring(bundledError) .. ", cache=" .. tostring(cachedError or manifestError) .. ")"
	end
end

local function resolveSettings(recoveryPreview)
	layerSources, enforcedPaths = {}, {}
	local resolved = deepCopy(DEFAULTS)
	for scope, values in pairs(DEFAULTS) do
		if scope ~= "components" and type(values) == "table" then for key in pairs(values) do layerSources[propertyID(scope, key)] = "fallback" end end
	end
	for name, values in pairs(DEFAULTS.components) do for key in pairs(values) do layerSources[propertyID(name, key)] = "fallback" end end
	if shipping.bundled then mergeSettingsLayer(resolved, shipping.bundled.settings, "bundled shipping") end
	if shipping.cached and (not shipping.bundled or compareVersions(shipping.cached.defaultsVersion, shipping.bundled.defaultsVersion) >= 0) then
		mergeSettingsLayer(resolved, shipping.cached.settings, "cached shipping")
	end
	shippingBaseline = deepCopy(resolved)
	if personalSettings then mergeSettingsLayer(resolved, personalSettings, "personal") end
	local enforced = shipping.cached and shipping.cached.enforcedSettings or nil
	if type(enforced) == "table" then
		mergeSettingsLayer(resolved, enforced, "enforced remote")
		if type(shipping.cached.enforcedPaths) == "table" then
			for _, path in ipairs(shipping.cached.enforcedPaths) do enforcedPaths[tostring(path)] = true end
		end
	end
	if type(recoveryPreview) == "table" then mergeSettingsLayer(resolved, recoveryPreview, "unsaved recovery") end
	-- Authoring mode is explicitly local. A remote document can never enable publishing controls.
	resolved.authoring.developerAuthoring = personalSettings and personalSettings.authoring
		and personalSettings.authoring.developerAuthoring == true or false
	settings = resolved
	touch()
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

touch = function()
	revision = revision + 1
	recalculateScale()
end

local function deepEqual(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in pairs(a) do if not deepEqual(value, b[key]) then return false end end
	for key in pairs(b) do if a[key] == nil then return false end end
	return true
end

local function pushBounded(list, value)
	list[#list + 1] = value
	if #list > MAX_UNDO then table.remove(list, 1) end
end

local function beginMutation(label)
	if history.suppress or history.active then return false end
	pushBounded(history.undo, { settings = deepCopy(settings), authorData = deepCopy(authorData), label = label })
	history.redo = {}
	history.active = label or "edit"
	return true
end

local function endMutation() history.active = nil end

local function recordRecent(scope, key)
	local id = propertyID(scope, key)
	for index = #authorData.recent, 1, -1 do if authorData.recent[index] == id then table.remove(authorData.recent, index) end end
	table.insert(authorData.recent, 1, id)
	while #authorData.recent > 20 do table.remove(authorData.recent) end
end

local function isEnforced(scope, key) return enforcedPaths[propertyID(scope, key)] == true end

local function applyThemePreset(name)
	local presets = {
		["BAR Default"] = { 0.020, 0.030, 0.045, 0.94, 0.98, 1.00, 0.30, 0.66, 1.00 },
		Minimal = { 0.010, 0.014, 0.020, 0.92, 0.96, 0.98, 0.48, 0.76, 0.86 },
		Compact = { 0.018, 0.028, 0.040, 0.94, 0.98, 1.00, 0.34, 0.82, 0.92 },
		["Large Accessibility"] = { 0.000, 0.000, 0.000, 1.00, 1.00, 1.00, 1.00, 0.82, 0.12 },
		Transparent = { 0.010, 0.018, 0.026, 0.96, 0.98, 1.00, 0.36, 0.82, 0.94 },
		Ocean = { 0.018, 0.028, 0.040, 0.94, 0.98, 1.00, 0.34, 0.82, 0.92 },
		["High Contrast"] = { 0.000, 0.000, 0.000, 1.00, 1.00, 1.00, 1.00, 0.82, 0.12 },
		Soft = { 0.055, 0.060, 0.080, 0.92, 0.92, 0.96, 0.58, 0.72, 0.88 },
		Colorblind = { 0.025, 0.035, 0.050, 0.96, 0.97, 1.00, 0.95, 0.62, 0.12 },
	}
	local values = presets[name]
	if name == "Custom" then settings.theme.preset = name; return end
	if not values then return end
	settings.theme.preset = name
	settings.theme.backgroundR, settings.theme.backgroundG, settings.theme.backgroundB = values[1], values[2], values[3]
	settings.theme.foregroundR, settings.theme.foregroundG, settings.theme.foregroundB = values[4], values[5], values[6]
	settings.theme.accentR, settings.theme.accentG, settings.theme.accentB = values[7], values[8], values[9]
	if name == "Minimal" then
		settings.components.hints.backgroundOpacity = 0.34; settings.components.hints.borderOpacity = 0.25
		settings.components.hints.presentation = "Action Text Only"
	elseif name == "Compact" then
		settings.components.hints.compact = true; settings.components.hints.presentation = "Compact"
		settings.components.hints.padding = 7; settings.components.hints.rowSpacing = 2
	elseif name == "Large Accessibility" then
		settings.global.fontScale = math.max(settings.global.fontScale, 1.3)
		settings.components.hints.backgroundOpacity = 0.92
	elseif name == "Transparent" then
		settings.components.hints.backgroundOpacity = 0.18; settings.components.hints.borderOpacity = 0.38
		settings.components.hotSlots.backgroundOpacity = 0.24
	end
end

local COLOR_PREFIXES = { Background = "background", Foreground = "foreground", Accent = "accent", Muted = "muted", Danger = "danger" }

function extra.rgbToHsv(r, g, b)
	if radialStyleAPI and radialStyleAPI.RGBToHSV then return radialStyleAPI.RGBToHSV(r, g, b) end
	local maximum, minimum = math.max(r, g, b), math.min(r, g, b)
	local delta, hue = maximum - minimum, 0
	if delta > 0 then
		if maximum == r then hue = 60 * (((g - b) / delta) % 6)
		elseif maximum == g then hue = 60 * (((b - r) / delta) + 2)
		else hue = 60 * (((r - g) / delta) + 4) end
	end
	return hue, maximum == 0 and 0 or delta / maximum, maximum
end

function extra.hsvToRgb(h, s, v)
	if radialStyleAPI and radialStyleAPI.HSVToRGB then return radialStyleAPI.HSVToRGB(h, s, v) end
	h, s, v = (tonumber(h) or 0) % 360, clamp(s, 0, 1), clamp(v, 0, 1)
	local chroma = v * s; local x = chroma * (1 - math.abs(((h / 60) % 2) - 1)); local m = v - chroma
	local r, g, b
	if h < 60 then r, g, b = chroma, x, 0 elseif h < 120 then r, g, b = x, chroma, 0
	elseif h < 180 then r, g, b = 0, chroma, x elseif h < 240 then r, g, b = 0, x, chroma
	elseif h < 300 then r, g, b = x, 0, chroma else r, g, b = chroma, 0, x end
	return r + m, g + m, b + m
end

function extra.colorHex(r, g, b)
	if radialStyleAPI and radialStyleAPI.ColorHex then return radialStyleAPI.ColorHex(r, g, b) end
	return string.format("#%02X%02X%02X", math.floor(clamp(r, 0, 1) * 255 + 0.5),
		math.floor(clamp(g, 0, 1) * 255 + 0.5), math.floor(clamp(b, 0, 1) * 255 + 0.5))
end

function extra.rememberColor(hex)
	for index = #authorData.recentColors, 1, -1 do if authorData.recentColors[index] == hex then table.remove(authorData.recentColors, index) end end
	table.insert(authorData.recentColors, 1, hex); while #authorData.recentColors > 12 do table.remove(authorData.recentColors) end
end

function extra.syncThemeColorEditor(remember)
	local prefix = COLOR_PREFIXES[settings.theme.colorTarget] or "accent"
	local r, g, b = settings.theme[prefix .. "R"], settings.theme[prefix .. "G"], settings.theme[prefix .. "B"]
	settings.theme.colorHex = extra.colorHex(r, g, b)
	settings.theme.colorHue, settings.theme.colorSaturation, settings.theme.colorValue = extra.rgbToHsv(r, g, b)
	if remember then extra.rememberColor(settings.theme.colorHex) end
end

local mutateAuthorData

function extra.favoriteCurrentColor(enabled)
	local hex = tostring(settings.theme.colorHex or "")
	return mutateAuthorData((enabled and "Favorite " or "Unfavorite ") .. hex, function()
		authorData.favoriteColors[hex] = enabled == true or nil
	end)
end

local function getScope(scope)
	if scope == "gameplay" then
		extra.gameplaySettings = extra.gameplaySettings or {}
		extra.gameplayDefaults = extra.gameplayDefaults or { lbTapMaxSeconds = 0.20, lbTacticalHoldSeconds = 0.20, visibleSelectionFilter = "Combat" }
		local api = WG and WG.BARControllerSupport
		if api and type(api.GetSetting) == "function" then
			for key in pairs(extra.gameplayDefaults) do extra.gameplaySettings[key] = api.GetSetting(key) end
		end
		return extra.gameplaySettings, extra.gameplayDefaults
	end
	if scope == "global" or scope == "theme" or scope == "authoring" then return settings[scope], shippingBaseline[scope] or DEFAULTS[scope] end
	return settings.components[scope], shippingBaseline.components[scope] or DEFAULTS.components[scope]
end

local function isRadialComponentScope(scope)
	for _, candidate in ipairs(radialComponentScopes) do if scope == candidate then return true end end
	return false
end

local function isRadialStyleKey(key) return radialTypographyDefaults[key] ~= nil end

local radialStyleCache = { revision = -1, values = {} }
local setValue
function extra.getResolvedRadialStyle(componentName)
	if not radialStyleAPI then return nil end
	if radialStyleCache.revision ~= revision then radialStyleCache.revision, radialStyleCache.values = revision, {} end
	componentName = tostring(componentName or "buildRadial")
	if not radialStyleCache.values[componentName] then
		radialStyleCache.values[componentName] = radialStyleAPI.Resolve(settings.components.radials, settings.components[componentName])
	end
	return radialStyleCache.values[componentName]
end

function extra.getColorState(row)
	local target = getScope(row[1]); local prefix = string.sub(row[2], 1, -2)
	local opacityKey = string.gsub(prefix, "Color$", "") .. "Opacity"
	if isRadialComponentScope(row[1]) and target and target.typographyOverride ~= true then target = settings.components.radials end
	local r, g, b = tonumber(target and target[prefix .. "R"]) or 1, tonumber(target and target[prefix .. "G"]) or 1,
		tonumber(target and target[prefix .. "B"]) or 1
	local alpha = target and target[opacityKey]; if alpha == nil then alpha = 1 end
	local h, s, v = extra.rgbToHsv(r, g, b)
	return { r = r, g = g, b = b, a = tonumber(alpha) or 1, h = h, s = s, v = v,
		hex = radialStyleAPI and radialStyleAPI.ColorHex and radialStyleAPI.ColorHex(r, g, b, alpha) or extra.colorHex(r, g, b) }
end

function extra.applyColor(row, r, g, b, alpha, remember)
	local prefix = string.sub(row[2], 1, -2); local target = getScope(row[1])
	local opacityKey = string.gsub(prefix, "Color$", "") .. "Opacity"
	if isRadialComponentScope(row[1]) and target and target.typographyOverride ~= true then
		editor.status = "Enable 'Use custom typography' before changing " .. tostring(row[1]); return false
	end
	setValue(row[1], prefix .. "R", clamp(r, 0, 1)); setValue(row[1], prefix .. "G", clamp(g, 0, 1)); setValue(row[1], prefix .. "B", clamp(b, 0, 1))
	local _, defaultsForScope = getScope(row[1]); if defaultsForScope[opacityKey] ~= nil then setValue(row[1], opacityKey, clamp(alpha, 0, 1)) end
	if remember then extra.rememberColor(radialStyleAPI and radialStyleAPI.ColorHex(r, g, b, alpha) or extra.colorHex(r, g, b)) end
	return true
end

function extra.adjustColor(row, channel, normalized, remember)
	local value = extra.getColorState(row); normalized = clamp(normalized, 0, 1)
	if channel == "h" then value.h = normalized * 360 elseif channel == "s" then value.s = normalized
	elseif channel == "v" then value.v = normalized else value.a = normalized end
	value.r, value.g, value.b = extra.hsvToRgb(value.h, value.s, value.v)
	return extra.applyColor(row, value.r, value.g, value.b, value.a, remember)
end

function extra.applyColorPreset(row, preset)
	if not row or not preset then return false end
	local ownMutation = beginMutation("Apply " .. tostring(preset[1]) .. " to " .. propertyID(row[1], row[2]))
	local changed = extra.applyColor(row, preset[2], preset[3], preset[4], preset[5] or 1, true)
	if ownMutation then endMutation() end; if changed then editor.status = "Applied " .. tostring(preset[1]) end
	return changed
end

function extra.getColorEditorPresets()
	local result, seen = {}, {}
	for _, preset in ipairs(radialStyleAPI and radialStyleAPI.COLOR_PRESETS or {}) do result[#result + 1] = preset; seen[radialStyleAPI.ColorHex(preset[2], preset[3], preset[4], preset[5])] = true end
	local function append(name, hex)
		if #result >= 30 or seen[hex] or not radialStyleAPI or not radialStyleAPI.ParseHexColor then return end
		local r, g, b, a = radialStyleAPI.ParseHexColor(hex); if r then result[#result + 1] = { name .. " " .. hex, r, g, b, a }; seen[hex] = true end
	end
	local favorites = {}; for hex in pairs(authorData.favoriteColors or {}) do favorites[#favorites + 1] = hex end; table.sort(favorites)
	for _, hex in ipairs(favorites) do append("Favorite", hex) end
	for _, hex in ipairs(authorData.recentColors or {}) do append("Recent", hex) end
	return result
end

local authoringPropertyHook
local themePropertyHook

setValue = function(scope, key, value)
	local target, defaultsForScope = getScope(scope)
	if not target or defaultsForScope[key] == nil then return nil end
	if isRadialComponentScope(scope) and isRadialStyleKey(key) and target.typographyOverride ~= true then
		editor.status = "Enable 'Use custom typography' before changing " .. tostring(scope)
		return settings.components.radials[key]
	end
	if scope == "gameplay" then
		local api = WG and WG.BARControllerSupport
		if not api or type(api.SetSetting) ~= "function" then editor.status = "Gameplay settings API unavailable"; return target[key] end
		local validated = validateValue(key, value, defaultsForScope[key])
		target[key] = api.SetSetting(key, validated)
		editor.status = "Changed gameplay " .. tostring(key)
		return target[key]
	end
	if isEnforced(scope, key) then editor.status = propertyID(scope, key) .. " is enforced by remote policy"; return target[key] end
	local validated = validateValue(key, value, defaultsForScope[key])
	if deepEqual(target[key], validated) then return target[key] end
	local ownMutation = beginMutation("Change " .. propertyID(scope, key))
	target[key] = validated
	if scope == "hotSlots" and key == "slotSize" then target.slotWidth, target.slotHeight = validated, validated end
	if scope == "theme" and key == "preset" then applyThemePreset(validated) end
	if authoringPropertyHook then authoringPropertyHook(scope, key, validated) end
	if themePropertyHook then themePropertyHook(scope, key, validated) end
	recordRecent(scope, key)
	layerSources[propertyID(scope, key)] = "unsaved preview"
	history.dirty = true
	touch()
	if ownMutation then endMutation() end
	return target[key]
end

local function resetComponent(scope)
	if scope == "gameplay" then
		local target, gameplayDefaults = getScope(scope)
		local api = WG and WG.BARControllerSupport
		if not target or not api then editor.status = "Gameplay settings API unavailable"; return end
		for key, fallback in pairs(gameplayDefaults) do
			if type(api.ResetSetting) == "function" then target[key] = api.ResetSetting(key)
			elseif type(api.SetSetting) == "function" then target[key] = api.SetSetting(key, fallback) end
		end
		editor.status = "Reset controller input settings"
		return
	end
	local ownMutation = beginMutation("Reset " .. tostring(scope))
	local target = getScope(scope)
	local previous = target and deepCopy(target) or nil
	if scope == "global" or scope == "theme" or scope == "authoring" then settings[scope] = deepCopy(shippingBaseline[scope] or DEFAULTS[scope])
	elseif DEFAULTS.components[scope] then settings.components[scope] = deepCopy(shippingBaseline.components[scope] or DEFAULTS.components[scope]) end
	local resetTarget = getScope(scope)
	if previous and resetTarget then for key in pairs(previous) do if isEnforced(scope, key) then resetTarget[key] = previous[key] end end end
	history.dirty = true
	touch()
	if ownMutation then endMutation() end
end

local function resetAll()
	local ownMutation = beginMutation("Reset all")
	local previous = deepCopy(settings)
	settings = deepCopy(shippingBaseline)
	for path in pairs(enforcedPaths) do
		local scope, key = path:match("^([^.]+)%.(.+)$")
		if scope and key then
			local topLevel = scope == "global" or scope == "theme" or scope == "authoring"
			local oldScope = topLevel and previous[scope] or previous.components[scope]
			local newScope = topLevel and settings[scope] or settings.components[scope]
			if oldScope and newScope then newScope[key] = oldScope[key] end
		end
	end
	authorData.hiddenActions, authorData.actionOrder, authorData.actionCategoryOverrides = {}, {}, {}
	authorData.shortLabels, authorData.categoryVisibility, authorData.categoryOrder = {}, {}, {}
	migratedLegacyLauncher = false
	history.dirty = true
	touch()
	if ownMutation then endMutation() end
end

local function revertSession()
	local ownMutation = beginMutation("Revert session")
	settings, authorData = deepCopy(history.lastSaved), deepCopy(history.lastSavedAuthorData)
	history.dirty = false; editor.recoveryAvailable = false; touch()
	if ownMutation then endMutation() end
	editor.status = "Reverted unsaved session changes"; return true
end

local function undo()
	local entry = table.remove(history.undo)
	if not entry then editor.status = "Nothing to undo"; return false end
	pushBounded(history.redo, { settings = deepCopy(settings), authorData = deepCopy(authorData), label = entry.label })
	settings = deepCopy(entry.settings); authorData = deepCopy(entry.authorData or authorData)
	history.dirty = not deepEqual(settings, history.lastSaved) or not deepEqual(authorData, history.lastSavedAuthorData)
	endMutation(); touch(); editor.status = "Undid: " .. tostring(entry.label); return true
end

local function redo()
	local entry = table.remove(history.redo)
	if not entry then editor.status = "Nothing to redo"; return false end
	pushBounded(history.undo, { settings = deepCopy(settings), authorData = deepCopy(authorData), label = entry.label })
	settings = deepCopy(entry.settings); authorData = deepCopy(entry.authorData or authorData)
	history.dirty = not deepEqual(settings, history.lastSaved) or not deepEqual(authorData, history.lastSavedAuthorData)
	endMutation(); touch(); editor.status = "Redid: " .. tostring(entry.label); return true
end

local function savePersonal()
	personalSettings = deepCopy(settings)
	history.lastSaved = deepCopy(settings)
	history.lastSavedAuthorData = deepCopy(authorData)
	history.dirty = false
	editor.recoveryAvailable = false
	editor.status = "Personal controller UI settings saved"
	return true
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
	baseWidth = item.width and item.width * REFERENCE_WIDTH or baseWidth
	baseHeight = item.height and item.height * REFERENCE_HEIGHT or baseHeight
	local width, height = baseWidth * scale, baseHeight * scale
	local margin = settings.global.safeMargin * automaticScale
	local x1, y1 = (item.x or 0.5) * viewX, (item.y or 0.5) * viewY
	if item.anchor == "center" then x1, y1 = x1 - width * 0.5, y1 - height * 0.5
	elseif item.anchor == "bottomcenter" then x1 = x1 - width * 0.5
	elseif item.anchor == "bottomright" then x1 = x1 - width end
	x1 = clamp(x1, margin, math.max(margin, viewX - margin - width))
	y1 = clamp(y1, margin, math.max(margin, viewY - margin - height))
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
local hintAnimationTime = 0
local activeHintContextLabel = "Normal Gameplay"
local hintHits = {}
local hintMoreHit = nil
extra.hintContextState = nil

local DEFAULT_HINT_CATEGORIES = {
	{ id = "Selection", order = 10 }, { id = "Commands", order = 20 }, { id = "Camera", order = 30 },
	{ id = "Building", order = 40 }, { id = "Placement", order = 50 }, { id = "Factory", order = 60 },
	{ id = "Tactical", order = 70 }, { id = "Radials", order = 80 }, { id = "Groups / Hot Slots", order = 90 },
	{ id = "Mouse Mode", order = 100 }, { id = "Pregame", order = 110 }, { id = "Editor", order = 120 },
	{ id = "System", order = 130 }, { id = "Advanced", order = 140 },
}

local ACTION_CATEGORIES = {
	select = "Selection", cancel = "Selection", smartAction = "Commands", commandLayer = "Commands",
	insertNextCommandModifier = "Commands", appendQueueModifier = "Commands", pitchModifier = "Camera",
	buildRadial = "Building", removeQueuedCommand = "Factory", removeLastQueuedCommand = "Factory",
	radialSelect = "Radials", radialCancel = "Radials", radialQuick = "Radials", radialClose = "Radials",
	radialPrevPage = "Radials", radialNextPage = "Radials", place = "Placement", placeStay = "Placement",
	cancelPlacement = "Placement", rotateBuildingLeft = "Placement", rotateBuildingRight = "Placement",
	spacingUp = "Placement", spacingDown = "Placement", patternPrev = "Placement", patternNext = "Placement",
	tacticalSelect = "Tactical", tacticalCancel = "Tactical", tacticalClose = "Tactical",
	commandUp = "Tactical", commandDown = "Tactical", commandLeft = "Tactical", commandRight = "Tactical",
	idlePrev = "Selection", idleNext = "Selection", controlGroupModifier = "Groups / Hot Slots",
	groupSlotUp = "Groups / Hot Slots", groupSlotDown = "Groups / Hot Slots",
	groupRecallOrAssign = "Groups / Hot Slots", groupAssign = "Groups / Hot Slots",
	groupClear = "Groups / Hot Slots", selectCommander = "Groups / Hot Slots",
}

local function addHint(def)
	if type(def) == "table" and type(def.id) == "string" then
		def.group = def.group or (def.action and ACTION_CATEGORIES[def.action]) or "System"
		hintRegistry[def.id] = def
		hintRevision = hintRevision + 1
	end
end

local function bind(action, label, when, priority, options)
	options = options or {}
	addHint({ id = options.id or action .. ":" .. label, action = action, label = label,
		compactLabel = options.compactLabel, when = when, priority = priority or 100,
		hold = options.hold, group = options.group or ACTION_CATEGORIES[action] or "System" })
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
local function isVisibleSelectionRadial(c) return c.visibleSelectionRadialOpen and not c.bindingsOpen and not c.layoutEditorOpen end
local function isDgun(c) return c.dgunMode and not c.bindingsOpen and not c.layoutEditorOpen end
local function isStaged(c) return c.stagedTactical and not c.bindingsOpen and not c.layoutEditorOpen end
local function isAreaSelection(c) return c.areaSelection and not c.selectionRadialOpen and not c.bindingsOpen and not c.layoutEditorOpen end
local function isLongStress(c) return c.longBindingStress == true end
local function isCommandLayer(c) return c.commandLayer and not c.bindingsOpen and not c.layoutEditorOpen end
local function isLBTacticalLayer(c) return c.lbTacticalLayer and c.hasSelection and not c.visibleSelectionRadialOpen
	and not c.bindingsOpen and not c.layoutEditorOpen end
local function hasModalGameplayContext(c)
	return c.buildPlacement or c.buildMenuOpen or c.tacticalRadialOpen or c.selectionRadialOpen or c.visibleSelectionRadialOpen
		or c.dgunMode or c.stagedTactical or c.areaSelection or c.pregame or c.mouseMode
end
local function isGroupLayer(c) return c.controlGroupLayer and not c.commandLayer and not hasModalGameplayContext(c) and not c.bindingsOpen and not c.layoutEditorOpen end
local function isPitchLayer(c) return c.pitchLayer and not c.lbTacticalLayer and not c.commandLayer and not c.controlGroupLayer
	and not hasModalGameplayContext(c) and not c.bindingsOpen and not c.layoutEditorOpen end
local function isNormal(c)
	return not c.pregame and not c.mouseMode and not c.bindingsOpen and not c.layoutEditorOpen
		and not c.buildPlacement and not c.buildMenuOpen and not c.tacticalRadialOpen and not c.selectionRadialOpen
		and not c.visibleSelectionRadialOpen and not c.lbTacticalLayer
		and not c.dgunMode and not c.stagedTactical and not c.areaSelection
		and not c.commandLayer
		and not c.controlGroupLayer and not c.pitchLayer and not c.longBindingStress
end

bind("cancel", "Close Layout Editor", isEditor, 1)
addHint({ id = "editor-nav", inputs = { "dpadUp", "dpadDown", "dpadLeft", "dpadRight" }, label = "Navigate / Adjust", when = isEditor, priority = 2, group = "Editor" })
addHint({ id = "editor-tabs", inputs = { "LB", "RB" }, label = "Change Section", when = isEditor, priority = 3, group = "Editor" })
bind("select", "Edit Binding", isBindings, 1)
bind("cancel", "Close Bindings", isBindings, 2)
bind("radialPrevPage", "Previous Category", isBindings, 3)
bind("radialNextPage", "Next Category", isBindings, 4)
bind("controlGroupModifier", "Bindings / Settings Tab", isBindings, 5)
bind("select", "Click / Set Start", isPregame, 1)
bind("smartAction", "Click / Set Start", isPregame, 2)
bind("pitchModifier", "Camera Tilt / Rotate", isPregame, 3)
addHint({ id = "pregame-stick", inputs = { "rightStick" }, label = "Move Cursor", when = isPregame, priority = 4, group = "Pregame" })
bind("select", "Mouse Click", isMouse, 1)
bind("smartAction", "Mouse Click", isMouse, 2)
addHint({ id = "mouse-stick", inputs = { "rightStick" }, label = "Move Cursor", when = isMouse, priority = 3, group = "Mouse Mode" })
bind("place", "Confirm Placement", isPlacement, 1)
bind("placeStay", "Place and Continue", isPlacement, 2)
bind("cancelPlacement", "Cancel Placement", isPlacement, 3)
bind("rotateBuildingLeft", "Rotate Left", isPlacement, 4)
bind("rotateBuildingRight", "Rotate Right", isPlacement, 5)
bind("spacingUp", "Increase Spacing", isPlacement, 6)
bind("spacingDown", "Decrease Spacing", isPlacement, 7)
bind("patternPrev", "Cycle Pattern", isPlacement, 8)
bind("patternPrev", "Force Grid Pattern", isPlacement, 9, { hold = true, id = "placement-pattern-hold" })
bind("patternNext", "Next Pattern", isPlacement, 9, { id = "placement-pattern-next" })
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
bind("radialClose", "Close Factory Radial", isFactoryBuild, 7, { id = "factory-close-alt" })
bind("removeQueuedCommand", "Remove Current / Next Queue Item", isFactoryBuild, 8)
bind("removeLastQueuedCommand", "Remove Last Queue Item", isFactoryBuild, 9)
bind("tacticalSelect", "Choose Command", isTactical, 1)
bind("tacticalCancel", "Close Tactical Radial", isTactical, 2)
bind("tacticalClose", "Close Tactical Radial", isTactical, 3)
bind("commandUp", "Guard / Patrol", isTactical, 4)
bind("commandDown", "Reclaim", isTactical, 5)
bind("commandLeft", "Previous Tactical Command", isTactical, 6)
bind("commandRight", "Next Tactical Command", isTactical, 7)
bind("radialSelect", "Choose Selection Filter", isSelectionRadial, 1)
bind("radialCancel", "Cancel Selection", isSelectionRadial, 2)
bind("radialPrevPage", "Previous Filter", isSelectionRadial, 3)
bind("radialNextPage", "Next Filter", isSelectionRadial, 4)
addHint({ id = "visible-filter-choose", inputs = { "leftStick" }, label = "Choose Filter",
	when = isVisibleSelectionRadial, priority = 1, group = "Selection" })
addHint({ id = "visible-filter-confirm", inputs = { "LT" }, label = "Release to Confirm",
	when = isVisibleSelectionRadial, priority = 2, group = "Selection" })
bind("cancel", "Cancel", isVisibleSelectionRadial, 3, { id = "visible-filter-cancel", group = "Selection" })
addHint({ id = "dgun-fire", inputs = { "RT" }, label = "Fire DGUN", when = isDgun, priority = 1, group = "Commands" })
bind("cancel", "Exit DGUN", isDgun, 2)
addHint({ id = "dgun-aim", inputs = { "rightStick" }, label = "Aim", when = isDgun, priority = 3, group = "Commands" })
bind("place", "Confirm Tactical Target", isStaged, 1)
bind("cancelPlacement", "Cancel Tactical Target", isStaged, 2)
bind("appendQueueModifier", "Repeat / Append", isStaged, 3)
bind("select", "Release to Select Area", isAreaSelection, 1)
bind("cancel", "Cancel Area Selection", isAreaSelection, 2)
addHint({ id = "area-radius", inputs = { "rightStick" }, label = "Adjust Radius / Filter", when = isAreaSelection, priority = 3, group = "Selection" })
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
addHint({ id = "lb-tactical-stop", action = "cancel", chordActions = { "pitchModifier", "cancel" },
	label = "Stop", when = isLBTacticalLayer, priority = 1, group = "Tactical" })
addHint({ id = "lb-tactical-primary", action = "select", chordActions = { "pitchModifier", "select" },
	label = "Tactical Primary", labelResolver = function(c)
		if c.selectionProfile == "builder" then return "Repair Area" end
		if c.selectionProfile == "air_transport" then return "Unload Unit / Hold for Area" end
		if c.selectionProfile == "factory" then return "Fight" end
		return "Attack / Fight"
	end, when = isLBTacticalLayer, priority = 2, group = "Tactical" })
addHint({ id = "lb-tactical-smart", action = "smartAction", chordActions = { "pitchModifier", "smartAction" },
	label = "Tactical Smart", labelResolver = function(c)
		if c.selectionProfile == "builder" then return "Reclaim Area" end
		if c.selectionProfile == "air_transport" then return "Load Unit / Hold for Area" end
		if c.selectionProfile == "factory" then return "Fight" end
		return "Attack"
	end, when = isLBTacticalLayer, priority = 3, group = "Tactical" })
addHint({ id = "lb-tactical-utility", action = "insertNextCommandModifier",
	chordActions = { "pitchModifier", "insertNextCommandModifier" }, label = "Patrol",
	when = function(c) return isLBTacticalLayer(c) and c.selectionProfile ~= "air_transport" end,
	priority = 4, group = "Tactical" })
addHint({ id = "lb-tactical-wait", action = "cancel", chordActions = { "pitchModifier", "cancel" },
	label = "Wait", hold = true, when = isLBTacticalLayer, priority = 5, group = "Tactical" })
bind("select", "Select Unit", isNormal, 1)
bind("smartAction", "Smart Action", function(c) return isNormal(c) and not c.hasTransport end, 3)
bind("smartAction", "Load / Move Transport", function(c) return isNormal(c) and c.hasTransport end, 3, { id = "normal-transport-smart" })
bind("smartAction", "Draw Move / Build Path", function(c) return isNormal(c) and c.hasSelection end, 4, { hold = true, id = "normal-smart-hold" })
bind("cancel", "Clear Selection", function(c) return isNormal(c) and c.hasSelection end, 5)
bind("buildRadial", "Build / Factory Radial", function(c) return isNormal(c) and (c.hasBuilder or c.hasFactory) end, 6)
bind("commandLayer", "Tactical Command Layer", function(c) return isNormal(c) and c.hasSelection end, 7)
addHint({ id = "normal-visible-select", action = "pitchModifier", label = "Select Visible Combat",
	labelResolver = function(c)
		local behavior = extra.SharedRenderers and extra.SharedRenderers.SelectionBehavior
		return behavior and behavior.FilterShortLabel(c.visibleSelectionFilter) or "Select Visible Combat"
	end, when = isNormal, priority = 8, group = "Selection" })
bind("idlePrev", "Previous Idle Unit", isNormal, 9)
bind("idleNext", "Next Idle Unit", isNormal, 10)
bind("controlGroupModifier", "Control Groups", isNormal, 11)
bind("selectCommander", "Select Commander", isNormal, 9, { id = "normal-select-commander" })

addHint({ id = "shortcut-mouse", shortcut = "mouseMode", label = "Toggle Mouse Mode", priority = 900,
	when = function(c) return not c.bindingsOpen and not c.layoutEditorOpen end })
addHint({ id = "shortcut-editor", shortcut = "uiSettings", label = "Controller UI Settings", hold = true, priority = 901,
	when = function(c) return not c.bindingsOpen end })
addHint({ id = "stress-long-chord", inputs = { "back", "start", "LB", "RB" },
	label = "Open the intentionally verbose controller interface authoring and accessibility configuration suite",
	compactLabel = "Open UI authoring", when = isLongStress, priority = 1, group = "Advanced" })
addHint({ id = "stress-long-hold", inputs = { "leftStickClick", "rightStickClick", "dpadDown" },
	label = "Hold this unusually long combination to validate wrapping, shrinking, clipping, and scrolling behavior",
	compactLabel = "Overflow stress", hold = true, when = isLongStress, priority = 2, group = "Advanced" })
addHint({ id = "stress-long-action", inputs = { "rightStick", "dpadLeft", "dpadRight" },
	label = "Preview a deliberately oversized action description without issuing any gameplay command",
	compactLabel = "Safe long preview", when = isLongStress, priority = 3, group = "Advanced" })

local function contextSignature(context)
	local keys = { "pregame", "mouseMode", "bindingsOpen", "layoutEditorOpen", "buildMenuOpen", "buildPlacement",
		"factoryRadialOpen", "tacticalRadialOpen", "selectionRadialOpen", "visibleSelectionRadialOpen", "areaSelection", "stagedTactical", "dgunMode",
		"selectedCount", "hasBuilder", "hasFactory", "hasTransport", "hasWorldTarget", "hoverTargetType", "smartTargetType",
		"commandLayer", "controlGroupLayer", "pitchLayer", "lbTacticalLayer", "visibleSelectionFilter", "selectionProfile", "selectionRevision" }
	local parts = {}
	for i, key in ipairs(keys) do parts[i] = tostring(context[key]) end
	return table.concat(parts, "|")
end

function extra.isConfirmedHintModal(context)
	return settings.components.hints.confirmedModalImmediate ~= false and (context.buildMenuOpen or context.buildPlacement
		or context.tacticalRadialOpen or context.selectionRadialOpen or context.visibleSelectionRadialOpen
		or context.stagedTactical or context.dgunMode or context.bindingsOpen or context.layoutEditorOpen
		or context.lbTacticalLayer)
end

local function resolveInputs(def, api)
	if type(def.chordActions) == "table" and type(api.GetBinding) == "function" then
		local inputs = {}
		for _, action in ipairs(def.chordActions) do inputs[#inputs + 1] = api.GetBinding(action) end
		return inputs
	end
	if def.action and type(api.GetBinding) == "function" then return { api.GetBinding(def.action) } end
	if def.shortcut and type(api.GetShortcutBinding) == "function" then return api.GetShortcutBinding(def.shortcut) end
	return def.inputs
end

function extra.normalLayerContext(context)
	local base = deepCopy(context or {})
	base.pregame, base.mouseMode, base.bindingsOpen, base.layoutEditorOpen = false, false, false, false
	base.buildPlacement, base.buildMenuOpen, base.factoryRadialOpen = false, false, false
	base.tacticalRadialOpen, base.selectionRadialOpen = false, false
	base.visibleSelectionRadialOpen, base.lbTacticalLayer = false, false
	base.dgunMode, base.stagedTactical, base.areaSelection = false, false, false
	base.commandLayer, base.controlGroupLayer, base.pitchLayer = false, false, false
	return base
end

function extra.activeShippingDocument()
	if shipping.cached and (not shipping.bundled or compareVersions(shipping.cached.defaultsVersion, shipping.bundled.defaultsVersion) >= 0) then
		return shipping.cached
	end
	return shipping.bundled
end

function extra.activeHintProfile()
	local document = extra.activeShippingDocument()
	return document and type(document.hintProfile) == "table" and document.hintProfile or {}
end

function extra.arrayIndex(values, wanted)
	for index, value in ipairs(type(values) == "table" and values or {}) do if value == wanted then return index end end
	return nil
end

function extra.categoryVisible(category, profile)
	if authorData.categoryVisibility[category] ~= nil then return authorData.categoryVisibility[category] ~= false end
	for _, item in ipairs(type(profile.categories) == "table" and profile.categories or DEFAULT_HINT_CATEGORIES) do
		if item.id == category then return item.visible ~= false end
	end
	return true
end

local function rebuildHints(context, api)
	visibleHints = {}
	hintAlpha = settings.components.hints.fadeDuration > 0 and 0 or 1
	activeHintContextLabel = tostring(context.name or (context.layoutEditorOpen and "Layout Editor")
		or (context.bindingsOpen and "Bindings UI") or (context.pregame and "Pregame")
		or (context.mouseMode and "Mouse Mode") or (context.buildPlacement and "Build Placement")
		or (context.factoryRadialOpen and "Factory Radial") or (context.buildMenuOpen and "Build Radial")
		or (context.tacticalRadialOpen and "Tactical Radial") or (context.selectionRadialOpen and "Selection Radial")
		or (context.visibleSelectionRadialOpen and "Visible Selection Filter Radial")
		or (context.lbTacticalLayer and "LB Tactical Layer")
		or (context.controlGroupLayer and "Groups / Hot Slots") or (context.commandLayer and "Commands")
		or "Normal Gameplay")
	local mode = settings.components.hints.mode or "Contextual"
	local profile = extra.activeHintProfile()
	local layeredContext = mode == "Layered" and not context.bindingsOpen and not context.layoutEditorOpen
		and not context.pregame and not context.mouseMode and extra.normalLayerContext(context) or nil
	for _, def in pairs(hintRegistry) do
		local actionID = def.action or def.id
		local hidden = authorData.hiddenActions[actionID]
		if hidden == nil then hidden = extra.arrayIndex(profile.hiddenActions, actionID) ~= nil end
		local available = type(def.when) ~= "function" or def.when(context)
		local layer = 0
		if layeredContext and not available then
			available = type(def.when) ~= "function" or def.when(layeredContext)
			if available then layer = 1 end
		end
		if mode == "Everything" and def.group ~= "Advanced" then available = true end
		if mode == "Minimal" and (def.priority or 100) > 5 then available = false end
		local category = authorData.actionCategoryOverrides[actionID]
			or (type(profile.actionCategoryOverrides) == "table" and profile.actionCategoryOverrides[actionID]) or def.group
		if available and not hidden and extra.categoryVisible(category, profile) then
			local inputs = resolveInputs(def, api)
			if type(inputs) == "table" and #inputs > 0 and inputs[1] ~= "none" then
				local profileOrder = extra.arrayIndex(profile.actionOrdering, actionID)
				local order = tonumber(authorData.actionOrder[actionID]) or profileOrder or def.priority or 100
				local shortLabel = authorData.shortLabels[actionID]
					or (type(profile.defaultShortLabels) == "table" and profile.defaultShortLabels[actionID]) or def.compactLabel
				local label = type(def.labelResolver) == "function" and def.labelResolver(context) or def.label
				visibleHints[#visibleHints + 1] = {
					id = def.id, action = actionID, inputs = inputs, label = label, compactLabel = shortLabel,
					hold = def.hold, priority = order, group = category, layer = layer,
				}
			end
		end
	end
	table.sort(visibleHints, function(a, b)
		if a.layer ~= b.layer then return a.layer < b.layer end
		if a.priority ~= b.priority then return a.priority < b.priority end
		return a.id < b.id
	end)
end

local auditContexts = {
	{ name = "normal" }, { name = "selected", hasSelection = true, selectedCount = 1, hasBuilder = true },
	{ name = "factory", buildMenuOpen = true, factoryRadialOpen = true, hasSelection = true, hasFactory = true },
	{ name = "build", buildMenuOpen = true, hasSelection = true, hasBuilder = true },
	{ name = "placement", buildPlacement = true, hasSelection = true, hasBuilder = true },
	{ name = "tactical", tacticalRadialOpen = true, hasSelection = true },
	{ name = "selection", selectionRadialOpen = true, areaSelection = true },
	{ name = "groups", controlGroupLayer = true, hasSelection = true },
	{ name = "command", commandLayer = true, hasSelection = true },
	{ name = "pitch", pitchLayer = true }, { name = "pregame", pregame = true },
	{ name = "mouse", mouseMode = true }, { name = "bindings", bindingsOpen = true },
	{ name = "editor", layoutEditorOpen = true }, { name = "dgun", dgunMode = true },
	{ name = "staged", stagedTactical = true }, { name = "area", areaSelection = true },
	{ name = "long-stress", longBindingStress = true },
}

local function getHintAudit(api)
	local registeredActions, bindingActions = {}, {}
	for _, def in pairs(hintRegistry) do if def.action then registeredActions[def.action] = true end end
	local definitionsFromGame = api and type(api.GetBindingDefinitions) == "function" and api.GetBindingDefinitions() or {}
	for _, def in ipairs(type(definitionsFromGame) == "table" and definitionsFromGame or {}) do bindingActions[def.action] = def end
	local missing, unregistered, neverVisible = {}, {}, {}
	for action, def in pairs(bindingActions) do if not registeredActions[action] then missing[#missing + 1] = { action = action, group = def.group, label = def.label } end end
	for action in pairs(registeredActions) do if not bindingActions[action] then unregistered[#unregistered + 1] = action end end
	for id, def in pairs(hintRegistry) do
		local appeared = false
		for _, context in ipairs(auditContexts) do
			local ok, result = true, true
			if type(def.when) == "function" then ok, result = pcall(def.when, context) end
			if ok and result then appeared = true; break end
		end
		if not appeared then neverVisible[#neverVisible + 1] = id end
	end
	table.sort(missing, function(a, b) return a.action < b.action end); table.sort(unregistered); table.sort(neverVisible)
	return { missingBindings = missing, unregisteredActions = unregistered, neverVisible = neverVisible,
		bindingCount = #definitionsFromGame, hintCount = (function() local count = 0; for _ in pairs(hintRegistry) do count = count + 1 end; return count end)() }
end

mutateAuthorData = function(label, callback)
	local ownMutation = beginMutation(label)
	callback(); history.dirty = true; lastContextSignature = ""; touch()
	if ownMutation then endMutation() end
	return true
end

local function setActionHidden(action, hidden)
	action = tostring(action or "")
	if action == "" then return false end
	return mutateAuthorData((hidden and "Hide " or "Show ") .. action, function() authorData.hiddenActions[action] = hidden == true end)
end

local getHintCategories

local function canonicalCategory(category)
	category = tostring(category or "")
	for _, item in ipairs(getHintCategories and getHintCategories() or DEFAULT_HINT_CATEGORIES) do
		if string.lower(tostring(item.id)) == string.lower(category) then return item.id end
	end
	return category
end

local function setActionCategory(action, category)
	action, category = tostring(action or ""), canonicalCategory(category)
	if action == "" then return false end
	return mutateAuthorData("Categorize " .. action, function() authorData.actionCategoryOverrides[action] = category ~= "" and category or nil end)
end

local function setActionOrder(action, order)
	action = tostring(action or "")
	if action == "" then return false end
	return mutateAuthorData("Reorder " .. action, function() authorData.actionOrder[action] = tonumber(order) end)
end

local function setActionShortLabel(action, label)
	action, label = tostring(action or ""), tostring(label or "")
	if action == "" then return false end
	return mutateAuthorData("Label " .. action, function() authorData.shortLabels[action] = label ~= "" and label or nil end)
end

local function setCategoryVisible(category, visible)
	category = canonicalCategory(category)
	if category == "" then return false end
	return mutateAuthorData((visible and "Show " or "Hide ") .. category, function() authorData.categoryVisibility[category] = visible == true end)
end

getHintCategories = function()
	local profile, result, seen = extra.activeHintProfile(), {}, {}
	for _, item in ipairs(type(profile.categories) == "table" and profile.categories or DEFAULT_HINT_CATEGORIES) do
		local copy = deepCopy(item); copy.order = tonumber(authorData.categoryOrder[copy.id]) or tonumber(copy.order) or 100
		copy.visible = extra.categoryVisible(copy.id, profile); result[#result + 1], seen[copy.id] = copy, true
	end
	for _, item in ipairs(DEFAULT_HINT_CATEGORIES) do if not seen[item.id] then result[#result + 1] = deepCopy(item) end end
	table.sort(result, function(a, b) return (a.order or 100) < (b.order or 100) end)
	return result
end

local function resetHintOrganization()
	return mutateAuthorData("Restore shipped hint organization", function()
		authorData.hiddenActions, authorData.actionOrder, authorData.actionCategoryOverrides = {}, {}, {}
		authorData.shortLabels, authorData.categoryVisibility, authorData.categoryOrder = {}, {}, {}
	end)
end

local function syncActionOrganizationEditor()
	local action = tostring(settings.authoring.actionTarget or "select")
	local profile = extra.activeHintProfile()
	local hidden = authorData.hiddenActions[action]
	if hidden == nil then hidden = extra.arrayIndex(profile.hiddenActions, action) ~= nil end
	settings.authoring.actionVisible = not hidden
	settings.authoring.actionCategory = authorData.actionCategoryOverrides[action]
		or (type(profile.actionCategoryOverrides) == "table" and profile.actionCategoryOverrides[action]) or ACTION_CATEGORIES[action] or "System"
	settings.authoring.actionOrder = tonumber(authorData.actionOrder[action]) or extra.arrayIndex(profile.actionOrdering, action) or 100
	settings.authoring.actionShortLabel = tostring(authorData.shortLabels[action]
		or (type(profile.defaultShortLabels) == "table" and profile.defaultShortLabels[action]) or "")
	local category = tostring(settings.authoring.categoryTarget or "Selection")
	settings.authoring.categoryVisible = extra.categoryVisible(category, profile)
	settings.authoring.categorySortOrder = tonumber(authorData.categoryOrder[category]) or 100
	for _, item in ipairs(getHintCategories()) do if item.id == category then settings.authoring.categorySortOrder = item.order or 100; break end end
end

authoringPropertyHook = function(scope, key, value)
	if scope ~= "authoring" then return end
	local action = tostring(settings.authoring.actionTarget or "select")
	if key == "actionTarget" then syncActionOrganizationEditor()
	elseif key == "actionVisible" then authorData.hiddenActions[action] = value ~= true
	elseif key == "actionCategory" then authorData.actionCategoryOverrides[action] = tostring(value)
	elseif key == "actionOrder" then authorData.actionOrder[action] = tonumber(value)
	elseif key == "actionShortLabel" then authorData.shortLabels[action] = tostring(value) ~= "" and tostring(value) or nil
	elseif key == "categoryTarget" then syncActionOrganizationEditor()
	elseif key == "categoryVisible" then authorData.categoryVisibility[tostring(settings.authoring.categoryTarget)] = value == true
	elseif key == "categorySortOrder" then authorData.categoryOrder[tostring(settings.authoring.categoryTarget)] = tonumber(value) end
end

themePropertyHook = function(scope, key, value)
	if scope ~= "theme" then return end
	local prefix = COLOR_PREFIXES[settings.theme.colorTarget] or "accent"
	if key == "preset" or key == "colorTarget" then extra.syncThemeColorEditor(false); return end
	if key == "colorHex" then
		local hex = tostring(value or ""):match("^#?([%x][%x][%x][%x][%x][%x])$")
		if hex then
			settings.theme[prefix .. "R"] = tonumber(string.sub(hex, 1, 2), 16) / 255
			settings.theme[prefix .. "G"] = tonumber(string.sub(hex, 3, 4), 16) / 255
			settings.theme[prefix .. "B"] = tonumber(string.sub(hex, 5, 6), 16) / 255
			settings.theme.preset = "Custom"; extra.syncThemeColorEditor(true)
		end
		return
	end
	if key == "colorHue" or key == "colorSaturation" or key == "colorValue" then
		settings.theme[prefix .. "R"], settings.theme[prefix .. "G"], settings.theme[prefix .. "B"] = extra.hsvToRgb(
			settings.theme.colorHue, settings.theme.colorSaturation, settings.theme.colorValue)
		settings.theme.preset = "Custom"; extra.syncThemeColorEditor(true); return
	end
	for _, candidate in pairs(COLOR_PREFIXES) do
		if key == candidate .. "R" or key == candidate .. "G" or key == candidate .. "B" then
			settings.theme.preset = "Custom"; if candidate == prefix then extra.syncThemeColorEditor(true) end; return
		end
	end
end

local function formatInputs(hint)
	local labels = {}
	for i, input in ipairs(hint.inputs) do labels[i] = inputLabel(input) end
	local layout = settings.components.hints.chordLayout
	if layout == "Vertical" then return table.concat(labels, " / ") end
	if layout == "Stacked" then return "[" .. table.concat(labels, "][") .. "]" end
	return table.concat(labels, " + ")
end

local function rowID(row) return row and propertyID(row[1], row[2]) or "" end

local function isRowModified(row)
	local target, defaultsForScope = getScope(row[1])
	return target and defaultsForScope and not deepEqual(target[row[2]], defaultsForScope[row[2]])
end

local function recentContains(id)
	for _, recent in ipairs(authorData.recent) do if recent == id then return true end end
	return false
end

local function currentRows()
	local cacheKey = table.concat({ tostring(editor.tab), tostring(editor.filterMode),
		tostring(editor.search or ""), tostring(revision) }, "|")
	if editor.rowsCacheKey == cacheKey and editor.rowsCache then return editor.rowsCache end
	local result = {}
	local filterMode = editor.filterMode or "Basic"
	local search = string.lower(editor.search or "")
	for _, row in ipairs(definitions[tabs[editor.tab]] or {}) do
		local id, level = rowID(row), row[8] or "Basic"
		local include = filterMode == "All" or (filterMode == "Basic" and level == "Basic")
			or (filterMode == "Advanced" and level == "Advanced")
			or (filterMode == "Favorites" and authorData.favorites[id] == true)
			or (filterMode == "Recent" and recentContains(id))
			or (filterMode == "Modified" and isRowModified(row))
		if search ~= "" then
			local haystack = string.lower(tostring(row[3]) .. " " .. id)
			include = string.find(haystack, search, 1, true) ~= nil
		end
		if include then result[#result + 1] = row end
	end
	editor.rowsCacheKey, editor.rowsCache = cacheKey, result
	return result
end

local function currentRow()
	local rows = currentRows()
	editor.row = math.max(1, math.min(math.max(1, #rows), editor.row))
	return rows[editor.row]
end

local function adjustRow(delta, multiplier)
	local row = currentRow()
	if not row then return end
	local target = getScope(row[1])
	local current = target and target[row[2]]
	if row[4] == "bool" then setValue(row[1], row[2], not current)
	elseif row[4] == "enum" then
		local options, currentIndex = row[9] or {}, 1
		for index, option in ipairs(options) do if option == current then currentIndex = index; break end end
		if #options > 0 then setValue(row[1], row[2], options[((currentIndex - 1 + delta) % #options) + 1]) end
	elseif row[4] ~= "text" then
		setValue(row[1], row[2], clamp((tonumber(current) or 0) + delta * row[7] * (multiplier or 1), row[5], row[6]))
	end
end

local function toggleFavorite(row)
	if not row then return end
	local ownMutation = beginMutation("Favorite " .. rowID(row))
	local id = rowID(row); authorData.favorites[id] = not authorData.favorites[id]
	history.dirty = true; recordRecent(row[1], row[2]); touch(); if ownMutation then endMutation() end
	editor.status = (authorData.favorites[id] and "Pinned " or "Unpinned ") .. id
end

local function saveCurrentValue(row, name)
	if not row then return end
	local ownMutation = beginMutation("Save value " .. rowID(row))
	local target = getScope(row[1]); authorData.savedValues[rowID(row)] = {
		name = name or (row[3] .. " " .. tostring(target[row[2]])), compatibleKey = row[2], value = deepCopy(target[row[2]]),
	}
	history.dirty = true; touch(); if ownMutation then endMutation() end
	editor.status = "Saved value for " .. rowID(row)
end

local function applySavedValue(row)
	if not row then return end
	local saved = authorData.savedValues[rowID(row)]
	if saved == nil then editor.status = "No saved value for " .. rowID(row); return end
	local value = type(saved) == "table" and saved.value ~= nil and saved.value or saved
	setValue(row[1], row[2], deepCopy(value)); editor.status = "Applied saved value for " .. rowID(row)
end

local function saveComponentPreset(component, name)
	local target = settings.components[component]
	if not target then return end
	name = tostring(name or (component .. " preset"))
	local ownMutation = beginMutation("Save preset " .. component)
	authorData.componentPresets[name] = { name = name, component = component,
		settings = deepCopy(target), favorite = true, shipping = false }
	history.dirty = true; touch(); if ownMutation then endMutation() end
	editor.status = "Saved component preset: " .. name
end

local function findComponentPreset(component, name)
	if name and type(authorData.componentPresets[name]) == "table" then return authorData.componentPresets[name], name end
	if type(authorData.componentPresets[component]) == "table" then return authorData.componentPresets[component], component end
	local fallback, fallbackName
	for presetName, preset in pairs(authorData.componentPresets) do
		if type(preset) == "table" and (preset.component == component or preset.component == nil) then
			if not fallback or preset.favorite then fallback, fallbackName = preset, presetName end
		end
	end
	return fallback, fallbackName
end

local function applyComponentPreset(component, name)
	local preset, presetName = findComponentPreset(component, name)
	if not preset or not settings.components[component] then editor.status = "No preset saved for " .. tostring(component); return end
	local ownMutation = beginMutation("Apply preset " .. tostring(presetName))
	local values = type(preset.settings) == "table" and preset.settings or preset
	mergeValidated(settings.components[component], values, DEFAULTS.components[component])
	history.dirty = true; touch(); if ownMutation then endMutation() end
	editor.status = "Applied component preset: " .. tostring(presetName)
end

local function renameComponentPreset(oldName, newName)
	oldName, newName = tostring(oldName or ""), tostring(newName or "")
	if oldName == "" or newName == "" or not authorData.componentPresets[oldName] then return false end
	return mutateAuthorData("Rename preset " .. oldName, function()
		authorData.componentPresets[newName] = authorData.componentPresets[oldName]
		authorData.componentPresets[newName].name = newName; authorData.componentPresets[oldName] = nil
	end)
end

local function duplicateComponentPreset(sourceName, newName)
	if not authorData.componentPresets[sourceName] or tostring(newName or "") == "" then return false end
	return mutateAuthorData("Duplicate preset " .. tostring(sourceName), function()
		authorData.componentPresets[newName] = deepCopy(authorData.componentPresets[sourceName]); authorData.componentPresets[newName].name = newName
	end)
end

local function deleteComponentPreset(name)
	if not authorData.componentPresets[name] then return false end
	return mutateAuthorData("Delete preset " .. tostring(name), function() authorData.componentPresets[name] = nil end)
end

local function setComponentPresetFlag(name, flag, enabled)
	local preset = authorData.componentPresets[name]
	if not preset or (flag ~= "favorite" and flag ~= "shipping") then return false end
	return mutateAuthorData("Update preset " .. tostring(name), function() preset[flag] = enabled == true end)
end

local function claimEditorInput(reclaim)
	if not widgetHandler then return end
	if not reclaim and widgetHandler.textOwner ~= widget then editor.previousTextOwner = widgetHandler.textOwner end
	widgetHandler.textOwner = widget
	if Spring and type(Spring.SDLStartTextInput) == "function" then Spring.SDLStartTextInput() end
end

local function releaseEditorInput()
	if widgetHandler and widgetHandler.textOwner == widget then widgetHandler.textOwner = editor.previousTextOwner end
	if widgetHandler and widgetHandler.mouseOwner == widget then widgetHandler.mouseOwner = nil end
	if not editor.previousTextOwner and Spring and type(Spring.SDLStopTextInput) == "function" then Spring.SDLStopTextInput() end
	editor.previousTextOwner = nil
end

local function setEditorOpen(open)
	editor.open = not not open
	editor.wheelEditId, editor.wheelEditRow = nil, nil
	if editor.open then
		if extra.input then extra.EditorInput.Open(extra.input) end
		if extra.workspace then extra.EditorWorkspace.ResetSession(extra.workspace) end
		editor.previewContext = editor.previewContext or settings.authoring.contextPreview or "Normal Gameplay"
		claimEditorInput()
		if widgetHandler and type(widgetHandler.RaiseWidget) == "function" then widgetHandler:RaiseWidget(widget) end
	else
		if extra.input then extra.EditorInput.Close(extra.input) end
		if extra.workspace then extra.EditorWorkspace.ResetSession(extra.workspace) end
		editor.dragComponent, editor.resizeComponent, editor.dragging, editor.resizing = nil, nil, false, false
		editor.propertyDrag, editor.held, editor.pointerCapture = nil, nil, nil
		editor.activeText, editor.searchActive, editor.textRow, editor.composition = nil, false, nil, ""
		endMutation(); releaseEditorInput()
	end
	local api = support()
	if api and type(api.SetLayoutEditorOpen) == "function" then api.SetLayoutEditorOpen(editor.open) end
end

local function toggleEditor() setEditorOpen(not editor.open) end

local function drawOutline(x1, y1, x2, y2, color)
	glColor(color[1], color[2], color[3], color[4])
	glRect(x1, y1, x2, y1 + 1); glRect(x1, y2 - 1, x2, y2)
	glRect(x1, y1, x1 + 1, y2); glRect(x2 - 1, y1, x2, y2)
end

local function textWidth(text, size)
	if type(gl.GetTextWidth) == "function" then
		local ok, width = pcall(gl.GetTextWidth, tostring(text or ""))
		if ok and type(width) == "number" then return width * size end
	end
	return #tostring(text or "") * size * 0.56
end

local function truncateText(text, size, maxWidth)
	text = tostring(text or "")
	if textWidth(text, size) <= maxWidth then return text end
	local suffix = "..."
	while #text > 1 and textWidth(text .. suffix, size) > maxWidth do text = string.sub(text, 1, #text - 1) end
	return text .. suffix
end

local function wrapText(text, size, maxWidth)
	text = tostring(text or "")
	if textWidth(text, size) <= maxWidth then return text, nil end
	local first, second = "", ""
	for word in text:gmatch("%S+") do
		local candidate = first == "" and word or first .. " " .. word
		if second == "" and textWidth(candidate, size) <= maxWidth then first = candidate
		else second = second == "" and word or second .. " " .. word end
	end
	return truncateText(first, size, maxWidth), truncateText(second, size * 0.82, maxWidth)
end

function extra.wrapTextLines(text, size, maxWidth, maxLines)
	text, maxLines = tostring(text or ""), math.max(2, math.floor(maxLines or 2))
	if textWidth(text, size) <= maxWidth then return { text } end
	local lines, current = {}, ""
	for word in text:gmatch("%S+") do
		local candidate = current == "" and word or current .. " " .. word
		if current ~= "" and textWidth(candidate, size) > maxWidth then
			lines[#lines + 1], current = current, word
			if #lines >= maxLines - 1 then break end
		else current = candidate end
	end
	if current ~= "" and #lines < maxLines then lines[#lines + 1] = current end
	if #lines == 0 then lines[1] = truncateText(text, size, maxWidth)
	else lines[#lines] = truncateText(lines[#lines], size, maxWidth) end
	return lines
end

function extra.marqueeText(text, size, maxWidth, component)
	text = tostring(text or "")
	if textWidth(text, size) <= maxWidth then return text end
	local visible = math.max(4, math.floor(#text * maxWidth / math.max(1, textWidth(text, size))))
	local travel = math.max(1, #text - visible)
	local phase = math.max(0, hintAnimationTime - (component.marqueeDelay or 0)) * (component.marqueeSpeed or 7)
	local offset
	if component.marqueeMode == "Loop" then offset = math.floor(phase % (#text + 3))
	else
		local cycle = travel * 2
		local step = math.floor(phase % math.max(1, cycle))
		offset = step <= travel and step or cycle - step
	end
	if offset >= #text then return string.sub(text .. "   " .. text, offset + 1, offset + visible) end
	return string.sub(text, offset + 1, math.min(#text, offset + visible))
end

function extra.automaticAbbreviation(text)
	text = tostring(text or "")
	for from, to in pairs({ Previous = "Prev", Selection = "Select", Controller = "Ctrl", Command = "Cmd",
		Building = "Build", Modifier = "Mod", Increase = "Inc", Decrease = "Dec", Tactical = "Tact",
		Current = "Cur", Placement = "Place", Factory = "Fac", Remove = "Rm", Settings = "Prefs" }) do
		text = text:gsub(from, to)
	end
	return text
end

function extra.hintPresentation(component)
	local name = component.presentation or "Glyph + Action Text"
	local chip, action, compact, abbreviated = true, true, false, false
	if name == "Glyph + Action Text" then abbreviated = true
	elseif name == "Button Chip Only" then action = false
	elseif name == "Action Text Only" then chip = false
	elseif name == "Background Only" then chip, action = false, false
	elseif name == "Minimal Glyph" then action, compact, abbreviated = false, true, true
	elseif name == "Compact" then compact = true
	elseif name == "Custom" then chip, action, compact = true, true, component.compact == true end
	return chip and component.showChip ~= false, action and component.showActionText ~= false, compact, abbreviated
end

local function drawHints()
	if not settings.global.enabled or not settings.components.hints.enabled or #visibleHints == 0 then return end
	if extra.SharedRenderers then
		local rendered = extra.SharedRenderers.DrawHints({
			model = visibleHints, settings = settings.components.hints, theme = settings.theme,
			viewportWidth = viewX, viewportHeight = viewY, margin = settings.global.safeMargin * automaticScale,
			scale = effectiveScale("hints"), fontScale = effectiveFontScale("hints"),
			opacity = effectiveOpacity("hints") * hintAlpha, glyphs = extra.Glyphs,
			contextLabel = activeHintContextLabel, formatInputs = formatInputs,
			time = hintAnimationTime,
		})
		hintHits, hintMoreHit = rendered.hits or {}, rendered.moreHit
		return
	end
	local component = settings.components.hints
	local scale = effectiveScale("hints")
	local fontScale = effectiveFontScale("hints")
	local fontSize = 14 * fontScale
	local showChip, showActionText, presentationCompact, abbreviatedChip = extra.hintPresentation(component)
	local displayCount = #visibleHints
	if not component.expanded and component.priorityHiding ~= false then displayCount = math.min(displayCount, math.floor(component.maxItems or 14)) end
	local glyphSize = math.max(18, 20 * scale * (component.iconScale or 1))
	local glyphSequences, maxGlyphHeight = {}, 0
	if extra.Glyphs and showChip then
		for index = 1, displayCount do
			glyphSequences[index] = extra.Glyphs.BuildSequence(visibleHints[index].inputs,
				{ hold = visibleHints[index].hold, showTapHold = component.showTapHold })
			local _, height = extra.Glyphs.Dimensions(glyphSequences[index], glyphSize,
				(component.glyphSpacing or 4) * scale, component.chordLayout)
			maxGlyphHeight = math.max(maxGlyphHeight, height)
		end
	end
	local rowHeight = math.max(22 * scale, fontSize + component.rowSpacing * scale, maxGlyphHeight + 6 * scale)
	if component.overflow == "Wrap" then rowHeight = rowHeight + fontSize * 0.72 * (math.max(2, component.wrapLines or 2) - 1) end
	local columns = math.floor(component.columns or 0)
	if columns <= 0 then columns = viewX < 1100 and 1 or 2 end
	columns = math.max(1, math.min(columns, displayCount))
	local rows = math.ceil(displayCount / columns)
	local maxWidth = component.maxWidth * viewX
	local panelWidth = math.min(maxWidth, math.max(300 * scale, columns * 285 * scale))
	local moreHeight = displayCount < #visibleHints and 20 * scale or 0
	local contextHeight = component.showContextHeader and 22 * scale or 0
	local panelHeight = component.padding * 2 * scale + rows * rowHeight + moreHeight + contextHeight
	local margin = settings.global.safeMargin * automaticScale
	local x1 = clamp(component.x * viewX, margin, math.max(margin, viewX - margin - panelWidth))
	local y1 = clamp(component.y * viewY, margin, math.max(margin, viewY - margin - panelHeight))
	local opacity = effectiveOpacity("hints") * hintAlpha
	local theme = settings.theme
	if component.shadowEnabled then glColor(0, 0, 0, 0.42 * opacity); glRect(x1 + 5 * scale, y1 - 5 * scale, x1 + panelWidth + 5 * scale, y1 + panelHeight - 5 * scale) end
	if component.glowEnabled then drawOutline(x1 - 3 * scale, y1 - 3 * scale, x1 + panelWidth + 3 * scale, y1 + panelHeight + 3 * scale,
		{ theme.accentR, theme.accentG, theme.accentB, 0.28 * opacity }) end
	glColor(theme.backgroundR, theme.backgroundG, theme.backgroundB, component.backgroundOpacity * opacity)
	glRect(x1, y1, x1 + panelWidth, y1 + panelHeight)
	for line = 1, math.max(1, math.floor(component.borderThickness or 1)) do
		drawOutline(x1 + line - 1, y1 + line - 1, x1 + panelWidth - line + 1, y1 + panelHeight - line + 1,
			{ theme.accentR, theme.accentG, theme.accentB, component.borderOpacity * opacity })
	end
	if component.showContextHeader then
		glColor(theme.accentR, theme.accentG, theme.accentB, 0.18 * opacity); glRect(x1, y1 + panelHeight - contextHeight, x1 + panelWidth, y1 + panelHeight)
		glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, opacity); glText(activeHintContextLabel, x1 + component.padding * scale,
			y1 + panelHeight - contextHeight + 6 * scale, 11 * fontScale, "o")
	end
	local columnWidth = (panelWidth - component.padding * 2 * scale - (columns - 1) * component.columnSpacing * scale) / columns
	hintHits, hintMoreHit = {}, nil
	local mouseX, mouseY = Spring.GetMouseState()
	local hovered = nil
	for index = 1, displayCount do
		local hint = visibleHints[index]
		local col = math.floor((index - 1) / rows)
		local row = (index - 1) % rows
		local rx = x1 + component.padding * scale + col * (columnWidth + component.columnSpacing * scale)
		local ry = y1 + panelHeight - component.padding * scale - moreHeight - contextHeight - (row + 1) * rowHeight
		local chip = formatInputs(hint)
		if abbreviatedChip then chip = chip:gsub("D%-pad ", "D"):gsub("Left Stick", "LS"):gsub("Right Stick", "RS") end
		local sequence = glyphSequences[index]
		local glyphWidth = sequence and extra.Glyphs.Dimensions(sequence, glyphSize,
			(component.glyphSpacing or 4) * scale, component.chordLayout) or nil
		local chipWidth = showChip and math.min(columnWidth * (showActionText and 0.48 or 1),
			math.max(38 * scale, sequence and glyphWidth + 8 * scale or (#chip * 7 + 14) * scale * component.iconScale)) or 0
		if component.showRowBackground then glColor(theme.mutedR, theme.mutedG, theme.mutedB, 0.13 * opacity); glRect(rx, ry + 1, rx + columnWidth, ry + rowHeight - 1) end
		if showChip then
			glColor(0.08, 0.18, 0.23, 0.94 * opacity); glRect(rx, ry + 2 * scale, rx + chipWidth, ry + rowHeight - 2 * scale)
			drawOutline(rx, ry + 2 * scale, rx + chipWidth, ry + rowHeight - 2 * scale, { theme.accentR, theme.accentG, theme.accentB, 0.9 * opacity })
			if sequence then
				extra.Glyphs.DrawSequence(sequence, rx + 4 * scale, ry + (rowHeight - maxGlyphHeight) * 0.5, {
					size = glyphSize, spacing = (component.glyphSpacing or 4) * scale, layout = component.chordLayout,
					alignment = "left", maxWidth = chipWidth - 8 * scale, colorMode = component.glyphColorMode or "Color-friendly",
					opacity = (component.glyphOpacity or 1) * component.textOpacity * opacity,
					tint = { theme.accentR, theme.accentG, theme.accentB }, backgroundOpacity = 0, borderOpacity = 0,
				})
			else
				glColor(0.76, 0.96, 1, component.textOpacity * opacity)
				glText(chip, rx + chipWidth * 0.5, ry + (rowHeight - fontSize) * 0.5, fontSize * 0.82 * component.iconScale, "oc")
			end
		end
		local label = (component.compact or presentationCompact) and (hint.compactLabel or extra.automaticAbbreviation(hint.label)) or hint.label
		if component.showCategoryHeaders then label = "[" .. tostring(hint.group or "System") .. "] " .. tostring(label) end
		local labelX = rx + chipWidth + (showChip and component.iconTextSpacing * scale or 0)
		local availableWidth = math.max(24, rx + columnWidth - labelX)
		local displayLabel, displaySize, displayLines = label, fontSize, nil
		if component.overflow == "Shrink" then
			while displaySize > fontSize * (component.fontMinScale or 0.62) and textWidth(displayLabel, displaySize) > availableWidth do displaySize = displaySize - 1 end
			displayLabel = truncateText(displayLabel, displaySize, availableWidth)
		elseif component.overflow == "Truncate" then displayLabel = truncateText(displayLabel, displaySize, availableWidth)
		elseif component.overflow == "Marquee" or component.overflow == "Scroll" then
			displayLabel = component.marqueeEnabled and extra.marqueeText(displayLabel, displaySize, availableWidth, component) or truncateText(displayLabel, displaySize, availableWidth)
		else displayLines = extra.wrapTextLines(displayLabel, displaySize, availableWidth, component.wrapLines) end
		if showActionText then
			glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, component.textOpacity * opacity)
			if displayLines then
				local labelY = ry + rowHeight - displaySize * 1.12
				for lineIndex, text in ipairs(displayLines) do glText(text, labelX, labelY - (lineIndex - 1) * displaySize * 0.86, displaySize * (lineIndex == 1 and 1 or 0.86), "o") end
			else glText(displayLabel, labelX, ry + (rowHeight - displaySize) * 0.5, displaySize, "o") end
		end
		if component.showSeparators then glColor(theme.mutedR, theme.mutedG, theme.mutedB, 0.32 * opacity); glRect(rx, ry, rx + columnWidth, ry + 1) end
		local hit = { x1 = rx, y1 = ry, x2 = rx + columnWidth, y2 = ry + rowHeight, hint = hint }
		hintHits[#hintHits + 1] = hit
		if pointInside(hit, mouseX, mouseY) then hovered = hint end
	end
	if displayCount < #visibleHints then
		hintMoreHit = { x1 = x1, y1 = y1, x2 = x1 + panelWidth, y2 = y1 + moreHeight }
		glColor(theme.accentR, theme.accentG, theme.accentB, opacity)
		glText("+" .. tostring(#visibleHints - displayCount) .. " more - click to expand", x1 + panelWidth * 0.5, y1 + 5 * scale, 11 * fontScale, "oc")
	end
	if hovered then
		local tooltip = formatInputs(hovered) .. " - " .. tostring(hovered.label)
		local tooltipW = math.min(viewX - 20, math.max(180, textWidth(tooltip, 13) + 20))
		local tx = clamp(mouseX + 14, 10, viewX - tooltipW - 10); local ty = clamp(mouseY + 14, 10, viewY - 38)
		glColor(theme.backgroundR, theme.backgroundG, theme.backgroundB, 0.96); glRect(tx, ty, tx + tooltipW, ty + 28)
		drawOutline(tx, ty, tx + tooltipW, ty + 28, { theme.accentR, theme.accentG, theme.accentB, 0.9 })
		glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1); glText(truncateText(tooltip, 13, tooltipW - 16), tx + 8, ty + 7, 13, "o")
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
	glColor(editor.open and 0.12 or settings.theme.backgroundR, editor.open and 0.38 or settings.theme.backgroundG,
		editor.open and 0.42 or settings.theme.backgroundB, component.backgroundOpacity * opacity)
	glRect(hit.x1, hit.y1, hit.x2, hit.y2)
	drawOutline(hit.x1, hit.y1, hit.x2, hit.y2, { settings.theme.accentR, settings.theme.accentG, settings.theme.accentB, 0.9 * opacity })
	glColor(settings.theme.foregroundR, settings.theme.foregroundG, settings.theme.foregroundB, opacity)
	local labelSize = 12 * effectiveFontScale("editorLauncher")
	glText("UI Layout", (hit.x1 + hit.x2) * 0.5, hit.y1 + math.max(component.padding * hit.scale, (hit.height - labelSize) * 0.5), labelSize, "oc")
end

local function editorBounds()
	local component = editor.chrome or settings.components.editor
	local margin = math.min(settings.global.safeMargin, math.max(0, math.min(viewX, viewY) * 0.08))
	local availableW, availableH = math.max(100, viewX - margin * 2), math.max(100, viewY - margin * 2)
	local minW, minH = math.min(MIN_EDITOR_W, availableW), math.min(MIN_EDITOR_H, availableH)
	local width = clamp(component.width * viewX, minW, availableW)
	local height = clamp(component.height * viewY, minH, availableH)
	local x1 = clamp(component.x * viewX, margin, math.max(margin, viewX - margin - width))
	local y1 = clamp(component.y * viewY, margin, math.max(margin, viewY - margin - height))
	return { x1 = x1, y1 = y1, x2 = x1 + width, y2 = y1 + height, width = width, height = height }
end

local canvasComponents = {
	{ "hints", "Button Hints", 570, 150 }, { "bindingsButton", "Bindings", 110, 28 },
	{ "editorLauncher", "UI Layout", 116, 28 }, { "buildRadial", "Build Radial", 420, 420 },
	{ "factoryRadial", "Factory Radial", 420, 420 }, { "tacticalRadial", "Tactical Radial", 390, 390 },
	{ "selectionRadial", "Selection Radial", 290, 290 }, { "visibleSelectionRadial", "Visible Selection Filter", 290, 290 },
	{ "hotSlots", "Unit Hot Slots", 500, 84 },
	{ "selectedStatus", "Selected Status", 294, 104 }, { "queueStatus", "Queue Status", 260, 42 },
	{ "placementStatus", "Placement Status", 300, 52 }, { "notifications", "Notifications", 360, 64 },
	{ "pregame", "Pregame", 440, 90 }, { "instructional", "Instructional", 560, 90 },
	{ "companionStatus", "Companion Status", 680, 120 }, { "reticle", "Reticle", 44, 44 },
}

local previewContexts = { "Normal Gameplay", "Nothing Selected", "Single Unit", "Multiple Units", "Builder Selected",
	"Factory Selected", "Transport Selected", "Mouse Mode", "Build Menu", "Build Placement", "Placement Rotation", "Placement Queue",
	"Build Radial - Economy Item", "Build Radial - Combat Item", "Factory Radial - Queued Unit", "Factory Radial - Expensive Unit",
	"Tactical Radial", "Selection Radial", "Visible Selection Filter Radial", "Long Description Stress Test", "Resource Cost Color Test",
	"Global-versus-Override Test", "Unit Hot Slots", "Empty Hot Slots",
	"Populated Hot Slots", "Selected Hot Slot", "Long Binding Stress Test", "Multi-column Hint Stress Test",
	"Maximum Wrapping Stress Test", "Long Chord Stress Test" }

function extra.previewKind()
	local selected = editor.selectedComponent
	if selected == "hints" then return "hints" end
	if selected == "hotSlots" then return "hotSlots" end
	if selected == "buildRadial" or selected == "factoryRadial" or selected == "tacticalRadial" or selected == "selectionRadial"
		or selected == "visibleSelectionRadial" then return "radials" end
	return nil
end

function extra.previewMenuEntries()
	local kind, entries = extra.previewKind(), {}
	local function category(label, values)
		entries[#entries + 1] = { label = label, heading = true, disabled = true }
		for _, value in ipairs(values) do
			entries[#entries + 1] = { label = (editor.previewContext == value and "Selected: " or "") .. value,
				action = "set-preview-context", value = value }
		end
	end
	if kind == "hints" then
		category("Gameplay", { "Normal Gameplay", "Nothing Selected", "Single Unit", "Multiple Units", "Builder Selected",
			"Factory Selected", "Transport Selected", "Mouse Mode" })
		category("Building", { "Build Menu", "Build Placement", "Placement Rotation", "Placement Queue" })
		category("Stress Tests", { "Long Binding Stress Test", "Multi-column Hint Stress Test", "Maximum Wrapping Stress Test", "Long Chord Stress Test" })
	elseif kind == "radials" then
		category("Build and factory", { "Build Radial - Economy Item", "Build Radial - Combat Item", "Factory Radial - Queued Unit", "Factory Radial - Expensive Unit" })
		category("Other radials", { "Tactical Radial", "Selection Radial", "Visible Selection Filter Radial" })
		category("Typography tests", { "Long Description Stress Test", "Resource Cost Color Test", "Global-versus-Override Test" })
	elseif kind == "hotSlots" then
		category("Groups", { "Unit Hot Slots", "Empty Hot Slots", "Populated Hot Slots", "Selected Hot Slot" })
	end
	return entries
end

local function canvasBounds(name, baseWidth, baseHeight)
	if name == "hotSlots" then
		local item = settings.components.hotSlots
		local count, padding = item.slotCount or 10, item.panelPadding or 12
		local rows = item.orientation == "Vertical" and count or item.orientation == "Grid" and math.min(count, item.rows or 2) or 1
		local columns = math.ceil(count / math.max(1, rows))
		local slotWidth, slotHeight = item.slotWidth or item.slotSize or 42, item.slotHeight or item.slotSize or 42
		baseWidth = padding * 2 + columns * slotWidth + math.max(0, columns - 1) * (item.slotGap or 5)
		baseHeight = padding * 2 + rows * slotHeight + math.max(0, rows - 1) * (item.slotGap or 5)
			+ (item.showLabel and 24 or 0) + (item.showStatus and 20 or 0)
	elseif name == "hints" then
		baseWidth = math.min(viewX * (settings.components.hints.maxWidth or 0.52), baseWidth)
	end
	return componentBounds(name, baseWidth, baseHeight)
end

local function componentAnchorFromBounds(name, bounds)
	local item = settings.components[name]
	if not item or not bounds then return end
	local px, py = bounds.x1, bounds.y1
	if item.anchor == "center" then px, py = bounds.x1 + bounds.width * 0.5, bounds.y1 + bounds.height * 0.5
	elseif item.anchor == "bottomcenter" then px = bounds.x1 + bounds.width * 0.5
	elseif item.anchor == "bottomright" then px = bounds.x2 end
	item.x, item.y = clamp(px / viewX, 0, 1), clamp(py / viewY, 0, 1)
end

local function snapPixel(value, targets)
	if not settings.authoring.snapEnabled then return value, nil end
	local threshold = settings.authoring.snapThreshold or 8
	local best, guide, distance = value, nil, threshold + 1
	for _, target in ipairs(targets) do
		local current = math.abs(value - target)
		if current <= threshold and current < distance then best, guide, distance = target, target, current end
	end
	local grid = math.max(1, settings.authoring.snapGrid or 8)
	local gridValue = math.floor(value / grid + 0.5) * grid
	if math.abs(value - gridValue) < distance then best, guide = gridValue, gridValue end
	return best, guide
end

local function moveComponent(name, x1, y1, bounds)
	local margin = settings.global.safeMargin * automaticScale
	x1 = clamp(x1, margin, math.max(margin, viewX - margin - bounds.width))
	y1 = clamp(y1, margin, math.max(margin, viewY - margin - bounds.height))
	local xTargets = { margin, viewX * 0.5 - bounds.width * 0.5, viewX - margin - bounds.width }
	local yTargets = { margin, viewY * 0.5 - bounds.height * 0.5, viewY - margin - bounds.height }
	for _, def in ipairs(canvasComponents) do
		if def[1] ~= name and settings.components[def[1]] and settings.components[def[1]].enabled ~= false then
			local other = canvasBounds(def[1], def[3], def[4])
			if other then
				xTargets[#xTargets + 1] = other.x1; xTargets[#xTargets + 1] = other.x2 - bounds.width
				xTargets[#xTargets + 1] = (other.x1 + other.x2 - bounds.width) * 0.5
				yTargets[#yTargets + 1] = other.y1; yTargets[#yTargets + 1] = other.y2 - bounds.height
				yTargets[#yTargets + 1] = (other.y1 + other.y2 - bounds.height) * 0.5
			end
		end
	end
	local snappedX, guideX = snapPixel(x1, xTargets)
	local snappedY, guideY = snapPixel(y1, yTargets)
	bounds.x1, bounds.y1, bounds.x2, bounds.y2 = snappedX, snappedY, snappedX + bounds.width, snappedY + bounds.height
	componentAnchorFromBounds(name, bounds)
	editor.guides = { x = guideX and guideX + bounds.width * 0.5 or nil, y = guideY and guideY + bounds.height * 0.5 or nil }
	history.dirty = true; touch()
end

local function alignSelected(mode)
	local selected = editor.selectedComponent
	for _, def in ipairs(canvasComponents) do
		if def[1] == selected then
			local bounds = canvasBounds(def[1], def[3], def[4]); if not bounds then return end
			local margin = settings.global.safeMargin * automaticScale
			local x1, y1 = bounds.x1, bounds.y1
			if mode == "left" then x1 = margin elseif mode == "hcenter" then x1 = (viewX - bounds.width) * 0.5 elseif mode == "right" then x1 = viewX - margin - bounds.width
			elseif mode == "bottom" then y1 = margin elseif mode == "vcenter" then y1 = (viewY - bounds.height) * 0.5 elseif mode == "top" then y1 = viewY - margin - bounds.height end
			local ownMutation = beginMutation("Align " .. selected .. " " .. mode); moveComponent(selected, x1, y1, bounds); if ownMutation then endMutation() end
			editor.status = "Aligned " .. selected .. " " .. mode; return
		end
	end
end

local function distributeComponents(axis)
	local entries = {}
	for _, def in ipairs(canvasComponents) do
		local item = settings.components[def[1]]
		if item and item.enabled ~= false and item.x and item.y then
			local bounds = canvasBounds(def[1], def[3], def[4]); if bounds then entries[#entries + 1] = { def = def, bounds = bounds } end
		end
	end
	if #entries < 3 then editor.status = "Distribution needs at least three visible components"; return end
	table.sort(entries, function(a, b)
		if axis == "horizontal" then return a.bounds.x1 < b.bounds.x1 end
		return a.bounds.y1 < b.bounds.y1
	end)
	local first, last = entries[1].bounds, entries[#entries].bounds
	local start = axis == "horizontal" and first.x1 or first.y1
	local finish = axis == "horizontal" and last.x1 or last.y1
	local ownMutation = beginMutation("Distribute components " .. axis)
	for index, entry in ipairs(entries) do
		local position = start + (finish - start) * (index - 1) / (#entries - 1)
		local x, y = entry.bounds.x1, entry.bounds.y1
		if axis == "horizontal" then x = position else y = position end
		moveComponent(entry.def[1], x, y, entry.bounds)
	end
	if ownMutation then endMutation() end
	editor.status = "Distributed visible components " .. axis
end

local function previewContext(base, mode)
	mode = mode or editor.previewContext or "Normal Gameplay"
	if mode == "Live" then return base end
	local result = { selectedCount = 0, hasSelection = false }
	if mode == "Normal Gameplay" then result.hasSelection, result.selectedCount, result.hasBuilder = true, 1, true
	elseif mode == "Nothing Selected" then result.selectedCount = 0
	elseif mode == "Single Unit" then result.hasSelection, result.selectedCount = true, 1
	elseif mode == "Multiple Units" then result.hasSelection, result.selectedCount = true, 12
	elseif mode == "Builder Selected" then result.hasSelection, result.selectedCount, result.hasBuilder = true, 1, true
	elseif mode == "Factory Selected" then result.hasSelection, result.selectedCount, result.hasFactory = true, 1, true
	elseif mode == "Transport Selected" then result.hasSelection, result.selectedCount, result.hasTransport = true, 1, true
	elseif mode == "Build Menu" then result.buildMenuOpen, result.hasBuilder, result.hasSelection = true, true, true
	elseif mode == "Factory Radial" then result.buildMenuOpen, result.factoryRadialOpen, result.hasFactory, result.hasSelection = true, true, true, true
	elseif mode == "Build Placement" then result.buildPlacement, result.hasBuilder, result.hasSelection = true, true, true
	elseif mode == "Tactical Radial" then result.tacticalRadialOpen, result.hasSelection = true, true
	elseif mode == "Selection Radial" then result.selectionRadialOpen, result.areaSelection = true, true
	elseif mode == "Visible Selection Filter Radial" then result.visibleSelectionRadialOpen, result.visibleSelectionFilter = true, "Combat"
	elseif mode == "Unit Hot Slots" then result.controlGroupLayer, result.hasSelection = true, true
	elseif mode == "Pregame" then result.pregame = true
	elseif mode == "Mouse Mode" then result.mouseMode = true
	elseif mode == "Bindings UI" then result.bindingsOpen = true
	elseif mode == "Layout Editor" then result.layoutEditorOpen = true
	elseif mode == "Long Binding Stress Test" then result.longBindingStress = true end
	if mode ~= "Layout Editor" then result.layoutEditorOpen = false end
	return result
end

local function cyclePreviewContext()
	local current = editor.previewContext or "Normal Gameplay"; local index = 1
	for i, name in ipairs(previewContexts) do if name == current then index = i; break end end
	editor.previewContext = previewContexts[(index % #previewContexts) + 1]
	editor.status = "Preview: " .. editor.previewContext
end

local function drawCanvasAuthoring()
	if not editor.open then editor.componentHits = {}; return end
	local theme, margin = settings.theme, settings.global.safeMargin * automaticScale
	if settings.authoring.showSafeArea then drawOutline(margin, margin, viewX - margin, viewY - margin, { theme.mutedR, theme.mutedG, theme.mutedB, 0.65 }) end
	editor.componentHits = {}
	if settings.authoring.showOutlines then
		for _, def in ipairs(canvasComponents) do
			local item = settings.components[def[1]]
			if item and item.enabled ~= false and def[1] == editor.selectedComponent then
				local bounds = canvasBounds(def[1], def[3], def[4])
				drawOutline(bounds.x1, bounds.y1, bounds.x2, bounds.y2, { theme.accentR, theme.accentG, theme.accentB, 0.98 })
				glColor(theme.backgroundR, theme.backgroundG, theme.backgroundB, 0.72); glRect(bounds.x1, bounds.y2 - 18, bounds.x1 + math.min(bounds.width, 150), bounds.y2)
				glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 0.9); glText(def[2], bounds.x1 + 5, bounds.y2 - 14, 10, "o")
				if item.width and item.height then
					bounds.resize = { x1 = bounds.x2 - 9, y1 = bounds.y2 - 9, x2 = bounds.x2 + 2, y2 = bounds.y2 + 2 }
					glColor(theme.accentR, theme.accentG, theme.accentB, 0.95); glRect(bounds.resize.x1, bounds.resize.y1, bounds.resize.x2, bounds.resize.y2)
				end
				bounds.component, bounds.label = def[1], def[2]; editor.componentHits[#editor.componentHits + 1] = bounds
			end
		end
	end
	if editor.guides.x then glColor(theme.accentR, theme.accentG, theme.accentB, 0.45); glRect(editor.guides.x, margin, editor.guides.x + 1, viewY - margin) end
	if editor.guides.y then glColor(theme.accentR, theme.accentG, theme.accentB, 0.45); glRect(margin, editor.guides.y, viewX - margin, editor.guides.y + 1) end
end

local function drawEditorLegacy()
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

function extra.drawEditorTable()
	if not editor.open then editor.bounds = nil; return end
	local b = editorBounds(); editor.bounds = b
	local opacity, theme = effectiveOpacity("editor"), settings.theme
	glColor(theme.backgroundR, theme.backgroundG, theme.backgroundB, 0.97 * opacity); glRect(b.x1, b.y1, b.x2, b.y2)
	drawOutline(b.x1, b.y1, b.x2, b.y2, { theme.accentR, theme.accentG, theme.accentB, opacity })
	local headerH = 42
	glColor(theme.accentR * 0.18, theme.accentG * 0.28, theme.accentB * 0.30, 0.98 * opacity); glRect(b.x1, b.y2 - headerH, b.x2, b.y2)
	glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, opacity)
	glText("Controller UI Authoring" .. (history.dirty and " *" or ""), b.x1 + 16, b.y2 - 27, 19, "o")
	glText(editor.status or "Ready", b.x1 + 250, b.y2 - 25, 11, "o")
	editor.close = { x1 = b.x2 - 38, y1 = b.y2 - 34, x2 = b.x2 - 10, y2 = b.y2 - 8 }
	glColor(theme.dangerR, theme.dangerG, theme.dangerB, 0.72); glRect(editor.close.x1, editor.close.y1, editor.close.x2, editor.close.y2)
	glColor(1, 0.82, 0.8, 1); glText("X", (editor.close.x1 + editor.close.x2) * 0.5, editor.close.y1 + 6, 16, "oc")

	editor.tabs = {}
	local tabY2, tabY1 = b.y2 - headerH - 8, b.y2 - headerH - 42
	local tabW = (b.width - 20) / #tabs
	for index, name in ipairs(tabs) do
		local x1 = b.x1 + 10 + (index - 1) * tabW
		local hit = { x1 = x1, y1 = tabY1, x2 = x1 + tabW - 3, y2 = tabY2, index = index }
		editor.tabs[index] = hit
		glColor(index == editor.tab and 0.12 or 0.045, index == editor.tab and 0.30 or 0.08, index == editor.tab and 0.34 or 0.10, 0.96)
		glRect(hit.x1, hit.y1, hit.x2, hit.y2); glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1)
		glText(name, (hit.x1 + hit.x2) * 0.5, hit.y1 + 8, 10, "oc")
	end

	local filterY2, filterY1 = tabY1 - 8, tabY1 - 34
	editor.filterHits = {}
	local filterW = math.min(66, (b.width - 260) / #filterModes)
	for index, mode in ipairs(filterModes) do
		local x1 = b.x1 + 12 + (index - 1) * (filterW + 3)
		local hit = { x1 = x1, y1 = filterY1, x2 = x1 + filterW, y2 = filterY2, mode = mode }
		editor.filterHits[#editor.filterHits + 1] = hit
		glColor(editor.filterMode == mode and 0.12 or 0.04, editor.filterMode == mode and 0.30 or 0.08, editor.filterMode == mode and 0.34 or 0.10, 0.96)
		glRect(hit.x1, hit.y1, hit.x2, hit.y2); glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1)
		glText(mode, (hit.x1 + hit.x2) * 0.5, hit.y1 + 7, 9, "oc")
	end
	editor.searchHit = { x1 = b.x2 - 240, y1 = filterY1, x2 = b.x2 - 12, y2 = filterY2 }
	glColor(0.03, 0.06, 0.08, 0.98); glRect(editor.searchHit.x1, editor.searchHit.y1, editor.searchHit.x2, editor.searchHit.y2)
	drawOutline(editor.searchHit.x1, editor.searchHit.y1, editor.searchHit.x2, editor.searchHit.y2,
		editor.searchActive and { theme.accentR, theme.accentG, theme.accentB, 1 } or { theme.mutedR, theme.mutedG, theme.mutedB, 0.7 })
	glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1)
	glText(editor.search ~= "" and editor.search or "Search properties (Ctrl+F)", editor.searchHit.x1 + 7, editor.searchHit.y1 + 7, 10, "o")

	local toolY2, toolY1 = filterY1 - 7, filterY1 - 33
	local function toolButton(x1, width, label)
		local hit = { x1 = x1, y1 = toolY1, x2 = x1 + width, y2 = toolY2 }
		glColor(0.06, 0.13, 0.16, 0.96); glRect(hit.x1, hit.y1, hit.x2, hit.y2)
		glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1); glText(label, (hit.x1 + hit.x2) * 0.5, hit.y1 + 7, 9, "oc")
		return hit
	end
	local tx = b.x1 + 12
	editor.undo = toolButton(tx, 48, "Undo"); tx = tx + 52
	editor.redo = toolButton(tx, 48, "Redo"); tx = tx + 52
	editor.save = toolButton(tx, 48, "Save"); tx = tx + 52
	editor.context = toolButton(tx, 142, "Preview: " .. tostring(settings.authoring.contextPreview)); tx = tx + 146
	editor.reload = toolButton(tx, 86, "Reload"); tx = tx + 90
	editor.draft = settings.authoring.developerAuthoring and toolButton(tx, 58, "Draft") or nil; tx = tx + (editor.draft and 62 or 0)
	editor.publish = settings.authoring.developerAuthoring and toolButton(tx, 74, "Publish Req") or nil

	editor.hits = {}
	local rows, rowY, rowH = currentRows(), toolY1 - 8, 34
	if #rows == 0 then
		glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1)
		local emptyText = tabs[editor.tab] == "Recovery"
			and (editor.recoveryAvailable and "Unsaved recovery data was restored. Save or reset when ready." or "No recovery is pending.")
			or "No properties match this filter/search."
		glText(emptyText, b.x1 + 22, rowY - 36, 14, "o")
	end
	local maxVisible = math.max(1, math.floor((rowY - (b.y1 + 92)) / (rowH + 3)))
	if editor.row <= editor.scroll then editor.scroll = math.max(0, editor.row - 1) end
	if editor.row > editor.scroll + maxVisible then editor.scroll = editor.row - maxVisible end
	editor.scroll = math.max(0, math.min(math.max(0, #rows - maxVisible), editor.scroll))
	for visibleIndex = 1, maxVisible do
		local index = editor.scroll + visibleIndex
		local row = rows[index]
		if not row then break end
		local y2, y1 = rowY - (visibleIndex - 1) * (rowH + 3), rowY - (visibleIndex - 1) * (rowH + 3) - rowH
		local selected = index == editor.row
		glColor(selected and 0.10 or 0.035, selected and 0.24 or 0.06, selected and 0.28 or 0.08, 0.94); glRect(b.x1 + 16, y1, b.x2 - 16, y2)
		if selected then drawOutline(b.x1 + 16, y1, b.x2 - 16, y2, { theme.accentR, theme.accentG, theme.accentB, 0.9 }) end
		local scope = getScope(row[1]); local value = scope and scope[row[2]]; local valueText
		if row[4] == "bool" then valueText = value and "ON" or "OFF"
		elseif row[4] == "number" then valueText = string.format(row[7] >= 1 and "%.0f" or "%.3f", value or 0)
		else valueText = tostring(value or "") end
		local id, source = rowID(row), layerSources[rowID(row)] or "preview"
		local star = { x1 = b.x1 + 18, y1 = y1 + 5, x2 = b.x1 + 42, y2 = y2 - 5 }
		glColor(theme.accentR, theme.accentG, theme.accentB, authorData.favorites[id] and 1 or 0.35); glText(authorData.favorites[id] and "*" or "+", (star.x1 + star.x2) * 0.5, star.y1 + 5, 15, "oc")
		glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1); glText(row[3], b.x1 + 48, y1 + 13, 12, "o")
		glColor(theme.mutedR, theme.mutedG, theme.mutedB, 0.9); glText(source .. (isEnforced(row[1], row[2]) and " (locked)" or ""), b.x1 + 48, y1 + 3, 8, "o")
		local minus = { x1 = b.x2 - 154, y1 = y1 + 4, x2 = b.x2 - 120, y2 = y2 - 4 }
		local plus = { x1 = b.x2 - 50, y1 = y1 + 4, x2 = b.x2 - 16, y2 = y2 - 4 }
		local saveValueHit = { x1 = b.x2 - 196, y1 = y1 + 4, x2 = b.x2 - 174, y2 = y2 - 4 }
		local applyValueHit = { x1 = b.x2 - 172, y1 = y1 + 4, x2 = b.x2 - 156, y2 = y2 - 4 }
		local enforceHit = settings.authoring.developerAuthoring and { x1 = b.x2 - 224, y1 = y1 + 4, x2 = b.x2 - 200, y2 = y2 - 4 } or nil
		glColor(0.08, 0.16, 0.19, 0.96)
		for _, hit in ipairs({ minus, plus, saveValueHit, applyValueHit }) do glRect(hit.x1, hit.y1, hit.x2, hit.y2) end
		local draftEnforced = authorData.shippingEnforcedPaths[id] == true
		if enforceHit then glColor(draftEnforced and theme.dangerR or 0.08, draftEnforced and theme.dangerG or 0.16,
			draftEnforced and theme.dangerB or 0.19, 0.96); glRect(enforceHit.x1, enforceHit.y1, enforceHit.x2, enforceHit.y2) end
		glColor(theme.accentR, theme.accentG, theme.accentB, 1); glText(row[4] == "bool" and "" or "-", (minus.x1 + minus.x2) * 0.5, minus.y1 + 6, 16, "oc")
		glText(truncateText(valueText, 12, 72), b.x2 - 85, y1 + 9, 12, "oc")
		glText(row[4] == "bool" and "Toggle" or "+", (plus.x1 + plus.x2) * 0.5, plus.y1 + 6, row[4] == "bool" and 9 or 16, "oc")
		glText("S", (saveValueHit.x1 + saveValueHit.x2) * 0.5, saveValueHit.y1 + 7, 9, "oc"); glText("V", (applyValueHit.x1 + applyValueHit.x2) * 0.5, applyValueHit.y1 + 7, 9, "oc")
		if enforceHit then glText("E", (enforceHit.x1 + enforceHit.x2) * 0.5, enforceHit.y1 + 7, 9, "oc") end
		editor.hits[#editor.hits + 1] = { x1 = b.x1 + 16, y1 = y1, x2 = b.x2 - 16, y2 = y2, index = index,
			minus = minus, plus = plus, star = star, saveValue = saveValueHit, applyValue = applyValueHit, enforce = enforceHit, row = row }
	end

	editor.resetSection = { x1 = b.x1 + 18, y1 = b.y1 + 16, x2 = b.x1 + 168, y2 = b.y1 + 46 }
	editor.resetAll = { x1 = b.x1 + 178, y1 = b.y1 + 16, x2 = b.x1 + 292, y2 = b.y1 + 46 }
	editor.savePreset = { x1 = b.x1 + 302, y1 = b.y1 + 16, x2 = b.x1 + 426, y2 = b.y1 + 46 }
	editor.applyPreset = { x1 = b.x1 + 436, y1 = b.y1 + 16, x2 = b.x1 + 570, y2 = b.y1 + 46 }
	for _, hit in ipairs({ editor.resetSection, editor.resetAll, editor.savePreset, editor.applyPreset }) do glColor(0.12, 0.18, 0.21, 0.98); glRect(hit.x1, hit.y1, hit.x2, hit.y2) end
	glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1)
	glText("Reset Section", b.x1 + 93, b.y1 + 24, 11, "oc"); glText("Reset All", b.x1 + 235, b.y1 + 24, 11, "oc")
	glText("Save Component", b.x1 + 364, b.y1 + 24, 10, "oc"); glText("Apply Component", b.x1 + 503, b.y1 + 24, 10, "oc")
	editor.alignHits = {}
	for index, item in ipairs({ { "left", "L" }, { "hcenter", "HC" }, { "right", "R" }, { "bottom", "B" }, { "vcenter", "VC" }, { "top", "T" },
		{ "distribute-horizontal", "DH" }, { "distribute-vertical", "DV" } }) do
		local hit = { x1 = b.x1 + 18 + (index - 1) * 42, y1 = b.y1 + 52, x2 = b.x1 + 55 + (index - 1) * 42, y2 = b.y1 + 76, mode = item[1] }
		editor.alignHits[#editor.alignHits + 1] = hit; glColor(0.06, 0.13, 0.16, 0.96); glRect(hit.x1, hit.y1, hit.x2, hit.y2)
		glColor(theme.foregroundR, theme.foregroundG, theme.foregroundB, 1); glText(item[2], (hit.x1 + hit.x2) * 0.5, hit.y1 + 6, 9, "oc")
	end
	editor.resize = { x1 = b.x2 - 22, y1 = b.y1, x2 = b.x2, y2 = b.y1 + 22 }
	glColor(theme.accentR, theme.accentG, theme.accentB, 0.8); glRect(b.x2 - 16, b.y1 + 4, b.x2 - 4, b.y1 + 7); glRect(b.x2 - 10, b.y1 + 10, b.x2 - 4, b.y1 + 13)
end

extra.editorNavigation = {
	{ id = "general", label = "General", icon = "G", group = "Interface", tab = "General" },
	{ id = "hints", label = "Button Hints", icon = "H", group = "Interface", tab = "Hints", component = "hints" },
	{ id = "actions", label = "Actions", icon = "A", group = "Interface", tab = "Actions" },
	{ id = "hotSlots", label = "Hot Slots", icon = "#", group = "Interface", tab = "Hot Slots", component = "hotSlots" },
	{ id = "launchers", label = "Launchers", icon = "L", group = "Interface", tab = "Launchers", component = "editorLauncher" },
	{ id = "radials", label = "Radials", icon = "R", group = "Interface", tab = "Radials", component = "buildRadial" },
	{ id = "status", label = "Status", icon = "S", group = "Interface", tab = "Status", component = "selectedStatus" },
	{ id = "pregame", label = "Pregame", icon = "P", group = "Interface", tab = "Other", component = "pregame" },
	{ id = "reticle", label = "Reticle", icon = "+", group = "Interface", tab = "Other", component = "reticle" },
	{ id = "mouseMode", label = "Mouse Mode", icon = "M", group = "Interface", tab = "Other" },
	{ id = "theme", label = "Themes", icon = "T", group = "Design", tab = "Theme" },
	{ id = "favorites", label = "Favorites", icon = "*", group = "Design", filter = "Favorites" },
	{ id = "authoring", label = "Authoring", icon = "Au", group = "System", tab = "Authoring" },
	{ id = "recovery", label = "Recovery", icon = "!", group = "System", tab = "Recovery" },
	{ id = "advanced", label = "Advanced", icon = "Ad", group = "System", filter = "Advanced" },
}

extra.editorScopeLabels = {
	global = "Global interface", hints = "Controller hints", hotSlots = "Hot slots", theme = "Theme",
	gameplay = "Controller input",
	authoring = "Authoring", bindingsButton = "Bindings launcher", editorLauncher = "Layout launcher",
	radials = "All radials", buildRadial = "Build radial", tacticalRadial = "Tactical radial",
	selectionRadial = "Selection radial", visibleSelectionRadial = "Visible selection filter radial",
	factoryRadial = "Factory radial", selectedStatus = "Selected status",
	queueStatus = "Queue status", placementStatus = "Placement status", notifications = "Notifications",
	pregame = "Pregame", instructional = "Instructional", companionStatus = "Companion status", reticle = "Reticle",
}

function extra.selectedNavigationID()
	if editor.navigationSelection then return editor.navigationSelection end
	local tabName = tabs[editor.tab]
	for _, item in ipairs(extra.editorNavigation) do
		if item.component and item.component == editor.selectedComponent and item.tab == tabName then return item.id end
	end
	for _, item in ipairs(extra.editorNavigation) do if item.tab == tabName and not item.component then return item.id end end
	return string.lower(tostring(tabName or "general"))
end

function extra.selectedPreviewDefinition()
	for _, def in ipairs(canvasComponents) do if def[1] == editor.selectedComponent then return def end end
	return { editor.selectedComponent or "hints", tabs[editor.tab] or "Component", 420, 180 }
end

function extra.workspaceGetValue(row)
	local scope = getScope(row[1]); if not scope then return nil end
	if isRadialComponentScope(row[1]) and isRadialStyleKey(row[2]) and scope.typographyOverride ~= true then
		return settings.components.radials[row[2]]
	end
	return scope[row[2]]
end

function extra.workspaceGetSource(row)
	local scope = getScope(row[1])
	if isRadialComponentScope(row[1]) and isRadialStyleKey(row[2]) and scope and scope.typographyOverride ~= true then
		return "inherited from All Radials"
	end
	return layerSources[rowID(row)] or "preview"
end

function extra.workspaceIsEnforced(row)
	return isEnforced(row[1], row[2])
end

function extra.drawWorkspacePreview(shape, colors)
	if not extra.SharedRenderers then return end
	local kind, context = extra.previewKind(), editor.previewContext or "Normal Gameplay"
	if kind == "hints" then
		local model = context == "Visible Selection Filter Radial" and {
			{ inputs = { "leftStick" }, label = "Choose Filter", compactLabel = "Choose", group = "Selection" },
			{ inputs = { "LT" }, label = "Release to Confirm", compactLabel = "Confirm", group = "Selection" },
			{ inputs = { "B" }, label = "Cancel", compactLabel = "Cancel", group = "Selection" },
		} or {
			{ inputs = { "A" }, label = "Select", compactLabel = "Select", group = "Selection" },
			{ inputs = { "B" }, label = "Cancel", compactLabel = "Cancel", group = "System" },
			{ inputs = { "LB", "RB" }, label = "Change category", compactLabel = "Category", group = "Navigation" },
			{ inputs = { "leftStick" }, label = "Move cursor", compactLabel = "Move", group = "Navigation" },
		}
		if string.find(context, "Stress Test", 1, true) then
			model[#model + 1] = { inputs = { "back", "start", "LB", "RB", "LT", "RT" }, hold = true,
				label = "Long binding stress test action with maximum wrapping", compactLabel = "Stress", group = "Stress Tests" }
			model[#model + 1] = { inputs = { "dpadUp", "dpadRight", "A" }, label = "Queue and rotate placement", group = "Building" }
		end
		extra.SharedRenderers.DrawHints({ model = model, settings = settings.components.hints, theme = settings.theme,
			bounds = shape, viewportWidth = shape.x2 - shape.x1, viewportHeight = shape.y2 - shape.y1,
			scale = 1, fontScale = 1, opacity = effectiveOpacity("hints"), glyphs = extra.Glyphs,
			contextLabel = context, formatInputs = formatInputs, time = hintAnimationTime })
	elseif kind == "radials" then
		local entries = {}
		local style = string.find(context, "Tactical", 1, true) and "tactical"
			or string.find(context, "Selection", 1, true) and "selection" or "build"
		local labels = style == "selection" and (context == "Visible Selection Filter Radial"
			and { "Last Selected", "Air", "Combat", "Builders" } or { "All Mobile", "Air", "Combat", "Builders" })
			or { "Economy", "Energy", "Defense", "Factory", "Assist", "Repair", "Reclaim", "Orders" }
		for index, label in ipairs(labels) do entries[index] = { label = label, disabled = index == 6,
			unavailableText = index == 6 and "Unavailable" or nil, badge = index == 4 and 3 or nil, indexLabel = tostring(index % 10) } end
		local componentName = context == "Visible Selection Filter Radial" and "visibleSelectionRadial"
			or string.find(context, "Factory", 1, true) and "factoryRadial" or string.find(context, "Tactical", 1, true) and "tacticalRadial"
			or string.find(context, "Selection", 1, true) and "selectionRadial" or editor.selectedComponent
		if componentName == "radials" or not settings.components[componentName] then componentName = "buildRadial" end
		local component = settings.components[componentName] or {}
		local description = context == "Long Description Stress Test"
			and "Long-range support unit with a deliberately extensive production description that demonstrates wrapping and maximum-line limits."
			or style == "selection" and "Choose which visible units become the active selection." or "Produces energy and supports nearby construction."
		extra.SharedRenderers.DrawRadial({ bounds = shape, theme = settings.theme,
			model = { style = style, title = string.find(context, "Combat", 1, true) and "Armada Stout" or string.find(context, "Factory", 1, true) and "Queued Constructor" or "Advanced Solar Collector",
				selectedTitle = string.find(context, "Factory", 1, true) ~= nil,
				categoryLabel = string.find(context, "Combat", 1, true) and "COMBAT" or style == "tactical" and "TACTICAL" or style == "selection" and "SELECTION" or "ECONOMY",
				description = description, metalCost = context == "Resource Cost Color Test" and "12,345" or "370",
				energyCost = context == "Resource Cost Color Test" and "67,890" or "4,200", metadata = { "Build time 28.4s", "Health 1,850", "DPS 142" },
				footer = "LS choose  A confirm  B close", pageLabel = "PAGE 1/2", entries = entries, selectedIndex = 3 },
			settings = { iconScale = (component.iconScale or 1) * (settings.components.radials.iconScale or 1),
				fontScale = effectiveFontScale(componentName), centerTextScale = settings.components.radials.centerTextScale,
				selectedScale = settings.components.radials.selectedScale,
				selectedBorderThickness = settings.components.radials.selectedBorderThickness,
				itemSpacing = settings.components.radials.itemSpacing, legacyThemeOpacity = settings.components.radials.legacyThemeOpacity,
				pageStatusVisible = settings.components.radials.pageStatusVisible, typography = extra.getResolvedRadialStyle(componentName) },
			opacity = effectiveOpacity(componentName) })
	elseif kind == "hotSlots" then
		local slots = {}
		for index = 1, 10 do slots[index] = { label = tostring(index % 10), count = context == "Empty Hot Slots" and 0 or index * 3,
			empty = context == "Empty Hot Slots" or index % 4 == 0, selected = context == "Selected Hot Slot" and index == 3,
			role = index % 2 == 0 and "builder" or "combat" } end
		extra.SharedRenderers.DrawHotSlots({ bounds = shape, settings = settings.components.hotSlots, theme = settings.theme,
			model = { slots = slots, selectedIndex = context == "Selected Hot Slot" and 3 or 1, status = "Synthetic data / production renderer" },
			opacity = effectiveOpacity("hotSlots"), scale = effectiveScale("hotSlots"), fontScale = effectiveFontScale("hotSlots") })
	end
end

function extra.drawEditor()
	if not editor.open then editor.bounds = nil; return end
	if not extra.workspace then extra.drawEditorTable(); return end
	local bounds, rows = editorBounds(), currentRows()
	editor.bounds = bounds
	editor.row = math.max(1, math.min(math.max(1, #rows), editor.row))
	local preview = extra.selectedPreviewDefinition()
	extra.EditorWorkspace.Draw(extra.workspace, {
		bounds = bounds, theme = settings.theme, title = "Controller UI Authoring", status = editor.status,
		dirty = history.dirty, canUndo = #history.undo > 0, canRedo = #history.redo > 0,
		components = extra.editorNavigation, selectedNav = extra.selectedNavigationID(), selectedComponent = editor.selectedComponent,
		tabName = tabs[editor.tab], rows = rows, selectedRow = editor.row, filterMode = editor.filterMode,
		inspectorKey = tostring(editor.selectedComponent or tabs[editor.tab]) .. "|" .. tostring(tabs[editor.tab]) .. "|" .. tostring(editor.filterMode),
		search = editor.search or "", searchActive = editor.searchActive, developer = settings.authoring.developerAuthoring,
		previewContext = editor.previewContext, previewLabel = preview[2], previewWidth = preview[3], previewHeight = preview[4],
		previewAvailable = extra.previewKind() ~= nil,
		previewDetail = "Drag the selection bounds in the live game view; resize handles appear where supported.",
		scopeLabels = extra.editorScopeLabels,
		getValue = extra.workspaceGetValue, getSource = extra.workspaceGetSource,
		getColor = extra.getColorState, hsvToRgb = extra.hsvToRgb,
		colorPresets = extra.getColorEditorPresets(), colorWheelEditingId = editor.colorWheelEditId,
		editingColorId = editor.activeText == "colorValue" and editor.colorText and rowID(editor.colorText.row) .. ":" .. editor.colorText.channel or nil,
		editingId = editor.activeText == "propertyValue" and editor.textRow and rowID(editor.textRow) or nil,
		wheelEditingId = editor.wheelEditId,
		editingText = editor.textBuffer, composition = editor.composition,
		isModified = isRowModified, isEnforced = extra.workspaceIsEnforced,
		drawPreview = extra.previewKind() and extra.drawWorkspacePreview or nil,
		controllerDebugVisible = support() and type(support().IsDebugPanelVisible) == "function"
			and support().IsDebugPanelVisible() or false,
		debugInfo = "focus=" .. tostring(extra.workspace.focusId or "none") .. "  input=modal  upvalues<60",
		emptyText = tabs[editor.tab] == "Recovery"
			and (editor.recoveryAvailable and "Recovery data is active. Save or reset when ready." or "No recovery is pending.")
			or "No properties match this filter or search.",
	})
	if extra.workspace.pendingFocus == "first-property" then
		for _, item in ipairs(extra.workspace.focusItems) do
			if item.pane == "inspector" and item.row then extra.EditorWorkspace.SetFocus(extra.workspace, item.id); break end
		end
		extra.workspace.pendingFocus = nil
	end
end

local function getComponentCenter(name, fallbackX, fallbackY)
	local item = settings.components[name]
	if not item then return fallbackX or viewX * 0.5, fallbackY or viewY * 0.5 end
	local margin = settings.global.safeMargin * automaticScale
	return clamp((item.x or 0.5) * viewX, margin, viewX - margin), clamp((item.y or 0.5) * viewY, margin, viewY - margin)
end

local function getThemeColor(role, alpha, componentName)
	local theme = settings.theme
	local component = componentName and settings.components[componentName] or nil
	local override = component and component.themeOverride
	local overrideColors = {
		["BAR Default"] = { background = { 0.020, 0.030, 0.045 }, foreground = { 0.94, 0.98, 1.00 }, accent = { 0.30, 0.66, 1.00 } },
		Minimal = { background = { 0.010, 0.014, 0.020 }, foreground = { 0.92, 0.96, 0.98 }, accent = { 0.48, 0.76, 0.86 } },
		Compact = { background = { 0.018, 0.028, 0.040 }, foreground = { 0.94, 0.98, 1.00 }, accent = { 0.34, 0.82, 0.92 } },
		["Large Accessibility"] = { background = { 0, 0, 0 }, foreground = { 1, 1, 1 }, accent = { 1, 0.82, 0.12 } },
		Transparent = { background = { 0.010, 0.018, 0.026 }, foreground = { 0.96, 0.98, 1.00 }, accent = { 0.36, 0.82, 0.94 } },
		["High Contrast"] = { background = { 0, 0, 0 }, foreground = { 1, 1, 1 }, accent = { 1, 0.82, 0.12 } },
	}
	local colors = override and override ~= "Global" and overrideColors[override] or nil
	if colors and colors[role] then return { colors[role][1], colors[role][2], colors[role][3], alpha == nil and 1 or alpha } end
	local prefix = role == "background" and "background" or role == "accent" and "accent"
		or role == "muted" and "muted" or role == "danger" and "danger" or "foreground"
	return { theme[prefix .. "R"], theme[prefix .. "G"], theme[prefix .. "B"], alpha == nil and 1 or alpha }
end

local function reloadDefaults(keepPreview)
	local preview = keepPreview and history.dirty and deepCopy(settings) or nil
	loadShippingDocuments(); resolveSettings(preview)
	history.dirty = preview ~= nil; lastContextSignature = ""
	editor.status = "Reloaded " .. shipping.status
	return true
end

function extra.writeJSONDocument(path, document)
	if not Json or type(Json.encode) ~= "function" or not io or type(io.open) ~= "function" then return false, "JSON/file API unavailable" end
	if Spring and type(Spring.CreateDir) == "function" then
		Spring.CreateDir("LuaUI/Config/BARControllerSupport"); Spring.CreateDir("LuaUI/Config/BARControllerSupport/outbox")
	end
	local okEncode, encoded = pcall(Json.encode, document)
	if not okEncode or type(encoded) ~= "string" then return false, "Could not encode JSON" end
	local file = io.open(path, "w"); if not file then return false, "Could not open " .. path end
	file:write(encoded); file:close(); return true
end

function extra.exportPersonalProfile(path)
	local timestamp = os and type(os.date) == "function" and os.date("!%Y-%m-%dT%H:%M:%SZ") or "runtime"
	local ok, err = extra.writeJSONDocument(path or PERSONAL_PROFILE_EXPORT_PATH, { kind = "bar-controller-ui-profile",
		schemaVersion = SCHEMA_VERSION, exportedAt = timestamp, settings = settings, authorData = authorData })
	editor.status = ok and "Exported controller UI profile" or err; return ok
end

function extra.importPersonalProfile(path)
	local document, err = decodeJSONFile(path or PERSONAL_PROFILE_EXPORT_PATH, VFS and VFS.RAW_FIRST or nil)
	if type(document) ~= "table" or document.kind ~= "bar-controller-ui-profile" or type(document.settings) ~= "table" then
		editor.status = "Profile import rejected: " .. tostring(err or "invalid profile"); return false
	end
	local backupOk, backupError = extra.writeJSONDocument(PROFILE_BACKUP_PATH, { kind = "bar-controller-ui-profile",
		schemaVersion = SCHEMA_VERSION, settings = settings, authorData = authorData })
	if not backupOk then editor.status = "Profile backup failed: " .. tostring(backupError); return false end
	local ownMutation = beginMutation("Import profile")
	mergeSettingsLayer(settings, document.settings, "import preview")
	if type(document.authorData) == "table" then
		for key, fallback in pairs(newAuthorData()) do authorData[key] = type(document.authorData[key]) == "table" and deepCopy(document.authorData[key]) or fallback end
	end
	syncActionOrganizationEditor(); history.dirty = true; touch(); if ownMutation then endMutation() end
	editor.status = "Imported profile; previous state backed up"; return true
end

function extra.buildHintProfile()
	local actions, seen = {}, {}
	for _, def in pairs(hintRegistry) do
		local action = def.action or def.id
		if not seen[action] then actions[#actions + 1], seen[action] = action, true end
	end
	table.sort(actions, function(a, b)
		local ao, bo = tonumber(authorData.actionOrder[a]) or 1000, tonumber(authorData.actionOrder[b]) or 1000
		if ao ~= bo then return ao < bo end
		return a < b
	end)
	local hidden = {}
	for action, value in pairs(authorData.hiddenActions) do if value then hidden[#hidden + 1] = action end end
	table.sort(hidden)
	return { categories = getHintCategories(), actionOrdering = actions,
		actionCategoryOverrides = deepCopy(authorData.actionCategoryOverrides), hiddenActions = hidden,
		defaultShortLabels = deepCopy(authorData.shortLabels) }
end

function extra.enforcedPathList()
	local result = {}
	for path, enabled in pairs(authorData.shippingEnforcedPaths or {}) do if enabled then result[#result + 1] = path end end
	table.sort(result); return result
end

local function setShippingEnforcement(scope, key, enabled)
	if not settings.authoring.developerAuthoring then editor.status = "Developer Authoring Mode is off"; return false end
	if scope == "authoring" and key == "developerAuthoring" then editor.status = "Developer mode can never be enforced"; return false end
	local target, defaultsForScope = getScope(scope)
	if not target or (key ~= "*" and defaultsForScope[key] == nil) then return false end
	return mutateAuthorData((enabled and "Enforce " or "Stop enforcing ") .. propertyID(scope, key), function()
		local keys = key == "*" and defaultsForScope or { [key] = defaultsForScope[key] }
		for property in pairs(keys) do
			if not (scope == "authoring" and property == "developerAuthoring") then
				local path = propertyID(scope, property)
				authorData.shippingEnforcedPaths[path] = enabled == true or nil
				local root
				if scope == "global" or scope == "theme" or scope == "authoring" then
					authorData.shippingEnforcedSettings[scope] = authorData.shippingEnforcedSettings[scope] or {}
					root = authorData.shippingEnforcedSettings[scope]
				else
					authorData.shippingEnforcedSettings.components = authorData.shippingEnforcedSettings.components or {}
					authorData.shippingEnforcedSettings.components[scope] = authorData.shippingEnforcedSettings.components[scope] or {}
					root = authorData.shippingEnforcedSettings.components[scope]
				end
				root[property] = enabled and deepCopy(target[property]) or nil
			end
		end
	end)
end

local function writeAuthoringDraft()
	if not settings.authoring.developerAuthoring then editor.status = "Developer Authoring Mode is off"; return false end
	if not Json or type(Json.encode) ~= "function" or not io or type(io.open) ~= "function" then editor.status = "JSON/file API unavailable"; return false end
	if Spring and type(Spring.CreateDir) == "function" then
		Spring.CreateDir("LuaUI/Config/BARControllerSupport")
		Spring.CreateDir("LuaUI/Config/BARControllerSupport/outbox")
	end
	local timestamp = os and type(os.date) == "function" and os.date("!%Y-%m-%dT%H:%M:%SZ") or "runtime"
	local draftSettings = deepCopy(settings); draftSettings.authoring.developerAuthoring = false
	local document = { kind = "bar-controller-ui-defaults", schemaVersion = SCHEMA_VERSION,
		defaultsVersion = "draft-" .. timestamp, generatedAt = timestamp, draft = true,
		compatibleModVersion = "0.6.0", settings = draftSettings, hintProfile = extra.buildHintProfile(),
		themes = { settings.theme.preset }, componentPresets = authorData.componentPresets,
		enforcedSettings = authorData.shippingEnforcedSettings, enforcedPaths = extra.enforcedPathList(),
		draftMetadata = { authoringIntent = "explicit", sourceDefaultsVersion = shipping.activeVersion, unsavedPersonalPreview = history.dirty } }
	local okEncode, encoded = pcall(Json.encode, document)
	if not okEncode or type(encoded) ~= "string" then editor.status = "Could not encode authoring draft"; return false end
	local file = io.open(AUTHORING_OUTBOX_PATH, "w")
	if not file then editor.status = "Could not open authoring outbox"; return false end
	file:write(encoded); file:close(); editor.status = "Wrote local draft outbox (not published)"; return true
end

local function writePublishRequest()
	if not writeAuthoringDraft() then return false end
	local timestamp = os and type(os.date) == "function" and os.date("!%Y%m%d%H%M%S") or tostring(revision)
	local requestedRevision = os and type(os.time) == "function" and os.time() or revision
	local request = { kind = "bar-controller-ui-publish-request", schemaVersion = 1,
		requestId = "controller-ui-" .. timestamp, requestedVersion = "0.6.0-" .. tostring(requestedRevision),
		draftFile = "shipping-defaults.draft.json", repository = "UnderarmCape/underarmcape-bar-controller-support-attempt-01",
		branch = "controller-ui-live-defaults", explicit = true }
	local okEncode, encoded = pcall(Json.encode, request)
	if not okEncode or type(encoded) ~= "string" then editor.status = "Could not encode publish request"; return false end
	local file = io.open("LuaUI/Config/BARControllerSupport/outbox/publish-request.json", "w")
	if not file then editor.status = "Could not write publish request"; return false end
	file:write(encoded); file:close(); editor.status = "Explicit publish request queued for the developer helper"; return true
end

local function resetCurrentTab()
	if tabs[editor.tab] == "Actions" then resetHintOrganization(); syncActionOrganizationEditor(); return end
	if tabs[editor.tab] == "Recovery" then revertSession(); return end
	local scopes = {}
	for _, row in ipairs(definitions[tabs[editor.tab]] or {}) do scopes[row[1]] = true end
	local ownMutation = beginMutation("Reset " .. tostring(tabs[editor.tab]))
	for scope in pairs(scopes) do resetComponent(scope) end
	if ownMutation then endMutation() end
end

-- BAR's Lua runtime limits a function to 60 captured upvalues. Keep the hint
-- registry construction outside Initialize so adding public authoring methods
-- cannot silently make the widget unloadable even when desktop luac accepts it.
extra.installHintRegistry = function()
	WG.ControllerHintRegistry = {
		Register = addHint,
		Unregister = function(id) hintRegistry[id] = nil; hintRevision = hintRevision + 1 end,
		GetVisibleActions = function() return visibleHints end,
		GetDefinitions = function() return hintRegistry end,
		GetCategories = getHintCategories,
		SetActionHidden = setActionHidden, SetActionCategory = setActionCategory, SetActionOrder = setActionOrder,
		SetActionShortLabel = setActionShortLabel, SetCategoryVisible = setCategoryVisible,
		ResetOrganization = resetHintOrganization,
		GetAuditReport = function() return getHintAudit(support()) end,
		Invalidate = function() lastContextSignature = ""; extra.hintContextState = nil end,
	}
end

function widget:Initialize()
	recalculateScale()
	local recoveredPreview = history.dirty and deepCopy(settings) or nil
	loadShippingDocuments()
	resolveSettings(recoveredPreview)
	local behavior = extra.SharedRenderers and extra.SharedRenderers.SelectionBehavior
	extra.hintContextState = behavior and behavior.NewHintContextState() or nil
	syncActionOrganizationEditor(); extra.syncThemeColorEditor(false)
	if not history.dirty then history.lastSaved, history.lastSavedAuthorData = deepCopy(settings), deepCopy(authorData) end
	local authoringAPI = {
		SCHEMA_VERSION = SCHEMA_VERSION, REFERENCE_WIDTH = REFERENCE_WIDTH, REFERENCE_HEIGHT = REFERENCE_HEIGHT,
		Get = function(scope, key) local target = getScope(scope); return target and target[key] end,
		Set = setValue, GetComponent = function(name) return settings.components[name] end,
		GetGlobal = function() return settings.global end, GetEffectiveScale = effectiveScale,
		GetEffectiveOpacity = effectiveOpacity, GetEffectiveFontScale = effectiveFontScale,
		GetResolvedRadialStyle = extra.getResolvedRadialStyle,
		GetComponentBounds = componentBounds, GetComponentCenter = getComponentCenter, GetColor = getThemeColor,
		GetRevision = function() return revision end,
		GetPropertySource = function(scope, key) return layerSources[propertyID(scope, key)] or "fallback" end,
		GetLayerStatus = function() return { activeVersion = shipping.activeVersion, status = shipping.status,
			dirty = history.dirty, undo = #history.undo, redo = #history.redo, lastPublishResult = shipping.lastPublishResult } end,
		ResetComponent = resetComponent, ResetAll = resetAll, ToggleEditor = toggleEditor,
		OpenEditor = function() setEditorOpen(true) end, CloseEditor = function() setEditorOpen(false) end,
		IsEditorOpen = function() return editor.open end, Undo = undo, Redo = redo, Save = savePersonal,
		RevertSession = revertSession,
		ReloadDefaults = function() return reloadDefaults(true) end, WriteAuthoringDraft = writeAuthoringDraft,
		WritePublishRequest = writePublishRequest, SetShippingEnforcement = setShippingEnforcement,
		GetPreviewContext = function() return editor.previewContext end,
		SetActionHidden = setActionHidden, SetActionCategory = setActionCategory, SetActionOrder = setActionOrder,
		SetActionShortLabel = setActionShortLabel, SetCategoryVisible = setCategoryVisible,
		ResetHintOrganization = resetHintOrganization, GetHintCategories = getHintCategories,
		SaveComponentPreset = saveComponentPreset, ApplyComponentPreset = applyComponentPreset,
		RenameComponentPreset = renameComponentPreset, DuplicateComponentPreset = duplicateComponentPreset,
		DeleteComponentPreset = deleteComponentPreset, SetComponentPresetFlag = setComponentPresetFlag,
		ExportProfile = extra.exportPersonalProfile, ImportProfile = extra.importPersonalProfile,
		FavoriteCurrentColor = extra.favoriteCurrentColor, GetRecentColors = function() return deepCopy(authorData.recentColors) end,
		GetFavoriteColors = function() return deepCopy(authorData.favoriteColors) end,
		MigrateLegacyBindingsButton = function(rightOffset, topOffset)
			if migratedLegacyLauncher then return false end
			local x = (viewX - (tonumber(rightOffset) or 560)) / viewX
			local y = (viewY - (tonumber(topOffset) or 8) - 28) / viewY
			settings.components.bindingsButton.x = clamp(x, 0, 1)
			settings.components.bindingsButton.y = clamp(y, 0, 1)
			migratedLegacyLauncher = true; touch(); return true
		end,
	}
	WG.ControllerUIAuthoring = authoringAPI
	if not WG.ControllerUISettings then WG.ControllerUISettings, ownsSettingsAPI = authoringAPI, true end
	if not WG.ControllerHintRegistry then extra.installHintRegistry(); ownsHintRegistry = true end
	if widgetHandler and widgetHandler.AddAction then widgetHandler:AddAction("bar_controller_ui", toggleEditor, nil, "t") end
end

function widget:Shutdown()
	setEditorOpen(false)
	if widgetHandler and widgetHandler.RemoveAction then widgetHandler:RemoveAction("bar_controller_ui") end
	if ownsSettingsAPI then WG.ControllerUISettings = nil end
	if ownsHintRegistry then WG.ControllerHintRegistry = nil end
	WG.ControllerUIAuthoring = nil
end

function widget:ViewResize(vsx, vsy)
	viewX, viewY = math.max(1, vsx or 1), math.max(1, vsy or 1)
	recalculateScale()
	local b = editorBounds()
	editor.chrome.x, editor.chrome.y = b.x1 / viewX, b.y1 / viewY
	local bb = componentBounds("bindingsButton", 110, 28)
	if bb then settings.components.bindingsButton.x, settings.components.bindingsButton.y = bb.x1 / viewX, bb.y1 / viewY end
end

function widget:Update(dt)
	hintAnimationTime = hintAnimationTime + math.max(0, tonumber(dt) or 0)
	local api = support()
	dt = dt or 0
	if editor.open then
		if widgetHandler and widgetHandler.textOwner ~= widget then claimEditorInput(true) end
		local _, _, left, middle, right, offscreen = Spring.GetMouseState()
		if offscreen or (extra.input and extra.EditorInput.Pointer(extra.input) and not (left or middle or right)) then
			if extra.workspace then extra.EditorWorkspace.EndPointer(extra.workspace) end
			if extra.input then extra.EditorInput.LostFocus(extra.input) end
			if offscreen and widgetHandler and widgetHandler.mouseOwner == widget then widgetHandler.mouseOwner = nil end
			editor.propertyDrag, editor.dragging, editor.resizing, editor.dragComponent, editor.resizeComponent = nil, false, false, nil, nil
			editor.held = nil; endMutation()
		end
		if editor.held and editor.held.keyboard and editor.held.key and type(Spring.GetKeyState) == "function"
				and not Spring.GetKeyState(editor.held.key) then editor.held = nil; endMutation() end
	end
	if editor.held then
		editor.held.elapsed = editor.held.elapsed + dt
		if editor.held.elapsed >= editor.held.nextRepeat then
			local heldFor = editor.held.elapsed
			local multiplier = heldFor > 2.0 and 10 or heldFor > 1.0 and 4 or 1
			if editor.held.colorChannel and editor.held.row then
				local state = extra.getColorState(editor.held.row); local channel = editor.held.colorChannel
				local current = channel == "h" and state.h / 360 or channel == "s" and state.s or channel == "v" and state.v or state.a
				extra.adjustColor(editor.held.row, channel, current + editor.held.delta * (channel == "h" and (1 / 360) or 0.01) * multiplier, false)
			else adjustRow(editor.held.delta, multiplier) end
			editor.held.nextRepeat = editor.held.nextRepeat + (heldFor > 2.0 and 0.035 or heldFor > 1.0 and 0.055 or 0.085)
		end
	end
	reloadPollElapsed = reloadPollElapsed + dt
	if reloadPollElapsed >= 2 then
		reloadPollElapsed = 0
		local request = decodeJSONFile(RELOAD_REQUEST_PATH, VFS and VFS.RAW_FIRST or nil)
		local token = type(request) == "table" and tostring(request.token or request.requestedAt or "") or nil
		if token and token ~= "" then
			if lastReloadToken and token ~= lastReloadToken then reloadDefaults(true) end
			lastReloadToken = token
		end
		local publishResult = decodeJSONFile(PUBLISH_RESULT_PATH, VFS and VFS.RAW_FIRST or nil)
		if type(publishResult) == "table" and publishResult.kind == "bar-controller-ui-publish-result"
				and tostring(publishResult.completedAt or "") ~= tostring(shipping.lastPublishResult and shipping.lastPublishResult.completedAt or "") then
			shipping.lastPublishResult = publishResult
			editor.status = (publishResult.success and "Publish succeeded: " or "Publish failed: ") .. tostring(publishResult.message or "no details")
		end
	end
	local fadeDuration = settings.components.hints.fadeDuration or 0
	if fadeDuration <= 0 then hintAlpha = 1 else hintAlpha = math.min(1, hintAlpha + dt / fadeDuration) end
	if api and type(api.SetLayoutEditorOpen) == "function" then api.SetLayoutEditorOpen(editor.open) end
	if editor.open and api and type(api.IsInputPressed) == "function" then
		if api.IsInputPressed(api.GetBinding and api.GetBinding("cancel") or "B") then setEditorOpen(false)
		elseif api.IsInputPressed("LB") then editor.tab = ((editor.tab - 2) % #tabs) + 1; editor.row, editor.scroll = 1, 0
		elseif api.IsInputPressed("RB") then editor.tab = (editor.tab % #tabs) + 1; editor.row, editor.scroll = 1, 0
		elseif api.IsInputPressed("dpadUp") then editor.row = math.max(1, editor.row - 1)
		elseif api.IsInputPressed("dpadDown") then editor.row = math.min(math.max(1, #currentRows()), editor.row + 1)
		elseif api.IsInputPressed("dpadLeft") then adjustRow(-1)
		elseif api.IsInputPressed("dpadRight") then adjustRow(1) end
	end

	hintRefreshElapsed = hintRefreshElapsed + dt
	local behavior = extra.SharedRenderers and extra.SharedRenderers.SelectionBehavior
	local pollSeconds = behavior and behavior.HINT_CONTEXT_POLL_SECONDS or 0.04
	if hintRefreshElapsed < pollSeconds or not api or type(api.GetContextSnapshot) ~= "function" then return end
	hintRefreshElapsed = 0
	-- Production hints always use the real gameplay snapshot. Synthetic editor
	-- contexts are rendered only inside the preview pane.
	local context = api.GetContextSnapshot()
	if type(context) ~= "table" then return end
	local signature = contextSignature(context)
	local bindingRevision = type(api.GetBindingRevision) == "function" and api.GetBindingRevision() or 0
	local committed, contextChanged = context, signature ~= lastContextSignature
	if behavior then
		extra.hintContextState = extra.hintContextState or behavior.NewHintContextState()
		committed, contextChanged = behavior.AdvanceHintContext(extra.hintContextState, context, signature, hintAnimationTime,
			extra.isConfirmedHintModal(context), settings.components.hints.contextEnterDebounce,
			settings.components.hints.contextExitGrace)
	end
	local modelRevision = tostring(hintRevision) .. "|" .. tostring(revision)
	if contextChanged or bindingRevision ~= lastBindingRevision or modelRevision ~= tostring(extra.hintModelRevision or "") then
		lastContextSignature, lastBindingRevision, extra.hintModelRevision = contextSignature(committed), bindingRevision, modelRevision
		rebuildHints(committed, api)
	end
end

function widget:DrawScreen()
	if not editor.open then return end
	drawCanvasAuthoring(); extra.drawEditor(); glColor(1, 1, 1, 1)
end

function widget:LegacyMousePress(x, y, button)
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
		elseif tab == "Radials" then for _, name in ipairs({ "radials", "buildRadial", "tacticalRadial", "selectionRadial", "visibleSelectionRadial", "factoryRadial" }) do resetComponent(name) end
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

function widget:LegacyMouseMove(x, y)
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

function widget:LegacyMouseRelease()
	local handled = editor.dragBindings or editor.dragging or editor.resizing
	editor.dragBindings, editor.dragging, editor.resizing = false, false, false
	return handled
end

function widget:LegacyKeyPress()
	if not editor.open then return false end
	return true
end

function widget:LegacyTextCommand(command)
	local normalized = string.lower(tostring(command or "")):gsub("[%s_%-]", "")
	if normalized == "barcontrollerui" then toggleEditor(); return true end
	return false
end

function widget:LegacyGetConfigData()
	return { schemaVersion = SCHEMA_VERSION, settings = settings, editorOpen = false,
		migratedLegacyLauncher = migratedLegacyLauncher }
end

function widget:LegacySetConfigData(data)
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

local componentTabs = {
	hints = "Hints", hotSlots = "Hot Slots", bindingsButton = "Launchers", editorLauncher = "Launchers",
	buildRadial = "Radials", factoryRadial = "Radials", tacticalRadial = "Radials", selectionRadial = "Radials", visibleSelectionRadial = "Radials",
	selectedStatus = "Status", queueStatus = "Status", placementStatus = "Status",
	reticle = "Other", notifications = "Other", pregame = "Other", instructional = "Other", companionStatus = "Other",
}

local function selectComponent(name)
	editor.wheelEditId, editor.wheelEditRow = nil, nil
	editor.selectedComponent = name
	editor.navigationSelection = nil
	local wanted = componentTabs[name]
	if wanted then for index, tab in ipairs(tabs) do if tab == wanted then editor.tab = index; editor.row = 1; break end end end
	editor.status = "Selected component: " .. tostring(name)
end

local function beginComponentDrag(hit, x, y)
	selectComponent(hit.component)
	beginMutation("Move " .. hit.component)
	editor.dragComponent = hit.component; editor.dragDX, editor.dragDY = x - hit.x1, y - hit.y1
	return true
end

function extra.focusTextField(kind, numeric)
	editor.activeText, editor.selectAll = kind, false
	editor.searchActive = kind == "propertySearch"
	editor.composition = ""
	if kind == "propertyValue" and editor.textRow then
		local target = getScope(editor.textRow[1])
		editor.textBuffer = tostring(target and target[editor.textRow[2]] or "")
		editor.textOriginal = editor.textBuffer
		editor.textNumeric = numeric == true or editor.textRow[4] == "number"
	else
		editor.textNumeric = false
		if kind ~= "propertyValue" then editor.textRow = nil end
	end
	claimEditorInput()
end

function extra.resetProperty(row)
	if not row then return false end
	local _, defaultsForScope = getScope(row[1])
	if not defaultsForScope then return false end
	if row[4] == "color" then
		local prefix = string.sub(row[2], 1, -2)
		for _, key in ipairs({ prefix .. "R", prefix .. "G", prefix .. "B", string.gsub(prefix, "Color$", "") .. "Opacity" }) do
			if defaultsForScope[key] ~= nil then setValue(row[1], key, deepCopy(defaultsForScope[key])) end
		end
	else setValue(row[1], row[2], deepCopy(defaultsForScope[row[2]])) end
	editor.status = "Reset " .. rowID(row)
	return true
end

function extra.selectNavigationItem(item)
	editor.wheelEditId, editor.wheelEditRow, editor.colorWheelEditId = nil, nil, nil
	editor.navigationSelection = item.id
	if item.tab then
		for index, name in ipairs(tabs) do if name == item.tab then editor.tab = index; break end end
	end
	if item.component then editor.selectedComponent = item.component end
	local previewKind = extra.previewKind()
	if previewKind == "radials" and not string.find(editor.previewContext or "", "Radial", 1, true) then editor.previewContext = "Build Radial"
	elseif previewKind == "hotSlots" and not string.find(editor.previewContext or "", "Hot Slots", 1, true) then editor.previewContext = "Unit Hot Slots"
	elseif previewKind == "hints" and (string.find(editor.previewContext or "", "Radial", 1, true) or string.find(editor.previewContext or "", "Hot Slot", 1, true)) then editor.previewContext = "Normal Gameplay" end
	if item.filter then editor.filterMode = item.filter end
	editor.row = 1
	extra.workspace.pendingFocus = "first-property"
	editor.status = "Selected " .. tostring(item.label)
	return true
end

function extra.beginPropertyControl(action, x)
	local row = action.row
	if not row then return true end
	editor.row = action.rowIndex or editor.row
	if action.kind == "bool" then
		beginMutation("Toggle " .. rowID(row)); adjustRow(1); endMutation()
	elseif action.kind == "enum" then
		local target = getScope(row[1]); extra.EditorWorkspace.OpenEnumMenu(extra.workspace, row, row[9], target and target[row[2]])
	elseif action.kind == "text" then
		editor.textRow = row; extra.focusTextField("propertyValue", false)
	elseif action.kind == "number" then
		local ratio = clamp((x - action.control.x1) / math.max(1, action.control.x2 - action.control.x1), 0, 1)
		local value = row[5] + (row[6] - row[5]) * ratio
		if row[7] and row[7] > 0 then value = math.floor(value / row[7] + 0.5) * row[7] end
		beginMutation("Adjust " .. rowID(row)); setValue(row[1], row[2], clamp(value, row[5], row[6]))
		editor.propertyDrag = { row = row, control = action.control }
	end
	return true
end

function extra.performModalOption(option)
	if not option then return true end
	local action, row = option.action, option.row
	extra.EditorWorkspace.CloseModal(extra.workspace); extra.workspace.showHelp = false
	editor.wheelEditId, editor.wheelEditRow = nil, nil
	if action == "favorite" then toggleFavorite(row)
	elseif action == "reset" then extra.resetProperty(row)
	elseif action == "save-value" then saveCurrentValue(row)
	elseif action == "apply-value" then applySavedValue(row)
	elseif action == "toggle-enforcement" then
		local id = rowID(row); setShippingEnforcement(row[1], row[2], authorData.shippingEnforcedPaths[id] ~= true)
	elseif action == "set-enum" then setValue(row[1], row[2], option.value)
	elseif action == "set-preview-context" then editor.previewContext = tostring(option.value or "Normal Gameplay"); editor.status = "Preview: " .. editor.previewContext
	elseif action == "set-filter" then editor.filterMode = option.value; editor.row = 1; extra.workspace.pendingFocus = "first-property"
	elseif action == "align-left" then alignSelected("left")
	elseif action == "align-hcenter" then alignSelected("hcenter")
	elseif action == "align-right" then alignSelected("right")
	elseif action == "align-bottom" then alignSelected("bottom")
	elseif action == "align-vcenter" then alignSelected("vcenter")
	elseif action == "align-top" then alignSelected("top")
	elseif action == "distribute-horizontal" then distributeComponents("horizontal")
	elseif action == "distribute-vertical" then distributeComponents("vertical") end
	return true
end

function extra.handleWorkspaceAction(action, x, y, button)
	if not action then return true end
	local kind = action.type
	if kind == "close" then setEditorOpen(false)
	elseif kind == "move-window" and button == 1 then
		editor.dragging = true; editor.dragDX, editor.dragDY = x - editor.bounds.x1, y - editor.bounds.y1
		if extra.input then extra.EditorInput.Capture(extra.input, "move-window", {}, button, x, y) end
	elseif kind == "resize-window" and button == 1 then
		editor.resizing = true; editor.startX, editor.startY = x, y
		editor.startW, editor.startH = editor.bounds.width, editor.bounds.height
		if extra.input then extra.EditorInput.Capture(extra.input, "resize-window", {}, button, x, y) end
	elseif kind == "toggle-nav" then extra.workspace.navCollapsed = not extra.workspace.navCollapsed
	elseif kind == "toggle-nav-group" then extra.workspace.navGroups[action.group] = not extra.workspace.navGroups[action.group]
	elseif kind == "select-component" then extra.selectNavigationItem(action.component)
	elseif kind == "focus-component-search" then extra.focusTextField("componentSearch")
	elseif kind == "focus-property-search" then extra.focusTextField("propertySearch")
	elseif kind == "undo" then undo()
	elseif kind == "redo" then redo()
	elseif kind == "save" then savePersonal()
	elseif kind == "preview-context" then extra.EditorWorkspace.OpenPreviewMenu(extra.workspace, extra.previewMenuEntries())
	elseif kind == "toggle-preview" then extra.EditorWorkspace.TogglePreview(extra.workspace, extra.previewKind() ~= nil)
	elseif kind == "preview-safe" then extra.workspace.showSafeMargins = not extra.workspace.showSafeMargins
	elseif kind == "preview-bounds" then extra.workspace.showSelectionBounds = not extra.workspace.showSelectionBounds
	elseif kind == "toggle-debug" then
		local api = support()
		local visible = api and type(api.ToggleDebugPanel) == "function" and api.ToggleDebugPanel("Controller UI Authoring") or false
		editor.status = visible and "Controller Debug shown" or "Controller Debug hidden"
	elseif kind == "toggle-authoring-diagnostics" then
		extra.workspace.debugVisible = not extra.workspace.debugVisible
		editor.status = extra.workspace.debugVisible and "Authoring diagnostics visible in Advanced" or "Authoring diagnostics hidden"
	elseif kind == "debug-audit" then
		local report = getHintAudit(support()); Spring.Echo(string.format("Controller editor audit: focus=%s hints=%d missing=%d",
			tostring(extra.workspace.focusId), report.hintCount, #report.missingBindings))
	elseif kind == "pane-divider" and button == 1 then
		local result = extra.EditorWorkspace.DividerPress(extra.workspace, x, y, Spring and Spring.GetGameSeconds and Spring.GetGameSeconds() or 0)
		if result and result ~= "reset" and extra.input then extra.EditorInput.Capture(extra.input, "pane-divider", { divider = result }, button, x, y) end
	elseif kind == "align-menu" then extra.EditorWorkspace.OpenAlignmentMenu(extra.workspace)
	elseif kind == "help" then extra.workspace.showHelp = true
	elseif kind == "draft" then writeAuthoringDraft()
	elseif kind == "publish" then writePublishRequest()
	elseif kind == "filter" then editor.filterMode = action.mode; editor.row = 1; extra.workspace.pendingFocus = "first-property"
	elseif kind == "filter-menu" then extra.EditorWorkspace.OpenFilterMenu(extra.workspace, editor.filterMode)
	elseif kind == "toggle-property-group" then extra.EditorWorkspace.ToggleGroup(extra.workspace, action.group)
	elseif kind == "focus-property" then
		editor.row = action.rowIndex or editor.row
		if button == 3 then extra.EditorWorkspace.OpenPropertyMenu(extra.workspace, action.row, settings.authoring.developerAuthoring,
			authorData.savedValues[rowID(action.row)] ~= nil) end
	elseif kind == "property-control" then extra.beginPropertyControl(action, x)
	elseif kind == "color-slider" then
		editor.row = action.rowIndex or editor.row
		local ratio = clamp((x - action.control.x1) / math.max(1, action.control.x2 - action.control.x1), 0, 1)
		beginMutation("Adjust color " .. rowID(action.row)); extra.adjustColor(action.row, action.channel, ratio, false)
		editor.propertyDrag = { kind = "color", row = action.row, channel = action.channel, control = action.control }
		editor.colorWheelEditId = rowID(action.row) .. ":" .. action.channel
		if extra.input then extra.EditorInput.Capture(extra.input, "color-slider", { row = action.row, channel = action.channel }, button, x, y) end
	elseif kind == "color-swatch" then extra.applyColorPreset(action.row, action.preset)
	elseif kind == "color-number-entry" then
		editor.row = action.rowIndex or editor.row; local value = extra.getColorState(action.row)
		local numeric = action.channel == "h" and value.h or (action.channel == "s" and value.s or action.channel == "v" and value.v or value.a) * 100
		editor.activeText, editor.colorText, editor.selectAll, editor.composition = "colorValue", { row = action.row, channel = action.channel }, true, ""
		editor.textBuffer, editor.textOriginal, editor.textNumeric = tostring(math.floor(numeric * 100 + 0.5) / 100), tostring(numeric), true; claimEditorInput()
	elseif kind == "color-copy" then
		local value = extra.getColorState(action.row); if Spring and type(Spring.SetClipboard) == "function" then Spring.SetClipboard(value.hex) end
		editor.status = "Copied " .. tostring(value.hex)
	elseif kind == "color-paste" then
		local clipboard = Spring and type(Spring.GetClipboard) == "function" and Spring.GetClipboard() or ""
		local r, g, b, a = radialStyleAPI and radialStyleAPI.ParseHexColor and radialStyleAPI.ParseHexColor(clipboard)
		if r then local ownMutation = beginMutation("Paste color " .. rowID(action.row)); extra.applyColor(action.row, r, g, b, a, true); if ownMutation then endMutation() end
			editor.status = "Pasted color" else editor.status = "Clipboard does not contain #RRGGBB or #RRGGBBAA" end
	elseif kind == "color-favorite" then
		local value = extra.getColorState(action.row); local ownMutation = beginMutation("Favorite color " .. tostring(value.hex))
		authorData.favoriteColors[value.hex] = authorData.favoriteColors[value.hex] and nil or true
		if ownMutation then endMutation() end; history.dirty = true; editor.status = authorData.favoriteColors[value.hex] and "Favorite saved" or "Favorite removed"
	elseif kind == "property-slider" then extra.beginPropertyControl({ row = action.row, rowIndex = action.rowIndex,
		kind = "number", control = action.control }, x)
		editor.wheelEditId, editor.wheelEditRow = rowID(action.row), action.row
		if extra.input then extra.EditorInput.Capture(extra.input, "property-slider", { row = action.row }, button, x, y) end
	elseif kind == "property-step" then
		editor.row = action.rowIndex or editor.row; beginMutation("Adjust " .. rowID(action.row)); adjustRow(action.delta)
		editor.wheelEditId, editor.wheelEditRow = rowID(action.row), action.row
		editor.held = { delta = action.delta, elapsed = 0, nextRepeat = 0.38, pointer = true, row = action.row }
		if extra.input then extra.EditorInput.Capture(extra.input, "property-step", { row = action.row }, button, x, y) end
	elseif kind == "property-number-entry" then
		editor.row, editor.textRow = action.rowIndex or editor.row, action.row
		editor.wheelEditId, editor.wheelEditRow = rowID(action.row), action.row
		extra.focusTextField("propertyValue", true)
	elseif kind == "favorite-property" then toggleFavorite(action.row)
	elseif kind == "reset-property" then extra.resetProperty(action.row)
	elseif kind == "property-menu" then extra.EditorWorkspace.OpenPropertyMenu(extra.workspace, action.row, settings.authoring.developerAuthoring,
		action.row and authorData.savedValues[rowID(action.row)] ~= nil)
	elseif kind == "reset-section" then resetCurrentTab()
	elseif kind == "reset-all" then resetAll()
	elseif kind == "save-preset" then saveComponentPreset(editor.selectedComponent)
	elseif kind == "apply-preset" then applyComponentPreset(editor.selectedComponent)
	elseif kind == "preview-fit" then extra.workspace.previewFit, extra.workspace.previewZoom = true, 1
	elseif kind == "preview-zoom" then extra.workspace.previewFit = false; extra.workspace.previewZoom = clamp(extra.workspace.previewZoom + action.delta, 0.5, 2)
	elseif kind == "modal-option" then extra.performModalOption(action.option)
	elseif kind == "close-modal" then extra.EditorWorkspace.CloseModal(extra.workspace); extra.workspace.showHelp = false
		editor.wheelEditId, editor.wheelEditRow = nil, nil end
	return true
end

function widget:IsAbove(x, y)
	if editor.open then return true end
	return pointInside(editor.launcher, x, y) or pointInside(hintMoreHit, x, y)
end

function widget:GetTooltip(x, y)
	if not editor.open or not extra.workspace then return "" end
	local hit = extra.EditorWorkspace.FindHit(extra.workspace, x, y)
	return hit and tostring(hit.tooltip or hit.accessibleLabel or "") or "Controller UI Authoring modal"
end

function widget:MousePress(x, y, button)
	if not editor.open then
		if button == 1 and pointInside(hintMoreHit, x, y) then setValue("hints", "expanded", true); return true end
		if button == 1 and pointInside(editor.launcher, x, y) then toggleEditor(); return true end
		return false
	end
	if extra.input then extra.EditorInput.Press(extra.input, button, x, y) end

	local insidePanel = pointInside(editor.bounds, x, y)
	if insidePanel then
		if extra.workspace then
			if button == 1 and extra.EditorWorkspace.ScrollbarPress(extra.workspace, x, y) then
				if extra.input then extra.EditorInput.Capture(extra.input, "scrollbar", {}, button, x, y) end
				return true
			end
			local hit = extra.EditorWorkspace.FindHit(extra.workspace, x, y)
			if hit then
				local actionType = hit.action and hit.action.type
				local valueClick = actionType == "property-slider" or actionType == "property-step"
					or actionType == "property-number-entry" or actionType == "color-slider" or actionType == "color-number-entry"
				if button == 1 and not valueClick then editor.wheelEditId, editor.wheelEditRow, editor.colorWheelEditId = nil, nil, nil end
				if actionType == "color-swatch" and hit.id then extra.EditorWorkspace.SetFocus(extra.workspace, hit.id)
				elseif hit.action and hit.action.row then
					extra.EditorWorkspace.SetFocus(extra.workspace, "property:" .. rowID(hit.action.row))
				elseif hit.id then extra.EditorWorkspace.SetFocus(extra.workspace, hit.id) end
				return extra.handleWorkspaceAction(hit.action, x, y, button)
			end
			if button == 1 then editor.wheelEditId, editor.wheelEditRow, editor.colorWheelEditId = nil, nil, nil end
			return true
		end
		if button == 1 and pointInside(editor.close, x, y) then setEditorOpen(false); return true end
		for _, hit in ipairs(editor.tabs or {}) do if button == 1 and pointInside(hit, x, y) then editor.tab, editor.row, editor.scroll = hit.index, 1, 0; return true end end
		for _, hit in ipairs(editor.filterHits or {}) do if button == 1 and pointInside(hit, x, y) then editor.filterMode = hit.mode; editor.row, editor.scroll = 1, 0; return true end end
		if button == 1 and pointInside(editor.searchHit, x, y) then editor.searchActive, editor.textRow = true, nil; return true end
		if button == 1 and pointInside(editor.undo, x, y) then undo(); return true end
		if button == 1 and pointInside(editor.redo, x, y) then redo(); return true end
		if button == 1 and pointInside(editor.save, x, y) then savePersonal(); return true end
		if button == 1 and pointInside(editor.context, x, y) then cyclePreviewContext(); return true end
		if button == 1 and pointInside(editor.reload, x, y) then reloadDefaults(true); return true end
		if button == 1 and pointInside(editor.draft, x, y) then writeAuthoringDraft(); return true end
		if button == 1 and pointInside(editor.publish, x, y) then writePublishRequest(); return true end
		if button == 1 and pointInside(editor.resetSection, x, y) then resetCurrentTab(); return true end
		if button == 1 and pointInside(editor.resetAll, x, y) then resetAll(); return true end
		if button == 1 and pointInside(editor.savePreset, x, y) then saveComponentPreset(editor.selectedComponent); return true end
		if button == 1 and pointInside(editor.applyPreset, x, y) then applyComponentPreset(editor.selectedComponent); return true end
		for _, hit in ipairs(editor.alignHits or {}) do if button == 1 and pointInside(hit, x, y) then
			if hit.mode == "distribute-horizontal" then distributeComponents("horizontal")
			elseif hit.mode == "distribute-vertical" then distributeComponents("vertical") else alignSelected(hit.mode) end
			return true
		end end
		for _, hit in ipairs(editor.hits or {}) do
			if pointInside(hit, x, y) then
				editor.row = hit.index
				if button == 3 or (button == 1 and pointInside(hit.star, x, y)) then toggleFavorite(hit.row)
				elseif button == 1 and pointInside(hit.saveValue, x, y) then saveCurrentValue(hit.row)
				elseif button == 1 and pointInside(hit.applyValue, x, y) then applySavedValue(hit.row)
				elseif button == 1 and pointInside(hit.enforce, x, y) then
					local id = rowID(hit.row); setShippingEnforcement(hit.row[1], hit.row[2], authorData.shippingEnforcedPaths[id] ~= true)
				elseif button == 1 and (pointInside(hit.minus, x, y) or pointInside(hit.plus, x, y)) then
					local delta = pointInside(hit.minus, x, y) and -1 or 1
					beginMutation("Adjust " .. rowID(hit.row)); adjustRow(delta)
					editor.held = { delta = delta, elapsed = 0, nextRepeat = 0.38 }
				elseif button == 1 and hit.row[4] == "text" then
					beginMutation("Edit " .. rowID(hit.row)); editor.textRow, editor.searchActive = hit.row, false
				end
				return true
			end
		end
		if button == 1 and pointInside(editor.resize, x, y) then
			beginMutation("Resize editor"); editor.resizing = true; editor.startX, editor.startY = x, y
			editor.startW, editor.startH = editor.bounds.width, editor.bounds.height; return true
		end
		if button == 1 and editor.bounds and y >= editor.bounds.y2 - 42 then
			beginMutation("Move editor"); editor.dragging = true; editor.dragDX, editor.dragDY = x - editor.bounds.x1, y - editor.bounds.y1; return true
		end
		return true
	end
	-- Full-screen modal shield: an outside press may dismiss transient editor
	-- state, but it never reaches selection, commands, or camera handling.
	if extra.workspace and extra.workspace.modal then
		extra.EditorWorkspace.CloseModal(extra.workspace); extra.workspace.showHelp = false; return true
	elseif editor.activeText then extra.finishTextField(nil, false); return true end
	if button == 1 then
		for index = #editor.componentHits, 1, -1 do
			local hit = editor.componentHits[index]
			if pointInside(hit.resize, x, y) then
				selectComponent(hit.component)
				local item = settings.components[hit.component]
				if item and item.width and item.height then
					beginMutation("Resize " .. hit.component)
					editor.resizeComponent, editor.startX, editor.startY = hit.component, x, y
					editor.startW, editor.startH = item.width, item.height
					if extra.input then extra.EditorInput.Capture(extra.input, "live-component-resize", { component = hit.component }, button, x, y) end
				end
				return true
			elseif pointInside(hit, x, y) then
				beginComponentDrag(hit, x, y)
				if extra.input then extra.EditorInput.Capture(extra.input, "live-component-move", { component = hit.component }, button, x, y) end
				return true
			end
		end
	end
	return true
end

function widget:MouseMove(x, y)
	if not editor.open then return false end
	if extra.input then extra.EditorInput.Move(extra.input, x, y) end
	if extra.workspace and extra.EditorWorkspace.DividerDrag(extra.workspace, x) then return true
	elseif extra.workspace and extra.EditorWorkspace.ScrollbarDrag(extra.workspace, y) then return true
	elseif editor.propertyDrag then
		local drag, row = editor.propertyDrag, editor.propertyDrag.row
		local ratio = clamp((x - drag.control.x1) / math.max(1, drag.control.x2 - drag.control.x1), 0, 1)
		if drag.kind == "color" then extra.adjustColor(row, drag.channel, ratio, false)
		else
			local value = row[5] + (row[6] - row[5]) * ratio
			if row[7] and row[7] > 0 then value = math.floor(value / row[7] + 0.5) * row[7] end
			setValue(row[1], row[2], clamp(value, row[5], row[6]))
		end
		return true
	elseif editor.resizeComponent then
		local item = settings.components[editor.resizeComponent]
		local scale = math.max(0.01, effectiveScale(editor.resizeComponent))
		item.width = clamp(editor.startW + (x - editor.startX) / (REFERENCE_WIDTH * scale), 0.02, 0.95)
		item.height = clamp(editor.startH + (y - editor.startY) / (REFERENCE_HEIGHT * scale), 0.02, 0.95)
		history.dirty = true; touch(); return true
	elseif editor.dragComponent then
		for _, def in ipairs(canvasComponents) do
			if def[1] == editor.dragComponent then
				local bounds = canvasBounds(def[1], def[3], def[4]); moveComponent(def[1], x - editor.dragDX, y - editor.dragDY, bounds); return true
			end
		end
	elseif editor.dragging then
		local b, margin = editorBounds(), settings.global.safeMargin
		local px = clamp(x - editor.dragDX, margin, viewX - margin - b.width)
		local py = clamp(y - editor.dragDY, margin, viewY - margin - b.height)
		editor.chrome.x, editor.chrome.y = px / viewX, py / viewY; return true
	elseif editor.resizing then
		local maxW = math.max(100, viewX - editor.bounds.x1 - settings.global.safeMargin)
		local maxH = math.max(100, viewY - editor.bounds.y1 - settings.global.safeMargin)
		local width = clamp(editor.startW + (x - editor.startX), math.min(MIN_EDITOR_W, maxW), maxW)
		local height = clamp(editor.startH - (y - editor.startY), math.min(MIN_EDITOR_H, maxH), maxH)
		editor.chrome.width, editor.chrome.height = width / viewX, height / viewY; return true
	end
	return true
end

function widget:MouseRelease(x, y, button)
	if not editor.open then return false end
	if extra.workspace then extra.EditorWorkspace.EndPointer(extra.workspace) end
	if extra.input then extra.EditorInput.Release(extra.input, button) end
	editor.dragComponent, editor.resizeComponent, editor.dragging, editor.resizing, editor.held = nil, nil, false, false, nil
	if editor.propertyDrag and editor.propertyDrag.kind == "color" then
		local value = extra.getColorState(editor.propertyDrag.row); extra.rememberColor(value.hex)
	end
	editor.propertyDrag = nil
	editor.guides = {}; endMutation(); return true
end

function widget:MouseWheel(up, value)
	if not editor.open then return false end
	if extra.workspace then
		local x, y = Spring.GetMouseState()
		local alt, ctrl, _, shift = Spring.GetModKeyState()
		local hit = extra.EditorWorkspace.FindHit(extra.workspace, x, y)
		local action = hit and hit.action
		if action and action.type == "color-slider" and editor.colorWheelEditId == rowID(action.row) .. ":" .. action.channel then
			editor.row = action.rowIndex or editor.row; local valueState = extra.getColorState(action.row)
			local current = action.channel == "h" and valueState.h / 360 or action.channel == "s" and valueState.s or action.channel == "v" and valueState.v or valueState.a
			local step = (action.channel == "h" and (1 / 360) or 0.01) * (shift and 10 or ctrl and 0.1 or 1)
			local ownMutation = beginMutation("Adjust color " .. rowID(action.row)); extra.adjustColor(action.row, action.channel, current + (up and step or -step), true)
			if ownMutation then endMutation() end; return true
		end
		if editor.wheelEditRow and action and action.row and rowID(action.row) == editor.wheelEditId then
			editor.row = action.rowIndex or editor.row
			local multiplier = shift and 10 or ctrl and 0.1 or 1
			local row = editor.wheelEditRow
			local target = getScope(row[1]); local step = (row[7] or 1) * multiplier
			beginMutation("Adjust " .. rowID(row))
			setValue(row[1], row[2], clamp((tonumber(target[row[2]]) or row[5]) + (up and step or -step), row[5], row[6]))
			endMutation()
			return true
		end
		extra.EditorWorkspace.MouseWheel(extra.workspace, x, y, up and 1 or -1, shift)
		return true
	end
	local _, ctrl, _, shift = Spring.GetModKeyState()
	local multiplier = shift and 10 or ctrl and 0.1 or 1
	adjustRow(up and 1 or -1, multiplier); return true
end

local function shortcutMatches(spec, key, mods, label)
	spec = string.lower(tostring(spec or "")); mods = mods or {}
	if (string.find(spec, "ctrl+", 1, true) ~= nil) ~= (mods.ctrl == true) then return false end
	if (string.find(spec, "shift+", 1, true) ~= nil) ~= (mods.shift == true) then return false end
	if (string.find(spec, "alt+", 1, true) ~= nil) ~= (mods.alt == true) then return false end
	local wanted = spec:match("([^+]+)$") or spec
	local named = string.lower(tostring(label or ""))
	if named ~= "" and named == wanted then return true end
	local symbol = KEYSYMS and (KEYSYMS[string.upper(wanted)] or KEYSYMS[wanted])
	return symbol ~= nil and key == symbol
end

function extra.activeTextValue()
	if editor.activeText == "componentSearch" then return extra.workspace and extra.workspace.componentSearch or "" end
	if editor.activeText == "propertySearch" then return editor.search or "" end
	if editor.activeText == "propertyValue" and editor.textRow then return tostring(editor.textBuffer or "") end
	if editor.activeText == "colorValue" and editor.colorText then return tostring(editor.textBuffer or "") end
	return ""
end

function extra.setActiveTextValue(value)
	value = tostring(value or "")
	if editor.activeText == "componentSearch" and extra.workspace then extra.workspace.componentSearch = value
	elseif editor.activeText == "propertySearch" then editor.search, editor.row = value, 1
	elseif editor.activeText == "propertyValue" and editor.textRow then editor.textBuffer = value end
	if editor.activeText == "colorValue" and editor.colorText then editor.textBuffer = value end
end

function extra.finishTextField(focusResult, commit)
	if editor.activeText == "propertyValue" and editor.textRow then
		if commit then
			local value = editor.textNumeric and tonumber(editor.textBuffer) or editor.textBuffer
			if value ~= nil then setValue(editor.textRow[1], editor.textRow[2], value)
			else editor.status = "Invalid numeric value; edit cancelled" end
		end
		editor.textRow = nil
	end
	if editor.activeText == "colorValue" and editor.colorText then
		if commit then
			local value = tonumber(editor.textBuffer); local channel = editor.colorText.channel
			if value then
				local ownMutation = beginMutation("Exact color " .. channel); extra.adjustColor(editor.colorText.row, channel,
					channel == "h" and clamp(value, 0, 360) / 360 or clamp(value, 0, 100) / 100, true); if ownMutation then endMutation() end
			else editor.status = "Invalid color value; edit cancelled" end
		end
		editor.colorText = nil
	end
	editor.activeText, editor.searchActive, editor.selectAll = nil, false, false
	editor.textBuffer, editor.textOriginal, editor.textNumeric, editor.composition = "", "", false, ""
	if extra.workspace and focusResult == "property" then extra.workspace.pendingFocus = "first-property" end
	if extra.workspace and focusResult == "component" then
		for _, item in ipairs(extra.workspace.focusItems) do
			if item.id and string.find(item.id, "component:", 1, true) == 1 then extra.EditorWorkspace.SetFocus(extra.workspace, item.id); break end
		end
	end
end

function extra.handleTextFieldKey(key, mods, label)
	mods = mods or {}
	local named = string.lower(tostring(label or ""))
	if mods.ctrl and named == "a" then editor.selectAll = true; return true end
	if mods.ctrl and (named == "c" or named == "x") then
		if Spring and type(Spring.SetClipboard) == "function" then Spring.SetClipboard(extra.activeTextValue()) end
		if named == "x" then extra.setActiveTextValue(""); editor.selectAll = false end
		return true
	end
	if mods.ctrl and named == "v" then
		local pasted = Spring and type(Spring.GetClipboard) == "function" and Spring.GetClipboard() or ""
		extra.setActiveTextValue(editor.selectAll and pasted or extra.activeTextValue() .. tostring(pasted or "")); editor.selectAll = false
		return true
	end
	if KEYSYMS and key == KEYSYMS.BACKSPACE then
		local value = extra.activeTextValue(); extra.setActiveTextValue(editor.selectAll and "" or string.sub(value, 1, math.max(0, #value - 1)))
		editor.selectAll = false; return true
	end
	if KEYSYMS and key == KEYSYMS.RETURN then
		local result = editor.activeText == "componentSearch" and "component" or editor.activeText == "propertySearch" and "property" or nil
		extra.finishTextField(result, true); return true
	end
	if KEYSYMS and key == KEYSYMS.ESCAPE then extra.finishTextField(nil, false)
		editor.wheelEditId, editor.wheelEditRow = nil, nil; return true end
	return true
end

function extra.activateFocusedControl()
	if not extra.workspace then return false end
	local item = extra.EditorWorkspace.Focused(extra.workspace)
	if not item or not item.action then return true end
	local action = item.action
	if action.type == "focus-property" then
		editor.row = action.rowIndex or editor.row
		if action.row[4] == "bool" then beginMutation("Toggle " .. rowID(action.row)); adjustRow(1); endMutation()
		elseif action.row[4] == "enum" then
			local target = getScope(action.row[1]); extra.EditorWorkspace.OpenEnumMenu(extra.workspace, action.row, action.row[9], target and target[action.row[2]])
		elseif action.row[4] == "color" then
			editor.colorWheelEditId = rowID(action.row) .. ":h"; editor.status = "Hue focused; Left/Right and wheel adjust"
		elseif action.row[4] == "text" or action.row[4] == "number" then
			if action.row[4] == "number" then editor.wheelEditId, editor.wheelEditRow = rowID(action.row), action.row end
			editor.textRow = action.row; extra.focusTextField("propertyValue", action.row[4] == "number")
		else editor.status = "Use Left/Right to adjust " .. tostring(action.row[3]) end
		return true
	end
	return extra.handleWorkspaceAction(action, editor.bounds.x1, editor.bounds.y1, 1)
end

function extra.adjustFocusedControl(delta, multiplier, isRepeat, key)
	local item = extra.workspace and extra.EditorWorkspace.Focused(extra.workspace) or nil
	if not item or not item.row then return true end
	editor.row = item.rowIndex or editor.row
	if item.action and item.action.type == "color-swatch" then extra.EditorWorkspace.MoveFocus(extra.workspace, delta); return true end
	if item.row[4] == "color" then
		local channel = editor.colorWheelEditId and string.match(editor.colorWheelEditId, ":([hsva])$") or "h"
		local state = extra.getColorState(item.row); local current = channel == "h" and state.h / 360 or channel == "s" and state.s or channel == "v" and state.v or state.a
		local step = (channel == "h" and (1 / 360) or 0.01) * (multiplier or 1)
		if not isRepeat and not editor.held then beginMutation("Adjust color " .. rowID(item.row)); editor.held = { delta = delta, elapsed = 0, nextRepeat = 0.38, keyboard = true, key = key, row = item.row, colorChannel = channel } end
		extra.adjustColor(item.row, channel, current + delta * step, false); editor.colorWheelEditId = rowID(item.row) .. ":" .. channel
		return true
	end
	if not isRepeat and not editor.held then
		beginMutation("Adjust " .. rowID(item.row)); adjustRow(delta, multiplier)
		editor.held = { delta = delta, elapsed = 0, nextRepeat = 0.38, keyboard = true, key = key, row = item.row }
	end
	return true
end

function widget:KeyPress(key, mods, isRepeat, label)
	if not editor.open then return false end
	if extra.input then extra.EditorInput.KeyDown(extra.input, key) end
	mods = mods or {}
	if extra.workspace and extra.workspace.modal then
		if KEYSYMS and key == KEYSYMS.ESCAPE then extra.EditorWorkspace.CloseModal(extra.workspace); extra.workspace.showHelp = false
			editor.wheelEditId, editor.wheelEditRow, editor.colorWheelEditId = nil, nil, nil; return true end
		if KEYSYMS and (key == KEYSYMS.UP or key == KEYSYMS.LEFT) then extra.EditorWorkspace.MoveFocus(extra.workspace, -1); return true end
		if KEYSYMS and (key == KEYSYMS.DOWN or key == KEYSYMS.RIGHT) then extra.EditorWorkspace.MoveFocus(extra.workspace, 1); return true end
		if KEYSYMS and key == KEYSYMS.HOME then extra.EditorWorkspace.FocusBoundary(extra.workspace, false); return true end
		if KEYSYMS and key == KEYSYMS.END then extra.EditorWorkspace.FocusBoundary(extra.workspace, true); return true end
		if KEYSYMS and key == KEYSYMS.PAGEUP then extra.EditorWorkspace.Page(extra.workspace, -1); return true end
		if KEYSYMS and key == KEYSYMS.PAGEDOWN then extra.EditorWorkspace.Page(extra.workspace, 1); return true end
		if shortcutMatches(settings.authoring.shortcutPrevious, key, mods, label) then extra.EditorWorkspace.MoveFocus(extra.workspace, -1); return true end
		if shortcutMatches(settings.authoring.shortcutNext, key, mods, label) then extra.EditorWorkspace.MoveFocus(extra.workspace, 1); return true end
		if KEYSYMS and (key == KEYSYMS.SPACE or key == KEYSYMS.RETURN) then return extra.activateFocusedControl() end
		return true
	end
	if shortcutMatches(settings.authoring.shortcutUndo, key, mods, label) then if not isRepeat then undo() end; return true end
	if shortcutMatches(settings.authoring.shortcutRedo, key, mods, label) then if not isRepeat then redo() end; return true end
	if shortcutMatches(settings.authoring.shortcutSave, key, mods, label) then if not isRepeat then savePersonal() end; return true end
	if shortcutMatches(settings.authoring.shortcutDraft, key, mods, label) then if not isRepeat then writeAuthoringDraft() end; return true end
	if shortcutMatches(settings.authoring.shortcutPublish, key, mods, label) then if not isRepeat then writePublishRequest() end; return true end
	if shortcutMatches(settings.authoring.shortcutSearch, key, mods, label) then extra.focusTextField("propertySearch"); if extra.workspace then extra.EditorWorkspace.SetFocus(extra.workspace, "inspector:search") end; return true end
	if editor.activeText then return extra.handleTextFieldKey(key, mods, label) end
	if KEYSYMS and key == KEYSYMS.ESCAPE and (editor.wheelEditId or editor.colorWheelEditId) then
		editor.wheelEditId, editor.wheelEditRow, editor.colorWheelEditId = nil, nil, nil; editor.status = "Wheel value editing exited"; return true
	end
	if (KEYSYMS and KEYSYMS.F1 and key == KEYSYMS.F1) or string.lower(tostring(label or "")) == "f1" then
		if extra.workspace then extra.workspace.showHelp = not extra.workspace.showHelp end; return true
	end
	if shortcutMatches(settings.authoring.shortcutClose, key, mods, label) then setEditorOpen(false); return true end
	if extra.workspace then
		if shortcutMatches(settings.authoring.shortcutPrevious, key, mods, label) then extra.EditorWorkspace.MoveFocus(extra.workspace, -1); return true end
		if shortcutMatches(settings.authoring.shortcutNext, key, mods, label) then extra.EditorWorkspace.MoveFocus(extra.workspace, 1); return true end
		if KEYSYMS and key == KEYSYMS.UP then extra.EditorWorkspace.MoveFocus(extra.workspace, -1); return true end
		if KEYSYMS and key == KEYSYMS.DOWN then extra.EditorWorkspace.MoveFocus(extra.workspace, 1); return true end
		local multiplier = mods.shift and 10 or (mods.ctrl and 0.1 or 1)
		if KEYSYMS and key == KEYSYMS.LEFT then return extra.adjustFocusedControl(-1, multiplier, isRepeat, key) end
		if KEYSYMS and key == KEYSYMS.RIGHT then return extra.adjustFocusedControl(1, multiplier, isRepeat, key) end
		if KEYSYMS and key == KEYSYMS.PAGEUP then extra.EditorWorkspace.Page(extra.workspace, -1); return true end
		if KEYSYMS and key == KEYSYMS.PAGEDOWN then extra.EditorWorkspace.Page(extra.workspace, 1); return true end
		if KEYSYMS and (key == KEYSYMS.HOME or key == KEYSYMS.END) then
			local item = extra.EditorWorkspace.Focused(extra.workspace)
			if item and item.row and item.row[4] == "number" then setValue(item.row[1], item.row[2], key == KEYSYMS.HOME and item.row[5] or item.row[6])
			elseif item and item.row and item.row[4] == "color" then
				local channel = editor.colorWheelEditId and string.match(editor.colorWheelEditId, ":([hsva])$") or "h"; extra.adjustColor(item.row, channel, key == KEYSYMS.HOME and 0 or 1, true)
			else extra.EditorWorkspace.FocusBoundary(extra.workspace, key == KEYSYMS.END) end
			return true
		end
		if KEYSYMS and (key == KEYSYMS.SPACE or key == KEYSYMS.RETURN) then return extra.activateFocusedControl() end
		if KEYSYMS and key == KEYSYMS.DELETE then editor.status = "Delete is available only for selected custom items"; return true end
		return true
	end
	if KEYSYMS and key == KEYSYMS.UP then editor.row = math.max(1, editor.row - 1); return true end
	if KEYSYMS and key == KEYSYMS.DOWN then editor.row = math.min(math.max(1, #currentRows()), editor.row + 1); return true end
	local multiplier = mods and mods.shift and 10 or (mods and mods.ctrl and 0.1 or 1)
	if KEYSYMS and key == KEYSYMS.LEFT then adjustRow(-1, multiplier); return true end
	if KEYSYMS and key == KEYSYMS.RIGHT then adjustRow(1, multiplier); return true end
	if KEYSYMS and key == KEYSYMS.PAGEUP then adjustRow(10, multiplier); return true end
	if KEYSYMS and key == KEYSYMS.PAGEDOWN then adjustRow(-10, multiplier); return true end
	if KEYSYMS and (key == KEYSYMS.HOME or key == KEYSYMS.END) then
		local row = currentRow(); if row and row[4] == "number" then setValue(row[1], row[2], key == KEYSYMS.HOME and row[5] or row[6]) end; return true
	end
	if shortcutMatches(settings.authoring.shortcutPrevious, key, mods, label) then editor.row = math.max(1, editor.row - 1); return true end
	if shortcutMatches(settings.authoring.shortcutNext, key, mods, label) then editor.row = (editor.row % math.max(1, #currentRows())) + 1; return true end
	if KEYSYMS and (key == KEYSYMS.SPACE or key == KEYSYMS.RETURN) then
		local row = currentRow(); if row and row[4] == "bool" then adjustRow(1) elseif row and row[4] == "text" then beginMutation("Edit " .. rowID(row)); editor.textRow = row end; return true
	end
	if KEYSYMS and key == KEYSYMS.DELETE then
		local row = currentRow(); if row then
			local id = rowID(row)
			if authorData.favorites[id] then toggleFavorite(row) else local _, defaultsForScope = getScope(row[1]); setValue(row[1], row[2], defaultsForScope[row[2]]) end
		end; return true
	end
	return true
end

function widget:KeyRelease(key)
	if not editor.open then return false end
	if extra.input then extra.EditorInput.KeyUp(extra.input, key) end
	if editor.held and editor.held.keyboard and (editor.held.key == nil or editor.held.key == key) then
		if editor.held.colorChannel and editor.held.row then extra.rememberColor(extra.getColorState(editor.held.row).hex) end
		editor.held = nil; endMutation()
	end
	return true
end

function widget:TextInput(value)
	if not editor.open or type(value) ~= "string" then return false end
	if editor.activeText then
		extra.setActiveTextValue(editor.selectAll and value or extra.activeTextValue() .. value)
		editor.selectAll, editor.composition = false, ""; if extra.input then extra.EditorInput.SetComposition(extra.input, "") end; return true
	end
	return true
end

function widget:TextEditing(value)
	if not editor.open then return false end
	editor.composition = editor.activeText and tostring(value or "") or ""
	if extra.input then extra.EditorInput.SetComposition(extra.input, editor.composition) end
	return true
end

function widget:TextCommand(command)
	local raw = string.lower(tostring(command or "")):gsub("^%s+", ""):gsub("%s+$", "")
	local compact = raw:gsub("[%s_%-]", "")
	if compact == "barcontrollerui" then toggleEditor(); return true end
	if raw:match("^bar[_%-]?controller[_%-]?ui%s+save$") then savePersonal(); return true end
	if raw:match("^bar[_%-]?controller[_%-]?ui%s+revert$") then revertSession(); return true end
	if raw:match("^bar[_%-]?controller[_%-]?ui%s+defaults%s+reload$") then reloadDefaults(true); return true end
	if raw:match("^bar[_%-]?controller[_%-]?ui%s+draft$") then writeAuthoringDraft(); return true end
	if raw:match("^bar[_%-]?controller[_%-]?ui%s+publish%s+request$") then writePublishRequest(); return true end
	local authorMode = raw:match("^bar[_%-]?controller[_%-]?ui%s+authoring%s+(%a+)$")
	if authorMode == "on" or authorMode == "off" then
		setValue("authoring", "developerAuthoring", authorMode == "on"); savePersonal()
		Spring.Echo("Controller UI Developer Authoring Mode " .. string.upper(authorMode)); return true
	end
	local shortcut, value = raw:match("^bar[_%-]?controller[_%-]?ui%s+shortcut%s+(%w+)%s+(.+)$")
	local shortcutKeys = { undo = "shortcutUndo", redo = "shortcutRedo", save = "shortcutSave", draft = "shortcutDraft",
		publish = "shortcutPublish", search = "shortcutSearch", close = "shortcutClose", next = "shortcutNext", previous = "shortcutPrevious" }
	if shortcut and shortcutKeys[shortcut] then setValue("authoring", shortcutKeys[shortcut], value); return true end
	local visibility, action = raw:match("^bar[_%-]?controller[_%-]?ui%s+hint%s+(%a+)%s+([%w_%-]+)$")
	if (visibility == "hide" or visibility == "show") and action then setActionHidden(action, visibility == "hide"); return true end
	local orderAction, order = raw:match("^bar[_%-]?controller[_%-]?ui%s+hint%s+order%s+([%w_%-]+)%s+(-?%d+)$")
	if orderAction then setActionOrder(orderAction, tonumber(order)); return true end
	local categoryAction, category = raw:match("^bar[_%-]?controller[_%-]?ui%s+hint%s+category%s+([%w_%-]+)%s+(.+)$")
	if categoryAction then setActionCategory(categoryAction, category); return true end
	local labelAction, shortLabel = raw:match("^bar[_%-]?controller[_%-]?ui%s+hint%s+short%s+([%w_%-]+)%s+(.+)$")
	if labelAction then setActionShortLabel(labelAction, shortLabel); return true end
	local categoryVisibility, categoryName = raw:match("^bar[_%-]?controller[_%-]?ui%s+category%s+(%a+)%s+(.+)$")
	if (categoryVisibility == "hide" or categoryVisibility == "show") and categoryName then setCategoryVisible(categoryName, categoryVisibility == "show"); return true end
	if raw:match("^bar[_%-]?controller[_%-]?ui%s+hint%s+restore$") then resetHintOrganization(); return true end
	local enforceMode, enforceScope, enforceKey = raw:match("^bar[_%-]?controller[_%-]?ui%s+(%a+)%s+([%w_%-]+)%.([%w_*%-]+)$")
	if enforceMode == "enforce" or enforceMode == "unenforce" then setShippingEnforcement(enforceScope, enforceKey, enforceMode == "enforce"); return true end
	local presetCommand, presetName = raw:match("^bar[_%-]?controller[_%-]?ui%s+preset%s+(%a+)%s+(.+)$")
	if presetCommand == "save" then saveComponentPreset(editor.selectedComponent, presetName); return true end
	if presetCommand == "apply" then applyComponentPreset(editor.selectedComponent, presetName); return true end
	if presetCommand == "delete" then deleteComponentPreset(presetName); return true end
	local renameFrom, renameTo = raw:match("^bar[_%-]?controller[_%-]?ui%s+preset%s+rename%s+(.+)%s+=>%s+(.+)$")
	if renameFrom then renameComponentPreset(renameFrom, renameTo); return true end
	local duplicateFrom, duplicateTo = raw:match("^bar[_%-]?controller[_%-]?ui%s+preset%s+duplicate%s+(.+)%s+=>%s+(.+)$")
	if duplicateFrom then duplicateComponentPreset(duplicateFrom, duplicateTo); return true end
	if raw:match("^bar[_%-]?controller[_%-]?ui%s+profile%s+export$") then extra.exportPersonalProfile(); return true end
	local importPath = raw:match("^bar[_%-]?controller[_%-]?ui%s+profile%s+import%s+(.+)$")
	if importPath then extra.importPersonalProfile(importPath); return true end
	if raw:match("^bar[_%-]?controller[_%-]?ui%s+audit$") then
		local report = getHintAudit(support()); Spring.Echo(string.format("Controller hint audit: bindings=%d hints=%d missing=%d unregistered=%d never-visible=%d",
			report.bindingCount, report.hintCount, #report.missingBindings, #report.unregisteredActions, #report.neverVisible)); return true
	end
	return false
end

function widget:GetConfigData()
	local workspaceChrome = extra.workspace and extra.EditorWorkspace.ExportChrome(extra.workspace) or nil
	return { schemaVersion = SCHEMA_VERSION, personalSettings = personalSettings or history.lastSaved,
		settings = personalSettings or history.lastSaved, authorData = history.dirty and history.lastSavedAuthorData or authorData,
		recovery = history.dirty and { dirty = true, settings = settings, authorData = authorData } or { dirty = false },
		editorChrome = { window = deepCopy(editor.chrome), workspace = workspaceChrome, tab = editor.tab,
			selectedComponent = editor.selectedComponent, filterMode = editor.filterMode, previewContext = editor.previewContext },
		editorOpen = false, migratedLegacyLauncher = migratedLegacyLauncher }
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then return end
	local savedSchema = tonumber(data.schemaVersion)
	if savedSchema ~= nil and savedSchema ~= 1 and savedSchema ~= 2 and savedSchema ~= SCHEMA_VERSION then
		personalSettings, authorData = nil, newAuthorData()
		loadShippingDocuments(); resolveSettings(nil); syncActionOrganizationEditor(); extra.syncThemeColorEditor(false)
		history.lastSaved, history.lastSavedAuthorData = deepCopy(settings), deepCopy(authorData); return
	end
	local saved = type(data.personalSettings) == "table" and data.personalSettings or data.settings
	personalSettings = type(saved) == "table" and deepCopy(saved) or nil
	authorData = newAuthorData()
	if type(data.authorData) == "table" then
		for key, fallback in pairs(authorData) do
			authorData[key] = type(data.authorData[key]) == "table" and deepCopy(data.authorData[key]) or fallback
		end
	end
	loadShippingDocuments(); resolveSettings(nil); syncActionOrganizationEditor(); extra.syncThemeColorEditor(false)
	history.lastSaved = deepCopy(settings); history.lastSavedAuthorData = deepCopy(authorData)
	if type(data.recovery) == "table" and data.recovery.dirty == true and type(data.recovery.settings) == "table" then
		resolveSettings(data.recovery.settings)
		if type(data.recovery.authorData) == "table" then authorData = deepCopy(data.recovery.authorData) end
		syncActionOrganizationEditor(); extra.syncThemeColorEditor(false)
		history.dirty = true; editor.recoveryAvailable = true; editor.status = "Recovered unsaved authoring changes"
	else history.dirty = false end
	history.undo, history.redo, history.active = {}, {}, nil
	migratedLegacyLauncher = data.migratedLegacyLauncher == true
	local chrome = type(data.editorChrome) == "table" and data.editorChrome or {}
	local window = type(chrome.window) == "table" and chrome.window or settings.components.editor or DEFAULTS.components.editor
	editor.chrome = {
		x = clamp(window.x, 0, 1), y = clamp(window.y, 0, 1),
		width = clamp(window.width, 0.20, 0.95), height = clamp(window.height, 0.30, 0.95),
	}
	editor.tab = clamp(chrome.tab or editor.tab, 1, #tabs)
	editor.selectedComponent = type(chrome.selectedComponent) == "string" and chrome.selectedComponent or editor.selectedComponent
	editor.filterMode = type(chrome.filterMode) == "string" and chrome.filterMode or "Basic"
	editor.previewContext = type(chrome.previewContext) == "string" and chrome.previewContext or "Normal Gameplay"
	if extra.workspace then extra.EditorWorkspace.ImportChrome(extra.workspace, chrome.workspace); extra.EditorWorkspace.ResetSession(extra.workspace) end
end
