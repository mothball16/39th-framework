local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Types = require(script.Parent.Types)

local State = {}
State.__index = State

type ClassCountByFaction = { [string]: { [string]: number } }

type self = {
	factionConfigs: Charm.Atom<{ [string]: Types.FactionConfig }>,
	playerFactionIds: Charm.Atom<{ [string]: string }>,
	playerClassKeys: Charm.Atom<{ [string]: string }>,
	playerClassIds: Charm.Atom<{ [string]: string }>,
	classCountsByFaction: any,
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local self = setmetatable(
		{
			factionConfigs = Charm.atom({}),
			playerFactionIds = Charm.atom({}),
			playerClassKeys = Charm.atom({}),
			playerClassIds = Charm.atom({}),
		} :: self,
		State
	)

	self.classCountsByFaction = Charm.computed(function()
		local factionConfigs = self.factionConfigs()
		local playerFactionIds = self.playerFactionIds()
		local playerClassKeys = self.playerClassKeys()
		local countsByFaction = {}

		for factionId, factionConfig in pairs(factionConfigs) do
			local counts = {}
			for classKey, _ in pairs(factionConfig.Classes) do
				counts[classKey] = 0
			end
			countsByFaction[factionId] = counts
		end

		for playerKey, factionId in pairs(playerFactionIds) do
			local classKey = playerClassKeys[playerKey]
			if not classKey then
				continue
			end

			local factionCounts = countsByFaction[factionId]
			if factionCounts == nil then
				factionCounts = {}
				countsByFaction[factionId] = factionCounts
			end
			factionCounts[classKey] = (factionCounts[classKey] or 0) + 1
		end

		return countsByFaction
	end)

	return self
end

function State:Destroy()
	-- i think atoms automatically cleanup?
end


return State
