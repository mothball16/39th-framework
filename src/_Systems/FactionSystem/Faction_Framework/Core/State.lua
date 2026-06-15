local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local useAtom = VideCharm.useAtom

local Types = require("./Types")

local State = {}
State.__index = State

type self = {
	configByFactionId: Charm.Atom<{ [string]: Types.FactionConfig }>,
	playerAssignmentByUserId: Charm.Atom<{ [string]: Types.PlayerClassAssignment }>,

	groupCountByFaction: () -> { [string]: { [string]: number } },
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local self = setmetatable(
		{
			configByFactionId = Charm.atom({}),
			playerAssignmentByUserId = Charm.atom({}),
		} :: self,
		State
	)

	self.groupCountByFaction = Charm.computed(function()
		local configByFactionId = self.configByFactionId()
		local playerAssignmentByUserId = self.playerAssignmentByUserId()
		local countsByFaction = {}

		for factionId, factionConfig in pairs(configByFactionId) do
			local counts = {}
			for groupKey, _ in pairs(factionConfig.Groups) do
				counts[groupKey] = 0
			end
			countsByFaction[factionId] = counts
		end

		for _, assignment in pairs(playerAssignmentByUserId) do
			local factionId = assignment.FactionId
			local groupKey = assignment.GroupKey
			if not groupKey then
				continue
			end

			local factionCounts = countsByFaction[factionId]
			if factionCounts == nil then
				factionCounts = {}
				countsByFaction[factionId] = factionCounts
			end
			factionCounts[groupKey] = (factionCounts[groupKey] or 0) + 1
		end

		return countsByFaction
	end)

	return self
end

function State:AsVideSources()
	return {
		configByFactionId = useAtom(self.configByFactionId),
		playerAssignmentByUserId = useAtom(self.playerAssignmentByUserId),
		groupCountByFaction = useAtom(self.groupCountByFaction),
	}
end

function State:Destroy()
	-- i think atoms automatically cleanup?
end


return State
