local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local LegacyEvents = require("@game/ReplicatedStorage/Faction_Framework/Core/Events").GetLegacyEvents()
local State = require("@game/ReplicatedStorage/Faction_Framework/Core/State")

return function(state: State.State)
    Client.addSignals({
        configByFactionId = state.configByFactionId,
        playerAssignmentByUserId = state.playerAssignmentByUserId,
    })

    LegacyEvents.SyncState.OnClientEvent:Connect(function(updates)
        Client.patch(updates)
    end)

    LegacyEvents.RequestState:FireServer()
end
