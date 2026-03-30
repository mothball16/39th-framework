local Patcher = {}
Patcher.modelDetectionMethod = nil
Patcher.modelDetectionPath = nil
Patcher.connections = {
	childAdded = nil;
	childRemoved = nil;
}

Patcher.parentingMethod = nil
Patcher.glassMethod = nil
Patcher.aimpartZOffset = 0.5

Patcher.currentRootModel = nil
Patcher.cleanupParts = {}

Patcher.interval = 0
Patcher.timeout = 100

local camera = workspace.CurrentCamera
local Activate = require(script.Parent:WaitForChild("Activate"))

function Patcher.init()
	Patcher.update("Default")
end

function Patcher.update(method: string)
	local module = require(script:FindFirstChild(method))
	
	-- disconnect old connections
	if Patcher.connections.childAdded then
		Patcher.connections.childAdded:Disconnect()
	end
	if Patcher.connections.childRemoved then
		Patcher.connections.childRemoved:Disconnect()
	end
	
	Patcher.modelDetectionPath = module.modelDetectionPath()
	Patcher.modelDetectionMethod = module.modelDetectionMethod
	Patcher.parentingMethod = module.parentingMethod
	Patcher.aimpartZOffset = module.aimpartZOffset
	
	Patcher.connections.childAdded = Patcher.modelDetectionPath.ChildAdded:Connect(Patcher.onChildAdded)
	Patcher.connections.childRemoved = Patcher.modelDetectionPath.ChildRemoved:Connect(Patcher.onChildRemoved)
end

function Patcher.onChildAdded(obj)
	local gunModel

	for i = 1, Patcher.timeout do
		gunModel = Patcher.modelDetectionMethod(obj)
		
		if gunModel then
			break
		end

		task.wait(Patcher.interval)
	end

	if gunModel then
		Patcher.currentRootModel = obj
		Patcher.cleanupParts = Activate.start(gunModel, Patcher)
	end
end

function Patcher.onChildRemoved(obj)
	if obj == Patcher.currentRootModel then
		for _, part in Patcher.cleanupParts do
			part:Destroy()
		end

		Patcher.currentRootModel = nil
	end
end

return Patcher
