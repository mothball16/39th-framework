local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Types = require(script.Parent.Types)

local State = {}
State.__index = State

type self = {
	FactionConfigs: Charm.Atom<{ [string]: Types.IFactionConfig }>,
	MembershipByUserId: Charm.Atom<{ [string]: Types.IPlayerClassAssignment }>,
	ClassCountsByFaction: Charm.Atom<{ [string]: { [string]: number } }>,
	Players: any,
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local self = setmetatable(
		{
			FactionConfigs = Charm.atom({}),
			MembershipByUserId = Charm.atom({}),
			ClassCountsByFaction = Charm.atom({}),
		} :: self,
		State
	)

	self.Players = Charm.computed(function()
		local assignments = self.MembershipByUserId()
		local players = {}
		for userId, assignment in pairs(assignments) do
			players[userId] = {
				Faction = assignment.FactionId,
				Class = assignment.ClassId,
			}
		end
		return players
	end)
	return self
end

function State:CreateFaction(config: Types.IFactionConfig)
	self.FactionConfigs(function(previous)
		local nextState = table.clone(previous)
		nextState[config.ID] = config
		return nextState
	end)

	self.ClassCountsByFaction(function(previous)
		local nextState = table.clone(previous)
		if nextState[config.ID] ~= nil then
			return nextState
		end

		local initialCounts = {}
		for _, classConfig in pairs(config.Classes) do
			initialCounts[classConfig.ClassID] = 0
		end
		nextState[config.ID] = initialCounts
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

	self.ClassCountsByFaction(function(previous)
		if previous[factionId] == nil then
			return previous
		end
		local nextState = table.clone(previous)
		nextState[factionId] = nil
		return nextState
	end)

	self.MembershipByUserId(function(previous)
		local hasChanges = false
		local nextState = table.clone(previous)
		for memberKey, assignment in pairs(previous) do
			if assignment.FactionId == factionId then
				nextState[memberKey] = nil
				hasChanges = true
			end
		end
		if hasChanges then
			return nextState
		end
		return previous
	end)
end

function State:SetPlayerClass(userId: number, factionId: string?, classId: string?)
	local memberKey = tostring(userId)
	local previousAssignment = self.MembershipByUserId()[memberKey]

	if previousAssignment
		and previousAssignment.FactionId == factionId
		and previousAssignment.ClassId == classId
	then
		return
	end

	self.MembershipByUserId(function(previous)
		local nextState = table.clone(previous)
		if factionId and classId then
			nextState[memberKey] = {
				FactionId = factionId,
				ClassId = classId,
			}
		else
			nextState[memberKey] = nil
		end
		return nextState
	end)

	self.ClassCountsByFaction(function(previous)
		local nextState = table.clone(previous)

		if previousAssignment then
			local previousFactionCounts = nextState[previousAssignment.FactionId]
			if previousFactionCounts ~= nil then
				local previousCount = previousFactionCounts[previousAssignment.ClassId] or 0
				local nextFactionCounts = table.clone(previousFactionCounts)
				nextFactionCounts[previousAssignment.ClassId] = math.max(previousCount - 1, 0)
				nextState[previousAssignment.FactionId] = nextFactionCounts
			end
		end

		if factionId and classId then
			local currentFactionCounts = nextState[factionId] or {}
			local currentCount = currentFactionCounts[classId] or 0
			local nextFactionCounts = table.clone(currentFactionCounts)
			nextFactionCounts[classId] = currentCount + 1
			nextState[factionId] = nextFactionCounts
		end

		return nextState
	end)
end

function State:GetClassOccupancyCount(factionId: string, classId: string): number
	local classCountsByFaction = self.ClassCountsByFaction()
	local factionCounts = classCountsByFaction[factionId]
	if not factionCounts then
		return 0
	end
	return factionCounts[classId] or 0
end

function State:SetFactionMemberClass(factionId: string, userId: number, classId: string)
	self:SetPlayerClass(userId, factionId, classId)
end

function State:AddFactionMember(faction: Types.IFactionConfig | Types.IFaction, userId: number, classId: string)
	local resolvedFactionId = if faction.Config then faction.Config.ID else faction.ID
	self:SetPlayerClass(userId, resolvedFactionId, classId)
end

function State:RemoveFactionMember(faction: Types.IFactionConfig | Types.IFaction, userId: number)
	local resolvedFactionId = if faction.Config then faction.Config.ID else faction.ID
	local memberKey = tostring(userId)
	local assignment = self.MembershipByUserId()[memberKey]
	if assignment and assignment.FactionId == resolvedFactionId then
		self:SetPlayerClass(userId, nil, nil)
	end
end

function State:RemoveFactionMemberFromAll(userId: number)
	self:SetPlayerClass(userId, nil, nil)
end

return State
