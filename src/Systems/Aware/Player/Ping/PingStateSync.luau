--!strict
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local GetPlayerSlice = require("@game/ReplicatedStorage/Systems/Aware/Selectors/GetPlayerSlice")

local observe = Charm.observe
local effectScope = Charm.effectScope
local computed = Charm.computed


return function(player: Player, state: Types.State)
    local playerSlice = GetPlayerSlice(player, state)

    observe(playerSlice.teamValues, function(ownedValues, playerKey)
        print("mount", ownedValues, playerKey)
        local pings = computed(function() return playerSlice.teamValues()[playerKey].Pings end)

        local unmount = effectScope(function()
            observe(pings, function(pings)
                print("pings", pings)
            end)
        end)
        
        return function()
            print("unmount", ownedValues, playerKey)
            unmount()
        end
    end)
end