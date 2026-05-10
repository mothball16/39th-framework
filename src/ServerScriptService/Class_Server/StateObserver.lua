--[[
observer for class state changes
should be the only point where Charm.observe is attached in a way that may cause side effects to the state itself
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local State = require(Access.Framework.Core.State)
local StateActions = require(script.Parent.StateActions)

local StateObserver = {}
StateObserver.__index = StateObserver

type self = {
	state: State.State,
}
export type StateObserver = typeof(setmetatable({} :: self, StateObserver))

function StateObserver.new(state: State.State): StateObserver
	local self = setmetatable({
		state = state,
	}, StateObserver)
	return self
end

function StateObserver.Start(self: StateObserver)
	-- player assigns themself to a (new) faction, set to default class
	Charm.observe(self.state.playerByFactionId, function(factionId, userId)
		StateActions.SetPlayerToDefaultClass(self.state, userId, factionId)
	end)

	Charm.observe(self.state.playerByClassId, function(classId, userId)
		print(`player {userId} has class {classId}`)
	end)
end

return StateObserver
