local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local Framework = replicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local config = Access.config

local warnPrefix = "【 SPEARHEAD 】 "
print(warnPrefix.."Loading Client "..config.version)

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

print(warnPrefix.."Main Client loaded successfully!")
