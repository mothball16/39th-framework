--!strict
local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local Events = require("@game/StarterPlayer/StarterPlayerScripts/StateSync_Player/Network")

Events.SyncState.On(function(payload)
	Client.patch(payload :: any)
end)