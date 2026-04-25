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
    print(self.Factions())
	return faction
end

function State:RemoveFaction(faction: Types.IFaction)
	self.Factions(function(prevFactionState)
		local nextFactionState = table.clone(prevFactionState)
		nextFactionState[faction.Config.ID] = nil
		return nextFactionState
	end)
end

function State:AddFactionMember(faction: Types.IFaction, userId: number)
    --[[
	faction.State(function(prevState)
		local newState = table.clone(prevState)
		newState[tostring(userId)] = {
			Class = "DEFAULT_PLACEHOLDER",
		}
		return newState
	end)]]
end

function State:RemoveFactionMember(faction: Types.IFaction, userId: number)
    --[[
	faction.State.Members(function(prevMemberState)
		local nextMemberState = table.clone(prevMemberState)
		nextMemberState[tostring(userId)] = nil
		return nextMemberState
	end)]]
end

return State
