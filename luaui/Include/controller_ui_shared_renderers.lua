--------------------------------------------------------------------------------
-- Shared production/preview renderers for controller UI components.
-- Owners collect live data; this module owns measured layout and drawing.
--------------------------------------------------------------------------------

local Renderers = {}
local max, min, floor, ceil, abs = math.max, math.min, math.floor, math.ceil, math.abs
local pi, sin, cos = math.pi, math.sin, math.cos

local function clamp(value, low, high)
	return max(low, min(high, tonumber(value) or low))
end

local function rgba(value, alpha)
	value = value or { 1, 1, 1, 1 }
	return { value[1] or 1, value[2] or 1, value[3] or 1, alpha == nil and (value[4] or 1) or alpha }
end

local function color(value, alpha)
	local c = rgba(value, alpha)
	gl.Color(c[1], c[2], c[3], c[4])
end

local function outline(x1, y1, x2, y2, value, thickness)
	color(value); thickness = max(1, floor((tonumber(thickness) or 1) + 0.5))
	for line = 0, thickness - 1 do
		gl.Rect(x1 + line, y1 + line, x2 - line, y1 + line + 1)
		gl.Rect(x1 + line, y2 - line - 1, x2 - line, y2 - line)
		gl.Rect(x1 + line, y1 + line, x1 + line + 1, y2 - line)
		gl.Rect(x2 - line - 1, y1 + line, x2 - line, y2 - line)
	end
end

local function textWidth(text, size)
	if gl.GetTextWidth then
		local ok, width = pcall(gl.GetTextWidth, tostring(text or ""))
		if ok and type(width) == "number" then return width * size end
	end
	return #tostring(text or "") * size * 0.56
end

local function truncate(text, size, width)
	text = tostring(text or "")
	if textWidth(text, size) <= width then return text end
	while #text > 1 and textWidth(text .. "...", size) > width do text = string.sub(text, 1, -2) end
	return text .. "..."
end

local function wrap(text, size, width, maximum)
	local lines, current = {}, ""
	for word in tostring(text or ""):gmatch("%S+") do
		local candidate = current == "" and word or current .. " " .. word
		if current ~= "" and textWidth(candidate, size) > width then
			lines[#lines + 1], current = current, word
			if #lines >= maximum then break end
		else current = candidate end
	end
	if current ~= "" and #lines < maximum then lines[#lines + 1] = current end
	if #lines == 0 then lines[1] = "" end
	if #lines == maximum and textWidth(lines[#lines], size) > width then lines[#lines] = truncate(lines[#lines], size, width) end
	return lines
end

local function circle(cx, cy, radius, segments)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(cx, cy)
		for index = 0, segments do
			local angle = index * pi * 2 / segments
			gl.Vertex(cx + radius * cos(angle), cy + radius * sin(angle))
		end
	end)
end

local function ring(cx, cy, radius, value, thickness, segments)
	color(value); gl.LineWidth(thickness or 1)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for index = 0, (segments or 40) do
			local angle = index * pi * 2 / (segments or 40)
			gl.Vertex(cx + radius * cos(angle), cy + radius * sin(angle))
		end
	end)
end

local function presentation(component)
	local name = component.presentation or "Glyph + Action Text"
	local chip, action, compact = true, true, component.compact == true
	if name == "Button Chip Only" then action = false
	elseif name == "Action Text Only" or name == "Background Only" then chip = false
	elseif name == "Minimal Glyph" then action, compact = false, true
	elseif name == "Compact" then compact = true
	elseif name == "Full Descriptive" then compact = false end
	return chip and component.showChip ~= false, action and component.showActionText ~= false, compact
end

-- Pure timing helper used by the live renderer and deterministic tests.
function Renderers.CalculateTextMotion(contentWidth, viewportWidth, now, component)
	local travel = max(0, (tonumber(contentWidth) or 0) - (tonumber(viewportWidth) or 0))
	local mode = tostring(component.overflow or "Clip")
	if travel <= 0 or (mode ~= "Marquee" and mode ~= "Ping Pong") then
		return { active = false, offset = 0, travel = travel, mode = mode }
	end
	local speed = max(1, tonumber(component.marqueeSpeed) or 28)
	local delay = max(0, tonumber(component.marqueeDelay) or 0.8)
	local time = max(0, tonumber(now) or 0)
	if mode == "Marquee" then
		local gap = max(16, tonumber(component.marqueeGap) or 36)
		local moving = max(0, time - delay)
		return { active = true, offset = (moving * speed) % (travel + gap), travel = travel, gap = gap, mode = mode }
	end
	local run = travel / speed
	local cycle = delay + run + delay + run
	local phase = cycle > 0 and (time % cycle) or 0
	local offset
	if phase < delay then offset = 0
	elseif phase < delay + run then offset = (phase - delay) * speed
	elseif phase < delay + run + delay then offset = travel
	else offset = travel - (phase - delay - run - delay) * speed end
	return { active = true, offset = clamp(offset, 0, travel), travel = travel, mode = mode }
end

local function effectColor(component, prefix, fallback, opacity)
	return {
		tonumber(component[prefix .. "R"]) or fallback[1],
		tonumber(component[prefix .. "G"]) or fallback[2],
		tonumber(component[prefix .. "B"]) or fallback[3],
		(tonumber(component[prefix .. "Opacity"]) or fallback[4] or 1) * opacity,
	}
end

local function drawTextLayers(text, x, y, size, options, component, theme, opacity, counters)
	if component.textGlowEnabled then
		local glow = effectColor(component, "textGlow", { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92, 0.34 }, opacity)
		local radius = clamp(component.textGlowSize or 2, 1, 6)
		local intensity = clamp(component.textGlowIntensity or 1, 0.1, 3)
		glow[4] = min(1, glow[4] * intensity * 0.25)
		for _, offset in ipairs({ { -radius, 0 }, { radius, 0 }, { 0, -radius }, { 0, radius } }) do
			color(glow); gl.Text(text, x + offset[1], y + offset[2], size, options); counters.textGlow = counters.textGlow + 1
		end
	end
	if component.textShadowEnabled then
		local shadow = effectColor(component, "textShadow", { 0, 0, 0, 0.78 }, opacity)
		local dx, dy = tonumber(component.textShadowOffsetX) or 2, tonumber(component.textShadowOffsetY) or -2
		local spread = max(0, min(2, floor((tonumber(component.textShadowSpread) or 1) + 0.5)))
		for sx = -spread, spread do
			color(shadow); gl.Text(text, x + dx + sx * 0.5, y + dy, size, options); counters.textShadow = counters.textShadow + 1
		end
	end
	color(options.color)
	gl.Text(text, x, y, size, options.flags or "o")
end

local function glyphOptions(component, theme, opacity, size, spacing, layout, maxWidth, tint)
	return {
		size = size, spacing = spacing, layout = layout, alignment = "left", maxWidth = maxWidth,
		colorMode = component.glyphColorMode or "Color-friendly", opacity = (component.glyphOpacity or 1) * opacity,
		tint = tint or { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92 },
		backgroundOpacity = component.glyphBackgroundEnabled and (component.glyphBackgroundOpacity or 0.18) * opacity or 0,
		borderOpacity = component.glyphBorderEnabled and (component.glyphBorderOpacity or 0.45) * opacity or 0,
		background = { theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04 },
		border = { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92 },
	}
end

local function drawGlyphLayers(glyphs, sequence, x, y, options, component, theme, opacity, counters)
	if component.glyphGlowEnabled then
		local glowColor = effectColor(component, "glyphGlow", { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92, 0.28 }, opacity)
		local radius = clamp(component.glyphGlowSize or 2, 1, 6)
		local intensity = clamp(component.glyphGlowIntensity or 1, 0.1, 3)
		for _, offset in ipairs({ { -radius, 0 }, { radius, 0 }, { 0, -radius }, { 0, radius } }) do
			local glow = glyphOptions(component, theme, min(1, glowColor[4] * intensity * 0.28), options.size, options.spacing, options.layout, options.maxWidth,
				{ glowColor[1], glowColor[2], glowColor[3] })
			glow.colorMode, glow.backgroundOpacity, glow.borderOpacity = "Theme Accent", 0, 0
			glyphs.DrawSequence(sequence, x + offset[1], y + offset[2], glow); counters.glyphGlow = counters.glyphGlow + 1
		end
	end
	if component.glyphShadowEnabled then
		local shadow = effectColor(component, "glyphShadow", { 0, 0, 0, 0.72 }, opacity)
		local dx, dy = tonumber(component.glyphShadowOffsetX) or 2, tonumber(component.glyphShadowOffsetY) or -2
		local spread = max(0, min(2, floor((tonumber(component.glyphShadowSpread) or 1) + 0.5)))
		for sx = -spread, spread do
			local shadowOptions = glyphOptions(component, theme, shadow[4], options.size, options.spacing, options.layout, options.maxWidth,
				{ shadow[1], shadow[2], shadow[3] })
			shadowOptions.colorMode, shadowOptions.backgroundOpacity, shadowOptions.borderOpacity = "Theme Accent", 0, 0
			glyphs.DrawSequence(sequence, x + dx + sx * 0.5, y + dy, shadowOptions); counters.glyphShadow = counters.glyphShadow + 1
		end
	end
	glyphs.DrawSequence(sequence, x, y, options); counters.glyph = counters.glyph + 1
end

function Renderers.DrawHints(args)
	args = args or {}
	local component, hints, theme = args.settings or {}, args.model or {}, args.theme or {}
	if component.enabled == false or #hints == 0 then return { hits = {}, effects = {} } end
	local scale, fontScale = args.scale or 1, args.fontScale or 1
	local fontSize, opacity = 14 * fontScale, args.opacity or 1
	local showChip, showAction, compact = presentation(component)
	local count = #hints
	if not component.expanded and component.priorityHiding ~= false then count = min(count, floor(component.maxItems or 14)) end
	local glyphSize = max(18, 20 * scale * (component.iconScale or 1))
	local sequences, glyphHeight = {}, 0
	if args.glyphs and showChip then
		for index = 1, count do
			local hint = hints[index]
			sequences[index] = args.glyphs.BuildSequence(hint.inputs, {
				hold = hint.hold, showHold = hint.hold and component.showHoldIndicator ~= false,
				holdStyle = component.holdStyle or "Bold HOLD",
			})
			local _, height = args.glyphs.Dimensions(sequences[index], glyphSize, (component.glyphSpacing or 4) * scale, component.chordLayout)
			glyphHeight = max(glyphHeight, height)
		end
	end
	local rowHeight = max(24 * scale, fontSize + (component.rowSpacing or 0) * scale, glyphHeight + 6 * scale)
	if component.overflow == "Wrap" then rowHeight = rowHeight + fontSize * 0.72 * (max(2, component.wrapLines or 2) - 1) end
	local viewportW, viewportH = args.viewportWidth or 1920, args.viewportHeight or 1080
	local columns = floor(component.columns or 0); if columns <= 0 then columns = viewportW < 1100 and 1 or 2 end
	columns = max(1, min(columns, count)); local rows = ceil(count / columns)
	local padding = (component.padding or 8) * scale
	local panelWidth = min((component.maxWidth or 0.52) * viewportW, max(300 * scale, columns * 285 * scale))
	local moreHeight = count < #hints and 20 * scale or 0
	local contextHeight = component.showContextHeader and 22 * scale or 0
	local panelHeight = padding * 2 + rows * rowHeight + moreHeight + contextHeight
	local target = args.bounds
	local x1, y1
	if target then
		local fit = min(1, (target.x2 - target.x1) / panelWidth, (target.y2 - target.y1) / panelHeight)
		scale, fontScale, glyphSize, fontSize, rowHeight, padding = scale * fit, fontScale * fit, glyphSize * fit, fontSize * fit, rowHeight * fit, padding * fit
		panelWidth, panelHeight, moreHeight, contextHeight = panelWidth * fit, panelHeight * fit, moreHeight * fit, contextHeight * fit
		x1, y1 = (target.x1 + target.x2 - panelWidth) * 0.5, (target.y1 + target.y2 - panelHeight) * 0.5
	else
		x1 = clamp((component.x or 0.04) * viewportW, args.margin or 0, viewportW - panelWidth - (args.margin or 0))
		y1 = clamp((component.y or 0.08) * viewportH, args.margin or 0, viewportH - panelHeight - (args.margin or 0))
	end
	local accent = { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92, (component.borderOpacity or 0) * opacity }
	local foreground = { theme.foregroundR or 0.94, theme.foregroundG or 0.98, theme.foregroundB or 1, (component.textOpacity or 1) * opacity }
	if (component.backgroundOpacity or 0) > 0 then
		color({ theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04, component.backgroundOpacity * opacity })
		gl.Rect(x1, y1, x1 + panelWidth, y1 + panelHeight)
	end
	if accent[4] > 0 and (component.borderThickness or 0) > 0 then outline(x1, y1, x1 + panelWidth, y1 + panelHeight, accent, component.borderThickness) end
	if component.showContextHeader then
		color({ accent[1], accent[2], accent[3], 0.18 * opacity }); gl.Rect(x1, y1 + panelHeight - contextHeight, x1 + panelWidth, y1 + panelHeight)
		color(foreground); gl.Text(args.contextLabel or "Gameplay", x1 + padding, y1 + panelHeight - contextHeight + 6 * scale, 11 * fontScale, "o")
	end
	local columnGap = (component.columnSpacing or 12) * scale
	local columnWidth = (panelWidth - padding * 2 - (columns - 1) * columnGap) / columns
	local hits, motions = {}, {}
	local effects = { textShadow = 0, glyphShadow = 0, textGlow = 0, glyphGlow = 0, glyph = 0, textBackground = 0, clipped = 0 }
	for index = 1, count do
		local hint = hints[index]; local col = floor((index - 1) / rows); local row = (index - 1) % rows
		local rx = x1 + padding + col * (columnWidth + columnGap)
		local ry = y1 + panelHeight - padding - moreHeight - contextHeight - (row + 1) * rowHeight
		local sequence = sequences[index]
		local sequenceWidth = sequence and args.glyphs.Dimensions(sequence, glyphSize, (component.glyphSpacing or 4) * scale, component.chordLayout) or 0
		local chipText = args.formatInputs and args.formatInputs(hint) or tostring(hint.input or "?")
		local chipWidth = showChip and min(columnWidth * (showAction and 0.48 or 1), max(38 * scale, sequenceWidth + 8 * scale, (#chipText * 7 + 14) * scale)) or 0
		if component.showRowBackground then color({ theme.mutedR or 0.3, theme.mutedG or 0.5, theme.mutedB or 0.6, 0.13 * opacity }); gl.Rect(rx, ry + 1, rx + columnWidth, ry + rowHeight - 1) end
		if component.showCategoryHeaders and (index == 1 or hints[index - 1].group ~= hint.group) then
			color({ accent[1], accent[2], accent[3], 0.92 * opacity }); gl.Text(string.upper(tostring(hint.group or "SYSTEM")), rx, ry + rowHeight - 8 * scale, 7 * fontScale, "o")
		end
		if showChip and sequence then
			local glyphY = ry + (rowHeight - glyphHeight) * 0.5
			local options = glyphOptions(component, theme, opacity, glyphSize, (component.glyphSpacing or 4) * scale,
				component.chordLayout, chipWidth - 8 * scale)
			drawGlyphLayers(args.glyphs, sequence, rx + 4 * scale, glyphY, options, component, theme, opacity, effects)
			if hint.hold and component.showHoldIndicator ~= false and component.holdStyle == "Hold Glyph" then
				outline(rx, ry + 1 * scale, rx + chipWidth, ry + rowHeight - 1 * scale,
					{ component.holdColorR or 1, component.holdColorG or 0.72, component.holdColorB or 0.22, component.holdGlyphOpacity or 0.9 },
					component.holdGlyphThickness or 2)
			end
		elseif showChip then
			color(foreground); gl.Text(chipText, rx + chipWidth * 0.5, ry + (rowHeight - fontSize) * 0.5, fontSize * 0.82, "oc")
		end
		if showAction then
			local labelText = tostring(compact and (hint.compactLabel or hint.label) or hint.label or "")
			local labelX = rx + chipWidth + (showChip and (component.iconTextSpacing or 8) * scale or 0)
			if hint.hold and component.showHoldIndicator ~= false and component.holdStyle ~= "Hold Glyph" then
				local holdSize = fontSize * (component.holdLabelScale or 1.08)
				local holdColor = { component.holdColorR or 1, component.holdColorG or 0.72, component.holdColorB or 0.22, (component.holdOpacity or 1) * opacity }
				drawTextLayers("HOLD", labelX, ry + (rowHeight - holdSize) * 0.5, holdSize,
					{ color = holdColor, flags = "o" }, component, theme, opacity, effects)
				-- A second pass creates a readable bold treatment without font dependencies.
				color(holdColor); gl.Text("HOLD", labelX + 0.75 * scale, ry + (rowHeight - holdSize) * 0.5, holdSize, "o")
				labelX = labelX + textWidth("HOLD", holdSize) + (component.holdLabelSpacing or 7) * scale
			end
			local available = max(24, rx + columnWidth - labelX)
			local contentWidth = textWidth(labelText, fontSize)
			local mode = component.overflow or "Clip"
			local lines = mode == "Wrap" and wrap(labelText, fontSize, available, component.wrapLines or 2) or { labelText }
			local backgroundWidth = mode == "Wrap" and min(available, max(1, contentWidth)) or min(available, contentWidth)
			if component.textBackgroundEnabled then
				local hp, vp = (component.textBackgroundPaddingX or 5) * scale, (component.textBackgroundPaddingY or 2) * scale
				local bg = effectColor(component, "textBackground", { theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04, 0.62 }, opacity)
				local bx1, by1 = labelX - hp, ry + (rowHeight - fontSize) * 0.5 - vp
				local bx2, by2 = labelX + backgroundWidth + hp, ry + (rowHeight + fontSize) * 0.5 + vp
				color(bg); gl.Rect(bx1, by1, bx2, by2); effects.textBackground = effects.textBackground + 1
				if (component.textBackgroundBorderOpacity or 0) > 0 then
					outline(bx1, by1, bx2, by2, { accent[1], accent[2], accent[3], component.textBackgroundBorderOpacity * opacity }, component.textBackgroundBorderThickness or 1)
				end
			end
			if mode == "Wrap" then
				for lineIndex, line in ipairs(lines) do
					drawTextLayers(line, labelX, ry + rowHeight - fontSize * 1.12 - (lineIndex - 1) * fontSize * 0.86,
						fontSize * (lineIndex == 1 and 1 or 0.86), { color = foreground, flags = "o" }, component, theme, opacity, effects)
				end
			else
				local motion = Renderers.CalculateTextMotion(contentWidth, available, args.time or 0, component)
				motions[index] = motion
				if contentWidth > available and gl.Scissor then gl.Scissor(labelX, ry, available, rowHeight); effects.clipped = effects.clipped + 1 end
				local tx = labelX - motion.offset
				drawTextLayers(labelText, tx, ry + (rowHeight - fontSize) * 0.5, fontSize,
					{ color = foreground, flags = "o" }, component, theme, opacity, effects)
				if motion.active and motion.mode == "Marquee" then
					drawTextLayers(labelText, tx + contentWidth + motion.gap, ry + (rowHeight - fontSize) * 0.5, fontSize,
						{ color = foreground, flags = "o" }, component, theme, opacity, effects)
				end
				if contentWidth > available and gl.Scissor then gl.Scissor(false) end
			end
		end
		if component.showSeparators and index < count then color({ theme.mutedR or 0.36, theme.mutedG or 0.52, theme.mutedB or 0.6, 0.32 * opacity }); gl.Rect(rx, ry, rx + columnWidth, ry + 1) end
		hits[#hits + 1] = { x1 = rx, y1 = ry, x2 = rx + columnWidth, y2 = ry + rowHeight, hint = hint }
	end
	local moreHit
	if count < #hints then
		moreHit = { x1 = x1, y1 = y1, x2 = x1 + panelWidth, y2 = y1 + moreHeight }
		color(accent); gl.Text("+" .. tostring(#hints - count) .. " more", x1 + panelWidth * 0.5, y1 + 5 * scale, 11 * fontScale, "oc")
	end
	gl.Color(1, 1, 1, 1)
	return { x1 = x1, y1 = y1, x2 = x1 + panelWidth, y2 = y1 + panelHeight, hits = hits, moreHit = moreHit,
		effects = effects, motions = motions, parameters = { scale = scale, fontScale = fontScale, glyphSize = glyphSize,
			rowHeight = rowHeight, columnGap = columnGap, padding = padding, opacity = opacity } }
end

--------------------------------------------------------------------------------
-- Semantic radial typography. Settings remain flat for backwards-compatible
-- persistence, while the resolved renderer contract is role-oriented.
--------------------------------------------------------------------------------

local RadialStyle = { DEFAULTS = {}, ROLES = {}, COLOR_PRESETS = {} }
Renderers.RadialStyle = RadialStyle

local roleDefaults = {
	categoryLabel = { size = 18, colorR = 0.34, colorG = 0.82, colorB = 0.92, opacity = 0.95,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.78,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0, letterSpacing = 0.5 },
	centerTitle = { size = 18, colorR = 0.82, colorG = 0.94, colorB = 1, opacity = 1,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.82,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0, emphasis = 1,
		maxWidth = 1.55, wrapMode = "Truncate", spacingAfter = 7 },
	centerDescription = { size = 10, colorR = 0.78, colorG = 0.84, colorB = 0.88, opacity = 0.96,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.72,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0, lineSpacing = 3,
		maxWidth = 1.55, wrapEnabled = true, maxLines = 2, spacingBefore = 0, spacingAfter = 5 },
	metalCost = { size = 11, colorR = 0.58, colorG = 0.82, colorB = 1, opacity = 1,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.78,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0, iconSize = 10, iconSpacing = 3 },
	energyCost = { size = 11, colorR = 1, colorG = 0.86, colorB = 0.12, opacity = 1,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.78,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0, iconSize = 10, iconSpacing = 3 },
	healthStat = { size = 11, colorR = 0.34, colorG = 1, colorB = 0.48, opacity = 1,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.78,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0, iconSize = 10, iconSpacing = 3 },
	availabilityText = { size = 9, colorR = 1, colorG = 0.62, colorB = 0.24, opacity = 0.92,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.78,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0, lineSpacing = 2 },
	metadata = { size = 10, colorR = 0.78, colorG = 0.86, colorB = 0.92, opacity = 0.82,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.68,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0, lineSpacing = 3 },
	footer = { size = 13, colorR = 0.72, colorG = 0.78, colorB = 0.82, opacity = 0.80,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.68,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0 },
	pageIndicator = { size = 10, colorR = 0.46, colorG = 0.88, colorB = 1, opacity = 0.88,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.68,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0 },
	slotNumber = { size = 12, colorR = 1, colorG = 0.84, colorB = 0, opacity = 1,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.82,
		outlineEnabled = true, alignment = "Left", offsetX = 0, offsetY = 0 },
	unavailableText = { size = 9, colorR = 0.72, colorG = 0.40, colorB = 0.40, opacity = 0.78,
		shadowEnabled = true, shadowColorR = 0, shadowColorG = 0, shadowColorB = 0, shadowOpacity = 0.72,
		outlineEnabled = true, alignment = "Center", offsetX = 0, offsetY = 0 },
}

local function upperFirst(value) return string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2) end
for _, roleName in ipairs({ "categoryLabel", "centerTitle", "centerDescription", "metalCost", "energyCost", "healthStat",
	"availabilityText", "metadata", "footer", "pageIndicator", "slotNumber", "unavailableText" }) do
	RadialStyle.ROLES[#RadialStyle.ROLES + 1] = roleName
	for property, value in pairs(roleDefaults[roleName]) do
		RadialStyle.DEFAULTS[roleName .. upperFirst(property)] = value
	end
end
for property, value in pairs({ radiusScale = 1, innerRadiusScale = 1, segmentSpacing = 1, segmentAnglePadding = 0,
	centerPanelScale = 1, safeScreenMargin = 0, resourceSpacing = 12, resourceRowSpacing = 6,
	resourceLayout = "Row", resourceAlignment = "Center",
	selectedBackgroundR = 0.27, selectedBackgroundG = 0.70, selectedBackgroundB = 0.84, selectedBackgroundOpacity = 0.85,
	selectedBorderR = 0.34, selectedBorderG = 0.82, selectedBorderB = 0.92, selectedBorderOpacity = 1,
	selectedLabelR = 1, selectedLabelG = 1, selectedLabelB = 1, selectedLabelOpacity = 1,
	selectedTitleR = 1, selectedTitleG = 1, selectedTitleB = 1, selectedTitleOpacity = 1,
	selectedIconOpacity = 1, unavailableIconOpacity = 0.75,
}) do RadialStyle.DEFAULTS[property] = value end

RadialStyle.COLOR_PRESETS = {
	{ "White", 1, 1, 1, 1 }, { "Light Gray", 0.82, 0.84, 0.86, 1 }, { "Medium Gray", 0.52, 0.55, 0.58, 1 },
	{ "Dark Gray", 0.22, 0.24, 0.27, 1 }, { "Black", 0, 0, 0, 1 }, { "Red", 0.94, 0.18, 0.18, 1 },
	{ "Orange", 1, 0.48, 0.08, 1 }, { "Yellow", 1, 0.86, 0.12, 1 }, { "Green", 0.20, 0.86, 0.35, 1 },
	{ "Cyan", 0.10, 0.88, 0.92, 1 }, { "Blue", 0.18, 0.48, 1, 1 }, { "Purple", 0.62, 0.30, 0.92, 1 },
	{ "Pink", 1, 0.36, 0.68, 1 }, { "BAR Accent", 0.34, 0.82, 0.92, 1 }, { "Metal", 0.58, 0.82, 1, 1 },
	{ "Energy", 1, 0.86, 0.12, 1 }, { "Warning", 1, 0.30, 0.18, 1 }, { "Success", 0.28, 0.88, 0.48, 1 },
	{ "Disabled", 0.48, 0.46, 0.46, 0.78 }, { "Selected", 1, 1, 1, 1 },
}

function RadialStyle.HSVToRGB(h, s, v)
	h, s, v = ((tonumber(h) or 0) % 360) / 60, clamp(s, 0, 1), clamp(v, 0, 1)
	local sector, fraction = floor(h), h - floor(h)
	local p, q, t = v * (1 - s), v * (1 - s * fraction), v * (1 - s * (1 - fraction))
	if sector == 0 then return v, t, p elseif sector == 1 then return q, v, p elseif sector == 2 then return p, v, t
	elseif sector == 3 then return p, q, v elseif sector == 4 then return t, p, v end
	return v, p, q
end

function RadialStyle.RGBToHSV(r, g, b)
	r, g, b = clamp(r, 0, 1), clamp(g, 0, 1), clamp(b, 0, 1)
	local high, low = max(r, g, b), min(r, g, b); local delta = high - low; local h = 0
	if delta > 0 then
		if high == r then h = 60 * (((g - b) / delta) % 6)
		elseif high == g then h = 60 * (((b - r) / delta) + 2)
		else h = 60 * (((r - g) / delta) + 4) end
	end
	return h, high == 0 and 0 or delta / high, high
end

function RadialStyle.ColorHex(r, g, b, a)
	local value = string.format("#%02X%02X%02X", floor(clamp(r, 0, 1) * 255 + 0.5), floor(clamp(g, 0, 1) * 255 + 0.5), floor(clamp(b, 0, 1) * 255 + 0.5))
	if a ~= nil and abs(clamp(a, 0, 1) - 1) > 0.0001 then value = value .. string.format("%02X", floor(clamp(a, 0, 1) * 255 + 0.5)) end
	return value
end

function RadialStyle.ParseHexColor(value)
	value = tostring(value or ""):gsub("#", "")
	if #value ~= 6 and #value ~= 8 then return nil end
	local number = tonumber(value, 16); if not number then return nil end
	if #value == 6 then return floor(number / 65536) % 256 / 255, floor(number / 256) % 256 / 255, number % 256 / 255, 1 end
	return floor(number / 16777216) % 256 / 255, floor(number / 65536) % 256 / 255,
		floor(number / 256) % 256 / 255, number % 256 / 255
end

function RadialStyle.Resolve(globalSettings, componentSettings)
	globalSettings, componentSettings = globalSettings or {}, componentSettings or {}
	local flat = {}; for key, value in pairs(RadialStyle.DEFAULTS) do flat[key] = value end
	for key in pairs(RadialStyle.DEFAULTS) do if globalSettings[key] ~= nil then flat[key] = globalSettings[key] end end
	local overridden = componentSettings.typographyOverride == true
	if overridden then for key in pairs(RadialStyle.DEFAULTS) do if componentSettings[key] ~= nil then flat[key] = componentSettings[key] end end end
	local resolved = { __resolvedRadialStyle = true, overridden = overridden, flat = flat }
	for _, roleName in ipairs(RadialStyle.ROLES) do
		local role = {}
		for property in pairs(roleDefaults[roleName]) do role[property] = flat[roleName .. upperFirst(property)] end
		resolved[roleName] = role
	end
	for key in pairs(RadialStyle.DEFAULTS) do if not resolved[key] then resolved[key] = flat[key] end end
	return resolved
end

local function radialSettings(args)
	local settings, model = args.settings or {}, args.model or {}
	local typography = settings.typography
	if not (type(typography) == "table" and typography.__resolvedRadialStyle) then typography = RadialStyle.Resolve(settings, nil) end
	return {
		iconScale = tonumber(settings.iconScale) or tonumber(model.iconScale) or 1,
		fontScale = tonumber(settings.fontScale) or tonumber(model.fontScale) or 1,
		centerTextScale = tonumber(settings.centerTextScale) or 1,
		selectedScale = tonumber(settings.selectedScale) or 1.06,
		selectedBorderThickness = tonumber(settings.selectedBorderThickness) or 3,
		itemSpacing = (tonumber(settings.itemSpacing) or tonumber(model.itemSpacing) or 1) * (tonumber(typography.segmentSpacing) or 1),
		legacyThemeOpacity = tonumber(settings.legacyThemeOpacity) or 1,
		pageStatusVisible = settings.pageStatusVisible ~= false,
		typography = typography,
	}
end

local function roleFlags(alignment, outlined)
	local flags = outlined and "o" or ""
	if alignment == "Right" then return "r" .. flags elseif alignment == "Center" then return "c" .. flags end
	return flags
end

local function roleColor(role, opacity, override)
	if override then return { override[1], override[2], override[3], (override[4] or 1) * opacity } end
	return { role.colorR or 1, role.colorG or 1, role.colorB or 1, (role.opacity or 1) * opacity }
end

local function drawRoleText(roleName, value, role, x, y, scale, opacity, measured, overrideColor)
	value = tostring(value or ""); local size = max(1, (tonumber(role.size) or 10) * scale * (tonumber(role.emphasis) or 1))
	x, y = x + (tonumber(role.offsetX) or 0) * scale, y + (tonumber(role.offsetY) or 0) * scale
	local flags = roleFlags(role.alignment, role.outlineEnabled ~= false)
	if role.shadowEnabled ~= false and (role.shadowOpacity or 0) > 0 then
		color({ role.shadowColorR or 0, role.shadowColorG or 0, role.shadowColorB or 0, (role.shadowOpacity or 0.75) * opacity })
		gl.Text(value, x + max(1, scale), y - max(1, scale), size, flags)
	end
	local finalColor = roleColor(role, opacity, overrideColor); color(finalColor)
	local spacing = (tonumber(role.letterSpacing) or 0) * scale
	if spacing ~= 0 and #value > 1 then
		local total = textWidth(value, size) + (#value - 1) * spacing; local start = x
		if role.alignment == "Center" then start = x - total * 0.5 elseif role.alignment == "Right" then start = x - total end
		for character in value:gmatch(".") do gl.Text(character, start, y, size, role.outlineEnabled ~= false and "o" or ""); start = start + textWidth(character, size) + spacing end
	else gl.Text(value, x, y, size, flags) end
	measured[roleName] = measured[roleName] or {}; local result = measured[roleName]
	result.size, result.color, result.opacity, result.x, result.y, result.text = size, finalColor, finalColor[4], x, y, value
	result.width = textWidth(value, size) + max(0, #value - 1) * spacing
	return size
end

local function drawWrappedRole(roleName, value, role, x, y, scale, opacity, measured, width)
	local size = max(1, (tonumber(role.size) or 10) * scale); local maxLines = max(1, floor(tonumber(role.maxLines) or 2))
	local lines = role.wrapEnabled == false and { truncate(value, size, width) } or wrap(value, size, width, maxLines)
	local advance = size + (tonumber(role.lineSpacing) or 0) * scale
	for index, line in ipairs(lines) do drawRoleText(roleName, line, role, x, y - (index - 1) * advance, scale, opacity, measured) end
	local result = measured[roleName]; result.lines, result.lineCount, result.lineSpacing, result.maxWidth = lines, #lines, advance, width
	return #lines * advance
end

local function drawResources(model, typography, cx, y, scale, opacity, measured)
	if model.metalCost == nil and model.energyCost == nil and model.healthStat == nil then return 0 end
	local metal, energy = typography.metalCost, typography.energyCost
	local metalText, energyText = model.metalCost ~= nil and tostring(model.metalCost) or nil, model.energyCost ~= nil and tostring(model.energyCost) or nil
	local gap = (tonumber(typography.resourceSpacing) or 12) * scale; local layout = typography.resourceLayout or "Row"
	local metalWidth = metalText and ((metal.iconSize + metal.iconSpacing) * scale + textWidth(metalText, metal.size * scale)) or 0
	local energyWidth = energyText and ((energy.iconSize + energy.iconSpacing) * scale + textWidth(energyText, energy.size * scale)) or 0
	local total = metalWidth + energyWidth + ((metalText and energyText) and gap or 0); local left = cx - total * 0.5
	if typography.resourceAlignment == "Left" then left = left - gap * 1.5 elseif typography.resourceAlignment == "Right" then left = left + gap * 1.5 end
	local textures = {
		metalCost = "LuaUI/Images/controller/stat-icons/metal.png",
		energyCost = "LuaUI/Images/controller/stat-icons/energy.png",
		healthStat = "LuaUI/Images/controller/stat-icons/health.png",
	}
	local function resource(roleName, role, text, x, rowY)
		if not text then return end
		local iconSize = (tonumber(role.iconSize) or 10) * scale
		local roleX = x + iconSize + (tonumber(role.iconSpacing) or 3) * scale
		local tokenRole = {}; for key, value in pairs(role) do tokenRole[key] = value end; tokenRole.alignment = "Left"
		drawRoleText(roleName, text, tokenRole, roleX, rowY, scale, opacity, measured)
		local result = measured[roleName]; color(result.color)
		gl.Texture(textures[roleName]); gl.TexRect(x, rowY - 1 * scale, x + iconSize, rowY + iconSize - 1 * scale); gl.Texture(false)
		result.iconSize, result.iconSpacing, result.layout, result.alignment = iconSize, (tonumber(role.iconSpacing) or 3) * scale, layout, typography.resourceAlignment
	end
	if layout == "Column" then resource("metalCost", metal, metalText, cx - metalWidth * 0.5, y); resource("energyCost", energy, energyText, cx - energyWidth * 0.5, y - max(metal.size, energy.size) * scale - gap)
	else resource("metalCost", metal, metalText, left, y); resource("energyCost", energy, energyText, left + metalWidth + (metalText and energyText and gap or 0), y) end
	local firstRowHeight = layout == "Column" and max(metal.size, energy.size) * scale * 2 + gap or max(metal.size, energy.size) * scale
	if model.healthStat ~= nil then
		local health, text = typography.healthStat, tostring(model.healthStat)
		local iconSize = (tonumber(health.iconSize) or 10) * scale
		local width = iconSize + (tonumber(health.iconSpacing) or 3) * scale + textWidth(text, health.size * scale)
		resource("healthStat", health, text, cx - width * 0.5,
			y - firstRowHeight - (tonumber(typography.resourceRowSpacing) or 6) * scale)
		return firstRowHeight + max(health.size, health.iconSize) * scale + (tonumber(typography.resourceRowSpacing) or 6) * scale
	end
	return firstRowHeight
end

local function entryAngle(index, count, typography)
	local angle = ((index - 1) * pi * 2 / max(1, count)) - pi * 0.5
	local padding = (tonumber(typography.segmentAnglePadding) or 0) * pi / 180
	return angle + ((index % 2 == 0) and padding or -padding)
end

local function drawBuildRadial(args, cx, cy, radius, accent, values)
	local model, theme, entries, opacity = args.model or {}, args.theme or {}, args.model.entries or {}, args.opacity or 1
	local typography, roles = values.typography, {}; local n = max(1, #entries)
	local iconSize = min(500, max(56, radius * 0.27 * values.iconScale))
	local fill = model.fill or { theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04 }
	color({ fill[1], fill[2], fill[3], 0.58 * opacity * values.legacyThemeOpacity }); circle(cx, cy, radius * 1.3, 40)
	ring(cx, cy, radius, { accent[1], accent[2], accent[3], 0.3 * opacity }, 2, 36)
	for index, entry in ipairs(entries) do
		-- Hybrid native models may retain holes so familiar BAR cells do not
		-- collapse into different positions when the selected builder changes.
		local angle = entryAngle(entry.slot or index, tonumber(model.slotCount) or n, typography)
		local x, y = cx + radius * values.itemSpacing * cos(angle), cy - radius * values.itemSpacing * sin(angle)
		local selected = index == (model.selectedIndex or 1); local size = iconSize * (selected and values.selectedScale or 1)
		local selectedFill = { typography.selectedBackgroundR, typography.selectedBackgroundG, typography.selectedBackgroundB, typography.selectedBackgroundOpacity * opacity }
		if selected then color(selectedFill) elseif entry.disabled then color({ 0.32, 0.12, 0.12, 0.42 * opacity }) else color({ 0.12, 0.18, 0.23, 0.42 * opacity }) end
		gl.Rect(x - size * 0.5 - 2, y - size * 0.5 - 2, x + size * 0.5 + 2, y + size * 0.5 + 2)
		local border = selected and { typography.selectedBorderR, typography.selectedBorderG, typography.selectedBorderB, typography.selectedBorderOpacity * opacity }
			or entry.disabled and { 0.68, 0.22, 0.22, 0.55 * opacity } or { 0.8, 0.8, 0.8, 0.9 * opacity }
		outline(x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5, border, selected and values.selectedBorderThickness or 1)
		if entry.texture then
			gl.Texture(entry.texture)
			local iconOpacity = entry.disabled and typography.unavailableIconOpacity or selected and typography.selectedIconOpacity or 1
			if entry.progress and entry.progress >= 0 and entry.progress <= 1 and gl.Scissor then
				color({ 0.2, 0.2, 0.2, 0.5 * opacity }); gl.TexRect(x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5)
				if entry.progress > 0 then gl.Scissor(x - size * 0.5, y - size * 0.5, size, size * entry.progress); color({ 1, 1, 1, iconOpacity * opacity }); gl.TexRect(x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5); gl.Scissor(false) end
			else color({ 1, 1, 1, iconOpacity * opacity }); gl.TexRect(x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5) end
			gl.Texture(false)
		else
			local labelColor = selected and { typography.selectedLabelR, typography.selectedLabelG, typography.selectedLabelB, typography.selectedLabelOpacity } or nil
			drawRoleText(entry.disabled and "unavailableText" or "metadata", entry.label or "Build", entry.disabled and typography.unavailableText or typography.metadata,
				x, y - 6, values.fontScale, opacity, roles, labelColor)
		end
		drawRoleText("slotNumber", entry.indexLabel or index, typography.slotNumber, x - size * 0.5 + 6, y + size * 0.5 - 16, values.fontScale, opacity, roles)
		if entry.disabled and entry.unavailableText then drawRoleText("unavailableText", entry.unavailableText, typography.unavailableText, x, y - size * 0.5 + 4, values.fontScale, opacity, roles) end
		if (entry.badge or 0) > 0 then
			local badge = "x" .. tostring(entry.badge); local badgeW = max(28, #badge * 8 + 10); local bx2, by2 = x + size * 0.5 + 3, y + size * 0.5 + 3
			color({ 0.04, 0.08, 0.12, 0.88 * opacity }); gl.Rect(bx2 - badgeW, by2 - 20, bx2, by2); outline(bx2 - badgeW, by2 - 20, bx2, by2, { accent[1], accent[2], accent[3], 0.7 * opacity }, 1)
			drawRoleText("metadata", badge, typography.metadata, bx2 - badgeW * 0.5, by2 - 16, values.fontScale, opacity, roles)
		end
	end
	local panelRadius = max(radius * 0.39, min(radius * 0.56, radius - iconSize * 0.6)) * typography.innerRadiusScale * typography.centerPanelScale
	color({ 0.015, 0.04, 0.065, 0.88 * opacity }); circle(cx, cy, panelRadius, 40); ring(cx, cy, panelRadius, { accent[1], accent[2], accent[3], 0.78 * opacity }, 1.5, 40)
	local centerScale = values.fontScale * values.centerTextScale
	local selectedTitleColor = { typography.selectedTitleR, typography.selectedTitleG, typography.selectedTitleB, typography.selectedTitleOpacity }
	local titleText = model.title or "Build"; local titleWidth = panelRadius * typography.centerTitle.maxWidth
	if typography.centerTitle.wrapMode == "Wrap" then drawWrappedRole("centerTitle", titleText, typography.centerTitle, cx, cy + panelRadius * 0.60, centerScale, opacity, roles, titleWidth)
	else drawRoleText("centerTitle", truncate(titleText, typography.centerTitle.size * centerScale, titleWidth), typography.centerTitle, cx, cy + panelRadius * 0.60, centerScale, opacity, roles,
		model.selectedTitle == true and selectedTitleColor or nil) end
	local details = model.details or {}; local description = model.description or details[1] or ""
	local descriptionY = cy + panelRadius * 0.28 - (typography.centerTitle.spacingAfter + typography.centerDescription.spacingBefore) * centerScale
	if description ~= "" then drawWrappedRole("centerDescription", description, typography.centerDescription, cx, descriptionY,
		centerScale, opacity, roles, panelRadius * typography.centerDescription.maxWidth) end
	local resourceY = descriptionY - ((roles.centerDescription and roles.centerDescription.lineCount or 0) * (roles.centerDescription and roles.centerDescription.lineSpacing or 0)) - typography.centerDescription.spacingAfter * centerScale
	local resourcesHeight = drawResources(model, typography, cx, resourceY, centerScale, opacity, roles)
	local availabilityY = resourceY - resourcesHeight - 4 * centerScale
	if model.availabilityText and model.availabilityText ~= "" then
		drawWrappedRole("availabilityText", model.availabilityText, typography.availabilityText, cx, availabilityY,
			centerScale, opacity, roles, panelRadius * 1.5)
	end
	local metadata = model.metadata or {}; if #metadata == 0 then for index = 2, #details do metadata[#metadata + 1] = details[index] end end
	for index = 1, min(4, #metadata) do drawRoleText("metadata", metadata[index], typography.metadata, cx,
		availabilityY - (model.availabilityText and 13 or 0) * centerScale - (index - 1) * (typography.metadata.size + typography.metadata.lineSpacing) * centerScale, centerScale, opacity, roles) end
	if values.pageStatusVisible then
		drawRoleText("categoryLabel", string.upper(model.categoryLabel or "BUILD"), typography.categoryLabel, cx, cy + radius * 0.65, values.fontScale, opacity, roles)
		if model.pageLabel then drawRoleText("pageIndicator", model.pageLabel, typography.pageIndicator, cx, cy - radius * 0.68, values.fontScale, opacity, roles) end
	end
	return { iconSize = iconSize, panelRadius = panelRadius, roles = roles }
end

local function drawTacticalRadial(args, cx, cy, radius, accent, values)
	local model, entries, opacity = args.model or {}, args.model.entries or {}, args.opacity or 1; local typography, roles = values.typography, {}
	local fill = model.fill or { 0.02, 0.03, 0.04, 0.46 }; local n = max(1, #entries)
	color({ fill[1], fill[2], fill[3], (fill[4] or 0.46) * opacity * values.legacyThemeOpacity }); circle(cx, cy, radius * 1.28, 42); ring(cx, cy, radius, { accent[1], accent[2], accent[3], 0.74 * opacity }, 2.5, 44)
	for _, chip in ipairs(model.categoryChips or {}) do
		local y = cy + (chip.direction == "up" and radius * 0.52 or chip.direction == "down" and -radius * 0.52 or 0); local selected, chipColor = chip.selected, chip.color or accent
		local width = max(120, #tostring(chip.label or "") * 11 + 24); color(selected and { chipColor[1] * 0.15, chipColor[2] * 0.15, chipColor[3] * 0.15, 0.88 * opacity } or { 0.04, 0.05, 0.06, 0.48 * opacity })
		gl.Rect(cx - width * 0.5, y - 17, cx + width * 0.5, y + 17); outline(cx - width * 0.5, y - 17, cx + width * 0.5, y + 17, { chipColor[1], chipColor[2], chipColor[3], (selected and 0.95 or 0.54) * opacity }, selected and 2 or 1)
		drawRoleText("categoryLabel", chip.label or "", typography.categoryLabel, cx, y - 6, values.fontScale * (selected and 1 or 0.78), opacity, roles,
			selected and { typography.selectedLabelR, typography.selectedLabelG, typography.selectedLabelB, typography.selectedLabelOpacity } or nil)
	end
	local itemW, itemH = min(260, max(130, radius * 0.54)), max(38, 54 * values.iconScale)
	for index, entry in ipairs(entries) do
		local angle = entryAngle(index, n, typography); local x, y = cx + radius * values.itemSpacing * cos(angle), cy - radius * values.itemSpacing * sin(angle)
		local selected = index == (model.selectedIndex or 1); local w, h = itemW * (selected and values.selectedScale or 1), itemH * (selected and values.selectedScale or 1)
		color(selected and { typography.selectedBackgroundR, typography.selectedBackgroundG, typography.selectedBackgroundB, typography.selectedBackgroundOpacity * opacity } or { fill[1] * 0.5, fill[2] * 0.5, fill[3] * 0.5, 0.85 * opacity })
		gl.Rect(x - w * 0.5, y - h * 0.5, x + w * 0.5, y + h * 0.5); outline(x - w * 0.5, y - h * 0.5, x + w * 0.5, y + h * 0.5,
			selected and { typography.selectedBorderR, typography.selectedBorderG, typography.selectedBorderB, typography.selectedBorderOpacity * opacity } or { accent[1], accent[2], accent[3], 0.64 * opacity }, selected and values.selectedBorderThickness or 1)
		drawRoleText(entry.disabled and "unavailableText" or "metadata", entry.label or "Command", entry.disabled and typography.unavailableText or typography.metadata, x, y - 6,
			values.fontScale * (selected and 1.18 or 1), opacity, roles, selected and { typography.selectedLabelR, typography.selectedLabelG, typography.selectedLabelB, typography.selectedLabelOpacity } or nil)
	end
	local panelRadius = radius * 0.42 * typography.innerRadiusScale * typography.centerPanelScale
	color({ fill[1] * 0.7, fill[2] * 0.7, fill[3] * 0.7, 0.88 * opacity }); circle(cx, cy, panelRadius, 30); ring(cx, cy, panelRadius, { accent[1] * 0.5, accent[2] * 0.5, accent[3] * 0.5, 0.64 * opacity }, 1.5, 30)
	local centerScale = values.fontScale * values.centerTextScale; local selected = entries[model.selectedIndex or 1]
	drawRoleText("categoryLabel", model.categoryLabel or model.title or "Tactical", typography.categoryLabel, cx, cy + 36, centerScale, opacity, roles)
	local titleText = selected and selected.label or model.title or "Tactical"; local titleWidth = panelRadius * typography.centerTitle.maxWidth
	if typography.centerTitle.wrapMode == "Wrap" then drawWrappedRole("centerTitle", titleText, typography.centerTitle, cx, cy + 10, centerScale, opacity, roles, titleWidth)
	else drawRoleText("centerTitle", truncate(titleText, typography.centerTitle.size * centerScale, titleWidth), typography.centerTitle, cx, cy + 10, centerScale, opacity, roles,
		model.selectedTitle == true and { typography.selectedTitleR, typography.selectedTitleG, typography.selectedTitleB, typography.selectedTitleOpacity } or nil) end
	drawWrappedRole("centerDescription", model.description or model.subtitle or "LS choose  A/X confirm  B/Y close", typography.centerDescription, cx,
		cy - 18 - typography.centerDescription.spacingBefore * centerScale, centerScale, opacity, roles, panelRadius * typography.centerDescription.maxWidth)
	if model.detail then drawRoleText("metadata", model.detail, typography.metadata, cx, cy - 42, centerScale, opacity, roles) end
	if model.footer then drawRoleText("footer", model.footer, typography.footer, cx, cy - radius * 0.65, values.fontScale, opacity, roles) end
	return { itemWidth = itemW, itemHeight = itemH, panelRadius = panelRadius, roles = roles }
end

local function drawSelectionRadial(args, cx, cy, radius, accent, values)
	local model, entries, opacity = args.model or {}, args.model.entries or {}, args.opacity or 1; local typography, roles = values.typography, {}
	color({ 0, 0, 0, 0.6 * opacity }); circle(cx, cy, radius * 1.5, 32); ring(cx, cy, radius, { accent[1], accent[2], accent[3], 0.75 * opacity }, 2.5, 44)
	local panelRadius = radius * 0.48 * typography.innerRadiusScale * typography.centerPanelScale
	color({ 0.08, 0.10, 0.13, 0.8 * opacity }); circle(cx, cy, panelRadius, 30)
	local centerScale = values.fontScale * values.centerTextScale
	local titleText = model.title or "SELECT FILTER"; local titleWidth = panelRadius * typography.centerTitle.maxWidth
	if typography.centerTitle.wrapMode == "Wrap" then drawWrappedRole("centerTitle", titleText, typography.centerTitle, cx, cy + 8, centerScale, opacity, roles, titleWidth)
	else drawRoleText("centerTitle", truncate(titleText, typography.centerTitle.size * centerScale, titleWidth), typography.centerTitle, cx, cy + 8, centerScale, opacity, roles) end
	drawWrappedRole("centerDescription", model.description or model.subtitle or "Release X to set", typography.centerDescription, cx,
		cy - 10 - typography.centerDescription.spacingBefore * centerScale, centerScale, opacity, roles, panelRadius * typography.centerDescription.maxWidth)
	for index, entry in ipairs(entries) do
		local angle = entryAngle(index, #entries, typography); local x, y = cx + radius * values.itemSpacing * cos(angle), cy - radius * values.itemSpacing * sin(angle)
		local vertical = index == 1 or index == 3; local w, h = vertical and 170 or 110, vertical and 38 or 30; local entryColor = entry.color or accent; local selected = index == (model.selectedIndex or 1)
		color(selected and { typography.selectedBackgroundR, typography.selectedBackgroundG, typography.selectedBackgroundB, typography.selectedBackgroundOpacity * opacity } or { entryColor[1] * 0.15, entryColor[2] * 0.15, entryColor[3] * 0.15, 0.58 * opacity })
		gl.Rect(x - w * 0.5, y - h * 0.5, x + w * 0.5, y + h * 0.5); outline(x - w * 0.5, y - h * 0.5, x + w * 0.5, y + h * 0.5,
			selected and { typography.selectedBorderR, typography.selectedBorderG, typography.selectedBorderB, typography.selectedBorderOpacity * opacity } or { entryColor[1], entryColor[2], entryColor[3], 0.55 * opacity }, selected and values.selectedBorderThickness or 1)
		drawRoleText(entry.disabled and "unavailableText" or "metadata", entry.label or "Filter", entry.disabled and typography.unavailableText or typography.metadata, x, y - (vertical and 6 or 5),
			values.fontScale * (vertical and 1.05 or 0.92), opacity, roles, selected and { typography.selectedLabelR, typography.selectedLabelG, typography.selectedLabelB, typography.selectedLabelOpacity } or nil)
	end
	if model.categoryLabel then drawRoleText("categoryLabel", model.categoryLabel, typography.categoryLabel, cx, cy + radius * 0.67, values.fontScale, opacity, roles) end
	if model.footer then drawRoleText("footer", model.footer, typography.footer, cx, cy - radius * 0.67, values.fontScale, opacity, roles) end
	return { panelRadius = panelRadius, roles = roles }
end

function Renderers.DrawRadial(args)
	args = args or {}; local model, theme = args.model or {}, args.theme or {}; local bounds = args.bounds or { x1 = 0, y1 = 0, x2 = 800, y2 = 800 }
	local values = radialSettings(args); local margin = (tonumber(values.typography.safeScreenMargin) or 0)
	local cx, cy = (bounds.x1 + bounds.x2) * 0.5, (bounds.y1 + bounds.y2) * 0.5
	local radius = max(10, min(bounds.x2 - bounds.x1, bounds.y2 - bounds.y1) * (model.radiusRatio or 0.34) * values.typography.radiusScale - margin)
	local accent = model.accent or { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92 }; local style = model.style or "build"; local measured
	if style == "tactical" then measured = drawTacticalRadial(args, cx, cy, radius, accent, values) elseif style == "selection" then measured = drawSelectionRadial(args, cx, cy, radius, accent, values)
	else measured = drawBuildRadial(args, cx, cy, radius, accent, values) end
	gl.Color(1, 1, 1, 1); gl.LineWidth(1); gl.Texture(false); measured = measured or {}
	measured.cx, measured.cy, measured.radius, measured.count, measured.style = cx, cy, radius, #(model.entries or {}), style; measured.parameters = values
	return measured
end

function Renderers.DrawHotSlots(args)
	args = args or {}; local model, component, theme = args.model or {}, args.settings or {}, args.theme or {}
	local bounds = args.bounds or { x1 = 0, y1 = 0, x2 = 600, y2 = 100 }
	local slots = model.slots or {}; local count = max(1, min(10, floor(component.slotCount or #slots or 10)))
	local drawCount = #slots > 0 and min(count, #slots) or count
	local scale, fontScale = args.scale or 1, args.fontScale or args.scale or 1
	local padding, gap = (component.panelPadding or 12) * scale, (component.slotGap or 5) * scale
	local orientation = component.orientation or "Horizontal"
	local rows = orientation == "Vertical" and count or orientation == "Grid" and max(1, min(count, floor(component.rows or 2))) or 1
	local columns = ceil(count / rows); local header = component.showLabel == false and 0 or 22 * scale; local status = component.showStatus == false and 0 or 18 * scale
	local availableW, availableH = bounds.x2 - bounds.x1 - padding * 2, bounds.y2 - bounds.y1 - padding * 2 - header - status
	local slotW = min((component.slotWidth or component.slotSize or 42) * scale, (availableW - gap * max(0, columns - 1)) / columns)
	local slotH = min((component.slotHeight or component.slotSize or 42) * scale, (availableH - gap * max(0, rows - 1)) / rows)
	local stripW = padding * 2 + columns * slotW + max(0, columns - 1) * gap
	local stripH = padding * 2 + rows * slotH + max(0, rows - 1) * gap + header + status
	local left, bottom = (bounds.x1 + bounds.x2 - stripW) * 0.5, (bounds.y1 + bounds.y2 - stripH) * 0.5
	local opacity = args.opacity or 1; local accent = { theme.accentR or 0.36, theme.accentG or 0.68, theme.accentB or 1 }
	color({ theme.backgroundR or 0, theme.backgroundG or 0, theme.backgroundB or 0, (component.backgroundOpacity or 0.72) * opacity }); gl.Rect(left, bottom, left + stripW, bottom + stripH)
	outline(left, bottom, left + stripW, bottom + stripH, { accent[1], accent[2], accent[3], 0.65 * opacity }, 1.5)
	if header > 0 then color({ theme.foregroundR or 0.82, theme.foregroundG or 0.92, theme.foregroundB or 1, opacity }); gl.Text(model.header or component.headerLabel or "Controller Groups", left + padding, bottom + stripH - 17 * scale, 11 * fontScale, "o") end
	local iconScale = clamp(component.iconScale or 1, 0.5, 2)
	for index = 1, drawCount do
		local slot = slots[index] or {}; local grid = index - 1; local column, row = grid % columns, floor(grid / columns)
		local x1 = left + padding + column * (slotW + gap); local y1 = bottom + padding + status + (rows - row - 1) * (slotH + gap)
		local selected = slot.selected == true or index == model.selectedIndex
		color(selected and { 0.18, 0.42, 0.78, 0.88 * opacity } or slot.empty and { 0.05, 0.07, 0.09, (component.emptyOpacity or 0.74) * opacity } or { 0.10, 0.18, 0.24, 0.82 * opacity })
		gl.Rect(x1, y1, x1 + slotW, y1 + slotH)
		if slot.texture then
			local short = min(slotW, slotH); local icon = short * min(0.92, iconScale * 0.72); local insetX, insetY = (slotW - icon) * 0.5, (slotH - icon) * 0.5
			gl.Texture(slot.texture); color({ 1, 1, 1, (selected and 0.95 or 0.75) * opacity }); gl.TexRect(x1 + insetX, y1 + insetY, x1 + slotW - insetX, y1 + slotH - insetY); gl.Texture(false)
		end
		outline(x1, y1, x1 + slotW, y1 + slotH, { selected and 1 or 0.55, selected and 0.92 or 0.72, selected and 0.35 or 0.82, opacity },
			(selected or slot.recent) and (component.selectedBorderThickness or 2.5) or 1)
		color({ 1, 1, 1, opacity }); gl.Text(slot.label or tostring(index), x1 + 4 * scale, y1 + slotH - 13 * scale, 10 * fontScale, "o")
		if component.showCounts ~= false and (slot.count or 0) > 0 then
			color({ 1, 0.92, 0.42, opacity }); gl.Text("x" .. tostring(slot.count), x1 + slotW - 4 * scale, y1 + 3 * scale, 9 * fontScale, "ro")
			if component.showAuto and slot.auto then color({ 0.52, 1, 0.66, 0.95 * opacity }); gl.Text("AUTO", x1 + 4 * scale, y1 + 3 * scale, 7 * fontScale, "o") end
		end
		if component.showRole and slot.role then
			local role = tostring(slot.role); if #role > 12 then role = string.sub(role, 1, 11) .. "." end
			color({ 0.76, 0.9, 1, 0.9 * opacity }); gl.Text(role, x1 + slotW * 0.5, y1 + 3 * scale, 7 * fontScale, "oc")
		end
	end
	if status > 0 then color({ theme.foregroundR or 0.92, theme.foregroundG or 0.96, theme.foregroundB or 1, opacity }); gl.Text(model.status or "Group ready", left + padding, bottom + 5 * scale, 10 * fontScale, "o") end
	gl.Color(1, 1, 1, 1)
	return { x1 = left, y1 = bottom, x2 = left + stripW, y2 = bottom + stripH, count = drawCount,
		parameters = { scale = scale, fontScale = fontScale, iconScale = iconScale, slotWidth = slotW, slotHeight = slotH,
			gap = gap, rows = rows, columns = columns, opacity = opacity } }
end

--------------------------------------------------------------------------------
-- Shared controller selection/input state. These helpers are deliberately pure
-- so the live widgets and the release harness exercise identical transitions.
--------------------------------------------------------------------------------

Renderers.SelectionBehavior = {
	LB_TAP_MAX_SECONDS = 0.20,
	LB_TACTICAL_HOLD_SECONDS = 0.20,
	HINT_CONTEXT_ENTER_DEBOUNCE_SECONDS = 0.14,
	HINT_CONTEXT_EXIT_GRACE_SECONDS = 0.12,
	HINT_CONTEXT_POLL_SECONDS = 0.04,
	FILTER_DEADZONE = 0.50,
	FILTERS = { "Last Selected", "Builders", "Air", "Combat" },
}

local SelectionBehavior = Renderers.SelectionBehavior

function SelectionBehavior.IsValidFilter(value)
	for _, filter in ipairs(SelectionBehavior.FILTERS) do
		if value == filter then return true end
	end
	return false
end

function SelectionBehavior.FilterShortLabel(value)
	if value == "Last Selected" then return "Restore Last Selection" end
	return "Select Visible " .. tostring(SelectionBehavior.IsValidFilter(value) and value or "Combat")
end

function SelectionBehavior.FilterFromStick(x, y, deadzone)
	x, y = tonumber(x) or 0, tonumber(y) or 0
	if ((x * x) + (y * y)) ^ 0.5 < (tonumber(deadzone) or SelectionBehavior.FILTER_DEADZONE) then return nil end
	if abs(y) > abs(x) then return y > 0 and "Last Selected" or "Combat" end
	return x < 0 and "Builders" or "Air"
end

function SelectionBehavior.FilterVisibleUnits(units, filter, classify)
	local selected = {}
	if type(classify) ~= "function" then return selected end
	for _, unitID in ipairs(type(units) == "table" and units or {}) do
		local facts = classify(unitID)
		if type(facts) == "table" and facts.safe then
			local matches = filter == "Builders" and facts.builder
				or filter == "Air" and facts.mobile and facts.air
				or filter == "Combat" and facts.mobile and facts.combat and (not facts.builder or facts.combatRole)
			if matches then selected[#selected + 1] = unitID end
		end
	end
	table.sort(selected)
	return selected
end

function SelectionBehavior.NewLBCycle()
	return { active = false, pressedAt = 0, heldSeconds = 0, tactical = false, consumed = false, consumeReason = "none" }
end

function SelectionBehavior.PressLB(state, now)
	state = state or SelectionBehavior.NewLBCycle()
	state.active, state.pressedAt, state.heldSeconds = true, tonumber(now) or 0, 0
	state.tactical, state.consumed, state.consumeReason = false, false, "none"
	return state
end

function SelectionBehavior.UpdateLB(state, now, holdSeconds)
	if not state or not state.active then return false end
	state.heldSeconds = max(0, (tonumber(now) or 0) - (tonumber(state.pressedAt) or 0))
	if state.heldSeconds >= (tonumber(holdSeconds) or SelectionBehavior.LB_TACTICAL_HOLD_SECONDS) then
		state.tactical = true
	end
	return state.tactical
end

function SelectionBehavior.ConsumeLB(state, reason)
	if not state or not state.active then return false end
	state.consumed, state.consumeReason = true, tostring(reason or "chord")
	return true
end

function SelectionBehavior.ReleaseLB(state, now, tapMaxSeconds, holdSeconds)
	if not state or not state.active then return false end
	SelectionBehavior.UpdateLB(state, now, holdSeconds)
	local shouldTap = not state.consumed and not state.tactical
		and state.heldSeconds <= (tonumber(tapMaxSeconds) or SelectionBehavior.LB_TAP_MAX_SECONDS)
	state.active, state.tactical, state.consumed = false, false, false
	state.pressedAt, state.heldSeconds, state.consumeReason = 0, 0, "none"
	return shouldTap
end

function SelectionBehavior.ResetLB(state, reason)
	if not state then return end
	state.active, state.tactical, state.consumed = false, false, false
	state.pressedAt, state.heldSeconds, state.consumeReason = 0, 0, tostring(reason or "reset")
end

function SelectionBehavior.NewHintContextState()
	return { committed = nil, committedSignature = nil, committedModal = false,
		candidate = nil, candidateSignature = nil, candidateSince = 0 }
end

function SelectionBehavior.AdvanceHintContext(state, context, signature, now, confirmedModal, enterSeconds, exitSeconds)
	state = state or SelectionBehavior.NewHintContextState()
	now, signature = tonumber(now) or 0, tostring(signature or "")
	if state.committed == nil or confirmedModal == true then
		local changed = state.committedSignature ~= signature
		state.committed, state.committedSignature, state.committedModal = context, signature, confirmedModal == true
		state.candidate, state.candidateSignature, state.candidateSince = nil, nil, now
		return state.committed, changed
	end
	if signature == state.committedSignature then
		state.candidate, state.candidateSignature, state.candidateSince = nil, nil, now
		return state.committed, false
	end
	if state.candidateSignature ~= signature then
		state.candidate, state.candidateSignature, state.candidateSince = context, signature, now
		return state.committed, false
	end
	local waitSeconds = state.committedModal and (tonumber(exitSeconds) or SelectionBehavior.HINT_CONTEXT_EXIT_GRACE_SECONDS)
		or (tonumber(enterSeconds) or SelectionBehavior.HINT_CONTEXT_ENTER_DEBOUNCE_SECONDS)
	if now - state.candidateSince < waitSeconds then return state.committed, false end
	state.committed, state.committedSignature, state.committedModal = state.candidate, signature, false
	state.candidate, state.candidateSignature, state.candidateSince = nil, nil, now
	return state.committed, true
end

return Renderers
