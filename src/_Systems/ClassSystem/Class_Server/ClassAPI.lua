--[[
API for extending the class system with custom item providers n stuff
]]

local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")
local Signal = require("@game/ReplicatedStorage/Packages/signal")
local ServerRuntime = require("./ServerRuntime")

local ClassAPI = {
	OnLoaded = Signal.new(),
}

local _runtime: ServerRuntime.ServerRuntime

function ClassAPI.Init(serverRuntime: ServerRuntime.ServerRuntime)
	if _runtime then
		error("ClassServer.init called more than once")
		return
	end

	_runtime = serverRuntime
	ClassAPI.OnLoaded:Fire()
end

function ClassAPI.IsLoaded()
	return _runtime ~= nil
end

function ClassAPI.RegisterItemProvider(provider: Types.ClassItemProvider)
	assert(ClassAPI.IsLoaded(), "class server not loaded yet - wait for OnLoaded signal")
	assert(provider.ID, "item provider must have an ID")

	if _runtime then
		_runtime.itemEquipper:RegisterProvider(provider)
		return
	end
end

return ClassAPI
