local root = (arg and arg[1]) or "."

local function assertTrue(value, label)
	if not value then error(label .. ": expected true", 2) end
end

local function assertEqual(actual, expected, label)
	if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function readFile(path)
	local file = assert(io.open(path, "rb"), "missing file: " .. path)
	local content = file:read("*a"); file:close(); return content
end

local texRects, textFallbacks, textureAvailable, lastTexRect = 0, 0, true, nil
gl = setmetatable({
	Color = function() end, Rect = function() end,
	Text = function() textFallbacks = textFallbacks + 1 end,
	Texture = function(path) if path == false then return true end return textureAvailable end,
	TexRect = function(x1, y1, x2, y2) texRects = texRects + 1; lastTexRect = { x1, y1, x2, y2 } end,
}, { __index = function() return function() end end })

local Glyphs = dofile(root .. "/luaui/Include/controller_glyphs.lua")

for _, token in ipairs({ "A", "B", "X", "Y", "LB", "RB", "LT", "RT", "leftStick", "rightStick",
	"leftStickClick", "rightStickClick", "dpad", "dpadUp", "dpadDown", "dpadLeft", "dpadRight",
	"back", "start", "guide", "stickDirection", "stickRotate", "tap", "hold", "doubleTap",
	"mouseLeft", "mouseRight", "mouseWheel", "keyboardKey" }) do
	assertTrue(not Glyphs.Resolve(token).fallback, "required glyph resolves: " .. token)
end

assertEqual(Glyphs.Resolve("Left Bumper").id, "LB", "friendly bumper alias")
assertEqual(Glyphs.Resolve("Start/Menu").id, "start", "friendly start alias")
assertEqual(Glyphs.Resolve("D-pad Down").id, "dpadDown", "friendly dpad alias")
assertEqual(Glyphs.Resolve("L3").id, "L3", "stick click alias")

local sequence = Glyphs.BuildSequence({ "back", "start", "LB", "RB" }, { hold = true, showTapHold = true })
assertEqual(sequence[1].id, "hold", "hold indicator prefixes chord")
assertEqual(#sequence, 8, "hold plus four-button chord layout")
assertEqual(sequence[3].id, "plus", "chord separator inserted")
assertEqual(sequence[#sequence].id, "RB", "final chord glyph retained")
local tapSequence = Glyphs.BuildSequence({ "A" }, { hold = false, showTapHold = true })
assertEqual(#tapSequence, 1, "ordinary tap never adds a TAP label")
assertEqual(tapSequence[1].id, "A", "ordinary tap begins with its live binding")
local boldHoldSequence = Glyphs.BuildSequence({ "A" }, { hold = true, showHold = true, holdStyle = "Bold HOLD" })
assertEqual(boldHoldSequence[1].id, "A", "bold HOLD style leaves label treatment to the renderer")
local glyphHoldSequence = Glyphs.BuildSequence({ "A" }, { hold = true, showHold = true, holdStyle = "Hold Glyph" })
assertEqual(glyphHoldSequence[1].id, "hold", "hold-glyph style prefixes the live sequence")

local rebound = Glyphs.BuildSequence({ "A" }, {})
assertEqual(rebound[1].id, "A", "first live binding resolution")
rebound = Glyphs.BuildSequence({ "dpadRight" }, {})
assertEqual(rebound[1].id, "dpadRight", "changed live binding resolution")

local inlineChord = Glyphs.BuildSequence({ "LB+X" }, {})
assertEqual(#inlineChord, 3, "inline chord tokenization")
assertEqual(inlineChord[2].id, "plus", "inline chord separator")
local ordered = Glyphs.BuildSequence({ "A > B" }, {})
assertEqual(ordered[2].id, "sequence", "sequence indicator")

local missing = Glyphs.Resolve("Paddle 7")
assertTrue(missing.fallback, "missing glyph uses fallback")
assertEqual(missing.text, "Paddle 7", "fallback preserves binding text")

local width = Glyphs.Dimensions(sequence, 24, 4, "Horizontal")
assertTrue(width > 150, "long chord has stress width")
local entries, fittedWidth, _, fittedSize = Glyphs.Layout(sequence, 0, 0, 24, 4, "Horizontal", "left", 120)
assertEqual(#entries, #sequence, "long chord keeps every glyph")
assertTrue(fittedWidth <= 121, "long chord fits maximum width")
assertTrue(fittedSize >= 12, "long chord stays above minimum readable size")
local verticalWidth, verticalHeight = Glyphs.Dimensions(sequence, 20, 3, "Vertical")
assertEqual(verticalWidth, 20, "vertical chord width")
assertTrue(verticalHeight > 150, "vertical chord height")

texRects, textFallbacks, textureAvailable = 0, 0, true
local _, _, fallbackCount = Glyphs.DrawSequence(sequence, 10, 10, {
	size = 22, spacing = 3, layout = "Horizontal", colorMode = "Color-friendly", opacity = 0.9,
	tint = { 0.3, 0.8, 0.9 }, backgroundOpacity = 0.2, borderOpacity = 0.5,
})
assertEqual(texRects, #sequence, "atlas renders each chord glyph")
assertEqual(fallbackCount, 0, "complete chord has no text fallbacks")

texRects, lastTexRect, textureAvailable = 0, nil, true
Glyphs.DrawSequence(Glyphs.BuildSequence({ "dpadUp" }, {}), 10, 10, { size = 31, spacing = 0 })
assertEqual(texRects, 1, "directional D-pad draws from atlas")
assertTrue(math.abs((lastTexRect[3] - lastTexRect[1]) - (lastTexRect[4] - lastTexRect[2])) < 0.001,
	"directional D-pad destination preserves square atlas aspect")

texRects, textFallbacks, textureAvailable = 0, 0, false
local missingTextureCount = select(3, Glyphs.DrawSequence(sequence, 10, 10, { size = 22 }))
assertEqual(texRects, 0, "missing atlas does not issue texture rectangles")
assertEqual(missingTextureCount, #sequence, "missing atlas falls back to text")
assertEqual(textFallbacks, #sequence, "missing atlas fallback remains visible")

local assetRoot = root .. "/luaui/Images/controller-glyphs/"
local png = readFile(assetRoot .. "controller_glyph_atlas.png")
assertEqual(string.sub(png, 1, 8), "\137PNG\13\10\26\10", "atlas PNG signature")
local bytes = { string.byte(png, 17, 24) }
local pngWidth = bytes[1] * 16777216 + bytes[2] * 65536 + bytes[3] * 256 + bytes[4]
local pngHeight = bytes[5] * 16777216 + bytes[6] * 65536 + bytes[7] * 256 + bytes[8]
assertEqual(pngWidth, 512, "atlas width")
assertEqual(pngHeight, 320, "atlas height")

loadstring = loadstring or load
local Json = dofile(root .. "/common/luaUtilities/json.lua")
local manifest = Json.decode(readFile(assetRoot .. "asset-manifest.json"))
assertEqual(manifest.kind, "bar-controller-original-glyph-atlas", "asset manifest kind")
assertEqual(#manifest.glyphs, 40, "asset manifest coverage")
assertTrue(string.find(readFile(assetRoot .. "LICENSE.md"), "original generic controller/input artwork", 1, true) ~= nil,
	"asset license documents original source")
assertTrue(#readFile(root .. "/tools/dev-scripts/Generate_Controller_Glyph_Atlas.ps1") > 1000, "atlas generator source exists")

print("Controller glyph tests passed: aliases, live rebinding, hold/chord/sequence layout, long-chord fitting, missing-glyph and missing-atlas fallback, rendering, asset dimensions, manifest, and license.")
