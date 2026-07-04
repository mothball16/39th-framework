local Server = require("@game/ReplicatedStorage/Packages/charm-sync").server
local Events = require("@game/ServerScriptService/Systems/StateSync/Network")
local State = require("@game/ReplicatedStorage/Systems/Faction/Core/State")

return function(state: State.State)
	Events.RequestState.On(function(player)
		Server.addSignalsToClient(player, {
			configByFactionId = state.configByFactionId,
			playerAssignmentByUserId = state.playerAssignmentByUserId,
		})
	end)
end
