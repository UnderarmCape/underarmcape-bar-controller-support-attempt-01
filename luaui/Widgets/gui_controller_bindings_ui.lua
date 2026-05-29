--------------------------------------------------------------------------------
-- BAR Xbox Controller Support - Binding editor pre-alpha
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Controller Bindings UI",
		desc = "Pre-alpha Xbox controller binding editor for BAR Controller Support",
		author = "Kailil / Codex",
		date = "2026-05-29",
		license = "GNU GPL, v2 or later",
		layer = 1000000,
		enabled = true,
	}
end

local spGetViewGeometry = Spring.GetViewGeometry
local spGetGameSeconds = Spring.GetGameSeconds
local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local GL_LINE_LOOP = GL.LINE_LOOP

local USE_SAFE_AREA_LAYOUT = true
local SAFE_LEFT_MARGIN = 285
local SAFE_TOP_MARGIN = 80
local SAFE_RIGHT_MARGIN = 20
local SAFE_BOTTOM_MARGIN = 40

local ControllerBindingsUI = {
	open = false,
	categoryIndex = 1,
	actionIndex = 1,
	categories = {},
	missing = {},
	toast = "Closed",
	modal = nil,
	captureAction = nil,
	captureStartTime = 0,
	captureGateReleased = false,
	pendingInput = nil,
	conflictAction = nil,
	layout = {
		tabs = {},
		rows = {},
		close = nil,
		modalButtons = {},
	},
}

local ControllerBindingsUIRequiredAPI = {
	"GetBindingDefinitions",
	"GetBinding",
	"SetBinding",
	"ResetBinding",
	"ResetAllBindings",
	"GetPressedBindingInput",
	"IsInputPressed",
	"IsInputDown",
	"SetBindingUIOpen",
	"IsBindingUIOpen",
}

local ControllerBindingsUIGroupOrder = {
	["Core"] = 1,
	["Camera"] = 2,
	["Build"] = 3,
	["Placement"] = 4,
	["Tactical"] = 5,
	["Queue"] = 6,
	["Idle / Groups"] = 7,
	["Advanced"] = 8,
}

local ControllerBindingsUIReadOnlyCameraDefs = {
	{
		action = "cameraPan",
		label = "Camera Pan",
		default = "Left Stick",
		group = "Camera",
		readOnly = true,
		description = "Fixed camera pan axis. This is shown for layout preview and is not remappable through the current gameplay API.",
	},
	{
		action = "cameraRotate",
		label = "Rotate Camera",
		default = "Right Stick X",
		group = "Camera",
		readOnly = true,
		description = "Fixed camera rotation axis. This is shown for layout preview and is not remappable through the current gameplay API.",
	},
	{
		action = "cameraZoom",
		label = "Zoom Camera",
		default = "Right Stick Y",
		group = "Camera",
		readOnly = true,
		description = "Fixed camera zoom axis. This is shown for layout preview and is not remappable through the current gameplay API.",
	},
}

local ControllerBindingsUIDescriptions = {
	select = "Select hovered units, confirm radial choices, and accept primary UI actions.",
	cancel = "Cancel current modes, close menus, or clear selection in normal play.",
	smartAction = "Context-sensitive action. Tap for smart action, hold for path or line behavior.",
	buildRadial = "Open constructor build options or factory radial controls.",
	commandLayer = "Open the tactical command layer for move, fight, reclaim, repair, and related commands.",
	queueModifier = "Queue modifier used like Shift while confirming commands.",
	controlGroupModifier = "Hold to use controller control-group mode.",
	pitchModifier = "Hold LB to access camera pitch / tilt behavior.",
	removeQueuedCommand = "Back/View removes the current or next queued unit command. LT + Back/View removes the last queued command.",
	radialSelect = "Select the highlighted radial item.",
	radialCancel = "Cancel or close the current radial.",
	radialQuick = "Quick-place a radial item when supported.",
	radialClose = "Close the current radial.",
	radialPrevPage = "Move to the previous radial page or category.",
	radialNextPage = "Move to the next radial page or category.",
	place = "Place the current building and exit placement when appropriate.",
	placeStay = "Place the current building and keep placement active when supported.",
	cancelPlacement = "Cancel current build placement.",
	rotateBuildingLeft = "Rotate building facing left.",
	rotateBuildingRight = "Rotate building facing right.",
	spacingUp = "Increase build spacing during placement.",
	spacingDown = "Decrease build spacing during placement.",
	patternPrev = "Cycle to the previous placement pattern.",
	patternNext = "Cycle to the next placement pattern.",
	tacticalSelect = "Confirm highlighted tactical radial command.",
	tacticalCancel = "Cancel the tactical radial.",
	tacticalClose = "Close the tactical radial.",
	commandUp = "RT layer D-pad Up command slot.",
	commandDown = "RT layer D-pad Down command slot.",
	commandLeft = "RT layer previous command or selection cycle.",
	commandRight = "RT layer next command or selection cycle.",
	idlePrev = "Cycle to the previous idle unit.",
	idleNext = "Cycle to the next idle unit.",
	groupSlotUp = "Move to the next controller control-group slot while RB is held.",
	groupSlotDown = "Move to the previous controller control-group slot while RB is held.",
	groupRecallOrAssign = "Tap to recall the active group. Hold to assign the same unit type.",
	groupClear = "Clear the active controller control-group slot while RB is held.",
}

local ControllerBindingsUILabelOverrides = {
	pitchModifier = "Camera Pitch Modifier",
}

local ControllerBindingsUIBindingLabels = {
	A = "A",
	B = "B",
	X = "X",
	Y = "Y",
	LB = "LB",
	RB = "RB",
	LT = "LT",
	RT = "RT",
	back = "Back/View",
	start = "Menu/Start",
	dpadUp = "D-pad Up",
	dpadDown = "D-pad Down",
	dpadLeft = "D-pad Left",
	dpadRight = "D-pad Right",
}

local ControllerBindingsUIControlIdMap = {
	a = "a",
	b = "b",
	x = "x",
	y = "y",
	lb = "lb",
	rb = "rb",
	lt = "lt",
	rt = "rt",
	back = "backView",
	backview = "backView",
	view = "backView",
	start = "menuStart",
	menu = "menuStart",
	menustart = "menuStart",
	startmenu = "menuStart",
	leftstick = "leftStick",
	leftstickx = "leftStickX",
	leftsticky = "leftStickY",
	rightstick = "rightStick",
	rightstickx = "rightStickX",
	rightsticky = "rightStickY",
	dpadup = "dpadUp",
	dpaddown = "dpadDown",
	dpadleft = "dpadLeft",
	dpadright = "dpadRight",
}

local ControllerBindingsUICaptureInputs = {
	"A", "B", "X", "Y", "back", "start", "LB", "RB",
	"dpadUp", "dpadDown", "dpadLeft", "dpadRight", "LT", "RT",
}

local function ControllerBindingsUISupport()
	return WG and WG.BARControllerSupport
end

local function ControllerBindingsUISafeCall(name, ...)
	local support = ControllerBindingsUISupport()
	local fn = support and support[name]
	if type(fn) ~= "function" then
		return false, nil
	end
	return pcall(fn, ...)
end

local function ControllerBindingsUIRefreshMissingAPI()
	local missing = {}
	local support = ControllerBindingsUISupport()
	if type(support) ~= "table" then
		for i = 1, #ControllerBindingsUIRequiredAPI do
			missing[#missing + 1] = ControllerBindingsUIRequiredAPI[i]
		end
	else
		for i = 1, #ControllerBindingsUIRequiredAPI do
			local name = ControllerBindingsUIRequiredAPI[i]
			if type(support[name]) ~= "function" then
				missing[#missing + 1] = name
			end
		end
	end
	ControllerBindingsUI.missing = missing
	return #missing == 0
end

local function ControllerBindingsUISetGameplayBlocked(blocked)
	ControllerBindingsUISafeCall("SetBindingUIOpen", blocked == true)
end

local function ControllerBindingsUIDisplayBinding(binding)
	if binding == nil or binding == "" then
		return "Unbound"
	end
	return ControllerBindingsUIBindingLabels[binding] or tostring(binding)
end

local function ControllerBindingsUINormalizeBindingName(binding)
	local text = string.lower(tostring(binding or ""))
	text = string.gsub(text, "[%s%-%_/]", "")
	return text
end

function ControllerBindingsUIBindingToControlId(bindingName)
	return ControllerBindingsUIControlIdMap[ControllerBindingsUINormalizeBindingName(bindingName)]
end

local function ControllerBindingsUIBindingToControlIds(bindingName)
	local ids = {}
	local text = tostring(bindingName or "")
	for part in string.gmatch(text, "[^+]+") do
		local controlId = ControllerBindingsUIBindingToControlId(part)
		if controlId then
			ids[controlId] = true
			if controlId == "leftStickX" or controlId == "leftStickY" then
				ids.leftStick = true
			elseif controlId == "rightStickX" or controlId == "rightStickY" then
				ids.rightStick = true
			end
		end
	end
	return ids
end

local function ControllerBindingsUIDisplayGroup(def)
	if def.action == "pitchModifier" then
		return "Camera"
	elseif def.action == "commandLayer" then
		return "Tactical"
	elseif def.action == "queueModifier" then
		return "Queue"
	elseif def.action == "controlGroupModifier" then
		return "Idle / Groups"
	elseif def.group == "Radials" then
		return "Build"
	end
	return def.group or "Advanced"
end

local function ControllerBindingsUIDisplayLabel(def)
	return ControllerBindingsUILabelOverrides[def.action] or def.label or def.action or "Unknown"
end

local function ControllerBindingsUIAddAction(groupsByName, def)
	local groupName = ControllerBindingsUIDisplayGroup(def)
	local group = groupsByName[groupName]
	if not group then
		group = { name = groupName, actions = {} }
		groupsByName[groupName] = group
	end
	group.actions[#group.actions + 1] = {
		action = def.action,
		label = ControllerBindingsUIDisplayLabel(def),
		default = def.default,
		group = groupName,
		sourceGroup = def.group,
		readOnly = def.readOnly == true,
		description = def.description or ControllerBindingsUIDescriptions[def.action] or "No help text yet.",
	}
end

local function ControllerBindingsUIRebuildCategories()
	local groupsByName = {}
	for i = 1, #ControllerBindingsUIReadOnlyCameraDefs do
		ControllerBindingsUIAddAction(groupsByName, ControllerBindingsUIReadOnlyCameraDefs[i])
	end

	local ok, defs = ControllerBindingsUISafeCall("GetBindingDefinitions")
	if ok and type(defs) == "table" then
		for i = 1, #defs do
			if type(defs[i]) == "table" and defs[i].action then
				ControllerBindingsUIAddAction(groupsByName, defs[i])
			end
		end
	end

	local categories = {}
	for _, group in pairs(groupsByName) do
		categories[#categories + 1] = group
	end
	table.sort(categories, function(a, b)
		local orderA = ControllerBindingsUIGroupOrder[a.name] or 100
		local orderB = ControllerBindingsUIGroupOrder[b.name] or 100
		if orderA == orderB then
			return a.name < b.name
		end
		return orderA < orderB
	end)

	ControllerBindingsUI.categories = categories
	if ControllerBindingsUI.categoryIndex > #categories then
		ControllerBindingsUI.categoryIndex = math.max(1, #categories)
	end
	local category = categories[ControllerBindingsUI.categoryIndex]
	if category and ControllerBindingsUI.actionIndex > #category.actions then
		ControllerBindingsUI.actionIndex = math.max(1, #category.actions)
	end
end

local function ControllerBindingsUISelectedCategory()
	return ControllerBindingsUI.categories[ControllerBindingsUI.categoryIndex]
end

local function ControllerBindingsUISelectedAction()
	local category = ControllerBindingsUISelectedCategory()
	return category and category.actions[ControllerBindingsUI.actionIndex]
end

local function ControllerBindingsUIGetCurrentBinding(action)
	if not action then
		return nil
	end
	if action.readOnly then
		return action.default
	end
	local ok, binding = ControllerBindingsUISafeCall("GetBinding", action.action)
	if ok then
		return binding
	end
	return nil
end

local function ControllerBindingsUIFindConflict(inputName, targetActionName)
	for i = 1, #ControllerBindingsUI.categories do
		local category = ControllerBindingsUI.categories[i]
		for j = 1, #category.actions do
			local action = category.actions[j]
			if not action.readOnly and action.action ~= targetActionName then
				local binding = ControllerBindingsUIGetCurrentBinding(action)
				if binding == inputName then
					return action
				end
			end
		end
	end
	return nil
end

local function ControllerBindingsUISetToast(text)
	ControllerBindingsUI.toast = tostring(text or "")
end

local function ControllerBindingsUIApplyBinding(action, inputName, allowDuplicate)
	if not action then
		return
	end
	if action.readOnly then
		ControllerBindingsUISetToast("Read-only camera axis")
		return
	end
	local conflict = (not allowDuplicate) and ControllerBindingsUIFindConflict(inputName, action.action) or nil
	if conflict then
		ControllerBindingsUI.modal = "conflict"
		ControllerBindingsUI.pendingInput = inputName
		ControllerBindingsUI.conflictAction = conflict
		ControllerBindingsUISetToast("Binding conflict")
		return
	end
	local ok = ControllerBindingsUISafeCall("SetBinding", action.action, inputName)
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.captureAction = nil
	ControllerBindingsUI.pendingInput = nil
	ControllerBindingsUI.conflictAction = nil
	ControllerBindingsUISetToast(ok and ("Bound " .. action.label .. " to " .. ControllerBindingsUIDisplayBinding(inputName)) or "SetBinding failed")
end

local function ControllerBindingsUIOpen()
	ControllerBindingsUI.open = true
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.captureAction = nil
	ControllerBindingsUISetGameplayBlocked(true)
	ControllerBindingsUIRefreshMissingAPI()
	ControllerBindingsUIRebuildCategories()
	ControllerBindingsUISetToast("Binding editor open")
end

local function ControllerBindingsUIClose()
	ControllerBindingsUI.open = false
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.captureAction = nil
	ControllerBindingsUI.pendingInput = nil
	ControllerBindingsUI.conflictAction = nil
	ControllerBindingsUISetGameplayBlocked(false)
	ControllerBindingsUISetToast("Closed")
end

local function ControllerBindingsUIToggle()
	if ControllerBindingsUI.open then
		ControllerBindingsUIClose()
	else
		ControllerBindingsUIOpen()
	end
end

local function ControllerBindingsUISelectCategory(index)
	local count = #ControllerBindingsUI.categories
	if count <= 0 then
		ControllerBindingsUI.categoryIndex = 1
		ControllerBindingsUI.actionIndex = 1
		return
	end
	ControllerBindingsUI.categoryIndex = ((index - 1) % count) + 1
	ControllerBindingsUI.actionIndex = 1
end

local function ControllerBindingsUISelectAction(index)
	local category = ControllerBindingsUISelectedCategory()
	local count = category and #category.actions or 0
	if count <= 0 then
		ControllerBindingsUI.actionIndex = 1
		return
	end
	ControllerBindingsUI.actionIndex = ((index - 1) % count) + 1
end

local function ControllerBindingsUIStartCapture()
	local action = ControllerBindingsUISelectedAction()
	if not action then
		return
	end
	if action.readOnly then
		ControllerBindingsUISetToast("Read-only camera axis")
		return
	end
	ControllerBindingsUI.captureAction = action
	ControllerBindingsUI.captureStartTime = spGetGameSeconds and spGetGameSeconds() or os.clock()
	ControllerBindingsUI.captureGateReleased = false
	ControllerBindingsUI.modal = "capture"
	ControllerBindingsUISetToast("Listening for input")
end

local function ControllerBindingsUICancelModal()
	ControllerBindingsUI.modal = nil
	ControllerBindingsUI.captureAction = nil
	ControllerBindingsUI.pendingInput = nil
	ControllerBindingsUI.conflictAction = nil
	ControllerBindingsUISetToast("Cancelled")
end

local function ControllerBindingsUIResetSelected()
	local action = ControllerBindingsUISelectedAction()
	if not action then
		return
	end
	if action.readOnly then
		ControllerBindingsUISetToast("Read-only camera axis")
		return
	end
	local ok = ControllerBindingsUISafeCall("ResetBinding", action.action)
	ControllerBindingsUISetToast(ok and ("Reset " .. action.label) or "ResetBinding failed")
end

local function ControllerBindingsUIResetAll()
	ControllerBindingsUI.modal = "resetAll"
	ControllerBindingsUISetToast("Confirm reset all")
end

local function ControllerBindingsUIConfirmResetAll()
	local ok = ControllerBindingsUISafeCall("ResetAllBindings")
	ControllerBindingsUI.modal = nil
	ControllerBindingsUISetToast(ok and "All bindings reset" or "ResetAllBindings failed")
end

local function ControllerBindingsUIIsPressed(inputName)
	local ok, pressed = ControllerBindingsUISafeCall("IsInputPressed", inputName)
	return ok and pressed == true
end

local function ControllerBindingsUIIsDown(inputName)
	local ok, down = ControllerBindingsUISafeCall("IsInputDown", inputName)
	return ok and down == true
end

local function ControllerBindingsUIAnyCaptureInputDown()
	for i = 1, #ControllerBindingsUICaptureInputs do
		if ControllerBindingsUIIsDown(ControllerBindingsUICaptureInputs[i]) then
			return true
		end
	end
	return false
end

local function ControllerBindingsUIHandleCaptureInput()
	if ControllerBindingsUIIsPressed("B") then
		ControllerBindingsUICancelModal()
		return true
	end

	local now = spGetGameSeconds and spGetGameSeconds() or os.clock()
	if not ControllerBindingsUI.captureGateReleased then
		if not ControllerBindingsUIAnyCaptureInputDown() and (now - ControllerBindingsUI.captureStartTime) >= 0.15 then
			ControllerBindingsUI.captureGateReleased = true
		end
		return true
	end

	local ok, inputName = ControllerBindingsUISafeCall("GetPressedBindingInput")
	if ok and inputName then
		ControllerBindingsUIApplyBinding(ControllerBindingsUI.captureAction, inputName, false)
	end
	return true
end

local function ControllerBindingsUIHandleConflictInput()
	if ControllerBindingsUIIsPressed("B") then
		ControllerBindingsUICancelModal()
	elseif ControllerBindingsUIIsPressed("X") then
		ControllerBindingsUIApplyBinding(ControllerBindingsUI.captureAction, ControllerBindingsUI.pendingInput, true)
	elseif ControllerBindingsUIIsPressed("A") then
		ControllerBindingsUISetToast("Replace unsupported by current API; use X to allow duplicate")
	end
	return true
end

local function ControllerBindingsUIHandleResetAllInput()
	if ControllerBindingsUIIsPressed("A") then
		ControllerBindingsUIConfirmResetAll()
	elseif ControllerBindingsUIIsPressed("B") then
		ControllerBindingsUICancelModal()
	end
	return true
end

local function ControllerBindingsUIHandleControllerInput()
	if not ControllerBindingsUI.open or #ControllerBindingsUI.missing > 0 then
		return false
	end
	if ControllerBindingsUI.modal == "capture" then
		return ControllerBindingsUIHandleCaptureInput()
	elseif ControllerBindingsUI.modal == "conflict" then
		return ControllerBindingsUIHandleConflictInput()
	elseif ControllerBindingsUI.modal == "resetAll" then
		return ControllerBindingsUIHandleResetAllInput()
	end

	if ControllerBindingsUIIsPressed("B") then
		ControllerBindingsUIClose()
	elseif ControllerBindingsUIIsPressed("A") then
		ControllerBindingsUIStartCapture()
	elseif ControllerBindingsUIIsPressed("X") then
		ControllerBindingsUIResetSelected()
	elseif ControllerBindingsUIIsPressed("Y") then
		ControllerBindingsUIResetAll()
	elseif ControllerBindingsUIIsPressed("dpadUp") then
		ControllerBindingsUISelectAction(ControllerBindingsUI.actionIndex - 1)
	elseif ControllerBindingsUIIsPressed("dpadDown") then
		ControllerBindingsUISelectAction(ControllerBindingsUI.actionIndex + 1)
	elseif ControllerBindingsUIIsPressed("dpadLeft") or ControllerBindingsUIIsPressed("LB") then
		ControllerBindingsUISelectCategory(ControllerBindingsUI.categoryIndex - 1)
	elseif ControllerBindingsUIIsPressed("dpadRight") or ControllerBindingsUIIsPressed("RB") then
		ControllerBindingsUISelectCategory(ControllerBindingsUI.categoryIndex + 1)
	end
	return true
end

local function ControllerBindingsUINormalizeKeyName(value)
	local text = string.lower(tostring(value or ""))
	text = string.gsub(text, "[%s%-%_]", "")
	return text
end

local function ControllerBindingsUIKeyMatches(key, label, candidates)
	local normalizedLabel = ControllerBindingsUINormalizeKeyName(label)
	for i = 1, #candidates do
		local candidate = candidates[i]
		if type(candidate) == "number" and key == candidate then
			return true
		elseif type(candidate) == "string" then
			if normalizedLabel ~= "" and normalizedLabel == ControllerBindingsUINormalizeKeyName(candidate) then
				return true
			end
			if KEYSYMS then
				local keySym = KEYSYMS[candidate] or KEYSYMS[string.upper(candidate)]
				if keySym ~= nil and key == keySym then
					return true
				end
			end
			if type(Spring.GetKeyCode) == "function" then
				local ok, keyCode = pcall(Spring.GetKeyCode, candidate)
				if ok and keyCode ~= nil and key == keyCode then
					return true
				end
			end
		end
	end
	return false
end

local function ControllerBindingsUIDrawRect(x1, y1, x2, y2, color)
	glColor(color[1], color[2], color[3], color[4])
	glRect(x1, y1, x2, y2)
end

local function ControllerBindingsUIDrawOutline(x1, y1, x2, y2, color)
	glColor(color[1], color[2], color[3], color[4])
	glLineWidth(1.5)
	glBeginEnd(GL_LINE_LOOP, function()
		glVertex(x1, y1)
		glVertex(x2, y1)
		glVertex(x2, y2)
		glVertex(x1, y2)
	end)
	glLineWidth(1)
end

local function ControllerBindingsUIDrawText(text, x, y, size, color, opts)
	glColor(0, 0, 0, 0.55)
	glText(tostring(text or ""), x + 1, y - 1, size, opts or "")
	glColor(color[1], color[2], color[3], color[4])
	glText(tostring(text or ""), x, y, size, opts or "")
end

local function ControllerBindingsUIDrawPanel(x1, y1, x2, y2, title)
	ControllerBindingsUIDrawRect(x1, y1, x2, y2, { 0.045, 0.06, 0.075, 0.88 })
	ControllerBindingsUIDrawOutline(x1, y1, x2, y2, { 0.26, 0.37, 0.45, 0.95 })
	if title then
		ControllerBindingsUIDrawText(title, x1 + 18, y2 - 31, 18, { 0.84, 0.93, 0.98, 1 }, "o")
	end
end

local function ControllerBindingsUIDrawChip(controlId, label, x1, y1, x2, y2, activeIds)
	local active = activeIds and activeIds[controlId]
	local fill = active and { 0.15, 0.45, 0.48, 0.96 } or { 0.085, 0.105, 0.13, 0.94 }
	local outline = active and { 0.55, 0.96, 0.92, 1 } or { 0.28, 0.36, 0.44, 0.9 }
	ControllerBindingsUIDrawRect(x1, y1, x2, y2, fill)
	ControllerBindingsUIDrawOutline(x1, y1, x2, y2, outline)
	ControllerBindingsUIDrawText(label, (x1 + x2) * 0.5, (y1 + y2) * 0.5 - 5, 15, { 0.94, 0.98, 1, 1 }, "oc")
end

local function ControllerBindingsUIDrawModalButton(id, label, x1, y1, x2, y2)
	ControllerBindingsUIDrawRect(x1, y1, x2, y2, { 0.09, 0.13, 0.16, 0.96 })
	ControllerBindingsUIDrawOutline(x1, y1, x2, y2, { 0.34, 0.48, 0.58, 0.95 })
	ControllerBindingsUIDrawText(label, (x1 + x2) * 0.5, (y1 + y2) * 0.5 - 5, 14, { 0.9, 0.97, 1, 1 }, "oc")
	ControllerBindingsUI.layout.modalButtons[#ControllerBindingsUI.layout.modalButtons + 1] = { id = id, x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

local function ControllerBindingsUIDrawHeader(x1, y2_header, x2, vsx, vsy)
	if USE_SAFE_AREA_LAYOUT then
		local h = 70
		ControllerBindingsUIDrawRect(x1, y2_header - h, x2, y2_header, { 0.025, 0.035, 0.047, 0.96 })
		ControllerBindingsUIDrawOutline(x1, y2_header - h, x2, y2_header, { 0.26, 0.37, 0.45, 0.95 })
		ControllerBindingsUIDrawText("BAR Controller Bindings", x1 + 20, y2_header - 30, 22, { 0.93, 0.98, 1, 1 }, "o")
		ControllerBindingsUIDrawText("Xbox Controller Support v0.4.0 pre-alpha", x1 + 22, y2_header - 52, 13, { 0.62, 0.75, 0.84, 1 }, "o")
		ControllerBindingsUIDrawText(ControllerBindingsUI.toast or "", x2 - 80, y2_header - 35, 14, { 0.78, 0.92, 0.98, 1 }, "or")
	else
		ControllerBindingsUIDrawRect(0, vsy - 92, vsx, vsy, { 0.025, 0.035, 0.047, 0.96 })
		ControllerBindingsUIDrawText("BAR Controller Bindings", 54, vsy - 42, 30, { 0.93, 0.98, 1, 1 }, "o")
		ControllerBindingsUIDrawText("Xbox Controller Support v0.4.0 pre-alpha", 56, vsy - 72, 16, { 0.62, 0.75, 0.84, 1 }, "o")
		ControllerBindingsUIDrawText(ControllerBindingsUI.toast or "", vsx - 54, vsy - 56, 15, { 0.78, 0.92, 0.98, 1 }, "or")
	end
end

local function ControllerBindingsUIDrawTabs(x1, y2_header, x2, vsx, vsy)
	local tabs = ControllerBindingsUI.layout.tabs
	for i = 1, #tabs do
		tabs[i] = nil
	end

	local start_x = 54
	local y_tab_top = y2_header - 15
	local h = 38

	if USE_SAFE_AREA_LAYOUT then
		start_x = x1 + 10
		y_tab_top = y2_header - 8
	end

	local x = start_x
	local y1 = y_tab_top - h
	local lowest_y = y1

	for i = 1, #ControllerBindingsUI.categories do
		local category = ControllerBindingsUI.categories[i]
		local w = math.max(96, math.min(168, 42 + string.len(category.name) * 8))

		if USE_SAFE_AREA_LAYOUT and (x + w > x2 - 10) then
			-- Wrap to the next row
			x = start_x
			y_tab_top = y_tab_top - h - 6
			y1 = y_tab_top - h
			if y1 < lowest_y then
				lowest_y = y1
			end
		end

		local active = i == ControllerBindingsUI.categoryIndex
		ControllerBindingsUIDrawRect(x, y1, x + w, y1 + h, active and { 0.12, 0.26, 0.34, 0.96 } or { 0.06, 0.075, 0.095, 0.9 })
		ControllerBindingsUIDrawOutline(x, y1, x + w, y1 + h, active and { 0.46, 0.78, 0.95, 1 } or { 0.22, 0.30, 0.37, 0.9 })
		ControllerBindingsUIDrawText(category.name, x + w * 0.5, y1 + 12, 14, { 0.9, 0.97, 1, 1 }, "oc")
		tabs[#tabs + 1] = { x1 = x, y1 = y1, x2 = x + w, y2 = y1 + h, index = i }
		x = x + w + 8
	end

	return lowest_y
end

local function ControllerBindingsUIDrawControllerOverview(x1, y1, x2, y2)
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, "Controller Overview")
	local action = ControllerBindingsUISelectedAction()
	local binding = ControllerBindingsUIGetCurrentBinding(action) or action and action.default
	local activeIds = ControllerBindingsUIBindingToControlIds(binding)
	local cx = (x1 + x2) * 0.5
	local cy = (y1 + y2) * 0.5 - 10
	local w = x2 - x1

	ControllerBindingsUIDrawChip("lt", "LT", x1 + 42, y2 - 86, x1 + 152, y2 - 50, activeIds)
	ControllerBindingsUIDrawChip("lb", "LB", x1 + 52, y2 - 130, x1 + 162, y2 - 94, activeIds)
	ControllerBindingsUIDrawChip("rt", "RT", x2 - 152, y2 - 86, x2 - 42, y2 - 50, activeIds)
	ControllerBindingsUIDrawChip("rb", "RB", x2 - 162, y2 - 130, x2 - 52, y2 - 94, activeIds)

	ControllerBindingsUIDrawChip("backView", "Back/View", cx - 150, y2 - 160, cx - 44, y2 - 126, activeIds)
	ControllerBindingsUIDrawChip("menuStart", "Menu/Start", cx + 44, y2 - 160, cx + 150, y2 - 126, activeIds)

	ControllerBindingsUIDrawChip("leftStick", "Left Stick", x1 + w * 0.17, cy - 10, x1 + w * 0.34, cy + 55, activeIds)
	ControllerBindingsUIDrawChip("rightStick", "Right Stick", x1 + w * 0.59, cy - 80, x1 + w * 0.78, cy - 15, activeIds)
	ControllerBindingsUIDrawChip("rightStickX", "Right Stick X", x1 + w * 0.58, cy - 128, x1 + w * 0.79, cy - 94, activeIds)
	ControllerBindingsUIDrawChip("rightStickY", "Right Stick Y", x1 + w * 0.58, cy - 170, x1 + w * 0.79, cy - 136, activeIds)

	local dx = x1 + w * 0.20
	local dy = cy - 150
	ControllerBindingsUIDrawChip("dpadUp", "D-pad Up", dx + 46, dy + 68, dx + 134, dy + 102, activeIds)
	ControllerBindingsUIDrawChip("dpadLeft", "D-pad Left", dx - 4, dy + 30, dx + 94, dy + 64, activeIds)
	ControllerBindingsUIDrawChip("dpadRight", "D-pad Right", dx + 94, dy + 30, dx + 198, dy + 64, activeIds)
	ControllerBindingsUIDrawChip("dpadDown", "D-pad Down", dx + 42, dy - 8, dx + 142, dy + 26, activeIds)

	local fx = x2 - 220
	local fy = cy + 10
	ControllerBindingsUIDrawChip("y", "Y", fx + 70, fy + 72, fx + 122, fy + 124, activeIds)
	ControllerBindingsUIDrawChip("x", "X", fx + 14, fy + 18, fx + 66, fy + 70, activeIds)
	ControllerBindingsUIDrawChip("b", "B", fx + 126, fy + 18, fx + 178, fy + 70, activeIds)
	ControllerBindingsUIDrawChip("a", "A", fx + 70, fy - 36, fx + 122, fy + 16, activeIds)
end

local function ControllerBindingsUIDrawActionList(x1, y1, x2, y2)
	local rows = ControllerBindingsUI.layout.rows
	for i = 1, #rows do
		rows[i] = nil
	end
	local category = ControllerBindingsUISelectedCategory()
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, category and category.name or "Actions")
	if not category then
		return
	end
	local rowH = 34
	local rowY = y2 - 70
	for i = 1, #category.actions do
		local action = category.actions[i]
		if rowY < y1 + 18 then
			break
		end
		local selected = i == ControllerBindingsUI.actionIndex
		local binding = ControllerBindingsUIGetCurrentBinding(action)
		if binding == nil then
			binding = action.default
		end
		ControllerBindingsUIDrawRect(x1 + 12, rowY - rowH + 4, x2 - 12, rowY + 3, selected and { 0.13, 0.28, 0.34, 0.95 } or { 0.07, 0.085, 0.105, 0.72 })
		if selected then
			ControllerBindingsUIDrawOutline(x1 + 12, rowY - rowH + 4, x2 - 12, rowY + 3, { 0.46, 0.88, 0.96, 1 })
		end
		ControllerBindingsUIDrawText(action.label, x1 + 24, rowY - 19, 14, { 0.92, 0.97, 1, 1 }, "o")
		local suffix = action.readOnly and " (view)" or ""
		ControllerBindingsUIDrawText(ControllerBindingsUIDisplayBinding(binding) .. suffix, x2 - 24, rowY - 19, 13, { 0.78, 0.9, 0.96, 1 }, "or")
		rows[#rows + 1] = { x1 = x1 + 12, y1 = rowY - rowH + 4, x2 = x2 - 12, y2 = rowY + 3, index = i }
		rowY = rowY - rowH - 3
	end
end

local function ControllerBindingsUIDrawDetails(x1, y1, x2, y2)
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, "Selected Action")
	local action = ControllerBindingsUISelectedAction()
	if not action then
		ControllerBindingsUIDrawText("No action selected", x1 + 20, y2 - 74, 16, { 0.92, 0.96, 1, 1 }, "o")
		return
	end
	local binding = ControllerBindingsUIGetCurrentBinding(action)
	if binding == nil then
		binding = action.default
	end
	local y = y2 - 76
	ControllerBindingsUIDrawText(action.label, x1 + 20, y, 21, { 0.94, 0.99, 1, 1 }, "o")
	y = y - 42
	ControllerBindingsUIDrawText("Action: " .. tostring(action.action), x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	y = y - 28
	ControllerBindingsUIDrawText("Group: " .. tostring(action.group), x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	y = y - 28
	ControllerBindingsUIDrawText("Default: " .. ControllerBindingsUIDisplayBinding(action.default), x1 + 20, y, 14, { 0.72, 0.84, 0.9, 1 }, "o")
	y = y - 28
	ControllerBindingsUIDrawText("Current: " .. ControllerBindingsUIDisplayBinding(binding), x1 + 20, y, 16, { 0.86, 0.98, 1, 1 }, "o")
	y = y - 34
	ControllerBindingsUIDrawText("Control ID: " .. tostring(ControllerBindingsUIBindingToControlId(binding) or "none"), x1 + 20, y, 13, { 0.62, 0.75, 0.82, 1 }, "o")
	y = y - 45
	ControllerBindingsUIDrawText(action.description or "", x1 + 20, y, 13, { 0.82, 0.9, 0.94, 1 }, "o")
	y = y - 34
	if action.readOnly then
		ControllerBindingsUIDrawText("Read-only display row. Not remappable yet.", x1 + 20, y, 13, { 1, 0.78, 0.46, 1 }, "o")
	end
end

local function ControllerBindingsUIDrawFooter(x1, y1, x2, vsx)
	if USE_SAFE_AREA_LAYOUT then
		ControllerBindingsUIDrawRect(x1, y1, x2, y1 + 40, { 0.025, 0.035, 0.047, 0.96 })
		ControllerBindingsUIDrawOutline(x1, y1, x2, y1 + 40, { 0.26, 0.37, 0.45, 0.95 })
		ControllerBindingsUIDrawText("A/Enter Rebind  |  X/R Reset  |  Y Reset All  |  B/Esc Close  |  LB/RB or Left/Right Category  |  Delete Clear: not supported yet", (x1 + x2) * 0.5, y1 + 13, 13, { 0.78, 0.9, 0.96, 1 }, "oc")
	else
		ControllerBindingsUIDrawRect(0, 0, vsx, 50, { 0.025, 0.035, 0.047, 0.96 })
		ControllerBindingsUIDrawText("A/Enter Rebind  |  X/R Reset  |  Y Reset All  |  B/Esc Close  |  LB/RB or Left/Right Category  |  Delete Clear: not supported yet", vsx * 0.5, 18, 14, { 0.78, 0.9, 0.96, 1 }, "oc")
	end
end

local function ControllerBindingsUIDrawWarning(vsx, vsy)
	ControllerBindingsUIDrawRect(0, 0, vsx, vsy, { 0, 0, 0, 0.68 })
	local w = math.min(760, vsx - 140)
	if USE_SAFE_AREA_LAYOUT then
		w = math.min(760, (vsx - SAFE_RIGHT_MARGIN - SAFE_LEFT_MARGIN) - 40)
	end
	local h = 240
	local x1, y1
	if USE_SAFE_AREA_LAYOUT then
		local cx = (SAFE_LEFT_MARGIN + vsx - SAFE_RIGHT_MARGIN) * 0.5
		local cy = (SAFE_BOTTOM_MARGIN + vsy - SAFE_TOP_MARGIN) * 0.5
		x1 = cx - w * 0.5
		y1 = cy - h * 0.5
	else
		x1 = (vsx - w) * 0.5
		y1 = (vsy - h) * 0.5
	end
	ControllerBindingsUIDrawPanel(x1, y1, x1 + w, y1 + h, "Controller Support API Missing")
	if not WG or not WG.BARControllerSupport then
		ControllerBindingsUIDrawText("Controller support API not available. Enable gui_controller_camera_test.lua first.", x1 + 24, y1 + h - 82, 17, { 1, 0.83, 0.62, 1 }, "o")
	else
		ControllerBindingsUIDrawText("Controller support API is incomplete. Missing:", x1 + 24, y1 + h - 82, 17, { 1, 0.83, 0.62, 1 }, "o")
		ControllerBindingsUIDrawText(table.concat(ControllerBindingsUI.missing, ", "), x1 + 24, y1 + h - 122, 14, { 0.9, 0.95, 1, 1 }, "o")
	end
	ControllerBindingsUIDrawText("Esc or B closes this editor.", x1 + 24, y1 + 34, 14, { 0.72, 0.84, 0.9, 1 }, "o")
end

local function ControllerBindingsUIDrawModal(vsx, vsy)
	if not ControllerBindingsUI.modal then
		return
	end
	ControllerBindingsUIDrawRect(0, 0, vsx, vsy, { 0, 0, 0, 0.62 })
	local w = 560
	local h = 250
	local x1, y1, x2, y2
	if USE_SAFE_AREA_LAYOUT then
		local cx = (SAFE_LEFT_MARGIN + vsx - SAFE_RIGHT_MARGIN) * 0.5
		local cy = (SAFE_BOTTOM_MARGIN + vsy - SAFE_TOP_MARGIN) * 0.5
		x1 = cx - w * 0.5
		y1 = cy - h * 0.5
		x2 = x1 + w
		y2 = y1 + h
	else
		x1 = (vsx - w) * 0.5
		y1 = (vsy - h) * 0.5
		x2 = x1 + w
		y2 = y1 + h
	end
	ControllerBindingsUIDrawPanel(x1, y1, x2, y2, "Controller Bindings")
	ControllerBindingsUI.layout.modalButtons = {}

	if ControllerBindingsUI.modal == "capture" then
		local action = ControllerBindingsUI.captureAction
		ControllerBindingsUIDrawText("Rebind: " .. tostring(action and action.label or "Unknown"), x1 + 28, y2 - 78, 21, { 0.94, 0.99, 1, 1 }, "o")
		ControllerBindingsUIDrawText("Current: " .. ControllerBindingsUIDisplayBinding(action and ControllerBindingsUIGetCurrentBinding(action)), x1 + 28, y2 - 118, 15, { 0.76, 0.88, 0.94, 1 }, "o")
		ControllerBindingsUIDrawText("Press a controller input...", x1 + 28, y2 - 162, 18, { 0.72, 0.98, 0.95, 1 }, "o")
		ControllerBindingsUIDrawText("B / Escape: Cancel", x1 + 28, y1 + 34, 14, { 0.74, 0.84, 0.9, 1 }, "o")
		ControllerBindingsUIDrawModalButton("cancel", "Cancel", x2 - 148, y1 + 22, x2 - 28, y1 + 58)
	elseif ControllerBindingsUI.modal == "conflict" then
		ControllerBindingsUIDrawText("This input is already assigned to " .. tostring(ControllerBindingsUI.conflictAction and ControllerBindingsUI.conflictAction.label or "another action") .. ".", x1 + 28, y2 - 82, 16, { 1, 0.84, 0.64, 1 }, "o")
		ControllerBindingsUIDrawText("Input: " .. ControllerBindingsUIDisplayBinding(ControllerBindingsUI.pendingInput), x1 + 28, y2 - 122, 16, { 0.9, 0.98, 1, 1 }, "o")
		ControllerBindingsUIDrawText("Replace needs a clear-binding API and is not enabled yet.", x1 + 28, y2 - 156, 13, { 0.72, 0.84, 0.9, 1 }, "o")
		ControllerBindingsUIDrawModalButton("replace", "Replace", x1 + 28, y1 + 22, x1 + 158, y1 + 58)
		ControllerBindingsUIDrawModalButton("duplicate", "Allow Duplicate", x1 + 174, y1 + 22, x1 + 344, y1 + 58)
		ControllerBindingsUIDrawModalButton("cancel", "Cancel", x2 - 148, y1 + 22, x2 - 28, y1 + 58)
	elseif ControllerBindingsUI.modal == "resetAll" then
		ControllerBindingsUIDrawText("Reset all controller bindings?", x1 + 28, y2 - 92, 22, { 0.94, 0.99, 1, 1 }, "o")
		ControllerBindingsUIDrawText("A / Enter confirms. B / Escape cancels.", x1 + 28, y2 - 136, 16, { 0.76, 0.88, 0.94, 1 }, "o")
		ControllerBindingsUIDrawModalButton("resetAll", "Reset All", x1 + 28, y1 + 22, x1 + 158, y1 + 58)
		ControllerBindingsUIDrawModalButton("cancel", "Cancel", x2 - 148, y1 + 22, x2 - 28, y1 + 58)
	end
end

local function ControllerBindingsUIDrawMain()
	local vsx, vsy = spGetViewGeometry()

	local safe_x1 = 54
	local safe_x2 = vsx - 54
	local safe_y1 = 0
	local safe_y2 = vsy

	if USE_SAFE_AREA_LAYOUT then
		safe_x1 = SAFE_LEFT_MARGIN
		safe_x2 = vsx - SAFE_RIGHT_MARGIN
		safe_y1 = SAFE_BOTTOM_MARGIN
		safe_y2 = vsy - SAFE_TOP_MARGIN
	end

	local close_x1, close_y1, close_x2, close_y2
	if USE_SAFE_AREA_LAYOUT then
		close_x1 = safe_x2 - 60
		close_y1 = safe_y2 - 53
		close_x2 = safe_x2 - 10
		close_y2 = safe_y2 - 13
	else
		close_x1 = vsx - 104
		close_y1 = vsy - 78
		close_x2 = vsx - 54
		close_y2 = vsy - 32
	end
	ControllerBindingsUI.layout.close = { x1 = close_x1, y1 = close_y1, x2 = close_x2, y2 = close_y2 }

	ControllerBindingsUIDrawRect(0, 0, vsx, vsy, { 0.012, 0.018, 0.026, 0.94 })
	ControllerBindingsUIDrawHeader(safe_x1, safe_y2, safe_x2, vsx, vsy)
	ControllerBindingsUIDrawChip("close", "X", close_x1, close_y1, close_x2, close_y2, {})

	if #ControllerBindingsUI.missing > 0 then
		ControllerBindingsUIDrawWarning(vsx, vsy)
		return
	end

	local lowest_y = ControllerBindingsUIDrawTabs(safe_x1, USE_SAFE_AREA_LAYOUT and (safe_y2 - 70) or (vsy - 92), safe_x2, vsx, vsy)

	local top = lowest_y - 15
	local bottom = 66
	local gap = 18

	if USE_SAFE_AREA_LAYOUT then
		bottom = safe_y1 + 50
	end

	local leftW = math.min(850, (safe_x2 - safe_x1) * 0.44)
	local actionW = math.min(500, (safe_x2 - safe_x1) * 0.25)

	local x1 = safe_x1
	local x2 = x1 + leftW
	local ax1 = x2 + gap
	local ax2 = ax1 + actionW
	local dx1 = ax2 + gap
	local dx2 = safe_x2

	if dx2 - dx1 < 330 then
		leftW = math.max(450, (safe_x2 - safe_x1) * 0.38)
		x2 = x1 + leftW
		ax1 = x2 + gap
		ax2 = math.min(safe_x2 - 300, ax1 + actionW)
		dx1 = ax2 + gap
	end

	ControllerBindingsUIDrawControllerOverview(x1, bottom, x2, top)
	ControllerBindingsUIDrawActionList(ax1, bottom, ax2, top)
	ControllerBindingsUIDrawDetails(dx1, bottom, dx2, top)
	ControllerBindingsUIDrawFooter(safe_x1, safe_y1, safe_x2, vsx)
	ControllerBindingsUIDrawModal(vsx, vsy)
end

local function ControllerBindingsUIPointInside(hit, x, y)
	return hit and x >= hit.x1 and x <= hit.x2 and y >= hit.y1 and y <= hit.y2
end

local function ControllerBindingsUIAction()
	ControllerBindingsUIToggle()
	return true
end

function widget:Initialize()
	if widgetHandler and widgetHandler.AddAction then
		widgetHandler:AddAction("bar_controller_bindings", ControllerBindingsUIAction, nil, "t")
	end
	WG.BARControllerBindingsUI = WG.BARControllerBindingsUI or {}
	WG.BARControllerBindingsUI.Toggle = ControllerBindingsUIToggle
	WG.BARControllerBindingsUI.Open = ControllerBindingsUIOpen
	WG.BARControllerBindingsUI.Close = ControllerBindingsUIClose
	ControllerBindingsUIRefreshMissingAPI()
	ControllerBindingsUIRebuildCategories()
end

function widget:Shutdown()
	ControllerBindingsUISetGameplayBlocked(false)
	if widgetHandler and widgetHandler.RemoveAction then
		widgetHandler:RemoveAction("bar_controller_bindings")
	end
	if WG and WG.BARControllerBindingsUI then
		WG.BARControllerBindingsUI.Toggle = nil
		WG.BARControllerBindingsUI.Open = nil
		WG.BARControllerBindingsUI.Close = nil
		WG.BARControllerBindingsUI = nil
	end
end

function widget:TextCommand(command)
	local normalized = ControllerBindingsUINormalizeKeyName(command)
	if normalized == "barcontrollerbindings" then
		ControllerBindingsUIToggle()
		return true
	end
	return false
end

function widget:Update()
	if not ControllerBindingsUI.open then
		return
	end
	ControllerBindingsUISetGameplayBlocked(true)
	ControllerBindingsUIRefreshMissingAPI()
	ControllerBindingsUIHandleControllerInput()
end

function widget:KeyPress(key, mods, isRepeat, label)
	if not ControllerBindingsUI.open or isRepeat then
		return false
	end
	if ControllerBindingsUI.modal == "capture" then
		if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
			ControllerBindingsUICancelModal()
			return true
		end
		return true
	elseif ControllerBindingsUI.modal == "conflict" then
		if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
			ControllerBindingsUICancelModal()
		elseif ControllerBindingsUIKeyMatches(key, label, { "D", "d" }) then
			ControllerBindingsUIApplyBinding(ControllerBindingsUI.captureAction, ControllerBindingsUI.pendingInput, true)
		elseif ControllerBindingsUIKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", 13, 271 }) then
			ControllerBindingsUISetToast("Replace unsupported by current API; press D to allow duplicate")
		end
		return true
	elseif ControllerBindingsUI.modal == "resetAll" then
		if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
			ControllerBindingsUICancelModal()
		elseif ControllerBindingsUIKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", 13, 271 }) then
			ControllerBindingsUIConfirmResetAll()
		end
		return true
	end

	if ControllerBindingsUIKeyMatches(key, label, { "ESCAPE", "Escape", "escape", "ESC", "esc", 27 }) then
		ControllerBindingsUIClose()
	elseif ControllerBindingsUIKeyMatches(key, label, { "UP", "Up", "up", 273 }) then
		ControllerBindingsUISelectAction(ControllerBindingsUI.actionIndex - 1)
	elseif ControllerBindingsUIKeyMatches(key, label, { "DOWN", "Down", "down", 274 }) then
		ControllerBindingsUISelectAction(ControllerBindingsUI.actionIndex + 1)
	elseif ControllerBindingsUIKeyMatches(key, label, { "LEFT", "Left", "left", 276 }) then
		ControllerBindingsUISelectCategory(ControllerBindingsUI.categoryIndex - 1)
	elseif ControllerBindingsUIKeyMatches(key, label, { "RIGHT", "Right", "right", 275 }) then
		ControllerBindingsUISelectCategory(ControllerBindingsUI.categoryIndex + 1)
	elseif ControllerBindingsUIKeyMatches(key, label, { "RETURN", "Return", "return", "ENTER", "Enter", "enter", 13, 271 }) then
		ControllerBindingsUIStartCapture()
	elseif ControllerBindingsUIKeyMatches(key, label, { "R", "r" }) then
		ControllerBindingsUIResetSelected()
	elseif ControllerBindingsUIKeyMatches(key, label, { "DELETE", "Delete", "delete", 127 }) then
		ControllerBindingsUISetToast("Clear not supported by current binding API")
	end
	return true
end

function widget:MousePress(x, y, button)
	if not ControllerBindingsUI.open or button ~= 1 then
		return false
	end
	if ControllerBindingsUIPointInside(ControllerBindingsUI.layout.close, x, y) then
		ControllerBindingsUIClose()
		return true
	end
	for i = 1, #ControllerBindingsUI.layout.modalButtons do
		local hit = ControllerBindingsUI.layout.modalButtons[i]
		if ControllerBindingsUIPointInside(hit, x, y) then
			if hit.id == "cancel" then
				ControllerBindingsUICancelModal()
			elseif hit.id == "duplicate" then
				ControllerBindingsUIApplyBinding(ControllerBindingsUI.captureAction, ControllerBindingsUI.pendingInput, true)
			elseif hit.id == "replace" then
				ControllerBindingsUISetToast("Replace unsupported by current API; use Allow Duplicate")
			elseif hit.id == "resetAll" then
				ControllerBindingsUIConfirmResetAll()
			end
			return true
		end
	end
	for i = 1, #ControllerBindingsUI.layout.tabs do
		local hit = ControllerBindingsUI.layout.tabs[i]
		if ControllerBindingsUIPointInside(hit, x, y) then
			ControllerBindingsUISelectCategory(hit.index)
			return true
		end
	end
	for i = 1, #ControllerBindingsUI.layout.rows do
		local hit = ControllerBindingsUI.layout.rows[i]
		if ControllerBindingsUIPointInside(hit, x, y) then
			ControllerBindingsUISelectAction(hit.index)
			return true
		end
	end
	return true
end

function widget:DrawScreen()
	if not ControllerBindingsUI.open then
		return
	end
	ControllerBindingsUIDrawMain()
	glColor(1, 1, 1, 1)
end
