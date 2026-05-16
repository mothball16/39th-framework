local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local assets = Access.assets
local config = Access.config
local hitFX = require(Framework.Ballistics.HitFX)
local shellEjection = require(Framework.Weapons.ShellEjection)
local bulletHandler = require(Framework.Ballistics.BulletHandler)
local weaponStatLocator = require(Framework.Weapons.WeaponStatLocator)
--local gunsmithHandler = require(ReplicatedStorage:WaitForChild("DD_GunsmithHandler"))

local Events = require(Framework.Network.Events)
local P = Events.GetNamespace().packets

local WeaponReplicationController = {}

function WeaponReplicationController.Initialize()
	P.ReplicateFire.listen(function(data, _plr)
		WeaponReplicationController.OnReplicateFire(data.shooter, data.firePoint)
	end)
	P.ReplicateSound.listen(function(data, _plr)
		WeaponReplicationController.OnReplicateSound(data.shooter, data.sound)
	end)
	P.ReplicateHit.listen(function(data, _plr)
		WeaponReplicationController.OnReplicateHit(data.toolData, data.rayHit)
	end)
	P.ReplicateBolt.listen(function(data, _plr)
		WeaponReplicationController.OnReplicateBolt(data.shooter, data.direction, data.magAmmo)
	end)
	P.ReplicateCharacterSound.listen(function(data, _plr)
		WeaponReplicationController.OnReplicateCharacterSound(data.shooter, data.soundType)
	end)
	P.ReplicateMagGrab.listen(function(data, _plr)
		WeaponReplicationController.OnReplicateMagGrab(data.magPart)
	end)
end

function WeaponReplicationController.OnReplicateFire(player: Player, firePoint: CFrame, tracer: boolean)
	if not player.Character then return end
	local tool = player.Character:FindFirstChildWhichIsA("Tool")
	if tool and tool:FindFirstChild("SPH_Weapon") then
		local rig = player.Character:FindFirstChild("WeaponRig")
		if not rig then return end
		
		local gunModel = rig:FindFirstChild("Weapon") and rig.Weapon:FindFirstChildWhichIsA("Model")
		if not gunModel then return end
		
		local wepStats = weaponStatLocator.getWeaponStats(tool.SPH_Weapon)
		local gunAmmo = tool:FindFirstChild("Ammo")

		local muCh = wepStats.muzzleChance
		local fxTarget = gunModel
		for _, child in ipairs(gunModel:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChild("Main") and child.Main:FindFirstChild("Muzzle") then
				fxTarget = child
				break
			end
		end

		bulletHandler.FireFX(player, fxTarget, "Muzzle", muCh)

		local muzzle = gunModel:FindFirstChild("Grip") and gunModel.Grip:FindFirstChild("Muzzle")
		if not muzzle then return end
		
		local bulletOrigin = muzzle.WorldCFrame.Position
		local bulletDirection = muzzle.WorldCFrame.LookVector

		local muVe = wepStats.muzzleVelocity
		local bulletVelocity = (bulletDirection * muVe * 3.5)

		local TrTi = wepStats.tracerTiming
		local possibleTracerColor = wepStats.tracerColor
		local tracerColor = nil

		if wepStats.tracers and gunAmmo and gunAmmo:FindFirstChild("MagAmmo") and TrTi and gunAmmo.MagAmmo.Value % TrTi == 0 then
			tracerColor = possibleTracerColor
		end

		if tracerColor == "Random" then
			tracerColor = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
		end

		bulletHandler.FireBullet(rig, bulletOrigin, bulletDirection, bulletVelocity, tool, player, tracerColor, true)

		if wepStats.fireMode ~= "Manual" and wepStats.shellEject then
			if (bulletOrigin - workspace.CurrentCamera.CFrame.Position).Magnitude <= config.shellDistance then
				shellEjection.ejectShell(player, tool, gunModel)
			end
		end
	end 
end

function WeaponReplicationController.OnReplicateSound(player: Player, soundToPlay: Sound, dupeSound: boolean)
	if not soundToPlay then return end

	if not dupeSound then
		soundToPlay:Play()
	else
		if not player.Character or (not player.Character:FindFirstChild("Torso") and not player.Character:FindFirstChild("UpperTorso")) then return end
		local newSound = soundToPlay:Clone()
		if not soundToPlay.Parent or not soundToPlay.Parent:IsA("BasePart") then
			newSound.Parent = player.Character:FindFirstChild("HumanoidRootPart")
		else
			newSound.Parent = soundToPlay.Parent
		end
		newSound:Play()
		
		local soundLength = math.max(newSound.TimeLength, 1)
		Debris:AddItem(newSound, soundLength)
	end
end

function WeaponReplicationController.OnReplicateHit(tool: Tool, raycastResult: RaycastResult)
	local hitPart = raycastResult.Instance
	local bulletStats = tool:FindFirstChild("SPH_Weapon") and weaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	if hitPart and bulletStats and bulletStats.projectile == "Bullet" then
		hitFX.HitEffect(raycastResult.Position, hitPart, raycastResult.Normal)
	end
end

function WeaponReplicationController.OnReplicateBolt(player: Player, direction, magAmmo)
	if not player.Character or not player.Character:FindFirstChild("WeaponRig") then return end
	
	local rig = player.Character.WeaponRig
	local gunModel = rig:FindFirstChild("Weapon") and rig.Weapon:FindFirstChildWhichIsA("Model")
	local tool = player.Character:FindFirstChildWhichIsA("Tool")
	if not tool or not gunModel then return end
	
	local wepStats = weaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	local boltData = {
		fireMoveParts = wepStats.fireMoveParts,
		fireRate = wepStats.fireRate,
		emptyLockBolt = wepStats.emptyLockBolt,
	}

	bulletHandler.MoveBolt(gunModel, boltData, direction, magAmmo)
end

function WeaponReplicationController.OnReplicateCharacterSound(player: Player, soundType: string)
	local humanoidRootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		local soundList = assets.Sounds:FindFirstChild(soundType)
		if soundList then
			local children = soundList:GetChildren()
			if #children > 0 then
				local newSound = children[math.random(#children)]:Clone()
				newSound.Parent = humanoidRootPart
				newSound:Play()
				Debris:AddItem(newSound, newSound.TimeLength)
			end
		end
	end
end

function WeaponReplicationController.OnReplicateMagGrab(magPart: BasePart)
	if magPart then
		magPart.LocalTransparencyModifier = 0
		for _, part in ipairs(magPart:GetDescendants()) do
			if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end
		end
	end
end

--[[
function WeaponReplicationController.OnInitiateGunsmith(weaponTool, weaponModel)
	gunsmithHandler.Init(weaponTool, weaponModel)
end]]

return WeaponReplicationController