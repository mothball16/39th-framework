local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local State = require(Access.Framework.Core.State)
local StateActions = require(script.Parent.StateActions)

local ClassStateListener = {}
ClassStateListener.__index = ClassStateListener

type self = {
    state: State.State,
}
export type ClassStateListener = typeof(setmetatable({} :: self, ClassStateListener))

function ClassStateListener.new(state: State.State): ClassStateListener
    local self = setmetatable({
        state = state,
    }, ClassStateListener)
    return self
end

function ClassStateListener.Start(self: ClassStateListener)
    -- player assigns themself to a (new) faction, set to default class
    Charm.observe(self.state.playerFactionIds, function(factionId, userId)
        StateActions.SetPlayerToDefaultClass(self.state, userId, factionId)
	end)

    Charm.observe(self.state.playerClassIds, function(classId, userId)
        print(`player {userId} has class {classId}`)
    end)
end

return ClassStateListener