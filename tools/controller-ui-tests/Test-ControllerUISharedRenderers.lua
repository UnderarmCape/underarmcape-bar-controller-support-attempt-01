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

local calls = { rect = 0, text = 0, fan = 0, texture = 0, glyph = 0 }
GL = { TRIANGLE_FAN = 1 }
gl = {
	Color = function() end,
	Rect = function() calls.rect = calls.rect + 1 end,
	Text = function() calls.text = calls.text + 1 end,
	GetTextWidth = function(value) return #tostring(value) * 0.55 end,
	BeginEnd = function(_, callback) calls.fan = calls.fan + 1; callback() end,
	Vertex = function() end,
	Texture = function() calls.texture = calls.texture + 1 end,
	TexRect = function() end,
}

local glyphs = {
	BuildSequence = function(inputs) return inputs or {} end,
	Dimensions = function(sequence, size, spacing) return #sequence * (size + spacing), size end,
	DrawSequence = function() calls.glyph = calls.glyph + 1 end,
}

local Renderers = dofile(root .. "/luaui/Include/controller_ui_shared_renderers.lua")
local theme = {
	backgroundR = 0.02, backgroundG = 0.03, backgroundB = 0.04,
	foregroundR = 0.94, foregroundG = 0.98, foregroundB = 1,
	accentR = 0.34, accentG = 0.82, accentB = 0.92,
	mutedR = 0.36, mutedG = 0.52, mutedB = 0.60,
}

local hints = Renderers.DrawHints({
	model = {
		{ inputs = { "A" }, label = "Select" },
		{ inputs = { "B" }, label = "Cancel" },
		{ inputs = { "LB", "RB" }, label = "Long wrapped action text used by the preview" },
	},
	settings = { enabled = true, maxItems = 2, expanded = false, priorityHiding = true,
		showChip = true, showActionText = true, overflow = "Wrap", wrapLines = 2,
		padding = 8, maxWidth = 0.52, columns = 1 },
	theme = theme, glyphs = glyphs, viewportWidth = 1280, viewportHeight = 720,
	bounds = { x1 = 0, y1 = 0, x2 = 520, y2 = 180 }, formatInputs = function() return "A" end,
})
assertEqual(#hints.hits, 2, "hint renderer applies production item limit")
assertTrue(hints.moreHit ~= nil, "hint renderer exposes production overflow row")
assertTrue(hints.x2 > hints.x1 and hints.y2 > hints.y1, "hint renderer returns measured bounds")
assertEqual(calls.glyph, 2, "hint renderer uses glyph sequence drawing")

local radial = Renderers.DrawRadial({
	bounds = { x1 = 0, y1 = 0, x2 = 420, y2 = 420 }, theme = theme,
	model = { title = "Build", subtitle = "Choose", selectedIndex = 2, entries = {
		{ label = "Economy", texture = "unitpics/armmex.dds" }, { label = "Energy" },
		{ label = "Defense" }, { label = "Factory" },
	} },
})
assertEqual(radial.count, 4, "radial renderer draws supplied production model")
assertTrue(radial.radius > 0 and calls.fan >= 2, "radial renderer draws outer and center geometry")
assertTrue(calls.texture >= 2, "radial renderer binds and releases unit texture")

local slots = Renderers.DrawHotSlots({
	bounds = { x1 = 0, y1 = 0, x2 = 520, y2 = 120 }, theme = theme,
	settings = { slotCount = 4, orientation = "Horizontal", slotWidth = 42, slotHeight = 42,
		showLabel = true, showStatus = true, showCounts = true, showRole = true },
	model = { selectedIndex = 3, status = "Group ready", slots = {
		{ label = "1", count = 12, role = "combat" }, { label = "2", empty = true },
		{ label = "3", count = 4, selected = true, role = "builder" }, { label = "4", empty = true },
	} },
})
assertEqual(slots.count, 4, "hot-slot renderer draws configured production slots")
assertTrue(slots.x2 > slots.x1 and slots.y2 > slots.y1, "hot-slot renderer returns measured bounds")
assertTrue(calls.rect > 20 and calls.text > 10, "shared renderers issue complete geometry and labels")

local layoutSource = readFile(root .. "/luaui/Widgets/gui_controller_ui_layout.lua")
local _, hintCallCount = layoutSource:gsub("extra%.SharedRenderers%.DrawHints", "")
assertTrue(hintCallCount >= 2, "production hints and editor preview call one shared renderer")
assertTrue(layoutSource:find("previewAvailable = extra.previewKind%(%) ~= nil"), "unsupported components declare no preview")
assertTrue(layoutSource:find("drawPreview = extra.previewKind%(%) and extra.drawWorkspacePreview or nil"), "unsupported components do not draw substitutes")

local cameraSource = readFile(root .. "/luaui/Widgets/gui_controller_camera_test.lua")
local _, radialCallCount = cameraSource:gsub("ControllerUISharedRenderers%.DrawRadial", "")
local _, hotSlotCallCount = cameraSource:gsub("ControllerUISharedRenderers%.DrawHotSlots", "")
assertTrue(radialCallCount >= 3, "production radial paths call the shared renderer")
assertTrue(hotSlotCallCount >= 1, "production hot-slot path calls the shared renderer")

print("Controller UI shared renderer tests passed: hints, radials, and hot slots share measured production drawing paths with previews; unsupported components remain preview-free.")
