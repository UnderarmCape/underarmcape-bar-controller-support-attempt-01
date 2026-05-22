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
local spGetGroundHeight = Spring.GetGroundHeight

local glText = gl.Text

local mathAbs = math.abs
local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt

local DEADZONE = 8000
local TRIGGER_DEADZONE = 3000
local AXIS_MAX = 32767
local PAN_SPEED = 1800
local ZOOM_SPEED = 1200
local ZOOM_SCALE_SPEED = 0.9
local MIN_SPRING_DISTANCE = 20
local MIN_OVERHEAD_HEIGHT = 60
local MIN_CAMERA_HEIGHT = 80

local apiAvailable = false
local controllerName = "none"
local controllerInstanceId = nil
local normalizedLeftX = 0
local normalizedLeftY = 0
local normalizedLeftTrigger = 0
local normalizedRightTrigger = 0
local panActive = false
local zoomActive = false
local cameraMode = "unknown"
local cameraModeId = "?"
local cameraFieldSummary = "camera state unavailable"
local zoomMethod = "none"

local mapSizeX = Game and Game.mapSizeX or 0
local mapSizeZ = Game and Game.mapSizeZ or 0
local maxCameraDistance = mathMax(mapSizeX, mapSizeZ, 1000) * 1.5

local function clamp(value, minValue, maxValue)
	return mathMin(maxValue, mathMax(minValue, value))
end

local function formatNumber(value)
	if type(value) ~= "number" then
		return "-"
	end

	return string.format("%.1f", value)
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

local function normalizeTrigger(value)
	value = tonumber(value) or 0

	if value < TRIGGER_DEADZONE then
		return 0
	end

	return clamp((value - TRIGGER_DEADZONE) / (AXIS_MAX - TRIGGER_DEADZONE), 0, 1)
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

local function updateCameraDebug(cameraState)
	if type(cameraState) ~= "table" then
		cameraMode = "unknown"
		cameraModeId = "?"
		cameraFieldSummary = "camera state unavailable"
		return
	end

	cameraMode = tostring(cameraState.name or "unknown")
	cameraModeId = tostring(cameraState.mode or "?")
	cameraFieldSummary = string.format(
		"px=%s py=%s pz=%s dist=%s height=%s oldHeight=%s fov=%s",
		formatNumber(cameraState.px),
		formatNumber(cameraState.py),
		formatNumber(cameraState.pz),
		formatNumber(cameraState.dist),
		formatNumber(cameraState.height),
		formatNumber(cameraState.oldHeight),
		formatNumber(cameraState.fov)
	)
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

local function applySpringZoom(cameraState, zoomInput, dt)
	if type(cameraState.dist) ~= "number" then
		return false
	end

	local scale = 1 - (zoomInput * ZOOM_SCALE_SPEED * (dt or 0))
	cameraState.dist = clamp(cameraState.dist * scale, MIN_SPRING_DISTANCE, maxCameraDistance)
	zoomMethod = "spring dist"
	return true
end

local function applyOverheadZoom(cameraState, zoomInput, dt)
	if type(cameraState.height) ~= "number" then
		return false
	end

	local scale = 1 - (zoomInput * ZOOM_SCALE_SPEED * (dt or 0))
	cameraState.height = clamp(cameraState.height * scale, MIN_OVERHEAD_HEIGHT, maxCameraDistance)
	zoomMethod = "overhead height"
	return true
end

local function applyFallbackHeightZoom(cameraState, zoomInput, dt)
	if type(cameraState.py) ~= "number" then
		return false
	end

	cameraState.py = cameraState.py - (zoomInput * ZOOM_SPEED * (dt or 0))

	if spGetGroundHeight and type(cameraState.px) == "number" and type(cameraState.pz) == "number" then
		local groundHeight = spGetGroundHeight(cameraState.px, cameraState.pz)
		cameraState.py = mathMax(cameraState.py, groundHeight + MIN_CAMERA_HEIGHT)
	end

	zoomMethod = "py fallback"
	return true
end

local function applyZoom(cameraState, zoomInput, dt)
	if zoomInput == 0 then
		zoomMethod = "none"
		return
	end

	if cameraState.mode == 2 or cameraState.name == "spring" then
		if applySpringZoom(cameraState, zoomInput, dt) then
			return
		end
	end

	if cameraState.mode == 1 or cameraState.name == "ta" then
		if applyOverheadZoom(cameraState, zoomInput, dt) then
			return
		end
	end

	if not applyFallbackHeightZoom(cameraState, zoomInput, dt) then
		zoomMethod = "unsupported"
	end
end

local function applyCameraInput(leftX, leftY, zoomInput, dt)
	local cameraState = spGetCameraState and spGetCameraState()
	if type(cameraState) ~= "table" or cameraState.px == nil or cameraState.pz == nil then
		updateCameraDebug(cameraState)
		return
	end

	local distance = PAN_SPEED * (dt or 0)
	local deltaX, deltaZ = getCameraPanDelta(leftX, leftY, distance)

	cameraState.px = cameraState.px + deltaX
	cameraState.pz = cameraState.pz + deltaZ

	applyZoom(cameraState, zoomInput, dt)

	if mapSizeX > 0 then
		cameraState.px = clamp(cameraState.px, 0, mapSizeX)
	end
	if mapSizeZ > 0 then
		cameraState.pz = clamp(cameraState.pz, 0, mapSizeZ)
	end

	spSetCameraState(cameraState, 0)
	updateCameraDebug(cameraState)
end

function widget:Initialize()
	apiAvailable = type(spGetAvailableControllers) == "function" and type(spGetControllerState) == "function"
end

function widget:Update(dt)
	panActive = false
	zoomActive = false

	if not apiAvailable then
		return
	end

	local controller = pollFirstController()
	if not controller then
		normalizedLeftX = 0
		normalizedLeftY = 0
		normalizedLeftTrigger = 0
		normalizedRightTrigger = 0
		return
	end

	local state = pollControllerState(controller.instanceId)
	if not state or type(state.axes) ~= "table" then
		normalizedLeftX = 0
		normalizedLeftY = 0
		normalizedLeftTrigger = 0
		normalizedRightTrigger = 0
		return
	end

	normalizedLeftX = normalizeAxis(state.axes[0])
	normalizedLeftY = normalizeAxis(state.axes[1])
	normalizedLeftTrigger = normalizeTrigger(state.axes[4])
	normalizedRightTrigger = normalizeTrigger(state.axes[5])
	panActive = normalizedLeftX ~= 0 or normalizedLeftY ~= 0
	local zoomInput = normalizedRightTrigger - normalizedLeftTrigger
	zoomActive = zoomInput ~= 0

	if panActive or zoomActive then
		applyCameraInput(normalizedLeftX, normalizedLeftY, zoomInput, dt)
	elseif spGetCameraState then
		zoomMethod = "none"
		updateCameraDebug(spGetCameraState())
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
	y = y - lineHeight

	glText(string.format("triggers: LT=%.3f RT=%.3f", normalizedLeftTrigger, normalizedRightTrigger), x, y, 12, "o")
	y = y - lineHeight

	glText("zoom active: " .. (zoomActive and "yes" or "no"), x, y, 12, "o")
	y = y - lineHeight

	glText("camera: " .. cameraMode .. " mode=" .. cameraModeId .. " zoom=" .. zoomMethod, x, y, 12, "o")
	y = y - lineHeight

	glText(cameraFieldSummary, x, y, 12, "o")
end
