--!strict
local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local Events = require("@game/StarterPlayer/StarterPlayerScripts/Systems/StateSync/Network")

Events.SyncState.On(function(payload)
	Client.patch(payload :: any)
end)

Events.RequestState.Fire()
