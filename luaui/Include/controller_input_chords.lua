--------------------------------------------------------------------------------
-- Pure shoulder arbitration for RB tap, LB-first repeats, and RB-first grace.
--------------------------------------------------------------------------------

local Chords = {}

function Chords.New()
	return {
		mode = "idle",
		active = false,
		startedAt = 0,
		rbPressedAt = 0,
		waitingForRelease = false,
		longFired = false,
		longAction = nil,
		firstShoulder = nil,
		lastEvent = "idle",
	}
end

local function normalizeLongAction(longAction, legacyDisassembleActive)
	if type(longAction) == "string" then return longAction end
	if longAction == true then return "factory-queue-mode" end
	if legacyDisassembleActive == true then return "disable-disassemble" end
	if legacyDisassembleActive == false then return "enable-disassemble" end
	return nil
end

local function beginChord(state, now, firstShoulder, longAction)
	state.mode = "chord"
	state.active = true
	state.waitingForRelease = false
	state.startedAt = now
	state.firstShoulder = firstShoulder
	state.longAction = longAction
	state.longFired = false
	state.lastEvent = firstShoulder .. "-chord-started"
	return "started", state
end

function Chords.Consume(state, reason)
	state = type(state) == "table" and state or Chords.New()
	if type(state.mode) ~= "string" then state.mode = "idle" end
	state.mode = "wait-rb-release"
	state.active = false
	state.waitingForRelease = true
	state.longFired = false
	state.longAction = nil
	state.lastEvent = "consumed:" .. tostring(reason or "external")
	return state
end

function Chords.Update(state, now, lbDown, rbDown, rbPressed, rbReleased,
		holdSeconds, longAction, legacyDisassembleActive, options)
	state = type(state) == "table" and state or Chords.New()
	if type(state.mode) ~= "string" then state.mode = "idle" end
	now = tonumber(now) or 0
	lbDown, rbDown = lbDown == true, rbDown == true
	holdSeconds = tonumber(holdSeconds) or 0.33
	longAction = normalizeLongAction(longAction, legacyDisassembleActive)
	options = type(options) == "table" and options or {}
	local lbPressed = options.lbPressed == true
	local graceSeconds = tonumber(options.graceSeconds) or 0.18
	local tapMaxSeconds = tonumber(options.tapMaxSeconds) or 0.22

	if state.mode == "wait-rb-release" then
		if not rbDown then
			state.mode, state.waitingForRelease = "idle", false
			state.firstShoulder, state.longAction = nil, nil
			state.lastEvent = "rearmed"
		end
		return nil, state
	end

	if state.mode == "rb-solo" then
		local elapsed = math.max(0, now - (tonumber(state.rbPressedAt) or now))
		if lbPressed or lbDown then
			if elapsed <= graceSeconds then
				return beginChord(state, now, "rb-first", longAction)
			end
			state.mode, state.active, state.waitingForRelease = "wait-rb-release", false, true
			state.lastEvent = "rb-first-grace-expired"
			return "late-lb-blocked", state
		end
		if rbReleased or not rbDown then
			state.mode, state.active = "idle", false
			if elapsed <= tapMaxSeconds then
				state.lastEvent = "rb-tap"
				return "rb-tap", state
			end
			state.lastEvent = "rb-hold-noop"
			return "rb-hold-noop", state
		end
		state.lastEvent = elapsed > tapMaxSeconds and "rb-hold-noop" or "rb-tap-pending"
		return "holding", state
	end

	if state.mode == "chord" then
		if not lbDown then
			-- RB-first cannot be reused by tapping LB while RB stays held.
			if rbDown then
				state.mode, state.active, state.waitingForRelease = "wait-rb-release", false, true
				state.lastEvent = "chord-lb-released"
				return "cancelled", state
			end
			state.mode, state.active, state.lastEvent = "idle", false, "cancelled"
			return "cancelled", state
		end
		local elapsed = math.max(0, now - (tonumber(state.startedAt) or now))
		if rbDown and elapsed >= holdSeconds then
			local event = state.longAction
			state.mode, state.active, state.waitingForRelease = "wait-rb-release", false, true
			state.longFired = event ~= nil
			if event ~= "factory-queue-mode" and event ~= "disable-disassemble"
					and event ~= "enable-disassemble" then event = nil end
			state.lastEvent = event or "unsupported-long"
			return event, state
		end
		if rbReleased or not rbDown then
			-- Re-arm immediately when LB remains held so each distinct RB tap cycles once.
			state.mode, state.active, state.waitingForRelease = "idle", false, false
			state.lastEvent = "move-state"
			return "move-state", state
		end
		state.lastEvent = "holding"
		return "holding", state
	end

	if rbPressed then
		state.rbPressedAt = now
		if lbDown then
			return beginChord(state, now, "lb-first", longAction)
		end
		state.mode = "rb-solo"
		state.active = false
		state.firstShoulder = "rb-first"
		state.lastEvent = "rb-tap-pending"
		return "rb-pending", state
	end

	return nil, state
end

function Chords.IsBusy(state)
	return type(state) == "table" and state.mode ~= "idle"
end

return Chords
