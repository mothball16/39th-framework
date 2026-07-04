--!strict
local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local Events = require("@game/StarterPlayer/StarterPlayerScripts/StateSync_Player/Network")

return function<T>(state: T)
	Client.addSignals(state)
	
	Events.RequestState.Fire()
end
