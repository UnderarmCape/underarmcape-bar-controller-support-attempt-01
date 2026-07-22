-- Shared vanilla Build Menu cell renderer for native controller surfaces.
-- Geometry is supplied by the owner; icon crop, costs, badges, disabled state,
-- queue count and focus treatment are identical for the grid and radial.
local Renderer = {}

local function spaced(value)
	local number = math.floor(tonumber(value) or 0)
	if number >= 1000 then return spaced(math.floor(number / 1000)) .. " " .. string.format("%03d", number % 1000) end
	return tostring(number)
end

local function printText(font, text, x, y, size, options)
	if font and type(font.Print) == "function" then font:Print(text, x, y, size, options)
	else gl.Text(text, x, y, size, options) end
end

function Renderer.Draw(args)
	args = args or {}
	local rect, flow = args.rect, args.flow or (WG and WG.FlowUI)
	local drawUnit = flow and flow.Draw and flow.Draw.Unit
	if type(rect) ~= "table" or type(drawUnit) ~= "function" then return false end
	local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
	if not x1 or not y1 or not x2 or not y2 or x2 <= x1 or y2 <= y1 then return false end
	local width, height = x2 - x1, y2 - y1
	local size = math.min(width, height)
	local innerSize = tonumber(args.innerSize) or size
	local padding = tonumber(args.padding) or size * 0.025
	local iconPadding = tonumber(args.iconPadding) or size * 0.03
	local corner = tonumber(args.corner) or size * 0.025
	local ix1, iy1, ix2, iy2 = x1 + padding + iconPadding, y1 + padding + iconPadding,
		x2 - padding - iconPadding, y2 - padding - iconPadding
	local disabled = args.disabled == true or args.unaffordable == true
	local texture = args.texture or (args.unitDefID and ("#" .. tostring(args.unitDefID)))
	if args.textureWarm and texture and not args.textureWarm[args.unitDefID] then
		if gl.Texture(texture) then args.textureWarm[args.unitDefID] = true end
		gl.Texture(false)
	end
	local tintPrefix = ""
	if disabled then
		gl.Color(0.4, 0.4, 0.4, 1)
		tintPrefix = "t0.3,0.3,0.3"
	elseif args.underConstruction then
		gl.Color(0.77, 0.77, 0.77, 1)
		tintPrefix = "t0.63,0.63,0.63"
	else
		gl.Color(1, 1, 1, 1)
	end
	local function tintedOverlay(value)
		if not value or tintPrefix == "" then return value end
		local suffix = tostring(value):match("^:l:(.+)$")
		return suffix and (":l" .. tintPrefix .. ":" .. suffix) or value
	end
	drawUnit(ix1, iy1, ix2, iy2, corner, 1, 1, 1, 1,
		tonumber(args.zoom) or 0.0375, nil, disabled and 0 or nil,
		texture, tintedOverlay(args.radarTexture), tintedOverlay(args.groupTexture),
		{ tonumber(args.metalCost) or 0, tonumber(args.energyCost) or 0 },
		tonumber(args.queueCount))

	if args.selectedTint then
		local color = args.selectedTint
		gl.Blending(GL.DST_ALPHA, GL.ONE_MINUS_SRC_COLOR)
		gl.Color(color[1], color[2], color[3], color[4])
		gl.Texture(texture)
		drawUnit(ix1, iy1, ix2, iy2, corner, 1, 1, 1, 1, tonumber(args.zoom) or 0.0375)
		if (tonumber(color[4]) or 0) > 0 then
			gl.Blending(GL.SRC_ALPHA, GL.ONE)
			drawUnit(ix1, iy1, ix2, iy2, corner, 1, 1, 1, 1, tonumber(args.zoom) or 0.0375)
		end
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	gl.Texture(false)

	local fontSize = tonumber(args.fontSize) or innerSize * 0.15
	local right = x2 - padding - innerSize * 0.048
	if args.showPrice ~= false then
		local override = args.costOverride
		local function drawCost(spec, fallbackValue, fallbackColor, fallbackDisabledColor,
				overrideColor, overrideDisabledColor, y)
			if spec and spec.disabled then return end
			local value = spec and spec.value or fallbackValue
			local color = spec and (disabled and (spec.colorDisabled or overrideDisabledColor)
				or (spec.color or overrideColor))
				or (disabled and fallbackDisabledColor or fallbackColor)
			printText(args.font, (color or fallbackColor) .. spaced(value), right, y, fontSize, "ro")
		end
		drawCost(override and override.top, args.metalCost, "\255\245\245\245", "\255\125\125\125",
			"\255\100\255\100", "\255\100\200\100",
			y1 + padding + fontSize * 1.35)
		drawCost(override and override.bottom, args.energyCost, "\255\255\255\000", "\255\135\135\135",
			"\255\255\255\000", "\255\135\135\135",
			y1 + padding + fontSize * 0.35)
	end

	local queue = tonumber(args.queueCount) or 0
	if queue > 0 then
		local rectRound = flow.Draw.RectRound
		local text = tostring(queue)
		local badgeWidth = args.font and type(args.font.GetTextWidth) == "function"
			and math.floor(args.font:GetTextWidth(text .. "  ") * innerSize * 0.285)
			or math.max(innerSize * 0.30, #text * innerSize * 0.18)
		local bx2, by2 = x2 - padding - iconPadding, y2 - padding - iconPadding
		local pad = math.floor(innerSize * 0.03)
		if rectRound then
			rectRound(bx2 - badgeWidth, by2 - math.floor(innerSize * 0.365), bx2, by2,
				corner * 3.3, 0, 0, 0, 1, { 0.15, 0.15, 0.15, 0.95 }, { 0.25, 0.25, 0.25, 0.95 })
			rectRound(bx2 - badgeWidth, by2 - math.floor(innerSize * 0.15), bx2, by2,
				0, 0, 0, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.05 })
			rectRound(bx2 - badgeWidth + pad, by2 - math.floor(innerSize * 0.365) + pad, bx2, by2,
				corner * 2.6, 0, 0, 0, 1, { 0.7, 0.7, 0.7, 0.1 }, { 1, 1, 1, 0.1 })
		end
		printText(args.font, "\255\190\255\190" .. text, x1 + padding + math.floor(innerSize * 0.96),
			y1 + padding + math.floor(innerSize * 0.735), innerSize * 0.29, "ro")
	end
	gl.Color(1, 1, 1, 1)
	return true
end

return Renderer
