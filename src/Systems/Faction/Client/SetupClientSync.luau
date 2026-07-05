local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local Events = require("@game/StarterPlayer/StarterPlayerScripts/Systems/StateSync/Network")
local State = require("@game/ReplicatedStorage/Systems/Faction/Core/State")
local toNamespace = require("@game/ReplicatedStorage/Systems/StateSync/Namespace").toNamespace

return function(state: State.State)
	Client.addSignals(toNamespace({
		configByFactionId = state.configByFactionId,
		playerAssignmentByUserId = state.playerAssignmentByUserId,
	}, "faction"))
end
