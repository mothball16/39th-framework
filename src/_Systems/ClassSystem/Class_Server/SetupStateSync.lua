local Server = require("@game/ReplicatedStorage/Packages/charm-sync").server
local LegacyEvents = require("@game/ReplicatedStorage/Class_Framework/Core/Events").GetLegacyEvents()
local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")
local Players = game:GetService("Players")

return function(state: State.State)

    LegacyEvents.RequestState.OnServerEvent:Connect(function(player)
        local signals = {
            configByFactionId = state.configByFactionId,
            playerByFactionId = state.playerByFactionId,
            playerByGroupKey = state.playerByGroupKey,
            playerByClassId = state.playerByClassId,
            groupCountByFaction = state.groupCountByFaction,
        }
        Server.addSignalsToClient(player, signals)
    end)

    Server.connect(function(player, updates)
        LegacyEvents.SyncState:FireClient(player, updates)
    end)

    Players.PlayerRemoving:Connect(function(player)
        Server.removeSignalsFromClient(player)
    end)
end