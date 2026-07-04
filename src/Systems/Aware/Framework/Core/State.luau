--!strict
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Types = require("./Types")

return function()
    local State = {
        valuesByPlayer = Charm.atom({}),
    } :: Types.State
    
    State.valuesByTeam = Charm.computed(function()
        local newValues: { [string]: { [string]: Types.OwnedValues } } = {}
        for playerKey, values in State.valuesByPlayer() do
            local team = values.Team
            if not team then continue end
            if not newValues[team] then
                newValues[team] = {}
            end
            newValues[team][playerKey] = values
        end
        return newValues
    end)
    
    return State
end
