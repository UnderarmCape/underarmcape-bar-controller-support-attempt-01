--------------------------------------------------------------------------------
-- BAR Controller Support - lean production UI settings and hint runtime
-- Authoring is deliberately implemented by the separately disabled widget.
--------------------------------------------------------------------------------

local Runtime = { SCHEMA_VERSION = 3, REFERENCE_WIDTH = 1920, REFERENCE_HEIGHT = 1080 }

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}; for key, child in pairs(value) do result[key] = copy(child) end; return result
end

local function merge(target, source)
	for key, value in pairs(type(source) == "table" and source or {}) do
		if type(value) == "table" then
			target[key] = type(target[key]) == "table" and target[key] or {}; merge(target[key], value)
		else target[key] = value end
	end
	return target
end

local function clamp(value, low, high) return math.max(low, math.min(high, tonumber(value) or low)) end

local FALLBACK = {
	global = { enabled = true, scale = 1, opacity = 1, fontScale = 1, safeMargin = 16, resolutionAware = true },
	theme = { backgroundR = 0.018, backgroundG = 0.028, backgroundB = 0.04,
		foregroundR = 0.94, foregroundG = 0.98, foregroundB = 1,
		accentR = 0.34, accentG = 0.82, accentB = 0.92, mutedR = 0.36, mutedG = 0.52, mutedB = 0.60,
		dangerR = 0.92, dangerG = 0.28, dangerB = 0.24 },
	components = {
		hints = { enabled = true, x = 0.018, y = 0.035, scale = 1.25, opacity = 1, fontScale = 1.15,
			iconScale = 1.25, spacingScale = 1.10, rowSpacing = 5, columnSpacing = 18, iconTextSpacing = 8, padding = 12,
			maxWidth = 0.52, columns = 2, backgroundOpacity = 0, textOpacity = 1, borderOpacity = 0,
			borderThickness = 0, fadeDuration = 0.18, contextEnterDebounce = 0.14, contextExitGrace = 0.12,
			confirmedModalImmediate = true, presentation = "Glyph + Action Text", showChip = true,
			showActionText = true, showRowBackground = false, showCategoryHeaders = false,
			showContextHeader = false, priorityHiding = true, maxItems = 14, overflow = "Wrap", wrapLines = 2,
			glyphSpacing = 4, glyphOpacity = 1, chordLayout = "Horizontal", textShadowEnabled = true,
			textShadowOpacity = 0.82, textShadowOffsetX = 2, textShadowOffsetY = -2, textShadowSpread = 1,
			glyphShadowEnabled = true, glyphShadowOpacity = 0.74, glyphShadowOffsetX = 2,
			glyphShadowOffsetY = -2, glyphShadowSpread = 1, showHoldIndicator = true,
			holdStyle = "Bold HOLD", holdLabelScale = 1.08, holdColorR = 1, holdColorG = 0.72, holdColorB = 0.22 },
		bindingsButton = { enabled = true, x = 1360 / 1920, y = 1044 / 1080, scale = 1, opacity = 1,
			fontScale = 1, anchor = "bottomleft", width = 110 / 1920, height = 28 / 1080 },
		radials = { enabled = true, scale = 1, opacity = 1, fontScale = 1, iconScale = 1 },
		buildRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		factoryRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		tacticalRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		selectionRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
		visibleSelectionRadial = { enabled = true, x = 0.5, y = 0.5, scale = 1, opacity = 1, fontScale = 1, iconScale = 1, anchor = "center" },
	},
}

local function decode(path)
	if not VFS or type(VFS.LoadFile) ~= "function" or not Json or type(Json.decode) ~= "function" then return nil end
	local ok, raw = pcall(VFS.LoadFile, path, VFS.RAW_FIRST); if not ok or type(raw) ~= "string" then return nil end
	local decodedOK, value = pcall(Json.decode, raw); return decodedOK and type(value) == "table" and value or nil
end

local function valid(document)
	return type(document) == "table" and document.kind == "bar-controller-ui-defaults"
		and tonumber(document.schemaVersion) and tonumber(document.schemaVersion) <= Runtime.SCHEMA_VERSION
		and type(document.settings) == "table"
end

local function versions(value)
	local result = {}; for part in tostring(value or "0"):gmatch("%d+") do result[#result + 1] = tonumber(part) or 0 end; return result
end

local function atLeast(a, b)
	a, b = versions(a), versions(b)
	for index = 1, math.max(#a, #b) do
		if (a[index] or 0) ~= (b[index] or 0) then return (a[index] or 0) > (b[index] or 0) end
	end
	return true
end

function Runtime.New()
	local self = {
		settings = copy(FALLBACK), personal = nil, revision = 1, viewX = 1, viewY = 1, automaticScale = 1,
		activeVersion = "fallback", layerStatus = "fallback defaults", migratedLegacyLauncher = false,
		hints = {}, visibleHints = {}, hintRevision = 1, contextSignature = "", bindingRevision = -1,
		pollElapsed = 0, animationTime = 0, alpha = 1, radialCache = {},
		legacyAuthorData = nil, legacyEditorChrome = nil,
		migratedLegacyHints = false, migratedSmallHintDefault = false,
	}
	local ok, result = false, nil
	if VFS and type(VFS.Include) == "function" then ok, result = pcall(VFS.Include, "LuaUI/Include/controller_ui_shared_renderers.lua") end
	self.renderers = ok and type(result) == "table" and result or nil
	ok, result = false, nil
	if VFS and type(VFS.Include) == "function" then ok, result = pcall(VFS.Include, "LuaUI/Include/controller_glyphs.lua") end
	self.glyphs = ok and type(result) == "table" and result or nil

	function self:Recalculate()
		if Spring and type(Spring.GetViewGeometry) == "function" then self.viewX, self.viewY = Spring.GetViewGeometry() end
		self.viewX, self.viewY = math.max(1, self.viewX or 1), math.max(1, self.viewY or 1)
		self.automaticScale = self.settings.global.resolutionAware == false and 1
			or clamp(math.min(self.viewX / Runtime.REFERENCE_WIDTH, self.viewY / Runtime.REFERENCE_HEIGHT), 0.62, 1.60)
	end

	function self:LoadSettings()
		local bundled = decode("controller-ui/shipping-defaults.json")
		local cached = decode("LuaUI/Config/BARControllerSupport/controller-ui-defaults.json")
		local manifest = decode("LuaUI/Config/BARControllerSupport/controller-ui-defaults-manifest.json")
		local cachedValid = valid(cached) and type(manifest) == "table"
			and tostring(manifest.defaultsVersion or "") == tostring(cached.defaultsVersion or "")
		local resolved = copy(FALLBACK)
		if valid(bundled) then merge(resolved, bundled.settings); self.activeVersion = tostring(bundled.defaultsVersion); self.layerStatus = "bundled shipping defaults " .. self.activeVersion end
		if cachedValid and (not valid(bundled) or atLeast(cached.defaultsVersion, bundled.defaultsVersion)) then
			merge(resolved, cached.settings); self.activeVersion = tostring(cached.defaultsVersion); self.layerStatus = "cached shipping defaults " .. self.activeVersion
		end
		if type(self.personal) == "table" then merge(resolved, self.personal) end
		if cachedValid and type(cached.enforcedSettings) == "table" then merge(resolved, cached.enforcedSettings) end
		self.settings, self.revision, self.radialCache = resolved, self.revision + 1, {}
		self:Recalculate()
	end

	local function personalHints(create)
		if create then
			self.personal = type(self.personal) == "table" and self.personal or {}
			self.personal.components = type(self.personal.components) == "table" and self.personal.components or {}
			self.personal.components.hints = type(self.personal.components.hints) == "table"
				and self.personal.components.hints or {}
		end
		return self.personal and self.personal.components and self.personal.components.hints or nil
	end

	function self:MigrateLegacyHints(data)
		if self.migratedLegacyHints or type(data) ~= "table" then return false end
		local saved = type(data.personalSettings) == "table" and data.personalSettings or data.settings
		local hints = saved and saved.components and saved.components.hints
		if type(hints) ~= "table" then return false end
		local target = personalHints(true)
		for key, value in pairs(hints) do target[key] = copy(value) end
		self.migratedLegacyHints = true
		self:LoadSettings()
		return true
	end

	function self:MigrateExactSmallHintDefault()
		local hints = personalHints(false)
		if type(hints) ~= "table" then return false end
		local exact = tonumber(hints.scale) == 1 and tonumber(hints.fontScale) == 1
			and tonumber(hints.iconScale) == 1 and hints.spacingScale == nil
			and tonumber(hints.rowSpacing) == 5 and tonumber(hints.columnSpacing) == 18
			and tonumber(hints.iconTextSpacing) == 8 and tonumber(hints.padding) == 12
		if not exact then return false end
		for _, key in ipairs({ "scale", "fontScale", "iconScale", "spacingScale",
			"rowSpacing", "columnSpacing", "iconTextSpacing", "padding" }) do hints[key] = nil end
		self.migratedSmallHintDefault = true
		self:LoadSettings()
		return true
	end

	function self:SetHintAppearance(key, value)
		local ranges = {
			scale = { 0.75, 2.50 }, fontScale = { 0.75, 2.00 },
			iconScale = { 0.75, 2.00 }, spacingScale = { 0.75, 1.75 },
		}
		local range = ranges[key]; if not range then return false end
		personalHints(true)[key] = clamp(value, range[1], range[2])
		self:LoadSettings()
		return true
	end

	function self:ResetHintAppearance(key)
		local hints = personalHints(false)
		if type(hints) == "table" then
			local allowed = { scale = true, fontScale = true, iconScale = true, spacingScale = true }
			if allowed[key] then hints[key] = nil
			else
				for _, appearanceKey in ipairs({ "scale", "fontScale", "iconScale", "spacingScale",
					"rowSpacing", "columnSpacing", "iconTextSpacing", "padding" }) do hints[appearanceKey] = nil end
			end
		end
		self:LoadSettings()
		return true
	end

	function self:EffectiveScale(name)
		local item = self.settings.components[name] or {}; return self.automaticScale * (self.settings.global.scale or 1) * (item.scale or 1)
	end
	function self:EffectiveOpacity(name)
		return (self.settings.global.opacity or 1) * ((self.settings.components[name] or {}).opacity or 1)
	end
	function self:EffectiveFontScale(name)
		local item = self.settings.components[name] or {}
		return self.automaticScale * (self.settings.global.scale or 1) * (self.settings.global.fontScale or 1) * (item.fontScale or 1)
	end
	function self:Center(name, fallbackX, fallbackY)
		local item = self.settings.components[name] or {}; local margin = (self.settings.global.safeMargin or 0) * self.automaticScale
		return clamp((item.x or 0.5) * self.viewX, margin, self.viewX - margin),
			clamp((item.y or 0.5) * self.viewY, margin, self.viewY - margin)
	end
	function self:Bounds(name, baseWidth, baseHeight)
		local item = self.settings.components[name]; if not item then return nil end
		local scale = self:EffectiveScale(name); local width = (item.width and item.width * Runtime.REFERENCE_WIDTH or baseWidth) * scale
		local height = (item.height and item.height * Runtime.REFERENCE_HEIGHT or baseHeight) * scale
		local x, y = (item.x or 0.5) * self.viewX, (item.y or 0.5) * self.viewY
		if item.anchor == "center" then x, y = x - width * 0.5, y - height * 0.5 elseif item.anchor == "bottomcenter" then x = x - width * 0.5 elseif item.anchor == "bottomright" then x = x - width end
		local margin = (self.settings.global.safeMargin or 0) * self.automaticScale
		x, y = clamp(x, margin, math.max(margin, self.viewX - margin - width)), clamp(y, margin, math.max(margin, self.viewY - margin - height))
		return { x1 = x, y1 = y, x2 = x + width, y2 = y + height, width = width, height = height, scale = scale }
	end
	function self:Color(role, alpha)
		local prefix = role == "background" and "background" or role == "accent" and "accent" or role == "muted" and "muted" or role == "danger" and "danger" or "foreground"
		local theme = self.settings.theme; return { theme[prefix .. "R"], theme[prefix .. "G"], theme[prefix .. "B"], alpha == nil and 1 or alpha }
	end
	function self:RadialStyle(name)
		if not self.radialCache[name] and self.renderers and self.renderers.RadialStyle then
			self.radialCache[name] = self.renderers.RadialStyle.Resolve(self.settings.components.radials or {}, self.settings.components[name] or {})
		end
		return self.radialCache[name]
	end

	local categories = { select = "Selection", cancel = "Selection", smartAction = "Commands", commandLayer = "Commands",
		insertNextCommandModifier = "Commands", appendQueueModifier = "Commands", pitchModifier = "Camera",
		buildRadial = "Building", removeQueuedCommand = "Factory", removeLastQueuedCommand = "Factory",
		radialSelect = "Radials", radialCancel = "Radials", radialQuick = "Radials", radialClose = "Radials",
		radialPrevPage = "Radials", radialNextPage = "Radials", place = "Placement", placeStay = "Placement",
		cancelPlacement = "Placement", rotateBuildingLeft = "Placement", rotateBuildingRight = "Placement",
		spacingUp = "Placement", spacingDown = "Placement", patternPrev = "Placement", patternNext = "Placement",
		tacticalSelect = "Tactical", tacticalCancel = "Tactical", tacticalClose = "Tactical",
		commandUp = "Tactical", commandDown = "Tactical", commandLeft = "Tactical", commandRight = "Tactical",
		idlePrev = "Selection", idleNext = "Selection", controlGroupModifier = "Groups / Hot Slots",
		groupSlotUp = "Groups / Hot Slots", groupSlotDown = "Groups / Hot Slots",
		groupRecallOrAssign = "Groups / Hot Slots", groupAssign = "Groups / Hot Slots",
		groupClear = "Groups / Hot Slots", selectCommander = "Groups / Hot Slots" }
	local function add(def) def.group = def.group or categories[def.action] or "System"; self.hints[def.id] = def; self.hintRevision = self.hintRevision + 1 end
	local function bind(action, label, when, priority, options)
		options = options or {}; add({ id = options.id or action .. ":" .. label, action = action, label = label,
			when = when, priority = priority or 100, hold = options.hold, group = options.group,
			compactLabel = options.compactLabel })
	end
	local function bindings(c) return c.bindingsOpen end
	local function pregame(c) return c.pregame and not c.bindingsOpen end
	local function mouse(c) return c.mouseMode and not c.bindingsOpen end
	local function placement(c) return c.buildPlacement and not c.bindingsOpen end
	local function build(c) return c.buildMenuOpen and not c.buildPlacement and not c.bindingsOpen end
	local function factory(c) return build(c) and c.factoryRadialOpen end
	local function constructor(c) return build(c) and not c.factoryRadialOpen end
	local function tactical(c) return c.tacticalRadialOpen and not c.bindingsOpen end
	local function selectionRadial(c) return c.selectionRadialOpen and not c.bindingsOpen end
	local function visibleRadial(c) return c.visibleSelectionRadialOpen and not c.bindingsOpen end
	local function dgun(c) return c.dgunMode and not c.bindingsOpen end
	local function staged(c) return c.stagedTactical and not c.bindingsOpen end
	local function area(c) return c.areaSelection and not c.selectionRadialOpen and not c.bindingsOpen end
	local function command(c) return c.commandLayer and not c.bindingsOpen end
	local function modal(c) return c.buildPlacement or c.buildMenuOpen or c.tacticalRadialOpen or c.selectionRadialOpen
		or c.visibleSelectionRadialOpen or c.dgunMode or c.stagedTactical or c.areaSelection or c.pregame or c.mouseMode end
	local function groups(c) return c.controlGroupLayer and not c.commandLayer and not modal(c) and not c.bindingsOpen end
	local function pitch(c) return c.pitchLayer and not c.lbTacticalLayer and not c.commandLayer and not c.controlGroupLayer
		and not modal(c) and not c.bindingsOpen end
	local function lbTactical(c) return c.lbTacticalLayer and c.hasSelection and not c.visibleSelectionRadialOpen
		and not c.bindingsOpen and not c.disassembleMode end
	local function normal(c) return not c.bindingsOpen and not modal(c) and not c.commandLayer and not c.controlGroupLayer
		and not c.pitchLayer and not c.lbTacticalLayer and not c.disassembleMode and not c.disassembleToggleCharge end
	local function context(field) return function(c) return c[field] and not c.disassembleToggleCharge end end
	local function anyCapability(c, ...)
		for _, key in ipairs({ ... }) do if c[key] then return true end end
		return false
	end

	bind("select", "Edit Binding", bindings, 1); bind("cancel", "Close Bindings", bindings, 2)
	bind("radialPrevPage", "Previous Category", bindings, 3); bind("radialNextPage", "Next Category", bindings, 4)
	bind("controlGroupModifier", "Bindings / Settings Tab", bindings, 5)
	bind("select", "Click / Set Start", pregame, 1); bind("smartAction", "Click / Set Start", pregame, 2)
	bind("pitchModifier", "Camera Tilt / Rotate", pregame, 3)
	add({ id = "pregame-stick", inputs = { "rightStick" }, label = "Move Cursor", when = pregame, priority = 4, group = "Pregame" })
	bind("select", "Mouse Click", mouse, 1); bind("smartAction", "Mouse Click", mouse, 2)
	add({ id = "mouse-stick", inputs = { "rightStick" }, label = "Move Cursor", when = mouse, priority = 3, group = "Mouse Mode" })
	bind("place", "Confirm Placement", placement, 1); bind("placeStay", "Place and Continue", placement, 2)
	bind("cancelPlacement", "Cancel Placement", placement, 3); bind("rotateBuildingLeft", "Rotate Left", placement, 4)
	bind("rotateBuildingRight", "Rotate Right", placement, 5); bind("spacingUp", "Increase Spacing", placement, 6)
	bind("spacingDown", "Decrease Spacing", placement, 7); bind("patternPrev", "Cycle Pattern", placement, 8)
	bind("patternPrev", "Force Grid Pattern", placement, 9, { hold = true, id = "placement-pattern-hold" })
	bind("patternNext", "Next Pattern", placement, 9, { id = "placement-pattern-next" })
	bind("appendQueueModifier", "Append to Queue", placement, 10)
	add({ id = "placement-insert-order", action = "insertNextCommandModifier",
		chordActions = { "insertNextCommandModifier", "place" }, label = "Insert Order",
		when = placement, priority = 11, group = "Placement" })
	bind("radialSelect", "Choose / Place", constructor, 1); bind("radialQuick", "Quick Place", constructor, 2)
	bind("radialCancel", "Close Build Radial", constructor, 3); bind("radialPrevPage", "Previous Page", constructor, 4)
	bind("radialNextPage", "Next Page", constructor, 5)
	bind("radialSelect", "Queue +1", factory, 1, { id = "factory-queue-one" })
	bind("appendQueueModifier", "Queue +5 Modifier", factory, 2, { id = "factory-queue-five" })
	bind("radialQuick", "Dequeue -1", factory, 3, { id = "factory-dequeue-one" })
	bind("radialCancel", "Close Factory Radial", factory, 4, { id = "factory-close" })
	bind("radialPrevPage", "Previous Page", factory, 5, { id = "factory-prev" })
	bind("radialNextPage", "Next Page", factory, 6, { id = "factory-next" })
	bind("radialClose", "Close Factory Radial", factory, 7, { id = "factory-close-alt" })
	bind("removeQueuedCommand", "Remove Current / Next Queue Item", factory, 8)
	bind("removeLastQueuedCommand", "Remove Last Queue Item", factory, 9)
	add({ id = "factory-insert-queue", action = "insertNextCommandModifier",
		chordActions = { "insertNextCommandModifier", "radialSelect" }, label = "Insert Queue",
		when = factory, priority = 2, group = "Factory" })
	bind("tacticalSelect", "Choose Command", tactical, 1); bind("tacticalCancel", "Close Tactical Radial", tactical, 2)
	bind("tacticalClose", "Close Tactical Radial", tactical, 3); bind("commandUp", "Guard / Patrol", tactical, 4)
	bind("commandDown", "Next Category", tactical, 5); bind("commandLeft", "Previous Tactical Command", tactical, 6)
	bind("commandRight", "Next Tactical Command", tactical, 7)
	bind("radialSelect", "Choose Selection Filter", selectionRadial, 1); bind("radialCancel", "Cancel Selection", selectionRadial, 2)
	bind("radialPrevPage", "Previous Filter", selectionRadial, 3); bind("radialNextPage", "Next Filter", selectionRadial, 4)
	add({ id = "visible-filter-choose", inputs = { "leftStick" }, label = "Choose Filter", when = visibleRadial, priority = 1, group = "Selection" })
	add({ id = "visible-filter-confirm", inputs = { "RB" }, label = "Release to Confirm", when = visibleRadial, priority = 2, group = "Selection" })
	bind("cancel", "Cancel", visibleRadial, 3, { id = "visible-filter-cancel", group = "Selection" })
	add({ id = "dgun-fire", inputs = { "RT" }, label = "Fire DGUN", when = dgun, priority = 1, group = "Commands" })
	bind("cancel", "Exit DGUN", dgun, 2); add({ id = "dgun-aim", inputs = { "rightStick" }, label = "Aim", when = dgun, priority = 3, group = "Commands" })
	bind("place", "Confirm Tactical Target", staged, 1); bind("cancelPlacement", "Cancel Tactical Target", staged, 2)
	bind("appendQueueModifier", "Repeat / Append", staged, 3)
	add({ id = "staged-insert-order", action = "insertNextCommandModifier",
		chordActions = { "insertNextCommandModifier", "place" }, label = "Insert Order",
		when = staged, priority = 2, group = "Commands" })
	bind("select", "Release to Select Area", area, 1); bind("cancel", "Cancel Area Selection", area, 2)
	add({ id = "area-radius", inputs = { "rightStick" }, label = "Adjust Radius / Filter", when = area, priority = 3, group = "Selection" })
	bind("buildRadial", "Tactical Radial", command, 5)
	bind("groupSlotUp", "Next Group Slot", groups, 1); bind("groupSlotDown", "Previous Group Slot", groups, 2)
	bind("groupRecallOrAssign", "Recall Group", groups, 3); bind("groupAssign", "Assign Type / Future Units", groups, 4)
	bind("groupClear", "Clear Group", groups, 5)
	bind("idlePrev", "Previous Idle Mobile", pitch, 1); bind("idleNext", "Next Idle Mobile", pitch, 2)
	bind("pitchModifier", "Camera Pitch Modifier", pitch, 3)
	add({ id = "lb-tactical-stop", action = "cancel", chordActions = { "pitchModifier", "cancel" }, label = "Stop",
		when = function(c) return lbTactical(c) and c.canStopCommand end, priority = 1, group = "Tactical" })
	add({ id = "lb-tactical-primary", action = "select", chordActions = { "pitchModifier", "select" }, label = "Tactical Primary",
		labelResolver = function(c) if c.selectionProfile == "builder" then return "Repair Area" end; if c.selectionProfile == "air_transport" then return "Unload Unit / Hold for Area" end; if c.selectionProfile == "factory" then return "Fight" end; return "Attack / Fight" end,
		when = function(c) return lbTactical(c) and (c.selectionProfile == "air_transport"
			or (c.selectionProfile == "builder" and c.canRepairCommand)
			or (c.selectionProfile == "factory" and c.canFightCommand)
			or anyCapability(c, "canAttackCommand", "canFightCommand")) end, priority = 2, group = "Tactical" })
	add({ id = "lb-tactical-smart", action = "smartAction", chordActions = { "pitchModifier", "smartAction" }, label = "Tactical Smart",
		labelResolver = function(c) if c.selectionProfile == "builder" then return "Reclaim Area" end; if c.selectionProfile == "air_transport" then return "Load Unit / Hold for Area" end; if c.selectionProfile == "factory" then return "Fight" end; return "Attack" end,
		when = function(c) return lbTactical(c) and (c.selectionProfile == "air_transport"
			or (c.selectionProfile == "builder" and c.canReclaimCommand)
			or (c.selectionProfile == "factory" and c.canFightCommand)
			or c.canAttackCommand) end, priority = 3, group = "Tactical" })
	add({ id = "lb-tactical-utility", action = "radialClose", chordActions = { "pitchModifier", "radialClose" },
		label = "Patrol", when = function(c) return lbTactical(c) and c.selectionProfile ~= "air_transport" and c.canPatrolCommand end, priority = 4, group = "Tactical" })
	add({ id = "lb-tactical-wait", action = "cancel", chordActions = { "pitchModifier", "cancel" }, label = "Wait", hold = true, when = lbTactical, priority = 5, group = "Tactical" })
	bind("select", "Select Unit", normal, 1); bind("smartAction", "Smart Action", function(c) return normal(c) and not c.hasTransport and c.canSmartAction end, 3)
	bind("smartAction", "Load / Move Transport", function(c) return normal(c) and c.hasTransport and c.canSmartAction end, 3, { id = "normal-transport-smart" })
	bind("smartAction", "Draw Move / Build Path", function(c) return normal(c) and c.hasSelection and c.canMoveCommand end, 4, { hold = true, id = "normal-smart-hold" })
	add({ id = "normal-selection-toggle", inputs = { "RT", "A" }, label = "Add / Remove Selection", priority = 2, group = "Selection",
		when = function(c) return normal(c) and c.selectionToggleModifier end })
	bind("cancel", "Clear Selection", function(c) return normal(c) and c.hasSelection end, 5)
	bind("buildRadial", "Build / Factory Radial", function(c) return normal(c) and c.canBuildCommand end, 6)
	bind("commandLayer", "Tactical Command Layer", function(c) return normal(c) and c.hasSelection and c.canTacticalCommand end, 7)
	add({ id = "normal-visible-select", action = "pitchModifier", label = "Select Visible Combat",
		labelResolver = function(c) local behavior = self.renderers and self.renderers.SelectionBehavior; return behavior and behavior.FilterShortLabel(c.visibleSelectionFilter) or "Select Visible Combat" end,
		when = normal, priority = 8, group = "Selection" })
	add({ id = "normal-disassemble-toggle", inputs = { "LB", "RB" }, label = "Disassemble Mode", hold = true, when = normal, priority = 7, group = "Commands" })
	add({ id = "normal-visible-filter", inputs = { "LB", "RB", "leftStick" }, label = "Visible Selection Filter", when = normal, priority = 8, group = "Selection" })
	bind("idlePrev", "Previous Idle Builder / Factory", normal, 9); bind("idleNext", "Next Idle Builder / Factory", normal, 10)
	bind("controlGroupModifier", "Control Groups", normal, 11); bind("selectCommander", "Select Commander", normal, 9, { id = "normal-select-commander" })
	add({ id = "shortcut-mouse", shortcut = "mouseMode", label = "Toggle Mouse Mode", priority = 900,
		when = function(c) return not c.bindingsOpen and not c.disassembleToggleCharge end, group = "Mouse Mode" })

	local function disassemble(c) return c.disassembleMode and not c.disassembleAreaMarking and not c.disassembleAreaReclaim and not c.disassembleToggleCharge end
	local function nativeDisassemble(c) return disassemble(c) and c.nativeBarUI end
	local function legacyDisassemble(c) return disassemble(c) and not c.nativeBarUI end
	local function nativeReclaim(c) return c.disassembleAreaReclaim and c.nativeBarUI and not c.disassembleToggleCharge end
	local function legacyReclaim(c) return c.disassembleAreaReclaim and not c.nativeBarUI and not c.disassembleToggleCharge end
	add({ id = "disassemble-exit", inputs = { "LB", "RB" }, label = "Exit Disassemble Mode", hold = true, when = disassemble, priority = 1, group = "Commands" })
	add({ id = "disassemble-native-select", inputs = { "A" }, label = "Select Unit", when = nativeDisassemble, priority = 2, group = "Selection" })
	add({ id = "disassemble-native-toggle", inputs = { "RT", "A" }, label = "Add / Remove Selection", when = nativeDisassemble, priority = 3, group = "Selection" })
	add({ id = "disassemble-native-reclaim", inputs = { "X" }, label = "Reclaim Target / Move on Empty", when = nativeDisassemble, priority = 4, group = "Commands" })
	add({ id = "disassemble-native-cancel", inputs = { "B" }, label = "Clear Selection / Cancel Target", when = nativeDisassemble, priority = 5, group = "Commands" })
	add({ id = "disassemble-mark", inputs = { "A" }, label = "Mark Target", when = legacyDisassemble, priority = 2, group = "Selection" })
	add({ id = "disassemble-mark-area", inputs = { "A" }, label = "Mark Targets in Area", hold = true, when = legacyDisassemble, priority = 3, group = "Selection" })
	add({ id = "disassemble-additive", inputs = { "RT", "A" }, label = "Add / Remove Target", when = legacyDisassemble, priority = 3, group = "Selection" })
	add({ id = "disassemble-reclaim", inputs = { "LB", "A" }, label = "Reclaim Target", when = disassemble, priority = 4, group = "Commands" })
	add({ id = "disassemble-reclaim-area", inputs = { "LB", "A" }, label = "Same-Type Area Reclaim", hold = true, when = disassemble, priority = 5, group = "Commands" })
	add({ id = "disassemble-stop", inputs = { "LB", "B" }, label = "Stop Selected", when = disassemble, priority = 6, group = "Commands" })
	add({ id = "disassemble-area-radius", inputs = { "rightStick" }, label = "Adjust Marking Radius", when = context("disassembleAreaMarking"), priority = 1, group = "Selection" })
	add({ id = "disassemble-area-release", inputs = { "A" }, label = "Release to Mark Area", when = context("disassembleAreaMarking"), priority = 2, group = "Selection" })
	add({ id = "disassemble-area-add", inputs = { "RT" }, label = "Add to Existing Targets", when = context("disassembleAreaMarking"), priority = 3, group = "Selection" })
	bind("cancel", "Cancel", context("disassembleAreaMarking"), 4, { id = "disassemble-area-cancel" })
	add({ id = "disassemble-reclaim-radius", inputs = { "rightStick" }, label = "Choose Same-Type Radius", when = context("disassembleAreaReclaim"), priority = 1, group = "Commands" })
	add({ id = "disassemble-native-reclaim-confirm", inputs = { "A" }, label = "Release to Confirm Reclaim", when = nativeReclaim, priority = 2, group = "Commands" })
	add({ id = "disassemble-native-reclaim-move", inputs = { "X" }, label = "Cancel Reclaim + Move", when = nativeReclaim, priority = 3, group = "Commands" })
	bind("cancel", "Cancel Area Reclaim", nativeReclaim, 4, { id = "disassemble-native-reclaim-cancel" })
	add({ id = "disassemble-reclaim-confirm", inputs = { "A", "X" }, label = "Confirm Reclaim", when = legacyReclaim, priority = 2, group = "Commands" })
	bind("cancel", "Cancel Area Reclaim", legacyReclaim, 3, { id = "disassemble-reclaim-cancel" })
	add({ id = "disassemble-reclaim-stop", inputs = { "LB", "B" }, label = "Stop Selected", when = context("disassembleAreaReclaim"), priority = 5, group = "Commands" })

	function self:ResolveInputs(def, api)
		if def.chordActions and type(api.GetBinding) == "function" then
			local result = {}; for _, action in ipairs(def.chordActions) do result[#result + 1] = api.GetBinding(action) end; return result
		end
		if def.inputs then return def.inputs end
		if def.action and type(api.GetBinding) == "function" then return { api.GetBinding(def.action) } end
		if def.shortcut and type(api.GetShortcutBinding) == "function" then return api.GetShortcutBinding(def.shortcut) end
		return nil
	end
	function self:Rebuild(context, api)
		self.visibleHints = {}
		if context.disassembleToggleCharge then self.alpha = 1; return end
		for _, def in pairs(self.hints) do
			if type(def.when) ~= "function" or def.when(context) then
				local inputs = self:ResolveInputs(def, api)
				if type(inputs) == "table" and #inputs > 0 and inputs[1] ~= "none" then
					self.visibleHints[#self.visibleHints + 1] = { id = def.id, action = def.action, inputs = inputs,
						label = def.labelResolver and def.labelResolver(context) or def.label, compactLabel = def.compactLabel, hold = def.hold,
						priority = def.priority, group = def.group }
				end
			end
		end
		table.sort(self.visibleHints, function(a, b) if a.priority ~= b.priority then return a.priority < b.priority end return a.id < b.id end)
		self.alpha = (self.settings.components.hints.fadeDuration or 0) > 0 and 0 or 1
	end
	function self:ContextSignature(context)
		local keys = { "pregame", "mouseMode", "bindingsOpen", "buildMenuOpen", "buildPlacement", "factoryRadialOpen",
			"tacticalRadialOpen", "selectionRadialOpen", "visibleSelectionRadialOpen", "areaSelection", "stagedTactical",
			"dgunMode", "commandLayer", "controlGroupLayer", "pitchLayer",
			"lbTacticalLayer", "visibleSelectionFilter", "selectionToggleModifier",
			"disassembleMode", "disassembleToggleCharge", "disassembleAreaMarking", "disassembleAreaReclaim", "disassembleMarkedCount",
			"nativeBarUI", "nativeCommandActive", "controllerGlyphStyle", "controllerGlyphFamily",
			"canSmartAction", "canTacticalCommand", "canMoveCommand", "canStopCommand", "canPatrolCommand", "canGuardCommand",
			"canReclaimCommand", "canRepairCommand", "canAttackCommand", "canFightCommand", "canBuildCommand" }
		local values = {}; for i, key in ipairs(keys) do values[i] = tostring(context[key]) end; return table.concat(values, "|")
	end
	function self:SelectionSignature(context)
		local keys = { "selectionRevision", "selectedCount", "hasSelection", "multipleSelection",
			"hasBuilder", "hasFactory", "hasTransport", "selectionProfile",
			"canSmartAction", "canTacticalCommand", "canMoveCommand", "canStopCommand", "canPatrolCommand", "canGuardCommand",
			"canReclaimCommand", "canRepairCommand", "canAttackCommand", "canFightCommand", "canBuildCommand" }
		local values = {}; for i, key in ipairs(keys) do values[i] = tostring(context[key]) end
		return table.concat(values, "|")
	end
	function self:Update(dt)
		dt = math.max(0, tonumber(dt) or 0); self.animationTime, self.pollElapsed = self.animationTime + dt, self.pollElapsed + dt
		local fade = self.settings.components.hints.fadeDuration or 0; self.alpha = fade <= 0 and 1 or math.min(1, self.alpha + dt / fade)
		if self.pollElapsed < 0.04 then return end; self.pollElapsed = 0
		local api = WG and WG.BARControllerSupport; if not api or type(api.GetContextSnapshot) ~= "function" then return end
		local context = api.GetContextSnapshot(); if type(context) ~= "table" then return end
		if self.glyphs and type(self.glyphs.SetStyle) == "function" then
			self.glyphs.SetStyle(context.controllerGlyphStyle, context.controllerGlyphFamily)
		end
		local stateSignature, selectionSignature = self:ContextSignature(context), self:SelectionSignature(context)
		local bindingRevision = type(api.GetBindingRevision) == "function" and api.GetBindingRevision() or 0
		local committed, changed, reason = self.committedContext, false, nil
		if not committed then
			committed, changed, reason = context, true, "initial"
		elseif stateSignature ~= self.committedStateSignature then
			committed, changed, reason = context, true, "explicit-state"
			self.selectionCandidate, self.selectionCandidateSince = nil, nil
		elseif selectionSignature ~= self.committedSelectionSignature then
			if self.selectionCandidateSignature ~= selectionSignature then
				self.selectionCandidate, self.selectionCandidateSignature = context, selectionSignature
				self.selectionCandidateSince = self.animationTime
			elseif self.animationTime - (self.selectionCandidateSince or self.animationTime) >= 0.16 then
				committed, changed, reason = self.selectionCandidate, true, "selection-debounced"
				self.selectionCandidate, self.selectionCandidateSignature, self.selectionCandidateSince = nil, nil, nil
			end
		else
			self.selectionCandidate, self.selectionCandidateSignature, self.selectionCandidateSince = nil, nil, nil
		end
		if bindingRevision ~= self.bindingRevision or self.lastHintRevision ~= self.hintRevision then
			committed, changed, reason = context, true, bindingRevision ~= self.bindingRevision and "bindings" or "definitions"
		end
		if changed then
			self.committedContext = committed
			self.committedStateSignature = self:ContextSignature(committed)
			self.committedSelectionSignature = self:SelectionSignature(committed)
			self.contextSignature, self.bindingRevision, self.lastHintRevision =
				self.committedStateSignature .. "|" .. self.committedSelectionSignature, bindingRevision, self.hintRevision
			self.modelRevision, self.lastUpdateReason = (self.modelRevision or 0) + 1, reason
			self.lastRebuildAt, self.rebuildCount = self.animationTime, (self.rebuildCount or 0) + 1
			self:Rebuild(committed, api)
		end
	end
	function self:Draw()
		if not self.renderers or #self.visibleHints == 0 or self.settings.global.enabled == false then return end
		local component = self.settings.components.hints
		local inputLabels = { back = "Back", start = "Start", dpadUp = "D-pad Up", dpadDown = "D-pad Down",
			dpadLeft = "D-pad Left", dpadRight = "D-pad Right", leftStickClick = "L3", rightStickClick = "R3",
			leftStick = "Left Stick", rightStick = "Right Stick", none = "Unbound" }
		local function formatInputs(hint)
			local labels = {}; for index, input in ipairs(hint.inputs or {}) do labels[index] = inputLabels[input] or tostring(input or "Unbound") end
			local layout = component.chordLayout; if layout == "Vertical" then return table.concat(labels, " / ") end
			if layout == "Stacked" then return "[" .. table.concat(labels, "][") .. "]" end; return table.concat(labels, " + ")
		end
		self.renderers.DrawHints({ settings = component, model = self.visibleHints, theme = self.settings.theme,
			viewportWidth = self.viewX, viewportHeight = self.viewY,
			margin = (self.settings.global.safeMargin or 0) * self.automaticScale,
			scale = self:EffectiveScale("hints"), fontScale = self:EffectiveFontScale("hints"),
			opacity = self:EffectiveOpacity("hints") * self.alpha, glyphs = self.glyphs, time = self.animationTime,
			formatInputs = formatInputs })
	end

	function self:PublicAPI()
		return {
			SCHEMA_VERSION = Runtime.SCHEMA_VERSION, REFERENCE_WIDTH = Runtime.REFERENCE_WIDTH, REFERENCE_HEIGHT = Runtime.REFERENCE_HEIGHT,
			Get = function(scope, key) local target = (scope == "global" or scope == "theme" or scope == "authoring") and self.settings[scope] or self.settings.components[scope]; return target and target[key] end,
			GetComponent = function(name) return self.settings.components[name] end, GetGlobal = function() return self.settings.global end,
			GetEffectiveScale = function(name) return self:EffectiveScale(name) end,
			GetEffectiveOpacity = function(name) return self:EffectiveOpacity(name) end,
			GetEffectiveFontScale = function(name) return self:EffectiveFontScale(name) end,
			GetResolvedRadialStyle = function(name) return self:RadialStyle(name) end,
			GetComponentBounds = function(name, width, height) return self:Bounds(name, width, height) end,
			GetComponentCenter = function(name, x, y) return self:Center(name, x, y) end,
			GetColor = function(role, alpha) return self:Color(role, alpha) end, GetRevision = function() return self.revision end,
			GetPropertySource = function() return self.personal and "personal" or self.layerStatus end,
			GetLayerStatus = function() return { activeVersion = self.activeVersion, status = self.layerStatus, dirty = false, undo = 0, redo = 0 } end,
			SetHintAppearance = function(key, value) return self:SetHintAppearance(key, value) end,
			ResetHintAppearance = function(key) return self:ResetHintAppearance(key) end,
			MigrateLegacyBindingsButton = function(rightOffset, topOffset)
				if self.migratedLegacyLauncher then return false end
				local component = self.settings.components.bindingsButton
				component.x = clamp((self.viewX - (tonumber(rightOffset) or 560)) / self.viewX, 0, 1)
				component.y = clamp((self.viewY - (tonumber(topOffset) or 8) - 28) / self.viewY, 0, 1)
				self.migratedLegacyLauncher, self.revision = true, self.revision + 1; return true
			end,
		}
	end
	function self:HintAPI()
		return { Register = add, Unregister = function(id) self.hints[id] = nil; self.hintRevision = self.hintRevision + 1 end,
			GetVisibleActions = function() return self.visibleHints end, GetDefinitions = function() return self.hints end,
			Invalidate = function() self.committedStateSignature = "" end,
			GetDiagnostics = function() return { modelRevision = self.modelRevision or 0,
				lastUpdateReason = self.lastUpdateReason or "none", lastRebuildAt = self.lastRebuildAt or 0,
				rebuildCount = self.rebuildCount or 0, selectionDebounceSeconds = 0.16 } end }
	end
	function self:GetConfigData()
		return { schemaVersion = Runtime.SCHEMA_VERSION, personalSettings = self.personal,
			settings = self.personal, authorData = self.legacyAuthorData, editorChrome = self.legacyEditorChrome,
			migratedLegacyLauncher = self.migratedLegacyLauncher,
			migratedLegacyHints = self.migratedLegacyHints,
			migratedSmallHintDefault = self.migratedSmallHintDefault, editorOpen = false }
	end
	function self:SetConfigData(data)
		if type(data) ~= "table" then return end
		local schema = tonumber(data.schemaVersion); if schema and schema ~= 1 and schema ~= 2 and schema ~= Runtime.SCHEMA_VERSION then self.personal = nil else
			local saved = type(data.personalSettings) == "table" and data.personalSettings or data.settings
			self.personal = type(saved) == "table" and copy(saved) or nil
		end
		self.migratedLegacyLauncher = data.migratedLegacyLauncher == true; self:LoadSettings()
		self.migratedLegacyHints = data.migratedLegacyHints == true
		self.migratedSmallHintDefault = data.migratedSmallHintDefault == true
		if not self.migratedSmallHintDefault then self:MigrateExactSmallHintDefault() end
		self.legacyAuthorData = type(data.authorData) == "table" and copy(data.authorData) or nil
		self.legacyEditorChrome = type(data.editorChrome) == "table" and copy(data.editorChrome) or nil
	end

	self:LoadSettings()
	return self
end

return Runtime
