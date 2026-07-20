--------------------------------------------------------------------------------
-- BAR Controller Companion generic controller glyph resolver and atlas renderer
--------------------------------------------------------------------------------

local Glyphs = {
	texture = "LuaUI/Images/controller-glyphs/controller_glyph_atlas.png",
	atlasWidth = 512, atlasHeight = 320, cell = 64, columns = 8, rows = 5,
}

local order = {
	"A", "B", "X", "Y", "LB", "RB", "LT", "RT",
	"leftStick", "rightStick", "L3", "R3", "dpad", "dpadUp", "dpadDown", "dpadLeft",
	"dpadRight", "back", "start", "guide", "stickDirection", "stickRotate", "tap", "hold",
	"doubleTap", "chord", "plus", "sequence", "mouseLeft", "mouseRight", "mouseWheel", "keyboardKey",
	"mouseMiddle", "dpadHorizontal", "dpadVertical", "leftStickX", "leftStickY", "rightStickX", "rightStickY", "fallback",
}

local labels = {
	A = "A button", B = "B button", X = "X button", Y = "Y button",
	LB = "Left bumper", RB = "Right bumper", LT = "Left trigger", RT = "Right trigger",
	leftStick = "Left stick", rightStick = "Right stick", L3 = "Left stick click", R3 = "Right stick click",
	dpad = "D-pad", dpadUp = "D-pad Up", dpadDown = "D-pad Down", dpadLeft = "D-pad Left", dpadRight = "D-pad Right",
	back = "Back / View", start = "Start / Menu", guide = "Guide / Home", stickDirection = "Stick direction",
	stickRotate = "Rotate stick", tap = "Tap", hold = "Hold", doubleTap = "Double tap", chord = "Chord",
	plus = "Simultaneous with", sequence = "Then", mouseLeft = "Left mouse button", mouseRight = "Right mouse button",
	mouseWheel = "Mouse wheel", mouseMiddle = "Middle mouse button", keyboardKey = "Keyboard key",
	dpadHorizontal = "D-pad horizontal", dpadVertical = "D-pad vertical", leftStickX = "Left stick horizontal",
	leftStickY = "Left stick vertical", rightStickX = "Right stick horizontal", rightStickY = "Right stick vertical",
	fallback = "Unknown input",
}

local faceColors = {
	A = { 0.35, 0.88, 0.48 }, B = { 0.96, 0.35, 0.32 }, X = { 0.30, 0.65, 1.00 }, Y = { 1.00, 0.82, 0.24 },
}

Glyphs.definitions = {}
for index, id in ipairs(order) do
	local column = (index - 1) % Glyphs.columns
	local row = math.floor((index - 1) / Glyphs.columns)
	Glyphs.definitions[id] = {
		id = id, label = labels[id], index = index,
		u1 = column / Glyphs.columns, v1 = row / Glyphs.rows,
		u2 = (column + 1) / Glyphs.columns, v2 = (row + 1) / Glyphs.rows,
		color = faceColors[id], widthFactor = (id == "plus" or id == "chord") and 0.55 or (id == "sequence" and 0.72 or 1),
		-- Every atlas cell is square. Keeping this explicit makes destination
		-- aspect preservation testable and prevents directional D-pads from
		-- inheriting a stretched control rectangle.
		textureAspect = 1,
	}
end

local aliases = {
	a = "A", abutton = "A", buttona = "A", b = "B", bbutton = "B", buttonb = "B",
	x = "X", xbutton = "X", buttonx = "X", y = "Y", ybutton = "Y", buttony = "Y",
	lb = "LB", leftbumper = "LB", leftshoulder = "LB", lshoulder = "LB",
	rb = "RB", rightbumper = "RB", rightshoulder = "RB", rshoulder = "RB",
	lt = "LT", lefttrigger = "LT", rt = "RT", righttrigger = "RT",
	leftstick = "leftStick", ls = "leftStick", leftanalog = "leftStick",
	rightstick = "rightStick", rs = "rightStick", rightanalog = "rightStick",
	leftstickclick = "L3", l3 = "L3", ls3 = "L3", rightstickclick = "R3", r3 = "R3", rs3 = "R3",
	dpad = "dpad", dpadup = "dpadUp", dpaddown = "dpadDown", dpadleft = "dpadLeft", dpadright = "dpadRight",
	back = "back", backview = "back", view = "back", select = "back", share = "back",
	start = "start", startmenu = "start", menu = "start", options = "start", guide = "guide", home = "guide",
	stickdirection = "stickDirection", stickrotate = "stickRotate", rotation = "stickRotate",
	tap = "tap", hold = "hold", doubletap = "doubleTap", chord = "chord", plus = "plus", sequence = "sequence", ["then"] = "sequence",
	mouseleft = "mouseLeft", mouse1 = "mouseLeft", lmb = "mouseLeft", leftmouse = "mouseLeft",
	mouseright = "mouseRight", mouse2 = "mouseRight", rmb = "mouseRight", rightmouse = "mouseRight",
	mousewheel = "mouseWheel", wheel = "mouseWheel", mousemiddle = "mouseMiddle", mouse3 = "mouseMiddle", mmb = "mouseMiddle",
	keyboard = "keyboardKey", key = "keyboardKey", keyboardkey = "keyboardKey",
	dpadhorizontal = "dpadHorizontal", dpadvertical = "dpadVertical",
	leftstickx = "leftStickX", leftsticky = "leftStickY", rightstickx = "rightStickX", rightsticky = "rightStickY",
}

local resolveCache = {}

function Glyphs.Normalize(token)
	return string.lower(tostring(token or "")):gsub("[%s_%-/]", "")
end

function Glyphs.Resolve(token)
	local raw = tostring(token or "Unbound")
	local normalized = Glyphs.Normalize(raw)
	local cached = resolveCache[normalized]
	if cached then return cached end
	local id = aliases[normalized]
	local definition = id and Glyphs.definitions[id] or nil
	if definition then
		resolveCache[normalized] = definition
		return definition
	end
	local fallback = {
		id = "fallback", label = raw ~= "" and raw or "Unbound", text = raw ~= "" and raw or "Unbound",
		fallback = true, widthFactor = math.max(1, math.min(2.4, #raw * 0.18)),
	}
	resolveCache[normalized] = fallback
	return fallback
end

local function appendToken(sequence, token)
	if token == nil or tostring(token) == "" then return end
	sequence[#sequence + 1] = Glyphs.Resolve(token)
end

local function splitBinding(sequence, binding)
	binding = tostring(binding or "")
	local separator = string.find(binding, ">", 1, true) and "sequence" or "plus"
	local pattern = separator == "sequence" and "[^>]+" or "[^+]+"
	local found = false
	for token in string.gmatch(binding, pattern) do
		if found then sequence[#sequence + 1] = Glyphs.definitions[separator] end
		appendToken(sequence, token:gsub("^%s+", ""):gsub("%s+$", "")); found = true
	end
	if not found then appendToken(sequence, binding) end
end

function Glyphs.BuildSequence(inputs, options)
	options = options or {}
	local sequence = {}
	-- Tap is the ordinary interaction and is intentionally never advertised.
	-- Hold can be represented by the atlas only when the selected hold style
	-- asks for it; the renderer supplies the alternative bold HOLD treatment.
	local holdGlyph = options.hold and (options.holdStyle == "Hold Glyph"
		or options.showTapHold == true or (options.showHold == nil and options.holdStyle == nil))
	if holdGlyph then sequence[#sequence + 1] = Glyphs.definitions.hold end
	for index, input in ipairs(type(inputs) == "table" and inputs or { inputs }) do
		if index > 1 then sequence[#sequence + 1] = Glyphs.definitions.plus end
		splitBinding(sequence, input)
	end
	if #sequence == 0 then sequence[1] = Glyphs.Resolve("Unbound") end
	return sequence
end

function Glyphs.Text(sequence)
	local parts = {}
	for _, glyph in ipairs(sequence or {}) do parts[#parts + 1] = glyph.label or glyph.text or glyph.id end
	return table.concat(parts, " ")
end

function Glyphs.Dimensions(sequence, size, spacing, layout)
	size, spacing, layout = tonumber(size) or 24, tonumber(spacing) or 4, layout or "Horizontal"
	if layout == "Vertical" then return size, #sequence * size + math.max(0, #sequence - 1) * spacing end
	local stepFactor = layout == "Stacked" and 0.68 or 1
	local width = 0
	for index, glyph in ipairs(sequence or {}) do
		if index > 1 then width = width + spacing end
		width = width + size * (glyph.widthFactor or 1) * stepFactor
	end
	return width, size
end

function Glyphs.Layout(sequence, x, y, size, spacing, layout, alignment, maxWidth)
	size, spacing = tonumber(size) or 24, tonumber(spacing) or 4
	local width, height = Glyphs.Dimensions(sequence, size, spacing, layout)
	if maxWidth and width > maxWidth then
		local ratio = maxWidth / width
		size, spacing = math.max(12, size * ratio), math.max(1, spacing * ratio)
		width, height = Glyphs.Dimensions(sequence, size, spacing, layout)
	end
	local startX = alignment == "center" and x - width * 0.5 or alignment == "right" and x - width or x
	local entries, cursorX, cursorY = {}, startX, y
	for _, glyph in ipairs(sequence or {}) do
		local glyphWidth = size * (glyph.widthFactor or 1)
		entries[#entries + 1] = { glyph = glyph, x1 = cursorX, y1 = cursorY, x2 = cursorX + glyphWidth, y2 = cursorY + size }
		if layout == "Vertical" then cursorY = cursorY + size + spacing
		else cursorX = cursorX + glyphWidth * (layout == "Stacked" and 0.68 or 1) + spacing end
	end
	return entries, width, height, size
end

local function outline(x1, y1, x2, y2, color)
	gl.Color(color[1], color[2], color[3], color[4])
	gl.Rect(x1, y1, x2, y1 + 1); gl.Rect(x1, y2 - 1, x2, y2)
	gl.Rect(x1, y1, x1 + 1, y2); gl.Rect(x2 - 1, y1, x2, y2)
end

local function glyphColor(glyph, options)
	local tint = options.tint or { 1, 1, 1 }
	if options.colorMode == "Monochrome" then return { 1, 1, 1, options.opacity or 1 } end
	if options.colorMode == "Color-friendly" and glyph.color then return { glyph.color[1], glyph.color[2], glyph.color[3], options.opacity or 1 } end
	return { tint[1] or 1, tint[2] or 1, tint[3] or 1, options.opacity or 1 }
end

function Glyphs.DrawSequence(sequence, x, y, options)
	options = options or {}
	if not gl then return 0, 0, 0 end
	local entries, width, height = Glyphs.Layout(sequence, x, y, options.size, options.spacing,
		options.layout, options.alignment, options.maxWidth)
	local fallbackCount = 0
	local textureResult = gl.Texture(Glyphs.texture)
	local textureAvailable = textureResult ~= false
	for _, entry in ipairs(entries) do
		local glyph = entry.glyph
		if (options.backgroundOpacity or 0) > 0 then
			local bg = options.background or { 0.02, 0.05, 0.07 }
			gl.Color(bg[1], bg[2], bg[3], options.backgroundOpacity); gl.Rect(entry.x1, entry.y1, entry.x2, entry.y2)
		end
		if (options.borderOpacity or 0) > 0 then
			local border = options.border or options.tint or { 1, 1, 1 }
			outline(entry.x1, entry.y1, entry.x2, entry.y2, { border[1], border[2], border[3], options.borderOpacity })
		end
		if glyph.fallback or not textureAvailable then
			fallbackCount = fallbackCount + 1
			local color = glyphColor(glyph, options); gl.Color(color[1], color[2], color[3], color[4])
			local text = tostring(glyph.text or glyph.id or "?"); if #text > 10 then text = string.sub(text, 1, 9) .. "." end
			gl.Text(text, (entry.x1 + entry.x2) * 0.5, entry.y1 + (entry.y2 - entry.y1) * 0.32,
				math.max(8, math.min(12, (entry.y2 - entry.y1) * 0.38)), "oc")
		else
			local color = glyphColor(glyph, options); gl.Color(color[1], color[2], color[3], color[4])
			local availableWidth, availableHeight = entry.x2 - entry.x1, entry.y2 - entry.y1
			local aspect = tonumber(glyph.textureAspect) or 1
			local drawWidth, drawHeight = availableWidth, availableHeight
			if availableWidth / math.max(0.001, availableHeight) > aspect then drawWidth = availableHeight * aspect
			else drawHeight = availableWidth / math.max(0.001, aspect) end
			local centerX, centerY = (entry.x1 + entry.x2) * 0.5, (entry.y1 + entry.y2) * 0.5
			gl.TexRect(centerX - drawWidth * 0.5, centerY - drawHeight * 0.5,
				centerX + drawWidth * 0.5, centerY + drawHeight * 0.5, glyph.u1, glyph.v2, glyph.u2, glyph.v1)
		end
	end
	gl.Texture(false); gl.Color(1, 1, 1, 1)
	return width, height, fallbackCount
end

return Glyphs
