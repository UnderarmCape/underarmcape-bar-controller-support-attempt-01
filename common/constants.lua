-- constants.lua ---------------------------------------------------------------
-- General game and engine constants, for use in general Lua environments.

if not Engine or not Spring then return end

-- Controller-support engine compatibility shim for custom d5c8a21 Recoil.
-- Minimal local test patch: keep the rest of BAR constants.lua intact.
Engine.FeatureSupport = Engine.FeatureSupport or {}
Engine.versionMajor = tonumber(Engine.versionMajor) or 2025
Engine.versionMinor = tonumber(Engine.versionMinor) or 6
Engine.versionPatchSet = tonumber(Engine.versionPatchSet) or 19
Engine.commitsNumber = tonumber(Engine.commitsNumber) or 0

--------------------------------------------------------------------------------
-- Version handling ------------------------------------------------------------

---@param major integer
local function isEngineMinVersion(major, minor, patch, commit)
	if major ~= tonumber(Engine.versionMajor) then
		return major < tonumber(Engine.versionMajor)
	elseif minor and minor ~= tonumber(Engine.versionMinor) then
		return minor < tonumber(Engine.versionMinor)
	elseif patch and patch ~= tonumber(Engine.versionPatchSet) then
		return patch < tonumber(Engine.versionPatchSet)
	elseif commit and commit ~= tonumber(Engine.commitsNumber) then
		return commit < tonumber(Engine.commitsNumber)
	end
	return true
end

---@type boolean Whether the `targetBorder` property is doubled for BeamLaser and LightningCannon.
Engine.FeatureSupport.targetBorderBug = isEngineMinVersion(2025, 6, 4) and not isEngineMinVersion(2025, 6, 14)

--------------------------------------------------------------------------------
-- Extended LuaConst -----------------------------------------------------------

if CMD then
	CMD.NIL   = "n" -- Handling for unintended nil's.
	CMD.ANY   = "a" -- Matches on all command values.
	CMD.BUILD = "b" -- Filters for negative commands.

	CMD.n     = "NIL"
	CMD.a     = "ANY"
	CMD.b     = "BUILD"
end

--------------------------------------------------------------------------------
-- Game constants --------------------------------------------------------------

if Game then
	---The first frame that units are spawned. Used for scenario units and commanders.
	---@type integer
	Game.spawnInitialFrame = 2 * Game.gameSpeed

	---Non-scenario starting units spend a number of frames warping/teleporting in.
	---@type integer
	Game.spawnWarpInFrame = 3 * Game.gameSpeed
end
