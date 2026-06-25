--!strict

local ClientRuntime = require("./ClientRuntime")
local RuntimeLocator = require("@game/ReplicatedStorage/Faction_Framework/RuntimeLocator")

local ClientRuntimeLocator: RuntimeLocator.Locator<ClientRuntime.ClientRuntime> = RuntimeLocator()

return ClientRuntimeLocator
