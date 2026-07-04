local runService = game:GetService("RunService")

local Controllers = script.Parent:WaitForChild("Controllers")
local WeaponReplicationController = require(Controllers:WaitForChild("WeaponReplicationController"))
local AttachmentReplicationController = require(Controllers:WaitForChild("AttachmentReplicationController"))
local StanceReplicationController = require(Controllers:WaitForChild("StanceReplicationController"))
WeaponReplicationController.Initialize()
AttachmentReplicationController.Initialize()
StanceReplicationController.Initialize()

runService.RenderStepped:Connect(function(dt)
	AttachmentReplicationController.UpdateRender(dt)
	StanceReplicationController.UpdateRender(dt)
end)
