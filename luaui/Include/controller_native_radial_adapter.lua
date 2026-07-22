-- Controller native radial adapter (v0.8 experimental).
--
-- This module is intentionally free of Spring/WG calls.  Patched BAR widgets
-- own authoritative descriptors and activation; this adapter only gives those
-- descriptors stable identities, categories, pages and radial slots.

local Adapter = {}
Adapter.__index = Adapter

Adapter.SLOT_COUNT = 8
Adapter.BUILDER_CATEGORY_ORDER = {
	"Economy", "Combat", "Defense", "Utility", "Production", "Special",
}
Adapter.TACTICAL_CATEGORY_ORDER = { "utility", "tactical" }

local function shallowCopy(source)
	local result = {}
	for key, value in pairs(type(source) == "table" and source or {}) do
		result[key] = value
	end
	return result
end

local function normalizedText(value)
	return string.lower(tostring(value or ""))
end

local function stableBuildKey(item)
	if type(item) ~= "table" then return nil end
	if item.stableKey then return tostring(item.stableKey) end
	local unitDefID = tonumber(item.unitDefID)
	if unitDefID then return "build:" .. tostring(unitDefID) end
	local cmdID = tonumber(item.cmdID or item.id)
	if cmdID then return "buildcmd:" .. tostring(cmdID) end
	return nil
end

local function stableCommandKey(item)
	if type(item) ~= "table" then return nil end
	if item.stableKey then return tostring(item.stableKey) end
	local cmdID = tonumber(item.cmdID or item.id)
	if cmdID then return "cmd:" .. tostring(cmdID) end
	return nil
end

local function stateLabels(params)
	local labels = {}
	if type(params) == "table" then
		for index = 2, #params do
			local label = params[index]
			if label ~= nil and tostring(label) ~= "" then
				labels[#labels + 1] = tostring(label)
			end
		end
	end
	return labels
end

local function tacticalCategory(item)
	if item.tacticalCategory == "utility" or item.tacticalCategory == "tactical" then
		return item.tacticalCategory
	end
	local text = normalizedText(item.name) .. " " .. normalizedText(item.action)
		.. " " .. normalizedText(item.tooltip)
	if item.isState
		or text:find("cloak", 1, true)
		or text:find("visible", 1, true)
		or text:find("fire state", 1, true)
		or text:find("firestate", 1, true)
		or text:find("move state", 1, true)
		or text:find("movestate", 1, true)
		or text:find("repeat", 1, true)
		or text:find("on/off", 1, true)
		or text:find("onoff", 1, true)
		or text:find("priority", 1, true)
		or text:find("wait", 1, true)
		or text:find("stop", 1, true)
		or text:find("clear queue", 1, true)
	then
		return "utility"
	end
	return "tactical"
end

local function tacticalKind(item)
	local action = normalizedText(item.action)
	local text = normalizedText(item.name) .. " " .. action
	if text:find("reclaim", 1, true) then return "reclaim" end
	if text:find("repair", 1, true) then return "repair" end
	if text:find("guard", 1, true) then return "alliedUnit" end
	if text:find("attack", 1, true) or text:find("manual fire", 1, true)
		or action == "settarget" then return "attack" end
	if text:find("move", 1, true) or text:find("fight", 1, true)
		or text:find("patrol", 1, true) or text:find("restore", 1, true)
		or text:find("capture", 1, true) then return "ground" end
	return "none"
end

local function claimPosition(occupied, preferred)
	local position = math.max(1, math.floor(tonumber(preferred) or 1))
	while occupied[position] do position = position + 1 end
	occupied[position] = true
	return position
end

function Adapter.New()
	return setmetatable({
		canonicalBuilderPositions = {},
		canonicalFactoryPositions = {},
	}, Adapter)
end

function Adapter.StableBuildKey(item)
	return stableBuildKey(item)
end

function Adapter.StableCommandKey(item)
	return stableCommandKey(item)
end

function Adapter:BuildBuildModel(sourceItems, context)
	context = context or {}
	local factory = context.isFactory == true
	local canonical = factory and self.canonicalFactoryPositions or self.canonicalBuilderPositions
	local occupiedByScope, result, categoriesSeen = {}, {}, {}
	local classifier = type(context.classify) == "function" and context.classify or nil

	for sourceIndex, source in ipairs(type(sourceItems) == "table" and sourceItems or {}) do
		local key = stableBuildKey(source)
		if key then
			local item = shallowCopy(source)
			local category = factory and "Factory" or item.category
			if not category and classifier then category = classifier(item) end
			category = tostring(category or "Special")
			local vanillaPosition = tonumber(item.vanillaIndex or item.cell or item.index) or sourceIndex
			local canonicalKey = (factory and "factory:" or category .. ":") .. key
			if not canonical[canonicalKey] then canonical[canonicalKey] = vanillaPosition end
			local preferred = canonical[canonicalKey]
			local occupied = occupiedByScope[category]
			if not occupied then occupied = {}; occupiedByScope[category] = occupied end
			local position = claimPosition(occupied, preferred)

			item.stableKey = key
			item.category = category
			item.vanillaIndex = vanillaPosition
			item.canonicalPosition = position
			item.radialPage = math.floor((position - 1) / Adapter.SLOT_COUNT) + 1
			item.radialSlot = ((position - 1) % Adapter.SLOT_COUNT) + 1
			item.slotException = position ~= preferred
			item.cmdID = tonumber(item.cmdID or item.id)
			item.unitDefID = tonumber(item.unitDefID) or (item.cmdID and item.cmdID < 0 and -item.cmdID or nil)
			item.name = item.name or item.label or (item.unitDefID and tostring(item.unitDefID)) or "Build"
			item.shortLabel = item.shortLabel or item.name
			item.iconTexture = item.iconTexture or (item.unitDefID and ("#" .. tostring(item.unitDefID)) or nil)
			item.disabled = item.disabled == true
			item.queueCount = tonumber(item.queueCount) or 0
			result[#result + 1] = item
			categoriesSeen[category] = true
		end
	end

	table.sort(result, function(a, b)
		if a.category ~= b.category then return a.category < b.category end
		if a.canonicalPosition ~= b.canonicalPosition then return a.canonicalPosition < b.canonicalPosition end
		return a.stableKey < b.stableKey
	end)

	local categories = {}
	if factory then
		if #result > 0 then categories[1] = "Factory" end
	else
		for _, category in ipairs(Adapter.BUILDER_CATEGORY_ORDER) do
			if categoriesSeen[category] then categories[#categories + 1] = category end
		end
		local extras = {}
		for category in pairs(categoriesSeen) do
			local known = false
			for _, expected in ipairs(Adapter.BUILDER_CATEGORY_ORDER) do
				if category == expected then known = true; break end
			end
			if not known then extras[#extras + 1] = category end
		end
		table.sort(extras)
		for _, category in ipairs(extras) do categories[#categories + 1] = category end
	end

	local selectedKey = context.previousStableKey
	local selectedIndex
	for index, item in ipairs(result) do
		if item.stableKey == selectedKey then selectedIndex = index; break end
	end
	if not selectedIndex and #result > 0 then selectedIndex, selectedKey = 1, result[1].stableKey end

	return {
		kind = factory and "factory" or "builder",
		items = result,
		categories = categories,
		selectedIndex = selectedIndex or 1,
		selectedStableKey = selectedKey,
		slotCount = Adapter.SLOT_COUNT,
		revision = tonumber(context.revision) or 0,
	}
end

function Adapter:BuildTacticalModel(sourceCommands, context)
	context = context or {}
	local items, byCategory = {}, { utility = {}, tactical = {} }
	for sourceIndex, source in ipairs(type(sourceCommands) == "table" and sourceCommands or {}) do
		local key = stableCommandKey(source)
		if key then
			local item = shallowCopy(source)
			item.stableKey = key
			item.cmdID = tonumber(item.cmdID or item.id)
			item.name = item.name or item.label or item.action or "Command"
			item.shortLabel = item.shortLabel or item.name
			item.tooltip = item.tooltip or ""
			item.disabled = item.disabled == true
			item.isState = item.isState == true
			item.states = stateLabels(item.params)
			item.currentStateIndex = tonumber(item.currentStateIndex)
				or tonumber(type(item.params) == "table" and item.params[1]) or 0
			item.currentStateLabel = item.states[item.currentStateIndex + 1]
			item.isBinaryState = item.isState and #item.states == 2
			item.kind = item.kind or tacticalKind(item)
			item.tacticalCategory = tacticalCategory(item)
			item.vanillaIndex = tonumber(item.vanillaIndex or item.cell or item.index) or sourceIndex
			items[#items + 1] = item
			byCategory[item.tacticalCategory][#byCategory[item.tacticalCategory] + 1] = item
		end
	end

	local selectedKey = context.previousStableKey
	local category = context.previousCategory
	if category ~= "utility" and category ~= "tactical" then category = "tactical" end
	local selectedIndex
	for index, item in ipairs(byCategory[category]) do
		if item.stableKey == selectedKey then selectedIndex = index; break end
	end
	if not selectedIndex and #byCategory[category] > 0 then
		selectedIndex, selectedKey = 1, byCategory[category][1].stableKey
	end
	if #byCategory[category] == 0 then
		category = category == "utility" and "tactical" or "utility"
		selectedIndex = #byCategory[category] > 0 and 1 or nil
		selectedKey = selectedIndex and byCategory[category][1].stableKey or nil
	end

	return {
		kind = "tactical",
		items = items,
		byCategory = byCategory,
		category = category,
		selectedIndex = selectedIndex or 1,
		selectedStableKey = selectedKey,
		revision = tonumber(context.revision) or 0,
	}
end

function Adapter.FindByStableKey(model, stableKey)
	if not stableKey then return nil end
	for index, item in ipairs(type(model) == "table" and model.items or {}) do
		if item.stableKey == stableKey then return item, index end
	end
	return nil
end

function Adapter.FindTactical(model, stableKey)
	local item = Adapter.FindByStableKey(model, stableKey)
	if not item then return nil end
	local category = item.tacticalCategory
	for index, candidate in ipairs(model.byCategory and model.byCategory[category] or {}) do
		if candidate.stableKey == stableKey then return candidate, index, category end
	end
	return nil
end

return Adapter
