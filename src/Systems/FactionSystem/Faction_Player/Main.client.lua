local ClientRuntime = require("./ClientRuntime")
local Access = require("@game/ReplicatedStorage/Faction_Framework/Access")
local SetupClientSync = require("./SetupClientSync")

local runtime = ClientRuntime.new(Access)
SetupClientSync(runtime.state)
runtime:WireControllers(script.Parent.Interaction)
runtime:Start()