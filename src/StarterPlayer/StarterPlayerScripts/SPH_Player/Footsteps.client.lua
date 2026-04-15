local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local sph = require(replicatedStorage.SPH_Framework.Core.GameAccess)
local assets = sph.assets
local config = sph.config
local bridgeNet = require(sph.framework.Network.BridgeNet)
local soundSets = assets.Sounds.WalkSounds
local player = game:GetService("Players").LocalPlayer

local repFootstep = bridgeNet.CreateBridge("ReplicateFootstep")
local defaultSoundSet = soundSets.Concrete
local leftFoot, rightFoot, stepLeftFoot, humanoidRootPart, humanoid:Humanoid
local character = nil

local delayTime = 0.5
local speedRef = 10
local stepping = false

local materialSounds = {
	CorrodedMetal = soundSets.Metal,
	DiamondPlate = soundSets.Metal,
	Fabric = soundSets.Sand,
	Glacier = soundSets.Ground,
	Grass = soundSets.Grass,
	Ground = soundSets.Ground,
	LeafyGrass = soundSets.Grass,
	Metal = soundSets.Metal,
	Mud = soundSets.Mud,
	Neon = soundSets.Metal,
	Pebble = soundSets.Ground,
	Salt = soundSets.Ground,
	Sand = soundSets.Sand,
	Snow = soundSets.Sand,
	Wood = soundSets.Wood,
	WoodPlanks = soundSets.Wood
}

local function GetSound(materialName)
	local sounds = materialSounds[materialName] or defaultSoundSet
	sounds = sounds:GetChildren()
	local randomSound = sounds[math.random(#sounds)]
	return randomSound.SoundId, randomSound.PlaybackSpeed
end

local function Footstep(material, foot)
	local newId, playSpeed = GetSound(material.Name)
	foot.SoundId = newId
	foot.PlaybackSpeed = playSpeed + (math.random(-100,100) / 1000)
	foot:Play()
end

local function SetupSoundsForCharacter(newCharacter)
	character = newCharacter
	
	humanoid = character:WaitForChild("Humanoid")
	
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local defaultWalk = humanoidRootPart:WaitForChild("Running")
	if defaultWalk then defaultWalk:Destroy() end
	
	local soundOrigin = humanoidRootPart:WaitForChild("FootstepSoundOrigin")
	
	leftFoot = soundOrigin:WaitForChild("LeftFoot")
	rightFoot = soundOrigin:WaitForChild("RightFoot")
	
	stepLeftFoot = true
end

player.CharacterAdded:Connect(SetupSoundsForCharacter) -- DD_SPH: CharacterAppearanceLoaded doesn't play with R15 rigs for whatever reason, using CharacterAdded solves this
--player.CharacterAppearanceLoaded:Connect(SetupSoundsForCharacter)

repFootstep:Connect(function(material, foot, volume)
	foot.Volume = volume
	Footstep(material, foot)
end)

if config.footstepSounds then
	runService.Heartbeat:Connect(function()
		--if not character and player.Character and not humanoid then
		--	SetupSoundsForCharacter(player.Character)
		--end
		if humanoid and humanoid.Health > 0 and humanoidRootPart and humanoidRootPart.AssemblyLinearVelocity.Magnitude > humanoid.WalkSpeed / 2 and not stepping and humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.FloorMaterial ~= Enum.Material.Water then
			stepping = true
			local curFoot = rightFoot
			if stepLeftFoot then
				curFoot = leftFoot
			end
			stepLeftFoot = not stepLeftFoot
		
			curFoot.Volume = 0.4 * (humanoidRootPart.AssemblyLinearVelocity.Magnitude / speedRef)
			
			Footstep(humanoid.FloorMaterial,curFoot,curFoot.Volume)
			repFootstep:Fire(humanoid.FloorMaterial,curFoot,curFoot.Volume)
			
			task.wait(delayTime * (1 / (humanoidRootPart.AssemblyLinearVelocity.Magnitude / speedRef)))
			stepping = false
		end
	end)
end