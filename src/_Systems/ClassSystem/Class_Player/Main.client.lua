local ClientRuntime = require("./ClientRuntime")
local Access = require("@game/ReplicatedStorage/Class_Framework/Access")
local SetupClientSync = require("./SetupClientSync")

local runtime = ClientRuntime.new(Access)
runtime:WireControllers(script.Parent.Interaction)
runtime:Start()

SetupClientSync(runtime.state)
