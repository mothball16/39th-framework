local ClientRuntime = require(script.Parent.ClientRuntime)

local runtime = ClientRuntime.new()
runtime:WireControllers(script.Parent.Interaction)
runtime:Start()
