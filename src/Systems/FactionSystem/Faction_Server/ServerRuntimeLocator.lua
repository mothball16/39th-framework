--!strict

local ServerRuntime = require("./ServerRuntime")
local RuntimeLocator = require("@game/ReplicatedStorage/Faction_Framework/RuntimeLocator")

local ServerRuntimeLocator: RuntimeLocator.Locator<ServerRuntime.ServerRuntime> = RuntimeLocator()

return ServerRuntimeLocator
