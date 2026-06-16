--[[
read-only slice of the state relevant to the provided userid
]]
local Types = require("../Core/Types")
local State = require("../Core/State")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local derive = Vide.derive

export type PlayerSlice = {
	factionId: () -> string?,
	factionConfig: () -> Types.FactionConfig?,
	groupCounts: () -> { [string]: number },
	groupKey: () -> string?,
	groupConfig: () -> Types.GroupConfig?,
	groupEntries: () -> { Types.GroupConfig },
	classes: () -> { Types.ClassDescriptor },
}


return function(state: State.State, userId: string): PlayerSlice
	local sources = state:AsVideSources()

	local assignment = derive(function()
		return sources.playerAssignmentByUserId()[userId]
	end)

	local factionId = derive(function()
		local currentAssignment = assignment()
		return if currentAssignment then currentAssignment.FactionId else nil
	end)

	local factionConfig = derive(function()
		local id = factionId()
		if not id then
			return nil
		end
		return sources.configByFactionId()[id]
	end)

	local groupCounts = derive(function()
		local id = factionId()
		if not id then
			return {}
		end
		return sources.getGroupCountByFaction()[id] or {}
	end)

	local groupKey = derive(function()
		local currentAssignment = assignment()
		return if currentAssignment then currentAssignment.GroupKey else nil
	end)

	local groupConfig = derive(function()
		local config = factionConfig()
		local key = groupKey()
		if not config or not key then
			return nil
		end
		return config.Groups[key]
	end)

	-- map faction config groups to a table for indexes to iterate over
	-- this runs only when factionConfig() changes so its not that expensive
	local groupEntries = derive(function()
		local groups = {}
		local factionConfig = factionConfig()
		if not factionConfig then
			return groups
		end

		for key, config in pairs(factionConfig.Groups) do
			local entry = table.clone(config)
			entry.Key = key
			table.insert(groups, entry)
		end
		return groups
	end)

	local classes = derive(function()
		local config = groupConfig()
		return if config then config.Classes else {}
	end)

	return {
		factionId = factionId,
		factionConfig = factionConfig,
		groupCounts = groupCounts,
		groupKey = groupKey,
		groupConfig = groupConfig,
		groupEntries = groupEntries,
		classes = classes,
	}
end
