local Server = require("@game/ReplicatedStorage/Packages/charm-sync").server
local Events = require("@game/ServerScriptService/StateSync_Server/Network")
local State = require("@game/ReplicatedStorage/Faction_Framework/Core/State")

return function(state: State.State)
	Events.RequestState.On(function(player)
		Server.addSignalsToClient(player, {
			configByFactionId = state.configByFactionId,
			playerAssignmentByUserId = state.playerAssignmentByUserId,
		})
	end)
end
