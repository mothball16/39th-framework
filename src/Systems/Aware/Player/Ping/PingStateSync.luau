--!strict
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local PlayerKey = require("@game/ReplicatedStorage/Systems/Aware/Core/PlayerKey")
local observe = Charm.observe
local computed = Charm.computed
local listen = Charm.listen


return function(player: Player, state: Types.State)
    local playerKey = PlayerKey.ToPlayerKey(player)

    local playerTeam = computed(function(): string?
        local playerValues = state.valuesByPlayer()[playerKey]
        if not playerValues then return nil end
        return playerValues.Team
    end)

    local teamValues = computed(function(): { [string]: Types.OwnedValues }
        local team = playerTeam()
        if not team then return {} end
        return state.valuesByTeam()[team] or {}
    end)

    listen(teamValues, function(value)
        if not value then return end

        observe(teamValues, function(item, key)
            print("mount", item, key)
            return function()
                print("unmount", item, key)
            end
        end)
    end)
end