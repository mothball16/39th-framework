local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local LegacyEvents = require("@game/ReplicatedStorage/Class_Framework/Core/Events").GetLegacyEvents()
local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")

return function(state: State.State)
    Client.addSignals({
        configByFactionId = state.configByFactionId,
        playerByFactionId = state.playerByFactionId,
        playerByGroupKey = state.playerByGroupKey,
        playerByClassId = state.playerByClassId,
        groupCountByFaction = state.groupCountByFaction,
    })

    LegacyEvents.SyncState.OnClientEvent:Connect(function(updates)
        Client.patch(updates)
    end)

    LegacyEvents.RequestState:FireServer()
end
