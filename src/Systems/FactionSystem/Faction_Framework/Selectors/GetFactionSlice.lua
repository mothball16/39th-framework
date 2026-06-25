--[[
read-only, reactive slice of faction-scoped state for a given factionId.
factionId may be a static id or a reactive getter so the slice can be
composed by other selectors later (e.g. a player slice deriving its faction).
]]
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local computed = Charm.computed

local Types = require("../Core/Types")
local State = require("../Core/State")

-- a faction's class config paired with its key, for ordered iteration
export type ClassEntry = Types.ClassConfig & { Key: string }

export type FactionSlice = {
	config: Charm.Getter<Types.FactionConfig?>,
	members: Charm.Getter<{ Types.PlayerKey }>,
	classCounts: Charm.Getter<{ [string]: number }>,
	classes: Charm.Getter<{ ClassEntry }>,
}

return function(state: State.State, factionId: string | Charm.Getter<string?>): FactionSlice
	local getFactionId: Charm.Getter<string?> = if type(factionId) == "function"
		then factionId
		else function()
			return factionId
		end

	local config = computed(function()
		local id = getFactionId()
		return if id then state.configByFactionId()[id] else nil
	end)

	-- userKeys of every player currently assigned to this faction
	local members = computed(function()
		local id = getFactionId()
		local result: { Types.PlayerKey } = {}
		if not id then
			return result
		end
		for userKey, assignment in state.playerAssignmentByUserId() do
			if assignment.FactionId == id then
				table.insert(result, userKey)
			end
		end
		return result
	end)

	local classCounts = computed(function()
		local id = getFactionId()
		return if id then state.getClassCountByFaction()[id] or {} else {}
	end)

	-- dict -> ordered array, tagging each entry with its key. only reruns when
	-- config changes, so the table.clone churn is bounded to config edits.
	local classes = computed(function()
		local result: { ClassEntry } = {}
		local cfg = config()
		if not cfg then
			return result
		end
		for key, classConfig in cfg.Classes do
			local entry = table.clone(classConfig) :: ClassEntry
			entry.Key = key
			table.insert(result, entry)
		end
		return result
	end)

	return {
		config = config,
		members = members,
		classCounts = classCounts,
		classes = classes,
	}
end
