--!strict
local Server = require("@game/ReplicatedStorage/Packages/charm-sync").server
local Events = require("@game/ServerScriptService/StateSync_Server/Network")

return function<T>(state: T)
	Events.RequestState.On(function(player)
		Server.addSignalsToClient(player, state)
	end)
end
