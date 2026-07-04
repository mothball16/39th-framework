--!strict

local ClientRuntime = require("./ClientRuntime")
local RuntimeLocator = require("@game/ReplicatedStorage/Systems/Faction/RuntimeLocator")

local locator = RuntimeLocator() :: RuntimeLocator.Locator<ClientRuntime.ClientRuntime>

return locator
