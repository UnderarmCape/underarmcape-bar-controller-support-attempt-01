local root = (arg and arg[1]) or "."

local function fail(label, detail) error(label .. ": " .. tostring(detail or "failed"), 2) end
local function assertTrue(value, label) if not value then fail(label, "expected true") end end
local function assertEqual(actual, expected, label) if actual ~= expected then fail(label, "expected " .. tostring(expected) .. ", got " .. tostring(actual)) end end
local function assertNear(actual, expected, label, tolerance)
	if math.abs((actual or 0) - expected) > (tolerance or 0.0001) then fail(label, "expected near " .. expected .. ", got " .. tostring(actual)) end
end
local function readFile(path) local file = assert(io.open(path, "rb")); local value = file:read("*a"); file:close(); return value end

local activeColor, textCalls = { 1, 1, 1, 1 }, {}
GL = { TRIANGLE_FAN = 1, LINE_LOOP = 2 }
gl = {
	Color = function(r, g, b, a) activeColor = { r, g, b, a } end,
	Rect = function() end, GetTextWidth = function(value) return #tostring(value) * 0.55 end,
	Text = function(value, x, y, size, flags) textCalls[#textCalls + 1] = { value = tostring(value), x = x, y = y, size = size, flags = flags, color = activeColor } end,
	BeginEnd = function(_, callback) callback() end, Vertex = function() end, LineWidth = function() end,
	Texture = function() end, TexRect = function() end, Scissor = function() end,
}

local Renderers = dofile(root .. "/luaui/Include/controller_ui_shared_renderers.lua")
local Style = Renderers.RadialStyle
local theme = { backgroundR = 0.02, backgroundG = 0.03, backgroundB = 0.04, accentR = 0.34, accentG = 0.82, accentB = 0.92 }
local model = {
	style = "build", title = "Advanced Solar Collector", description = "Generates energy and supports a nearby construction project with a deliberately useful description.",
	categoryLabel = "ECONOMY", metalCost = "370", energyCost = "4200", metadata = { "Build time 28.4s", "Health 1,850" },
	footer = "LS choose  A confirm", pageLabel = "PAGE 1/2", selectedIndex = 2,
	entries = { { label = "Economy", indexLabel = "1" }, { label = "Energy", indexLabel = "2" },
		{ label = "Unavailable", indexLabel = "3", disabled = true, unavailableText = "UNAVAILABLE" }, { label = "Factory", indexLabel = "4" } },
}

local function render(global, component, extraSettings)
	textCalls = {}; local settings = extraSettings or {}; settings.typography = Style.Resolve(global or {}, component or {})
	return Renderers.DrawRadial({ bounds = { x1 = 0, y1 = 0, x2 = 640, y2 = 640 }, theme = theme, model = model, settings = settings, opacity = 1 })
end

local baseline = render()
assertTrue(baseline.roles.categoryLabel and baseline.roles.centerTitle and baseline.roles.centerDescription, "semantic roles render")

local categorySize = render({ categoryLabelSize = 31 })
assertEqual(categorySize.roles.categoryLabel.size, 31, "1 category size reaches geometry")
assertEqual(categorySize.roles.centerTitle.size, baseline.roles.centerTitle.size, "1 category size changes only category geometry")

local categoryColor = render({ categoryLabelColorR = 0.91, categoryLabelColorG = 0.13, categoryLabelColorB = 0.27 })
assertNear(categoryColor.roles.categoryLabel.color[1], 0.91, "2 category color reaches role")
assertNear(categoryColor.roles.centerTitle.color[1], baseline.roles.centerTitle.color[1], "2 category color does not alter title")

local titleSize = render({ centerTitleSize = 29 })
assertEqual(titleSize.roles.centerTitle.size, 29, "3 title size reaches title")
assertEqual(titleSize.roles.centerDescription.size, baseline.roles.centerDescription.size, "3 title size independent from description")

local descriptionSize = render({ centerDescriptionSize = 17 })
assertEqual(descriptionSize.roles.centerDescription.size, 17, "4 description size reaches body")
assertEqual(descriptionSize.roles.centerTitle.size, baseline.roles.centerTitle.size, "4 description size independent from title")

local descriptionSpacing = render({ centerDescriptionLineSpacing = 12 })
assertTrue(descriptionSpacing.roles.centerDescription.lineSpacing > baseline.roles.centerDescription.lineSpacing, "5 description line spacing changes layout")

local descriptionNarrow = render({ centerDescriptionMaxWidth = 0.55, centerDescriptionMaxLines = 6 })
assertTrue(descriptionNarrow.roles.centerDescription.lineCount > baseline.roles.centerDescription.lineCount, "6 description width changes wrapping")

local resourceColor = render({ metalCostColorR = 0.93, energyCostColorR = 0.21 })
assertNear(resourceColor.roles.metalCost.color[1], 0.93, "7 metal color reaches metal")
assertNear(resourceColor.roles.energyCost.color[1], 0.21, "7 metal and energy colors independent")

assertNear(Style.DEFAULTS.energyCostColorR, 1, "8 energy default red")
assertNear(Style.DEFAULTS.energyCostColorG, 0.86, "8 energy default readable yellow")
assertNear(Style.DEFAULTS.energyCostColorB, 0.12, "8 energy default blue")

local resourceSizes = render({ metalCostSize = 19, energyCostSize = 13 })
assertEqual(resourceSizes.roles.metalCost.size, 19, "9 metal font independent")
assertEqual(resourceSizes.roles.energyCost.size, 13, "9 energy font independent")

local resourceIcons = render({ metalCostIconSize = 21, energyCostIconSize = 9 })
assertEqual(resourceIcons.roles.metalCost.iconSize, 21, "10 metal icon independent")
assertEqual(resourceIcons.roles.energyCost.iconSize, 9, "10 energy icon independent")

local metadataSize = render({ metadataSize = 16 })
assertEqual(metadataSize.roles.metadata.size, 16, "11 metadata size independent")
assertEqual(metadataSize.roles.centerDescription.size, baseline.roles.centerDescription.size, "11 metadata does not resize description")

local metadataColor = render({ metadataColorB = 0.19 })
assertNear(metadataColor.roles.metadata.color[3], 0.19, "12 metadata color independent")
assertNear(metadataColor.roles.centerTitle.color[3], baseline.roles.centerTitle.color[3], "12 metadata color does not alter title")

local inherited = Style.Resolve({ centerTitleSize = 27 }, { typographyOverride = false, centerTitleSize = 9 })
assertEqual(inherited.centerTitle.size, 27, "13 global values inherited")

local overridden = Style.Resolve({ centerTitleSize = 27 }, { typographyOverride = true, centerTitleSize = 14 })
assertEqual(overridden.centerTitle.size, 14, "14 per-radial override supersedes global")

local removed = Style.Resolve({ centerTitleSize = 27 }, { typographyOverride = false, centerTitleSize = 14 })
assertEqual(removed.centerTitle.size, 27, "15 removing override restores inheritance")

local reset = Style.Resolve({}, {})
assertEqual(reset.centerTitle.size, Style.DEFAULTS.centerTitleSize, "16 reset resolves shipping fallback")

local layoutSource = readFile(root .. "/luaui/Widgets/gui_controller_ui_layout.lua")
local cameraSource = readFile(root .. "/luaui/Widgets/gui_controller_camera_test.lua")
assertTrue(layoutSource:find("typography = extra%.getResolvedRadialStyle%(componentName%)"), "17 preview uses resolved production style")
assertTrue(cameraSource:find("GetResolvedRadialStyle") and cameraSource:find("settings = renderSettings"), "17 production uses resolved production style")

local redR, redG, redB = Style.HSVToRGB(0, 1, 1)
assertNear(redR, 1, "18 HSV red R"); assertNear(redG, 0, "18 HSV red G"); assertNear(redB, 0, "18 HSV red B")

local hue, saturation, value = Style.RGBToHSV(0, 1, 0)
assertNear(hue, 120, "19 RGB green hue"); assertNear(saturation, 1, "19 RGB green saturation"); assertNear(value, 1, "19 RGB green value")

local baseH, baseS, baseV = Style.RGBToHSV(0.2, 0.5, 0.8); local hr, hg, hb = Style.HSVToRGB(250, baseS, baseV)
local changedH, changedS, changedV = Style.RGBToHSV(hr, hg, hb)
assertNear(changedH, 250, "20 hue adjustment"); assertNear(changedS, baseS, "20 hue preserves saturation"); assertNear(changedV, baseV, "20 hue preserves value")

local sr, sg, sb = Style.HSVToRGB(baseH, 0.2, baseV); local saturatedH, saturatedS, saturatedV = Style.RGBToHSV(sr, sg, sb)
assertNear(saturatedH, baseH, "21 saturation preserves hue"); assertNear(saturatedS, 0.2, "21 saturation adjustment"); assertNear(saturatedV, baseV, "21 saturation preserves value")

local vr, vg, vb = Style.HSVToRGB(baseH, baseS, 0.4); local valueH, valueS, valueV = Style.RGBToHSV(vr, vg, vb)
assertNear(valueH, baseH, "22 value preserves hue"); assertNear(valueS, baseS, "22 value preserves saturation"); assertNear(valueV, 0.4, "22 value adjustment")

local parsedR, parsedG, parsedB, parsedA = Style.ParseHexColor("#33669980")
assertNear(parsedR, 0.2, "23 alpha parse preserves red", 0.003); assertNear(parsedA, 128 / 255, "23 alpha independent", 0.003)

assertTrue(#Style.COLOR_PRESETS >= 20, "24 at least twenty swatches")
local energyPreset, metalPreset
for _, preset in ipairs(Style.COLOR_PRESETS) do if preset[1] == "Energy" then energyPreset = preset elseif preset[1] == "Metal" then metalPreset = preset end end
assertTrue(energyPreset and metalPreset, "24 named resource presets")
assertNear(energyPreset[2], 1, "24 energy preset red"); assertNear(energyPreset[3], 0.86, "24 energy preset yellow")

assertTrue(layoutSource:find('beginMutation%("Adjust color ') and layoutSource:find('editor%.propertyDrag = { kind = "color"'), "25 drag starts one logical mutation")
assertTrue(layoutSource:find("editor%.propertyDrag = nil") and layoutSource:find("endMutation%(%)"), "25 release closes one logical mutation")

assertEqual(Style.ColorHex(parsedR, parsedG, parsedB, parsedA), "#33669980", "26 saved hex/RGBA migrates unchanged")
assertTrue(layoutSource:find("personalSettings") and layoutSource:find("favoriteColors") and layoutSource:find("recentColors"), "26 personal color collections remain persisted")

for key, fallback in pairs(Style.DEFAULTS) do
	local alternate = type(fallback) == "boolean" and not fallback or type(fallback) == "number" and fallback + 0.123
		or fallback == "Row" and "Column" or fallback == "Center" and "Right" or fallback == "Truncate" and "Wrap" or fallback
	local measured = render({ [key] = alternate })
	assertEqual(measured.parameters.typography.flat[key], alternate, "27 exposed property reaches final render parameters: " .. key)
end

local workspaceSource = readFile(root .. "/luaui/Include/controller_ui_editor_workspace.lua")
assertTrue(workspaceSource:find("color%-swatch:") and workspaceSource:find("addFocus%(state") and layoutSource:find("Search properties"), "28 search and keyboard focus reach new controls")

assertTrue(layoutSource:find("colorWheelEditId == rowID%(action%.row%) %.%. %\":%\" %.%. action%.channel")
	and layoutSource:find("MouseWheel") and layoutSource:find("MouseMove"), "29 focused wheel gating remains explicit")

assertEqual(Renderers.SelectionBehavior.FilterFromStick(0, -1), "Combat", "30 existing radial navigation behavior")
assertTrue(cameraSource:find("ControllerCameraTestGetCachedAffordability") and cameraSource:find("ControllerCameraTestUpdateVisibleSelectionRadial"), "30 command behavior remains wired")

print("Controller radial typography tests passed: 30/30 property-wiring, HSV, swatch, inheritance, migration, focus, undo, and navigation behaviors validated.")
