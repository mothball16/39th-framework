--[[       
DRAGOON TANK SYSTEM
Self-destruction script
1.2.0
--]]

--// Services
local DS = game:GetService("Debris")
local replicatedStorage = game:GetService("ReplicatedStorage")
local SelfDestruct = {}

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules

local config = require(assets.GlobalSettings)
local fxmod = require(modules.FXModule)
local atmod = require(modules.Antitank)
local notifMod = require(replicatedStorage.INTERACT_Assets.Modules.NotifModule) --Interact system shared module

--// Functions
local function DisableVic(target)
	for _, Part in ipairs(target:GetDescendants()) do
		if Part:IsA("Seat") or Part:IsA("VehicleSeat") then
			Part.Disabled = true
		elseif Part:IsA("HingeConstraint") then
			local weld = Instance.new("RigidConstraint")
			weld.Attachment0 = Part.Attachment0
			weld.Attachment1 = Part.Attachment1
			weld.Parent = Part.Parent
			weld.Name = "DTS_DESTROYED_WELD"
			Part:Destroy()
		elseif Part:IsA("LinearVelocity") or Part:IsA("AngularVelocity") then
			Part.Enabled = false
		elseif Part:IsA("BodyAngularVelocity") then
			Part.P = 0
			Part.MaxTorque = Vector3.zero
			Part.AngularVelocity = Vector3.zero
		elseif Part:IsA("ProximityPrompt") then
			Part.Enabled = false
			DS:AddItem(Part,1)
		end
	end
end

local function RustFX(target)
	for _, Part in ipairs(target:GetDescendants()) do
		local chance = math.random(1,3)

		if Part:IsA("BasePart") and chance == 2 then
			Part.Material = Enum.Material.CorrodedMetal
			Part.BrickColor = BrickColor.new("Black")	
		elseif Part:IsA("BasePart") and Part.Material == Enum.Material.Glass then
			Part.Material = Enum.Material.Metal
		end
	end
end

local function KillOccupants(target, player:Player)
	for _, Seat in ipairs(target:GetChildren()) do
		if Seat:IsA("Seat") or Seat:IsA("VehicleSeat") then
			if not Seat.Occupant then continue end
			atmod.DamagePlayer(player, Seat.Occupant, 9999, nil, false)
		elseif Seat:IsA("Model") or Seat:IsA("Folder") then
			KillOccupants(Seat, player)
		end
	end
end

function SelfDestruct.Explode(Vehicle : Model, MainPart : BasePart, Engine : BasePart, ExplosionEffect : string)	
	Vehicle:AddTag("Dragoon_Destroyed")
	local killerRef = Vehicle:FindFirstChild("Killer") or Vehicle:FindFirstChild("creator")
	local killerPlr = killerRef and killerRef.Value
	
	local Explosion = Instance.new("Explosion")
	Explosion.BlastRadius = 50
	Explosion.BlastPressure = 0
	Explosion.Parent = game.Workspace
	Explosion.Position = Engine.Position
	Explosion.DestroyJointRadiusPercent = 0

	Vehicle:SetAttribute("Car_Disabled", true)
	Vehicle:SetAttribute("Car_Running", false)

	KillOccupants(Vehicle, killerPlr)
	DisableVic(Vehicle)
	RustFX(Vehicle)

	local parts = Engine:GetChildren()
	for _, part in pairs(parts) do
		if part:IsA("Sound") then 
			part:Stop() 
		elseif part:IsA("AngularVelocity") or part:IsA("LinearVelocity") or part:IsA("BodyGyro") then 
			part:Destroy()
		end
	end

	fxmod.PlayFX(nil, Engine, ExplosionEffect)

	if config.WreckRemovalDelay then
		DS:AddItem(Vehicle, config.WreckRemovalDelay)
	end
end

return SelfDestruct
