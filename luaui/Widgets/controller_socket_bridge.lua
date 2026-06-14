local ControllerSocketBridge = {}
ControllerSocketBridge.__index = ControllerSocketBridge

local PROTOCOL_MAGIC = "BARCTRL1"
local DEFAULT_HOST = "127.0.0.1"
local DEFAULT_PORT = 28777
local DEFAULT_STALE_SECONDS = 0.25
local CONTROLLER_INSTANCE_ID = 0
local CONTROLLER_DEVICE_ID = 0
local CONTROLLER_NAME = "BAR Companion XInput Controller 0"
local AXIS_COUNT = 6
local BUTTON_COUNT = 21
local UINT32_MODULUS = 4294967296
local UINT32_HALF_RANGE = 2147483648

local function newZeroArray(count)
	local values = {}
	for i = 1, count do
		values[i] = 0
	end
	return values
end

local function splitPacket(packet)
	local fields = {}
	for field in string.gmatch(packet .. "|", "(.-)|") do
		fields[#fields + 1] = field
	end
	return fields
end

local function parseUnsignedInteger(value, maximum)
	if type(value) ~= "string" or not string.match(value, "^%d+$") then
		return nil
	end

	local number = tonumber(value)
	if not number or number < 0 or number > maximum or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function parseSignedInteger(value, minimum, maximum)
	if type(value) ~= "string"
		or (not string.match(value, "^%d+$") and not string.match(value, "^%-%d+$"))
	then
		return nil
	end

	local number = tonumber(value)
	if not number or number < minimum or number > maximum or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function isNewerSequence(candidate, current)
	if current == nil then
		return true
	end

	local difference = (candidate - current) % UINT32_MODULUS
	return difference > 0 and difference < UINT32_HALF_RANGE
end

local function clearArray(values)
	for i = 1, #values do
		values[i] = 0
	end
end

function ControllerSocketBridge.New(options)
	options = options or {}

	local self = setmetatable({}, ControllerSocketBridge)
	self.host = options.host or DEFAULT_HOST
	self.port = tonumber(options.port) or DEFAULT_PORT
	self.staleSeconds = tonumber(options.staleSeconds) or DEFAULT_STALE_SECONDS
	self.socketApi = options.socketApi or rawget(_G, "socket")
	self.udp = nil
	self.now = 0
	self.lastPacketTime = nil
	self.lastSequence = nil
	self.hasReceivedPacket = false
	self.connected = false
	self.status = "not initialized"
	self.validPacketCount = 0
	self.rejectedPacketCount = 0
	self.controllerInfo = {
		instanceID = CONTROLLER_INSTANCE_ID,
		deviceID = CONTROLLER_DEVICE_ID,
		name = CONTROLLER_NAME,
	}
	self.controllerState = {
		instanceID = CONTROLLER_INSTANCE_ID,
		name = CONTROLLER_NAME,
		axes = newZeroArray(AXIS_COUNT),
		buttons = newZeroArray(BUTTON_COUNT),
	}
	self.availableControllers = { self.controllerInfo }
	return self
end

function ControllerSocketBridge:SetNeutral()
	clearArray(self.controllerState.axes)
	clearArray(self.controllerState.buttons)
end

function ControllerSocketBridge:IsFresh()
	return self.lastPacketTime ~= nil
		and (self.now - self.lastPacketTime) <= self.staleSeconds
end

function ControllerSocketBridge:IsConnected()
	return self.connected and self:IsFresh()
end

function ControllerSocketBridge:Initialize()
	if self.udp ~= nil then
		return true
	end
	if type(self.socketApi) ~= "table" or type(self.socketApi.udp) ~= "function" then
		self.status = "LuaSocket unavailable"
		return false, self.status
	end

	local udp, createError = self.socketApi.udp()
	if not udp then
		self.status = "UDP create failed: " .. tostring(createError)
		return false, self.status
	end

	local timeoutOk, timeoutError = udp:settimeout(0)
	if timeoutOk == nil then
		udp:close()
		self.status = "UDP nonblocking setup failed: " .. tostring(timeoutError)
		return false, self.status
	end

	local bindOk, bindError = udp:setsockname(self.host, self.port)
	if bindOk == nil then
		udp:close()
		self.status = "UDP bind failed: " .. tostring(bindError)
		return false, self.status
	end

	self.udp = udp
	self.status = string.format("listening on %s:%d", self.host, self.port)
	return true
end

function ControllerSocketBridge:ParsePacket(packet)
	if type(packet) ~= "string" or #packet > 256 then
		return nil
	end

	local fields = splitPacket(packet)
	if #fields ~= 10 or fields[1] ~= PROTOCOL_MAGIC then
		return nil
	end

	local sequence = parseUnsignedInteger(fields[2], UINT32_MODULUS - 1)
	local connected = parseUnsignedInteger(fields[3], 1)
	local leftX = parseSignedInteger(fields[4], -32768, 32767)
	local leftY = parseSignedInteger(fields[5], -32768, 32767)
	local rightX = parseSignedInteger(fields[6], -32768, 32767)
	local rightY = parseSignedInteger(fields[7], -32768, 32767)
	local leftTrigger = parseUnsignedInteger(fields[8], 32767)
	local rightTrigger = parseUnsignedInteger(fields[9], 32767)
	local buttons = fields[10]

	if sequence == nil
		or connected == nil
		or leftX == nil
		or leftY == nil
		or rightX == nil
		or rightY == nil
		or leftTrigger == nil
		or rightTrigger == nil
		or #buttons ~= BUTTON_COUNT
		or string.find(buttons, "[^01]") ~= nil
	then
		return nil
	end

	return {
		sequence = sequence,
		connected = connected == 1,
		axes = { leftX, leftY, rightX, rightY, leftTrigger, rightTrigger },
		buttons = buttons,
	}
end

function ControllerSocketBridge:ApplyPacket(packet)
	if not isNewerSequence(packet.sequence, self.lastSequence) then
		return false
	end

	self.lastSequence = packet.sequence
	self.lastPacketTime = self.now
	self.hasReceivedPacket = true
	self.connected = packet.connected

	if not packet.connected then
		self:SetNeutral()
		self.status = "companion connected; controller disconnected"
		return true
	end

	for i = 1, AXIS_COUNT do
		self.controllerState.axes[i] = packet.axes[i]
	end
	for i = 1, BUTTON_COUNT do
		self.controllerState.buttons[i] = string.byte(packet.buttons, i) == 49 and 1 or 0
	end
	self.status = "receiving controller packets"
	return true
end

function ControllerSocketBridge:Update(dt)
	self.now = self.now + math.max(0, tonumber(dt) or 0)
	if self.udp == nil then
		return
	end

	while true do
		local data, sourceIp = self.udp:receivefrom()
		if data == nil then
			break
		end

		if sourceIp ~= self.host then
			self.rejectedPacketCount = self.rejectedPacketCount + 1
		else
			local packet = self:ParsePacket(data)
			if packet and self:ApplyPacket(packet) then
				self.validPacketCount = self.validPacketCount + 1
			else
				self.rejectedPacketCount = self.rejectedPacketCount + 1
			end
		end
	end

	if self.lastPacketTime ~= nil and not self:IsFresh() then
		self.connected = false
		self.lastSequence = nil
		self:SetNeutral()
		self.status = "packet stream stale"
	end
end

function ControllerSocketBridge:GetAvailableControllers()
	if self.hasReceivedPacket then
		return self.availableControllers
	end
	return {}
end

function ControllerSocketBridge:GetControllerState(instanceID)
	if tonumber(instanceID) ~= CONTROLLER_INSTANCE_ID then
		return nil
	end
	if not self:IsConnected() then
		self:SetNeutral()
	end
	return self.controllerState
end

function ControllerSocketBridge:GetStatus()
	return self.status
end

function ControllerSocketBridge:Shutdown()
	if self.udp ~= nil then
		self.udp:close()
		self.udp = nil
	end
	self.connected = false
	self:SetNeutral()
	self.status = "stopped"
end

return ControllerSocketBridge
