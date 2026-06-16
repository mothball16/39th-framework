local Server = require("@game/ReplicatedStorage/Packages/charm-sync").server
local LegacyEvents = require("@game/ReplicatedStorage/Faction_Framework/Core/Events").GetLegacyEvents()
local State = require("@game/ReplicatedStorage/Faction_Framework/Core/State")
local Players = game:GetService("Players")

return function(state: State.State)

    LegacyEvents.RequestState.OnServerEvent:Connect(function(player)
        local signals = {
            configByFactionId = state.configByFactionId,
            playerAssignmentByUserId = state.playerAssignmentByUserId,
            groupCountByFaction = state.groupCountByFaction,
        }
        Server.addSignalsToClient(player, signals)
    end)

    Server.connect(function(player, updates)
        LegacyEvents.SyncState:FireClient(player, updates)
    end)

    Players.PlayerRemoving:Connect(function(player)
        Server.removeClient(player)
    end)
end