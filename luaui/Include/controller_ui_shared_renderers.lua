--------------------------------------------------------------------------------
-- Shared production/preview renderers for controller UI components.
-- Data collection remains in the owning widget; these functions only lay out
-- and draw supplied models.
--------------------------------------------------------------------------------

local Renderers = {}
local max, min, floor, ceil = math.max, math.min, math.floor, math.ceil

local function clamp(value, low, high)
	return max(low, min(high, tonumber(value) or low))
end

local function color(value, alpha)
	value = value or { 1, 1, 1, 1 }
	gl.Color(value[1] or 1, value[2] or 1, value[3] or 1, alpha == nil and (value[4] or 1) or alpha)
end

local function outline(x1, y1, x2, y2, value, thickness)
	color(value); thickness = max(1, floor(thickness or 1))
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
	while #text > 1 and textWidth(text .. "...", size) > width do text = string.sub(text, 1, -2) end
	return textWidth(text, size) > width and "" or text .. (textWidth(text, size) > width and "" or "...")
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
	return lines
end

local function presentation(component)
	local name = component.presentation or "Glyph + Action Text"
	local chip, action, compact = true, true, component.compact == true
	if name == "Button Chip Only" then action = false
	elseif name == "Action Text Only" or name == "Background Only" then chip = false
	elseif name == "Minimal Glyph" then action, compact = false, true
	elseif name == "Compact" then compact = true end
	return chip and component.showChip ~= false, action and component.showActionText ~= false, compact
end

function Renderers.DrawHints(args)
	args = args or {}
	local component, hints, theme = args.settings or {}, args.model or {}, args.theme or {}
	if component.enabled == false or #hints == 0 then return { hits = {} } end
	local scale, fontScale = args.scale or 1, args.fontScale or 1
	local fontSize, opacity = 14 * fontScale, (args.opacity or 1)
	local showChip, showAction, compact = presentation(component)
	local count = #hints
	if not component.expanded and component.priorityHiding ~= false then count = min(count, floor(component.maxItems or 14)) end
	local glyphSize = max(18, 20 * scale * (component.iconScale or 1))
	local sequences, glyphHeight = {}, 0
	if args.glyphs and showChip then
		for index = 1, count do
			sequences[index] = args.glyphs.BuildSequence(hints[index].inputs,
				{ hold = hints[index].hold, showTapHold = component.showTapHold })
			local _, height = args.glyphs.Dimensions(sequences[index], glyphSize, (component.glyphSpacing or 4) * scale, component.chordLayout)
			glyphHeight = max(glyphHeight, height)
		end
	end
	local rowHeight = max(22 * scale, fontSize + (component.rowSpacing or 0) * scale, glyphHeight + 6 * scale)
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
		local availableW, availableH = target.x2 - target.x1, target.y2 - target.y1
		local fit = min(1, availableW / panelWidth, availableH / panelHeight)
		scale, fontScale, glyphSize, fontSize, rowHeight, padding = scale * fit, fontScale * fit, glyphSize * fit, fontSize * fit, rowHeight * fit, padding * fit
		panelWidth, panelHeight, moreHeight, contextHeight = panelWidth * fit, panelHeight * fit, moreHeight * fit, contextHeight * fit
		x1, y1 = (target.x1 + target.x2 - panelWidth) * 0.5, (target.y1 + target.y2 - panelHeight) * 0.5
	else
		x1 = clamp((component.x or 0.04) * viewportW, args.margin or 0, viewportW - panelWidth - (args.margin or 0))
		y1 = clamp((component.y or 0.08) * viewportH, args.margin or 0, viewportH - panelHeight - (args.margin or 0))
	end
	local background = { theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04,
		(component.backgroundOpacity or 0.72) * opacity }
	local accent = { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92, (component.borderOpacity or 0.5) * opacity }
	local foreground = { theme.foregroundR or 0.94, theme.foregroundG or 0.98, theme.foregroundB or 1, (component.textOpacity or 1) * opacity }
	color(background); gl.Rect(x1, y1, x1 + panelWidth, y1 + panelHeight)
	outline(x1, y1, x1 + panelWidth, y1 + panelHeight, accent, component.borderThickness or 1)
	if component.showContextHeader then
		color({ accent[1], accent[2], accent[3], 0.18 * opacity }); gl.Rect(x1, y1 + panelHeight - contextHeight, x1 + panelWidth, y1 + panelHeight)
		color(foreground); gl.Text(args.contextLabel or "Gameplay", x1 + padding, y1 + panelHeight - contextHeight + 6 * scale, 11 * fontScale, "o")
	end
	local columnGap = (component.columnSpacing or 12) * scale
	local columnWidth = (panelWidth - padding * 2 - (columns - 1) * columnGap) / columns
	local hits = {}
	for index = 1, count do
		local hint = hints[index]; local col = floor((index - 1) / rows); local row = (index - 1) % rows
		local rx = x1 + padding + col * (columnWidth + columnGap)
		local ry = y1 + panelHeight - padding - moreHeight - contextHeight - (row + 1) * rowHeight
		local sequence = sequences[index]
		local sequenceWidth = sequence and args.glyphs.Dimensions(sequence, glyphSize, (component.glyphSpacing or 4) * scale, component.chordLayout) or 0
		local chipText = args.formatInputs and args.formatInputs(hint) or tostring(hint.input or "?")
		local chipWidth = showChip and min(columnWidth * (showAction and 0.48 or 1), max(38 * scale, sequenceWidth + 8 * scale, (#chipText * 7 + 14) * scale)) or 0
		if component.showRowBackground then color({ theme.mutedR or 0.3, theme.mutedG or 0.5, theme.mutedB or 0.6, 0.13 * opacity }); gl.Rect(rx, ry + 1, rx + columnWidth, ry + rowHeight - 1) end
		if showChip then
			color({ 0.08, 0.18, 0.23, 0.94 * opacity }); gl.Rect(rx, ry + 2 * scale, rx + chipWidth, ry + rowHeight - 2 * scale)
			outline(rx, ry + 2 * scale, rx + chipWidth, ry + rowHeight - 2 * scale, accent, 1)
			if sequence then
				args.glyphs.DrawSequence(sequence, rx + 4 * scale, ry + (rowHeight - glyphHeight * (target and min(1, (target.x2-target.x1)/panelWidth) or 1)) * 0.5, {
					size = glyphSize, spacing = (component.glyphSpacing or 4) * scale, layout = component.chordLayout,
					alignment = "left", maxWidth = chipWidth - 8 * scale, colorMode = component.glyphColorMode or "Color-friendly",
					opacity = (component.glyphOpacity or 1) * (component.textOpacity or 1) * opacity,
					tint = { accent[1], accent[2], accent[3] }, backgroundOpacity = 0, borderOpacity = 0,
				})
			else color(foreground); gl.Text(chipText, rx + chipWidth * 0.5, ry + (rowHeight - fontSize) * 0.5, fontSize * 0.82, "oc") end
		end
		if showAction then
			local labelText = compact and (hint.compactLabel or hint.label) or hint.label
			local labelX = rx + chipWidth + (showChip and (component.iconTextSpacing or 8) * scale or 0)
			local available = max(24, rx + columnWidth - labelX)
			local lines = component.overflow == "Wrap" and wrap(labelText, fontSize, available, component.wrapLines or 2)
				or { textWidth(labelText, fontSize) > available and truncate(labelText, fontSize, available) or labelText }
			color(foreground)
			for lineIndex, line in ipairs(lines) do gl.Text(line, labelX, ry + rowHeight - fontSize * 1.12 - (lineIndex - 1) * fontSize * 0.86, fontSize * (lineIndex == 1 and 1 or 0.86), "o") end
		end
		hits[#hits + 1] = { x1 = rx, y1 = ry, x2 = rx + columnWidth, y2 = ry + rowHeight, hint = hint }
	end
	local moreHit
	if count < #hints then
		moreHit = { x1 = x1, y1 = y1, x2 = x1 + panelWidth, y2 = y1 + moreHeight }
		color(accent); gl.Text("+" .. tostring(#hints - count) .. " more", x1 + panelWidth * 0.5, y1 + 5 * scale, 11 * fontScale, "oc")
	end
	gl.Color(1, 1, 1, 1)
	return { x1 = x1, y1 = y1, x2 = x1 + panelWidth, y2 = y1 + panelHeight, hits = hits, moreHit = moreHit }
end

local function circle(cx, cy, radius, segments)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(cx, cy)
		for index = 0, segments do local angle = index * math.pi * 2 / segments; gl.Vertex(cx + radius * math.cos(angle), cy + radius * math.sin(angle)) end
	end)
end

function Renderers.DrawRadial(args)
	args = args or {}; local model, theme = args.model or {}, args.theme or {}
	local bounds = args.bounds or { x1 = 0, y1 = 0, x2 = 800, y2 = 800 }
	local cx, cy = (bounds.x1 + bounds.x2) * 0.5, (bounds.y1 + bounds.y2) * 0.5
	local radius = min(bounds.x2 - bounds.x1, bounds.y2 - bounds.y1) * (model.radiusRatio or 0.34)
	local entries = model.entries or {}; local count = max(1, #entries); local opacity = args.opacity or 1
	local accent = model.accent or { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92 }
	color({ theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04, 0.72 * opacity }); circle(cx, cy, radius * 1.24, 40)
	local hasTextures = false; for _, entry in ipairs(entries) do if entry.texture then hasTextures = true; break end end
	local itemW = model.itemWidth or min(132, max(74, radius * 0.72)); local itemH = model.itemHeight or (hasTextures and itemW * 0.78 or max(32, radius * 0.22))
	local itemRadius = radius * (model.itemSpacing or 1)
	for index, entry in ipairs(entries) do
		local angle = ((index - 1) * math.pi * 2 / count) - math.pi * 0.5
		local x, y = cx + itemRadius * math.cos(angle), cy - itemRadius * math.sin(angle)
		local selected = index == (model.selectedIndex or 1)
		color(selected and { accent[1] * 0.5, accent[2] * 0.5, accent[3] * 0.5, 0.94 * opacity }
			or entry.disabled and { 0.32, 0.12, 0.12, 0.62 * opacity } or { 0.05, 0.08, 0.11, 0.86 * opacity })
		gl.Rect(x - itemW * 0.5, y - itemH * 0.5, x + itemW * 0.5, y + itemH * 0.5)
		outline(x - itemW * 0.5, y - itemH * 0.5, x + itemW * 0.5, y + itemH * 0.5,
			entry.disabled and { 0.68, 0.22, 0.22, 0.72 * opacity }
				or { accent[1], accent[2], accent[3], (selected and 1 or 0.48) * opacity }, selected and 2 or 1)
		if entry.texture then
			local icon = min(itemW, itemH) * 0.62
			local tx1, ty1, tx2, ty2 = x - icon * 0.5, y - icon * 0.36, x + icon * 0.5, y + icon * 0.64
			gl.Texture(entry.texture)
			if entry.progress and entry.progress >= 0 and entry.progress <= 1 and gl.Scissor then
				color({ 0.2, 0.2, 0.2, 0.5 * opacity }); gl.TexRect(tx1, ty1, tx2, ty2)
				if entry.progress > 0 then
					gl.Scissor(tx1, ty1, tx2 - tx1, (ty2 - ty1) * entry.progress)
					color({ 1, 1, 1, (entry.disabled and 0.45 or 0.92) * opacity }); gl.TexRect(tx1, ty1, tx2, ty2); gl.Scissor(false)
				end
			else color({ 1, 1, 1, (entry.disabled and 0.45 or 0.92) * opacity }); gl.TexRect(tx1, ty1, tx2, ty2) end
			gl.Texture(false)
			color({ 1, 1, 1, opacity }); gl.Text(entry.label or entry.name or "Build", x, y - itemH * 0.43, selected and 10 or 9, "oc")
		else color({ 1, 1, 1, opacity }); gl.Text(entry.label or entry.name or "Command", x, y - 5, selected and 13 or 11, "oc") end
		if entry.indexLabel then color({ 1, 0.84, 0, opacity }); gl.Text(tostring(entry.indexLabel), x - itemW * 0.5 + 5, y + itemH * 0.5 - 14, 10, "o") end
		if (entry.badge or 0) > 0 then
			local badge = "x" .. tostring(entry.badge); local badgeW = max(28, #badge * 8 + 10)
			local bx2, by2 = x + itemW * 0.5 + 3, y + itemH * 0.5 + 3
			color({ 0.04, 0.08, 0.12, 0.9 * opacity }); gl.Rect(bx2 - badgeW, by2 - 20, bx2, by2)
			outline(bx2 - badgeW, by2 - 20, bx2, by2, { accent[1], accent[2], accent[3], 0.7 * opacity }, 1)
			color({ 1, 0.95, 0.8, opacity }); gl.Text(badge, bx2 - badgeW * 0.5, by2 - 15, 10, "oc")
		end
	end
	color({ theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04, 0.94 * opacity }); circle(cx, cy, radius * 0.39, 32)
	outline(cx - radius * 0.39, cy - radius * 0.39, cx + radius * 0.39, cy + radius * 0.39, { accent[1], accent[2], accent[3], 0.6 * opacity }, 1)
	local detailLines = model.details or {}
	local titleY = cy + (#detailLines > 0 and radius * 0.20 or 8)
	color({ accent[1], accent[2], accent[3], opacity }); gl.Text(model.title or "Radial", cx, titleY, 15, "oc")
	color({ 1, 1, 1, 0.84 * opacity }); gl.Text(model.subtitle or "LS choose  A confirm  B close", cx, titleY - 23, 10, "oc")
	for index, detail in ipairs(detailLines) do
		if index > 4 then break end
		local size = index == 1 and 9 or 8
		local content = tostring(detail)
		if textWidth(content, size) > radius * 0.68 then content = truncate(content, size, radius * 0.68) end
		color({ 0.78, 0.88, 0.96, (index == 1 and 0.9 or 0.76) * opacity })
		gl.Text(content, cx, titleY - 40 - (index - 1) * 13, size, "oc")
	end
	gl.Color(1, 1, 1, 1)
	return { cx = cx, cy = cy, radius = radius, count = #entries }
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
	local opacity = args.opacity or 1; local accent = { theme.accentR or 0.34, theme.accentG or 0.82, theme.accentB or 0.92 }
	color({ theme.backgroundR or 0.02, theme.backgroundG or 0.03, theme.backgroundB or 0.04, (component.backgroundOpacity or 0.72) * opacity }); gl.Rect(left, bottom, left + stripW, bottom + stripH)
	outline(left, bottom, left + stripW, bottom + stripH, { accent[1], accent[2], accent[3], 0.65 * opacity }, 1)
	if header > 0 then color({ theme.foregroundR or 0.94, theme.foregroundG or 0.98, theme.foregroundB or 1, opacity }); gl.Text(component.headerLabel or "Controller Groups", left + padding, bottom + stripH - 17 * scale, 11 * fontScale, "o") end
	for index = 1, drawCount do
		local slot = slots[index] or {}; local grid = index - 1; local column, row = grid % columns, floor(grid / columns)
		local x1 = left + padding + column * (slotW + gap); local y1 = bottom + padding + status + (rows - row - 1) * (slotH + gap)
		local selected = slot.selected == true or index == model.selectedIndex
		color(selected and { 0.18, 0.42, 0.78, 0.88 * opacity } or slot.empty and { 0.05, 0.07, 0.09, (component.emptyOpacity or 0.74) * opacity } or { 0.10, 0.18, 0.24, 0.82 * opacity })
		gl.Rect(x1, y1, x1 + slotW, y1 + slotH)
		if slot.texture then
			local inset = max(3, min(slotW, slotH) * 0.14)
			gl.Texture(slot.texture); color({ 1, 1, 1, (selected and 0.95 or 0.75) * opacity })
			gl.TexRect(x1 + inset, y1 + inset, x1 + slotW - inset, y1 + slotH - inset); gl.Texture(false)
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
	if status > 0 then color({ theme.foregroundR or 0.94, theme.foregroundG or 0.98, theme.foregroundB or 1, opacity }); gl.Text(model.status or "Group ready", left + padding, bottom + 5 * scale, 10 * fontScale, "o") end
	gl.Color(1, 1, 1, 1)
	return { x1 = left, y1 = bottom, x2 = left + stripW, y2 = bottom + stripH, count = drawCount }
end

return Renderers
