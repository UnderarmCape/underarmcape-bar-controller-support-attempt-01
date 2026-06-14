local sourcePath = assert(arg[1], "expected controller_socket_bridge.lua path")
local ControllerSocketBridge = assert(dofile(sourcePath))
local bridge = ControllerSocketBridge.New({ staleSeconds = 0.25 })

local valid = bridge:ParsePacket(
	"BARCTRL1|1|1|100|-200|300|-400|500|600|100000000000000000000"
)
assert(valid, "valid packet was rejected")
assert(valid.sequence == 1 and valid.connected, "valid packet metadata was parsed incorrectly")
assert(valid.axes[1] == 100 and valid.axes[6] == 600, "valid axes were parsed incorrectly")
assert(bridge:ApplyPacket(valid), "first valid packet was not applied")
assert(bridge:GetControllerState(0).axes[2] == -200, "controller state did not update")
assert(not bridge:ApplyPacket(valid), "duplicate sequence was accepted")

local invalidPackets = {
	"",
	"WRONG|2|1|0|0|0|0|0|0|000000000000000000000",
	"BARCTRL1|2|1|32768|0|0|0|0|0|000000000000000000000",
	"BARCTRL1|2|1|0|0|0|0|0|0|00000000000000000000x",
	"BARCTRL1|2|2|0|0|0|0|0|0|000000000000000000000",
}
for _, packet in ipairs(invalidPackets) do
	assert(bridge:ParsePacket(packet) == nil, "malformed packet was accepted: " .. packet)
end

local disconnected = assert(bridge:ParsePacket(
	"BARCTRL1|2|0|1|2|3|4|5|6|111111111111111111111"
))
assert(bridge:ApplyPacket(disconnected), "disconnect packet was not applied")
local disconnectedState = bridge:GetControllerState(0)
for _, value in ipairs(disconnectedState.axes) do
	assert(value == 0, "disconnect did not neutralize axes")
end
for _, value in ipairs(disconnectedState.buttons) do
	assert(value == 0, "disconnect did not neutralize buttons")
end

local restarted = assert(bridge:ParsePacket(
	"BARCTRL1|0|1|10|20|30|40|50|60|010000000000000000000"
))
bridge.lastSequence = nil
assert(bridge:ApplyPacket(restarted), "restart sequence was not accepted")
bridge.udp = {
	receivefrom = function()
		return nil
	end,
}
bridge:Update(0.30)
assert(not bridge:IsConnected(), "stale packet stream remained connected")
assert(bridge:GetStatus() == "packet stream stale", "stale status was not reported")

print("PASS: UDP parser, sequence, disconnect, restart, and staleness smoke tests")
