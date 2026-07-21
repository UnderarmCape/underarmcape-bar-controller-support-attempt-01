--------------------------------------------------------------------------------
-- BAR Controller Support - production settings and contextual hint runtime
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Controller UI Runtime",
		desc = "Lean controller UI settings and contextual hints (no authoring paths)",
		author = "Kailil / Codex", date = "2026-07-21", license = "GNU GPL, v2 or later",
		layer = -99990, enabled = true, handler = true,
	}
end

local Runtime = VFS.Include("LuaUI/Include/controller_ui_runtime.lua")
local service
local pendingConfig

function widget:Initialize()
	service = Runtime.New()
	if pendingConfig then service:SetConfigData(pendingConfig); pendingConfig = nil end
	WG.ControllerUISettings = service:PublicAPI()
	WG.ControllerHintRegistry = service:HintAPI()
end

function widget:Shutdown()
	WG.ControllerUISettings = nil
	WG.ControllerHintRegistry = nil
	service = nil
end

function widget:ViewResize(vsx, vsy)
	if service then service.viewX, service.viewY = vsx, vsy; service:Recalculate() end
end

function widget:Update(dt) if service then service:Update(dt) end end
function widget:DrawScreen() if service then service:Draw() end end
function widget:GetConfigData() return service and service:GetConfigData() or nil end
function widget:SetConfigData(data) if service then service:SetConfigData(data) else pendingConfig = data end end
