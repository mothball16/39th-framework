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

local function updateMapValue(atom, key: string, value: string?)
	atom(function(previous)
		local existing = previous[key]
		if existing == value then
			return previous
		end

		local nextState = table.clone(previous)
		nextState[key] = value
		return nextState
	end)
end

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

function State:CreateFaction(config: Types.FactionConfig)
	self.factionConfigs(function(previous)
		local nextState = table.clone(previous)
		nextState[config.ID] = config
		return nextState
	end)

	return config
end

function State:RemoveFaction(factionId: string)
	self.factionConfigs(function(previous)
		if previous[factionId] == nil then
			return previous
		end
		local nextState = table.clone(previous)
		nextState[factionId] = nil
		return nextState
	end)

	local removedPlayerKeys: { [string]: boolean } = {}

	self.playerFactionIds(function(previous)
		local changed = false
		local nextState = table.clone(previous)

		for memberKey, assignedFactionId in pairs(previous) do
			if assignedFactionId == factionId then
				nextState[memberKey] = nil
				removedPlayerKeys[memberKey] = true
				changed = true
			end
		end

		if not changed then
			return previous
		end
		return nextState
	end)

	if next(removedPlayerKeys) == nil then
		return
	end

	self.playerClassKeys(function(previous)
		local nextState = table.clone(previous)
		local changed = false
		for memberKey, _ in pairs(nextState) do
			if removedPlayerKeys[memberKey] then
				nextState[memberKey] = nil
				changed = true
			end
		end
		if not changed then
			return previous
		end
		return nextState
	end)

	self.playerClassIds(function(previous)
		local nextState = table.clone(previous)
		local changed = false
		for memberKey, _ in pairs(nextState) do
			if removedPlayerKeys[memberKey] then
				nextState[memberKey] = nil
				changed = true
			end
		end
		if not changed then
			return previous
		end
		return nextState
	end)
end

function State:SetPlayerClass(userId: number, factionId: string?, classKey: string?, classId: string?)
	local playerKey = tostring(userId)
	local previousFactionId = self.playerFactionIds()[playerKey]
	local previousClassKey = self.playerClassKeys()[playerKey]
	local previousClassId = self.playerClassIds()[playerKey]
	if previousFactionId == factionId and previousClassKey == classKey and previousClassId == classId then
		return
	end

	local hasFullAssignment = factionId ~= nil and classKey ~= nil and classId ~= nil
	local nextFactionId = if hasFullAssignment then factionId else nil
	local nextClassKey = if hasFullAssignment then classKey else nil
	local nextClassId = if hasFullAssignment then classId else nil

	updateMapValue(self.playerFactionIds, playerKey, nextFactionId)
	updateMapValue(self.playerClassKeys, playerKey, nextClassKey)
	updateMapValue(self.playerClassIds, playerKey, nextClassId)
end

function State:GetClassOccupancyCount(factionId: string, classKey: string): number
	local classCountsByFaction = self.classCountsByFaction()
	local factionCounts = classCountsByFaction[factionId]
	if not factionCounts then
		return 0
	end
	return factionCounts[classKey] or 0
end

function State:SetFactionMemberClass(factionId: string, userId: number, classKey: string, classId: string)
	self:SetPlayerClass(userId, factionId, classKey, classId)
end

function State:AddFactionMember(faction: Types.FactionConfig | Types.Faction, userId: number, classKey: string, classId: string)
	local resolvedFactionId = if faction.Config then faction.Config.ID else faction.ID
	self:SetPlayerClass(userId, resolvedFactionId, classKey, classId)
end

function State:RemoveFactionMember(faction: Types.FactionConfig | Types.Faction, userId: number)
	local resolvedFactionId = if faction.Config then faction.Config.ID else faction.ID
	local playerKey = tostring(userId)
	local playerFactionId = self.playerFactionIds()[playerKey]
	if playerFactionId == resolvedFactionId then
		self:SetPlayerClass(userId, nil, nil, nil)
	end
end

function State:RemoveFactionMemberFromAll(userId: number)
	self:SetPlayerClass(userId, nil, nil, nil)
end

return State
