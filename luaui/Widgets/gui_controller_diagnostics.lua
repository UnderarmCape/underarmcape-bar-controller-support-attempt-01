local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Controller Diagnostics",
		desc    = "Logs controller add/connect/button/axis events for debugging",
		author  = "UnderarmCape / Kailil",
		date    = "2026-05-21",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false,
	}
end

local spEcho = Spring.Echo

local connectedController = nil
local reportState = true
local stateTimer = 0
local axisLogTimer = 0
local axisLogInterval = 0.15 -- prevents analog sticks from spamming too hard

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

local function log(...)
	spEcho("[ControllerDiag]", ...)
end

local function hasControllerApi()
	return Spring.GetAvailableControllers
		and Spring.ConnectController
		and Spring.DisconnectController
		and Spring.GetControllerState
end

local function connectFirstAvailableController()
	if not Spring.GetAvailableControllers then
		log("Spring.GetAvailableControllers is not available. Controller API may not exist in this engine build.")
		return
	end

	local availableControllers = Spring.GetAvailableControllers()

	if not availableControllers or next(availableControllers) == nil then
		log("No available controllers found.")
		return
	end

	log("Available controllers:", safeToString(availableControllers))

	for _, controller in pairs(availableControllers) do
		if controller.instanceId then
			connectedController = controller.instanceId
			log("Using already-connected controller:", controller.instanceId, controller.name or "unknown")
			return
		end
	end

	if Spring.ConnectController then
		local deviceId, controller = next(availableControllers)
		if deviceId and controller then
			log("Connecting to controller device:", deviceId, controller.name or "unknown")
			Spring.ConnectController(deviceId)
		end
	else
		log("Spring.ConnectController is not available.")
	end
end

function widget:Initialize()
	log("Initializing controller diagnostics widget.")

	if not hasControllerApi() then
		log("Controller API incomplete or unavailable.")
		log("GetAvailableControllers:", Spring.GetAvailableControllers and "yes" or "no")
		log("ConnectController:", Spring.ConnectController and "yes" or "no")
		log("DisconnectController:", Spring.DisconnectController and "yes" or "no")
		log("GetControllerState:", Spring.GetControllerState and "yes" or "no")
	end

	connectFirstAvailableController()
end

function widget:Shutdown()
	log("Shutting down controller diagnostics widget.")

	if connectedController and Spring.DisconnectController then
		log("Disconnecting controller:", connectedController)
		Spring.DisconnectController(connectedController)
	end
end

function widget:Update(dt)
	stateTimer = stateTimer + dt
	axisLogTimer = axisLogTimer + dt

	if reportState and connectedController and Spring.GetControllerState and stateTimer >= 1.0 then
		stateTimer = 0

		local state = Spring.GetControllerState(connectedController)
		log("Controller state:", safeToString(state))
	end
end

function widget:ControllerAdded(deviceId)
	log("ControllerAdded:", deviceId)

	if not connectedController and Spring.ConnectController then
		log("Attempting to connect to added controller:", deviceId)
		Spring.ConnectController(deviceId)
	end
end

function widget:ControllerRemoved(instanceId)
	log("ControllerRemoved:", instanceId)

	if connectedController == instanceId then
		connectedController = nil
		log("Connected controller was removed.")
	end
end

function widget:ControllerConnected(instanceId)
	log("ControllerConnected:", instanceId)

	if not connectedController then
		connectedController = instanceId
		log("Now tracking controller:", instanceId)
	end
end

function widget:ControllerDisconnected(instanceId)
	log("ControllerDisconnected:", instanceId)

	if connectedController == instanceId then
		connectedController = nil
		log("Tracked controller disconnected.")
	end
end

function widget:ControllerRemapped(instanceId)
	log("ControllerRemapped:", instanceId)
end

function widget:ControllerButtonDown(instanceId, buttonId, state, name)
	log("ButtonDown:", "instanceId=" .. tostring(instanceId), "buttonId=" .. tostring(buttonId), "state=" .. tostring(state), "name=" .. tostring(name))

	if not connectedController then
		connectedController = instanceId
		log("Auto-tracking controller from button event:", instanceId)
	end
end

function widget:ControllerButtonUp(instanceId, buttonId, state, name)
	log("ButtonUp:", "instanceId=" .. tostring(instanceId), "buttonId=" .. tostring(buttonId), "state=" .. tostring(state), "name=" .. tostring(name))
end

function widget:ControllerAxisMotion(instanceId, axisId, value, name)
	if axisLogTimer < axisLogInterval then
		return
	end

	axisLogTimer = 0

	log("AxisMotion:", "instanceId=" .. tostring(instanceId), "axisId=" .. tostring(axisId), "value=" .. tostring(value), "name=" .. tostring(name))

	if not connectedController then
		connectedController = instanceId
		log("Auto-tracking controller from axis event:", instanceId)
	end
end