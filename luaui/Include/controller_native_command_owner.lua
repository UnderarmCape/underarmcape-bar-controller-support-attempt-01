-- Controller adapter for BAR command-owner widgets (v0.8 experimental).
--
-- This object owns the complete controller gesture once a native descriptor is
-- selected.  The camera supplies only current buttons and the reticle hit.  A
-- host widget supplies the final mouse-equivalent dispatcher, preview renderer,
-- and optional command-specific parameter builder.

local Targeting = VFS.Include("luaui/Include/controller_native_targeting.lua")

local Owner = {}
Owner.__index = Owner

local function copy(source)
	local result = {}
	for key, value in pairs(type(source) == "table" and source or {}) do result[key] = value end
	return result
end

function Owner.New(config)
	config = type(config) == "table" and config or {}
	return setmetatable({
		name = tostring(config.name or "Order Menu"),
		types = config.types,
		dispatch = config.dispatch,
		buildParams = config.buildParams,
		onCancel = config.onCancel,
		onTransition = config.onTransition,
		state = Targeting.New(),
		dispatchCount = 0,
		lastDispatchSerial = nil,
		transitionRevision = 0,
	}, Owner)
end

function Owner:_transition(event, detail)
	self.transitionRevision = self.transitionRevision + 1
	self.state.ownerName = self.name
	self.state.ownerEvent = event
	self.state.ownerDetail = detail
	self.state.ownerRevision = self.transitionRevision
	if type(self.onTransition) == "function" then
		pcall(self.onTransition, event, detail, self:GetState())
	end
end

function Owner:Begin(descriptor)
	if type(descriptor) ~= "table" then return false, "descriptor unavailable" end
	Targeting.SetDescriptor(self.state, descriptor, self.types)
	if self.state.phase == Targeting.IDLE then return false, self.state.lastResult end
	self.dispatchCount = 0
	self.lastDispatchSerial = nil
	self:_transition("begin", self.state.phase)
	return true, self.state.phase
end

function Owner:Cancel(reason)
	local wasActive = self.state.phase ~= Targeting.IDLE
	Targeting.Reset(self.state, reason or "cancelled")
	if type(self.onCancel) == "function" then pcall(self.onCancel, reason) end
	if wasActive then self:_transition("cancel", reason or "cancelled") end
	return wasActive
end

function Owner:GetState()
	local state = copy(self.state)
	state.descriptor = copy(self.state.descriptor)
	state.anchor = copy(self.state.anchor)
	state.current = copy(self.state.current)
	state.ownerName = self.name
	state.dispatchCount = self.dispatchCount
	state.transitionRevision = self.transitionRevision
	return state
end

function Owner:IsActive()
	return self.state.phase ~= Targeting.IDLE and self.state.phase ~= Targeting.BUILD_PLACEMENT
end

function Owner:_issue(params, input)
	local serial = input and input.pressSerial
	if serial ~= nil and self.lastDispatchSerial == serial then
		return false, "duplicate press suppressed"
	end
	if self.dispatchCount > 0 then return false, "operation already dispatched" end
	self.lastDispatchSerial = serial
	local ok, accepted, route = pcall(self.dispatch, self.state.cmdID, params,
		input and input.options, input and input.dispatchMode, self.state.descriptor)
	if not ok or accepted ~= true then
		self.state.lastResult = tostring(route or accepted or "dispatch rejected")
		self:_transition("dispatch-rejected", self.state.lastResult)
		return false, self.state.lastResult
	end
	self.dispatchCount = self.dispatchCount + 1
	self.state.lastResult = "issued once via " .. tostring(route or "owner")
	self:_transition("dispatch", route or "owner")
	local descriptor = copy(self.state.descriptor)
	if input and input.queueActive then
		Targeting.Reset(self.state, "queued target issued")
		Targeting.SetDescriptor(self.state, descriptor, self.types)
		self.state.persistentUntilQueueRelease = true
		self.dispatchCount = 0
		self.lastDispatchSerial = nil
	else
		Targeting.Reset(self.state, "target issued")
	end
	return true, route
end

function Owner:Input(input)
	input = type(input) == "table" and input or {}
	if not self:IsActive() then return false, "inactive" end
	if self.state.persistentUntilQueueRelease and input.queueActive ~= true then
		self:Cancel("queue modifier released")
		return true, "queue-release"
	end
	if input.cancelPressed then
		self:Cancel("controller cancel")
		return true, "cancel"
	end

	Targeting.ObserveInput(self.state, input.selectDown, input.smartDown)
	if self.state.anchor and input.target then Targeting.UpdatePreview(self.state, input.target) end
	local pressed = input.selectPressed == true or input.smartPressed == true
	if pressed and Targeting.CanAcceptPress(self.state) then
		local params, result
		if self.state.anchor then
			params, result = Targeting.BuildAnchoredParams(self.state)
		else
			params, result = Targeting.BeginOrBuildPoint(self.state, input.target, self.types)
		end
		if params and type(self.buildParams) == "function" then
			local custom, customResult = self.buildParams(self.state, params, input)
			params, result = custom, customResult or result
		end
		if params then return self:_issue(params, input) end
		self.state.lastResult = tostring(result or "invalid target")
		self:_transition(result == "anchor" and "anchor" or "invalid", self.state.lastResult)
	end
	return true, self.state.lastResult
end

Owner.Targeting = Targeting
return Owner
