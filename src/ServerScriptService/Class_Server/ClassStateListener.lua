local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local State = require(Access.Framework.Core.State)

local ClassStateListener = {}
ClassStateListener.__index = ClassStateListener

type self = {
    state: State.State,
}
export type ClassStateListener = typeof(setmetatable({} :: self, ClassStateListener))

local function _updateMapValue(atom, key, value)
	atom(function(previous)
		local nextState = table.clone(previous)
		nextState[key] = value
		return nextState
	end)
end

function ClassStateListener.new(state: State.State): ClassStateListener
    local self = setmetatable({
        state = state,
    }, ClassStateListener)
    return self
end

function ClassStateListener.Start(self: ClassStateListener)
    print("Starting class state listener")
    Charm.observe(self.state.playerFactionIds, function(factionId, userId)
        print(`player {userId} has faction {factionId}`)
		local factionConfig = self.state.factionConfigs()[factionId]
        if not factionConfig then
            return
        end

        local defaultClassKey = factionConfig.DefaultClassKey
        if not defaultClassKey then
            warn(`faction {factionId} has no default class`)
            defaultClassKey = next(factionConfig.Classes)
        end

        local classConfig = factionConfig.Classes[defaultClassKey]
        local classId = classConfig.ClassIDs[1].Id

        Charm.batch(function()
            _updateMapValue(self.state.playerClassKeys, userId, defaultClassKey)
            _updateMapValue(self.state.playerClassIds, userId, classId)
        end)
	end)

    Charm.observe(self.state.playerClassKeys, function(classKey, userId)
        print(`player {userId} has class {classKey}`)
    end)
end

return ClassStateListener