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
local spGetMouseState = Spring.GetMouseState
local spGetViewGeometry = Spring.GetViewGeometry
local spTraceScreenRay = Spring.TraceScreenRay

local glText = gl.Text

local mathAbs = math.abs
local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt
local mathCos = math.cos
local mathSin = math.sin
local mathPi = math.pi

local DEADZONE = 3000
local TRIGGER_DEADZONE = 3000
local AXIS_MAX = 32767
local PAN_SPEED = 2800
local FAST_PAN_MULTIPLIER = 2.75
local FAST_ZOOM_MULTIPLIER = 3.0
local DEBUG_EVENT_HOLD_SECONDS = 0.45
local ZOOM_SPEED = 3200
local ZOOM_SCALE_SPEED = 0.9
local ROTATION_SPEED = 3.0
local PITCH_SPEED = 3.0
local MIN_SPRING_DISTANCE = 20
local MIN_OVERHEAD_HEIGHT = 60
local MIN_CAMERA_HEIGHT = 80
local MIN_CAMERA_RX = 1.0
local MAX_CAMERA_RX = 3.05
local MAX_DIRECTION_PITCH_Y = 0.98
local RETICLE_RADIUS = 11
local RETICLE_GAP = 5
local RETICLE_LINE_LENGTH = 11
local RETICLE_SEGMENTS = 28
local DEBUG_PAGE_COUNT = 4
local DEBUG_PAGE_NAMES = {
	[1] = "Core Controls",
	[2] = "Reticle / World Target",
	[3] = "Buttons / Command Layer",
	[4] = "Camera State",
}

local XboxController = {
	axes = {
		leftStickX = 0,
		leftStickY = 1,
		rightStickX = 2,
		rightStickY = 3,
		leftTrigger = 4,
		rightTrigger = 5,
	},
	axisLabels = {
		leftStickX = "Left Stick X",
		leftStickY = "Left Stick Y",
		rightStickX = "Right Stick X",
		rightStickY = "Right Stick Y",
		leftTrigger = "LT",
		rightTrigger = "RT",
	},
	axisOrder = {
		"leftStickX",
		"leftStickY",
		"rightStickX",
		"rightStickY",
		"leftTrigger",
		"rightTrigger",
	},
	buttons = {
		A = 0,
		a = 0,
		B = 1,
		b = 1,
		X = 2,
		x = 2,
		Y = 3,
		y = 3,
		back = 4,
		view = 4,
		["Back/View"] = 4,
		guide = 5,
		start = 6,
		menu = 6,
		["Start/Menu"] = 6,
		leftStick = 7,
		leftStickClick = 7,
		["Left Stick Click"] = 7,
		rightStick = 8,
		rightStickClick = 8,
		["Right Stick Click"] = 8,
		LB = 9,
		lb = 9,
		leftBumper = 9,
		RB = 10,
		rb = 10,
		rightBumper = 10,
		dpadUp = 11,
		["D-pad Up"] = 11,
		dpadDown = 12,
		["D-pad Down"] = 12,
		dpadLeft = 13,
		["D-pad Left"] = 13,
		dpadRight = 14,
		["D-pad Right"] = 14,
	},
	buttonLabels = {
		[0] = "A",
		[1] = "B",
		[2] = "X",
		[3] = "Y",
		[4] = "Back/View",
		[5] = "Guide",
		[6] = "Start/Menu",
		[7] = "Left Stick Click",
		[8] = "Right Stick Click",
		[9] = "LB",
		[10] = "RB",
		[11] = "D-pad Up",
		[12] = "D-pad Down",
		[13] = "D-pad Left",
		[14] = "D-pad Right",
	},
	buttonOrder = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	commandLayerButtonOrder = { 0, 1, 2, 3, 9, 10, 11, 12, 13, 14 },
	previewButtonOrder = { 0, 1, 2, 3, 9, 10, 11, 12, 13, 14 },
	normalPreviewLabels = {
		[0] = "A = Select / Confirm placeholder",
		[1] = "B = Cancel / Back placeholder",
		[2] = "X = Context Action placeholder",
		[3] = "Y = Build / Menu placeholder",
		[9] = "LB = Camera pitch modifier",
		[10] = "RB = Cycle placeholder",
		[11] = "D-pad Up = Control group placeholder",
		[12] = "D-pad Down = Control group placeholder",
		[13] = "D-pad Left = Control group placeholder",
		[14] = "D-pad Right = Control group placeholder",
	},
	commandPreviewLabels = {
		[0] = "RT + A = Select all visible combat units placeholder",
		[1] = "RT + B = Stop / cancel command mode placeholder",
		[2] = "RT + X = Attack-move placeholder",
		[3] = "RT + Y = Command wheel placeholder",
		[9] = "RT + LB = Previous subgroup placeholder",
		[10] = "RT + RB = Next subgroup placeholder",
		[11] = "RT + D-pad Up = Control group / quick group placeholder",
		[12] = "RT + D-pad Down = Control group / quick group placeholder",
		[13] = "RT + D-pad Left = Control group / quick group placeholder",
		[14] = "RT + D-pad Right = Control group / quick group placeholder",
	},
	normalLayoutSummary = "A Select, B Cancel, X Context, Y Build/Menu, LB Pitch, RB Cycle, D-pad Groups",
	commandLayoutSummary = "RT+A Select combat, RT+B Stop/cancel, RT+X Attack-move, RT+Y Wheel, RT+LB/RB Subgroups, RT+D-pad Quick groups",
}

local apiAvailable = false
local controllerName = "none"
local controllerInstanceId = nil
local normalizedLeftX = 0
local normalizedLeftY = 0
local normalizedRightX = 0
local normalizedRightY = 0
local normalizedLeftTrigger = 0
local normalizedRightTrigger = 0
local zoomSpeedMultiplier = 1
local heldButtonsSummary = "none"
local pressedThisFrameSummary = "none"
local releasedThisFrameSummary = "none"
local commandLayerPressedSummary = "none"
local pressedRecentlySummary = "none"
local releasedRecentlySummary = "none"
local commandLayerPressedRecentlySummary = "none"
local activeButtonLayoutSummary = XboxController.normalLayoutSummary
local normalPreviewSummary = "none"
local commandPreviewSummary = "none"
local activeAxesSummary = "none"
local panActive = false
local zoomActive = false
local rotationActive = false
local pitchActive = false
local fastPanActive = false
local lbCameraModifierActive = false
local commandLayerActive = false
local rightStickYMode = "zoom"
local cameraMode = "unknown"
local cameraModeId = "?"
local cameraFieldSummary = "camera state unavailable"
local cameraPitchSummary = "pitch field unavailable"
local cameraPxSummary = "-"
local cameraPySummary = "-"
local cameraPzSummary = "-"
local cameraDistSummary = "-"
local cameraHeightSummary = "-"
local cameraOldHeightSummary = "-"
local cameraRxSummary = "-"
local cameraRySummary = "-"
local cameraRzSummary = "-"
local cameraDxSummary = "-"
local cameraDySummary = "-"
local cameraDzSummary = "-"
local cameraFovSummary = "-"
local zoomMethod = "none"
local rotationMethod = "none"
local pitchMethod = "none"
local debugPageIndex = 1
local controllerMode = false
local reticleVisible = false
local screenCenterX = 0
local screenCenterY = 0
local reticleTargetType = "unavailable"
local reticleHasWorldTarget = false
local reticleWorldX = nil
local reticleWorldY = nil
local reticleWorldZ = nil
local viewSizeX = 0
local viewSizeY = 0
local lastMouseX = nil
local lastMouseY = nil
local lastMouseLeft = false
local lastMouseMiddle = false
local lastMouseRight = false
local mouseStateInitialized = false

local mapSizeX = Game and Game.mapSizeX or 0
local mapSizeZ = Game and Game.mapSizeZ or 0
local maxCameraDistance = mathMax(mapSizeX, mapSizeZ, 1000) * 1.5

local previousButtonStates = {}
local currentButtonStates = {}
local pressedButtonStates = {}
local releasedButtonStates = {}
local debugEventTime = 0
local pressedRecentlyExpirations = {}
local releasedRecentlyExpirations = {}
local commandLayerPressedRecentlyExpirations = {}
local normalPreviewExpiration = 0
local commandPreviewExpiration = 0

local function clearButtonStateTracking()
	previousButtonStates = {}
	currentButtonStates = {}
	pressedButtonStates = {}
	releasedButtonStates = {}
end

local function clearDebugEventLatches()
	pressedRecentlyExpirations = {}
	releasedRecentlyExpirations = {}
	commandLayerPressedRecentlyExpirations = {}
	pressedRecentlySummary = "none"
	releasedRecentlySummary = "none"
	commandLayerPressedRecentlySummary = "none"
	normalPreviewExpiration = 0
	commandPreviewExpiration = 0
	normalPreviewSummary = "none"
	commandPreviewSummary = "none"
end

local resetReticleWorldTarget

local function resetControllerInputDebug()
	normalizedLeftX = 0
	normalizedLeftY = 0
	normalizedRightX = 0
	normalizedRightY = 0
	normalizedLeftTrigger = 0
	normalizedRightTrigger = 0
	zoomSpeedMultiplier = 1
	heldButtonsSummary = "none"
	pressedThisFrameSummary = "none"
	releasedThisFrameSummary = "none"
	commandLayerPressedSummary = "none"
	pressedRecentlySummary = "none"
	releasedRecentlySummary = "none"
	commandLayerPressedRecentlySummary = "none"
	activeButtonLayoutSummary = XboxController.normalLayoutSummary
	normalPreviewSummary = "none"
	commandPreviewSummary = "none"
	activeAxesSummary = "none"
	panActive = false
	zoomActive = false
	rotationActive = false
	pitchActive = false
	fastPanActive = false
	lbCameraModifierActive = false
	commandLayerActive = false
	rightStickYMode = "zoom"
	cameraFieldSummary = "camera state unavailable"
	cameraPitchSummary = "pitch field unavailable"
	cameraPxSummary = "-"
	cameraPySummary = "-"
	cameraPzSummary = "-"
	cameraDistSummary = "-"
	cameraHeightSummary = "-"
	cameraOldHeightSummary = "-"
	cameraRxSummary = "-"
	cameraRySummary = "-"
	cameraRzSummary = "-"
	cameraDxSummary = "-"
	cameraDySummary = "-"
	cameraDzSummary = "-"
	cameraFovSummary = "-"
	zoomMethod = "none"
	rotationMethod = "none"
	pitchMethod = "none"
	clearButtonStateTracking()
	clearDebugEventLatches()
	resetReticleWorldTarget()
end

local function updateScreenCenter(vsx, vsy)
	viewSizeX = tonumber(vsx) or viewSizeX
	viewSizeY = tonumber(vsy) or viewSizeY
	screenCenterX = viewSizeX * 0.5
	screenCenterY = viewSizeY * 0.5
end

function resetReticleWorldTarget()
	reticleTargetType = "unavailable"
	reticleHasWorldTarget = false
	reticleWorldX = nil
	reticleWorldY = nil
	reticleWorldZ = nil
end

local function setControllerMode(active)
	controllerMode = active == true
	reticleVisible = controllerMode
	if not reticleVisible then
		resetReticleWorldTarget()
	end
end

local function noteControllerInput()
	setControllerMode(true)
end

local function noteMouseInput()
	setControllerMode(false)
end

local function clamp(value, minValue, maxValue)
	return mathMin(maxValue, mathMax(minValue, value))
end

local function formatNumber(value)
	if type(value) ~= "number" then
		return "-"
	end

	return string.format("%.1f", value)
end

local function resetDebugPageIfInvalid()
	if type(debugPageIndex) ~= "number" or debugPageIndex < 1 or debugPageIndex > DEBUG_PAGE_COUNT then
		debugPageIndex = 1
	end
end

local function getDebugPageName()
	resetDebugPageIfInvalid()
	return DEBUG_PAGE_NAMES[debugPageIndex] or DEBUG_PAGE_NAMES[1]
end

local function advanceDebugPage()
	resetDebugPageIfInvalid()
	debugPageIndex = debugPageIndex + 1
	if debugPageIndex > DEBUG_PAGE_COUNT then
		debugPageIndex = 1
	end
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

local function GetAxis(state, axisId)
	if type(state) ~= "table" or type(state.axes) ~= "table" then
		return 0
	end

	return tonumber(state.axes[axisId]) or 0
end

local function GetButton(state, buttonId)
	if type(state) ~= "table" or type(state.buttons) ~= "table" then
		return false
	end

	local value = state.buttons[buttonId]
	if type(value) == "boolean" then
		return value
	end

	return (tonumber(value) or 0) ~= 0
end

local function GetNamedAxis(state, axisName)
	local axisId = XboxController.axes[axisName]
	if axisId == nil then
		return 0
	end

	return GetAxis(state, axisId)
end

local function GetNamedButton(state, buttonName)
	local buttonId = XboxController.buttons[buttonName]
	if buttonId == nil then
		return false
	end

	return GetButton(state, buttonId)
end

local function IsButtonDown(buttonName)
	local buttonId = XboxController.buttons[buttonName]
	return buttonId ~= nil and currentButtonStates[buttonId] == true
end

local function WasButtonPressed(buttonName)
	local buttonId = XboxController.buttons[buttonName]
	return buttonId ~= nil and pressedButtonStates[buttonId] == true
end

local function WasButtonReleased(buttonName)
	local buttonId = XboxController.buttons[buttonName]
	return buttonId ~= nil and releasedButtonStates[buttonId] == true
end

local function updateButtonStates(state)
	for _, buttonId in ipairs(XboxController.buttonOrder) do
		local isDown = GetButton(state, buttonId)
		local wasDown = currentButtonStates[buttonId] == true

		previousButtonStates[buttonId] = wasDown
		currentButtonStates[buttonId] = isDown
		pressedButtonStates[buttonId] = isDown and not wasDown
		releasedButtonStates[buttonId] = wasDown and not isDown
	end
end

local function getButtonLabel(buttonId)
	return XboxController.buttonLabels[buttonId] or tostring(buttonId)
end

local function getButtonStateSummary(buttonStates, buttonOrder)
	local buttons = {}

	for _, buttonId in ipairs(buttonOrder or XboxController.buttonOrder) do
		if buttonStates[buttonId] then
			buttons[#buttons + 1] = getButtonLabel(buttonId)
		end
	end

	if #buttons == 0 then
		return "none"
	end

	return table.concat(buttons, ", ")
end

local function hasButtonState(buttonStates, buttonOrder)
	for _, buttonId in ipairs(buttonOrder or XboxController.buttonOrder) do
		if buttonStates[buttonId] then
			return true
		end
	end

	return false
end

local function latchDebugButtonEvents(buttonStates, expirations, buttonOrder)
	for _, buttonId in ipairs(buttonOrder or XboxController.buttonOrder) do
		if buttonStates[buttonId] then
			expirations[getButtonLabel(buttonId)] = debugEventTime + DEBUG_EVENT_HOLD_SECONDS
		end
	end
end

local function pruneDebugEventLatches(expirations)
	for buttonName, expirationTime in pairs(expirations) do
		if expirationTime <= debugEventTime then
			expirations[buttonName] = nil
		end
	end
end

local function getDebugLatchSummary(expirations, buttonOrder)
	local buttons = {}

	for _, buttonId in ipairs(buttonOrder or XboxController.buttonOrder) do
		local buttonName = getButtonLabel(buttonId)
		if expirations[buttonName] ~= nil then
			buttons[#buttons + 1] = buttonName
		end
	end

	if #buttons == 0 then
		return "none"
	end

	return table.concat(buttons, ", ")
end

local function updateDebugLatchSummaries()
	pruneDebugEventLatches(pressedRecentlyExpirations)
	pruneDebugEventLatches(releasedRecentlyExpirations)
	pruneDebugEventLatches(commandLayerPressedRecentlyExpirations)

	pressedRecentlySummary = getDebugLatchSummary(pressedRecentlyExpirations)
	releasedRecentlySummary = getDebugLatchSummary(releasedRecentlyExpirations)
	commandLayerPressedRecentlySummary = getDebugLatchSummary(commandLayerPressedRecentlyExpirations, XboxController.commandLayerButtonOrder)

	if normalPreviewExpiration <= debugEventTime then
		normalPreviewSummary = "none"
	end
	if commandPreviewExpiration <= debugEventTime then
		commandPreviewSummary = "none"
	end
end

local function getPreviewSummary(buttonStates, previewLabels)
	local previews = {}

	for _, buttonId in ipairs(XboxController.previewButtonOrder) do
		if buttonStates[buttonId] and previewLabels[buttonId] then
			previews[#previews + 1] = previewLabels[buttonId]
		end
	end

	if #previews == 0 then
		return nil
	end

	return table.concat(previews, "; ")
end

local function latchButtonPreview(buttonStates, previewLabels)
	local preview = getPreviewSummary(buttonStates, previewLabels)
	if not preview then
		return nil
	end

	return preview, debugEventTime + DEBUG_EVENT_HOLD_SECONDS
end

local function getNormalizedDebugAxis(state, axisName)
	local value = GetNamedAxis(state, axisName)

	if axisName == "leftTrigger" or axisName == "rightTrigger" then
		return normalizeTrigger(value)
	end

	return normalizeAxis(value)
end

local function getActiveAxisSummary(state)
	local active = {}

	for _, axisName in ipairs(XboxController.axisOrder) do
		local value = getNormalizedDebugAxis(state, axisName)
		if value ~= 0 then
			active[#active + 1] = string.format(
				"%s=%.2f",
				XboxController.axisLabels[axisName] or axisName,
				value
			)
		end
	end

	if #active == 0 then
		return "none"
	end

	return table.concat(active, ", ")
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

local function rotateVectorAroundAxis(x, y, z, axisX, axisY, axisZ, angle)
	local cosAmount = mathCos(angle)
	local sinAmount = mathSin(angle)
	local dot = (x * axisX) + (y * axisY) + (z * axisZ)
	local oneMinusCos = 1 - cosAmount

	return
		(x * cosAmount) + (((axisY * z) - (axisZ * y)) * sinAmount) + (axisX * dot * oneMinusCos),
		(y * cosAmount) + (((axisZ * x) - (axisX * z)) * sinAmount) + (axisY * dot * oneMinusCos),
		(z * cosAmount) + (((axisX * y) - (axisY * x)) * sinAmount) + (axisZ * dot * oneMinusCos)
end

local function normalizeDirectionWithClampedY(x, y, z)
	y = clamp(y, -MAX_DIRECTION_PITCH_Y, MAX_DIRECTION_PITCH_Y)

	local horizontalLength = mathSqrt((x * x) + (z * z))
	if horizontalLength <= 0.001 then
		return x, y, z
	end

	local targetHorizontalLength = mathSqrt(mathMax(0, 1 - (y * y)))
	return
		(x / horizontalLength) * targetHorizontalLength,
		y,
		(z / horizontalLength) * targetHorizontalLength
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
		cameraPitchSummary = "pitch field unavailable"
		cameraPxSummary = "-"
		cameraPySummary = "-"
		cameraPzSummary = "-"
		cameraDistSummary = "-"
		cameraHeightSummary = "-"
		cameraOldHeightSummary = "-"
		cameraRxSummary = "-"
		cameraRySummary = "-"
		cameraRzSummary = "-"
		cameraDxSummary = "-"
		cameraDySummary = "-"
		cameraDzSummary = "-"
		cameraFovSummary = "-"
		return
	end

	cameraMode = tostring(cameraState.name or "unknown")
	cameraModeId = tostring(cameraState.mode or "?")
	cameraPxSummary = formatNumber(cameraState.px)
	cameraPySummary = formatNumber(cameraState.py)
	cameraPzSummary = formatNumber(cameraState.pz)
	cameraDistSummary = formatNumber(cameraState.dist)
	cameraHeightSummary = formatNumber(cameraState.height)
	cameraOldHeightSummary = formatNumber(cameraState.oldHeight)
	cameraRxSummary = formatNumber(cameraState.rx)
	cameraRySummary = formatNumber(cameraState.ry)
	cameraRzSummary = formatNumber(cameraState.rz)
	cameraDxSummary = formatNumber(cameraState.dx)
	cameraDySummary = formatNumber(cameraState.dy)
	cameraDzSummary = formatNumber(cameraState.dz)
	cameraFovSummary = formatNumber(cameraState.fov)
	cameraFieldSummary = string.format(
		"px=%s py=%s pz=%s dist=%s height=%s oldHeight=%s rx=%s ry=%s rz=%s dx=%s dy=%s dz=%s fov=%s",
		cameraPxSummary,
		cameraPySummary,
		cameraPzSummary,
		cameraDistSummary,
		cameraHeightSummary,
		cameraOldHeightSummary,
		cameraRxSummary,
		cameraRySummary,
		cameraRzSummary,
		cameraDxSummary,
		cameraDySummary,
		cameraDzSummary,
		cameraFovSummary
	)

	if type(cameraState.rx) == "number" then
		cameraPitchSummary = "rx=" .. formatNumber(cameraState.rx)
	elseif type(cameraState.dy) == "number" then
		cameraPitchSummary = "dy=" .. formatNumber(cameraState.dy)
	else
		cameraPitchSummary = "pitch field unavailable"
	end
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

local function updateMouseInputMode()
	if type(spGetMouseState) ~= "function" then
		return
	end

	local mouseX, mouseY, leftButton, middleButton, rightButton = spGetMouseState()
	if mouseX == nil or mouseY == nil then
		return
	end

	leftButton = leftButton == true
	middleButton = middleButton == true
	rightButton = rightButton == true

	if mouseStateInitialized then
		if mouseX ~= lastMouseX
			or mouseY ~= lastMouseY
			or leftButton ~= lastMouseLeft
			or middleButton ~= lastMouseMiddle
			or rightButton ~= lastMouseRight
		then
			noteMouseInput()
		end
	else
		mouseStateInitialized = true
	end

	lastMouseX = mouseX
	lastMouseY = mouseY
	lastMouseLeft = leftButton
	lastMouseMiddle = middleButton
	lastMouseRight = rightButton
end

local function updateReticleWorldTarget()
	if not reticleVisible or type(spTraceScreenRay) ~= "function" then
		resetReticleWorldTarget()
		return
	end

	local ok, targetType, worldPosition = pcall(spTraceScreenRay, screenCenterX, screenCenterY, true)
	if not ok then
		resetReticleWorldTarget()
		reticleTargetType = "trace failed"
		return
	end

	reticleTargetType = tostring(targetType or "unavailable")
	if type(worldPosition) == "table" then
		local worldX = tonumber(worldPosition[1])
		local worldY = tonumber(worldPosition[2])
		local worldZ = tonumber(worldPosition[3])

		if worldX and worldY and worldZ then
			reticleWorldX = worldX
			reticleWorldY = worldY
			reticleWorldZ = worldZ
			reticleHasWorldTarget = true
			return
		end
	end

	reticleWorldX = nil
	reticleWorldY = nil
	reticleWorldZ = nil
	reticleHasWorldTarget = false
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

local function applyZoom(cameraState, zoomInput, zoomMultiplier, dt)
	if zoomInput == 0 then
		zoomMethod = "none"
		return
	end

	zoomInput = zoomInput * (zoomMultiplier or 1)

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

local function applyRotation(cameraState, rotationInput, dt)
	if rotationInput == 0 then
		rotationMethod = "none"
		return
	end

	local rotationAmount = rotationInput * ROTATION_SPEED * (dt or 0)

	if type(cameraState.ry) == "number" then
		cameraState.ry = cameraState.ry + rotationAmount
		rotationMethod = "ry"
		return true
	end

	if cameraState.name == "rot" and type(cameraState.dx) == "number" and type(cameraState.dz) == "number" then
		local cosAmount = mathCos(rotationAmount)
		local sinAmount = mathSin(rotationAmount)
		local dx = cameraState.dx
		local dz = cameraState.dz

		cameraState.dx = (dx * cosAmount) - (dz * sinAmount)
		cameraState.dz = (dx * sinAmount) + (dz * cosAmount)
		rotationMethod = "rot direction"
		return true
	end

	rotationMethod = "unsupported"
	return false
end

local function applyPitch(cameraState, pitchInput, dt)
	if pitchInput == 0 then
		pitchMethod = "none"
		return
	end

	local pitchAmount = pitchInput * PITCH_SPEED * (dt or 0)

	if type(cameraState.rx) == "number" then
		cameraState.rx = clamp(cameraState.rx + pitchAmount, MIN_CAMERA_RX, MAX_CAMERA_RX)
		pitchMethod = "rx"
		return true
	end

	if cameraState.name == "rot"
		and type(cameraState.dx) == "number"
		and type(cameraState.dy) == "number"
		and type(cameraState.dz) == "number"
	then
		local rightX, rightZ = normalizeHorizontalVector({ cameraState.dx, cameraState.dy, cameraState.dz })
		if not rightX then
			pitchMethod = "unsupported"
			return false
		end

		local newDx, newDy, newDz = rotateVectorAroundAxis(
			cameraState.dx,
			cameraState.dy,
			cameraState.dz,
			rightZ,
			0,
			-rightX,
			pitchAmount
		)

		cameraState.dx, cameraState.dy, cameraState.dz = normalizeDirectionWithClampedY(newDx, newDy, newDz)
		pitchMethod = "rot direction"
		return true
	end

	pitchMethod = "unsupported"
	return false
end

local function applyCameraInput(leftX, leftY, zoomInput, rotationInput, pitchInput, panMultiplier, zoomMultiplier, dt)
	local cameraState = spGetCameraState and spGetCameraState()
	if type(cameraState) ~= "table" or cameraState.px == nil or cameraState.pz == nil then
		updateCameraDebug(cameraState)
		return
	end

	local distance = PAN_SPEED * (panMultiplier or 1) * (dt or 0)
	local deltaX, deltaZ = getCameraPanDelta(leftX, leftY, distance)

	cameraState.px = cameraState.px + deltaX
	cameraState.pz = cameraState.pz + deltaZ

	applyZoom(cameraState, zoomInput, zoomMultiplier, dt)
	applyRotation(cameraState, rotationInput, dt)
	applyPitch(cameraState, pitchInput, dt)

	if mapSizeX > 0 then
		cameraState.px = clamp(cameraState.px, 0, mapSizeX)
	end
	if mapSizeZ > 0 then
		cameraState.pz = clamp(cameraState.pz, 0, mapSizeZ)
	end

	spSetCameraState(cameraState, 0)
	updateCameraDebug(cameraState)
end

local function drawReticleCircle(cx, cy, radius)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, RETICLE_SEGMENTS - 1 do
			local angle = (i / RETICLE_SEGMENTS) * mathPi * 2
			gl.Vertex(cx + (mathCos(angle) * radius), cy + (mathSin(angle) * radius))
		end
	end)
end

local function drawReticleLines(cx, cy)
	gl.BeginEnd(GL.LINES, function()
		gl.Vertex(cx - RETICLE_GAP - RETICLE_LINE_LENGTH, cy)
		gl.Vertex(cx - RETICLE_GAP, cy)
		gl.Vertex(cx + RETICLE_GAP, cy)
		gl.Vertex(cx + RETICLE_GAP + RETICLE_LINE_LENGTH, cy)
		gl.Vertex(cx, cy - RETICLE_GAP - RETICLE_LINE_LENGTH)
		gl.Vertex(cx, cy - RETICLE_GAP)
		gl.Vertex(cx, cy + RETICLE_GAP)
		gl.Vertex(cx, cy + RETICLE_GAP + RETICLE_LINE_LENGTH)
	end)
end

local function drawControllerReticle()
	if not reticleVisible then
		return
	end

	gl.LineWidth(4)
	gl.Color(0, 0, 0, 0.42)
	drawReticleCircle(screenCenterX, screenCenterY, RETICLE_RADIUS)
	drawReticleLines(screenCenterX, screenCenterY)

	gl.LineWidth(2)
	gl.Color(0.65, 0.92, 1, 0.78)
	drawReticleCircle(screenCenterX, screenCenterY, RETICLE_RADIUS)
	drawReticleLines(screenCenterX, screenCenterY)

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function widget:Initialize()
	apiAvailable = type(spGetAvailableControllers) == "function" and type(spGetControllerState) == "function"
	updateScreenCenter(spGetViewGeometry())
end

function widget:ViewResize(vsx, vsy)
	updateScreenCenter(vsx, vsy)
end

function widget:Update(dt)
	debugEventTime = debugEventTime + (dt or 0)
	updateMouseInputMode()
	panActive = false
	zoomActive = false
	rotationActive = false
	pitchActive = false

	if not apiAvailable then
		resetControllerInputDebug()
		return
	end

	local controller = pollFirstController()
	if not controller then
		resetControllerInputDebug()
		return
	end

	local state = pollControllerState(controller.instanceId)
	if not state or type(state.axes) ~= "table" then
		resetControllerInputDebug()
		return
	end

	normalizedLeftX = normalizeAxis(GetNamedAxis(state, "leftStickX"))
	normalizedLeftY = normalizeAxis(GetNamedAxis(state, "leftStickY"))
	normalizedRightX = normalizeAxis(GetNamedAxis(state, "rightStickX"))
	normalizedRightY = normalizeAxis(GetNamedAxis(state, "rightStickY"))
	normalizedLeftTrigger = normalizeTrigger(GetNamedAxis(state, "leftTrigger"))
	normalizedRightTrigger = normalizeTrigger(GetNamedAxis(state, "rightTrigger"))
	updateButtonStates(state)
	heldButtonsSummary = getButtonStateSummary(currentButtonStates)
	pressedThisFrameSummary = getButtonStateSummary(pressedButtonStates)
	releasedThisFrameSummary = getButtonStateSummary(releasedButtonStates)
	activeAxesSummary = getActiveAxisSummary(state)
	if normalizedLeftX ~= 0
		or normalizedLeftY ~= 0
		or normalizedRightX ~= 0
		or normalizedRightY ~= 0
		or normalizedLeftTrigger ~= 0
		or normalizedRightTrigger ~= 0
		or hasButtonState(pressedButtonStates)
		or hasButtonState(releasedButtonStates)
	then
		noteControllerInput()
	end
	latchDebugButtonEvents(pressedButtonStates, pressedRecentlyExpirations)
	latchDebugButtonEvents(releasedButtonStates, releasedRecentlyExpirations)

	fastPanActive = normalizedLeftTrigger > 0
	lbCameraModifierActive = IsButtonDown("LB")
	commandLayerActive = normalizedRightTrigger > 0
	if commandLayerActive and WasButtonPressed("Back/View") then
		advanceDebugPage()
	end
	activeButtonLayoutSummary = commandLayerActive
		and XboxController.commandLayoutSummary
		or XboxController.normalLayoutSummary
	commandLayerPressedSummary = commandLayerActive
		and getButtonStateSummary(pressedButtonStates, XboxController.commandLayerButtonOrder)
		or "none"
	if commandLayerActive then
		latchDebugButtonEvents(pressedButtonStates, commandLayerPressedRecentlyExpirations, XboxController.commandLayerButtonOrder)
		local commandPreview, commandExpiration = latchButtonPreview(pressedButtonStates, XboxController.commandPreviewLabels)
		if commandPreview then
			commandPreviewSummary = commandPreview
			commandPreviewExpiration = commandExpiration
		end
	else
		local normalPreview, normalExpiration = latchButtonPreview(pressedButtonStates, XboxController.normalPreviewLabels)
		if normalPreview then
			normalPreviewSummary = normalPreview
			normalPreviewExpiration = normalExpiration
		end
	end
	panActive = normalizedLeftX ~= 0 or normalizedLeftY ~= 0
	rightStickYMode = lbCameraModifierActive and "pitch" or "zoom"
	local zoomInput = lbCameraModifierActive and 0 or -normalizedRightY
	local pitchInput = lbCameraModifierActive and -normalizedRightY or 0
	zoomActive = zoomInput ~= 0
	rotationActive = normalizedRightX ~= 0
	pitchActive = pitchInput ~= 0

	local panMultiplier = fastPanActive and FAST_PAN_MULTIPLIER or 1
	zoomSpeedMultiplier = fastPanActive and FAST_ZOOM_MULTIPLIER or 1
	if panActive or zoomActive or rotationActive or pitchActive then
		applyCameraInput(normalizedLeftX, normalizedLeftY, zoomInput, normalizedRightX, pitchInput, panMultiplier, zoomSpeedMultiplier, dt)
	elseif spGetCameraState then
		zoomMethod = "none"
		rotationMethod = "none"
		pitchMethod = "none"
		updateCameraDebug(spGetCameraState())
	end

	updateReticleWorldTarget()
end

function widget:MouseMove()
	noteMouseInput()
end

function widget:MousePress()
	noteMouseInput()
end

function widget:MouseRelease()
	noteMouseInput()
end

function widget:DrawScreen()
	updateDebugLatchSummaries()
	drawControllerReticle()

	local x = 20
	local y = 500
	local lineHeight = 18
	local function yesNo(value)
		return value and "yes" or "no"
	end
	local function activeInactive(value)
		return value and "active" or "inactive"
	end
	local function drawLine(text)
		glText(text, x, y, 12, "o")
		y = y - lineHeight
	end

	resetDebugPageIfInvalid()
	glText(string.format(
		"Controller Camera Test - Debug Page %d/%d: %s",
		debugPageIndex,
		DEBUG_PAGE_COUNT,
		getDebugPageName()
	), x, y, 14, "o")
	y = y - lineHeight

	if debugPageIndex == 1 then
		drawLine("API: " .. (apiAvailable and "available" or "missing"))
		drawLine("Controller: " .. tostring(controllerName))
		drawLine("instanceId: " .. tostring(controllerInstanceId))
		drawLine("input mode: " .. (controllerMode and "controller" or "mouse"))
		drawLine(string.format("left stick: x=%.3f y=%.3f", normalizedLeftX, normalizedLeftY))
		drawLine(string.format("right stick: x=%.3f y=%.3f mode=%s", normalizedRightX, normalizedRightY, rightStickYMode))
		drawLine(string.format(
			"LT boost: %s (LT=%.3f, pan %.1fx, zoom %.1fx)",
			activeInactive(fastPanActive),
			normalizedLeftTrigger,
			fastPanActive and FAST_PAN_MULTIPLIER or 1,
			zoomSpeedMultiplier
		))
		drawLine(string.format("RT command layer: %s (RT=%.3f)", activeInactive(commandLayerActive), normalizedRightTrigger))
		drawLine(string.format(
			"pan/zoom/rotate/pitch: %s/%s/%s/%s",
			yesNo(panActive),
			yesNo(zoomActive),
			yesNo(rotationActive),
			yesNo(pitchActive)
		))
		drawLine("LB camera modifier active: " .. yesNo(lbCameraModifierActive))
		drawLine("zoom method: " .. zoomMethod)
		drawLine("rotation method: " .. rotationMethod)
		drawLine("pitch method: " .. pitchMethod)
		drawLine("axes: " .. activeAxesSummary)
	elseif debugPageIndex == 2 then
		drawLine("input mode: " .. (controllerMode and "controller" or "mouse"))
		drawLine("reticle visible: " .. yesNo(reticleVisible))
		drawLine(string.format("reticle screen: x=%.1f y=%.1f", screenCenterX, screenCenterY))
		if reticleHasWorldTarget then
			drawLine(string.format("reticle world: x=%.1f y=%.1f z=%.1f", reticleWorldX, reticleWorldY, reticleWorldZ))
		else
			drawLine("reticle world: unavailable")
		end
		drawLine("reticle target type: " .. reticleTargetType)
		drawLine("reticle has world target: " .. yesNo(reticleHasWorldTarget))
		drawLine("center-screen ray status: " .. (reticleHasWorldTarget and "hit" or reticleTargetType))
	elseif debugPageIndex == 3 then
		drawLine("held buttons: " .. heldButtonsSummary)
		drawLine("pressed recently: " .. pressedRecentlySummary)
		drawLine("released recently: " .. releasedRecentlySummary)
		drawLine("command layer: " .. activeInactive(commandLayerActive))
		drawLine("command layer pressed recently: " .. commandLayerPressedRecentlySummary)
		drawLine("button layout: " .. activeButtonLayoutSummary)
		drawLine("normal preview: " .. normalPreviewSummary)
		drawLine("command preview: " .. commandPreviewSummary)
		drawLine("page switch: RT + Back/View")
	elseif debugPageIndex == 4 then
		drawLine("camera: " .. cameraMode .. " mode=" .. cameraModeId)
		drawLine("px/py/pz: " .. cameraPxSummary .. " / " .. cameraPySummary .. " / " .. cameraPzSummary)
		drawLine("dist: " .. cameraDistSummary)
		drawLine("height/oldHeight: " .. cameraHeightSummary .. " / " .. cameraOldHeightSummary)
		drawLine("rx/ry/rz: " .. cameraRxSummary .. " / " .. cameraRySummary .. " / " .. cameraRzSummary)
		drawLine("dx/dy/dz: " .. cameraDxSummary .. " / " .. cameraDySummary .. " / " .. cameraDzSummary)
		drawLine("fov: " .. cameraFovSummary)
		drawLine(string.format("zoom speed multiplier: %.1fx", zoomSpeedMultiplier))
		drawLine("zoom method: " .. zoomMethod)
		drawLine("rotation method: " .. rotationMethod)
		drawLine("pitch method: " .. pitchMethod)
		drawLine("pitch field: " .. cameraPitchSummary)
		drawLine(cameraFieldSummary)
	end
end
