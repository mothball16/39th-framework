local CS = game:GetService("CollectionService")

local TagObserver = {}
TagObserver.__index = TagObserver

export type Callbacks = {
	onCreated: (Instance) -> { RBXScriptConnection }?,
	onDestroyed: (Instance) -> ()?,
}

function TagObserver.new(tag: string, callbacks: Callbacks)
	local self = setmetatable({}, TagObserver)
	self.tag = tag
	self.callbacks = callbacks or {}
	self.activeInstances = {}
	self.connections = {}
	return self
end

function TagObserver:_OnCreated(instance: Instance)
	if self.activeInstances[instance] then
		warn(`Duplicate instance of tag {self.tag} attempted to be registered, aborting.`)
		return
	end

	local instanceConnections = {}
	if self.callbacks.onCreated then
		local result = self.callbacks.onCreated(instance)
		if type(result) == "table" then
			instanceConnections = result
		end
	end

	self.activeInstances[instance] = instanceConnections
end

function TagObserver:_OnDestroyed(instance: Instance)
	local instanceConnections = self.activeInstances[instance]
	if instanceConnections then
		for _, con in pairs(instanceConnections) do
			if typeof(con) == "RBXScriptConnection" or (type(con) == "table" and type(con.Disconnect) == "function") then
				con:Disconnect()
			end
		end
	end

	if self.callbacks.onDestroyed then
		self.callbacks.onDestroyed(instance)
	end

	self.activeInstances[instance] = nil
end

function TagObserver:Init()
	for _, instance in pairs(CS:GetTagged(self.tag)) do
		self:_OnCreated(instance)
	end

	table.insert(self.connections, CS:GetInstanceAddedSignal(self.tag):Connect(function(instance)
		self:_OnCreated(instance)
	end))

	table.insert(self.connections, CS:GetInstanceRemovedSignal(self.tag):Connect(function(instance)
		self:_OnDestroyed(instance)
	end))
	return self
end

function TagObserver:Destroy()
	for _, con in ipairs(self.connections) do
		con:Disconnect()
	end
	table.clear(self.connections)

	for instance in pairs(self.activeInstances) do
		self:_OnDestroyed(instance)
	end
end

return TagObserver
