local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Types = require(script.Parent.Types)

local State = {}
State.__index = State

type self = {
	FactionConfigs: Charm.Atom<{ [string]: Types.FactionConfig }>,
	PlayerAssignments: Charm.Atom<{ [string]: Types.PlayerClassAssignment }>,
	FactionClassCounts: any,
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local self = setmetatable(
		{
			FactionConfigs = Charm.atom({}),
			PlayerAssignments = Charm.atom({}),
		} :: self,
		State
	)

	self.FactionClassCounts = Charm.computed(function()
		local factionConfigs = self.FactionConfigs()
		local assignments = self.PlayerAssignments()
		local countsByFaction = {}

		for factionId, factionConfig in pairs(factionConfigs) do
			local counts = {}
			for classKey, _ in pairs(factionConfig.Classes) do
				counts[classKey] = 0
			end
			countsByFaction[factionId] = counts
		end

		for _, assignment in pairs(assignments) do
			local factionId = assignment.FactionId
			local classKey = assignment.ClassKey
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
	self.FactionConfigs(function(previous)
		local nextState = table.clone(previous)
		nextState[config.ID] = config
		return nextState
	end)

	return config
end

function State:RemoveFaction(factionId: string)
	self.FactionConfigs(function(previous)
		if previous[factionId] == nil then
			return previous
		end
		local nextState = table.clone(previous)
		nextState[factionId] = nil
		return nextState
	end)

	self.PlayerAssignments(function(state)
		state = table.clone(state)
		for memberKey, assignment in pairs(state) do
			if assignment.FactionId == factionId then
				state[memberKey] = nil
			end
		end
		return state
	end)
end

function State:SetPlayerClass(userId: number, factionId: string?, classKey: string?, classId: string?)
	local memberKey = tostring(userId)
	local previousAssignment = self.PlayerAssignments()[memberKey]

	if previousAssignment
		and previousAssignment.FactionId == factionId
		and previousAssignment.ClassKey == classKey
		and previousAssignment.ClassId == classId
	then
		return
	end

	self.PlayerAssignments(function(previous)
		local nextState = table.clone(previous)
		if factionId and classKey and classId then
			nextState[memberKey] = {
				FactionId = factionId,
				ClassKey = classKey,
				ClassId = classId,
			}
		else
			nextState[memberKey] = nil
		end
		return nextState
	end)
end

function State:GetClassOccupancyCount(factionId: string, classKey: string): number
	local classCountsByFaction = self.FactionClassCounts()
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
	local memberKey = tostring(userId)
	local assignment = self.PlayerAssignments()[memberKey]
	if assignment and assignment.FactionId == resolvedFactionId then
		self:SetPlayerClass(userId, nil, nil, nil)
	end
end

function State:RemoveFactionMemberFromAll(userId: number)
	self:SetPlayerClass(userId, nil, nil, nil)
end

return State
