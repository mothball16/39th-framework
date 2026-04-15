--[[       
DRAGOON TANK SYSTEM
Server Script
1.1.1
--]]

--// Services
local players = game:GetService("Players")
local userInput = game:GetService("UserInputService")
local replicatedStorage = game:GetService("ReplicatedStorage")

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules

local hitFX = require(modules.HitFX)
local ballistics = require(assets.Weapons.Ballistic.BallisticPhysics)
local config = require(assets.GlobalSettings)

local sphCore = replicatedStorage:FindFirstChild("SPH_Framework")
local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets")
local bridgeNet
if sphCore then
	bridgeNet = require(sphCore.Network.BridgeNet)
elseif sphInstall and sphInstall:FindFirstChild("Modules") then
	bridgeNet = require(sphInstall.Modules.Network.BridgeNet)
else
	bridgeNet = require(modules.BridgeNet)
end
warn(config.prefix.." Loading Client "..config.version)

local localPlayer = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

--// Events
local fastCastClient = assets.Events.BallisticReplication
local repAssembly = bridgeNet.CreateBridge("rotateAssembly2") -- Server > Client
local repFire = bridgeNet.CreateBridge("ReplicateFire2")
local repHit = bridgeNet.CreateBridge("ReplicateHit2") -- Server > Client

--// Functions
local function RepBallistics(func:string, player, ...)
	if not func or player~=localPlayer then return end
	--fastCastClient:Fire("FireBullet", player, vehicle, weapon, bulletOrigin, newDirection, bulletVelocity, player, tracerColor, nil, muzzleObj, camShake)
	--local fastCastClient = assets.Events.BallisticReplication
	
	if func=="FireBullet" then
		ballistics.FireBullet(...)
	elseif func=="FireFX" then
		ballistics.FireFX(...)
	end
end

local function RepFire(plr, firePoint, vehicle, weapon, grip)
	ballistics.FireFX(plr, grip, 10)

	local wepStats = require(weapon:FindFirstChildWhichIsA("ModuleScript"))

	-- Fire bullet
	local muzzle = grip.Muzzle
	local bulletOrigin = muzzle.WorldCFrame.Position
	local bulletDirection = muzzle.WorldCFrame.LookVector
	local bulletVelocity = (bulletDirection * wepStats.ShellVelocity*3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)
	local tracerColor = Color3.new(1, 0.803922, 0.415686)

	ballistics.FireBullet(vehicle, weapon, bulletOrigin, bulletDirection, bulletVelocity, plr, tracerColor,true)
end

local function RepHit(weapon, raycastResult:RaycastResult, effectClass)
	if raycastResult.Instance then
		hitFX.HitEffect(raycastResult.Position,raycastResult.Instance,raycastResult.Normal, raycastResult.Material, effectClass)
	end
end

local function RepAssembly(TurretHinge, GunHinge, Rotation, Elevation, TurretSpeed, GunSpeed)
	if config.DirectTurretReplication and config.UseWeldReplication then
		if TurretHinge then TurretHinge.C1 = Rotation end
		if GunHinge then GunHinge.C1 = Elevation end
	elseif config.DirectTurretReplication and not config.UseWeldReplication then
		if TurretHinge then
			TurretHinge.AngularSpeed = TurretSpeed
			TurretHinge.TargetAngle = Rotation
		end
		if GunHinge then
			GunHinge.AngularSpeed = GunSpeed
			GunHinge.TargetAngle = Elevation
		end
	end
end

local function ResetCamZooms()
	--Sights
	if not localPlayer.Character then return end
	local human = localPlayer.Character:FindFirstChildWhichIsA("Humanoid")
	if not human then return end
	
	playerCam.CameraSubject = human
	playerCam.FieldOfView = 70
	localPlayer.CameraMode = Enum.CameraMode.Classic
	localPlayer.CameraMaxZoomDistance = game:GetService("StarterPlayer").CameraMaxZoomDistance
	localPlayer.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
	userInput.MouseDeltaSensitivity = 1
	userInput.MouseIconEnabled = true
end

--// Code & Loops
fastCastClient.Event:Connect(RepBallistics)
repFire:Connect(RepFire)
repHit:Connect(RepHit)
repAssembly:Connect(RepAssembly)
ResetCamZooms()

warn(config.prefix.." Client loaded successfully!")