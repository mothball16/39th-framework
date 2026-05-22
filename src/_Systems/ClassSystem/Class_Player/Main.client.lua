local ClientRuntime = require("./ClientRuntime")

local runtime = ClientRuntime.new()
runtime:WireControllers(script.Parent.Interaction)
runtime:Start()
