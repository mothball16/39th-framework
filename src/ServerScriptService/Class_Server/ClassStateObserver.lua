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

local ClassStateObserver = {}
ClassStateObserver.__index = ClassStateObserver

type self = {
    state: State.State,
}
export type ClassStateObserver = typeof(setmetatable({} :: self, ClassStateObserver))

function ClassStateObserver.new(state: State.State): ClassStateObserver
    local self = setmetatable({
        state = state,
    }, ClassStateObserver)
    return self
end

function ClassStateObserver.Start(self: ClassStateObserver)
    -- player assigns themself to a (new) faction, set to default class
    Charm.observe(self.state.playerFactionIds, function(factionId, userId)
        StateActions.SetPlayerToDefaultClass(self.state, userId, factionId)
	end)

    Charm.observe(self.state.playerClassIds, function(classId, userId)
        print(`player {userId} has class {classId}`)
    end)
end

return ClassStateObserver