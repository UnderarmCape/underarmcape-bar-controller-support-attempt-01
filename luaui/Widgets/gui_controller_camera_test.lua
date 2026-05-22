local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Controller Camera Test",
		desc = "Prototype Xbox controller left-stick camera panning",
		author = "Kailil / Codex",
		date = "2026-05-22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end

local spGetAvailableControllers = Spring.GetAvailableControllers
local spGetControllerState = Spring.GetControllerState
local spGetCameraState = Spring.GetCameraState
local spSetCameraState = Spring.SetCameraState
local spGetCameraVectors = Spring.GetCameraVectors

local glText = gl.Text

local mathAbs = math.abs
local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt

local DEADZONE = 8000
local AXIS_MAX = 32767
local PAN_SPEED = 1800

local apiAvailable = false
local controllerName = "none"
local controllerInstanceId = nil
local normalizedLeftX = 0
local normalizedLeftY = 0
local panActive = false

local mapSizeX = Game and Game.mapSizeX or 0
local mapSizeZ = Game and Game.mapSizeZ or 0

local function clamp(value, minValue, maxValue)
	return mathMin(maxValue, mathMax(minValue, value))
end

local function normalizeAxis(value)
	value = tonumber(value) or 0

	local magnitude = mathAbs(value)
	if magnitude < DEADZONE then
		return 0
	end

	local sign = value < 0 and -1 or 1
	local normalized = (magnitude - DEADZONE) / (AXIS_MAX - DEADZONE)
	return sign * clamp(normalized, 0, 1)
end

local function getFirstController(controllers)
	if type(controllers) ~= "table" then
		return nil
	end

	if type(controllers[1]) == "table" then
		return controllers[1]
	end

	local _, controller = next(controllers)
	if type(controller) == "table" then
		return controller
	end

	return nil
end

local function normalizeHorizontalVector(vector)
	if type(vector) ~= "table" then
		return nil, nil
	end

	local x = tonumber(vector[1]) or 0
	local z = tonumber(vector[3]) or 0
	local length = mathSqrt((x * x) + (z * z))

	if length <= 0.001 then
		return nil, nil
	end

	return x / length, z / length
end

local function getCameraPanDelta(leftX, leftY, distance)
	local cameraVectors = spGetCameraVectors and spGetCameraVectors()

	if type(cameraVectors) == "table" then
		local rightX, rightZ = normalizeHorizontalVector(cameraVectors.right)
		local forwardX, forwardZ = normalizeHorizontalVector(cameraVectors.forward)

		if rightX and forwardX then
			local forwardInput = -leftY
			return
				((leftX * rightX) + (forwardInput * forwardX)) * distance,
				((leftX * rightZ) + (forwardInput * forwardZ)) * distance
		end
	end

	return leftX * distance, leftY * distance
end

local function pollFirstController()
	local ok, controllers = pcall(spGetAvailableControllers)
	if not ok then
		controllerName = "GetAvailableControllers failed"
		controllerInstanceId = nil
		return nil
	end

	local controller = getFirstController(controllers)
	if not controller then
		controllerName = "none"
		controllerInstanceId = nil
		return nil
	end

	controllerName = tostring(controller.name or "unknown")
	controllerInstanceId = controller.instanceId
	return controller
end

local function pollControllerState(instanceId)
	if instanceId == nil then
		return nil
	end

	local ok, state = pcall(spGetControllerState, instanceId)
	if not ok or type(state) ~= "table" then
		return nil
	end

	return state
end

local function panCamera(leftX, leftY, dt)
	local cameraState = spGetCameraState and spGetCameraState()
	if type(cameraState) ~= "table" or cameraState.px == nil or cameraState.pz == nil then
		return
	end

	local distance = PAN_SPEED * (dt or 0)
	local deltaX, deltaZ = getCameraPanDelta(leftX, leftY, distance)

	cameraState.px = cameraState.px + deltaX
	cameraState.pz = cameraState.pz + deltaZ

	if mapSizeX > 0 then
		cameraState.px = clamp(cameraState.px, 0, mapSizeX)
	end
	if mapSizeZ > 0 then
		cameraState.pz = clamp(cameraState.pz, 0, mapSizeZ)
	end

	spSetCameraState(cameraState, 0)
end

function widget:Initialize()
	apiAvailable = type(spGetAvailableControllers) == "function" and type(spGetControllerState) == "function"
end

function widget:Update(dt)
	panActive = false

	if not apiAvailable then
		return
	end

	local controller = pollFirstController()
	if not controller then
		normalizedLeftX = 0
		normalizedLeftY = 0
		return
	end

	local state = pollControllerState(controller.instanceId)
	if not state or type(state.axes) ~= "table" then
		normalizedLeftX = 0
		normalizedLeftY = 0
		return
	end

	normalizedLeftX = normalizeAxis(state.axes[0])
	normalizedLeftY = normalizeAxis(state.axes[1])
	panActive = normalizedLeftX ~= 0 or normalizedLeftY ~= 0

	if panActive then
		panCamera(normalizedLeftX, normalizedLeftY, dt)
	end
end

function widget:DrawScreen()
	local x = 20
	local y = 500
	local lineHeight = 18

	glText("Controller Camera Test", x, y, 14, "o")
	y = y - lineHeight

	glText("API: " .. (apiAvailable and "available" or "missing"), x, y, 12, "o")
	y = y - lineHeight

	glText("Controller: " .. tostring(controllerName), x, y, 12, "o")
	y = y - lineHeight

	glText("instanceId: " .. tostring(controllerInstanceId), x, y, 12, "o")
	y = y - lineHeight

	glText(string.format("left stick: x=%.3f y=%.3f", normalizedLeftX, normalizedLeftY), x, y, 12, "o")
	y = y - lineHeight

	glText("camera pan active: " .. (panActive and "yes" or "no"), x, y, 12, "o")
end
