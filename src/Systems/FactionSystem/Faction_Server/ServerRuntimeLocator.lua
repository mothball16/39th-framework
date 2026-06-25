--!strict

local ServerRuntime = require("./ServerRuntime")
local RuntimeLocator = require("@game/ReplicatedStorage/Faction_Framework/RuntimeLocator")

local locator = RuntimeLocator() :: RuntimeLocator.Locator<ServerRuntime.ServerRuntime>

return locator
