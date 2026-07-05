--!strict
local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local toNamespace = require("@game/ReplicatedStorage/Systems/StateSync/Namespace").toNamespace

return function(state: Types.State)
	-- ponytail: valuesByTeam is derived locally from valuesByPlayer on each peer
	Client.addSignals(toNamespace({
		valuesByPlayer = state.valuesByPlayer,
	}, "aware"))
end
