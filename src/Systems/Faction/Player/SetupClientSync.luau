local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local Events = require("@game/StarterPlayer/StarterPlayerScripts/Systems/StateSync/Network")
local State = require("@game/ReplicatedStorage/Systems/Faction/Core/State")

return function(state: State.State)
	Client.addSignals({
		configByFactionId = state.configByFactionId,
		playerAssignmentByUserId = state.playerAssignmentByUserId,
	})
	
	Events.RequestState.Fire()
end
