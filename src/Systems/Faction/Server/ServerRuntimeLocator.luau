--!strict

local ServerRuntime = require("./ServerRuntime")
local RuntimeLocator = require("@game/ReplicatedStorage/Systems/Faction/RuntimeLocator")

local locator = RuntimeLocator() :: RuntimeLocator.Locator<ServerRuntime.ServerRuntime>

return locator
