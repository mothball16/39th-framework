local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local observe = Charm.observe
local computed = Charm.computed
local listen = Charm.listen
return function(player: Player, state: Types.State)
    local teamValue = computed(function()
        local playerValues = state.valuesByPlayer()[player]
        if not playerValues then return nil end
        return playerValues.Team
    end)

    listen(teamValue, function(value, oldValue)
        if not value then return end

        return function()
        
        end
    end)
end