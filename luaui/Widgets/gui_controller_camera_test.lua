--------------------------------------------------------------------------------
-- SECTION: Widget info and Spring/gl references
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Controller Camera Test",
		desc = "Prototype Xbox controller left-stick camera panning",
		author = "Kailil / Codex",
		date = "2026-05-22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
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
--------------------------------------------------------------------------------
-- SECTION: State tables and settings defaults
--------------------------------------------------------------------------------
ControllerCameraTestCommandDebug = ControllerCameraTestCommandDebug or {
	defaultCmdIndex = "none",
	defaultCmdID = "none",
	defaultCmdType = "none",
	defaultCmdName = "none",
	isBuild = "no",
	issuedCmdID = "none",
	issuedParamsCount = 0,
	lastOptions = "none",
	lastResult = "none",
	mexSmartAvailable = "no",
	mexNearestSpot = "no",
	mexBuildingCmdID = "none",
	mexActionResult = "none",
	mexApplyPreviewPath = "no",
	mexFallbackGiveOrderPath = "no",
	queueRemovalMode = "none",
	queueRemovalSelectedCount = 0,
	queueRemovalAttemptedCount = 0,
	queueRemovalRemovedCount = 0,
	queueRemovalLastQueueSize = "none",
	queueRemovalLastTag = "none",
	queueRemovalUnitDetails = "none",
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
	factoryQueueCounts = {},
	factoryQueueProgress = {},
	factoryProgressKnown = "no",
	factoryProgressCmdID = "none",
	factoryProgressValue = "none",
	factoryProgressSource = "none",
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
	placementPattern = "single",
	placementSpacing = 0,
	queueFrontActive = false,
	gridShortcutResult = "none",
	lastConstructionShortcut = "none",
	useCustomGridFallback = true,
	patternPressActive = false,
	patternPressStartTime = 0,
	patternHoldTriggered = false,
	patternHoldSeconds = 0.25,
}
ControllerCameraTestDragCommand = ControllerCameraTestDragCommand or {
	active = false,
	mode = "none",
	cmdID = nil,
	startX = nil,
	startY = nil,
	startZ = nil,
	endX = nil,
	endY = nil,
	endZ = nil,
	radius = 0,
	shape = "none",
	lastResult = "none",
	lastMode = "none",
	previewPoints = {},
	pressStartTime = 0,
	pressActive = false,
	pressButton = nil,
	nativeRouteUsed = false,
	nativeRouteName = "unavailable",
	nativePreviewResult = "none",
	customGridFallback = "yes",
	singleUnitPathActive = false,
	singleUnitPathUnitID = nil,
	singleUnitPathPoints = {},
	singleUnitLastPointX = nil,
	singleUnitLastPointY = nil,
	singleUnitLastPointZ = nil,
	singleUnitLastIssueTime = 0,
	singleUnitPathResult = "none",
	singleUnitWaypointCount = 0,
}

ControllerCameraTestAreaSelect = ControllerCameraTestAreaSelect or {
	pressActive = false,
	active = false,
	pressStartTime = 0,
	lastTapTime = -10,
	radius = 320,
	lastCount = 0,
	lastResult = "none",
	doubleTapAction = "none",
	filterMode = "units-only",
	sameTypeTarget = "none",
	sameTypeUnitDefID = "none",
	sameTypeSource = "none",
	sameTypeCandidateCount = 0,
	sameTypeSelectedCount = 0,
}
ControllerCameraTestTacticalMenu = ControllerCameraTestTacticalMenu or {
	open = false,
	selectedIndex = 1,
	highlightedName = "none",
	lastAction = "none",
	lastResult = "none",
	stagedOption = nil,
	stagedName = "none",
	stagedKind = "none",
	stagedState = "none",
	repeatPlacementActive = false,
	repeatPlacementState = "none",
	radialLastAngle = 0,
}
ControllerCameraTestMemoryDebug = ControllerCameraTestMemoryDebug or {
	lastSampleTime = -10,
	lastInputSummaryTime = -10,
	lastRawSummaryTime = -10,
	lastControllerScanTime = -10,
	luaKB = 0,
	initLuaKB = nil,
	deltaKB = 0,
	maxLuaKB = 0,
	luaMB = "0.0",
	lastResult = "not sampled",
	audit = "binding definitions cached; hot debug summaries throttled",
	controllerConnected = "no",
	mode = "unknown",
	buttonEventCount = 0,
	tacticalOpenCount = 0,
	hitboxCount = 0,
	debugRowCount = 0,
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
ControllerCameraTestIdleCycle = ControllerCameraTestIdleCycle or {
	currentUnitID = nil,
	currentIndex = 1,
	currentTypeKey = nil,
	currentTypeIndex = 1,
	lastResult = "none",
	lastTypeName = "none",
	lastCount = 0,
	selectedAllCount = 0,
}
ControllerCameraTestControlGroups = ControllerCameraTestControlGroups or {
	slots = {},
	activeSlot = 1,
	visibleUntil = 0,
	lastAction = "none",
	lastSlot = "none",
	lastCount = 0,
	leftPressActive = false,
	leftPressStartTime = 0,
	leftHoldTriggered = false,
	leftInputState = "idle",
	nativeAutogroupStatus = "none",
}
ControllerCameraTestVisualFeedback = ControllerCameraTestVisualFeedback or {
	targetX = nil,
	targetY = nil,
	targetZ = nil,
	label = "none",
	kind = "generic",
	expireTime = 0,
}
ControllerCameraTestPlacementPopup = ControllerCameraTestPlacementPopup or {
	text = "none",
	expireTime = 0,
	lastResult = "none",
}
ControllerCameraTestInputSmoothing = ControllerCameraTestInputSmoothing or {
	panX = 0,
	panY = 0,
	rotateX = 0,
	pitchY = 0,
	zoomY = 0,
	leftTrigger = 0,
}
ControllerCameraTestSelectedStatus = ControllerCameraTestSelectedStatus or {
	mode = "hidden",
	lastResult = "none",
	vanillaCommandPanelStatus = "untouched",
}
ControllerCameraTestLayerDebug = ControllerCameraTestLayerDebug or {
	commandLayerAction = "none",
	normalUtilityAction = "none",
	areaSelect = "inactive",
	modeSummary = "normal",
}
ControllerCameraTestDebugSections = ControllerCameraTestDebugSections or {
	Input = true,
	Camera = false,
	Reticle = false,
	Selection = false,
	Commands = false,
	AreaSelect = false,
	TacticalMenu = false,
	BuildMenu = true,
	Bookmarks = false,
	IdleCycle = true,
	ControlGroups = true,
	QuickGroups = false,
	Tuning = false,
}
ControllerCameraTestDebugCompact = ControllerCameraTestDebugCompact or false
ControllerCameraTestDebugSectionHitboxes = {}

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spWarpMouse = Spring.WarpMouse

local glText = gl.Text
local glRect = gl.Rect

local PAN_SPEED = 1400
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

function ControllerCameraTestGetDefaultSettings()
	return {
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
		xHoldSeconds = 0.14,
		aHoldSeconds = 0.38,
		controlGroupAssignHoldSeconds = 0.35,
		radialScale = 1,
		cameraSmoothing = 0.06,
		stickCurve = 1.175,
		triggerCurve = 1.075,
		singlePathSpacing = 96,
		singlePathInterval = 0.10,
		compactSelectedStatus = true,
		hideCompactStatusWhenRadialOpen = true,
		placementPopupEnabled = true,
		preferNativeBlueprint = true,
		debugPanelVisible = true,
		helpOverlayVisible = false,
	}
end

ControllerCameraTestSettings = ControllerCameraTestSettings or ControllerCameraTestGetDefaultSettings()
ControllerCameraTestTuning = ControllerCameraTestTuning or {
	selectedIndex = 1,
	backHeld = false,
	backComboUsed = false,
	backQueueModifier = false,
	backCommandLayerATapTime = -10,
	lastAction = "none",
}
ControllerCameraTestSettingsUI = ControllerCameraTestSettingsUI or {
	open = false,
	categoryIndex = 1,
	selectedIndex = 1,
	lastAction = "none",
	lastCategory = "Camera",
}
ControllerCameraTestExternalBindingUI = ControllerCameraTestExternalBindingUI or {
	open = false,
	lastAction = "none",
}
ControllerCameraTestKeyDebug = ControllerCameraTestKeyDebug or {
	rawKey = "none",
	label = "none",
	matchedAction = "none",
	lastUIToggle = "none",
}
ControllerCameraTestBindings = ControllerCameraTestBindings or {
	actions = {},
	captureAction = nil,
	conflictAction = nil,
	lastAction = "defaults active",
	triggerDown = { LT = false, RT = false },
	triggerPressed = { LT = false, RT = false },
	triggerReleased = { LT = false, RT = false },
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
		panSpeed = { 100, 10000 },
		fastPanMultiplier = { 1.0, 10.0 },
		zoomSpeed = { 100, 20000 },
		zoomBoostMultiplier = { 1.0, 12.0 },
		rotationSpeed = { 0.1, 20.0 },
		pitchSpeed = { 0.1, 20.0 },
		stickDeadzone = { 0, 20000 },
		triggerDeadzone = { 0, 20000 },
		areaSelectRadius = { 40, 2000 },
		reticleSize = { 4, 100 },
		xHoldSeconds = { 0.05, 2.0 },
		aHoldSeconds = { 0.05, 2.0 },
		controlGroupAssignHoldSeconds = { 0.05, 2.5 },
		radialScale = { 0.5, 3.0 },
		cameraSmoothing = { 0.0, 1.0 },
		stickCurve = { 0.25, 5.0 },
		triggerCurve = { 0.25, 5.0 },
		singlePathSpacing = { 16, 1024 },
		singlePathInterval = { 0.02, 1.0 },
	}
	local range = ranges[name]
	if not range then
		return value
	end
	return math.max(range[1], math.min(range[2], value))
end

function ControllerCameraTestApplySettingsDefaults()
	local settings = ControllerCameraTestSettings
	local defaults = ControllerCameraTestGetDefaultSettings()
	for key, value in pairs(defaults) do
		if settings[key] == nil then
			settings[key] = value
		end
	end
	settings.panSpeed = ControllerCameraTestClampSetting("panSpeed", settings.panSpeed or defaults.panSpeed)
	settings.fastPanMultiplier = ControllerCameraTestClampSetting("fastPanMultiplier", settings.fastPanMultiplier or FAST_PAN_MULTIPLIER)
	settings.zoomSpeed = ControllerCameraTestClampSetting("zoomSpeed", settings.zoomSpeed or ZOOM_SPEED)
	settings.zoomBoostMultiplier = ControllerCameraTestClampSetting("zoomBoostMultiplier", settings.zoomBoostMultiplier or FAST_ZOOM_MULTIPLIER)
	settings.rotationSpeed = ControllerCameraTestClampSetting("rotationSpeed", settings.rotationSpeed or ROTATION_SPEED)
	settings.pitchSpeed = ControllerCameraTestClampSetting("pitchSpeed", settings.pitchSpeed or PITCH_SPEED)
	settings.stickDeadzone = ControllerCameraTestClampSetting("stickDeadzone", settings.stickDeadzone or 3000)
	settings.triggerDeadzone = ControllerCameraTestClampSetting("triggerDeadzone", settings.triggerDeadzone or 3000)
	settings.areaSelectRadius = ControllerCameraTestClampSetting("areaSelectRadius", settings.areaSelectRadius or 320)
	settings.reticleSize = ControllerCameraTestClampSetting("reticleSize", settings.reticleSize or 16)
	settings.xHoldSeconds = ControllerCameraTestClampSetting("xHoldSeconds", settings.xHoldSeconds or 0.14)
	settings.aHoldSeconds = ControllerCameraTestClampSetting("aHoldSeconds", settings.aHoldSeconds or 0.38)
	settings.controlGroupAssignHoldSeconds = ControllerCameraTestClampSetting("controlGroupAssignHoldSeconds", settings.controlGroupAssignHoldSeconds or 0.35)
	settings.radialScale = ControllerCameraTestClampSetting("radialScale", settings.radialScale or 1)
	settings.cameraSmoothing = ControllerCameraTestClampSetting("cameraSmoothing", settings.cameraSmoothing or defaults.cameraSmoothing)
	settings.stickCurve = ControllerCameraTestClampSetting("stickCurve", settings.stickCurve or defaults.stickCurve)
	settings.triggerCurve = ControllerCameraTestClampSetting("triggerCurve", settings.triggerCurve or defaults.triggerCurve)
	settings.singlePathSpacing = ControllerCameraTestClampSetting("singlePathSpacing", settings.singlePathSpacing or 96)
	settings.singlePathInterval = ControllerCameraTestClampSetting("singlePathInterval", settings.singlePathInterval or 0.10)
	settings.compactSelectedStatus = settings.compactSelectedStatus ~= false
	settings.hideCompactStatusWhenRadialOpen = settings.hideCompactStatusWhenRadialOpen ~= false
	settings.placementPopupEnabled = settings.placementPopupEnabled ~= false
	settings.preferNativeBlueprint = settings.preferNativeBlueprint ~= false
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
		{ key = "xHoldSeconds", label = "X hold seconds", step = 0.02, decimals = 2 },
		{ key = "aHoldSeconds", label = "A hold seconds", step = 0.02, decimals = 2 },
		{ key = "controlGroupAssignHoldSeconds", label = "Group hold seconds", step = 0.02, decimals = 2 },
		{ key = "radialScale", label = "Radial scale", step = 0.05, decimals = 2 },
		{ key = "cameraSmoothing", label = "Camera smoothing", step = 0.01, decimals = 2 },
		{ key = "stickCurve", label = "Stick curve", step = 0.05, decimals = 2 },
		{ key = "triggerCurve", label = "Trigger curve", step = 0.05, decimals = 2 },
		{ key = "singlePathSpacing", label = "Path spacing", step = 8, decimals = 0 },
		{ key = "singlePathInterval", label = "Path interval", step = 0.01, decimals = 2 },
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

function ControllerCameraTestResetSettingsToDefaults()
	local settings = ControllerCameraTestSettings
	for key, value in pairs(ControllerCameraTestGetDefaultSettings()) do
		settings[key] = value
	end
	ControllerCameraTestApplySettingsDefaults()
	ControllerCameraTestTuning.lastAction = "controller settings reset to code defaults"
	ControllerCameraTestSettingsUI.lastAction = "all settings reset to code defaults"
	latchSelectionDebugMessage("Controller settings reset to code defaults")
end

ControllerCameraTestApplySettingsDefaults()


--------------------------------------------------------------------------------
-- SECTION: Input polling and button helpers
--------------------------------------------------------------------------------
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
	previewButtonOrder = { 0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14 },
	normalPreviewLabels = {
		[0] = "A = Select / hold area / double-tap same visible type",
		[1] = "B = Clear Selection",
		[2] = "X = Smart Action (Move/Build/Attack)",
		[3] = "Y = Controller Build Menu",
		[4] = "Back/View = Command layer / Commander utility",
		[6] = "Start/Menu = Hold group layer",
		[7] = "Left Stick Click = Remove current/next queued command",
		[8] = "Right Stick Click = Remove last queued command",
		[9] = "LB = Camera pitch; LB+D-pad L/R idle type",
		[10] = "RB = Preset action / radial page",
		[11] = "D-pad Up = Camera bookmark Up",
		[12] = "D-pad Down = Camera bookmark Down",
		[13] = "D-pad Left = Previous idle unit",
		[14] = "D-pad Right = Next idle unit",
	},
	commandPreviewLabels = {
		[0] = "Layer + A = Reserved / Back double-tap commander",
		[1] = "Layer + B = Stop selected units",
		[2] = "Layer + X = Attack / Attack-move",
		[3] = "Layer + Y = Tactical command menu if bound",
		[9] = "Layer + LB = Previous selected unit/type",
		[10] = "Layer + RB = Tactical command menu",
		[11] = "Layer + D-pad Up = Guard allied / Patrol ground",
		[12] = "Layer + D-pad Down = Reclaim target/area",
		[13] = "Layer + D-pad Left = Previous selection cycle",
		[14] = "Layer + D-pad Right = Next selection cycle",
	},
	normalLayoutSummary = "A Select/Hold Area/Double Same-Type, B Clear, X Context, Y Build, L3/R3 Queue Remove, D-pad L/R Idle, Start Groups",
	commandLayoutSummary = "Layer+A Commander, Layer+B Stop, Layer+X Attack, Layer+RB Tactical, Layer+D-pad Commands",
}

apiAvailable = false
controllerName = "none"
controllerInstanceId = nil
rawControllerStateStatus = "none"
rawAxesSummary = "none"
rawButtonsSummary = "none"
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
cameraMode = "unknown"
cameraModeId = "?"
cameraFieldSummary = "camera state unavailable"
cameraPitchSummary = "pitch field unavailable"
zoomMethod = "none"
rotationMethod = "none"
pitchMethod = "none"
selectionTestActive = false
lastReticleSelectedUnitID = "none"
lastSelectionResult = "none"
lastBButtonResult = "none"
lastClearSelectionResult = "none"
selectionDebugMessage = "none"
selectionDebugExpiration = 0
controllerMode = false
reticleVisible = false
screenCenterX = 0
screenCenterY = 0
reticleTargetType = "unavailable"
reticleHasWorldTarget = false
reticleWorldX = nil
reticleWorldY = nil
reticleWorldZ = nil
reticleTargetAlignment = "none"
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
	local height = ControllerCameraTestDebugCompact and 120 or debugPanelHeight
	return x >= debugPanelX
		and x <= debugPanelX + debugPanelWidth
		and y >= debugPanelY
		and y <= debugPanelY + height
end

local function isPointInDebugPanelHeader(x, y)
	local height = ControllerCameraTestDebugCompact and 120 or debugPanelHeight
	return isPointInDebugPanel(x, y)
		and y >= debugPanelY + height - DEBUG_PANEL_HEADER_HEIGHT
end

local function isPointInDebugPanelResizeHandle(x, y)
	if ControllerCameraTestDebugCompact then
		return false
	end
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

	local value = state.axes[axisId + 1]
	if value == nil then
		value = state.axes[axisId]
	end

	return tonumber(value) or 0
end

local function GetButton(state, buttonId)
	if type(state) ~= "table" or type(state.buttons) ~= "table" then
		return false
	end

	local value = state.buttons[buttonId + 1]
	if value == nil then
		value = state.buttons[buttonId]
	end
	if type(value) == "boolean" then
		return value
	end

	return (tonumber(value) or 0) ~= 0
end

function ControllerCameraTestSummarizeRawControllerState(state)
	if type(state) ~= "table" then
		rawControllerStateStatus = "state unavailable"
		rawAxesSummary = "none"
		rawButtonsSummary = "none"
		return
	end

	rawControllerStateStatus = "state table ok"
	local memory = ControllerCameraTestMemoryDebug
	if not ControllerCameraTestSettings.debugPanelVisible
		or (debugEventTime - (memory.lastRawSummaryTime or -10)) < 1
	then
		return
	end
	memory.lastRawSummaryTime = debugEventTime

	local axes = type(state.axes) == "table" and state.axes or {}
	local buttons = type(state.buttons) == "table" and state.buttons or {}
	local oneBasedAxes = {}
	local zeroBasedAxes = {}
	local oneBasedDown = {}
	local zeroBasedDown = {}

	for axisID = 1, 6 do
		oneBasedAxes[#oneBasedAxes + 1] = tostring(axisID) .. "=" .. tostring(axes[axisID])
	end
	for axisID = 0, 5 do
		zeroBasedAxes[#zeroBasedAxes + 1] = tostring(axisID) .. "=" .. tostring(axes[axisID])
	end

	for buttonID = 1, 15 do
		local value = buttons[buttonID]
		if value == true or (tonumber(value) or 0) ~= 0 then
			oneBasedDown[#oneBasedDown + 1] = tostring(buttonID)
		end
	end
	for buttonID = 0, 14 do
		local value = buttons[buttonID]
		if value == true or (tonumber(value) or 0) ~= 0 then
			zeroBasedDown[#zeroBasedDown + 1] = tostring(buttonID)
		end
	end

	rawAxesSummary = "1-based: " .. table.concat(oneBasedAxes, " ")
		.. " | 0-based: " .. table.concat(zeroBasedAxes, " ")
	rawButtonsSummary = "1-based down: " .. (#oneBasedDown > 0 and table.concat(oneBasedDown, ",") or "none")
		.. " | 0-based down: " .. (#zeroBasedDown > 0 and table.concat(zeroBasedDown, ",") or "none")
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

local getActiveAxisSummary

function ControllerCameraTestUpdateMemoryDebug()
	local memory = ControllerCameraTestMemoryDebug
	if (debugEventTime - (memory.lastSampleTime or -10)) < 2 then
		return
	end
	memory.lastSampleTime = debugEventTime
	if type(collectgarbage) ~= "function" then
		memory.lastResult = "collectgarbage unavailable"
		return
	end
	local ok, kb = pcall(collectgarbage, "count")
	if not ok or type(kb) ~= "number" then
		memory.lastResult = "sample failed"
		return
	end
	memory.luaKB = math.floor(kb + 0.5)
	if type(memory.initLuaKB) ~= "number" then
		memory.initLuaKB = memory.luaKB
	end
	memory.deltaKB = memory.luaKB - (memory.initLuaKB or memory.luaKB)
	if memory.luaKB > (memory.maxLuaKB or 0) then
		memory.maxLuaKB = memory.luaKB
	end
	memory.luaMB = string.format("%.1f", kb / 1024)
	memory.mode = ControllerCameraTestGetModeSummary and ControllerCameraTestGetModeSummary() or tostring(ControllerCameraTestLayerDebug.modeSummary)
	memory.hitboxCount = type(ControllerCameraTestDebugSectionHitboxes) == "table" and #ControllerCameraTestDebugSectionHitboxes or 0
	memory.lastResult = "sampled"
end

local function countButtonStates(buttonStates)
	local count = 0
	for _, buttonId in ipairs(XboxController.buttonOrder) do
		if buttonStates[buttonId] then
			count = count + 1
		end
	end
	return count
end

function ControllerCameraTestUpdateHotInputDebugSummaries(state)
	local memory = ControllerCameraTestMemoryDebug
	local eventCount = countButtonStates(pressedButtonStates) + countButtonStates(releasedButtonStates)
	if eventCount > 0 then
		memory.buttonEventCount = (memory.buttonEventCount or 0) + eventCount
	end
	if eventCount == 0 and (debugEventTime - (memory.lastInputSummaryTime or -10)) < 0.5 then
		return
	end
	memory.lastInputSummaryTime = debugEventTime
	heldButtonsSummary = getButtonStateSummary(currentButtonStates)
	pressedThisFrameSummary = getButtonStateSummary(pressedButtonStates)
	releasedThisFrameSummary = getButtonStateSummary(releasedButtonStates)
	activeAxesSummary = getActiveAxisSummary(state)
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

getActiveAxisSummary = function(state)
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
	local memory = ControllerCameraTestMemoryDebug
	if (debugEventTime - (memory.lastControllerScanTime or -10)) < 1 then
		if controllerInstanceId ~= nil then
			memory.controllerConnected = "yes"
			return true
		end
		return nil
	end
	memory.lastControllerScanTime = debugEventTime

	local ok, controllers = pcall(spGetAvailableControllers)
	if not ok then
		controllerName = "GetAvailableControllers failed"
		controllerInstanceId = nil
		rawControllerStateStatus = "GetAvailableControllers failed"
		rawAxesSummary = "none"
		rawButtonsSummary = "none"
		memory.controllerConnected = "scan failed"
		return nil
	end

	local controller = getFirstController(controllers)
	if not controller then
		controllerName = "none"
		controllerInstanceId = nil
		rawControllerStateStatus = "no controller"
		rawAxesSummary = "none"
		rawButtonsSummary = "none"
		memory.controllerConnected = "no"
		return nil
	end

	controllerName = tostring(controller.name or "unknown")
	controllerInstanceId = controller.instanceID or controller.instanceId
	memory.controllerConnected = "yes"
	return controller
end

local function pollControllerState(instanceId)
	if instanceId == nil then
		rawControllerStateStatus = "no instanceID"
		rawAxesSummary = "none"
		rawButtonsSummary = "none"
		return nil
	end

	local ok, state = pcall(spGetControllerState, instanceId)
	if not ok then
		rawControllerStateStatus = "GetControllerState failed"
		rawAxesSummary = "none"
		rawButtonsSummary = "none"
		controllerInstanceId = nil
		ControllerCameraTestMemoryDebug.controllerConnected = "state failed"
		ControllerCameraTestMemoryDebug.lastControllerScanTime = -10
		return nil
	end
	if type(state) ~= "table" then
		rawControllerStateStatus = "state unavailable"
		rawAxesSummary = "none"
		rawButtonsSummary = "none"
		controllerInstanceId = nil
		ControllerCameraTestMemoryDebug.controllerConnected = "state unavailable"
		ControllerCameraTestMemoryDebug.lastControllerScanTime = -10
		return nil
	end

	ControllerCameraTestSummarizeRawControllerState(state)
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

--------------------------------------------------------------------------------
-- SECTION: Reticle/world target helpers
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- SECTION: Selection and area select
--------------------------------------------------------------------------------
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
		latchSelectionDebugMessage("A select skipped: command layer active")
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
		latchSelectionDebugMessage("B ignored: command layer active")
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

--------------------------------------------------------------------------------
-- SECTION: Binding system
--------------------------------------------------------------------------------
function ControllerCameraTestBindingDefinitions()
	local bindings = ControllerCameraTestBindings
	local version = "v0.4.1-memory-cache-1"
	if type(bindings.definitionCache) == "table" and bindings.definitionCacheVersion == version then
		return bindings.definitionCache
	end
	local defs = {
		{ action = "select", label = "Select / Area Select", default = "A", group = "Core" },
		{ action = "cancel", label = "Cancel / Clear", default = "B", group = "Core" },
		{ action = "smartAction", label = "Smart Action", default = "X", group = "Core" },
		{ action = "buildRadial", label = "Build / Factory Radial", default = "Y", group = "Core" },
		{ action = "commandLayer", label = "Command Layer", default = "RT", group = "Modifiers" },
		{ action = "insertNextCommandModifier", label = "Do Next / Insert Command Modifier", default = "RB", group = "Queue" },
		{ action = "appendQueueModifier", label = "Append Queue / Shift Modifier", default = "RT", group = "Queue" },
		{ action = "controlGroupModifier", label = "Group Layer Modifier", default = "start", group = "Modifiers" },
		{ action = "pitchModifier", label = "Pitch / Idle Type Modifier", default = "LB", group = "Modifiers" },
		{ action = "removeQueuedCommand", label = "Remove Current/Next Queue Item", default = "leftStickClick", group = "Queue" },
		{ action = "removeLastQueuedCommand", label = "Remove Last Queue Item", default = "rightStickClick", group = "Queue" },
		{ action = "radialSelect", label = "Radial Select", default = "A", group = "Radials" },
		{ action = "radialCancel", label = "Radial Cancel", default = "B", group = "Radials" },
		{ action = "radialQuick", label = "Radial Quick Place", default = "X", group = "Radials" },
		{ action = "radialClose", label = "Radial Close", default = "Y", group = "Radials" },
		{ action = "radialPrevPage", label = "Radial Previous Page", default = "LB", group = "Radials" },
		{ action = "radialNextPage", label = "Radial Next Page", default = "RB", group = "Radials" },
		{ action = "place", label = "Place / Confirm", default = "A", group = "Placement" },
		{ action = "placeStay", label = "Place and Stay", default = "X", group = "Placement" },
		{ action = "cancelPlacement", label = "Cancel Placement", default = "B", group = "Placement" },
		{ action = "rotateBuildingLeft", label = "Rotate Building Left", default = "dpadLeft", group = "Placement" },
		{ action = "rotateBuildingRight", label = "Rotate Building Right", default = "dpadRight", group = "Placement" },
		{ action = "spacingUp", label = "Increase Spacing", default = "dpadUp", group = "Placement" },
		{ action = "spacingDown", label = "Decrease Spacing", default = "dpadDown", group = "Placement" },
		{ action = "patternPrev", label = "Tap Pattern / Hold Grid", default = "LB", group = "Placement" },
		{ action = "patternNext", label = "Placement Pattern Reserved", default = "none", group = "Placement" },
		{ action = "tacticalSelect", label = "Tactical Select", default = "A", group = "Tactical" },
		{ action = "tacticalCancel", label = "Tactical Cancel", default = "B", group = "Tactical" },
		{ action = "tacticalClose", label = "Tactical Close", default = "Y", group = "Tactical" },
		{ action = "commandUp", label = "Command Guard / Patrol", default = "dpadUp", group = "Tactical" },
		{ action = "commandDown", label = "Command Reclaim", default = "dpadDown", group = "Tactical" },
		{ action = "commandLeft", label = "Command Cycle Previous", default = "dpadLeft", group = "Tactical" },
		{ action = "commandRight", label = "Command Cycle Next", default = "dpadRight", group = "Tactical" },
		{ action = "idlePrev", label = "Previous Idle Unit", default = "dpadLeft", group = "Idle / Groups" },
		{ action = "idleNext", label = "Next Idle Unit", default = "dpadRight", group = "Idle / Groups" },
		{ action = "groupSlotUp", label = "Next Group Slot", default = "dpadUp", group = "Idle / Groups" },
		{ action = "groupSlotDown", label = "Previous Group Slot", default = "dpadDown", group = "Idle / Groups" },
		{ action = "groupRecallOrAssign", label = "Recall Current Group", default = "dpadLeft", group = "Idle / Groups" },
		{ action = "groupAssign", label = "Assign Same-Type/Future Group", default = "dpadRight", group = "Idle / Groups" },
		{ action = "groupClear", label = "Clear Group", default = "leftStickClick", group = "Idle / Groups" },
	}
	bindings.definitionCache = defs
	bindings.definitionCacheVersion = version
	return defs
end

function ControllerCameraTestEnsureBindings()
	local bindings = ControllerCameraTestBindings
	bindings.defaults = bindings.defaults or {}
	bindings.actions = bindings.actions or {}
	local version = "v0.4.1-memory-cache-1"
	if bindings.defaultsInitializedVersion == version then
		return
	end
	for _, def in ipairs(ControllerCameraTestBindingDefinitions()) do
		bindings.defaults[def.action] = def.default
		if type(bindings.actions[def.action]) ~= "string" then
			bindings.actions[def.action] = def.default
		end
	end
	bindings.defaultsInitializedVersion = version
end

function ControllerCameraTestGetBinding(actionName)
	ControllerCameraTestEnsureBindings()
	return ControllerCameraTestBindings.actions[actionName] or ControllerCameraTestBindings.defaults[actionName]
end

function ControllerCameraTestBindingLabel(buttonName)
	local labels = ControllerCameraTestBindings.labelCache
	if type(labels) ~= "table" then
		labels = {
			back = "Back/View",
			start = "Start/Menu",
			dpadUp = "D-pad Up",
			dpadDown = "D-pad Down",
			dpadLeft = "D-pad Left",
			dpadRight = "D-pad Right",
			leftStickClick = "Left Stick Click",
			rightStickClick = "Right Stick Click",
			none = "Unbound",
		}
		ControllerCameraTestBindings.labelCache = labels
	end
	return labels[buttonName] or tostring(buttonName or "Unbound")
end

function ControllerCameraTestSetBinding(actionName, buttonName)
	ControllerCameraTestEnsureBindings()
	local conflict = nil
	for otherAction, assigned in pairs(ControllerCameraTestBindings.actions) do
		if otherAction ~= actionName and assigned == buttonName then
			conflict = otherAction
			break
		end
	end
	ControllerCameraTestBindings.actions[actionName] = buttonName
	ControllerCameraTestBindings.conflictAction = conflict
	ControllerCameraTestBindings.lastAction = "bound " .. tostring(actionName) .. " to "
		.. ControllerCameraTestBindingLabel(buttonName)
		.. (conflict and ("; shared with " .. tostring(conflict)) or "")
	latchSelectionDebugMessage(ControllerCameraTestBindings.lastAction)
end

function ControllerCameraTestResetBinding(actionName)
	ControllerCameraTestEnsureBindings()
	ControllerCameraTestBindings.actions[actionName] = ControllerCameraTestBindings.defaults[actionName]
	ControllerCameraTestBindings.lastAction = "reset " .. tostring(actionName) .. " to "
		.. ControllerCameraTestBindingLabel(ControllerCameraTestBindings.actions[actionName])
	latchSelectionDebugMessage(ControllerCameraTestBindings.lastAction)
end

function ControllerCameraTestResetAllBindings()
	ControllerCameraTestEnsureBindings()
	for actionName, buttonName in pairs(ControllerCameraTestBindings.defaults) do
		ControllerCameraTestBindings.actions[actionName] = buttonName
	end
	ControllerCameraTestBindings.captureAction = nil
	ControllerCameraTestBindings.conflictAction = nil
	ControllerCameraTestBindings.lastAction = "all bindings reset to defaults"
	latchSelectionDebugMessage(ControllerCameraTestBindings.lastAction)
end

function ControllerCameraTestUpdateBindingTriggerEdges()
	local state = ControllerCameraTestBindings
	local nowLT = (normalizedLeftTrigger or 0) > 0.35
	local nowRT = (normalizedRightTrigger or 0) > 0.35
	state.triggerPressed.LT = nowLT and not state.triggerDown.LT
	state.triggerPressed.RT = nowRT and not state.triggerDown.RT
	state.triggerReleased.LT = state.triggerDown.LT and not nowLT
	state.triggerReleased.RT = state.triggerDown.RT and not nowRT
	state.triggerDown.LT = nowLT
	state.triggerDown.RT = nowRT
end

function ControllerCameraTestBindingDown(buttonName)
	if buttonName == "LT" or buttonName == "RT" then
		return ControllerCameraTestBindings.triggerDown[buttonName] == true
	end
	return IsButtonDown(buttonName)
end

function ControllerCameraTestBindingPressed(buttonName)
	if buttonName == "LT" or buttonName == "RT" then
		return ControllerCameraTestBindings.triggerPressed[buttonName] == true
	end
	return WasButtonPressed(buttonName)
end

function ControllerCameraTestBindingReleased(buttonName)
	if buttonName == "LT" or buttonName == "RT" then
		return ControllerCameraTestBindings.triggerReleased[buttonName] == true
	end
	return WasButtonReleased(buttonName)
end

function ControllerCameraTestActionDown(actionName)
	return ControllerCameraTestBindingDown(ControllerCameraTestGetBinding(actionName))
end

function ControllerCameraTestActionPressed(actionName)
	return ControllerCameraTestBindingPressed(ControllerCameraTestGetBinding(actionName))
end

function ControllerCameraTestActionReleased(actionName)
	return ControllerCameraTestBindingReleased(ControllerCameraTestGetBinding(actionName))
end

function ControllerCameraTestSetBindingUIOpen(open)
	ControllerCameraTestExternalBindingUI.open = not not open
	ControllerCameraTestExternalBindingUI.lastAction = ControllerCameraTestExternalBindingUI.open and "external binding UI open" or "external binding UI closed"
end

function ControllerCameraTestIsBindingUIOpen()
	return ControllerCameraTestExternalBindingUI.open == true or ControllerCameraTestSettingsUI.open == true
end

function ControllerCameraTestIsGameplayInputBlocked()
	return ControllerCameraTestExternalBindingUI.open == true
end

function ControllerCameraTestGetSettingsDefinitions()
	local categories = ControllerCameraTestGetSettingsUICategories()
	local defaults = ControllerCameraTestGetDefaultSettings()
	local ranges = {
		panSpeed = { 100, 10000, 100, "number", 0 },
		fastPanMultiplier = { 1.0, 10.0, 0.25, "number", 2 },
		zoomSpeed = { 100, 20000, 100, "number", 0 },
		zoomBoostMultiplier = { 1.0, 12.0, 0.25, "number", 2 },
		rotationSpeed = { 0.1, 20.0, 0.1, "number", 1 },
		pitchSpeed = { 0.1, 20.0, 0.1, "number", 1 },
		cameraSmoothing = { 0.0, 1.0, 0.01, "number", 2 },
		stickCurve = { 0.25, 5.0, 0.025, "number", 3 },
		triggerCurve = { 0.25, 5.0, 0.025, "number", 3 },
		stickDeadzone = { 0, 20000, 250, "number", 0 },
		triggerDeadzone = { 0, 20000, 250, "number", 0 },
		xHoldSeconds = { 0.05, 2.0, 0.01, "number", 2 },
		aHoldSeconds = { 0.05, 2.0, 0.01, "number", 2 },
		controlGroupAssignHoldSeconds = { 0.05, 2.5, 0.01, "number", 2 },
		singlePathSpacing = { 16, 1024, 8, "number", 0 },
		singlePathInterval = { 0.02, 1.0, 0.01, "number", 2 },
		radialScale = { 0.5, 3.0, 0.05, "number", 2 },
		areaSelectRadius = { 40, 2000, 40, "number", 0 },
		reticleSize = { 4, 100, 1, "number", 0 },
		compactSelectedStatus = { 0, 1, 1, "boolean", 0 },
		hideCompactStatusWhenRadialOpen = { 0, 1, 1, "boolean", 0 },
		placementPopupEnabled = { 0, 1, 1, "boolean", 0 },
		preferNativeBlueprint = { 0, 1, 1, "boolean", 0 },
		debugPanelVisible = { 0, 1, 1, "boolean", 0 },
		helpOverlayVisible = { 0, 1, 1, "boolean", 0 },
	}

	local defs = {}
	for _, cat in ipairs(categories) do
		if not cat.bindings then
			for _, item in ipairs(cat.items) do
				local r = ranges[item.key]
				if r then
					local def = {
						key = item.key,
						label = item.label,
						group = cat.key,
						type = item.type or r[4],
						min = r[1],
						max = r[2],
						step = item.step or r[3],
						decimals = item.decimals or r[5],
						default = defaults[item.key],
						value = ControllerCameraTestSettings[item.key],
					}
					table.insert(defs, def)
				end
			end
		end
	end
	return defs
end

function ControllerCameraTestGetSetting(key)
	return ControllerCameraTestSettings[key]
end

function ControllerCameraTestSetSetting(key, value)
	local current = ControllerCameraTestSettings[key]
	if type(current) == "boolean" then
		if type(value) == "string" then
			ControllerCameraTestSettings[key] = (value == "true" or value == "ON")
		else
			ControllerCameraTestSettings[key] = not not value
		end
	else
		local num = tonumber(value)
		if num then
			ControllerCameraTestSettings[key] = ControllerCameraTestClampSetting(key, num)
		end
	end
	if key == "areaSelectRadius" then
		ControllerCameraTestAreaSelect.radius = ControllerCameraTestSettings.areaSelectRadius
	end
	ControllerCameraTestApplySettingsDefaults()
	return ControllerCameraTestSettings[key]
end

function ControllerCameraTestResetSetting(key)
	ControllerCameraTestResetSettingToDefault(key)
	return ControllerCameraTestSettings[key]
end

function ControllerCameraTestInstallWGAPI()
	WG.BARControllerSupport = WG.BARControllerSupport or {}
	WG.BARControllerSupport.GetBindingDefinitions = ControllerCameraTestBindingDefinitions
	WG.BARControllerSupport.GetBinding = ControllerCameraTestGetBinding
	WG.BARControllerSupport.SetBinding = ControllerCameraTestSetBinding
	WG.BARControllerSupport.ResetBinding = ControllerCameraTestResetBinding
	WG.BARControllerSupport.ResetAllBindings = ControllerCameraTestResetAllBindings
	WG.BARControllerSupport.GetPressedBindingInput = ControllerCameraTestGetPressedBindingInput
	WG.BARControllerSupport.IsInputPressed = ControllerCameraTestBindingPressed
	WG.BARControllerSupport.IsInputDown = ControllerCameraTestBindingDown
	WG.BARControllerSupport.SetBindingUIOpen = ControllerCameraTestSetBindingUIOpen
	WG.BARControllerSupport.IsBindingUIOpen = ControllerCameraTestIsBindingUIOpen
	WG.BARControllerSupport.GetSettingsDefinitions = ControllerCameraTestGetSettingsDefinitions
	WG.BARControllerSupport.GetSetting = ControllerCameraTestGetSetting
	WG.BARControllerSupport.SetSetting = ControllerCameraTestSetSetting
	WG.BARControllerSupport.ResetSetting = ControllerCameraTestResetSetting
	WG.BARControllerSupport.ResetAllSettings = ControllerCameraTestResetSettingsToDefaults
end

function ControllerCameraTestRemoveWGAPI()
	if not WG or not WG.BARControllerSupport then
		return
	end
	WG.BARControllerSupport.GetBindingDefinitions = nil
	WG.BARControllerSupport.GetBinding = nil
	WG.BARControllerSupport.SetBinding = nil
	WG.BARControllerSupport.ResetBinding = nil
	WG.BARControllerSupport.ResetAllBindings = nil
	WG.BARControllerSupport.GetPressedBindingInput = nil
	WG.BARControllerSupport.IsInputPressed = nil
	WG.BARControllerSupport.IsInputDown = nil
	WG.BARControllerSupport.SetBindingUIOpen = nil
	WG.BARControllerSupport.IsBindingUIOpen = nil
	WG.BARControllerSupport.GetSettingsDefinitions = nil
	WG.BARControllerSupport.GetSetting = nil
	WG.BARControllerSupport.SetSetting = nil
	WG.BARControllerSupport.ResetSetting = nil
	WG.BARControllerSupport.ResetAllSettings = nil
end

--------------------------------------------------------------------------------
-- SECTION: Settings UI
--------------------------------------------------------------------------------
function ControllerCameraTestGetSettingsUICategories()
	return {
		{ key = "Camera", items = {
			{ key = "panSpeed", label = "Pan speed", step = 50, decimals = 0 },
			{ key = "fastPanMultiplier", label = "LT pan boost", step = 0.25, decimals = 2 },
			{ key = "zoomSpeed", label = "Zoom speed", step = 100, decimals = 0 },
			{ key = "zoomBoostMultiplier", label = "LT zoom boost", step = 0.25, decimals = 2 },
			{ key = "rotationSpeed", label = "Rotation speed", step = 0.25, decimals = 2 },
			{ key = "pitchSpeed", label = "Pitch speed", step = 0.25, decimals = 2 },
			{ key = "cameraSmoothing", label = "Camera smoothing", step = 0.01, decimals = 2 },
			{ key = "stickCurve", label = "Stick curve", step = 0.025, decimals = 3 },
			{ key = "triggerCurve", label = "Trigger curve", step = 0.025, decimals = 3 },
		} },
		{ key = "Input", items = {
			{ key = "stickDeadzone", label = "Stick deadzone", step = 250, decimals = 0 },
			{ key = "triggerDeadzone", label = "Trigger deadzone", step = 250, decimals = 0 },
			{ key = "xHoldSeconds", label = "X hold seconds", step = 0.01, decimals = 2 },
			{ key = "aHoldSeconds", label = "A hold seconds", step = 0.01, decimals = 2 },
			{ key = "controlGroupAssignHoldSeconds", label = "Group assign hold", step = 0.01, decimals = 2 },
			{ key = "singlePathSpacing", label = "Path waypoint spacing", step = 8, decimals = 0 },
			{ key = "singlePathInterval", label = "Path issue interval", step = 0.01, decimals = 2 },
		} },
		{ key = "Radials", items = {
			{ key = "radialScale", label = "Radial scale", step = 0.05, decimals = 2 },
			{ key = "compactSelectedStatus", label = "Compact status panel", type = "bool" },
			{ key = "hideCompactStatusWhenRadialOpen", label = "Hide status with radial", type = "bool" },
		} },
		{ key = "Selection", items = {
			{ key = "areaSelectRadius", label = "Area select radius", step = 40, decimals = 0 },
		} },
		{ key = "Placement", items = {
			{ key = "placementPopupEnabled", label = "Placement popup", type = "bool" },
			{ key = "preferNativeBlueprint", label = "Prefer native blueprint", type = "bool" },
		} },
		{ key = "UI", items = {
			{ key = "reticleSize", label = "Reticle size", step = 1, decimals = 0 },
			{ key = "debugPanelVisible", label = "Debug panel visible", type = "bool" },
			{ key = "helpOverlayVisible", label = "Help overlay visible", type = "bool" },
		} },
		{ key = "Bindings", bindings = true, items = ControllerCameraTestBindingDefinitions() },
	}
end

function ControllerCameraTestGetSettingsUICategory()
	local ui = ControllerCameraTestSettingsUI
	local categories = ControllerCameraTestGetSettingsUICategories()
	ui.categoryIndex = math.max(1, math.min(#categories, tonumber(ui.categoryIndex) or 1))
	local category = categories[ui.categoryIndex]
	ui.selectedIndex = math.max(1, math.min(#category.items, tonumber(ui.selectedIndex) or 1))
	ui.lastCategory = category.key
	return category
end

local LEGACY_CONTROLLER_SETTINGS_UI_ENABLED = false

function ControllerCameraTestToggleSettingsUI(forceOpen)
	if not LEGACY_CONTROLLER_SETTINGS_UI_ENABLED then
		if WG.BARControllerBindingsUI and WG.BARControllerBindingsUI.Toggle then
			if forceOpen == false then
				if WG.BARControllerBindingsUI.Close then
					WG.BARControllerBindingsUI.Close()
				end
			elseif forceOpen == true then
				if WG.BARControllerBindingsUI.Open then
					WG.BARControllerBindingsUI.Open()
				end
			else
				WG.BARControllerBindingsUI.Toggle()
			end
		else
			Spring.Echo("BAR Controller Support: Legacy settings UI is disabled. Binding/Settings UI is unavailable.")
		end
		return
	end
	local ui = ControllerCameraTestSettingsUI
	ui.open = forceOpen == nil and not ui.open or forceOpen
	ui.bindingCaptureAction = nil
	ControllerCameraTestBindings.captureAction = nil
	ui.lastAction = ui.open and "settings opened" or "settings closed"
	if ui.open then
		ControllerCameraTestEnsureBindings()
		ControllerCameraTestCycleDebug.lbPressActive = false
		ControllerCameraTestCycleDebug.lbHadPitchMotion = false
		ControllerCameraTestControlGroups.leftPressActive = false
		if ControllerCameraTestDragCommand.active then
			ControllerCameraTestCancelDrag("cancelled by settings")
		end
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by settings")
		end
	end
	latchSelectionDebugMessage(ui.lastAction)
end

function ControllerCameraTestAdjustSettingFromUI(settingKey, delta, step)
	local current = ControllerCameraTestSettings[settingKey]
	if type(current) == "boolean" then
		ControllerCameraTestSettings[settingKey] = not current
	else
		ControllerCameraTestSettings[settingKey] = ControllerCameraTestClampSetting(settingKey, (tonumber(current) or 0) + ((step or 1) * delta))
	end
	ControllerCameraTestApplySettingsDefaults()
	ControllerCameraTestSettingsUI.lastAction = "changed " .. tostring(settingKey)
end

function ControllerCameraTestResetSettingToDefault(settingKey)
	local defaults = ControllerCameraTestGetDefaultSettings()
	if defaults[settingKey] ~= nil then
		ControllerCameraTestSettings[settingKey] = defaults[settingKey]
		ControllerCameraTestApplySettingsDefaults()
		ControllerCameraTestSettingsUI.lastAction = "reset " .. tostring(settingKey)
	end
end

function ControllerCameraTestResetSettingsCategory(category)
	if category.bindings then
		ControllerCameraTestResetAllBindings()
	else
		for _, item in ipairs(category.items) do
			ControllerCameraTestResetSettingToDefault(item.key)
		end
	end
	ControllerCameraTestSettingsUI.lastAction = "reset " .. tostring(category.key)
end

function ControllerCameraTestGetPressedBindingInput()
	for _, buttonName in ipairs({ "A", "X", "Y", "back", "start", "LB", "RB", "dpadUp", "dpadDown", "dpadLeft", "dpadRight", "leftStickClick", "rightStickClick" }) do
		if WasButtonPressed(buttonName) then
			return buttonName
		end
	end
	if ControllerCameraTestBindings.triggerPressed.LT then return "LT" end
	if ControllerCameraTestBindings.triggerPressed.RT then return "RT" end
	return nil
end

function ControllerCameraTestHandleSettingsUIInput()
	local ui = ControllerCameraTestSettingsUI
	if not ui.open then
		return false
	end
	local category = ControllerCameraTestGetSettingsUICategory()
	if ControllerCameraTestBindings.captureAction then
		if WasButtonPressed("B") then
			ControllerCameraTestBindings.captureAction = nil
			ui.lastAction = "binding capture cancelled"
		else
			local captured = ControllerCameraTestGetPressedBindingInput()
			if captured then
				ControllerCameraTestSetBinding(ControllerCameraTestBindings.captureAction, captured)
				ControllerCameraTestBindings.captureAction = nil
				ui.lastAction = ControllerCameraTestBindings.lastAction
			end
		end
		return true
	end
	if WasButtonPressed("B") then
		ControllerCameraTestToggleSettingsUI(false)
	elseif WasButtonPressed("LB") then
		ui.categoryIndex = ((ui.categoryIndex - 2) % #ControllerCameraTestGetSettingsUICategories()) + 1
		ui.selectedIndex = 1
	elseif WasButtonPressed("RB") then
		ui.categoryIndex = (ui.categoryIndex % #ControllerCameraTestGetSettingsUICategories()) + 1
		ui.selectedIndex = 1
	elseif WasButtonPressed("dpadUp") then
		ui.selectedIndex = ((ui.selectedIndex - 2) % #category.items) + 1
	elseif WasButtonPressed("dpadDown") then
		ui.selectedIndex = (ui.selectedIndex % #category.items) + 1
	elseif WasButtonPressed("dpadLeft") and not category.bindings then
		local item = category.items[ui.selectedIndex]
		ControllerCameraTestAdjustSettingFromUI(item.key, -1, item.step)
	elseif WasButtonPressed("dpadRight") and not category.bindings then
		local item = category.items[ui.selectedIndex]
		ControllerCameraTestAdjustSettingFromUI(item.key, 1, item.step)
	elseif WasButtonPressed("A") then
		local item = category.items[ui.selectedIndex]
		if category.bindings then
			ControllerCameraTestBindings.captureAction = item.action
			ui.lastAction = "press a controller input for " .. tostring(item.label)
		elseif item.type == "bool" then
			ControllerCameraTestAdjustSettingFromUI(item.key, 1, 1)
		end
	elseif WasButtonPressed("X") then
		local item = category.items[ui.selectedIndex]
		if category.bindings then
			ControllerCameraTestResetBinding(item.action)
		else
			ControllerCameraTestResetSettingToDefault(item.key)
		end
	elseif WasButtonPressed("Y") then
		ControllerCameraTestResetSettingsCategory(category)
	end
	return true
end

--------------------------------------------------------------------------------
-- SECTION: Command issuing
--------------------------------------------------------------------------------
function ControllerCameraTestIsInsertModifierActive()
	return ControllerCameraTestActionDown("insertNextCommandModifier")
end

function ControllerCameraTestIsQueueFrontModifierActive()
	return ControllerCameraTestIsInsertModifierActive()
end

function ControllerCameraTestIsAppendQueueModifierActive()
	if not ControllerCameraTestActionDown("appendQueueModifier") or ControllerCameraTestIsQueueFrontModifierActive() then
		return false
	end
	if commandLayerActive and not ControllerCameraTestBuildPlacement.active and not ControllerCameraTestBuildMenu.open then
		return false
	end
	return true
end

function ControllerCameraTestIsQueueModifierActive()
	return ControllerCameraTestIsAppendQueueModifierActive()
end

function ControllerCameraTestResetQueueRemovalDebug(mode)
	ControllerCameraTestCommandDebug.queueRemovalMode = tostring(mode or "none")
	ControllerCameraTestCommandDebug.queueRemovalSelectedCount = 0
	ControllerCameraTestCommandDebug.queueRemovalAttemptedCount = 0
	ControllerCameraTestCommandDebug.queueRemovalRemovedCount = 0
	ControllerCameraTestCommandDebug.queueRemovalLastQueueSize = "none"
	ControllerCameraTestCommandDebug.queueRemovalLastTag = "none"
	ControllerCameraTestCommandDebug.queueRemovalUnitDetails = "none"
end

function ControllerCameraTestAppendQueueRemovalDebug(text)
	text = tostring(text or "none")
	local current = tostring(ControllerCameraTestCommandDebug.queueRemovalUnitDetails or "none")
	if current == "none" then
		current = text
	elseif #current < 260 then
		current = current .. "; " .. text
	end
	ControllerCameraTestCommandDebug.queueRemovalUnitDetails = current
end

function ControllerCameraTestGetGameFrameSafe()
	if type(Spring.GetGameFrame) ~= "function" then
		return 1
	end
	local ok, frame = pcall(Spring.GetGameFrame)
	return ok and (tonumber(frame) or 0) or 0
end

function ControllerCameraTestGetCommandCountSafe(unitID)
	if type(Spring.GetUnitCommandCount) ~= "function" then
		return 0
	end
	local ok, count = pcall(Spring.GetUnitCommandCount, unitID)
	return ok and (tonumber(count) or 0) or 0
end

function ControllerCameraTestGetCurrentCommandSafe(unitID, cmdIndex)
	if type(Spring.GetUnitCurrentCommand) ~= "function" then
		return nil
	end
	local ok, cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2 = pcall(Spring.GetUnitCurrentCommand, unitID, cmdIndex)
	if not ok then
		return nil
	end
	return cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2
end

function ControllerCameraTestGetUnitCommandsSafe(unitID, count)
	if type(Spring.GetUnitCommands) ~= "function" then
		return nil
	end
	local ok, commands = pcall(Spring.GetUnitCommands, unitID, count)
	if ok and type(commands) == "table" then
		return commands
	end
	return nil
end

function ControllerCameraTestGiveOrderToUnitSafe(unitID, cmdID, params, options)
	if type(Spring.GiveOrderToUnit) ~= "function" or not unitID or not cmdID then
		return false
	end
	return pcall(Spring.GiveOrderToUnit, unitID, cmdID, params or {}, options or 0)
end

function ControllerCameraTestRemovePregameBuildQueueCommand(cmdIndex)
	local pregame = WG and WG["pregame-build"]
	if type(pregame) ~= "table" or type(pregame.getBuildQueue) ~= "function" or type(pregame.setBuildQueue) ~= "function" then
		ControllerCameraTestAppendQueueRemovalDebug("pregame unavailable")
		return false, "pregame unavailable"
	end
	local ok, buildQueue = pcall(pregame.getBuildQueue)
	if not ok or type(buildQueue) ~= "table" or #buildQueue == 0 then
		ControllerCameraTestAppendQueueRemovalDebug("pregame empty")
		return false, "pregame empty"
	end
	cmdIndex = math.max(1, math.min(#buildQueue, tonumber(cmdIndex) or 1))
	local newQueue = {}
	for i, item in ipairs(buildQueue) do
		if i ~= cmdIndex then
			newQueue[#newQueue + 1] = item
		end
	end
	local setOk = pcall(pregame.setBuildQueue, newQueue)
	ControllerCameraTestCommandDebug.queueRemovalLastQueueSize = tostring(#buildQueue)
	ControllerCameraTestCommandDebug.queueRemovalLastTag = "pregame:" .. tostring(cmdIndex)
	ControllerCameraTestAppendQueueRemovalDebug("pregame q" .. tostring(#buildQueue) .. " idx" .. tostring(cmdIndex) .. (setOk and " removed" or " failed"))
	return setOk, setOk and "pregame removed" or "pregame set failed"
end

function ControllerCameraTestRemoveCommand(unitID, cmdIndex, commandQueueSize)
	if ControllerCameraTestGetGameFrameSafe() <= 0 then
		return ControllerCameraTestRemovePregameBuildQueueCommand(cmdIndex)
	end

	commandQueueSize = tonumber(commandQueueSize) or ControllerCameraTestGetCommandCountSafe(unitID)
	ControllerCameraTestCommandDebug.queueRemovalLastQueueSize = tostring(commandQueueSize or "none")
	if not unitID then
		ControllerCameraTestAppendQueueRemovalDebug("no unit")
		return false, "no unit"
	end
	if not commandQueueSize or commandQueueSize < 1 then
		ControllerCameraTestAppendQueueRemovalDebug("u" .. tostring(unitID) .. " empty")
		return false, "empty queue"
	end

	cmdIndex = math.max(1, math.min(commandQueueSize, tonumber(cmdIndex) or 1))
	local cmdID, _, cmdTag, _, cmdParam2 = ControllerCameraTestGetCurrentCommandSafe(unitID, cmdIndex)
	ControllerCameraTestCommandDebug.queueRemovalLastTag = tostring(cmdTag or "none")
	if not cmdID or not cmdTag then
		ControllerCameraTestAppendQueueRemovalDebug("u" .. tostring(unitID) .. " q" .. tostring(commandQueueSize) .. " no tag")
		return false, "no command tag"
	end

	local commandDeleted = false
	local result = "remove tag " .. tostring(cmdTag)
	if (cmdID == CMD.RECLAIM or cmdID == CMD.REPAIR) and cmdParam2 then
		local _, _, cmdTag2 = ControllerCameraTestGetCurrentCommandSafe(unitID, cmdIndex + 1)
		if cmdTag2 then
			commandDeleted = ControllerCameraTestGiveOrderToUnitSafe(unitID, CMD.REMOVE, { cmdTag2, cmdTag }, 0)
			result = "remove area pair " .. tostring(cmdTag2) .. "," .. tostring(cmdTag)
		end
	elseif cmdID == CMD.REPAIR and cmdIndex ~= commandQueueSize then
		local cmdID2, _, cmdTag2 = ControllerCameraTestGetCurrentCommandSafe(unitID, cmdIndex + 1)
		if cmdID2 == CMD.GUARD and cmdTag2 then
			commandDeleted = ControllerCameraTestGiveOrderToUnitSafe(unitID, CMD.REMOVE, { cmdTag2, cmdTag }, 0)
			result = "remove repair/guard pair " .. tostring(cmdTag2) .. "," .. tostring(cmdTag)
		end
	elseif cmdID == CMD.GUARD and cmdIndex ~= 1 then
		local cmdID2, _, cmdTag2 = ControllerCameraTestGetCurrentCommandSafe(unitID, cmdIndex - 1)
		if cmdID2 == CMD.REPAIR and cmdTag2 then
			commandDeleted = ControllerCameraTestGiveOrderToUnitSafe(unitID, CMD.REMOVE, { cmdTag, cmdTag2 }, 0)
			result = "remove guard/repair pair " .. tostring(cmdTag) .. "," .. tostring(cmdTag2)
		end
	elseif cmdID == CMD.FIGHT and cmdIndex == 1 then
		local commands = ControllerCameraTestGetUnitCommandsSafe(unitID, -1)
		if commands and commands[2] and commands[2].id == CMD.PATROL then
			commandQueueSize = commandQueueSize - 2
			ControllerCameraTestGiveOrderToUnitSafe(unitID, CMD.STOP, {}, {})
			for i = 1, #commands do
				if i == 1 then
					ControllerCameraTestGiveOrderToUnitSafe(unitID, CMD.MOVE, commands[i].params, {})
				end
				if i ~= cmdIndex then
					ControllerCameraTestGiveOrderToUnitSafe(unitID, commands[i].id, commands[i].params, { "shift" })
				end
			end
			commandDeleted = true
			result = "rebuilt fight/patrol queue"
		end
	end

	if not commandDeleted then
		commandDeleted = ControllerCameraTestGiveOrderToUnitSafe(unitID, CMD.REMOVE, { cmdTag }, 0)
	end
	if commandDeleted and commandQueueSize == 1 then
		ControllerCameraTestGiveOrderToUnitSafe(unitID, CMD.STOP, {}, 0)
	end

	ControllerCameraTestAppendQueueRemovalDebug("u" .. tostring(unitID) .. " q" .. tostring(commandQueueSize) .. " idx" .. tostring(cmdIndex) .. " " .. tostring(result) .. (commandDeleted and " ok" or " failed"))
	return commandDeleted, commandDeleted and result or "remove failed"
end

function ControllerCameraTestProcessSelectedUnits(processCommandFunc)
	if ControllerCameraTestGetGameFrameSafe() <= 0 then
		ControllerCameraTestCommandDebug.queueRemovalSelectedCount = 0
		ControllerCameraTestCommandDebug.queueRemovalAttemptedCount = 1
		local removed = processCommandFunc(nil, true)
		ControllerCameraTestCommandDebug.queueRemovalRemovedCount = removed and 1 or 0
		return removed and 1 or 0, 1
	end

	if type(Spring.GetSelectedUnits) ~= "function" then
		ControllerCameraTestAppendQueueRemovalDebug("selection API unavailable")
		return 0, 0
	end

	local ok, selectedUnits = pcall(Spring.GetSelectedUnits)
	if not ok or type(selectedUnits) ~= "table" or #selectedUnits == 0 then
		ControllerCameraTestCommandDebug.queueRemovalSelectedCount = 0
		ControllerCameraTestAppendQueueRemovalDebug("no selected units")
		return 0, 0
	end

	ControllerCameraTestCommandDebug.queueRemovalSelectedCount = #selectedUnits
	local removedCount = 0
	local attemptedCount = 0
	for i = 1, #selectedUnits do
		attemptedCount = attemptedCount + 1
		if processCommandFunc(selectedUnits[i], false) then
			removedCount = removedCount + 1
		end
	end
	ControllerCameraTestCommandDebug.queueRemovalAttemptedCount = attemptedCount
	ControllerCameraTestCommandDebug.queueRemovalRemovedCount = removedCount
	return removedCount, attemptedCount
end

function ControllerCameraTestSkipCurrentCommand()
	return ControllerCameraTestProcessSelectedUnits(function(unitID, force)
		if force then
			return ControllerCameraTestRemoveCommand(nil, 1, nil)
		end
		return ControllerCameraTestRemoveCommand(unitID, 1, ControllerCameraTestGetCommandCountSafe(unitID))
	end)
end

function ControllerCameraTestCancelLastCommand()
	return ControllerCameraTestProcessSelectedUnits(function(unitID, force)
		if force then
			local pregame = WG and WG["pregame-build"]
			local buildQueue = type(pregame) == "table" and type(pregame.getBuildQueue) == "function" and select(2, pcall(pregame.getBuildQueue)) or nil
			return ControllerCameraTestRemoveCommand(nil, type(buildQueue) == "table" and #buildQueue or 1, nil)
		end
		local commandQueueSize = ControllerCameraTestGetCommandCountSafe(unitID)
		if not commandQueueSize or commandQueueSize < 1 then
			ControllerCameraTestAppendQueueRemovalDebug("u" .. tostring(unitID) .. " empty")
			return false
		end
		return ControllerCameraTestRemoveCommand(unitID, commandQueueSize, commandQueueSize)
	end)
end

function ControllerCameraTestIssueQueueRemovalCommand(removeLast)
	ControllerCameraTestResetQueueRemovalDebug(removeLast and "cancel-last" or "skip-current")
	local removedCount, attemptedCount
	if removeLast then
		removedCount, attemptedCount = ControllerCameraTestCancelLastCommand()
	else
		removedCount, attemptedCount = ControllerCameraTestSkipCurrentCommand()
	end

	local result = (removeLast and "queue cancel-last" or "queue skip-current")
		.. " removed " .. tostring(removedCount or 0) .. "/" .. tostring(attemptedCount or 0)
	ControllerCameraTestCommandDebug.lastOptions = removeLast and "LT queue removal" or "queue removal"
	ControllerCameraTestCommandDebug.lastResult = result
	ControllerCameraTestLayerDebug.normalUtilityAction = result
	lastIssuedCommand = result
	latchSelectionDebugMessage(result)
	return true
end

function ControllerCameraTestHandleQueueRemovalInput()
	if ControllerCameraTestActionPressed("removeQueuedCommand") then
		if ControllerCameraTestGetBinding("removeQueuedCommand") == "back" then
			return false
		end
		return ControllerCameraTestIssueQueueRemovalCommand(false)
	end
	if ControllerCameraTestActionPressed("removeLastQueuedCommand") then
		if ControllerCameraTestGetBinding("removeLastQueuedCommand") == "back" then
			return false
		end
		return ControllerCameraTestIssueQueueRemovalCommand(true)
	end
	return false
end

function ControllerCameraTestGetCommandOptions(extraOptions)
	local opts = {}
	if ControllerCameraTestIsQueueModifierActive() then
		opts[#opts + 1] = "shift"
	end
	if type(extraOptions) == "table" then
		for _, opt in ipairs(extraOptions) do
			opts[#opts + 1] = opt
		end
	end
	return opts
end

function ControllerCameraTestCommandOptionsSummary(options)
	if type(options) ~= "table" or #options == 0 then
		return "none"
	end
	return table.concat(options, ",")
end

local function issueOrderToSelection(cmdID, params, cmdName, targetName, options)
	-- 1. Check if we actually have units selected
	local selectedUnits = type(Spring.GetSelectedUnits) == "function" and Spring.GetSelectedUnits() or {}
	local paramsCount = type(params) == "table" and #params or 0
	local orderOptions = type(options) == "table" and options or ControllerCameraTestGetCommandOptions()
	ControllerCameraTestCommandDebug.issuedCmdID = tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = paramsCount
	ControllerCameraTestCommandDebug.lastOptions = ControllerCameraTestCommandOptionsSummary(orderOptions)
	if #selectedUnits == 0 then
		lastIssuedCommand = "none"
		ControllerCameraTestCommandDebug.lastResult = "no selected units"
		latchSelectionDebugMessage(tostring(cmdName) .. " skipped: no units selected")
		return
	end

	-- 2. Use the universally safe LuaUI GiveOrder API
	if type(Spring.GiveOrder) == "function" then
		local orderOk, orderResult = pcall(Spring.GiveOrder, cmdID, params, orderOptions)
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
	ControllerCameraTestCommandDebug.lastOptions = forceShift and "shift" or "none"

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

local function ControllerCameraTestIssueBuildOrders(builders, unitDefID, buildPositions, useQueue, useQueueFront)
	local cmdInsert = CMD.INSERT or 140
	local firstOpts = useQueue and { "shift" } or {}
	ControllerCameraTestCommandDebug.lastOptions = useQueueFront and "queue-front" or ControllerCameraTestCommandOptionsSummary(firstOpts)
	local restOpts = { "shift" }

	if useQueueFront then
		for i = #buildPositions, 1, -1 do
			local bp = buildPositions[i]
			local bx, by, bz, bfacing = bp[1], bp[2], bp[3], bp[4] or 0
			for _, unitID in ipairs(builders) do
				pcall(spGiveOrderToUnit, unitID, cmdInsert, { 0, -unitDefID, 0, bx, by, bz, bfacing }, { "alt" })
			end
		end
		return true
	end

	if type(Spring.GiveOrderArrayToUnitArray) == "function" then
		local orders = {}
		for i, bp in ipairs(buildPositions) do
			local bx, by, bz, bfacing = bp[1], bp[2], bp[3], bp[4] or 0
			local opts = (i == 1 and not useQueue) and {} or { "shift" }
			table.insert(orders, { -unitDefID, { bx, by, bz, bfacing }, opts })
		end
		local ok, err = pcall(Spring.GiveOrderArrayToUnitArray, builders, orders, false)
		if ok then
			return true
		end
	end

	for i, bp in ipairs(buildPositions) do
		local bx, by, bz, bfacing = bp[1], bp[2], bp[3], bp[4] or 0
		local opts = (i == 1 and not useQueue) and {} or { "shift" }
		for _, unitID in ipairs(builders) do
			pcall(spGiveOrderToUnit, unitID, -unitDefID, { bx, by, bz, bfacing }, opts)
		end
	end
	return true
end

function ControllerCameraTestClearNativeBlueprintPreview()
	local api = WG and WG["api_blueprint"]
	if type(api) ~= "table" then
		return
	end
	if type(api.setActiveBlueprint) == "function" then
		pcall(api.setActiveBlueprint, nil)
	end
	if type(api.setBlueprintPositions) == "function" then
		pcall(api.setBlueprintPositions, {})
	end
end

function ControllerCameraTestGetSelectedMobileUnits()
	local mobileUnits = {}
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	for _, unitID in ipairs(selectedUnits) do
		local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if type(unitDef) == "table" and not unitDef.isBuilding and not unitDef.isFactory then
			mobileUnits[#mobileUnits + 1] = unitID
		end
	end
	return mobileUnits
end

--------------------------------------------------------------------------------
-- SECTION: Drag/path commands
--------------------------------------------------------------------------------
function ControllerCameraTestIssueSingleUnitPathPoint(isFirst)
	local drag = ControllerCameraTestDragCommand
	if not drag.singleUnitPathActive or not drag.singleUnitPathUnitID
		or not reticleHasWorldTarget or not reticleWorldX or not reticleWorldY or not reticleWorldZ
	then
		return false
	end
	if not isFirst then
		local dx = reticleWorldX - (drag.singleUnitLastPointX or reticleWorldX)
		local dz = reticleWorldZ - (drag.singleUnitLastPointZ or reticleWorldZ)
		local spacing = ControllerCameraTestSettings.singlePathSpacing or 96
		local interval = ControllerCameraTestSettings.singlePathInterval or 0.10
		if ((dx * dx) + (dz * dz)) < (spacing * spacing)
			or (debugEventTime - (drag.singleUnitLastIssueTime or 0)) < interval
		then
			return false
		end
	end
	if type(spGiveOrderToUnit) ~= "function" or not CMD or type(CMD.MOVE) ~= "number" then
		drag.singleUnitPathResult = "move API unavailable"
		return false
	end

	local options = {}
	if not isFirst or ControllerCameraTestIsQueueModifierActive() then
		options = { "shift" }
	end
	local ok, result = pcall(spGiveOrderToUnit, drag.singleUnitPathUnitID, CMD.MOVE, { reticleWorldX, reticleWorldY, reticleWorldZ }, options)
	if not ok or result == false then
		drag.singleUnitPathResult = "waypoint rejected"
		return false
	end

	drag.singleUnitPathPoints[#drag.singleUnitPathPoints + 1] = { reticleWorldX, reticleWorldY, reticleWorldZ }
	drag.previewPoints = drag.singleUnitPathPoints
	drag.singleUnitLastPointX, drag.singleUnitLastPointY, drag.singleUnitLastPointZ = reticleWorldX, reticleWorldY, reticleWorldZ
	drag.singleUnitLastIssueTime = debugEventTime
	drag.singleUnitWaypointCount = #drag.singleUnitPathPoints
	drag.singleUnitPathResult = "recording " .. tostring(drag.singleUnitWaypointCount) .. " waypoints"
	ControllerCameraTestCommandDebug.issuedCmdID = tostring(CMD.MOVE)
	ControllerCameraTestCommandDebug.issuedParamsCount = 3
	ControllerCameraTestCommandDebug.lastOptions = ControllerCameraTestCommandOptionsSummary(options)
	ControllerCameraTestCommandDebug.lastResult = "single path waypoint accepted"
	return true
end

function ControllerCameraTestStartSingleUnitPath(unitID)
	local drag = ControllerCameraTestDragCommand
	drag.active = true
	drag.mode = "singleMovePath"
	drag.singleUnitPathActive = true
	drag.singleUnitPathUnitID = unitID
	drag.singleUnitPathPoints = {}
	drag.singleUnitLastPointX, drag.singleUnitLastPointY, drag.singleUnitLastPointZ = nil, nil, nil
	drag.singleUnitLastIssueTime = -10
	drag.singleUnitWaypointCount = 0
	drag.singleUnitPathResult = "started"
	drag.previewPoints = drag.singleUnitPathPoints
	drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
	drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
	ControllerCameraTestIssueSingleUnitPathPoint(true)
	latchSelectionDebugMessage("Single-unit move path started")
end

function ControllerCameraTestUpdateSingleUnitPath()
	local drag = ControllerCameraTestDragCommand
	if drag.singleUnitPathActive then
		drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
		ControllerCameraTestIssueSingleUnitPathPoint(false)
	end
end

function ControllerCameraTestFinishSingleUnitPath()
	local drag = ControllerCameraTestDragCommand
	local count = drag.singleUnitWaypointCount or 0
	drag.singleUnitPathActive = false
	drag.active = false
	drag.pressActive = false
	drag.lastMode = "singleMovePath"
	drag.lastResult = "single path issued " .. tostring(count) .. " waypoints"
	drag.singleUnitPathResult = drag.lastResult
	lastIssuedCommand = drag.lastResult
	latchSelectionDebugMessage(drag.lastResult)
end

function ControllerCameraTestUpdateDragPreview()
	local drag = ControllerCameraTestDragCommand
	if not drag.active then
		ControllerCameraTestClearNativeBlueprintPreview()
		drag.previewPoints = {}
		return
	end

	if drag.mode == "singleMovePath" then
		ControllerCameraTestUpdateSingleUnitPath()
		return
	end

	local startX, startY, startZ = drag.startX, drag.startY, drag.startZ
	local endX, endY, endZ = reticleWorldX, reticleWorldY, reticleWorldZ
	if not endX or not startX then return end

	drag.endX, drag.endY, drag.endZ = endX, endY, endZ

	if drag.mode == "moveLine" or drag.mode == "fightLine" or drag.mode == "attackLine" then
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		local mobileUnits = {}
		for _, unitID in ipairs(selectedUnits) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			local unitDef = unitDefID and UnitDefs[unitDefID]
			if unitDef and not unitDef.isBuilding and not unitDef.isFactory then
				table.insert(mobileUnits, unitID)
			end
		end

		local N = #mobileUnits
		local pts = {}
		if N == 1 then
			table.insert(pts, { endX, endY, endZ })
		elseif N > 1 then
			for i = 1, N do
				local t = (i - 1) / (N - 1)
				local x = startX + t * (endX - startX)
				local z = startZ + t * (endZ - startZ)
				local y = Spring.GetGroundHeight(x, z)
				table.insert(pts, { x, y, z })
			end
		end
		drag.previewPoints = pts

	elseif drag.mode == "buildLine" or drag.mode == "buildGrid" or drag.mode == "buildBorder" then
		local option = ControllerCameraTestBuildPlacement.option
		if option and type(option.cmdID) == "number" and option.cmdID < 0 then
			local unitDefID = -option.cmdID
			local facing = ControllerCameraTestBuildPlacement.facing or 0
			local spacing = ControllerCameraTestBuildPlacement.placementSpacing or 0

			local bp = {
				facing = facing,
				units = {
					{
						blueprintUnitID = 1,
						unitDefID = unitDefID,
						position = { 0, 0, 0 },
						facing = 0
					}
				}
			}

			local startPos = { startX, startY, startZ }
			local endPos = { endX, endY, endZ }

			local api = type(WG) == "table" and WG["api_blueprint"] or nil
			local nativeModes = type(api) == "table" and api.BUILD_MODES or nil
			local modeMap = nativeModes and {
				buildLine = nativeModes.LINE,
				buildGrid = nativeModes.GRID,
				buildBorder = nativeModes.BOX,
				buildSplit = nativeModes.SPLIT,
			} or {}
			local apiMode = modeMap[drag.mode]
			local buildPositions = {}

			drag.nativeRouteUsed = false
			drag.nativeRouteName = "unavailable"
			drag.nativePreviewResult = "not attempted"
			drag.customGridFallback = "yes"
			if ControllerCameraTestSettings.preferNativeBlueprint ~= false and apiMode and type(api.calculateBuildPositions) == "function" then
				local ok, res = pcall(api.calculateBuildPositions, bp, apiMode, startPos, endPos, spacing)
				if ok and type(res) == "table" and #res > 0 then
					buildPositions = res
					drag.nativeRouteUsed = true
					drag.nativeRouteName = "api_blueprint.calculateBuildPositions"
					drag.nativePreviewResult = "positions calculated"
					drag.customGridFallback = "no"
					if type(api.setActiveBlueprint) == "function"
						and type(api.setBlueprintPositions) == "function"
					then
						local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
						if type(api.setActiveBuilders) == "function" then
							pcall(api.setActiveBuilders, selectedUnits)
						end
						local previewOk = pcall(api.setActiveBlueprint, bp)
						local posOk = pcall(api.setBlueprintPositions, buildPositions)
						if previewOk and posOk then
							drag.nativePreviewResult = "native preview active"
						end
					end
				end
			end
			if not drag.nativeRouteUsed then
				ControllerCameraTestClearNativeBlueprintPreview()
			end

			if #buildPositions == 0 then
				local unitDef = UnitDefs[unitDefID]
				if unitDef then
					local sizeX = unitDef.xsize * 8
					local sizeZ = unitDef.zsize * 8
					local bw, bh
					if facing % 2 == 1 then bw, bh = sizeZ, sizeX else bw, bh = sizeX, sizeZ end

					if drag.mode == "buildLine" then
						local dx = endX - startX
						local dz = endZ - startZ
						local dist = math.sqrt(dx*dx + dz*dz)
						local stepSize = math.max(bw, bh) + spacing * 16
						if dist < 2 then
							table.insert(buildPositions, { startX, startY, startZ, facing })
						else
							local vx, vz = dx / dist, dz / dist
							local numBuildings = math.floor(dist / stepSize) + 1
							if numBuildings > 100 then numBuildings = 100 end
							for i = 0, numBuildings - 1 do
								local x = startX + i * stepSize * vx
								local z = startZ + i * stepSize * vz
								local y = Spring.GetGroundHeight(x, z)
								table.insert(buildPositions, { x, y, z, facing })
							end
						end
					elseif drag.mode == "buildGrid" then
						local dx = endX - startX
						local dz = endZ - startZ
						local stepX = bw + spacing * 16
						local stepZ = bh + spacing * 16
						local numX = math.floor(math.abs(dx) / stepX) + 1
						local numZ = math.floor(math.abs(dz) / stepZ) + 1
						if numX * numZ > 100 then
							numX = 10
							numZ = 10
						end
						local signX = dx >= 0 and 1 or -1
						local signZ = dz >= 0 and 1 or -1
						for ix = 0, numX - 1 do
							for iz = 0, numZ - 1 do
								local x = startX + ix * stepX * signX
								local z = startZ + iz * stepZ * signZ
								local y = Spring.GetGroundHeight(x, z)
								table.insert(buildPositions, { x, y, z, facing })
							end
						end
					elseif drag.mode == "buildBorder" or drag.mode == "buildSplit" then
						table.insert(buildPositions, { startX, startY, startZ, facing })
						table.insert(buildPositions, { endX, endY, endZ, facing })
					end
				end
			end

			drag.previewPoints = buildPositions
		end
	end
end

function ControllerCameraTestConfirmDragCommand(exitMode)
	local drag = ControllerCameraTestDragCommand
	if not drag.active then return end

	local startX, startY, startZ = drag.startX, drag.startY, drag.startZ
	local endX, endY, endZ = drag.endX or reticleWorldX, drag.endY or reticleWorldY, drag.endZ or reticleWorldZ

	if not endX or not startX then
		drag.active = false
		drag.lastResult = "failed: no world target"
		return
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		drag.active = false
		drag.lastResult = "failed: no selected units"
		latchSelectionDebugMessage("Drag failed: no units selected")
		return
	end

	local isQueueFront = ControllerCameraTestIsQueueFrontModifierActive()
	local orderOptions = ControllerCameraTestGetCommandOptions()
	ControllerCameraTestCommandDebug.lastOptions = ControllerCameraTestCommandOptionsSummary(orderOptions)

	if drag.mode == "moveLine" or drag.mode == "fightLine" or drag.mode == "attackLine" then
		local mobileUnits = {}
		for _, unitID in ipairs(selectedUnits) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			local unitDef = unitDefID and UnitDefs[unitDefID]
			if unitDef and not unitDef.isBuilding and not unitDef.isFactory then
				table.insert(mobileUnits, unitID)
			end
		end

		local N = #mobileUnits
		if N == 0 then
			drag.active = false
			drag.lastResult = "failed: no selected mobile units"
			latchSelectionDebugMessage("Drag failed: no mobile units")
			return
		end

		local dx = endX - startX
		local dz = endZ - startZ
		local dist = math.sqrt(dx*dx + dz*dz)
		if dist > 0.1 then
			local vx, vz = dx / dist, dz / dist
			local sortedUnits = {}
			for _, unitID in ipairs(mobileUnits) do
				local ux, uy, uz = Spring.GetUnitPosition(unitID)
				if ux and uz then
					local proj = (ux - startX) * vx + (uz - startZ) * vz
					table.insert(sortedUnits, { unitID = unitID, proj = proj })
				else
					table.insert(sortedUnits, { unitID = unitID, proj = 0 })
				end
			end
			table.sort(sortedUnits, function(a, b) return a.proj < b.proj end)
			mobileUnits = {}
			for _, item in ipairs(sortedUnits) do
				table.insert(mobileUnits, item.unitID)
			end
		end

		local points = {}
		if N == 1 then
			table.insert(points, { endX, endY, endZ })
		else
			for i = 1, N do
				local t = (i - 1) / (N - 1)
				local px = startX + t * (endX - startX)
				local pz = startZ + t * (endZ - startZ)
				local py = Spring.GetGroundHeight(px, pz)
				table.insert(points, { px, py, pz })
			end
		end

		local cmdID = CMD.MOVE
		local cmdName = "Move Line"
		if drag.mode == "fightLine" then
			cmdID = CMD.FIGHT
			cmdName = "Fight Line"
		elseif drag.mode == "attackLine" then
			cmdID = CMD.ATTACK
			cmdName = "Attack Line"
		end

		local cmdInsert = CMD.INSERT or 140
		if isQueueFront then
			for i = #points, 1, -1 do
				local pt = points[i]
				local unitID = mobileUnits[i]
				pcall(spGiveOrderToUnit, unitID, cmdInsert, { 0, cmdID, 0, pt[1], pt[2], pt[3] }, { "alt" })
			end
		else
			for i, pt in ipairs(points) do
				local unitID = mobileUnits[i]
				pcall(spGiveOrderToUnit, unitID, cmdID, { pt[1], pt[2], pt[3] }, orderOptions)
			end
		end

		drag.lastResult = "issued " .. cmdName .. " to " .. tostring(N) .. " units"
		latchSelectionDebugMessage(cmdName .. " confirmed!")
		ControllerCameraTestSetCommandMarker(endX, endY, endZ, cmdName, "build")

	elseif drag.mode == "reclaimArea" or drag.mode == "repairArea" or drag.mode == "attackArea" then
		local dx = endX - startX
		local dz = endZ - startZ
		local r = math.sqrt(dx*dx + dz*dz)
		if r < 10 then r = 120 end

		local cmdID = CMD.RECLAIM
		local cmdName = "Reclaim Area"
		if drag.mode == "repairArea" then
			cmdID = CMD.REPAIR
			cmdName = "Repair Area"
		elseif drag.mode == "attackArea" then
			cmdID = CMD.ATTACK
			cmdName = "Attack Area"
		end

		local params = { startX, startY, startZ, r }
		local issued = 0

		if isQueueFront then
			local cmdInsert = CMD.INSERT or 140
			for _, unitID in ipairs(selectedUnits) do
				local ok, err = pcall(spGiveOrderToUnit, unitID, cmdInsert, { 0, cmdID, 0, startX, startY, startZ, r }, { "alt" })
				if ok then issued = issued + 1 end
			end
		else
			for _, unitID in ipairs(selectedUnits) do
				local ok, err = pcall(spGiveOrderToUnit, unitID, cmdID, params, orderOptions)
				if ok then issued = issued + 1 end
			end
		end

		drag.lastResult = "issued " .. cmdName .. " to " .. tostring(issued) .. " units"
		latchSelectionDebugMessage(cmdName .. " confirmed!")
		ControllerCameraTestSetCommandMarker(startX, startY, startZ, cmdName, "build")
	end

	drag.lastMode = drag.mode
	drag.active = false
	ControllerCameraTestClearNativeBlueprintPreview()
end

function ControllerCameraTestConfirmDragBuild(exitMode)
	local drag = ControllerCameraTestDragCommand
	if not drag.active then return end

	local startX, startY, startZ = drag.startX, drag.startY, drag.startZ
	local endX, endY, endZ = drag.endX or reticleWorldX, drag.endY or reticleWorldY, drag.endZ or reticleWorldZ

	if not endX or not startX then
		drag.active = false
		drag.lastResult = "failed: no world target"
		return
	end

	local placement = ControllerCameraTestBuildPlacement
	if not placement.option or type(placement.option.cmdID) ~= "number" then
		drag.active = false
		drag.lastResult = "failed: no build option"
		return
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		drag.active = false
		drag.lastResult = "failed: no selected units"
		latchSelectionDebugMessage("Build drag failed: no builders")
		return
	end

	if drag.mode == "buildBorder" and not (WG["api_blueprint"] and WG["api_blueprint"].calculateBuildPositions) then
		drag.active = false
		drag.lastResult = "border unavailable: native route not found"
		latchSelectionDebugMessage("Border build unavailable natively")
		return
	elseif drag.mode == "buildSplit" then
		drag.active = false
		drag.lastResult = "split unavailable: native route not found"
		latchSelectionDebugMessage("Split build unavailable natively")
		return
	end

	ControllerCameraTestUpdateDragPreview()
	local points = drag.previewPoints or {}
	if #points == 0 then
		drag.active = false
		drag.lastResult = "failed: no points"
		latchSelectionDebugMessage("Build drag failed: no positions")
		return
	end

	local unitDefID = -placement.option.cmdID
	local useQueue = placement.queueActive
	local useQueueFront = placement.queueFrontActive

	ControllerCameraTestIssueBuildOrders(selectedUnits, unitDefID, points, useQueue, useQueueFront)

	drag.lastResult = "placed " .. tostring(#points) .. " buildings"
	latchSelectionDebugMessage("Placed " .. tostring(#points) .. " " .. placement.option.name)

	drag.lastMode = drag.mode
	drag.active = false
	ControllerCameraTestClearNativeBlueprintPreview()

	if exitMode then
		ControllerCameraTestCancelPlacement("placed and exited")
	end
end

function ControllerCameraTestCancelDrag(reason)
	local drag = ControllerCameraTestDragCommand
	if drag.singleUnitPathActive then
		drag.singleUnitPathResult = reason or "single path cancelled"
	end
	drag.active = false
	drag.pressActive = false
	drag.singleUnitPathActive = false
	drag.singleUnitPathUnitID = nil
	drag.lastResult = reason or "cancelled"
	drag.previewPoints = {}
	ControllerCameraTestClearNativeBlueprintPreview()
	latchSelectionDebugMessage("Drag cancelled")
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
		and ControllerCameraTestAttemptMexBuildSmartAction(reticleWorldX, reticleWorldY, reticleWorldZ, ControllerCameraTestIsQueueModifierActive())
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
	issueOrderToSelection(CMD.STOP, {}, "Stop", "none", {})
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

--------------------------------------------------------------------------------
-- SECTION: Selection utilities and allied target helpers
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- SECTION: Selection orders and issuing utility
--------------------------------------------------------------------------------
function ControllerCameraTestIssueOrderToSelectedUnits(cmdID, params, cmdName, targetName, options)
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	params = type(params) == "table" and params or {}

	local useInsert = options == nil and ControllerCameraTestIsQueueFrontModifierActive()
	local finalOpts = type(options) == "table" and options or ControllerCameraTestGetCommandOptions()

	ControllerCameraTestCommandDebug.issuedCmdID = useInsert and tostring(CMD.INSERT or 140) or tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = useInsert and (#params + 3) or #params
	ControllerCameraTestCommandDebug.lastOptions = useInsert and "alt" or ControllerCameraTestCommandOptionsSummary(finalOpts)
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
	local cmdInsert = CMD.INSERT or 140
	for _, unitID in ipairs(selectedUnits) do
		local ok, result
		if useInsert then
			local insertParams = { 0, cmdID, 0 }
			for i = 1, #params do
				insertParams[#insertParams + 1] = params[i]
			end
			ok, result = pcall(spGiveOrderToUnit, unitID, cmdInsert, insertParams, { "alt" })
		else
			ok, result = pcall(spGiveOrderToUnit, unitID, cmdID, params, finalOpts)
		end
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
	ControllerCameraTestCycleDebug.lastResult = "visible select disabled"
	ControllerCameraTestLayerDebug.commandLayerAction = "Layer+A select-all disabled"
	latchSelectionDebugMessage("Visible select-all is disabled")
	return false
end

function ControllerCameraTestSelectSameTypeAtReticleOrCombat()
	return ControllerCameraTestSelectSameTypeFromReticle(false)
end

function ControllerCameraTestIsOwnUnit(unitID)
	if not unitID or type(Spring.GetUnitTeam) ~= "function" then
		return false
	end
	local myTeam = type(Spring.GetMyTeamID) == "function" and Spring.GetMyTeamID()
		or (type(Spring.GetLocalTeamID) == "function" and Spring.GetLocalTeamID() or nil)
	if not myTeam then
		return false
	end
	local ok, unitTeam = pcall(Spring.GetUnitTeam, unitID)
	return ok and unitTeam == myTeam
end

function ControllerCameraTestGetAllOwnedUnitsOfType(unitDefID)
	local units = {}
	if not unitDefID then
		return units
	end
	for _, unitID in ipairs(ControllerCameraTestGetOwnTeamUnits()) do
		local ok, candidateDefID = pcall(Spring.GetUnitDefID, unitID)
		if ok and candidateDefID == unitDefID then
			units[#units + 1] = unitID
		end
	end
	return ControllerCameraTestFilterValidUnits(units)
end

function ControllerCameraTestGetReticleAlliedUnitAndDef()
	local target = ControllerCameraTestGetReticleTargetInfo()
	if target.targetType ~= "unit" or not target.targetID or not ControllerCameraTestIsAlliedUnit(target.targetID) then
		return nil, nil, nil
	end
	local unitDefID, unitDef = ControllerCameraTestGetUnitDef(target.targetID)
	return target.targetID, unitDefID, unitDef
end

function ControllerCameraTestUnitIsOnScreen(unitID)
	if type(Spring.WorldToScreenCoords) ~= "function" then
		return true
	end
	if (viewSizeX or 0) <= 0 or (viewSizeY or 0) <= 0 then
		return true
	end
	local x, y, z
	if type(Spring.GetUnitViewPosition) == "function" then
		local ok
		ok, x, y, z = pcall(Spring.GetUnitViewPosition, unitID)
		if not ok then
			x, y, z = nil, nil, nil
		end
	end
	if not x and type(spGetUnitPosition) == "function" then
		local ok
		ok, x, y, z = pcall(spGetUnitPosition, unitID)
		if not ok then
			x, y, z = nil, nil, nil
		end
	end
	if not x or not z then
		return false
	end
	local ok, sx, sy = pcall(Spring.WorldToScreenCoords, x, y or 0, z)
	if not ok or type(sx) ~= "number" or type(sy) ~= "number" then
		return true
	end
	local margin = 24
	return sx >= -margin and sx <= (viewSizeX + margin) and sy >= -margin and sy <= (viewSizeY + margin)
end

function ControllerCameraTestCollectSameTypeCandidates(unitDefID, includeOffscreen)
	local candidates = {}
	local seen = {}
	local source = includeOffscreen and "owned" or "visible+owned-screen"
	local function addCandidate(unitID)
		if unitID and not seen[unitID] then
			seen[unitID] = true
			candidates[#candidates + 1] = unitID
		end
	end

	if includeOffscreen then
		for _, unitID in ipairs(ControllerCameraTestGetOwnTeamUnits()) do
			addCandidate(unitID)
		end
	else
		if type(Spring.GetVisibleUnits) == "function" then
			local ok, visibleUnits = pcall(Spring.GetVisibleUnits)
			if ok and type(visibleUnits) == "table" then
				for _, unitID in ipairs(visibleUnits) do
					addCandidate(unitID)
				end
			else
				source = "owned-screen"
			end
		else
			source = "owned-screen"
		end
		for _, unitID in ipairs(ControllerCameraTestGetOwnTeamUnits()) do
			addCandidate(unitID)
		end
	end

	local units = {}
	for _, unitID in ipairs(candidates) do
		local ok, candidateDefID = pcall(Spring.GetUnitDefID, unitID)
		if ok and candidateDefID == unitDefID and (includeOffscreen or ControllerCameraTestUnitIsOnScreen(unitID)) then
			if includeOffscreen then
				if ControllerCameraTestIsOwnUnit(unitID) then
					units[#units + 1] = unitID
				end
			elseif ControllerCameraTestIsAlliedUnit(unitID) then
				units[#units + 1] = unitID
			end
		end
	end
	table.sort(units)
	return ControllerCameraTestFilterValidUnits(units), source
end

function ControllerCameraTestUpdateSameTypeDebug(unitDefID, source, candidates, selected, action)
	ControllerCameraTestAreaSelect.sameTypeUnitDefID = tostring(unitDefID or "none")
	ControllerCameraTestAreaSelect.sameTypeTarget = ControllerCameraTestUnitTypeName(unitDefID)
	ControllerCameraTestAreaSelect.sameTypeSource = tostring(source or "none")
	ControllerCameraTestAreaSelect.sameTypeCandidateCount = candidates or 0
	ControllerCameraTestAreaSelect.sameTypeSelectedCount = selected or 0
	ControllerCameraTestAreaSelect.doubleTapAction = tostring(action or "none")
end

function ControllerCameraTestSelectSameTypeFromReticle(includeOffscreen)
	local targetID, unitDefID, unitDef = ControllerCameraTestGetReticleAlliedUnitAndDef()
	if not targetID or not unitDefID then
		ControllerCameraTestUpdateSameTypeDebug(nil, "none", 0, 0, "no reticle unit")
		return false
	end
	if unitDef and unitDef.isBuilding and not includeOffscreen then
		ControllerCameraTestUpdateSameTypeDebug(unitDefID, "reticle building", 0, 0, "building requires LT")
		latchSelectionDebugMessage("Double-tap same-type: hold LT for buildings")
		return false
	end

	local units, source = ControllerCameraTestCollectSameTypeCandidates(unitDefID, includeOffscreen)
	local label = includeOffscreen and "LT+A double-tap all type" or "A double-tap visible type"

	if ControllerCameraTestSelectUnits(units, label) then
		ControllerCameraTestAreaSelect.lastCount = #units
		ControllerCameraTestAreaSelect.lastResult = (includeOffscreen and "same owned type " or "same visible type ") .. tostring(#units)
		ControllerCameraTestUpdateSameTypeDebug(unitDefID, source, #units, #units, includeOffscreen and "same owned type selected" or "same visible type selected")
		if includeOffscreen then
			ControllerCameraTestFocusUnitsCenter(units, "Same type")
		end
		return true
	end
	ControllerCameraTestUpdateSameTypeDebug(unitDefID, source, #units, 0, includeOffscreen and "same owned type none" or "same visible type none")
	return false
end

function ControllerCameraTestSelectVisibleSameTypeUnderReticle()
	return ControllerCameraTestSelectSameTypeFromReticle(false)
end

function ControllerCameraTestSelectAllOwnedSameTypeUnderReticle()
	return ControllerCameraTestSelectSameTypeFromReticle(true)
end

function ControllerCameraTestFocusCameraAt(x, y, z, label)
	if not x or not z then
		return false
	end
	local focusY = y
	if not focusY and type(spGetGroundHeight) == "function" then
		focusY = spGetGroundHeight(x, z)
	end
	focusY = focusY or 0
	if type(Spring.SetCameraTarget) == "function" then
		local ok = pcall(Spring.SetCameraTarget, x, focusY, z, 0.35)
		if ok then
			ControllerCameraTestSetCommandMarker(x, focusY, z, label or "Focus", "generic")
			return true
		end
	end
	if type(spGetCameraState) == "function" and type(spSetCameraState) == "function" then
		local cameraState = spGetCameraState()
		if type(cameraState) == "table" then
			cameraState.px = x
			cameraState.pz = z
			if cameraState.py == nil then
				cameraState.py = focusY + 600
			end
			local ok = pcall(spSetCameraState, cameraState, 0.25)
			if ok then
				ControllerCameraTestSetCommandMarker(x, focusY, z, label or "Focus", "generic")
				return true
			end
		end
	end
	return false
end

function ControllerCameraTestFocusAndSelectUnit(unitID, label)
	if not unitID then
		return false
	end
	local selected = ControllerCameraTestSelectUnits({ unitID }, label or "Select unit")
	if type(spGetUnitPosition) == "function" then
		local ok, x, y, z = pcall(spGetUnitPosition, unitID)
		if ok and x and z then
			ControllerCameraTestFocusCameraAt(x, y, z, label or "Focus unit")
		end
	end
	return selected
end

function ControllerCameraTestFocusUnitsCenter(units, label)
	if type(units) ~= "table" or #units == 0 or type(spGetUnitPosition) ~= "function" then
		return false
	end
	local sx, sy, sz, count = 0, 0, 0, 0
	for _, unitID in ipairs(units) do
		local ok, x, y, z = pcall(spGetUnitPosition, unitID)
		if ok and x and z then
			sx, sy, sz = sx + x, sy + (y or 0), sz + z
			count = count + 1
		end
	end
	if count <= 0 then
		return false
	end
	return ControllerCameraTestFocusCameraAt(sx / count, sy / count, sz / count, label or "Focus group")
end

function ControllerCameraTestGetOwnTeamUnits()
	local teamID = type(Spring.GetMyTeamID) == "function" and Spring.GetMyTeamID()
		or (type(Spring.GetLocalTeamID) == "function" and Spring.GetLocalTeamID() or nil)
	if teamID and type(Spring.GetTeamUnits) == "function" then
		local ok, units = pcall(Spring.GetTeamUnits, teamID)
		if ok and type(units) == "table" then
			table.sort(units)
			return units
		end
	end
	return ControllerCameraTestGetVisibleAlliedUnits()
end

function ControllerCameraTestIsCommanderUnit(unitID)
	local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
	if type(unitDef) ~= "table" then
		return false
	end
	local cp = unitDef.customParams or {}
	if cp.iscommander or cp.commtype or cp.level == "commander" then
		return true
	end
	local name = string.lower(tostring(unitDef.name or "") .. " " .. tostring(unitDef.humanName or "") .. " " .. tostring(unitDef.translatedHumanName or ""))
	return string.find(name, "commander", 1, true) ~= nil
end

function ControllerCameraTestFocusCommander()
	for _, unitID in ipairs(ControllerCameraTestGetOwnTeamUnits()) do
		if ControllerCameraTestIsCommanderUnit(unitID) then
			if type(spGetUnitPosition) ~= "function" then
				ControllerCameraTestIdleCycle.lastResult = "commander focus failed: position API unavailable"
				latchSelectionDebugMessage(ControllerCameraTestIdleCycle.lastResult)
				return false
			end
			local ok, x, y, z = pcall(spGetUnitPosition, unitID)
			if ok and x and z and ControllerCameraTestFocusCameraAt(x, y, z, "Commander") then
				ControllerCameraTestSelectUnits({ unitID }, "Commander")
				ControllerCameraTestIdleCycle.currentUnitID = unitID
				ControllerCameraTestIdleCycle.lastResult = "focused and selected Commander " .. tostring(unitID)
				ControllerCameraTestLayerDebug.normalUtilityAction = "Double-tap A Commander focus/select"
				latchSelectionDebugMessage("Focused and selected Commander")
				return true
			end
		end
	end
	ControllerCameraTestIdleCycle.lastResult = "Commander focus failed: no commander found"
	ControllerCameraTestLayerDebug.normalUtilityAction = ControllerCameraTestIdleCycle.lastResult
	latchSelectionDebugMessage(ControllerCameraTestIdleCycle.lastResult)
	return false
end

function ControllerCameraTestUnitIsIdle(unitID)
	if type(Spring.GetUnitCommandCount) == "function" then
		local ok, count = pcall(Spring.GetUnitCommandCount, unitID)
		if ok and type(count) == "number" then
			return count == 0
		end
	end
	if type(Spring.GetUnitCommands) == "function" then
		local ok, queue = pcall(Spring.GetUnitCommands, unitID, 1)
		if ok and type(queue) == "table" then
			return #queue == 0
		end
	end
	return false
end

function ControllerCameraTestUnitIsFinished(unitID)
	if type(Spring.GetUnitHealth) ~= "function" then
		return true
	end
	local ok, health, maxHealth, paralyzeDamage, captureProgress, buildProgress = pcall(Spring.GetUnitHealth, unitID)
	if not ok then
		return true
	end
	return not (type(buildProgress) == "number" and buildProgress < 1)
end

function ControllerCameraTestIsIdleCycleCandidate(unitID)
	local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
	if type(unitDef) ~= "table" then
		return false, false
	end
	if unitDef.isBuilding or unitDef.isFactory then
		return false, false
	end
	if not ControllerCameraTestIsMobileUnitDef(unitDef) then
		return false, false
	end
	if not ControllerCameraTestUnitIsFinished(unitID) then
		return false, false
	end
	if not ControllerCameraTestUnitIsIdle(unitID) then
		return false, false
	end
	local isBuilder = unitDef.isBuilder or unitDef.canBuild or (type(unitDef.buildOptions) == "table" and #unitDef.buildOptions > 0)
	return true, isBuilder
end

function ControllerCameraTestGetIdleCycleUnits()
	local builders, fallback = {}, {}
	for _, unitID in ipairs(ControllerCameraTestGetOwnTeamUnits()) do
		local ok, isBuilder = ControllerCameraTestIsIdleCycleCandidate(unitID)
		if ok then
			if isBuilder then
				builders[#builders + 1] = unitID
			else
				fallback[#fallback + 1] = unitID
			end
		end
	end
	local units = (#builders > 0) and builders or fallback
	table.sort(units)
	ControllerCameraTestIdleCycle.lastCount = #units
	return units
end

function ControllerCameraTestUnitTypeName(unitDefID)
	local unitDef = unitDefID and UnitDefs and UnitDefs[unitDefID]
	if not unitDef then
		return tostring(unitDefID or "unknown")
	end
	return unitDef.translatedHumanName or unitDef.humanName or unitDef.name or tostring(unitDefID)
end

--------------------------------------------------------------------------------
-- SECTION: Idle cycling
--------------------------------------------------------------------------------
function ControllerCameraTestCycleIdleUnit(delta)
	local units = ControllerCameraTestGetIdleCycleUnits()
	if #units == 0 then
		ControllerCameraTestIdleCycle.lastResult = "no idle units"
		ControllerCameraTestIdleCycle.currentUnitID = nil
		latchSelectionDebugMessage("Idle cycle: no idle units")
		return false
	end

	local currentIndex = 0
	for i, unitID in ipairs(units) do
		if unitID == ControllerCameraTestIdleCycle.currentUnitID then
			currentIndex = i
			break
		end
	end
	local nextIndex = ((currentIndex - 1 + delta) % #units) + 1
	local unitID = units[nextIndex]
	local unitDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(unitID) or nil
	ControllerCameraTestIdleCycle.currentIndex = nextIndex
	ControllerCameraTestIdleCycle.currentUnitID = unitID
	ControllerCameraTestIdleCycle.currentTypeKey = unitDefID
	ControllerCameraTestIdleCycle.lastTypeName = ControllerCameraTestUnitTypeName(unitDefID)
	if ControllerCameraTestFocusAndSelectUnit(unitID, "Idle unit") then
		ControllerCameraTestIdleCycle.lastResult = "idle unit " .. tostring(nextIndex) .. "/" .. tostring(#units)
		ControllerCameraTestLayerDebug.normalUtilityAction = "Idle cycle " .. ControllerCameraTestIdleCycle.lastResult
		return true
	end
	return false
end

function ControllerCameraTestGetIdleUnitTypeBuckets()
	local bucketsByDef = {}
	local buckets = {}
	for _, unitID in ipairs(ControllerCameraTestGetIdleCycleUnits()) do
		local unitDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(unitID) or nil
		if unitDefID then
			local bucket = bucketsByDef[unitDefID]
			if not bucket then
				bucket = { unitDefID = unitDefID, name = ControllerCameraTestUnitTypeName(unitDefID), units = {} }
				bucketsByDef[unitDefID] = bucket
				buckets[#buckets + 1] = bucket
			end
			bucket.units[#bucket.units + 1] = unitID
		end
	end
	table.sort(buckets, function(a, b)
		if a.name == b.name then
			return a.unitDefID < b.unitDefID
		end
		return a.name < b.name
	end)
	return buckets
end

function ControllerCameraTestSelectRepresentativeFromIdleTypeBucket(bucket)
	if type(bucket) ~= "table" or type(bucket.units) ~= "table" or #bucket.units == 0 then
		return false
	end
	local unitID = bucket.units[1]
	ControllerCameraTestIdleCycle.currentUnitID = unitID
	ControllerCameraTestIdleCycle.currentTypeKey = bucket.unitDefID
	ControllerCameraTestIdleCycle.lastTypeName = bucket.name
	ControllerCameraTestIdleCycle.lastCount = #bucket.units
	return ControllerCameraTestFocusAndSelectUnit(unitID, "Idle type " .. tostring(bucket.name))
end

function ControllerCameraTestCycleIdleUnitType(delta)
	local buckets = ControllerCameraTestGetIdleUnitTypeBuckets()
	if #buckets == 0 then
		ControllerCameraTestIdleCycle.lastResult = "no idle type buckets"
		latchSelectionDebugMessage("Idle type cycle: no idle units")
		return false
	end
	local currentIndex = 0
	for i, bucket in ipairs(buckets) do
		if bucket.unitDefID == ControllerCameraTestIdleCycle.currentTypeKey then
			currentIndex = i
			break
		end
	end
	local nextIndex = ((currentIndex - 1 + delta) % #buckets) + 1
	local bucket = buckets[nextIndex]
	ControllerCameraTestIdleCycle.currentTypeIndex = nextIndex
	if ControllerCameraTestSelectRepresentativeFromIdleTypeBucket(bucket) then
		ControllerCameraTestIdleCycle.lastResult = "idle type " .. tostring(nextIndex) .. "/" .. tostring(#buckets)
		ControllerCameraTestLayerDebug.normalUtilityAction = "Idle type " .. tostring(bucket.name) .. " x" .. tostring(#bucket.units)
		return true
	end
	return false
end

function ControllerCameraTestSelectAllIdleUnitsInCurrentTypeBucket()
	local buckets = ControllerCameraTestGetIdleUnitTypeBuckets()
	if #buckets == 0 then
		ControllerCameraTestIdleCycle.selectedAllCount = 0
		ControllerCameraTestIdleCycle.lastResult = "no idle units for type-select"
		latchSelectionDebugMessage("LT+A double-tap: no idle units")
		return false
	end
	local bucket = buckets[1]
	for _, candidate in ipairs(buckets) do
		if candidate.unitDefID == ControllerCameraTestIdleCycle.currentTypeKey then
			bucket = candidate
			break
		end
	end
	if ControllerCameraTestSelectUnits(bucket.units, "Idle type group") then
		ControllerCameraTestIdleCycle.currentTypeKey = bucket.unitDefID
		ControllerCameraTestIdleCycle.lastTypeName = bucket.name
		ControllerCameraTestIdleCycle.selectedAllCount = #bucket.units
		ControllerCameraTestIdleCycle.lastResult = "selected idle type x" .. tostring(#bucket.units)
		ControllerCameraTestFocusUnitsCenter(bucket.units, "Idle type group")
		return true
	end
	return false
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

--------------------------------------------------------------------------------
-- SECTION: Control groups
--------------------------------------------------------------------------------
function ControllerCameraTestNormalizeControlGroupSlot(slot)
	slot = tonumber(slot) or 1
	slot = ((slot - 1) % 10) + 1
	return slot
end

function ControllerCameraTestGetControlGroupDisplaySlot(slot)
	slot = ControllerCameraTestNormalizeControlGroupSlot(slot)
	return slot == 10 and "0" or tostring(slot)
end

function ControllerCameraTestShowControlGroupOverlay(seconds)
	ControllerCameraTestControlGroups.visibleUntil = debugEventTime + (seconds or 1.5)
end

function ControllerCameraTestPruneDeadUnitsFromControlGroup(slot)
	slot = ControllerCameraTestNormalizeControlGroupSlot(slot)
	local groups = ControllerCameraTestControlGroups
	local entry = groups.slots[slot]
	if type(entry) ~= "table" then
		return {}
	end
	local units = ControllerCameraTestFilterValidUnits(entry.units)
	entry.units = units
	entry.count = #units
	if #units == 0 and not entry.autoAddUnitDefID and not entry.autoAddUnitDefIDs then
		groups.slots[slot] = nil
	end
	return units
end

function ControllerCameraTestSetControlGroupAction(action, slot, count)
	local groups = ControllerCameraTestControlGroups
	groups.lastAction = action
	groups.lastSlot = ControllerCameraTestGetControlGroupDisplaySlot(slot)
	groups.lastCount = count or 0
	ControllerCameraTestShowControlGroupOverlay(1.5)
	ControllerCameraTestLayerDebug.normalUtilityAction = "Group " .. tostring(groups.lastSlot) .. ": " .. tostring(action)
	latchSelectionDebugMessage("Group " .. tostring(groups.lastSlot) .. ": " .. tostring(action))
end

function ControllerCameraTestGetControlGroupSourceUnitDefIDs()
	local unitDefIDs = {}
	local seen = {}
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	for _, unitID in ipairs(selectedUnits) do
		if ControllerCameraTestIsOwnUnit(unitID) then
			local selectedDefID = ControllerCameraTestGetUnitDef(unitID)
			if selectedDefID and not seen[selectedDefID] then
				seen[selectedDefID] = true
				unitDefIDs[#unitDefIDs + 1] = selectedDefID
			end
		end
	end
	if #unitDefIDs > 0 then
		return unitDefIDs, "selection"
	end

	local targetID, unitDefID = ControllerCameraTestGetReticleAlliedUnitAndDef()
	if unitDefID and ControllerCameraTestIsOwnUnit(targetID) then
		return { unitDefID }, "reticle"
	end

	if ControllerCameraTestIdleCycle.currentUnitID then
		local idleDefID = ControllerCameraTestGetUnitDef(ControllerCameraTestIdleCycle.currentUnitID)
		if idleDefID then
			return { idleDefID }, "idle"
		end
	end
	return {}, "none"
end

function ControllerCameraTestControlGroupAutoAddLabel(entry)
	if type(entry) ~= "table" then
		return "none"
	end

	local labels = {}
	local seen = {}
	if entry.autoAddUnitDefID then
		seen[entry.autoAddUnitDefID] = true
		labels[#labels + 1] = ControllerCameraTestUnitTypeName(entry.autoAddUnitDefID)
	end
	if type(entry.autoAddUnitDefIDs) == "table" then
		for unitDefID in pairs(entry.autoAddUnitDefIDs) do
			if not seen[unitDefID] then
				seen[unitDefID] = true
				labels[#labels + 1] = ControllerCameraTestUnitTypeName(unitDefID)
			end
		end
	end
	if #labels == 0 then
		return "none"
	end
	table.sort(labels)
	return table.concat(labels, ", ")
end

function ControllerCameraTestAssignControlGroup(slot)
	slot = ControllerCameraTestNormalizeControlGroupSlot(slot)
	local groups = ControllerCameraTestControlGroups
	local unitDefIDs, source = ControllerCameraTestGetControlGroupSourceUnitDefIDs()
	if #unitDefIDs == 0 then
		ControllerCameraTestSetControlGroupAction("assign failed: no source unit", slot, 0)
		return false
	end

	local units = {}
	local addedUnits = {}
	local autoAddUnitDefIDs = {}
	local typeNames = {}
	for _, unitDefID in ipairs(unitDefIDs) do
		autoAddUnitDefIDs[unitDefID] = true
		typeNames[#typeNames + 1] = ControllerCameraTestUnitTypeName(unitDefID)
		for _, unitID in ipairs(ControllerCameraTestGetAllOwnedUnitsOfType(unitDefID)) do
			if not addedUnits[unitID] then
				addedUnits[unitID] = true
				units[#units + 1] = unitID
			end
		end
	end

	if #units == 0 then
		ControllerCameraTestSetControlGroupAction("assign failed: no owned type", slot, 0)
		return false
	end
	table.sort(units)
	table.sort(typeNames)
	local primaryUnitDefID = unitDefIDs[1]
	local typeName = table.concat(typeNames, ", ")
	groups.slots[slot] = {
		units = units,
		unitDefID = primaryUnitDefID,
		autoAddUnitDefID = primaryUnitDefID,
		autoAddUnitDefIDs = autoAddUnitDefIDs,
		typeName = typeName,
		count = #units,
		lastAssignedTime = debugEventTime,
	}
	groups.activeSlot = slot
	ControllerCameraTestSetControlGroupAction("assigned " .. typeName .. " x" .. tostring(#units) .. " AUTO via " .. tostring(source), slot, #units)
	if source == "selection" then
		ControllerCameraTestTryNativeAutogroup(slot)
	else
		groups.nativeAutogroupStatus = "BAR Auto Group mirror skipped: source " .. tostring(source)
	end
	return true
end

function ControllerCameraTestTryNativeAutogroup(slot)
	if not WG or type(WG.autogroup) ~= "table" or type(WG.autogroup.addCurrentSelectionToAutogroup) ~= "function" then
		return false
	end

	local groupNumber = tonumber(ControllerCameraTestGetControlGroupDisplaySlot(slot))
	if groupNumber == nil then
		return false
	end
	local ok, result = pcall(WG.autogroup.addCurrentSelectionToAutogroup, groupNumber)
	if ok and result ~= false then
		ControllerCameraTestControlGroups.nativeAutogroupStatus = "mirrored to BAR Auto Group " .. tostring(groupNumber)
	else
		ControllerCameraTestControlGroups.nativeAutogroupStatus = "BAR Auto Group mirror skipped/failed"
	end
	return ok and result ~= false
end

function ControllerCameraTestRecallControlGroup(slot)
	slot = ControllerCameraTestNormalizeControlGroupSlot(slot)
	local groups = ControllerCameraTestControlGroups
	local units = ControllerCameraTestPruneDeadUnitsFromControlGroup(slot)
	groups.activeSlot = slot
	if #units == 0 then
		ControllerCameraTestSetControlGroupAction("empty", slot, 0)
		return false
	end
	if ControllerCameraTestSelectUnits(units, "Control group " .. ControllerCameraTestGetControlGroupDisplaySlot(slot)) then
		ControllerCameraTestFocusUnitsCenter(units, "Control group")
		local entry = groups.slots[slot]
		local typeName = entry and entry.typeName or (entry and ControllerCameraTestUnitTypeName(entry.unitDefID) or "units")
		ControllerCameraTestSetControlGroupAction("recalled " .. tostring(typeName) .. " x" .. tostring(#units), slot, #units)
		return true
	end
	ControllerCameraTestSetControlGroupAction("recall failed", slot, #units)
	return false
end

function ControllerCameraTestClearControlGroup(slot)
	slot = ControllerCameraTestNormalizeControlGroupSlot(slot)
	ControllerCameraTestControlGroups.slots[slot] = nil
	ControllerCameraTestControlGroups.activeSlot = slot
	ControllerCameraTestSetControlGroupAction("cleared", slot, 0)
	return true
end

function ControllerCameraTestChangeControlGroupSlot(delta)
	local groups = ControllerCameraTestControlGroups
	groups.activeSlot = ControllerCameraTestNormalizeControlGroupSlot((groups.activeSlot or 1) + delta)
	ControllerCameraTestSetControlGroupAction("active slot", groups.activeSlot, groups.slots[groups.activeSlot] and (groups.slots[groups.activeSlot].count or 0) or 0)
end

function ControllerCameraTestStartControlGroupLeftPress()
	local groups = ControllerCameraTestControlGroups
	groups.leftPressActive = true
	groups.leftPressStartTime = debugEventTime
	groups.leftHoldTriggered = false
	groups.leftInputState = "left tap pending"
	ControllerCameraTestShowControlGroupOverlay(0.4)
end

function ControllerCameraTestResolveControlGroupLeftPress()
	local groups = ControllerCameraTestControlGroups
	if not groups.leftPressActive then
		return false
	end

	local holdSeconds = ControllerCameraTestSettings.controlGroupAssignHoldSeconds or 0.35
	local elapsed = debugEventTime - (groups.leftPressStartTime or debugEventTime)
	if not groups.leftHoldTriggered and elapsed >= holdSeconds then
		ControllerCameraTestAssignControlGroup(groups.activeSlot)
		groups.leftInputState = "assigned hold"
	elseif not groups.leftHoldTriggered then
		ControllerCameraTestRecallControlGroup(groups.activeSlot)
		groups.leftInputState = "recalled tap"
	else
		groups.leftInputState = "assigned hold"
	end

	groups.leftPressActive = false
	groups.leftPressStartTime = 0
	groups.leftHoldTriggered = false
	return true
end

function ControllerCameraTestUpdateControlGroupLeftHold()
	local groups = ControllerCameraTestControlGroups
	if not groups.leftPressActive then
		return false
	end

	if not ControllerCameraTestActionDown("controlGroupModifier") or not ControllerCameraTestActionDown("groupRecallOrAssign") then
		return ControllerCameraTestResolveControlGroupLeftPress()
	end

	local holdSeconds = ControllerCameraTestSettings.controlGroupAssignHoldSeconds or 0.35
	if not groups.leftHoldTriggered and (debugEventTime - (groups.leftPressStartTime or debugEventTime)) >= holdSeconds then
		ControllerCameraTestAssignControlGroup(groups.activeSlot)
		groups.leftHoldTriggered = true
		groups.leftInputState = "assigned hold"
	else
		groups.leftInputState = groups.leftHoldTriggered and "assigned hold" or "holding left"
	end
	return true
end

function ControllerCameraTestHandleControlGroupInput()
	local groups = ControllerCameraTestControlGroups
	if not (ControllerCameraTestActionDown("controlGroupModifier") or ControllerCameraTestActionPressed("controlGroupModifier") or groups.leftPressActive) then
		return false
	end

	groups.activeSlot = ControllerCameraTestNormalizeControlGroupSlot(groups.activeSlot or 1)
	ControllerCameraTestShowControlGroupOverlay(ControllerCameraTestActionDown("controlGroupModifier") and 0.2 or 1.5)

	if groups.leftPressActive then
		ControllerCameraTestUpdateControlGroupLeftHold()
		if groups.leftPressActive or not ControllerCameraTestActionDown("controlGroupModifier") then
			return true
		end
	end

	if ControllerCameraTestActionDown("controlGroupModifier") then
		if ControllerCameraTestActionPressed("groupSlotUp") then
			ControllerCameraTestChangeControlGroupSlot(1)
		elseif ControllerCameraTestActionPressed("groupSlotDown") then
			ControllerCameraTestChangeControlGroupSlot(-1)
		elseif ControllerCameraTestActionPressed("groupRecallOrAssign") then
			ControllerCameraTestRecallControlGroup(groups.activeSlot)
			groups.leftInputState = "recalled"
		elseif ControllerCameraTestActionPressed("groupAssign") then
			ControllerCameraTestAssignControlGroup(groups.activeSlot)
			groups.leftInputState = "assigned same-type"
		elseif ControllerCameraTestActionPressed("groupClear") then
			ControllerCameraTestClearControlGroup(groups.activeSlot)
		else
			ControllerCameraTestLayerDebug.normalUtilityAction = "Control group mode"
		end
	end
	return true
end

function ControllerCameraTestAutoAddFinishedUnitToGroups(unitID, unitDefID, unitTeam)
	if not unitID or not unitDefID then
		return
	end
	local myTeam = type(Spring.GetMyTeamID) == "function" and Spring.GetMyTeamID()
		or (type(Spring.GetLocalTeamID) == "function" and Spring.GetLocalTeamID() or nil)
	if not unitTeam and type(Spring.GetUnitTeam) == "function" then
		local teamOk, detectedTeam = pcall(Spring.GetUnitTeam, unitID)
		if teamOk then
			unitTeam = detectedTeam
		end
	end
	if myTeam and unitTeam ~= myTeam then
		return
	end
	local groups = ControllerCameraTestControlGroups
	for slot, entry in pairs(groups.slots) do
		local shouldAutoAdd = type(entry) == "table"
			and (entry.autoAddUnitDefID == unitDefID
				or (type(entry.autoAddUnitDefIDs) == "table" and entry.autoAddUnitDefIDs[unitDefID]))
		if shouldAutoAdd then
			local exists = false
			for _, existingID in ipairs(entry.units or {}) do
				if existingID == unitID then
					exists = true
					break
				end
			end
			if not exists then
				entry.units = entry.units or {}
				entry.units[#entry.units + 1] = unitID
				table.sort(entry.units)
				entry.count = #entry.units
				entry.unitDefID = entry.unitDefID or unitDefID
				entry.typeName = entry.typeName or ControllerCameraTestControlGroupAutoAddLabel(entry)
				groups.lastAction = "auto-added " .. tostring(entry.typeName)
				groups.lastSlot = ControllerCameraTestGetControlGroupDisplaySlot(slot)
				groups.lastCount = entry.count
			end
		end
	end
end

function ControllerCameraTestRemoveUnitFromControlGroups(unitID)
	if not unitID then
		return
	end
	for slot, entry in pairs(ControllerCameraTestControlGroups.slots) do
		if type(entry) == "table" and type(entry.units) == "table" then
			local filtered = {}
			for _, existingID in ipairs(entry.units) do
				if existingID ~= unitID then
					filtered[#filtered + 1] = existingID
				end
			end
			entry.units = filtered
			entry.count = #filtered
			if #filtered == 0 and not entry.autoAddUnitDefID and not entry.autoAddUnitDefIDs then
				ControllerCameraTestControlGroups.slots[slot] = nil
			end
		end
	end
end

function ControllerCameraTestTacticalCommandAvailable(cmdID)
	if type(cmdID) ~= "number" then
		return true
	end
	if cmdID == CMD.STOP or cmdID == CMD.WAIT or cmdID == CMD.REPEAT then
		return true
	end
	if type(Spring.GetActiveCmdDescs) ~= "function" then
		return true
	end
	local ok, descs = pcall(Spring.GetActiveCmdDescs)
	if not ok or type(descs) ~= "table" then
		return true
	end
	for _, desc in ipairs(descs) do
		if desc and desc.id == cmdID then
			return true
		end
	end
	return false
end

function ControllerCameraTestAppendTacticalCommand(commands, option)
	if type(option) ~= "table" then
		return
	end
	if option.cmdID ~= nil and not ControllerCameraTestTacticalCommandAvailable(option.cmdID) then
		return
	end
	commands[#commands + 1] = option
end

--------------------------------------------------------------------------------
-- SECTION: Tactical radial
--------------------------------------------------------------------------------
function ControllerCameraTestGetTacticalCommands()
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local isFactory = ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits)

	if isFactory then
		return {
			{ name = "Clear Queue", kind = "factory_clear" },
			{ name = "Repeat Toggle", kind = "factory_repeat" },
			{ name = "Stop", cmdID = CMD.STOP, kind = "none" },
		}
	end

	local commands = {}
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Stop", cmdID = CMD.STOP, kind = "none" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Wait", cmdID = CMD.WAIT, kind = "none" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Repeat", cmdID = CMD.REPEAT, kind = "repeat_toggle" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Move Line", cmdID = CMD.MOVE, kind = "drag_line", dragMode = "moveLine" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Fight Line", cmdID = CMD.FIGHT, kind = "drag_line", dragMode = "fightLine" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Attack Line", cmdID = CMD.ATTACK, kind = "drag_line", dragMode = "attackLine" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Reclaim Area", cmdID = CMD.RECLAIM, kind = "drag_area", dragMode = "reclaimArea" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Repair Area", cmdID = CMD.REPAIR, kind = "drag_area", dragMode = "repairArea" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Attack Area", cmdID = CMD.ATTACK, kind = "drag_area", dragMode = "attackArea" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Patrol", cmdID = CMD.PATROL, kind = "ground" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Guard", cmdID = CMD.GUARD, kind = "alliedUnit" })
	ControllerCameraTestAppendTacticalCommand(commands, { name = "Fire State", cmdID = CMD.FIRESTATE or 20, kind = "fire_state_cycle" })
	return commands
end

function ControllerCameraTestRefreshTacticalDebug()
	local menu = ControllerCameraTestTacticalMenu
	local commands = ControllerCameraTestGetTacticalCommands()
	if #commands <= 0 then
		menu.selectedIndex = 1
		menu.highlightedName = "none"
		return
	end
	if menu.selectedIndex < 1 or menu.selectedIndex > #commands then
		menu.selectedIndex = 1
	end
	local option = commands[menu.selectedIndex]
	menu.highlightedName = option and option.name or "none"
end

function ControllerCameraTestSetTacticalHighlight(index, reason)
	local menu = ControllerCameraTestTacticalMenu
	local commands = ControllerCameraTestGetTacticalCommands()
	if #commands <= 0 then
		menu.selectedIndex = 1
		menu.highlightedName = "none"
		menu.lastAction = "no tactical commands"
		return
	end
	menu.selectedIndex = ((index - 1) % #commands) + 1
	menu.lastAction = reason or "highlight changed"
	ControllerCameraTestRefreshTacticalDebug()
end

function ControllerCameraTestToggleTacticalMenu()
	local menu = ControllerCameraTestTacticalMenu
	menu.open = not menu.open
	if menu.open then
		ControllerCameraTestMemoryDebug.tacticalOpenCount = (ControllerCameraTestMemoryDebug.tacticalOpenCount or 0) + 1
	end
	menu.lastAction = menu.open and "opened" or "closed"
	ControllerCameraTestRefreshTacticalDebug()
	latchSelectionDebugMessage(menu.open and "Command layer tactical menu opened" or "Tactical menu closed")
end

function ControllerCameraTestTacticalTogglePressed()
	return ControllerCameraTestBindingPressed("RB") or ControllerCameraTestActionPressed("buildRadial")
end

function ControllerCameraTestCycleTacticalCommand(delta)
	local menu = ControllerCameraTestTacticalMenu
	local commands = ControllerCameraTestGetTacticalCommands()
	if #commands <= 0 then
		menu.lastAction = "no tactical commands"
		menu.highlightedName = "none"
		return
	end
	ControllerCameraTestSetTacticalHighlight(menu.selectedIndex + delta, "highlight changed")
	latchSelectionDebugMessage("Tactical: " .. tostring(menu.highlightedName))
end

function ControllerCameraTestUpdateTacticalStickSelection()
	local menu = ControllerCameraTestTacticalMenu
	if not menu.open then
		return
	end

	local commands = ControllerCameraTestGetTacticalCommands()
	local count = #commands
	if count <= 0 then
		ControllerCameraTestRefreshTacticalDebug()
		return
	end

	local aimX = normalizedLeftX
	local aimY = -normalizedLeftY
	local magnitude = math.sqrt(aimX * aimX + aimY * aimY)
	if magnitude <= 0.5 then
		return
	end

	local angle = math.atan2(aimX, aimY)
	if angle < 0 then
		angle = angle + 2 * math.pi
	end
	menu.radialLastAngle = angle

	local segment = 2 * math.pi / count
	local adjustedAngle = angle + (segment / 2)
	if adjustedAngle >= 2 * math.pi then
		adjustedAngle = adjustedAngle - 2 * math.pi
	end

	local newIndex = math.floor(adjustedAngle / segment) + 1
	if newIndex ~= menu.selectedIndex then
		ControllerCameraTestSetTacticalHighlight(newIndex, "stick select")
	end
end

function ControllerCameraTestTacticalCommandNeedsTarget(option)
	if type(option) ~= "table" then
		return false
	end
	return option.kind == "drag_line"
		or option.kind == "drag_area"
		or option.kind == "ground"
		or option.kind == "attack"
		or option.kind == "alliedUnit"
		or option.kind == "reclaim"
		or option.kind == "repair"
end

function ControllerCameraTestStageTacticalCommand(option)
	local menu = ControllerCameraTestTacticalMenu
	if type(option) ~= "table" then
		menu.lastResult = "stage failed: no option"
		return false
	end
	menu.stagedOption = {
		name = option.name,
		cmdID = option.cmdID,
		kind = option.kind,
		dragMode = option.dragMode,
	}
	menu.stagedName = tostring(option.name or "Command")
	menu.stagedKind = tostring(option.kind or "none")
	menu.stagedState = "staged"
	menu.repeatPlacementActive = false
	menu.repeatPlacementState = "none"
	menu.open = false
	menu.lastAction = "staged " .. menu.stagedName
	menu.lastResult = "staged: move reticle, A confirm, B cancel"
	ControllerCameraTestLayerDebug.commandLayerAction = menu.lastAction
	latchSelectionDebugMessage(menu.stagedName .. " staged")
	return true
end

function ControllerCameraTestClearStagedTacticalCommand(reason)
	local menu = ControllerCameraTestTacticalMenu
	local name = tostring(menu.stagedName or "Command")
	menu.stagedOption = nil
	menu.stagedName = "none"
	menu.stagedKind = "none"
	menu.stagedState = reason or "none"
	menu.repeatPlacementActive = false
	menu.repeatPlacementState = reason or "none"
	if reason then
		menu.lastAction = tostring(reason)
		menu.lastResult = tostring(reason)
		latchSelectionDebugMessage(name .. " " .. tostring(reason))
	end
end

function ControllerCameraTestConfirmStagedTacticalCommand()
	local menu = ControllerCameraTestTacticalMenu
	local option = menu.stagedOption
	if type(option) ~= "table" then
		return false
	end
	local name = tostring(menu.stagedName or option.name or "Command")
	local repeatHeld = ControllerCameraTestIsQueueModifierActive()
	local repeatOption = {
		name = option.name,
		cmdID = option.cmdID,
		kind = option.kind,
		dragMode = option.dragMode,
	}
	menu.stagedOption = nil
	menu.stagedName = name
	menu.stagedKind = tostring(option.kind or "none")
	menu.stagedState = "confirming"
	menu.repeatPlacementActive = false
	menu.repeatPlacementState = repeatHeld and "RT held" or "none"
	menu.lastAction = "confirming " .. name
	local confirmed = ControllerCameraTestExecuteTacticalCommand(option, false)
	if confirmed and repeatHeld then
		menu.stagedOption = repeatOption
		menu.stagedState = "repeat active"
		menu.repeatPlacementActive = true
		menu.repeatPlacementState = "RT held"
		menu.lastAction = "repeat staged " .. name
		menu.lastResult = "placed; repeat active while RT held"
		ControllerCameraTestLayerDebug.commandLayerAction = "Tactical repeat active: " .. name
		latchSelectionDebugMessage(name .. " repeat active")
	else
		menu.stagedState = confirmed and "confirmed" or "confirm failed"
		menu.repeatPlacementActive = false
		menu.repeatPlacementState = confirmed and "none" or "confirm failed"
	end
	menu.stagedName = name
	return confirmed
end

function ControllerCameraTestUpdateTacticalRepeatPlacement()
	local menu = ControllerCameraTestTacticalMenu
	if not menu.repeatPlacementActive then
		return false
	end
	if ControllerCameraTestIsQueueModifierActive() then
		return false
	end
	ControllerCameraTestClearStagedTacticalCommand("repeat cleared: RT released")
	menu.repeatPlacementState = "RT released"
	ControllerCameraTestLayerDebug.commandLayerAction = "Tactical repeat cleared: RT released"
	return true
end

function ControllerCameraTestHandleStagedTacticalCommandInput()
	local menu = ControllerCameraTestTacticalMenu
	if ControllerCameraTestUpdateTacticalRepeatPlacement() then
		return true
	end
	if type(menu.stagedOption) ~= "table" then
		return false
	end
	if ControllerCameraTestActionPressed("tacticalCancel") or ControllerCameraTestActionPressed("cancel") then
		ControllerCameraTestClearStagedTacticalCommand("cancelled")
		ControllerCameraTestLayerDebug.commandLayerAction = "Tactical staged command cancelled"
		return true
	end
	if ControllerCameraTestActionPressed("tacticalSelect") or ControllerCameraTestActionPressed("select") then
		ControllerCameraTestConfirmStagedTacticalCommand()
		return true
	end
	ControllerCameraTestLayerDebug.commandLayerAction = menu.repeatPlacementActive
		and ("Tactical repeat: " .. tostring(menu.stagedName))
		or ("Tactical staged: " .. tostring(menu.stagedName))
	return true
end

function ControllerCameraTestExecuteTacticalCommand(option, stageTargeted)
	if type(option) ~= "table" then
		ControllerCameraTestTacticalMenu.lastResult = "no tactical option"
		return false
	end
	if stageTargeted and ControllerCameraTestTacticalCommandNeedsTarget(option) then
		return ControllerCameraTestStageTacticalCommand(option)
	end

	if option.kind == "drag_line" or option.kind == "drag_area" then
		local drag = ControllerCameraTestDragCommand
		drag.active = true
		drag.mode = option.dragMode
		drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
		drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
		drag.pressActive = false
		drag.pressButton = nil
		ControllerCameraTestTacticalMenu.lastResult = "confirming staged drag: " .. tostring(option.name)
		pcall(ControllerCameraTestUpdateDragPreview)
		ControllerCameraTestConfirmDragCommand(false)
		ControllerCameraTestTacticalMenu.lastResult = drag.lastResult or ControllerCameraTestTacticalMenu.lastResult
		latchSelectionDebugMessage(option.name .. " confirmed")
		ControllerCameraTestTacticalMenu.open = false
		drag.previewPoints = {}
		drag.startX, drag.startY, drag.startZ = nil, nil, nil
		drag.endX, drag.endY, drag.endZ = nil, nil, nil
		return not tostring(ControllerCameraTestTacticalMenu.lastResult or ""):find("failed", 1, true)
	elseif option.kind == "repeat_toggle" then
		local ok = false
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if #selectedUnits > 0 then
			local firstUnit = selectedUnits[1]
			local states = type(Spring.GetUnitStates) == "function" and Spring.GetUnitStates(firstUnit)
			local currentRepeat = states and states["repeat"]
			local nextVal = currentRepeat and 0 or 1
			local count
			ok, count = ControllerCameraTestIssueOrderToSelectedUnits(CMD.REPEAT, { nextVal }, "Repeat", nextVal == 1 and "ON" or "OFF", {})
			ControllerCameraTestTacticalMenu.lastResult = ok and ("toggled for " .. tostring(count)) or "failed"
		end
		ControllerCameraTestTacticalMenu.open = false
		return ok
	elseif option.kind == "fire_state_cycle" then
		local ok = false
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if #selectedUnits > 0 then
			local firstUnit = selectedUnits[1]
			local states = type(Spring.GetUnitStates) == "function" and Spring.GetUnitStates(firstUnit)
			local currentFireState = states and states.firestate or 2
			local nextVal = (currentFireState + 1) % 3
			local labels = { [0] = "Hold Fire", [1] = "Return Fire", [2] = "Fire At Will" }
			local count
			ok, count = ControllerCameraTestIssueOrderToSelectedUnits(CMD.FIRESTATE or 20, { nextVal }, "Fire State", labels[nextVal] or tostring(nextVal), {})
			ControllerCameraTestTacticalMenu.lastResult = ok and (labels[nextVal] .. " for " .. tostring(count)) or "failed"
		end
		ControllerCameraTestTacticalMenu.open = false
		return ok
	elseif option.kind == "factory_clear" then
		local ok, count = ControllerCameraTestIssueOrderToSelectedUnits(CMD.STOP, {}, "Clear Queue", "factory", {})
		ControllerCameraTestTacticalMenu.lastResult = ok and ("cleared " .. tostring(count) .. " factories") or "failed"
		ControllerCameraTestTacticalMenu.open = false
		return ok
	elseif option.kind == "factory_repeat" then
		local ok = false
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if #selectedUnits > 0 then
			local states = type(Spring.GetUnitStates) == "function" and Spring.GetUnitStates(selectedUnits[1])
			local currentRepeat = states and states["repeat"]
			local nextVal = currentRepeat and 0 or 1
			local count
			ok, count = ControllerCameraTestIssueOrderToSelectedUnits(CMD.REPEAT, { nextVal }, "Repeat", nextVal == 1 and "ON" or "OFF", {})
			ControllerCameraTestTacticalMenu.lastResult = ok and ("toggled repeat for " .. tostring(count)) or "failed"
		end
		ControllerCameraTestTacticalMenu.open = false
		return ok
	end

	if type(option.cmdID) ~= "number" then
		ControllerCameraTestTacticalMenu.lastResult = tostring(option.name) .. " unavailable"
		latchSelectionDebugMessage(tostring(option.name) .. " unavailable")
		return false
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
			return false
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
			return false
		end
	elseif option.kind == "alliedUnit" then
		if target.targetType ~= "unit" or not target.targetID or not ControllerCameraTestIsAlliedUnit(target.targetID) then
			ControllerCameraTestTacticalMenu.lastResult = option.name .. " failed: no allied unit"
			latchSelectionDebugMessage(option.name .. " failed: no allied unit target")
			return false
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
			return false
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
			return false
		end
	end

	local ok, count = ControllerCameraTestIssueOrderToSelectedUnits(option.cmdID, params, option.name, targetName)
	ControllerCameraTestTacticalMenu.lastResult = ok and ("issued to " .. tostring(count)) or "failed"
	ControllerCameraTestLayerDebug.commandLayerAction = option.name .. " " .. ControllerCameraTestTacticalMenu.lastResult
	ControllerCameraTestTacticalMenu.open = false
	return ok
end

function ControllerCameraTestHandleTacticalMenuInput()
	local menu = ControllerCameraTestTacticalMenu
	if not menu.open then
		return false
	end

	ControllerCameraTestUpdateTacticalStickSelection()

	if ControllerCameraTestActionPressed("tacticalCancel") or ControllerCameraTestActionPressed("tacticalClose") then
		menu.open = false
		menu.lastAction = "cancelled"
		latchSelectionDebugMessage("Tactical menu cancelled")
	elseif WasButtonPressed("dpadUp") or WasButtonPressed("dpadLeft") or ControllerCameraTestActionPressed("radialPrevPage") then
		ControllerCameraTestCycleTacticalCommand(-1)
	elseif WasButtonPressed("dpadDown") or WasButtonPressed("dpadRight") or ControllerCameraTestActionPressed("radialNextPage") then
		ControllerCameraTestCycleTacticalCommand(1)
	elseif ControllerCameraTestActionPressed("tacticalSelect") or ControllerCameraTestActionPressed("radialQuick") then
		local commands = ControllerCameraTestGetTacticalCommands()
		ControllerCameraTestExecuteTacticalCommand(commands[menu.selectedIndex], true)
	end
	ControllerCameraTestRefreshTacticalDebug()
	return true
end

function ControllerCameraTestIssueGuardOrPatrol()
	local target = ControllerCameraTestGetReticleTargetInfo()
	if target.targetType == "unit" and target.targetID and ControllerCameraTestIsAlliedUnit(target.targetID) then
		ControllerCameraTestIssueOrderToSelectedUnits(CMD.GUARD, { target.targetID }, "Guard", "unit " .. tostring(target.targetID))
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+D-pad Up guard"
	elseif target.hasWorld then
		ControllerCameraTestIssueOrderToSelectedUnits(CMD.PATROL, { target.x, target.y, target.z }, "Patrol", "ground")
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+D-pad Up patrol"
	else
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+D-pad Up failed: no target"
		latchSelectionDebugMessage("Guard/Patrol failed: no target")
	end
end

function ControllerCameraTestIssueReclaimOrStop()
	local option = { name = "Reclaim", cmdID = CMD.RECLAIM, kind = "reclaim" }
	ControllerCameraTestExecuteTacticalCommand(option)
	ControllerCameraTestLayerDebug.commandLayerAction = "Layer+D-pad Down reclaim"
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
	local isBuild = unitDef.isBuilder
		or unitDef.canBuild
		or unitDef.canAssist
		or (type(unitDef.buildOptions) == "table" and #unitDef.buildOptions > 0)
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

--------------------------------------------------------------------------------
-- SECTION: Factory radial helpers
--------------------------------------------------------------------------------
function ControllerCameraTestGetFactoryQueueCounts()
	local counts = {}
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		return counts
	end

	for _, unitID in ipairs(selectedUnits) do
		local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if type(unitDef) == "table" and unitDef.isFactory then
			local q = type(Spring.GetFactoryCommands) == "function" and Spring.GetFactoryCommands(unitID, -1)
			if type(q) == "table" then
				for i = 1, #q do
					local cmd = q[i]
					if cmd and type(cmd.id) == "number" and cmd.id < 0 then
						counts[cmd.id] = (counts[cmd.id] or 0) + 1
					end
				end
			end
		end
	end
	return counts
end

function ControllerCameraTestRefreshFactoryQueueCounts()
	ControllerCameraTestBuildMenu.factoryQueueCounts = ControllerCameraTestGetFactoryQueueCounts()
end

function ControllerCameraTestGetFactoryQueueProgress()
	local progressByCmdID = {}
	local menu = ControllerCameraTestBuildMenu
	menu.factoryProgressKnown = "no"
	menu.factoryProgressCmdID = "none"
	menu.factoryProgressValue = "none"
	menu.factoryProgressSource = "none"
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		return progressByCmdID
	end

	for _, unitID in ipairs(selectedUnits) do
		local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if type(unitDef) == "table" and unitDef.isFactory then
			local unitBuildID = type(Spring.GetUnitIsBuilding) == "function" and Spring.GetUnitIsBuilding(unitID)
			if unitBuildID then
				local buildUnitDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(unitBuildID)
				if buildUnitDefID then
					local progress = nil
					if type(Spring.GetUnitHealth) == "function" then
						local ok, health, maxHealth, paralyzeDamage, captureProgress, buildProgress = pcall(Spring.GetUnitHealth, unitBuildID)
						if ok and type(buildProgress) == "number" then
							progress = buildProgress
							menu.factoryProgressSource = "GetUnitIsBuilding/GetUnitHealth"
						elseif ok and type(health) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
							progress = health / maxHealth
							menu.factoryProgressSource = "health fallback"
						end
					end
					if progress and progress >= 0.0 and progress <= 1.0 then
						local cmdID = -buildUnitDefID
						if not progressByCmdID[cmdID] or progress > progressByCmdID[cmdID] then
							progressByCmdID[cmdID] = progress
						end
						menu.factoryProgressKnown = "yes"
						menu.factoryProgressCmdID = tostring(cmdID)
						menu.factoryProgressValue = string.format("%.2f", progress)
					end
				end
			end
		end
	end
	return progressByCmdID
end

function ControllerCameraTestRefreshFactoryQueueProgress()
	ControllerCameraTestBuildMenu.factoryQueueProgress = ControllerCameraTestGetFactoryQueueProgress()
end

function ControllerCameraTestCanAffordBuildOption(option)
	if not option then
		return false, false, false, "no option"
	end
	if type(Spring.GetMyTeamID) ~= "function" or type(Spring.GetTeamResources) ~= "function" then
		return true, true, true, "no api"
	end

	local myTeamID = Spring.GetMyTeamID()
	local metalOk, metalLevel = pcall(Spring.GetTeamResources, myTeamID, "metal")
	local energyOk, energyLevel = pcall(Spring.GetTeamResources, myTeamID, "energy")

	local currentMetal = (metalOk and type(metalLevel) == "number") and metalLevel or 0
	local currentEnergy = (energyOk and type(energyLevel) == "number") and energyLevel or 0

	local mCost = option.metalCost or 0
	local eCost = option.energyCost or 0

	local metalAffordable = currentMetal >= mCost
	local energyAffordable = currentEnergy >= eCost
	local affordable = metalAffordable and energyAffordable

	local reason = ""
	if not metalAffordable and not energyAffordable then
		reason = "both"
	elseif not metalAffordable then
		reason = "metal"
	elseif not energyAffordable then
		reason = "energy"
	end

	return affordable, metalAffordable, energyAffordable, reason
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

--------------------------------------------------------------------------------
-- SECTION: Build radial
--------------------------------------------------------------------------------
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
	ControllerCameraTestRefreshFactoryQueueCounts()
	ControllerCameraTestRefreshFactoryQueueProgress()

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
	placement.placementSpacing = (type(Spring.GetBuildSpacing) == "function" and Spring.GetBuildSpacing()) or 0
	placement.placementPattern = "single"
	placement.queueFrontActive = false
	placement.lastConstructionShortcut = "none"
	placement.gridShortcutResult = "none"
	placement.lastResult = "placing " .. tostring(option.name)
	placement.patternPressActive = false
	placement.patternPressStartTime = 0
	placement.patternHoldTriggered = false
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
	placement.patternPressActive = false
	placement.patternPressStartTime = 0
	placement.patternHoldTriggered = false
	latchSelectionDebugMessage("Placement cancelled")
end

function ControllerCameraTestRotatePlacementFacing(delta)
	local placement = ControllerCameraTestBuildPlacement
	-- Flip delta sign to fix inverted placement rotation
	local correctedDelta = -delta
	placement.facing = ((placement.facing or 0) + correctedDelta) % 4
	if type(Spring.SetBuildFacing) == "function" then
		pcall(Spring.SetBuildFacing, placement.facing)
	end
	placement.lastResult = "facing " .. tostring(placement.facing)
	latchSelectionDebugMessage("Build facing: " .. tostring(placement.facing))
end

function ControllerCameraTestTryConstructionShortcut(actionName, direction)
	local placement = ControllerCameraTestBuildPlacement
	if not placement.active then
		return false
	end

	if actionName == "spacing" then
		if direction == "inc" then
			local ok = pcall(Spring.SendCommands, "buildspacing inc")
			if ok then
				if type(Spring.GetBuildSpacing) == "function" then
					placement.placementSpacing = Spring.GetBuildSpacing() or 0
				end
				placement.lastConstructionShortcut = "spacing inc"
				placement.gridShortcutResult = "success"
				ControllerCameraTestShowPlacementPatternPopup(placement.placementPattern, "spacing")
				return true
			end
		elseif direction == "dec" then
			local ok = pcall(Spring.SendCommands, "buildspacing dec")
			if ok then
				if type(Spring.GetBuildSpacing) == "function" then
					placement.placementSpacing = Spring.GetBuildSpacing() or 0
				end
				placement.lastConstructionShortcut = "spacing dec"
				placement.gridShortcutResult = "success"
				ControllerCameraTestShowPlacementPatternPopup(placement.placementPattern, "spacing")
				return true
			end
		end
	elseif actionName == "pattern" then
		if direction == "next" then
			placement.lastConstructionShortcut = "pattern next disabled"
			placement.gridShortcutResult = "pattern next disabled"
			return false
		end

		if direction == "grid" then
			if placement.placementPattern ~= "grid" then
				placement.placementPattern = "grid"
				placement.lastConstructionShortcut = "pattern grid"
				placement.gridShortcutResult = "grid selected"
				ControllerCameraTestShowPlacementPatternPopup(placement.placementPattern, "pattern")
				return true
			end

			placement.lastConstructionShortcut = "pattern grid held"
			placement.gridShortcutResult = "grid already selected"
			return false
		end

		local patterns = { "single", "line", "grid", "border", "split" }
		local currentIdx = 1
		for idx, pat in ipairs(patterns) do
			if pat == placement.placementPattern then
				currentIdx = idx
				break
			end
		end

		if direction == "prev" then
			currentIdx = ((currentIdx - 2) % #patterns) + 1
		else
			currentIdx = (currentIdx % #patterns) + 1
		end

		placement.placementPattern = patterns[currentIdx]
		placement.lastConstructionShortcut = "pattern " .. tostring(direction or "cycle")
		placement.gridShortcutResult = "pattern selected"
		ControllerCameraTestShowPlacementPatternPopup(placement.placementPattern, "pattern")
		return true
	end

	return false
end

function ControllerCameraTestHandlePlacementPatternInput()
	local placement = ControllerCameraTestBuildPlacement
	local isDown = ControllerCameraTestActionDown("patternPrev")
	local changed = false

	if isDown then
		if not placement.patternPressActive then
			placement.patternPressActive = true
			placement.patternPressStartTime = debugEventTime
			placement.patternHoldTriggered = false
		elseif not placement.patternHoldTriggered
			and (debugEventTime - (placement.patternPressStartTime or debugEventTime)) >= (placement.patternHoldSeconds or 0.25) then
			changed = ControllerCameraTestTryConstructionShortcut("pattern", "grid") or changed
			placement.patternHoldTriggered = true
		end
	elseif placement.patternPressActive then
		if not placement.patternHoldTriggered then
			changed = ControllerCameraTestTryConstructionShortcut("pattern", "cycle") or changed
		end

		placement.patternPressActive = false
		placement.patternPressStartTime = 0
		placement.patternHoldTriggered = false
	end

	return changed
end

function ControllerCameraTestDragModeForPlacementPattern(pattern)
	if pattern == "line" then
		return "buildLine"
	elseif pattern == "grid" then
		return "buildGrid"
	elseif pattern == "border" then
		return "buildBorder"
	elseif pattern == "split" then
		return "buildSplit"
	end
	return "buildLine"
end

function ControllerCameraTestPlacementPatternLabel(pattern)
	local labels = {
		single = "Single",
		line = "Line",
		grid = "Grid",
		border = "Border",
		split = "Split",
	}
	return labels[pattern] or tostring(pattern or "Single")
end

function ControllerCameraTestShowPlacementPatternPopup(pattern, reason)
	if ControllerCameraTestSettings.placementPopupEnabled == false then
		return
	end
	local placement = ControllerCameraTestBuildPlacement
	local label = ControllerCameraTestPlacementPatternLabel(pattern)
	local text = "Placement: " .. label
	if reason == "drag" then
		text = "Build " .. label
	elseif reason == "spacing" then
		text = "Spacing: " .. tostring(placement.placementSpacing or 0) .. " (" .. label .. ")"
	end
	ControllerCameraTestPlacementPopup.text = text
	ControllerCameraTestPlacementPopup.lastResult = text
	ControllerCameraTestPlacementPopup.expireTime = debugEventTime + 1.25
end

function ControllerCameraTestUpdatePlacementAnalog()
	local placement = ControllerCameraTestBuildPlacement
	if not placement.active then
		return
	end

	-- Right stick remains camera control during placement; facing is explicit on D-pad L/R.
	placement.analogRotateArmed = true
end

function ControllerCameraTestPlaceBuildOption(option, exitPlacement, source)
	local menu = ControllerCameraTestBuildMenu
	local queueActive = ControllerCameraTestIsQueueModifierActive()
	local orderOptions = ControllerCameraTestGetCommandOptions()
	ControllerCameraTestBuildPlacement.queueActive = queueActive
	ControllerCameraTestCommandDebug.lastOptions = ControllerCameraTestCommandOptionsSummary(orderOptions)
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
		local queueFrontActive = ControllerCameraTestBuildPlacement.active and ControllerCameraTestBuildPlacement.queueFrontActive
		local cmdToIssue = option.cmdID
		local paramsToIssue = {}
		local optionsToIssue = orderOptions

		if queueFrontActive then
			cmdToIssue = CMD.INSERT or 140
			paramsToIssue = { 0, option.cmdID, 0 }
			optionsToIssue = { "alt" }
		end

		local ok, issuedCount = ControllerCameraTestIssueOrderToSelectedUnits(cmdToIssue, paramsToIssue, "Factory queue " .. tostring(option.name), "queue", optionsToIssue)
		menu.placementParamsCount = #paramsToIssue
		ControllerCameraTestBuildPlacement.lastParamsCount = #paramsToIssue
		ControllerCameraTestBuildPlacement.lastIssuedCount = issuedCount
		if ok then
			menu.placementResult = queueFrontActive and ("factory prepended to " .. tostring(issuedCount)) or ("factory queued to " .. tostring(issuedCount))
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

	local useQueueFront = ControllerCameraTestBuildPlacement.active and ControllerCameraTestBuildPlacement.queueFrontActive
	local cmdInsert = CMD.INSERT or 140

	for _, unitID in ipairs(selectedUnits) do
		local orderOk, orderResult
		if useQueueFront then
			orderOk, orderResult = pcall(spGiveOrderToUnit, unitID, cmdInsert, { 0, option.cmdID, 0, x, y, z, facing }, { "alt" })
		else
			orderOk, orderResult = pcall(spGiveOrderToUnit, unitID, option.cmdID, params, orderOptions)
		end
		if orderOk and orderResult ~= false then
			issuedCount = issuedCount + 1
		end
	end

	if useQueueFront then
		ControllerCameraTestCommandDebug.issuedCmdID = tostring(cmdInsert) .. " (inserting " .. tostring(option.cmdID) .. ")"
		ControllerCameraTestCommandDebug.issuedParamsCount = 7
	else
		ControllerCameraTestCommandDebug.issuedCmdID = tostring(option.cmdID)
		ControllerCameraTestCommandDebug.issuedParamsCount = #params
	end
	menu.placementParamsCount = useQueueFront and 7 or #params
	ControllerCameraTestBuildPlacement.lastParamsCount = useQueueFront and 7 or #params
	ControllerCameraTestBuildPlacement.lastIssuedCount = issuedCount
	if issuedCount > 0 then
		lastIssuedCommand = useQueueFront and ("Build menu prepend: " .. tostring(option.name)) or ("Build menu: " .. tostring(option.name))
		menu.placementResult = useQueueFront and ("prepended to " .. tostring(issuedCount) .. " units") or ("issued to " .. tostring(issuedCount) .. " units")
		menu.lastAction = source or "placed"
		ControllerCameraTestBuildPlacement.lastResult = menu.placementResult
		ControllerCameraTestCommandDebug.lastResult = "build menu GiveOrderToUnit"
		latchSelectionDebugMessage(useQueueFront and ("Build prepended: " .. tostring(option.name)) or ("Build placed: " .. tostring(option.name)))
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

function ControllerCameraTestPlacementShouldExit(button)
	return button == "place" and not ControllerCameraTestIsQueueModifierActive()
end

function ControllerCameraTestDequeueFactoryBuildOption(option)
	local menu = ControllerCameraTestBuildMenu
	if not option or type(option.cmdID) ~= "number" or option.cmdID >= 0 then
		menu.lastAction = "dequeue failed: invalid option"
		menu.radialLastAction = "dequeue failed: invalid option"
		return false
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		menu.lastAction = "dequeue failed: no selected units"
		menu.radialLastAction = "dequeue failed: no selected units"
		return false
	end

	if not ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits) then
		menu.lastAction = "dequeue failed: not a factory"
		menu.radialLastAction = "dequeue failed: not a factory"
		return false
	end

	local queueActive = ControllerCameraTestIsQueueModifierActive()
	local optionsToIssue = { "right" }
	if queueActive then
		optionsToIssue = { "right", "shift" }
	end

	local ok, issuedCount = ControllerCameraTestIssueOrderToSelectedUnits(option.cmdID, {}, "Factory dequeue " .. tostring(option.name), "queue", optionsToIssue)
	if ok then
		menu.lastAction = queueActive and "factory dequeued 5 (B)" or "factory dequeued (B)"
		menu.radialLastAction = menu.lastAction
		ControllerCameraTestRefreshFactoryQueueCounts()
		ControllerCameraTestRefreshFactoryQueueProgress()
		return true
	else
		menu.lastAction = "factory dequeue failed"
		menu.radialLastAction = "factory dequeue failed"
		return false
	end
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
			placement.placementSpacing = (type(Spring.GetBuildSpacing) == "function" and Spring.GetBuildSpacing()) or 0
			placement.placementPattern = "single"
			placement.queueFrontActive = false
			placement.lastConstructionShortcut = "none"
			placement.gridShortcutResult = "none"
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
		placement.placementSpacing = (type(Spring.GetBuildSpacing) == "function" and Spring.GetBuildSpacing()) or 0
		placement.placementPattern = "single"
		placement.queueFrontActive = false
		placement.lastConstructionShortcut = "none"
		placement.gridShortcutResult = "none"
		menu.lastAction = "entered custom placement"
	else
		menu.lastAction = "placement failed"
	end
	ControllerCameraTestRefreshBuildMenuDebug()
end

function ControllerCameraTestHandlePlacementInput(dt)
	local placement = ControllerCameraTestBuildPlacement
	if not placement.active then
		placement.patternPressActive = false
		placement.patternPressStartTime = 0
		placement.patternHoldTriggered = false
		return false
	end

	placement.queueActive = ControllerCameraTestIsQueueModifierActive()
	placement.queueFrontActive = ControllerCameraTestIsQueueFrontModifierActive()
	ControllerCameraTestUpdatePlacementAnalog()

	local drag = ControllerCameraTestDragCommand
	if ControllerCameraTestHandleQueueRemovalInput() then
		return true
	end

	if ControllerCameraTestActionPressed("cancelPlacement") then
		if drag.active then
			ControllerCameraTestCancelDrag("cancelled by B")
		else
			ControllerCameraTestCancelPlacement("cancelled by B")
		end
	elseif ControllerCameraTestActionPressed("place") or ControllerCameraTestActionPressed("placeStay") then
		local button = ControllerCameraTestActionPressed("place") and "place" or "placeStay"
		local isExit = ControllerCameraTestPlacementShouldExit(button)
		if placement.placementPattern == "single" then
			ControllerCameraTestPlaceBuildOption(placement.option, isExit, "placed and " .. (isExit and "exited" or "remained"))
		else
			if drag.active then
				ControllerCameraTestConfirmDragBuild(isExit)
			else
				drag.active = true
				drag.pressActive = true
				drag.pressStartTime = debugEventTime
				drag.pressButton = button
				drag.mode = ControllerCameraTestDragModeForPlacementPattern(placement.placementPattern)
				drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
				drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
				drag.previewPoints = {}
				ControllerCameraTestShowPlacementPatternPopup(placement.placementPattern, "drag")
				latchSelectionDebugMessage(placement.placementPattern:gsub("^%l", string.upper) .. " drag build started")
			end
		end
	end

	if drag.active and drag.pressActive and (drag.pressButton == "place" or drag.pressButton == "placeStay") then
		local btn = drag.pressButton
		if ControllerCameraTestActionDown(btn) then
			ControllerCameraTestUpdateDragPreview()
		end
		if ControllerCameraTestActionReleased(btn) then
			if (debugEventTime - drag.pressStartTime) >= 0.35 then
				local isExit = ControllerCameraTestPlacementShouldExit(btn)
				ControllerCameraTestConfirmDragBuild(isExit)
			end
			drag.pressActive = false
		end
	elseif drag.active then
		ControllerCameraTestUpdateDragPreview()
	end

	if drag.active then
		local changed = false
		if ControllerCameraTestActionPressed("rotateBuildingLeft") then
			ControllerCameraTestRotatePlacementFacing(-1)
			changed = true
		elseif ControllerCameraTestActionPressed("rotateBuildingRight") then
			ControllerCameraTestRotatePlacementFacing(1)
			changed = true
		else
			changed = ControllerCameraTestHandlePlacementPatternInput()
			if not changed then
				if ControllerCameraTestActionPressed("spacingUp") then
					changed = ControllerCameraTestTryConstructionShortcut("spacing", "inc")
				elseif ControllerCameraTestActionPressed("spacingDown") then
					changed = ControllerCameraTestTryConstructionShortcut("spacing", "dec")
				end
			end
		end
		if changed then
			drag.mode = ControllerCameraTestDragModeForPlacementPattern(placement.placementPattern)
			ControllerCameraTestUpdateDragPreview()
		end
	end

	if not drag.active then
		if ControllerCameraTestActionPressed("rotateBuildingLeft") then
			ControllerCameraTestRotatePlacementFacing(-1)
		elseif ControllerCameraTestActionPressed("rotateBuildingRight") then
			ControllerCameraTestRotatePlacementFacing(1)
		elseif ControllerCameraTestActionPressed("radialClose") then
			ControllerCameraTestCancelPlacement("cancelled by Y")
		elseif ControllerCameraTestHandlePlacementPatternInput() then
			-- Pattern helper handles LB tap-to-cycle and hold-to-grid.
		elseif ControllerCameraTestActionPressed("spacingUp") then
			ControllerCameraTestTryConstructionShortcut("spacing", "inc")
		elseif ControllerCameraTestActionPressed("spacingDown") then
			ControllerCameraTestTryConstructionShortcut("spacing", "dec")
		end
	end

	if drag.active then
		activeButtonLayoutSummary = "Drag Build: A/X confirm, B cancel, RS X camera, D-pad L/R facing, U/D spacing, LB tap pattern/hold grid"
	else
		activeButtonLayoutSummary = "Placement: A place+exit, X place again, B cancel, RS X camera, D-pad L/R facing, U/D spacing, LB tap pattern/hold grid"
	end
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

	if ControllerCameraTestHandleQueueRemovalInput() then
		return true
	end

	local currentLocalIndex = 1
	for idx, option in ipairs(menu.radialVisibleOptions or {}) do
		if option.menuIndex == menu.selectedIndex then
			currentLocalIndex = idx
			break
		end
	end

	local categories = menu.radialCategories or { "Economy", "Combat", "Utility", "Build" }

	if ControllerCameraTestActionPressed("radialCancel") then
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits) then
			local option = type(menu.options) == "table" and menu.options[menu.selectedIndex] or nil
			if option then
				ControllerCameraTestDequeueFactoryBuildOption(option)
			else
				menu.lastAction = "factory dequeue failed: no option"
				menu.radialLastAction = "factory dequeue failed: no option"
			end
		else
			ControllerCameraTestCloseBuildMenu("closed by B")
		end
	elseif ControllerCameraTestActionPressed("radialClose") then
		ControllerCameraTestCloseBuildMenu("closed by Y")
	elseif ControllerCameraTestActionPressed("radialSelect") then
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits) then
			local option = type(menu.options) == "table" and menu.options[menu.selectedIndex] or nil
			if option then
				local queueActive = ControllerCameraTestIsQueueModifierActive()
				local queueFrontActive = ControllerCameraTestIsQueueFrontModifierActive()
				local orderOptions = ControllerCameraTestGetCommandOptions()

				local cmdToIssue = option.cmdID
				local paramsToIssue = {}
				local optionsToIssue = orderOptions

				if queueFrontActive then
					cmdToIssue = CMD.INSERT or 140
					paramsToIssue = { 0, option.cmdID, 0 }
					optionsToIssue = { "alt" }
				end

				ControllerCameraTestBuildPlacement.queueActive = queueActive
				ControllerCameraTestBuildPlacement.queueFrontActive = queueFrontActive
				local ok, issuedCount = ControllerCameraTestIssueOrderToSelectedUnits(cmdToIssue, paramsToIssue, "Factory queue " .. tostring(option.name), "queue", optionsToIssue)
				if ok then
					menu.lastAction = queueFrontActive and "factory prepended (A)" or "factory queued (A)"
					menu.radialLastAction = menu.lastAction
					ControllerCameraTestRefreshFactoryQueueCounts()
					ControllerCameraTestRefreshFactoryQueueProgress()
				else
					menu.lastAction = "factory queue failed (A)"
					menu.radialLastAction = "factory queue failed (A)"
				end
			end
		else
			ControllerCameraTestEnterPlacementFromHighlight()
			ControllerCameraTestCloseBuildMenu("entered placement")
		end
	elseif ControllerCameraTestActionPressed("radialQuick") then
		ControllerCameraTestPlaceHighlightedBuildOption(false, "quick placed from radial")
	elseif WasButtonPressed("dpadDown") or WasButtonPressed("dpadRight") then
		ControllerCameraTestSetRadialHighlight(currentLocalIndex + 1, "dpad next")
	elseif WasButtonPressed("dpadUp") or WasButtonPressed("dpadLeft") then
		ControllerCameraTestSetRadialHighlight(currentLocalIndex - 1, "dpad prev")
	elseif ControllerCameraTestActionPressed("radialPrevPage") then
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
	elseif ControllerCameraTestActionPressed("radialNextPage") then
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

	local includeBuildings = ControllerCameraTestIsQueueModifierActive()
	local filteredUnits = ControllerCameraTestFilterAreaSelection(units, includeBuildings)
	area.filterMode = includeBuildings and "include buildings" or "units-first"
	area.lastCount = #filteredUnits
	if ControllerCameraTestSelectUnits(filteredUnits, "Area select") then
		area.lastResult = "selected " .. tostring(#filteredUnits) .. " (" .. tostring(area.filterMode) .. ")"
	else
		area.lastResult = "no units selected"
	end
	ControllerCameraTestLayerDebug.areaSelect = area.lastResult
end

function ControllerCameraTestFilterAreaSelection(unitIDs, includeBuildings)
	if type(unitIDs) ~= "table" then
		return {}
	end
	if includeBuildings then
		return ControllerCameraTestFilterValidUnits(unitIDs)
	end

	local mobileUnits = {}
	local buildingUnits = {}
	for _, unitID in ipairs(unitIDs) do
		local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if ControllerCameraTestIsMobileUnitDef(unitDef) then
			mobileUnits[#mobileUnits + 1] = unitID
		else
			buildingUnits[#buildingUnits + 1] = unitID
		end
	end

	if #mobileUnits > 0 then
		return ControllerCameraTestFilterValidUnits(mobileUnits)
	end
	return ControllerCameraTestFilterValidUnits(buildingUnits)
end

function ControllerCameraTestHandleNormalXInput(dt)
	local drag = ControllerCameraTestDragCommand
	local HOLD_SECONDS = ControllerCameraTestSettings.xHoldSeconds or 0.14

	if drag.active and ControllerCameraTestActionPressed("cancel") then
		ControllerCameraTestCancelDrag("cancelled by B")
		return true
	end

	if ControllerCameraTestActionPressed("smartAction") then
		drag.pressActive = true
		drag.pressStartTime = debugEventTime
		drag.pressButton = "smartAction"
		drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
		drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
		drag.active = false
		drag.singleUnitPathActive = false
		drag.singleUnitPathUnitID = nil
	end

	if drag.pressActive and drag.pressButton == "smartAction" and ControllerCameraTestActionDown("smartAction") then
		if not drag.active and (debugEventTime - drag.pressStartTime) >= HOLD_SECONDS then
			local mobileUnits = ControllerCameraTestGetSelectedMobileUnits()
			local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
			if #selectedUnits == 1 and #mobileUnits == 1 and reticleHasWorldTarget then
				ControllerCameraTestStartSingleUnitPath(mobileUnits[1])
			else
				drag.active = true
				drag.mode = "moveLine"
				drag.lastResult = "active"
				latchSelectionDebugMessage("Move Line Drag started")
			end
		end
		if drag.active and drag.mode ~= "singleMovePath" then
			ControllerCameraTestUpdateDragPreview()
		end
	end

	if ControllerCameraTestActionReleased("smartAction") and drag.pressActive and drag.pressButton == "smartAction" then
		if drag.singleUnitPathActive then
			ControllerCameraTestFinishSingleUnitPath()
		elseif drag.active then
			ControllerCameraTestConfirmDragCommand(false)
		else
			attemptContextCommand()
		end
		drag.pressActive = false
	end

	return drag.pressActive or drag.active
end

function ControllerCameraTestHandleCommandLayerDragInputs(dt)
	local drag = ControllerCameraTestDragCommand
	local X_HOLD_SECONDS = ControllerCameraTestSettings.xHoldSeconds or 0.14
	local A_HOLD_SECONDS = 0.35

	if drag.active and ControllerCameraTestActionPressed("cancel") then
		ControllerCameraTestCancelDrag("cancelled by B")
		return true
	end

	if ControllerCameraTestActionPressed("smartAction") then
		drag.pressActive = true
		drag.pressStartTime = debugEventTime
		drag.pressButton = "RT+X"
		drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
		drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
		drag.active = false
	end

	if drag.pressActive and drag.pressButton == "RT+X" and ControllerCameraTestActionDown("smartAction") then
		if not drag.active and (debugEventTime - drag.pressStartTime) >= X_HOLD_SECONDS then
			drag.active = true
			drag.mode = "fightLine"
			drag.lastResult = "active"
			latchSelectionDebugMessage("Fight Line Drag started")
		end
		if drag.active then
			ControllerCameraTestUpdateDragPreview()
		end
	end

	if ControllerCameraTestActionReleased("smartAction") and drag.pressActive and drag.pressButton == "RT+X" then
		if drag.active then
			ControllerCameraTestConfirmDragCommand(false)
		else
			attemptAttackCommand()
		end
		drag.pressActive = false
	end

	if ControllerCameraTestActionPressed("select") then
		drag.pressActive = true
		drag.pressStartTime = debugEventTime
		drag.pressButton = "RT+A"
		drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
		drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
		drag.active = false
	end

	if drag.pressActive and drag.pressButton == "RT+A" and ControllerCameraTestActionDown("select") then
		if not drag.active and (debugEventTime - drag.pressStartTime) >= A_HOLD_SECONDS then
			drag.active = true
			drag.mode = "attackLine"
			drag.lastResult = "active"
			latchSelectionDebugMessage("Attack Line Drag started")
		end
		if drag.active then
			ControllerCameraTestUpdateDragPreview()
		end
	end

	if ControllerCameraTestActionReleased("select") and drag.pressActive and drag.pressButton == "RT+A" then
		if drag.active then
			ControllerCameraTestConfirmDragCommand(false)
		else
			ControllerCameraTestLayerDebug.commandLayerAction = "Layer+A select-all disabled"
			ControllerCameraTestCycleDebug.lastResult = "Layer+A select-all disabled"
			latchSelectionDebugMessage("Layer+A reserved: select-all disabled")
		end
		drag.pressActive = false
	end

	return drag.pressActive or drag.active
end

function ControllerCameraTestHandleNormalAInput(dt)
	local area = ControllerCameraTestAreaSelect
	local HOLD_SECONDS = ControllerCameraTestSettings.aHoldSeconds or 0.38

	if ControllerCameraTestActionPressed("select") then
		area.pressActive = true
		area.active = false
		area.pressStartTime = debugEventTime
		area.lastResult = "press started"
		ControllerCameraTestLayerDebug.areaSelect = area.lastResult
	end

	if area.pressActive and ControllerCameraTestActionDown("select") then
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

	if ControllerCameraTestActionReleased("select") and area.pressActive then
		if area.active then
			ControllerCameraTestSelectAreaUnits()
		elseif (debugEventTime - (area.lastTapTime or -10)) <= 0.35 then
			local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
			local targetID = ControllerCameraTestGetReticleAlliedUnitAndDef()
			if targetID and ControllerCameraTestIsQueueModifierActive() then
				ControllerCameraTestSelectAllOwnedSameTypeUnderReticle()
			elseif targetID then
				ControllerCameraTestSelectVisibleSameTypeUnderReticle()
			elseif IsButtonDown("back") then
				ControllerCameraTestTuning.backComboUsed = true
				if ControllerCameraTestFocusCommander() then
					ControllerCameraTestAreaSelect.doubleTapAction = "Back+double-tap commander focused"
				else
					ControllerCameraTestAreaSelect.doubleTapAction = "Back+double-tap commander failed"
				end
			elseif ControllerCameraTestIsQueueModifierActive() then
				ControllerCameraTestSelectAllIdleUnitsInCurrentTypeBucket()
				ControllerCameraTestAreaSelect.doubleTapAction = ControllerCameraTestIdleCycle.lastResult
			elseif #selectedUnits == 0 then
				ControllerCameraTestAreaSelect.lastResult = "double tap empty ignored"
				ControllerCameraTestAreaSelect.doubleTapAction = "empty ignored"
				ControllerCameraTestLayerDebug.normalUtilityAction = "Double-tap empty ignored"
				latchSelectionDebugMessage("Double-tap A empty: no action")
			else
				ControllerCameraTestAreaSelect.lastResult = "double tap ignored: units selected"
				ControllerCameraTestAreaSelect.doubleTapAction = "ignored: units selected"
				ControllerCameraTestLayerDebug.normalUtilityAction = "Double-tap A ignored"
				latchSelectionDebugMessage("Double-tap A ignored: units already selected")
			end
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

function ControllerCameraTestHandleBackCommandLayerSelectTap()
	if not ControllerCameraTestActionPressed("select") then
		return false
	end

	local commandLayerBinding = ControllerCameraTestGetBinding("commandLayer")
	if commandLayerBinding ~= "back" and commandLayerBinding ~= "view" and commandLayerBinding ~= "Back/View" then
		return false
	end
	if not ControllerCameraTestActionDown("commandLayer") then
		return false
	end

	local tuning = ControllerCameraTestTuning
	local area = ControllerCameraTestAreaSelect
	if (debugEventTime - (tuning.backCommandLayerATapTime or -10)) <= 0.35 then
		tuning.backComboUsed = true
		tuning.backCommandLayerATapTime = -10
		if ControllerCameraTestFocusCommander() then
			area.doubleTapAction = "Back+command-layer double-tap commander focused/selected"
			ControllerCameraTestLayerDebug.commandLayerAction = "Back+A+A commander focus/select"
		else
			area.doubleTapAction = "Back+command-layer double-tap commander failed"
			ControllerCameraTestLayerDebug.commandLayerAction = "Back+A+A commander focus failed"
		end
	else
		tuning.backCommandLayerATapTime = debugEventTime
		area.doubleTapAction = "Back+A first tap"
		ControllerCameraTestLayerDebug.commandLayerAction = "Back+A first tap commander utility"
	end
	return true
end

function ControllerCameraTestHandleCommandLayerInput(dt)
	if ControllerCameraTestTacticalTogglePressed() then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestToggleTacticalMenu()
		ControllerCameraTestLayerDebug.commandLayerAction = ControllerCameraTestTacticalMenu.open and "Layer+RB tactical menu opened" or "Layer+RB tactical menu closed"
		return
	end

	if ControllerCameraTestHandleTacticalMenuInput() then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		return
	end

	if ControllerCameraTestHandleStagedTacticalCommandInput() then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		return
	end

	-- Back/View is a command-layer modifier in presets; check its A+A utility before layer drag can consume A.
	if ControllerCameraTestHandleBackCommandLayerSelectTap() then
		return
	end

	if ControllerCameraTestHandleCommandLayerDragInputs(dt) then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		return
	end

	if ControllerCameraTestActionPressed("select") then
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+A select-all disabled"
		ControllerCameraTestCycleDebug.lastResult = "Layer+A select-all disabled"
		latchSelectionDebugMessage("Layer+A reserved: select-all disabled")
	elseif ControllerCameraTestActionPressed("cancel") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		attemptStopCommand()
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+B stop"
	elseif ControllerCameraTestActionPressed("smartAction") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		attemptAttackCommand()
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+X attack/attack-move"
	elseif ControllerCameraTestActionPressed("buildRadial") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestToggleTacticalMenu()
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer build/tactical menu"
	elseif ControllerCameraTestActionPressed("commandUp") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestIssueGuardOrPatrol()
	elseif ControllerCameraTestActionPressed("commandDown") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestIssueReclaimOrStop()
	elseif ControllerCameraTestActionPressed("commandLeft") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		if not ControllerCameraTestCycleQuickGroup(-1) then
			ControllerCameraTestCycleSelection(-1)
			ControllerCameraTestLayerDebug.commandLayerAction = "Layer+D-pad Left cycle selection"
		end
	elseif ControllerCameraTestActionPressed("commandRight") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		if not ControllerCameraTestCycleQuickGroup(1) then
			ControllerCameraTestCycleSelection(1)
			ControllerCameraTestLayerDebug.commandLayerAction = "Layer+D-pad Right cycle selection"
		end
	elseif ControllerCameraTestActionPressed("pitchModifier") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestCycleSelection(-1)
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+LB previous selection"
	elseif ControllerCameraTestActionPressed("controlGroupModifier") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestCycleSelection(1)
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+RB next selection"
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

	if ControllerCameraTestActionPressed("pitchModifier") then
		ControllerCameraTestCycleDebug.lbPressActive = true
		ControllerCameraTestCycleDebug.lbHadPitchMotion = false
	end
	if ControllerCameraTestActionDown("pitchModifier") and math.abs(normalizedRightY) > 0.2 then
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
	if WasButtonPressed("back") then
		ControllerCameraTestTuning.backHeld = true
		ControllerCameraTestTuning.backComboUsed = false
		ControllerCameraTestTuning.backQueueModifier = ControllerCameraTestIsQueueModifierActive()
		ControllerCameraTestTuning.lastAction = "Back/View commander utility ready"
		ControllerCameraTestLayerDebug.normalUtilityAction = "Back/View modifier ready"
	end
	if WasButtonReleased("back") and ControllerCameraTestTuning.backHeld then
		ControllerCameraTestTuning.backHeld = false
		ControllerCameraTestTuning.backComboUsed = false
		ControllerCameraTestTuning.backQueueModifier = false
	end
	return false
end

function ControllerCameraTestHandleNormalUtilityInput()
	if ControllerCameraTestHandleControlGroupInput() then
		return true
	elseif ControllerCameraTestHandleQueueRemovalInput() then
		return true
	elseif ControllerCameraTestActionDown("pitchModifier") and ControllerCameraTestActionPressed("idlePrev") then
		ControllerCameraTestCycleDebug.lbHadPitchMotion = true
		ControllerCameraTestCycleIdleUnitType(-1)
	elseif ControllerCameraTestActionDown("pitchModifier") and ControllerCameraTestActionPressed("idleNext") then
		ControllerCameraTestCycleDebug.lbHadPitchMotion = true
		ControllerCameraTestCycleIdleUnitType(1)
	elseif ControllerCameraTestActionReleased("pitchModifier") and ControllerCameraTestCycleDebug.lbPressActive then
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
	elseif ControllerCameraTestActionPressed("idlePrev") then
		ControllerCameraTestCycleIdleUnit(-1)
	elseif ControllerCameraTestActionPressed("idleNext") then
		ControllerCameraTestCycleIdleUnit(1)
	end
	return false
end

function ControllerCameraTestGetModeSummary()
	if ControllerCameraTestSettingsUI.open then
		return "settings"
	end
	if ControllerCameraTestIsGameplayInputBlocked() then
		return "external binding UI"
	end
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
	if type(ControllerCameraTestTacticalMenu.stagedOption) == "table" then
		return "tactical staged"
	end
	if ControllerCameraTestTacticalMenu.open then
		return "tactical menu"
	end
	if ControllerCameraTestAreaSelect.active then
		return "area select"
	end
	if ControllerCameraTestTuning.backHeld then
		return "back modifier"
	end
	if ControllerCameraTestActionDown("controlGroupModifier") then
		return "control groups"
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
	ControllerCameraTestEnsureBindings()
	ControllerCameraTestInstallWGAPI()
	updateScreenCenter(spGetViewGeometry())
	ensureDebugPanelInitialized()
end

function widget:Shutdown()
	ControllerCameraTestRemoveWGAPI()
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
		rawControllerStateStatus = "controller API unavailable"
		rawAxesSummary = "none"
		rawButtonsSummary = "none"
		resetControllerInputDebug()
		return
	end

	local controller = pollFirstController()
	if not controller then
		resetControllerInputDebug()
		return
	end

	local state = pollControllerState(controllerInstanceId)
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
	ControllerCameraTestUpdateBindingTriggerEdges()
	if not hasButtonState(pressedButtonStates) then
		pressedThisFrameSummary = "none"
	end
	if not hasButtonState(releasedButtonStates) then
		releasedThisFrameSummary = "none"
	end
	ControllerCameraTestUpdateHotInputDebugSummaries(state)
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
	lbCameraModifierActive = ControllerCameraTestActionDown("pitchModifier")
	commandLayerActive = ControllerCameraTestActionDown("commandLayer")
		and not ControllerCameraTestBuildPlacement.active
		and not ControllerCameraTestBuildMenu.open
	if not commandLayerActive then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
	end
	if ControllerCameraTestSettingsUI.open then
		commandLayerActive = false
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestHandleSettingsUIInput()
		ControllerCameraTestLayerDebug.modeSummary = "settings"
		activeButtonLayoutSummary = "Settings: D-pad adjust, LB/RB category, A edit, B close, X/Y reset"
		return
	end
	if ControllerCameraTestIsGameplayInputBlocked() then
		commandLayerActive = false
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestLayerDebug.modeSummary = "external binding UI"
		activeButtonLayoutSummary = "External binding UI active: gameplay input blocked"
		ControllerCameraTestExternalBindingUI.lastAction = "gameplay input blocked"
		return
	end
	ControllerCameraTestUpdateLBTapState()
	updateSelectionTestActive()

	if ControllerCameraTestHandleStagedTacticalCommandInput() then
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by tactical stage")
		end
	elseif commandLayerActive then
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by RT layer")
		end
		ControllerCameraTestHandleCommandLayerInput(dt)
	elseif ControllerCameraTestHandleTacticalMenuInput() then
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by tactical menu")
		end
	elseif ControllerCameraTestHandlePlacementInput(dt) then
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
		if ControllerCameraTestHandleControlGroupInput() then
			if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
				ControllerCameraTestCancelAreaSelect("cancelled by control group")
			end
		else
			local areaBusy = ControllerCameraTestHandleNormalAInput(dt)
			local xBusy = false
			if not areaBusy then
				xBusy = ControllerCameraTestHandleNormalXInput(dt)
			end

			if areaBusy and ControllerCameraTestActionPressed("cancel") then
				ControllerCameraTestCancelAreaSelect("cancelled by B")
			elseif xBusy and ControllerCameraTestActionPressed("cancel") then
				-- Handled inside X handler
			elseif not areaBusy and not xBusy and ControllerCameraTestActionPressed("cancel") then
				attemptClearSelection()
			end

			if not areaBusy and not xBusy and ControllerCameraTestActionPressed("buildRadial") then
				attemptBuildMenu()
			end
			if not areaBusy and not xBusy then
				ControllerCameraTestHandleNormalUtilityInput()
			end
		end
	end

	ControllerCameraTestLayerDebug.modeSummary = ControllerCameraTestGetModeSummary()
	if commandLayerActive then
		activeButtonLayoutSummary = ControllerCameraTestTacticalMenu.open and "Tactical: A/X stage, B/Y cancel, Back+RB toggle, D-pad/LB/RB choose"
			or XboxController.commandLayoutSummary
	elseif type(ControllerCameraTestTacticalMenu.stagedOption) == "table" then
		activeButtonLayoutSummary = ControllerCameraTestTacticalMenu.repeatPlacementActive
			and "Tactical repeat: move reticle, A place again, release RT clear, B cancel"
			or "Tactical staged: move reticle, A confirm, RT+A repeat, B cancel"
	elseif ControllerCameraTestTacticalMenu.open then
		activeButtonLayoutSummary = "Tactical: A/X stage, B/Y close, D-pad/LB/RB choose"
	elseif ControllerCameraTestBuildPlacement.active then
		activeButtonLayoutSummary = "Placement: A/X place, RT append, insert modifier fronts, LB tap pattern/hold grid"
	elseif ControllerCameraTestBuildMenu.open then
		activeButtonLayoutSummary = "Build menu: A placement, X quick-place, B/Y close, D-pad/LB/RB navigate"
	elseif ControllerCameraTestAreaSelect.active then
		activeButtonLayoutSummary = "Area select: release A to select, RS Y/D-pad changes radius"
	elseif ControllerCameraTestActionDown("controlGroupModifier") then
		activeButtonLayoutSummary = "Control Groups: Start+D-pad U/D slot, L recall, R type+future assign, Start+L3 clear"
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

function ControllerCameraTestApplyInputCurve(value, exponent)
	value = tonumber(value) or 0
	exponent = tonumber(exponent) or 1
	if value == 0 then
		return 0
	end
	local sign = value < 0 and -1 or 1
	return sign * (math.abs(value) ^ exponent)
end

function ControllerCameraTestSmoothAxis(current, target, dt)
	local response = math.max(0.01, tonumber(ControllerCameraTestSettings.cameraSmoothing) or 0.06)
	local alpha = 1 - math.exp(-math.max(0, dt or 0) / response)
	local value = (tonumber(current) or 0) + ((tonumber(target) or 0) - (tonumber(current) or 0)) * alpha
	return math.abs(value) < 0.001 and 0 or value
end

function ControllerCameraTestUpdateSmoothedCameraInputs(dt, menuOpen, areaActive)
	local smooth = ControllerCameraTestInputSmoothing
	if menuOpen then
		smooth.panX, smooth.panY, smooth.rotateX, smooth.pitchY, smooth.zoomY = 0, 0, 0, 0, 0
	else
		local curve = ControllerCameraTestSettings.stickCurve or 1.175
		smooth.panX = ControllerCameraTestSmoothAxis(smooth.panX, ControllerCameraTestApplyInputCurve(normalizedLeftX, curve), dt)
		smooth.panY = ControllerCameraTestSmoothAxis(smooth.panY, ControllerCameraTestApplyInputCurve(normalizedLeftY, curve), dt)
		smooth.rotateX = ControllerCameraTestSmoothAxis(smooth.rotateX, ControllerCameraTestApplyInputCurve(normalizedRightX, curve), dt)
		local yInput = ControllerCameraTestApplyInputCurve(-normalizedRightY, curve)
		smooth.pitchY = ControllerCameraTestSmoothAxis(smooth.pitchY, (lbCameraModifierActive and not areaActive) and yInput or 0, dt)
		smooth.zoomY = ControllerCameraTestSmoothAxis(smooth.zoomY, (not lbCameraModifierActive and not areaActive) and yInput or 0, dt)
	end
	local triggerInput = ControllerCameraTestApplyInputCurve(normalizedLeftTrigger or 0, ControllerCameraTestSettings.triggerCurve or 1.075)
	smooth.leftTrigger = ControllerCameraTestSmoothAxis(smooth.leftTrigger, triggerInput, dt)
end

function ControllerCameraTestUpdateCameraControls(dt)
	local placementActive = ControllerCameraTestBuildPlacement.active
	local menuOpen = (ControllerCameraTestBuildMenu.open and not placementActive) or ControllerCameraTestTacticalMenu.open or ControllerCameraTestSettingsUI.open or ControllerCameraTestIsGameplayInputBlocked()
	local areaActive = ControllerCameraTestAreaSelect.active
	ControllerCameraTestUpdateSmoothedCameraInputs(dt, menuOpen, areaActive)
	local smooth = ControllerCameraTestInputSmoothing
	panActive = (not menuOpen) and (smooth.panX ~= 0 or smooth.panY ~= 0)
	rightStickYMode = areaActive and "area radius" or (lbCameraModifierActive and "pitch" or "zoom")
	local zoomInput = menuOpen and 0 or smooth.zoomY
	local pitchInput = menuOpen and 0 or smooth.pitchY
	local rotationInput = menuOpen and 0 or smooth.rotateX
	zoomActive = zoomInput ~= 0
	rotationActive = rotationInput ~= 0
	pitchActive = pitchInput ~= 0

	local boostInput = smooth.leftTrigger or 0
	local panMultiplier = 1 + (((ControllerCameraTestSettings.fastPanMultiplier or 1) - 1) * boostInput)
	zoomSpeedMultiplier = 1 + (((ControllerCameraTestSettings.zoomBoostMultiplier or 1) - 1) * boostInput)
	if panActive or zoomActive or rotationActive or pitchActive then
		applyCameraInput(menuOpen and 0 or smooth.panX, menuOpen and 0 or smooth.panY, zoomInput, rotationInput, pitchInput, panMultiplier, zoomSpeedMultiplier, dt)
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
	if ControllerCameraTestIsGameplayInputBlocked() then
		updateReticleWorldTarget()
		if controllerMode and reticleVisible and type(spWarpMouse) == "function" then spWarpMouse(screenCenterX, screenCenterY) end
		return
	end
	if not ControllerCameraTestSettingsUI.open and ControllerCameraTestBuildMenu.open then
		ControllerCameraTestUpdateRadialStickSelection()
	end
	if not ControllerCameraTestSettingsUI.open and ControllerCameraTestTacticalMenu.open then
		ControllerCameraTestUpdateTacticalStickSelection()
	end
	ControllerCameraTestUpdateCameraControls(dt)
	updateReticleWorldTarget()
	if not ControllerCameraTestSettingsUI.open and ControllerCameraTestDragCommand.active then
		pcall(ControllerCameraTestUpdateDragPreview)
	end
	if controllerMode and reticleVisible and type(spWarpMouse) == "function" then spWarpMouse(screenCenterX, screenCenterY) end
end

function widget:Update(dt)
	ControllerCameraTestUpdateControllerFrame(dt)
end

function ControllerCameraTestNormalizeKeyName(value)
	return string.lower(tostring(value or "")):gsub("[%s_%-]", "")
end

function ControllerCameraTestKeyMatches(key, label, candidates)
	local normalizedLabel = ControllerCameraTestNormalizeKeyName(label)
	for _, candidate in ipairs(candidates or {}) do
		if type(candidate) == "number" and key == candidate then
			return true
		end
		local candidateText = tostring(candidate)
		local normalizedCandidate = ControllerCameraTestNormalizeKeyName(candidateText)
		if normalizedLabel ~= "" and normalizedLabel == normalizedCandidate then
			return true
		end
		if type(KEYSYMS) == "table" then
			local keySym = KEYSYMS[candidateText] or KEYSYMS[string.upper(candidateText)]
			if keySym ~= nil and key == keySym then
				return true
			end
		end
		if type(Spring.GetKeyCode) == "function" then
			local ok, keyCode = pcall(Spring.GetKeyCode, candidateText)
			if ok and keyCode ~= nil and key == keyCode then
				return true
			end
		end
	end
	return false
end

function ControllerCameraTestRecordKeyAction(key, label, action)
	ControllerCameraTestKeyDebug.rawKey = tostring(key or "nil")
	ControllerCameraTestKeyDebug.label = tostring(label or "")
	ControllerCameraTestKeyDebug.matchedAction = tostring(action or "none")
end

function ControllerCameraTestRecordUIToggleAction(action)
	ControllerCameraTestKeyDebug.lastUIToggle = tostring(action)
	ControllerCameraTestTuning.lastAction = tostring(action)
	latchSelectionDebugMessage(tostring(action))
end

function ControllerCameraTestToggleDebugPanel(source)
	ControllerCameraTestSettings.debugPanelVisible = not ControllerCameraTestSettings.debugPanelVisible
	ControllerCameraTestRecordUIToggleAction(tostring(source) .. " debug panel "
		.. (ControllerCameraTestSettings.debugPanelVisible and "shown" or "hidden"))
end

function ControllerCameraTestToggleHelpOverlay(source)
	ControllerCameraTestSettings.helpOverlayVisible = not ControllerCameraTestSettings.helpOverlayVisible
	ControllerCameraTestRecordUIToggleAction(tostring(source) .. " help overlay "
		.. (ControllerCameraTestSettings.helpOverlayVisible and "shown" or "hidden"))
end

function ControllerCameraTestToggleSettingsFromInput(source)
	ControllerCameraTestToggleSettingsUI()
	ControllerCameraTestRecordUIToggleAction(tostring(source) .. " settings "
		.. (ControllerCameraTestSettingsUI.open and "shown" or "hidden"))
end

function ControllerCameraTestResetSettingsFromInput(source)
	ControllerCameraTestResetSettingsToDefaults()
	ControllerCameraTestRecordUIToggleAction(tostring(source) .. " reset settings defaults")
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
	ControllerCameraTestRecordKeyAction(key, label, isRepeat and "repeat ignored" or "unmatched")
	if isRepeat then
		return false
	end

	if ControllerCameraTestKeyMatches(key, label, { "END", "End", "end", 279 }) then
		ControllerCameraTestRecordKeyAction(key, label, "toggle settings")
		ControllerCameraTestToggleSettingsFromInput("End")
		return true
	elseif ControllerCameraTestKeyMatches(key, label, { "PAGEUP", "PageUp", "pageup", "PGUP", "pgup", "PRIOR", "prior", 280 }) then
		ControllerCameraTestRecordKeyAction(key, label, "toggle debug")
		ControllerCameraTestToggleDebugPanel("Page Up")
		return true
	elseif ControllerCameraTestKeyMatches(key, label, { "PAGEDOWN", "PageDown", "pagedown", "PGDN", "pgdn", "NEXT", "next", 281 }) then
		ControllerCameraTestRecordKeyAction(key, label, "toggle help")
		ControllerCameraTestToggleHelpOverlay("Page Down")
		return true
	elseif ControllerCameraTestKeyMatches(key, label, { "HOME", "Home", "home", 278 }) then
		ControllerCameraTestRecordKeyAction(key, label, "reset settings")
		ControllerCameraTestResetSettingsFromInput("Home")
		return true
	end

	if ControllerCameraTestSettingsUI.open then
		local ui = ControllerCameraTestSettingsUI
		local category = ControllerCameraTestGetSettingsUICategory()
		if ControllerCameraTestKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
			ControllerCameraTestRecordKeyAction(key, label, "close settings")
			if ControllerCameraTestBindings.captureAction then
				ControllerCameraTestBindings.captureAction = nil
				ui.lastAction = "binding capture cancelled"
				ControllerCameraTestRecordUIToggleAction("Escape binding capture cancelled")
			else
				ControllerCameraTestToggleSettingsUI(false)
				ControllerCameraTestRecordUIToggleAction("Escape settings hidden")
			end
			return true
		elseif ControllerCameraTestKeyMatches(key, label, { "UP", "Up", "up", 273 }) then
			ControllerCameraTestRecordKeyAction(key, label, "settings up")
			ui.selectedIndex = ((ui.selectedIndex - 2) % #category.items) + 1
			return true
		elseif ControllerCameraTestKeyMatches(key, label, { "DOWN", "Down", "down", 274 }) then
			ControllerCameraTestRecordKeyAction(key, label, "settings down")
			ui.selectedIndex = (ui.selectedIndex % #category.items) + 1
			return true
		elseif ControllerCameraTestKeyMatches(key, label, { "LEFT", "Left", "left", 276 }) and not category.bindings then
			ControllerCameraTestRecordKeyAction(key, label, "settings decrease")
			local item = category.items[ui.selectedIndex]
			ControllerCameraTestAdjustSettingFromUI(item.key, -1, item.step)
			return true
		elseif ControllerCameraTestKeyMatches(key, label, { "RIGHT", "Right", "right", 275 }) and not category.bindings then
			ControllerCameraTestRecordKeyAction(key, label, "settings increase")
			local item = category.items[ui.selectedIndex]
			ControllerCameraTestAdjustSettingFromUI(item.key, 1, item.step)
			return true
		elseif ControllerCameraTestKeyMatches(key, label, { "TAB", "Tab", "tab", 9 }) then
			ControllerCameraTestRecordKeyAction(key, label, "settings category")
			local delta = mods and mods.shift and -1 or 1
			local categories = ControllerCameraTestGetSettingsUICategories()
			ui.categoryIndex = ((ui.categoryIndex - 1 + delta) % #categories) + 1
			ui.selectedIndex = 1
			return true
		elseif ControllerCameraTestKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", "KP_ENTER", "kpenter", 13, 271 }) then
			ControllerCameraTestRecordKeyAction(key, label, "settings confirm")
			local item = category.items[ui.selectedIndex]
			if category.bindings then
				ControllerCameraTestBindings.captureAction = item.action
				ui.lastAction = "press a controller input for " .. tostring(item.label)
			elseif item.type == "bool" then
				ControllerCameraTestAdjustSettingFromUI(item.key, 1, 1)
			end
			return true
		end
	end
	return false
end

function widget:TextCommand(command)
	local normalized = ControllerCameraTestNormalizeKeyName(command)
	if normalized == "cctdebug" then
		ControllerCameraTestRecordKeyAction("text", command, "toggle debug")
		ControllerCameraTestToggleDebugPanel("/luaui cct_debug")
		return true
	elseif normalized == "ccthelp" then
		ControllerCameraTestRecordKeyAction("text", command, "toggle help")
		ControllerCameraTestToggleHelpOverlay("/luaui cct_help")
		return true
	elseif normalized == "cctsettings" then
		ControllerCameraTestRecordKeyAction("text", command, "toggle settings")
		ControllerCameraTestToggleSettingsFromInput("/luaui cct_settings")
		return true
	elseif normalized == "cctresetsettings" then
		ControllerCameraTestRecordKeyAction("text", command, "reset settings")
		ControllerCameraTestResetSettingsFromInput("/luaui cct_reset_settings")
		return true
	end
	return false
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

	-- 1. Compact / Full toggle button hit detection in header
	local panelHeight = ControllerCameraTestDebugCompact and 120 or debugPanelHeight
	local headerHeight = 22
	local compX1 = debugPanelX + debugPanelWidth - 85
	local compX2 = debugPanelX + debugPanelWidth - 15
	local compY1 = debugPanelY + panelHeight - headerHeight + 2
	local compY2 = debugPanelY + panelHeight - 2
	if x >= compX1 and x <= compX2 and y >= compY1 and y <= compY2 then
		ControllerCameraTestDebugCompact = not ControllerCameraTestDebugCompact
		latchSelectionDebugMessage("Debug compact mode: " .. (ControllerCameraTestDebugCompact and "ON" or "OFF"))
		return true
	end

	-- 2. Section headers click hit detection (only in full mode)
	if not ControllerCameraTestDebugCompact then
		for _, hb in ipairs(ControllerCameraTestDebugSectionHitboxes or {}) do
			if x >= hb.x1 and x <= hb.x2 and y >= hb.y1 and y <= hb.y2 then
				ControllerCameraTestDebugSections[hb.key] = not ControllerCameraTestDebugSections[hb.key]
				latchSelectionDebugMessage("Section " .. tostring(hb.key) .. ": " .. (ControllerCameraTestDebugSections[hb.key] and "Expanded" or "Collapsed"))
				return true
			end
		end
	end

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

function ControllerCameraTestDrawCircle2D(x, y, r, segments)
	segments = segments or 32
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(x, y)
		for i = 0, segments do
			local theta = i * (2 * math.pi / segments)
			gl.Vertex(x + r * math.cos(theta), y + r * math.sin(theta))
		end
	end)
end

function ControllerCameraTestDrawTacticalRadial()
	local menu = ControllerCameraTestTacticalMenu
	if not menu.open then
		return
	end

	local commands = ControllerCameraTestGetTacticalCommands()
	local n = #commands
	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
	local minView = math.min(viewSizeX, viewSizeY)
	local radialScale = ControllerCameraTestSettings.radialScale or 1
	local radius = math.min(430, math.max(160, minView * 0.22 * radialScale))
	local itemW = math.min(180, math.max(86, minView * 0.11 * radialScale))
	local itemH = 40 * radialScale

	gl.Color(0, 0, 0, 0.46)
	ControllerCameraTestDrawCircle2D(cx, cy, radius * 1.28, 42)
	gl.Color(0.95, 0.32, 0.24, 0.74)
	gl.LineWidth(2.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, 44 do
			local theta = i * (2 * math.pi / 44)
			gl.Vertex(cx + radius * math.cos(theta), cy + radius * math.sin(theta))
		end
	end)

	if n <= 0 then
		gl.Color(1, 1, 1, 1)
		gl.Text("No tactical commands", cx, cy, 16, "oc")
		return
	end

	for i, option in ipairs(commands) do
		local angle = ((i - 1) * (2 * math.pi / n)) - (math.pi / 2)
		local x = cx + radius * math.cos(angle)
		local y = cy - radius * math.sin(angle)
		local selected = (i == menu.selectedIndex)
		local label = tostring(option.name or "Command")
		if #label > 18 then
			label = string.sub(label, 1, 16) .. ".."
		end

		if selected then
			gl.Color(0.95, 0.36, 0.26, 0.88)
		else
			gl.Color(0.10, 0.12, 0.15, 0.74)
		end
		gl.Rect(x - itemW / 2, y - itemH / 2, x + itemW / 2, y + itemH / 2)
		gl.Color(selected and 1 or 0.55, selected and 0.92 or 0.7, selected and 0.62 or 0.78, selected and 1 or 0.88)
		gl.LineWidth(selected and 2.5 or 1.2)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(x - itemW / 2, y - itemH / 2)
			gl.Vertex(x + itemW / 2, y - itemH / 2)
			gl.Vertex(x + itemW / 2, y + itemH / 2)
			gl.Vertex(x - itemW / 2, y + itemH / 2)
		end)

		gl.Color(1, 1, 1, selected and 1 or 0.82)
		gl.Text(label, x, y - 5, selected and 13 or 11, "oc")
	end

	local current = commands[menu.selectedIndex]
	gl.Color(0.08, 0.10, 0.13, 0.76)
	ControllerCameraTestDrawCircle2D(cx, cy, radius * 0.36, 30)
	gl.Color(1, 0.92, 0.72, 1)
	gl.Text(current and current.name or "Tactical", cx, cy + 22, 15, "oc")
	gl.Color(1, 1, 1, 0.86)
	gl.Text("A/X stage  B/Y close", cx, cy - 2, 11, "oc")
	if ControllerCameraTestIsQueueModifierActive() then
		gl.Color(0.35, 0.95, 0.65, 1)
		gl.Text("APPEND", cx, cy - 20, 11, "oc")
	end
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end

function ControllerCameraTestDrawQueueIndicator()
	if not ControllerCameraTestIsQueueModifierActive() then
		return
	end
	if not (ControllerCameraTestBuildPlacement.active
		or ControllerCameraTestBuildMenu.open
		or ControllerCameraTestTacticalMenu.open
		or ControllerCameraTestDragCommand.active
		or commandLayerActive)
	then
		return
	end

	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
	gl.Color(0.02, 0.12, 0.06, 0.74)
	gl.Rect(cx - 38, cy + 30, cx + 38, cy + 50)
	gl.Color(0.35, 1.0, 0.62, 0.95)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(cx - 38, cy + 30)
		gl.Vertex(cx + 38, cy + 30)
		gl.Vertex(cx + 38, cy + 50)
		gl.Vertex(cx - 38, cy + 50)
	end)
	gl.Color(0.8, 1, 0.86, 1)
	gl.Text("QUEUE", cx, cy + 35, 12, "oc")
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function ControllerCameraTestDrawPlacementPatternPopup()
	local popup = ControllerCameraTestPlacementPopup
	if not popup or (popup.expireTime or 0) <= debugEventTime then
		return
	end
	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
	local alpha = math.min(1, math.max(0, (popup.expireTime - debugEventTime) * 2))
	local width = math.max(150, (#tostring(popup.text) * 8) + 28)
	local bottom = math.max(38, cy - 116)
	gl.Color(0.02, 0.04, 0.06, 0.84 * alpha)
	gl.Rect(cx - (width / 2), bottom, cx + (width / 2), bottom + 30)
	gl.Color(0.58, 0.84, 1, 0.88 * alpha)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(cx - (width / 2), bottom)
		gl.Vertex(cx + (width / 2), bottom)
		gl.Vertex(cx + (width / 2), bottom + 30)
		gl.Vertex(cx - (width / 2), bottom + 30)
	end)
	gl.Color(0.92, 0.97, 1, alpha)
	gl.Text(tostring(popup.text), cx, bottom + 9, 13, "oc")
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end

function ControllerCameraTestGetReadableUnitName(unitDef)
	if type(unitDef) ~= "table" then
		return "Unit"
	end
	return unitDef.translatedHumanName or unitDef.humanName or unitDef.name or "Unit"
end

function ControllerCameraTestGetSelectedPrimaryUnitInfo()
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local constructorInfo = nil
	for _, unitID in ipairs(selectedUnits) do
		local unitDefID, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if type(unitDef) == "table" then
			local info = {
				unitID = unitID,
				unitDefID = unitDefID,
				unitDef = unitDef,
				name = ControllerCameraTestGetReadableUnitName(unitDef),
			}
			if unitDef.isFactory then
				info.mode = "factory"
				return info
			end
			if not constructorInfo and (unitDef.isBuilder or unitDef.canBuild or unitDef.canAssist
				or (type(unitDef.buildOptions) == "table" and #unitDef.buildOptions > 0))
			then
				info.mode = "constructor"
				constructorInfo = info
			end
		end
	end
	return constructorInfo
end

--------------------------------------------------------------------------------
-- SECTION: Compact selected status panel
--------------------------------------------------------------------------------
function ControllerCameraTestBuildCompactSelectedStatus()
	local status = ControllerCameraTestSelectedStatus
	status.mode = "hidden"
	if not controllerMode or ControllerCameraTestSettingsUI.open or ControllerCameraTestSettings.compactSelectedStatus == false then
		status.lastResult = "hidden: mouse mode or disabled"
		return nil
	end
	if ControllerCameraTestSettings.hideCompactStatusWhenRadialOpen
		and (ControllerCameraTestBuildMenu.open or ControllerCameraTestTacticalMenu.open)
	then
		status.lastResult = "hidden: radial open"
		return nil
	end
	local info = ControllerCameraTestGetSelectedPrimaryUnitInfo()
	if not info then
		status.lastResult = "none selected"
		return nil
	end
	status.mode = info.mode
	status.unitID = info.unitID
	status.unitDefID = info.unitDefID
	status.name = info.name
	status.vanillaCommandPanelStatus = "untouched"

	if info.mode == "factory" then
		if status.refreshUnitID ~= info.unitID or debugEventTime >= (status.nextRefreshTime or 0) then
			ControllerCameraTestRefreshFactoryQueueCounts()
			ControllerCameraTestRefreshFactoryQueueProgress()
			status.refreshUnitID = info.unitID
			status.nextRefreshTime = debugEventTime + 0.12
		end
		status.progress = tonumber(ControllerCameraTestBuildMenu.factoryProgressValue)
		status.currentCmdID = tonumber(ControllerCameraTestBuildMenu.factoryProgressCmdID)
		status.repeatState = "unknown"
		if type(Spring.GetUnitStates) == "function" then
			local ok, states = pcall(Spring.GetUnitStates, info.unitID)
			if ok and type(states) == "table" and states["repeat"] ~= nil then
				status.repeatState = states["repeat"] and "on" or "off"
			end
		end
		status.queueItems = {}
		for cmdID, count in pairs(ControllerCameraTestBuildMenu.factoryQueueCounts or {}) do
			local unitDef = UnitDefs and UnitDefs[-cmdID]
			status.queueItems[#status.queueItems + 1] = {
				cmdID = cmdID,
				unitDefID = -cmdID,
				name = ControllerCameraTestGetReadableUnitName(unitDef),
				count = count,
			}
		end
		table.sort(status.queueItems, function(a, b)
			return tostring(a.name) < tostring(b.name)
		end)
		status.lastResult = "factory"
	else
		status.progress = nil
		status.currentCmdID = nil
		status.queueItems = nil
		status.currentAction = "idle"
		if type(Spring.GetUnitCommands) == "function" then
			local ok, queue = pcall(Spring.GetUnitCommands, info.unitID, 1)
			if ok and type(queue) == "table" and queue[1] then
				status.currentAction = "command " .. tostring(queue[1].id or "active")
			end
		end
		status.lastResult = "constructor"
	end
	return status
end

function ControllerCameraTestDrawCompactSelectedStatusPanel()
	local status = ControllerCameraTestBuildCompactSelectedStatus()
	if not status then
		return
	end
	local screenWidth = viewSizeX > 0 and viewSizeX or 1280
	local left = math.max(14, screenWidth - 310)
	local right = screenWidth - 16
	local bottom = 50
	local top = status.mode == "factory" and 154 or 124
	gl.Color(0.02, 0.04, 0.06, 0.82)
	gl.Rect(left, bottom, right, top)
	gl.Color(0.56, 0.84, 1, 0.7)
	gl.LineWidth(1)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(left, bottom)
		gl.Vertex(right, bottom)
		gl.Vertex(right, top)
		gl.Vertex(left, top)
	end)
	gl.Color(0.82, 0.94, 1, 1)
	gl.Text(status.mode == "factory" and "Factory Status" or "Constructor Status", left + 12, top - 19, 13, "o")
	gl.Color(1, 1, 1, 0.96)
	gl.Text(tostring(status.name), left + 12, top - 39, 13, "o")

	if status.mode == "factory" then
		local currentDefID = status.currentCmdID and -status.currentCmdID or nil
		local currentDef = currentDefID and UnitDefs and UnitDefs[currentDefID] or nil
		local buildText = currentDef and ControllerCameraTestGetReadableUnitName(currentDef) or "Idle"
		if currentDefID then
			gl.Texture("#" .. tostring(currentDefID))
			gl.Color(1, 1, 1, 0.92)
			gl.TexRect(left + 12, bottom + 25, left + 50, bottom + 63)
			gl.Texture(false)
		end
		local progressText = status.progress and (" " .. tostring(math.floor(status.progress * 100 + 0.5)) .. "%") or ""
		gl.Color(0.92, 0.96, 1, 0.95)
		gl.Text("Building: " .. buildText .. progressText, left + 58, bottom + 52, 11, "o")
		gl.Text("Repeat: " .. tostring(status.repeatState) .. "  Queue:", left + 58, bottom + 34, 10, "o")
		local iconX = left + 164
		for i = 1, math.min(3, #(status.queueItems or {})) do
			local item = status.queueItems[i]
			gl.Texture("#" .. tostring(item.unitDefID))
			gl.Color(1, 1, 1, 0.88)
			gl.TexRect(iconX, bottom + 21, iconX + 26, bottom + 47)
			gl.Texture(false)
			gl.Color(1, 0.92, 0.42, 1)
			gl.Text("x" .. tostring(item.count), iconX + 13, bottom + 10, 9, "oc")
			iconX = iconX + 34
		end
		gl.Color(0.66, 0.9, 1, 0.95)
		gl.Text("Y: Factory radial", left + 12, bottom + 7, 10, "o")
	else
		gl.Color(0.92, 0.96, 1, 0.95)
		gl.Text("Action: " .. tostring(status.currentAction or "idle"), left + 12, bottom + 38, 11, "o")
		local placementText = ControllerCameraTestBuildPlacement.active
			and ("Pattern: " .. ControllerCameraTestPlacementPatternLabel(ControllerCameraTestBuildPlacement.placementPattern)
				.. "  Space: " .. tostring(ControllerCameraTestBuildPlacement.placementSpacing or 0))
			or "Ready for construction"
		gl.Text(placementText, left + 12, bottom + 23, 11, "o")
		gl.Color(0.66, 0.9, 1, 0.95)
		gl.Text("Y: Build radial", left + 12, bottom + 7, 10, "o")
	end
	gl.Texture(false)
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end

function ControllerCameraTestDrawControlGroupOverlay()
	local groups = ControllerCameraTestControlGroups
	if not (ControllerCameraTestActionDown("controlGroupModifier") or (groups.visibleUntil or 0) > debugEventTime) then
		return
	end

	local screenWidth = viewSizeX > 0 and viewSizeX or 1280
	local slotSize = 42
	local gap = 5
	local stripWidth = (slotSize * 10) + (gap * 9) + 24
	local left = math.max(12, (screenWidth - stripWidth) * 0.5)
	local bottom = 86
	local top = bottom + slotSize + 34
	local activeSlot = ControllerCameraTestNormalizeControlGroupSlot(groups.activeSlot or 1)

	gl.Color(0, 0, 0, 0.72)
	gl.Rect(left, bottom, left + stripWidth, top)
	gl.Color(0.36, 0.68, 1, 0.65)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(left, bottom)
		gl.Vertex(left + stripWidth, bottom)
		gl.Vertex(left + stripWidth, top)
		gl.Vertex(left, top)
	end)

	gl.Color(0.82, 0.92, 1, 1)
	gl.Text("Controller Groups  Start+Dpad: U/D slot, L recall, R type+future assign, Start+L3 clear", left + 12, top - 18, 12, "o")

	for slot = 1, 10 do
		local x1 = left + 12 + ((slot - 1) * (slotSize + gap))
		local y1 = bottom + 8
		local x2 = x1 + slotSize
		local y2 = y1 + slotSize
		local entry = groups.slots[slot]
		local isActive = slot == activeSlot
		local isRecent = tostring(groups.lastSlot) == ControllerCameraTestGetControlGroupDisplaySlot(slot)

		if isActive then
			gl.Color(0.18, 0.42, 0.78, 0.88)
		elseif entry then
			gl.Color(0.10, 0.18, 0.24, 0.82)
		else
			gl.Color(0.05, 0.07, 0.09, 0.74)
		end
		gl.Rect(x1, y1, x2, y2)

		if entry and entry.unitDefID then
			gl.Texture("#" .. tostring(entry.unitDefID))
			gl.Color(1, 1, 1, isActive and 0.95 or 0.75)
			gl.TexRect(x1 + 5, y1 + 7, x2 - 5, y2 - 5)
			gl.Texture(false)
		end

		gl.Color(isActive and 1 or 0.55, isActive and 0.92 or 0.72, isActive and 0.35 or 0.82, 1)
		gl.LineWidth((isActive or isRecent) and 2.5 or 1)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(x1, y1)
			gl.Vertex(x2, y1)
			gl.Vertex(x2, y2)
			gl.Vertex(x1, y2)
		end)

		gl.Color(1, 1, 1, 1)
		gl.Text(ControllerCameraTestGetControlGroupDisplaySlot(slot), x1 + 4, y2 - 13, 11, "o")
		if entry and (entry.count or 0) > 0 then
			gl.Color(1, 0.92, 0.42, 1)
			gl.Text("x" .. tostring(entry.count), x2 - 4, y1 + 3, 10, "ro")
			if entry.autoAddUnitDefID then
				gl.Color(0.52, 1.0, 0.66, 0.95)
				gl.Text("AUTO", x1 + 4, y1 + 3, 8, "o")
			end
		end
	end

	gl.Color(0.92, 0.96, 1, 1)
	gl.Text("Group " .. ControllerCameraTestGetControlGroupDisplaySlot(activeSlot) .. ": " .. tostring(groups.lastAction), left + 12, bottom - 16, 12, "o")
	gl.Texture(false)
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function ControllerCameraTestDrawBuildRadial()
	local menu = ControllerCameraTestBuildMenu
	if not menu.open then
		return
	end

	if ControllerCameraTestBuildPlacement.active then
		return
	end

	-- Throttled refresh of factory queue counts while radial is drawn
	if Spring.GetGameFrame() % 15 == 0 then
		ControllerCameraTestRefreshFactoryQueueCounts()
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local isFactoryContext = ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits)

	if isFactoryContext then
		ControllerCameraTestRefreshFactoryQueueProgress()
	end

	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)

	local minView = math.min(viewSizeX, viewSizeY)
	local radialScale = ControllerCameraTestSettings.radialScale or 1
	local radius = math.min(520, math.max(200, minView * 0.28 * radialScale))

	local visibleOptions = menu.radialVisibleOptions or {}
	local n = #visibleOptions

	-- 1. Translucent backdrop (large dark circle around the reticle) - opacity halved from 0.72 to 0.36
	gl.Color(0, 0, 0, 0.36)
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

	-- Draw a thin ring - opacity halved from 0.45 to 0.22
	gl.LineWidth(2)
	gl.Color(0.56, 0.84, 1, 0.22)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, 36 do
			local theta = i * (2 * math.pi / 36)
			gl.Vertex(cx + radius * math.cos(theta), cy + radius * math.sin(theta))
		end
	end)

	-- 2. Draw each item
	local iconSize = math.min(145, math.max(56, minView * 0.075 * radialScale))
	for i = 1, n do
		local option = visibleOptions[i]
		local angle = ((i - 1) * (2 * math.pi / n)) - (math.pi / 2)
		local x = cx + radius * math.cos(angle)
		local y = cy - radius * math.sin(angle)

		local isSelected = (option.menuIndex == menu.selectedIndex)

		-- Check affordability
		local affordable, mAff, eAff = ControllerCameraTestCanAffordBuildOption(option)

		if isSelected then
			gl.Color(0.2, 0.6, 1, 0.85)
			gl.Rect(x - iconSize/2 - 4, y - iconSize/2 - 4, x + iconSize/2 + 4, y + iconSize/2 + 4)
			gl.Color(0.85, 0.95, 1, 1)
		else
			if affordable then
				gl.Color(0.12, 0.18, 0.23, 0.42)
			else
				gl.Color(0.32, 0.12, 0.12, 0.42) -- red background tint for unaffordable
			end
			gl.Rect(x - iconSize/2 - 2, y - iconSize/2 - 2, x + iconSize/2 + 2, y + iconSize/2 + 2)
			if affordable then
				gl.Color(0.8, 0.8, 0.8, 0.9)
			else
				gl.Color(0.68, 0.22, 0.22, 0.55) -- red border for unaffordable
			end
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
			local progress = isFactoryContext and option.cmdID and menu.factoryQueueProgress and menu.factoryQueueProgress[option.cmdID]
			if progress and progress >= 0.0 and progress <= 1.0 then
				-- Draw darkened base icon
				gl.Color(0.2, 0.2, 0.2, 0.5)
				gl.TexRect(x - iconSize/2, y - iconSize/2, x + iconSize/2, y + iconSize/2)

				-- Draw bright/full-color version wiped on top according to build progress
				if progress > 0 then
					gl.Scissor(x - iconSize/2, y - iconSize/2, iconSize, iconSize * progress)
					if isSelected then
						gl.Color(1, 1, 1, 1)
					else
						gl.Color(0.85, 0.85, 0.85, 0.9)
					end
					gl.TexRect(x - iconSize/2, y - iconSize/2, x + iconSize/2, y + iconSize/2)
					gl.Scissor(false)
				end
			else
				-- Standard icon drawing
				if isSelected then
					gl.Color(1, 1, 1, 1)
				elseif affordable then
					gl.Color(0.85, 0.85, 0.85, 0.9)
				else
					gl.Color(0.35, 0.3, 0.3, 0.42) -- dim texture for unaffordable
				end
				gl.TexRect(x - iconSize/2, y - iconSize/2, x + iconSize/2, y + iconSize/2)
			end
			gl.Texture(false)
			hasIcon = true
		end

		if not hasIcon then
			gl.Color(1, 1, 1, 1)
			gl.Text(string.sub(option.name, 1, 4), x, y - 6, 12, "oc")
		end

		gl.Color(1, 0.84, 0, 1)
		gl.Text(tostring(i), x - iconSize/2 + 6, y + iconSize/2 - 16, 12, "o")

		-- Draw Factory Queue badge if needed
		if isFactoryContext and option.cmdID and menu.factoryQueueCounts then
			local qCount = menu.factoryQueueCounts[option.cmdID] or 0
			if qCount > 0 then
				local badgeText = "x" .. tostring(qCount)
				local badgeW = 28
				if qCount >= 10 then
					badgeW = 36
				end
				if qCount >= 100 then
					badgeW = 44
				end
				local bx2 = x + iconSize/2 + 3
				local bx1 = bx2 - badgeW
				local by2 = y + iconSize/2 + 3
				local by1 = by2 - 18

				-- Translucent dark glassmorphism badge
				gl.Color(0.04, 0.08, 0.12, 0.88)
				gl.Rect(bx1, by1, bx2, by2)
				gl.Color(0.56, 0.84, 1, 0.7)
				gl.LineWidth(1)
				gl.BeginEnd(GL.LINE_LOOP, function()
					gl.Vertex(bx1, by1)
					gl.Vertex(bx2, by1)
					gl.Vertex(bx2, by2)
					gl.Vertex(bx1, by2)
				end)

				gl.Color(1, 0.95, 0.8, 1)
				gl.Text(badgeText, (bx1 + bx2)/2, by1 + 3, 11, "oc")
			end
		end
	end

	-- 3. Center display details
	local currentOption = ControllerCameraTestGetRadialCurrentOption()
	if currentOption then
		gl.Color(0.2, 0.6, 1, 0.08) -- opacity halved from 0.15 to 0.08
		drawCircle(cx, cy, radius * 0.45, 30)

		gl.Color(0.82, 0.94, 1, 1)
		gl.Text(currentOption.name or "unknown", cx, cy + 42, 16, "oc")

		local mCost = currentOption.metalCost or 0
		local eCost = currentOption.energyCost or 0
		local aff, mAff, eAff = ControllerCameraTestCanAffordBuildOption(currentOption)

		if mCost > 0 and eCost > 0 then
			if mAff then
				gl.Color(0.9, 0.8, 0.1, 1)
			else
				gl.Color(1, 0.25, 0.2, 1)
			end
			gl.Text("M: " .. tostring(mCost), cx - 36, cy + 22, 12, "oc")

			if eAff then
				gl.Color(0.9, 0.8, 0.1, 1)
			else
				gl.Color(1, 0.25, 0.2, 1)
			end
			gl.Text("E: " .. tostring(eCost), cx + 36, cy + 22, 12, "oc")
		elseif mCost > 0 then
			if mAff then
				gl.Color(0.9, 0.8, 0.1, 1)
			else
				gl.Color(1, 0.25, 0.2, 1)
			end
			gl.Text("M: " .. tostring(mCost), cx, cy + 22, 12, "oc")
		elseif eCost > 0 then
			if eAff then
				gl.Color(0.9, 0.8, 0.1, 1)
			else
				gl.Color(1, 0.25, 0.2, 1)
			end
			gl.Text("E: " .. tostring(eCost), cx, cy + 22, 12, "oc")
		end

		if isFactoryContext then
			local qCount = 0
			if menu.factoryQueueCounts and currentOption.cmdID then
				qCount = menu.factoryQueueCounts[currentOption.cmdID] or 0
			end
			if qCount > 0 then
				gl.Color(0.4, 0.85, 1, 1)
				gl.Text("Queued: " .. tostring(qCount), cx, cy + 4, 12, "oc")
			end
		else
			if currentOption.tooltip and currentOption.tooltip ~= "" then
				gl.Color(0.7, 0.7, 0.7, 0.8)
				local tip = string.sub(currentOption.tooltip, 1, 28)
				if #currentOption.tooltip > 28 then tip = tip .. "..." end
				gl.Text(tip, cx, cy + 4, 11, "oc")
			end
		end

		-- Draw context-specific controller hints
		if isFactoryContext then
			gl.Color(0.4, 1.0, 0.4, 0.9)
			gl.Text("[A] +1", cx - 8, cy - 12, 11, "or")
			gl.Color(0.2, 0.9, 0.7, 0.9)
			gl.Text("[LT+A] +5", cx + 8, cy - 12, 11, "ol")

			gl.Color(1.0, 0.4, 0.4, 0.9)
			gl.Text("[B] -1", cx - 8, cy - 25, 11, "or")
			gl.Color(1.0, 0.6, 0.2, 0.9)
			gl.Text("[LT+B] -5", cx + 8, cy - 25, 11, "ol")

			gl.Color(1.0, 0.9, 0.4, 0.9)
			gl.Text("[Y] Close", cx, cy - 38, 11, "oc")
		else
			gl.Color(0.4, 1.0, 0.4, 0.9)
			gl.Text("[A] Place", cx - 8, cy - 16, 11, "or")
			gl.Color(0.4, 0.8, 1.0, 0.9)
			gl.Text("[X] Stay", cx + 8, cy - 16, 11, "ol")
			gl.Color(1.0, 0.4, 0.4, 0.9)
			gl.Text("[B] Cancel", cx - 8, cy - 30, 11, "or")
			gl.Color(1.0, 0.9, 0.4, 0.9)
			gl.Text("[Y] Close", cx + 8, cy - 30, 11, "ol")
		end
	end

	-- 4. Category/Page Indicator
	gl.Color(0.56, 0.84, 1, 0.95)
	local categoryStr = string.upper(menu.radialCategoryName or "Build")
	local pageStr = "PAGE " .. tostring(menu.radialPage) .. "/" .. tostring(menu.radialPageCount)

	gl.Text(categoryStr, cx, cy + radius * 0.65, 18, "oc")
	gl.Color(0.8, 0.8, 0.8, 0.8)
	gl.Text(pageStr, cx, cy - radius * 0.65, 15, "oc")

	gl.Color(0.6, 0.6, 0.6, 0.7)
	gl.Text("LB", cx - radius * 0.4, cy + radius * 0.65, 14, "oc")
	gl.Text("RB", cx + radius * 0.4, cy + radius * 0.65, 14, "oc")

	gl.Color(1, 1, 1, 1)
	gl.Texture(false)
	gl.LineWidth(1)
end

function ControllerCameraTestFormatSettingsUIValue(item)
	if item.type == "bool" then
		return ControllerCameraTestSettings[item.key] and "ON" or "OFF"
	end
	local value = tonumber(ControllerCameraTestSettings[item.key]) or 0
	if item.decimals == 0 then
		return string.format("%.0f", value)
	end
	return string.format("%." .. tostring(item.decimals or 2) .. "f", value)
end

function ControllerCameraTestDrawSettingsUI()
	local ui = ControllerCameraTestSettingsUI
	if not ui.open then
		return
	end
	local categories = ControllerCameraTestGetSettingsUICategories()
	local category = ControllerCameraTestGetSettingsUICategory()
	local width = math.min(720, math.max(500, viewSizeX - 80))
	local height = math.min(570, math.max(420, viewSizeY - 90))
	local left = math.max(20, (viewSizeX - width) * 0.5)
	local bottom = math.max(20, (viewSizeY - height) * 0.5)
	local right = left + width
	local top = bottom + height
	local headerY = top - 34
	local rowHeight = 27

	gl.Color(0.01, 0.025, 0.04, 0.94)
	gl.Rect(left, bottom, right, top)
	gl.Color(0.07, 0.12, 0.17, 0.98)
	gl.Rect(left, headerY, right, top)
	gl.Color(0.58, 0.84, 1, 0.92)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(left, bottom)
		gl.Vertex(right, bottom)
		gl.Vertex(right, top)
		gl.Vertex(left, top)
	end)
	gl.Color(0.84, 0.95, 1, 1)
	gl.Text("Controller Settings", left + 18, top - 23, 18, "o")
	gl.Color(0.72, 0.84, 0.92, 0.92)
	gl.Text("End/Esc close   Home reset all defaults", right - 18, top - 22, 11, "ro")

	local tabX = left + 16
	for index, cat in ipairs(categories) do
		local tabW = math.max(62, (#cat.key * 7) + 18)
		if index == ui.categoryIndex then
			gl.Color(0.16, 0.40, 0.62, 0.88)
			gl.Rect(tabX, headerY - 37, tabX + tabW, headerY - 8)
		end
		gl.Color(index == ui.categoryIndex and 1 or 0.68, index == ui.categoryIndex and 0.95 or 0.78, 1, 1)
		gl.Text(cat.key, tabX + 9, headerY - 27, 12, "o")
		tabX = tabX + tabW + 5
	end

	local listTop = headerY - 62
	local visibleRows = math.max(5, math.floor((height - 144) / rowHeight))
	local firstRow = math.max(1, math.min(ui.selectedIndex - math.floor(visibleRows / 2), #category.items - visibleRows + 1))
	local lastRow = math.min(#category.items, firstRow + visibleRows - 1)
	local drawY = listTop
	for index = firstRow, lastRow do
		local item = category.items[index]
		local selected = index == ui.selectedIndex
		if selected then
			gl.Color(0.13, 0.30, 0.44, 0.9)
			gl.Rect(left + 18, drawY - 7, right - 18, drawY + 18)
		end
		gl.Color(selected and 0.94 or 0.79, selected and 0.98 or 0.84, selected and 1 or 0.9, 1)
		gl.Text(category.bindings and item.label or item.label, left + 30, drawY, 14, "o")
		if category.bindings then
			gl.Color(0.65, 0.9, 1, 1)
			gl.Text(ControllerCameraTestBindingLabel(ControllerCameraTestGetBinding(item.action)), right - 34, drawY, 14, "ro")
		else
			local value = ControllerCameraTestFormatSettingsUIValue(item)
			gl.Color(item.type == "bool" and (ControllerCameraTestSettings[item.key] and 0.44 or 0.94) or 0.65,
				item.type == "bool" and (ControllerCameraTestSettings[item.key] and 1 or 0.62) or 0.9,
				item.type == "bool" and 0.64 or 1, 1)
			gl.Text(value, right - 34, drawY, 14, "ro")
		end
		drawY = drawY - rowHeight
	end

	local footer = category.bindings
		and "A/Enter capture  X reset binding  Y reset all bindings  B/Esc close"
		or "D-pad/arrows adjust  A toggle  X reset selected  Y reset category  LB/RB or Tab change tab"
	gl.Color(0.68, 0.84, 0.96, 0.95)
	gl.Text(footer, left + 18, bottom + 35, 12, "o")
	if ControllerCameraTestBindings.captureAction then
		gl.Color(0.10, 0.23, 0.30, 0.95)
		gl.Rect(left + 20, bottom + 55, right - 20, bottom + 91)
		gl.Color(1, 0.92, 0.48, 1)
		gl.Text("Listening: press a controller input for " .. tostring(ControllerCameraTestBindings.captureAction) .. " (B cancels)", left + 34, bottom + 69, 14, "o")
	elseif category.bindings and ControllerCameraTestBindings.conflictAction then
		gl.Color(1, 0.76, 0.36, 0.95)
		gl.Text("Shared binding warning: also used by " .. tostring(ControllerCameraTestBindings.conflictAction), left + 20, bottom + 62, 12, "o")
	end
	gl.Color(0.76, 0.86, 0.95, 0.95)
	gl.Text("Last: " .. tostring(ui.lastAction or ControllerCameraTestBindings.lastAction), left + 18, bottom + 15, 11, "o")
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end

--------------------------------------------------------------------------------
-- SECTION: Debug/help UI drawing
--------------------------------------------------------------------------------
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
		"Camera/Move: LS pan | RS X rotate | RS Y zoom | LB+RS Y pitch | LT: Camera speed modifier",
		"Selection: A select | A hold area-select units first | append modifier + A hold includes buildings",
		"Double-tap A on unit: visible same type | append modifier + double-tap A on unit: all owned same type | empty: no action",
		"Back/View: command layer modifier; Back/View + double-tap A focuses/selects Commander | Start/Menu: group layer",
		"Left Stick Click: Remove current/next queued command | Right Stick Click: Remove last queued command",
		"append modifier + double-tap A on empty reticle: select all idle units in current idle type",
		"Context Actions: X tap context | X hold one unit draw queued path | X hold many units line/spread | Layer+B stop | Layer+X attack/fight",
		"Combat Layers: Back+RB toggles tactical radial | LS/Dpad choose | A/X stage target command | A confirm staged | B/Y close/cancel",
		"Append Queue: hold RT/bound append modifier to add commands/builds to the end",
		"Do Next: hold bound insert modifier to insert near the front",
		"Constructor Radial: Y open | LS/Dpad select | LB/RB page | Y close",
		"   * A enter placement | X quick-place | B close radial",
		"Factory Radial: Y open | LS/Dpad select | LB/RB page | Y close",
		"   * A add 1 queue | append modifier + A add 5 queue | B remove 1 | append modifier + B remove 5",
		"Placement Mode: A place | X place+stay | B cancel | RT append queue | bound insert modifier fronts",
		"   * RS X camera rotate | Dpad L/R building facing | Dpad U/D spacing | LB tap pattern/hold grid | A/X hold Line/Grid",
		"Idle Cycling: Dpad L/R idle unit | LB+Dpad L/R idle type | Dpad U/D recall cam | bound modifier + Dpad U/D store cam",
		"Control Groups: hold Start/Menu overlay | Start+Dpad U/D slot | Start+Dpad L recall | Start+Dpad R same-type/future assign",
		"Control Groups: Start+L3 clear | Start/Menu uses D-pad/L3 only, not ABXY",
		"Status: controller mode shows compact factory/constructor activity panel; Y opens its radial",
		"System UI: End Controller Settings | Page Up Debug | Page Down Help | Home Reset Settings Defaults",
		"Fallback UI commands: /luaui cct_debug | cct_help | cct_settings | cct_reset_settings",
		"Settings UI: D-pad/arrows adjust | LB/RB or Tab categories | A/Enter select | B/Escape close | X/Y reset",
		"Bindings tab: A capture next input | B cancel capture | X reset binding | Y reset all bindings",
		"Settings: saved ControllerCameraTestSettings override edited defaults after reload; Home applies code defaults",
		"Tuning Selection: " .. ControllerCameraTestCurrentSettingLabel(),
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
		local colorIsHeader = i == 1
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
	if not ControllerCameraTestSettingsUI.open and ControllerCameraTestBuildMenu.open then
		ControllerCameraTestDrawBuildRadial()
	end
	if not ControllerCameraTestSettingsUI.open and ControllerCameraTestTacticalMenu.open then
		ControllerCameraTestDrawTacticalRadial()
	end
	if not ControllerCameraTestSettingsUI.open then
		ControllerCameraTestDrawQueueIndicator()
		ControllerCameraTestDrawPlacementPatternPopup()
	end
	ControllerCameraTestDrawCompactSelectedStatusPanel()
	if not ControllerCameraTestSettingsUI.open then
		ControllerCameraTestDrawControlGroupOverlay()
	end
	if ControllerCameraTestSettings.helpOverlayVisible then
		ControllerCameraTestDrawHelpOverlay()
	end
	ControllerCameraTestDrawSettingsUI()
	if ControllerCameraTestSettingsUI.open then
		return
	end
	if not ControllerCameraTestSettings.debugPanelVisible then
		return
	end
	ControllerCameraTestUpdateMemoryDebug()

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
	local function drawSection(section, drawX, drawY, maxChars, contentBottom, columnWidth)
		if drawY < contentBottom then
			return drawY, false
		end

		local isExpanded = ControllerCameraTestDebugSections[section.key]
		if isExpanded == nil then
			isExpanded = true
		end

		local arrow = isExpanded and "[-] " or "[+] "
		local displayTitle = arrow .. section.title

		if section.key then
			table.insert(ControllerCameraTestDebugSectionHitboxes, {
				key = section.key,
				x1 = drawX,
				y1 = drawY - 3,
				x2 = drawX + columnWidth,
				y2 = drawY + 16,
			})
		end

		gl.Color(0.62, 0.86, 1, 1)
		drawLine(displayTitle, drawX, drawY)
		gl.Color(1, 1, 1, 1)
		drawY = drawY - 17

		if not isExpanded then
			return drawY - 6, true
		end

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
	local panelHeight = ControllerCameraTestDebugCompact and 120 or debugPanelHeight
	local panelRight = panelLeft + panelWidth
	local panelTop = panelBottom + panelHeight
	local padding = 8 -- Freed DEBUG_PANEL_PADDING upvalue
	local headerHeight = 22 -- Freed DEBUG_PANEL_HEADER_HEIGHT upvalue
	local useColumns = (not ControllerCameraTestDebugCompact) and (panelWidth >= 720)
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

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local isFactoryRadialVal = ControllerCameraTestBuildMenu.open and ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits)
	local isFactoryRadial = yesNo(isFactoryRadialVal)
	local currentOption = ControllerCameraTestGetRadialCurrentOption()
	local highlightedQueueCount = 0
	if currentOption and currentOption.cmdID and ControllerCameraTestBuildMenu.factoryQueueCounts then
		highlightedQueueCount = ControllerCameraTestBuildMenu.factoryQueueCounts[currentOption.cmdID] or 0
	end
	local hasQueueCounts = "no"
	if ControllerCameraTestBuildMenu.factoryQueueCounts then
		for _, count in pairs(ControllerCameraTestBuildMenu.factoryQueueCounts) do
			if count > 0 then
				hasQueueCounts = "yes"
				break
			end
		end
	end

	local factoryProgressKnown = "no"
	local factoryProgressCmdID = "none"
	local factoryProgressValue = "none"
	local factoryProgressSource = "none"
	if isFactoryRadialVal and currentOption and currentOption.cmdID and ControllerCameraTestBuildMenu.factoryQueueProgress then
		local progress = ControllerCameraTestBuildMenu.factoryQueueProgress[currentOption.cmdID]
		if progress then
			factoryProgressKnown = "yes"
			factoryProgressCmdID = tostring(currentOption.cmdID)
			factoryProgressValue = string.format("%.2f", progress)
			factoryProgressSource = tostring(ControllerCameraTestBuildMenu.factoryProgressSource or "GetUnitIsBuilding")
		end
	end
	if factoryProgressKnown ~= "yes" and ControllerCameraTestBuildMenu.factoryProgressKnown == "yes" then
		factoryProgressKnown = "yes"
		factoryProgressCmdID = tostring(ControllerCameraTestBuildMenu.factoryProgressCmdID or "none")
		factoryProgressValue = tostring(ControllerCameraTestBuildMenu.factoryProgressValue or "none")
		factoryProgressSource = tostring(ControllerCameraTestBuildMenu.factoryProgressSource or "none")
	end
	local activeGroupSlot = ControllerCameraTestNormalizeControlGroupSlot(ControllerCameraTestControlGroups.activeSlot or 1)
	local activeGroupEntry = ControllerCameraTestControlGroups.slots[activeGroupSlot]
	local activeGroupType = activeGroupEntry and (activeGroupEntry.typeName or ControllerCameraTestUnitTypeName(activeGroupEntry.unitDefID)) or "none"
	local activeGroupAuto = ControllerCameraTestControlGroupAutoAddLabel(activeGroupEntry)
	local activeGroupCount = activeGroupEntry and tostring(activeGroupEntry.count or #(activeGroupEntry.units or {})) or "0"

	local controllerSections = {
		{
			key = "Input",
			title = "Input / Controller",
			lines = {
				"Widget: Controller Camera Test",
				"API: " .. yesNo(apiAvailable),
				"Name: " .. tostring(controllerName),
				"instanceID: " .. tostring(controllerInstanceId),
				"Input: " .. (controllerMode and "controller" or "mouse"),
				"Mode: " .. tostring(ControllerCameraTestLayerDebug.modeSummary),
				"Raw state: " .. tostring(rawControllerStateStatus),
				"Raw axes: " .. tostring(rawAxesSummary),
				"Raw buttons: " .. tostring(rawButtonsSummary),
				"Held: " .. heldButtonsSummary,
				"Pressed recent: " .. pressedRecentlySummary,
				"Released recent: " .. releasedRecentlySummary,
				string.format("LS: x=%.3f y=%.3f", normalizedLeftX, normalizedLeftY),
				string.format("RS: x=%.3f y=%.3f", normalizedRightX, normalizedRightY),
				string.format("LT: %.3f", normalizedLeftTrigger),
				string.format("RT: %.3f", normalizedRightTrigger),
				"Active axes: " .. activeAxesSummary,
			},
		},
		{
			key = "Reticle",
			title = "Reticle",
			lines = {
				"Reticle visible: " .. yesNo(reticleVisible),
				string.format("Screen: x=%.1f y=%.1f", screenCenterX, screenCenterY),
				"World: " .. reticleWorldSummary,
				"Target type: " .. reticleTargetType,
				"Has world target: " .. yesNo(reticleHasWorldTarget),
			},
		},
		{
			key = "Selection",
			title = "Selection",
			lines = {
				"Selection test: " .. yesNo(selectionTestActive),
				"Last selected unitID: " .. tostring(lastReticleSelectedUnitID),
				"Selection result: " .. lastSelectionResult,
				"Last B-button result: " .. tostring(lastBButtonResult),
				"Last clear-selection result: " .. tostring(lastClearSelectionResult),
				"Selection msg: " .. selectionDebugMessage,
				"Cycle: " .. tostring(ControllerCameraTestCycleDebug.lastResult) .. " count=" .. tostring(ControllerCameraTestCycleDebug.lastCount),
			},
		},
		{
			key = "Bookmarks",
			title = "Bookmarks",
			lines = {
				"Bookmark: " .. tostring(ControllerCameraTestBookmarkDebug.lastResult),
			},
		},
		{
			key = "IdleCycle",
			title = "Idle Unit Cycling",
			lines = {
				"Idle result: " .. tostring(ControllerCameraTestIdleCycle.lastResult),
				"Idle unitID: " .. tostring(ControllerCameraTestIdleCycle.currentUnitID or "none"),
				"Idle type: " .. tostring(ControllerCameraTestIdleCycle.lastTypeName),
				"Idle count/type count: " .. tostring(ControllerCameraTestIdleCycle.lastCount),
				"Idle selected all count: " .. tostring(ControllerCameraTestIdleCycle.selectedAllCount),
			},
		},
		{
			key = "ControlGroups",
			title = "Controller Groups",
			lines = {
				"Active group slot: " .. ControllerCameraTestGetControlGroupDisplaySlot(ControllerCameraTestControlGroups.activeSlot or 1),
				"Group active type/count: " .. tostring(activeGroupType) .. " x" .. tostring(activeGroupCount),
				"Group auto-add type: " .. tostring(activeGroupAuto),
				"Group last action: " .. tostring(ControllerCameraTestControlGroups.lastAction),
				"Group last slot: " .. tostring(ControllerCameraTestControlGroups.lastSlot),
				"Group last count: " .. tostring(ControllerCameraTestControlGroups.lastCount),
				"Group left input: " .. tostring(ControllerCameraTestControlGroups.leftInputState),
				"Group native autogroup: " .. tostring(ControllerCameraTestControlGroups.nativeAutogroupStatus or "none"),
			},
		},
		{
			key = "QuickGroups",
			title = "Quick Groups",
			lines = {
				"Quick group: " .. tostring(ControllerCameraTestQuickGroups.lastResult) .. " slot=" .. tostring(ControllerCameraTestQuickGroups.lastSlot),
			},
		},
		{
			key = "Tuning",
			title = "Tuning",
			lines = {
				"Tuning: " .. ControllerCameraTestCurrentSettingLabel(),
				"Tuning action: " .. tostring(ControllerCameraTestTuning.lastAction),
				"Settings UI: End | Reset all settings: Home",
				"Settings source: saved config; Home resets code defaults",
				"Settings UI open: " .. yesNo(ControllerCameraTestSettingsUI.open),
				"External binding UI open: " .. yesNo(ControllerCameraTestExternalBindingUI.open),
				"External binding UI action: " .. tostring(ControllerCameraTestExternalBindingUI.lastAction),
				"Settings category: " .. tostring(ControllerCameraTestSettingsUI.lastCategory),
				"Binding capture: " .. tostring(ControllerCameraTestBindings.captureAction or "none"),
				"Binding result: " .. tostring(ControllerCameraTestBindings.lastAction),
				"Last key: key=" .. tostring(ControllerCameraTestKeyDebug.rawKey) .. " label=" .. tostring(ControllerCameraTestKeyDebug.label),
				"Last key action: " .. tostring(ControllerCameraTestKeyDebug.matchedAction),
				"Last UI toggle: " .. tostring(ControllerCameraTestKeyDebug.lastUIToggle),
				string.format("Thresholds X/A/group: %.2f / %.2f / %.2f", ControllerCameraTestSettings.xHoldSeconds, ControllerCameraTestSettings.aHoldSeconds, ControllerCameraTestSettings.controlGroupAssignHoldSeconds),
				string.format("Radial scale groundwork: %.2f", ControllerCameraTestSettings.radialScale),
			},
		},
	}
	local cameraSections = {
		{
			key = "Camera",
			title = "Camera",
			lines = {
				"Camera: " .. tostring(cameraState.name or cameraMode) .. " mode=" .. tostring(cameraState.mode or cameraModeId),
				"RS Y mode: " .. rightStickYMode,
				"LT boost pan+zoom: " .. activeInactive(fastPanActive),
				"LB camera mod: " .. activeInactive(lbCameraModifierActive),
				"Pan active: " .. yesNo(panActive),
				"Zoom active: " .. yesNo(zoomActive),
				"Rotate active: " .. yesNo(rotationActive),
				"Pitch active: " .. yesNo(pitchActive),
				string.format("Zoom speed: %.1fx", zoomSpeedMultiplier),
				string.format("Pan speed setting: %.0f", ControllerCameraTestSettings.panSpeed),
				string.format("Rotate/Pitch: %.2f / %.2f", ControllerCameraTestSettings.rotationSpeed, ControllerCameraTestSettings.pitchSpeed),
				string.format("Smoothing/curves: %.2f / %.2f / %.2f", ControllerCameraTestSettings.cameraSmoothing, ControllerCameraTestSettings.stickCurve, ControllerCameraTestSettings.triggerCurve),
				string.format("Deadzones stick/trigger: %.0f / %.0f", ControllerCameraTestSettings.stickDeadzone, ControllerCameraTestSettings.triggerDeadzone),
				"Zoom method: " .. zoomMethod,
				"Rotate method: " .. rotationMethod,
				"Pitch method: " .. pitchMethod,
				"px/py/pz: " .. formatNumber(cameraState.px) .. " / " .. formatNumber(cameraState.py) .. " / " .. formatNumber(cameraState.pz),
				"dist: " .. formatNumber(cameraState.dist),
				"height/old: " .. formatNumber(cameraState.height) .. " / " .. formatNumber(cameraState.oldHeight),
				"rx/ry/rz: " .. formatNumber(cameraState.rx) .. " / " .. formatNumber(cameraState.ry) .. " / " .. formatNumber(cameraState.rz),
				"dx/dy/dz: " .. formatNumber(cameraState.dx) .. " / " .. formatNumber(cameraState.dy) .. " / " .. formatNumber(cameraState.dz),
				"fov: " .. formatNumber(cameraState.fov),
				"Pitch field: " .. cameraPitchSummary,
			},
		},
		{
			key = "Commands",
			title = "Commands",
			lines = {
				"Command layer: " .. activeInactive(commandLayerActive),
				"Layout: " .. activeButtonLayoutSummary,
				"Normal preview: " .. normalPreviewSummary,
				"Command preview: " .. commandPreviewSummary,
				"Command action: " .. tostring(ControllerCameraTestLayerDebug.commandLayerAction),
				"Normal utility: " .. tostring(ControllerCameraTestLayerDebug.normalUtilityAction),
				"Append queue active: " .. yesNo(ControllerCameraTestIsQueueModifierActive()),
				"Insert front active: " .. yesNo(ControllerCameraTestIsQueueFrontModifierActive()),
				"Single path active: " .. yesNo(ControllerCameraTestDragCommand.singleUnitPathActive),
				"Single path waypoints: " .. tostring(ControllerCameraTestDragCommand.singleUnitWaypointCount or 0),
				"Single path result: " .. tostring(ControllerCameraTestDragCommand.singleUnitPathResult),
				"Default cmd index: " .. tostring(ControllerCameraTestCommandDebug.defaultCmdIndex),
				"Default cmd ID: " .. tostring(ControllerCameraTestCommandDebug.defaultCmdID),
				"Default cmd type: " .. tostring(ControllerCameraTestCommandDebug.defaultCmdType),
				"Default cmd name: " .. tostring(ControllerCameraTestCommandDebug.defaultCmdName),
				"Is build: " .. tostring(ControllerCameraTestCommandDebug.isBuild),
				"Issued cmd ID: " .. tostring(ControllerCameraTestCommandDebug.issuedCmdID),
				"Issued params count: " .. tostring(ControllerCameraTestCommandDebug.issuedParamsCount),
				"Last command options: " .. tostring(ControllerCameraTestCommandDebug.lastOptions),
				"Last command result: " .. tostring(ControllerCameraTestCommandDebug.lastResult),
				"Last issued command: " .. tostring(lastIssuedCommand),
				"Queue removal mode: " .. tostring(ControllerCameraTestCommandDebug.queueRemovalMode),
				"Queue removal selected/attempted/removed: " .. tostring(ControllerCameraTestCommandDebug.queueRemovalSelectedCount) .. " / " .. tostring(ControllerCameraTestCommandDebug.queueRemovalAttemptedCount) .. " / " .. tostring(ControllerCameraTestCommandDebug.queueRemovalRemovedCount),
				"Queue removal last q/tag: " .. tostring(ControllerCameraTestCommandDebug.queueRemovalLastQueueSize) .. " / " .. tostring(ControllerCameraTestCommandDebug.queueRemovalLastTag),
				"Queue removal units: " .. tostring(ControllerCameraTestCommandDebug.queueRemovalUnitDetails),
				"Mex smart available: " .. tostring(ControllerCameraTestCommandDebug.mexSmartAvailable),
				"Mex nearest spot: " .. tostring(ControllerCameraTestCommandDebug.mexNearestSpot),
				"Mex building cmd ID: " .. tostring(ControllerCameraTestCommandDebug.mexBuildingCmdID),
				"Mex action result: " .. tostring(ControllerCameraTestCommandDebug.mexActionResult),
				"Mex ApplyPreviewCmds: " .. tostring(ControllerCameraTestCommandDebug.mexApplyPreviewPath),
				"Mex fallback GiveOrder: " .. tostring(ControllerCameraTestCommandDebug.mexFallbackGiveOrderPath),
			},
		},
		{
			key = "AreaSelect",
			title = "Area Select",
			lines = {
				"Area active: " .. yesNo(ControllerCameraTestAreaSelect.active),
				"Area radius: " .. tostring(math.floor(ControllerCameraTestAreaSelect.radius)),
				"Area filter: " .. tostring(ControllerCameraTestAreaSelect.filterMode),
				"Double-tap action: " .. tostring(ControllerCameraTestAreaSelect.doubleTapAction),
				"Same-type target: " .. tostring(ControllerCameraTestAreaSelect.sameTypeTarget) .. " defID=" .. tostring(ControllerCameraTestAreaSelect.sameTypeUnitDefID),
				"Same-type source/count: " .. tostring(ControllerCameraTestAreaSelect.sameTypeSource) .. " candidates=" .. tostring(ControllerCameraTestAreaSelect.sameTypeCandidateCount) .. " selected=" .. tostring(ControllerCameraTestAreaSelect.sameTypeSelectedCount),
				"Area result: " .. tostring(ControllerCameraTestAreaSelect.lastResult) .. " count=" .. tostring(ControllerCameraTestAreaSelect.lastCount),
				"Area select debug: " .. tostring(ControllerCameraTestLayerDebug.areaSelect),
			},
		},
		{
			key = "TacticalMenu",
			title = "Tactical Menu",
			lines = {
				"Tactical open: " .. yesNo(ControllerCameraTestTacticalMenu.open),
				"Tactical radial visible: " .. yesNo(ControllerCameraTestTacticalMenu.open),
				"Tactical command: " .. tostring(ControllerCameraTestTacticalMenu.highlightedName),
				"Tactical staged: " .. tostring(ControllerCameraTestTacticalMenu.stagedName),
				"Tactical stage state: " .. tostring(ControllerCameraTestTacticalMenu.stagedState),
				"Tactical repeat: " .. yesNo(ControllerCameraTestTacticalMenu.repeatPlacementActive) .. " (" .. tostring(ControllerCameraTestTacticalMenu.repeatPlacementState) .. ")",
				"Tactical result: " .. tostring(ControllerCameraTestTacticalMenu.lastResult),
			},
		},
		{
			key = "Memory",
			title = "Lua Memory Audit",
			lines = {
				"Lua KB: " .. tostring(ControllerCameraTestMemoryDebug.luaKB),
				"Lua MB: " .. tostring(ControllerCameraTestMemoryDebug.luaMB),
				"Lua delta/max KB: " .. tostring(ControllerCameraTestMemoryDebug.deltaKB) .. " / " .. tostring(ControllerCameraTestMemoryDebug.maxLuaKB),
				"Controller connected: " .. tostring(ControllerCameraTestMemoryDebug.controllerConnected),
				"Active mode: " .. tostring(ControllerCameraTestMemoryDebug.mode),
				"Button event count: " .. tostring(ControllerCameraTestMemoryDebug.buttonEventCount),
				"Tactical open count: " .. tostring(ControllerCameraTestMemoryDebug.tacticalOpenCount),
				"Hitbox/debug rows: " .. tostring(ControllerCameraTestMemoryDebug.hitboxCount) .. " / " .. tostring(ControllerCameraTestMemoryDebug.debugRowCount),
				"Sample: " .. tostring(ControllerCameraTestMemoryDebug.lastResult),
				"Audit: " .. tostring(ControllerCameraTestMemoryDebug.audit),
			},
		},
		{
			key = "BuildMenu",
			title = "Build Menu / Placement",
			lines = {
				"Open: " .. yesNo(ControllerCameraTestBuildMenu.open),
				"Option count: " .. tostring(ControllerCameraTestBuildMenu.optionCount),
				"Highlight index: " .. tostring(ControllerCameraTestBuildMenu.selectedIndex) .. " / " .. tostring(ControllerCameraTestBuildMenu.optionCount),
				"Highlight name: " .. tostring(ControllerCameraTestBuildMenu.highlightedName),
				"Highlight cmdID: " .. tostring(ControllerCameraTestBuildMenu.highlightedCmdID),
				"Options: " .. ControllerCameraTestGetBuildOptionSummary(),
				"Placement active: " .. yesNo(ControllerCameraTestBuildPlacement.active),
				"Placement facing: " .. tostring(ControllerCameraTestBuildPlacement.facing),
				"Append queue active: " .. yesNo(ControllerCameraTestBuildPlacement.queueActive),
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
				"Placement pattern: " .. tostring(ControllerCameraTestBuildPlacement.placementPattern),
				"Placement spacing: " .. tostring(ControllerCameraTestBuildPlacement.placementSpacing),
				"Placement input: RS X camera, D-pad L/R facing",
				"Placement popup: " .. tostring(ControllerCameraTestPlacementPopup.lastResult),
				"Insert front active: " .. yesNo(ControllerCameraTestBuildPlacement.queueFrontActive),
				"Last construction shortcut: " .. tostring(ControllerCameraTestBuildPlacement.lastConstructionShortcut),
				"Grid shortcut result: " .. tostring(ControllerCameraTestBuildPlacement.gridShortcutResult),
				"Factory radial: " .. tostring(isFactoryRadial),
				"Highlighted queue count: " .. tostring(highlightedQueueCount),
				"Last factory queue action: " .. tostring(ControllerCameraTestBuildMenu.radialLastAction or "none"),
				"Factory queue counts known: " .. tostring(hasQueueCounts),
				"Factory progress known: " .. tostring(factoryProgressKnown),
				"Factory progress cmdID: " .. tostring(factoryProgressCmdID),
				"Factory progress value: " .. tostring(factoryProgressValue),
				"Factory progress source: " .. tostring(factoryProgressSource),
				"Drag active: " .. yesNo(ControllerCameraTestDragCommand.active),
				"Drag mode: " .. tostring(ControllerCameraTestDragCommand.mode),
				"Drag start: " .. (ControllerCameraTestDragCommand.startX and string.format("%.0f, %.0f, %.0f", ControllerCameraTestDragCommand.startX, ControllerCameraTestDragCommand.startY, ControllerCameraTestDragCommand.startZ) or "nil"),
				"Drag end: " .. (ControllerCameraTestDragCommand.endX and string.format("%.0f, %.0f, %.0f", ControllerCameraTestDragCommand.endX, ControllerCameraTestDragCommand.endY, ControllerCameraTestDragCommand.endZ) or "nil"),
				"Drag preview points count: " .. tostring(ControllerCameraTestDragCommand.previewPoints and #ControllerCameraTestDragCommand.previewPoints or 0),
				"Drag last result: " .. tostring(ControllerCameraTestDragCommand.lastResult),
				"Drag native route used: " .. yesNo(ControllerCameraTestDragCommand.nativeRouteUsed),
				"Native blueprint preview route: " .. tostring(ControllerCameraTestDragCommand.nativeRouteName),
				"Native preview result: " .. tostring(ControllerCameraTestDragCommand.nativePreviewResult),
				"Custom grid fallback: " .. tostring(ControllerCameraTestDragCommand.customGridFallback),
				"Compact selected status: " .. tostring(ControllerCameraTestSelectedStatus.mode),
				"Vanilla command panel: " .. tostring(ControllerCameraTestSelectedStatus.vanillaCommandPanelStatus),
			},
		},
	}

	local debugRowCount = 0
	for _, section in ipairs(controllerSections) do
		debugRowCount = debugRowCount + 1 + #(section.lines or {})
	end
	for _, section in ipairs(cameraSections) do
		debugRowCount = debugRowCount + 1 + #(section.lines or {})
	end
	ControllerCameraTestMemoryDebug.debugRowCount = debugRowCount

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

	ControllerCameraTestDebugSectionHitboxes = {}

	local textX = panelLeft + padding
	local textY = panelTop - 15
	gl.Text("Controller Debug", textX, textY, 15, "o")

	-- Draw Toggle Button
	local btnText = ControllerCameraTestDebugCompact and " [Full] " or "[Compact]"
	gl.Color(0.2, 0.4, 0.6, 0.6)
	gl.Rect(panelRight - 85, panelTop - headerHeight + 3, panelRight - 15, panelTop - 3)
	gl.Color(1, 1, 1, 1)
	gl.Text(btnText, panelRight - 80, panelTop - 15, 12, "o")

	textY = panelTop - headerHeight - padding - 10

	if ControllerCameraTestDebugCompact then
		local compactLines = {
			"Mode: " .. tostring(ControllerCameraTestLayerDebug.modeSummary) .. " | Held: " .. heldButtonsSummary .. " | Pressed: " .. pressedRecentlySummary,
			"Idle: " .. tostring(ControllerCameraTestIdleCycle.lastTypeName) .. " x" .. tostring(ControllerCameraTestIdleCycle.lastCount) .. " | Group " .. ControllerCameraTestGetControlGroupDisplaySlot(activeGroupSlot) .. " " .. tostring(activeGroupType) .. " x" .. tostring(activeGroupCount) .. " | A2: " .. tostring(ControllerCameraTestAreaSelect.doubleTapAction),
			"Append: " .. yesNo(ControllerCameraTestIsQueueModifierActive()) .. " | Insert: " .. yesNo(ControllerCameraTestIsQueueFrontModifierActive()) .. " | Settings: " .. yesNo(ControllerCameraTestSettingsUI.open) .. " | External UI: " .. yesNo(ControllerCameraTestExternalBindingUI.open) .. " | Tactical: " .. yesNo(ControllerCameraTestTacticalMenu.open) .. " | Build: " .. yesNo(ControllerCameraTestBuildMenu.open),
			"Key: " .. tostring(ControllerCameraTestKeyDebug.rawKey) .. " " .. tostring(ControllerCameraTestKeyDebug.label) .. " -> " .. tostring(ControllerCameraTestKeyDebug.matchedAction),
			"Radial: " .. yesNo(ControllerCameraTestBuildMenu.open) .. " | Cat: " .. tostring(ControllerCameraTestBuildMenu.radialCategoryName) .. " | Highlight: " .. tostring(ControllerCameraTestBuildMenu.highlightedName) .. " (Q:" .. tostring(highlightedQueueCount) .. (factoryProgressKnown == "yes" and " P:" .. factoryProgressValue or "") .. ")",
			"Placement: " .. tostring(ControllerCameraTestBuildPlacement.placementMode or "none") .. " | Pattern: " .. tostring(ControllerCameraTestBuildPlacement.placementPattern) .. " | Spacing: " .. tostring(ControllerCameraTestBuildPlacement.placementSpacing),
			"Drag: Act=" .. yesNo(ControllerCameraTestDragCommand.active) .. " Mode=" .. tostring(ControllerCameraTestDragCommand.mode) .. " Pts=" .. tostring(ControllerCameraTestDragCommand.previewPoints and #ControllerCameraTestDragCommand.previewPoints or 0) .. " Path=" .. tostring(ControllerCameraTestDragCommand.singleUnitWaypointCount or 0) .. " Route=" .. (ControllerCameraTestDragCommand.nativeRouteUsed and "Native" or "Fallback"),
			"Last Action: " .. tostring(ControllerCameraTestBuildMenu.lastAction or "none") .. " | Result: " .. tostring(ControllerCameraTestBuildMenu.radialLastAction or "none"),
			"Selection Msg: " .. selectionDebugMessage .. " | Last cmd: " .. tostring(lastIssuedCommand)
		}

		for _, line in ipairs(compactLines) do
			if textY < contentBottom then
				break
			end
			drawLine(line, textX, textY)
			textY = textY - 17
		end
	else
		if useColumns then
			local rightX = textX + columnWidth + columnGap
			local leftY = textY
			local rightY = textY

			for _, section in ipairs(controllerSections) do
				leftY = drawSection(section, textX, leftY, maxChars, contentBottom, columnWidth)
			end
			for _, section in ipairs(cameraSections) do
				rightY = drawSection(section, rightX, rightY, maxChars, contentBottom, columnWidth)
			end
		else
			for _, section in ipairs(controllerSections) do
				textY = drawSection(section, textX, textY, maxChars, contentBottom, columnWidth)
			end
			for _, section in ipairs(cameraSections) do
				textY = drawSection(section, textX, textY, maxChars, contentBottom, columnWidth)
			end
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
	ControllerCameraTestEnsureBindings()
	local settings = {}
	for key, value in pairs(ControllerCameraTestSettings) do
		if type(value) ~= "table" then
			settings[key] = value
		end
	end

	local savedSections = {}
	if ControllerCameraTestDebugSections then
		for k, v in pairs(ControllerCameraTestDebugSections) do
			savedSections[k] = v
		end
	end

	return {
		panelX = debugPanelX,
		panelY = debugPanelY,
		panelWidth = debugPanelWidth,
		panelHeight = debugPanelHeight,
		settings = settings,
		debugSections = savedSections,
		debugCompact = ControllerCameraTestDebugCompact,
		bindings = ControllerCameraTestBindings.actions,
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
	ControllerCameraTestEnsureBindings()
	if type(data.bindings) == "table" then
		for _, def in ipairs(ControllerCameraTestBindingDefinitions()) do
			local saved = data.bindings[def.action]
			if type(saved) == "string"
				and (saved == "LT" or saved == "RT" or XboxController.buttons[saved] ~= nil)
			then
				ControllerCameraTestBindings.actions[def.action] = saved
			end
		end
	end

	if type(data.debugSections) == "table" then
		for k, v in pairs(data.debugSections) do
			if ControllerCameraTestDebugSections[k] ~= nil then
				ControllerCameraTestDebugSections[k] = v
			end
		end
	end
	if data.debugCompact ~= nil then
		ControllerCameraTestDebugCompact = not not data.debugCompact
	end

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

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	ControllerCameraTestAutoAddFinishedUnitToGroups(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID)
	ControllerCameraTestRemoveUnitFromControlGroups(unitID)
end

function widget:UnitTaken(unitID)
	ControllerCameraTestRemoveUnitFromControlGroups(unitID)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	ControllerCameraTestAutoAddFinishedUnitToGroups(unitID, unitDefID, unitTeam)
end

--------------------------------------------------------------------------------
-- SECTION: Widget lifecycle
--------------------------------------------------------------------------------
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

	-- Drag command previews
	local drag = ControllerCameraTestDragCommand
	if drag and drag.active and drag.startX
		and not (drag.nativeRouteUsed and drag.nativePreviewResult == "native preview active"
			and string.sub(tostring(drag.mode), 1, 5) == "build")
	then
		local startX, startY, startZ = drag.startX, drag.startY, drag.startZ
		local endX = drag.endX or reticleWorldX
		local endY = drag.endY or reticleWorldY
		local endZ = drag.endZ or reticleWorldZ

		if endX and startX then
			gl.LineWidth(3.0)
			if drag.mode == "reclaimArea" or drag.mode == "repairArea" or drag.mode == "attackArea" then
				local dx = endX - startX
				local dz = endZ - startZ
				local r = math.sqrt(dx*dx + dz*dz)
				if r < 10 then r = 120 end

				if drag.mode == "reclaimArea" then
					gl.Color(0.2, 0.8, 0.8, 0.65)
				elseif drag.mode == "repairArea" then
					gl.Color(0.2, 0.9, 0.3, 0.65)
				else
					gl.Color(1.0, 0.2, 0.2, 0.65)
				end
				gl.DrawGroundCircle(startX, startY, startZ, r, 64)
				gl.DrawGroundCircle(startX, startY, startZ, 12, 16)
			else
				if drag.mode == "moveLine" or drag.mode == "singleMovePath" then
					gl.Color(0.2, 0.8, 0.9, 0.7)
				elseif drag.mode == "fightLine" then
					gl.Color(1.0, 0.5, 0.1, 0.7)
				elseif drag.mode == "attackLine" then
					gl.Color(1.0, 0.1, 0.1, 0.8)
				else -- buildLine, buildGrid, buildBorder, buildSplit
					gl.Color(1.0, 0.85, 0.2, 0.7)
				end

				gl.BeginEnd(GL.LINE_STRIP, function()
					gl.Vertex(startX, startY, startZ)
					gl.Vertex(endX, endY, endZ)
				end)

				local pts = drag.previewPoints or {}
				for _, pt in ipairs(pts) do
					if pt[1] and pt[3] then
						local py = pt[2] or Spring.GetGroundHeight(pt[1], pt[3])
						gl.DrawGroundCircle(pt[1], py, pt[3], 24, 16)
					end
				end
			end
		end
	end

	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end
