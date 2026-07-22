--------------------------------------------------------------------------------
-- Pure ownership state for the shared LB-held + RB tap/hold gesture.
--------------------------------------------------------------------------------

local Chords = {}

function Chords.New()
	return {
		active = false,
		startedAt = 0,
		waitingForRelease = false,
		longFired = false,
		factoryContext = false,
		lastEvent = "idle",
	}
end

function Chords.Update(state, now, lbDown, rbDown, rbPressed, rbReleased, holdSeconds, factoryContext, disassembleActive)
	state = type(state) == "table" and state or Chords.New()
	now = tonumber(now) or 0
	lbDown, rbDown = lbDown == true, rbDown == true
	holdSeconds = tonumber(holdSeconds) or 0.33

	if state.waitingForRelease then
		if not lbDown and not rbDown then
			state.waitingForRelease, state.lastEvent = false, "released"
		end
		return nil, state
	end

	-- Deliberately starts on the RB edge while LB is already held. This makes
	-- the owner unambiguous and prevents ordinary RB radial input from leaking.
	if not state.active then
		if lbDown and rbPressed == true then
			state.active = true
			state.startedAt = now
			state.factoryContext = factoryContext == true
			state.longFired = false
			state.lastEvent = "started"
			return "started", state
		end
		return nil, state
	end

	if not lbDown then
		state.active, state.waitingForRelease, state.lastEvent = false, true, "cancelled"
		return "cancelled", state
	end

	local elapsed = math.max(0, now - (tonumber(state.startedAt) or now))
	if rbDown and elapsed >= holdSeconds then
		state.active, state.waitingForRelease, state.longFired = false, true, true
		local event
		if state.factoryContext then event = "factory-queue-mode"
		else event = disassembleActive == true and "disable-disassemble" or "enable-disassemble" end
		state.lastEvent = event
		return event, state
	end

	if rbReleased == true or not rbDown then
		state.active, state.waitingForRelease, state.lastEvent = false, true, "move-state"
		return "move-state", state
	end

	state.lastEvent = "holding"
	return "holding", state
end

function Chords.IsBusy(state)
	return type(state) == "table" and (state.active == true or state.waitingForRelease == true)
end

return Chords
