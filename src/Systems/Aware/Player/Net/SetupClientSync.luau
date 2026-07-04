--!strict
local Client = require("@game/ReplicatedStorage/Packages/charm-sync").client
local toNamespace = require("@game/ReplicatedStorage/Systems/StateSync/Namespace").toNamespace

return function<T>(state: T)
	Client.addSignals(toNamespace(state, "aware"))
end