--!strict

local ClientRuntime = require("./ClientRuntime")
local RuntimeLocator = require("@game/ReplicatedStorage/Faction_Framework/RuntimeLocator")

local locator = RuntimeLocator() :: RuntimeLocator.Locator<ClientRuntime.ClientRuntime>

return locator
