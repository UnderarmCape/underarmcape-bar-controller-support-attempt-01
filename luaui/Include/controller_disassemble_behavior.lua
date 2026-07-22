--------------------------------------------------------------------------------
-- BAR Controller Support - pure Disassemble Mode state helpers
--------------------------------------------------------------------------------

local Behavior = {
	DISASSEMBLE_TOGGLE_HOLD_SECONDS = 1.0,
	DISASSEMBLE_UNUSED_TIMEOUT_SECONDS = 20.0,
	AREA_RECLAIM_HOLD_SECONDS = 0.45,
	AREA_MARK_HOLD_SECONDS = 0.38,
	MIN_TARGET_RADIUS = 120,
	MAX_TARGET_RADIUS = 1200,
	FILTER_DEADZONE = 0.50,
}

local function copyArray(values)
	local result = {}
	for index, value in ipairs(type(values) == "table" and values or {}) do result[index] = value end
	return result
end

function Behavior.IsConstructorDef(unitDef)
	return type(unitDef) == "table" and unitDef.isFactory ~= true
		and (unitDef.isBuilder == true or unitDef.canBuild == true
			or (type(unitDef.buildOptions) == "table" and #unitDef.buildOptions > 0))
end

function Behavior.FilterConstructors(units, resolveDef, hasReclaim)
	local result, seen = {}, {}
	if type(resolveDef) ~= "function" then return result end
	for _, unitID in ipairs(type(units) == "table" and units or {}) do
		if not seen[unitID] and Behavior.IsConstructorDef(resolveDef(unitID))
				and (type(hasReclaim) ~= "function" or hasReclaim(unitID) == true) then
			seen[unitID], result[#result + 1] = true, unitID
		end
	end
	table.sort(result)
	return result
end

function Behavior.FilterOwnedTargets(units, constructorSet, isValid, resolveDefID, requiredDefID)
	local result, seen = {}, {}
	constructorSet = type(constructorSet) == "table" and constructorSet or {}
	for _, unitID in ipairs(type(units) == "table" and units or {}) do
		local typeMatches = requiredDefID == nil or (type(resolveDefID) == "function"
			and resolveDefID(unitID) == requiredDefID)
		if not seen[unitID] and not constructorSet[unitID] and typeMatches
				and type(isValid) == "function" and isValid(unitID) == true then
			seen[unitID], result[#result + 1] = true, unitID
		end
	end
	table.sort(result)
	return result
end

function Behavior.NewToggleCharge()
	return {
		charging = false,
		startedAt = 0,
		progress = 0,
		waitingForRelease = false,
		lastEvent = "idle",
	}
end

-- A single pure transition owns the shared LB+RB chord. In normal gameplay a
-- stick sector wins before the one-second deadline; in Disassemble Mode the
-- stick is deliberately ignored and the chord is reserved for exit.
function Behavior.UpdateToggleCharge(state, now, lbDown, rbDown, stickSector, modeActive, holdSeconds)
	state = state or Behavior.NewToggleCharge()
	now, lbDown, rbDown = tonumber(now) or 0, lbDown == true, rbDown == true
	if state.waitingForRelease then
		state.progress = 0
		if not lbDown and not rbDown then
			state.waitingForRelease, state.lastEvent = false, "released"
		end
		return nil, state
	end
	if not state.charging then
		if lbDown and rbDown then
			state.charging, state.startedAt, state.progress, state.lastEvent = true, now, 0, "charging"
			return "charge-started", state
		end
		return nil, state
	end
	if not lbDown or not rbDown then
		state.charging, state.progress, state.waitingForRelease, state.lastEvent = false, 0, true, "cancelled"
		return "charge-cancelled", state
	end
	local elapsed = math.max(0, now - (tonumber(state.startedAt) or now))
	holdSeconds = tonumber(holdSeconds) or Behavior.DISASSEMBLE_TOGGLE_HOLD_SECONDS
	state.progress = math.min(1, elapsed / holdSeconds)
	if not modeActive and stickSector ~= nil and elapsed < holdSeconds then
		state.charging, state.progress, state.waitingForRelease, state.lastEvent = false, 0, true, "filter"
		return "open-filter", state
	end
	if elapsed >= holdSeconds then
		state.charging, state.progress, state.waitingForRelease, state.lastEvent = false, 1, true, "toggle"
		return modeActive and "disable" or "enable", state
	end
	return "charging", state
end

function Behavior.FilterFromStick(x, y, deadzone)
	x, y = tonumber(x) or 0, tonumber(y) or 0
	if math.sqrt((x * x) + (y * y)) < (tonumber(deadzone) or Behavior.FILTER_DEADZONE) then return nil end
	if math.abs(y) > math.abs(x) then return y > 0 and "Last Selected" or "Combat" end
	return x < 0 and "Builders" or "Air"
end

function Behavior.NewFilterRadial(persisted)
	return {
		open = false,
		persistedFilter = persisted or "Combat",
		candidate = persisted or "Combat",
		stickSector = nil,
		initialValue = persisted or "Combat",
		lastResult = "closed",
	}
end

function Behavior.OpenFilterRadial(radial, persisted, initialSector)
	radial = radial or Behavior.NewFilterRadial(persisted)
	persisted = persisted or radial.persistedFilter or "Combat"
	radial.open, radial.persistedFilter, radial.initialValue = true, persisted, persisted
	radial.candidate, radial.stickSector, radial.lastResult = initialSector or persisted, initialSector, "open"
	return radial
end

function Behavior.LatchFilterCandidate(radial, sector)
	if not radial then return nil end
	radial.stickSector = sector
	if sector ~= nil then radial.candidate = sector end
	return radial.candidate
end

function Behavior.ToggleSelection(existing, targetID)
	local result, found = {}, false
	for _, unitID in ipairs(copyArray(existing)) do
		if unitID == targetID then found = true else result[#result + 1] = unitID end
	end
	if not found and targetID ~= nil then result[#result + 1] = targetID end
	table.sort(result)
	return result, found and "removed" or "added"
end

function Behavior.ToggleMarked(marked, targetID)
	local result = {}
	for unitID, value in pairs(type(marked) == "table" and marked or {}) do if value then result[unitID] = true end end
	if result[targetID] then result[targetID] = nil; return result, "removed" end
	if targetID ~= nil then result[targetID] = true end
	return result, "added"
end

function Behavior.MergeMarked(existing, candidates, additive)
	local result = {}
	if additive then
		for unitID, value in pairs(type(existing) == "table" and existing or {}) do if value then result[unitID] = true end end
	end
	for _, unitID in ipairs(type(candidates) == "table" and candidates or {}) do result[unitID] = true end
	return result
end

function Behavior.CollectMarkedTypes(marked, resolveDefID)
	local types = {}
	if type(resolveDefID) ~= "function" then return types end
	for unitID, value in pairs(type(marked) == "table" and marked or {}) do
		if value then
			local unitDefID = resolveDefID(unitID)
			if unitDefID ~= nil then types[unitDefID] = true end
		end
	end
	return types
end

function Behavior.OrderTargets(targets)
	local result, seen = {}, {}
	for _, unitID in ipairs(type(targets) == "table" and targets or {}) do
		if not seen[unitID] then seen[unitID], result[#result + 1] = true, unitID end
	end
	table.sort(result)
	return result
end

function Behavior.TimeoutExpired(activatedAt, now, successfulActivity, timeoutSeconds)
	return successfulActivity ~= true
		and (tonumber(now) or 0) - (tonumber(activatedAt) or 0)
			>= (tonumber(timeoutSeconds) or Behavior.DISASSEMBLE_UNUSED_TIMEOUT_SECONDS)
end

return Behavior
