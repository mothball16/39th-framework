--!strict
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Types = require("./Types")

return function()
    local State = {
        valuesByPlayer = Charm.atom({}),
    } :: Types.State
    
    State.valuesByTeam = Charm.computed(function()
        local newValues = {}
        for player, values in State.valuesByPlayer() do
            if not newValues[values.Team] then
                newValues[values.Team] = {}
            end
            newValues[values.Team][player] = values
        end
    end)
    
    return State
end
