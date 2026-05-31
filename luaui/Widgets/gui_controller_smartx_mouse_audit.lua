local versionNumber = "v1.1"

function widget:GetInfo()
	return {
		name      = "Controller SmartX Mouse Audit",
		desc      = "Audits vanilla mouse context commands to assist controller Smart X debugging.",
		author    = "Antigravity",
		date      = "2026-05-31",
		license   = "GNU GPL, v2 or later",
		layer     = 100000, -- high debug layer
		enabled   = false,  -- disabled by default!
	}
end

-- Local state to track click history and UnitCommand events
local lastClickSnapshot = {
	button = nil,
	eventType = nil,
	screenX = nil,
	screenY = nil,
	worldX = nil,
	worldY = nil,
	worldZ = nil,
	traceType = nil,
	traceID = nil,
	targetName = nil,
	mexX = nil,
	mexZ = nil,
	mexDist = nil,
	activeCmd = nil,
	selectedSummary = "",
	frame = nil,
	time = nil,
}

local lastObservedCommand = {
	cmdID = nil,
	cmdName = nil,
	params = nil,
	opts = nil,
	frame = nil,
	unitDefName = nil,
	unitID = nil,
	linkMatch = false,
}

local lastError = nil

-- Safe call-in wrapper to prevent widget from auto-removing on runtime error
local function safeCall(label, fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then
		local errStr = tostring(result)
		if lastError ~= errStr then
			Spring.Echo("[SmartXMouseAudit] ERROR in " .. tostring(label) .. ": " .. errStr)
			lastError = errStr
		end
		return nil
	end
	return result
end

-- Safe frame fetcher
local function getFrame()
	return Spring.GetGameFrame and Spring.GetGameFrame() or 0
end

-- Safe table serializer
local function serializeTable(t)
	if type(t) ~= "table" then
		return tostring(t)
	end
	local parts = {}
	for i = 1, #t do
		local v = t[i]
		if type(v) == "number" then
			parts[i] = string.format("%.0f", v)
		else
			parts[i] = tostring(v)
		end
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function CaptureClickSnapshot(x, y, button, eventType)
	local traceType, traceID
	if type(Spring.TraceScreenRay) == "function" then
		traceType, traceID = Spring.TraceScreenRay(x, y)
	end

	local wx, wy, wz
	if type(Spring.TraceScreenRay) == "function" then
		local _, worldPosition = Spring.TraceScreenRay(x, y, true)
		if type(worldPosition) == "table" then
			wx, wy, wz = worldPosition[1], worldPosition[2], worldPosition[3]
		end
	end

	local targetName = "none"
	if traceType == "unit" and traceID then
		local unitDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(traceID)
		if unitDefID and UnitDefs and UnitDefs[unitDefID] then
			targetName = UnitDefs[unitDefID].name
		end
	elseif traceType == "feature" and traceID then
		local featureDefID = type(Spring.GetFeatureDefID) == "function" and Spring.GetFeatureDefID(traceID)
		if featureDefID and FeatureDefs and FeatureDefs[featureDefID] then
			targetName = FeatureDefs[featureDefID].name
		end
	end

	-- Nearest Mex Spot Finder
	local mexDist = "N/A"
	local nearestMexX, nearestMexZ
	if wx and wz and WG.resource_spot_finder and type(WG.resource_spot_finder.GetClosestMexSpot) == "function" then
		local spot = WG.resource_spot_finder.GetClosestMexSpot(wx, wz)
		if spot and type(spot) == "table" then
			nearestMexX = spot.x or spot[1]
			nearestMexZ = spot.z or spot[3]
			if nearestMexX and nearestMexZ then
				local dx = wx - nearestMexX
				local dz = wz - nearestMexZ
				mexDist = math.floor(math.sqrt(dx*dx + dz*dz))
			end
		end
	end

	-- Selected units summary
	local selectedUnits = type(Spring.GetSelectedUnits) == "function" and Spring.GetSelectedUnits() or {}
	local counts = {}
	for _, uID in ipairs(selectedUnits) do
		local uDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(uID)
		if uDefID and UnitDefs and UnitDefs[uDefID] then
			local name = UnitDefs[uDefID].name
			counts[name] = (counts[name] or 0) + 1
		end
	end
	local selParts = {}
	for name, count in pairs(counts) do
		selParts[#selParts + 1] = name .. " x" .. count
	end
	local selectedSummary = table.concat(selParts, ", ")
	if #selectedUnits == 0 then
		selectedSummary = "none"
	end

	-- Active command
	local activeCmdStr = "none"
	if type(Spring.GetActiveCommand) == "function" then
		local activeCmdID, activeCmdType, activeCmdName = Spring.GetActiveCommand()
		activeCmdStr = activeCmdName or (activeCmdID and tostring(activeCmdID)) or "none"
	end

	-- Update lastClickSnapshot
	lastClickSnapshot.button = button
	lastClickSnapshot.eventType = eventType
	lastClickSnapshot.screenX = x
	lastClickSnapshot.screenY = y
	lastClickSnapshot.worldX = wx
	lastClickSnapshot.worldY = wy
	lastClickSnapshot.worldZ = wz
	lastClickSnapshot.traceType = traceType or "none"
	lastClickSnapshot.traceID = traceID or "none"
	lastClickSnapshot.targetName = targetName
	lastClickSnapshot.mexDist = mexDist
	lastClickSnapshot.mexX = nearestMexX
	lastClickSnapshot.mexZ = nearestMexZ
	lastClickSnapshot.activeCmd = activeCmdStr
	lastClickSnapshot.selectedSummary = selectedSummary
	lastClickSnapshot.frame = getFrame()
	lastClickSnapshot.time = type(Spring.GetGameSeconds) == "function" and Spring.GetGameSeconds() or 0

	-- Spring.Echo on click
	local clickMsg = string.format(
		"[SmartXMouseAudit] Mouse%s button=%d screen=%d,%d trace=%s target=%s name=%s world=%s mexDist=%s selected={%s} activeCmd=%s",
		eventType == "press" and "Press" or "Release",
		button,
		x, y,
		tostring(traceType or "none"),
		tostring(traceID or "none"),
		targetName,
		wx and string.format("%.0f,%.0f,%.0f", wx, wy, wz) or "none",
		tostring(mexDist),
		selectedSummary,
		activeCmdStr
	)
	Spring.Echo(clickMsg)
end

local function InitializeUnsafe()
	Spring.Echo("[SmartXMouseAudit] Initialized Controller SmartX Mouse Audit Widget v" .. versionNumber)
end

function widget:Initialize()
	safeCall("Initialize", InitializeUnsafe)
end

local function ShutdownUnsafe()
	Spring.Echo("[SmartXMouseAudit] Shutdown Controller SmartX Mouse Audit Widget")
end

function widget:Shutdown()
	safeCall("Shutdown", ShutdownUnsafe)
end

local function MousePressUnsafe(x, y, button)
	CaptureClickSnapshot(x, y, button, "press")
	return false -- propagate click
end

function widget:MousePress(x, y, button)
	local result = safeCall("MousePress", MousePressUnsafe, x, y, button)
	return (result ~= nil) and result or false
end

local function MouseReleaseUnsafe(x, y, button)
	CaptureClickSnapshot(x, y, button, "release")
	return false -- propagate click
end

function widget:MouseRelease(x, y, button)
	local result = safeCall("MouseRelease", MouseReleaseUnsafe, x, y, button)
	return (result ~= nil) and result or false
end

local function UnitCommandUnsafe(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag)
	-- Filter only for selected units to audit the exact actions resulting from player context selection clicks
	local isSelected = false
	local selectedUnits = type(Spring.GetSelectedUnits) == "function" and Spring.GetSelectedUnits() or {}
	for _, uID in ipairs(selectedUnits) do
		if uID == unitID then
			isSelected = true
			break
		end
	end

	if not isSelected then
		return
	end

	local unitName = "unknown"
	if unitDefID and UnitDefs and UnitDefs[unitDefID] then
		unitName = UnitDefs[unitDefID].name
	end

	local cmdName = "unknown"
	if CMD and CMD[cmdID] then
		cmdName = CMD[cmdID]
	elseif cmdID < 0 and UnitDefs and UnitDefs[-cmdID] then
		cmdName = "Build " .. UnitDefs[-cmdID].name
	end

	-- Decode options
	local opts = {
		shift = false,
		alt = false,
		ctrl = false,
		meta = false,
		right = false,
	}
	if type(cmdOpts) == "number" then
		opts.shift = (math.floor(cmdOpts / 1) % 2 == 1)
		opts.ctrl = (math.floor(cmdOpts / 2) % 2 == 1)
		opts.alt = (math.floor(cmdOpts / 4) % 2 == 1)
		opts.meta = (math.floor(cmdOpts / 8) % 2 == 1)
		opts.right = (math.floor(cmdOpts / 16) % 2 == 1)
	elseif type(cmdOpts) == "table" then
		for _, o in ipairs(cmdOpts) do
			if o == "shift" then opts.shift = true end
			if o == "ctrl" then opts.ctrl = true end
			if o == "alt" then opts.alt = true end
			if o == "meta" then opts.meta = true end
			if o == "right" then opts.right = true end
		end
	end

	local currentFrame = getFrame()

	-- Match linked click
	local linkedClickStr = "none"
	local timeDiff = 999999
	if lastClickSnapshot.frame then
		timeDiff = currentFrame - lastClickSnapshot.frame
		-- Accept click as linked if within 30 frames (1 second) of command dispatch
		if timeDiff >= 0 and timeDiff <= 30 then
			linkedClickStr = string.format("button%d_%s", lastClickSnapshot.button, lastClickSnapshot.eventType)
		end
	end

	local paramsStr = serializeTable(cmdParams)

	-- Echo to chat console
	local cmdMsg = string.format(
		"[SmartXMouseAudit] UnitCommand frame=%d unit=%d %s cmdID=%d cmdName=%s params=%s opts={shift=%s,alt=%s,ctrl=%s,meta=%s} linkedClick=%s trace=%s target=%s",
		currentFrame,
		unitID,
		unitName,
		cmdID,
		cmdName,
		paramsStr,
		tostring(opts.shift),
		tostring(opts.alt),
		tostring(opts.ctrl),
		tostring(opts.meta),
		linkedClickStr,
		tostring(lastClickSnapshot.traceType or "none"),
		tostring(lastClickSnapshot.traceID or "none")
	)
	Spring.Echo(cmdMsg)

	-- Save state for overlay
	lastObservedCommand.cmdID = cmdID
	lastObservedCommand.cmdName = cmdName
	lastObservedCommand.params = cmdParams
	lastObservedCommand.opts = opts
	lastObservedCommand.frame = currentFrame
	lastObservedCommand.unitDefName = unitName
	lastObservedCommand.unitID = unitID
	lastObservedCommand.linkMatch = (linkedClickStr ~= "none")
end

function widget:UnitCommand(...)
	safeCall("UnitCommand", UnitCommandUnsafe, ...)
end

local function DrawScreenUnsafe()
	local vsx, vsy = Spring.GetViewGeometry()
	if not vsx or not vsy then return end

	-- Overlay Position: Top Right
	local w = 260
	local h = 210
	local x1 = vsx - w - 20
	local y1 = vsy - h - 100

	-- Dark Backing
	gl.Color(0.08, 0.08, 0.1, 0.85)
	gl.Rect(x1, y1, x1 + w, y1 + h)

	-- Sleek Blue Border (using gl.BeginEnd with GL.LINE_LOOP)
	gl.LineWidth(2.0)
	gl.Color(0.25, 0.75, 1.0, 0.7)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(x1, y1)
		gl.Vertex(x1 + w, y1)
		gl.Vertex(x1 + w, y1 + h)
		gl.Vertex(x1, y1 + h)
	end)

	-- Fetch current hover under mouse cursor
	local mx, my = Spring.GetMouseState()
	local traceType, traceID = "none", "none"
	local wx, wy, wz
	local targetName = "none"
	if mx and my and type(Spring.TraceScreenRay) == "function" then
		local tType, tID = Spring.TraceScreenRay(mx, my)
		if tType then
			traceType = tType
			traceID = tID or "none"
		end
		local _, worldPosition = Spring.TraceScreenRay(mx, my, true)
		if type(worldPosition) == "table" then
			wx, wy, wz = worldPosition[1], worldPosition[2], worldPosition[3]
		end

		if traceType == "unit" and tID then
			local unitDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(tID)
			if unitDefID and UnitDefs and UnitDefs[unitDefID] then
				targetName = UnitDefs[unitDefID].name
			end
		elseif traceType == "feature" and tID then
			local featureDefID = type(Spring.GetFeatureDefID) == "function" and Spring.GetFeatureDefID(tID)
			if featureDefID and FeatureDefs and FeatureDefs[featureDefID] then
				targetName = FeatureDefs[featureDefID].name
			end
		end
	end

	-- Nearest Mex Spot Distance
	local mexDistStr = "mex API unavailable"
	if wx and wz then
		if WG.resource_spot_finder and type(WG.resource_spot_finder.GetClosestMexSpot) == "function" then
			local spot = WG.resource_spot_finder.GetClosestMexSpot(wx, wz)
			if spot and type(spot) == "table" then
				local nearestMexX = spot.x or spot[1]
				local nearestMexZ = spot.z or spot[3]
				if nearestMexX and nearestMexZ then
					local dx = wx - nearestMexX
					local dz = wz - nearestMexZ
					mexDistStr = string.format("%d elmo", math.floor(math.sqrt(dx*dx + dz*dz)))
				else
					mexDistStr = "spot error"
				end
			else
				mexDistStr = "no spot found"
			end
		end
	else
		mexDistStr = "no ground target"
	end

	-- Selected Unit Count
	local selectedUnits = type(Spring.GetSelectedUnits) == "function" and Spring.GetSelectedUnits() or {}
	local selCount = #selectedUnits

	-- Active command
	local activeCmdStr = "none"
	if type(Spring.GetActiveCommand) == "function" then
		local activeCmdID, activeCmdType, activeCmdName = Spring.GetActiveCommand()
		activeCmdStr = activeCmdName or (activeCmdID and tostring(activeCmdID)) or "none"
	end

	-- Formatting Overlay Text
	gl.Color(1, 1, 1, 1)
	local fontSize = 12
	local textY = y1 + h - 20
	local textX = x1 + 10
	local leading = 15

	-- Title
	gl.Text("\255\064\192\255SmartX Mouse Audit\255\255\255\255", textX, textY, fontSize, "o")
	textY = textY - leading - 5

	-- Hover Target
	local hoverStr = string.format("Hover: %s (%s)", traceType, targetName)
	if traceType ~= "none" and traceID ~= "none" then
		hoverStr = hoverStr .. " ID=" .. tostring(traceID)
	end
	gl.Text(hoverStr, textX, textY, fontSize, "o")
	textY = textY - leading

	-- World Pos
	local worldStr = "World: none"
	if wx then
		worldStr = string.format("World: %.0f, %.0f, %.0f", wx, wy, wz)
	end
	gl.Text(worldStr, textX, textY, fontSize, "o")
	textY = textY - leading

	-- Nearest Mex Spot Distance
	gl.Text("Mex Distance: " .. mexDistStr, textX, textY, fontSize, "o")
	textY = textY - leading

	-- Selected Units
	gl.Text("Selected Units: " .. tostring(selCount), textX, textY, fontSize, "o")
	textY = textY - leading

	-- Active Command
	gl.Text("Active Cmd: " .. activeCmdStr, textX, textY, fontSize, "o")
	textY = textY - leading - 5

	-- Last click snapshot
	local lastClickStr = "Last Click: none"
	if lastClickSnapshot.button then
		lastClickStr = string.format(
			"Last Click: button%d %s at %d,%d",
			lastClickSnapshot.button,
			lastClickSnapshot.eventType,
			lastClickSnapshot.screenX or 0,
			lastClickSnapshot.screenY or 0
		)
	end
	gl.Text(lastClickStr, textX, textY, fontSize, "o")
	textY = textY - leading

	-- Last UnitCommand
	local lastCmdStr = "Last Cmd: none"
	if lastObservedCommand.cmdID then
		local paramsCount = lastObservedCommand.params and #lastObservedCommand.params or 0
		lastCmdStr = string.format(
			"Last Cmd: %s (%d) params=%d",
			lastObservedCommand.cmdName or "unknown",
			lastObservedCommand.cmdID,
			paramsCount
		)
	end
	gl.Text(lastCmdStr, textX, textY, fontSize, "o")
	textY = textY - leading

	-- Error reporting in overlay / Comparison Note
	if lastError then
		gl.Text("\255\255\000\000Err: " .. string.sub(lastError, 1, 35) .. "\255\255\255\255", textX, textY, fontSize, "o")
	else
		local compNote = "Comparison: waiting for click..."
		if lastObservedCommand.cmdID then
			if lastObservedCommand.linkMatch then
				compNote = "\255\000\255\000Linked to click! Command validated.\255\255\255\255"
			else
				compNote = "\255\255\128\000Unlinked command observed.\255\255\255\255"
			end
		end
		gl.Text(compNote, textX, textY, fontSize, "o")
	end
end

function widget:DrawScreen()
	safeCall("DrawScreen", DrawScreenUnsafe)
end
