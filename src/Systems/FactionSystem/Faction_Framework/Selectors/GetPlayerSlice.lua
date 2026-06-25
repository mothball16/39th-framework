--[[
read-only slice of the state relevant to the provided userid
]]
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Types = require("../Core/Types")
local State = require("../Core/State")
local Utilities = require("../Logic/Utilities")
export type PlayerSlice = {
	factionId: Charm.Getter<string?>,
	factionConfig: Charm.Getter<Types.FactionConfig?>,
	classCounts: Charm.Getter<{ [string]: number }>,
	classKey: Charm.Getter<string?>,
	variantId: Charm.Getter<string?>,
	classConfig: Charm.Getter<Types.ClassConfig?>,
	classEntries: Charm.Getter<{ Types.ClassConfig }>,
	variants: Charm.Getter<{ Types.VariantDescriptor }>,
}

return function(state: State.State, userId: string): PlayerSlice
	local userKey = Utilities.ToPlayerKey(userId)
	local assignment = Charm.computed(function()
		return state.playerAssignmentByUserId()[userKey]
	end)

	local factionId = Charm.computed(function()
		local currentAssignment = assignment()
		return if currentAssignment then currentAssignment.FactionId else nil
	end)

	local factionConfig = Charm.computed(function()
		local id = factionId()
		if not id then
			return nil
		end
		return state.configByFactionId()[id]
	end)

	local classCounts = Charm.computed(function()
		local id = factionId()
		if not id then
			return {}
		end
		return state.getClassCountByFaction()[id] or {}
	end)

	local classKey = Charm.computed(function()
		local currentAssignment = assignment()
		
		return if currentAssignment then currentAssignment.ClassKey else nil
	end)

	local variantId = Charm.computed(function()
		local currentAssignment = assignment()
		return if currentAssignment then currentAssignment.VariantId else nil
	end)

	local classConfig = Charm.computed(function()
		local config = factionConfig()
		local key = classKey()
		if not config or not key then
			return nil
		end
		return config.Classes[key]
	end)

	-- map faction config classes to a table for indexes to iterate over
	-- this runs only when factionConfig() changes so its not that expensive
	local classEntries = Charm.computed(function()
		local classes = {}
		local config = factionConfig()
		if not config then
			return classes
		end

		for key, classEntry in pairs(config.Classes) do
			local entry = table.clone(classEntry)
			entry.Key = key
			table.insert(classes, entry)
		end
		return classes
	end)

	local variants = Charm.computed(function()
		local config = classConfig()
		return if config then config.Variants else {}
	end)

	return {
		factionId = factionId,
		factionConfig = factionConfig,
		classCounts = classCounts,
		classKey = classKey,
		variantId = variantId,
		classConfig = classConfig,
		classEntries = classEntries,
		variants = variants,
	}
end
