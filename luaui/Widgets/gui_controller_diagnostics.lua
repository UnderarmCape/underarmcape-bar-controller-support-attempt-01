local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Controller Diagnostics",
		desc    = "Diagnoses controller API availability and controller state polling",
		author  = "UnderarmCape / Kailil",
		date    = "2026-05-21",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false,
	}
end

local spEcho = Spring.Echo
local spGetGameFrame = Spring.GetGameFrame

local trackedControllerInstanceId = nil
local firstControllerName = "none"
local controllerCount = 0

local lastStateSummary = "no state yet"
local lastPollFrame = 0
local pollIntervalFrames = 30

local apiStatus = {
	GetAvailableControllers = false,
	GetControllerState = false,
	ConnectController = false,
	DisconnectController = false,
}

local function log(...)
	spEcho("[ControllerDiag]", ...)
end

local function safeToString(value, depth)
	depth = depth or 0

	if type(value) ~= "table" then
		return tostring(value)
	end

	if depth > 2 then
		return "{...}"
	end

	local parts = {}
	for k, v in pairs(value) do
		parts[#parts + 1] = tostring(k) .. "=" .. safeToString(v, depth + 1)
	end

	return "{" .. table.concat(parts, ", ") .. "}"
end

local function updateApiStatus()
	apiStatus.GetAvailableControllers = type(Spring.GetAvailableControllers) == "function"
	apiStatus.GetControllerState = type(Spring.GetControllerState) == "function"
	apiStatus.ConnectController = type(Spring.ConnectController) == "function"
	apiStatus.DisconnectController = type(Spring.DisconnectController) == "function"
end

local function logApiStatus()
	log("Controller API status:")
	log("Spring.GetAvailableControllers:", apiStatus.GetAvailableControllers and "yes" or "no")
	log("Spring.GetControllerState:", apiStatus.GetControllerState and "yes" or "no")
	log("Spring.ConnectController:", apiStatus.ConnectController and "yes" or "no")
	log("Spring.DisconnectController:", apiStatus.DisconnectController and "yes" or "no")
end

local function summarizeButtons(buttons)
	if type(buttons) ~= "table" then
		return "buttons=nil"
	end

	local pressed = {}

	for buttonId, value in pairs(buttons) do
		if value ~= 0 and value ~= false and value ~= nil then
			pressed[#pressed + 1] = tostring(buttonId) .. "=" .. tostring(value)
		end
	end

	if #pressed == 0 then
		return "buttons=none"
	end

	return "buttons={" .. table.concat(pressed, ", ") .. "}"
end

local function summarizeAxes(axes)
	if type(axes) ~= "table" then
		return "axes=nil"
	end

	local active = {}

	for axisId, value in pairs(axes) do
		local numericValue = tonumber(value) or 0
		if math.abs(numericValue) > 8000 then
			active[#active + 1] = tostring(axisId) .. "=" .. tostring(numericValue)
		end
	end

	if #active == 0 then
		return "axes=neutral"
	end

	return "axes={" .. table.concat(active, ", ") .. "}"
end

local function refreshAvailableControllers()
	controllerCount = 0
	trackedControllerInstanceId = nil
	firstControllerName = "none"

	if not apiStatus.GetAvailableControllers then
		log("Spring.GetAvailableControllers is not available. Current engine probably does not expose controller Lua API.")
		return
	end

	local ok, controllers = pcall(Spring.GetAvailableControllers)

	if not ok then
		log("Spring.GetAvailableControllers call failed:", tostring(controllers))
		return
	end

	if type(controllers) ~= "table" then
		log("Spring.GetAvailableControllers returned non-table:", tostring(controllers))
		return
	end

	for index, controller in pairs(controllers) do
		controllerCount = controllerCount + 1

		local instanceId = controller and controller.instanceId
		local deviceId = controller and controller.deviceId
		local name = controller and controller.name or "unknown"

		log(
			"Controller found:",
			"index=" .. tostring(index),
			"instanceId=" .. tostring(instanceId),
			"deviceId=" .. tostring(deviceId),
			"name=" .. tostring(name)
		)

		if not trackedControllerInstanceId and instanceId then
			trackedControllerInstanceId = instanceId
			firstControllerName = name
		end
	end

	if controllerCount == 0 then
		log("No controllers returned by Spring.GetAvailableControllers.")
	else
		log("Controller count:", controllerCount)
		log("Tracking first controller:", trackedControllerInstanceId, firstControllerName)
	end
end

local function pollTrackedControllerState()
	if not apiStatus.GetControllerState then
		return
	end

	if not trackedControllerInstanceId then
		return
	end

	local ok, state = pcall(Spring.GetControllerState, trackedControllerInstanceId)

	if not ok then
		lastStateSummary = "GetControllerState failed: " .. tostring(state)
		log(lastStateSummary)
		return
	end

	if type(state) ~= "table" then
		lastStateSummary = "state=nil"
		return
	end

	local axesSummary = summarizeAxes(state.axes)
	local buttonsSummary = summarizeButtons(state.buttons)

	lastStateSummary =
		"instanceId=" .. tostring(state.instanceId) ..
		" name=" .. tostring(state.name or firstControllerName or "unknown") ..
		" " .. axesSummary ..
		" " .. buttonsSummary

	log("Controller state:", lastStateSummary)
end

function widget:Initialize()
	log("Initializing controller diagnostics widget.")

	updateApiStatus()
	logApiStatus()

	if not apiStatus.GetAvailableControllers and not apiStatus.GetControllerState then
		log("Read-only controller API unavailable. This is expected on the current shipped BAR engine.")
		log("Expected after modified Recoil engine is installed: GetAvailableControllers=yes, GetControllerState=yes.")
		return
	end

	refreshAvailableControllers()
end

function widget:Shutdown()
	log("Shutting down controller diagnostics widget.")

	if trackedControllerInstanceId and apiStatus.DisconnectController then
		log("DisconnectController exists, but diagnostics widget will not disconnect automatically in read-only test mode.")
	end
end

function widget:Update()
	local frame = spGetGameFrame()

	if frame - lastPollFrame < pollIntervalFrames then
		return
	end

	lastPollFrame = frame

	updateApiStatus()

	if controllerCount == 0 and apiStatus.GetAvailableControllers then
		refreshAvailableControllers()
	end

	pollTrackedControllerState()
end

function widget:DrawScreen()
	local x = 20
	local y = 420
	local lineHeight = 18

	gl.Text("Controller Diagnostics", x, y, 14, "o")
	y = y - lineHeight

	gl.Text("GetAvailableControllers: " .. (apiStatus.GetAvailableControllers and "yes" or "no"), x, y, 12, "o")
	y = y - lineHeight

	gl.Text("GetControllerState: " .. (apiStatus.GetControllerState and "yes" or "no"), x, y, 12, "o")
	y = y - lineHeight

	gl.Text("ConnectController: " .. (apiStatus.ConnectController and "yes" or "no"), x, y, 12, "o")
	y = y - lineHeight

	gl.Text("DisconnectController: " .. (apiStatus.DisconnectController and "yes" or "no"), x, y, 12, "o")
	y = y - lineHeight

	gl.Text("Controller count: " .. tostring(controllerCount), x, y, 12, "o")
	y = y - lineHeight

	gl.Text("First controller: " .. tostring(firstControllerName), x, y, 12, "o")
	y = y - lineHeight

	gl.Text("Last state: " .. tostring(lastStateSummary), x, y, 12, "o")
end

function widget:ControllerAdded(deviceId)
	log("ControllerAdded:", deviceId)
	refreshAvailableControllers()
end

function widget:ControllerRemoved(instanceId)
	log("ControllerRemoved:", instanceId)

	if trackedControllerInstanceId == instanceId then
		trackedControllerInstanceId = nil
		firstControllerName = "none"
		lastStateSummary = "tracked controller removed"
	end

	refreshAvailableControllers()
end

function widget:ControllerConnected(instanceId)
	log("ControllerConnected:", instanceId)
	refreshAvailableControllers()
end

function widget:ControllerDisconnected(instanceId)
	log("ControllerDisconnected:", instanceId)

	if trackedControllerInstanceId == instanceId then
		trackedControllerInstanceId = nil
		firstControllerName = "none"
		lastStateSummary = "tracked controller disconnected"
	end

	refreshAvailableControllers()
end

function widget:ControllerRemapped(instanceId)
	log("ControllerRemapped:", instanceId)
	refreshAvailableControllers()
end

function widget:ControllerButtonDown(instanceId, buttonId, state, name)
	log(
		"ButtonDown:",
		"instanceId=" .. tostring(instanceId),
		"buttonId=" .. tostring(buttonId),
		"state=" .. tostring(state),
		"name=" .. tostring(name)
	)
end

function widget:ControllerButtonUp(instanceId, buttonId, state, name)
	log(
		"ButtonUp:",
		"instanceId=" .. tostring(instanceId),
		"buttonId=" .. tostring(buttonId),
		"state=" .. tostring(state),
		"name=" .. tostring(name)
	)
end

function widget:ControllerAxisMotion(instanceId, axisId, value, name)
	log(
		"AxisMotion:",
		"instanceId=" .. tostring(instanceId),
		"axisId=" .. tostring(axisId),
		"value=" .. tostring(value),
		"name=" .. tostring(name)
	)
end