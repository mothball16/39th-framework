--!strict
local Server = require("@game/ReplicatedStorage/Packages/charm-sync").server
local Events = require("@game/ServerScriptService/Systems/StateSync/Network")
local toNamespace = require("@game/ReplicatedStorage/Systems/StateSync/Namespace").toNamespace
return function<T>(state: T)
	Events.RequestState.On(function(player)
		Server.addSignalsToClient(player, toNamespace(state, "aware"))
	end)
end
