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
	groupCounts: Charm.Getter<{ [string]: number }>,
	groupKey: Charm.Getter<string?>,
	classId: Charm.Getter<string?>,
	groupConfig: Charm.Getter<Types.GroupConfig?>,
	groupEntries: Charm.Getter<{ Types.GroupConfig }>,
	classes: Charm.Getter<{ Types.ClassDescriptor }>,
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

	local groupCounts = Charm.computed(function()
		local id = factionId()
		if not id then
			return {}
		end
		return state.getGroupCountByFaction()[id] or {}
	end)

	local groupKey = Charm.computed(function()
		local currentAssignment = assignment()
		
		return if currentAssignment then currentAssignment.GroupKey else nil
	end)

	local classId = Charm.computed(function()
		local currentAssignment = assignment()
		return if currentAssignment then currentAssignment.ClassId else nil
	end)

	local groupConfig = Charm.computed(function()
		local config = factionConfig()
		local key = groupKey()
		if not config or not key then
			return nil
		end
		return config.Groups[key]
	end)

	-- map faction config groups to a table for indexes to iterate over
	-- this runs only when factionConfig() changes so its not that expensive
	local groupEntries = Charm.computed(function()
		local groups = {}
		local config = factionConfig()
		if not config then
			return groups
		end

		for key, group in pairs(config.Groups) do
			local entry = table.clone(group)
			entry.Key = key
			table.insert(groups, entry)
		end
		return groups
	end)

	local classes = Charm.computed(function()
		local config = groupConfig()
		return if config then config.Classes else {}
	end)

	return {
		factionId = factionId,
		factionConfig = factionConfig,
		groupCounts = groupCounts,
		groupKey = groupKey,
		classId = classId,
		groupConfig = groupConfig,
		groupEntries = groupEntries,
		classes = classes,
	}
end
