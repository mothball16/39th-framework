local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local Events = require("@game/StarterPlayer/StarterPlayerScripts/StateSync_Player/Network")
local State = require("@game/ReplicatedStorage/Faction_Framework/Core/State")

return function(state: State.State)
	Client.addSignals({
		configByFactionId = state.configByFactionId,
		playerAssignmentByUserId = state.playerAssignmentByUserId,
	})
	
	Events.RequestState.Fire()
end
