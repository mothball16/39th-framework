--[[
service locator for the class system runtime
]]

local Signal = require("@game/ReplicatedStorage/Packages/signal")
local ServerRuntime = require("./ServerRuntime")

local RuntimeLocator = {
	OnLoaded = Signal.new(),
}

local _runtime: ServerRuntime.ServerRuntime

function RuntimeLocator.LoadRuntime(serverRuntime: ServerRuntime.ServerRuntime)
	if _runtime then
		error("RuntimeLocator already initialized")
		return
	end

	_runtime = serverRuntime
	RuntimeLocator.OnLoaded:Fire()
end

function RuntimeLocator.GetRuntime(): ServerRuntime.ServerRuntime
	if not _runtime then
		RuntimeLocator.OnLoaded:Wait()
	end
	return _runtime
end

return RuntimeLocator