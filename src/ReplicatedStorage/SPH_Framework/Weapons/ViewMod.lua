local weldMod = require(script.Parent.WeldMod)
local Framework = script:FindFirstAncestor("SPH_Framework")
local Access = require(Framework.Access)
local assets = Access.assets
local callbacks = require(assets.Mods)
local models = assets.Arms

local viewMod = {}

viewMod.RigModel = function(player, forceDefault, attachTo)
	local newRig
	local newRigType

	if forceDefault then
		local attachingHumanoid:Humanoid = attachTo.Parent:FindFirstChildWhichIsA("Humanoid")
		newRigType = attachingHumanoid.RigType

		if attachingHumanoid and attachingHumanoid.RigType ~= Enum.HumanoidRigType.R15 then
			if models:FindFirstChild("R6_Arms") then
				newRig = models.R6_Arms.WeaponRig
			else
				newRig = models.Default.WeaponRig
			end
		else
			if models:FindFirstChild("R15_Arms") then
				newRig = models.R15_Arms.WeaponRig
			else
				newRig = models.Default_R15.WeaponRig
			end
		end
	elseif player.Neutral or not player.Team or not models:FindFirstChild(player.Team.Name) then
		local plr_human = player.Character:FindFirstChildWhichIsA("Humanoid")
		newRigType = plr_human.RigType

		if plr_human.RigType ~= Enum.HumanoidRigType.R15 then
			newRig = models.Default.WeaponRig
		else
			newRig = models.Default_R15.WeaponRig
		end
	else
		newRig = models[player.Team.Name].WeaponRig -- gotta figure out a way to rig check this
	end

	if not forceDefault and callbacks.viewmodelOverride then
		local override = callbacks.viewmodelOverride(player,newRig)
		if override and override:FindFirstChild("AnimBase") then
			newRig = override
		end
	end

	newRig = newRig:Clone()

	local base = newRig.AnimBase

	if newRigType == Enum.HumanoidRigType.R6 then

		local lArm = newRig["Left Arm"]
		for _, part in ipairs(lArm:GetChildren()) do
			if part:IsA("BasePart") then
				weldMod.Weld(lArm,part)
				part.CanCollide = false
				part.CanQuery = false
			end
		end

		local rArm = newRig["Right Arm"]
		for _, part in ipairs(rArm:GetChildren()) do
			if part:IsA("BasePart") then
				weldMod.Weld(rArm,part)
				part.CanCollide = false
				part.CanQuery = false
			end
		end

		local leftJoint = weldMod.M6D(newRig.AnimBase,lArm)
		leftJoint.Name = "LeftJoint"

		local rightJoint = weldMod.M6D(newRig.AnimBase,rArm)
		rightJoint.Name = "RightJoint"

		base.Transparency = 1
		base.CanCollide = false
		base.CanQuery = false
		base.CanTouch = false
		base.CastShadow = false

		lArm.CanCollide = false
		lArm.CanQuery = false
		lArm.CanTouch = false
		lArm.CastShadow = true

		rArm.CanCollide = false
		rArm.CanQuery = false
		rArm.CanTouch = false
		rArm.CastShadow = true

	else
		
		--Arm models
		local lUArm = newRig["LeftUpperArm"]
		for _, part in ipairs(lUArm:GetChildren()) do
			if part:IsA("BasePart") then weldMod.Weld(lUArm,part) ;part.CanCollide = false; part.CanQuery = false end
		end
		lUArm.CanCollide = false
		lUArm.CanQuery = false
		lUArm.CanTouch = false
		lUArm.CastShadow = true

		local lLArm = newRig["LeftLowerArm"]
		for _, part in ipairs(lLArm:GetChildren()) do
			if part:IsA("BasePart") then weldMod.Weld(lLArm,part) ;part.CanCollide = false; part.CanQuery = false end
		end
		lLArm.CanCollide = false
		lLArm.CanQuery = false
		lLArm.CanTouch = false
		lLArm.CastShadow = true

		local lhand = newRig["LeftHand"]
		for _, part in ipairs(lhand:GetChildren()) do
			if part:IsA("BasePart") then weldMod.Weld(lhand,part) ;part.CanCollide = false; part.CanQuery = false end
		end
		lhand.CanCollide = false
		lhand.CanQuery = false
		lhand.CanTouch = false
		lhand.CastShadow = true

		local rUArm = newRig["RightUpperArm"]
		for _, part in ipairs(rUArm:GetChildren()) do
			if part:IsA("BasePart") then weldMod.Weld(rUArm,part) ;part.CanCollide = false; part.CanQuery = false end
		end
		rUArm.CanCollide = false
		rUArm.CanQuery = false
		rUArm.CanTouch = false
		rUArm.CastShadow = true

		local rLArm = newRig["RightLowerArm"]
		for _, part in ipairs(rLArm:GetChildren()) do
			if part:IsA("BasePart") then weldMod.Weld(rLArm,part) ;part.CanCollide = false; part.CanQuery = false end
		end
		rLArm.CanCollide = false
		rLArm.CanQuery = false
		rLArm.CanTouch = false
		rLArm.CastShadow = true

		local rhand = newRig["RightHand"]
		for _, part in ipairs(rhand:GetChildren()) do
			if part:IsA("BasePart") then weldMod.Weld(rhand,part) ;part.CanCollide = false; part.CanQuery = false end
		end
		rhand.CanCollide = false
		rhand.CanQuery = false
		rhand.CanTouch = false
		rhand.CastShadow = true
		--Joints
		local leftUJoint = weldMod.M6D(newRig.AnimBase,lUArm)
		leftUJoint.Name = "LeftUJoint"
		local leftLJoint = weldMod.M6D(lUArm,lLArm)
		leftLJoint.Name = "LeftLJoint"
		local leftHJoint = weldMod.M6D(lLArm,lhand)
		leftHJoint.Name = "LeftHJoint"

		local rightUJoint = weldMod.M6D(newRig.AnimBase,rUArm)
		rightUJoint.Name = "RightUJoint"
		local rightLJoint = weldMod.M6D(rUArm,rLArm)
		rightLJoint.Name = "RightLJoint"
		local rightHJoint = weldMod.M6D(rLArm,rhand)
		rightHJoint.Name = "RightHJoint"

		base.Transparency = 1
		base.CanCollide = false
		base.CanQuery = false
		base.CanTouch = false
		base.CastShadow = false
		
	end

	--if not default then
	--	rArm.Transparency = 1
	--	lArm.Transparency = 1
	--end

	if attachTo then
		local baseWeld = weldMod.BlankWeld(attachTo,newRig.AnimBase)
		baseWeld.Name = "BaseWeld"
		baseWeld.Parent = newRig
	end

	local weaponFolder = Instance.new("Folder",newRig)
	weaponFolder.Name = "Weapon"

	return newRig
end

return viewMod
