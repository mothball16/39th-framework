--[[       
DRAGOON TANK SYSTEM
Vehicle Setup
1.2.0
--]]

--// Services
local DS = game:GetService("Debris")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local Setup = {}

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules
local wmodules = assets.Weapons
local amodules = assets.Addons

local atmod = require(modules.Antitank)
local destroy = require(modules.SelfDestruction)
local config = require(assets.GlobalSettings)

local nameExceptions_Massless = {"Mass", "Floater", "TJointTop", "TJointBase", "GJointTop", "GJointBase", "MassPart", "Trigger"}

--// Functions
local function Weld(x:BasePart,y:BasePart,name:string)
	local W = Instance.new("WeldConstraint")
	W.Name = name or "Weld"
	W.Part0 = x
	W.Part1 = y
	W.Parent = x
end

local function ParentCheck(Part:BasePart, ParentName:string, Times:number)
	local tries = 0
	Times = Times or 6
	local currentPart = Part
	while currentPart and tries < Times do
		if currentPart.Name == ParentName then return currentPart end
		currentPart = currentPart.Parent
		tries += 1
	end
	return nil
end

local function ParentCheckII(Part:BasePart, TargetName:string)
	local ancestor = Part.Parent
	while ancestor do
		local partB = ancestor:FindFirstChild(TargetName)
		if partB then return partB end
		ancestor = ancestor.Parent
	end
	return nil
end

local function UpdateOwner(target,owner,bool)
	for _, Part in ipairs(target:GetChildren()) do		
		if Part:IsA("BasePart") then 
			if bool == true then
				Part:SetNetworkOwner(owner)
			else
				Part:SetNetworkOwnershipAuto()
			end		
		elseif Part:IsA("Model") or Part:IsA("Folder") then
			UpdateOwner(Part,owner,bool)
		end
	end
end

local function ResetVelocities(engine)
	for _, Part in ipairs(engine:GetChildren()) do		
		if Part:IsA("BodyAngularVelocity") then
			Part.AngularVelocity = Vector3.zero
		end
	end
end

--// Important Functions
local function ChildChanged(player)
	if not player then return end

	local targetPos = player:FindFirstChild("Target_Pos") 
	local targetObj = player:FindFirstChild("Target_Obj")

	if targetPos then
		targetPos.Value = Vector3.zero
	end

	if targetObj then
		targetObj.Value = nil
	end
end

local function ChildAdded(child, seat:VehicleSeat, vehicle, mainPart)
	if vehicle:GetAttribute("Vehicle_HP") <= 0 then return end

	local weapons = vehicle.Weapons
	local addons = vehicle.Addons
	local seatWeld = seat:FindFirstChild("SeatWeld")

	if seatWeld and seatWeld==child then
		local character = child.Part1.Parent
		local player = game.Players:getPlayerFromCharacter(character)
		if not player then  return end --ResetVelocities(mainPart)

		ChildChanged(player)

		--Prevent players from leaving ny jumping ()
		local humanoid:Humanoid = character:FindFirstChildOfClass("Humanoid")
		if character and humanoid then
			humanoid.UseJumpPower = true
			--print("ping!")
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 1
			humanoid.Jump = false
		end

		--Vehicle seat ownership
		if seat:HasTag("Vehicle_Owner") then
			UpdateOwner(vehicle, player, true)
		end

		--Initial check for tags
		local weaponTags = {}
		local addonTags = {}

		for _, tag in seat:GetChildren() do
			if tag.Name == "ControlsSystem" then
				table.insert(weaponTags, tag.Value)
			elseif tag.Name == "ControlsModule" then
				table.insert(addonTags, tag.Value)
			end
		end
		if #weaponTags <= 0 then return end

		local newGui = script.DTS_UI:clone()
		newGui.Parent = player.PlayerGui;

		local controllerScript = script.DTS_Controller:Clone()
		controllerScript.Vehicle.Value = vehicle
		controllerScript.Seat.Value = seat
		controllerScript.Parent = newGui.Scripts

		for _, weaponObj in weapons:GetChildren() do
			local weaponCode = weaponObj:GetAttribute("Weapon_Code")
			if not weaponCode or not table.find(weaponTags, weaponCode) then continue end

			local module = weaponObj:FindFirstChildOfClass("ModuleScript")
			if not module then continue end

			local uiFrame = module:FindFirstChildOfClass("Frame"):Clone()
			uiFrame:SetAttribute("Weapon_Code", weaponCode)
			uiFrame.Parent = newGui
		end
		for _, addonObj in addons:GetChildren() do
			local addonCode = addonObj:GetAttribute("Addon_Code")
			if not addonCode or not table.find(addonTags, addonCode) then continue end

			local module = addonObj:FindFirstChildOfClass("ModuleScript")
			if not module then continue end

			local uiFrame = module:FindFirstChildOfClass("Frame"):Clone()
			uiFrame:SetAttribute("Addon_Code", addonCode)
			uiFrame.Parent = newGui
		end

		controllerScript.Enabled = true
		ResetVelocities(mainPart)
	end
end

local function ChildRemoved(child, seat)
	if child:IsA("Weld") then
		local character = child.Part1.Parent
		local player = game.Players:getPlayerFromCharacter(character)
		if not player then return end

		ChildChanged(player)

		local gui = player.PlayerGui:FindFirstChild("DTS_UI")
		if gui then gui:Destroy() end

		--Reset jumping if it was disabled
		task.delay(1, function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if character and humanoid then 
				humanoid.JumpPower = game.StarterPlayer.CharacterJumpPower
				humanoid.JumpHeight = game.StarterPlayer.CharacterJumpHeight
				humanoid.Jump = false
				humanoid.UseJumpPower = game.StarterPlayer.CharacterUseJumpPower
			end
		end)
	end
end

local function WeldException(Part)
	local c1 = Part:FindFirstChild("CoaxialWeld")
	local c2 = Part:FindFirstChild("TurretWeld")
	local c3 = Part:FindFirstChild("GunWeld")
	local c4 = Part:FindFirstChild("BaseWeld")
	local c5 = Part:HasTag("IgnoreWeld")
	if c1 or c2 or c3 or c4 or c5 then return true end
end

local function Combine(a1, a2)
	local new = table.create(#a1 + #a2)
	table.move(a1, 1, #a1, 1, new)
	table.move(a2, 1, #a2, 1 + #a1, new)
	return new
end

local function CheckForAlignment(vehicle, hullMain, weapons, addons)
	for each, weaponObj in Combine(weapons:GetChildren(), addons:GetChildren()) do
		--View alignment
		local gunModel = weaponObj:FindFirstChild("Gun")
		local baseModel = weaponObj:FindFirstChild("Base")
		local turretModel = weaponObj:FindFirstChild("Turret")
		local miscModel = weaponObj:FindFirstChild("Misc")

		--Muzzle alignment
		if gunModel then
			for each, muzzle in gunModel:GetChildren() do
				if muzzle.Name~="Grip" then continue end
				
				--Rotator hinge replacement
				local rotatorHinge:HingeConstraint = muzzle:FindFirstChild("Rotator")
				if rotatorHinge and config.UseWeldReplication then
					local weldReplacement = Instance.new("Weld")
					
					weldReplacement.Name = "RotatorWeld"
					weldReplacement.Parent = rotatorHinge.Parent
					weldReplacement.Part0 = rotatorHinge.Attachment0.Parent
					weldReplacement.Part1 = rotatorHinge.Attachment1.Parent
					weldReplacement.C1 = CFrame.new()
					weldReplacement.C0 = weldReplacement.Part0.CFrame:toObjectSpace(weldReplacement.Part1.CFrame)
					rotatorHinge.Enabled = false
				end
				
				--Muzzle realignment
				if muzzle:FindFirstChildWhichIsA("WeldConstraint") then continue end
				muzzle.Orientation = weaponObj.Gun.GJointTop.Orientation
			end
		end

		--Viewpoint aligment
		local view1:BasePart = miscModel and miscModel:FindFirstChild("View1")
		local view2:BasePart = miscModel and miscModel:FindFirstChild("View2")
		if view1 then
			view1.Orientation = weaponObj.Gun.GJointTop.Orientation
			--[[
			local weld1og = view1:FindFirstChildWhichIsA("WeldConstraint")
			local weld1new = Instance.new("Weld")
			weld1new.Name = "HingeWeld"
			weld1new.Parent = view1
			weld1new.Part0 = weld1og.Part0
			weld1new.Part1 = weld1og.Part1
			weld1new.C1 = CFrame.new()
			weld1new.C0 = weld1new.Part0.CFrame:toObjectSpace(weld1new.Part1.CFrame)
			weld1og.Enabled = false
			
			local weld2og = view2:FindFirstChildWhichIsA("WeldConstraint")
			local weld2new = Instance.new("Weld")
			weld2new.Name = "HingeWeld"
			weld2new.Parent = view2
			weld2new.Part0 = weld2og.Part0
			weld2new.Part1 = weld2og.Part1
			weld2new.C1 = CFrame.new()
			weld2new.C0 = weld2new.Part0.CFrame:toObjectSpace(weld2new.Part1.CFrame)
			weld2og.Enabled = false
			--]]
		end

		--Weld replacement
		local hinge1:HingeConstraint = baseModel and baseModel:FindFirstChild("TJointBase") and baseModel.TJointBase:FindFirstChild("Hinge")
		local hinge2:HingeConstraint =  turretModel and turretModel:FindFirstChild("GJointBase") and turretModel.GJointBase:FindFirstChild("Hinge")
		
		if config.UseWeldReplication then
			if hinge1 then
				local weld1 = Instance.new("Weld")
				weld1.Name = "HingeWeld"
				weld1.Parent = hinge1.Parent
				weld1.Part0 = hinge1.Attachment0.Parent
				weld1.Part1 = hinge1.Attachment1.Parent
				--weld1.C0 = hinge1.Attachment0.CFrame
				weld1.C1 = CFrame.identity * CFrame.Angles(0, 0, math.rad(hinge1.TargetAngle))
				hinge1.Enabled = false
			end

			if hinge2 then
				local weld2 = Instance.new("Weld")
				weld2.Name = "HingeWeld"
				weld2.Parent = hinge2.Parent
				weld2.Part0 = hinge2.Attachment0.Parent
				weld2.Part1 = hinge2.Attachment1.Parent
				--weld2.C0 = hinge2.Attachment0.CFrame
				weld2.C1 = CFrame.identity * CFrame.Angles(0, math.rad(hinge2.TargetAngle), 0)
				hinge2.Enabled = false
			end
		end
	end
end

local function CheckForWelds(target, hullMain, vehicle)
	for _, Part in target:GetChildren() do
		if Part:IsA("VehicleSeat") or Part:IsA("Seat") and (Part:FindFirstChild("ControlsSystem") or Part:FindFirstChild("ControlsModule")) then 
			Part.ChildAdded:connect(function(child)
				ChildAdded(child, Part, vehicle, hullMain) 
			end)
		end
		

		if Part:IsA("BasePart") and not Part:HasTag("IgnoreWeld") then
			
			local Avoid = WeldException(Part)

			if ParentCheck(Part, "Body",  4) and not Avoid then
				Weld(Part, hullMain, "toHullMain")
				Part.CollisionGroup="VehicleBody"
			elseif ParentCheckII(Part, "WheelModel") and not Avoid then
				Weld(Part, ParentCheckII(Part, "WheelModel"), "WheelWeld")
				Part.CollisionGroup="VehicleWheels"
			elseif ParentCheckII(Part, "Trigger") then
				Weld(ParentCheckII(Part, "Trigger") or Part.Parent.PrimaryPart, Part, "toHullMainMisc")	
			elseif ParentCheckII(Part, "SJointTop") and not Avoid then
				Weld(Part, ParentCheckII(Part, "SJointTop"), "SpecialJointTop")
				Part.CollisionGroup="VehicleTurret"
			elseif ParentCheckII(Part, "TJointTop") and not Avoid then
				Weld(Part, ParentCheckII(Part, "TJointTop"), "toTurretJointTop")
				Part.CollisionGroup="VehicleTurret"
			elseif ParentCheckII(Part, "GJointTop") and not Avoid then
				Weld(Part, ParentCheckII(Part, "GJointTop"), "toGunJointTop")
				Part.CollisionGroup="VehicleGun"
			elseif ParentCheckII(Part, "TJointBase") and not Avoid then
				Weld(Part, ParentCheckII(Part, "TJointBase"), "toTurretJointBase")
				Part.CollisionGroup="VehicleBody"
			end

			if Part:HasTag("Dragoon_Armor") then 
				Part.CollisionGroup="VehicleBody" 
			end
		elseif (Part:IsA("Model") or Part:IsA("Folder")) then --and not Part:HasTag("IgnoreWeld") 
			CheckForWelds(Part, hullMain, vehicle)
		end
	end
end

local function CheckForAnchored(target)
	for _, Part in target:GetChildren() do
		if Part:HasTag("IgnoreWeld") then continue end
		
		if Part:IsA("BasePart") then
			Part.Anchored = false
			if not table.find(nameExceptions_Massless, Part.Name) and not Part:HasTag("Dragoon_Armor") then
				Part.Massless = true	
			end
		elseif Part:IsA("Model") or Part:IsA("Folder") and not Part:HasTag("IgnoreWeld") then
			CheckForAnchored(Part)
		end
	end
end

function Setup.LoadVic(vehicle:Model)
	--Load vehicle
	local vehicleScripts = vehicle.Scripts
	local mainParts = vehicle.Functional
	local hullMain = mainParts.Mass
	local engine = mainParts:FindFirstChild("Engine") or hullMain

	local weapons = vehicle.Weapons
	local addons = vehicle.Addons
	local vehicleConfig = require(vehicleScripts.VehicleSettings)
	local roadkill = {}
	local roadkillTime = 0
	local roadkillTask

	--Run welding script
	CheckForAlignment(vehicle, hullMain, weapons, addons)
	CheckForWelds(vehicle, hullMain, vehicle)
	CheckForAnchored(vehicle)

	--Kill brick setup
	for _, funcPart:BasePart in mainParts:GetChildren() do
		if funcPart.Name=="MovingHitbox" then
			funcPart.Touched:Connect(function(hitPart)
				if hitPart:IsDescendantOf(vehicle) then return end

				roadkillTime = os.clock()

				if roadkillTask then task.cancel(roadkillTask) end
				roadkillTask = task.delay(5, function()
					if os.clock() - roadkillTime >= 5 then
						table.clear(roadkill)
					end
				end)

				--Run code
				local hitVel:number = funcPart.AssemblyLinearVelocity.Magnitude
				local hitMass:number = hitPart.AssemblyMass
				if hitVel<5 or hitMass<5 or table.find(roadkill, hitPart)~=nil then return end

				local plrDriver = mainParts.Seats.VehicleSeat.Occupant -- does this vehicle have a driver?
				local plrKiller = plrDriver and game.Players:GetPlayerFromCharacter(plrDriver.Parent)

				local vicDmg = math.clamp(math.map(hitVel, 0, 20, 0, 50), 0, 50)
				local vicPen = 25
				local plrDmg = math.map(hitVel, 0, 20, 5, 150)
				local knockback = Vector3.new(0,0, -hitVel/5)

				local result = atmod.RoadKill(funcPart, hitPart, plrKiller, roadkill, {vicPen, vicDmg, plrDmg, knockback})
				if result then
					table.insert(roadkill, result)
				end
			end)
		end
	end

	--Weapon & Module setup
	for _, weaponObj in weapons:GetChildren() do
		local module = weaponObj:FindFirstChildOfClass("ModuleScript")
		if not module then continue end

		local moduleCFG = require(module)
		if moduleCFG.MaxAmmo and moduleCFG.ClipSize then
			weaponObj:SetAttribute("clipAmmo", moduleCFG.SpawnClip or moduleCFG.ClipSize)
			weaponObj:SetAttribute("storedAmmo", moduleCFG.SpawnAmmo or moduleCFG.MaxAmmo)
			weaponObj:SetAttribute("maxAmmo", moduleCFG.MaxAmmo)
		end
		if moduleCFG.ShellType then
			weaponObj:SetAttribute("Weapon_ShellType", moduleCFG.ShellType)
		end
		weaponObj:SetAttribute("Weapon_Name", moduleCFG.WeaponName)
		weaponObj:SetAttribute("Weapon_Type", moduleCFG.WeaponType)
		weaponObj:SetAttribute("Weapon_Module", moduleCFG.WeaponModule)
		weaponObj:SetAttribute("Weapon_Code", moduleCFG.WeaponCode)

		local uiFrame = module:FindFirstChildOfClass("Frame")
		if uiFrame then
			uiFrame.Name = "View"..moduleCFG.WeaponCode
		end
	end
	for _, moduleObj in addons:GetChildren() do
		local module = moduleObj:FindFirstChildOfClass("ModuleScript")
		if not module then continue end

		local moduleCFG = require(module)
		if moduleCFG.MaxAmmo and moduleCFG.ClipSize then
			moduleObj:SetAttribute("clipAmmo", moduleCFG.ClipSize)
			moduleObj:SetAttribute("storedAmmo", moduleCFG.MaxAmmo)
			moduleObj:SetAttribute("maxAmmo", moduleCFG.MaxAmmo)
		end
		moduleObj:SetAttribute("Addon_Name", moduleCFG.AddonName)
		moduleObj:SetAttribute("Addon_Type", moduleCFG.AddonType)
		moduleObj:SetAttribute("Addon_Module", moduleCFG.AddonModule)
		moduleObj:SetAttribute("Addon_Code", moduleCFG.AddonCode)

		local uiFrame = module:FindFirstChildOfClass("Frame")
		if uiFrame then
			uiFrame.Name = "ViewM"..moduleCFG.AddonCode
		end
	end

	vehicle:SetAttribute("Vehicle_HP", vehicleConfig.MaxVehicleHitpoints)
	vehicle:SetAttribute("Vehicle_MaxHP", vehicleConfig.MaxVehicleHitpoints)
	vehicle:SetAttribute("Vehicle_ExplodeFX", vehicleConfig.ExplodeFX)
	vehicle:SetAttribute("Vehicle_Name", vehicleConfig.VehicleName)

	if not vehicle:HasTag("Okami_Chassis") and not vehicle:HasTag("INTERACT_LOADED") then
		vehicle:AddTag("INTERACT_LOADED")
	end
end

return Setup
