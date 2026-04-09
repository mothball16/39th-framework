local debugMode = false

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local assets = replicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets:WaitForChild("GameConfig"))

local warnPrefix = "【 SPEARHEAD 】 "
print(warnPrefix.."Loading Client "..config.version)

local Controllers = script.Parent:WaitForChild("Controllers")
local WeaponReplicationController = require(Controllers:WaitForChild("WeaponReplicationController"))
local CharacterReplicationController = require(Controllers:WaitForChild("CharacterReplicationController"))
local AttachmentReplicationController = require(Controllers:WaitForChild("AttachmentReplicationController"))
local StanceReplicationController = require(Controllers:WaitForChild("StanceReplicationController"))
WeaponReplicationController.Initialize()
CharacterReplicationController.Initialize()
AttachmentReplicationController.Initialize()
StanceReplicationController.Initialize()

runService.RenderStepped:Connect(function(dt)
	AttachmentReplicationController.UpdateRender(dt)
	CharacterReplicationController.UpdateRender(dt)
end)

print(warnPrefix.."Main Client loaded successfully!")