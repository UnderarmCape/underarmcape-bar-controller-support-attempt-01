-- Controller-native targeting state machine (v0.8 experimental).
--
-- This module deliberately has no Spring/WG dependencies.  The camera widget
-- supplies the active BAR descriptor and reticle hit; BAR's Order Menu remains
-- responsible for the single CommandNotify/GiveOrder dispatch boundary.

local Targeting = {}

Targeting.IDLE = "IDLE"
Targeting.POINT_TARGETING = "POINT_TARGETING"
Targeting.CONTROLLER_AREA_TARGETING = "CONTROLLER_AREA_TARGETING"
Targeting.FRONT_TARGETING = "FRONT_TARGETING"
Targeting.BUILD_PLACEMENT = "BUILD_PLACEMENT"

local function shallowCopy(source)
	local result = {}
	for key, value in pairs(type(source) == "table" and source or {}) do result[key] = value end
	return result
end

local function commandTypes(types)
	return type(types) == "table" and types or rawget(_G, "CMDTYPE") or {}
end

local function hasType(descriptor, name, types)
	local expected = tonumber(commandTypes(types)[name])
	return expected ~= nil and tonumber(descriptor and descriptor.type) == expected
end

local function worldParams(target)
	if type(target) ~= "table" then return nil end
	local x, y, z = tonumber(target.x), tonumber(target.y), tonumber(target.z)
	if not x or not y or not z then return nil end
	return { x, y, z }
end

local function featureParam(featureID)
	featureID = tonumber(featureID)
	if not featureID then return nil end
	return featureID + (tonumber(rawget(_G, "Game") and Game.maxUnits) or 32000)
end

local function descriptorText(descriptor)
	return string.lower(tostring(descriptor and descriptor.action or "") .. " "
		.. tostring(descriptor and descriptor.name or ""))
end

function Targeting.New()
	return {
		phase = Targeting.IDLE,
		descriptor = nil,
		cmdID = nil,
		shape = nil,
		anchor = nil,
		current = nil,
		radius = 0,
		cancelReleaseRequired = false,
		persistentUntilQueueRelease = false,
		lastResult = "idle",
	}
end

function Targeting.Reset(state, reason)
	state = type(state) == "table" and state or Targeting.New()
	state.phase = Targeting.IDLE
	state.descriptor = nil
	state.cmdID = nil
	state.shape = nil
	state.anchor = nil
	state.current = nil
	state.radius = 0
	state.persistentUntilQueueRelease = false
	state.lastResult = reason or "reset"
	return state
end

function Targeting.IsBuildDescriptor(descriptor)
	return type(descriptor) == "table" and tonumber(descriptor.id or descriptor.cmdID) ~= nil
		and tonumber(descriptor.id or descriptor.cmdID) < 0
end

function Targeting.Classify(descriptor, types)
	if type(descriptor) ~= "table" then return Targeting.IDLE end
	if Targeting.IsBuildDescriptor(descriptor) or hasType(descriptor, "ICON_BUILDING", types) then
		return Targeting.BUILD_PLACEMENT
	end
	if hasType(descriptor, "ICON_AREA", types)
		or hasType(descriptor, "ICON_UNIT_OR_AREA", types)
		or hasType(descriptor, "ICON_UNIT_FEATURE_OR_AREA", types) then
		return Targeting.CONTROLLER_AREA_TARGETING
	end
	if hasType(descriptor, "ICON_FRONT", types) then return Targeting.FRONT_TARGETING end
	if hasType(descriptor, "ICON_UNIT_OR_RECTANGLE", types) then
		return Targeting.CONTROLLER_AREA_TARGETING
	end
	if hasType(descriptor, "ICON_MAP", types) or hasType(descriptor, "ICON_UNIT", types)
		or hasType(descriptor, "ICON_UNIT_OR_MAP", types) then
		return Targeting.POINT_TARGETING
	end
	return Targeting.IDLE
end

function Targeting.SetDescriptor(state, descriptor, types)
	state = type(state) == "table" and state or Targeting.New()
	if type(descriptor) ~= "table" then return Targeting.Reset(state, "no active target command") end
	local cmdID = tonumber(descriptor.id or descriptor.cmdID)
	local phase = Targeting.Classify(descriptor, types)
	if phase == Targeting.IDLE then return Targeting.Reset(state, "active command is not targetable") end
	if state.cmdID ~= cmdID then
		Targeting.Reset(state, "active target command changed")
		state.descriptor = shallowCopy(descriptor)
		state.cmdID = cmdID
		state.phase = phase
		state.lastResult = "target command active"
	else
		state.descriptor = shallowCopy(descriptor)
		if not state.anchor then state.phase = phase end
	end
	return state
end

local function directTarget(descriptor, target, types, isAlliedUnit)
	if type(target) ~= "table" then return nil, "reticle has no target" end
	local targetType = target.targetType
	local targetID = tonumber(target.targetID)
	local text = descriptorText(descriptor)

	if targetType == "unit" and targetID then
		if hasType(descriptor, "ICON_MAP", types) or hasType(descriptor, "ICON_AREA", types)
			or hasType(descriptor, "ICON_FRONT", types) then
			return nil, "ground target required"
		end
		if (text:find("guard", 1, true) or text:find("repair", 1, true))
			and type(isAlliedUnit) == "function" and not isAlliedUnit(targetID) then
			return nil, "allied unit required"
		end
		if text:find("resurrect", 1, true) then return nil, "feature target required" end
		return { targetID }, "unit"
	end

	if targetType == "feature" and targetID then
		if hasType(descriptor, "ICON_UNIT_FEATURE_OR_AREA", types) then
			return { tonumber(target.commandID) or featureParam(targetID) }, "feature"
		end
		return nil, "feature target not accepted"
	end

	if hasType(descriptor, "ICON_UNIT", types) then return nil, "unit target required" end
	local params = worldParams(target)
	if not params then return nil, "ground target required" end
	if hasType(descriptor, "ICON_AREA", types) or hasType(descriptor, "ICON_UNIT_OR_AREA", types)
		or hasType(descriptor, "ICON_UNIT_FEATURE_OR_AREA", types)
		or hasType(descriptor, "ICON_FRONT", types)
		or hasType(descriptor, "ICON_UNIT_OR_RECTANGLE", types) then
		return nil, "anchor"
	end
	return params, "ground"
end

function Targeting.BeginOrBuildPoint(state, target, types, isAlliedUnit)
	if type(state) ~= "table" or not state.descriptor then return nil, "no active target command" end
	local params, result = directTarget(state.descriptor, target, types, isAlliedUnit)
	if params then return params, result end
	if result ~= "anchor" then return nil, result end
	state.anchor = { x = target.x, y = target.y, z = target.z }
	state.current = { x = target.x, y = target.y, z = target.z }
	state.radius = 0
	if hasType(state.descriptor, "ICON_FRONT", types) then
		state.phase, state.shape = Targeting.FRONT_TARGETING, "front"
	elseif hasType(state.descriptor, "ICON_UNIT_OR_RECTANGLE", types) then
		state.phase, state.shape = Targeting.CONTROLLER_AREA_TARGETING, "rectangle"
	else
		state.phase, state.shape = Targeting.CONTROLLER_AREA_TARGETING, "area"
	end
	state.lastResult = "anchor latched"
	return nil, "anchor"
end

function Targeting.UpdatePreview(state, target)
	if type(state) ~= "table" or not state.anchor or not target then return 0 end
	local x, y, z = tonumber(target.x), tonumber(target.y), tonumber(target.z)
	if not x or not y or not z then return state.radius or 0 end
	state.current = { x = x, y = y, z = z }
	local dx, dz = x - state.anchor.x, z - state.anchor.z
	state.radius = math.sqrt(dx * dx + dz * dz)
	return state.radius
end

function Targeting.BuildAnchoredParams(state)
	if type(state) ~= "table" or not state.anchor or not state.current then
		return nil, "area anchor is missing"
	end
	local radius = tonumber(state.radius) or 0
	if state.shape == "front" or state.shape == "rectangle" then
		if radius <= 0.5 then return nil, "move the reticle before confirming" end
		return {
			state.anchor.x, state.anchor.y, state.anchor.z,
			state.current.x, state.current.y, state.current.z,
		}, state.shape
	end
	if radius <= 0.5 then return nil, "area radius is too small" end
	local maximum
	local descriptorParams = state.descriptor and state.descriptor.params
	if type(descriptorParams) == "table" and #descriptorParams == 1 then maximum = tonumber(descriptorParams[1]) end
	if maximum and maximum > 0 then radius = math.min(radius, maximum) end
	state.radius = radius
	local params = { state.anchor.x, state.anchor.y, state.anchor.z, radius }
	local text = descriptorText(state.descriptor)
	if text:find("unload", 1, true) and state.descriptor and state.descriptor.buildFacing ~= nil then
		params[5] = tonumber(state.descriptor.buildFacing) or 0
	end
	return params, "area"
end

function Targeting.ArmCancelRelease(state, reason)
	state.cancelReleaseRequired = true
	state.lastResult = reason or "cancel release required"
end

function Targeting.ReleaseCancelLatch(state)
	state.cancelReleaseRequired = false
end

return Targeting
