local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local useAtom = VideCharm.useAtom

local Types = require("./Types")

local State = {}
State.__index = State

type self = {
	configByFactionId: Charm.Atom<{ [string]: Types.FactionConfig }>,
	playerByFactionId: Charm.Atom<{ [string]: string }>,
	playerByGroupKey: Charm.Atom<{ [string]: string }>,
	playerByClassId: Charm.Atom<{ [string]: string }>,

	groupCountByFaction: () -> { [string]: { [string]: number } },
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local self = setmetatable(
		{
			configByFactionId = Charm.atom({}),
			playerByFactionId = Charm.atom({}),
			playerByGroupKey = Charm.atom({}),
			playerByClassId = Charm.atom({}),
		} :: self,
		State
	)

	self.groupCountByFaction = Charm.computed(function()
		local configByFactionId = self.configByFactionId()
		local playerByFactionId = self.playerByFactionId()
		local playerByGroupKey = self.playerByGroupKey()
		local countsByFaction = {}

		for factionId, factionConfig in pairs(configByFactionId) do
			local counts = {}
			for groupKey, _ in pairs(factionConfig.Groups) do
				counts[groupKey] = 0
			end
			countsByFaction[factionId] = counts
		end

		for userId, factionId in pairs(playerByFactionId) do
			local groupKey = playerByGroupKey[userId]
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
		playerByFactionId = useAtom(self.playerByFactionId),
		playerByGroupKey = useAtom(self.playerByGroupKey),
		playerByClassId = useAtom(self.playerByClassId),
		groupCountByFaction = useAtom(self.groupCountByFaction),
	}
end

function State:Destroy()
	-- i think atoms automatically cleanup?
end


return State
