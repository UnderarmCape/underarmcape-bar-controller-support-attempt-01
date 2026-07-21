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
		handler = true,
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
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray

ControllerUISharedRenderers = ControllerUISharedRenderers or nil
do
	local ok, module = pcall(VFS.Include, "LuaUI/Include/controller_ui_shared_renderers.lua")
	if ok and type(module) == "table" then ControllerUISharedRenderers = module end
end
ControllerSelectionBehavior = ControllerUISharedRenderers and ControllerUISharedRenderers.SelectionBehavior or nil
ControllerDisassembleBehavior = ControllerDisassembleBehavior or nil
do
	local ok, module = pcall(VFS.Include, "LuaUI/Include/controller_disassemble_behavior.lua")
	if ok and type(module) == "table" then ControllerDisassembleBehavior = module end
end

function serializeTable(t)
	if type(t) ~= "table" then return tostring(t) end
	local s = {}
	for i = 1, #t do
		s[#s + 1] = tostring(t[i])
	end
	return "{" .. table.concat(s, ", ") .. "}"
end

local lastIssuedCommand = "none"
local ControllerCameraTestDrawSelectedUnitGreenCircle = false
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
	smartExactTargetType = "none",
	smartAssistTargetType = "none",
	smartAssistTargetID = "none",
	smartAssistDistance = "none",
	smartChosenAction = "none",
	smartChosenCmdID = "none",
	smartActionSource = "none",
	smartLastResult = "none",
	smartExactTargetID = "none",
	smartOrderParams = "none",
	smartAssistScale = "1.00",
	smartEffectiveScreenRadius = "none",
	smartEffectiveFeatureRadius = "none",
	smartEffectiveUnitRadius = "none",
	queueRemovalMode = "none",
	queueRemovalSelectedCount = 0,
	queueRemovalAttemptedCount = 0,
	queueRemovalRemovedCount = 0,
	queueRemovalLastQueueSize = "none",
	queueRemovalLastTag = "none",
	queueRemovalUnitDetails = "none",
}
-- TEMP BUILD RADIAL TUNING: remove after visual values are finalized.
local BuildRadialTuning = {
	enabled = true,
}
setmetatable(BuildRadialTuning, {
	__index = function(t, key)
		if not ControllerCameraTestSettings then
			return nil
		end
		if key == "radialScale" then
			return ControllerCameraTestSettings.buildRadialScale or 1.25
		elseif key == "iconScale" then
			return (ControllerCameraTestSettings.buildIconScale or 2.0) * ControllerCameraTestGetControllerUIIconScale("buildRadial")
		elseif key == "textScale" then
			return (ControllerCameraTestSettings.buildTextScale or 2.0) * ControllerCameraTestGetControllerUIFontScale("buildRadial")
		elseif key == "pageLabelScale" then
			return (ControllerCameraTestSettings.buildPageLabelScale or 2.0) * ControllerCameraTestGetControllerUIFontScale("buildRadial")
		elseif key == "fillAlpha" then
			return ControllerCameraTestSettings.buildFillAlpha or 0.45
		elseif key == "selectedBorderScale" then
			return ControllerCameraTestSettings.buildSelectedBorderScale or 1.3
		elseif key == "itemSpacing" then
			return ControllerCameraTestSettings.buildItemSpacing or 1.0
		end
		return nil
	end,
	__newindex = function(t, key, val)
		if not ControllerCameraTestSettings then
			return
		end
		if key == "radialScale" then
			ControllerCameraTestSettings.buildRadialScale = val
		elseif key == "iconScale" then
			ControllerCameraTestSettings.buildIconScale = val
		elseif key == "textScale" then
			ControllerCameraTestSettings.buildTextScale = val
		elseif key == "pageLabelScale" then
			ControllerCameraTestSettings.buildPageLabelScale = val
		elseif key == "fillAlpha" then
			ControllerCameraTestSettings.buildFillAlpha = val
		elseif key == "selectedBorderScale" then
			ControllerCameraTestSettings.buildSelectedBorderScale = val
		elseif key == "itemSpacing" then
			ControllerCameraTestSettings.buildItemSpacing = val
		end
	end
})

-- TEMP BUILD RADIAL TUNING: page colors
local BuildRadialPageColors = {
	economy = {
		fill = { 0.04, 0.32, 0.08, 0.45 },
		accent = { 0.5, 0.9, 0.2, 1.0 },
	},
	combat = {
		fill = { 0.45, 0.04, 0.04, 0.45 },
		accent = { 1.0, 0.18, 0.12, 1.0 },
	},
	utility = {
		fill = { 0.12, 0.08, 0.45, 0.45 },
		accent = { 0.55, 0.45, 1.0, 1.0 },
	},
	build = {
		fill = { 0.45, 0.28, 0.04, 0.45 },
		accent = { 1.0, 0.75, 0.1, 1.0 },
	},
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
	-- Affordability cache: rebuilt on open/page-change, then refreshed every 10s
	affordabilityCache = {},
	affordabilityCacheTime = -100,
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
	slowPanActive = false, -- toggled by Back during placement
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
	queueFrontInsertActive = false,
	queueFrontInsertPos = 0,
	queueFrontInsertResult = "none",
}

-- Table pool for build drag preview cells to avoid per-frame allocations
local cellTablePool = {}
local cellTablePoolSize = 0

function GetCellTable(x, y, z, facing)
	if cellTablePoolSize > 0 then
		local t = cellTablePool[cellTablePoolSize]
		cellTablePool[cellTablePoolSize] = nil
		cellTablePoolSize = cellTablePoolSize - 1
		t[1] = x
		t[2] = y
		t[3] = z
		t[4] = facing
		return t
	else
		return { x, y, z, facing }
	end
end

function ReleaseCellTable(t)
	cellTablePoolSize = cellTablePoolSize + 1
	cellTablePool[cellTablePoolSize] = t
end

-- Drag preview input cache
local lastDragPreviewCache = {
	active = false,
	mode = nil,
	startX = nil,
	startY = nil,
	startZ = nil,
	endX = nil,
	endY = nil,
	endZ = nil,
	cmdID = nil,
	facing = nil,
	spacing = nil,
	preferNative = nil,
}

local lastSelectedUnits = {}
local lastPreviewWasNative = false

function CheckSelectedUnitsChanged(current)
	if #current ~= #lastSelectedUnits then
		return true
	end
	for i = 1, #current do
		if current[i] ~= lastSelectedUnits[i] then
			return true
		end
	end
	return false
end

function UpdateSelectedUnitsCache(current)
	for k in pairs(lastSelectedUnits) do
		lastSelectedUnits[k] = nil
	end
	for i = 1, #current do
		lastSelectedUnits[i] = current[i]
	end
end

function ClearCachedPreviewPoints()
	local drag = ControllerCameraTestDragCommand
	if type(drag.previewPoints) == "table" then
		if not lastPreviewWasNative then
			for i = 1, #drag.previewPoints do
				local pt = drag.previewPoints[i]
				if type(pt) == "table" then
					ReleaseCellTable(pt)
				end
				drag.previewPoints[i] = nil
			end
		else
			drag.previewPoints = {}
		end
	else
		drag.previewPoints = {}
	end
	lastPreviewWasNative = false
end

function ControllerCameraTestClearDragPreviewCache()
	for k in pairs(lastDragPreviewCache) do
		lastDragPreviewCache[k] = nil
	end
	lastDragPreviewCache.active = false
	for k in pairs(lastSelectedUnits) do
		lastSelectedUnits[k] = nil
	end
	ClearCachedPreviewPoints()
end

-- Static pre-allocated structures for native route to avoid allocations
local staticBlueprintTable = {
	facing = 0,
	units = {
		{
			blueprintUnitID = 1,
			unitDefID = 0,
			position = { 0, 0, 0 },
			facing = 0
		}
	}
}
local staticStartPos = { 0, 0, 0 }
local staticEndPos = { 0, 0, 0 }

-- Scalar diagnostics for build placement
local diagPlacementPreviewCells = 0
local diagPlacementPreviewRebuildCount = 0
local diagPlacementPreviewCacheHits = 0
local diagPlacementPreviewCacheMisses = 0
local diagPlacementPreviewLastRebuildReason = "none"
local diagPlacementGridRows = 0
local diagPlacementGridCols = 0
local diagPlacementDrawCount = 0

local ControllerCameraTestMexSpotSnapRadius = 160
local ControllerCameraTestAreaRadiusSensitivity = 1.5
local ControllerCameraTestSmartTargetScreenRadius = 55
local ControllerCameraTestSmartFeatureWorldRadius = 180
local ControllerCameraTestSmartUnitWorldRadius = 160

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
	cachedCommands = nil,
	allCachedCommands = nil,
	categoryCommands = nil,
	categoryKey = "tactical",
	categoryLabel = "Tactical Actions",
	categoryDirection = "down",
	cacheValid = false,
	cacheSelectionKey = "none",
	cacheLastRefreshTime = -10,
	optionCount = 0,
	optionsRebuildCount = 0,
	cacheHits = 0,
	cacheMisses = 0,
	lastRebuildReason = "none",
	drawCount = 0,
	hitboxCount = 0,
	debugRowsCount = 0,
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
	audit = "binding defs cached; tactical options cached; hot debug summaries throttled",
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
ControllerCameraTestLBCycle = ControllerCameraTestLBCycle
	or (ControllerSelectionBehavior and ControllerSelectionBehavior.NewLBCycle())
	or { active = false, pressedAt = 0, heldSeconds = 0, tactical = false, consumed = false, consumeReason = "none" }
ControllerCameraTestVisibleSelection = ControllerCameraTestVisibleSelection or {
	currentSelection = {},
	previousSelection = {},
	selectionRevision = 0,
	suppressNextSnapshot = false,
	radial = ControllerDisassembleBehavior and ControllerDisassembleBehavior.NewFilterRadial("Combat")
		or { open = false, persistedFilter = "Combat", candidate = "Combat", stickSector = nil, initialValue = "Combat", lastResult = "closed" },
}
ControllerCameraTestDisassemble = ControllerCameraTestDisassemble or {
	active = false,
	reclaimers = {},
	markedTargets = {},
	highlightedTargets = {},
	toggle = ControllerDisassembleBehavior and ControllerDisassembleBehavior.NewToggleCharge()
		or { charging = false, startedAt = 0, progress = 0, waitingForRelease = false, lastEvent = "idle" },
	activatedAt = 0,
	successfulActivity = false,
	lastValidationAt = -10,
	lastResult = "inactive",
	markArea = { pressActive = false, active = false, startedAt = 0, radius = 320, additive = false, typeFilter = nil },
	areaReclaim = { active = false, anchorUnitID = nil, unitDefID = nil, x = nil, y = nil, z = nil, radius = 120, candidates = {} },
	lbA = { pressActive = false, startedAt = 0, targetID = nil, unitDefID = nil, holdFired = false },
}
ControllerCameraTestNativeUI = ControllerCameraTestNativeUI or {
	tacticalFocus = 1,
	buildFocus = nil,
	controllerStable = false,
	pendingControllerState = false,
	pendingSince = 0,
	lastCompatibilityWarning = nil,
}
ControllerCameraTestLBHotkeys = ControllerCameraTestLBHotkeys or {
	A = { pending = false, lastPressTime = 0, pressCount = 0 },
	B = { pending = false, lastPressTime = 0, pressCount = 0 },
	X = { pending = false, lastPressTime = 0, pressCount = 0 },
	Y = { pending = false, lastPressTime = 0, pressCount = 0 },
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
ControllerCameraTestDgunMode = ControllerCameraTestDgunMode or {
	active = false,
	commanderID = nil,
	cmdID = nil,
	aimX = 0,
	aimZ = 0,
	targetX = 0,
	targetY = 0,
	targetZ = 0,
	range = 280,
	rangeSource = "fallback",
	lastFireResult = "none",
	lastExitReason = "none",
	lastFireTime = 0,
	lastMoveTime = 0,
	moveActive = false,
	lastMoveResult = "none",
	moveTargetX = 0,
	moveTargetY = 0,
	moveTargetZ = 0,
	aimActive = false,
	movementStickActive = false,
}
ControllerCameraTestDgunAimRange = 280
ControllerCameraTestAreaCancelReason = "none"
ControllerCameraTestAreaCommandDebug = ControllerCameraTestAreaCommandDebug or {
	state = "none",
	label = "none",
	cmdID = "none",
	action = "none",
	descriptorSource = "none",
	rawRadius = "none",
	effectiveRadius = "none",
	sensitivity = ControllerCameraTestAreaRadiusSensitivity,
	colorProfile = "none",
	iconSource = "none",
	lastIssueResult = "none",
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
	DGun = true,
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

local debugEventTime = 0

local ControllerCameraTestHotkeyFeedback = {
	text = nil,
	color = { 1, 1, 1, 0.80 },
	startTime = nil,
	duration = 1.15,
}

local function ControllerCameraTestShowHotkeyFeedback(label, colorType)
	local color = { 1, 1, 1, 0.80 }
	if colorType == "repair" then
		color = { 0.2, 1.0, 0.6, 0.80 }
	elseif colorType == "reclaim" then
		color = { 0.7, 1.0, 0.2, 0.80 }
	elseif colorType == "mex" then
		color = { 0.2, 1.0, 0.2, 0.80 }
	elseif colorType == "patrol" then
		color = { 0.2, 0.6, 1.0, 0.80 }
	elseif colorType == "attack" then
		color = { 1.0, 0.3, 0.2, 0.80 }
	elseif colorType == "utility" then
		color = { 0.2, 0.8, 1.0, 0.80 }
	elseif colorType == "commander" then
		color = { 1.0, 0.8, 0.2, 0.80 }
	end

	ControllerCameraTestHotkeyFeedback.text = label
	ControllerCameraTestHotkeyFeedback.color = color
	ControllerCameraTestHotkeyFeedback.startTime = Spring.GetTimer()
end
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
		stickDeadzone = 5000,
		triggerDeadzone = 3000,
		areaSelectRadius = 320,
		reticleSize = 16,
		xHoldSeconds = 0.14,
		aHoldSeconds = 0.38,
		areaReclaimHoldSeconds = 0.45,
		disassembleToggleHoldSeconds = 0.33,
		nativeBarUIIntegration = "Native Experimental",
		controllerGlyphStyle = "Auto",
		disassembleUnusedTimeoutSeconds = 20.0,
		lbTapMaxSeconds = 0.20,
		lbTacticalHoldSeconds = 0.20,
		visibleSelectionFilter = "Combat",
		controlGroupAssignHoldSeconds = 0.35,
		radialScale = 1,
		cameraSmoothing = 0.06,
		stickCurve = 1.175,
		triggerCurve = 1.075,
		smartAssistScale = 0.10,
		singlePathSpacing = 96,
		singlePathInterval = 0.10,
		compactSelectedStatus = true,
		hideCompactStatusWhenRadialOpen = true,
		placementPopupEnabled = true,
		preferNativeBlueprint = true,
		debugPanelVisible = false,
		helpOverlayVisible = false,
		compactBuildMenuEnabled = true,
		compactBuildMenuScale = 0.85,
		buildRadialScale = 1.25,
		buildIconScale = 2.0,
		buildTextScale = 2.0,
		buildPageLabelScale = 2.0,
		buildFillAlpha = 0.45,
		buildSelectedBorderScale = 1.3,
		buildItemSpacing = 1.0,
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
	layoutEditorOpen = false,
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
	revision = 0,
	activePreset = "Build-First Commander",
	captureAction = nil,
	conflictAction = nil,
	lastAction = "defaults active",
	triggerDown = { LT = false, RT = false },
	triggerPressed = { LT = false, RT = false },
	triggerReleased = { LT = false, RT = false },
}

-- Binding persistence schema 2 makes the gameplay widget the owner of the
-- Build-First Commander preset. UI widgets call ApplyBindingPreset instead of
-- carrying a second mapping table.
CONTROLLER_BINDINGS_CONFIG_SCHEMA = 2
CONTROLLER_BUILD_FIRST_PRESET_NAME = "Build-First Commander"
ControllerCameraTestBuildFirstPreset = ControllerCameraTestBuildFirstPreset or {
	select = "A", cancel = "B", smartAction = "X", buildRadial = "RB",
	commandLayer = "back", insertNextCommandModifier = "Y", appendQueueModifier = "RT",
	controlGroupModifier = "start", pitchModifier = "LB",
	removeQueuedCommand = "leftStickClick", removeLastQueuedCommand = "rightStickClick",
	radialSelect = "A", radialCancel = "B", radialQuick = "X", radialClose = "Y",
	radialPrevPage = "LB", radialNextPage = "RB",
	place = "A", placeStay = "X", cancelPlacement = "B",
	rotateBuildingLeft = "dpadLeft", rotateBuildingRight = "dpadRight",
	spacingUp = "dpadUp", spacingDown = "dpadDown", patternPrev = "LB", patternNext = "none",
	tacticalSelect = "A", tacticalCancel = "B", tacticalClose = "Y",
	commandUp = "dpadUp", commandDown = "dpadDown", commandLeft = "dpadLeft", commandRight = "dpadRight",
	idlePrev = "dpadLeft", idleNext = "dpadRight",
	groupSlotUp = "dpadUp", groupSlotDown = "dpadDown",
	groupRecallOrAssign = "dpadLeft", groupAssign = "dpadRight", groupClear = "leftStickClick",
	selectCommander = "dpadDown",
}
ControllerCameraTestQuickGroups = ControllerCameraTestQuickGroups or {
	slots = {},
	lastResult = "none",
	lastSlot = "none",
	currentSlot = 1,
}
ControllerCameraTestSelfDestruct = ControllerCameraTestSelfDestruct or {
	chordActive = false,
	holdStartTime = 0,
	holdSeconds = 0.75,
	holdTime = 0,
	attempted = false,
	issued = false,
	cmdID = "none",
	lastResult = "none",
	selectedCount = 0,
	issuedCount = 0,
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
		areaReclaimHoldSeconds = { 0.10, 2.0 },
		disassembleToggleHoldSeconds = { 0.15, 1.50 },
		disassembleUnusedTimeoutSeconds = { 5.0, 120.0 },
		lbTapMaxSeconds = { 0.08, 0.50 },
		lbTacticalHoldSeconds = { 0.08, 0.50 },
		controlGroupAssignHoldSeconds = { 0.05, 2.5 },
		radialScale = { 0.5, 3.0 },
		cameraSmoothing = { 0.0, 1.0 },
		stickCurve = { 0.25, 5.0 },
		triggerCurve = { 0.25, 5.0 },
		smartAssistScale = { 0.0, 1.0 },
		singlePathSpacing = { 16, 1024 },
		singlePathInterval = { 0.02, 1.0 },
		compactBuildMenuScale = { 0.50, 1.00 },
		buildRadialScale = { 0.5, 3.0 },
		buildIconScale = { 0.5, 5.0 },
		buildTextScale = { 0.5, 5.0 },
		buildPageLabelScale = { 0.5, 5.0 },
		buildFillAlpha = { 0.0, 1.0 },
		buildSelectedBorderScale = { 0.5, 5.0 },
		buildItemSpacing = { 0.5, 5.0 },
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
	settings.stickDeadzone = ControllerCameraTestClampSetting("stickDeadzone", settings.stickDeadzone or 5000)
	settings.triggerDeadzone = ControllerCameraTestClampSetting("triggerDeadzone", settings.triggerDeadzone or 3000)
	settings.areaSelectRadius = ControllerCameraTestClampSetting("areaSelectRadius", settings.areaSelectRadius or 320)
	settings.reticleSize = ControllerCameraTestClampSetting("reticleSize", settings.reticleSize or 16)
	settings.xHoldSeconds = ControllerCameraTestClampSetting("xHoldSeconds", settings.xHoldSeconds or 0.14)
	settings.aHoldSeconds = ControllerCameraTestClampSetting("aHoldSeconds", settings.aHoldSeconds or 0.38)
	settings.areaReclaimHoldSeconds = ControllerCameraTestClampSetting("areaReclaimHoldSeconds", settings.areaReclaimHoldSeconds or 0.45)
	settings.disassembleToggleHoldSeconds = ControllerCameraTestClampSetting("disassembleToggleHoldSeconds", settings.disassembleToggleHoldSeconds or defaults.disassembleToggleHoldSeconds)
	settings.disassembleUnusedTimeoutSeconds = ControllerCameraTestClampSetting("disassembleUnusedTimeoutSeconds", settings.disassembleUnusedTimeoutSeconds or 20.0)
	settings.lbTapMaxSeconds = ControllerCameraTestClampSetting("lbTapMaxSeconds", settings.lbTapMaxSeconds or defaults.lbTapMaxSeconds)
	settings.lbTacticalHoldSeconds = ControllerCameraTestClampSetting("lbTacticalHoldSeconds", settings.lbTacticalHoldSeconds or defaults.lbTacticalHoldSeconds)
	if not ControllerSelectionBehavior or not ControllerSelectionBehavior.IsValidFilter(settings.visibleSelectionFilter) then
		settings.visibleSelectionFilter = defaults.visibleSelectionFilter
	end
	settings.controlGroupAssignHoldSeconds = ControllerCameraTestClampSetting("controlGroupAssignHoldSeconds", settings.controlGroupAssignHoldSeconds or 0.35)
	settings.radialScale = ControllerCameraTestClampSetting("radialScale", settings.radialScale or 1)
	settings.cameraSmoothing = ControllerCameraTestClampSetting("cameraSmoothing", settings.cameraSmoothing or defaults.cameraSmoothing)
	settings.stickCurve = ControllerCameraTestClampSetting("stickCurve", settings.stickCurve or defaults.stickCurve)
	settings.triggerCurve = ControllerCameraTestClampSetting("triggerCurve", settings.triggerCurve or defaults.triggerCurve)
	settings.smartAssistScale = ControllerCameraTestClampSetting("smartAssistScale", settings.smartAssistScale or defaults.smartAssistScale)
	settings.singlePathSpacing = ControllerCameraTestClampSetting("singlePathSpacing", settings.singlePathSpacing or 96)
	settings.singlePathInterval = ControllerCameraTestClampSetting("singlePathInterval", settings.singlePathInterval or 0.10)
	settings.compactBuildMenuScale = ControllerCameraTestClampSetting("compactBuildMenuScale", settings.compactBuildMenuScale or 0.85)
	settings.buildRadialScale = ControllerCameraTestClampSetting("buildRadialScale", settings.buildRadialScale or defaults.buildRadialScale)
	settings.buildIconScale = ControllerCameraTestClampSetting("buildIconScale", settings.buildIconScale or defaults.buildIconScale)
	settings.buildTextScale = ControllerCameraTestClampSetting("buildTextScale", settings.buildTextScale or defaults.buildTextScale)
	settings.buildPageLabelScale = ControllerCameraTestClampSetting("buildPageLabelScale", settings.buildPageLabelScale or defaults.buildPageLabelScale)
	settings.buildFillAlpha = ControllerCameraTestClampSetting("buildFillAlpha", settings.buildFillAlpha or defaults.buildFillAlpha)
	settings.buildSelectedBorderScale = ControllerCameraTestClampSetting("buildSelectedBorderScale", settings.buildSelectedBorderScale or defaults.buildSelectedBorderScale)
	settings.buildItemSpacing = ControllerCameraTestClampSetting("buildItemSpacing", settings.buildItemSpacing or defaults.buildItemSpacing)
	settings.compactBuildMenuEnabled = settings.compactBuildMenuEnabled ~= false
	settings.compactSelectedStatus = settings.compactSelectedStatus ~= false
	settings.hideCompactStatusWhenRadialOpen = settings.hideCompactStatusWhenRadialOpen ~= false
	settings.placementPopupEnabled = settings.placementPopupEnabled ~= false
	settings.preferNativeBlueprint = settings.preferNativeBlueprint ~= false
	if settings.nativeBarUIIntegration ~= "Legacy Controller UI" then
		settings.nativeBarUIIntegration = "Native Experimental"
	end
	if settings.controllerGlyphStyle ~= "Xbox" and settings.controllerGlyphStyle ~= "PlayStation" then
		settings.controllerGlyphStyle = "Auto"
	end
	settings.debugPanelVisible = settings.debugPanelVisible == true
	settings.helpOverlayVisible = settings.helpOverlayVisible == true
	ControllerCameraTestAreaSelect.radius = settings.areaSelectRadius
end

function ControllerCameraTestUsesNativeBARUI()
	return ControllerCameraTestSettings
		and ControllerCameraTestSettings.nativeBarUIIntegration ~= "Legacy Controller UI"
end

function ControllerCameraTestGetControllerGlyphFamily()
	local normalized = string.lower(tostring(controllerName or ""))
	if normalized:find("playstation", 1, true) or normalized:find("dualsense", 1, true)
			or normalized:find("dualshock", 1, true) or normalized:find("sony", 1, true)
			or normalized == "wireless controller" then
		return "PlayStation"
	end
	if normalized:find("xbox", 1, true) or normalized:find("xinput", 1, true)
			or normalized:find("microsoft", 1, true) then
		return "Xbox"
	end
	return "Unknown"
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
		{ key = "areaReclaimHoldSeconds", label = "Area reclaim hold seconds", step = 0.02, decimals = 2 },
		{ key = "disassembleToggleHoldSeconds", label = "Disassemble toggle hold seconds", step = 0.01, decimals = 2 },
		{ key = "disassembleUnusedTimeoutSeconds", label = "Disassemble unused timeout", step = 1, decimals = 0 },
		{ key = "controlGroupAssignHoldSeconds", label = "Group hold seconds", step = 0.02, decimals = 2 },
		{ key = "radialScale", label = "Radial scale", step = 0.05, decimals = 2 },
		{ key = "smartAssistScale", label = "Smart X assist scale", step = 0.05, decimals = 2 },
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
ControllerCameraTestSocketBridge = nil
ControllerCameraTestInputBackend = "unavailable"
ControllerCameraTestBridgeStatus = "not initialized"
ControllerCameraTestCompanionFeedback = ControllerCameraTestCompanionFeedback or {
	wasFresh = nil,
	missingSince = nil,
	missingVisible = false,
	connectedUntil = 0,
}
controllerName = "none"
controllerInstanceId = nil
rawControllerStateStatus = "none"
rawAxesSummary = "none"
rawButtonsSummary = "none"
normalizedLeftX = 0
normalizedLeftY = 0
normalizedRightX = 0
normalizedRightY = 0
pregameRawRightX = 0
pregameRawRightY = 0
spacingByBuildCmdID = {}
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
controllerMouseModeActive = false
-- Keep this state global because the widget main chunk is at Lua's local-variable limit.
CONTROLLER_MOUSE_CURSOR_SPEED = 15
MOUSE_MODE_BACK_TAP_MAX_TIME = 0.25
ControllerCameraTestMouseModeSpeedPresets = {
	{ multiplier = 0.125, label = "SLOW" },
	{ multiplier = 0.25, label = "DEFAULT" },
	{ multiplier = 0.50, label = "MEDIUM" },
	{ multiplier = 1.00, label = "FAST" },
}
ControllerCameraTestMouseModeSpeedPresetIndex = 2
ControllerCameraTestMouseModeBackTapActive = false
ControllerCameraTestMouseModeBackTapTime = 0
ControllerCameraTestMouseModeBackTapUsedWithStart = false
BACK_START_EDITOR_HOLD_SECONDS = 1.5
backStartHoldTime = 0
backStartHoldTriggered = false
backStartChordActive = false
backStartChordLocked = false
reticleVisible = false
local lastCompactScaleEnabled = nil
local lastCompactScaleValue = nil
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
debugEventTime = 0
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
	ControllerCameraTestCommandDebug.smartExactTargetType = "none"
	ControllerCameraTestCommandDebug.smartAssistTargetType = "none"
	ControllerCameraTestCommandDebug.smartAssistTargetID = "none"
	ControllerCameraTestCommandDebug.smartAssistDistance = "none"
	ControllerCameraTestCommandDebug.smartChosenAction = "none"
	ControllerCameraTestCommandDebug.smartChosenCmdID = "none"
	ControllerCameraTestCommandDebug.smartActionSource = "none"
	ControllerCameraTestCommandDebug.smartLastResult = "none"
	ControllerCameraTestCommandDebug.smartExactTargetID = "none"
	ControllerCameraTestCommandDebug.smartOrderParams = "none"
	ControllerCameraTestCommandDebug.smartAssistScale = "1.00"
	ControllerCameraTestCommandDebug.smartEffectiveScreenRadius = "none"
	ControllerCameraTestCommandDebug.smartEffectiveFeatureRadius = "none"
	ControllerCameraTestCommandDebug.smartEffectiveUnitRadius = "none"
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
	local deadzone = tonumber(ControllerCameraTestSettings.stickDeadzone) or 5000
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
		if not controllerMouseModeActive and Spring.GetGameFrame() > 0 then
			if math.abs(mouseX - screenCenterX) > 5 or math.abs(mouseY - screenCenterY) > 5 then
				noteMouseInput()
			end
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
	if not controllerMode or type(spTraceScreenRay) ~= "function" then
		resetReticleWorldTarget()
		return
	end

	local tx, ty = screenCenterX, screenCenterY
	if Spring.GetGameFrame() <= 0 or controllerMouseModeActive then
		tx, ty = Spring.GetMouseState()
	end

	-- 1. Standard trace to see what we are aiming at
	local okTarget, targetType, targetID = pcall(spTraceScreenRay, tx, ty)
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
	local okGround, _, worldPosition = pcall(spTraceScreenRay, tx, ty, true)

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
	if not ControllerCameraTestIsSafeSelectableUnit(unitID) then
		lastSelectionResult = "invalid or non-friendly unit"
		latchSelectionDebugMessage("A select: target is not a valid friendly unit")
		return
	end

	if ControllerCameraTestUsesNativeBARUI() and WG.smartselect
			and type(WG.smartselect.controllerSelectUnit) == "function" then
		local toggle = ControllerCameraTestIsQueueModifierActive()
		local action = "selected"
		if toggle then
			local existing = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
			action = "added"
			for i = 1, #existing do
				if existing[i] == unitID then action = "removed"; break end
			end
		end
		local okSelect, result = pcall(WG.smartselect.controllerSelectUnit, unitID, toggle and "toggle" or "replace")
		if not okSelect or type(result) ~= "table" then
			lastSelectionResult = "native helper unavailable"
			latchSelectionDebugMessage("Native SmartSelect failed")
			return
		end
		lastReticleSelectedUnitID = tostring(unitID)
		lastSelectionResult = (toggle and "RT+A " or "A ") .. action
		latchSelectionDebugMessage(lastSelectionResult .. " unit " .. tostring(unitID)
			.. " (" .. tostring(#result) .. " total)")
		return
	end

	-- RT+A toggles exactly one valid friendly unit or structure while retaining
	-- every other selected unit. Removing the last item intentionally produces
	-- an empty selection.
	if ControllerCameraTestIsQueueModifierActive() then
		local existing = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		local toggled, action
		if ControllerDisassembleBehavior then
			toggled, action = ControllerDisassembleBehavior.ToggleSelection(existing, unitID)
		else
			toggled, action = {}, "added"
			for _, selectedID in ipairs(existing) do if selectedID ~= unitID then toggled[#toggled + 1] = selectedID else action = "removed" end end
			if action == "added" then toggled[#toggled + 1] = unitID end
		end
		local selectOk = pcall(spSelectUnitArray, toggled, false)
		if not selectOk then
			lastSelectionResult = "unavailable"
			latchSelectionDebugMessage("RT+A select failed")
			return
		end
		lastReticleSelectedUnitID = tostring(unitID)
		lastSelectionResult = "RT+A " .. tostring(action)
		latchSelectionDebugMessage("RT+A " .. tostring(action) .. " unit " .. tostring(unitID)
			.. " (" .. tostring(#toggled) .. " total)")
		return
	end

	-- Normal A (no RT): replace selection
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
	local version = "v0.6.0-build-first-schema-2"
	if type(bindings.definitionCache) == "table" and bindings.definitionCacheVersion == version then
		return bindings.definitionCache
	end
	local defs = {
		{ action = "select", label = "Select / Area Select", default = "A", group = "Core" },
		{ action = "cancel", label = "Cancel / Clear", default = "B", group = "Core" },
		{ action = "smartAction", label = "Smart Action", default = "X", group = "Core" },
		{ action = "buildRadial", label = "Build / Factory Radial", default = "RB", group = "Core" },
		{ action = "commandLayer", label = "Command Layer", default = ControllerCameraTestBuildFirstPreset.commandLayer, group = "Modifiers" },
		{ action = "insertNextCommandModifier", label = "Do Next / Insert Command Modifier", default = "Y", group = "Queue" },
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
		{ action = "selectCommander", label = "Select Commander", default = "dpadDown", group = "Idle / Groups" },
	}
	for _, def in ipairs(defs) do
		def.default = ControllerCameraTestBuildFirstPreset[def.action] or def.default
	end
	bindings.definitionCache = defs
	bindings.definitionCacheVersion = version
	return defs
end

function ControllerCameraTestEnsureBindings()
	local bindings = ControllerCameraTestBindings
	bindings.defaults = bindings.defaults or {}
	bindings.actions = bindings.actions or {}
	local version = "v0.6.0-build-first-schema-2"
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
	ControllerCameraTestBindings.revision = (ControllerCameraTestBindings.revision or 0) + 1
	ControllerCameraTestBindings.activePreset = "Custom"
	ControllerCameraTestBindings.conflictAction = conflict
	ControllerCameraTestBindings.lastAction = "bound " .. tostring(actionName) .. " to "
		.. ControllerCameraTestBindingLabel(buttonName)
		.. (conflict and ("; shared with " .. tostring(conflict)) or "")
	latchSelectionDebugMessage(ControllerCameraTestBindings.lastAction)
end

function ControllerCameraTestResetBinding(actionName)
	ControllerCameraTestEnsureBindings()
	ControllerCameraTestBindings.actions[actionName] = ControllerCameraTestBindings.defaults[actionName]
	ControllerCameraTestBindings.revision = (ControllerCameraTestBindings.revision or 0) + 1
	ControllerCameraTestRefreshActivePreset()
	ControllerCameraTestBindings.lastAction = "reset " .. tostring(actionName) .. " to "
		.. ControllerCameraTestBindingLabel(ControllerCameraTestBindings.actions[actionName])
	latchSelectionDebugMessage(ControllerCameraTestBindings.lastAction)
end

function ControllerCameraTestResetAllBindings()
	ControllerCameraTestApplyBindingPreset(CONTROLLER_BUILD_FIRST_PRESET_NAME)
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
	local buttonName = ControllerCameraTestGetBinding(actionName)
	if (buttonName == "back" or buttonName == "start") and (backStartChordActive or backStartChordLocked) then return false end
	return ControllerCameraTestBindingDown(buttonName)
end

function ControllerCameraTestActionPressed(actionName)
	local buttonName = ControllerCameraTestGetBinding(actionName)
	if (buttonName == "back" or buttonName == "start") and (backStartChordActive or backStartChordLocked) then return false end
	return ControllerCameraTestBindingPressed(buttonName)
end

function ControllerCameraTestActionReleased(actionName)
	local buttonName = ControllerCameraTestGetBinding(actionName)
	if (buttonName == "back" or buttonName == "start") and (backStartChordActive or backStartChordLocked) then return false end
	return ControllerCameraTestBindingReleased(buttonName)
end

function ControllerCameraTestSetBindingUIOpen(open)
	ControllerCameraTestExternalBindingUI.open = not not open
	if open and ControllerCameraTestCancelVisibleSelectionRadial then ControllerCameraTestCancelVisibleSelectionRadial("binding UI opened") end
	ControllerCameraTestExternalBindingUI.lastAction = ControllerCameraTestExternalBindingUI.open and "external binding UI open" or "external binding UI closed"
end

function ControllerCameraTestIsBindingUIOpen()
	return ControllerCameraTestExternalBindingUI.open == true or ControllerCameraTestSettingsUI.open == true
end

function ControllerCameraTestIsGameplayInputBlocked()
	return ControllerCameraTestExternalBindingUI.open == true
		or ControllerCameraTestExternalBindingUI.layoutEditorOpen == true
		or backStartChordActive == true
		or backStartChordLocked == true
end

function ControllerCameraTestSetLayoutEditorOpen(open)
	ControllerCameraTestExternalBindingUI.layoutEditorOpen = not not open
	if open and ControllerCameraTestCancelVisibleSelectionRadial then ControllerCameraTestCancelVisibleSelectionRadial("layout editor opened") end
	-- The Controller Debug panel is deliberately session-only and never follows
	-- editor persistence. Every editor open/close transition starts hidden.
	ControllerCameraTestSettings.debugPanelVisible = false
end

function ControllerCameraTestCanUseLBHotkeys()
	if ControllerCameraTestDisassemble and ControllerCameraTestDisassemble.active then return false end
	if ControllerCameraTestBuildMenu.open then return false end
	if ControllerCameraTestBuildPlacement.active then return false end
	if ControllerCameraTestTacticalMenu.open then return false end
	if ControllerCameraTestSettingsUI.open then return false end
	if ControllerCameraTestIsBindingUIOpen() then return false end
	if ControllerCameraTestDgunMode.active then return false end
	if ControllerCameraTestAreaSelect.active or ControllerCameraTestAreaSelect.pressActive then return false end
	if ControllerCameraTestDragCommand.active or ControllerCameraTestDragCommand.pressActive then return false end
	if ControllerCameraTestVisibleSelection.radial.open then return false end
	if ControllerCameraTestTacticalMenu.stagedOption ~= nil then return false end
	if Spring.IsChatOpened and Spring.IsChatOpened() then return false end
	return true
end

function ControllerCameraTestGetSelectionProfile()
	if ControllerCameraTestSelectionIsAirTransport() then
		return "air_transport"
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits()
	if not selectedUnits or #selectedUnits == 0 then
		return nil
	end

	for _, unitID in ipairs(selectedUnits) do
		local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if type(unitDef) == "table" and unitDef.isFactory then
			return "factory"
		end
	end

	for _, unitID in ipairs(selectedUnits) do
		if ControllerCameraTestIsCommanderUnit(unitID) then
			return "builder"
		end
		local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
		if unitDef then
			local isBuilder = unitDef.isBuilder or unitDef.canBuild or (type(unitDef.buildOptions) == "table" and #unitDef.buildOptions > 0) or unitDef.canAssist or unitDef.canRepair or unitDef.canReclaim
			if isBuilder then
				return "builder"
			end
		end
	end
	return "combat"
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
		lbTapMaxSeconds = { 0.08, 0.50, 0.01, "number", 2 },
		lbTacticalHoldSeconds = { 0.08, 0.50, 0.01, "number", 2 },
		disassembleToggleHoldSeconds = { 0.15, 1.50, 0.01, "number", 2 },
		nativeBarUIIntegration = { 0, 0, 0, "enum", 0 },
		controllerGlyphStyle = { 0, 0, 0, "enum", 0 },
		visibleSelectionFilter = { 0, 0, 0, "enum", 0 },
		controlGroupAssignHoldSeconds = { 0.05, 2.5, 0.01, "number", 2 },
		singlePathSpacing = { 16, 1024, 8, "number", 0 },
		singlePathInterval = { 0.02, 1.0, 0.01, "number", 2 },
		radialScale = { 0.5, 3.0, 0.05, "number", 2 },
		areaSelectRadius = { 40, 2000, 40, "number", 0 },
		smartAssistScale = { 0.0, 1.0, 0.05, "number", 2 },
		reticleSize = { 4, 100, 1, "number", 0 },
		compactSelectedStatus = { 0, 1, 1, "boolean", 0 },
		hideCompactStatusWhenRadialOpen = { 0, 1, 1, "boolean", 0 },
		placementPopupEnabled = { 0, 1, 1, "boolean", 0 },
		preferNativeBlueprint = { 0, 1, 1, "boolean", 0 },
		debugPanelVisible = { 0, 1, 1, "boolean", 0 },
		helpOverlayVisible = { 0, 1, 1, "boolean", 0 },
		compactBuildMenuEnabled = { 0, 1, 1, "boolean", 0 },
		compactBuildMenuScale = { 0.50, 1.00, 0.01, "number", 2 },
		buildRadialScale = { 0.5, 3.0, 0.05, "number", 2 },
		buildIconScale = { 0.5, 5.0, 0.1, "number", 1 },
		buildTextScale = { 0.5, 5.0, 0.1, "number", 1 },
		buildPageLabelScale = { 0.5, 5.0, 0.1, "number", 1 },
		buildFillAlpha = { 0.0, 1.0, 0.05, "number", 2 },
		buildSelectedBorderScale = { 0.5, 5.0, 0.1, "number", 1 },
		buildItemSpacing = { 0.5, 5.0, 0.05, "number", 2 },
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
						type = (item.type == "bool" and "boolean") or item.type or r[4],
						min = r[1],
						max = r[2],
						step = item.step or r[3],
						decimals = item.decimals or r[5],
						default = defaults[item.key],
						value = ControllerCameraTestSettings[item.key],
					}
					if item.type == "enum" then def.options = item.options end
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
	elseif type(current) == "string" then
		if key == "nativeBarUIIntegration"
				and (value == "Native Experimental" or value == "Legacy Controller UI") then
			ControllerCameraTestSettings[key] = value
		elseif key == "controllerGlyphStyle"
				and (value == "Auto" or value == "Xbox" or value == "PlayStation") then
			ControllerCameraTestSettings[key] = value
		elseif key == "visibleSelectionFilter" and ControllerSelectionBehavior
				and ControllerSelectionBehavior.IsValidFilter(value) then
			ControllerCameraTestSettings[key] = value
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

function ControllerCameraTestGetContextSnapshot()
	local selected = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local hasBuilder, hasFactory, hasTransport = false, false, false
	local selectedSet = {}
	for _, unitID in ipairs(selected) do
		selectedSet[unitID] = true
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitDef = unitDefID and UnitDefs and UnitDefs[unitDefID]
		if unitDef then
			hasFactory = hasFactory or unitDef.isFactory == true
			hasBuilder = hasBuilder or unitDef.isBuilder == true or (type(unitDef.buildOptions) == "table" and #unitDef.buildOptions > 0)
			hasTransport = hasTransport or (tonumber(unitDef.transportCapacity) or 0) > 0
		end
	end
	local hoverOwnedTarget = ControllerCameraTestGetReticleOwnedTarget and ControllerCameraTestGetReticleOwnedTarget() or nil
	local markedCount = 0
	if not ControllerCameraTestUsesNativeBARUI() then
		for _ in pairs(ControllerCameraTestDisassemble.markedTargets or {}) do markedCount = markedCount + 1 end
	end
	return {
		controllerActive = controllerMode == true,
		pregame = Spring.GetGameFrame() <= 0,
		mouseMode = controllerMouseModeActive == true,
		bindingsOpen = ControllerCameraTestExternalBindingUI.open == true,
		layoutEditorOpen = ControllerCameraTestExternalBindingUI.layoutEditorOpen == true,
		buildMenuOpen = ControllerCameraTestBuildMenu.open == true,
		buildPlacement = ControllerCameraTestBuildPlacement.active == true,
		factoryRadialOpen = ControllerCameraTestBuildMenu.open == true and hasFactory,
		tacticalRadialOpen = ControllerCameraTestTacticalMenu.open == true,
		selectionRadialOpen = ControllerCameraTestAreaSelect.filterRadialOpen == true,
		visibleSelectionRadialOpen = ControllerCameraTestVisibleSelection.radial.open == true,
		disassembleMode = ControllerCameraTestDisassemble.active == true,
		disassembleToggleCharge = ControllerCameraTestDisassemble.toggle.charging == true,
		disassembleToggleProgress = ControllerCameraTestDisassemble.toggle.progress or 0,
		disassembleAreaMarking = ControllerCameraTestDisassemble.markArea.active == true,
		disassembleAreaReclaim = ControllerCameraTestDisassemble.areaReclaim.active == true,
		disassembleMarkedCount = markedCount,
		nativeBarUI = ControllerCameraTestUsesNativeBARUI(),
		nativeCommandActive = ControllerCameraTestGetNativeActiveCommandID and
			ControllerCameraTestGetNativeActiveCommandID() ~= nil or false,
		controllerGlyphStyle = ControllerCameraTestSettings.controllerGlyphStyle,
		controllerGlyphFamily = ControllerCameraTestGetControllerGlyphFamily(),
		hoverFriendlyTarget = hoverOwnedTarget ~= nil,
		disassembleTargetToggleAction = hoverOwnedTarget and
			(ControllerCameraTestDisassemble.markedTargets[hoverOwnedTarget] and "Remove Target" or "Add Target") or nil,
		hoverSelectionToggleAction = hoverOwnedTarget and (selectedSet[hoverOwnedTarget] and "Remove from Selection" or "Add to Selection") or nil,
		selectionToggleModifier = ControllerCameraTestIsQueueModifierActive(),
		areaSelection = ControllerCameraTestAreaSelect.active == true,
		stagedTactical = type(ControllerCameraTestTacticalMenu.stagedOption) == "table",
		dgunMode = ControllerCameraTestDgunMode.active == true,
		selectedCount = #selected,
		hasSelection = #selected > 0,
		multipleSelection = #selected > 1,
		hasBuilder = hasBuilder,
		hasFactory = hasFactory,
		hasTransport = hasTransport,
		hasWorldTarget = reticleHasWorldTarget == true,
		hoverTargetType = reticleTargetType,
		smartTargetType = ControllerCameraTestCommandDebug.smartExactTargetType,
		commandLayer = commandLayerActive == true,
		controlGroupLayer = ControllerCameraTestActionDown("controlGroupModifier"),
		pitchLayer = ControllerCameraTestLBCycle.tactical == true,
		lbTacticalLayer = ControllerCameraTestLBCycle.tactical == true and ControllerCameraTestVisibleSelection.radial.open ~= true,
		lbTapPending = ControllerCameraTestLBCycle.active == true and ControllerCameraTestLBCycle.tactical ~= true,
		selectionProfile = ControllerCameraTestGetSelectionProfile(),
		visibleSelectionFilter = ControllerCameraTestSettings.visibleSelectionFilter or "Combat",
		selectionRevision = ControllerCameraTestVisibleSelection.selectionRevision or 0,
		backStartHoldProgress = backStartChordActive and math.min(1, backStartHoldTime / BACK_START_EDITOR_HOLD_SECONDS) or 0,
	}
end

function ControllerCameraTestInstallWGAPI()
	WG.BARControllerSupport = WG.BARControllerSupport or {}
	WG.BARControllerSupport.GetBindingDefinitions = ControllerCameraTestBindingDefinitions
	WG.BARControllerSupport.GetBinding = ControllerCameraTestGetBinding
	WG.BARControllerSupport.SetBinding = ControllerCameraTestSetBinding
	WG.BARControllerSupport.ResetBinding = ControllerCameraTestResetBinding
	WG.BARControllerSupport.ResetAllBindings = ControllerCameraTestResetAllBindings
	WG.BARControllerSupport.ApplyBindingPreset = ControllerCameraTestApplyBindingPreset
	WG.BARControllerSupport.GetActiveBindingPreset = ControllerCameraTestRefreshActivePreset
	WG.BARControllerSupport.GetBindingRevision = function() return ControllerCameraTestBindings.revision or 0 end
	WG.BARControllerSupport.GetBindingPreset = function(presetName)
		if presetName == CONTROLLER_BUILD_FIRST_PRESET_NAME then return ControllerCameraTestBuildFirstPreset end
		return nil
	end
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
	WG.BARControllerSupport.GetContextSnapshot = ControllerCameraTestGetContextSnapshot
	WG.BARControllerSupport.SetLayoutEditorOpen = ControllerCameraTestSetLayoutEditorOpen
	WG.BARControllerSupport.SetDebugPanelVisible = function(visible, source)
		ControllerCameraTestSettings.debugPanelVisible = visible == true
		ControllerCameraTestRecordUIToggleAction(tostring(source or "Controller UI") .. " debug panel "
			.. (ControllerCameraTestSettings.debugPanelVisible and "shown" or "hidden"))
		return ControllerCameraTestSettings.debugPanelVisible
	end
	WG.BARControllerSupport.ToggleDebugPanel = function(source)
		ControllerCameraTestToggleDebugPanel(source or "Controller UI")
		return ControllerCameraTestSettings.debugPanelVisible
	end
	WG.BARControllerSupport.IsDebugPanelVisible = function()
		return ControllerCameraTestSettings.debugPanelVisible == true
	end
	WG.BARControllerSupport.GetShortcutBinding = function(shortcut)
		if shortcut == "mouseMode" or shortcut == "uiSettings" then return { "back", "start" } end
		return nil
	end
	WG.BARControllerSupport.GetBackStartHoldProgress = function()
		return backStartChordActive and math.min(1, backStartHoldTime / BACK_START_EDITOR_HOLD_SECONDS) or 0
	end
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
	WG.BARControllerSupport.ApplyBindingPreset = nil
	WG.BARControllerSupport.GetActiveBindingPreset = nil
	WG.BARControllerSupport.GetBindingRevision = nil
	WG.BARControllerSupport.GetBindingPreset = nil
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
	WG.BARControllerSupport.GetContextSnapshot = nil
	WG.BARControllerSupport.SetLayoutEditorOpen = nil
	WG.BARControllerSupport.SetDebugPanelVisible = nil
	WG.BARControllerSupport.ToggleDebugPanel = nil
	WG.BARControllerSupport.IsDebugPanelVisible = nil
	WG.BARControllerSupport.GetShortcutBinding = nil
	WG.BARControllerSupport.GetBackStartHoldProgress = nil
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
			{ key = "lbTapMaxSeconds", label = "LB tap maximum", step = 0.01, decimals = 2 },
			{ key = "lbTacticalHoldSeconds", label = "LB tactical hold", step = 0.01, decimals = 2 },
			{ key = "disassembleToggleHoldSeconds", label = "Disassemble Toggle Hold Duration", step = 0.01, decimals = 2 },
			{ key = "nativeBarUIIntegration", label = "Native BAR UI Integration", type = "enum",
				options = { "Native Experimental", "Legacy Controller UI" } },
			{ key = "controllerGlyphStyle", label = "Controller Glyph Style", type = "enum",
				options = { "Auto", "Xbox", "PlayStation" } },
			{ key = "controlGroupAssignHoldSeconds", label = "Group assign hold", step = 0.01, decimals = 2 },
			{ key = "singlePathSpacing", label = "Path waypoint spacing", step = 8, decimals = 0 },
			{ key = "singlePathInterval", label = "Path issue interval", step = 0.01, decimals = 2 },
		} },
		{ key = "Radials", items = {
			{ key = "radialScale", label = "Radial scale", step = 0.05, decimals = 2 },
			{ key = "compactSelectedStatus", label = "Compact status panel", type = "bool" },
			{ key = "hideCompactStatusWhenRadialOpen", label = "Hide status with radial", type = "bool" },
			-- TEMP BUILD RADIAL TUNING: remove after visual values are finalized.
			{ key = "buildRadialScale", label = "Build radial scale", step = 0.05, decimals = 2 },
			{ key = "buildIconScale", label = "Build icon scale", step = 0.1, decimals = 1 },
			{ key = "buildTextScale", label = "Build text scale", step = 0.1, decimals = 1 },
			{ key = "buildPageLabelScale", label = "Build page label scale", step = 0.1, decimals = 1 },
			{ key = "buildFillAlpha", label = "Build fill alpha", step = 0.05, decimals = 2 },
			{ key = "buildSelectedBorderScale", label = "Build selected border scale", step = 0.1, decimals = 1 },
			{ key = "buildItemSpacing", label = "Build item spacing factor", step = 0.05, decimals = 2 },
		} },
		{ key = "Selection", items = {
			{ key = "areaSelectRadius", label = "Area select radius", step = 40, decimals = 0 },
			{ key = "smartAssistScale", label = "Smart X Assist Radius Scale", step = 0.05, decimals = 2 },
			{ key = "visibleSelectionFilter", label = "Quick LB visible filter", type = "enum",
				options = { "Combat", "Builders", "Air", "Last Selected" } },
		} },
		{ key = "Placement", items = {
			{ key = "placementPopupEnabled", label = "Placement popup", type = "bool" },
			{ key = "preferNativeBlueprint", label = "Prefer native blueprint", type = "bool" },
			{ key = "compactBuildMenuEnabled", label = "Compact Build Menu Override", type = "bool" },
			{ key = "compactBuildMenuScale", label = "Compact Build Menu Scale", step = 0.01, decimals = 2 },
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

function ControllerCameraTestToggleSettingsUI(forceOpen)
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
		Spring.Echo("BAR Controller Support: Binding/Settings UI is unavailable.")
	end
end

function ControllerCameraTestAdjustSettingFromUI(settingKey, delta, step)
	local current = ControllerCameraTestSettings[settingKey]
	if type(current) == "boolean" then
		ControllerCameraTestSettings[settingKey] = not current
	elseif settingKey == "visibleSelectionFilter" and ControllerSelectionBehavior then
		local options = { "Combat", "Builders", "Air", "Last Selected" }
		local index = 1
		for i, value in ipairs(options) do if value == current then index = i; break end end
		ControllerCameraTestSettings[settingKey] = options[((index - 1 + delta) % #options) + 1]
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
		if ControllerCameraTestSettingsUI then ControllerCameraTestSettingsUI.lastAction = "reset " .. tostring(settingKey) end
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
	if ControllerCameraTestSettingsUI then ControllerCameraTestSettingsUI.lastAction = "reset " .. tostring(category.key) end
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
	-- Block L3 queue removal when self-destruct chord (Back + R3 + L3) is active
	if ControllerCameraTestSelfDestruct.chordActive then
		return false
	end
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

ControllerCameraTestAreaCommandProfiles = ControllerCameraTestAreaCommandProfiles or {
	reclaimArea = {
		key = "reclaim",
		label = "RECLAIM",
		color = { 0.22, 0.95, 0.35, 0.68 },
		centerColor = { 0.18, 1.0, 0.42, 0.95 },
	},
	resurrectArea = {
		key = "resurrect",
		label = "RES",
		color = { 0.72, 0.36, 1.0, 0.72 },
		centerColor = { 0.88, 0.62, 1.0, 0.96 },
	},
	restoreArea = {
		key = "restore",
		label = "RESTORE",
		color = { 0.42, 0.78, 1.0, 0.72 },
		centerColor = { 0.62, 0.9, 1.0, 0.96 },
	},
	repairArea = {
		key = "repair",
		label = "REPAIR",
		color = { 1.0, 0.72, 0.18, 0.72 },
		centerColor = { 1.0, 0.82, 0.28, 0.96 },
	},
	areaMex = {
		key = "areaMex",
		label = "MEX",
		color = { 1.0, 0.82, 0.12, 0.72 },
		centerColor = { 1.0, 0.9, 0.22, 0.96 },
	},
	attackArea = {
		key = "attack",
		label = "ATK",
		color = { 1.0, 0.28, 0.12, 0.72 },
		centerColor = { 1.0, 0.42, 0.22, 0.96 },
	},
	loadArea = {
		key = "load",
		label = "LOAD",
		color = { 0.2, 0.75, 1.0, 0.72 },
		centerColor = { 0.4, 0.85, 1.0, 0.96 },
	},
	unloadArea = {
		key = "unload",
		label = "UNLOAD",
		color = { 0.2, 0.75, 1.0, 0.72 },
		centerColor = { 0.4, 0.85, 1.0, 0.96 },
	},
	genericArea = {
		key = "generic",
		label = "AREA",
		color = { 0.84, 0.88, 0.92, 0.68 },
		centerColor = { 0.92, 0.96, 1.0, 0.95 },
	},
}

local ControllerCameraTestAreaMexWarningLogged = false
ControllerCameraTestAreaMexHelperEnableAttempted = ControllerCameraTestAreaMexHelperEnableAttempted or false

function ControllerCameraTestGetAreaCommandProfile(optionOrMode)
	local mode = type(optionOrMode) == "table" and optionOrMode.dragMode or optionOrMode
	return ControllerCameraTestAreaCommandProfiles[mode] or ControllerCameraTestAreaCommandProfiles.genericArea
end

function ControllerCameraTestIsAreaMexOption(option)
	return type(option) == "table" and option.dragMode == "areaMex"
end

function ControllerCameraTestIsRestoreAreaOption(option)
	return type(option) == "table" and option.dragMode == "restoreArea"
end

function ControllerCameraTestIsRepairAreaOption(option)
	return type(option) == "table" and option.dragMode == "repairArea"
end

function ControllerCameraTestIsReclaimAreaOption(option)
	return type(option) == "table" and option.dragMode == "reclaimArea"
end

function ControllerCameraTestIsAreaTacticalOption(option)
	if type(option) ~= "table" then
		return false
	end
	return option.kind == "drag_area" or ControllerCameraTestAreaCommandProfiles[option.dragMode] ~= nil
end

function ControllerCameraTestAreaCommandRadius(startX, startZ, endX, endZ)
	local dx = (endX or startX or 0) - (startX or 0)
	local dz = (endZ or startZ or 0) - (startZ or 0)
	local rawRadius = math.sqrt(dx * dx + dz * dz)
	if rawRadius < 10 then
		rawRadius = 120
	end
	return rawRadius, rawRadius * ControllerCameraTestAreaRadiusSensitivity
end

function ControllerCameraTestIsFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function ControllerCameraTestIssueAreaMexRouteA(option, x, y, z, radius)
	local api = WG and WG.controllerAreaMex
	if type(api) ~= "table" or type(api.issueArea) ~= "function" then
		if not ControllerCameraTestAreaMexWarningLogged then
			ControllerCameraTestAreaMexWarningLogged = true
			Spring.Echo("[ControllerAreaMex] Route A API unavailable; Area Mex not issued")
		end
		return false, "Route A API unavailable"
	end

	if not (ControllerCameraTestIsFiniteNumber(x)
		and ControllerCameraTestIsFiniteNumber(y)
		and ControllerCameraTestIsFiniteNumber(z))
	then
		return false, "invalid ground target"
	end

	if not ControllerCameraTestIsFiniteNumber(radius) or radius <= 0 then
		return false, "invalid radius"
	end

	-- cmd_area_mex.lua owns the executor; controller code supplies synthesized
	-- {x, y, z, radius} because controller activation cannot populate engine
	-- mouse-drag area params.
	local queueHeld = ControllerCameraTestIsQueueModifierActive()
	local ok, result, reason = pcall(api.issueArea, x, y, z, radius, { shift = queueHeld })
	if not ok then
		return false, tostring(result)
	end
	if result == false then
		return false, tostring(reason or "issue failed")
	end

	local name = tostring((option and option.name) or "Area Mex")
	ControllerCameraTestCommandDebug.issuedCmdID = tostring((option and option.cmdID) or "RouteA")
	ControllerCameraTestCommandDebug.issuedParamsCount = 4
	ControllerCameraTestCommandDebug.lastOptions = queueHeld and "shift" or "none"
	ControllerCameraTestCommandDebug.lastResult = "Area Mex Route A issued"
	ControllerCameraTestCommandDebug.mexApplyPreviewPath = "RouteA"
	ControllerCameraTestCommandDebug.mexActionResult = "issued Area Mex area"
	ControllerCameraTestSetCommandMarker(x, y, z, name, "areaMex")
	ControllerCameraTestUpdateAreaCommandDebug("confirmed", option, radius, radius, "Route A issued")
	latchSelectionDebugMessage(name .. " confirmed!")
	return true, "Route A issued"
end

function ControllerCameraTestIssueRestoreRouteA(option, x, y, z, radius, queueHeld)
	if type(spGiveOrderToUnitArray) ~= "function" then
		return false, "GiveOrderToUnitArray unavailable"
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if type(selectedUnits) ~= "table" or #selectedUnits <= 0 then
		return false, "no selected units"
	end

	if not (ControllerCameraTestIsFiniteNumber(x)
		and ControllerCameraTestIsFiniteNumber(y)
		and ControllerCameraTestIsFiniteNumber(z))
	then
		return false, "invalid ground target"
	end

	if not ControllerCameraTestIsFiniteNumber(radius) or radius <= 0 then
		return false, "invalid radius"
	end

	local cmdID = (CMD and CMD.RESTORE) or 110
	local opts = queueHeld and { "shift" } or {}
	local params = { x, y, z, radius }
	local ok, result = pcall(spGiveOrderToUnitArray, selectedUnits, cmdID, params, opts)
	if not ok then
		return false, tostring(result)
	end
	if result == false then
		return false, "order rejected"
	end

	local name = tostring((option and option.name) or "Restore Area")
	ControllerCameraTestCommandDebug.issuedCmdID = tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = #params
	ControllerCameraTestCommandDebug.lastOptions = queueHeld and "shift" or "none"
	ControllerCameraTestCommandDebug.lastResult = "Restore Route A issued"
	ControllerCameraTestSetCommandMarker(x, y, z, name, "restore")
	latchSelectionDebugMessage(name .. " confirmed!")
	return true, "Route A issued"
end

function ControllerCameraTestIssueRepairAreaRouteA(option, x, y, z, radius, queueHeld)
	if type(spGiveOrderToUnitArray) ~= "function" then
		return false, "GiveOrderToUnitArray unavailable"
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if type(selectedUnits) ~= "table" or #selectedUnits <= 0 then
		return false, "no selected units"
	end

	if not (ControllerCameraTestIsFiniteNumber(x)
		and ControllerCameraTestIsFiniteNumber(y)
		and ControllerCameraTestIsFiniteNumber(z))
	then
		return false, "invalid ground target"
	end

	if not ControllerCameraTestIsFiniteNumber(radius) or radius <= 0 then
		return false, "invalid radius"
	end

	local cmdID = (CMD and CMD.REPAIR) or 40
	local opts = queueHeld and { "shift" } or {}
	local params = { x, y, z, radius }
	local ok, result = pcall(spGiveOrderToUnitArray, selectedUnits, cmdID, params, opts)
	if not ok then
		return false, tostring(result)
	end
	if result == false then
		return false, "order rejected"
	end

	local name = tostring((option and option.name) or "Repair Area")
	ControllerCameraTestCommandDebug.issuedCmdID = tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = #params
	ControllerCameraTestCommandDebug.lastOptions = queueHeld and "shift" or "none"
	ControllerCameraTestCommandDebug.lastResult = "Repair Route A issued"
	ControllerCameraTestSetCommandMarker(x, y, z, name, "repair")
	latchSelectionDebugMessage(name .. " confirmed!")
	return true, "Route A issued"
end

function ControllerCameraTestIssueReclaimAreaRouteA(option, x, y, z, radius, queueHeld)
	if type(spGiveOrderToUnitArray) ~= "function" then
		return false, "GiveOrderToUnitArray unavailable"
	end

	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if type(selectedUnits) ~= "table" or #selectedUnits <= 0 then
		return false, "no selected units"
	end

	if not (ControllerCameraTestIsFiniteNumber(x)
		and ControllerCameraTestIsFiniteNumber(y)
		and ControllerCameraTestIsFiniteNumber(z))
	then
		return false, "invalid ground target"
	end

	if not ControllerCameraTestIsFiniteNumber(radius) or radius <= 0 then
		return false, "invalid radius"
	end

	local cmdID = (CMD and CMD.RECLAIM) or 90
	local opts = queueHeld and { "shift" } or {}
	local params = { x, y, z, radius }
	local ok, result = pcall(spGiveOrderToUnitArray, selectedUnits, cmdID, params, opts)
	if not ok then
		return false, tostring(result)
	end
	if result == false then
		return false, "order rejected"
	end

	local name = tostring((option and option.name) or "Reclaim Area")
	ControllerCameraTestCommandDebug.issuedCmdID = tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = #params
	ControllerCameraTestCommandDebug.lastOptions = queueHeld and "shift" or "none"
	ControllerCameraTestCommandDebug.lastResult = "Reclaim Route A issued"
	ControllerCameraTestSetCommandMarker(x, y, z, name, "reclaim")
	latchSelectionDebugMessage(name .. " confirmed!")
	return true, "Route A issued"
end

function ControllerCameraTestCopyTacticalOption(option)
	if type(option) ~= "table" then
		return nil
	end
	return {
		name = option.name,
		shortLabel = option.shortLabel,
		cmdID = option.cmdID,
		kind = option.kind,
		dragMode = option.dragMode,
		action = option.action,
		descriptorSource = option.descriptorSource,
		colorProfile = option.colorProfile,
		iconLabel = option.iconLabel,
		iconSource = option.iconSource,
		tacticalCategory = option.tacticalCategory,
	}
end

function ControllerCameraTestUpdateAreaCommandDebug(state, option, rawRadius, effectiveRadius, result)
	local debug = ControllerCameraTestAreaCommandDebug
	local profile = ControllerCameraTestGetAreaCommandProfile(option)
	debug.state = tostring(state or "none")
	debug.label = tostring((option and (option.name or option.shortLabel)) or "none")
	debug.cmdID = tostring(option and option.cmdID or "none")
	debug.action = tostring(option and option.action or "none")
	debug.descriptorSource = tostring(option and option.descriptorSource or "none")
	debug.rawRadius = type(rawRadius) == "number" and string.format("%.1f", rawRadius) or "none"
	debug.effectiveRadius = type(effectiveRadius) == "number" and string.format("%.1f", effectiveRadius) or "none"
	debug.sensitivity = ControllerCameraTestAreaRadiusSensitivity
	debug.colorProfile = tostring(option and option.colorProfile or (profile and profile.key) or "generic")
	debug.iconSource = tostring(option and option.iconSource or "fallback text")
	if result ~= nil and result ~= "preview" then
		debug.lastIssueResult = tostring(result)
	end
end

function ControllerCameraTestGetAreaOptionCommandID(option, mode)
	if type(option) == "table" and type(option.cmdID) == "number" then
		return option.cmdID
	end
	if mode == "reclaimArea" then
		return CMD.RECLAIM
	elseif mode == "repairArea" then
		return CMD.REPAIR
	elseif mode == "attackArea" then
		return CMD.ATTACK
	elseif mode == "restoreArea" then
		return (CMD and CMD.RESTORE) or 110
	elseif mode == "resurrectArea" then
		return CMD.RESURRECT
	elseif mode == "loadArea" then
		return (CMD and CMD.LOAD_UNITS) or 75
	elseif mode == "unloadArea" then
		return (CMD and CMD.UNLOAD_UNITS) or 80
	end
	return nil
end

local function issueOrderToSelection(cmdID, params, cmdName, targetName, options)
	-- 1. Check if we actually have units selected
	local selectedUnits = type(Spring.GetSelectedUnits) == "function" and Spring.GetSelectedUnits() or {}
	local paramsCount = type(params) == "table" and #params or 0
	local orderOptions = type(options) == "table" and options or ControllerCameraTestGetCommandOptions()

	local useInsert = (options == nil or #options == 0) and ControllerCameraTestIsQueueFrontModifierActive()

	-- INSERT outer options: vanilla cmd_commandinsert uses {"alt"} only.
	-- Do NOT use {"alt","shift"} - "shift" would append the INSERT cmd itself
	-- to the queue instead of executing it immediately at position 0.
	local finalOptsTable = useInsert and {"alt"} or orderOptions
	local queuePreserveFlag = false
	for _, opt in ipairs(finalOptsTable) do
		if opt == "shift" then
			queuePreserveFlag = true
		end
	end

	ControllerCameraTestCommandDebug.issuedCmdID = useInsert and tostring(CMD.INSERT) or tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = useInsert and (paramsCount + 3) or paramsCount
	ControllerCameraTestCommandDebug.lastOptions = useInsert and "alt (INSERT front)" or ControllerCameraTestCommandOptionsSummary(orderOptions)

	if ControllerCameraTestSettings.debugPanelVisible and ControllerCameraTestIsQueueFrontModifierActive() then
		Spring.Echo(string.format(
			"[ControllerQueueDebug] Path: issueOrderToSelection | cmdID: %s | params: %s | Y_insert: %s | RT_append: %s | final_options: %s | wrapper_used: %s | queue_preserve: %s",
			tostring(cmdID),
			serializeTable(params),
			tostring(ControllerCameraTestIsQueueFrontModifierActive()),
			tostring(ControllerCameraTestIsQueueModifierActive()),
			serializeTable(finalOptsTable),
			tostring(useInsert),
			"true (INSERT at pos 0 preserves queue)"
		))
	end

	if #selectedUnits == 0 then
		lastIssuedCommand = "none"
		ControllerCameraTestCommandDebug.lastResult = "no selected units"
		latchSelectionDebugMessage(tostring(cmdName) .. " skipped: no units selected")
		return
	end

	-- 2. Use the universally safe LuaUI GiveOrder API
	if type(Spring.GiveOrder) == "function" then
		local orderOk, orderResult
		if useInsert then
			-- Vanilla INSERT format: CMD.INSERT, {pos, cmdID, encodedOpts, ...params}, {"alt"}
			-- pos=0 inserts at front; encodedOpts=0 means no special sub-command options
			-- Outer {"alt"} is required by engine; do NOT add "shift" here
			local cmdInsert = CMD.INSERT
			local insertParams = { 0, cmdID, 0 }
			for i = 1, paramsCount do
				insertParams[#insertParams + 1] = params[i]
			end
			orderOk, orderResult = pcall(Spring.GiveOrder, cmdInsert, insertParams, { "alt" })
		else
			orderOk, orderResult = pcall(Spring.GiveOrder, cmdID, params, orderOptions)
		end

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

function ControllerCameraTestResetSmartCommandDebug()
	ControllerCameraTestCommandDebug.smartExactTargetType = "none"
	ControllerCameraTestCommandDebug.smartAssistTargetType = "none"
	ControllerCameraTestCommandDebug.smartAssistTargetID = "none"
	ControllerCameraTestCommandDebug.smartAssistDistance = "none"
	ControllerCameraTestCommandDebug.smartChosenAction = "none"
	ControllerCameraTestCommandDebug.smartChosenCmdID = "none"
	ControllerCameraTestCommandDebug.smartActionSource = "none"
	ControllerCameraTestCommandDebug.smartLastResult = "pending"
	ControllerCameraTestCommandDebug.smartExactTargetID = "none"
	ControllerCameraTestCommandDebug.smartOrderParams = "none"
	ControllerCameraTestUpdateSmartAssistDebug()
end

function ControllerCameraTestAttemptMexBuildSmartAction(x, y, z, forceShift, forceQueueFront)
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

	local controllerMexTriggerRadius = ControllerCameraTestMexSpotSnapRadius or 160

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

	ControllerCameraTestCommandDebug.mexActionResult = string.format(
		"snap-detected metal spot at dist %.1f <= %d",
		math.sqrt(distSq),
		controllerMexTriggerRadius
	)

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

	local useQueueFront = forceQueueFront or ControllerCameraTestIsQueueFrontModifierActive()
	if useQueueFront then
		-- Find which selected units can actually build this mex
		local builders = {}
		for _, unitID in ipairs(selectedUnits) do
			if mexConstructors[unitID] then
				for _, buildable in pairs(mexConstructors[unitID].building) do
					if -buildable == selectedMex then
						builders[#builders + 1] = unitID
						break
					end
				end
			end
		end

		if #builders > 0 then
			local cmdInsert = CMD.INSERT
			for _, unitID in ipairs(builders) do
				-- Vanilla INSERT: {pos, cmdID, encodedOpts, ...params}, outer {"alt"} only
				pcall(spGiveOrderToUnit, unitID, cmdInsert, { 0, -selectedMex, 0, buildCmd[2], buildCmd[3], buildCmd[4], buildCmd[5] }, { "alt" })
			end
			if ControllerCameraTestSettings.debugPanelVisible then
				Spring.Echo(string.format(
					"[ControllerQueueDebug] Path: AttemptMexBuildSmartAction | cmdID: %s | params: %s | Y_insert: %s | RT_append: %s | final_options: %s | wrapper_used: %s | queue_preserve: %s",
					tostring(-selectedMex),
					serializeTable({ buildCmd[2], buildCmd[3], buildCmd[4], buildCmd[5] }),
					tostring(ControllerCameraTestIsQueueFrontModifierActive()),
					tostring(ControllerCameraTestIsQueueModifierActive()),
					serializeTable(useQueueFront and {"alt", "shift"} or {"shift"}),
					tostring(useQueueFront),
					tostring(true)
				))
			end
			lastIssuedCommand = "Mex Build Prepend (" .. tostring(-selectedMex) .. ")"
			ControllerCameraTestCommandDebug.mexApplyPreviewPath = "custom_insert"
			ControllerCameraTestCommandDebug.lastResult = "mex via custom insert"
			ControllerCameraTestCommandDebug.mexActionResult = "issued via custom insert"
			latchSelectionDebugMessage("X mex build prepend: " .. tostring(-selectedMex))
			return true
		end
	end

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

function ControllerCameraTestAttemptGeoBuildSmartAction(x, y, z)
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		return false
	end

	local geoBuildOptionID = nil
	local buildersWithGeo = {}
	for _, unitID in ipairs(selectedUnits) do
		local uDefID = Spring.GetUnitDefID(unitID)
		local ud = UnitDefs[uDefID]
		if ud and ud.buildOptions then
			for _, optDefID in ipairs(ud.buildOptions) do
				local optDef = UnitDefs[optDefID]
				if optDef and optDef.needGeo then
					geoBuildOptionID = optDefID
					buildersWithGeo[#buildersWithGeo + 1] = unitID
					break
				end
			end
		end
	end

	if not geoBuildOptionID or #buildersWithGeo == 0 then
		return false
	end

	local bestSpot = nil
	local bestDist = 160 -- Snapping radius (e.g. 160 elmos)
	if type(Spring.GetAllFeatures) == "function" and type(Spring.GetFeatureDefID) == "function" and type(Spring.GetFeaturePosition) == "function" then
		local features = Spring.GetAllFeatures()
		for i = 1, #features do
			local featID = features[i]
			local fDefID = Spring.GetFeatureDefID(featID)
			local fDef = FeatureDefs[fDefID]
			if fDef and fDef.geoThermal then
				local fx, fy, fz = Spring.GetFeaturePosition(featID)
				if fx and fz then
					local dx = x - fx
					local dz = z - fz
					local dist = math.sqrt(dx*dx + dz*dz)
					if dist < bestDist then
						bestDist = dist
						bestSpot = {x = fx, y = fy, z = fz}
					end
				end
			end
		end
	end

	if not bestSpot then
		return false
	end

	local cmdID = -geoBuildOptionID
	local facing = 0
	if type(Spring.GetBuildFacing) == "function" then
		local facingOk, buildFacing = pcall(Spring.GetBuildFacing)
		if facingOk and type(buildFacing) == "number" then
			facing = buildFacing
		end
	end
	local params = { bestSpot.x, bestSpot.y, bestSpot.z, facing }

	local orderOptions = ControllerCameraTestGetCommandOptions()
	local useInsert = ControllerCameraTestIsQueueFrontModifierActive()
	local finalOpts = useInsert and {"alt"} or orderOptions
	local issuedCount = 0

	local cmdInsert = CMD.INSERT
	for _, unitID in ipairs(buildersWithGeo) do
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
		ControllerCameraTestShowHotkeyFeedback("GEOTHERMAL", "utility")
		ControllerCameraTestCommandDebug.smartChosenAction = "geothermal"
		ControllerCameraTestCommandDebug.smartActionSource = "geothermal snap"
		ControllerCameraTestCommandDebug.smartLastResult = "built geo plant"
		return true
	end

	return false
end

local function ControllerCameraTestIssueBuildOrders(builders, unitDefID, buildPositions, useQueue, useQueueFront)
	local cmdInsert = CMD.INSERT
	local firstOpts = useQueue and { "shift" } or {}
	ControllerCameraTestCommandDebug.lastOptions = useQueueFront and "queue-front" or ControllerCameraTestCommandOptionsSummary(firstOpts)
	local restOpts = { "shift" }

	if ControllerCameraTestSettings.debugPanelVisible and (useQueueFront or ControllerCameraTestIsQueueFrontModifierActive()) then
		Spring.Echo(string.format(
			"[ControllerQueueDebug] Path: IssueBuildOrders | cmdID: %s | params: %s | Y_insert: %s | RT_append: %s | final_options: %s | wrapper_used: %s | queue_preserve: %s",
			tostring(-unitDefID),
			serializeTable(buildPositions),
			tostring(ControllerCameraTestIsQueueFrontModifierActive()),
			tostring(ControllerCameraTestIsQueueModifierActive()),
			serializeTable(useQueueFront and {"alt"} or {"shift"}),
			tostring(useQueueFront),
			"true (INSERT at pos 0 preserves queue)"
		))
	end

	if useQueueFront then
		for i = #buildPositions, 1, -1 do
			local bp = buildPositions[i]
			local bx, by, bz, bfacing = bp[1], bp[2], bp[3], bp[4] or 0
			for _, unitID in ipairs(builders) do
				-- Vanilla INSERT: {pos, cmdID, encodedOpts, ...params}, outer {"alt"} only
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
function ControllerCameraTestUpdateQueueFrontDragInsertState()
	local drag = ControllerCameraTestDragCommand
	if not ControllerCameraTestIsQueueFrontModifierActive() then
		if drag.queueFrontInsertActive then
			drag.queueFrontInsertResult = "reset: insert modifier released"
		end
		drag.queueFrontInsertActive = false
		drag.queueFrontInsertPos = 0
		return false
	end

	if not drag.queueFrontInsertActive then
		drag.queueFrontInsertActive = true
		drag.queueFrontInsertPos = 0
		drag.queueFrontInsertResult = "started at pos 0"
	end
	return true
end

function ControllerCameraTestNextQueueFrontDragInsertPos()
	if not ControllerCameraTestUpdateQueueFrontDragInsertState() then
		return nil
	end
	local drag = ControllerCameraTestDragCommand
	local insertPos = tonumber(drag.queueFrontInsertPos) or 0
	drag.queueFrontInsertPos = insertPos + 1
	drag.queueFrontInsertResult = "used pos " .. tostring(insertPos)
	return insertPos
end

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

	local queueFrontActive = ControllerCameraTestIsQueueFrontModifierActive()
	local options = {}
	local ok, result
	if queueFrontActive then
		if type(CMD.INSERT) ~= "number" then
			drag.singleUnitPathResult = "INSERT unavailable"
			return false
		end
		local insertPos = ControllerCameraTestNextQueueFrontDragInsertPos() or 0
		ok, result = pcall(spGiveOrderToUnit, drag.singleUnitPathUnitID, CMD.INSERT, { insertPos, CMD.MOVE, 0, reticleWorldX, reticleWorldY, reticleWorldZ }, { "alt" })
		options = { "alt" }
		ControllerCameraTestCommandDebug.issuedCmdID = tostring(CMD.INSERT)
		ControllerCameraTestCommandDebug.issuedParamsCount = 6
		ControllerCameraTestCommandDebug.lastOptions = "alt (INSERT path pos " .. tostring(insertPos) .. ")"
	else
		if not isFirst or ControllerCameraTestIsQueueModifierActive() then
			options = { "shift" }
		end
		ok, result = pcall(spGiveOrderToUnit, drag.singleUnitPathUnitID, CMD.MOVE, { reticleWorldX, reticleWorldY, reticleWorldZ }, options)
		ControllerCameraTestCommandDebug.issuedCmdID = tostring(CMD.MOVE)
		ControllerCameraTestCommandDebug.issuedParamsCount = 3
		ControllerCameraTestCommandDebug.lastOptions = ControllerCameraTestCommandOptionsSummary(options)
	end
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
		ClearCachedPreviewPoints()
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

	-- Caching Check
	local currentOption = ControllerCameraTestBuildPlacement.option
	local currentCmdID = currentOption and currentOption.cmdID or nil
	local currentFacing = ControllerCameraTestBuildPlacement.facing or 0
	local currentSpacing = ControllerCameraTestBuildPlacement.placementSpacing or 0
	local currentPreferNative = ControllerCameraTestSettings.preferNativeBlueprint ~= false
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}

	local needsRebuild = false
	if not lastDragPreviewCache.active
		or lastDragPreviewCache.mode ~= drag.mode
		or lastDragPreviewCache.startX ~= startX
		or lastDragPreviewCache.startY ~= startY
		or lastDragPreviewCache.startZ ~= startZ
		or lastDragPreviewCache.endX ~= endX
		or lastDragPreviewCache.endY ~= endY
		or lastDragPreviewCache.endZ ~= endZ
		or lastDragPreviewCache.cmdID ~= currentCmdID
		or lastDragPreviewCache.facing ~= currentFacing
		or lastDragPreviewCache.spacing ~= currentSpacing
		or lastDragPreviewCache.preferNative ~= currentPreferNative
		or CheckSelectedUnitsChanged(selectedUnits)
	then
		needsRebuild = true
	end

	if not needsRebuild then
		diagPlacementPreviewCacheHits = diagPlacementPreviewCacheHits + 1
		return
	end

	-- Rebuilding
	diagPlacementPreviewCacheMisses = diagPlacementPreviewCacheMisses + 1
	diagPlacementPreviewRebuildCount = diagPlacementPreviewRebuildCount + 1

	-- Determine rebuild reason
	if not lastDragPreviewCache.active then
		diagPlacementPreviewLastRebuildReason = "initial rebuild"
	elseif lastDragPreviewCache.mode ~= drag.mode then
		diagPlacementPreviewLastRebuildReason = "mode changed"
	elseif lastDragPreviewCache.startX ~= startX or lastDragPreviewCache.startY ~= startY or lastDragPreviewCache.startZ ~= startZ then
		diagPlacementPreviewLastRebuildReason = "start position changed"
	elseif lastDragPreviewCache.endX ~= endX or lastDragPreviewCache.endY ~= endY or lastDragPreviewCache.endZ ~= endZ then
		diagPlacementPreviewLastRebuildReason = "end position changed"
	elseif lastDragPreviewCache.cmdID ~= currentCmdID then
		diagPlacementPreviewLastRebuildReason = "cmdID changed"
	elseif lastDragPreviewCache.facing ~= currentFacing then
		diagPlacementPreviewLastRebuildReason = "facing changed"
	elseif lastDragPreviewCache.spacing ~= currentSpacing then
		diagPlacementPreviewLastRebuildReason = "spacing changed"
	elseif lastDragPreviewCache.preferNative ~= currentPreferNative then
		diagPlacementPreviewLastRebuildReason = "preferNative changed"
	elseif CheckSelectedUnitsChanged(selectedUnits) then
		diagPlacementPreviewLastRebuildReason = "selection changed"
	else
		diagPlacementPreviewLastRebuildReason = "unknown"
	end

	-- Clear previous preview points returning them to pool
	ClearCachedPreviewPoints()

	local buildPositions = {}

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
		if N == 1 then
			table.insert(buildPositions, GetCellTable(endX, endY, endZ, nil))
		elseif N > 1 then
			for i = 1, N do
				local t = (i - 1) / (N - 1)
				local x = startX + t * (endX - startX)
				local z = startZ + t * (endZ - startZ)
				local y = Spring.GetGroundHeight(x, z)
				table.insert(buildPositions, GetCellTable(x, y, z, nil))
			end
		end
		drag.previewPoints = buildPositions
		lastPreviewWasNative = false

	elseif drag.mode == "buildLine" or drag.mode == "buildGrid" or drag.mode == "buildBorder" then
		local option = ControllerCameraTestBuildPlacement.option
		if option and type(option.cmdID) == "number" and option.cmdID < 0 then
			local unitDefID = -option.cmdID
			local facing = ControllerCameraTestBuildPlacement.facing or 0
			local spacing = ControllerCameraTestBuildPlacement.placementSpacing or 0

			-- Update static structures to avoid allocations
			staticBlueprintTable.facing = facing
			staticBlueprintTable.units[1].unitDefID = unitDefID

			staticStartPos[1] = startX
			staticStartPos[2] = startY
			staticStartPos[3] = startZ

			staticEndPos[1] = endX
			staticEndPos[2] = endY
			staticEndPos[3] = endZ

			local api = type(WG) == "table" and WG["api_blueprint"] or nil
			local nativeModes = type(api) == "table" and api.BUILD_MODES or nil
			local modeMap = nativeModes and {
				buildLine = nativeModes.LINE,
				buildGrid = nativeModes.GRID,
				buildBorder = nativeModes.BOX,
				buildSplit = nativeModes.SPLIT,
			} or {}
			local apiMode = modeMap[drag.mode]

			drag.nativeRouteUsed = false
			drag.nativeRouteName = "unavailable"
			drag.nativePreviewResult = "not attempted"
			drag.customGridFallback = "yes"

			if ControllerCameraTestSettings.preferNativeBlueprint ~= false and apiMode and type(api.calculateBuildPositions) == "function" then
				local ok, res = pcall(api.calculateBuildPositions, staticBlueprintTable, apiMode, staticStartPos, staticEndPos, spacing)
				if ok and type(res) == "table" and #res > 0 then
					buildPositions = res
					drag.nativeRouteUsed = true
					drag.nativeRouteName = "api_blueprint.calculateBuildPositions"
					drag.nativePreviewResult = "positions calculated"
					drag.customGridFallback = "no"
					if type(api.setActiveBlueprint) == "function"
						and type(api.setBlueprintPositions) == "function"
					then
						if type(api.setActiveBuilders) == "function" then
							pcall(api.setActiveBuilders, selectedUnits)
						end
						pcall(api.setActiveBlueprint, staticBlueprintTable)
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
							table.insert(buildPositions, GetCellTable(startX, startY, startZ, facing))
						else
							local vx, vz = dx / dist, dz / dist
							local numBuildings = math.floor(dist / stepSize) + 1
							if numBuildings > 100 then numBuildings = 100 end
							for i = 0, numBuildings - 1 do
								local x = startX + i * stepSize * vx
								local z = startZ + i * stepSize * vz
								local y = Spring.GetGroundHeight(x, z)
								table.insert(buildPositions, GetCellTable(x, y, z, facing))
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
								table.insert(buildPositions, GetCellTable(x, y, z, facing))
							end
						end
					elseif drag.mode == "buildBorder" or drag.mode == "buildSplit" then
						table.insert(buildPositions, GetCellTable(startX, startY, startZ, facing))
						table.insert(buildPositions, GetCellTable(endX, endY, endZ, facing))
					end
				end
			end

			-- Preview, validation, and final issue all share these resolved points.
			for i = #buildPositions, 1, -1 do
				local point = buildPositions[i]
				local bx, by, bz, valid = ControllerCameraTestResolveBuildPosition(option.cmdID, point[1], point[3], facing, true)
				if valid then
					point[1], point[2], point[3], point[4] = bx, by, bz, facing
				else
					table.remove(buildPositions, i)
				end
			end
			if drag.nativeRouteUsed then
				local blueprintAPI = type(WG) == "table" and WG["api_blueprint"] or nil
				if type(blueprintAPI) == "table" and type(blueprintAPI.setBlueprintPositions) == "function"
					and pcall(blueprintAPI.setBlueprintPositions, buildPositions)
				then
					drag.nativePreviewResult = "native preview active"
				end
			end
			drag.previewPoints = buildPositions
			lastPreviewWasNative = drag.nativeRouteUsed
		end
	end

	-- Update diagnostic grid rows/cols
	if drag.mode == "buildGrid" then
		local option = ControllerCameraTestBuildPlacement.option
		if option and type(option.cmdID) == "number" and option.cmdID < 0 then
			local unitDefID = -option.cmdID
			local unitDef = UnitDefs[unitDefID]
			if unitDef then
				local sizeX = unitDef.xsize * 8
				local sizeZ = unitDef.zsize * 8
				local bw, bh
				if currentFacing % 2 == 1 then bw, bh = sizeZ, sizeX else bw, bh = sizeX, sizeZ end
				local stepX = bw + currentSpacing * 16
				local stepZ = bh + currentSpacing * 16
				local dx = endX - startX
				local dz = endZ - startZ
				local numX = math.floor(math.abs(dx) / stepX) + 1
				local numZ = math.floor(math.abs(dz) / stepZ) + 1
				if numX * numZ > 100 then
					numX = 10
					numZ = 10
				end
				diagPlacementGridRows = numX
				diagPlacementGridCols = numZ
			else
				diagPlacementGridRows = 0
				diagPlacementGridCols = 0
			end
		else
			diagPlacementGridRows = 0
			diagPlacementGridCols = 0
		end
	else
		diagPlacementGridRows = 0
		diagPlacementGridCols = 0
	end

	diagPlacementPreviewCells = #buildPositions

	-- Update cache inputs
	lastDragPreviewCache.active = true
	lastDragPreviewCache.mode = drag.mode
	lastDragPreviewCache.startX = startX
	lastDragPreviewCache.startY = startY
	lastDragPreviewCache.startZ = startZ
	lastDragPreviewCache.endX = endX
	lastDragPreviewCache.endY = endY
	lastDragPreviewCache.endZ = endZ
	lastDragPreviewCache.cmdID = currentCmdID
	lastDragPreviewCache.facing = currentFacing
	lastDragPreviewCache.spacing = currentSpacing
	lastDragPreviewCache.preferNative = currentPreferNative
	UpdateSelectedUnitsCache(selectedUnits)
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

		local cmdInsert = CMD.INSERT
		local lineInsertPos = nil
		if isQueueFront then
			lineInsertPos = ControllerCameraTestNextQueueFrontDragInsertPos() or 0
		end
		if ControllerCameraTestSettings.debugPanelVisible and (isQueueFront or ControllerCameraTestIsQueueFrontModifierActive()) then
			Spring.Echo(string.format(
				"[ControllerQueueDebug] Path: ConfirmDragCommandLine | cmdID: %s | params: %s | Y_insert: %s | RT_append: %s | final_options: %s | wrapper_used: %s | insert_pos: %s | queue_preserve: %s",
				tostring(cmdID),
				serializeTable(points),
				tostring(ControllerCameraTestIsQueueFrontModifierActive()),
				tostring(ControllerCameraTestIsQueueModifierActive()),
				serializeTable(isQueueFront and {"alt"} or {"shift"}),
				tostring(isQueueFront),
				tostring(lineInsertPos or "none"),
				"true (INSERT position advances while modifier is held)"
			))
		end

		if isQueueFront then
			for i = #points, 1, -1 do
				local pt = points[i]
				local unitID = mobileUnits[i]
				-- Vanilla INSERT: {pos, cmdID, encodedOpts, ...params}, outer {"alt"} only
				pcall(spGiveOrderToUnit, unitID, cmdInsert, { lineInsertPos or 0, cmdID, 0, pt[1], pt[2], pt[3] }, { "alt" })
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

	elseif ControllerCameraTestIsAreaTacticalOption(drag.option or { kind = "drag_area", dragMode = drag.mode }) then
		local option = type(drag.option) == "table" and drag.option or { kind = "drag_area", dragMode = drag.mode }
		local mode = option.dragMode or drag.mode
		local rawRadius, effectiveRadius = ControllerCameraTestAreaCommandRadius(startX, startZ, endX, endZ)
		local profile = ControllerCameraTestGetAreaCommandProfile(option)
		local cmdID = ControllerCameraTestGetAreaOptionCommandID(option, mode)
		local cmdName = tostring(option.name or profile.label or "Area Command")

		if ControllerCameraTestIsAreaMexOption(option) then
			local issued, reason = ControllerCameraTestIssueAreaMexRouteA(option, startX, startY, startZ, effectiveRadius)
			drag.lastResult = issued and "Area Mex Route A issued" or ("Area Mex failed: " .. tostring(reason))
			ControllerCameraTestCommandDebug.lastResult = drag.lastResult
			if not issued then
				ControllerCameraTestUpdateAreaCommandDebug("failed", option, rawRadius, effectiveRadius, drag.lastResult)
				latchSelectionDebugMessage(cmdName .. " failed: " .. tostring(reason))
			else
				ControllerCameraTestUpdateAreaCommandDebug("confirmed", option, rawRadius, effectiveRadius, "Route A issued")
			end
		elseif ControllerCameraTestIsRestoreAreaOption(option) then
			local issued, reason = ControllerCameraTestIssueRestoreRouteA(option, startX, startY, startZ, effectiveRadius, ControllerCameraTestIsQueueModifierActive())
			drag.lastResult = issued and "Restore Route A issued" or ("Restore failed: " .. tostring(reason))
			ControllerCameraTestCommandDebug.lastResult = drag.lastResult
			if not issued then
				ControllerCameraTestUpdateAreaCommandDebug("failed", option, rawRadius, effectiveRadius, drag.lastResult)
				latchSelectionDebugMessage(cmdName .. " failed: " .. tostring(reason))
			else
				ControllerCameraTestUpdateAreaCommandDebug("confirmed", option, rawRadius, effectiveRadius, "Route A issued")
			end
		elseif ControllerCameraTestIsRepairAreaOption(option) then
			local issued, reason = ControllerCameraTestIssueRepairAreaRouteA(option, startX, startY, startZ, effectiveRadius, ControllerCameraTestIsQueueModifierActive())
			drag.lastResult = issued and "Repair Route A issued" or ("Repair failed: " .. tostring(reason))
			ControllerCameraTestCommandDebug.lastResult = drag.lastResult
			if not issued then
				ControllerCameraTestUpdateAreaCommandDebug("failed", option, rawRadius, effectiveRadius, drag.lastResult)
				latchSelectionDebugMessage(cmdName .. " failed: " .. tostring(reason))
			else
				ControllerCameraTestUpdateAreaCommandDebug("confirmed", option, rawRadius, effectiveRadius, "Route A issued")
			end
		elseif ControllerCameraTestIsReclaimAreaOption(option) then
			local issued, reason = ControllerCameraTestIssueReclaimAreaRouteA(option, startX, startY, startZ, effectiveRadius, ControllerCameraTestIsQueueModifierActive())
			drag.lastResult = issued and "Reclaim Route A issued" or ("Reclaim failed: " .. tostring(reason))
			ControllerCameraTestCommandDebug.lastResult = drag.lastResult
			if not issued then
				ControllerCameraTestUpdateAreaCommandDebug("failed", option, rawRadius, effectiveRadius, drag.lastResult)
				latchSelectionDebugMessage(cmdName .. " failed: " .. tostring(reason))
			else
				ControllerCameraTestUpdateAreaCommandDebug("confirmed", option, rawRadius, effectiveRadius, "Route A issued")
			end
		elseif type(cmdID) ~= "number" then
			drag.active = false
			drag.lastResult = "failed unavailable cmdID"
			ControllerCameraTestCommandDebug.lastResult = drag.lastResult
			ControllerCameraTestUpdateAreaCommandDebug("failed unavailable", option, rawRadius, effectiveRadius, drag.lastResult)
			latchSelectionDebugMessage(cmdName .. " failed: unavailable")
			return
		else
			local params = { startX, startY, startZ, effectiveRadius }
			local issued = 0
			local lastError = nil
			ControllerCameraTestCommandDebug.issuedCmdID = isQueueFront and tostring(CMD.INSERT) or tostring(cmdID)
			ControllerCameraTestCommandDebug.issuedParamsCount = isQueueFront and 7 or #params

			if ControllerCameraTestSettings.debugPanelVisible and (isQueueFront or ControllerCameraTestIsQueueFrontModifierActive()) then
				Spring.Echo(string.format(
					"[ControllerQueueDebug] Path: ConfirmDragCommandArea | cmdID: %s | params: %s | Y_insert: %s | RT_append: %s | final_options: %s | wrapper_used: %s | queue_preserve: %s",
					tostring(cmdID),
					serializeTable(params),
					tostring(ControllerCameraTestIsQueueFrontModifierActive()),
					tostring(ControllerCameraTestIsQueueModifierActive()),
					serializeTable(isQueueFront and {"alt"} or {"shift"}),
					tostring(isQueueFront),
					"true (INSERT at pos 0 preserves queue)"
				))
			end

			if isQueueFront then
				local cmdInsert = CMD.INSERT
				for _, unitID in ipairs(selectedUnits) do
					-- Vanilla INSERT: {pos, cmdID, encodedOpts, ...params}, outer {"alt"} only
					local ok, result = pcall(spGiveOrderToUnit, unitID, cmdInsert, { 0, cmdID, 0, startX, startY, startZ, effectiveRadius }, { "alt" })
					if ok and result ~= false then
						issued = issued + 1
					else
						lastError = tostring(result)
					end
				end
			else
				for _, unitID in ipairs(selectedUnits) do
					local ok, result = pcall(spGiveOrderToUnit, unitID, cmdID, params, orderOptions)
					if ok and result ~= false then
						issued = issued + 1
					else
						lastError = tostring(result)
					end
				end
			end

			if issued > 0 then
				drag.lastResult = "issued cmdID " .. tostring(cmdID) .. " to " .. tostring(issued) .. " units"
				ControllerCameraTestCommandDebug.lastResult = drag.lastResult
				latchSelectionDebugMessage(cmdName .. " confirmed!")
				ControllerCameraTestSetCommandMarker(startX, startY, startZ, cmdName, profile.key or "area")
				ControllerCameraTestUpdateAreaCommandDebug("confirmed", option, rawRadius, effectiveRadius, drag.lastResult)
			else
				drag.lastResult = "failed no orders accepted" .. (lastError and (": " .. lastError) or "")
				ControllerCameraTestCommandDebug.lastResult = drag.lastResult
				latchSelectionDebugMessage(cmdName .. " failed: no orders accepted")
				ControllerCameraTestUpdateAreaCommandDebug("failed bad params", option, rawRadius, effectiveRadius, drag.lastResult)
			end
		end
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
	ControllerCameraTestClearDragPreviewCache()

	if exitMode then
		ControllerCameraTestCancelPlacement("placed and exited")
	end
end

function ControllerCameraTestCancelDrag(reason)
	local drag = ControllerCameraTestDragCommand
	local wasArea = type(drag.option) == "table" and ControllerCameraTestIsAreaTacticalOption(drag.option)
	if drag.singleUnitPathActive then
		drag.singleUnitPathResult = reason or "single path cancelled"
	end
	drag.active = false
	drag.pressActive = false
	drag.singleUnitPathActive = false
	drag.singleUnitPathUnitID = nil
	drag.lastResult = reason or "cancelled"
	drag.previewPoints = {}
	drag.option = nil
	drag.cmdID = nil
	if wasArea then
		ControllerCameraTestUpdateAreaCommandDebug("cancelled", nil, nil, nil, reason or "cancelled")
	end
	ControllerCameraTestClearNativeBlueprintPreview()
	latchSelectionDebugMessage("Drag cancelled")
end

local function IsUnitInSelection(unitID)
	if not tonumber(unitID) then return false end
	local selectedUnits = type(Spring.GetSelectedUnits) == "function" and Spring.GetSelectedUnits() or {}
	for i = 1, #selectedUnits do
		if selectedUnits[i] == tonumber(unitID) then
			return true
		end
	end
	return false
end

local function ControllerCameraTestSmartDescText(desc)
	return string.lower(tostring(desc and desc.name or "") .. " " .. tostring(desc and desc.action or "") .. " " .. tostring(desc and desc.tooltip or ""))
end

function ControllerCameraTestFindActiveSmartCommandID(descs, lookup, fallbackCmdID, keywords)
	if type(descs) == "table" then
		for _, desc in ipairs(descs) do
			local cmdID = desc and tonumber(desc.id or desc.cmdID)
			if type(cmdID) == "number" and not desc.disabled then
				local text = ControllerCameraTestSmartDescText(desc)
				for _, keyword in ipairs(keywords or {}) do
					if text:find(keyword, 1, true) then
						return cmdID, tostring(desc.action or desc.name or "activeCmdDesc")
					end
				end
			end
		end
	end
	if type(fallbackCmdID) == "number" and (type(lookup) ~= "table" or lookup[fallbackCmdID]) then
		return fallbackCmdID, "CMD constant"
	end
	return nil, "unavailable"
end

function ControllerCameraTestGetSmartCommandIDs()
	local lookup, descs = ControllerCameraTestBuildActiveCommandLookup()
	local ids = {}
	ids.resurrect, ids.resurrectSource = ControllerCameraTestFindActiveSmartCommandID(
		descs,
		lookup,
		CMD.RESURRECT,
		{ "resurrect", "resurrection", "ressurect", "revive", " rez ", " res " }
	)
	ids.reclaim, ids.reclaimSource = ControllerCameraTestFindActiveSmartCommandID(descs, lookup, CMD.RECLAIM, { "reclaim" })
	ids.repair, ids.repairSource = ControllerCameraTestFindActiveSmartCommandID(descs, lookup, CMD.REPAIR, { "repair" })
	ids.guard, ids.guardSource = ControllerCameraTestFindActiveSmartCommandID(descs, lookup, CMD.GUARD, { "guard" })
	ids.attack, ids.attackSource = ControllerCameraTestFindActiveSmartCommandID(descs, lookup, CMD.ATTACK, { "attack" })
	return ids
end

function ControllerCameraTestFindSelfDestructCommandID()
	local lookup, descs = ControllerCameraTestBuildActiveCommandLookup()
	if type(descs) == "table" then
		for _, desc in ipairs(descs) do
			local cmdID = desc and tonumber(desc.id or desc.cmdID)
			if type(cmdID) == "number" and not desc.disabled then
				local text = ControllerCameraTestSmartDescText(desc)
				if text:find("selfd", 1, true)
					or text:find("self destruct", 1, true)
					or text:find("self-destruct", 1, true)
					or text:find("selfdestroy", 1, true)
					or text:find("self destroy", 1, true)
				then
					return cmdID, tostring(desc.action or desc.name or "activeCmdDesc")
				end
			end
		end
	end
	if type(CMD.SELFD) == "number" and (type(lookup) ~= "table" or lookup[CMD.SELFD]) then
		return CMD.SELFD, "CMD.SELFD"
	end
	return nil, "unavailable"
end

function ControllerCameraTestIssueSelfDestruct()
	local state = ControllerCameraTestSelfDestruct
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	state.selectedCount = type(selectedUnits) == "table" and #selectedUnits or 0
	state.issuedCount = 0
	if state.selectedCount == 0 then
		state.lastResult = "failed: no selected units"
		latchSelectionDebugMessage("Self-destruct failed: no selected units")
		return false
	end
	if type(spGiveOrderToUnit) ~= "function" then
		state.lastResult = "failed: GiveOrderToUnit unavailable"
		latchSelectionDebugMessage(state.lastResult)
		return false
	end
	local cmdID, source = ControllerCameraTestFindSelfDestructCommandID()
	state.cmdID = tostring(cmdID or "none") .. " (" .. tostring(source) .. ")"
	if type(cmdID) ~= "number" then
		state.lastResult = "failed: self-destruct command unavailable"
		latchSelectionDebugMessage(state.lastResult)
		return false
	end
	for _, unitID in ipairs(selectedUnits) do
		local ok, result = pcall(spGiveOrderToUnit, unitID, cmdID, {}, {})
		if ok and result ~= false then
			state.issuedCount = state.issuedCount + 1
		end
	end
	if state.issuedCount > 0 then
		state.lastResult = "issued to " .. tostring(state.issuedCount) .. " / " .. tostring(state.selectedCount)
		latchSelectionDebugMessage("Self-destruct issued to " .. tostring(state.issuedCount) .. " units")
		return true
	end
	state.lastResult = "failed: no orders accepted"
	latchSelectionDebugMessage(state.lastResult)
	return false
end

function ControllerCameraTestHandleSelfDestructChord()
	local state = ControllerCameraTestSelfDestruct
	-- Chord: Back/View + R3 (rightStickClick) + L3 (leftStickClick)
	-- Must take priority over DGUN entry (Back + R3 alone).
	-- L3 normal queue-removal is blocked while chord is active (see HandleQueueRemovalInput).
	local chordActive = IsButtonDown("back")
		and IsButtonDown("rightStickClick")
		and IsButtonDown("leftStickClick")
	if not chordActive then
		if state.chordActive and not state.attempted then
			state.lastResult = "cancelled before safety hold"
		end
		state.chordActive = false
		state.holdStartTime = 0
		state.attempted = false
		state.issued = false
		return false
	end

	if not state.chordActive then
		state.chordActive = true
		state.holdStartTime = debugEventTime
		state.attempted = false
		state.issued = false
		state.lastResult = "safety hold started"
	end

	local elapsed = math.max(0, debugEventTime - (state.holdStartTime or debugEventTime))
	state.holdTime = elapsed
	state.selectedCount = #(type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {})
	if not state.attempted and elapsed >= (state.holdSeconds or 0.75) then
		state.attempted = true
		state.issued = ControllerCameraTestIssueSelfDestruct()
	elseif not state.attempted then
		state.lastResult = string.format("holding %.2f / %.2f s (%d units)", elapsed, state.holdSeconds or 0.75, state.selectedCount or 0)
	end
	return true
end

function ControllerCameraTestFeatureIsResurrectable(featureID)
	if not featureID or type(Spring.GetFeatureResurrect) ~= "function" then
		return false
	end
	local ok, unitDefName = pcall(Spring.GetFeatureResurrect, featureID)
	return ok and unitDefName ~= nil and tostring(unitDefName) ~= ""
end

function ControllerCameraTestFeatureIsReclaimable(featureID)
	if not featureID then
		return false
	end
	if type(Spring.GetFeatureResources) ~= "function" then
		return true
	end
	local ok, metal, _, energy, _, reclaimLeft = pcall(Spring.GetFeatureResources, featureID)
	if not ok then
		return true
	end
	return (tonumber(metal) or 0) > 0
		or (tonumber(energy) or 0) > 0
		or (tonumber(reclaimLeft) or 0) > 0
end

function ControllerCameraTestUnitNeedsRepair(unitID)
	if not unitID or type(Spring.GetUnitHealth) ~= "function" then
		return false
	end
	local ok, health, maxHealth, _, _, buildProgress = pcall(Spring.GetUnitHealth, unitID)
	if not ok then
		return false
	end
	if type(health) == "number" and type(maxHealth) == "number" and health < (maxHealth - 1) then
		return true
	end
	return type(buildProgress) == "number" and buildProgress < 1
end

function ControllerCameraTestSmartTargetPosition(target)
	if type(target) ~= "table" then
		return nil, nil, nil
	end
	if target.targetType == "unit" and type(spGetUnitPosition) == "function" then
		local ok, x, y, z = pcall(spGetUnitPosition, target.targetID)
		if ok then
			return x, y, z
		end
	elseif target.targetType == "feature" and type(Spring.GetFeaturePosition) == "function" then
		local ok, x, y, z = pcall(Spring.GetFeaturePosition, target.targetID)
		if ok then
			return x, y, z
		end
	end
	return nil, nil, nil
end

function ControllerCameraTestSmartScreenDistance(target)
	if type(Spring.WorldToScreenCoords) ~= "function" then
		return nil
	end
	local x, y, z = ControllerCameraTestSmartTargetPosition(target)
	if not x or not z then
		return nil
	end
	local ok, sx, sy = pcall(Spring.WorldToScreenCoords, x, y or 0, z)
	if not ok or type(sx) ~= "number" or type(sy) ~= "number" then
		return nil
	end
	local dx = sx - screenCenterX
	local dy = sy - screenCenterY
	return math.sqrt((dx * dx) + (dy * dy))
end

function ControllerCameraTestSmartWorldDistance(target)
	if not reticleWorldX or not reticleWorldZ then
		return nil
	end
	local x, _, z = ControllerCameraTestSmartTargetPosition(target)
	if not x or not z then
		return nil
	end
	local dx = x - reticleWorldX
	local dz = z - reticleWorldZ
	return math.sqrt((dx * dx) + (dz * dz))
end

function ControllerCameraTestSmartAssistScale()
	return ControllerCameraTestClampSetting("smartAssistScale", ControllerCameraTestSettings.smartAssistScale or 1)
end

function ControllerCameraTestUpdateSmartAssistDebug()
	local scale = ControllerCameraTestSmartAssistScale()
	ControllerCameraTestCommandDebug.smartAssistScale = string.format("%.2f", scale)
	ControllerCameraTestCommandDebug.smartEffectiveScreenRadius = string.format("%.1f", ControllerCameraTestSmartTargetScreenRadius * scale)
	ControllerCameraTestCommandDebug.smartEffectiveFeatureRadius = string.format("%.1f", ControllerCameraTestSmartFeatureWorldRadius * scale)
	ControllerCameraTestCommandDebug.smartEffectiveUnitRadius = string.format("%.1f", ControllerCameraTestSmartUnitWorldRadius * scale)
	return scale
end

function ControllerCameraTestClassifySmartTarget(target, commandIDs)
	if type(target) ~= "table" or type(commandIDs) ~= "table" then
		return nil
	end
	if target.targetType == "feature" and tonumber(target.targetID) then
		local featureID = tonumber(target.targetID)
		if commandIDs.resurrect and ControllerCameraTestFeatureIsResurrectable(featureID) then
			return {
				priority = 1,
				action = "resurrect",
				cmdID = commandIDs.resurrect,
				params = { ControllerCameraTestFeatureCommandID(featureID) },
				targetName = "feature " .. tostring(featureID),
				debug = "Smart X: resurrect target feature " .. tostring(featureID),
			}
		end
		if commandIDs.reclaim and ControllerCameraTestFeatureIsReclaimable(featureID) then
			return {
				priority = 3,
				action = "reclaim",
				cmdID = commandIDs.reclaim,
				params = { ControllerCameraTestFeatureCommandID(featureID) },
				targetName = "feature " .. tostring(featureID),
				debug = "Smart X: reclaim target feature " .. tostring(featureID),
			}
		end
	elseif target.targetType == "unit" and tonumber(target.targetID) then
		local unitID = tonumber(target.targetID)
		if IsUnitInSelection(unitID) then
			return nil
		end
		if ControllerCameraTestIsAlliedUnit(unitID) then
			if commandIDs.repair and ControllerCameraTestUnitNeedsRepair(unitID) then
				return {
					priority = 2,
					action = "repair",
					cmdID = commandIDs.repair,
					params = { unitID },
					targetName = "unit " .. tostring(unitID),
					debug = "Smart X: repair target unit " .. tostring(unitID),
				}
			end
			-- TODO: Future transport Smart X load request
			-- For light/heavy air transports, Smart X over a pickup-capable unit should prefer LOAD UNIT instead of Guard.
			-- Add an easy unload/dropoff hotkey for carried units.
			if commandIDs.guard then
				return {
					priority = 4,
					action = "guard",
					cmdID = commandIDs.guard,
					params = { unitID },
					targetName = "unit " .. tostring(unitID),
					debug = "Smart X: guard target unit " .. tostring(unitID),
				}
			end
		elseif commandIDs.attack then
			return {
				priority = 5,
				action = "attack",
				cmdID = commandIDs.attack,
				params = { unitID },
				targetName = "unit " .. tostring(unitID),
				debug = "Smart X: attack target unit " .. tostring(unitID),
			}
		end
	end
	return nil
end

function ControllerCameraTestConsiderSmartCandidate(best, target, commandIDs)
	local classified = ControllerCameraTestClassifySmartTarget(target, commandIDs)
	if not classified then
		return best
	end
	classified.targetType = target.targetType
	classified.targetID = target.targetID
	classified.source = target.source or "assist"
	classified.distance = target.distance or 0
	if not best or classified.priority < best.priority
		or (classified.priority == best.priority and classified.distance < best.distance)
	then
		return classified
	end
	return best
end

function ControllerCameraTestFindAssistedSmartTarget(commandIDs)
	local best = nil
	local seenUnits = {}
	local seenFeatures = {}
	local scale = ControllerCameraTestUpdateSmartAssistDebug()
	if scale <= 0 then
		return nil
	end
	local screenRadius = ControllerCameraTestSmartTargetScreenRadius * scale
	local featureWorldRadius = ControllerCameraTestSmartFeatureWorldRadius * scale
	local unitWorldRadius = ControllerCameraTestSmartUnitWorldRadius * scale

	local function consider(targetType, targetID, source, distance)
		targetID = tonumber(targetID)
		if not targetID then
			return
		end
		if targetType == "unit" then
			if seenUnits[targetID] then return end
			seenUnits[targetID] = true
		elseif targetType == "feature" then
			if seenFeatures[targetID] then return end
			seenFeatures[targetID] = true
		else
			return
		end
		best = ControllerCameraTestConsiderSmartCandidate(best, {
			targetType = targetType,
			targetID = targetID,
			source = source,
			distance = tonumber(distance) or 0,
		}, commandIDs)
	end

	if type(Spring.GetVisibleFeatures) == "function" then
		local ok, features = pcall(Spring.GetVisibleFeatures)
		if ok and type(features) == "table" then
			for _, featureID in ipairs(features) do
				local target = { targetType = "feature", targetID = featureID }
				local dist = ControllerCameraTestSmartScreenDistance(target)
				if dist and dist <= screenRadius then
					consider("feature", featureID, "screen assist", dist)
				end
			end
		end
	end

	if reticleWorldX and reticleWorldZ and type(Spring.GetFeaturesInCylinder) == "function" then
		local ok, features = pcall(Spring.GetFeaturesInCylinder, reticleWorldX, reticleWorldZ, featureWorldRadius)
		if ok and type(features) == "table" then
			for _, featureID in ipairs(features) do
				local target = { targetType = "feature", targetID = featureID }
				local dist = ControllerCameraTestSmartWorldDistance(target)
				consider("feature", featureID, "world assist", dist)
			end
		end
	end

	if type(Spring.GetVisibleUnits) == "function" then
		local ok, units = pcall(Spring.GetVisibleUnits)
		if ok and type(units) == "table" then
			for _, unitID in ipairs(units) do
				local target = { targetType = "unit", targetID = unitID }
				local dist = ControllerCameraTestSmartScreenDistance(target)
				if dist and dist <= screenRadius then
					consider("unit", unitID, "screen assist", dist)
				end
			end
		end
	end

	if reticleWorldX and reticleWorldZ and type(Spring.GetUnitsInCylinder) == "function" then
		local ok, units = pcall(Spring.GetUnitsInCylinder, reticleWorldX, reticleWorldZ, unitWorldRadius)
		if ok and type(units) == "table" then
			for _, unitID in ipairs(units) do
				local target = { targetType = "unit", targetID = unitID }
				local dist = ControllerCameraTestSmartWorldDistance(target)
				consider("unit", unitID, "world assist", dist)
			end
		end
	end

	return best
end

function ControllerCameraTestTrySmartAssistedCommand(exactTargetType, exactTargetID, exactOnly)
	local commandIDs = ControllerCameraTestGetSmartCommandIDs()
	local best = nil
	if (exactTargetType == "unit" or exactTargetType == "feature") and tonumber(exactTargetID) then
		best = ControllerCameraTestConsiderSmartCandidate(nil, {
			targetType = exactTargetType,
			targetID = tonumber(exactTargetID),
			source = "exact trace",
			distance = 0,
		}, commandIDs)
	end
	if not best and not exactOnly then
		best = ControllerCameraTestFindAssistedSmartTarget(commandIDs)
	end
	if not best then
		ControllerCameraTestCommandDebug.smartActionSource = "fallback"
		ControllerCameraTestCommandDebug.smartLastResult = "Smart X: no assisted target, fallback move"
		return false
	end

	ControllerCameraTestCommandDebug.smartAssistTargetType = tostring(best.targetType)
	ControllerCameraTestCommandDebug.smartAssistTargetID = tostring(best.targetID)
	ControllerCameraTestCommandDebug.smartAssistDistance = string.format("%.1f", best.distance or 0)
	ControllerCameraTestCommandDebug.smartChosenAction = tostring(best.action)
	ControllerCameraTestCommandDebug.smartChosenCmdID = tostring(best.cmdID)
	ControllerCameraTestCommandDebug.smartActionSource = tostring(best.source)
	ControllerCameraTestCommandDebug.smartLastResult = tostring(best.debug or "smart assisted command")
	ControllerCameraTestCommandDebug.smartOrderParams = type(best.params) == "table" and table.concat(best.params, ",") or "none"
	latchSelectionDebugMessage(tostring(best.debug or "Smart X assisted command"))
	local actionName = string.upper(string.sub(best.action, 1, 1)) .. string.sub(best.action, 2)
	local ok, issuedCount = ControllerCameraTestIssueOrderToSelectedUnits(best.cmdID, best.params, actionName, best.targetName)
	ControllerCameraTestCommandDebug.smartLastResult = ok
		and (tostring(best.debug or "smart assisted command") .. "; issued to " .. tostring(issuedCount) .. "; fallback move blocked")
		or (tostring(best.debug or "smart assisted command") .. "; issue failed; fallback move blocked")
	return true
end

local function IsUnitAirTransport(unitID)
	local uDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(unitID) or nil
	if not uDefID then return false end
	local ud = UnitDefs[uDefID]
	if ud then
		if ud.transportCapacity and ud.transportCapacity > 0 and ud.canFly then
			return true
		end
		if (ud.isAirTransporter or (ud.tooltip and ud.tooltip:lower():find("transport aircraft"))) and ud.canFly then
			return true
		end
	end
	local cmdDescs = type(Spring.GetUnitCmdDescs) == "function" and Spring.GetUnitCmdDescs(unitID) or nil
	local hasTransportCmds = false
	if cmdDescs then
		for i = 1, #cmdDescs do
			local desc = cmdDescs[i]
			local cmdID = desc and tonumber(desc.id or desc.cmdID)
			if cmdID == 75 or cmdID == 80 then
				hasTransportCmds = true
				break
			end
		end
	end
	if hasTransportCmds and ud and ud.canFly then
		return true
	end
	return false
end

function ControllerCameraTestSelectionIsAirTransport()
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if not selectedUnits or #selectedUnits == 0 then
		return false
	end
	for _, unitID in ipairs(selectedUnits) do
		if not IsUnitAirTransport(unitID) then
			return false
		end
	end
	return true
end

local function TransportsHaveCargo(transports)
	for _, uID in ipairs(transports) do
		if type(Spring.GetUnitIsTransporting) == "function" then
			local cargo = Spring.GetUnitIsTransporting(uID)
			if type(cargo) == "table" and #cargo > 0 then
				return true
			end
		end
	end
	return false
end

local function GetTransportUnloadCommand(transports)
	local descs = type(Spring.GetActiveCmdDescs) == "function" and Spring.GetActiveCmdDescs() or {}
	local hasUnloadUnits = false
	local hasUnloadUnit = false
	for _, desc in ipairs(descs) do
		local cmdID = desc and tonumber(desc.id or desc.cmdID)
		if cmdID == 80 then
			hasUnloadUnits = true
		elseif cmdID == 81 then
			hasUnloadUnit = true
		end
	end
	if hasUnloadUnit then
		return 81
	elseif hasUnloadUnits then
		return 80
	end
	return nil
end

function IsT2Builder(builderDef)
	if type(builderDef) ~= "table" then return false end
	if builderDef.customParams and builderDef.customParams.techlevel == "2" then
		return true
	end
	if type(builderDef.buildOptions) == "table" then
		for _, optDefID in ipairs(builderDef.buildOptions) do
			local optDef = UnitDefs[optDefID]
			if optDef and (optDef.extractsMetal or 0) > 0 and (optDef.metalCost or 0) > 400 then
				return true
			end
		end
	end
	return false
end

function ControllerCameraTestBindingsMatchPreset(preset)
	if type(preset) ~= "table" then return false end
	for _, def in ipairs(ControllerCameraTestBindingDefinitions()) do
		if ControllerCameraTestBindings.actions[def.action] ~= preset[def.action] then
			return false
		end
	end
	return true
end

function ControllerCameraTestRefreshActivePreset()
	ControllerCameraTestBindings.activePreset = ControllerCameraTestBindingsMatchPreset(ControllerCameraTestBuildFirstPreset)
		and CONTROLLER_BUILD_FIRST_PRESET_NAME or "Custom"
	return ControllerCameraTestBindings.activePreset
end

function ControllerCameraTestApplyBindingPreset(presetName)
	if presetName ~= CONTROLLER_BUILD_FIRST_PRESET_NAME then return false, "unknown preset" end
	ControllerCameraTestEnsureBindings()
	for actionName, buttonName in pairs(ControllerCameraTestBuildFirstPreset) do
		ControllerCameraTestBindings.actions[actionName] = buttonName
	end
	ControllerCameraTestBindings.captureAction = nil
	ControllerCameraTestBindings.conflictAction = nil
	ControllerCameraTestBindings.revision = (ControllerCameraTestBindings.revision or 0) + 1
	ControllerCameraTestBindings.activePreset = CONTROLLER_BUILD_FIRST_PRESET_NAME
	ControllerCameraTestBindings.lastAction = "applied preset " .. CONTROLLER_BUILD_FIRST_PRESET_NAME
	return true, CONTROLLER_BUILD_FIRST_PRESET_NAME
end

function ControllerCameraTestIsValidBindingName(value)
	return type(value) == "string"
		and (value == "none" or value == "LT" or value == "RT" or XboxController.buttons[value] ~= nil)
end

function ControllerCameraTestValidateSavedBindings(saved)
	if type(saved) ~= "table" then return false end
	for _, def in ipairs(ControllerCameraTestBindingDefinitions()) do
		if not ControllerCameraTestIsValidBindingName(saved[def.action]) then return false end
	end
	return true
end

function ControllerCameraTestGetExistingUnitBuildFacing(unitID)
	if type(Spring.GetUnitBuildFacing) ~= "function" then
		return 0
	end
	local facingOk, facing = pcall(Spring.GetUnitBuildFacing, unitID)
	if facingOk and type(facing) == "number" then
		return facing % 4
	end
	return 0
end

function ControllerCameraTestAttemptT2UpgradeSmartAction(targetUnitID)
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	if #selectedUnits == 0 then
		return false
	end

	local targetDefID, targetDef = ControllerCameraTestGetUnitDef(targetUnitID)
	if not targetDef then
		return false
	end

	local isMex = (targetDef.extractsMetal or 0) > 0
	local isGeo = targetDef.needGeo == true

	if not isMex and not isGeo then
		return false
	end

	local isT1Mex = isMex and (targetDef.metalCost or 0) < 200
	local isT1Geo = isGeo and (targetDef.metalCost or 0) < 500
	if not isT1Mex and not isT1Geo then
		return false
	end

	local tx, ty, tz = Spring.GetUnitPosition(targetUnitID)
	if not tx then
		return false
	end

	for _, builderID in ipairs(selectedUnits) do
		local builderDefID, builderDef = ControllerCameraTestGetUnitDef(builderID)
		if builderDef and type(builderDef.buildOptions) == "table" then
			local bestUpgradeOptionID = nil
			local bestUpgradeMetalCost = tonumber(targetDef.metalCost) or 0

			for _, optDefID in ipairs(builderDef.buildOptions) do
				local optDef = UnitDefs and UnitDefs[optDefID]
				if optDef then
					local optionMetalCost = tonumber(optDef.metalCost) or 0
					if isMex and (optDef.extractsMetal or 0) > 0 then
						if optionMetalCost > bestUpgradeMetalCost then
							bestUpgradeOptionID = optDefID
							bestUpgradeMetalCost = optionMetalCost
						end
					elseif isGeo and optDef.needGeo == true then
						if optionMetalCost > bestUpgradeMetalCost then
							bestUpgradeOptionID = optDefID
							bestUpgradeMetalCost = optionMetalCost
						end
					end
				end
			end

			if bestUpgradeOptionID then
				local buildCmdID = -bestUpgradeOptionID
				local buildParams = { tx, ty, tz, ControllerCameraTestGetExistingUnitBuildFacing(targetUnitID) }
				local orderOptions = ControllerCameraTestGetCommandOptions()

				local ok, issuedCount = ControllerCameraTestIssueOrderToSelectedUnits(buildCmdID, buildParams, isMex and "Upgrade Mex" or "Upgrade Geo", "point", orderOptions)
				if ok then
					ControllerCameraTestShowHotkeyFeedback(isMex and "UPGRADE MEX" or "UPGRADE GEO", "utility")
					return true
				end
			end
		end
	end

	local hasT2Builder = false
	for _, builderID in ipairs(selectedUnits) do
		local _, builderDef = ControllerCameraTestGetUnitDef(builderID)
		if builderDef and IsT2Builder(builderDef) then
			hasT2Builder = true
			break
		end
	end

	if hasT2Builder then
		latchSelectionDebugMessage("Upgrade: selected builder has no compatible upgrade option")
		return true
	end

	return false
end

local function attemptContextCommand()
	local cmdID = 10 -- Fallback to Move (CMD.MOVE)
	local cmdName = "Move"

	ControllerCameraTestResetMexCommandDebug()
	ControllerCameraTestResetSmartCommandDebug()
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
	local exactTargetType = ok and targetType or nil
	local exactTargetID = ok and targetID or nil
	local hasExactTarget = (exactTargetType == "unit" or exactTargetType == "feature") and tonumber(exactTargetID)

	if exactTargetType == "unit" and exactTargetID then
		if ControllerCameraTestAttemptT2UpgradeSmartAction(exactTargetID) then
			ControllerCameraTestCommandDebug.smartChosenAction = "upgrade"
			return
		end
	end

	ControllerCameraTestCommandDebug.smartExactTargetType = ok and tostring(targetType or "none") or "trace failed"
	ControllerCameraTestCommandDebug.smartExactTargetID = ok and tostring(targetID or "none") or "none"

	-- Dedicated Air Transport Smart X Override
	if ControllerCameraTestSelectionIsAirTransport() then
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if #selectedUnits > 0 then
			if ok and targetType == "unit" and tonumber(targetID) then
				local targetUnitID = tonumber(targetID)
				if ControllerCameraTestIsAlliedUnit(targetUnitID) and not IsUnitInSelection(targetUnitID) then
					local loadCmdID = (CMD and CMD.LOAD_UNITS) or 75
					local loadParams = { targetUnitID }
					local orderOptions = ControllerCameraTestGetCommandOptions()
					local issueOk = false
					if type(spGiveOrderToUnitArray) == "function" then
						local pOk, result = pcall(spGiveOrderToUnitArray, selectedUnits, loadCmdID, loadParams, orderOptions)
						issueOk = pOk and result ~= false
					end
					if not issueOk then
						for _, transportID in ipairs(selectedUnits) do
							pcall(spGiveOrderToUnit, transportID, loadCmdID, loadParams, orderOptions)
						end
						issueOk = true
					end
					if issueOk then
						ControllerCameraTestShowHotkeyFeedback("LOAD UNIT", "utility")
						ControllerCameraTestCommandDebug.lastResult = "issued Load Unit to air transports"
						ControllerCameraTestCommandDebug.smartChosenAction = "load"
						return
					end
				end
			end

			-- X tap over ground / no unit -> Issue normal Move to reticle ground point.
			if reticleHasWorldTarget and reticleWorldX and reticleWorldY and reticleWorldZ then
				local moveCmdID = (CMD and CMD.MOVE) or 10
				local moveParams = { reticleWorldX, reticleWorldY, reticleWorldZ }
				local orderOptions = ControllerCameraTestGetCommandOptions()
				local issueOk = false
				if type(spGiveOrderToUnitArray) == "function" then
					local pOk, result = pcall(spGiveOrderToUnitArray, selectedUnits, moveCmdID, moveParams, orderOptions)
					issueOk = pOk and result ~= false
				end
				if not issueOk then
					for _, transportID in ipairs(selectedUnits) do
						pcall(spGiveOrderToUnit, transportID, moveCmdID, moveParams, orderOptions)
					end
					issueOk = true
				end
				if issueOk then
					ControllerCameraTestShowHotkeyFeedback("MOVE", "utility")
					ControllerCameraTestCommandDebug.lastResult = "issued Move to air transports"
					ControllerCameraTestCommandDebug.smartChosenAction = "move"
					return
				end
			end
		end
		return -- Always return early to bypass normal Smart X behavior and prevent Guard fallback
	end

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
	elseif hasExactTarget and ControllerCameraTestTrySmartAssistedCommand(exactTargetType, exactTargetID, true) then
		return
	elseif cmdID == 10 and reticleHasWorldTarget and reticleWorldX and reticleWorldY and reticleWorldZ
		and ControllerCameraTestAttemptGeoBuildSmartAction(reticleWorldX, reticleWorldY, reticleWorldZ)
	then
		return
	elseif cmdID == 10 and reticleHasWorldTarget and reticleWorldX and reticleWorldY and reticleWorldZ
		and ControllerCameraTestAttemptMexBuildSmartAction(reticleWorldX, reticleWorldY, reticleWorldZ, ControllerCameraTestIsQueueModifierActive(), ControllerCameraTestIsQueueFrontModifierActive())
	then
		ControllerCameraTestCommandDebug.smartChosenAction = "mex"
		ControllerCameraTestCommandDebug.smartActionSource = "mex snap"
		ControllerCameraTestCommandDebug.smartLastResult = ControllerCameraTestCommandDebug.mexActionResult
		return
	elseif ControllerCameraTestTrySmartAssistedCommand(nil, nil) then
		return
	elseif ok and targetType == "unit" and tonumber(targetID) and IsUnitInSelection(targetID) then
		ControllerCameraTestCommandDebug.lastResult = "ignored self-target move"
		ControllerCameraTestCommandDebug.smartLastResult = "ignored self-target selected unit"
		latchSelectionDebugMessage("ignored self-target move")
		return
	elseif ok and targetType == "unit" and tonumber(targetID) then
		-- Only raw-target a unit (not a feature) with the default command.
		-- Feature targets must go through TrySmartAssistedCommand to get proper cmdID.
		-- If TrySmartAssistedCommand returned false for a feature it means no smart command
		-- was found; we do NOT issue a move-to-feature (featureID as param is misinterpreted).
		params = { tonumber(targetID) }
		targetString = "unit " .. tostring(targetID)
		ControllerCameraTestCommandDebug.smartFallbackBlocked = "no"
	elseif ok and targetType == "feature" and tonumber(targetID) then
		-- Feature directly traced; TrySmartAssistedCommand had no match (unit has no
		-- reclaim/resurrect available for this feature). Fall back to world-pos move
		-- rather than passing featureID as a unit-target param.
		ControllerCameraTestCommandDebug.smartFeatureRawID = tostring(targetID)
		ControllerCameraTestCommandDebug.smartFallbackBlocked = "yes (feature: using world pos)"
		if reticleHasWorldTarget and reticleWorldX and reticleWorldY and reticleWorldZ then
			params = { reticleWorldX, reticleWorldY, reticleWorldZ }
			targetString = "ground (from feature " .. tostring(targetID) .. ")"
			ControllerCameraTestCommandDebug.smartLastResult = "Smart X: feature no smart cmd, world pos fallback"
		else
			ControllerCameraTestCommandDebug.lastResult = "Smart X: feature no smart cmd, no world pos - aborted"
			latchSelectionDebugMessage("Smart X: feature no smart cmd, aborted")
			return
		end
	elseif reticleHasWorldTarget and reticleWorldX and reticleWorldY and reticleWorldZ then
		params = { reticleWorldX, reticleWorldY, reticleWorldZ }
		targetString = "ground"
		ControllerCameraTestCommandDebug.smartFallbackBlocked = "no"
		ControllerCameraTestCommandDebug.smartLastResult = "Smart X: no assisted target, fallback move"
	else
		ControllerCameraTestCommandDebug.lastResult = "context failed: no target"
		ControllerCameraTestCommandDebug.smartLastResult = "context failed: no target"
		latchSelectionDebugMessage("X context failed: no target")
		return
	end

	-- Smart X no-Move guard check
	local nearMexSpot = false
	local mexSpotID = nil
	local finder = WG.resource_spot_finder
	if finder and type(finder.GetClosestMexSpot) == "function" and reticleHasWorldTarget and reticleWorldX and reticleWorldZ then
		local nearestSpot = finder.GetClosestMexSpot(reticleWorldX, reticleWorldZ)
		if nearestSpot then
			local spotX = nearestSpot.x or nearestSpot[1]
			local spotZ = nearestSpot.z or nearestSpot[3] or nearestSpot[2]
			if spotX and spotZ then
				local dx = spotX - reticleWorldX
				local dz = spotZ - reticleWorldZ
				local distSq = (dx * dx) + (dz * dz)
				local SMART_X_MEX_CONTEXT_RADIUS = 55
				if distSq <= (SMART_X_MEX_CONTEXT_RADIUS * SMART_X_MEX_CONTEXT_RADIUS) then
					nearMexSpot = true
					mexSpotID = string.format("%.0f,%.0f", spotX, spotZ)
				end
			end
		end
	end

	local isGuardTarget = false
	local guardReason = nil
	local guardID = nil

	if cmdID == 10 then
		if ok and targetType == "feature" then
			isGuardTarget = true
			guardReason = "feature"
			guardID = targetID
		elseif ok and targetType == "unit" and tonumber(targetID) and not IsUnitInSelection(targetID) then
			isGuardTarget = true
			guardReason = "unit"
			guardID = targetID
		elseif nearMexSpot then
			-- Only block Move if there is no exact target taking precedence
			if not (ok and (targetType == "unit" or targetType == "feature") and tonumber(targetID)) then
				isGuardTarget = true
				guardReason = "mex spot"
				guardID = mexSpotID
			end
		end
	end

	if isGuardTarget then
		local selectedUnits = type(Spring.GetSelectedUnits) == "function" and Spring.GetSelectedUnits() or {}

		if ControllerCameraTestSettings.debugPanelVisible then
			local selectedTypes = {}
			for _, uID in ipairs(selectedUnits) do
				local uDefID = Spring.GetUnitDefID(uID)
				if uDefID then
					local uDef = UnitDefs[uDefID]
					if uDef then
						selectedTypes[uDef.name] = (selectedTypes[uDef.name] or 0) + 1
					end
				end
			end
			local typesStr = ""
			for uName, count in pairs(selectedTypes) do
				if typesStr ~= "" then typesStr = typesStr .. ", " end
				typesStr = typesStr .. uName .. " (" .. tostring(count) .. ")"
			end

			Spring.Echo(string.format(
				"[SmartXGuard] TargetType: %s | TargetID: %s | SelectedCount: %d | SelectedTypes: {%s} | IntendedAction: %s | FallbackCmdID: %d | Result: blocked Move fallback",
				tostring(guardReason),
				tostring(guardID or "none"),
				#selectedUnits,
				typesStr,
				"Move fallback to " .. tostring(targetString),
				cmdID
			))
		end

		ControllerCameraTestCommandDebug.lastResult = "SmartXGuard blocked Move fallback over " .. tostring(guardReason)
		if ControllerCameraTestSettings.debugPanelVisible then
			latchSelectionDebugMessage("Smart X: blocked Move fallback over " .. tostring(guardReason))
		end
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

local function attemptFightCommand()
	if not reticleHasWorldTarget or not reticleWorldX or not reticleWorldY or not reticleWorldZ then
		latchSelectionDebugMessage("Fight skipped: no world target")
		return
	end
	local params = { reticleWorldX, reticleWorldY, reticleWorldZ }
	local targetName = string.format("x=%.1f, y=%.1f, z=%.1f", reticleWorldX, reticleWorldY, reticleWorldZ)
	issueOrderToSelection(CMD.FIGHT, params, "Fight", targetName)
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

function ControllerCameraTestIsOwnedUnit(unitID)
	if not unitID or type(Spring.GetUnitTeam) ~= "function" then
		return false
	end
	local unitTeam = Spring.GetUnitTeam(unitID)
	local myTeam = type(Spring.GetMyTeamID) == "function" and Spring.GetMyTeamID()
	return unitTeam ~= nil and myTeam ~= nil and unitTeam == myTeam
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

function ControllerCameraTestIsBuilderUnitDef(unitDef)
	return type(unitDef) == "table" and (unitDef.isBuilder or unitDef.canBuild
		or (type(unitDef.buildOptions) == "table" and #unitDef.buildOptions > 0)) == true
end

function ControllerCameraTestHasCombatRole(unitDef)
	local group = type(unitDef) == "table" and unitDef.customParams and unitDef.customParams.unitgroup
	return group == "weapon" or group == "explo" or group == "weaponaa" or group == "weaponsub"
		or group == "aa" or group == "emp" or group == "sub" or group == "nuke" or group == "antinuke"
end

function ControllerCameraTestIsSafeSelectableUnit(unitID)
	if not ControllerCameraTestIsOwnedUnit(unitID) then return false end
	if type(Spring.GetUnitIsDead) == "function" then
		local ok, dead = pcall(Spring.GetUnitIsDead, unitID)
		if not ok or dead then return false end
	end
	local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
	return unitDef ~= nil
end

function ControllerCameraTestSafeSelectionSnapshot(units)
	local result, seen = {}, {}
	for _, unitID in ipairs(type(units) == "table" and units or {}) do
		if not seen[unitID] and ControllerCameraTestIsSafeSelectableUnit(unitID) then
			seen[unitID], result[#result + 1] = true, unitID
		end
	end
	table.sort(result)
	return result
end

function ControllerCameraTestSelectionsEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	for index = 1, #a do if a[index] ~= b[index] then return false end end
	return true
end

function ControllerCameraTestRecordSelectionSnapshot(units)
	local history = ControllerCameraTestVisibleSelection
	local safe = ControllerCameraTestSafeSelectionSnapshot(units)
	if history.suppressNextSnapshot then
		history.suppressNextSnapshot = false
		history.currentSelection = safe
		history.selectionRevision = (history.selectionRevision or 0) + 1
		return
	end
	if ControllerCameraTestSelectionsEqual(safe, history.currentSelection or {}) then return end
	if #(history.currentSelection or {}) > 0 then
		history.previousSelection = ControllerCameraTestSafeSelectionSnapshot(history.currentSelection)
	end
	history.currentSelection = safe
	history.selectionRevision = (history.selectionRevision or 0) + 1
end

function ControllerCameraTestSelectSnapshot(units, label, skipPrevious)
	local safe = ControllerCameraTestSafeSelectionSnapshot(units)
	if #safe == 0 or type(spSelectUnitArray) ~= "function" then return false end
	local history = ControllerCameraTestVisibleSelection
	local current = ControllerCameraTestSafeSelectionSnapshot(type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {})
	if not skipPrevious and #current > 0 and not ControllerCameraTestSelectionsEqual(current, safe) then
		history.previousSelection = current
	end
	history.suppressNextSnapshot = true
	local ok = pcall(spSelectUnitArray, safe, false)
	if not ok then history.suppressNextSnapshot = false; return false end
	history.currentSelection = safe
	history.selectionRevision = (history.selectionRevision or 0) + 1
	ControllerCameraTestCycleDebug.lastResult = tostring(label or "Selection") .. ": " .. #safe
	return true
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

function ControllerCameraTestApplyVisibleSelectionFilter(filter)
	filter = ControllerSelectionBehavior and ControllerSelectionBehavior.IsValidFilter(filter) and filter or "Combat"
	if not ControllerSelectionBehavior then return false end
	local history = ControllerCameraTestVisibleSelection
	if filter == "Last Selected" then
		local previous = ControllerCameraTestSafeSelectionSnapshot(history.previousSelection)
		if #previous == 0 then return false end
		local current = ControllerCameraTestSafeSelectionSnapshot(type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {})
		if #current > 0 and not ControllerCameraTestSelectionsEqual(current, previous) then history.previousSelection = current end
		return ControllerCameraTestSelectSnapshot(previous, "Restored last selection", true)
	end
	if type(Spring.GetVisibleUnits) ~= "function" then
		ControllerCameraTestCycleDebug.lastResult = "LB visible selection unavailable"
		return false
	end

	local ok, visibleUnits = pcall(Spring.GetVisibleUnits)
	if not ok or type(visibleUnits) ~= "table" then
		ControllerCameraTestCycleDebug.lastResult = "LB visible selection query failed"
		return false
	end

	local unitsToSelect = ControllerSelectionBehavior.FilterVisibleUnits(visibleUnits, filter, function(unitID)
		local safe = ControllerCameraTestIsSafeSelectableUnit(unitID)
		local unitDef = nil
		if safe then local ignored; ignored, unitDef = ControllerCameraTestGetUnitDef(unitID) end
		local mobile = unitDef and ControllerCameraTestIsMobileUnitDef(unitDef) or false
		local builder = mobile and ControllerCameraTestIsBuilderUnitDef(unitDef) or false
		return { safe = safe and unitDef ~= nil, mobile = mobile, builder = builder,
			air = unitDef and unitDef.canFly == true, combat = unitDef and ControllerCameraTestIsCombatUnitDef(unitDef),
			combatRole = unitDef and ControllerCameraTestHasCombatRole(unitDef) }
	end)
	if #unitsToSelect == 0 then ControllerCameraTestCycleDebug.lastResult = "LB " .. filter .. " selection: 0"; return false end
	return ControllerCameraTestSelectSnapshot(unitsToSelect, "LB selected visible " .. string.lower(filter))
end

function ControllerCameraTestSelectCombatUnitsOnScreen()
	return ControllerCameraTestApplyVisibleSelectionFilter("Combat")
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

	local isBuild = type(cmdID) == "number" and cmdID < 0
	local useInsert = not isBuild and (options == nil or #options == 0) and ControllerCameraTestIsQueueFrontModifierActive()
	local finalOpts = type(options) == "table" and options or ControllerCameraTestGetCommandOptions()

	-- If it's a build command and queue front is active, ensure we pass "alt" natively instead of CMD.INSERT
	if isBuild and ControllerCameraTestIsQueueFrontModifierActive() then
		local hasAlt = false
		for _, opt in ipairs(finalOpts) do
			if opt == "alt" then hasAlt = true end
		end
		if not hasAlt then
			finalOpts = { "alt" }
		end
	end

	-- INSERT outer options: vanilla cmd_commandinsert uses {"alt"} only.
	-- Do NOT use {"alt","shift"} - "shift" would append the INSERT cmd itself
	-- to the queue instead of executing it immediately at position 0.
	local finalOptsTable = useInsert and {"alt"} or finalOpts
	local queuePreserveFlag = false
	for _, opt in ipairs(finalOptsTable) do
		if opt == "shift" then
			queuePreserveFlag = true
		end
	end

	if ControllerCameraTestSettings.debugPanelVisible and ControllerCameraTestIsQueueFrontModifierActive() then
		Spring.Echo(string.format(
			"[ControllerQueueDebug] Path: IssueOrderToSelectedUnits | cmdID: %s | params: %s | Y_insert: %s | RT_append: %s | final_options: %s | wrapper_used: %s | queue_preserve: %s",
			tostring(cmdID),
			serializeTable(params),
			tostring(ControllerCameraTestIsQueueFrontModifierActive()),
			tostring(ControllerCameraTestIsQueueModifierActive()),
			serializeTable(finalOptsTable),
			tostring(useInsert),
			"true (INSERT at pos 0 preserves queue)"
		))
	end

	ControllerCameraTestCommandDebug.issuedCmdID = useInsert and tostring(CMD.INSERT) or tostring(cmdID)
	ControllerCameraTestCommandDebug.issuedParamsCount = useInsert and (#params + 3) or #params
	ControllerCameraTestCommandDebug.lastOptions = useInsert and "alt (INSERT front)" or ControllerCameraTestCommandOptionsSummary(finalOpts)
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
	local cmdInsert = CMD.INSERT
	for _, unitID in ipairs(selectedUnits) do
		local ok, result
		if useInsert then
			-- Vanilla INSERT: {pos, cmdID, encodedOpts, ...params}, outer {"alt"} only
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

--------------------------------------------------------------------------------
-- SECTION: Friendly selection toggling and persistent Disassemble Mode
--------------------------------------------------------------------------------
function ControllerCameraTestGetReticleOwnedTarget()
	local target = ControllerCameraTestGetReticleTargetInfo()
	if target.targetType ~= "unit" or not target.targetID or not ControllerCameraTestIsSafeSelectableUnit(target.targetID) then
		return nil, nil, nil
	end
	local unitDefID, unitDef = ControllerCameraTestGetUnitDef(target.targetID)
	if not unitDefID or not unitDef then return nil, nil, nil end
	return target.targetID, unitDefID, unitDef
end

function ControllerCameraTestUnitHasReclaimCapability(unitID)
	if not ControllerCameraTestIsSafeSelectableUnit(unitID) then return false end
	local reclaimID = (CMD and CMD.RECLAIM) or 90
	if type(Spring.FindUnitCmdDesc) == "function" then
		local ok, index = pcall(Spring.FindUnitCmdDesc, unitID, reclaimID)
		if ok and type(index) == "number" and index > 0 then return true end
	end
	if type(Spring.GetUnitCmdDescs) == "function" then
		local ok, descriptors = pcall(Spring.GetUnitCmdDescs, unitID)
		if ok and type(descriptors) == "table" then
			for _, descriptor in ipairs(descriptors) do
				if type(descriptor) == "table" then
					local id = tonumber(descriptor.id or descriptor.cmdID)
					local action = string.lower(tostring(descriptor.action or descriptor.name or ""))
					if id == reclaimID or action == "reclaim" or string.find(action, "reclaim", 1, true) then return true end
				end
			end
		end
	end
	local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
	return type(unitDef) == "table" and unitDef.canReclaim == true
end

function ControllerCameraTestPruneMarkedTargets()
	local state = ControllerCameraTestDisassemble
	for unitID in pairs(state.markedTargets or {}) do
		if not ControllerCameraTestIsSafeSelectableUnit(unitID) then state.markedTargets[unitID] = nil end
	end
end

function ControllerCameraTestGetNativeActiveCommandID()
	if type(Spring.GetActiveCommand) ~= "function" then return nil end
	local ok, _, cmdID = pcall(Spring.GetActiveCommand)
	return ok and tonumber(cmdID) or nil
end

function ControllerCameraTestCancelNativeTargeting()
	local hadTargeting = false
	if WG.smartareareclaim and type(WG.smartareareclaim.controllerGetState) == "function" then
		local ok, active = pcall(WG.smartareareclaim.controllerGetState)
		hadTargeting = ok and active == true
		if hadTargeting and type(WG.smartareareclaim.controllerCancel) == "function" then
			pcall(WG.smartareareclaim.controllerCancel)
		end
	end
	if ControllerCameraTestGetNativeActiveCommandID() ~= nil then
		hadTargeting = true
		pcall(Spring.SetActiveCommand, nil)
	end
	ControllerCameraTestDisassemble.areaReclaim.active = false
	ControllerCameraTestDisassemble.areaReclaim.candidates = {}
	return hadTargeting
end

function ControllerCameraTestIssueNativeDisassembleMove()
	ControllerCameraTestCancelNativeTargeting()
	if not reticleHasWorldTarget or not reticleWorldX or not reticleWorldZ then
		latchSelectionDebugMessage("Move failed: no ground under reticle")
		return false
	end
	local ok = ControllerCameraTestIssueOrderToSelectedUnits((CMD and CMD.MOVE) or 10,
		{ reticleWorldX, reticleWorldY or 0, reticleWorldZ }, "Move", "ground", {})
	if ok then ControllerCameraTestShowHotkeyFeedback("MOVE", "utility") end
	return ok == true
end

function ControllerCameraTestIssueNativeDisassembleStop()
	ControllerCameraTestCancelNativeTargeting()
	local stopID = (CMD and CMD.STOP) or 0
	local accepted = false
	if WG.ordermenu and type(WG.ordermenu.controllerActivate) == "function" then
		local ok, result = pcall(WG.ordermenu.controllerActivate, stopID, 1)
		accepted = ok and result == true
	end
	if not accepted then
		local selected = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if #selected > 0 and type(spGiveOrderToUnitArray) == "function" then
			local ok, result = pcall(spGiveOrderToUnitArray, selected, stopID, {}, {})
			accepted = ok and result ~= false
		end
	end
	if accepted then ControllerCameraTestShowHotkeyFeedback("STOP", "utility") end
	return accepted
end

function ControllerCameraTestBeginNativeReclaim(mode, targetID, unitDefID)
	if not targetID or not ControllerCameraTestIsSafeSelectableUnit(targetID) then return false end
	local x, y, z = spGetUnitPosition(targetID)
	if not x or not z or not WG.smartareareclaim
			or type(WG.smartareareclaim.controllerBegin) ~= "function" then
		return false
	end
	local radius = mode == "same" and 120 or nil
	local ok, result = pcall(WG.smartareareclaim.controllerBegin, mode, targetID, x, y, z, radius)
	if not ok or result ~= true then return false end
	local state = ControllerCameraTestDisassemble
	state.areaReclaim = { active = mode == "same", anchorUnitID = targetID, unitDefID = unitDefID,
		x = x, y = y or 0, z = z, radius = radius or 0, candidates = {} }
	state.lastResult = "native " .. tostring(mode) .. " reclaim active"
	return true
end

function ControllerCameraTestConfirmNativeReclaim()
	if not WG.smartareareclaim or type(WG.smartareareclaim.controllerConfirm) ~= "function" then
		return false
	end
	local ok, result = pcall(WG.smartareareclaim.controllerConfirm, ControllerCameraTestIsQueueModifierActive())
	ControllerCameraTestDisassemble.areaReclaim.active = false
	if ok and result == true then
		ControllerCameraTestDisassemble.successfulActivity = true
		ControllerCameraTestShowHotkeyFeedback("RECLAIM", "reclaim")
		return true
	end
	return false
end

function ControllerCameraTestConfirmNativeActiveCommand(cmdID)
	cmdID = tonumber(cmdID)
	if not cmdID then return false end
	local target = ControllerCameraTestGetReticleTargetInfo()
	if cmdID == ((CMD and CMD.RECLAIM) or 90) and target.targetType == "unit" then
		local targetID, unitDefID = ControllerCameraTestGetReticleOwnedTarget()
		if targetID and ControllerCameraTestBeginNativeReclaim("single", targetID, unitDefID) then
			return ControllerCameraTestConfirmNativeReclaim()
		end
		return false
	end

	local params
	if cmdID ~= ((CMD and CMD.MOVE) or 10) and cmdID >= 0
			and target.targetType == "unit" and target.targetID then
		params = { target.targetID }
	elseif cmdID ~= ((CMD and CMD.MOVE) or 10) and cmdID >= 0
			and target.targetType == "feature" and target.targetID then
		params = { ControllerCameraTestFeatureCommandID(target.targetID) }
	elseif target.hasWorld and target.x and target.z then
		params = { target.x, target.y or 0, target.z }
	else
		return false
	end

	local issued = ControllerCameraTestIssueOrderToSelectedUnits(cmdID, params,
		"Native command " .. tostring(cmdID), target.targetType)
	if issued and not ControllerCameraTestIsQueueModifierActive() then
		pcall(Spring.SetActiveCommand, nil)
	end
	return issued == true
end

function ControllerCameraTestUpdateNativeDisassembleInput(dt)
	local state = ControllerCameraTestDisassemble
	local lbDown = ControllerCameraTestActionDown("pitchModifier")

	if lbDown and ControllerCameraTestActionPressed("cancel") then
		ControllerCameraTestIssueNativeDisassembleStop()
		return true
	end
	if ControllerCameraTestActionPressed("smartAction") then
		ControllerCameraTestIssueNativeDisassembleMove()
		return true
	end
	if ControllerCameraTestActionPressed("cancel") then
		if ControllerCameraTestCancelNativeTargeting() then
			state.lastResult = "native targeting cancelled"
			ControllerCameraTestShowHotkeyFeedback("TARGET CANCELLED", "utility")
		else
			pcall(spSelectUnitArray, {})
			state.lastResult = "native selection cleared"
			ControllerCameraTestShowHotkeyFeedback("SELECTION CLEARED", "utility")
		end
		return true
	end

	if state.areaReclaim.active then
		local area = state.areaReclaim
		if reticleHasWorldTarget and reticleWorldX and reticleWorldZ then
			local dx, dz = reticleWorldX - area.x, reticleWorldZ - area.z
			area.radius = clamp(math.sqrt(dx * dx + dz * dz), 16, 1200)
			if WG.smartareareclaim and type(WG.smartareareclaim.controllerUpdate) == "function" then
				pcall(WG.smartareareclaim.controllerUpdate, area.anchorUnitID,
					area.x, area.y, area.z, area.radius)
			end
		end
		if ControllerCameraTestActionReleased("select") then
			state.lbA.pressActive, state.lbA.holdFired = false, false
			ControllerCameraTestConfirmNativeReclaim()
		end
		return true
	end

	if lbDown and ControllerCameraTestActionPressed("select") then
		local targetID, unitDefID = ControllerCameraTestGetReticleOwnedTarget()
		state.lbA = { pressActive = targetID ~= nil, startedAt = debugEventTime,
			targetID = targetID, unitDefID = unitDefID, holdFired = false }
		return true
	end
	if state.lbA.pressActive and lbDown and ControllerCameraTestActionDown("select") then
		local threshold = ControllerCameraTestSettings.areaReclaimHoldSeconds or 0.45
		if not state.lbA.holdFired and debugEventTime - state.lbA.startedAt >= threshold then
			state.lbA.holdFired = ControllerCameraTestBeginNativeReclaim("same",
				state.lbA.targetID, state.lbA.unitDefID)
		end
		return true
	end
	if state.lbA.pressActive and ControllerCameraTestActionReleased("select") then
		if not state.lbA.holdFired and ControllerCameraTestBeginNativeReclaim("single",
				state.lbA.targetID, state.lbA.unitDefID) then
			ControllerCameraTestConfirmNativeReclaim()
		end
		state.lbA.pressActive, state.lbA.holdFired = false, false
		return true
	end
	if not lbDown and ControllerCameraTestActionPressed("select") then
		local activeCommandID = ControllerCameraTestGetNativeActiveCommandID()
		if activeCommandID then
			if not ControllerCameraTestConfirmNativeActiveCommand(activeCommandID) then
				latchSelectionDebugMessage("Native command target unavailable")
			end
			return true
		end
		attemptReticleSelection()
		return true
	end
	return true
end

function ControllerCameraTestSelectionsContainSameUnits(first, second)
	local a, b = ControllerCameraTestSafeSelectionSnapshot(first), ControllerCameraTestSafeSelectionSnapshot(second)
	return ControllerCameraTestSelectionsEqual(a, b)
end

function ControllerCameraTestValidateReclaimers(keepActualSelection)
	local state, valid = ControllerCameraTestDisassemble, {}
	if ControllerCameraTestUsesNativeBARUI() then
		local selected = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		for _, unitID in ipairs(selected) do
			if ControllerCameraTestUnitHasReclaimCapability(unitID) then valid[#valid + 1] = unitID end
		end
		state.reclaimers = valid
		return #valid > 0
	end
	for _, unitID in ipairs(state.reclaimers or {}) do
		if ControllerCameraTestUnitHasReclaimCapability(unitID) then valid[#valid + 1] = unitID end
	end
	table.sort(valid)
	state.reclaimers = valid
	ControllerCameraTestPruneMarkedTargets()
	if state.active and #valid == 0 then
		ControllerCameraTestExitDisassembleMode("Disassemble Mode Ended: No Reclaimers", "reclaimers invalid")
		return false
	end
	if state.active and keepActualSelection ~= false and type(spGetSelectedUnits) == "function" and type(spSelectUnitArray) == "function" then
		local selected = spGetSelectedUnits() or {}
		if not ControllerCameraTestSelectionsContainSameUnits(selected, valid) then
			ControllerCameraTestVisibleSelection.suppressNextSnapshot = true
			pcall(spSelectUnitArray, valid, false)
		end
	end
	return #valid > 0
end

function ControllerCameraTestCancelDisassembleSubstates(reason)
	local state = ControllerCameraTestDisassemble
	if ControllerCameraTestUsesNativeBARUI() then ControllerCameraTestCancelNativeTargeting() end
	state.markArea.pressActive, state.markArea.active = false, false
	state.markArea.typeFilter = nil
	state.areaReclaim.active, state.areaReclaim.anchorUnitID = false, nil
	state.areaReclaim.unitDefID, state.areaReclaim.candidates = nil, {}
	state.lbA.pressActive, state.lbA.holdFired, state.lbA.targetID = false, false, nil
	state.lastResult = tostring(reason or "targeting cancelled")
end

function ControllerCameraTestEnterDisassembleMode()
	local state = ControllerCameraTestDisassemble
	local selected = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local reclaimers = {}
	for _, unitID in ipairs(selected) do
		if ControllerCameraTestUnitHasReclaimCapability(unitID) then reclaimers[#reclaimers + 1] = unitID end
	end
	table.sort(reclaimers)
	if #reclaimers == 0 then
		state.lastResult = "no reclaim-capable selection"
		ControllerCameraTestShowHotkeyFeedback("SELECT RECLAIM-CAPABLE UNITS", "utility")
		return false
	end
	if ControllerCameraTestUsesNativeBARUI() then
		state.active, state.reclaimers, state.markedTargets, state.highlightedTargets = true, reclaimers, {}, {}
		state.activatedAt, state.successfulActivity, state.lastValidationAt = debugEventTime, false, debugEventTime
		ControllerCameraTestCancelDisassembleSubstates("native mode entered")
		state.active, state.reclaimers = true, reclaimers
		state.lastResult = "native enabled with " .. tostring(#reclaimers) .. " reclaimers"
		ControllerCameraTestShowHotkeyFeedback("NATIVE DISASSEMBLE ENABLED", "reclaim")
		return true
	end
	state.active, state.reclaimers, state.markedTargets, state.highlightedTargets = true, reclaimers, {}, {}
	state.activatedAt, state.successfulActivity, state.lastValidationAt = debugEventTime, false, debugEventTime
	ControllerCameraTestCancelDisassembleSubstates("mode entered")
	state.active, state.reclaimers, state.activatedAt, state.successfulActivity = true, reclaimers, debugEventTime, false
	if type(spSelectUnitArray) == "function" then
		ControllerCameraTestVisibleSelection.suppressNextSnapshot = true
		pcall(spSelectUnitArray, reclaimers, false)
	end
	state.lastResult = "enabled with " .. tostring(#reclaimers) .. " reclaimers"
	ControllerCameraTestShowHotkeyFeedback("DISASSEMBLE MODE ENABLED", "reclaim")
	return true
end

function ControllerCameraTestExitDisassembleMode(toast, reason)
	local state = ControllerCameraTestDisassemble
	if not state.active and not state.toggle.charging then return false end
	ControllerCameraTestCancelDisassembleSubstates(reason or "mode exited")
	state.active, state.markedTargets, state.highlightedTargets = false, {}, {}
	state.reclaimers, state.successfulActivity = {}, false
	state.lastResult = tostring(reason or "disabled")
	ControllerCameraTestShowHotkeyFeedback(string.upper(toast or "Disassemble Mode Disabled"), "utility")
	return true
end

function ControllerCameraTestCollectOwnedTargetsInRadius(x, z, radius, typeFilter)
	local candidates = {}
	if type(Spring.GetUnitsInCylinder) == "function" and x and z and radius then
		local myTeam = type(Spring.GetMyTeamID) == "function" and Spring.GetMyTeamID() or nil
		local ok, units = pcall(Spring.GetUnitsInCylinder, x, z, radius, myTeam)
		if not ok or type(units) ~= "table" then ok, units = pcall(Spring.GetUnitsInCylinder, x, z, radius) end
		if ok and type(units) == "table" then
			for _, unitID in ipairs(units) do
				local unitDefID = type(Spring.GetUnitDefID) == "function" and Spring.GetUnitDefID(unitID) or nil
				if ControllerCameraTestIsSafeSelectableUnit(unitID)
						and (type(typeFilter) ~= "table" or typeFilter[unitDefID] == true) then
					candidates[#candidates + 1] = unitID
				end
			end
		end
	end
	if ControllerDisassembleBehavior then return ControllerDisassembleBehavior.OrderTargets(candidates) end
	table.sort(candidates); return candidates
end

function ControllerCameraTestMarkSingleTarget(unitID, additive)
	if not ControllerCameraTestIsSafeSelectableUnit(unitID) then return false end
	local state = ControllerCameraTestDisassemble
	if additive then
		if state.markedTargets[unitID] then state.markedTargets[unitID] = nil else state.markedTargets[unitID] = true end
	else
		state.markedTargets = { [unitID] = true }
	end
	state.lastResult = additive and "target toggled" or "single target marked"
	return true
end

function ControllerCameraTestFinishDisassembleAreaMark()
	local state, area = ControllerCameraTestDisassemble, ControllerCameraTestDisassemble.markArea
	local units = ControllerCameraTestCollectOwnedTargetsInRadius(reticleWorldX, reticleWorldZ, area.radius, area.typeFilter)
	if ControllerDisassembleBehavior then
		state.markedTargets = ControllerDisassembleBehavior.MergeMarked(state.markedTargets, units, area.additive)
	else
		if not area.additive then state.markedTargets = {} end
		for _, unitID in ipairs(units) do state.markedTargets[unitID] = true end
	end
	area.pressActive, area.active, area.typeFilter = false, false, nil
	state.lastResult = "area marked " .. tostring(#units)
	return #units
end

function ControllerCameraTestUpdateDisassembleAreaRadius(area, dt)
	local delta = (-normalizedRightY * 520 * (dt or 0))
	if WasButtonPressed("dpadUp") or WasButtonPressed("dpadRight") then delta = delta + 80
	elseif WasButtonPressed("dpadDown") or WasButtonPressed("dpadLeft") then delta = delta - 80 end
	if delta ~= 0 then area.radius = clamp((area.radius or 320) + delta,
		ControllerDisassembleBehavior and ControllerDisassembleBehavior.MIN_TARGET_RADIUS or 120,
		ControllerDisassembleBehavior and ControllerDisassembleBehavior.MAX_TARGET_RADIUS or 1200) end
end

function ControllerCameraTestIssueDisassembleReclaim(targets)
	local state = ControllerCameraTestDisassemble
	if not ControllerCameraTestValidateReclaimers(false) then return 0 end
	local ordered = ControllerDisassembleBehavior and ControllerDisassembleBehavior.OrderTargets(targets) or targets
	local validTargets = {}
	for _, unitID in ipairs(type(ordered) == "table" and ordered or {}) do
		if ControllerCameraTestIsSafeSelectableUnit(unitID) then validTargets[#validTargets + 1] = unitID end
	end
	local issuedTargets, reclaimID = 0, (CMD and CMD.RECLAIM) or 90
	for index, targetID in ipairs(validTargets) do
		local options = index == 1 and {} or { "shift" }
		local accepted = false
		if type(spGiveOrderToUnitArray) == "function" then
			local ok, result = pcall(spGiveOrderToUnitArray, state.reclaimers, reclaimID, { targetID }, options)
			accepted = ok and result ~= false
		elseif type(spGiveOrderToUnit) == "function" then
			for _, reclaimerID in ipairs(state.reclaimers) do
				local ok, result = pcall(spGiveOrderToUnit, reclaimerID, reclaimID, { targetID }, options)
				accepted = accepted or (ok and result ~= false)
			end
		end
		if accepted then issuedTargets = issuedTargets + 1 end
	end
	if issuedTargets > 0 then
		state.successfulActivity, state.lastResult = true, "reclaim issued for " .. tostring(issuedTargets) .. " targets"
		ControllerCameraTestShowHotkeyFeedback("RECLAIM " .. tostring(issuedTargets), "reclaim")
	end
	return issuedTargets
end

function ControllerCameraTestStopDisassembleReclaimers()
	local state, stopID = ControllerCameraTestDisassemble, (CMD and CMD.STOP) or 0
	if not ControllerCameraTestValidateReclaimers(false) then return false end
	local accepted = false
	if type(spGiveOrderToUnitArray) == "function" then
		local ok, result = pcall(spGiveOrderToUnitArray, state.reclaimers, stopID, {}, {})
		accepted = ok and result ~= false
	elseif type(spGiveOrderToUnit) == "function" then
		for _, unitID in ipairs(state.reclaimers) do
			local ok, result = pcall(spGiveOrderToUnit, unitID, stopID, {}, {})
			accepted = accepted or (ok and result ~= false)
		end
	end
	state.lastResult = accepted and "reclaimers stopped" or "stop failed"
	return accepted
end

function ControllerCameraTestStartAreaReclaim(targetID, unitDefID)
	if not ControllerCameraTestIsSafeSelectableUnit(targetID) or not unitDefID then return false end
	local x, y, z
	if type(spGetUnitPosition) == "function" then x, y, z = spGetUnitPosition(targetID) end
	if not x or not z then return false end
	local state = ControllerCameraTestDisassemble
	state.areaReclaim = { active = true, anchorUnitID = targetID, unitDefID = unitDefID,
		x = x, y = y or (type(spGetGroundHeight) == "function" and spGetGroundHeight(x, z) or 0), z = z,
		radius = ControllerDisassembleBehavior and ControllerDisassembleBehavior.MIN_TARGET_RADIUS or 120, candidates = {} }
	state.lbA.pressActive, state.lbA.holdFired = false, true
	state.lastResult = "area reclaim targeting"
	ControllerCameraTestShowHotkeyFeedback("AREA RECLAIM TARGETING", "reclaim")
	return true
end

function ControllerCameraTestUpdateAreaReclaimTargeting()
	local state, area = ControllerCameraTestDisassemble, ControllerCameraTestDisassemble.areaReclaim
	if not area.active then return false end
	if reticleHasWorldTarget and reticleWorldX and reticleWorldZ then
		local dx, dz = reticleWorldX - area.x, reticleWorldZ - area.z
		area.radius = clamp(math.sqrt(dx * dx + dz * dz),
			ControllerDisassembleBehavior and ControllerDisassembleBehavior.MIN_TARGET_RADIUS or 120,
			ControllerDisassembleBehavior and ControllerDisassembleBehavior.MAX_TARGET_RADIUS or 1200)
	end
	area.candidates = ControllerCameraTestCollectOwnedTargetsInRadius(area.x, area.z, area.radius, { [area.unitDefID] = true })
	if ControllerCameraTestActionDown("pitchModifier") and ControllerCameraTestActionPressed("cancel") then
		area.active = false
		ControllerCameraTestStopDisassembleReclaimers()
		ControllerCameraTestShowHotkeyFeedback("STOP", "utility")
		return true
	end
	if ControllerCameraTestActionPressed("cancel") then
		area.active, area.candidates, state.lastResult = false, {}, "area reclaim cancelled"
		return true
	end
	if ControllerCameraTestActionPressed("select") or ControllerCameraTestActionPressed("smartAction") then
		local targets = area.candidates
		area.active, area.candidates = false, {}
		ControllerCameraTestIssueDisassembleReclaim(targets)
		return true
	end
	return true
end

function ControllerCameraTestUpdateDisassembleModeInput(dt)
	local state = ControllerCameraTestDisassemble
	if not state.active then return false end
	if ControllerCameraTestUsesNativeBARUI() then
		return ControllerCameraTestUpdateNativeDisassembleInput(dt)
	end
	if ControllerCameraTestUpdateAreaReclaimTargeting() then return true end

	if ControllerCameraTestActionDown("pitchModifier") and ControllerCameraTestActionPressed("cancel") then
		ControllerCameraTestCancelDisassembleSubstates("stopped")
		ControllerCameraTestStopDisassembleReclaimers()
		ControllerCameraTestShowHotkeyFeedback("STOP", "utility")
		return true
	end

	local lbDown = ControllerCameraTestActionDown("pitchModifier")
	if lbDown and ControllerCameraTestActionPressed("select") then
		local targetID, unitDefID = ControllerCameraTestGetReticleOwnedTarget()
		state.lbA = { pressActive = targetID ~= nil, startedAt = debugEventTime, targetID = targetID,
			unitDefID = unitDefID, holdFired = false }
		return true
	end
	if state.lbA.pressActive and lbDown and ControllerCameraTestActionDown("select") then
		local threshold = ControllerCameraTestSettings.areaReclaimHoldSeconds
			or (ControllerDisassembleBehavior and ControllerDisassembleBehavior.AREA_RECLAIM_HOLD_SECONDS) or 0.45
		if not state.lbA.holdFired and debugEventTime - state.lbA.startedAt >= threshold then
			state.lbA.holdFired = ControllerCameraTestStartAreaReclaim(state.lbA.targetID, state.lbA.unitDefID)
		end
		return true
	end
	if state.lbA.pressActive and (ControllerCameraTestActionReleased("select") or not lbDown) then
		if not state.lbA.holdFired and state.lbA.targetID then ControllerCameraTestIssueDisassembleReclaim({ state.lbA.targetID }) end
		state.lbA.pressActive, state.lbA.holdFired = false, false
		return true
	end

	local mark = state.markArea
	if not lbDown and ControllerCameraTestActionPressed("select") then
		mark.pressActive, mark.active, mark.startedAt = true, false, debugEventTime
		mark.additive = ControllerCameraTestIsQueueModifierActive()
		mark.typeFilter = next(state.markedTargets) and (ControllerDisassembleBehavior and
			ControllerDisassembleBehavior.CollectMarkedTypes(state.markedTargets, Spring.GetUnitDefID) or nil) or nil
		return true
	end
	if mark.pressActive and ControllerCameraTestActionPressed("cancel") then
		mark.pressActive, mark.active, mark.typeFilter, state.lastResult = false, false, nil, "area marking cancelled"
		return true
	end
	if mark.pressActive and ControllerCameraTestActionDown("select") then
		local threshold = ControllerCameraTestSettings.aHoldSeconds
			or (ControllerDisassembleBehavior and ControllerDisassembleBehavior.AREA_MARK_HOLD_SECONDS) or 0.38
		if not mark.active and debugEventTime - mark.startedAt >= threshold then mark.active = true end
		if mark.active then
			mark.additive = ControllerCameraTestIsQueueModifierActive()
			ControllerCameraTestUpdateDisassembleAreaRadius(mark, dt)
		end
		return true
	end
	if mark.pressActive and ControllerCameraTestActionReleased("select") then
		if mark.active then ControllerCameraTestFinishDisassembleAreaMark()
		else
			local targetID = ControllerCameraTestGetReticleOwnedTarget()
			if targetID then ControllerCameraTestMarkSingleTarget(targetID, mark.additive) end
			mark.pressActive = false
		end
		return true
	end
	return true
end

function ControllerCameraTestUpdateDisassembleLifecycle()
	local state = ControllerCameraTestDisassemble
	if not state.active then return end
	if ControllerCameraTestUsesNativeBARUI() then
		if debugEventTime - (state.lastValidationAt or -10) >= 0.25 then
			state.lastValidationAt = debugEventTime
			ControllerCameraTestValidateReclaimers(false)
		end
		return
	end
	if debugEventTime - (state.lastValidationAt or -10) >= 0.25 then
		state.lastValidationAt = debugEventTime
		if not ControllerCameraTestValidateReclaimers(true) then return end
	end
	if ControllerDisassembleBehavior and ControllerDisassembleBehavior.TimeoutExpired(
			state.activatedAt, debugEventTime, state.successfulActivity,
			ControllerCameraTestSettings.disassembleUnusedTimeoutSeconds) then
		ControllerCameraTestExitDisassembleMode("Disassemble Mode Timed Out", "unused timeout")
	end
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

function ControllerCameraTestSelectSameTypeFromReticle(includeOffscreen, overrideUnitID, overrideUnitDefID)
	local targetID = overrideUnitID
	local unitDefID = overrideUnitDefID
	local unitDef
	if targetID then
		_, unitDef = ControllerCameraTestGetUnitDef(targetID)
	else
		targetID, unitDefID, unitDef = ControllerCameraTestGetReticleAlliedUnitAndDef()
	end

	if not targetID or not unitDefID then
		ControllerCameraTestUpdateSameTypeDebug(nil, "none", 0, 0, "no unit resolved")
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

function ControllerCameraTestSelectVisibleSameTypeUnderReticle(overrideUnitID, overrideUnitDefID)
	return ControllerCameraTestSelectSameTypeFromReticle(false, overrideUnitID, overrideUnitDefID)
end

function ControllerCameraTestSelectAllOwnedSameTypeUnderReticle(overrideUnitID, overrideUnitDefID)
	return ControllerCameraTestSelectSameTypeFromReticle(true, overrideUnitID, overrideUnitDefID)
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

local dgunMoveParams = { 0, 0, 0 }
local dgunTargetParams = { 0, 0, 0 }
local dgunStaticOptions = {}

local function GetSelectedCommanderID()
	if type(spGetSelectedUnits) ~= "function" then
		return nil
	end
	local selectedUnits = spGetSelectedUnits()
	if type(selectedUnits) ~= "table" then
		return nil
	end
	for _, unitID in ipairs(selectedUnits) do
		if ControllerCameraTestIsCommanderUnit(unitID) then
			return unitID
		end
	end
	return nil
end

local function FindActiveDgunCommandID()
	if type(Spring.GetActiveCmdDescs) == "function" then
		local ok, cmdDescs = pcall(Spring.GetActiveCmdDescs)
		if ok and type(cmdDescs) == "table" then
			for _, desc in pairs(cmdDescs) do
				if type(desc) == "table" and (desc.name == "ManualFire" or desc.name == "dgun" or desc.name == "DGun") then
					return desc.id
				end
			end
		end
	end
	if CMD and CMD.MANUALFIRE then
		return CMD.MANUALFIRE
	end
	return 2
end

local function GetCommanderDgunRange(commanderID)
	local _, unitDef = ControllerCameraTestGetUnitDef(commanderID)
	if type(unitDef) ~= "table" or type(unitDef.weapons) ~= "table" then
		return nil, "no weapons"
	end
	for i = 1, #unitDef.weapons do
		local w = unitDef.weapons[i]
		if type(w) == "table" and w.weaponDef then
			local wDef = WeaponDefs[w.weaponDef]
			if type(wDef) == "table" then
				local name = string.lower(tostring(wDef.name or "") .. " " .. tostring(wDef.label or ""))
				if string.find(name, "dgun", 1, true) or string.find(name, "disintegrator", 1, true) then
					if type(wDef.range) == "number" and wDef.range > 0 then
						return wDef.range, "weaponDef (" .. tostring(wDef.name) .. ")"
					end
				end
			end
		end
	end
	for i = 1, #unitDef.weapons do
		local w = unitDef.weapons[i]
		if type(w) == "table" and w.weaponDef then
			local wDef = WeaponDefs[w.weaponDef]
			if type(wDef) == "table" then
				if wDef.range and type(wDef.range) == "number" and wDef.range > 0 then
					if wDef.manualFire or wDef.type == "DGun" then
						return wDef.range, "weaponDef manualFire (" .. tostring(wDef.name) .. ")"
					end
				end
			end
		end
	end
	return nil, "fallback"
end

function ControllerCameraTestEnterDgunMode(commanderID)
	local dgun = ControllerCameraTestDgunMode
	dgun.active = true
	dgun.commanderID = commanderID
	dgun.lastExitReason = "none"
	dgun.lastFireResult = "none"
	dgun.lastMoveResult = "none"
	dgun.moveActive = false
	dgun.aimActive = false
	dgun.movementStickActive = false

	-- Resolve command ID once
	dgun.cmdID = FindActiveDgunCommandID()

	-- Resolve weapon range dynamically
	local dynamicRange, rSource = GetCommanderDgunRange(commanderID)
	if dynamicRange then
		dgun.range = dynamicRange
		dgun.rangeSource = rSource
	else
		dgun.range = 280
		dgun.rangeSource = "fallback (constant)"
	end

	-- Initialize aim direction
	dgun.aimX = 0
	dgun.aimZ = 0

	local cx, cy, cz = spGetUnitPosition(commanderID)
	if cx and cz then
		cy = cy or 0
		local initialDX, initialDZ = 0, -1
		if reticleHasWorldTarget and reticleWorldX and reticleWorldZ then
			local dx = reticleWorldX - cx
			local dz = reticleWorldZ - cz
			local dist = math.sqrt(dx*dx + dz*dz)
			if dist > 10 then
				initialDX = dx / dist
				initialDZ = dz / dist
			end
		else
			local ok, camState = pcall(spGetCameraState)
			if ok and camState and camState.dx and camState.dz then
				local dist = math.sqrt(camState.dx * camState.dx + camState.dz * camState.dz)
				if dist > 0.01 then
					initialDX = camState.dx / dist
					initialDZ = camState.dz / dist
				end
			end
		end

		dgun.aimX = initialDX
		dgun.aimZ = initialDZ

		dgun.targetX = cx + dgun.aimX * dgun.range
		dgun.targetZ = cz + dgun.aimZ * dgun.range
		dgun.targetY = spGetGroundHeight(dgun.targetX, dgun.targetZ) or cy
	end

	latchSelectionDebugMessage("Entered DGUN Mode")
end

function ControllerCameraTestExitDgunMode(reason)
	local dgun = ControllerCameraTestDgunMode
	if not dgun.active then
		return
	end
	dgun.active = false
	dgun.lastExitReason = reason or "exit"
	latchSelectionDebugMessage("Exited DGUN Mode: " .. tostring(reason or "user cancelled"))
end

function ControllerCameraTestUpdateDgunAim(dt)
	local dgun = ControllerCameraTestDgunMode
	if not dgun.active or not dgun.commanderID then
		dgun.aimActive = false
		return
	end

	local cx, cy, cz = spGetUnitPosition(dgun.commanderID)
	if not cx or not cz then
		dgun.aimActive = false
		return
	end
	cy = cy or 0

	local rx = normalizedRightX or 0
	local ry = normalizedRightY or 0

	local deadzone = 0.50
	local mag = math.sqrt(rx * rx + ry * ry)

	if mag > deadzone then
		local cdx, _, cdz = 0, 0, -1
		if type(Spring.GetCameraDirection) == "function" then
			local camX, camY, camZ = Spring.GetCameraDirection()
			if camX and camZ then
				cdx, cdz = camX, camZ
			end
		end
		local len = math.sqrt(cdx * cdx + cdz * cdz)
		local fx, fz = 0, -1
		if len > 0.001 then
			fx = cdx / len
			fz = cdz / len
		end
		local rightX = -fz
		local rightZ = fx

		local aimX = rx * rightX + (-ry) * fx
		local aimZ = rx * rightZ + (-ry) * fz
		local aimMag = math.sqrt(aimX * aimX + aimZ * aimZ)
		if aimMag > 0.001 then
			dgun.aimX = aimX / aimMag
			dgun.aimZ = aimZ / aimMag
		else
			dgun.aimX = 0
			dgun.aimZ = -1
		end
		dgun.aimActive = true
	else
		dgun.aimActive = false
	end

	dgun.targetX = cx + dgun.aimX * dgun.range
	dgun.targetZ = cz + dgun.aimZ * dgun.range
	dgun.targetY = spGetGroundHeight(dgun.targetX, dgun.targetZ) or cy
end

function ControllerCameraTestUpdateDgunMovement(dt)
	local dgun = ControllerCameraTestDgunMode
	if not dgun.active or not dgun.commanderID then
		dgun.moveActive = false
		dgun.movementStickActive = false
		return
	end

	local lx = normalizedLeftX or 0
	local ly = normalizedLeftY or 0

	local deadzone = 0.40
	local mag = math.sqrt(lx * lx + ly * ly)

	if mag <= deadzone then
		dgun.moveActive = false
		dgun.movementStickActive = false
		return
	end

	dgun.movementStickActive = true

	local now = debugEventTime
	local elapsed = now - (dgun.lastMoveTime or 0)
	if elapsed < 0.20 then
		dgun.moveActive = true
		return
	end

	dgun.lastMoveTime = now
	dgun.moveActive = true

	local cx, cy, cz = spGetUnitPosition(dgun.commanderID)
	if not cx or not cz then
		dgun.moveActive = false
		return
	end
	cy = cy or 0

	local cdx, _, cdz = 0, 0, -1
	if type(Spring.GetCameraDirection) == "function" then
		local camX, camY, camZ = Spring.GetCameraDirection()
		if camX and camZ then
			cdx, cdz = camX, camZ
		end
	end
	local len = math.sqrt(cdx * cdx + cdz * cdz)
	local fx, fz = 0, -1
	if len > 0.001 then
		fx = cdx / len
		fz = cdz / len
	end
	local rightX = -fz
	local rightZ = fx

	local moveX = lx * rightX + (-ly) * fx
	local moveZ = lx * rightZ + (-ly) * fz
	local moveMag = math.sqrt(moveX * moveX + moveZ * moveZ)

	local dx, dz
	if moveMag > 0.001 then
		dx = moveX / moveMag
		dz = moveZ / moveMag
	else
		dx = 0
		dz = -1
	end

	local step = 150
	local tx = cx + dx * step
	local tz = cz + dz * step
	local ty = spGetGroundHeight(tx, tz) or cy

	dgun.moveTargetX = tx
	dgun.moveTargetY = ty
	dgun.moveTargetZ = tz

	dgunMoveParams[1] = tx
	dgunMoveParams[2] = ty
	dgunMoveParams[3] = tz

	local moveCmdID = CMD and CMD.MOVE or 10

	local ok, err = pcall(Spring.GiveOrderToUnit, dgun.commanderID, moveCmdID, dgunMoveParams, dgunStaticOptions)
	if ok then
		dgun.lastMoveResult = "issued to " .. string.format("%.1f, %.1f", tx, tz)
	else
		dgun.lastMoveResult = "failed: " .. tostring(err or "unknown")
	end
end

function ControllerCameraTestHandleDgunModeInput(dt)
	local dgun = ControllerCameraTestDgunMode
	if not dgun.active then
		return false
	end

	local selectedCommanderID = GetSelectedCommanderID()
	if not selectedCommanderID or selectedCommanderID ~= dgun.commanderID then
		ControllerCameraTestExitDgunMode("commander deselected or dead")
		return false
	end

	if type(Spring.ValidUnitID) == "function" and not Spring.ValidUnitID(dgun.commanderID) then
		ControllerCameraTestExitDgunMode("commander destroyed")
		return false
	end

	if type(Spring.GetUnitIsDead) == "function" then
		local ok, isDead = pcall(Spring.GetUnitIsDead, dgun.commanderID)
		if ok and isDead then
			ControllerCameraTestExitDgunMode("commander dead")
			return false
		end
	end

	if type(Spring.GetUnitTeam) == "function" then
		local myTeamID = type(Spring.GetMyTeamID) == "function" and Spring.GetMyTeamID()
		local ok, uTeam = pcall(Spring.GetUnitTeam, dgun.commanderID)
		if ok and uTeam and myTeamID and uTeam ~= myTeamID then
			ControllerCameraTestExitDgunMode("commander transferred")
			return false
		end
	end

	if ControllerCameraTestActionPressed("cancel") then
		ControllerCameraTestExitDgunMode("user cancelled with B")
		return true
	end

	ControllerCameraTestUpdateDgunAim(dt)
	ControllerCameraTestUpdateDgunMovement(dt)

	if ControllerCameraTestBindingPressed("RT") then
		local now = debugEventTime
		local elapsed = now - (dgun.lastFireTime or 0)

		if elapsed >= 0.15 then
			dgun.lastFireTime = now

			if not dgun.commanderID then
				dgun.lastFireResult = "DGUN fire failed: invalid commander"
				latchSelectionDebugMessage(dgun.lastFireResult)
			elseif not dgun.targetX or not dgun.targetY or not dgun.targetZ then
				dgun.lastFireResult = "DGUN fire failed: invalid target"
				latchSelectionDebugMessage(dgun.lastFireResult)
			elseif type(Spring.GiveOrderToUnit) ~= "function" then
				dgun.lastFireResult = "DGUN fire failed: missing GiveOrderToUnit"
				latchSelectionDebugMessage(dgun.lastFireResult)
			else
				local solvedCmdID = dgun.cmdID or 2
				dgunTargetParams[1] = dgun.targetX
				dgunTargetParams[2] = dgun.targetY
				dgunTargetParams[3] = dgun.targetZ

				local ok, orderResult = pcall(Spring.GiveOrderToUnit, dgun.commanderID, solvedCmdID, dgunTargetParams, dgunStaticOptions)
				if ok then
					dgun.lastFireResult = "DGUN fired cmdID " .. tostring(solvedCmdID)
					latchSelectionDebugMessage("DGUN fired")
				else
					dgun.lastFireResult = "DGUN fire failed: pcall error " .. tostring(orderResult or "unknown")
					latchSelectionDebugMessage(dgun.lastFireResult)
				end
			end
		end
	end

	return true
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
	local duration = seconds or 1.5
	local shared = WG and WG.ControllerUISettings
	local component = shared and type(shared.GetComponent) == "function" and shared.GetComponent("hotSlots") or nil
	if component and component.autoCollapse then duration = math.min(duration, tonumber(component.autoCollapseDelay) or 2.5) end
	ControllerCameraTestControlGroups.visibleUntil = debugEventTime + duration
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

ControllerCameraTestTacticalCommandTemplates = ControllerCameraTestTacticalCommandTemplates or {
	{ name = "Stop", shortLabel = "Stop", cmdID = CMD.STOP, kind = "none" },
	{ name = "Wait", shortLabel = "Wait", cmdID = CMD.WAIT, kind = "none" },
	{ name = "Repeat", shortLabel = "Repeat", cmdID = CMD.REPEAT, kind = "repeat_toggle" },
	{ name = "Move State", shortLabel = "Move State", cmdID = (CMD and CMD.MOVE_STATE) or 50, kind = "move_state_cycle" },
	{ name = "High Priority", shortLabel = "High Prio", cmdID = (GameCMD and GameCMD.PRIORITY) or 34571, kind = "none" },
	{ name = "Move Line", shortLabel = "Move Line", cmdID = CMD.MOVE, kind = "drag_line", dragMode = "moveLine" },
	{ name = "Fight Line", shortLabel = "Fight Line", cmdID = CMD.FIGHT, kind = "drag_line", dragMode = "fightLine" },
	{ name = "Attack Line", shortLabel = "Attack Line", cmdID = CMD.ATTACK, kind = "drag_line", dragMode = "attackLine" },
	{ name = "Reclaim Area", shortLabel = "Reclaim Area", cmdID = CMD.RECLAIM, kind = "drag_area", dragMode = "reclaimArea", descriptorSource = "template", colorProfile = "reclaim", iconLabel = "RECLAIM", iconSource = "fallback text" },
	{ name = "Repair Area", shortLabel = "Repair Area", cmdID = CMD.REPAIR, kind = "drag_area", dragMode = "repairArea", descriptorSource = "template", colorProfile = "repair", iconLabel = "REPAIR", iconSource = "fallback text" },
	{ name = "Attack Area", shortLabel = "Attack Area", cmdID = CMD.ATTACK, kind = "drag_area", dragMode = "attackArea", descriptorSource = "template", colorProfile = "attack", iconLabel = "ATK", iconSource = "fallback text" },
	{ name = "Patrol", shortLabel = "Patrol", cmdID = CMD.PATROL, kind = "ground" },
	{ name = "Guard", shortLabel = "Guard", cmdID = CMD.GUARD, kind = "alliedUnit" },
	{ name = "Fire State", shortLabel = "Fire State", cmdID = CMD.FIRESTATE or 20, kind = "fire_state_cycle" },
}
ControllerCameraTestFactoryTacticalCommandTemplates = ControllerCameraTestFactoryTacticalCommandTemplates or {
	{ name = "Fight", shortLabel = "Fight", cmdID = CMD.FIGHT, kind = "ground" },
	{ name = "Patrol", shortLabel = "Patrol", cmdID = CMD.PATROL, kind = "ground" },
	{ name = "Stop", shortLabel = "Stop", cmdID = CMD.STOP, kind = "none" },
	{ name = "Wait", shortLabel = "Wait", cmdID = CMD.WAIT, kind = "none" },
	{ name = "Repeat Toggle", shortLabel = "Repeat", kind = "factory_repeat" },
}

local TacticalCategories = {
	CmdMoveState = (CMD and CMD.MOVE_STATE) or 50,
	CmdHighPriority = (GameCMD and GameCMD.PRIORITY) or 34571,
	CmdRestore = (CMD and CMD.RESTORE) or 110,
	CmdAreaMex = (GameCMD and GameCMD.AREA_MEX) or 30100,

	Order = { "up", "down" },
	ByDirection = {
		up = { key = "utility", label = "Utility", shortLabel = "Utility", hint = "D-pad Up" },
		down = { key = "tactical", label = "Tactical Actions", shortLabel = "Tactical", hint = "D-pad Down" },
	},
	ByKey = {},
	Colors = {
		utility = { 0.15, 0.65, 0.95 },
		tactical = { 0.25, 0.85, 0.45 },
	},
	FillColors = {
		utility = { 0.03, 0.16, 0.28, 0.52 },
		tactical = { 0.05, 0.24, 0.12, 0.52 },
	},
}

for _, direction in ipairs(TacticalCategories.Order) do
	local category = TacticalCategories.ByDirection[direction]
	category.direction = direction
	TacticalCategories.ByKey[category.key] = category
end

function TacticalCategories.AreaMexFallbackOption()
	return {
		name = "Area Mex",
		shortLabel = "Area Mex",
		cmdID = TacticalCategories.CmdAreaMex,
		kind = "drag_area",
		dragMode = "areaMex",
		action = "areamex",
		descriptorSource = "selection eligibility",
		colorProfile = "areaMex",
		iconLabel = "MEX",
		iconSource = "fallback text",
	}
end

function ControllerCameraTestUnitDefCanBuildMex(unitDef)
	if type(unitDef) ~= "table" or type(unitDef.buildOptions) ~= "table" then
		return false
	end
	for _, buildDefID in ipairs(unitDef.buildOptions) do
		local buildDef = UnitDefs and UnitDefs[buildDefID]
		if type(buildDef) == "table" and (tonumber(buildDef.extractsMetal) or 0) > 0 then
			return true
		end
	end
	return false
end

function ControllerCameraTestSelectionCanUseAreaMex(selectedUnits)
	if type(selectedUnits) ~= "table" or #selectedUnits <= 0 then
		return false
	end

	local resourceBuilder = WG and WG.resource_spot_builder
	local resourceFinder = WG and WG["resource_spot_finder"]
	if type(resourceFinder) == "table" and resourceFinder.isMetalMap then
		return false
	end

	local mexConstructors = nil
	if type(resourceBuilder) == "table" and type(resourceBuilder.GetMexConstructors) == "function" then
		local constructorsOk, constructors = pcall(resourceBuilder.GetMexConstructors)
		if constructorsOk and type(constructors) == "table" then
			mexConstructors = constructors
		end
	end

	for _, unitID in ipairs(selectedUnits) do
		if (mexConstructors and mexConstructors[unitID])
			or ControllerCameraTestUnitDefCanBuildMex(select(2, ControllerCameraTestGetUnitDef(unitID)))
		then
			return true
		end
	end
	return false
end

function ControllerCameraTestEnsureAreaMexHelper()
	local areaMexApi = WG and WG.controllerAreaMex
	if type(areaMexApi) == "table" and type(areaMexApi.issueArea) == "function" then
		return true
	end
	if ControllerCameraTestAreaMexHelperEnableAttempted then
		return false
	end
	ControllerCameraTestAreaMexHelperEnableAttempted = true

	if type(widgetHandler) ~= "table" or type(widgetHandler.EnableWidget) ~= "function" then
		return false
	end
	if type(widgetHandler.IsWidgetKnown) == "function" then
		local knownOk, known = pcall(widgetHandler.IsWidgetKnown, widgetHandler, "Area Mex")
		if not knownOk or not known then
			return false
		end
	end

	local enableOk = pcall(widgetHandler.EnableWidget, widgetHandler, "Area Mex")
	if enableOk and type(Spring.Echo) == "function" then
		Spring.Echo("[ControllerAreaMex] Enabling existing Area Mex helper for tactical radial")
	end
	return false
end

function TacticalCategories.Info(keyOrDirection)
	return TacticalCategories.ByKey[keyOrDirection]
		or TacticalCategories.ByDirection[keyOrDirection]
		or TacticalCategories.ByKey.tactical
end

function TacticalCategories.CommandDescText(desc)
	return string.lower(tostring(desc.name or "") .. " " .. tostring(desc.action or "") .. " " .. tostring(desc.tooltip or ""))
end

function TacticalCategories.TextHasAny(text, needles)
	for _, needle in ipairs(needles) do
		if text:find(needle, 1, true) then
			return true
		end
	end
	return false
end

function TacticalCategories.OptionText(option)
	return string.lower(tostring(option and option.name or "")
		.. " " .. tostring(option and option.shortLabel or "")
		.. " " .. tostring(option and option.action or "")
		.. " " .. tostring(option and option.tooltip or ""))
end

function TacticalCategories.IsHiddenTacticalOption(option)
	if type(option) ~= "table" then
		return true
	end
	local cmdID = option.cmdID and tonumber(option.cmdID)
	local text = TacticalCategories.OptionText(option)
	local lowerName = string.lower(option.name or option.shortLabel or "")
	local action = string.lower(tostring(option.action or ""))

	-- Block High Priority command
	if cmdID == 34571 or cmdID == TacticalCategories.CmdHighPriority then
		return true
	end
	if lowerName == "high priority" or lowerName == "priority"
		or action == "high priority" or action == "priority" or action == "highpriority"
	then
		return true
	end

	-- Block wait subtypes
	if lowerName == "gather wait" or lowerName == "gatherwait"
		or lowerName == "squad wait" or lowerName == "squadwait"
		or lowerName == "death wait" or lowerName == "deathwait"
		or lowerName == "time wait" or lowerName == "timewait"
		or action == "gather wait" or action == "gatherwait"
		or action == "squad wait" or action == "squadwait"
		or action == "death wait" or action == "deathwait"
		or action == "time wait" or action == "timewait"
		or text:find("gather wait", 1, true) or text:find("gatherwait", 1, true)
		or text:find("squad wait", 1, true) or text:find("squadwait", 1, true)
		or text:find("death wait", 1, true) or text:find("deathwait", 1, true)
		or text:find("time wait", 1, true) or text:find("timewait", 1, true)
	then
		return true
	end

	-- Globally block by cmdID if they are unwanted commands
	if cmdID == CMD.MOVE
		or cmdID == CMD.STOP
		or cmdID == (CMD.CLOAK or 90)
		or cmdID == (CMD.LOAD_UNITS or 75)
		or cmdID == (CMD.UNLOAD_UNITS or 80)
		or cmdID == (CMD.FIRESTATE or 20)
		or cmdID == CMD.ATTACK
		or cmdID == CMD.MOVE_STATE
	then
		return true
	end

	-- Check explicit keyword search in name, action, or option text
	-- This blocks cloak, load, unload, transport, target, manual fire, fire state,
	-- move state, hold position, line/formation, move, stop, blueprint, build line, etc.
	if lowerName:find("cloak", 1, true)
		or lowerName:find("load", 1, true)
		or lowerName:find("unload", 1, true)
		or lowerName:find("transport", 1, true)
		or lowerName:find("target", 1, true)
		or lowerName:find("manual fire", 1, true)
		or lowerName:find("fire state", 1, true)
		or lowerName:find("firestate", 1, true)
		or lowerName:find("move state", 1, true)
		or lowerName:find("movestate", 1, true)
		or lowerName:find("hold position", 1, true)
		or lowerName:find("holdposition", 1, true)
		or lowerName:find("move", 1, true)
		or lowerName:find("stop", 1, true)
		or lowerName:find("blueprint", 1, true)
		or lowerName:find("formation", 1, true)
		or lowerName:find("line", 1, true)
		or lowerName:find("attack area", 1, true)
		or lowerName:find("area attack", 1, true)
	then
		return true
	end

	if action:find("cloak", 1, true)
		or action:find("load", 1, true)
		or action:find("unload", 1, true)
		or action:find("transport", 1, true)
		or action:find("target", 1, true)
		or action:find("manualfire", 1, true)
		or action:find("firestate", 1, true)
		or action:find("movestate", 1, true)
		or action:find("move", 1, true)
		or action:find("stop", 1, true)
		or action:find("blueprint", 1, true)
		or action:find("formation", 1, true)
		or action:find("line", 1, true)
		or action:find("areaattack", 1, true)
	then
		return true
	end

	if text:find("cloak", 1, true)
		or text:find("load", 1, true)
		or text:find("unload", 1, true)
		or text:find("transport", 1, true)
		or text:find("target", 1, true)
		or text:find("manual fire", 1, true)
		or text:find("fire state", 1, true)
		or text:find("move state", 1, true)
		or text:find("hold position", 1, true)
		or text:find("move", 1, true)
		or text:find("stop", 1, true)
		or text:find("blueprint", 1, true)
		or text:find("formation", 1, true)
		or text:find("line", 1, true)
		or text:find("area attack", 1, true)
		or text:find("attack area", 1, true)
	then
		return true
	end

	return false
end

function TacticalCategories.CategoryForOption(option)
	if type(option) ~= "table" or TacticalCategories.IsHiddenTacticalOption(option) then
		return nil
	end
	if option.tacticalCategory then
		if option.tacticalCategory == "utility" then
			return "utility"
		elseif option.tacticalCategory == "buildArea" or option.tacticalCategory == "combat" or option.tacticalCategory == "special" or option.tacticalCategory == "tactical" then
			return "tactical"
		end
	end

	local cmdID = tonumber(option.cmdID)
	local kind = tostring(option.kind or "")
	local mode = tostring(option.dragMode or "")
	local text = TacticalCategories.OptionText(option)
	local lowerName = string.lower(option.name or option.shortLabel or "")
	local action = string.lower(tostring(option.action or ""))

	-- 1. UTILITY WHITELIST
	if cmdID == CMD.WAIT
		or cmdID == CMD.REPEAT
		or cmdID == (CMD.SELFD or 70)
		or kind == "repeat_toggle"
		or kind == "factory_repeat"
		or (lowerName:find("wait", 1, true) and not lowerName:find("gather", 1, true) and not lowerName:find("squad", 1, true) and not lowerName:find("death", 1, true) and not lowerName:find("time", 1, true))
		or lowerName:find("repeat", 1, true)
		or lowerName:find("self destruct", 1, true)
		or lowerName:find("self-destruct", 1, true)
		or lowerName:find("selfd", 1, true)
		or (text:find("wait", 1, true) and not text:find("gather", 1, true) and not text:find("squad", 1, true) and not text:find("death", 1, true) and not text:find("time", 1, true))
		or text:find("repeat", 1, true)
		or text:find("self destruct", 1, true)
		or text:find("self-destruct", 1, true)
	then
		return "utility"
	end

	-- 2. TACTICAL ACTIONS WHITELIST: Fight, Guard, Patrol, Area Mex, Repair Area, Reclaim Area, Restore Area
	if cmdID == CMD.FIGHT
		or cmdID == CMD.GUARD
		or cmdID == CMD.PATROL
		or cmdID == CMD.REPAIR
		or cmdID == CMD.RECLAIM
		or cmdID == TacticalCategories.CmdAreaMex
		or cmdID == TacticalCategories.CmdRestore
		or mode == "areaMex"
		or mode == "repairArea"
		or mode == "reclaimArea"
		or mode == "restoreArea"
		or lowerName:find("fight", 1, true)
		or lowerName:find("guard", 1, true)
		or lowerName:find("patrol", 1, true)
		or lowerName:find("repair", 1, true)
		or lowerName:find("reclaim", 1, true)
		or lowerName:find("restore", 1, true)
		or action:find("fight", 1, true)
		or action:find("guard", 1, true)
		or action:find("patrol", 1, true)
		or action:find("repair", 1, true)
		or action:find("reclaim", 1, true)
		or action:find("restore", 1, true)
	then
		return "tactical"
	end

	return nil
end

function TacticalCategories.AreaIconLabel(label, fallback)
	label = tostring(label or fallback or "AREA")
	label = label:gsub("[^%w]", "")
	if label == "" then
		return fallback or "AREA"
	end
	return string.upper(string.sub(label, 1, 7))
end

function TacticalCategories.AreaOptionFromDesc(desc)
	if type(desc) ~= "table" or desc.disabled then
		return nil
	end
	local cmdID = tonumber(desc.id or desc.cmdID)
	if type(cmdID) ~= "number" or cmdID < 0 then
		return nil
	end

	local name = tostring(desc.name or desc.action or "Area Command")
	local action = tostring(desc.action or "")
	local lowerAction = string.lower(action)
	local lowerName = string.lower(name)
	local text = TacticalCategories.CommandDescText(desc)
	local dragMode, shortLabel, colorProfile, iconLabel

	-- Area Mex is routed through WG.controllerAreaMex.issueArea from the staged
	-- tactical aim mode; cmd_area_mex.lua owns the direct executor.
	if text:find("area mex", 1, true)
		or cmdID == TacticalCategories.CmdAreaMex
		or lowerAction == "areamex"
		or string.lower(name) == "areamex"
		or (text:find("mex", 1, true) and text:find("area", 1, true))
		or text:find("area metal extractor", 1, true)
		or text:find("area build metal extractors", 1, true)
	then
		dragMode = "areaMex"
		shortLabel = "Area Mex"
		colorProfile = "areaMex"
		iconLabel = "MEX"
	elseif lowerName:find("restore", 1, true) or lowerAction:find("restore", 1, true) or cmdID == TacticalCategories.CmdRestore then
		dragMode = "restoreArea"
		shortLabel = "Restore Area"
		colorProfile = "restore"
		iconLabel = "RESTORE"
	elseif TacticalCategories.TextHasAny(text, { "resurrect", "resurrection", "ressurect", "revive" })
		or lowerAction == "rez"
		or lowerAction == "res"
	then
		dragMode = "resurrectArea"
		shortLabel = "Resurrect Area"
		colorProfile = "resurrect"
		iconLabel = "RES"
	elseif text:find("reclaim", 1, true) and (text:find("area", 1, true) or text:find("radius", 1, true)) then
		dragMode = "reclaimArea"
		shortLabel = "Reclaim Area"
		colorProfile = "reclaim"
		iconLabel = "RECLAIM"
	elseif text:find("repair", 1, true) and (text:find("area", 1, true) or text:find("radius", 1, true)) then
		dragMode = "repairArea"
		shortLabel = "Repair Area"
		colorProfile = "repair"
		iconLabel = "REPAIR"
	elseif text:find("attack", 1, true) and (text:find("area", 1, true) or text:find("radius", 1, true)) then
		dragMode = "attackArea"
		shortLabel = "Attack Area"
		colorProfile = "attack"
		iconLabel = "ATK"
	elseif cmdID ~= CMD.RECLAIM and cmdID ~= CMD.REPAIR and cmdID ~= CMD.ATTACK
		and (text:find("area", 1, true) or text:find("radius", 1, true))
	then
		dragMode = "genericArea"
		shortLabel = name
		colorProfile = "generic"
		iconLabel = TacticalCategories.AreaIconLabel(name, "AREA")
	end

	if not dragMode then
		return nil
	end

	return {
		name = name,
		shortLabel = shortLabel or name,
		cmdID = cmdID,
		kind = "drag_area",
		dragMode = dragMode,
		action = action,
		descriptorSource = "activeCmdDesc",
		colorProfile = colorProfile,
		iconLabel = iconLabel,
		iconSource = "fallback text",
	}
end

function TacticalCategories.TacticalOptionFromDesc(desc)
	local areaOption = TacticalCategories.AreaOptionFromDesc(desc)
	if areaOption then
		areaOption.tacticalCategory = TacticalCategories.CategoryForOption(areaOption)
		return areaOption
	end
	if type(desc) ~= "table" or desc.disabled then
		return nil
	end

	local cmdID = tonumber(desc.id or desc.cmdID)
	if type(cmdID) ~= "number" or cmdID < 0 then
		return nil
	end

	local name = tostring(desc.name or desc.action or "Command")
	local action = tostring(desc.action or "")
	local lowerText = TacticalCategories.CommandDescText(desc)
	local option = {
		name = name,
		shortLabel = name,
		cmdID = cmdID,
		kind = "none",
		action = action,
		descriptorSource = "activeCmdDesc",
	}

	if cmdID == CMD.REPEAT or lowerText:find("repeat", 1, true) then
		option.kind = "repeat_toggle"
		option.shortLabel = "Repeat"
	elseif cmdID == TacticalCategories.CmdMoveState
		or lowerText:find("move state", 1, true)
		or lowerText:find("hold position", 1, true)
	then
		option.kind = "move_state_cycle"
		option.shortLabel = "Move State"
	elseif lowerText:find("selfd", 1, true)
		or lowerText:find("self destruct", 1, true)
		or lowerText:find("self-destruct", 1, true)
		or lowerText:find("selfdestroy", 1, true)
		or lowerText:find("self destroy", 1, true)
	then
		option.kind = "self_destruct"
		option.shortLabel = "Self Destruct"
	elseif cmdID == CMD.GUARD or lowerText:find("guard", 1, true) then
		option.kind = "alliedUnit"
		option.shortLabel = "Guard"
	elseif cmdID == CMD.ATTACK or lowerText:find("attack", 1, true) then
		option.kind = "attack"
		option.shortLabel = lowerText:find("area", 1, true) and "Area Attack" or "Attack"
	elseif lowerText:find("set target", 1, true) or string.lower(action) == "settarget" then
		option.kind = "attack"
		option.shortLabel = "Set Target"
	end

	option.tacticalCategory = TacticalCategories.CategoryForOption(option)
	if not option.tacticalCategory then
		return nil
	end
	return option
end

function ControllerCameraTestBuildActiveCommandLookup()
	if type(Spring.GetActiveCmdDescs) ~= "function" then
		return nil
	end
	local ok, descs = pcall(Spring.GetActiveCmdDescs)
	if not ok or type(descs) ~= "table" then
		return nil
	end
	local lookup = {}
	for _, desc in ipairs(descs) do
		local cmdID = desc and tonumber(desc.id or desc.cmdID)
		if type(cmdID) == "number" then
			lookup[cmdID] = true
		end
	end
	return lookup, descs
end

function ControllerCameraTestTacticalCommandAvailable(cmdID, activeCommandLookup)
	if type(cmdID) ~= "number" then
		return true
	end
	if cmdID == CMD.STOP or cmdID == CMD.WAIT or cmdID == CMD.REPEAT then
		return true
	end
	if type(activeCommandLookup) ~= "table" then
		return true
	end
	return activeCommandLookup[cmdID] == true
end

function ControllerCameraTestAppendTacticalCommand(commands, option, activeCommandLookup)
	if type(option) ~= "table" then
		return
	end
	if (option.cmdID == TacticalCategories.CmdMoveState or option.cmdID == TacticalCategories.CmdHighPriority)
		and (type(activeCommandLookup) ~= "table" or activeCommandLookup[option.cmdID] ~= true)
	then
		return
	end
	if option.cmdID ~= nil and not ControllerCameraTestTacticalCommandAvailable(option.cmdID, activeCommandLookup) then
		return
	end
	local category = TacticalCategories.CategoryForOption(option)
	if not category then
		return
	end
	option.tacticalCategory = category
	commands[#commands + 1] = option
end

function ControllerCameraTestAppendDynamicTacticalCommands(commands, descs)
	if type(descs) ~= "table" then
		return
	end
	local seen = {}
	for _, option in ipairs(commands) do
		if type(option) == "table" and type(option.cmdID) == "number" then
			seen[option.cmdID] = true
		end
	end
	for _, desc in ipairs(descs) do
		local option = TacticalCategories.TacticalOptionFromDesc(desc)
		if option and not seen[option.cmdID] then
			commands[#commands + 1] = option
			seen[option.cmdID] = true
		end
	end
end

function ControllerCameraTestSyncAreaMexCommand(commands, selectedUnits)
	local canUseAreaMex = ControllerCameraTestSelectionCanUseAreaMex(selectedUnits)
	if canUseAreaMex then
		ControllerCameraTestEnsureAreaMexHelper()
	end
	for index = #commands, 1, -1 do
		local option = commands[index]
		if type(option) == "table"
			and (option.dragMode == "areaMex" or tonumber(option.cmdID) == TacticalCategories.CmdAreaMex)
		then
			if canUseAreaMex then
				return
			end
			table.remove(commands, index)
		end
	end
	if not canUseAreaMex then
		return
	end

	-- The custom command descriptor may arrive after the radial cache is built.
	-- Constructor runtime data and UnitDef build options determine eligibility.
	ControllerCameraTestAppendTacticalCommand(commands, TacticalCategories.AreaMexFallbackOption(), nil)
end

--------------------------------------------------------------------------------
-- SECTION: Tactical radial
--------------------------------------------------------------------------------
function ControllerCameraTestBuildTacticalSelectionKey(selectedUnits, isFactory)
	local count = type(selectedUnits) == "table" and #selectedUnits or 0
	local first = count > 0 and selectedUnits[1] or "none"
	local last = count > 0 and selectedUnits[count] or "none"
	local canAreaMex = not isFactory and ControllerCameraTestSelectionCanUseAreaMex(selectedUnits)
	return tostring(isFactory and "factory" or "unit")
		.. ":" .. tostring(count)
		.. ":" .. tostring(first)
		.. ":" .. tostring(last)
		.. ":areaMex=" .. tostring(canAreaMex)
end

function ControllerCameraTestBuildTacticalCategoryCommands(commands)
	local byKey = {}
	for _, direction in ipairs(TacticalCategories.Order) do
		local category = TacticalCategories.ByDirection[direction]
		byKey[category.key] = {}
	end
	for _, option in ipairs(commands or {}) do
		local categoryKey = TacticalCategories.CategoryForOption(option)
		if categoryKey and byKey[categoryKey] then
			option.tacticalCategory = categoryKey
			byKey[categoryKey][#byKey[categoryKey] + 1] = option
		end
	end
	return byKey
end

function ControllerCameraTestRefreshTacticalCategoryCommands()
	local menu = ControllerCameraTestTacticalMenu
	local category = TacticalCategories.Info(menu.categoryKey or menu.categoryDirection or "down")
	menu.categoryKey = category.key
	menu.categoryLabel = category.label
	menu.categoryDirection = category.direction
	menu.cachedCommands = (type(menu.categoryCommands) == "table" and menu.categoryCommands[category.key]) or {}
	menu.optionCount = #menu.cachedCommands
	if menu.selectedIndex < 1 or menu.selectedIndex > #menu.cachedCommands then
		menu.selectedIndex = 1
	end
	local option = menu.cachedCommands[menu.selectedIndex]
	menu.highlightedName = option and option.name or "none"
end

function ControllerCameraTestRebuildTacticalCommandCache(reason)
	local menu = ControllerCameraTestTacticalMenu
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local isFactory = ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits)
	local selectionKey = ControllerCameraTestBuildTacticalSelectionKey(selectedUnits, isFactory)
	local commands = {}

	if isFactory then
		local activeCommandLookup, activeCommandDescs = ControllerCameraTestBuildActiveCommandLookup()
		for _, option in ipairs(ControllerCameraTestFactoryTacticalCommandTemplates) do
			ControllerCameraTestAppendTacticalCommand(commands, option, activeCommandLookup)
		end
	else
		local activeCommandLookup, activeCommandDescs = ControllerCameraTestBuildActiveCommandLookup()
		for _, option in ipairs(ControllerCameraTestTacticalCommandTemplates) do
			ControllerCameraTestAppendTacticalCommand(commands, option, activeCommandLookup)
		end
		local selfDestructCmdID = ControllerCameraTestFindSelfDestructCommandID()
		if type(selfDestructCmdID) == "number" then
			ControllerCameraTestAppendTacticalCommand(commands, {
				name = "Self Destruct",
				shortLabel = "Self Destruct",
				cmdID = selfDestructCmdID,
				kind = "self_destruct",
				descriptorSource = "activeCmdDesc",
			}, activeCommandLookup)
		end
		ControllerCameraTestAppendDynamicTacticalCommands(commands, activeCommandDescs)
		ControllerCameraTestSyncAreaMexCommand(commands, selectedUnits)
	end
	menu.allCachedCommands = commands
	menu.categoryCommands = ControllerCameraTestBuildTacticalCategoryCommands(commands)
	ControllerCameraTestRefreshTacticalCategoryCommands()
	menu.cacheValid = true
	menu.cacheSelectionKey = selectionKey
	menu.cacheLastRefreshTime = debugEventTime
	menu.optionCount = #menu.cachedCommands
	menu.optionsRebuildCount = (menu.optionsRebuildCount or 0) + 1
	menu.cacheMisses = (menu.cacheMisses or 0) + 1
	menu.lastRebuildReason = tostring(reason or "refresh")
	return menu.cachedCommands
end

function ControllerCameraTestMaybeRefreshTacticalCommandCache()
	local menu = ControllerCameraTestTacticalMenu
	if not menu.open then
		return
	end
	if (debugEventTime - (menu.cacheLastRefreshTime or -10)) < 1 then
		return
	end
	local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
	local isFactory = ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits)
	local selectionKey = ControllerCameraTestBuildTacticalSelectionKey(selectedUnits, isFactory)
	if selectionKey ~= menu.cacheSelectionKey then
		ControllerCameraTestRebuildTacticalCommandCache("selection changed")
	else
		menu.cacheLastRefreshTime = debugEventTime
	end
end

function ControllerCameraTestGetTacticalCommands(forceRefresh, reason)
	local menu = ControllerCameraTestTacticalMenu
	if forceRefresh or not menu.cacheValid or type(menu.cachedCommands) ~= "table" then
		return ControllerCameraTestRebuildTacticalCommandCache(reason or "cache miss")
	end
	menu.cacheHits = (menu.cacheHits or 0) + 1
	return menu.cachedCommands
end

function ControllerCameraTestFindTacticalAreaOptionByMode(dragMode, forceRefresh, reason)
	local commands = ControllerCameraTestGetTacticalCommands(forceRefresh, reason or "area shortcut")
	for _, option in ipairs(commands or {}) do
		if type(option) == "table" and option.dragMode == dragMode and ControllerCameraTestIsAreaTacticalOption(option) then
			return option
		end
	end
	return nil
end

function ControllerCameraTestStageAreaCommandShortcut(dragMode, label)
	local option = ControllerCameraTestFindTacticalAreaOptionByMode(dragMode, true, "area shortcut")
	if option then
		return ControllerCameraTestStageTacticalCommand(option)
	end
	local name = tostring(label or dragMode or "Area command")
	ControllerCameraTestTacticalMenu.lastResult = name .. " unavailable"
	ControllerCameraTestLayerDebug.commandLayerAction = name .. " unavailable"
	ControllerCameraTestUpdateAreaCommandDebug("failed unavailable", nil, nil, nil, name .. " unavailable")
	latchSelectionDebugMessage(name .. " unavailable")
	return false
end

function ControllerCameraTestRefreshTacticalDebug(commands)
	local menu = ControllerCameraTestTacticalMenu
	if commands == nil and not menu.open then
		commands = type(menu.cachedCommands) == "table" and menu.cachedCommands or {}
	else
		commands = commands or ControllerCameraTestGetTacticalCommands(false, "debug")
	end
	if #commands <= 0 then
		menu.selectedIndex = 1
		menu.highlightedName = "none"
		menu.optionCount = 0
		return
	end
	if menu.selectedIndex < 1 or menu.selectedIndex > #commands then
		menu.selectedIndex = 1
	end
	local option = commands[menu.selectedIndex]
	menu.highlightedName = option and option.name or "none"
	menu.optionCount = #commands
end

function ControllerCameraTestSetTacticalHighlight(index, reason)
	local menu = ControllerCameraTestTacticalMenu
	local commands = ControllerCameraTestGetTacticalCommands(false, "highlight")
	if #commands <= 0 then
		menu.selectedIndex = 1
		menu.highlightedName = "none"
		menu.lastAction = "no tactical commands"
		return
	end
	menu.selectedIndex = ((index - 1) % #commands) + 1
	menu.lastAction = reason or "highlight changed"
	ControllerCameraTestRefreshTacticalDebug(commands)
end

function ControllerCameraTestToggleTacticalMenu()
	local menu = ControllerCameraTestTacticalMenu
	if ControllerCameraTestUsesNativeBARUI() then
		menu.open = not menu.open
		local commands = {}
		if menu.open and WG.ordermenu and type(WG.ordermenu.controllerGetCommands) == "function" then
			local ok, result = pcall(WG.ordermenu.controllerGetCommands)
			if ok and type(result) == "table" then commands = result end
		end
		if menu.open and #commands == 0 then menu.open = false end
		ControllerCameraTestNativeUI.tacticalFocus = math.max(1,
			math.min(#commands, ControllerCameraTestNativeUI.tacticalFocus or 1))
		local focused = commands[ControllerCameraTestNativeUI.tacticalFocus]
		if WG.ordermenu and type(WG.ordermenu.controllerSetFocus) == "function" then
			pcall(WG.ordermenu.controllerSetFocus, menu.open and focused and focused.id or nil)
		end
		menu.cachedCommands = commands
		menu.selectedIndex = ControllerCameraTestNativeUI.tacticalFocus
		menu.highlightedName = focused and (focused.name or focused.action) or "none"
		menu.lastAction = menu.open and "native order panel opened" or "native order panel closed"
		latchSelectionDebugMessage(menu.lastAction)
		return menu.open
	end
	menu.open = not menu.open
	if menu.open then
		ControllerCameraTestMemoryDebug.tacticalOpenCount = (ControllerCameraTestMemoryDebug.tacticalOpenCount or 0) + 1
		menu.categoryKey = menu.categoryKey or "tactical"
		menu.categoryDirection = menu.categoryDirection or "down"
		ControllerCameraTestGetTacticalCommands(true, "menu opened")
	else
		menu.cacheValid = false
	end
	menu.lastAction = menu.open and "opened" or "closed"
	ControllerCameraTestRefreshTacticalDebug()
	latchSelectionDebugMessage(menu.open and "Command layer tactical menu opened" or "Tactical menu closed")
end

function ControllerCameraTestTacticalTogglePressed()
	return ControllerCameraTestBindingPressed("RB") or ControllerCameraTestActionPressed("buildRadial")
end

function ControllerCameraTestSelectTacticalCategory(direction, reason)
	local menu = ControllerCameraTestTacticalMenu
	local category = TacticalCategories.Info(direction)
	menu.categoryKey = category.key
	menu.categoryLabel = category.label
	menu.categoryDirection = category.direction
	menu.selectedIndex = 1
	ControllerCameraTestRefreshTacticalCategoryCommands()
	menu.lastAction = tostring(reason or "category") .. ": " .. category.label
	latchSelectionDebugMessage("Tactical: " .. category.label)
	return true
end

function ControllerCameraTestCycleTacticalCommand(delta)
	local menu = ControllerCameraTestTacticalMenu
	local commands = ControllerCameraTestGetTacticalCommands(false, "cycle")
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

	ControllerCameraTestMaybeRefreshTacticalCommandCache()
	local commands = ControllerCameraTestGetTacticalCommands(false, "stick")
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
	menu.stagedOption = ControllerCameraTestCopyTacticalOption(option)
	menu.stagedName = tostring(option.name or "Command")
	menu.stagedKind = tostring(option.kind or "none")
	menu.stagedState = ControllerCameraTestIsAreaTacticalOption(option) and "staged waiting for center" or "staged"
	menu.repeatPlacementActive = false
	menu.repeatPlacementState = "none"
	menu.open = false
	menu.lastAction = "staged " .. menu.stagedName
	menu.lastResult = "staged: move reticle, A confirm, B cancel"
	ControllerCameraTestLayerDebug.commandLayerAction = menu.lastAction
	if ControllerCameraTestIsAreaTacticalOption(option) then
		ControllerCameraTestUpdateAreaCommandDebug(menu.stagedState, menu.stagedOption, nil, nil, "staged")
	end
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
	ControllerCameraTestAreaCancelReason = reason or "none"
	ControllerCameraTestUpdateAreaCommandDebug(reason or "none", nil, nil, nil, reason or "cleared")
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
	local repeatOption = ControllerCameraTestCopyTacticalOption(option)
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
		if ControllerCameraTestIsAreaTacticalOption(repeatOption) then
			ControllerCameraTestUpdateAreaCommandDebug("staged waiting for center", repeatOption, nil, nil, "repeat active")
		end
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

	local option = menu.stagedOption
	local drag = ControllerCameraTestDragCommand
	local isAreaCmd = ControllerCameraTestIsAreaTacticalOption(option)

	if ControllerCameraTestActionPressed("tacticalCancel") or ControllerCameraTestActionPressed("cancel") then
		if drag.active and (isAreaCmd or isLineCmd) then
			drag.active = false
			drag.startX, drag.startY, drag.startZ = nil, nil, nil
			drag.endX, drag.endY, drag.endZ = nil, nil, nil
			drag.option = nil
			drag.cmdID = nil
		end
		ControllerCameraTestClearStagedTacticalCommand("cancelled")
		ControllerCameraTestLayerDebug.commandLayerAction = "Tactical staged command cancelled"
		return true
	end

	local isLineCmd = option.kind == "drag_line"
	if (isAreaCmd or isLineCmd) and drag.active then
		drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
	end

	if ControllerCameraTestActionPressed("tacticalSelect") or ControllerCameraTestActionPressed("select") or ControllerCameraTestActionPressed("smartAction") then
		if isAreaCmd or isLineCmd then
			if not drag.active then
				if reticleHasWorldTarget and reticleWorldX then
					drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
					drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
					drag.active = true
					drag.mode = option.dragMode
					drag.cmdID = option.cmdID
					drag.option = option
					menu.stagedState = "dragging radius"
					if isLineCmd then
						ControllerCameraTestShowHotkeyFeedback("FIGHT LINE", "attack")
					else
						ControllerCameraTestUpdateAreaCommandDebug("dragging radius", option, 120, 120 * ControllerCameraTestAreaRadiusSensitivity, "center anchored")
					end
					latchSelectionDebugMessage(option.name .. " anchored")
				end
			else
				ControllerCameraTestConfirmStagedTacticalCommand()
			end
		else
			ControllerCameraTestConfirmStagedTacticalCommand()
		end
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
		local wasAlreadyAnchored = drag.active and (drag.startX ~= nil) and (option.kind == "drag_area")
		drag.active = true
		drag.mode = option.dragMode
		drag.cmdID = option.cmdID
		drag.option = option
		if not wasAlreadyAnchored then
			drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
			drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
		else
			drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
		end
		drag.pressActive = false
		drag.pressButton = nil
		ControllerCameraTestTacticalMenu.lastResult = "confirming staged drag: " .. tostring(option.name)
		pcall(ControllerCameraTestUpdateDragPreview)
		ControllerCameraTestConfirmDragCommand(false)
		ControllerCameraTestTacticalMenu.lastResult = drag.lastResult or ControllerCameraTestTacticalMenu.lastResult
		local confirmed = not tostring(ControllerCameraTestTacticalMenu.lastResult or ""):find("failed", 1, true)
		latchSelectionDebugMessage(option.name .. (confirmed and " confirmed" or " failed"))
		ControllerCameraTestTacticalMenu.open = false
		drag.previewPoints = {}
		drag.startX, drag.startY, drag.startZ = nil, nil, nil
		drag.endX, drag.endY, drag.endZ = nil, nil, nil
		drag.option = nil
		drag.cmdID = nil
		return confirmed
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
	elseif option.kind == "move_state_cycle" then
		local ok = false
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if #selectedUnits > 0 then
			local states = type(Spring.GetUnitStates) == "function" and Spring.GetUnitStates(selectedUnits[1])
			local currentMoveState = states and (states.movestate or states.moveState) or 1
			local nextVal = (tonumber(currentMoveState) or 1) + 1
			if nextVal > 2 then
				nextVal = 0
			end
			local count
			ok, count = ControllerCameraTestIssueOrderToSelectedUnits(TacticalCategories.CmdMoveState, { nextVal }, "Move State", tostring(nextVal), {})
			ControllerCameraTestTacticalMenu.lastResult = ok and ("move state for " .. tostring(count)) or "failed"
		end
		ControllerCameraTestTacticalMenu.open = false
		return ok
	elseif option.kind == "self_destruct" then
		local ok = ControllerCameraTestIssueSelfDestruct()
		ControllerCameraTestTacticalMenu.lastResult = ControllerCameraTestSelfDestruct.lastResult
		ControllerCameraTestLayerDebug.commandLayerAction = "Self Destruct " .. tostring(ControllerCameraTestSelfDestruct.lastResult or "")
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
	if ControllerCameraTestUsesNativeBARUI() then
		local commands = {}
		if WG.ordermenu and type(WG.ordermenu.controllerGetCommands) == "function" then
			local ok, result = pcall(WG.ordermenu.controllerGetCommands)
			if ok and type(result) == "table" then commands = result end
		end
		if #commands == 0 then
			menu.open = false
			return true
		end
		local focus = math.max(1, math.min(#commands, ControllerCameraTestNativeUI.tacticalFocus or 1))
		if ControllerCameraTestActionPressed("tacticalCancel") or ControllerCameraTestActionPressed("tacticalClose") then
			menu.open = false
			if WG.ordermenu and type(WG.ordermenu.controllerSetFocus) == "function" then
				pcall(WG.ordermenu.controllerSetFocus, nil)
			end
			return true
		elseif WasButtonPressed("dpadUp") or WasButtonPressed("dpadLeft") then
			focus = ((focus - 2) % #commands) + 1
		elseif WasButtonPressed("dpadDown") or WasButtonPressed("dpadRight") then
			focus = (focus % #commands) + 1
		elseif ControllerCameraTestActionPressed("tacticalSelect") or ControllerCameraTestActionPressed("radialQuick") then
			local direction = ControllerCameraTestActionPressed("radialQuick") and -1 or 1
			local focused = commands[focus]
			local ok, activated = false, false
			if focused and WG.ordermenu and type(WG.ordermenu.controllerActivate) == "function" then
				ok, activated = pcall(WG.ordermenu.controllerActivate, focused.id, direction)
			end
			menu.lastResult = ok and activated and "native command activated" or "native command unavailable"
			menu.open = false
			if WG.ordermenu and type(WG.ordermenu.controllerSetFocus) == "function" then
				pcall(WG.ordermenu.controllerSetFocus, nil)
			end
			return true
		end
		ControllerCameraTestNativeUI.tacticalFocus = focus
		menu.selectedIndex = focus
		menu.cachedCommands = commands
		menu.highlightedName = commands[focus] and (commands[focus].name or commands[focus].action) or "none"
		if WG.ordermenu and type(WG.ordermenu.controllerSetFocus) == "function" then
			pcall(WG.ordermenu.controllerSetFocus, commands[focus] and commands[focus].id or nil)
		end
		return true
	end

	ControllerCameraTestMaybeRefreshTacticalCommandCache()
	ControllerCameraTestUpdateTacticalStickSelection()
	local changed = false

	if ControllerCameraTestActionPressed("tacticalCancel") or ControllerCameraTestActionPressed("tacticalClose") then
		menu.open = false
		menu.cacheValid = false
		menu.lastAction = "cancelled"
		latchSelectionDebugMessage("Tactical menu cancelled")
		changed = true
	elseif WasButtonPressed("dpadUp") then
		ControllerCameraTestSelectTacticalCategory("up", "D-pad category")
		changed = true
	elseif WasButtonPressed("dpadDown") then
		ControllerCameraTestSelectTacticalCategory("down", "D-pad category")
		changed = true
	elseif ControllerCameraTestActionPressed("tacticalSelect") or ControllerCameraTestActionPressed("radialQuick") then
		local commands = ControllerCameraTestGetTacticalCommands(false, "select")
		ControllerCameraTestExecuteTacticalCommand(commands[menu.selectedIndex], true)
		changed = true
	end
	if changed then
		ControllerCameraTestRefreshTacticalDebug()
	end
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

	local group = unitDef.customParams and unitDef.customParams.unitgroup
	if group then
		local categoryGroupMapping = {
			energy = "Economy",
			metal = "Economy",
			builder = "Build",
			buildert2 = "Build",
			buildert3 = "Build",
			buildert4 = "Build",
			util = "Utility",
			weapon = "Combat",
			explo = "Combat",
			weaponaa = "Combat",
			weaponsub = "Combat",
			aa = "Combat",
			emp = "Combat",
			sub = "Combat",
			nuke = "Combat",
			antinuke = "Combat",
		}
		local mapped = categoryGroupMapping[group]
		if mapped then
			return mapped
		end
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

	return "Utility"
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
		if type(desc) == "table" then
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
						disabled = desc.disabled == true,
						disabledReason = desc.disabled and ControllerCameraTestCleanRadialDescription(desc.tooltip or "") or nil,
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
	ControllerCameraTestInvalidateAffordabilityCache()  -- refresh on page/category change
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

function ControllerCameraTestInvalidateAffordabilityCache()
	-- Forces the affordability cache to be rebuilt on next draw
	ControllerCameraTestBuildMenu.affordabilityCacheTime = -100
	ControllerCameraTestBuildMenu.affordabilityCache = {}
end

local AFFORDABILITY_CACHE_TTL = 10  -- seconds between full re-checks during idle browsing

function ControllerCameraTestGetCachedAffordability(option)
	-- Returns (affordable, metalAffordable, energyAffordable) from cache,
	-- rebuilding the cache when stale (>10s) or freshly invalidated.
	local menu = ControllerCameraTestBuildMenu
	local now = debugEventTime
	if (now - (menu.affordabilityCacheTime or -100)) >= AFFORDABILITY_CACHE_TTL then
		-- Rebuild cache for all currently visible options
		local newCache = {}
		for _, opt in ipairs(menu.radialVisibleOptions or {}) do
			if opt and opt.cmdID then
				local aff, mAff, eAff = ControllerCameraTestCanAffordBuildOption(opt)
				newCache[opt.cmdID] = { aff, mAff, eAff }
			end
		end
		menu.affordabilityCache = newCache
		menu.affordabilityCacheTime = now
	end
	local key = option and option.cmdID
	local cached = key and menu.affordabilityCache[key]
	if cached then
		return cached[1], cached[2], cached[3]
	end
	-- Fallback for items not in cache (e.g. factory units without cmdID key collision)
	return ControllerCameraTestCanAffordBuildOption(option)
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
	if ControllerCameraTestUsesNativeBARUI() then
		local items = {}
		if WG.buildmenu and type(WG.buildmenu.controllerGetItems) == "function" then
			local ok, result = pcall(WG.buildmenu.controllerGetItems)
			if ok and type(result) == "table" then items = result end
		end
		if #items == 0 then
			menu.open, menu.lastAction = false, "native build menu has no options"
			latchSelectionDebugMessage(menu.lastAction)
			return false
		end
		menu.open, menu.lastAction, menu.optionCount = true, "native build menu opened", #items
		ControllerCameraTestNativeUI.buildFocus = items[1].unitDefID
		if WG.buildmenu and type(WG.buildmenu.controllerSetInputActive) == "function" then
			pcall(WG.buildmenu.controllerSetInputActive, true)
		end
		if WG.buildmenu and type(WG.buildmenu.controllerSetFocus) == "function" then
			pcall(WG.buildmenu.controllerSetFocus, ControllerCameraTestNativeUI.buildFocus)
		end
		activeButtonLayoutSummary = "Native Build Menu: D-pad navigate | A activate | X dequeue | B/Y close"
		latchSelectionDebugMessage(menu.lastAction .. ": " .. tostring(#items) .. " options")
		return true
	end
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
	ControllerCameraTestInvalidateAffordabilityCache()  -- immediate refresh on open

	menu.lastAction = "opened"
	menu.placementResult = "none"
	activeButtonLayoutSummary = "Build radial: LS/D-pad select | LB/RB page/category | A place | X quick-place | B/Y close"
	latchSelectionDebugMessage("Y build menu opened: " .. tostring(count) .. " options")
	ControllerCameraTestRefreshBuildMenuDebug()
end

function ControllerCameraTestCloseBuildMenu(reason)
	local menu = ControllerCameraTestBuildMenu
	menu.open = false
	if ControllerCameraTestUsesNativeBARUI() and WG.buildmenu then
		if type(WG.buildmenu.controllerSetFocus) == "function" then pcall(WG.buildmenu.controllerSetFocus, nil) end
		if type(WG.buildmenu.controllerSetInputActive) == "function" then
			pcall(WG.buildmenu.controllerSetInputActive, ControllerCameraTestNativeUI.controllerStable)
		end
		ControllerCameraTestNativeUI.buildFocus = nil
	end
	menu.lastAction = reason or "closed"
	activeButtonLayoutSummary = commandLayerActive
		and XboxController.commandLayoutSummary
		or XboxController.normalLayoutSummary
	latchSelectionDebugMessage("Build menu closed")
	ControllerCameraTestRefreshBuildMenuDebug()
	ControllerCameraTestClearDragPreviewCache()
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

function ControllerCameraTestResolveBuildPosition(cmdID, x, z, facing, validate)
	if type(cmdID) ~= "number" or cmdID >= 0 or type(x) ~= "number" or type(z) ~= "number"
		or type(spGetGroundHeight) ~= "function"
	then
		return nil, nil, nil, false, "invalid build position"
	end

	local groundOk, groundY = pcall(spGetGroundHeight, x, z)
	if not groundOk or type(groundY) ~= "number" then
		return nil, nil, nil, false, "terrain height unavailable"
	end

	local unitDefID = -cmdID
	local sx, sz = x, z
	if type(Spring.Pos2BuildPos) == "function" then
		local snapOk, snappedX, _, snappedZ = pcall(Spring.Pos2BuildPos, unitDefID, x, groundY, z, facing or 0)
		if not snapOk or type(snappedX) ~= "number" or type(snappedZ) ~= "number" then
			return nil, nil, nil, false, "build-grid snap failed"
		end
		sx, sz = snappedX, snappedZ
	end

	-- Re-resolve after grid snapping. Negative underwater terrain is retained;
	-- the engine receives the actual terrain Y for land and water definitions.
	local finalGroundOk, sy = pcall(spGetGroundHeight, sx, sz)
	if not finalGroundOk or type(sy) ~= "number" then
		return nil, nil, nil, false, "snapped terrain height unavailable"
	end

	if validate ~= false and type(Spring.TestBuildOrder) == "function" then
		local testOk, testResult = pcall(Spring.TestBuildOrder, unitDefID, sx, sy, sz, facing or 0)
		if not testOk or type(testResult) ~= "number" or testResult <= 0 then
			return sx, sy, sz, false, "invalid build order"
		end
	end
	return sx, sy, sz, true, "valid"
end

function ControllerCameraTestGetBuildAvailability(option)
	if not option then return nil end
	if option.disabled then
		local reason = string.lower(tostring(option.disabledReason or option.tooltip or ""))
		if string.find(reason, "limit", 1, true) then return "UNIT LIMIT REACHED" end
		if string.find(reason, "tech", 1, true) or string.find(reason, "unlock", 1, true)
				or string.find(reason, "locked", 1, true) then return "TECH LOCKED" end
		if string.find(reason, "cannot", 1, true) or string.find(reason, "unavailable", 1, true) then
			return string.upper(ControllerCameraTestCleanRadialDescription(option.disabledReason or option.tooltip))
		end
		return "CANNOT BUILD"
	end
	if type(Spring.GetMyTeamID) ~= "function" or type(Spring.GetTeamResources) ~= "function" then return nil end
	local team = Spring.GetMyTeamID()
	local okM, currentM = pcall(Spring.GetTeamResources, team, "metal")
	local okE, currentE = pcall(Spring.GetTeamResources, team, "energy")
	currentM = okM and tonumber(currentM) or 0; currentE = okE and tonumber(currentE) or 0
	local deficitM = math.max(0, (tonumber(option.metalCost) or 0) - currentM)
	local deficitE = math.max(0, (tonumber(option.energyCost) or 0) - currentE)
	local parts = {}
	if deficitM > 0 then parts[#parts + 1] = "NEED " .. ControllerCameraTestFormatRadialStatNumber(deficitM) .. " METAL" end
	if deficitE > 0 then parts[#parts + 1] = "NEED " .. ControllerCameraTestFormatRadialStatNumber(deficitE) .. " ENERGY" end
	return #parts > 0 and table.concat(parts, "  |  ") or nil
end

function ControllerCameraTestGetSnappedBuildPosition(cmdID, x, y, z, facing)
	return ControllerCameraTestResolveBuildPosition(cmdID, x, z, facing, true)
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
	if option and option.disabled then
		placement.nativeSetActiveCommandResult = "failed: descriptor disabled"
		return false
	end
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
	ControllerCameraTestClearDragPreviewCache()
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
	local savedSpacing = option.cmdID and spacingByBuildCmdID[option.cmdID] or 0
	pcall(Spring.SendCommands, "buildspacing " .. savedSpacing)
	placement.placementSpacing = savedSpacing
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
	placement.slowPanActive = false  -- reset pan speed on exit
	latchSelectionDebugMessage("Placement cancelled")
	ControllerCameraTestClearDragPreviewCache()
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
					local newSpacing = Spring.GetBuildSpacing() or 0
					placement.placementSpacing = newSpacing
					if placement.option and placement.option.cmdID then
						spacingByBuildCmdID[placement.option.cmdID] = newSpacing
					end
					ControllerCameraTestShowHotkeyFeedback("SPACING " .. newSpacing, "utility")
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
					local newSpacing = Spring.GetBuildSpacing() or 0
					placement.placementSpacing = newSpacing
					if placement.option and placement.option.cmdID then
						spacingByBuildCmdID[placement.option.cmdID] = newSpacing
					end
					ControllerCameraTestShowHotkeyFeedback("SPACING " .. newSpacing, "utility")
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
	local useQueueFront = (ControllerCameraTestBuildPlacement.active and ControllerCameraTestBuildPlacement.queueFrontActive) or ControllerCameraTestIsQueueFrontModifierActive()
	local orderOptions = ControllerCameraTestGetCommandOptions()
	ControllerCameraTestBuildPlacement.queueActive = queueActive
	ControllerCameraTestCommandDebug.lastOptions = ControllerCameraTestCommandOptionsSummary(orderOptions)
	if option and option.disabled then
		menu.placementResult = ControllerCameraTestGetBuildAvailability(option) or "cannot build"
		ControllerCameraTestBuildPlacement.lastResult = menu.placementResult
		ControllerCameraTestShowHotkeyFeedback(string.upper(menu.placementResult), "utility")
		return false
	end
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
		and ControllerCameraTestAttemptMexBuildSmartAction(reticleWorldX, reticleWorldY, reticleWorldZ, queueActive, useQueueFront)
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
	local x, y, z, validPosition, positionReason = ControllerCameraTestGetSnappedBuildPosition(option.cmdID, reticleWorldX, reticleWorldY, reticleWorldZ, facing)
	if not validPosition then
		menu.placementResult = tostring(positionReason or "invalid placement")
		menu.placementParamsCount = 0
		ControllerCameraTestBuildPlacement.lastResult = menu.placementResult
		menu.lastAction = "place failed"
		latchSelectionDebugMessage("Build place failed: " .. menu.placementResult)
		ControllerCameraTestRefreshBuildMenuDebug()
		return false
	end
	local params = { x, y, z, facing }
	local issuedCount = 0

	local useQueueFront = ControllerCameraTestBuildPlacement.active and ControllerCameraTestBuildPlacement.queueFrontActive
	local cmdInsert = CMD.INSERT

	if ControllerCameraTestSettings.debugPanelVisible and (useQueueFront or ControllerCameraTestIsQueueFrontModifierActive()) then
		Spring.Echo(string.format(
			"[ControllerQueueDebug] Path: ConfirmBuildPlacement | cmdID: %s | params: %s | Y_insert: %s | RT_append: %s | final_options: %s | wrapper_used: %s | Y_priority: %s",
			tostring(option.cmdID),
			serializeTable(params),
			tostring(ControllerCameraTestIsQueueFrontModifierActive()),
			tostring(ControllerCameraTestIsQueueModifierActive()),
			"alt",
			tostring(useQueueFront),
			tostring(ControllerCameraTestIsQueueFrontModifierActive() and ControllerCameraTestIsQueueModifierActive())
		))
	end

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
		menu.lastAction = queueActive and "factory dequeued 5 (X)" or "factory dequeued (X)"
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
	if option.disabled then
		menu.lastAction = ControllerCameraTestGetBuildAvailability(option) or "cannot build"
		ControllerCameraTestShowHotkeyFeedback(string.upper(menu.lastAction), "utility")
		return false
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
			local savedSpacing = option.cmdID and spacingByBuildCmdID[option.cmdID] or 0
			pcall(Spring.SendCommands, "buildspacing " .. savedSpacing)
			placement.placementSpacing = savedSpacing
			placement.placementPattern = "single"
			placement.queueFrontActive = false
			placement.lastConstructionShortcut = "none"
			placement.gridShortcutResult = "none"
			placement.slowPanActive = true
			menu.lastAction = "entered native placement"
			latchSelectionDebugMessage("Placement: " .. tostring(option.name) .. " (native)")
			ControllerCameraTestRefreshBuildMenuDebug()
			ControllerCameraTestShowHotkeyFeedback("SPACING " .. savedSpacing, "utility")
			return
		end
	end

	-- Fallback to existing custom placement logic
	if ControllerCameraTestSetPlacementOption(option) then
		placement.nativePreviewActive = false
		placement.placementMode = "custom"
		local savedSpacing = option.cmdID and spacingByBuildCmdID[option.cmdID] or 0
		pcall(Spring.SendCommands, "buildspacing " .. savedSpacing)
		placement.placementSpacing = savedSpacing
		placement.placementPattern = "single"
		placement.queueFrontActive = false
		placement.lastConstructionShortcut = "none"
		placement.gridShortcutResult = "none"
		placement.slowPanActive = true
		menu.lastAction = "entered custom placement"
		ControllerCameraTestShowHotkeyFeedback("SPACING " .. savedSpacing, "utility")
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
	-- Back button: toggle slow pan speed during placement
	elseif WasButtonPressed("back") then
		placement.slowPanActive = not placement.slowPanActive
		if placement.slowPanActive then
			ControllerCameraTestShowHotkeyFeedback("SLOW PAN", "utility")
		else
			ControllerCameraTestShowHotkeyFeedback("FULL PAN", "utility")
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
			-- Y is reserved as Do Next modifier, so do not cancel placement with Y
			local radialCloseBtn = ControllerCameraTestGetBinding("radialClose")
			if radialCloseBtn ~= "Y" and radialCloseBtn ~= "none" then
				ControllerCameraTestCancelPlacement("cancelled by " .. radialCloseBtn)
			end
		elseif ControllerCameraTestHandlePlacementPatternInput() then
			-- Pattern helper handles LB tap-to-cycle and hold-to-grid.
		elseif ControllerCameraTestActionPressed("spacingUp") then
			ControllerCameraTestTryConstructionShortcut("spacing", "inc")
		elseif ControllerCameraTestActionPressed("spacingDown") then
			ControllerCameraTestTryConstructionShortcut("spacing", "dec")
		end
	end

	if drag.active then
		activeButtonLayoutSummary = "Drag Build: A/X confirm, B cancel, Back slow/full pan, RS X camera, D-pad L/R facing, U/D spacing, LB tap pattern/hold grid"
	else
		activeButtonLayoutSummary = "Placement: A place+exit, X place again, B cancel, Back slow/full pan, RS X camera, D-pad L/R facing, U/D spacing, LB tap pattern/hold grid"
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
	if ControllerCameraTestUsesNativeBARUI() then
		if ControllerCameraTestActionPressed("radialCancel") or ControllerCameraTestActionPressed("radialClose") then
			ControllerCameraTestCloseBuildMenu("native panel closed")
			return true
		end
		local dx, dy = 0, 0
		if WasButtonPressed("dpadLeft") then dx = -1
		elseif WasButtonPressed("dpadRight") then dx = 1
		elseif WasButtonPressed("dpadUp") then dy = -1
		elseif WasButtonPressed("dpadDown") then dy = 1 end
		if (dx ~= 0 or dy ~= 0) and WG.buildmenu and type(WG.buildmenu.controllerMoveFocus) == "function" then
			local ok, unitDefID, item = pcall(WG.buildmenu.controllerMoveFocus, dx, dy)
			if ok then
				ControllerCameraTestNativeUI.buildFocus = unitDefID
				menu.highlightedName = type(item) == "table" and item.name or tostring(unitDefID or "none")
			end
		elseif ControllerCameraTestActionPressed("radialSelect") or ControllerCameraTestActionPressed("radialQuick") then
			local button = ControllerCameraTestActionPressed("radialQuick") and 3 or 1
			local ok, activated = false, false
			if WG.buildmenu and type(WG.buildmenu.controllerActivate) == "function" then
				ok, activated = pcall(WG.buildmenu.controllerActivate,
					ControllerCameraTestNativeUI.buildFocus, button)
			end
			menu.lastAction = ok and activated and "native build command activated" or "native build unavailable"
			if button == 1 and ok and activated then ControllerCameraTestCloseBuildMenu("native command activated") end
		end
		return true
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
		ControllerCameraTestCloseBuildMenu("closed by B")
	elseif ControllerCameraTestActionPressed("radialQuick") then
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits) then
			local option = type(menu.options) == "table" and menu.options[menu.selectedIndex] or nil
			if option and option.disabled then
				menu.lastAction = ControllerCameraTestGetBuildAvailability(option) or "cannot build"
				menu.radialLastAction = menu.lastAction
				ControllerCameraTestShowHotkeyFeedback(string.upper(menu.lastAction), "utility")
			elseif option then
				ControllerCameraTestDequeueFactoryBuildOption(option)
			else
				menu.lastAction = "factory dequeue failed: no option"
				menu.radialLastAction = "factory dequeue failed: no option"
			end
		end
	elseif ControllerCameraTestActionPressed("radialClose") then
		ControllerCameraTestCloseBuildMenu("closed by Y")
	elseif ControllerCameraTestActionPressed("radialSelect") then
		local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
		if ControllerCameraTestSelectionPrefersFactoryQueue(selectedUnits) then
			local option = type(menu.options) == "table" and menu.options[menu.selectedIndex] or nil
			if option and option.disabled then
				menu.lastAction = ControllerCameraTestGetBuildAvailability(option) or "cannot build"
				menu.radialLastAction = menu.lastAction
				ControllerCameraTestShowHotkeyFeedback(string.upper(menu.lastAction), "utility")
			elseif option then
				local queueActive = ControllerCameraTestIsQueueModifierActive()
				local queueFrontActive = ControllerCameraTestIsQueueFrontModifierActive() or (normalizedLeftTrigger > 0.5)
				local orderOptions = ControllerCameraTestGetCommandOptions()

				local cmdToIssue = option.cmdID
				local paramsToIssue = {}
				local optionsToIssue = orderOptions

				if queueFrontActive then
					optionsToIssue = { "alt" }
				end

				ControllerCameraTestBuildPlacement.queueActive = queueActive
				ControllerCameraTestBuildPlacement.queueFrontActive = queueFrontActive
				local ok, issuedCount = ControllerCameraTestIssueOrderToSelectedUnits(cmdToIssue, paramsToIssue, "Factory queue " .. tostring(option.name), "queue", optionsToIssue)
				if ok then
					if queueFrontActive then
						ControllerCameraTestShowHotkeyFeedback("INSERT", "utility")
					end
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
	elseif WasButtonPressed("dpadUp") then
		local foundIndex = nil
		for idx, cat in ipairs(categories) do
			if cat == "Combat" then foundIndex = idx; break end
		end
		if foundIndex then
			menu.radialCategoryIndex = foundIndex
			menu.radialCategoryName = "Combat"
			menu.radialPage = 1
			ControllerCameraTestRefreshRadialVisibleOptions()
			if #menu.radialVisibleOptions > 0 then
				menu.selectedIndex = menu.radialVisibleOptions[1].menuIndex
			end
			menu.lastAction = "category Combat"
		end
	elseif WasButtonPressed("dpadRight") then
		local foundIndex = nil
		for idx, cat in ipairs(categories) do
			if cat == "Utility" then foundIndex = idx; break end
		end
		if foundIndex then
			menu.radialCategoryIndex = foundIndex
			menu.radialCategoryName = "Utility"
			menu.radialPage = 1
			ControllerCameraTestRefreshRadialVisibleOptions()
			if #menu.radialVisibleOptions > 0 then
				menu.selectedIndex = menu.radialVisibleOptions[1].menuIndex
			end
			menu.lastAction = "category Utility"
		end
	elseif WasButtonPressed("dpadDown") then
		local foundIndex = nil
		for idx, cat in ipairs(categories) do
			if cat == "Economy" then foundIndex = idx; break end
		end
		if foundIndex then
			menu.radialCategoryIndex = foundIndex
			menu.radialCategoryName = "Economy"
			menu.radialPage = 1
			ControllerCameraTestRefreshRadialVisibleOptions()
			if #menu.radialVisibleOptions > 0 then
				menu.selectedIndex = menu.radialVisibleOptions[1].menuIndex
			end
			menu.lastAction = "category Economy"
		end
	elseif WasButtonPressed("dpadLeft") then
		local foundIndex = nil
		for idx, cat in ipairs(categories) do
			if cat == "Build" then foundIndex = idx; break end
		end
		if foundIndex then
			menu.radialCategoryIndex = foundIndex
			menu.radialCategoryName = "Build"
			menu.radialPage = 1
			ControllerCameraTestRefreshRadialVisibleOptions()
			if #menu.radialVisibleOptions > 0 then
				menu.selectedIndex = menu.radialVisibleOptions[1].menuIndex
			end
			menu.lastAction = "category Build"
		end
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

	activeButtonLayoutSummary = "Build radial: LS select | Dpad Up Combat, Right Utility, Down Economy, Left Build | LB/RB page | A place | X dequeue | B close"
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
	local selected = false
	if ControllerCameraTestUsesNativeBARUI() and WG.smartselect
			and type(WG.smartselect.controllerApplyUnits) == "function" then
		local ok, result = pcall(WG.smartselect.controllerApplyUnits, filteredUnits,
			ControllerCameraTestIsQueueModifierActive() and "toggle" or "replace", true)
		selected = ok and type(result) == "table" and #result > 0
	else
		selected = ControllerCameraTestSelectUnits(filteredUnits, "Area select")
	end
	if selected then
		area.lastResult = "selected " .. tostring(#filteredUnits) .. " (" .. tostring(area.filterMode) .. ")"
	else
		area.lastResult = "no units selected"
	end
	ControllerCameraTestLayerDebug.areaSelect = area.lastResult
end

function ControllerCameraTestHandleNormalXInput(dt)
	if ControllerCameraTestActionDown("pitchModifier") and ControllerCameraTestCanUseLBHotkeys() then
		return false
	end

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
				-- Normal Smart X hold is always movement. Fight and Attack line
				-- commands remain available through their explicit command-layer inputs.
				drag.mode = "moveLine"
				ControllerCameraTestShowHotkeyFeedback("MOVE LINE", "utility")
				drag.lastResult = "active"
				latchSelectionDebugMessage(drag.mode .. " Drag started")
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
		if ControllerCameraTestActionDown("pitchModifier") then
			ControllerCameraTestStageAreaCommandShortcut("attackArea", "Attack Area")
			return true
		end
	end

	if drag.pressActive and (drag.pressButton == "RT+X" or drag.pressButton == "fight") and ControllerCameraTestActionDown("smartAction") then
		if not drag.active and (debugEventTime - drag.pressStartTime) >= X_HOLD_SECONDS then
			drag.active = true
			if drag.pressButton == "RT+X" then
				drag.mode = "attackLine"
				drag.lastResult = "active"
				latchSelectionDebugMessage("Attack Line Drag started")
			else
				drag.mode = "fightLine"
				drag.lastResult = "active"
				latchSelectionDebugMessage("Fight Line Drag started")
			end
		end
		if drag.active then
			ControllerCameraTestUpdateDragPreview()
		end
	end

	if ControllerCameraTestActionReleased("smartAction") and drag.pressActive and (drag.pressButton == "RT+X" or drag.pressButton == "fight") then
		if drag.active then
			ControllerCameraTestConfirmDragCommand(false)
		else
			if drag.pressButton == "RT+X" then
				attemptAttackCommand()
			else
				attemptFightCommand()
			end
		end
		drag.pressActive = false
	end



	return drag.pressActive or drag.active
end

function ControllerCameraTestHandleNormalAInput(dt)
	if ControllerCameraTestActionDown("pitchModifier")
			and (ControllerCameraTestCanUseLBHotkeys() or ControllerCameraTestVisibleSelection.radial.open) then
		return false
	end

	local area = ControllerCameraTestAreaSelect
	local HOLD_SECONDS = ControllerCameraTestSettings.aHoldSeconds or 0.38

	if ControllerCameraTestActionPressed("select") then
		area.pressActive = true
		area.active = false
		area.pressStartTime = debugEventTime
		area.lastResult = "press started"
		ControllerCameraTestLayerDebug.areaSelect = area.lastResult

		-- Prepare live brush selection state
		area.brushedUnits = {}
		area.initialSelection = {}
		area.lastBrushedCount = 0
		area.filterRadialOpen = false
		area.highlightedFilter = nil
		area.currentFilter = area.currentFilter or "All Mobile"

		-- Store initial selection if RT (append modifier) is held
		if ControllerCameraTestIsQueueModifierActive() then
			local sel = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
			for _, uID in ipairs(sel) do
				area.initialSelection[uID] = true
			end
		end
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

			-- Intercept X button for selection filter radial
			if ControllerCameraTestActionPressed("smartAction") then
				area.filterRadialOpen = true
				area.highlightedFilter = nil
			end

			if area.filterRadialOpen then
				if ControllerCameraTestActionDown("smartAction") then
					local aimX = normalizedLeftX
					local aimY = -normalizedLeftY  -- aimY positive is up!
					local magnitude = math.sqrt(aimX * aimX + aimY * aimY)
					if magnitude >= 0.50 then
						if math.abs(aimY) > math.abs(aimX) then
							if aimY > 0 then
								area.highlightedFilter = "All Mobile"
							else
								area.highlightedFilter = "Combat"
							end
						else
							if aimX < 0 then
								area.highlightedFilter = "Builders"
							else
								area.highlightedFilter = "Air"
							end
						end
					end
				end

				if ControllerCameraTestActionReleased("smartAction") then
					if area.highlightedFilter then
						area.currentFilter = area.highlightedFilter
						latchSelectionDebugMessage("Filter changed to: " .. area.currentFilter)
					end
					area.filterRadialOpen = false
					area.highlightedFilter = nil
				end
			end

			-- Perform live selection brush scanning and touch-accumulation
			if reticleHasWorldTarget and reticleWorldX and reticleWorldZ and type(ControllerCameraTestGetVisibleAlliedUnits) == "function" then
				local radiusSq = area.radius * area.radius
				for _, unitID in ipairs(ControllerCameraTestGetVisibleAlliedUnits()) do
					local x, _, z = spGetUnitPosition(unitID)
					if x and z then
						local dx = x - reticleWorldX
						local dz = z - reticleWorldZ
						if ((dx * dx) + (dz * dz)) <= radiusSq then
							if not area.brushedUnits[unitID] then
								local _, unitDef = ControllerCameraTestGetUnitDef(unitID)
								if unitDef then
									local isMobile = ControllerCameraTestIsMobileUnitDef(unitDef)
									local isBuilder = isMobile and (unitDef.isBuilder or unitDef.canBuild or (type(unitDef.buildOptions) == "table" and #unitDef.buildOptions > 0))

									local matchesFilter = false
									local filter = area.currentFilter or "All Mobile"
									if filter == "All Mobile" then
										matchesFilter = isMobile
									elseif filter == "Combat" then
										matchesFilter = isMobile and not isBuilder and (unitDef.canAttack or (type(unitDef.weapons) == "table" and #unitDef.weapons > 0))
									elseif filter == "Builders" then
										matchesFilter = isBuilder
									elseif filter == "Air" then
										matchesFilter = isMobile and unitDef.canFly
									end

									if matchesFilter then
										area.brushedUnits[unitID] = true
									end
								end
							end
						end
					end
				end
			end

			-- Apply the accumulated brush selection only when count changes
			local brushedCount = 0
			for _ in pairs(area.brushedUnits) do
				brushedCount = brushedCount + 1
			end

			if brushedCount > 0 and brushedCount ~= (area.lastBrushedCount or 0) then
				area.lastBrushedCount = brushedCount
				local finalSelection = {}
				if area.initialSelection then
					for uID in pairs(area.initialSelection) do
						finalSelection[#finalSelection + 1] = uID
					end
				end
				for uID in pairs(area.brushedUnits) do
					if not area.initialSelection or not area.initialSelection[uID] then
						finalSelection[#finalSelection + 1] = uID
					end
				end
				if #finalSelection > 0 then
					pcall(spSelectUnitArray, finalSelection, false)
				end
			end
		end
	end

	if ControllerCameraTestHandleBackCommandLayerSelectTap() then
		return
	end

	if ControllerCameraTestActionReleased("select") and area.pressActive then
		if area.active then
			-- Already selected live! Just finalize and clean up brush state.
			area.filterRadialOpen = false
			area.highlightedFilter = nil
			area.lastResult = "live brush selection completed"
		elseif (debugEventTime - (area.lastTapTime or -10)) <= 0.35 then
			local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
			local targetID = area.lastTapUnitID
			local unitDefID = area.lastTapUnitDefID

			-- If the reticle is still over a valid allied unit, use that in preference
			local reticleUnitID, reticleUnitDefID = ControllerCameraTestGetReticleAlliedUnitAndDef()
			if reticleUnitID then
				targetID = reticleUnitID
				unitDefID = reticleUnitDefID
			end

			-- Fallback to first selected unit if still nil
			if not targetID and #selectedUnits > 0 then
				targetID = selectedUnits[1]
				local okDef, uDefID = pcall(Spring.GetUnitDefID, targetID)
				if okDef and uDefID then
					unitDefID = uDefID
				end
			end

			if targetID and unitDefID then
				if ControllerCameraTestIsQueueModifierActive() then
					ControllerCameraTestSelectAllOwnedSameTypeUnderReticle(targetID, unitDefID)
				else
					ControllerCameraTestSelectVisibleSameTypeUnderReticle(targetID, unitDefID)
				end
			elseif ControllerCameraTestIsQueueModifierActive() then
				ControllerCameraTestSelectAllIdleUnitsInCurrentTypeBucket()
				area.doubleTapAction = ControllerCameraTestIdleCycle.lastResult
			elseif #selectedUnits == 0 then
				area.lastResult = "double tap empty ignored"
				area.doubleTapAction = "empty ignored"
				ControllerCameraTestLayerDebug.normalUtilityAction = "Double-tap A empty: no action"
				latchSelectionDebugMessage("Double-tap A empty: no action")
			else
				area.lastResult = "double tap ignored: units selected"
				area.doubleTapAction = "ignored: units selected"
				ControllerCameraTestLayerDebug.normalUtilityAction = "Double-tap A ignored"
				latchSelectionDebugMessage("Double-tap A ignored: units already selected")
			end
			area.lastTapTime = -10
			area.lastTapUnitID = nil
			area.lastTapUnitDefID = nil
		else
			attemptReticleSelection()
			local reticleUnitID, reticleUnitDefID = ControllerCameraTestGetReticleAlliedUnitAndDef()
			area.lastTapUnitID = reticleUnitID
			area.lastTapUnitDefID = reticleUnitDefID
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
	return false
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
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+B disabled"
		latchSelectionDebugMessage("Layer+B disabled")
	elseif ControllerCameraTestActionPressed("smartAction") then
		ControllerCameraTestTuning.backCommandLayerATapTime = -10
		ControllerCameraTestLayerDebug.commandLayerAction = "Layer+X disabled"
		latchSelectionDebugMessage("Layer+X disabled")
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

function ControllerCameraTestConsumeLBCycle(reason)
	if ControllerSelectionBehavior then ControllerSelectionBehavior.ConsumeLB(ControllerCameraTestLBCycle, reason) end
	ControllerCameraTestCycleDebug.lbHadPitchMotion = true
end

function ControllerCameraTestCancelVisibleSelectionRadial(reason)
	local radial = ControllerCameraTestVisibleSelection.radial
	if not radial.open then return false end
	radial.open, radial.stickSector, radial.lastResult = false, nil, "cancelled: " .. tostring(reason or "cancel")
	radial.candidate = radial.initialValue or radial.persistedFilter or ControllerCameraTestSettings.visibleSelectionFilter or "Combat"
	ControllerCameraTestConsumeLBCycle("filter radial cancelled")
	return true
end

function ControllerCameraTestOpenVisibleSelectionRadial(initialSector)
	local radial = ControllerCameraTestVisibleSelection.radial
	if radial.open or ControllerCameraTestDisassemble.active then return false end
	local persisted = ControllerCameraTestSettings.visibleSelectionFilter or "Combat"
	if ControllerDisassembleBehavior then ControllerDisassembleBehavior.OpenFilterRadial(radial, persisted, initialSector)
	else
		radial.open, radial.persistedFilter, radial.initialValue = true, persisted, persisted
		radial.candidate, radial.stickSector, radial.lastResult = initialSector or persisted, initialSector, "open"
	end
	ControllerCameraTestConsumeLBCycle("filter radial opened")
	return true
end

function ControllerCameraTestUpdateVisibleSelectionRadial()
	local radial = ControllerCameraTestVisibleSelection.radial
	if not radial.open then return false end
	if not ControllerCameraTestActionDown("pitchModifier") then
		ControllerCameraTestCancelVisibleSelectionRadial("modifier released first")
		return true
	end
	if ControllerCameraTestActionPressed("cancel") then
		ControllerCameraTestCancelVisibleSelectionRadial("cancel action")
		return true
	end
	local sector = ControllerDisassembleBehavior and ControllerDisassembleBehavior.FilterFromStick(normalizedLeftX, -normalizedLeftY)
		or (ControllerSelectionBehavior and ControllerSelectionBehavior.FilterFromStick(normalizedLeftX, -normalizedLeftY))
	if ControllerDisassembleBehavior then ControllerDisassembleBehavior.LatchFilterCandidate(radial, sector)
	else radial.stickSector = sector; if sector then radial.candidate = sector end end
	if ControllerCameraTestActionReleased("buildRadial") then
		local selected = radial.candidate or radial.initialValue or radial.persistedFilter
		if ControllerSelectionBehavior and ControllerSelectionBehavior.IsValidFilter(selected) then
			ControllerCameraTestSettings.visibleSelectionFilter = selected
		end
		radial.persistedFilter = ControllerCameraTestSettings.visibleSelectionFilter
		radial.open, radial.stickSector, radial.lastResult = false, nil, "confirmed: " .. tostring(selected)
		ControllerCameraTestConsumeLBCycle("filter radial confirmed")
		ControllerCameraTestShowHotkeyFeedback(string.upper(tostring(selected)), "utility")
	end
	return true
end

function ControllerCameraTestUpdateDisassembleController(dt)
	local state = ControllerCameraTestDisassemble
	if not ControllerDisassembleBehavior then return false end
	local lbDown = ControllerCameraTestActionDown("pitchModifier")
	local rbDown = ControllerCameraTestActionDown("buildRadial")
	local stickSector = nil
	if not state.active and lbDown and rbDown then
		stickSector = ControllerDisassembleBehavior.FilterFromStick(normalizedLeftX, -normalizedLeftY)
	end
	local event
	event, state.toggle = ControllerDisassembleBehavior.UpdateToggleCharge(
		state.toggle, debugEventTime, lbDown, rbDown, stickSector, state.active,
		ControllerCameraTestSettings.disassembleToggleHoldSeconds)
	if event == "charge-started" then
		ControllerCameraTestConsumeLBCycle("disassemble toggle charge")
		ControllerCameraTestResetLBHotkeys()
	elseif event == "open-filter" then
		ControllerCameraTestOpenVisibleSelectionRadial(stickSector)
	elseif event == "enable" then
		ControllerCameraTestConsumeLBCycle("disassemble mode enabled")
		ControllerCameraTestEnterDisassembleMode()
	elseif event == "disable" then
		ControllerCameraTestExitDisassembleMode("Disassemble Mode Disabled", "manual exit")
	end
	ControllerCameraTestUpdateDisassembleLifecycle()
	if state.active then ControllerCameraTestUpdateDisassembleModeInput(dt); return true end
	return state.toggle.charging == true or state.toggle.waitingForRelease == true
		or ControllerCameraTestVisibleSelection.radial.open == true
end

function ControllerCameraTestUpdateLBTapState()
	local area, cycle = ControllerCameraTestAreaSelect, ControllerCameraTestLBCycle
	local blocked = Spring.GetGameFrame() <= 0 or controllerMouseModeActive or commandLayerActive
		or ControllerCameraTestBuildMenu.open or ControllerCameraTestBuildPlacement.active
		or ControllerCameraTestTacticalMenu.open or ControllerCameraTestSettingsUI.open
		or ControllerCameraTestIsGameplayInputBlocked() or ControllerCameraTestAreaSelect.active
		or (ControllerCameraTestDisassemble and ControllerCameraTestDisassemble.active)
		or (ControllerCameraTestDragCommand and ControllerCameraTestDragCommand.active)
	if area and (blocked or ControllerCameraTestActionDown("pitchModifier")) then
		area.lastTapTime, area.lastTapUnitID, area.lastTapUnitDefID = -10, nil, nil
	end
	if blocked then
		ControllerCameraTestCancelVisibleSelectionRadial("game state interruption")
		if ControllerSelectionBehavior then ControllerSelectionBehavior.ResetLB(cycle, "game state interruption") end
		ControllerCameraTestCycleDebug.lbPressActive, ControllerCameraTestCycleDebug.lbHadPitchMotion = false, false
		return
	end

	local lbDown = ControllerCameraTestActionDown("pitchModifier")
	if ControllerCameraTestActionPressed("pitchModifier") and ControllerCameraTestCanUseLBHotkeys() then
		if ControllerSelectionBehavior then ControllerSelectionBehavior.PressLB(cycle, debugEventTime) end
	end
	if cycle.active and lbDown and ControllerSelectionBehavior then
		ControllerSelectionBehavior.UpdateLB(cycle, debugEventTime, ControllerCameraTestSettings.lbTacticalHoldSeconds)
		if math.abs(normalizedRightY) > 0.2 then ControllerCameraTestConsumeLBCycle("camera pitch motion") end
		ControllerCameraTestUpdateVisibleSelectionRadial()
	end
	if ControllerCameraTestActionReleased("pitchModifier") and cycle.active then
		ControllerCameraTestCancelVisibleSelectionRadial("modifier released first")
		local shouldTap = ControllerSelectionBehavior and ControllerSelectionBehavior.ReleaseLB(cycle, debugEventTime,
			ControllerCameraTestSettings.lbTapMaxSeconds, ControllerCameraTestSettings.lbTacticalHoldSeconds)
		if shouldTap then ControllerCameraTestApplyVisibleSelectionFilter(ControllerCameraTestSettings.visibleSelectionFilter) end
	end
	ControllerCameraTestCycleDebug.lbPressActive = cycle.active == true
	ControllerCameraTestCycleDebug.lbHadPitchMotion = cycle.consumed == true or cycle.tactical == true
end

function ControllerCameraTestResetLBHotkeys()
	if not ControllerCameraTestLBHotkeys then return end
	for _, btn in ipairs({ "A", "B", "X", "Y" }) do
		local state = ControllerCameraTestLBHotkeys[btn]
		if state then
			state.pending = false
			state.pressCount = 0
			state.lastPressTime = 0
			state.holdFired = false
			state.releasedRegistered = false
		end
	end
end

function ControllerCameraTestUpdateLBFaceButtonDispatcher(dt)
	if not ControllerCameraTestLBHotkeys then return end
	if ControllerCameraTestLBCycle.consumed
			and string.find(tostring(ControllerCameraTestLBCycle.consumeReason), "filter radial", 1, true) == 1 then
		ControllerCameraTestResetLBHotkeys()
		return
	end

	if not ControllerCameraTestCanUseLBHotkeys() then
		ControllerCameraTestResetLBHotkeys()
		return
	end

	local lbHeld = ControllerCameraTestActionDown("pitchModifier")
	local buttons = {
		{ key = "A", action = "select" }, { key = "B", action = "cancel" },
		{ key = "X", action = "smartAction" }, { key = "Y", action = "insertNextCommandModifier" },
	}
	local now = debugEventTime

	for _, mapping in ipairs(buttons) do
		local btn, action = mapping.key, mapping.action
		local state = ControllerCameraTestLBHotkeys[btn]
		if not state then
			ControllerCameraTestLBHotkeys[btn] = { pending = false, lastPressTime = 0, pressCount = 0, holdFired = false, releasedRegistered = false }
			state = ControllerCameraTestLBHotkeys[btn]
		else
			if state.holdFired == nil then state.holdFired = false end
			if state.releasedRegistered == nil then state.releasedRegistered = false end
		end

		local isDown = lbHeld and ControllerCameraTestActionDown(action)
		local pressed = lbHeld and ControllerCameraTestActionPressed(action)
		local released = ControllerCameraTestActionReleased(action) or (not isDown and state.lastPressTime > 0 and not state.releasedRegistered)

		if pressed then
			ControllerCameraTestConsumeLBCycle("tactical chord " .. action)
			ControllerCameraTestLBCycle.tactical = true
			state.holdFired = false
			state.releasedRegistered = false

			if state.pending and (now - state.lastPressTime) <= 0.22 then
				state.pending = false
				state.pressCount = 0
				state.lastPressTime = 0
				ControllerCameraTestExecuteLBHotkey(btn, 2)
			else
				state.pending = true
				state.pressCount = 1
				state.lastPressTime = now
			end
		end

		if isDown and state.lastPressTime > 0 and not state.holdFired then
			local heldDuration = now - state.lastPressTime
			if heldDuration >= 0.50 then
				state.holdFired = true
				state.pending = false
				state.pressCount = 0
				state.lastPressTime = 0
				ControllerCameraTestExecuteLBFaceHoldAction(btn)
			end
		end

		if released then
			state.releasedRegistered = true
			if state.pending and not state.holdFired then
				if (now - state.lastPressTime) > 0.22 then
					state.pending = false
					state.pressCount = 0
					state.lastPressTime = 0
					ControllerCameraTestExecuteLBHotkey(btn, 1)
				end
			end
		end

		if state.pending and not isDown and not state.holdFired then
			if (now - state.lastPressTime) > 0.22 then
				state.pending = false
				state.pressCount = 0
				state.lastPressTime = 0
				ControllerCameraTestExecuteLBHotkey(btn, 1)
			end
		end
	end
end

function ControllerCameraTestExecuteLBFaceHoldAction(btn)
	local profile = ControllerCameraTestGetSelectionProfile()
	if not profile then
		latchSelectionDebugMessage("Hold Hotkey: no units selected")
		return
	end

	if profile == "air_transport" then
		if btn == "X" then
			-- LB + Hold X = Load Units area radial.
			if reticleHasWorldTarget and reticleWorldX then
				local loadAreaOption = {
					name = "Load Area",
					shortLabel = "Load Area",
					cmdID = (CMD and CMD.LOAD_UNITS) or 75,
					kind = "drag_area",
					dragMode = "loadArea",
					descriptorSource = "template",
					colorProfile = "load",
					iconLabel = "LOAD",
					iconSource = "fallback text"
				}
				ControllerCameraTestStageTacticalCommand(loadAreaOption)
				local menu = ControllerCameraTestTacticalMenu
				local drag = ControllerCameraTestDragCommand
				drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
				drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
				drag.active = true
				drag.mode = loadAreaOption.dragMode
				drag.cmdID = loadAreaOption.cmdID
				drag.option = loadAreaOption
				menu.stagedState = "dragging radius"
				ControllerCameraTestUpdateAreaCommandDebug("dragging radius", loadAreaOption, 120, 120 * ControllerCameraTestAreaRadiusSensitivity, "center auto-anchored")
				latchSelectionDebugMessage(loadAreaOption.name .. " center auto-anchored")
				ControllerCameraTestShowHotkeyFeedback("LOAD AREA", "utility")
			else
				latchSelectionDebugMessage("Load Area: no valid world target under reticle")
			end
		elseif btn == "A" then
			-- LB + Hold A = Unload Units area radial.
			local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
			if TransportsHaveCargo(selectedUnits) then
				if reticleHasWorldTarget and reticleWorldX then
					local unloadAreaOption = {
						name = "Unload Area",
						shortLabel = "Unload Area",
						cmdID = (CMD and CMD.UNLOAD_UNITS) or 80,
						kind = "drag_area",
						dragMode = "unloadArea",
						descriptorSource = "template",
						colorProfile = "unload",
						iconLabel = "UNLOAD",
						iconSource = "fallback text"
					}
					ControllerCameraTestStageTacticalCommand(unloadAreaOption)
					local menu = ControllerCameraTestTacticalMenu
					local drag = ControllerCameraTestDragCommand
					drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
					drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
					drag.active = true
					drag.mode = unloadAreaOption.dragMode
					drag.cmdID = unloadAreaOption.cmdID
					drag.option = unloadAreaOption
					menu.stagedState = "dragging radius"
					ControllerCameraTestUpdateAreaCommandDebug("dragging radius", unloadAreaOption, 120, 120 * ControllerCameraTestAreaRadiusSensitivity, "center auto-anchored")
					latchSelectionDebugMessage(unloadAreaOption.name .. " center auto-anchored")
					ControllerCameraTestShowHotkeyFeedback("UNLOAD AREA", "utility")
				else
					latchSelectionDebugMessage("Unload Area: no valid world target under reticle")
				end
			else
				ControllerCameraTestShowHotkeyFeedback("NO CARGO", "utility")
			end
		elseif btn == "B" then
			local cmdID = CMD.WAIT or 5
			ControllerCameraTestIssueOrderToSelectedUnits(cmdID, {}, "Wait", "units")
			ControllerCameraTestShowHotkeyFeedback("WAIT", "utility")
		end
	elseif profile == "factory" then
		if btn == "B" then
			local cmdID = CMD.WAIT or 5
			ControllerCameraTestIssueOrderToSelectedUnits(cmdID, {}, "Wait", "units")
			ControllerCameraTestShowHotkeyFeedback("WAIT", "utility")
		end
	else
		if btn == "B" then
			local cmdID = CMD.WAIT or 5
			ControllerCameraTestIssueOrderToSelectedUnits(cmdID, {}, "Wait", "units")
			ControllerCameraTestShowHotkeyFeedback("WAIT", "utility")
		end
	end
end

function ControllerCameraTestExecuteLBHotkey(btn, tapCount)
	local profile = ControllerCameraTestGetSelectionProfile()
	if not profile then
		latchSelectionDebugMessage("Hotkey: no units selected")
		return
	end

	if profile == "builder" then
		if btn == "A" then
			-- LB + A: Repair Area auto-anchored (single tap; AA is unused)
			if tapCount == 1 then
				if reticleHasWorldTarget and reticleWorldX then
					local repairAreaOption = {
						name = "Repair Area",
						shortLabel = "Repair Area",
						cmdID = CMD.REPAIR or 40,
						kind = "drag_area",
						dragMode = "repairArea",
						descriptorSource = "template",
						colorProfile = "repair",
						iconLabel = "REPAIR",
						iconSource = "fallback text"
					}
					ControllerCameraTestStageTacticalCommand(repairAreaOption)
					local menu = ControllerCameraTestTacticalMenu
					local drag = ControllerCameraTestDragCommand
					drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
					drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
					drag.active = true
					drag.mode = repairAreaOption.dragMode
					drag.cmdID = repairAreaOption.cmdID
					drag.option = repairAreaOption
					menu.stagedState = "dragging radius"
					ControllerCameraTestUpdateAreaCommandDebug("dragging radius", repairAreaOption, 120, 120 * ControllerCameraTestAreaRadiusSensitivity, "center auto-anchored")
					latchSelectionDebugMessage(repairAreaOption.name .. " center auto-anchored")
					ControllerCameraTestShowHotkeyFeedback("REPAIR AREA", "repair")
				else
					latchSelectionDebugMessage("Repair Area: no valid world target under reticle")
				end
			end
		elseif btn == "X" then
			if tapCount == 1 then
				if reticleHasWorldTarget and reticleWorldX then
					local reclaimAreaOption = {
						name = "Reclaim Area",
						shortLabel = "Reclaim Area",
						cmdID = CMD.RECLAIM or 90,
						kind = "drag_area",
						dragMode = "reclaimArea",
						descriptorSource = "template",
						colorProfile = "reclaim",
						iconLabel = "RECLAIM",
						iconSource = "fallback text"
					}
					ControllerCameraTestStageTacticalCommand(reclaimAreaOption)
					local menu = ControllerCameraTestTacticalMenu
					local drag = ControllerCameraTestDragCommand
					drag.startX, drag.startY, drag.startZ = reticleWorldX, reticleWorldY, reticleWorldZ
					drag.endX, drag.endY, drag.endZ = reticleWorldX, reticleWorldY, reticleWorldZ
					drag.active = true
					drag.mode = reclaimAreaOption.dragMode
					drag.cmdID = reclaimAreaOption.cmdID
					drag.option = reclaimAreaOption
					menu.stagedState = "dragging radius"
					ControllerCameraTestUpdateAreaCommandDebug("dragging radius", reclaimAreaOption, 120, 120 * ControllerCameraTestAreaRadiusSensitivity, "center auto-anchored")
					latchSelectionDebugMessage(reclaimAreaOption.name .. " center auto-anchored")
					ControllerCameraTestShowHotkeyFeedback("RECLAIM AREA", "reclaim")
				else
					latchSelectionDebugMessage("Reclaim Area: no valid world target under reticle")
				end
			end
		elseif btn == "Y" then
			if tapCount == 1 then
				if reticleHasWorldTarget and reticleWorldX then
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.PATROL or 15, { reticleWorldX, reticleWorldY, reticleWorldZ }, "Patrol", "point")
					ControllerCameraTestShowHotkeyFeedback("PATROL", "patrol")
				else
					latchSelectionDebugMessage("Patrol: no world target under reticle")
				end
			elseif tapCount == 2 then
				local areaMexOption = {
					name = "Area Mex",
					shortLabel = "Area Mex",
					cmdID = 30100,
					kind = "drag_area",
					dragMode = "areaMex",
					descriptorSource = "template",
					colorProfile = "areaMex",
					iconLabel = "MEX",
					iconSource = "fallback text"
				}
				ControllerCameraTestStageTacticalCommand(areaMexOption)
				ControllerCameraTestShowHotkeyFeedback("AREA MEX", "mex")
			end
		elseif btn == "B" then
			if tapCount == 1 then
				ControllerCameraTestIssueOrderToSelectedUnits(CMD.STOP or 0, {}, "Stop", "units")
				ControllerCameraTestShowHotkeyFeedback("STOP", "utility")
			elseif tapCount == 2 then
				local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
				if #selectedUnits > 0 then
					local firstUnit = selectedUnits[1]
					local states = type(Spring.GetUnitStates) == "function" and Spring.GetUnitStates(firstUnit)
					local currentRepeat = states and states["repeat"]
					local nextVal = currentRepeat and 0 or 1
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.REPEAT or 115, { nextVal }, "Repeat", nextVal == 1 and "ON" or "OFF", {})
					ControllerCameraTestShowHotkeyFeedback("REPEAT", "utility")
				end
			end
		end

	elseif profile == "air_transport" then
		if btn == "X" then
			if tapCount == 1 then
				-- LB + X: Deliberate Load Unit command only.
				local ok, targetType, targetID = pcall(spTraceScreenRay, screenCenterX, screenCenterY)
				if ok and targetType == "unit" and targetID then
					local targetUnitID = tonumber(targetID)
					if ControllerCameraTestIsAlliedUnit(targetUnitID) and not IsUnitInSelection(targetUnitID) then
						local loadCmdID = (CMD and CMD.LOAD_UNITS) or 75
						local loadParams = { targetUnitID }
						ControllerCameraTestIssueOrderToSelectedUnits(loadCmdID, loadParams, "Load Unit", "unit")
						ControllerCameraTestShowHotkeyFeedback("LOAD UNIT", "utility")
					else
						ControllerCameraTestShowHotkeyFeedback("NO LOAD TARGET", "utility")
					end
				else
					ControllerCameraTestShowHotkeyFeedback("NO LOAD TARGET", "utility")
				end
			end
		elseif btn == "A" then
			if tapCount == 1 then
				-- LB + A: Unload carried unit at reticle ground point.
				local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
				if TransportsHaveCargo(selectedUnits) then
					if reticleHasWorldTarget and reticleWorldX then
						local unloadCmdID = GetTransportUnloadCommand(selectedUnits) or (CMD and CMD.UNLOAD_UNITS) or 80
						local unloadParams
						if unloadCmdID == 81 then -- CMD.UNLOAD_UNIT
							unloadParams = { reticleWorldX, reticleWorldY, reticleWorldZ }
						else -- CMD.UNLOAD_UNITS
							unloadParams = { reticleWorldX, reticleWorldY, reticleWorldZ, 0 }
						end
						ControllerCameraTestIssueOrderToSelectedUnits(unloadCmdID, unloadParams, "Unload Point", "point")
						ControllerCameraTestShowHotkeyFeedback("UNLOAD", "utility")
					else
						ControllerCameraTestShowHotkeyFeedback("NO UNLOAD", "utility")
					end
				else
					ControllerCameraTestShowHotkeyFeedback("NO CARGO", "utility")
				end
			end
		elseif btn == "B" then
			if tapCount == 1 then
				ControllerCameraTestIssueOrderToSelectedUnits(CMD.STOP or 0, {}, "Stop", "units")
				ControllerCameraTestShowHotkeyFeedback("STOP", "utility")
			elseif tapCount == 2 then
				local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
				if #selectedUnits > 0 then
					local firstUnit = selectedUnits[1]
					local states = type(Spring.GetUnitStates) == "function" and Spring.GetUnitStates(firstUnit)
					local currentRepeat = states and states["repeat"]
					local nextVal = currentRepeat and 0 or 1
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.REPEAT or 115, { nextVal }, "Repeat", nextVal == 1 and "ON" or "OFF", {})
					ControllerCameraTestShowHotkeyFeedback("REPEAT", "utility")
				end
			end
		end

	elseif profile == "factory" then
		if btn == "A" or btn == "X" then
			if tapCount == 1 then
				if reticleHasWorldTarget and reticleWorldX then
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.FIGHT or 16, { reticleWorldX, reticleWorldY, reticleWorldZ }, "Fight", "point")
					ControllerCameraTestShowHotkeyFeedback("FIGHT", "attack")
				else
					latchSelectionDebugMessage("Fight: no world target under reticle")
				end
			end
		elseif btn == "Y" then
			if tapCount == 1 then
				if reticleHasWorldTarget and reticleWorldX then
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.PATROL or 15, { reticleWorldX, reticleWorldY, reticleWorldZ }, "Patrol", "point")
					ControllerCameraTestShowHotkeyFeedback("PATROL", "patrol")
				else
					latchSelectionDebugMessage("Patrol: no world target under reticle")
				end
			end
		elseif btn == "B" then
			if tapCount == 1 then
				ControllerCameraTestIssueOrderToSelectedUnits(CMD.STOP or 0, {}, "Stop", "units")
				ControllerCameraTestShowHotkeyFeedback("STOP", "utility")
			elseif tapCount == 2 then
				local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
				if #selectedUnits > 0 then
					local firstUnit = selectedUnits[1]
					local states = type(Spring.GetUnitStates) == "function" and Spring.GetUnitStates(firstUnit)
					local currentRepeat = states and states["repeat"]
					local nextVal = currentRepeat and 0 or 1
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.REPEAT or 115, { nextVal }, "Repeat", nextVal == 1 and "ON" or "OFF", {})
					ControllerCameraTestShowHotkeyFeedback("REPEAT", "utility")
				end
			end
		end

	elseif profile == "combat" then
		if btn == "A" then
			if tapCount == 1 then
				local ok, targetType, targetID = pcall(spTraceScreenRay, screenCenterX, screenCenterY)
				local isEnemyUnit = false
				if ok and targetType == "unit" and targetID then
					local myAllyTeam = type(spGetMyAllyTeamID) == "function" and spGetMyAllyTeamID() or -1
					local unitAllyTeam = type(Spring.GetUnitAllyTeam) == "function" and Spring.GetUnitAllyTeam(targetID) or -2
					if myAllyTeam ~= unitAllyTeam then
						isEnemyUnit = true
					end
				end
				if isEnemyUnit then
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.ATTACK or 20, { targetID }, "Attack", "enemy unit")
					ControllerCameraTestShowHotkeyFeedback("ATTACK", "attack")
				elseif reticleHasWorldTarget and reticleWorldX then
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.FIGHT or 16, { reticleWorldX, reticleWorldY, reticleWorldZ }, "Fight", "point")
					ControllerCameraTestShowHotkeyFeedback("FIGHT", "attack")
				else
					latchSelectionDebugMessage("Attack/Fight: no target under reticle")
				end
			end
		elseif btn == "X" then
			if tapCount == 1 then
				local ok, targetType, targetID = pcall(spTraceScreenRay, screenCenterX, screenCenterY)
				local isEnemyUnit = false
				if ok and targetType == "unit" and targetID then
					local myAllyTeam = type(spGetMyAllyTeamID) == "function" and spGetMyAllyTeamID() or -1
					local unitAllyTeam = type(Spring.GetUnitAllyTeam) == "function" and Spring.GetUnitAllyTeam(targetID) or -2
					if myAllyTeam ~= unitAllyTeam then
						isEnemyUnit = true
					end
				end
				if isEnemyUnit then
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.ATTACK or 20, { targetID }, "Attack", "enemy unit")
					ControllerCameraTestShowHotkeyFeedback("ATTACK", "attack")
				elseif reticleHasWorldTarget and reticleWorldX then
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.ATTACK or 20, { reticleWorldX, reticleWorldY, reticleWorldZ }, "Attack", "ground")
					ControllerCameraTestShowHotkeyFeedback("ATTACK GROUND", "attack")
				else
					latchSelectionDebugMessage("Attack: no target/ground under reticle")
				end
			end
		elseif btn == "Y" then
			if tapCount == 1 then
				if reticleHasWorldTarget and reticleWorldX then
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.PATROL or 15, { reticleWorldX, reticleWorldY, reticleWorldZ }, "Patrol", "point")
					ControllerCameraTestShowHotkeyFeedback("PATROL", "patrol")
				else
					latchSelectionDebugMessage("Patrol: no world target under reticle")
				end
			end
		elseif btn == "B" then
			if tapCount == 1 then
				ControllerCameraTestIssueOrderToSelectedUnits(CMD.STOP or 0, {}, "Stop", "units")
				ControllerCameraTestShowHotkeyFeedback("STOP", "utility")
			elseif tapCount == 2 then
				local selectedUnits = type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {}
				if #selectedUnits > 0 then
					local firstUnit = selectedUnits[1]
					local states = type(Spring.GetUnitStates) == "function" and Spring.GetUnitStates(firstUnit)
					local currentRepeat = states and states["repeat"]
					local nextVal = currentRepeat and 0 or 1
					ControllerCameraTestIssueOrderToSelectedUnits(CMD.REPEAT or 115, { nextVal }, "Repeat", nextVal == 1 and "ON" or "OFF", {})
					ControllerCameraTestShowHotkeyFeedback("REPEAT", "utility")
				end
			end
		end
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
		ControllerCameraTestConsumeLBCycle("idle type previous")
		ControllerCameraTestCycleIdleUnitType(-1)
	elseif ControllerCameraTestActionDown("pitchModifier") and ControllerCameraTestActionPressed("idleNext") then
		ControllerCameraTestConsumeLBCycle("idle type next")
		ControllerCameraTestCycleIdleUnitType(1)
	elseif WasButtonPressed("dpadUp") then
		ControllerCameraTestHandleBookmarkButton("up")
	elseif ControllerCameraTestActionPressed("selectCommander") then
		if ControllerCameraTestFocusCommander() then
			ControllerCameraTestShowHotkeyFeedback("COMMANDER", "commander")
		end
	elseif ControllerCameraTestActionPressed("idlePrev") then
		ControllerCameraTestCycleIdleUnit(-1)
	elseif ControllerCameraTestActionPressed("idleNext") then
		ControllerCameraTestCycleIdleUnit(1)
	end
	return false
end

function ControllerCameraTestGetModeSummary()
	if ControllerCameraTestDisassemble and ControllerCameraTestDisassemble.active then
		if ControllerCameraTestDisassemble.areaReclaim.active then return "disassemble area reclaim" end
		if ControllerCameraTestDisassemble.markArea.active then return "disassemble area marking" end
		return "disassemble"
	end
	if ControllerCameraTestDisassemble and ControllerCameraTestDisassemble.toggle.charging then return "disassemble charge" end
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

	local speedFactor = (ControllerCameraTestSettings.zoomSpeed or ZOOM_SPEED) / ZOOM_SPEED
	local scale = 1 - (zoomInput * ZOOM_SCALE_SPEED * speedFactor * 3 * (dt or 0))
	cameraState.dist = clamp(cameraState.dist * scale, MIN_SPRING_DISTANCE, maxCameraDistance)
	zoomMethod = "spring dist"
	return true
end

local function applyOverheadZoom(cameraState, zoomInput, dt)
	if type(cameraState.height) ~= "number" then
		return false
	end

	local speedFactor = (ControllerCameraTestSettings.zoomSpeed or ZOOM_SPEED) / ZOOM_SPEED
	local scale = 1 - (zoomInput * ZOOM_SCALE_SPEED * speedFactor * 3 * (dt or 0))
	cameraState.height = clamp(cameraState.height * scale, MIN_OVERHEAD_HEIGHT, maxCameraDistance)
	zoomMethod = "overhead height"
	return true
end

local function applyFallbackHeightZoom(cameraState, zoomInput, dt)
	local mathMax = math.max
	if type(cameraState.py) ~= "number" then
		return false
	end

	cameraState.py = cameraState.py - (zoomInput * (ControllerCameraTestSettings.zoomSpeed * 3) * (dt or 0))

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

local function drawReticleLines(cx, cy, scale)
	scale = scale or 1
	local RETICLE_GAP = 5 * scale
	local RETICLE_LINE_LENGTH = 11 * scale
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
	if not reticleVisible or controllerMouseModeActive then
		return
	end
	local shared = WG and WG.ControllerUISettings
	local reticleComponent = shared and type(shared.GetComponent) == "function" and shared.GetComponent("reticle") or nil
	if not ControllerCameraTestControllerUIVisible("reticle", false) or (reticleComponent and reticleComponent.enabled == false) then return end

	local reticleScale = ControllerCameraTestGetControllerUIScale("reticle", false)
	local reticleOpacity = ControllerCameraTestGetControllerUIOpacity("reticle")
	local RETICLE_RADIUS = ControllerCameraTestSettings.reticleSize * reticleScale
	local rx, ry = screenCenterX, screenCenterY
	if Spring.GetGameFrame() <= 0 then
		rx, ry = Spring.GetMouseState()
	end

	gl.LineWidth(4)
	gl.Color(0, 0, 0, 0.42 * reticleOpacity)
	drawReticleCircle(rx, ry, RETICLE_RADIUS)
	drawReticleLines(rx, ry, reticleScale)

	gl.LineWidth(2)

	-- Apply colors based on unit alignment
	if reticleTargetAlignment == "enemy" then
		gl.Color(1.0, 0.2, 0.2, 0.9 * reticleOpacity) -- Red for Enemies
	elseif reticleTargetAlignment == "ally" then
		gl.Color(0.2, 1.0, 0.2, 0.9 * reticleOpacity) -- Green for Allies & Self
	else
		gl.Color(0.65, 0.92, 1.0, 0.78 * reticleOpacity) -- Default Blue/White for Ground
	end

	drawReticleCircle(rx, ry, RETICLE_RADIUS)
	drawReticleLines(rx, ry, reticleScale)

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function widget:Initialize()
	-- Debug visibility is a fresh-session concern, never a persisted preference.
	ControllerCameraTestSettings.debugPanelVisible = false
	local nativeApiAvailable = type(spGetAvailableControllers) == "function"
		and type(spGetControllerState) == "function"
	if nativeApiAvailable then
		apiAvailable = true
		ControllerCameraTestInputBackend = "native Spring controller API"
		ControllerCameraTestBridgeStatus = "native backend preferred"
	else
		local includeOk, bridgeModule = pcall(
			VFS.Include,
			LUAUI_DIRNAME .. "Widgets/controller_socket_bridge.lua"
		)
		if includeOk and type(bridgeModule) == "table" and type(bridgeModule.New) == "function" then
			ControllerCameraTestSocketBridge = bridgeModule.New()
			local bridgeOk, bridgeError = ControllerCameraTestSocketBridge:Initialize()
			if bridgeOk then
				spGetAvailableControllers = function()
					return ControllerCameraTestSocketBridge:GetAvailableControllers()
				end
				spGetControllerState = function(instanceID)
					return ControllerCameraTestSocketBridge:GetControllerState(instanceID)
				end
				apiAvailable = true
				ControllerCameraTestInputBackend = "companion UDP bridge"
				ControllerCameraTestBridgeStatus = ControllerCameraTestSocketBridge:GetStatus()
			else
				apiAvailable = false
				ControllerCameraTestInputBackend = "companion UDP bridge unavailable"
				ControllerCameraTestBridgeStatus = tostring(bridgeError or ControllerCameraTestSocketBridge:GetStatus())
			end
		else
			apiAvailable = false
			ControllerCameraTestInputBackend = "companion UDP bridge unavailable"
			ControllerCameraTestBridgeStatus = includeOk and "invalid bridge module" or tostring(bridgeModule)
		end
	end
	ControllerCameraTestEnsureBindings()
	ControllerCameraTestInstallWGAPI()
	ControllerCameraTestVisibleSelection.currentSelection = ControllerCameraTestSafeSelectionSnapshot(
		type(spGetSelectedUnits) == "function" and spGetSelectedUnits() or {})
	updateScreenCenter(spGetViewGeometry())
	ensureDebugPanelInitialized()
	ControllerCameraTestShowHotkeyFeedback("HOTKEY UI READY", "utility")
end

function widget:Shutdown()
	if ControllerCameraTestSocketBridge then
		ControllerCameraTestSocketBridge:Shutdown()
	end
	ControllerCameraTestRemoveWGAPI()
	ControllerCameraTestClearDragPreviewCache()
	if ControllerCameraTestExitDgunMode then
		ControllerCameraTestExitDgunMode("widget shutdown")
	end
	if WG.buildmenu and type(WG.buildmenu.setControllerCompactScale) == "function" then
		pcall(WG.buildmenu.setControllerCompactScale, false, 1.0)
	end
end

function ControllerCameraTestUpdateCompanionFeedback()
	local feedback = ControllerCameraTestCompanionFeedback
	if ControllerCameraTestInputBackend ~= "companion UDP bridge"
		and ControllerCameraTestInputBackend ~= "companion UDP bridge unavailable"
	then
		feedback.wasFresh = nil
		feedback.missingSince = nil
		feedback.missingVisible = false
		feedback.connectedUntil = 0
		return
	end

	local fresh = false
	if ControllerCameraTestSocketBridge
		and type(ControllerCameraTestSocketBridge.IsFresh) == "function"
	then
		local ok, result = pcall(
			ControllerCameraTestSocketBridge.IsFresh,
			ControllerCameraTestSocketBridge
		)
		fresh = ok and result == true
	end

	if fresh then
		if feedback.wasFresh == false then
			feedback.connectedUntil = debugEventTime + 2.5
		end
		feedback.wasFresh = true
		feedback.missingSince = nil
		feedback.missingVisible = false
		return
	end

	if feedback.wasFresh ~= false or feedback.missingSince == nil then
		feedback.missingSince = debugEventTime
	end
	feedback.wasFresh = false
	if (debugEventTime - feedback.missingSince) >= 0.75 then
		feedback.missingVisible = true
	end
end

function widget:ViewResize(vsx, vsy)
	updateScreenCenter(vsx, vsy)
	ensureDebugPanelInitialized()
end

function ControllerCameraTestBeginControllerUpdate(dt)
	debugEventTime = debugEventTime + (dt or 0)
	if ControllerCameraTestSocketBridge then
		ControllerCameraTestSocketBridge:Update(dt)
		ControllerCameraTestBridgeStatus = ControllerCameraTestSocketBridge:GetStatus()
	end
	ControllerCameraTestUpdateCompanionFeedback()
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
	pregameRawRightX = normalizeAxis(GetNamedAxis(state, "rightStickX"))
	pregameRawRightY = normalizeAxis(GetNamedAxis(state, "rightStickY"))
	if Spring.GetGameFrame() <= 0 or controllerMouseModeActive then
		normalizedRightX = 0
		normalizedRightY = 0
	else
		normalizedRightX = pregameRawRightX
		normalizedRightY = pregameRawRightY
	end
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

	-- TODO: Future modifier button hotkeys request
	-- Add easy modifier + face-button hotkeys for the big frequent commands:
	-- - Reclaim
	-- - Repair
	-- - Patrol
	-- Possibly LB + A/B/X/Y, final mapping TBD.
end

local function ControllerCameraTestPointInRect(x, y, rect)
	return type(rect) == "table"
		and type(rect[1]) == "number" and type(rect[2]) == "number"
		and type(rect[3]) == "number" and type(rect[4]) == "number"
		and x > rect[1] and x < rect[3]
		and y > rect[2] and y < rect[4]
end

local function ControllerCameraTestTryPregamePrimaryAction(mx, my)
	if Spring.GetGameFrame() > 0 then
		return false
	end

	local pregameUI = WG and WG['pregameui']
	if type(pregameUI) ~= "table"
		or type(pregameUI.getPrimaryActionRect) ~= "function"
		or type(pregameUI.activatePrimaryAction) ~= "function"
	then
		return false
	end

	local okRect, rects = pcall(pregameUI.getPrimaryActionRect)
	if not okRect or type(rects) ~= "table" or not ControllerCameraTestPointInRect(mx, my, rects.button) then
		return false
	end

	local okAction, actionHandled, actionName = pcall(pregameUI.activatePrimaryAction)
	if not okAction or not actionHandled then
		return false
	end

	ControllerCameraTestShowHotkeyFeedback(actionName or "CLICK", "utility")
	return true
end

local function ControllerCameraTestTryLuaUIClick(mx, my)
	if type(widgetHandler) ~= "table"
		or type(widgetHandler.MousePress) ~= "function"
		or type(widgetHandler.MouseRelease) ~= "function"
	then
		return false
	end

	local okPress, pressHandled = pcall(widgetHandler.MousePress, widgetHandler, mx, my, 1)
	if not okPress or not pressHandled then
		return false
	end

	pcall(widgetHandler.MouseRelease, widgetHandler, mx, my, 1)
	return true
end

local function ControllerCameraTestTryRmlClick(mx, my)
	if not RmlUi or type(RmlUi.contexts) ~= "function" then
		return false
	end

	local okContexts, contexts = pcall(RmlUi.contexts)
	if not okContexts or type(contexts) ~= "table" then
		return false
	end

	local _, vsy = spGetViewGeometry()
	local rmlY = type(vsy) == "number" and (vsy - my - 1) or my
	for _, ctx in ipairs(contexts) do
		if type(ctx.ProcessMouseMove) == "function" then
			pcall(ctx.ProcessMouseMove, ctx, mx, rmlY, 0)
		end

		local handled = false
		if type(ctx.ProcessMouseButtonDown) == "function" then
			local okDown, rawDown = pcall(ctx.ProcessMouseButtonDown, ctx, 0, 0)
			handled = okDown and rawDown == false
		end
		if type(ctx.ProcessMouseButtonUp) == "function" then
			local okUp, rawUp = pcall(ctx.ProcessMouseButtonUp, ctx, 0, 0)
			handled = handled or (okUp and rawUp == false)
		end
		if handled then
			return true
		end
	end

	return false
end

local function ControllerCameraTestTryPregamePlacement(mx, my)
	if Spring.GetGameFrame() > 0 then
		return false
	end

	if type(Spring.TraceScreenRay) ~= "function" or type(Spring.RequestStartPosition) ~= "function" then
		return false
	end

	local okTrace, traceType, worldPosition = pcall(Spring.TraceScreenRay, mx, my, true, true)
	if okTrace and traceType == "ground" and type(worldPosition) == "table" then
		local wx = tonumber(worldPosition[1])
		local wy = tonumber(worldPosition[2])
		local wz = tonumber(worldPosition[3])
		if wx and wy and wz then
			local okPlacement = pcall(Spring.RequestStartPosition, wx, wy, wz, false)
			if okPlacement then
				ControllerCameraTestShowHotkeyFeedback("PLACE", "utility")
				return true
			end
		end
	end

	return false
end

function ControllerCameraTestUpdateControllerModeAndCommandLayer(dt)
	if Spring.GetGameFrame() <= 0 or controllerMouseModeActive then
		if Spring.GetGameFrame() <= 0 then
			ControllerCameraTestLayerDebug.modeSummary = "pregame"
			activeButtonLayoutSummary = "Pregame: RS cursor | LB+RS rotate/tilt | LB+LT+RS Y zoom | A/X Click/Place"
		else
			ControllerCameraTestLayerDebug.modeSummary = "controller mouse mode"
			activeButtonLayoutSummary = "Mouse Mode: Right Stick cursor, A/X Click"
		end

		if ControllerCameraTestActionPressed("select") or ControllerCameraTestActionPressed("smartAction") then
			local mx, my = Spring.GetMouseState()
			local handled = ControllerCameraTestTryPregamePrimaryAction(mx, my)
			if not handled then
				handled = ControllerCameraTestTryLuaUIClick(mx, my)
				if handled then
					ControllerCameraTestShowHotkeyFeedback("CLICK", "utility")
				end
			end
			if not handled then
				handled = ControllerCameraTestTryRmlClick(mx, my)
				if handled then
					ControllerCameraTestShowHotkeyFeedback("CLICK", "utility")
				end
			end
			if not handled and Spring.GetGameFrame() <= 0 then
				ControllerCameraTestTryPregamePlacement(mx, my)
			end
		end

		ControllerCameraTestUpdateLBTapState()
		ControllerCameraTestUpdateLBFaceButtonDispatcher(dt)
		updateSelectionTestActive()
		return
	end

	if ControllerCameraTestDgunMode.active then
		if ControllerCameraTestHandleDgunModeInput(dt) then
			ControllerCameraTestLayerDebug.modeSummary = "DGUN mode"
			activeButtonLayoutSummary = "DGUN targeting: Right stick aim, RT fire once, B cancel/exit"
			return
		end
	end

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

	if ControllerCameraTestHandleSelfDestructChord() then
		ControllerCameraTestLayerDebug.modeSummary = "self-destruct safety"
		activeButtonLayoutSummary = "Self-destruct: hold Back/View + R3 + L3 (" .. string.format("%.2f", ControllerCameraTestSelfDestruct.holdTime or 0) .. "s)"
		return
	end

	-- Hook DGUN Mode Activation: Back + R3 (but NOT when L3 is also held - that is self-destruct chord)
	if IsButtonDown("back") and WasButtonPressed("rightStickClick") and not IsButtonDown("leftStickClick") then
		local commanderID = GetSelectedCommanderID()
		if commanderID then
			ControllerCameraTestEnterDgunMode(commanderID)
			ControllerCameraTestLayerDebug.modeSummary = "DGUN mode"
			activeButtonLayoutSummary = "DGUN targeting: Right stick aim, RT fire once, B cancel/exit"
			return
		else
			latchSelectionDebugMessage("DGUN mode unavailable: commander not selected")
		end
	end

	ControllerCameraTestUpdateLBTapState()
	local disassembleBusy = ControllerCameraTestUpdateDisassembleController(dt)
	if not disassembleBusy then ControllerCameraTestUpdateLBFaceButtonDispatcher(dt) end
	updateSelectionTestActive()

	if disassembleBusy then
		commandLayerActive = false
		if ControllerCameraTestAreaSelect.pressActive or ControllerCameraTestAreaSelect.active then
			ControllerCameraTestCancelAreaSelect("cancelled by Disassemble Mode")
		end
	elseif ControllerCameraTestHandleStagedTacticalCommandInput() then
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
				if not (ControllerCameraTestActionDown("pitchModifier") and ControllerCameraTestCanUseLBHotkeys()) then
					attemptClearSelection()
				end
			end

			if not areaBusy and not xBusy and ControllerCameraTestActionPressed("buildRadial") then
				if not (ControllerCameraTestActionDown("pitchModifier") and ControllerCameraTestCanUseLBHotkeys()) then
					attemptBuildMenu()
				end
			end
			if not areaBusy and not xBusy then
				ControllerCameraTestHandleNormalUtilityInput()
			end
		end
	end

	ControllerCameraTestLayerDebug.modeSummary = ControllerCameraTestGetModeSummary()
	if ControllerCameraTestDisassemble.active then
		activeButtonLayoutSummary = ControllerCameraTestDisassemble.areaReclaim.active
			and "Disassemble area reclaim: move cursor, A/X confirm, B cancel, LB+B stop"
			or (ControllerCameraTestDisassemble.markArea.active
				and "Disassemble area marking: release A finish, RT additive, B cancel"
				or "Disassemble: A mark, RT+A toggle, LB+A reclaim, hold LB+RB exit")
	elseif ControllerCameraTestDisassemble.toggle.charging then
		activeButtonLayoutSummary = "Hold LB+RB: Disassemble Mode"
	elseif commandLayerActive then
		activeButtonLayoutSummary = ControllerCameraTestTacticalMenu.open and "Tactical: D-pad category, LS choose, A/X confirm, B/Y cancel"
			or XboxController.commandLayoutSummary
	elseif type(ControllerCameraTestTacticalMenu.stagedOption) == "table" then
		activeButtonLayoutSummary = ControllerCameraTestTacticalMenu.repeatPlacementActive
			and "Tactical repeat: move reticle, A place again, release RT clear, B cancel"
			or (ControllerCameraTestIsAreaTacticalOption(ControllerCameraTestTacticalMenu.stagedOption)
				and "Tactical area: A anchor center, move reticle resize, A confirm, B cancel"
				or "Tactical staged: move reticle, A confirm, RT+A repeat, B cancel")
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
	local dgun = ControllerCameraTestDgunMode
	local area = ControllerCameraTestAreaSelect
	local filterRadialOpen = (area and area.active and area.filterRadialOpen)
		or (ControllerCameraTestVisibleSelection.radial and ControllerCameraTestVisibleSelection.radial.open)

	if dgun and dgun.active then
		smooth.panX, smooth.panY, smooth.rotateX, smooth.pitchY, smooth.zoomY = 0, 0, 0, 0, 0
	elseif menuOpen then
		smooth.panX, smooth.panY, smooth.rotateX, smooth.pitchY, smooth.zoomY = 0, 0, 0, 0, 0
	else
		local curve = ControllerCameraTestSettings.stickCurve or 1.175
		if filterRadialOpen then
			smooth.panX = 0
			smooth.panY = 0
		else
			smooth.panX = ControllerCameraTestSmoothAxis(smooth.panX, ControllerCameraTestApplyInputCurve(normalizedLeftX, curve), dt)
			smooth.panY = ControllerCameraTestSmoothAxis(smooth.panY, ControllerCameraTestApplyInputCurve(normalizedLeftY, curve), dt)
		end
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
	local dgunActive = ControllerCameraTestDgunMode.active
	ControllerCameraTestUpdateSmoothedCameraInputs(dt, menuOpen, areaActive)
	local smooth = ControllerCameraTestInputSmoothing
	panActive = (not menuOpen and not dgunActive) and (smooth.panX ~= 0 or smooth.panY ~= 0)
	rightStickYMode = dgunActive and "dgun aim" or (areaActive and "area radius" or (lbCameraModifierActive and "pitch" or "zoom"))
	local zoomInput = (menuOpen or dgunActive) and 0 or smooth.zoomY
	local pitchInput = (menuOpen or dgunActive) and 0 or smooth.pitchY
	local rotationInput = (menuOpen or dgunActive) and 0 or smooth.rotateX
	zoomActive = zoomInput ~= 0
	rotationActive = rotationInput ~= 0
	pitchActive = pitchInput ~= 0

	local boostInput = smooth.leftTrigger or 0
	local panMultiplier = 1 + (((ControllerCameraTestSettings.fastPanMultiplier or 1) - 1) * boostInput)
	-- Slow pan override: toggled by Back during build placement
	if ControllerCameraTestBuildPlacement.active and ControllerCameraTestBuildPlacement.slowPanActive then
		panMultiplier = panMultiplier * 0.3
	end
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

function ControllerCameraTestUpdatePregameCameraControls(dt)
	if Spring.GetGameFrame() > 0
		or ControllerCameraTestSettingsUI.open
		or ControllerCameraTestIsGameplayInputBlocked()
	then
		return false
	end

	local lbHeld = ControllerCameraTestActionDown("pitchModifier")
	lbCameraModifierActive = lbHeld
	if not lbHeld then
		return false
	end

	local curve = ControllerCameraTestSettings.stickCurve or 1.175
	local rotationInput = ControllerCameraTestApplyInputCurve(pregameRawRightX or 0, curve)
	local verticalInput = ControllerCameraTestApplyInputCurve(-(pregameRawRightY or 0), curve)
	local zoomModifierActive = (normalizedLeftTrigger or 0) > 0.35
	local zoomInput = zoomModifierActive and verticalInput or 0
	local pitchInput = zoomModifierActive and 0 or verticalInput
	if zoomModifierActive then
		rotationInput = 0
	end

	panActive = false
	zoomActive = zoomInput ~= 0
	rotationActive = rotationInput ~= 0
	pitchActive = pitchInput ~= 0
	rightStickYMode = zoomModifierActive and "pregame zoom" or "pregame tilt"

	if rotationActive or pitchActive or zoomActive then
		ControllerCameraTestCycleDebug.lbHadPitchMotion = true
		applyCameraInput(0, 0, zoomInput, rotationInput, pitchInput, 1, 1, dt)
	elseif spGetCameraState then
		zoomMethod = "none"
		rotationMethod = "none"
		pitchMethod = "none"
		updateCameraDebug(spGetCameraState())
	end

	return true
end

function ControllerCameraTestCycleMouseModeSpeed()
	ControllerCameraTestMouseModeSpeedPresetIndex = (ControllerCameraTestMouseModeSpeedPresetIndex % #ControllerCameraTestMouseModeSpeedPresets) + 1
	local preset = ControllerCameraTestMouseModeSpeedPresets[ControllerCameraTestMouseModeSpeedPresetIndex]
	ControllerCameraTestShowHotkeyFeedback("MOUSE SPEED " .. preset.label, "utility")
end

function ControllerCameraTestUpdateMouseModeControls(dt)
	local backDown = IsButtonDown("back")
	local startDown = IsButtonDown("start")

	if WasButtonPressed("back") then
		ControllerCameraTestMouseModeBackTapActive = controllerMouseModeActive and not startDown
		ControllerCameraTestMouseModeBackTapTime = 0
		ControllerCameraTestMouseModeBackTapUsedWithStart = startDown
	end

	if backDown and ControllerCameraTestMouseModeBackTapActive then
		ControllerCameraTestMouseModeBackTapTime = ControllerCameraTestMouseModeBackTapTime + dt
		if ControllerCameraTestMouseModeBackTapTime > MOUSE_MODE_BACK_TAP_MAX_TIME then
			ControllerCameraTestMouseModeBackTapActive = false
		end
	end

	if backDown and startDown and not backStartChordLocked then
		ControllerCameraTestMouseModeBackTapActive = false
		ControllerCameraTestMouseModeBackTapUsedWithStart = true
		backStartChordActive = true
		backStartHoldTime = (backStartHoldTime or 0) + dt
		-- UI authoring is intentionally absent from normal controller runtime.
		-- A long Back+Start chord therefore remains the same harmless mouse-mode
		-- chord as a short release instead of opening the disabled authoring widget.
	elseif backStartChordActive and (not backDown or not startDown) then
		-- A release before the named threshold resolves exactly one short chord.
		if not backStartHoldTriggered then
			controllerMouseModeActive = not controllerMouseModeActive
			ControllerCameraTestShowHotkeyFeedback(controllerMouseModeActive and "MOUSE ON" or "MOUSE OFF", "utility")
		end
		backStartChordActive = false
		backStartChordLocked = true
	elseif not backDown and not startDown then
		backStartHoldTime = 0
		backStartHoldTriggered = false
		backStartChordActive = false
		backStartChordLocked = false
	end

	if WasButtonReleased("back") then
		if ControllerCameraTestMouseModeBackTapActive
			and controllerMouseModeActive
			and not ControllerCameraTestMouseModeBackTapUsedWithStart
			and ControllerCameraTestMouseModeBackTapTime <= MOUSE_MODE_BACK_TAP_MAX_TIME
		then
			ControllerCameraTestCycleMouseModeSpeed()
		end
		ControllerCameraTestMouseModeBackTapActive = false
		ControllerCameraTestMouseModeBackTapTime = 0
		ControllerCameraTestMouseModeBackTapUsedWithStart = false
	end
end

function ControllerCameraTestUpdateControllerFrame(dt)
	local state = ControllerCameraTestBeginControllerUpdate(dt)
	if not state then
		return
	end

	ControllerCameraTestUpdateControllerAxesAndButtons(state)
	ControllerCameraTestUpdateMouseModeControls(dt)
	local pregameCameraModifierActive = ControllerCameraTestUpdatePregameCameraControls(dt)

	if (Spring.GetGameFrame() <= 0 or controllerMouseModeActive) and controllerMode and not pregameCameraModifierActive then
		local rxStick = pregameRawRightX or 0
		local ryStick = pregameRawRightY or 0
		if math.abs(rxStick) > 0.1 or math.abs(ryStick) > 0.1 then
			local mouseX, mouseY = Spring.GetMouseState()
			local speedMultiplier = controllerMouseModeActive
				and ControllerCameraTestMouseModeSpeedPresets[ControllerCameraTestMouseModeSpeedPresetIndex].multiplier
				or 1
			local cursorSpeed = CONTROLLER_MOUSE_CURSOR_SPEED * speedMultiplier
			local maxMouseX = controllerMouseModeActive and math.max(0, viewSizeX - 1) or viewSizeX
			local maxMouseY = controllerMouseModeActive and math.max(0, viewSizeY - 1) or viewSizeY
			local newX = clamp(mouseX + rxStick * cursorSpeed, 0, maxMouseX)
			local newY = clamp(mouseY - ryStick * cursorSpeed, 0, maxMouseY)
			if type(spWarpMouse) == "function"
				and (not controllerMouseModeActive or newX ~= mouseX or newY ~= mouseY)
			then
				spWarpMouse(newX, newY)
			end
		end
	end
	ControllerCameraTestUpdateControllerModeAndCommandLayer(dt)
	ControllerCameraTestUpdateQueueFrontDragInsertState()
	if ControllerCameraTestIsGameplayInputBlocked() then
		updateReticleWorldTarget()
		if controllerMode and reticleVisible and type(spWarpMouse) == "function" and Spring.GetGameFrame() > 0 and not controllerMouseModeActive then spWarpMouse(screenCenterX, screenCenterY) end
		return
	end
	if not ControllerCameraTestSettingsUI.open and ControllerCameraTestBuildMenu.open
			and not ControllerCameraTestUsesNativeBARUI() then
		ControllerCameraTestUpdateRadialStickSelection()
	end
	if not ControllerCameraTestSettingsUI.open and ControllerCameraTestTacticalMenu.open
			and not ControllerCameraTestUsesNativeBARUI() then
		ControllerCameraTestUpdateTacticalStickSelection()
	end
	if not pregameCameraModifierActive then
		ControllerCameraTestUpdateCameraControls(dt)
	end
	updateReticleWorldTarget()
	if not ControllerCameraTestSettingsUI.open and ControllerCameraTestDragCommand.active then
		pcall(ControllerCameraTestUpdateDragPreview)
	end
	if controllerMode and reticleVisible and type(spWarpMouse) == "function" and Spring.GetGameFrame() > 0 and not controllerMouseModeActive then spWarpMouse(screenCenterX, screenCenterY) end
end

function ControllerCameraTestUpdateBuildMenuCompact()
	local hasBuildMenu = WG.buildmenu and type(WG.buildmenu.setControllerCompactScale) == "function"
	if not hasBuildMenu then
		return
	end

	local isCompactDesired = (ControllerCameraTestSettings.compactBuildMenuEnabled == true) and (controllerMode == true)
	local targetScale = ControllerCameraTestSettings.compactBuildMenuScale or 0.85

	local desiredEnabled = isCompactDesired
	local desiredScale = isCompactDesired and targetScale or 1.0

	if desiredEnabled ~= lastCompactScaleEnabled or desiredScale ~= lastCompactScaleValue then
		local ok, err = pcall(WG.buildmenu.setControllerCompactScale, desiredEnabled, desiredScale)
		if ok then
			lastCompactScaleEnabled = desiredEnabled
			lastCompactScaleValue = desiredScale
		else
			if ControllerCameraTestSettings.debugPanelVisible then
				Spring.Echo("[Controller Build Menu] Error calling setControllerCompactScale: " .. tostring(err))
			end
		end
	end
end

function ControllerCameraTestUpdateNativeInputMode()
	local state = ControllerCameraTestNativeUI
	local desired = controllerMode == true and ControllerCameraTestUsesNativeBARUI()
	if state.pendingControllerState ~= desired then
		state.pendingControllerState = desired
		state.pendingSince = debugEventTime
	end
	local delay = desired and 0.15 or 0.35
	if state.controllerStable ~= desired and debugEventTime - (state.pendingSince or 0) >= delay then
		state.controllerStable = desired
		if WG.buildmenu and type(WG.buildmenu.controllerSetInputActive) == "function" then
			pcall(WG.buildmenu.controllerSetInputActive, desired)
		end
	end
end

function widget:Update(dt)
	ControllerCameraTestUpdateControllerFrame(dt)
	ControllerCameraTestUpdateNativeInputMode()
	ControllerCameraTestUpdateBuildMenuCompact()
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
	ControllerCameraTestRecordUIToggleAction(tostring(source or "Controller UI") .. " debug panel "
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
	if not ControllerCameraTestSettings.debugPanelVisible or not ControllerCameraTestControllerUIVisible("debug", false) then
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
	if not menu.open or not ControllerCameraTestControllerUIVisible("tacticalRadial", true) then
		return
	end
	if ControllerUISharedRenderers then
		local commands = ControllerCameraTestGetTacticalCommands(false, "draw")
		local category = TacticalCategories.Info(menu.categoryKey or "tactical")
		local categoryColor = TacticalCategories.Colors[category.key] or { 1, 1, 1 }
		local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
		local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
		cx, cy = ControllerCameraTestGetControllerUIPosition("tacticalRadial", cx, cy)
		local minView = math.min(viewSizeX, viewSizeY)
		local radialScale = (ControllerCameraTestSettings.radialScale or 1) * ControllerCameraTestGetControllerUIScale("tacticalRadial", true)
		local radius = math.min(520, math.max(220, minView * 0.28 * radialScale))
		local entries = {}
		for index, command in ipairs(commands) do entries[index] = { label = command.shortLabel or command.name or "Command" } end
		local chips = {}
		for _, direction in ipairs(TacticalCategories.Order) do
			local item = TacticalCategories.ByDirection[direction]
			chips[#chips + 1] = { direction = direction, label = item.shortLabel,
				selected = item.key == category.key, color = TacticalCategories.Colors[item.key] }
		end
		ControllerUISharedRenderers.DrawRadial({
			bounds = { x1 = cx - radius * 1.45, y1 = cy - radius * 1.45, x2 = cx + radius * 1.45, y2 = cy + radius * 1.45 },
			model = { style = "tactical", title = category.label, categoryLabel = category.label, selectedTitle = true,
				description = "Choose a tactical command for the current selection.", footer = "LS choose  A/X confirm  B/Y close",
				detail = "D-pad: Up Utility  |  Down Tactical Actions",
				entries = entries, categoryChips = chips, selectedIndex = menu.selectedIndex, accent = categoryColor,
				fill = TacticalCategories.FillColors[category.key] },
			theme = { backgroundR = 0.02, backgroundG = 0.03, backgroundB = 0.04,
				accentR = categoryColor[1], accentG = categoryColor[2], accentB = categoryColor[3] },
			opacity = ControllerCameraTestGetControllerUIOpacity("tacticalRadial"),
			settings = ControllerCameraTestGetRadialRendererSettings("tacticalRadial"),
		})
		return
	end

	gl.PushMatrix()

	local function DrawTacticalTextBold(text, x, y, size, options)
		size = size * ControllerCameraTestGetControllerUIFontScale("tacticalRadial")
		gl.Text(text, x, y, size, options)
		gl.Text(text, x - 0.5, y, size, options)
		gl.Text(text, x + 0.5, y, size, options)
	end

	menu.drawCount = (menu.drawCount or 0) + 1
	menu.hitboxCount = 0
	local commands = ControllerCameraTestGetTacticalCommands(false, "draw")
	local n = #commands
	local currentCategory = TacticalCategories.Info(menu.categoryKey or "tactical")
	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
	cx, cy = ControllerCameraTestGetControllerUIPosition("tacticalRadial", cx, cy)
	local minView = math.min(viewSizeX, viewSizeY)
	local radialScale = (ControllerCameraTestSettings.radialScale or 1) * ControllerCameraTestGetControllerUIScale("tacticalRadial", true)
	local radius = math.min(520, math.max(220, minView * 0.28 * radialScale))
	local itemW = math.min(260, math.max(130, minView * 0.15 * radialScale))
	local itemH = 54 * radialScale

	local catColor = TacticalCategories.Colors[currentCategory.key] or { 1, 1, 1 }
	local catFill = TacticalCategories.FillColors[currentCategory.key] or { 0, 0, 0, 0.46 }

	gl.Color(catFill[1], catFill[2], catFill[3], catFill[4])
	ControllerCameraTestDrawCircle2D(cx, cy, radius * 1.28, 42)

	-- Center Circle Border
	gl.Color(catColor[1] * 0.5, catColor[2] * 0.5, catColor[3] * 0.5, 0.64)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, 30 do
			local theta = i * (2 * math.pi / 30)
			gl.Vertex(cx + radius * 0.42 * math.cos(theta), cy + radius * 0.42 * math.sin(theta))
		end
	end)

	-- Outer Ring Accent using Active Category Color
	gl.Color(catColor[1], catColor[2], catColor[3], 0.74)
	gl.LineWidth(2.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, 44 do
			local theta = i * (2 * math.pi / 44)
			gl.Vertex(cx + radius * math.cos(theta), cy + radius * math.sin(theta))
		end
	end)

	-- Compact category chips positioned closer to center (0.52 * radius)
	for _, direction in ipairs(TacticalCategories.Order) do
		local category = TacticalCategories.ByDirection[direction]
		local selected = category.key == currentCategory.key
		local cellColor = TacticalCategories.Colors[category.key] or { 1, 1, 1 }
		local dx, dy = 0, 0
		if direction == "up" then
			dy = radius * 0.52
		elseif direction == "down" then
			dy = -radius * 0.52
		end
		local chipW = math.min(180, math.max(120, #category.shortLabel * 11.0 + 24))
		local chipH = 34 * radialScale
		local x = cx + dx
		local y = cy + dy

		if selected then
			gl.Color(cellColor[1] * 0.15, cellColor[2] * 0.15, cellColor[3] * 0.15, 0.88)
			gl.Rect(x - chipW / 2, y - chipH / 2, x + chipW / 2, y + chipH / 2)
			gl.Color(cellColor[1], cellColor[2], cellColor[3], 0.95)
			gl.LineWidth(2.2)
		else
			gl.Color(0.04, 0.05, 0.06, 0.48)
			gl.Rect(x - chipW / 2, y - chipH / 2, x + chipW / 2, y + chipH / 2)
			gl.Color(cellColor[1] * 0.38, cellColor[2] * 0.38, cellColor[3] * 0.38, 0.54)
			gl.LineWidth(1.0)
		end

		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(x - chipW / 2, y - chipH / 2)
			gl.Vertex(x + chipW / 2, y - chipH / 2)
			gl.Vertex(x + chipW / 2, y + chipH / 2)
			gl.Vertex(x - chipW / 2, y + chipH / 2)
		end)

		gl.Color(selected and { 1, 1, 1, 1.0 } or { 0.72, 0.72, 0.72, 0.68 })
		DrawTacticalTextBold(category.shortLabel, x, y - 6, selected and 18 or 14, "oc")
	end

	if n <= 0 then
		gl.Color(catColor[1], catColor[2], catColor[3], 1.0)
		DrawTacticalTextBold(currentCategory.label, cx, cy + 28, 22, "oc")
		gl.Color(1, 1, 1, 0.80)
		DrawTacticalTextBold("No available commands", cx, cy - 2, 16, "oc")
		gl.Color(1, 1, 1, 0.65)
		DrawTacticalTextBold("D-pad Up/Down chooses category  |  B/Y cancel", cx, cy - 28, 13, "oc")
		gl.PopMatrix()
		return
	end

	-- Option rendering inheriting category color theme
	for i, option in ipairs(commands) do
		local angle = ((i - 1) * (2 * math.pi / n)) - (math.pi / 2)
		local x = cx + radius * math.cos(angle)
		local y = cy - radius * math.sin(angle)
		local selected = (i == menu.selectedIndex)
		local label = option.shortLabel or option.name or "Command"

		if selected then
			gl.Color(catColor[1] * 0.8, catColor[2] * 0.8, catColor[3] * 0.8, 0.82)
			gl.Rect(x - itemW / 2, y - itemH / 2, x + itemW / 2, y + itemH / 2)
			gl.Color(catColor[1], catColor[2], catColor[3], 1.0)
			gl.LineWidth(2.5)
		else
			gl.Color(catFill[1] * 0.5, catFill[2] * 0.5, catFill[3] * 0.5, 0.85)
			gl.Rect(x - itemW / 2, y - itemH / 2, x + itemW / 2, y + itemH / 2)
			gl.Color(catColor[1] * 0.45, catColor[2] * 0.45, catColor[3] * 0.45, 0.64)
			gl.LineWidth(1.2)
		end

		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(x - itemW / 2, y - itemH / 2)
			gl.Vertex(x + itemW / 2, y - itemH / 2)
			gl.Vertex(x + itemW / 2, y + itemH / 2)
			gl.Vertex(x - itemW / 2, y + itemH / 2)
		end)

		gl.Color(selected and { 1, 1, 1, 1.0 } or { catColor[1], catColor[2], catColor[3], 0.9 })
		DrawTacticalTextBold(label, x, y - 6, selected and 20 or 16, "oc")
	end

	local current = commands[menu.selectedIndex]
	gl.Color(catFill[1] * 0.7, catFill[2] * 0.7, catFill[3] * 0.7, 0.88)
	ControllerCameraTestDrawCircle2D(cx, cy, radius * 0.42, 30)

	-- Center Circle Border
	gl.Color(catColor[1] * 0.5, catColor[2] * 0.5, catColor[3] * 0.5, 0.64)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, 30 do
			local theta = i * (2 * math.pi / 30)
			gl.Vertex(cx + radius * 0.42 * math.cos(theta), cy + radius * 0.42 * math.sin(theta))
		end
	end)

	gl.Color(catColor[1], catColor[2], catColor[3], 1.0)
	DrawTacticalTextBold(currentCategory.label, cx, cy + 36, 18, "oc")
	gl.Color(1, 1, 1, 1)
	DrawTacticalTextBold(current and current.name or "Tactical", cx, cy + 10, 22, "oc")
	gl.Color(1, 1, 1, 0.85)
	DrawTacticalTextBold("LS choose  A/X confirm  B/Y close", cx, cy - 18, 14, "oc")
	gl.Color(1, 1, 1, 0.70)
	DrawTacticalTextBold("D-pad: Up Utility  |  Down Tactical Actions", cx, cy - 38, 13, "oc")
	if ControllerCameraTestIsQueueModifierActive() then
		gl.Color(0.35, 0.95, 0.65, 1)
		DrawTacticalTextBold("APPEND", cx, cy - 58, 15, "oc")
	end
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)

	gl.PopMatrix()
end

function ControllerCameraTestDrawAreaCommandCenterLabel()
	local drag = ControllerCameraTestDragCommand
	if not drag.active or not drag.startX or not drag.startZ then
		return
	end
	local option = type(drag.option) == "table" and drag.option or nil
	if not option or not ControllerCameraTestIsAreaTacticalOption(option) or type(Spring.WorldToScreenCoords) ~= "function" then
		return
	end

	local ok, sx, sy = pcall(Spring.WorldToScreenCoords, drag.startX, drag.startY or 0, drag.startZ)
	if not ok or type(sx) ~= "number" or type(sy) ~= "number" then
		return
	end

	local profile = ControllerCameraTestGetAreaCommandProfile(option)
	local label = tostring(option.iconLabel or profile.label or "AREA")
	local halfWidth = math.max(30, (#label * 4.8) + 16)
	local halfHeight = 13
	gl.Color(0, 0, 0, 0.58)
	glRect(sx - halfWidth, sy - halfHeight, sx + halfWidth, sy + halfHeight)
	local color = profile.centerColor or profile.color
	gl.Color(color[1], color[2], color[3], color[4] or 0.95)
	glText(label, sx, sy - 5, 13, "oc")
	gl.Color(1, 1, 1, 1)
end

function ControllerCameraTestDrawQueueIndicator()
	if not ControllerCameraTestControllerUIVisible("queueStatus", false) then return end
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
	cx, cy = ControllerCameraTestGetControllerUIPosition("queueStatus", cx, cy)
	local scale = ControllerCameraTestGetControllerUIScale("queueStatus", false)
	local opacity = ControllerCameraTestGetControllerUIOpacity("queueStatus")
	gl.Color(0.02, 0.12, 0.06, 0.74 * opacity)
	gl.Rect(cx - 38 * scale, cy - 10 * scale, cx + 38 * scale, cy + 10 * scale)
	gl.Color(0.35, 1.0, 0.62, 0.95 * opacity)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(cx - 38 * scale, cy - 10 * scale)
		gl.Vertex(cx + 38 * scale, cy - 10 * scale)
		gl.Vertex(cx + 38 * scale, cy + 10 * scale)
		gl.Vertex(cx - 38 * scale, cy + 10 * scale)
	end)
	gl.Color(0.8, 1, 0.86, opacity)
	gl.Text("QUEUE", cx, cy - 5 * scale, 12 * ControllerCameraTestGetControllerUIFontScale("queueStatus"), "oc")
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function ControllerCameraTestDrawFilterRadial()
	local area = ControllerCameraTestAreaSelect
	if not area.active or not ControllerCameraTestControllerUIVisible("selectionRadial", true) then
		return
	end

	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
	cx, cy = ControllerCameraTestGetControllerUIPosition("selectionRadial", cx, cy)
	if area.filterRadialOpen and ControllerUISharedRenderers then
		local labels = { "All Mobile", "Air", "Combat", "Builders" }
		local selectedIndex = 1
		for index, label in ipairs(labels) do if area.highlightedFilter == label then selectedIndex = index end end
		local radius = 130 * ControllerCameraTestGetControllerUIScale("selectionRadial", true)
		ControllerUISharedRenderers.DrawRadial({
			bounds = { x1 = cx - radius * 1.55, y1 = cy - radius * 1.55, x2 = cx + radius * 1.55, y2 = cy + radius * 1.55 },
			model = { style = "selection", title = "SELECT FILTER", description = "Choose the unit role included by the selection brush.", footer = "Release X to set", entries = {
				{ label = labels[1], color = { 0.25, 0.75, 1.0 } }, { label = labels[2], color = { 0.65, 0.45, 1.0 } },
				{ label = labels[3], color = { 1.0, 0.35, 0.2 } }, { label = labels[4], color = { 1.0, 0.85, 0.25 } },
			}, selectedIndex = selectedIndex, accent = { 0.25, 0.75, 1.0 } },
			theme = { backgroundR = 0.02, backgroundG = 0.03, backgroundB = 0.04, accentR = 0.25, accentG = 0.75, accentB = 1.0 },
			opacity = ControllerCameraTestGetControllerUIOpacity("selectionRadial"),
			settings = ControllerCameraTestGetRadialRendererSettings("selectionRadial"),
		})
		return
	end

	if area.filterRadialOpen then
		local radius = 130 * ControllerCameraTestGetControllerUIScale("selectionRadial", true)
		gl.Color(0, 0, 0, 0.6)
		ControllerCameraTestDrawCircle2D(cx, cy, radius * 1.5, 32)

		gl.Color(0.25, 0.75, 1.0, 0.75)
		gl.LineWidth(2.5)
		gl.BeginEnd(GL.LINE_LOOP, function()
			for i = 0, 44 do
				local theta = i * (2 * math.pi / 44)
				gl.Vertex(cx + radius * math.cos(theta), cy + radius * math.sin(theta))
			end
		end)

		gl.Color(0.08, 0.10, 0.13, 0.8)
		ControllerCameraTestDrawCircle2D(cx, cy, radius * 0.48, 30)
		gl.Color(1, 1, 1, 1)
		glText("SELECT FILTER", cx, cy + 8, 12, "oc")
		gl.Color(0.8, 0.8, 0.8, 0.8)
		glText("Release X to set", cx, cy - 8, 9, "oc")

		local options = {
			{ name = "All Mobile", x = cx, y = cy + radius, w = 170, h = 38, fontSize = 15, color = {0.25, 0.75, 1.0} },
			{ name = "Combat", x = cx, y = cy - radius, w = 170, h = 38, fontSize = 15, color = {1.0, 0.35, 0.2} },
			{ name = "Builders", x = cx - radius * 1.08, y = cy, w = 110, h = 30, fontSize = 12, color = {1.0, 0.85, 0.25} },
			{ name = "Air", x = cx + radius * 1.08, y = cy, w = 110, h = 30, fontSize = 12, color = {0.65, 0.45, 1.0} },
		}

		for _, opt in ipairs(options) do
			local selected = (area.highlightedFilter == opt.name)
			if selected then
				gl.Color(opt.color[1], opt.color[2], opt.color[3], 0.85)
				glRect(opt.x - opt.w / 2, opt.y - opt.h / 2, opt.x + opt.w / 2, opt.y + opt.h / 2)
				gl.Color(1, 1, 1, 0.95)
				gl.LineWidth(2.5)
				gl.BeginEnd(GL.LINE_LOOP, function()
					gl.Vertex(opt.x - opt.w / 2, opt.y - opt.h / 2)
					gl.Vertex(opt.x + opt.w / 2, opt.y - opt.h / 2)
					gl.Vertex(opt.x + opt.w / 2, opt.y + opt.h / 2)
					gl.Vertex(opt.x - opt.w / 2, opt.y + opt.h / 2)
				end)
				gl.Color(1, 1, 1, 1)
			else
				gl.Color(opt.color[1] * 0.15, opt.color[2] * 0.15, opt.color[3] * 0.15, 0.58)
				glRect(opt.x - opt.w / 2, opt.y - opt.h / 2, opt.x + opt.w / 2, opt.y + opt.h / 2)
				gl.Color(opt.color[1], opt.color[2], opt.color[3], 0.55)
				gl.LineWidth(1.0)
				gl.BeginEnd(GL.LINE_LOOP, function()
					gl.Vertex(opt.x - opt.w / 2, opt.y - opt.h / 2)
					gl.Vertex(opt.x + opt.w / 2, opt.y - opt.h / 2)
					gl.Vertex(opt.x + opt.w / 2, opt.y + opt.h / 2)
					gl.Vertex(opt.x - opt.w / 2, opt.y + opt.h / 2)
				end)
				gl.Color(opt.color[1] * 0.4 + 0.6, opt.color[2] * 0.4 + 0.6, opt.color[3] * 0.4 + 0.6, 0.8)
			end
			glText(opt.name, opt.x, opt.y - opt.fontSize / 2.5, opt.fontSize, "oc")
		end
	else
		local filterName = area.currentFilter or "All Mobile"
		local color = {0.25, 0.75, 1.0}
		if filterName == "Combat" then color = {1.0, 0.35, 0.2}
		elseif filterName == "Builders" then color = {1.0, 0.85, 0.25}
		elseif filterName == "Air" then color = {0.65, 0.45, 1.0} end

		local labelY = cy + 90
		gl.Color(0, 0, 0, 0.5)
		glRect(cx - 100, labelY - 14, cx + 100, labelY + 14)
		gl.Color(color[1], color[2], color[3], 0.9)
		gl.LineWidth(1.5)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(cx - 100, labelY - 14)
			gl.Vertex(cx + 100, labelY - 14)
			gl.Vertex(cx + 100, labelY + 14)
			gl.Vertex(cx - 100, labelY + 14)
		end)
		glText("BRUSH FILTER: " .. filterName, cx, labelY - 5, 13, "oc")
	end
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end

function ControllerCameraTestDrawVisibleSelectionRadial()
	local radial = ControllerCameraTestVisibleSelection.radial
	if not radial.open or not ControllerUISharedRenderers
			or not ControllerCameraTestControllerUIVisible("visibleSelectionRadial", true) then return end
	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
	cx, cy = ControllerCameraTestGetControllerUIPosition("visibleSelectionRadial", cx, cy)
	local labels = { "Last Selected", "Air", "Combat", "Builders" }
	local selected = radial.candidate or radial.persistedFilter or ControllerCameraTestSettings.visibleSelectionFilter or "Combat"
	local selectedIndex = 3
	for index, label in ipairs(labels) do if selected == label then selectedIndex = index end end
	local radius = 130 * ControllerCameraTestGetControllerUIScale("visibleSelectionRadial", true)
	ControllerUISharedRenderers.DrawRadial({
		bounds = { x1 = cx - radius * 1.55, y1 = cy - radius * 1.55, x2 = cx + radius * 1.55, y2 = cy + radius * 1.55 },
		model = { style = "selection", title = "VISIBLE FILTER", categoryLabel = "VISIBLE SELECTION",
			description = "Choose visible units, or restore the previous selection.", footer = "Release RB to confirm", entries = {
			{ label = labels[1], color = { 0.25, 0.75, 1.0 } }, { label = labels[2], color = { 0.65, 0.45, 1.0 } },
			{ label = labels[3], color = { 1.0, 0.35, 0.2 } }, { label = labels[4], color = { 1.0, 0.85, 0.25 } },
		}, selectedIndex = selectedIndex, accent = { 0.25, 0.75, 1.0 } },
		theme = { backgroundR = 0.02, backgroundG = 0.03, backgroundB = 0.04, accentR = 0.25, accentG = 0.75, accentB = 1.0 },
		opacity = ControllerCameraTestGetControllerUIOpacity("visibleSelectionRadial"),
		settings = ControllerCameraTestGetRadialRendererSettings("visibleSelectionRadial"),
	})
end

function ControllerCameraTestDrawPlacementPatternPopup()
	local popup = ControllerCameraTestPlacementPopup
	if not ControllerCameraTestControllerUIVisible("placementStatus", false) or not popup or (popup.expireTime or 0) <= debugEventTime then
		return
	end
	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
	cx, cy = ControllerCameraTestGetControllerUIPosition("placementStatus", cx, cy)
	local alpha = math.min(1, math.max(0, (popup.expireTime - debugEventTime) * 2))
	local scale = ControllerCameraTestGetControllerUIScale("placementStatus", false)
	local opacity = ControllerCameraTestGetControllerUIOpacity("placementStatus")
	local width = math.max(150, (#tostring(popup.text) * 8) + 28) * scale
	local bottom = math.max(38, cy - 15 * scale)
	gl.Color(0.02, 0.04, 0.06, 0.84 * alpha * opacity)
	gl.Rect(cx - (width / 2), bottom, cx + (width / 2), bottom + 30 * scale)
	gl.Color(0.58, 0.84, 1, 0.88 * alpha * opacity)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(cx - (width / 2), bottom)
		gl.Vertex(cx + (width / 2), bottom)
		gl.Vertex(cx + (width / 2), bottom + 30 * scale)
		gl.Vertex(cx - (width / 2), bottom + 30 * scale)
	end)
	gl.Color(0.92, 0.97, 1, alpha * opacity)
	gl.Text(tostring(popup.text), cx, bottom + 9 * scale, 13 * ControllerCameraTestGetControllerUIFontScale("placementStatus"), "oc")
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
		and (ControllerCameraTestBuildMenu.open or ControllerCameraTestTacticalMenu.open
			or ControllerCameraTestAreaSelect.filterRadialOpen or ControllerCameraTestVisibleSelection.radial.open)
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
	if not ControllerCameraTestControllerUIVisible("selectedStatus", false) then return end
	local status = ControllerCameraTestBuildCompactSelectedStatus()
	if not status then
		return
	end
	local screenWidth = viewSizeX > 0 and viewSizeX or 1280
	local left = math.max(14, screenWidth - 310)
	local right = screenWidth - 16
	local bottom = 50
	local top = status.mode == "factory" and 154 or 124
	local uiScale = ControllerCameraTestGetControllerUIScale("selectedStatus", false)
	local uiOpacity = ControllerCameraTestGetControllerUIOpacity("selectedStatus")
	local uiFontScale = ControllerCameraTestGetControllerUIFontScale("selectedStatus")
	local uiIconScale = ControllerCameraTestGetControllerUIIconScale("selectedStatus")
	local function uiColor(r, g, b, a) gl.Color(r, g, b, (a == nil and 1 or a) * uiOpacity) end
	local uiBounds = ControllerCameraTestGetControllerUIBounds("selectedStatus", 294, status.mode == "factory" and 104 or 74)
	if uiBounds then
		gl.PushMatrix()
		gl.Translate(uiBounds.x1 - left * uiScale, uiBounds.y1 - bottom * uiScale, 0)
		gl.Scale(uiScale, uiScale, 1)
	end
	uiColor(0.02, 0.04, 0.06, 0.82)
	gl.Rect(left, bottom, right, top)
	uiColor(0.56, 0.84, 1, 0.7)
	gl.LineWidth(1)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(left, bottom)
		gl.Vertex(right, bottom)
		gl.Vertex(right, top)
		gl.Vertex(left, top)
	end)
	uiColor(0.82, 0.94, 1, 1)
	gl.Text(status.mode == "factory" and "Factory Status" or "Constructor Status", left + 12, top - 19, 13 * uiFontScale, "o")
	uiColor(1, 1, 1, 0.96)
	gl.Text(tostring(status.name), left + 12, top - 39, 13 * uiFontScale, "o")

	if status.mode == "factory" then
		local currentDefID = status.currentCmdID and -status.currentCmdID or nil
		local currentDef = currentDefID and UnitDefs and UnitDefs[currentDefID] or nil
		local buildText = currentDef and ControllerCameraTestGetReadableUnitName(currentDef) or "Idle"
		if currentDefID then
			gl.Texture("#" .. tostring(currentDefID))
			uiColor(1, 1, 1, 0.92)
			local iconSize = 38 * uiIconScale
			gl.TexRect(left + 12, bottom + 25, left + 12 + iconSize, bottom + 25 + iconSize)
			gl.Texture(false)
		end
		local progressText = status.progress and (" " .. tostring(math.floor(status.progress * 100 + 0.5)) .. "%") or ""
		uiColor(0.92, 0.96, 1, 0.95)
		gl.Text("Building: " .. buildText .. progressText, left + 58, bottom + 52, 11 * uiFontScale, "o")
		gl.Text("Repeat: " .. tostring(status.repeatState) .. "  Queue:", left + 58, bottom + 34, 10 * uiFontScale, "o")
		local iconX = left + 164
		for i = 1, math.min(3, #(status.queueItems or {})) do
			local item = status.queueItems[i]
			gl.Texture("#" .. tostring(item.unitDefID))
			uiColor(1, 1, 1, 0.88)
			local queueIconSize = 26 * uiIconScale
			gl.TexRect(iconX, bottom + 21, iconX + queueIconSize, bottom + 21 + queueIconSize)
			gl.Texture(false)
			uiColor(1, 0.92, 0.42, 1)
			gl.Text("x" .. tostring(item.count), iconX + queueIconSize * 0.5, bottom + 10, 9 * uiFontScale, "oc")
			iconX = iconX + math.max(34, queueIconSize + 8)
		end
		uiColor(0.66, 0.9, 1, 0.95)
		gl.Text("Y: Factory radial", left + 12, bottom + 7, 10 * uiFontScale, "o")
	else
		uiColor(0.92, 0.96, 1, 0.95)
		gl.Text("Action: " .. tostring(status.currentAction or "idle"), left + 12, bottom + 38, 11 * uiFontScale, "o")
		local placementText = ControllerCameraTestBuildPlacement.active
			and ("Pattern: " .. ControllerCameraTestPlacementPatternLabel(ControllerCameraTestBuildPlacement.placementPattern)
				.. "  Space: " .. tostring(ControllerCameraTestBuildPlacement.placementSpacing or 0))
			or "Ready for construction"
		gl.Text(placementText, left + 12, bottom + 23, 11 * uiFontScale, "o")
		uiColor(0.66, 0.9, 1, 0.95)
		gl.Text("Y: Build radial", left + 12, bottom + 7, 10 * uiFontScale, "o")
	end
	gl.Texture(false)
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
	if uiBounds then gl.PopMatrix() end
end

function ControllerCameraTestDrawControlGroupOverlayLegacy()
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

function ControllerCameraTestDrawControlGroupOverlay()
	local groups = ControllerCameraTestControlGroups
	if not ControllerCameraTestControllerUIVisible("hotSlots", false)
		or not (ControllerCameraTestActionDown("controlGroupModifier") or (groups.visibleUntil or 0) > debugEventTime)
	then return end

	local shared = WG and WG.ControllerUISettings
	local component = shared and type(shared.GetComponent) == "function" and shared.GetComponent("hotSlots") or nil
	local backgroundColor = shared and type(shared.GetColor) == "function" and shared.GetColor("background", 1, "hotSlots") or { 0, 0, 0, 1 }
	local accentColor = shared and type(shared.GetColor) == "function" and shared.GetColor("accent", 1, "hotSlots") or { 0.36, 0.68, 1, 1 }
	local foregroundColor = shared and type(shared.GetColor) == "function" and shared.GetColor("foreground", 1, "hotSlots") or { 0.92, 0.96, 1, 1 }
	component = component or { slotSize = 42, slotWidth = 42, slotHeight = 42, slotGap = 5, slotCount = 10,
		orientation = "Horizontal", rows = 1, panelPadding = 12, showLabel = true, headerLabel = "Controller Groups",
		showStatus = true, showCounts = true, showAuto = true, showRole = false, hideEmpty = false,
		selectedBorderThickness = 2.5, emptyOpacity = 0.74, backgroundOpacity = 0.72, iconScale = 1 }
	local slotCount = math.max(1, math.min(10, math.floor(tonumber(component.slotCount) or 10)))
	local baseSlotWidth = tonumber(component.slotWidth) or tonumber(component.slotSize) or 42
	local baseSlotHeight = tonumber(component.slotHeight) or tonumber(component.slotSize) or 42
	local baseGap = tonumber(component.slotGap) or 5
	local padding = tonumber(component.panelPadding) or 12
	local orientation = tostring(component.orientation or "Horizontal")
	local rowCount = orientation == "Vertical" and slotCount or orientation == "Grid" and math.max(1, math.min(slotCount, math.floor(tonumber(component.rows) or 2))) or 1
	local columnCount = math.ceil(slotCount / rowCount)
	local headerHeight, statusHeight = component.showLabel and 24 or 0, component.showStatus and 20 or 0
	local baseWidth = padding * 2 + baseSlotWidth * columnCount + baseGap * math.max(0, columnCount - 1)
	local baseHeight = padding * 2 + baseSlotHeight * rowCount + baseGap * math.max(0, rowCount - 1) + headerHeight + statusHeight
	local bounds = ControllerCameraTestGetControllerUIBounds("hotSlots", baseWidth, baseHeight)
	local scale = bounds and bounds.scale or ControllerCameraTestGetControllerUIScale("hotSlots", false)
	local slotWidth, slotHeight, gap = baseSlotWidth * scale, baseSlotHeight * scale, baseGap * scale
	local stripWidth, stripHeight = baseWidth * scale, baseHeight * scale
	local left = bounds and bounds.x1 or math.max(12, ((viewSizeX > 0 and viewSizeX or 1280) - stripWidth) * 0.5)
	local bottom = bounds and bounds.y1 or 86
	local top = bottom + stripHeight
	local opacity = ControllerCameraTestGetControllerUIOpacity("hotSlots")
	local animationDuration = math.max(0, tonumber(component.animationDuration) or 0)
	if animationDuration > 0 and not ControllerCameraTestActionDown("controlGroupModifier") then
		opacity = opacity * math.max(0, math.min(1, ((groups.visibleUntil or 0) - debugEventTime) / animationDuration))
	end
	local fontScale = ControllerCameraTestGetControllerUIFontScale("hotSlots")
	local iconScale = math.max(0.5, math.min(2, tonumber(component.iconScale) or 1))
	local activeSlot = ControllerCameraTestNormalizeControlGroupSlot(groups.activeSlot or 1)
	local availableSlots = {}
	for slot = 1, 10 do if not component.hideEmpty or groups.slots[slot] or slot == activeSlot then availableSlots[#availableSlots + 1] = slot end end
	local activeIndex = 1
	for index, slot in ipairs(availableSlots) do if slot == activeSlot then activeIndex = index; break end end
	local startIndex = 1
	if component.scrollBehavior ~= "Fixed" then startIndex = math.max(1, math.min(math.max(1, #availableSlots - slotCount + 1), activeIndex - math.floor(slotCount * 0.5))) end
	local displaySlots = {}
	for index = 0, slotCount - 1 do
		local sourceIndex = startIndex + index
		if component.scrollBehavior == "Wrap" and #availableSlots > 0 then sourceIndex = ((sourceIndex - 1) % #availableSlots) + 1 end
		if availableSlots[sourceIndex] then displaySlots[#displaySlots + 1] = availableSlots[sourceIndex] end
	end
	if ControllerUISharedRenderers then
		local modelSlots, selectedIndex = {}, 1
		for visibleIndex, slot in ipairs(displaySlots) do
			local entry = groups.slots[slot]
			if slot == activeSlot then selectedIndex = visibleIndex end
			modelSlots[visibleIndex] = {
				label = ControllerCameraTestGetControlGroupDisplaySlot(slot), count = entry and entry.count or 0,
				empty = entry == nil, selected = slot == activeSlot,
				recent = tostring(groups.lastSlot) == ControllerCameraTestGetControlGroupDisplaySlot(slot),
				auto = entry and entry.autoAddUnitDefID ~= nil,
				role = entry and tostring(entry.typeName or "assigned") or nil,
				texture = entry and entry.unitDefID and ("#" .. tostring(entry.unitDefID)) or nil,
			}
		end
		ControllerUISharedRenderers.DrawHotSlots({
			bounds = { x1 = left, y1 = bottom, x2 = left + stripWidth, y2 = top }, settings = component,
			theme = { backgroundR = backgroundColor[1], backgroundG = backgroundColor[2], backgroundB = backgroundColor[3],
				foregroundR = foregroundColor[1], foregroundG = foregroundColor[2], foregroundB = foregroundColor[3],
				accentR = accentColor[1], accentG = accentColor[2], accentB = accentColor[3] },
			model = { slots = modelSlots, selectedIndex = selectedIndex,
				status = "Group " .. ControllerCameraTestGetControlGroupDisplaySlot(activeSlot) .. ": " .. tostring(groups.lastAction) },
			opacity = opacity, scale = scale, fontScale = fontScale,
		})
		return
	end

	gl.Color(backgroundColor[1], backgroundColor[2], backgroundColor[3], (tonumber(component.backgroundOpacity) or 0.72) * opacity)
	gl.Rect(left, bottom, left + stripWidth, top)
	gl.Color(accentColor[1], accentColor[2], accentColor[3], 0.65 * opacity); gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(left, bottom); gl.Vertex(left + stripWidth, bottom); gl.Vertex(left + stripWidth, top); gl.Vertex(left, top)
	end)

	if component.showLabel then
		gl.Color(foregroundColor[1], foregroundColor[2], foregroundColor[3], opacity)
		gl.Text(tostring(component.headerLabel or "Controller Groups"), left + padding * scale, top - 17 * scale, 11 * fontScale, "o")
	end

	for visibleIndex, slot in ipairs(displaySlots) do
		local gridIndex = visibleIndex - 1
		local column = gridIndex % columnCount
		local row = math.floor(gridIndex / columnCount)
		local x1 = left + padding * scale + column * (slotWidth + gap)
		local y1 = bottom + (padding + statusHeight) * scale + (rowCount - row - 1) * (slotHeight + gap)
		local x2, y2 = x1 + slotWidth, y1 + slotHeight
		local entry = groups.slots[slot]
		local isActive = slot == activeSlot
		local isRecent = tostring(groups.lastSlot) == ControllerCameraTestGetControlGroupDisplaySlot(slot)
		if isActive then gl.Color(0.18, 0.42, 0.78, 0.88 * opacity)
		elseif entry then gl.Color(0.10, 0.18, 0.24, 0.82 * opacity)
		else gl.Color(0.05, 0.07, 0.09, (tonumber(component.emptyOpacity) or 0.74) * opacity) end
		gl.Rect(x1, y1, x2, y2)
		if entry and entry.unitDefID then
			local shortSide = math.min(slotWidth, slotHeight)
			local inset = math.max(3 * scale, (shortSide - shortSide * math.min(0.92, iconScale * 0.72)) * 0.5)
			gl.Texture("#" .. tostring(entry.unitDefID)); gl.Color(1, 1, 1, (isActive and 0.95 or 0.75) * opacity)
			gl.TexRect(x1 + inset, y1 + inset, x2 - inset, y2 - inset); gl.Texture(false)
		end
		gl.Color(isActive and 1 or 0.55, isActive and 0.92 or 0.72, isActive and 0.35 or 0.82, opacity)
		gl.LineWidth((isActive or isRecent) and (tonumber(component.selectedBorderThickness) or 2.5) or 1)
		gl.BeginEnd(GL.LINE_LOOP, function() gl.Vertex(x1, y1); gl.Vertex(x2, y1); gl.Vertex(x2, y2); gl.Vertex(x1, y2) end)
		gl.Color(1, 1, 1, opacity); gl.Text(ControllerCameraTestGetControlGroupDisplaySlot(slot), x1 + 4 * scale, y2 - 13 * scale, 10 * fontScale, "o")
		if component.showCounts and entry and (entry.count or 0) > 0 then
			gl.Color(1, 0.92, 0.42, opacity); gl.Text("x" .. tostring(entry.count), x2 - 4 * scale, y1 + 3 * scale, 9 * fontScale, "ro")
			if component.showAuto and entry.autoAddUnitDefID then gl.Color(0.52, 1, 0.66, 0.95 * opacity); gl.Text("AUTO", x1 + 4 * scale, y1 + 3 * scale, 7 * fontScale, "o") end
		end
		if component.showRole and entry then
			gl.Color(0.76, 0.9, 1, 0.9 * opacity)
			local role = tostring(entry.typeName or "assigned")
			if #role > 12 then role = string.sub(role, 1, 11) .. "." end
			gl.Text(role, (x1 + x2) * 0.5, y1 + 3 * scale, 7 * fontScale, "oc")
		end
	end

	if component.showStatus then
		gl.Color(foregroundColor[1], foregroundColor[2], foregroundColor[3], opacity)
		gl.Text("Group " .. ControllerCameraTestGetControlGroupDisplaySlot(activeSlot) .. ": " .. tostring(groups.lastAction),
			left + padding * scale, bottom + 5 * scale, 10 * fontScale, "o")
	end
	gl.Texture(false); gl.LineWidth(1); gl.Color(1, 1, 1, 1)
end

function ControllerCameraTestCleanRadialDescription(text)
	text = tostring(text or "")
	text = string.gsub(text, "\255...", "")
	text = string.gsub(text, "[\r\n]+", " ")
	text = string.gsub(text, "%s+", " ")
	return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

function ControllerCameraTestMeasureRadialText(text, fontSize)
	if gl.GetTextWidth then
		local ok, width = pcall(gl.GetTextWidth, tostring(text or ""))
		if ok and type(width) == "number" then
			return width * fontSize
		end
	end
	return #tostring(text or "") * fontSize * 0.55
end

function ControllerCameraTestWrapRadialText(text, maxWidth, fontSize, maxLines)
	local lines = {}
	local currentLine = ""
	text = ControllerCameraTestCleanRadialDescription(text)
	for word in string.gmatch(text, "%S+") do
		local candidate = currentLine == "" and word or (currentLine .. " " .. word)
		if currentLine ~= "" and ControllerCameraTestMeasureRadialText(candidate, fontSize) > maxWidth then
			lines[#lines + 1] = currentLine
			currentLine = word
			if #lines >= maxLines then
				break
			end
		else
			currentLine = candidate
		end
	end
	if #lines < maxLines and currentLine ~= "" then
		lines[#lines + 1] = currentLine
	end
	if #lines == maxLines and text ~= table.concat(lines, " ") then
		local lastLine = lines[#lines]
		while lastLine ~= "" and ControllerCameraTestMeasureRadialText(lastLine .. "...", fontSize) > maxWidth do
			lastLine = string.gsub(lastLine, "%s+%S+$", "")
			if not string.find(lastLine, "%s") then
				break
			end
		end
		lines[#lines] = lastLine .. "..."
	end
	return lines
end

function ControllerCameraTestFormatRadialStatNumber(value)
	value = tonumber(value)
	if not value then
		return nil
	end
	if math.abs(value) >= 100 or math.abs(value - math.floor(value + 0.5)) < 0.05 then
		return string.format("%.0f", value)
	end
	return string.format("%.1f", value)
end

function ControllerCameraTestGetRadialWeaponStats(unitDef)
	local primaryDPS = nil
	local primaryReload = nil
	local maxRange = nil
	if not unitDef or type(unitDef.weapons) ~= "table" or not WeaponDefs then
		return primaryDPS, maxRange, primaryReload
	end

	local armorTypes = Game and Game.armorTypes or {}
	local defaultArmorIndex = armorTypes and (armorTypes["default"] or 0) or 0
	local airArmorIndex = armorTypes and armorTypes["vtol"] or nil
	for _, weapon in ipairs(unitDef.weapons) do
		local weaponDef = weapon and weapon.weaponDef and WeaponDefs[weapon.weaponDef]
		local customParams = weaponDef and weaponDef.customParams or {}
		if weaponDef and customParams.bogus ~= "1" then
			local range = tonumber(weaponDef.range)
			if range and range > 0 and (not maxRange or range > maxRange) then
				maxRange = range
			end
			if not primaryDPS and not weaponDef.paralyzer and weaponDef.damages then
				local defaultDamage = tonumber(weaponDef.damages[defaultArmorIndex]) or 0
				local airDamage = airArmorIndex and tonumber(weaponDef.damages[airArmorIndex]) or 0
				local damage = math.max(defaultDamage, airDamage)
				local reload = weaponDef.stockpile and tonumber(weaponDef.stockpileTime) and (weaponDef.stockpileTime / 30)
					or tonumber(weaponDef.reload)
				if damage > 0 and reload and reload > 0 then
					local salvoSize = tonumber(weaponDef.salvoSize) or 1
					local projectiles = tonumber(weaponDef.projectiles) or 1
					primaryDPS = damage * salvoSize * projectiles / reload
					primaryReload = reload
				end
			end
		end
	end
	return primaryDPS, maxRange, primaryReload
end

function ControllerCameraTestBuildRadialUnitInfo(option)
	if not option then
		return nil
	end
	local unitDef = option.unitDefID and UnitDefs and UnitDefs[option.unitDefID]
	local info = {
		title = option.name or "Unknown unit",
		description = ControllerCameraTestCleanRadialDescription(option.tooltip),
		stats = {},
		availabilityText = ControllerCameraTestGetBuildAvailability(option),
	}
	if unitDef then
		info.title = unitDef.translatedHumanName or unitDef.humanName or unitDef.name or info.title
		info.description = ControllerCameraTestCleanRadialDescription(
			unitDef.translatedTooltip or unitDef.tooltip or unitDef.description or option.tooltip
		)
	end

	local metalCost = unitDef and unitDef.metalCost or option.metalCost
	local energyCost = unitDef and unitDef.energyCost or option.energyCost
	info.metalCost = type(metalCost) == "number" and ControllerCameraTestFormatRadialStatNumber(metalCost) or nil
	info.energyCost = type(energyCost) == "number" and ControllerCameraTestFormatRadialStatNumber(energyCost) or nil

	if unitDef then
		if type(unitDef.health) == "number" then
			info.healthStat = ControllerCameraTestFormatRadialStatNumber(unitDef.health)
		end
		local dps, range, reload = ControllerCameraTestGetRadialWeaponStats(unitDef)
		if dps then
			info.stats[#info.stats + 1] = "DPS  " .. ControllerCameraTestFormatRadialStatNumber(dps)
		end
		if range then
			info.stats[#info.stats + 1] = "Range  " .. ControllerCameraTestFormatRadialStatNumber(range)
		end
		local sight = type(unitDef.sightDistance) == "number" and unitDef.sightDistance or nil
		local airSight = type(unitDef.airSightDistance) == "number" and unitDef.airSightDistance or nil
		if sight or airSight then
			info.stats[#info.stats + 1] = "LOS/Air  "
				.. (sight and ControllerCameraTestFormatRadialStatNumber(sight) or "-")
				.. " / "
				.. (airSight and ControllerCameraTestFormatRadialStatNumber(airSight) or "-")
		end
		if reload then
			info.stats[#info.stats + 1] = "Reload  " .. ControllerCameraTestFormatRadialStatNumber(reload) .. "s"
		end
		if type(unitDef.speed) == "number" then
			info.stats[#info.stats + 1] = "Speed  " .. ControllerCameraTestFormatRadialStatNumber(unitDef.speed)
		end
	end
	return info
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
	local componentName = isFactoryContext and "factoryRadial" or "buildRadial"
	if not ControllerCameraTestControllerUIVisible(componentName, true) then return end

	if isFactoryContext then
		ControllerCameraTestRefreshFactoryQueueProgress()
	end

	local cx = screenCenterX > 0 and screenCenterX or (viewSizeX / 2)
	local cy = screenCenterY > 0 and screenCenterY or (viewSizeY / 2)
	cx, cy = ControllerCameraTestGetControllerUIPosition(componentName, cx, cy)

	local minView = math.min(viewSizeX, viewSizeY)
	local radialScale = (ControllerCameraTestSettings.radialScale or 1) * ControllerCameraTestGetControllerUIScale(componentName, true)
	local scaleFactor = BuildRadialTuning.radialScale
	local radius = math.min(1000, math.max(200, minView * 0.28 * radialScale * scaleFactor))

	local visibleOptions = menu.radialVisibleOptions or {}
	local n = #visibleOptions

	-- Resolve page/category color
	local catKey = string.lower(menu.radialCategoryName or "economy")
	local pageColor = BuildRadialPageColors[catKey] or BuildRadialPageColors.economy
	if ControllerUISharedRenderers then
		local entries, selectedIndex = {}, 1
		for index, option in ipairs(visibleOptions) do
			if option.menuIndex == menu.selectedIndex then selectedIndex = index end
			local progress = isFactoryContext and option.cmdID and menu.factoryQueueProgress and menu.factoryQueueProgress[option.cmdID]
			local queueCount = isFactoryContext and option.cmdID and menu.factoryQueueCounts and menu.factoryQueueCounts[option.cmdID] or 0
			entries[index] = { label = option.shortLabel or option.name or "Build", texture = option.iconTexture,
				disabled = option.disabled == true, unavailableText = option.disabled and ControllerCameraTestGetBuildAvailability(option) or nil,
				progress = progress, badge = queueCount, indexLabel = index }
		end
		local current = visibleOptions[selectedIndex]
		local info = current and ControllerCameraTestBuildRadialUnitInfo(current)
		local renderSettings = ControllerCameraTestGetRadialRendererSettings(componentName)
		renderSettings.iconScale = renderSettings.iconScale * (BuildRadialTuning.iconScale or 1)
		renderSettings.fontScale = renderSettings.fontScale * (BuildRadialTuning.textScale or 1)
		renderSettings.selectedBorderThickness = renderSettings.selectedBorderThickness * (BuildRadialTuning.selectedBorderScale or 1)
		renderSettings.itemSpacing = renderSettings.itemSpacing * (BuildRadialTuning.itemSpacing or 1)
		ControllerUISharedRenderers.DrawRadial({
			bounds = { x1 = cx - radius * 1.45, y1 = cy - radius * 1.45, x2 = cx + radius * 1.45, y2 = cy + radius * 1.45 },
			model = { style = "build", title = info and info.title or (current and (current.name or current.shortLabel)) or (isFactoryContext and "Factory" or "Build"), selectedTitle = isFactoryContext,
				description = info and info.description or "", metalCost = info and info.metalCost, energyCost = info and info.energyCost,
				healthStat = info and info.healthStat, availabilityText = info and info.availabilityText,
				metadata = info and info.stats or {},
				categoryLabel = menu.radialCategoryName or (isFactoryContext and "Factory" or "Build"),
				pageLabel = "PAGE " .. tostring(menu.radialPage or 1) .. "/" .. tostring(menu.radialPageCount or 1),
				entries = entries, selectedIndex = selectedIndex, accent = pageColor.accent, fill = pageColor.fill },
			theme = { backgroundR = pageColor.fill[1], backgroundG = pageColor.fill[2], backgroundB = pageColor.fill[3],
				accentR = pageColor.accent[1], accentG = pageColor.accent[2], accentB = pageColor.accent[3] },
			opacity = ControllerCameraTestGetControllerUIOpacity(componentName),
			settings = renderSettings,
		})
		return
	end

	-- 1. Translucent backdrop (large colored circle around the reticle)
	local fillR = pageColor.fill[1]
	local fillG = pageColor.fill[2]
	local fillB = pageColor.fill[3]
	local fillA = BuildRadialTuning.fillAlpha
	gl.Color(fillR, fillG, fillB, fillA)

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
	gl.Color(pageColor.accent[1], pageColor.accent[2], pageColor.accent[3], 0.3)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, 36 do
			local theta = i * (2 * math.pi / 36)
			gl.Vertex(cx + radius * math.cos(theta), cy + radius * math.sin(theta))
		end
	end)

	-- 2. Draw each item
	local iconSize = math.min(500, math.max(56, minView * 0.075 * radialScale * BuildRadialTuning.iconScale))
	for i = 1, n do
		local option = visibleOptions[i]
		local angle = ((i - 1) * (2 * math.pi / n)) - (math.pi / 2)
		local x = cx + radius * BuildRadialTuning.itemSpacing * math.cos(angle)
		local y = cy - radius * BuildRadialTuning.itemSpacing * math.sin(angle)

		local isSelected = (option.menuIndex == menu.selectedIndex)

		-- Check affordability (cached; refreshes every 10s or immediately on page change)
		local affordable, mAff, eAff = ControllerCameraTestGetCachedAffordability(option)

		if isSelected then
			gl.Color(pageColor.accent[1], pageColor.accent[2], pageColor.accent[3], 0.85)
			local borderW = iconSize/2 + 4 * BuildRadialTuning.selectedBorderScale
			gl.Rect(x - borderW, y - borderW, x + borderW, y + borderW)
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

		gl.LineWidth(isSelected and (3 * BuildRadialTuning.selectedBorderScale) or 1.5)
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
					gl.Color(0.75, 0.72, 0.72, 0.85) -- softly dimmed for unaffordable (75% brightness)
				end
				gl.TexRect(x - iconSize/2, y - iconSize/2, x + iconSize/2, y + iconSize/2)
			end
			gl.Texture(false)
			hasIcon = true
		end

		if not hasIcon then
			gl.Color(1, 1, 1, 1)
			gl.Text(string.sub(option.name, 1, 4), x, y - 6 * BuildRadialTuning.textScale, 12 * BuildRadialTuning.textScale, "oc")
		end

		gl.Color(1, 0.84, 0, 1)
		gl.Text(tostring(i), x - iconSize/2 + 6, y + iconSize/2 - 16 * BuildRadialTuning.textScale, 12 * BuildRadialTuning.textScale, "o")

		-- Draw Factory Queue badge if needed
		if isFactoryContext and option.cmdID and menu.factoryQueueCounts then
			local qCount = menu.factoryQueueCounts[option.cmdID] or 0
			if qCount > 0 then
				local badgeText = "x" .. tostring(qCount)
				local badgeW = 28 * BuildRadialTuning.textScale
				if qCount >= 10 then
					badgeW = 36 * BuildRadialTuning.textScale
				end
				if qCount >= 100 then
					badgeW = 44 * BuildRadialTuning.textScale
				end
				local bx2 = x + iconSize/2 + 3
				local bx1 = bx2 - badgeW
				local by2 = y + iconSize/2 + 3
				local by1 = by2 - 18 * BuildRadialTuning.textScale

				-- Translucent dark glassmorphism badge
				gl.Color(0.04, 0.08, 0.12, 0.88)
				gl.Rect(bx1, by1, bx2, by2)
				gl.Color(pageColor.accent[1], pageColor.accent[2], pageColor.accent[3], 0.7)
				gl.LineWidth(1)
				gl.BeginEnd(GL.LINE_LOOP, function()
					gl.Vertex(bx1, by1)
					gl.Vertex(bx2, by1)
					gl.Vertex(bx2, by2)
					gl.Vertex(bx1, by2)
				end)

				gl.Color(1, 0.95, 0.8, 1)
				gl.Text(badgeText, (bx1 + bx2)/2, by1 + 3 * BuildRadialTuning.textScale, 11 * BuildRadialTuning.textScale, "oc")
			end
		end
	end

	-- 3. Center display details
	local currentOption = ControllerCameraTestGetRadialCurrentOption()
	if currentOption then
		local info = ControllerCameraTestBuildRadialUnitInfo(currentOption)
		local panelRadius = math.max(105, math.min(radius * 0.56, radius - iconSize * 0.6))
		local panelTextScale = math.max(0.75, math.min(1.5, BuildRadialTuning.textScale * radius / 640))
		local titleSize = math.max(16, 18 * panelTextScale)
		local descriptionSize = math.max(10, 10 * panelTextScale)
		local statsSize = math.max(9, 10 * panelTextScale)
		local labelSize = math.max(8, 8 * panelTextScale)
		local panelTextWidth = panelRadius * 1.55

		gl.Color(0.015, 0.04, 0.065, 0.88)
		drawCircle(cx, cy, panelRadius, 40)
		gl.Color(pageColor.accent[1], pageColor.accent[2], pageColor.accent[3], 0.78)
		gl.LineWidth(1.5)
		gl.BeginEnd(GL.LINE_LOOP, function()
			for i = 0, 40 do
				local theta = i * (2 * math.pi / 40)
				gl.Vertex(cx + panelRadius * math.cos(theta), cy + panelRadius * math.sin(theta))
			end
		end)

		while titleSize > 14 and ControllerCameraTestMeasureRadialText(info.title, titleSize) > panelTextWidth * 0.9 do
			titleSize = titleSize - 1
		end
		local titleY = cy + panelRadius * 0.66
		gl.Color(0.82, 0.94, 1, 1)
		gl.Text(info.title, cx + 0.8, titleY, titleSize, "oc")
		gl.Text(info.title, cx, titleY, titleSize, "oc")

		local titleDividerY = cy + panelRadius * 0.48
		gl.Color(pageColor.accent[1], pageColor.accent[2], pageColor.accent[3], 0.58)
		gl.BeginEnd(GL.LINES, function()
			gl.Vertex(cx - panelRadius * 0.7, titleDividerY)
			gl.Vertex(cx + panelRadius * 0.7, titleDividerY)
		end)

		local descriptionMaxLines = panelRadius < 145 and 2 or 3
		local descriptionLines = info.description ~= ""
			and ControllerCameraTestWrapRadialText(info.description, panelTextWidth, descriptionSize, descriptionMaxLines)
			or {}
		local roleLabelY = titleDividerY - labelSize * 1.35
		gl.Color(0.52, 0.78, 0.96, 0.9)
		gl.Text("ROLE", cx, roleLabelY, labelSize, "oc")
		local descriptionY = roleLabelY - descriptionSize * 1.35
		gl.Color(0.78, 0.84, 0.88, 0.96)
		for index, line in ipairs(descriptionLines) do
			gl.Text(line, cx, descriptionY - ((index - 1) * descriptionSize * 1.18), descriptionSize, "oc")
		end

		local descriptionBottom = descriptionY - (math.max(1, #descriptionLines) - 1) * descriptionSize * 1.18
		local statsDividerY = descriptionBottom - descriptionSize * 0.9
		gl.Color(pageColor.accent[1], pageColor.accent[2], pageColor.accent[3], 0.42)
		gl.BeginEnd(GL.LINES, function()
			gl.Vertex(cx - panelRadius * 0.7, statsDividerY)
			gl.Vertex(cx + panelRadius * 0.7, statsDividerY)
		end)

		local statsLabelY = statsDividerY - labelSize * 1.35
		gl.Color(0.52, 0.78, 0.96, 0.9)
		gl.Text("STATS", cx, statsLabelY, labelSize, "oc")
		local statRows = {}
		if info.stats[1] then
			statRows[#statRows + 1] = info.stats[1]
		end
		if panelRadius >= 145 then
			for index = 2, #info.stats, 2 do
				local row = info.stats[index]
				if info.stats[index + 1] then
					local pairedRow = row .. "     " .. info.stats[index + 1]
					if ControllerCameraTestMeasureRadialText(pairedRow, statsSize) <= panelTextWidth then
						row = pairedRow
					else
						statRows[#statRows + 1] = row
						row = info.stats[index + 1]
					end
				end
				statRows[#statRows + 1] = row
			end
		else
			for index = 2, #info.stats do
				statRows[#statRows + 1] = info.stats[index]
			end
		end

		local affordable = ControllerCameraTestGetCachedAffordability(currentOption)
		local statsY = statsLabelY - statsSize * 1.35
		for index, row in ipairs(statRows) do
			if index == 1 and not affordable then
				gl.Color(1.0, 0.4, 0.32, 1)
			elseif index == 1 then
				gl.Color(1.0, 0.84, 0.26, 1)
			else
				gl.Color(0.9, 0.94, 0.98, 0.98)
			end
			gl.Text(row, cx, statsY - ((index - 1) * statsSize * 1.18), statsSize, "oc")
		end

	end

	-- 4. Category/Page Indicator
	gl.Color(pageColor.accent[1], pageColor.accent[2], pageColor.accent[3], 0.95)
	local categoryStr = string.upper(menu.radialCategoryName or "Build")
	local pageStr = "PAGE " .. tostring(menu.radialPage) .. "/" .. tostring(menu.radialPageCount)

	gl.Text(categoryStr, cx, cy + radius * 0.65, 18 * BuildRadialTuning.pageLabelScale, "oc")
	gl.Color(0.8, 0.8, 0.8, 0.8)
	gl.Text(pageStr, cx, cy - radius * 0.65, 15 * BuildRadialTuning.pageLabelScale, "oc")

	gl.Color(0.6, 0.6, 0.6, 0.7)
	gl.Text("LB", cx - radius * 0.4, cy + radius * 0.65, 14 * BuildRadialTuning.pageLabelScale, "oc")
	gl.Text("RB", cx + radius * 0.4, cy + radius * 0.65, 14 * BuildRadialTuning.pageLabelScale, "oc")

	gl.Color(1, 1, 1, 1)
	gl.Texture(false)
	gl.LineWidth(1)
end

function ControllerCameraTestFormatSettingsUIValue(item)
	if item.type == "bool" then
		return ControllerCameraTestSettings[item.key] and "ON" or "OFF"
	end
	if item.type == "enum" then return tostring(ControllerCameraTestSettings[item.key] or "Combat") end
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
	local scale = ControllerCameraTestGetControllerUIScale("instructional", false)
	local fontScale = ControllerCameraTestGetControllerUIFontScale("instructional")
	local opacity = ControllerCameraTestGetControllerUIOpacity("instructional")
	local width = math.min(screenWidth - 40, math.min(760, math.max(300, screenWidth - 40)) * scale)
	local height = math.min(screenHeight - 40, math.min(430, math.max(300, screenHeight - 60)) * scale)
	local cx, cy = ControllerCameraTestGetControllerUIPosition("instructional", screenWidth * 0.5, screenHeight * 0.5)
	local left = math.max(20, math.min(screenWidth - width - 20, cx - width * 0.5))
	local top = math.max(height + 20, math.min(screenHeight - 20, cy + height * 0.5))
	local bottom = top - height
	local right = left + width
	local x = left + 18 * scale
	local y = top - 24 * scale
	local lineHeight = 17 * fontScale
	local maxChars = math.max(28, math.floor((width - 36 * scale) / math.max(1, 7.5 * fontScale)))
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
		"LB + Face Hotkeys (Builder): A Repair Area | X Reclaim Area | Y Patrol | YY Area Mex | B Stop | BB Repeat | Hold B Wait",
		"LB + Face Hotkeys (Combat): A Attack/Fight | X Attack | Y Patrol | B Stop | BB Repeat | Hold B Wait",
		"System UI: End Controller Settings | Page Up Debug | Page Down Help | Home Reset Settings Defaults",
		"Fallback UI commands: /luaui cct_debug | cct_help | cct_settings | cct_reset_settings",
		"Settings UI: D-pad/arrows adjust | LB/RB or Tab categories | A/Enter select | B/Escape close | X/Y reset",
		"Bindings tab: A capture next input | B cancel capture | X reset binding | Y reset all bindings",
		"Settings: saved ControllerCameraTestSettings override edited defaults after reload; Home applies code defaults",
		"Tuning Selection: " .. ControllerCameraTestCurrentSettingLabel(),
	}

	gl.Color(0, 0, 0, 0.86 * opacity)
	gl.Rect(left, bottom, right, top)
	gl.Color(0.12, 0.18, 0.23, 0.96 * opacity)
	gl.Rect(left, top - 34 * scale, right, top)
	gl.Color(0.72, 0.88, 1, 0.9 * opacity)
	gl.Rect(left, top - 34 * scale, right, top - 33 * scale)
	gl.Color(1, 1, 1, opacity)

	for i, line in ipairs(lines) do
		local size = ((i == 1) and 18 or 14) * fontScale
		local colorIsHeader = i == 1
		if colorIsHeader then
			gl.Color(0.72, 0.9, 1, opacity)
		else
			gl.Color(1, 1, 1, 0.96 * opacity)
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

function ControllerCameraTestGetControllerUIScale(componentName, includeSharedRadialScale)
	local shared = WG and WG.ControllerUISettings
	if not shared or type(shared.GetEffectiveScale) ~= "function" then return 1 end
	local scale = tonumber(shared.GetEffectiveScale(componentName)) or 1
	if includeSharedRadialScale and type(shared.GetComponent) == "function" then
		local radial = shared.GetComponent("radials")
		scale = scale * (radial and tonumber(radial.scale) or 1)
	end
	return scale
end

function ControllerCameraTestGetControllerUIPosition(componentName, fallbackX, fallbackY)
	local shared = WG and WG.ControllerUISettings
	if shared and type(shared.GetComponentCenter) == "function" then
		local x, y = shared.GetComponentCenter(componentName, fallbackX, fallbackY)
		if type(x) == "number" and type(y) == "number" then return x, y end
	end
	return fallbackX, fallbackY
end

function ControllerCameraTestGetControllerUIOpacity(componentName)
	local shared = WG and WG.ControllerUISettings
	if shared and type(shared.GetEffectiveOpacity) == "function" then
		local opacity = tonumber(shared.GetEffectiveOpacity(componentName)) or 1
		local radialComponent = componentName == "buildRadial" or componentName == "factoryRadial"
			or componentName == "tacticalRadial" or componentName == "selectionRadial" or componentName == "visibleSelectionRadial"
		if radialComponent and type(shared.GetComponent) == "function" then
			local radial = shared.GetComponent("radials"); opacity = opacity * (radial and tonumber(radial.opacity) or 1)
		end
		return opacity
	end
	return 1
end

function ControllerCameraTestGetControllerUIBounds(componentName, baseWidth, baseHeight)
	local shared = WG and WG.ControllerUISettings
	if shared and type(shared.GetComponentBounds) == "function" then return shared.GetComponentBounds(componentName, baseWidth, baseHeight) end
	return nil
end

function ControllerCameraTestControllerUIVisible(componentName, includeSharedRadials)
	local shared = WG and WG.ControllerUISettings
	if not shared or type(shared.GetComponent) ~= "function" then return true end
	local global = type(shared.GetGlobal) == "function" and shared.GetGlobal() or nil
	local component = shared.GetComponent(componentName)
	local radials = includeSharedRadials and shared.GetComponent("radials") or nil
	return (not global or global.enabled ~= false) and (not component or component.enabled ~= false)
		and (not radials or radials.enabled ~= false)
end

function ControllerCameraTestGetControllerUIFontScale(componentName)
	local shared = WG and WG.ControllerUISettings
	if not shared or type(shared.GetEffectiveFontScale) ~= "function" then return 1 end
	local scale = tonumber(shared.GetEffectiveFontScale(componentName)) or 1
	local radialComponent = componentName == "buildRadial" or componentName == "factoryRadial"
		or componentName == "tacticalRadial" or componentName == "selectionRadial" or componentName == "visibleSelectionRadial" or componentName == "radials"
	if radialComponent and type(shared.GetComponent) == "function" then
		local radial = shared.GetComponent("radials")
		scale = scale * (radial and tonumber(radial.fontScale) or 1)
	end
	return scale
end

function ControllerCameraTestGetControllerUIIconScale(componentName)
	local shared = WG and WG.ControllerUISettings
	if not shared or type(shared.GetComponent) ~= "function" then return 1 end
	local component, radial = shared.GetComponent(componentName), shared.GetComponent("radials")
	return (component and tonumber(component.iconScale) or 1) * (radial and tonumber(radial.iconScale) or 1)
end

function ControllerCameraTestGetRadialRendererSettings(componentName)
	local shared = WG and WG.ControllerUISettings
	local radial = shared and type(shared.GetComponent) == "function" and shared.GetComponent("radials") or nil
	local component = shared and type(shared.GetComponent) == "function" and shared.GetComponent(componentName) or nil
	local typography = shared and type(shared.GetResolvedRadialStyle) == "function" and shared.GetResolvedRadialStyle(componentName) or nil
	if not typography and ControllerUISharedRenderers and ControllerUISharedRenderers.RadialStyle then
		typography = ControllerUISharedRenderers.RadialStyle.Resolve(radial, component)
	end
	return {
		iconScale = ControllerCameraTestGetControllerUIIconScale(componentName),
		fontScale = ControllerCameraTestGetControllerUIFontScale(componentName),
		centerTextScale = radial and tonumber(radial.centerTextScale) or 1,
		selectedScale = radial and tonumber(radial.selectedScale) or 1.06,
		selectedBorderThickness = radial and tonumber(radial.selectedBorderThickness) or 3,
		itemSpacing = radial and tonumber(radial.itemSpacing) or 1,
		legacyThemeOpacity = radial and tonumber(radial.legacyThemeOpacity) or 1,
		pageStatusVisible = not radial or radial.pageStatusVisible ~= false,
		typography = typography,
	}
end

function ControllerCameraTestDrawCompanionFeedback()
	if not ControllerCameraTestControllerUIVisible("companionStatus", false) then return end
	local feedback = ControllerCameraTestCompanionFeedback
	local missing = feedback.missingVisible == true
	local connected = not missing and (feedback.connectedUntil or 0) > debugEventTime
	if not missing and not connected then
		return
	end

	local cx, cy = ControllerCameraTestGetControllerUIPosition("companionStatus", viewSizeX * 0.5, viewSizeY * 0.73)
	local scale = ControllerCameraTestGetControllerUIScale("companionStatus", false)
	local fontScale = ControllerCameraTestGetControllerUIFontScale("companionStatus")
	local opacity = ControllerCameraTestGetControllerUIOpacity("companionStatus")
	local halfWidth = math.min(430, viewSizeX * 0.42) * scale
	local halfHeight = (missing and 72 or 44) * scale

	gl.Color(0.02, 0.04, 0.06, 0.92 * opacity)
	gl.Rect(cx - halfWidth, cy - halfHeight, cx + halfWidth, cy + halfHeight)
	if missing then
		gl.Color(1.0, 0.35, 0.24, 0.98 * opacity)
		gl.Text("Controller Companion Not Running", cx, cy + 15 * scale, 31 * fontScale, "oc")
		gl.Color(0.94, 0.96, 1.0, 0.96 * opacity)
		gl.Text("Start BARControllerBridge.exe, then return to BAR.", cx, cy - 29 * scale, 20 * fontScale, "oc")
	else
		gl.Color(0.35, 1.0, 0.55, 0.98 * opacity)
		gl.Text("Controller Companion Connected", cx, cy - 11 * scale, 29 * fontScale, "oc")
	end
	gl.Color(1, 1, 1, 1)
end

function ControllerCameraTestDrawDisassembleCharge()
	local toggle = ControllerCameraTestDisassemble and ControllerCameraTestDisassemble.toggle
	if not toggle or not toggle.charging then return end
	local cx, cy = ControllerCameraTestGetControllerUIPosition("notifications", viewSizeX * 0.5, viewSizeY * 0.35)
	local scale = ControllerCameraTestGetControllerUIScale("notifications", false)
	local opacity = ControllerCameraTestGetControllerUIOpacity("notifications")
	local progress = clamp(toggle.progress or 0, 0, 1)
	local width, height = 360 * scale, 54 * scale
	gl.Color(0.015, 0.025, 0.035, 0.92 * opacity)
	gl.Rect(cx - width * 0.5, cy - height * 0.5, cx + width * 0.5, cy + height * 0.5)
	gl.Color(0.18, 0.72, 0.42, 0.88 * opacity)
	gl.Rect(cx - width * 0.5 + 6 * scale, cy - height * 0.5 + 6 * scale,
		cx - width * 0.5 + 6 * scale + (width - 12 * scale) * progress, cy - height * 0.5 + 14 * scale)
	gl.Color(0.82, 1.0, 0.9, opacity)
	gl.Text(ControllerCameraTestDisassemble.active and "HOLD LB + RB: EXIT DISASSEMBLE MODE"
		or "HOLD LB + RB: DISASSEMBLE MODE", cx, cy - 5 * scale,
		14 * ControllerCameraTestGetControllerUIFontScale("notifications"), "oc")
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
		ControllerCameraTestDrawAreaCommandCenterLabel()
		ControllerCameraTestDrawFilterRadial()
		ControllerCameraTestDrawVisibleSelectionRadial()
	end
	ControllerCameraTestDrawCompactSelectedStatusPanel()
	if not ControllerCameraTestSettingsUI.open then
		ControllerCameraTestDrawControlGroupOverlay()
	end
	if ControllerCameraTestSettings.helpOverlayVisible and ControllerCameraTestControllerUIVisible("instructional", false) then
		ControllerCameraTestDrawHelpOverlay()
	end
	ControllerCameraTestDrawSettingsUI()
	ControllerCameraTestDrawCompanionFeedback()
	ControllerCameraTestDrawDisassembleCharge()

	local feedback = ControllerCameraTestHotkeyFeedback
	if ControllerCameraTestControllerUIVisible("notifications", false) and feedback and feedback.text and feedback.startTime then
		local age = Spring.DiffTimers(Spring.GetTimer(), feedback.startTime)
		if age < feedback.duration then
			local alpha = 1.0
			local fadeDuration = 0.50
			local fadeStart = feedback.duration - fadeDuration
			if age > fadeStart then
				alpha = (feedback.duration - age) / fadeDuration
			end
			alpha = math.max(0, math.min(1, alpha))

			local col = feedback.color
			local cx, cy = ControllerCameraTestGetControllerUIPosition("notifications", viewSizeX / 2, viewSizeY * 0.35)
			local uiOpacity = ControllerCameraTestGetControllerUIOpacity("notifications")
			local size = 38 * ControllerCameraTestGetControllerUIFontScale("notifications")
			alpha = alpha * uiOpacity

			-- Outline/Shadow
			gl.Color(0, 0, 0, 0.40 * alpha)
			gl.Text(feedback.text, cx - 1.5, cy - 1.5, size, "oc")
			gl.Text(feedback.text, cx + 1.5, cy - 1.5, size, "oc")
			gl.Text(feedback.text, cx - 1.5, cy + 1.5, size, "oc")
			gl.Text(feedback.text, cx + 1.5, cy + 1.5, size, "oc")
			gl.Text(feedback.text, cx, cy - 1.5, size, "oc")
			gl.Text(feedback.text, cx, cy + 1.5, size, "oc")
			gl.Text(feedback.text, cx - 1.5, cy, size, "oc")
			gl.Text(feedback.text, cx + 1.5, cy, size, "oc")

			-- Main Text
			gl.Color(col[1], col[2], col[3], col[4] * alpha)
			gl.Text(feedback.text, cx, cy, size, "oc")
		end
	end
	gl.Color(1, 1, 1, 1)

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
	local areaStateStr = tostring(ControllerCameraTestAreaCommandDebug.state or "none")
	local activeMode = tostring(ControllerCameraTestAreaCommandDebug.colorProfile or "none")
	local centerPosStr = "nil"
	local radiusStr = "nil"
	local areaRawRadiusStr = tostring(ControllerCameraTestAreaCommandDebug.rawRadius or "none")
	local areaEffectiveRadiusStr = tostring(ControllerCameraTestAreaCommandDebug.effectiveRadius or "none")
	local areaOption = ControllerCameraTestTacticalMenu.stagedOption
	local drag = ControllerCameraTestDragCommand

	if type(areaOption) == "table" then
		local isAreaCmd = ControllerCameraTestIsAreaTacticalOption(areaOption)
		if isAreaCmd then
			activeMode = tostring(areaOption.dragMode or areaOption.name)
			if not drag.active then
				areaStateStr = "staged waiting for center"
			else
				areaStateStr = "dragging radius"
				if drag.startX then
					centerPosStr = string.format("%.1f, %.1f, %.1f", drag.startX, drag.startY, drag.startZ)
					local dx = (drag.endX or reticleWorldX or 0) - drag.startX
					local dz = (drag.endZ or reticleWorldZ or 0) - drag.startZ
					local rawRadius, effectiveRadius = ControllerCameraTestAreaCommandRadius(drag.startX, drag.startZ, drag.endX or reticleWorldX, drag.endZ or reticleWorldZ)
					radiusStr = string.format("%.1f", effectiveRadius)
					areaRawRadiusStr = string.format("%.1f", rawRadius)
					areaEffectiveRadiusStr = radiusStr
				end
			end
		end
	end

	ControllerCameraTestTacticalMenu.debugRowsCount = 23

	local controllerSections = {
		{
			key = "Input",
			title = "Input / Controller",
			lines = {
				"Widget: Controller Camera Test",
				"API: " .. yesNo(apiAvailable),
				"Backend: " .. tostring(ControllerCameraTestInputBackend),
				"Bridge: " .. tostring(ControllerCameraTestBridgeStatus),
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
		{
			key = "DGun",
			title = "Commander DGUN Mode",
			lines = {
				"DGUN mode active: " .. yesNo(ControllerCameraTestDgunMode.active),
				"Commander unitID: " .. tostring(ControllerCameraTestDgunMode.commanderID or "none"),
				"DGUN command ID: " .. tostring(ControllerCameraTestDgunMode.cmdID or "none"),
				"DGUN range source: " .. tostring(ControllerCameraTestDgunMode.rangeSource or "none"),
				"DGUN aim range: " .. tostring(ControllerCameraTestDgunMode.range or 280),
				"DGUN aim deadzone: 0.50",
				"DGUN move deadzone: 0.40",
				"Aim stick input: " .. (ControllerCameraTestDgunMode.aimActive and "active" or "ignored"),
				"Move stick input: " .. (ControllerCameraTestDgunMode.movementStickActive and "active" or "ignored"),
				string.format("Aim vector: rx=%.3f rz=%.3f", ControllerCameraTestDgunMode.aimX, ControllerCameraTestDgunMode.aimZ),
				string.format("Target world: x=%.1f y=%.1f z=%.1f", ControllerCameraTestDgunMode.targetX, ControllerCameraTestDgunMode.targetY, ControllerCameraTestDgunMode.targetZ),
				"Last fire result: " .. tostring(ControllerCameraTestDgunMode.lastFireResult),
				"Last exit reason: " .. tostring(ControllerCameraTestDgunMode.lastExitReason),
				"Movement active: " .. yesNo(ControllerCameraTestDgunMode.moveActive),
				string.format("Move target: x=%.1f z=%.1f", ControllerCameraTestDgunMode.moveTargetX or 0, ControllerCameraTestDgunMode.moveTargetZ or 0),
				"Last move result: " .. tostring(ControllerCameraTestDgunMode.lastMoveResult),
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
				"Self destruct chord: " .. yesNo(ControllerCameraTestSelfDestruct.chordActive) .. " hold=" .. string.format("%.2f", ControllerCameraTestSelfDestruct.chordActive and (debugEventTime - (ControllerCameraTestSelfDestruct.holdStartTime or debugEventTime)) or 0),
				"Self destruct cmd/result: " .. tostring(ControllerCameraTestSelfDestruct.cmdID) .. " / " .. tostring(ControllerCameraTestSelfDestruct.lastResult),
				"Self destruct selected/issued: " .. tostring(ControllerCameraTestSelfDestruct.selectedCount) .. " / " .. tostring(ControllerCameraTestSelfDestruct.issuedCount),
				"Mex smart available: " .. tostring(ControllerCameraTestCommandDebug.mexSmartAvailable),
				"Mex nearest spot: " .. tostring(ControllerCameraTestCommandDebug.mexNearestSpot),
				"Mex building cmd ID: " .. tostring(ControllerCameraTestCommandDebug.mexBuildingCmdID),
				"Mex action result: " .. tostring(ControllerCameraTestCommandDebug.mexActionResult),
				"Mex ApplyPreviewCmds: " .. tostring(ControllerCameraTestCommandDebug.mexApplyPreviewPath),
				"Mex fallback GiveOrder: " .. tostring(ControllerCameraTestCommandDebug.mexFallbackGiveOrderPath),
				"Smart X exact target: " .. tostring(ControllerCameraTestCommandDebug.smartExactTargetType) .. " " .. tostring(ControllerCameraTestCommandDebug.smartExactTargetID),
				"Smart X assist target: " .. tostring(ControllerCameraTestCommandDebug.smartAssistTargetType) .. " " .. tostring(ControllerCameraTestCommandDebug.smartAssistTargetID) .. " d=" .. tostring(ControllerCameraTestCommandDebug.smartAssistDistance),
				"Smart X assist scale: " .. tostring(ControllerCameraTestCommandDebug.smartAssistScale),
				"Smart X effective radii screen/feature/unit: " .. tostring(ControllerCameraTestCommandDebug.smartEffectiveScreenRadius) .. " / " .. tostring(ControllerCameraTestCommandDebug.smartEffectiveFeatureRadius) .. " / " .. tostring(ControllerCameraTestCommandDebug.smartEffectiveUnitRadius),
				"Smart X action/cmd: " .. tostring(ControllerCameraTestCommandDebug.smartChosenAction) .. " / " .. tostring(ControllerCameraTestCommandDebug.smartChosenCmdID),
				"Smart X params: " .. tostring(ControllerCameraTestCommandDebug.smartOrderParams),
				"Smart X source/result: " .. tostring(ControllerCameraTestCommandDebug.smartActionSource) .. " / " .. tostring(ControllerCameraTestCommandDebug.smartLastResult),
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
				"Tactical options/rebuilds: " .. tostring(ControllerCameraTestTacticalMenu.optionCount) .. " / " .. tostring(ControllerCameraTestTacticalMenu.optionsRebuildCount),
				"Tactical draw/hitboxes: " .. tostring(ControllerCameraTestTacticalMenu.drawCount) .. " / " .. tostring(ControllerCameraTestTacticalMenu.hitboxCount),
				"Tactical cache hits/misses: " .. tostring(ControllerCameraTestTacticalMenu.cacheHits) .. " / " .. tostring(ControllerCameraTestTacticalMenu.cacheMisses),
				"Tactical cache reason: " .. tostring(ControllerCameraTestTacticalMenu.lastRebuildReason),
				"Tactical result: " .. tostring(ControllerCameraTestTacticalMenu.lastResult),
				"Area command state: " .. areaStateStr,
				"Area command mode: " .. activeMode,
				"Area command label/cmdID: " .. tostring(ControllerCameraTestAreaCommandDebug.label) .. " / " .. tostring(ControllerCameraTestAreaCommandDebug.cmdID),
				"Area command action/source: " .. tostring(ControllerCameraTestAreaCommandDebug.action) .. " / " .. tostring(ControllerCameraTestAreaCommandDebug.descriptorSource),
				"Area center pos: " .. centerPosStr,
				"Area radius raw/effective: " .. areaRawRadiusStr .. " / " .. areaEffectiveRadiusStr,
				"Area sensitivity/color: " .. tostring(ControllerCameraTestAreaCommandDebug.sensitivity) .. " / " .. tostring(ControllerCameraTestAreaCommandDebug.colorProfile),
				"Area icon source: " .. tostring(ControllerCameraTestAreaCommandDebug.iconSource),
				"Area last issue: " .. tostring(ControllerCameraTestAreaCommandDebug.lastIssueResult),
				"Area last cancel reason: " .. tostring(ControllerCameraTestAreaCancelReason),
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
				"Tactical rows/options: " .. tostring(ControllerCameraTestTacticalMenu.debugRowsCount) .. " / " .. tostring(ControllerCameraTestTacticalMenu.optionCount),
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
				"Placement cells: " .. tostring(diagPlacementPreviewCells),
				"Placement rebuilds: " .. tostring(diagPlacementPreviewRebuildCount),
				"Placement cache hits/misses: " .. tostring(diagPlacementPreviewCacheHits) .. " / " .. tostring(diagPlacementPreviewCacheMisses),
				"Placement rebuild reason: " .. tostring(diagPlacementPreviewLastRebuildReason),
				"Placement grid size: " .. tostring(diagPlacementGridRows) .. " x " .. tostring(diagPlacementGridCols),
				"Placement draw count: " .. tostring(diagPlacementDrawCount),
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
			"Mode: " .. tostring(ControllerCameraTestLayerDebug.modeSummary) .. " (DGUN:" .. yesNo(ControllerCameraTestDgunMode.active) .. ") | Held: " .. heldButtonsSummary .. " | Pressed: " .. pressedRecentlySummary,
			"Idle: " .. tostring(ControllerCameraTestIdleCycle.lastTypeName) .. " x" .. tostring(ControllerCameraTestIdleCycle.lastCount) .. " | Group " .. ControllerCameraTestGetControlGroupDisplaySlot(activeGroupSlot) .. " " .. tostring(activeGroupType) .. " x" .. tostring(activeGroupCount) .. " | A2: " .. tostring(ControllerCameraTestAreaSelect.doubleTapAction),
			"Append: " .. yesNo(ControllerCameraTestIsQueueModifierActive()) .. " | Insert: " .. yesNo(ControllerCameraTestIsQueueFrontModifierActive()) .. " | Settings: " .. yesNo(ControllerCameraTestSettingsUI.open) .. " | External UI: " .. yesNo(ControllerCameraTestExternalBindingUI.open) .. " | Tactical: " .. yesNo(ControllerCameraTestTacticalMenu.open) .. " | Build: " .. yesNo(ControllerCameraTestBuildMenu.open),
			"Key: " .. tostring(ControllerCameraTestKeyDebug.rawKey) .. " " .. tostring(ControllerCameraTestKeyDebug.label) .. " -> " .. tostring(ControllerCameraTestKeyDebug.matchedAction),
			"Radial: " .. yesNo(ControllerCameraTestBuildMenu.open) .. " | Cat: " .. tostring(ControllerCameraTestBuildMenu.radialCategoryName) .. " | Highlight: " .. tostring(ControllerCameraTestBuildMenu.highlightedName) .. " (Q:" .. tostring(highlightedQueueCount) .. (factoryProgressKnown == "yes" and " P:" .. factoryProgressValue or "") .. ")",
			"Placement: " .. tostring(ControllerCameraTestBuildPlacement.placementMode or "none") .. " | Pattern: " .. tostring(ControllerCameraTestBuildPlacement.placementPattern) .. " | Spacing: " .. tostring(ControllerCameraTestBuildPlacement.placementSpacing),
			"Drag: Act=" .. yesNo(ControllerCameraTestDragCommand.active) .. " Mode=" .. tostring(ControllerCameraTestDragCommand.mode) .. " Pts=" .. tostring(ControllerCameraTestDragCommand.previewPoints and #ControllerCameraTestDragCommand.previewPoints or 0) .. " R:" .. tostring(diagPlacementPreviewRebuildCount) .. " H/M:" .. tostring(diagPlacementPreviewCacheHits) .. "/" .. tostring(diagPlacementPreviewCacheMisses) .. " G:" .. tostring(diagPlacementGridRows) .. "x" .. tostring(diagPlacementGridCols),
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
		if type(value) ~= "table" and key ~= "debugPanelVisible" then
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
		configSchema = CONTROLLER_BINDINGS_CONFIG_SCHEMA,
		bindingPreset = ControllerCameraTestRefreshActivePreset(),
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
			if key ~= "debugPanelVisible" and ControllerCameraTestSettings[key] ~= nil then
				local val = value
				if key == "stickDeadzone" and val == 3000 then
					val = 5000
				end
				-- v0.7 shipped the Disassemble chord at exactly one second.  Preserve
				-- custom values, but migrate that old default to the v0.8 test default.
				if key == "disassembleToggleHoldSeconds" and tonumber(val) == 1.0 then
					val = 0.33
				end
				ControllerCameraTestSettings[key] = val
			end
		end
	end
	ControllerCameraTestApplySettingsDefaults()
	ControllerCameraTestSettings.debugPanelVisible = false
	ControllerCameraTestEnsureBindings()
	local explicitSchema = tonumber(data.configSchema)
	local schemaSupported = explicitSchema == nil or explicitSchema == 1 or explicitSchema == CONTROLLER_BINDINGS_CONFIG_SCHEMA
	if schemaSupported and ControllerCameraTestValidateSavedBindings(data.bindings) then
		for _, def in ipairs(ControllerCameraTestBindingDefinitions()) do
			local saved = data.bindings[def.action]
			ControllerCameraTestBindings.actions[def.action] = saved
		end
		ControllerCameraTestBindings.revision = (ControllerCameraTestBindings.revision or 0) + 1
		ControllerCameraTestRefreshActivePreset()
	else
		-- The only automatic application: fresh, partial, malformed, or an
		-- explicitly unsupported schema. Complete legacy/custom tables migrate
		-- above and are never overwritten on normal launches.
		ControllerCameraTestApplyBindingPreset(CONTROLLER_BUILD_FIRST_PRESET_NAME)
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
	ControllerCameraTestVisibleSelection.currentSelection = ControllerCameraTestSafeSelectionSnapshot(ControllerCameraTestVisibleSelection.currentSelection)
	ControllerCameraTestVisibleSelection.previousSelection = ControllerCameraTestSafeSelectionSnapshot(ControllerCameraTestVisibleSelection.previousSelection)
end

function widget:UnitTaken(unitID)
	ControllerCameraTestRemoveUnitFromControlGroups(unitID)
	ControllerCameraTestVisibleSelection.currentSelection = ControllerCameraTestSafeSelectionSnapshot(ControllerCameraTestVisibleSelection.currentSelection)
	ControllerCameraTestVisibleSelection.previousSelection = ControllerCameraTestSafeSelectionSnapshot(ControllerCameraTestVisibleSelection.previousSelection)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	ControllerCameraTestAutoAddFinishedUnitToGroups(unitID, unitDefID, unitTeam)
end

function widget:SelectionChanged(selectedUnits)
	ControllerCameraTestRecordSelectionSnapshot(selectedUnits)
end

--------------------------------------------------------------------------------
-- SECTION: Widget lifecycle
--------------------------------------------------------------------------------
function widget:DrawWorld()
	if not controllerMode then
		return
	end

	-- DGUN Mode Preview
	local dgun = ControllerCameraTestDgunMode
	if dgun and dgun.active and dgun.commanderID then
		local cx, cy, cz = spGetUnitPosition(dgun.commanderID)
		if cx and cz then
			cy = cy or 0
			-- Faint range circle (red)
			gl.LineWidth(1.5)
			gl.Color(1.0, 0.0, 0.0, 0.25)
			gl.DrawGroundCircle(cx, cy, cz, dgun.range or ControllerCameraTestDgunAimRange, 64)

			-- Red target circle/marker at target point
			gl.LineWidth(2.5)
			gl.Color(1.0, 0.0, 0.0, 0.8)
			gl.DrawGroundCircle(dgun.targetX, dgun.targetY, dgun.targetZ, 32, 24)
			gl.DrawGroundCircle(dgun.targetX, dgun.targetY, dgun.targetZ, 8, 12)

			-- Red aim vector line from commander to target
			gl.BeginEnd(GL.LINE_STRIP, function()
				gl.Vertex(cx, cy + 12, cz)
				gl.Vertex(dgun.targetX, dgun.targetY + 2, dgun.targetZ)
			end)
		end
	end

	if ControllerCameraTestDrawSelectedUnitGreenCircle and type(spGetSelectedUnits) == "function" and type(spGetUnitPosition) == "function" then
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
		local R = ControllerCameraTestAreaSelect.radius
		-- Stroke
		gl.LineWidth(2.5)
		gl.Color(0.25, 0.75, 1.0, 0.75)
		gl.DrawGroundCircle(reticleWorldX, reticleWorldY, reticleWorldZ, R, 48)

		-- Fill (concentric rings for smooth look, 22% opacity)
		gl.LineWidth(2.0)
		gl.Color(0.25, 0.75, 1.0, 0.22)
		local step = R / 25
		for r = step, R - step/2, step do
			gl.DrawGroundCircle(reticleWorldX, reticleWorldY, reticleWorldZ, r, 32)
		end
	end

	local disassemble = ControllerCameraTestDisassemble
	if disassemble and disassemble.active and not ControllerCameraTestUsesNativeBARUI() then
		ControllerCameraTestPruneMarkedTargets()
		gl.LineWidth(2.6)
		for unitID in pairs(disassemble.markedTargets or {}) do
			local x, y, z = spGetUnitPosition(unitID)
			if x and z then
				gl.Color(1.0, 0.48, 0.12, 0.92)
				gl.DrawGroundCircle(x, y or 0, z, 43, 32)
				gl.Color(1.0, 0.78, 0.2, 0.42)
				gl.DrawGroundCircle(x, y or 0, z, 34, 24)
			end
		end
		if disassemble.markArea.active and reticleHasWorldTarget then
			gl.LineWidth(3)
			gl.Color(1.0, 0.52, 0.12, 0.86)
			gl.DrawGroundCircle(reticleWorldX, reticleWorldY or 0, reticleWorldZ, disassemble.markArea.radius or 320, 64)
		end
		local reclaimArea = disassemble.areaReclaim
		if reclaimArea and reclaimArea.active and reclaimArea.x and reclaimArea.z then
			gl.LineWidth(3)
			gl.Color(0.2, 1.0, 0.46, 0.9)
			gl.DrawGroundCircle(reclaimArea.x, reclaimArea.y or 0, reclaimArea.z, reclaimArea.radius or 120, 64)
			for _, unitID in ipairs(reclaimArea.candidates or {}) do
				local x, y, z = spGetUnitPosition(unitID)
				if x and z then
					gl.Color(0.36, 1.0, 0.58, 0.76)
					gl.DrawGroundCircle(x, y or 0, z, 38, 28)
				end
			end
		end
		gl.Color(1, 1, 1, 1)
		gl.LineWidth(1)
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
		and drag.mode ~= "moveLine"
		and drag.mode ~= "singleMovePath"
		and not (drag.nativeRouteUsed and drag.nativePreviewResult == "native preview active"
			and string.sub(tostring(drag.mode), 1, 5) == "build")
	then
		diagPlacementDrawCount = diagPlacementDrawCount + 1
		local startX, startY, startZ = drag.startX, drag.startY, drag.startZ
		local endX = drag.endX or reticleWorldX
		local endY = drag.endY or reticleWorldY
		local endZ = drag.endZ or reticleWorldZ

		if endX and startX then
			gl.LineWidth(3.0)
			if ControllerCameraTestAreaCommandProfiles[drag.mode] ~= nil
				or (type(drag.option) == "table" and ControllerCameraTestIsAreaTacticalOption(drag.option))
			then
				local rawRadius, effectiveRadius = ControllerCameraTestAreaCommandRadius(startX, startZ, endX, endZ)
				local option = type(drag.option) == "table" and drag.option or nil
				local profile = ControllerCameraTestGetAreaCommandProfile(option or drag.mode)
				local color = profile.color or ControllerCameraTestAreaCommandProfiles.genericArea.color
				gl.Color(color[1], color[2], color[3], color[4] or 0.68)
				gl.DrawGroundCircle(startX, startY, startZ, effectiveRadius, 64)
				gl.DrawGroundCircle(startX, startY, startZ, 12, 16)
				ControllerCameraTestUpdateAreaCommandDebug("dragging radius", option, rawRadius, effectiveRadius, "preview")
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
