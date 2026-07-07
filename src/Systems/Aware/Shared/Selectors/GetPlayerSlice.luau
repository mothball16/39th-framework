--!strict
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local PlayerKey = require("@game/ReplicatedStorage/Systems/Aware/Core/PlayerKey")
local computed = Charm.computed

return function(player: Player, state: Types.State)
    -- the key of the player in the state
    local playerKey = PlayerKey.ToPlayerKey(player)

    -- the team of the player listed in the state itself
    local playerTeam = computed(function(): string?
        local playerValues = state.valuesByPlayer()[playerKey]
        return if playerValues then playerValues.Team else nil
    end)

    -- the owned values for the player
    local ownedValues = computed(function(): Types.OwnedValues
        return state.valuesByPlayer()[playerKey]
    end)

    -- stable list of owned values for the player's current team
    local teamValues = computed(function(): Types.OwnedValuesByKey
        local team = playerTeam()
        return if not team then {} else state.valuesByTeam()[team] or {}
    end)

    return {
        playerKey = playerKey,
        playerTeam = playerTeam,
        ownedValues = ownedValues,
        teamValues = teamValues,
    }
end