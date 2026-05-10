local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Types = require(script.Parent.Types)

local State = {}
State.__index = State

type self = {
	factionConfigs: Charm.Atom<{ [string]: Types.FactionConfig }>,
	playerByFactionId: Charm.Atom<{ [string]: string }>,
	playerByClassKey: Charm.Atom<{ [string]: string }>,
	playerByClassId: Charm.Atom<{ [string]: string }>,

	classCountByFaction: () -> { [string]: { [string]: number } },
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local self = setmetatable(
		{
			factionConfigs = Charm.atom({}),
			playerByFactionId = Charm.atom({}),
			playerByClassKey = Charm.atom({}),
			playerByClassId = Charm.atom({}),
		} :: self,
		State
	)

	self.classCountByFaction = Charm.computed(function()
		local factionConfigs = self.factionConfigs()
		local playerByFactionId = self.playerByFactionId()
		local playerByClassKey = self.playerByClassKey()
		local countsByFaction = {}

		for factionId, factionConfig in pairs(factionConfigs) do
			local counts = {}
			for classKey, _ in pairs(factionConfig.Classes) do
				counts[classKey] = 0
			end
			countsByFaction[factionId] = counts
		end

		for playerKey, factionId in pairs(playerByFactionId) do
			local classKey = playerByClassKey[playerKey]
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
