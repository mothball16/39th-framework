local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Types = require(script.Parent.Types)

local State = {}
State.__index = State

type self = {
	Factions: Charm.Atom<{ [string]: Types.IFaction }>,
}
export type State = typeof(setmetatable({} :: self, State))

function State.new(): State
	local self = setmetatable(
		{
			Factions = Charm.atom({}),
		} :: self,
		State
	)
	return self
end

function State:CreateFaction(config: Types.IFactionConfig)
	local faction: Types.IFaction = {
		Config = config,
		State = {
			Members = {},
		},
	}

	self.Factions(function(previous)
		local nextState = table.clone(previous)
		nextState[config.ID] = faction
		return nextState
	end)
	return faction
end

function State:RemoveFaction(faction: Types.IFaction)
	self.Factions(function(prevFactionState)
		local nextFactionState = table.clone(prevFactionState)
		nextFactionState[faction.Config.ID] = nil
		return nextFactionState
	end)
end

function State:SetFactionMemberClass(factionId: string, userId: number, classId: string)
	local memberKey = tostring(userId)
	self.Factions(function(previous)
		local faction = previous[factionId]
		if not faction then
			warn(`faction {factionId} not found while setting member state`)
			return previous
		end

		local nextState = table.clone(previous)
		local nextMembers = table.clone(faction.State.Members)
		nextMembers[memberKey] = {
			Class = classId,
		}

		nextState[factionId] = {
			Config = faction.Config,
			State = {
				Members = nextMembers,
			},
		}

		return nextState
	end)
end

function State:AddFactionMember(faction: Types.IFaction, userId: number, classId: string)
	self:SetFactionMemberClass(faction.Config.ID, userId, classId)
end

function State:RemoveFactionMember(faction: Types.IFaction, userId: number)
	local memberKey = tostring(userId)
	self.Factions(function(previous)
		local factionId = faction.Config.ID
		local currentFaction = previous[factionId]
		if not currentFaction then
			return previous
		end

		if currentFaction.State.Members[memberKey] == nil then
			return previous
		end

		local nextState = table.clone(previous)
		local nextMembers = table.clone(currentFaction.State.Members)
		nextMembers[memberKey] = nil
		nextState[factionId] = {
			Config = currentFaction.Config,
			State = {
				Members = nextMembers,
			},
		}
		return nextState
	end)
end

function State:RemoveFactionMemberFromAll(userId: number)
	local memberKey = tostring(userId)
	self.Factions(function(previous)
		local hasChanges = false
		local nextState = table.clone(previous)

		for factionId, faction in pairs(previous) do
			if faction.State.Members[memberKey] ~= nil then
				hasChanges = true
				local nextMembers = table.clone(faction.State.Members)
				nextMembers[memberKey] = nil
				nextState[factionId] = {
					Config = faction.Config,
					State = {
						Members = nextMembers,
					},
				}
			end
		end

		if hasChanges then
			return nextState
		end
		return previous
	end)
end

return State
