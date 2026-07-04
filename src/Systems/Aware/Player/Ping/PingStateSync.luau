local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local observe = Charm.observe
local computed = Charm.computed
local listen = Charm.listen
local effectScope = Charm.effectScope

return function(player: Player, state: Types.State)
    local teamValue = computed(function()
        print("teamValue", player.Name)
        local playerValues = state.valuesByPlayer()[player]
        if not playerValues then return nil end
        return playerValues.Team
    end)


    listen(state.valuesByPlayer, function(value, oldValue)
        print("valuesByPlayer", value, oldValue)
    end)

    listen(teamValue, function(value, oldValue)
        if not value then return end

        local unmount = effectScope(function()

            observe(value, function(item, key)
                print("mount", item, key)
                return function()
                    print("unmount", item, key)
                end
            end)
        end)
        return unmount
    end)
end