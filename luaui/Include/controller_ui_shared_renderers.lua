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

local function radialSettings(args)
	local settings, model = args.settings or {}, args.model or {}
	return {
		iconScale = tonumber(settings.iconScale) or tonumber(model.iconScale) or 1,
		fontScale = tonumber(settings.fontScale) or tonumber(model.fontScale) or 1,
		centerTextScale = tonumber(settings.centerTextScale) or 1,
		selectedScale = tonumber(settings.selectedScale) or 1.06,
		selectedBorderThickness = tonumber(settings.selectedBorderThickness) or 3,
		itemSpacing = tonumber(settings.itemSpacing) or tonumber(model.itemSpacing) or 1,
		legacyThemeOpacity = tonumber(settings.legacyThemeOpacity) or 1,
		pageStatusVisible = settings.pageStatusVisible ~= false,
	}
end

local function drawBuildRadial(args, cx, cy, radius, accent, values)
	local model, theme, entries, opacity = args.model or {}, args.theme or {}, args.model.entries or {}, args.opacity or 1
	local n = max(1, #entries); local iconSize = min(500, max(56, radius * 0.27 * values.iconScale))
	local fill = model.fill or { theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04 }
	color({ fill[1], fill[2], fill[3], 0.58 * opacity * values.legacyThemeOpacity }); circle(cx, cy, radius * 1.3, 40)
	ring(cx, cy, radius, { accent[1], accent[2], accent[3], 0.3 * opacity }, 2, 36)
	for index, entry in ipairs(entries) do
		local angle = ((index - 1) * pi * 2 / n) - pi * 0.5
		local x, y = cx + radius * values.itemSpacing * cos(angle), cy - radius * values.itemSpacing * sin(angle)
		local selected = index == (model.selectedIndex or 1); local size = iconSize * (selected and values.selectedScale or 1)
		if selected then color({ accent[1], accent[2], accent[3], 0.85 * opacity })
		elseif entry.disabled then color({ 0.32, 0.12, 0.12, 0.42 * opacity })
		else color({ 0.12, 0.18, 0.23, 0.42 * opacity }) end
		gl.Rect(x - size * 0.5 - 2, y - size * 0.5 - 2, x + size * 0.5 + 2, y + size * 0.5 + 2)
		outline(x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5,
			selected and { accent[1], accent[2], accent[3], opacity } or entry.disabled and { 0.68, 0.22, 0.22, 0.55 * opacity } or { 0.8, 0.8, 0.8, 0.9 * opacity },
			selected and values.selectedBorderThickness or 1)
		if entry.texture then
			gl.Texture(entry.texture)
			if entry.progress and entry.progress >= 0 and entry.progress <= 1 and gl.Scissor then
				color({ 0.2, 0.2, 0.2, 0.5 * opacity }); gl.TexRect(x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5)
				if entry.progress > 0 then
					gl.Scissor(x - size * 0.5, y - size * 0.5, size, size * entry.progress)
					color({ 1, 1, 1, (entry.disabled and 0.75 or 1) * opacity }); gl.TexRect(x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5); gl.Scissor(false)
				end
			else color({ 1, 1, 1, (entry.disabled and 0.75 or 1) * opacity }); gl.TexRect(x - size * 0.5, y - size * 0.5, x + size * 0.5, y + size * 0.5) end
			gl.Texture(false)
		else color({ 1, 1, 1, opacity }); gl.Text(entry.label or "Build", x, y - 6, 12 * values.fontScale, "oc") end
		color({ 1, 0.84, 0, opacity }); gl.Text(tostring(entry.indexLabel or index), x - size * 0.5 + 6, y + size * 0.5 - 16, 12 * values.fontScale, "o")
		if (entry.badge or 0) > 0 then
			local badge = "x" .. tostring(entry.badge); local badgeW = max(28, #badge * 8 + 10)
			local bx2, by2 = x + size * 0.5 + 3, y + size * 0.5 + 3
			color({ 0.04, 0.08, 0.12, 0.88 * opacity }); gl.Rect(bx2 - badgeW, by2 - 20, bx2, by2)
			outline(bx2 - badgeW, by2 - 20, bx2, by2, { accent[1], accent[2], accent[3], 0.7 * opacity }, 1)
			color({ 1, 0.95, 0.8, opacity }); gl.Text(badge, bx2 - badgeW * 0.5, by2 - 16, 11 * values.fontScale, "oc")
		end
	end
	local panelRadius = max(radius * 0.39, min(radius * 0.56, radius - iconSize * 0.6))
	color({ 0.015, 0.04, 0.065, 0.88 * opacity }); circle(cx, cy, panelRadius, 40)
	ring(cx, cy, panelRadius, { accent[1], accent[2], accent[3], 0.78 * opacity }, 1.5, 40)
	local titleSize = 18 * values.fontScale * values.centerTextScale
	color({ 0.82, 0.94, 1, opacity }); gl.Text(model.title or "Build", cx, cy + panelRadius * 0.60, titleSize, "oc")
	local details = model.details or {}
	for index = 1, min(5, #details) do
		local line = truncate(details[index], 10 * values.fontScale * values.centerTextScale, panelRadius * 1.55)
		color(index == 1 and { 0.78, 0.84, 0.88, 0.96 * opacity } or { 0.9, 0.94, 0.98, 0.96 * opacity })
		gl.Text(line, cx, cy + panelRadius * 0.28 - (index - 1) * 14 * values.fontScale, 10 * values.fontScale * values.centerTextScale, "oc")
	end
	if values.pageStatusVisible then
		color({ accent[1], accent[2], accent[3], 0.95 * opacity }); gl.Text(string.upper(model.categoryLabel or "BUILD"), cx, cy + radius * 0.65, 18 * values.fontScale, "oc")
		color({ 0.8, 0.8, 0.8, 0.8 * opacity }); gl.Text(model.pageLabel or model.subtitle or "LS choose  A confirm", cx, cy - radius * 0.65, 13 * values.fontScale, "oc")
	end
	return { iconSize = iconSize, panelRadius = panelRadius }
end

local function drawTacticalRadial(args, cx, cy, radius, accent, values)
	local model, entries, opacity = args.model or {}, args.model.entries or {}, args.opacity or 1
	local fill = model.fill or { 0.02, 0.03, 0.04, 0.46 }; local n = max(1, #entries)
	color({ fill[1], fill[2], fill[3], (fill[4] or 0.46) * opacity * values.legacyThemeOpacity }); circle(cx, cy, radius * 1.28, 42)
	ring(cx, cy, radius, { accent[1], accent[2], accent[3], 0.74 * opacity }, 2.5, 44)
	for _, chip in ipairs(model.categoryChips or {}) do
		local y = cy + (chip.direction == "up" and radius * 0.52 or chip.direction == "down" and -radius * 0.52 or 0)
		local selected = chip.selected; local chipColor = chip.color or accent; local width = max(120, #tostring(chip.label or "") * 11 + 24)
		color(selected and { chipColor[1] * 0.15, chipColor[2] * 0.15, chipColor[3] * 0.15, 0.88 * opacity } or { 0.04, 0.05, 0.06, 0.48 * opacity })
		gl.Rect(cx - width * 0.5, y - 17, cx + width * 0.5, y + 17)
		outline(cx - width * 0.5, y - 17, cx + width * 0.5, y + 17, { chipColor[1], chipColor[2], chipColor[3], (selected and 0.95 or 0.54) * opacity }, selected and 2 or 1)
		color(selected and { 1, 1, 1, opacity } or { 0.72, 0.72, 0.72, 0.68 * opacity }); gl.Text(chip.label or "", cx, y - 6, (selected and 18 or 14) * values.fontScale, "oc")
	end
	local itemW, itemH = min(260, max(130, radius * 0.54)), max(38, 54 * values.iconScale)
	for index, entry in ipairs(entries) do
		local angle = ((index - 1) * pi * 2 / n) - pi * 0.5
		local x, y = cx + radius * values.itemSpacing * cos(angle), cy - radius * values.itemSpacing * sin(angle)
		local selected = index == (model.selectedIndex or 1); local w, h = itemW * (selected and values.selectedScale or 1), itemH * (selected and values.selectedScale or 1)
		color(selected and { accent[1] * 0.8, accent[2] * 0.8, accent[3] * 0.8, 0.82 * opacity } or { fill[1] * 0.5, fill[2] * 0.5, fill[3] * 0.5, 0.85 * opacity })
		gl.Rect(x - w * 0.5, y - h * 0.5, x + w * 0.5, y + h * 0.5)
		outline(x - w * 0.5, y - h * 0.5, x + w * 0.5, y + h * 0.5, { accent[1], accent[2], accent[3], (selected and 1 or 0.64) * opacity }, selected and values.selectedBorderThickness or 1)
		color(selected and { 1, 1, 1, opacity } or { accent[1], accent[2], accent[3], 0.9 * opacity }); gl.Text(entry.label or "Command", x, y - 6, (selected and 20 or 16) * values.fontScale, "oc")
	end
	color({ fill[1] * 0.7, fill[2] * 0.7, fill[3] * 0.7, 0.88 * opacity }); circle(cx, cy, radius * 0.42, 30)
	ring(cx, cy, radius * 0.42, { accent[1] * 0.5, accent[2] * 0.5, accent[3] * 0.5, 0.64 * opacity }, 1.5, 30)
	color({ accent[1], accent[2], accent[3], opacity }); gl.Text(model.categoryLabel or model.title or "Tactical", cx, cy + 36, 18 * values.fontScale * values.centerTextScale, "oc")
	local selected = entries[model.selectedIndex or 1]
	color({ 1, 1, 1, opacity }); gl.Text(selected and selected.label or model.title or "Tactical", cx, cy + 10, 22 * values.fontScale * values.centerTextScale, "oc")
	color({ 1, 1, 1, 0.85 * opacity }); gl.Text(model.subtitle or "LS choose  A/X confirm  B/Y close", cx, cy - 18, 14 * values.fontScale * values.centerTextScale, "oc")
	if model.detail then color({ 1, 1, 1, 0.7 * opacity }); gl.Text(model.detail, cx, cy - 38, 13 * values.fontScale * values.centerTextScale, "oc") end
	return { itemWidth = itemW, itemHeight = itemH, panelRadius = radius * 0.42 }
end

local function drawSelectionRadial(args, cx, cy, radius, accent, values)
	local model, entries, opacity = args.model or {}, args.model.entries or {}, args.opacity or 1
	color({ 0, 0, 0, 0.6 * opacity }); circle(cx, cy, radius * 1.5, 32)
	ring(cx, cy, radius, { accent[1], accent[2], accent[3], 0.75 * opacity }, 2.5, 44)
	color({ 0.08, 0.10, 0.13, 0.8 * opacity }); circle(cx, cy, radius * 0.48, 30)
	color({ 1, 1, 1, opacity }); gl.Text(model.title or "SELECT FILTER", cx, cy + 8, 12 * values.fontScale * values.centerTextScale, "oc")
	color({ 0.8, 0.8, 0.8, 0.8 * opacity }); gl.Text(model.subtitle or "Release X to set", cx, cy - 8, 9 * values.fontScale * values.centerTextScale, "oc")
	for index, entry in ipairs(entries) do
		local angle = ((index - 1) * pi * 2 / max(1, #entries)) - pi * 0.5
		local x, y = cx + radius * values.itemSpacing * cos(angle), cy - radius * values.itemSpacing * sin(angle)
		local vertical = index == 1 or index == 3; local w, h = vertical and 170 or 110, vertical and 38 or 30
		local entryColor = entry.color or accent; local selected = index == (model.selectedIndex or 1)
		color(selected and { entryColor[1], entryColor[2], entryColor[3], 0.85 * opacity } or { entryColor[1] * 0.15, entryColor[2] * 0.15, entryColor[3] * 0.15, 0.58 * opacity })
		gl.Rect(x - w * 0.5, y - h * 0.5, x + w * 0.5, y + h * 0.5)
		outline(x - w * 0.5, y - h * 0.5, x + w * 0.5, y + h * 0.5, { entryColor[1], entryColor[2], entryColor[3], (selected and 0.95 or 0.55) * opacity }, selected and values.selectedBorderThickness or 1)
		color(selected and { 1, 1, 1, opacity } or { entryColor[1] * 0.4 + 0.6, entryColor[2] * 0.4 + 0.6, entryColor[3] * 0.4 + 0.6, 0.8 * opacity })
		gl.Text(entry.label or "Filter", x, y - (vertical and 6 or 5), (vertical and 15 or 12) * values.fontScale, "oc")
	end
	return { panelRadius = radius * 0.48 }
end

function Renderers.DrawRadial(args)
	args = args or {}; local model, theme = args.model or {}, args.theme or {}
	local bounds = args.bounds or { x1 = 0, y1 = 0, x2 = 800, y2 = 800 }
	local cx, cy = (bounds.x1 + bounds.x2) * 0.5, (bounds.y1 + bounds.y2) * 0.5
	local radius = min(bounds.x2 - bounds.x1, bounds.y2 - bounds.y1) * (model.radiusRatio or 0.34)
	local accent = model.accent or { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92 }
	local values = radialSettings(args); local style = model.style or "build"
	local measured
	if style == "tactical" then measured = drawTacticalRadial(args, cx, cy, radius, accent, values)
	elseif style == "selection" then measured = drawSelectionRadial(args, cx, cy, radius, accent, values)
	else measured = drawBuildRadial(args, cx, cy, radius, accent, values) end
	gl.Color(1, 1, 1, 1); gl.LineWidth(1); gl.Texture(false)
	measured = measured or {}; measured.cx, measured.cy, measured.radius, measured.count, measured.style = cx, cy, radius, #(model.entries or {}), style
	measured.parameters = values
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
