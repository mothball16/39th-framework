-- This module handles bullet piercing

local players = game:GetService("Players")
local module = {}
local collectionService = game:GetService("CollectionService")
local debrisservice = game:GetService("Debris")

local Framework = script:FindFirstAncestor("SPH_Framework")
local Access = require(Framework.Access)
local Assets = Access.assets
local Sounds = Assets:WaitForChild("Sounds")
local RicoSound = Sounds:WaitForChild("Ricochet"):GetChildren()

local randomSeed = Random.new()

local function RandomInt(min, max)
	return randomSeed:NextInteger(min, max)
end

local hitFX = require(script.Parent.HitFX)
local GetMaterialType = require(script.Parent.MaterialTypes)
local config = Access.config


local function IsInHumanoid(Inst)
	while Inst.Parent do
		if Inst.Parent:FindFirstChild("Humanoid") then
			return Inst.Parent.Humanoid
		else
			Inst = Inst.Parent
		end
	end
	return false
end

local function RoundUp(number)
	return math.floor(number + 0.5)
end

module.CanPierce = function(cast, rayResult:RaycastResult, segmentVelocity)
	local willPierce = false

	local hitPart = rayResult.Instance
	local Humanoid = IsInHumanoid(hitPart)
	local projectile = cast.RayInfo.CosmeticBulletObject

	if workspace:FindFirstChild("Vehicles") and hitPart:IsDescendantOf(workspace.Vehicles) then
		if hitPart:GetAttribute("ArmorThickness") then
			willPierce = true
		else
			willPierce = false
		end
	elseif cast.UserData.IgnoreModel and hitPart:IsDescendantOf(cast.UserData.IgnoreModel) then
		willPierce = true
	elseif Humanoid then
		local player = players:GetPlayerFromCharacter(Humanoid.Parent)
		if player and cast.UserData.Player == player then
			willPierce = true
		elseif hitPart.Parent:IsA("Accoutrement") or (hitPart.Parent:IsA("Model") and hitPart.Parent ~= Humanoid.Parent) then
			willPierce = true
		end
		--willPierce = false
	elseif collectionService:HasTag(hitPart,"SPH_Collide") then
		willPierce = false
	elseif collectionService:HasTag(hitPart,"Dragoon_Armor") then -- DD_SPH: Dragoon Tank System Compat
		willPierce = false
		-- </DD_SPH>
	elseif hitPart.Transparency == 1 or not hitPart.CanCollide or hitPart.Name == "Ignore" or collectionService:HasTag(hitPart,"SPH_NoCollide") then
		willPierce = true
	end

	if not willPierce and cast.UserData.Tool then -- Bullet pen and ricochet
		local physicsModule
		if typeof(cast.UserData.Tool) == "number" and cast.UserData.IgnoreModel.Base["FirePoint"..cast.UserData.Tool]:FindFirstChild("BulletPhysics") then
			physicsModule = cast.UserData.IgnoreModel.Base["FirePoint"..cast.UserData.Tool]:FindFirstChild("BulletPhysics")
		elseif cast.UserData.Tool:FindFirstChild("SPH_Weapon") and cast.UserData.Tool.SPH_Weapon:FindFirstChild("BulletPhysics") then
			physicsModule = cast.UserData.Tool.SPH_Weapon:FindFirstChild("BulletPhysics")
		end

		if not physicsModule then
			return false -- Bullet will never penetrate or ricochet without a physics module
		else
			physicsModule = require(physicsModule)
		end

		local materialProperties = physicsModule.materialProperties[GetMaterialType(rayResult.Instance.Material)]

		local angle = math.acos(projectile.CFrame.LookVector.Unit:Dot(rayResult.Normal.Unit)) -- Find angle of impact
		angle = RoundUp(math.abs(math.deg(angle) - 180)) -- Convert to a useable number in degrees

		local ricochetAngles = materialProperties.RicochetAngle
		local angleNumber = RandomInt(ricochetAngles[1] * 10, ricochetAngles[2] * 10)
		local reqAngle = RoundUp((angleNumber / 10) * (1 + (cast:GetVelocity().Magnitude)/100000)) -- Ricochet angle

		if angle > reqAngle and segmentVelocity.Magnitude > materialProperties.MinRicochetVelocity and not Humanoid then -- Angle is high enough to bounce, and bullet is traveling fast enough

			hitFX.HitEffect(rayResult.Position, rayResult.Instance, rayResult.Normal)

			willPierce = true

			local newDir = projectile.CFrame.LookVector - (2 * projectile.CFrame.LookVector:Dot(rayResult.Normal) * rayResult.Normal) -- Get the new direction for the bullet

			local ricochetDeviation = materialProperties.RicochetDeviation
			local deviationVector = Vector3.new(RandomInt(-ricochetDeviation, ricochetDeviation) / 5000, RandomInt(-ricochetDeviation, ricochetDeviation) / 5000, RandomInt(-ricochetDeviation, ricochetDeviation) / 5000)

			newDir = CFrame.fromOrientation(deviationVector.X, deviationVector.Y, deviationVector.Z) * newDir -- Deviate direction

			local velocityMult = materialProperties.VelocityMultiplier
			cast:SetPosition(rayResult.Position) -- Move cast to hit position
			cast:SetVelocity(RandomInt(velocityMult[1], velocityMult[2]) / 100 * segmentVelocity.Magnitude * newDir.Unit) -- Point cast in new direction and decrease velocity

			local ricochetPart = Instance.new("Part")
			ricochetPart.Name = "Ricochet Hit Temp"
			ricochetPart.Position = rayResult.Position
			ricochetPart.Anchored = true
			ricochetPart.CanCollide = false
			ricochetPart.Transparency = 1
			ricochetPart.Parent = workspace

			local ricochetSound = RicoSound[math.random(1, #RicoSound)]:Clone()
			ricochetSound.Parent = ricochetPart
			ricochetSound.Volume = 10
			ricochetSound:Play()

			debrisservice:AddItem(ricochetPart, 5)
		elseif config.bulletPen and not Humanoid and not hitPart:HasTag("SPH_Collide") then -- Check if bullet can pierce material
			local pierceDepthValues = materialProperties.PenetrationDepth
			local pierceDepth = math.random(pierceDepthValues[1] * 1000, pierceDepthValues[2] * 1000) / 1000
			local bulletDirection = segmentVelocity.Unit
			local maxDepthPoint = rayResult.Position + (bulletDirection * pierceDepth)

			local pierceRayParams = RaycastParams.new()
			pierceRayParams.FilterType = Enum.RaycastFilterType.Include
			pierceRayParams.FilterDescendantsInstances = {hitPart}

			local pierceRay = workspace:Raycast(maxDepthPoint, -bulletDirection, pierceRayParams)
			if pierceRay then
				hitFX.HitEffect(rayResult.Position, rayResult.Instance, rayResult.Normal)
				hitFX.HitEffect(pierceRay.Position, pierceRay.Instance, pierceRay.Normal)

				return true
			else
				return false
			end
		end
	end

	return willPierce
end

return module