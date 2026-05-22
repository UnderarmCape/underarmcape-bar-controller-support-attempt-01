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
local spSelectUnitArray = Spring.SelectUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local lastIssuedCommand = "none"
ControllerCameraTestCommandDebug = ControllerCameraTestCommandDebug or {
	defaultCmdIndex = "none",
	defaultCmdID = "none",
	defaultCmdType = "none",
	defaultCmdName = "none",
	isBuild = "no",
	issuedCmdID = "none",
	issuedParamsCount = 0,
	lastResult = "none",
	mexSmartAvailable = "no",
	mexNearestSpot = "no",
	mexBuildingCmdID = "none",
	mexActionResult = "none",
	mexApplyPreviewPath = "no",
	mexFallbackGiveOrderPath = "no",
}
ControllerCameraTestBuildMenu = ControllerCameraTestBuildMenu or {
	open = false,
	options = {},
	selectedIndex = 1,
	optionCount = 0,
	highlightedName = "none",
	highlightedCmdID = "none",
	lastAction = "none",
	placementResult = "none",
	placementParamsCount = 0,
	radialCategories = { "Economy", "Combat", "Utility", "Build" },
	radialPage = 1,
	radialPageCount = 1,
	radialCategoryIndex = 1,
	radialCategoryName = "Economy",
	radialVisibleOptions = {},
	radialStickArmed = true,
	radialLastAngle = 0,
	radialLastAction = "none",
}
ControllerCameraTestBuildPlacement = ControllerCameraTestBuildPlacement or {
	active = false,
	option = nil,
	facing = 0,
	lastResult = "none",
	lastParamsCount = 0,
	lastIssuedCount = 0,
	analogRotateArmed = true,
	queueActive = false,
	nativePreviewActive = false,
	nativeSetActiveCommandResult = "none",
	cmdDescIndex = nil,
	placementMode = "none",
}
ControllerCameraTestAreaSelect = ControllerCameraTestAreaSelect or {
	pressActive = false,
	active = false,
	pressStartTime = 0,
	lastTapTime = -10,
	radius = 320,
	lastCount = 0,
	lastResult = "none",
}
ControllerCameraTestTacticalMenu = ControllerCameraTestTacticalMenu or {
	open = false,
	selectedIndex = 1,
	highlightedName = "none",
	lastAction = "none",
	lastResult = "none",
}
ControllerCameraTestCycleDebug = ControllerCameraTestCycleDebug or {
	lastResult = "none",
	lastCount = 0,
	lastUnitID = "none",
	lbPressActive = false,
	lbHadPitchMotion = false,
}
ControllerCameraTestBookmarkDebug = ControllerCameraTestBookmarkDebug or {
	slots = {},
	lastResult = "none",
	lastSlot = "none",
}
ControllerCameraTestVisualFeedback = ControllerCameraTestVisualFeedback or {
	targetX = nil,
	targetY = nil,
	targetZ = nil,
	label = "none",
	kind = "generic",
	expireTime = 0,
}
ControllerCameraTestLayerDebug = ControllerCameraTestLayerDebug or {
	commandLayerAction = "none",
	normalUtilityAction = "none",
	areaSelect = "inactive",
	modeSummary = "normal",
}
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spWarpMouse = Spring.WarpMouse

local glText = gl.Text
local glRect = gl.Rect

local PAN_SPEED = 2800
local FAST_PAN_MULTIPLIER = 2.75
local FAST_ZOOM_MULTIPLIER = 3.0
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
local DEBUG_PANEL_MARGIN = 10
local DEBUG_PANEL_PADDING = 8
local DEBUG_PANEL_HEADER_HEIGHT = 22
local DEBUG_PANEL_RESIZE_HANDLE = 14
local DEBUG_PANEL_MIN_WIDTH = 280
local DEBUG_PANEL_MIN_HEIGHT = 118
local DEBUG_PANEL_DEFAULT_WIDTH = 650
local DEBUG_PANEL_DEFAULT_HEIGHT = 150

ControllerCameraTestSettings = ControllerCameraTestSettings or {
	panSpeed = PAN_SPEED,
	fastPanMultiplier = FAST_PAN_MULTIPLIER,
	zoomSpeed = ZOOM_SPEED,
	zoomBoostMultiplier = FAST_ZOOM_MULTIPLIER,
	rotationSpeed = ROTATION_SPEED,
	pitchSpeed = PITCH_SPEED,
	stickDeadzone = 3000,
	triggerDeadzone = 3000,
	areaSelectRadius = 320,
	reticleSize = 16,
	debugPanelVisible = true,
	helpOverlayVisible = false,
}
ControllerCameraTestTuning = ControllerCameraTestTuning or {
	selectedIndex = 1,
	backHeld = false,
	backComboUsed = false,
	lastAction = "none",
}
ControllerCameraTestQuickGroups = ControllerCameraTestQuickGroups or {
	slots = {},
	lastResult = "none",
	lastSlot = "none",
	currentSlot = 1,
}

function ControllerCameraTestClampSetting(name, value)
	value = tonumber(value)
	if not value then
		return ControllerCameraTestSettings[name]
	end
	local ranges = {
		panSpeed = { 500, 8000 },
		fastPanMultiplier = { 1, 6 },
		zoomSpeed = { 400, 9000 },
		zoomBoostMultiplier = { 1, 6 },
		rotationSpeed = { 0.5, 8 },
		pitchSpeed = { 0.5, 8 },
		stickDeadzone = { 0, 12000 },
		triggerDeadzone = { 0, 12000 },
		areaSelectRadius = { 120, 1200 },
		reticleSize = { 8, 36 },
	}
	local range = ranges[name]
	if not range then
		return value
	end
	return math.max(range[1], math.min(range[2], value))
end

function ControllerCameraTestApplySettingsDefaults()
	local settings = ControllerCameraTestSettings
	settings.panSpeed = ControllerCameraTestClampSetting("panSpeed", settings.panSpeed or PAN_SPEED)
	settings.fastPanMultiplier = ControllerCameraTestClampSetting("fastPanMultiplier", settings.fastPanMultiplier or FAST_PAN_MULTIPLIER)
	settings.zoomSpeed = ControllerCameraTestClampSetting("zoomSpeed", settings.zoomSpeed or ZOOM_SPEED)
	settings.zoomBoostMultiplier = ControllerCameraTestClampSetting("zoomBoostMultiplier", settings.zoomBoostMultiplier or FAST_ZOOM_MULTIPLIER)
	settings.rotationSpeed = ControllerCameraTestClampSetting("rotationSpeed", settings.rotationSpeed or ROTATION_SPEED)
	settings.pitchSpeed = ControllerCameraTestClampSetting("pitchSpeed", settings.pitchSpeed or PITCH_SPEED)
	settings.stickDeadzone = ControllerCameraTestClampSetting("stickDeadzone", settings.stickDeadzone or 3000)
	settings.triggerDeadzone = ControllerCameraTestClampSetting("triggerDeadzone", settings.triggerDeadzone or 3000)
	settings.areaSelectRadius = ControllerCameraTestClampSetting("areaSelectRadius", settings.areaSelectRadius or 320)
	settings.reticleSize = ControllerCameraTestClampSetting("reticleSize", settings.reticleSize or 16)
	settings.debugPanelVisible = settings.debugPanelVisible ~= false
	settings.helpOverlayVisible = settings.helpOverlayVisible == true
	ControllerCameraTestAreaSelect.radius = settings.areaSelectRadius
end

function ControllerCameraTestSettingDefinitions()
	return {
		{ key = "panSpeed", label = "Pan speed", step = 100, decimals = 0 },
		{ key = "fastPanMultiplier", label = "LT pan boost", step = 0.25, decimals = 2 },
		{ key = "zoomSpeed", label = "Zoom speed", step = 100, decimals = 0 },
		{ key = "zoomBoostMultiplier", label = "LT zoom boost", step = 0.25, decimals = 2 },
		{ key = "rotationSpeed", label = "Rotate speed", step = 0.25, decimals = 2 },
		{ key = "pitchSpeed", label = "Pitch speed", step = 0.25, decimals = 2 },
		{ key = "stickDeadzone", label = "Stick deadzone", step = 500, decimals = 0 },
		{ key = "triggerDeadzone", label = "Trigger deadzone", step = 500, decimals = 0 },
		{ key = "areaSelectRadius", label = "Area radius", step = 40, decimals = 0 },
		{ key = "reticleSize", label = "Reticle size", step = 1, decimals = 0 },
	}
end

function ControllerCameraTestCurrentSettingLabel()
	local defs = ControllerCameraTestSettingDefinitions()
	local index = ControllerCameraTestTuning.selectedIndex
	if index < 1 or index > #defs then
		ControllerCameraTestTuning.selectedIndex = 1
		index = 1
	end
	local def = defs[index]
	local value = ControllerCameraTestSettings[def.key]
	local format = def.decimals == 0 and "%s: %.0f" or "%s: %.2f"
	return string.format(format, def.label, tonumber(value) or 0)
end

function ControllerCameraTestCycleTuningSetting(delta)
	local defs = ControllerCameraTestSettingDefinitions()
	ControllerCameraTestTuning.selectedIndex = ((ControllerCameraTestTuning.selectedIndex - 1 + delta) % #defs) + 1
	ControllerCameraTestTuning.lastAction = "selected " .. ControllerCameraTestCurrentSettingLabel()
end

function ControllerCameraTestAdjustTuningSetting(delta)
	local defs = ControllerCameraTestSettingDefinitions()
	local def = defs[ControllerCameraTestTuning.selectedIndex] or defs[1]
	local settings = ControllerCameraTestSettings
	settings[def.key] = ControllerCameraTestClampSetting(def.key, (tonumber(settings[def.key]) or 0) + (def.step * delta))
	if def.key == "areaSelectRadius" then
		ControllerCameraTestAreaSelect.radius = settings.areaSelectRadius
	end
	ControllerCameraTestTuning.lastAction = "adjusted " .. ControllerCameraTestCurrentSettingLabel()
end

ControllerCameraTestApplySettingsDefaults()


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
	previewButtonOrder = { 0, 1, 2, 3, 4, 6, 9, 10, 11, 12, 13, 14 },
	normalPreviewLabels = {
		[0] = "A = Select / Confirm",
		[1] = "B = Clear Selection",
		[2] = "X = Smart Action (Move/Build/Attack)",
		[3] = "Y = Controller Build Menu",
		[4] = "Back/View = Debug toggle; hold for tuning/groups",
		[6] = "Start/Menu = Help overlay",
		[9] = "LB = Camera pitch modifier",
		[10] = "RB = Cycle selection",
		[11] = "D-pad Up = Camera bookmark Up",
		[12] = "D-pad Down = Camera bookmark Down",
		[13] = "D-pad Left = Camera bookmark Left",
		[14] = "D-pad Right = Camera bookmark Right",
	},
	commandPreviewLabels = {
		[0] = "RT + A = Select visible combat/mobile units",
		[1] = "RT + B = Stop selected units",
		[2] = "RT + X = Attack / Attack-move",
		[3] = "RT + Y = Tactical command menu",
		[9] = "RT + LB = Previous selected unit/type",
		[10] = "RT + RB = Next selected unit/type",
		[11] = "RT + D-pad Up = Guard allied / Patrol ground",
		[12] = "RT + D-pad Down = Reclaim target/area",
		[13] = "RT + D-pad Left = Previous selection cycle",
		[14] = "RT + D-pad Right = Next selection cycle",
	},
	normalLayoutSummary = "A Tap/Hold Select, B Clear, X Context, Y Build, LB Pitch/Cycle, RB Cycle, D-pad Bookmarks, Back Settings, Start Help",
	commandLayoutSummary = "RT+A Select combat, RT+B Stop, RT+X Attack, RT+Y Tactical, RT+LB/RB Cycle, RT+D-pad Commands",
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
local zoomMethod = "none"
local rotationMethod = "none"
local pitchMethod = "none"
local selectionTestActive = false
local lastReticleSelectedUnitID = "none"
local lastSelectionResult = "none"
local lastBButtonResult = "none"
local lastClearSelectionResult = "none"
local selectionDebugMessage = "none"
local selectionDebugExpiration = 0
local controllerMode = false
local reticleVisible = false
local screenCenterX = 0
local screenCenterY = 0
local reticleTargetType = "unavailable"
local reticleHasWorldTarget = false
local reticleWorldX = nil
local reticleWorldY = nil
local reticleWorldZ = nil
local reticleTargetAlignment = "none"
local viewSizeX = 0
local viewSizeY = 0
local lastMouseX = nil
local lastMouseY = nil
local lastMouseLeft = false
local lastMouseMiddle = false
local lastMouseRight = false
local mouseStateInitialized = false
local debugPanelX = DEBUG_PANEL_MARGIN
local debugPanelY = 0
local debugPanelWidth = DEBUG_PANEL_DEFAULT_WIDTH
local debugPanelHeight = DEBUG_PANEL_DEFAULT_HEIGHT
local debugPanelInitialized = false
local debugPanelDragging = false
local debugPanelResizing = false
local debugPanelDragOffsetX = 0
local debugPanelDragOffsetY = 0
local debugPanelResizeStartMouseX = 0
local debugPanelResizeStartMouseY = 0
local debugPanelResizeStartY = 0
local debugPanelResizeStartWidth = 0
local debugPanelResizeStartHeight = 0

local mapSizeX = Game and Game.mapSizeX or 0
local mapSizeZ = Game and Game.mapSizeZ or 0
local maxCameraDistance = math.max(mapSizeX, mapSizeZ, 1000) * 1.5

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
	selectionDebugMessage = "none"
	selectionDebugExpiration = 0
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
	cameraPitchSummary = "pitch field unavailable"
	zoomMethod = "none"
	rotationMethod = "none"
	pitchMethod = "none"
	selectionTestActive = false
	lastBButtonResult = "none"
	lastClearSelectionResult = "none"
	lastIssuedCommand = "none"
	ControllerCameraTestBuildPlacement.active = false
	ControllerCameraTestBuildPlacement.queueActive = false
	ControllerCameraTestAreaSelect.pressActive = false
	ControllerCameraTestAreaSelect.active = false
	ControllerCameraTestTacticalMenu.open = false
	ControllerCameraTestLayerDebug.modeSummary = "normal"
	ControllerCameraTestLayerDebug.areaSelect = "inactive"
	ControllerCameraTestCommandDebug.issuedCmdID = "none"
	ControllerCameraTestCommandDebug.issuedParamsCount = 0
	ControllerCameraTestCommandDebug.lastResult = "none"
	ControllerCameraTestCommandDebug.mexSmartAvailable = "no"
	ControllerCameraTestCommandDebug.mexNearestSpot = "no"
	ControllerCameraTestCommandDebug.mexBuildingCmdID = "none"
	ControllerCameraTestCommandDebug.mexActionResult = "none"
	ControllerCameraTestCommandDebug.mexApplyPreviewPath = "no"
	ControllerCameraTestCommandDebug.mexFallbackGiveOrderPath = "no"
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
	reticleTargetAlignment = "none"
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
	local mathMin, mathMax = math.min, math.max
	return mathMin(maxValue, mathMax(minValue, value))
end

local function formatNumber(value)
	if type(value) ~= "number" then
		return "-"
	end

	return string.format("%.1f", value)
end

local function normalizeAxis(value)
	local AXIS_MAX = 32767
	local mathAbs = math.abs
	value = tonumber(value) or 0

	local magnitude = mathAbs(value)
	local deadzone = tonumber(ControllerCameraTestSettings.stickDeadzone) or 3000
	if magnitude < deadzone then
		return 0
	end

	local sign = value < 0 and -1 or 1
	local normalized = (magnitude - deadzone) / (AXIS_MAX - deadzone)
	return sign * clamp(normalized, 0, 1)
end

local function normalizeTrigger(value)
	local AXIS_MAX = 32767
	value = tonumber(value) or 0

	local deadzone = tonumber(ControllerCameraTestSettings.triggerDeadzone) or 3000
	if value < deadzone then
		return 0
	end

	return clamp((value - deadzone) / (AXIS_MAX - deadzone), 0, 1)
end

local function getDebugPanelScreenSize()
	return viewSizeX > 0 and viewSizeX or 1280, viewSizeY > 0 and viewSizeY or 720
end

local function clampDebugPanelToScreen()
	local mathMax = math.max
	local screenWidth, screenHeight = getDebugPanelScreenSize()
	local maxWidth = mathMax(DEBUG_PANEL_MIN_WIDTH, screenWidth - (DEBUG_PANEL_MARGIN * 2))
	local maxHeight = mathMax(DEBUG_PANEL_MIN_HEIGHT, screenHeight - (DEBUG_PANEL_MARGIN * 2))

	debugPanelWidth = clamp(debugPanelWidth, DEBUG_PANEL_MIN_WIDTH, maxWidth)
	debugPanelHeight = clamp(debugPanelHeight, DEBUG_PANEL_MIN_HEIGHT, maxHeight)
	debugPanelX = clamp(debugPanelX, DEBUG_PANEL_MARGIN, mathMax(DEBUG_PANEL_MARGIN, screenWidth - DEBUG_PANEL_MARGIN - debugPanelWidth))
	debugPanelY = clamp(debugPanelY, DEBUG_PANEL_MARGIN, mathMax(DEBUG_PANEL_MARGIN, screenHeight - DEBUG_PANEL_MARGIN - debugPanelHeight))
end

local function resetDebugPanelToDefault()
	local mathMin, mathMax = math.min, math.max
	local screenWidth, screenHeight = getDebugPanelScreenSize()
	debugPanelWidth = mathMin(DEBUG_PANEL_DEFAULT_WIDTH, mathMax(DEBUG_PANEL_MIN_WIDTH, screenWidth - (DEBUG_PANEL_MARGIN * 2)))
	debugPanelHeight = mathMin(DEBUG_PANEL_DEFAULT_HEIGHT, mathMax(DEBUG_PANEL_MIN_HEIGHT, screenHeight - (DEBUG_PANEL_MARGIN * 2)))
	debugPanelX = DEBUG_PANEL_MARGIN
	debugPanelY = screenHeight - DEBUG_PANEL_MARGIN - debugPanelHeight
	debugPanelInitialized = true
	clampDebugPanelToScreen()
end

local function ensureDebugPanelInitialized()
	if not debugPanelInitialized then
		resetDebugPanelToDefault()
	else
		clampDebugPanelToScreen()
	end
end

local function isPointInDebugPanel(x, y)
	ensureDebugPanelInitialized()
	return x >= debugPanelX
		and x <= debugPanelX + debugPanelWidth
		and y >= debugPanelY
		and y <= debugPanelY + debugPanelHeight
end

local function isPointInDebugPanelHeader(x, y)
	return isPointInDebugPanel(x, y)
		and y >= debugPanelY + debugPanelHeight - DEBUG_PANEL_HEADER_HEIGHT
end

local function isPointInDebugPanelResizeHandle(x, y)
	return isPointInDebugPanel(x, y)
		and x >= debugPanelX + debugPanelWidth - DEBUG_PANEL_RESIZE_HANDLE
		and y <= debugPanelY + DEBUG_PANEL_RESIZE_HANDLE
end

local function updateDebugPanelDrag(x, y)
	debugPanelX = x - debugPanelDragOffsetX
	debugPanelY = y - debugPanelDragOffsetY
	clampDebugPanelToScreen()
end

local function updateDebugPanelResize(x, y)
	local mathMax = math.max
	local top = debugPanelResizeStartY + debugPanelResizeStartHeight
	local screenWidth = getDebugPanelScreenSize()
	local maxWidth = mathMax(DEBUG_PANEL_MIN_WIDTH, screenWidth - DEBUG_PANEL_MARGIN - debugPanelX)
	local maxHeight = mathMax(DEBUG_PANEL_MIN_HEIGHT, top - DEBUG_PANEL_MARGIN)
	debugPanelWidth = clamp(debugPanelResizeStartWidth + (x - debugPanelResizeStartMouseX), DEBUG_PANEL_MIN_WIDTH, maxWidth)
	debugPanelHeight = clamp(debugPanelResizeStartHeight - (y - debugPanelResizeStartMouseY), DEBUG_PANEL_MIN_HEIGHT, maxHeight)
	debugPanelY = top - debugPanelHeight
	clampDebugPanelToScreen()
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
	local DEBUG_EVENT_HOLD_SECONDS = 0.45
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
	if selectionDebugExpiration <= debugEventTime then
		selectionDebugMessage = "none"
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
	local DEBUG_EVENT_HOLD_SECONDS = 0.45
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
	local mathSqrt = math.sqrt
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
	local mathCos, mathSin = math.cos, math.sin
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
	local mathSqrt, mathMax = math.sqrt, math.max
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
		return
	end

	cameraMode = tostring(cameraState.name or "unknown")
	cameraModeId = tostring(cameraState.mode or "?")
	cameraFieldSummary = string.format(
		"px=%s py=%s pz=%s dist=%s height=%s rx=%s ry=%s dx=%s dy=%s dz=%s fov=%s",
		formatNumber(cameraState.px),
		formatNumber(cameraState.py),
		formatNumber(cameraState.pz),
		formatNumber(cameraState.dist),
		formatNumber(cameraState.height),
		formatNumber(cameraState.rx),
		formatNumber(cameraState.ry),
		formatNumber(cameraState.dx),
		formatNumber(cameraState.dy),
		formatNumber(cameraState.dz),
		formatNumber(cameraState.fov)
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

	if controllerMode then
		if math.abs(mouseX - screenCenterX) > 5 or math.abs(mouseY - screenCenterY) > 5 then
			noteMouseInput()
		end
	else
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

	-- 1. Standard trace to see what we are aiming at
	local okTarget, targetType, targetID = pcall(spTraceScreenRay, screenCenterX, screenCenterY)
	if okTarget then
		reticleTargetType = tostring(targetType or "unavailable")

		-- Check team alignment if it's a unit
		if reticleTargetType == "unit" and tonumber(targetID) then
			local unitID = tonumber(targetID)
			local myAllyTeam = (type(spGetMyAllyTeamID) == "function") and spGetMyAllyTeamID() or -1
			local unitAllyTeam = (type(spGetUnitAllyTeam) == "function") and spGetUnitAllyTeam(unitID) or -2

			if myAllyTeam == unitAllyTeam then
				reticleTargetAlignment = "ally"
			else
				reticleTargetAlignment = "enemy"
			end
		else
			reticleTargetAlignment = "none"
		end
	else
		reticleTargetType = "trace failed"
		reticleTargetAlignment = "none"
	end

	-- 2. Ground-only trace for movement coordinates
	local okGround, _, worldPosition = pcall(spTraceScreenRay, screenCenterX, screenCenterY, true)

	if okGround and type(worldPosition) == "table" then
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

local function latchSelectionDebugMessage(message)
	local SELECTION_DEBUG_HOLD_SECONDS = 1.2
	selectionDebugMessage = message
	selectionDebugExpiration = debugEventTime + SELECTION_DEBUG_HOLD_SECONDS
end

local function updateSelectionTestActive()
	selectionTestActive = controllerMode
		and reticleVisible
		and not commandLayerActive
		and not ControllerCameraTestBuildMenu.open
		and not ControllerCameraTestBuildPlacement.active
		and not ControllerCameraTestAreaSelect.active
		and type(spTraceScreenRay) == "function"
		and type(spSelectUnitArray) == "function"
end

local function attemptReticleSelection()
	if commandLayerActive then
		lastSelectionResult = "RT layer active"
		latchSelectionDebugMessage("A select skipped: RT command layer active")
		return
	end
	if not controllerMode or not reticleVisible then
		lastSelectionResult = "unavailable"
		latchSelectionDebugMessage("A select skipped: reticle inactive")
		return
	end
	if type(spTraceScreenRay) ~= "function" or type(spSelectUnitArray) ~= "function" then
		lastSelectionResult = "unavailable"
		latchSelectionDebugMessage("A select unavailable")
		return
	end

	local ok, targetType, targetID = pcall(spTraceScreenRay, screenCenterX, screenCenterY)
	if not ok then
		lastSelectionResult = "unavailable"
		latchSelectionDebugMessage("A select trace failed")
		return
	end

	if targetType ~= "unit" or tonumber(targetID) == nil then
		lastSelectionResult = "no unit"
		latchSelectionDebugMessage("A select: no unit under reticle")
		return
	end

	local unitID = tonumber(targetID)
	local selectOk = pcall(spSelectUnitArray, { unitID }, false)
	if not selectOk then
		lastSelectionResult = "unavailable"
		latchSelectionDebugMessage("A select failed")
		return
	end

	lastReticleSelectedUnitID = tostring(unitID)
	lastSelectionResult = "selected"
	latchSelectionDebugMessage("A selected unit " .. tostring(unitID))
end

local function attemptClearSelection()
	if commandLayerActive then
		lastBButtonResult = "RT active"
		latchSelectionDebugMessage("B ignored: RT command layer active")
		return
	end

	if type(spSelectUnitArray) ~= "function" then
		lastBButtonResult = "unavailable"
		lastClearSelectionResult = "failed"
		latchSelectionDebugMessage("B clear: select API unavailable")
		return
	end

	local selectOk = pcall(spSelectUnitArray, {})
	if selectOk then
		lastBButtonResult = "cleared"
		lastClearSelectionResult = "success"
		latchSelectionDebugMessage("B: selection cleared")
	else
		lastBButtonResult = "failed"
		lastClearSelectionResult = "failed"
		latchSelectionDebugMessage("B clear: API call failed")
	end
end

local function issueOrderToSelection(cmdID, params, cmdName, targetName)
	-- 1. Check if we actually have units selected
	local selectedUnits = type(Spring.GetSelectedUnits) == "function" and Spring.GetSelectedUnits() or {}
	local paramsCount = type(params) == "table" and #params or 0
	ControllerCameraTestCommandDebug.issuedCmdID = tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = paramsCount
	if #selectedUnits == 0 then
		lastIssuedCommand = "none"
		ControllerCameraTestCommandDebug.lastResult = "no selected units"
		latchSelectionDebugMessage(tostring(cmdName) .. " skipped: no units selected")
		return
	end

	-- 2. Use the universally safe LuaUI GiveOrder API
	if type(Spring.GiveOrder) == "function" then
		local orderOk, orderResult = pcall(Spring.GiveOrder, cmdID, params, {})
		if not orderOk or orderResult == false then
			lastIssuedCommand = "none"
			ControllerCameraTestCommandDebug.lastResult = "GiveOrder failed"
			latchSelectionDebugMessage("Command failed: GiveOrder call failed")
			return
		end
		lastIssuedCommand = tostring(cmdName) .. " (" .. tostring(targetName) .. ")"
		ControllerCameraTestCommandDebug.lastResult = "issued via GiveOrder"
		latchSelectionDebugMessage(tostring(cmdName) .. " ordered to " .. #selectedUnits .. " units")
		if type(params) == "table" and type(params[1]) == "number" and type(params[2]) == "number" and type(params[3]) == "number" then
			ControllerCameraTestSetCommandMarker(params[1], params[2], params[3], cmdName)
		end
	else
		lastIssuedCommand = "none"
		ControllerCameraTestCommandDebug.lastResult = "GiveOrder unavailable"
		latchSelectionDebugMessage("Command failed: GiveOrder API unavailable")
	end
end

function ControllerCameraTestResetMexCommandDebug()
	ControllerCameraTestCommandDebug.mexSmartAvailable = "no"
	ControllerCameraTestCommandDebug.mexNearestSpot = "no"
	ControllerCameraTestCommandDebug.mexBuildingCmdID = "none"
	ControllerCameraTestCommandDebug.mexActionResult = "not attempted"
	ControllerCameraTestCommandDebug.mexApplyPreviewPath = "no"
	ControllerCameraTestCommandDebug.mexFallbackGiveOrderPath = "no"
end

function ControllerCameraTestAttemptMexBuildSmartAction(x, y, z, forceShift)
	ControllerCameraTestResetMexCommandDebug()

	local builder = WG and WG.resource_spot_builder
	local finder = WG and WG["resource_spot_finder"]
	if type(builder) ~= "table" or type(finder) ~= "table" then
		ControllerCameraTestCommandDebug.mexActionResult = "WG mex APIs unavailable"
		return false
	end
	if finder.isMetalMap then
		ControllerCameraTestCommandDebug.mexActionResult = "metal map disabled"
		return false
	end
	if type(builder.GetMexConstructors) ~= "function"
		or type(builder.GetMexBuildings) ~= "function"
		or type(builder.GetBestExtractorFromBuilders) ~= "function"
		or type(builder.PreviewExtractorCommand) ~= "function"
	then
		ControllerCameraTestCommandDebug.mexActionResult = "builder API incomplete"
		return false
	end
	if type(finder.GetClosestMexSpot) ~= "function" or type(finder.metalSpotsList) ~= "table" then
		ControllerCameraTestCommandDebug.mexActionResult = "finder API incomplete"
		return false
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		ControllerCameraTestCommandDebug.mexActionResult = "no selected units"
		return false
	end

	local mexConstructors = builder.GetMexConstructors()
	local mexBuildings = builder.GetMexBuildings()
	local selectedMex = builder.GetBestExtractorFromBuilders(selectedUnits, mexConstructors, mexBuildings)
	if not selectedMex then
		ControllerCameraTestCommandDebug.mexSmartAvailable = "no"
		ControllerCameraTestCommandDebug.mexActionResult = "selected units cannot build mex"
		return false
	end

	ControllerCameraTestCommandDebug.mexSmartAvailable = "yes"
	ControllerCameraTestCommandDebug.mexBuildingCmdID = tostring(-selectedMex)

	local nearestSpot = finder.GetClosestMexSpot(x, z)
	if not nearestSpot then
		ControllerCameraTestCommandDebug.mexActionResult = "no nearest spot"
		return false
	end
	ControllerCameraTestCommandDebug.mexNearestSpot = "yes"

	local controllerMexTriggerRadius = 80

local spotX = nearestSpot.x or nearestSpot[1]
local spotZ = nearestSpot.z or nearestSpot[3] or nearestSpot[2]

if not spotX or not spotZ then
	ControllerCameraTestCommandDebug.mexNearestSpot = "no"
	ControllerCameraTestCommandDebug.mexActionResult = "mex spot position unavailable, falling back to Move"
	return false
end

local dx = spotX - x
local dz = spotZ - z
local distSq = (dx * dx) + (dz * dz)
local maxDistSq = controllerMexTriggerRadius * controllerMexTriggerRadius

if distSq > maxDistSq then
	ControllerCameraTestCommandDebug.mexNearestSpot = "no"
	ControllerCameraTestCommandDebug.mexActionResult = string.format(
		"not close enough to metal spot %.0f > %d, falling back to Move",
		math.sqrt(distSq),
		controllerMexTriggerRadius
	)
	return false
end

	if type(builder.ExtractorCanBeBuiltOnSpot) == "function" and not builder.ExtractorCanBeBuiltOnSpot(nearestSpot, selectedMex) then
		ControllerCameraTestCommandDebug.mexActionResult = "spot unavailable"
		return false
	end

	local buildCmd = builder.PreviewExtractorCommand({ x, y, z }, selectedMex, nearestSpot)
	if not buildCmd or #buildCmd == 0 then
		ControllerCameraTestCommandDebug.mexActionResult = "preview failed"
		return false
	end

	local cmdID = -buildCmd[1]
	local params = { buildCmd[2], buildCmd[3], buildCmd[4], buildCmd[5] }
	ControllerCameraTestCommandDebug.issuedCmdID = tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = #params

	if type(builder.ApplyPreviewCmds) == "function" then
		local _, _, _, shift = Spring.GetModKeyState()
		shift = forceShift or shift
		local applyOk = pcall(builder.ApplyPreviewCmds, { buildCmd }, mexConstructors, shift)
		if applyOk then
			lastIssuedCommand = "Mex Build (" .. tostring(cmdID) .. ")"
			ControllerCameraTestCommandDebug.mexApplyPreviewPath = "yes"
			ControllerCameraTestCommandDebug.lastResult = "mex via ApplyPreviewCmds"
			ControllerCameraTestCommandDebug.mexActionResult = "issued via ApplyPreviewCmds"
			latchSelectionDebugMessage("X mex build: " .. tostring(cmdID))
			return true
		end
	end

	if type(spGiveOrderToUnit) ~= "function" then
		ControllerCameraTestCommandDebug.mexActionResult = "fallback GiveOrderToUnit unavailable"
		return false
	end

	local issuedCount = 0
	local orderOptions = forceShift and { "shift" } or {}
	for _, unitID in ipairs(selectedUnits) do
		if mexConstructors[unitID] then
			local orderOk = pcall(spGiveOrderToUnit, unitID, cmdID, params, orderOptions)
			if orderOk then
				issuedCount = issuedCount + 1
			end
		end
	end

	if issuedCount > 0 then
		lastIssuedCommand = "Mex Build (" .. tostring(cmdID) .. ")"
		ControllerCameraTestCommandDebug.mexFallbackGiveOrderPath = "yes"
		ControllerCameraTestCommandDebug.lastResult = "mex via GiveOrderToUnit"
		ControllerCameraTestCommandDebug.mexActionResult = "issued via GiveOrderToUnit"
		latchSelectionDebugMessage("X mex build fallback: " .. tostring(cmdID))
		return true
	end

	ControllerCameraTestCommandDebug.mexActionResult = "no selected mex constructors"
	return false
end

local function attemptContextCommand()
	local cmdID = 10 -- Fallback to Move (CMD.MOVE)
	local cmdName = "Move"

	ControllerCameraTestResetMexCommandDebug()
	ControllerCameraTestCommandDebug.defaultCmdIndex = "none"
	ControllerCameraTestCommandDebug.defaultCmdID = "none"
	ControllerCameraTestCommandDebug.defaultCmdType = "none"
	ControllerCameraTestCommandDebug.defaultCmdName = "none"
	ControllerCameraTestCommandDebug.issuedCmdID = "none"
	ControllerCameraTestCommandDebug.issuedParamsCount = 0
	ControllerCameraTestCommandDebug.lastResult = "pending"

	if type(Spring.GetDefaultCommand) == "function" then
		local cmdIndex, defaultCmdID, defaultCmdType, defaultCmdName = Spring.GetDefaultCommand()
		ControllerCameraTestCommandDebug.defaultCmdIndex = tostring(cmdIndex)
		ControllerCameraTestCommandDebug.defaultCmdID = tostring(defaultCmdID)
		ControllerCameraTestCommandDebug.defaultCmdType = tostring(defaultCmdType)
		ControllerCameraTestCommandDebug.defaultCmdName = tostring(defaultCmdName)

		if type(defaultCmdID) == "number" then
			cmdID = defaultCmdID
			cmdName = defaultCmdName or "Smart Action"
		end
	end

	local isBuild = type(cmdID) == "number" and cmdID < 0
	ControllerCameraTestCommandDebug.isBuild = isBuild and "yes" or "no"

	local ok, targetType, targetID = pcall(Spring.TraceScreenRay, screenCenterX, screenCenterY)
	local params = {}
	local targetString = "unknown"

	if isBuild then
		if not reticleHasWorldTarget or not reticleWorldX or not reticleWorldY or not reticleWorldZ then
			ControllerCameraTestCommandDebug.lastResult = "build failed: no world target"
			latchSelectionDebugMessage("X build failed: no world target")
			return
		end

		local facing = 0
		if type(Spring.GetBuildFacing) == "function" then
			local facingOk, buildFacing = pcall(Spring.GetBuildFacing)
			if facingOk and type(buildFacing) == "number" then
				facing = buildFacing
			end
		end
		params = { reticleWorldX, reticleWorldY, reticleWorldZ, facing }
		targetString = "build pos"
	elseif cmdID == 10 and reticleHasWorldTarget and reticleWorldX and reticleWorldY and reticleWorldZ
		and ControllerCameraTestAttemptMexBuildSmartAction(reticleWorldX, reticleWorldY, reticleWorldZ)
	then
		return
	elseif ok and (targetType == "unit" or targetType == "feature") and tonumber(targetID) then
		params = { tonumber(targetID) }
		targetString = targetType .. " " .. tostring(targetID)
	elseif reticleHasWorldTarget and reticleWorldX and reticleWorldY and reticleWorldZ then
		params = { reticleWorldX, reticleWorldY, reticleWorldZ }
		targetString = "ground"
	else
		ControllerCameraTestCommandDebug.lastResult = "context failed: no target"
		latchSelectionDebugMessage("X context failed: no target")
		return
	end

	issueOrderToSelection(cmdID, params, cmdName, targetString)
end

local function attemptAttackCommand()
	if type(spTraceScreenRay) ~= "function" then
		latchSelectionDebugMessage("Attack failed: API unavailable")
		return
	end
	local ok, targetType, targetID = pcall(spTraceScreenRay, screenCenterX, screenCenterY)
	if not ok then
		latchSelectionDebugMessage("Attack failed: trace failed")
		return
	end

	if targetType == "unit" and tonumber(targetID) then
		local unitID = tonumber(targetID)
		issueOrderToSelection(CMD.ATTACK, { unitID }, "Attack", "unit " .. tostring(unitID))
	else
		if not reticleHasWorldTarget or not reticleWorldX or not reticleWorldY or not reticleWorldZ then
			latchSelectionDebugMessage("Attack skipped: no world target")
			return
		end
		local params = { reticleWorldX, reticleWorldY, reticleWorldZ }
		local targetName = string.format("x=%.1f, y=%.1f, z=%.1f", reticleWorldX, reticleWorldY, reticleWorldZ)
		issueOrderToSelection(CMD.ATTACK, params, "Attack-Move", targetName)
	end
end

local function attemptStopCommand()
	issueOrderToSelection(CMD.STOP, {}, "Stop", "none")
end

function ControllerCameraTestSetCommandMarker(x, y, z, label, kind)
	local marker = ControllerCameraTestVisualFeedback
	marker.targetX = x
	marker.targetY = y
	marker.targetZ = z
	marker.label = label or "command"
	marker.kind = kind or string.lower(tostring(label or "generic"))
	marker.expireTime = debugEventTime + 1.0
end

function ControllerCameraTestGetReticleTargetInfo()
	local info = {
		targetType = reticleTargetType,
		targetID = nil,
		x = reticleWorldX,
		y = reticleWorldY,
		z = reticleWorldZ,
		hasWorld = reticleHasWorldTarget,
	}

	if type(spTraceScreenRay) == "function" then
		local ok, targetType, targetID = pcall(spTraceScreenRay, screenCenterX, screenCenterY)
		if ok then
			info.targetType = tostring(targetType or "unavailable")
			info.targetID = tonumber(targetID)
		end
	end
	return info
end

function ControllerCameraTestFeatureCommandID(featureID)
	if not featureID then
		return nil
	end
	if Engine and Engine.FeatureSupport and Engine.FeatureSupport.noOffsetForFeatureID then
		return featureID
	end
	return featureID + (Game.maxUnits or 32000)
end

function ControllerCameraTestIsAlliedUnit(unitID)
	if not unitID or type(Spring.GetUnitTeam) ~= "function" then
		return false
	end

	local unitTeam = Spring.GetUnitTeam(unitID)
	local myTeam = type(Spring.GetMyTeamID) == "function" and Spring.GetMyTeamID()
		or (type(Spring.GetLocalTeamID) == "function" and Spring.GetLocalTeamID() or nil)
	if not unitTeam or not myTeam then
		return false
	end
	if type(Spring.AreTeamsAllied) == "function" then
		return Spring.AreTeamsAllied(myTeam, unitTeam)
	end
	return unitTeam == myTeam
end

function ControllerCameraTestGetUnitDef(unitID)
	if not unitID or type(Spring.GetUnitDefID) ~= "function" then
		return nil, nil
	end
	local unitDefID = Spring.GetUnitDefID(unitID)
	if not unitDefID or not UnitDefs then
		return unitDefID, nil
	end
	return unitDefID, UnitDefs[unitDefID]
end

function ControllerCameraTestIsMobileUnitDef(unitDef)
	if type(unitDef) ~= "table" then
		return true
	end
	if unitDef.isBuilding then
		return false
	end
	if type(unitDef.speed) == "number" then
		return unitDef.speed > 0
	end
	return true
end

function ControllerCameraTestIsCombatUnitDef(unitDef)
	if type(unitDef) ~= "table" then
		return false
	end
	if unitDef.canAttack then
		return true
	end
	return type(unitDef.weapons) == "table" and #unitDef.weapons > 0
end

function ControllerCameraTestGetVisibleAlliedUnits()
	if type(Spring.GetVisibleUnits) ~= "function" then
		return {}
	end

	local visibleUnits = Spring.GetVisibleUnits()
	local alliedUnits = {}
	if type(visibleUnits) ~= "table" then
		return alliedUnits
	end

	for _, unitID in ipairs(visibleUnits) do
		if ControllerCameraTestIsAlliedUnit(unitID) then
			alliedUnits[#alliedUnits + 1] = unitID
		end
	end
	table.sort(alliedUnits)
	return alliedUnits
end

function ControllerCameraTestSelectUnits(units, label)
	if type(spSelectUnitArray) ~= "function" then
		lastSelectionResult = "select API unavailable"
		latchSelectionDebugMessage(tostring(label or "Select") .. " failed: API unavailable")
		return false
	end
	if type(units) ~= "table" or #units == 0 then
		lastSelectionResult = "no units"
		latchSelectionDebugMessage(tostring(label or "Select") .. ": no units")
		return false
	end

	local ok = pcall(spSelectUnitArray, units, false)
	if not ok then
		lastSelectionResult = "select failed"
		latchSelectionDebugMessage(tostring(label or "Select") .. " failed")
		return false
	end

	lastSelectionResult = tostring(label or "selected") .. " " .. tostring(#units)
	lastReticleSelectedUnitID = tostring(units[1])
	latchSelectionDebugMessage(tostring(label or "Selected") .. ": " .. tostring(#units) .. " units")
	return true
end

function ControllerCameraTestIssueOrderToSelectedUnits(cmdID, params, cmdName, targetName, options)
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	params = type(params) == "table" and params or {}
	options = type(options) == "table" and options or {}

	ControllerCameraTestCommandDebug.issuedCmdID = tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = #params
	if type(cmdID) ~= "number" then
		ControllerCameraTestCommandDebug.lastResult = "command unavailable"
		latchSelectionDebugMessage(tostring(cmdName) .. " unavailable")
		return false, 0
	end
	if #selectedUnits == 0 then
		ControllerCameraTestCommandDebug.lastResult = "no selected units"
		latchSelectionDebugMessage(tostring(cmdName) .. " skipped: no units selected")
		return false, 0
	end
	if type(spGiveOrderToUnit) ~= "function" then
		ControllerCameraTestCommandDebug.lastResult = "GiveOrderToUnit unavailable"
		latchSelectionDebugMessage(tostring(cmdName) .. " failed: order API unavailable")
		return false, 0
	end

	local issuedCount = 0
	for _, unitID in ipairs(selectedUnits) do
		local ok, result = pcall(spGiveOrderToUnit, unitID, cmdID, params, options)
		if ok and result ~= false then
			issuedCount = issuedCount + 1
		end
	end

	if issuedCount > 0 then
		lastIssuedCommand = tostring(cmdName) .. " (" .. tostring(targetName or "target") .. ")"
		ControllerCameraTestCommandDebug.lastResult = "issued to " .. tostring(issuedCount) .. " units"
		latchSelectionDebugMessage(tostring(cmdName) .. " ordered to " .. tostring(issuedCount) .. " units")
		if type(params[1]) == "number" and type(params[2]) == "number" and type(params[3]) == "number" then
			ControllerCameraTestSetCommandMarker(params[1], params[2], params[3], cmdName)
		elseif type(params[1]) == "number" and type(Spring.GetUnitPosition) == "function" then
			local x, y, z = Spring.GetUnitPosition(params[1])
			if not x and params[1] > (Game.maxUnits or 32000) and type(Spring.GetFeaturePosition) == "function" then
				x, y, z = Spring.GetFeaturePosition(params[1] - (Game.maxUnits or 32000))
			end
			if x and y and z then
				ControllerCameraTestSetCommandMarker(x, y, z, cmdName)
			end
		end
		return true, issuedCount
	end

	ControllerCameraTestCommandDebug.lastResult = "no orders accepted"
	latchSelectionDebugMessage(tostring(cmdName) .. " failed: no orders accepted")
	return false, 0
end

function ControllerCameraTestSelectVisibleCombatUnits()
	local alliedUnits = ControllerCameraTestGetVisibleAlliedUnits()
	local combatUnits = {}
	local mobileUnits = {}
	local fallbackUnits = {}

	for _, unitID in ipairs(alliedUnits) do
		local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if ControllerCameraTestIsMobileUnitDef(unitDef) then
			mobileUnits[#mobileUnits + 1] = unitID
			if ControllerCameraTestIsCombatUnitDef(unitDef) then
				combatUnits[#combatUnits + 1] = unitID
			end
		elseif #fallbackUnits < 1 then
			fallbackUnits[#fallbackUnits + 1] = unitID
		end
	end

	local units = (#combatUnits > 0 and combatUnits) or (#mobileUnits > 0 and mobileUnits) or fallbackUnits
	ControllerCameraTestCycleDebug.lastCount = #units
	if ControllerCameraTestSelectUnits(units, "RT+A visible combat") then
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+A selected " .. tostring(#units) .. " visible units"
	else
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+A found no safe visible units"
	end
end

function ControllerCameraTestSelectSameTypeAtReticleOrCombat()
	local target = ControllerCameraTestGetReticleTargetInfo()
	if target.targetType == "unit" and target.targetID and ControllerCameraTestIsAlliedUnit(target.targetID) then
		local targetDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(target.targetID)
		if targetDefID then
			local sameTypeUnits = {}
			for _, unitID in ipairs(ControllerCameraTestGetVisibleAlliedUnits()) do
				local unitDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(unitID)
				if unitDefID == targetDefID then
					sameTypeUnits[#sameTypeUnits + 1] = unitID
				end
			end
			if #sameTypeUnits > 0 then
				ControllerCameraTestAreaSelect.lastCount = #sameTypeUnits
				ControllerCameraTestAreaSelect.lastResult = "double tap same type " .. tostring(#sameTypeUnits)
				ControllerCameraTestSelectUnits(sameTypeUnits, "A double-tap same type")
				return
			end
		end
	end

	ControllerCameraTestSelectVisibleCombatUnits()
	ControllerCameraTestAreaSelect.lastResult = "double tap visible combat"
end

function ControllerCameraTestCycleSelection(delta)
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local candidates = {}
	local selectedUnitID = selectedUnits[1]
	local selectedDefID = selectedUnitID and type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(selectedUnitID)

	if #selectedUnits > 1 then
		for _, unitID in ipairs(selectedUnits) do
			candidates[#candidates + 1] = unitID
		end
	elseif selectedDefID then
		for _, unitID in ipairs(ControllerCameraTestGetVisibleAlliedUnits()) do
			local unitDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(unitID)
			if unitDefID == selectedDefID then
				candidates[#candidates + 1] = unitID
			end
		end
	else
		for _, unitID in ipairs(ControllerCameraTestGetVisibleAlliedUnits()) do
			local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
			if ControllerCameraTestIsMobileUnitDef(unitDef) then
				candidates[#candidates + 1] = unitID
			end
		end
	end

	table.sort(candidates)
	if #candidates == 0 then
		ControllerCameraTestCycleDebug.lastResult = "no cycle candidates"
		ControllerCameraTestCycleDebug.lastCount = 0
		latchSelectionDebugMessage("Cycle selection: no candidates")
		return
	end

	local currentIndex = 0
	for i, unitID in ipairs(candidates) do
		if unitID == selectedUnitID then
			currentIndex = i
			break
		end
	end
	local nextIndex = ((currentIndex - 1 + delta) % #candidates) + 1
	local nextUnitID = candidates[nextIndex]
	if ControllerCameraTestSelectUnits({ nextUnitID }, "Cycle selection") then
		ControllerCameraTestCycleDebug.lastResult = "selected " .. tostring(nextUnitID)
		ControllerCameraTestCycleDebug.lastCount = #candidates
		ControllerCameraTestCycleDebug.lastUnitID = tostring(nextUnitID)
	end
end

function ControllerCameraTestStoreCameraBookmark(slot)
	if type(spGetCameraState) ~= "function" then
		ControllerCameraTestBookmarkDebug.lastResult = "camera API unavailable"
		return
	end
	local cameraState = spGetCameraState()
	if type(cameraState) ~= "table" then
		ControllerCameraTestBookmarkDebug.lastResult = "camera state unavailable"
		return
	end

	local copy = {}
	for key, value in pairs(cameraState) do
		copy[key] = value
	end
	ControllerCameraTestBookmarkDebug.slots[slot] = copy
	ControllerCameraTestBookmarkDebug.lastSlot = slot
	ControllerCameraTestBookmarkDebug.lastResult = "stored " .. tostring(slot)
	latchSelectionDebugMessage("Camera bookmark stored: " .. tostring(slot))
end

function ControllerCameraTestRecallCameraBookmark(slot)
	local cameraState = ControllerCameraTestBookmarkDebug.slots[slot]
	if type(cameraState) ~= "table" then
		ControllerCameraTestBookmarkDebug.lastSlot = slot
		ControllerCameraTestBookmarkDebug.lastResult = "empty " .. tostring(slot)
		latchSelectionDebugMessage("Camera bookmark empty: " .. tostring(slot))
		return
	end
	if type(spSetCameraState) ~= "function" then
		ControllerCameraTestBookmarkDebug.lastResult = "SetCameraState unavailable"
		return
	end

	local ok = pcall(spSetCameraState, cameraState, 0.25)
	ControllerCameraTestBookmarkDebug.lastSlot = slot
	ControllerCameraTestBookmarkDebug.lastResult = ok and ("recalled " .. tostring(slot)) or "recall failed"
	latchSelectionDebugMessage("Camera bookmark " .. (ok and "recalled: " or "failed: ") .. tostring(slot))
end

function ControllerCameraTestHandleBookmarkButton(slot)
	if fastPanActive then
		ControllerCameraTestStoreCameraBookmark(slot)
	else
		ControllerCameraTestRecallCameraBookmark(slot)
	end
	ControllerCameraTestLayerDebug.normalUtilityAction = "Bookmark " .. tostring(ControllerCameraTestBookmarkDebug.lastResult)
end

function ControllerCameraTestFilterValidUnits(units)
	local validUnits = {}
	if type(units) ~= "table" then
		return validUnits
	end
	for _, unitID in ipairs(units) do
		local isValid = true
		if type(Spring.GetUnitIsDead) == "function" and Spring.GetUnitIsDead(unitID) then
			isValid = false
		end
		if type(Spring.GetUnitDefID) == "function" and not Spring.GetUnitDefID(unitID) then
			isValid = false
		end
		if isValid then
			validUnits[#validUnits + 1] = unitID
		end
	end
	return validUnits
end

function ControllerCameraTestStoreQuickGroup(slot)
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local units = ControllerCameraTestFilterValidUnits(selectedUnits)
	ControllerCameraTestQuickGroups.currentSlot = slot
	ControllerCameraTestQuickGroups.lastSlot = tostring(slot)
	if #units == 0 then
		ControllerCameraTestQuickGroups.lastResult = "store failed: no selected units"
		ControllerCameraTestTuning.lastAction = "quick group " .. tostring(slot) .. " store failed"
		latchSelectionDebugMessage("Quick group " .. tostring(slot) .. ": no selected units")
		return
	end

	ControllerCameraTestQuickGroups.slots[slot] = units
	ControllerCameraTestQuickGroups.lastResult = "stored " .. tostring(#units) .. " units"
	ControllerCameraTestTuning.lastAction = "quick group " .. tostring(slot) .. " stored"
	latchSelectionDebugMessage("Quick group " .. tostring(slot) .. " stored: " .. tostring(#units))
end

function ControllerCameraTestRecallQuickGroup(slot)
	local units = ControllerCameraTestFilterValidUnits(ControllerCameraTestQuickGroups.slots[slot])
	ControllerCameraTestQuickGroups.currentSlot = slot
	ControllerCameraTestQuickGroups.lastSlot = tostring(slot)
	if #units == 0 then
		ControllerCameraTestQuickGroups.slots[slot] = nil
		ControllerCameraTestQuickGroups.lastResult = "empty"
		ControllerCameraTestTuning.lastAction = "quick group " .. tostring(slot) .. " empty"
		latchSelectionDebugMessage("Quick group " .. tostring(slot) .. " empty")
		return false
	end

	ControllerCameraTestQuickGroups.slots[slot] = units
	ControllerCameraTestQuickGroups.lastResult = "recalled " .. tostring(#units) .. " units"
	ControllerCameraTestTuning.lastAction = "quick group " .. tostring(slot) .. " recalled"
	ControllerCameraTestSelectUnits(units, "Quick group " .. tostring(slot))
	return true
end

function ControllerCameraTestCycleQuickGroup(delta)
	local startSlot = ControllerCameraTestQuickGroups.currentSlot or 1
	for i = 1, 4 do
		local slot = ((startSlot - 1 + (delta * i)) % 4) + 1
		if ControllerCameraTestRecallQuickGroup(slot) then
			ControllerCameraTestLayerDebug.commandLayerAction = "Quick group " .. tostring(slot)
			return true
		end
	end
	ControllerCameraTestQuickGroups.lastResult = "no stored groups"
	latchSelectionDebugMessage("No stored quick groups")
	return false
end

function ControllerCameraTestGetTacticalCommands()
	return {
		{ name = "Stop", cmdID = CMD.STOP, kind = "none" },
		{ name = "Move", cmdID = CMD.MOVE, kind = "ground" },
		{ name = "Attack", cmdID = CMD.ATTACK, kind = "attack" },
		{ name = "Patrol", cmdID = CMD.PATROL, kind = "ground" },
		{ name = "Guard", cmdID = CMD.GUARD, kind = "alliedUnit" },
		{ name = "Reclaim", cmdID = CMD.RECLAIM, kind = "reclaim" },
		{ name = "Repair", cmdID = CMD.REPAIR, kind = "repair" },
	}
end

function ControllerCameraTestRefreshTacticalDebug()
	local menu = ControllerCameraTestTacticalMenu
	local commands = ControllerCameraTestGetTacticalCommands()
	local option = commands[menu.selectedIndex]
	menu.highlightedName = option and option.name or "none"
end

function ControllerCameraTestToggleTacticalMenu()
	local menu = ControllerCameraTestTacticalMenu
	menu.open = not menu.open
	menu.lastAction = menu.open and "opened" or "closed"
	ControllerCameraTestRefreshTacticalDebug()
	latchSelectionDebugMessage(menu.open and "RT+Y tactical menu opened" or "Tactical menu closed")
end

function ControllerCameraTestCycleTacticalCommand(delta)
	local menu = ControllerCameraTestTacticalMenu
	local commands = ControllerCameraTestGetTacticalCommands()
	menu.selectedIndex = ((menu.selectedIndex - 1 + delta) % #commands) + 1
	menu.lastAction = "highlight changed"
	ControllerCameraTestRefreshTacticalDebug()
	latchSelectionDebugMessage("Tactical: " .. tostring(menu.highlightedName))
end

function ControllerCameraTestExecuteTacticalCommand(option)
	if type(option) ~= "table" then
		ControllerCameraTestTacticalMenu.lastResult = "no tactical option"
		return
	end
	if type(option.cmdID) ~= "number" then
		ControllerCameraTestTacticalMenu.lastResult = tostring(option.name) .. " unavailable"
		latchSelectionDebugMessage(tostring(option.name) .. " unavailable")
		return
	end

	local target = ControllerCameraTestGetReticleTargetInfo()
	local params = {}
	local targetName = "none"
	if option.kind == "none" then
		params = {}
	elseif option.kind == "ground" then
		if not target.hasWorld then
			ControllerCameraTestTacticalMenu.lastResult = option.name .. " failed: no ground"
			latchSelectionDebugMessage(option.name .. " failed: no ground target")
			return
		end
		params = { target.x, target.y, target.z }
		targetName = "ground"
	elseif option.kind == "attack" then
		if target.targetType == "unit" and target.targetID then
			params = { target.targetID }
			targetName = "unit " .. tostring(target.targetID)
		elseif target.hasWorld then
			params = { target.x, target.y, target.z }
			targetName = "ground"
		else
			ControllerCameraTestTacticalMenu.lastResult = "attack failed: no target"
			latchSelectionDebugMessage("Attack failed: no target")
			return
		end
	elseif option.kind == "alliedUnit" then
		if target.targetType ~= "unit" or not target.targetID or not ControllerCameraTestIsAlliedUnit(target.targetID) then
			ControllerCameraTestTacticalMenu.lastResult = option.name .. " failed: no allied unit"
			latchSelectionDebugMessage(option.name .. " failed: no allied unit target")
			return
		end
		params = { target.targetID }
		targetName = "unit " .. tostring(target.targetID)
	elseif option.kind == "reclaim" then
		if target.targetType == "feature" and target.targetID then
			params = { ControllerCameraTestFeatureCommandID(target.targetID) }
			targetName = "feature " .. tostring(target.targetID)
		elseif target.targetType == "unit" and target.targetID then
			params = { target.targetID }
			targetName = "unit " .. tostring(target.targetID)
		elseif target.hasWorld then
			params = { target.x, target.y, target.z, 120 }
			targetName = "area"
		else
			ControllerCameraTestTacticalMenu.lastResult = "reclaim failed: no target"
			latchSelectionDebugMessage("Reclaim failed: no target")
			return
		end
	elseif option.kind == "repair" then
		if target.targetType == "unit" and target.targetID and ControllerCameraTestIsAlliedUnit(target.targetID) then
			params = { target.targetID }
			targetName = "unit " .. tostring(target.targetID)
		elseif target.hasWorld then
			params = { target.x, target.y, target.z, 120 }
			targetName = "area"
		else
			ControllerCameraTestTacticalMenu.lastResult = "repair failed: no target"
			latchSelectionDebugMessage("Repair failed: no target")
			return
		end
	end

	local ok, count = ControllerCameraTestIssueOrderToSelectedUnits(option.cmdID, params, option.name, targetName, {})
	ControllerCameraTestTacticalMenu.lastResult = ok and ("issued to " .. tostring(count)) or "failed"
	ControllerCameraTestLayerDebug.commandLayerAction = option.name .. " " .. ControllerCameraTestTacticalMenu.lastResult
end

function ControllerCameraTestHandleTacticalMenuInput()
	local menu = ControllerCameraTestTacticalMenu
	if not menu.open then
		return false
	end

	if WasButtonPressed("B") or WasButtonPressed("Y") then
		menu.open = false
		menu.lastAction = "cancelled"
		latchSelectionDebugMessage("Tactical menu cancelled")
	elseif WasButtonPressed("dpadUp") or WasButtonPressed("LB") then
		ControllerCameraTestCycleTacticalCommand(-1)
	elseif WasButtonPressed("dpadDown") or WasButtonPressed("RB") then
		ControllerCameraTestCycleTacticalCommand(1)
	elseif WasButtonPressed("A") or WasButtonPressed("X") then
		local commands = ControllerCameraTestGetTacticalCommands()
		ControllerCameraTestExecuteTacticalCommand(commands[menu.selectedIndex])
	end
	ControllerCameraTestRefreshTacticalDebug()
	return true
end

function ControllerCameraTestIssueGuardOrPatrol()
	local target = ControllerCameraTestGetReticleTargetInfo()
	if target.targetType == "unit" and target.targetID and ControllerCameraTestIsAlliedUnit(target.targetID) then
		ControllerCameraTestIssueOrderToSelectedUnits(CMD.GUARD, { target.targetID }, "Guard", "unit " .. tostring(target.targetID), {})
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+D-pad Up guard"
	elseif target.hasWorld then
		ControllerCameraTestIssueOrderToSelectedUnits(CMD.PATROL, { target.x, target.y, target.z }, "Patrol", "ground", {})
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+D-pad Up patrol"
	else
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+D-pad Up failed: no target"
		latchSelectionDebugMessage("Guard/Patrol failed: no target")
	end
end

function ControllerCameraTestIssueReclaimOrStop()
	local option = { name = "Reclaim", cmdID = CMD.RECLAIM, kind = "reclaim" }
	ControllerCameraTestExecuteTacticalCommand(option)
	ControllerCameraTestLayerDebug.commandLayerAction = "RT+D-pad Down reclaim"
end

function ControllerCameraTestRefreshBuildMenuDebug()
	local menu = ControllerCameraTestBuildMenu
	local options = type(menu.options) == "table" and menu.options or {}
	local option = options[menu.selectedIndex]
	menu.optionCount = #options
	if option then
		menu.highlightedName = option.name or "unnamed"
		menu.highlightedCmdID = tostring(option.cmdID)
	else
		menu.highlightedName = "none"
		menu.highlightedCmdID = "none"
	end
end

function ControllerCameraTestGetBuildOptionSummary()
	local menu = ControllerCameraTestBuildMenu
	local options = type(menu.options) == "table" and menu.options or {}
	if #options == 0 then
		return "none"
	end

	local labels = {}
	for i, option in ipairs(options) do
		local marker = (i == menu.selectedIndex) and ">" or ""
		labels[#labels + 1] = marker .. tostring(i) .. ":" .. tostring(option.name) .. " (" .. tostring(option.cmdID) .. ")"
		if i >= 12 and i < #options then
			labels[#labels + 1] = "...+" .. tostring(#options - i)
			break
		end
	end
	return table.concat(labels, ", ")
end

function ControllerCameraTestBuildOptionName(cmdID, desc)
	local unitDefID = (type(cmdID) == "number") and -cmdID or nil
	local unitDef = unitDefID and UnitDefs and UnitDefs[unitDefID]
	if unitDef then
		return unitDef.translatedHumanName or unitDef.humanName or unitDef.name or tostring(desc and desc.name or cmdID)
	end
	if desc and desc.name and desc.name ~= "" then
		return desc.name
	end
	if desc and desc.action and desc.action ~= "" then
		return desc.action
	end
	return "Build " .. tostring(unitDefID or cmdID)
end

function ControllerCameraTestClassifyBuildOption(unitDef, name)
	if not unitDef then
		return "Build"
	end

	local nameLower = string.lower(name or "")

	-- Economy Heuristic
	local isEco = unitDef.isExtractor
		or (unitDef.energyMake and unitDef.energyMake > 0)
		or (unitDef.metalMake and unitDef.metalMake > 0)
		or (unitDef.energyStorage and unitDef.energyStorage > 0)
		or (unitDef.metalStorage and unitDef.metalStorage > 0)
		or (unitDef.customParams and (unitDef.customParams.energyprod or unitDef.customParams.metalprod))
		or string.find(nameLower, "solar")
		or string.find(nameLower, "wind")
		or string.find(nameLower, "generator")
		or string.find(nameLower, "fusion")
		or string.find(nameLower, "converter")
		or string.find(nameLower, "mex")
		or string.find(nameLower, "extractor")
		or string.find(nameLower, "storage")
		or string.find(nameLower, "tidal")
		or string.find(nameLower, "geothermal")
	if isEco then
		return "Economy"
	end

	-- Combat Heuristic
	local isCombat = (unitDef.weapons and #unitDef.weapons > 0)
		or unitDef.canAttack
		or string.find(nameLower, "turret")
		or string.find(nameLower, "laser")
		or string.find(nameLower, "cannon")
		or string.find(nameLower, "artillery")
		or string.find(nameLower, "anti")
		or string.find(nameLower, "defense")
		or string.find(nameLower, "fortification")
		or string.find(nameLower, "mine")
		or string.find(nameLower, "missile")
	if isCombat then
		return "Combat"
	end

	-- Utility Heuristic
	local isUtility = (unitDef.radarRadius and unitDef.radarRadius > 0)
		or (unitDef.jammerRadius and unitDef.jammerRadius > 0)
		or (unitDef.sonarRadius and unitDef.sonarRadius > 0)
		or (unitDef.shieldRadius and unitDef.shieldRadius > 0)
		or unitDef.canRepair
		or unitDef.canRestore
		or unitDef.canTransport
		or string.find(nameLower, "radar")
		or string.find(nameLower, "jammer")
		or string.find(nameLower, "sonar")
		or string.find(nameLower, "shield")
		or string.find(nameLower, "repair")
		or string.find(nameLower, "juno")
		or string.find(nameLower, "support")
		or string.find(nameLower, "transport")
		or string.find(nameLower, "targeting")
		or string.find(nameLower, "beacon")
	if isUtility then
		return "Utility"
	end

	-- Build Heuristic
	local isBuild = unitDef.builder
		or string.find(nameLower, "lab")
		or string.find(nameLower, "factory")
		or string.find(nameLower, "gantry")
		or string.find(nameLower, "hub")
		or string.find(nameLower, "builder")
		or string.find(nameLower, "con ")
		or string.find(nameLower, "construction")
	if isBuild then
		return "Build"
	end

	return "Build"
end

function ControllerCameraTestGatherBuildOptions()
	local menu = ControllerCameraTestBuildMenu
	menu.options = {}
	menu.optionCount = 0
	menu.highlightedName = "none"
	menu.highlightedCmdID = "none"

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		menu.lastAction = "no selected units"
		ControllerCameraTestRefreshBuildMenuDebug()
		return 0
	end

	if type(Spring.GetActiveCmdDescs) ~= "function" then
		menu.lastAction = "GetActiveCmdDescs unavailable"
		ControllerCameraTestRefreshBuildMenuDebug()
		return 0
	end

	local cmdDescs = Spring.GetActiveCmdDescs()
	if type(cmdDescs) ~= "table" then
		menu.lastAction = "no active command descriptions"
		ControllerCameraTestRefreshBuildMenuDebug()
		return 0
	end

	local seen = {}
	for index, desc in ipairs(cmdDescs) do
		if type(desc) == "table" and not desc.disabled then
			local cmdID = tonumber(desc.id or desc.cmdID)
			if cmdID and cmdID < 0 and not seen[cmdID] then
				local action = tostring(desc.action or "")
				if action == "" or string.sub(action, 1, 10) == "buildunit_" or (UnitDefs and UnitDefs[-cmdID]) then
					seen[cmdID] = true
					local unitDef = UnitDefs and UnitDefs[-cmdID]
					local name = ControllerCameraTestBuildOptionName(cmdID, desc)
					local cat = ControllerCameraTestClassifyBuildOption(unitDef, name)
					menu.options[#menu.options + 1] = {
						cmdID = cmdID,
						name = name,
						index = index,
						cmdDescIndex = index,
						type = desc.type or "unknown",
						action = action,
						tooltip = desc.tooltip or "",
						unitDefID = -cmdID,
						unitDefName = unitDef and unitDef.name or "unknown",
						buildPicName = unitDef and unitDef.buildPicName or nil,
						iconTexture = "#" .. tostring(-cmdID),
						metalCost = unitDef and unitDef.metalCost or 0,
						energyCost = unitDef and unitDef.energyCost or 0,
						category = cat,
					}
				end
			end
		end
	end

	local hasEco, hasCombat, hasUtility, hasBuild = false, false, false, false
	for _, opt in ipairs(menu.options) do
		if opt.category == "Economy" then hasEco = true
		elseif opt.category == "Combat" then hasCombat = true
		elseif opt.category == "Utility" then hasUtility = true
		elseif opt.category == "Build" then hasBuild = true
		end
	end

	local cats = {}
	if hasEco then cats[#cats + 1] = "Economy" end
	if hasCombat then cats[#cats + 1] = "Combat" end
	if hasUtility then cats[#cats + 1] = "Utility" end
	if hasBuild then cats[#cats + 1] = "Build" end

	if #cats == 0 then
		cats[#cats + 1] = "Build"
	end

	menu.radialCategories = cats

	if menu.selectedIndex < 1 then
		menu.selectedIndex = 1
	elseif menu.selectedIndex > #menu.options then
		menu.selectedIndex = #menu.options
	end
	if menu.selectedIndex < 1 then
		menu.selectedIndex = 1
	end

	ControllerCameraTestRefreshBuildMenuDebug()
	return #menu.options
end

function ControllerCameraTestRefreshRadialVisibleOptions()
	local menu = ControllerCameraTestBuildMenu
	menu.radialVisibleOptions = {}

	local filterCat = menu.radialCategoryName or (menu.radialCategories and menu.radialCategories[1]) or "Build"
	local filtered = {}
	for i, option in ipairs(menu.options) do
		if option.category == filterCat then
			filtered[#filtered + 1] = option
			option.menuIndex = i
		end
	end

	if #filtered == 0 then
		filterCat = (menu.radialCategories and menu.radialCategories[1]) or "Build"
		menu.radialCategoryIndex = 1
		menu.radialCategoryName = filterCat
		for i, option in ipairs(menu.options) do
			if option.category == filterCat then
				filtered[#filtered + 1] = option
				option.menuIndex = i
			end
		end
	end

	local maxPerPage = 8
	local totalFiltered = #filtered
	menu.radialPageCount = math.max(1, math.ceil(totalFiltered / maxPerPage))

	if menu.radialPage < 1 then
		menu.radialPage = 1
	elseif menu.radialPage > menu.radialPageCount then
		menu.radialPage = menu.radialPageCount
	end

	local startIndex = (menu.radialPage - 1) * maxPerPage + 1
	local endIndex = math.min(startIndex + maxPerPage - 1, totalFiltered)

	for i = startIndex, endIndex do
		menu.radialVisibleOptions[#menu.radialVisibleOptions + 1] = filtered[i]
	end

	local currentVisibleSelected = nil
	for i, option in ipairs(menu.radialVisibleOptions) do
		if option.menuIndex == menu.selectedIndex then
			currentVisibleSelected = i
			break
		end
	end

	if not currentVisibleSelected then
		if #menu.radialVisibleOptions > 0 then
			menu.selectedIndex = menu.radialVisibleOptions[1].menuIndex
		end
	end

	ControllerCameraTestRefreshBuildMenuDebug()
end

function ControllerCameraTestGetRadialCurrentOption()
	local menu = ControllerCameraTestBuildMenu
	if type(menu.radialVisibleOptions) == "table" and #menu.radialVisibleOptions > 0 then
		for _, option in ipairs(menu.radialVisibleOptions) do
			if option.menuIndex == menu.selectedIndex then
				return option
			end
		end
		return menu.radialVisibleOptions[1]
	end
	return type(menu.options) == "table" and menu.options[menu.selectedIndex] or nil
end

function ControllerCameraTestSetRadialHighlight(localIndex, reason)
	local menu = ControllerCameraTestBuildMenu
	local count = #menu.radialVisibleOptions
	if count <= 0 then
		return
	end

	localIndex = ((localIndex - 1) % count) + 1
	local option = menu.radialVisibleOptions[localIndex]
	if option and option.menuIndex then
		menu.selectedIndex = option.menuIndex
		menu.lastAction = reason or "radial highlight changed"
		menu.radialLastAction = reason or "radial highlight changed"
		ControllerCameraTestRefreshBuildMenuDebug()
	end
end

function ControllerCameraTestUpdateRadialStickSelection()
	local menu = ControllerCameraTestBuildMenu
	if not menu.open then
		return
	end
	if ControllerCameraTestBuildPlacement.active then
		return
	end

	local aimX = normalizedLeftX
	local aimY = -normalizedLeftY
	local magnitude = math.sqrt(aimX * aimX + aimY * aimY)
	local visibleOptions = menu.radialVisibleOptions or {}
	local visibleCount = #visibleOptions

	if visibleCount <= 0 then
		return
	end

	if magnitude > 0.5 then
		local angle = math.atan2(aimX, aimY)
		if angle < 0 then
			angle = angle + 2 * math.pi
		end
		menu.radialLastAngle = angle

		local segment = 2 * math.pi / visibleCount
		local adjustedAngle = angle + (segment / 2)
		if adjustedAngle >= 2 * math.pi then
			adjustedAngle = adjustedAngle - 2 * math.pi
		end

		local newIndex = math.floor(adjustedAngle / segment) + 1
		local option = visibleOptions[newIndex]
		if option and option.menuIndex and menu.selectedIndex ~= option.menuIndex then
			menu.selectedIndex = option.menuIndex
			menu.lastAction = "stick select"
			menu.radialLastAction = "stick select"
			ControllerCameraTestRefreshBuildMenuDebug()
		end
	end
end

function ControllerCameraTestOpenBuildMenu()
	local menu = ControllerCameraTestBuildMenu
	local count = ControllerCameraTestGatherBuildOptions()
	if count <= 0 then
		menu.open = false
		menu.lastAction = "no build options"
		menu.placementResult = "none"
		latchSelectionDebugMessage("Y build menu: no build options")
		ControllerCameraTestRefreshBuildMenuDebug()
		return
	end

	menu.open = true
	menu.radialCategoryIndex = 1
	menu.radialCategoryName = menu.radialCategories[1] or "Build"
	menu.radialPage = 1
	menu.radialStickArmed = true
	menu.radialLastAngle = 0
	menu.radialLastAction = "none"

	ControllerCameraTestRefreshRadialVisibleOptions()

	menu.lastAction = "opened"
	menu.placementResult = "none"
	activeButtonLayoutSummary = "Build radial: LS/D-pad select | LB/RB page/category | A place | X quick-place | B/Y close"
	latchSelectionDebugMessage("Y build menu opened: " .. tostring(count) .. " options")
	ControllerCameraTestRefreshBuildMenuDebug()
end

function ControllerCameraTestCloseBuildMenu(reason)
	local menu = ControllerCameraTestBuildMenu
	menu.open = false
	menu.lastAction = reason or "closed"
	activeButtonLayoutSummary = commandLayerActive
		and XboxController.commandLayoutSummary
		or XboxController.normalLayoutSummary
	latchSelectionDebugMessage("Build menu closed")
	ControllerCameraTestRefreshBuildMenuDebug()
end

function ControllerCameraTestToggleBuildMenu()
	if ControllerCameraTestBuildMenu.open then
		ControllerCameraTestCloseBuildMenu("closed by Y")
	else
		ControllerCameraTestOpenBuildMenu()
	end
end

function ControllerCameraTestCycleBuildOption(delta)
	local menu = ControllerCameraTestBuildMenu
	local count = #menu.options
	if count <= 0 then
		menu.lastAction = "no options to navigate"
		ControllerCameraTestRefreshBuildMenuDebug()
		return
	end

	menu.selectedIndex = ((menu.selectedIndex - 1 + delta) % count) + 1
	menu.lastAction = "highlight changed"
	ControllerCameraTestRefreshBuildMenuDebug()
	latchSelectionDebugMessage("Build option: " .. tostring(menu.highlightedName))
end

function ControllerCameraTestGetBuildFacing()
	if type(Spring.GetBuildFacing) ~= "function" then
		return 0
	end
	local facingOk, facing = pcall(Spring.GetBuildFacing)
	if facingOk and type(facing) == "number" then
		return facing
	end
	return 0
end

function ControllerCameraTestGetSnappedBuildPosition(cmdID, x, y, z, facing)
	if type(Spring.Pos2BuildPos) ~= "function" or type(cmdID) ~= "number" then
		return x, y, z
	end

	local unitDefID = -cmdID
	local snapOk, sx, sy, sz = pcall(Spring.Pos2BuildPos, unitDefID, x, y, z, facing)
	if snapOk and type(sx) == "number" and type(sy) == "number" and type(sz) == "number" then
		return sx, sy, sz
	end
	return x, y, z
end

function ControllerCameraTestIsMexBuildCommand(cmdID)
	local builder = WG and WG.resource_spot_builder
	if type(builder) ~= "table" or type(builder.GetMexBuildings) ~= "function" then
		return false
	end

	local mexBuildings = builder.GetMexBuildings()
	return type(mexBuildings) == "table" and mexBuildings[-cmdID] ~= nil
end

function ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits)
	if type(selectedUnits) ~= "table" then
		return false
	end
	for _, unitID in ipairs(selectedUnits) do
		local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if type(unitDef) == "table" and unitDef.isFactory then
			return true
		end
	end
	return false
end

function ControllerCameraTestTrySetNativeBuildCommand(option)
	local placement = ControllerCameraTestBuildPlacement
	if not option or not option.cmdDescIndex then
		placement.nativeSetActiveCommandResult = "failed: invalid option or cmdDescIndex"
		return false
	end
	if type(Spring.SetActiveCommand) ~= "function" then
		placement.nativeSetActiveCommandResult = "failed: SetActiveCommand API missing"
		return false
	end

	local ok, res = pcall(Spring.SetActiveCommand, option.cmdDescIndex, 1)
	if ok then
		placement.nativeSetActiveCommandResult = "success"
		placement.cmdDescIndex = option.cmdDescIndex
		return true
	else
		placement.nativeSetActiveCommandResult = "failed: " .. tostring(res)
		return false
	end
end

function ControllerCameraTestClearNativeBuildCommand()
	if type(Spring.SetActiveCommand) ~= "function" then
		return false
	end
	local ok, res = pcall(Spring.SetActiveCommand, 0)
	if not ok then
		pcall(Spring.SetActiveCommand, nil)
	end
	return true
end

function ControllerCameraTestSetPlacementOption(option)
	local placement = ControllerCameraTestBuildPlacement
	if type(option) ~= "table" or type(option.cmdID) ~= "number" or option.cmdID >= 0 then
		placement.active = false
		placement.option = nil
		placement.lastResult = "no highlighted build option"
		latchSelectionDebugMessage("Placement failed: no highlighted option")
		return false
	end

	placement.active = true
	placement.option = option
	placement.facing = ControllerCameraTestGetBuildFacing() % 4
	if type(Spring.SetBuildFacing) == "function" then
		pcall(Spring.SetBuildFacing, placement.facing)
	end
	placement.analogRotateArmed = true
	placement.lastResult = "placing " .. tostring(option.name)
	latchSelectionDebugMessage("Placement: " .. tostring(option.name))
	return true
end

function ControllerCameraTestCancelPlacement(reason)
	local placement = ControllerCameraTestBuildPlacement
	if placement.nativePreviewActive then
		ControllerCameraTestClearNativeBuildCommand()
		placement.nativePreviewActive = false
	end
	placement.active = false
	placement.option = nil
	placement.lastResult = reason or "cancelled"
	placement.lastParamsCount = 0
	placement.lastIssuedCount = 0
	placement.queueActive = false
	placement.placementMode = "none"
	placement.cmdDescIndex = nil
	placement.nativeSetActiveCommandResult = "none"
	latchSelectionDebugMessage("Placement cancelled")
end

function ControllerCameraTestRotatePlacementFacing(delta)
	local placement = ControllerCameraTestBuildPlacement
	placement.facing = ((placement.facing or 0) + delta) % 4
	if type(Spring.SetBuildFacing) == "function" then
		pcall(Spring.SetBuildFacing, placement.facing)
	end
	placement.lastResult = "facing " .. tostring(placement.facing)
	latchSelectionDebugMessage("Build facing: " .. tostring(placement.facing))
end

function ControllerCameraTestUpdatePlacementAnalog()
	local placement = ControllerCameraTestBuildPlacement
	if not placement.active then
		return
	end

	if math.abs(normalizedRightX) < 0.28 then
		placement.analogRotateArmed = true
	elseif placement.analogRotateArmed and math.abs(normalizedRightX) > 0.72 then
		ControllerCameraTestRotatePlacementFacing(normalizedRightX > 0 and 1 or -1)
		placement.analogRotateArmed = false
	end
end

function ControllerCameraTestPlaceBuildOption(option, exitPlacement, source)
	local menu = ControllerCameraTestBuildMenu
	local queueActive = normalizedLeftTrigger > 0
	local orderOptions = queueActive and { "shift" } or {}
	ControllerCameraTestBuildPlacement.queueActive = queueActive
	if not option or type(option.cmdID) ~= "number" or option.cmdID >= 0 then
		menu.placementResult = "no highlighted build option"
		menu.placementParamsCount = 0
		ControllerCameraTestBuildPlacement.lastResult = "no highlighted build option"
		menu.lastAction = "place failed"
		latchSelectionDebugMessage("Build place failed: no highlighted option")
		ControllerCameraTestRefreshBuildMenuDebug()
		return false
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		menu.placementResult = "no selected units"
		menu.placementParamsCount = 0
		ControllerCameraTestBuildPlacement.lastResult = "no selected units"
		menu.lastAction = "place failed"
		latchSelectionDebugMessage("Build place failed: no units selected")
		ControllerCameraTestRefreshBuildMenuDebug()
		return false
	end

	if ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits) then
		local ok, issuedCount = ControllerCameraTestIssueOrderToSelectedUnits(option.cmdID, {}, "Factory queue " .. tostring(option.name), "queue", orderOptions)
		menu.placementParamsCount = 0
		ControllerCameraTestBuildPlacement.lastParamsCount = 0
		ControllerCameraTestBuildPlacement.lastIssuedCount = issuedCount
		if ok then
			menu.placementResult = "factory queued to " .. tostring(issuedCount)
			menu.lastAction = source or "factory queued"
			ControllerCameraTestBuildPlacement.lastResult = menu.placementResult
			if exitPlacement then
				if ControllerCameraTestBuildPlacement.nativePreviewActive then
					ControllerCameraTestClearNativeBuildCommand()
					ControllerCameraTestBuildPlacement.nativePreviewActive = false
				end
				ControllerCameraTestBuildPlacement.active = false
				ControllerCameraTestBuildPlacement.placementMode = "none"
				ControllerCameraTestBuildPlacement.cmdDescIndex = nil
				ControllerCameraTestBuildPlacement.nativeSetActiveCommandResult = "none"
			end
		else
			menu.placementResult = "factory queue failed"
			menu.lastAction = "queue failed"
			ControllerCameraTestBuildPlacement.lastResult = menu.placementResult
		end
		ControllerCameraTestRefreshBuildMenuDebug()
		return ok
	end

	if not reticleHasWorldTarget or not reticleWorldX or not reticleWorldY or not reticleWorldZ then
		menu.placementResult = "no world target"
		menu.placementParamsCount = 0
		ControllerCameraTestBuildPlacement.lastResult = "no world target"
		menu.lastAction = "place failed"
		latchSelectionDebugMessage("Build place failed: no world target")
		ControllerCameraTestRefreshBuildMenuDebug()
		return false
	end

	if ControllerCameraTestIsMexBuildCommand(option.cmdID)
		and ControllerCameraTestAttemptMexBuildSmartAction(reticleWorldX, reticleWorldY, reticleWorldZ, queueActive)
	then
		menu.placementResult = "mex smart action"
		menu.placementParamsCount = 4
		menu.lastAction = source or "placed mex via BAR snap"
		ControllerCameraTestBuildPlacement.lastResult = "mex smart action"
		ControllerCameraTestBuildPlacement.lastParamsCount = 4
		ControllerCameraTestBuildPlacement.lastIssuedCount = #selectedUnits
		if exitPlacement then
			if ControllerCameraTestBuildPlacement.nativePreviewActive then
				ControllerCameraTestClearNativeBuildCommand()
				ControllerCameraTestBuildPlacement.nativePreviewActive = false
			end
			ControllerCameraTestBuildPlacement.active = false
			ControllerCameraTestBuildPlacement.placementMode = "none"
			ControllerCameraTestBuildPlacement.cmdDescIndex = nil
			ControllerCameraTestBuildPlacement.nativeSetActiveCommandResult = "none"
		end
		ControllerCameraTestRefreshBuildMenuDebug()
		return true
	end

	if type(spGiveOrderToUnit) ~= "function" then
		menu.placementResult = "GiveOrderToUnit unavailable"
		menu.placementParamsCount = 0
		ControllerCameraTestBuildPlacement.lastResult = "GiveOrderToUnit unavailable"
		menu.lastAction = "place failed"
		latchSelectionDebugMessage("Build place failed: order API unavailable")
		ControllerCameraTestRefreshBuildMenuDebug()
		return false
	end

	local facing = ControllerCameraTestBuildPlacement.active and ControllerCameraTestBuildPlacement.facing or ControllerCameraTestGetBuildFacing()
	local x, y, z = ControllerCameraTestGetSnappedBuildPosition(option.cmdID, reticleWorldX, reticleWorldY, reticleWorldZ, facing)
	local params = { x, y, z, facing }
	local issuedCount = 0
	for _, unitID in ipairs(selectedUnits) do
		local orderOk, orderResult = pcall(spGiveOrderToUnit, unitID, option.cmdID, params, orderOptions)
		if orderOk and orderResult ~= false then
			issuedCount = issuedCount + 1
		end
	end

	ControllerCameraTestCommandDebug.issuedCmdID = tostring(option.cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = #params
	menu.placementParamsCount = #params
	ControllerCameraTestBuildPlacement.lastParamsCount = #params
	ControllerCameraTestBuildPlacement.lastIssuedCount = issuedCount
	if issuedCount > 0 then
		lastIssuedCommand = "Build menu: " .. tostring(option.name)
		menu.placementResult = "issued to " .. tostring(issuedCount) .. " units"
		menu.lastAction = source or "placed"
		ControllerCameraTestBuildPlacement.lastResult = menu.placementResult
		ControllerCameraTestCommandDebug.lastResult = "build menu GiveOrderToUnit"
		latchSelectionDebugMessage("Build placed: " .. tostring(option.name))
		ControllerCameraTestSetCommandMarker(x, y, z, "Build", "build")
		if exitPlacement then
			if ControllerCameraTestBuildPlacement.nativePreviewActive then
				ControllerCameraTestClearNativeBuildCommand()
				ControllerCameraTestBuildPlacement.nativePreviewActive = false
			end
			ControllerCameraTestBuildPlacement.active = false
			ControllerCameraTestBuildPlacement.placementMode = "none"
			ControllerCameraTestBuildPlacement.cmdDescIndex = nil
			ControllerCameraTestBuildPlacement.nativeSetActiveCommandResult = "none"
		end
		ControllerCameraTestRefreshBuildMenuDebug()
		return true
	else
		menu.placementResult = "no orders accepted"
		menu.lastAction = "place failed"
		ControllerCameraTestBuildPlacement.lastResult = "no orders accepted"
		ControllerCameraTestCommandDebug.lastResult = "build menu failed"
		latchSelectionDebugMessage("Build place failed: no orders accepted")
	end
	ControllerCameraTestRefreshBuildMenuDebug()
	return false
end

function ControllerCameraTestPlaceHighlightedBuildOption(exitPlacement, source)
	local menu = ControllerCameraTestBuildMenu
	local option = type(menu.options) == "table" and menu.options[menu.selectedIndex] or nil
	return ControllerCameraTestPlaceBuildOption(option, exitPlacement, source)
end

function ControllerCameraTestEnterPlacementFromHighlight()
	local menu = ControllerCameraTestBuildMenu
	local option = type(menu.options) == "table" and menu.options[menu.selectedIndex] or nil
	if not option then
		menu.lastAction = "placement failed: no option"
		ControllerCameraTestRefreshBuildMenuDebug()
		return
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits) then
		local placement = ControllerCameraTestBuildPlacement
		placement.placementMode = "factory-queue"
		ControllerCameraTestPlaceBuildOption(option, true, "factory queued from menu")
		return
	end

	-- Try native placement first for buildings/structures (non-mobile units)
	local placement = ControllerCameraTestBuildPlacement
	placement.nativePreviewActive = false

	local tryNative = false
	local unitDef = option.unitDefID and UnitDefs and UnitDefs[option.unitDefID]
	if unitDef and not unitDef.isMobile then
		tryNative = true
	end

	if tryNative then
		if ControllerCameraTestTrySetNativeBuildCommand(option) then
			placement.active = true
			placement.option = option
			placement.facing = ControllerCameraTestGetBuildFacing() % 4
			if type(Spring.SetBuildFacing) == "function" then
				pcall(Spring.SetBuildFacing, placement.facing)
			end
			placement.analogRotateArmed = true
			placement.nativePreviewActive = true
			placement.lastResult = "native placement active"
			placement.placementMode = "native"
			menu.lastAction = "entered native placement"
			latchSelectionDebugMessage("Placement: " .. tostring(option.name) .. " (native)")
			ControllerCameraTestRefreshBuildMenuDebug()
			return
		end
	end

	-- Fallback to existing custom placement logic
	if ControllerCameraTestSetPlacementOption(option) then
		placement.nativePreviewActive = false
		placement.placementMode = "custom"
		menu.lastAction = "entered custom placement"
	else
		menu.lastAction = "placement failed"
	end
	ControllerCameraTestRefreshBuildMenuDebug()
end

function ControllerCameraTestHandlePlacementInput()
	local placement = ControllerCameraTestBuildPlacement
	if not placement.active then
		return false
	end

	placement.queueActive = normalizedLeftTrigger > 0
	ControllerCameraTestUpdatePlacementAnalog()
	if WasButtonPressed("B") then
		ControllerCameraTestCancelPlacement("cancelled by B")
	elseif WasButtonPressed("A") then
		ControllerCameraTestPlaceBuildOption(placement.option, true, "placed and exited")
	elseif WasButtonPressed("X") then
		ControllerCameraTestPlaceBuildOption(placement.option, false, "placed and remained")
	elseif WasButtonPressed("dpadLeft") then
		ControllerCameraTestRotatePlacementFacing(-1)
	elseif WasButtonPressed("dpadRight") then
		ControllerCameraTestRotatePlacementFacing(1)
	elseif WasButtonPressed("Y") then
		ControllerCameraTestCancelPlacement("cancelled by Y")
	end

	activeButtonLayoutSummary = "Placement: A place+exit, X place again, B cancel, D-pad/RS X rotate"
	return true
end

function ControllerCameraTestHandleBuildMenuInput()
	local menu = ControllerCameraTestBuildMenu
	if not menu.open then
		return false
	end

	if ControllerCameraTestBuildPlacement.active then
		return false
	end

	local currentLocalIndex = 1
	for idx, option in ipairs(menu.radialVisibleOptions or {}) do
		if option.menuIndex == menu.selectedIndex then
			currentLocalIndex = idx
			break
		end
	end

	local categories = menu.radialCategories or { "Economy", "Combat", "Utility", "Build" }

	if WasButtonPressed("B") then
		ControllerCameraTestCloseBuildMenu("closed by B")
	elseif WasButtonPressed("Y") then
		ControllerCameraTestCloseBuildMenu("closed by Y")
	elseif WasButtonPressed("A") then
		ControllerCameraTestEnterPlacementFromHighlight()
		ControllerCameraTestCloseBuildMenu("entered placement")
	elseif WasButtonPressed("X") then
		ControllerCameraTestPlaceHighlightedBuildOption(false, "quick placed from radial")
	elseif WasButtonPressed("dpadDown") or WasButtonPressed("dpadRight") then
		ControllerCameraTestSetRadialHighlight(currentLocalIndex + 1, "dpad next")
	elseif WasButtonPressed("dpadUp") or WasButtonPressed("dpadLeft") then
		ControllerCameraTestSetRadialHighlight(currentLocalIndex - 1, "dpad prev")
	elseif WasButtonPressed("LB") then
		if menu.radialPage > 1 then
			menu.radialPage = menu.radialPage - 1
			ControllerCameraTestRefreshRadialVisibleOptions()
		else
			menu.radialCategoryIndex = ((menu.radialCategoryIndex - 2) % #categories) + 1
			menu.radialCategoryName = categories[menu.radialCategoryIndex]
			menu.radialPage = 1
			ControllerCameraTestRefreshRadialVisibleOptions()
			if #menu.radialVisibleOptions > 0 then
				menu.selectedIndex = menu.radialVisibleOptions[1].menuIndex
			end
		end
		menu.lastAction = "category/page prev"
	elseif WasButtonPressed("RB") then
		if menu.radialPage < menu.radialPageCount then
			menu.radialPage = menu.radialPage + 1
			ControllerCameraTestRefreshRadialVisibleOptions()
		else
			menu.radialCategoryIndex = (menu.radialCategoryIndex % #categories) + 1
			menu.radialCategoryName = categories[menu.radialCategoryIndex]
			menu.radialPage = 1
			ControllerCameraTestRefreshRadialVisibleOptions()
			if #menu.radialVisibleOptions > 0 then
				menu.selectedIndex = menu.radialVisibleOptions[1].menuIndex
			end
		end
		menu.lastAction = "category/page next"
	end

	activeButtonLayoutSummary = "Build radial: LS/D-pad select | LB/RB page/category | A place | X quick-place | B/Y close"
	ControllerCameraTestRefreshBuildMenuDebug()
	return true
end

function ControllerCameraTestCancelAreaSelect(reason)
	local area = ControllerCameraTestAreaSelect
	area.pressActive = false
	area.active = false
	area.lastResult = reason or "cancelled"
	ControllerCameraTestLayerDebug.areaSelect = area.lastResult
end

function ControllerCameraTestUpdateAreaRadius(dt)
	local area = ControllerCameraTestAreaSelect
	local radiusDelta = 0
	if normalizedRightY ~= 0 then
		radiusDelta = radiusDelta + (-normalizedRightY * 520 * (dt or 0))
	end
	if WasButtonPressed("dpadUp") or WasButtonPressed("dpadRight") then
		radiusDelta = radiusDelta + 80
	elseif WasButtonPressed("dpadDown") or WasButtonPressed("dpadLeft") then
		radiusDelta = radiusDelta - 80
	end
	if radiusDelta ~= 0 then
		area.radius = clamp(area.radius + radiusDelta, 120, 1200)
		ControllerCameraTestSettings.areaSelectRadius = area.radius
	end
end

function ControllerCameraTestSelectAreaUnits()
	local area = ControllerCameraTestAreaSelect
	if not reticleHasWorldTarget or not reticleWorldX or not reticleWorldZ then
		area.lastResult = "no world target"
		area.lastCount = 0
		ControllerCameraTestLayerDebug.areaSelect = area.lastResult
		latchSelectionDebugMessage("Area select failed: no world target")
		return
	end
	if type(spGetUnitPosition) ~= "function" then
		area.lastResult = "unit position API unavailable"
		area.lastCount = 0
		ControllerCameraTestLayerDebug.areaSelect = area.lastResult
		latchSelectionDebugMessage("Area select failed: position API unavailable")
		return
	end

	local radiusSq = area.radius * area.radius
	local units = {}
	for _, unitID in ipairs(ControllerCameraTestGetVisibleAlliedUnits()) do
		local x, _, z = spGetUnitPosition(unitID)
		if x and z then
			local dx = x - reticleWorldX
			local dz = z - reticleWorldZ
			if ((dx * dx) + (dz * dz)) <= radiusSq then
				units[#units + 1] = unitID
			end
		end
	end

	area.lastCount = #units
	if ControllerCameraTestSelectUnits(units, "Area select") then
		area.lastResult = "selected " .. tostring(#units)
	else
		area.lastResult = "no units selected"
	end
	ControllerCameraTestLayerDebug.areaSelect = area.lastResult
end

function ControllerCameraTestHandleNormalAInput(dt)
	local area = ControllerCameraTestAreaSelect
	local HOLD_SECONDS = 0.38

	if WasButtonPressed("A") then
		area.pressActive = true
		area.active = false
		area.pressStartTime = debugEventTime
		area.lastResult = "press started"
		ControllerCameraTestLayerDebug.areaSelect = area.lastResult
	end

	if area.pressActive and IsButtonDown("A") then
		if not area.active and (debugEventTime - area.pressStartTime) >= HOLD_SECONDS then
			area.active = true
			area.lastResult = "active"
			ControllerCameraTestLayerDebug.areaSelect = "active radius " .. tostring(math.floor(area.radius))
			latchSelectionDebugMessage("Area select active")
		end
		if area.active then
			ControllerCameraTestUpdateAreaRadius(dt)
			ControllerCameraTestLayerDebug.areaSelect = "active radius " .. tostring(math.floor(area.radius))
		end
	end

	if WasButtonReleased("A") and area.pressActive then
		if area.active then
			ControllerCameraTestSelectAreaUnits()
		elseif (debugEventTime - (area.lastTapTime or -10)) <= 0.35 then
			ControllerCameraTestSelectSameTypeAtReticleOrCombat()
			area.lastTapTime = -10
		else
			attemptReticleSelection()
			area.lastTapTime = debugEventTime
		end
		area.pressActive = false
		area.active = false
	end

	return area.pressActive or area.active
end

local function attemptBuildMenu()
	ControllerCameraTestToggleBuildMenu()
end

function ControllerCameraTestSetLayerAction(message)
	ControllerCameraTestLayerDebug.commandLayerAction = message
	lastIssuedCommand = message
	latchSelectionDebugMessage(message)
end

local function attemptCommandWheel()
	ControllerCameraTestToggleTacticalMenu()
end

function ControllerCameraTestSetNormalUtilityAction(message)
	ControllerCameraTestLayerDebug.normalUtilityAction = message
	lastIssuedCommand = message
	latchSelectionDebugMessage(message)
end

function ControllerCameraTestHandleCommandLayerInput()
	if ControllerCameraTestHandleTacticalMenuInput() then
		return
	end

	if WasButtonPressed("A") then
		ControllerCameraTestSelectVisibleCombatUnits()
	elseif WasButtonPressed("B") then
		attemptStopCommand()
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+B stop"
	elseif WasButtonPressed("X") then
		attemptAttackCommand()
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+X attack/attack-move"
	elseif WasButtonPressed("Y") then
		ControllerCameraTestToggleTacticalMenu()
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+Y tactical menu"
	elseif WasButtonPressed("dpadUp") then
		ControllerCameraTestIssueGuardOrPatrol()
	elseif WasButtonPressed("dpadDown") then
		ControllerCameraTestIssueReclaimOrStop()
	elseif WasButtonPressed("dpadLeft") then
		if not ControllerCameraTestCycleQuickGroup(-1) then
			ControllerCameraTestCycleSelection(-1)
			ControllerCameraTestLayerDebug.commandLayerAction = "RT+D-pad Left cycle selection"
		end
	elseif WasButtonPressed("dpadRight") then
		if not ControllerCameraTestCycleQuickGroup(1) then
			ControllerCameraTestCycleSelection(1)
			ControllerCameraTestLayerDebug.commandLayerAction = "RT+D-pad Right cycle selection"
		end
	elseif WasButtonPressed("LB") then
		ControllerCameraTestCycleSelection(-1)
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+LB previous selection"
	elseif WasButtonPressed("RB") then
		ControllerCameraTestCycleSelection(1)
		ControllerCameraTestLayerDebug.commandLayerAction = "RT+RB next selection"
	end
end

function ControllerCameraTestUpdateLBTapState()
	if commandLayerActive
		or ControllerCameraTestBuildMenu.open
		or ControllerCameraTestBuildPlacement.active
		or ControllerCameraTestAreaSelect.active
	then
		ControllerCameraTestCycleDebug.lbPressActive = false
		ControllerCameraTestCycleDebug.lbHadPitchMotion = false
		return
	end

	if WasButtonPressed("LB") then
		ControllerCameraTestCycleDebug.lbPressActive = true
		ControllerCameraTestCycleDebug.lbHadPitchMotion = false
	end
	if IsButtonDown("LB") and math.abs(normalizedRightY) > 0.2 then
		ControllerCameraTestCycleDebug.lbHadPitchMotion = true
	end
end

function ControllerCameraTestCanUseTuningControls()
	return not commandLayerActive
		and not ControllerCameraTestBuildMenu.open
		and not ControllerCameraTestBuildPlacement.active
		and not ControllerCameraTestTacticalMenu.open
		and not ControllerCameraTestAreaSelect.active
		and not ControllerCameraTestAreaSelect.pressActive
end

function ControllerCameraTestHandleBackViewControls()
	if not ControllerCameraTestCanUseTuningControls() then
		ControllerCameraTestTuning.backHeld = false
		ControllerCameraTestTuning.backComboUsed = false
		return false
	end

	if WasButtonPressed("back") then
		ControllerCameraTestTuning.backHeld = true
		ControllerCameraTestTuning.backComboUsed = false
	end

	if IsButtonDown("back") then
		local usedCombo = false
		if WasButtonPressed("dpadLeft") then
			ControllerCameraTestCycleTuningSetting(-1)
			usedCombo = true
		elseif WasButtonPressed("dpadRight") then
			ControllerCameraTestCycleTuningSetting(1)
			usedCombo = true
		elseif WasButtonPressed("dpadUp") then
			ControllerCameraTestAdjustTuningSetting(1)
			usedCombo = true
		elseif WasButtonPressed("dpadDown") then
			ControllerCameraTestAdjustTuningSetting(-1)
			usedCombo = true
		elseif WasButtonPressed("A") then
			ControllerCameraTestStoreQuickGroup(1)
			usedCombo = true
		elseif WasButtonPressed("B") then
			ControllerCameraTestStoreQuickGroup(2)
			usedCombo = true
		elseif WasButtonPressed("X") then
			ControllerCameraTestStoreQuickGroup(3)
			usedCombo = true
		elseif WasButtonPressed("Y") then
			ControllerCameraTestStoreQuickGroup(4)
			usedCombo = true
		elseif WasButtonPressed("LB") then
			ControllerCameraTestCycleQuickGroup(-1)
			usedCombo = true
		elseif WasButtonPressed("RB") then
			ControllerCameraTestCycleQuickGroup(1)
			usedCombo = true
		end

		if usedCombo then
			ControllerCameraTestTuning.backComboUsed = true
			ControllerCameraTestLayerDebug.normalUtilityAction = "Back/View combo: " .. tostring(ControllerCameraTestTuning.lastAction)
		end
		return true
	end

	if WasButtonReleased("back") and ControllerCameraTestTuning.backHeld then
		if not ControllerCameraTestTuning.backComboUsed then
			ControllerCameraTestSettings.debugPanelVisible = not ControllerCameraTestSettings.debugPanelVisible
			ControllerCameraTestTuning.lastAction = "debug panel " .. (ControllerCameraTestSettings.debugPanelVisible and "shown" or "hidden")
			latchSelectionDebugMessage("Debug panel " .. (ControllerCameraTestSettings.debugPanelVisible and "shown" or "hidden"))
		end
		ControllerCameraTestTuning.backHeld = false
		ControllerCameraTestTuning.backComboUsed = false
		return true
	end

	return false
end

function ControllerCameraTestHandleNormalUtilityInput()
	if WasButtonPressed("RB") then
		ControllerCameraTestCycleSelection(1)
		ControllerCameraTestLayerDebug.normalUtilityAction = "RB cycle selection"
	elseif WasButtonReleased("LB") and ControllerCameraTestCycleDebug.lbPressActive then
		if not ControllerCameraTestCycleDebug.lbHadPitchMotion then
			ControllerCameraTestCycleSelection(-1)
			ControllerCameraTestLayerDebug.normalUtilityAction = "LB tap cycle selection"
		end
		ControllerCameraTestCycleDebug.lbPressActive = false
		ControllerCameraTestCycleDebug.lbHadPitchMotion = false
	elseif WasButtonPressed("dpadUp") then
		ControllerCameraTestHandleBookmarkButton("up")
	elseif WasButtonPressed("dpadDown") then
		ControllerCameraTestHandleBookmarkButton("down")
	elseif WasButtonPressed("dpadLeft") then
		ControllerCameraTestHandleBookmarkButton("left")
	elseif WasButtonPressed("dpadRight") then
		ControllerCameraTestHandleBookmarkButton("right")
	elseif WasButtonPressed("start") then
		ControllerCameraTestSettings.helpOverlayVisible = not ControllerCameraTestSettings.helpOverlayVisible
		ControllerCameraTestSetNormalUtilityAction("Help overlay " .. (ControllerCameraTestSettings.helpOverlayVisible and "shown" or "hidden"))
	end
end

function ControllerCameraTestGetModeSummary()
	if commandLayerActive then
		if ControllerCameraTestTacticalMenu.open then
			return "tactical menu"
		end
		return "command layer"
	end
	if ControllerCameraTestBuildPlacement.active then
		return "placement"
	end
	if ControllerCameraTestBuildMenu.open then
		return "build menu"
	end
	if ControllerCameraTestAreaSelect.active then
		return "area select"
	end
	if ControllerCameraTestTuning.backHeld then
		return "tuning"
	end
	if ControllerCameraTestSettings.helpOverlayVisible then
		return "help overlay"
	end
	if controllerMode then
		return "normal"
	end
	return "mouse"
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
	local mathMax = math.max
	if type(cameraState.py) ~= "number" then
		return false
	end

	cameraState.py = cameraState.py - (zoomInput * ControllerCameraTestSettings.zoomSpeed * (dt or 0))

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
	local mathCos, mathSin = math.cos, math.sin
	if rotationInput == 0 then
		rotationMethod = "none"
		return
	end

	local rotationAmount = rotationInput * ControllerCameraTestSettings.rotationSpeed * (dt or 0)

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
	local mathCos, mathSin = math.cos, math.sin
	if pitchInput == 0 then
		pitchMethod = "none"
		return
	end

	local pitchAmount = pitchInput * ControllerCameraTestSettings.pitchSpeed * (dt or 0)

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

	local distance = ControllerCameraTestSettings.panSpeed * (panMultiplier or 1) * (dt or 0)
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
	local RETICLE_SEGMENTS = 28
	local mathCos, mathSin, mathPi = math.cos, math.sin, math.pi
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, RETICLE_SEGMENTS - 1 do
			local angle = (i / RETICLE_SEGMENTS) * mathPi * 2
			gl.Vertex(cx + (mathCos(angle) * radius), cy + (mathSin(angle) * radius))
		end
	end)
end

local function drawReticleLines(cx, cy)
	local RETICLE_GAP = 5
	local RETICLE_LINE_LENGTH = 11
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

	local RETICLE_RADIUS = ControllerCameraTestSettings.reticleSize

	gl.LineWidth(4)
	gl.Color(0, 0, 0, 0.42)
	drawReticleCircle(screenCenterX, screenCenterY, RETICLE_RADIUS)
	drawReticleLines(screenCenterX, screenCenterY)

	gl.LineWidth(2)

	-- Apply colors based on unit alignment
	if reticleTargetAlignment == "enemy" then
		gl.Color(1.0, 0.2, 0.2, 0.9) -- Red for Enemies
	elseif reticleTargetAlignment == "ally" then
		gl.Color(0.2, 1.0, 0.2, 0.9) -- Green for Allies & Self
	else
		gl.Color(0.65, 0.92, 1.0, 0.78) -- Default Blue/White for Ground
	end

	drawReticleCircle(screenCenterX, screenCenterY, RETICLE_RADIUS)
	drawReticleLines(screenCenterX, screenCenterY)

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function widget:Initialize()
	apiAvailable = type(spGetAvailableControllers) == "function" and type(spGetControllerState) == "function"
	updateScreenCenter(spGetViewGeometry())
	ensureDebugPanelInitialized()
end

function widget:ViewResize(vsx, vsy)
	updateScreenCenter(vsx, vsy)
	ensureDebugPanelInitialized()
end

function ControllerCameraTestBeginControllerUpdate(dt)
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
		return nil
	end

	return state
end

function ControllerCameraTestUpdateControllerAxesAndButtons(state)
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
end

function ControllerCameraTestUpdateControllerModeAndCommandLayer(dt)
	fastPanActive = normalizedLeftTrigger > 0
	lbCameraModifierActive = IsButtonDown("LB")
	commandLayerActive = normalizedRightTrigger > 0
	if not commandLayerActive and ControllerCameraTestTacticalMenu.open then
		ControllerCameraTestTacticalMenu.open = false
		ControllerCameraTestTacticalMenu.lastAction = "closed: RT released"
	end
	ControllerCameraTestUpdateLBTapState()
	updateSelectionTestActive()

	if commandLayerActive then
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by RT layer")
		end
		ControllerCameraTestHandleCommandLayerInput()
	elseif ControllerCameraTestHandlePlacementInput() then
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by placement")
		end
	elseif ControllerCameraTestHandleBuildMenuInput() then
		-- Build-menu input consumes normal A/B/Y/D-pad actions while it is open.
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by build menu")
		end
	elseif ControllerCameraTestHandleBackViewControls() then
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by Back/View")
		end
	else
		local areaBusy = ControllerCameraTestHandleNormalAInput(dt)
		if areaBusy and WasButtonPressed("B") then
			ControllerCameraTestCancelAreaSelect("cancelled by B")
		elseif not areaBusy and WasButtonPressed("B") then
			attemptClearSelection()
		end
		if not areaBusy and WasButtonPressed("X") then
			attemptContextCommand()
		end
		if not areaBusy and WasButtonPressed("Y") then
			attemptBuildMenu()
		end
		if not areaBusy then
			ControllerCameraTestHandleNormalUtilityInput()
		end
	end

	ControllerCameraTestLayerDebug.modeSummary = ControllerCameraTestGetModeSummary()
	if commandLayerActive then
		activeButtonLayoutSummary = ControllerCameraTestTacticalMenu.open and "Tactical: A/X confirm, B/Y cancel, D-pad/LB/RB choose"
			or XboxController.commandLayoutSummary
	elseif ControllerCameraTestBuildPlacement.active then
		activeButtonLayoutSummary = "Placement: A place+exit, X place again, B cancel, D-pad/RS X rotate"
	elseif ControllerCameraTestBuildMenu.open then
		activeButtonLayoutSummary = "Build menu: A placement, X quick-place, B/Y close, D-pad/LB/RB navigate"
	elseif ControllerCameraTestAreaSelect.active then
		activeButtonLayoutSummary = "Area select: release A to select, RS Y/D-pad changes radius"
	else
		activeButtonLayoutSummary = XboxController.normalLayoutSummary
	end
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
end

function ControllerCameraTestUpdateCameraControls(dt)
	local menuOpen = ControllerCameraTestBuildMenu.open
	panActive = (not menuOpen) and (normalizedLeftX ~= 0 or normalizedLeftY ~= 0)
	local placementActive = ControllerCameraTestBuildPlacement.active
	local areaActive = ControllerCameraTestAreaSelect.active
	rightStickYMode = areaActive and "area radius" or (lbCameraModifierActive and "pitch" or "zoom")
	local zoomInput = (lbCameraModifierActive or areaActive or menuOpen) and 0 or -normalizedRightY
	local pitchInput = (lbCameraModifierActive and not areaActive and not menuOpen) and -normalizedRightY or 0
	local rotationInput = (placementActive or menuOpen) and 0 or normalizedRightX
	zoomActive = zoomInput ~= 0
	rotationActive = rotationInput ~= 0
	pitchActive = pitchInput ~= 0

	local panMultiplier = fastPanActive and ControllerCameraTestSettings.fastPanMultiplier or 1
	zoomSpeedMultiplier = fastPanActive and ControllerCameraTestSettings.zoomBoostMultiplier or 1
	if panActive or zoomActive or rotationActive or pitchActive then
		applyCameraInput(menuOpen and 0 or normalizedLeftX, menuOpen and 0 or normalizedLeftY, zoomInput, rotationInput, pitchInput, panMultiplier, zoomSpeedMultiplier, dt)
	elseif spGetCameraState then
		zoomMethod = "none"
		rotationMethod = "none"
		pitchMethod = "none"
		updateCameraDebug(spGetCameraState())
	end
end

function ControllerCameraTestUpdateControllerFrame(dt)
	local state = ControllerCameraTestBeginControllerUpdate(dt)
	if not state then
		return
	end

	ControllerCameraTestUpdateControllerAxesAndButtons(state)
	ControllerCameraTestUpdateControllerModeAndCommandLayer(dt)
	if ControllerCameraTestBuildMenu.open then
		ControllerCameraTestUpdateRadialStickSelection()
	end
	ControllerCameraTestUpdateCameraControls(dt)
	updateReticleWorldTarget()
	if controllerMode and reticleVisible and type(spWarpMouse) == "function" then spWarpMouse(screenCenterX, screenCenterY) end
end

function widget:Update(dt)
	ControllerCameraTestUpdateControllerFrame(dt)
end

function widget:MouseMove(x, y)
	noteMouseInput()

	if debugPanelDragging then
		updateDebugPanelDrag(x, y)
		return true
	end
	if debugPanelResizing then
		updateDebugPanelResize(x, y)
		return true
	end
end

function widget:MousePress(x, y, button)
	noteMouseInput()

	if button ~= 1 then
		return
	end
	if not ControllerCameraTestSettings.debugPanelVisible then
		return
	end

	ensureDebugPanelInitialized()
	if isPointInDebugPanelResizeHandle(x, y) then
		debugPanelResizing = true
		debugPanelResizeStartMouseX = x
		debugPanelResizeStartMouseY = y
		debugPanelResizeStartY = debugPanelY
		debugPanelResizeStartWidth = debugPanelWidth
		debugPanelResizeStartHeight = debugPanelHeight
		return true
	end

	if isPointInDebugPanelHeader(x, y) then
		debugPanelDragging = true
		debugPanelDragOffsetX = x - debugPanelX
		debugPanelDragOffsetY = y - debugPanelY
		return true
	end
end

function widget:MouseRelease()
	noteMouseInput()

	if debugPanelDragging or debugPanelResizing then
		debugPanelDragging = false
		debugPanelResizing = false
		return true
	end
end

function ControllerCameraTestDrawBuildRadial()
	local menu = ControllerCameraTestBuildMenu
	if not menu.open then
		return
	end

	if ControllerCameraTestBuildPlacement.active then
		return
	end

	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)

	local radius = math.max(150, math.min(220, math.min(viewSizeX, viewSizeY) * 0.25))

	local visibleOptions = menu.radialVisibleOptions or {}
	local n = #visibleOptions

	-- 1. Translucent backdrop (large dark circle around the reticle)
	gl.Color(0, 0, 0, 0.72)
	local function drawCircle(x, y, r, segments)
		segments = segments or 32
		gl.BeginEnd(GL.TRIANGLE_FAN, function()
			gl.Vertex(x, y)
			for i = 0, segments do
				local theta = i * (2 * math.pi / segments)
				gl.Vertex(x + r * math.cos(theta), y + r * math.sin(theta))
			end
		end)
	end

	drawCircle(cx, cy, radius * 1.3, 40)

	-- Draw a thin ring
	gl.LineWidth(2)
	gl.Color(0.56, 0.84, 1, 0.45)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, 36 do
			local theta = i * (2 * math.pi / 36)
			gl.Vertex(cx + radius * math.cos(theta), cy + radius * math.sin(theta))
		end
	end)

	-- 2. Draw each item
	local iconSize = 48
	for i = 1, n do
		local option = visibleOptions[i]
		local angle = ((i - 1) * (2 * math.pi / n)) - (math.pi / 2)
		local x = cx + radius * math.cos(angle)
		local y = cy - radius * math.sin(angle)

		local isSelected = (option.menuIndex == menu.selectedIndex)

		if isSelected then
			gl.Color(0.2, 0.6, 1, 0.85)
			gl.Rect(x - iconSize/2 - 4, y - iconSize/2 - 4, x + iconSize/2 + 4, y + iconSize/2 + 4)
			gl.Color(0.85, 0.95, 1, 1)
		else
			gl.Color(0.12, 0.18, 0.23, 0.85)
			gl.Rect(x - iconSize/2 - 2, y - iconSize/2 - 2, x + iconSize/2 + 2, y + iconSize/2 + 2)
			gl.Color(0.8, 0.8, 0.8, 0.9)
		end

		gl.LineWidth(isSelected and 3 or 1.5)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(x - iconSize/2, y - iconSize/2)
			gl.Vertex(x + iconSize/2, y - iconSize/2)
			gl.Vertex(x + iconSize/2, y + iconSize/2)
			gl.Vertex(x - iconSize/2, y + iconSize/2)
		end)

		local hasIcon = false
		if option.iconTexture then
			gl.Texture(option.iconTexture)
			gl.Color(1, 1, 1, 1)
			gl.TexRect(x - iconSize/2, y - iconSize/2, x + iconSize/2, y + iconSize/2)
			gl.Texture(false)
			hasIcon = true
		end

		if not hasIcon then
			gl.Color(1, 1, 1, 1)
			gl.Text(string.sub(option.name, 1, 4), x, y - 4, 10, "oc")
		end

		gl.Color(1, 0.84, 0, 1)
		gl.Text(tostring(i), x - iconSize/2 + 4, y + iconSize/2 - 12, 10, "o")
	end

	-- 3. Center display details
	local currentOption = ControllerCameraTestGetRadialCurrentOption()
	if currentOption then
		gl.Color(0.2, 0.6, 1, 0.15)
		drawCircle(cx, cy, radius * 0.45, 30)

		gl.Color(0.82, 0.94, 1, 1)
		gl.Text(currentOption.name or "unknown", cx, cy + 12, 15, "oc")

		local costText = ""
		if currentOption.metalCost and currentOption.metalCost > 0 then
			costText = costText .. "M: " .. tostring(currentOption.metalCost)
		end
		if currentOption.energyCost and currentOption.energyCost > 0 then
			if costText ~= "" then costText = costText .. "  " end
			costText = costText .. "E: " .. tostring(currentOption.energyCost)
		end
		if costText ~= "" then
			gl.Color(1, 0.85, 0.3, 0.95)
			gl.Text(costText, cx, cy - 10, 12, "oc")
		end

		if currentOption.tooltip and currentOption.tooltip ~= "" then
			gl.Color(0.7, 0.7, 0.7, 0.8)
			local tip = string.sub(currentOption.tooltip, 1, 26)
			if #currentOption.tooltip > 26 then tip = tip .. "..." end
			gl.Text(tip, cx, cy - 28, 10, "oc")
		end
	end

	-- 4. Category/Page Indicator
	gl.Color(0.56, 0.84, 1, 0.95)
	local categoryStr = string.upper(menu.radialCategoryName or "Build")
	local pageStr = "PAGE " .. tostring(menu.radialPage) .. "/" .. tostring(menu.radialPageCount)

	gl.Text(categoryStr, cx, cy + radius * 0.7, 14, "oc")
	gl.Color(0.8, 0.8, 0.8, 0.8)
	gl.Text(pageStr, cx, cy - radius * 0.7, 12, "oc")

	gl.Color(0.6, 0.6, 0.6, 0.7)
	gl.Text("LB", cx - 80, cy + radius * 0.7, 11, "oc")
	gl.Text("RB", cx + 80, cy + radius * 0.7, 11, "oc")

	gl.Color(1, 1, 1, 1)
	gl.Texture(false)
	gl.LineWidth(1)
end

function ControllerCameraTestDrawHelpOverlay()
	local screenWidth = viewSizeX > 0 and viewSizeX or 1280
	local screenHeight = viewSizeY > 0 and viewSizeY or 720
	local width = math.min(760, math.max(300, screenWidth - 40))
	local height = math.min(430, math.max(300, screenHeight - 60))
	local left = math.max(20, (screenWidth - width) * 0.5)
	local top = math.min(screenHeight - 20, height + 20)
	local bottom = top - height
	local right = left + width
	local x = left + 18
	local y = top - 24
	local lineHeight = 17
	local maxChars = math.max(28, math.floor((width - 36) / 7.5))
	local lines = {
		"Controller Camera Test Help",
		"Normal: LS pan | LT boost | RS X rotate | RS Y zoom | LB+RSY pitch",
		"A tap select | A hold radius select | A double-tap same type / combat fallback",
		"B clear/cancel | X smart move/mex/context | Y build menu | RB/LB cycle",
		"D-pad recalls camera bookmarks | LT+D-pad stores camera bookmarks",
		"Build radial: LS/D-pad select | LB/RB page/category | A place | X quick-place | B/Y close",
		"RT: A visible combat/mobile | B stop | X attack | Y tactical menu",
		"RT+D-pad Up guard/patrol | Down reclaim | Left/Right quick group or cycle",
		"Tactical menu: D-pad/LB/RB choose | A/X confirm | B/Y cancel",
		"Back/View tap toggles debug panel",
		"Back/View + D-pad Left/Right selects setting | Up/Down adjusts",
		"Back/View + A/B/X/Y stores quick group 1-4 | Back/View + LB/RB recalls groups",
		"Start/Menu toggles this overlay",
		"Selected setting: " .. ControllerCameraTestCurrentSettingLabel(),
	}

	gl.Color(0, 0, 0, 0.86)
	gl.Rect(left, bottom, right, top)
	gl.Color(0.12, 0.18, 0.23, 0.96)
	gl.Rect(left, top - 34, right, top)
	gl.Color(0.72, 0.88, 1, 0.9)
	gl.Rect(left, top - 34, right, top - 33)
	gl.Color(1, 1, 1, 1)

	for i, line in ipairs(lines) do
		local size = (i == 1) and 18 or 14
		local colorIsHeader = i == 1 or i == 10
		if colorIsHeader then
			gl.Color(0.72, 0.9, 1, 1)
		else
			gl.Color(1, 1, 1, 0.96)
		end
		local remaining = line
		local first = true
		while #remaining > 0 and y > bottom + 12 do
			local drawText = remaining
			if #remaining > maxChars then
				local breakAt = maxChars
				for pos = maxChars, math.max(1, math.floor(maxChars * 0.5)), -1 do
					if string.sub(remaining, pos, pos) == " " then
						breakAt = pos
						break
					end
				end
				drawText = string.sub(remaining, 1, breakAt)
				remaining = string.gsub(string.sub(remaining, breakAt + 1), "^%s+", "")
			else
				remaining = ""
			end
			gl.Text((first and "" or "  ") .. drawText, x, y, size, "o")
			y = y - lineHeight
			first = false
		end
	end
	gl.Color(1, 1, 1, 1)
end

function widget:DrawScreen()
	local mathMax, mathPi = math.max, math.pi
	updateDebugLatchSummaries()
	drawControllerReticle()
	if ControllerCameraTestBuildMenu.open then
		ControllerCameraTestDrawBuildRadial()
	end
	if ControllerCameraTestSettings.helpOverlayVisible then
		ControllerCameraTestDrawHelpOverlay()
	end
	if not ControllerCameraTestSettings.debugPanelVisible then
		return
	end

	local function yesNo(value)
		return value and "yes" or "no"
	end
	local function activeInactive(value)
		return value and "active" or "inactive"
	end
	local function trimText(text)
		return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	end
	local function WrapDebugLine(text, maxChars)
		text = tostring(text or "")
		maxChars = mathMax(8, maxChars)
		if #text <= maxChars then
			return { text }
		end

		local lines = {}
		local remaining = text
		local firstLine = true

		while #remaining > 0 do
			local lineMaxChars = firstLine and maxChars or mathMax(8, maxChars - 2)
			if #remaining <= lineMaxChars then
				lines[#lines + 1] = (firstLine and "" or "  ") .. remaining
				break
			end

			local minBreak = mathMax(1, math.floor(lineMaxChars * 0.45))
			local breakAt = nil
			for i = lineMaxChars, minBreak, -1 do
				local char = string.sub(remaining, i, i)
				if char == " " or char == "," or char == "/" or char == ";" or char == "|" then
					breakAt = i
					break
				end
			end

			breakAt = breakAt or lineMaxChars
			local line = trimText(string.sub(remaining, 1, breakAt))
			if line == "" then
				line = string.sub(remaining, 1, lineMaxChars)
				breakAt = lineMaxChars
			end

			lines[#lines + 1] = (firstLine and "" or "  ") .. line
			remaining = trimText(string.sub(remaining, breakAt + 1))
			firstLine = false
		end

		return lines
	end
	local function drawLine(text, drawX, drawY)
		gl.Text(text, drawX, drawY, 15, "o")
	end
	local function drawSection(section, drawX, drawY, maxChars, contentBottom)
		if drawY < contentBottom then
			return drawY, false
		end

		gl.Color(0.62, 0.86, 1, 1)
		drawLine(section.title, drawX, drawY)
		gl.Color(1, 1, 1, 1)
		drawY = drawY - 17

		for _, line in ipairs(section.lines) do
			for _, wrappedLine in ipairs(WrapDebugLine(line, maxChars)) do
				if drawY < contentBottom then
					return drawY, false
				end
				drawLine(wrappedLine, drawX, drawY)
				drawY = drawY - 17
			end
		end

		return drawY - 6, true
	end

	ensureDebugPanelInitialized()

	local panelLeft = debugPanelX
	local panelBottom = debugPanelY
	local panelWidth = debugPanelWidth
	local panelHeight = debugPanelHeight
	local panelRight = panelLeft + panelWidth
	local panelTop = panelBottom + panelHeight
	local padding = 8 -- Freed DEBUG_PANEL_PADDING upvalue
	local headerHeight = 22 -- Freed DEBUG_PANEL_HEADER_HEIGHT upvalue
	local useColumns = panelWidth >= 720
	local columnGap = 12
	local columnWidth = useColumns
		and ((panelWidth - (padding * 2) - columnGap) * 0.5)
		or (panelWidth - (padding * 2))
	local maxChars = mathMax(12, math.floor(columnWidth / 7.8))
	local contentBottom = panelBottom + padding + 14 -- Freed DEBUG_PANEL_RESIZE_HANDLE upvalue
	local cameraState = spGetCameraState and spGetCameraState()
	if type(cameraState) ~= "table" then
		cameraState = {}
	end

	local reticleWorldSummary = "none"
	if reticleHasWorldTarget then
		reticleWorldSummary = string.format("x=%.1f y=%.1f z=%.1f", reticleWorldX, reticleWorldY, reticleWorldZ)
	end

	local currentLocalIndex = 1
	for idx, option in ipairs(ControllerCameraTestBuildMenu.radialVisibleOptions or {}) do
		if option.menuIndex == ControllerCameraTestBuildMenu.selectedIndex then
			currentLocalIndex = idx
			break
		end
	end

	local controllerSections = {
		{
			title = "Controller",
			lines = {
				"Widget: Controller Camera Test",
				"API: " .. yesNo(apiAvailable),
				"Name: " .. tostring(controllerName),
				"instanceId: " .. tostring(controllerInstanceId),
				"Input: " .. (controllerMode and "controller" or "mouse"),
				"Mode: " .. tostring(ControllerCameraTestLayerDebug.modeSummary),
				"Reticle visible: " .. yesNo(reticleVisible),
				"Debug panel: " .. yesNo(ControllerCameraTestSettings.debugPanelVisible),
				"Help overlay: " .. yesNo(ControllerCameraTestSettings.helpOverlayVisible),
			},
		},
		{
			title = "Reticle",
			lines = {
				string.format("Screen: x=%.1f y=%.1f", screenCenterX, screenCenterY),
				"World: " .. reticleWorldSummary,
				"Target type: " .. reticleTargetType,
				"Has world target: " .. yesNo(reticleHasWorldTarget),
			},
		},
		{
			title = "Axes",
			lines = {
				string.format("LS: x=%.3f y=%.3f", normalizedLeftX, normalizedLeftY),
				string.format("RS: x=%.3f y=%.3f", normalizedRightX, normalizedRightY),
				string.format("LT: %.3f", normalizedLeftTrigger),
				string.format("RT: %.3f", normalizedRightTrigger),
				"Active axes: " .. activeAxesSummary,
			},
		},
		{
			title = "Buttons",
			lines = {
				"Held: " .. heldButtonsSummary,
				"Pressed recent: " .. pressedRecentlySummary,
				"Released recent: " .. releasedRecentlySummary,
				"Cmd recent: " .. commandLayerPressedRecentlySummary,
				"Selection test: " .. yesNo(selectionTestActive),
				"Last selected unitID: " .. tostring(lastReticleSelectedUnitID),
				"Selection result: " .. lastSelectionResult,
				"Last B-button result: " .. tostring(lastBButtonResult),
				"Last clear-selection result: " .. tostring(lastClearSelectionResult),
				"Last command: " .. tostring(lastIssuedCommand),
				"Selection msg: " .. selectionDebugMessage,
				"Area active: " .. yesNo(ControllerCameraTestAreaSelect.active),
				"Area radius: " .. tostring(math.floor(ControllerCameraTestAreaSelect.radius)),
				"Area result: " .. tostring(ControllerCameraTestAreaSelect.lastResult) .. " count=" .. tostring(ControllerCameraTestAreaSelect.lastCount),
				"Cycle: " .. tostring(ControllerCameraTestCycleDebug.lastResult) .. " count=" .. tostring(ControllerCameraTestCycleDebug.lastCount),
				"Bookmark: " .. tostring(ControllerCameraTestBookmarkDebug.lastResult),
				"Quick group: " .. tostring(ControllerCameraTestQuickGroups.lastResult) .. " slot=" .. tostring(ControllerCameraTestQuickGroups.lastSlot),
				"Tuning: " .. ControllerCameraTestCurrentSettingLabel(),
				"Tuning action: " .. tostring(ControllerCameraTestTuning.lastAction),
			},
		},
	}
	local cameraSections = {
		{
			title = "Camera Controls",
			lines = {
				"RS Y mode: " .. rightStickYMode,
				"LT boost pan+zoom: " .. activeInactive(fastPanActive),
				"LB camera mod: " .. activeInactive(lbCameraModifierActive),
				"RT command layer: " .. activeInactive(commandLayerActive),
				"Pan active: " .. yesNo(panActive),
				"Zoom active: " .. yesNo(zoomActive),
				"Rotate active: " .. yesNo(rotationActive),
				"Pitch active: " .. yesNo(pitchActive),
				string.format("Zoom speed: %.1fx", zoomSpeedMultiplier),
				string.format("Pan speed setting: %.0f", ControllerCameraTestSettings.panSpeed),
				string.format("Rotate/Pitch: %.2f / %.2f", ControllerCameraTestSettings.rotationSpeed, ControllerCameraTestSettings.pitchSpeed),
				string.format("Deadzones stick/trigger: %.0f / %.0f", ControllerCameraTestSettings.stickDeadzone, ControllerCameraTestSettings.triggerDeadzone),
				"Zoom method: " .. zoomMethod,
				"Rotate method: " .. rotationMethod,
				"Pitch method: " .. pitchMethod,
			},
		},
		{
			title = "Command Layer",
			lines = {
				"Active: " .. activeInactive(commandLayerActive),
				"Layout: " .. activeButtonLayoutSummary,
				"Normal preview: " .. normalPreviewSummary,
				"Command preview: " .. commandPreviewSummary,
				"Command action: " .. tostring(ControllerCameraTestLayerDebug.commandLayerAction),
				"Normal utility: " .. tostring(ControllerCameraTestLayerDebug.normalUtilityAction),
				"Area select: " .. tostring(ControllerCameraTestLayerDebug.areaSelect),
				"Tactical open: " .. yesNo(ControllerCameraTestTacticalMenu.open),
				"Tactical command: " .. tostring(ControllerCameraTestTacticalMenu.highlightedName),
				"Tactical result: " .. tostring(ControllerCameraTestTacticalMenu.lastResult),
				"Default cmd index: " .. tostring(ControllerCameraTestCommandDebug.defaultCmdIndex),
				"Default cmd ID: " .. tostring(ControllerCameraTestCommandDebug.defaultCmdID),
				"Default cmd type: " .. tostring(ControllerCameraTestCommandDebug.defaultCmdType),
				"Default cmd name: " .. tostring(ControllerCameraTestCommandDebug.defaultCmdName),
				"Is build: " .. tostring(ControllerCameraTestCommandDebug.isBuild),
				"Issued cmd ID: " .. tostring(ControllerCameraTestCommandDebug.issuedCmdID),
				"Issued params count: " .. tostring(ControllerCameraTestCommandDebug.issuedParamsCount),
				"Last command result: " .. tostring(ControllerCameraTestCommandDebug.lastResult),
				"Mex smart available: " .. tostring(ControllerCameraTestCommandDebug.mexSmartAvailable),
				"Mex nearest spot: " .. tostring(ControllerCameraTestCommandDebug.mexNearestSpot),
				"Mex building cmd ID: " .. tostring(ControllerCameraTestCommandDebug.mexBuildingCmdID),
				"Mex action result: " .. tostring(ControllerCameraTestCommandDebug.mexActionResult),
				"Mex ApplyPreviewCmds: " .. tostring(ControllerCameraTestCommandDebug.mexApplyPreviewPath),
				"Mex fallback GiveOrder: " .. tostring(ControllerCameraTestCommandDebug.mexFallbackGiveOrderPath),
			},
		},
		{
			title = "Build Menu",
			lines = {
				"Open: " .. yesNo(ControllerCameraTestBuildMenu.open),
				"Option count: " .. tostring(ControllerCameraTestBuildMenu.optionCount),
				"Highlight index: " .. tostring(ControllerCameraTestBuildMenu.selectedIndex) .. " / " .. tostring(ControllerCameraTestBuildMenu.optionCount),
				"Highlight name: " .. tostring(ControllerCameraTestBuildMenu.highlightedName),
				"Highlight cmdID: " .. tostring(ControllerCameraTestBuildMenu.highlightedCmdID),
				"Options: " .. ControllerCameraTestGetBuildOptionSummary(),
				"Placement active: " .. yesNo(ControllerCameraTestBuildPlacement.active),
				"Placement facing: " .. tostring(ControllerCameraTestBuildPlacement.facing),
				"Queue active: " .. yesNo(ControllerCameraTestBuildPlacement.queueActive),
				"Placement result: " .. tostring(ControllerCameraTestBuildPlacement.lastResult),
				"Placement issued: " .. tostring(ControllerCameraTestBuildPlacement.lastIssuedCount),
				"Menu place result: " .. tostring(ControllerCameraTestBuildMenu.placementResult),
				"Placement params: " .. tostring(ControllerCameraTestBuildMenu.placementParamsCount),
				"Last action: " .. tostring(ControllerCameraTestBuildMenu.lastAction),
				"Radial open: " .. yesNo(ControllerCameraTestBuildMenu.open),
				"Radial category: " .. tostring(ControllerCameraTestBuildMenu.radialCategoryName),
				"Radial category count: " .. tostring(ControllerCameraTestBuildMenu.radialCategories and #ControllerCameraTestBuildMenu.radialCategories or 0),
				"Radial page: " .. tostring(ControllerCameraTestBuildMenu.radialPage) .. " / " .. tostring(ControllerCameraTestBuildMenu.radialPageCount),
				"Radial visible count: " .. tostring(ControllerCameraTestBuildMenu.radialVisibleOptions and #ControllerCameraTestBuildMenu.radialVisibleOptions or 0),
				"Radial selected local index: " .. tostring(currentLocalIndex or 1),
				"Radial highlighted name: " .. tostring(ControllerCameraTestBuildMenu.highlightedName),
				"Radial last action: " .. tostring(ControllerCameraTestBuildMenu.radialLastAction or "none"),
				"Native placement active: " .. yesNo(ControllerCameraTestBuildPlacement.nativePreviewActive),
				"Native set cmd result: " .. tostring(ControllerCameraTestBuildPlacement.nativeSetActiveCommandResult or "none"),
				"Native cmdDescIndex: " .. tostring(ControllerCameraTestBuildPlacement.cmdDescIndex or "none"),
				"Placement mode: " .. tostring(ControllerCameraTestBuildPlacement.placementMode or "none"),
			},
		},
		{
			title = "Camera State",
			lines = {
				"Camera: " .. tostring(cameraState.name or cameraMode) .. " mode=" .. tostring(cameraState.mode or cameraModeId),
				"px/py/pz: " .. formatNumber(cameraState.px) .. " / " .. formatNumber(cameraState.py) .. " / " .. formatNumber(cameraState.pz),
				"dist: " .. formatNumber(cameraState.dist),
				"height/old: " .. formatNumber(cameraState.height) .. " / " .. formatNumber(cameraState.oldHeight),
				"rx/ry/rz: " .. formatNumber(cameraState.rx) .. " / " .. formatNumber(cameraState.ry) .. " / " .. formatNumber(cameraState.rz),
				"dx/dy/dz: " .. formatNumber(cameraState.dx) .. " / " .. formatNumber(cameraState.dy) .. " / " .. formatNumber(cameraState.dz),
				"fov: " .. formatNumber(cameraState.fov),
				"Pitch field: " .. cameraPitchSummary,
			},
		},
	}

gl.Color(0, 0, 0, 0.82)
	gl.Rect(panelLeft, panelBottom, panelRight, panelTop)
	gl.Color(0.06, 0.11, 0.15, 0.96)
	gl.Rect(panelLeft, panelTop - headerHeight, panelRight, panelTop)
	gl.Color(0.56, 0.84, 1, 0.62)
	gl.Rect(panelLeft, panelTop - headerHeight, panelRight, panelTop - headerHeight + 1)
	gl.Color(0.76, 0.88, 0.96, 0.95)
	gl.Rect(panelLeft, panelTop - 1, panelRight, panelTop)
	gl.Rect(panelLeft, panelBottom, panelRight, panelBottom + 1)
	gl.Rect(panelLeft, panelBottom, panelLeft + 1, panelTop)
	gl.Rect(panelRight - 1, panelBottom, panelRight, panelTop)
	gl.Color(1, 1, 1, 1)

	local textX = panelLeft + padding
	local textY = panelTop - 15
	gl.Text("Controller Debug", textX, textY, 15, "o")
	textY = panelTop - headerHeight - padding - 10

	if useColumns then
		local rightX = textX + columnWidth + columnGap
		local leftY = textY
		local rightY = textY

		for _, section in ipairs(controllerSections) do
			leftY = drawSection(section, textX, leftY, maxChars, contentBottom)
		end
		for _, section in ipairs(cameraSections) do
			rightY = drawSection(section, rightX, rightY, maxChars, contentBottom)
		end
	else
		for _, section in ipairs(controllerSections) do
			textY = drawSection(section, textX, textY, maxChars, contentBottom)
		end
		for _, section in ipairs(cameraSections) do
			textY = drawSection(section, textX, textY, maxChars, contentBottom)
		end
	end

	local handleRight = panelRight - 4
	local handleBottom = panelBottom + 4
	gl.Color(0.72, 0.86, 0.94, 0.75)
	gl.Rect(handleRight - 4, handleBottom, handleRight, handleBottom + 1)
	gl.Rect(handleRight - 8, handleBottom + 4, handleRight, handleBottom + 5)
	gl.Rect(handleRight - 12, handleBottom + 8, handleRight, handleBottom + 9)
	gl.Color(1, 1, 1, 1)
end

function widget:GetConfigData()
	ensureDebugPanelInitialized()
	local settings = {}
	for key, value in pairs(ControllerCameraTestSettings) do
		if type(value) ~= "table" then
			settings[key] = value
		end
	end
	return {
		panelX = debugPanelX,
		panelY = debugPanelY,
		panelWidth = debugPanelWidth,
		panelHeight = debugPanelHeight,
		settings = settings,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end

	if type(data.settings) == "table" then
		for key, value in pairs(data.settings) do
			if ControllerCameraTestSettings[key] ~= nil then
				ControllerCameraTestSettings[key] = value
			end
		end
	end
	ControllerCameraTestApplySettingsDefaults()

	local panelX = tonumber(data.panelX)
	local panelY = tonumber(data.panelY)
	local panelWidth = tonumber(data.panelWidth)
	local panelHeight = tonumber(data.panelHeight)
	if not panelX or not panelY or not panelWidth or not panelHeight then
		ensureDebugPanelInitialized()
	else
		debugPanelX = panelX
		debugPanelY = panelY
		debugPanelWidth = panelWidth
		debugPanelHeight = panelHeight
		debugPanelInitialized = true
		if viewSizeX > 0 and viewSizeY > 0 then
			clampDebugPanelToScreen()
		end
	end
end

function widget:DrawWorld()
	if not controllerMode then
		return
	end

	if type(spGetSelectedUnits) == "function" and type(spGetUnitPosition) == "function" then
		local selectedUnits = spGetSelectedUnits()
		if selectedUnits and #selectedUnits > 0 then
			gl.LineWidth(2.5)
			gl.Color(0.2, 1.0, 0.2, 0.8) -- Bright green

			for i = 1, #selectedUnits do
				local unitID = selectedUnits[i]
				local x, y, z = spGetUnitPosition(unitID)
				if x and y and z then
					gl.DrawGroundCircle(x, y, z, 35, 32)
				end
			end
		end
	end

	if ControllerCameraTestAreaSelect.active and reticleHasWorldTarget then
		gl.LineWidth(2)
		gl.Color(0.25, 0.75, 1.0, 0.55)
		gl.DrawGroundCircle(reticleWorldX, reticleWorldY, reticleWorldZ, ControllerCameraTestAreaSelect.radius, 48)
	end

	if ControllerCameraTestBuildPlacement.active and reticleHasWorldTarget then
		gl.LineWidth(2.5)
		gl.Color(1.0, 0.88, 0.25, 0.7)
		gl.DrawGroundCircle(reticleWorldX, reticleWorldY, reticleWorldZ, 52, 32)
	end

	if ControllerCameraTestVisualFeedback.expireTime > debugEventTime and ControllerCameraTestVisualFeedback.targetX then
		local marker = ControllerCameraTestVisualFeedback
		local alpha = clamp(marker.expireTime - debugEventTime, 0, 1)
		if string.find(marker.kind, "attack") then
			gl.Color(1.0, 0.18, 0.12, 0.75 * alpha)
		elseif string.find(marker.kind, "build") then
			gl.Color(1.0, 0.88, 0.18, 0.75 * alpha)
		elseif string.find(marker.kind, "reclaim") or string.find(marker.kind, "repair") then
			gl.Color(0.35, 1.0, 0.45, 0.72 * alpha)
		elseif string.find(marker.kind, "guard") or string.find(marker.kind, "patrol") then
			gl.Color(0.25, 0.65, 1.0, 0.72 * alpha)
		else
			gl.Color(1.0, 1.0, 1.0, 0.62 * alpha)
		end
		gl.LineWidth(2)
		gl.DrawGroundCircle(
			marker.targetX,
			marker.targetY or 0,
			marker.targetZ,
			44 + ((1 - alpha) * 32),
			28
		)
	end

	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end
