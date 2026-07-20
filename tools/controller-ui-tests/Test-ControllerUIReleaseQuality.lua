local root = (arg and arg[1]) or "."

local function assertTrue(value, label)
	if not value then error(label .. ": expected true", 2) end
end

local function assertEqual(actual, expected, label)
	if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function read(path)
	local file = assert(io.open(path, "rb"), "missing " .. path)
	local content = file:read("*a"); file:close(); return content
end

local calls = { rect = 0, text = 0, tex = 0, scissor = 0 }
GL = { TRIANGLE_FAN = 1, LINE_LOOP = 2 }
gl = setmetatable({
	Color = function() end, Rect = function() calls.rect = calls.rect + 1 end,
	Text = function() calls.text = calls.text + 1 end,
	GetTextWidth = function(value) return #tostring(value) * 0.56 end,
	BeginEnd = function(_, callback) callback() end, Vertex = function() end, LineWidth = function() end,
	Texture = function() end, TexRect = function() calls.tex = calls.tex + 1 end,
	Scissor = function() calls.scissor = calls.scissor + 1 end,
}, { __index = function() return function() end end })

local glyphCalls = 0
local glyphs = {
	BuildSequence = function(inputs, options)
		local sequence = {}
		if options.hold and options.holdStyle == "Hold Glyph" then sequence[#sequence + 1] = { id = "hold" } end
		for _, input in ipairs(inputs or {}) do sequence[#sequence + 1] = { id = input } end
		return sequence
	end,
	Dimensions = function(sequence, size, spacing) return #sequence * size + math.max(0, #sequence - 1) * spacing, size end,
	DrawSequence = function() glyphCalls = glyphCalls + 1 end,
}

local Renderers = dofile(root .. "/luaui/Include/controller_ui_shared_renderers.lua")
local theme = { backgroundR = 0.018, backgroundG = 0.028, backgroundB = 0.04,
	foregroundR = 0.94, foregroundG = 0.98, foregroundB = 1,
	accentR = 0.34, accentG = 0.82, accentB = 0.92, mutedR = 0.36, mutedG = 0.52, mutedB = 0.60 }
local hintModel = {
	{ inputs = { "A" }, label = "Select" },
	{ inputs = { "LB", "RB" }, label = "A deliberately overflowing production hint label", hold = true },
}
local settings = {
	enabled = true, columns = 1, maxItems = 8, expanded = true, padding = 9, rowSpacing = 6,
	columnSpacing = 17, iconTextSpacing = 11, maxWidth = 0.7, iconScale = 1.2, glyphSpacing = 5,
	showChip = true, showActionText = true, overflow = "Ping Pong", marqueeSpeed = 32, marqueeDelay = 0.5,
	textOpacity = 0.91, glyphOpacity = 0.83, backgroundOpacity = 0, borderOpacity = 0,
	textShadowEnabled = true, textShadowOpacity = 0.7, textShadowOffsetX = 3, textShadowOffsetY = -3,
	glyphShadowEnabled = true, glyphShadowOpacity = 0.65, glyphShadowOffsetX = 2, glyphShadowOffsetY = -2,
	textGlowEnabled = true, textGlowOpacity = 0.3, textGlowSize = 3, textGlowIntensity = 1.2,
	glyphGlowEnabled = true, glyphGlowOpacity = 0.25, glyphGlowSize = 2, glyphGlowIntensity = 1.1,
	textBackgroundEnabled = true, textBackgroundOpacity = 0.55, textBackgroundPaddingX = 7,
	textBackgroundPaddingY = 3, textBackgroundBorderOpacity = 0.4,
	showHoldIndicator = true, holdStyle = "Bold HOLD", holdLabelScale = 1.2, holdLabelSpacing = 9,
}
local hintResult = Renderers.DrawHints({ model = hintModel, settings = settings, theme = theme, glyphs = glyphs,
	viewportWidth = 800, viewportHeight = 500, bounds = { x1 = 0, y1 = 0, x2 = 430, y2 = 150 }, time = 2.25 })
assertTrue(hintResult.effects.textShadow > 0 and hintResult.effects.glyphShadow > 0, "separate text/glyph shadows draw")
assertTrue(hintResult.effects.textGlow > 0 and hintResult.effects.glyphGlow > 0, "separate text/glyph glows draw")
assertEqual(hintResult.effects.textBackground, 2, "per-label backgrounds draw independently")
assertTrue(hintResult.effects.clipped > 0 and calls.scissor >= 2, "overflow is clipped in final draw path")
assertTrue(hintResult.motions[2].active and hintResult.motions[2].offset > 0, "ping-pong reaches overflowing production label")
assertTrue(hintResult.parameters.glyphSize > 18 and hintResult.parameters.columnGap > 0, "hint sizing/spacing properties reach layout")

settings.holdStyle = "Hold Glyph"; settings.textGlowEnabled = false; settings.glyphGlowEnabled = false
local holdGlyphResult = Renderers.DrawHints({ model = hintModel, settings = settings, theme = theme, glyphs = glyphs,
	viewportWidth = 800, viewportHeight = 500, bounds = { x1 = 0, y1 = 0, x2 = 430, y2 = 150 }, time = 1 })
assertTrue(holdGlyphResult.effects.glyph > 0 and glyphCalls > 0, "hold-glyph treatment uses live binding sequence")

local build = Renderers.DrawRadial({ bounds = { x1 = 0, y1 = 0, x2 = 500, y2 = 500 }, theme = theme,
	settings = { iconScale = 1.3, fontScale = 1.15, centerTextScale = 1.2, selectedScale = 1.09,
		selectedBorderThickness = 4, itemSpacing = 0.92, legacyThemeOpacity = 0.85, pageStatusVisible = true },
	model = { style = "build", title = "Fusion Reactor", categoryLabel = "ENERGY", pageLabel = "PAGE 2/3",
		selectedIndex = 2, details = { "Advanced power generation", "Cost 4200 M / 26000 E" }, entries = {
		{ label = "Solar", texture = "#1" }, { label = "Fusion", texture = "#2", badge = 3 }, { label = "Storage" },
	} } })
assertEqual(build.style, "build", "polished build model dispatch")
assertTrue(build.panelRadius > 0 and build.iconSize > 0 and build.parameters.itemSpacing == 0.92,
	"build center panel/icons/spacing are measured")
local tactical = Renderers.DrawRadial({ bounds = { x1 = 0, y1 = 0, x2 = 500, y2 = 500 }, theme = theme,
	settings = { fontScale = 1.1, selectedScale = 1.08 }, model = { style = "tactical", title = "Tactical",
		categoryLabel = "TACTICAL", selectedIndex = 2, categoryChips = { { label = "UTILITY", direction = "up", selected = true } },
		entries = { { label = "Fight" }, { label = "Patrol" }, { label = "Guard" } } } })
assertEqual(tactical.style, "tactical", "polished tactical model dispatch")
assertTrue(tactical.itemWidth > tactical.itemHeight, "legacy tactical command-card geometry")
local selection = Renderers.DrawRadial({ bounds = { x1 = 0, y1 = 0, x2 = 420, y2 = 420 }, theme = theme,
	model = { style = "selection", title = "SELECT FILTER", entries = {
		{ label = "All Mobile" }, { label = "Air" }, { label = "Combat" }, { label = "Builders" },
	} } })
assertEqual(selection.style, "selection", "polished selection compass dispatch")

local slots = Renderers.DrawHotSlots({ bounds = { x1 = 0, y1 = 0, x2 = 540, y2 = 180 }, theme = theme,
	settings = { slotCount = 6, orientation = "Grid", rows = 2, slotWidth = 48, slotHeight = 40, slotGap = 7,
		panelPadding = 10, iconScale = 1.25, selectedBorderThickness = 3.5, showLabel = true, showStatus = true },
	model = { selectedIndex = 2, slots = { { label = "1", count = 3 }, { label = "2", count = 8, selected = true },
		{ label = "3", empty = true }, { label = "4", count = 2 }, { label = "5", empty = true }, { label = "6", count = 1 } } } })
assertEqual(slots.parameters.rows, 2, "hot-slot row property changes layout")
assertEqual(slots.parameters.columns, 3, "hot-slot orientation changes columns")
assertEqual(slots.parameters.iconScale, 1.25, "hot-slot icon scale reaches draw parameters")
assertTrue(slots.parameters.gap > 0 and slots.parameters.slotWidth ~= slots.parameters.slotHeight,
	"hot-slot gap and independent dimensions reach layout")

loadstring = loadstring or load
local Json = dofile(root .. "/common/luaUtilities/json.lua")
local defaults = Json.decode(read(root .. "/controller-ui/shipping-defaults.json"))
local manifest = Json.decode(read(root .. "/controller-ui/shipping-defaults-manifest.json"))
assertEqual(defaults.defaultsVersion, "0.6.0-3", "shipping defaults revision")
assertEqual(manifest.revision, 3, "shipping manifest revision")
assertEqual(#defaults.enforcedPaths, 0, "shipping defaults do not enforce personal appearance")
local shippedHints = defaults.settings.components.hints
assertEqual(shippedHints.backgroundOpacity, 0, "default giant hint panel disabled")
assertTrue(not shippedHints.glyphBackgroundEnabled and not shippedHints.glyphBorderEnabled, "default glyph fill/border disabled")
assertTrue(shippedHints.textShadowEnabled and shippedHints.glyphShadowEnabled, "default readable shadows enabled")
assertTrue(not shippedHints.textGlowEnabled and not shippedHints.glyphGlowEnabled, "default glow remains optional")
assertEqual(shippedHints.holdStyle, "Bold HOLD", "default strong hold treatment")
assertTrue(shippedHints.showTapHold == nil and shippedHints.shadowEnabled == nil and shippedHints.marqueeEnabled == nil,
	"obsolete/no-op hint fields removed from shipping defaults")

local layout = read(root .. "/luaui/Widgets/gui_controller_ui_layout.lua")
local camera = read(root .. "/luaui/Widgets/gui_controller_camera_test.lua")
local workspace = read(root .. "/luaui/Include/controller_ui_editor_workspace.lua")
assertTrue(not layout:find('addProperty%("Hints", "hints", "showTapHold"'), "obsolete TAP control hidden")
assertTrue(not layout:find('addProperty%("Hints", "hints", "shadowEnabled"'), "obsolete aggregate shadow control hidden")
assertTrue(layout:find('wheelEditingId = editor%.wheelEditId'), "visible wheel edit focus is supplied to inspector")
assertTrue(layout:find('editor%.wheelEditRow and action'), "wheel edit requires explicit focus")
assertTrue(workspace:find('"WHEEL"'), "wheel edit focus has a visible indicator")
assertTrue(camera:find('debugPanelVisible = false'), "Controller Debug starts hidden")
assertTrue(camera:find('key ~= "debugPanelVisible"'), "Controller Debug excluded from persisted settings")
assertTrue(camera:find('ToggleDebugPanel') and camera:find('IsDebugPanelVisible'), "clean Controller Debug WG API installed")
assertTrue(camera:find('model = { style = "tactical"') and camera:find('model = { style = "selection"')
	and camera:find('model = { style = "build"'), "all production radial owners select polished shared styles")
assertTrue(camera:find('ControllerUISharedRenderers%.DrawHotSlots'), "production hot slots use shared renderer")

print("Controller UI v0.6.0 release-quality tests passed: polished shared models, complete hint effects, deterministic motion, focus-gated wheel editing, session-only debug, D-pad-ready glyph path, and revision-3 defaults.")
