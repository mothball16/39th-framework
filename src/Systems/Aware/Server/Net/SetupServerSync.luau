--!strict
local Server = require("@game/ReplicatedStorage/Packages/charm-sync").server
local Events = require("@game/ServerScriptService/Systems/StateSync/Network")
local toNamespace = require("@game/ReplicatedStorage/Systems/StateSync/Namespace").toNamespace
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
return function(state: Types.State)
	Events.RequestState.On(function(player)
		Server.addSignalsToClient(player, toNamespace(state :: {[string]: any}, "aware"))
	end)
end
