-- Controller A-tap arbitration extracted from the camera widget.
--
-- This module has no Spring/WG dependency. The caller validates ownership and
-- visibility, performs the exact single-unit selection, and expands only when
-- ResolveRelease reports an intentional compatible double tap.

local Taps = {}

Taps.DEFAULT_WINDOW_SECONDS = 0.35

function Taps.New(windowSeconds)
	return {
		windowSeconds = tonumber(windowSeconds) or Taps.DEFAULT_WINDOW_SECONDS,
		lastTapAt = -math.huge,
		lastUnitID = nil,
		lastUnitDefID = nil,
		lastResult = "idle",
		resetReason = "none",
	}
end

function Taps.Reset(state, reason)
	state = type(state) == "table" and state or Taps.New()
	state.lastTapAt = -math.huge
	state.lastUnitID = nil
	state.lastUnitDefID = nil
	state.lastResult = "reset"
	state.resetReason = tostring(reason or "reset")
	return state
end

function Taps.Expire(state, now)
	if type(state) ~= "table" or state.lastUnitDefID == nil then return false end
	local elapsed = (tonumber(now) or 0) - (tonumber(state.lastTapAt) or -math.huge)
	if elapsed <= (tonumber(state.windowSeconds) or Taps.DEFAULT_WINDOW_SECONDS) then return false end
	Taps.Reset(state, "timeout")
	return true
end

function Taps.ObserveTarget(state, unitID, unitDefID)
	if type(state) ~= "table" or state.lastUnitDefID == nil then return false end
	unitID, unitDefID = tonumber(unitID), tonumber(unitDefID)
	if unitID and unitDefID == state.lastUnitDefID then return false end
	Taps.Reset(state, "incompatible cursor target")
	return true
end

function Taps.ResolveRelease(state, now, unitID, unitDefID, modified)
	state = type(state) == "table" and state or Taps.New()
	now = tonumber(now) or 0
	Taps.Expire(state, now)
	if modified == true then
		Taps.Reset(state, "modified tap")
		return "modified", state
	end
	unitID, unitDefID = tonumber(unitID), tonumber(unitDefID)
	if not unitID or not unitDefID then
		Taps.Reset(state, "invalid target")
		state.lastResult = "invalid"
		return "invalid", state
	end
	local elapsed = now - (tonumber(state.lastTapAt) or -math.huge)
	if state.lastUnitDefID == unitDefID and elapsed >= 0
			and elapsed <= (tonumber(state.windowSeconds) or Taps.DEFAULT_WINDOW_SECONDS) then
		local firstUnitID = state.lastUnitID
		Taps.Reset(state, "double tap completed")
		state.lastResult = "double"
		state.completedFirstUnitID = firstUnitID
		state.completedSecondUnitID = unitID
		state.completedUnitDefID = unitDefID
		return "double", state
	end
	state.lastTapAt = now
	state.lastUnitID = unitID
	state.lastUnitDefID = unitDefID
	state.lastResult = "single"
	state.resetReason = "none"
	return "single", state
end

return Taps
