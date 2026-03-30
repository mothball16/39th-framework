--[[       
DRAGOON TANK SYSTEM
Vehicle Controller Script
1.2.0
--]]

--// Services
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local tweens = game:GetService("TweenService")
local userInput = game:GetService("UserInputService")

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules
local wmodules = assets.Weapons
local amodules = assets.Addons

local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets") --Spearhead compat
local bridgeNet
if sphInstall then 
	bridgeNet = require(sphInstall.Modules.BridgeNet)
else  
	bridgeNet = require(modules.BridgeNet) 
end

local vehicle = script.Vehicle.Value
local seat = script.Seat.Value

local vehicleScripts = vehicle.Scripts
local mainParts = vehicle.Functional
local hullMain = mainParts.Mass

local weapons = vehicle.Weapons
local addons = vehicle.Addons
local InfraredMod = require(replicatedStorage.INTERACT_Assets.Modules.InfraredVision)
local bcalc = require(wmodules.Ballistic.BallisticCalculator)
local cameraShaker = require(modules.CameraShaker)
local config = require(assets.GlobalSettings)
local vehicleConfig = require(vehicleScripts.VehicleSettings)

--// Remotes
local rotateAssembly = bridgeNet.CreateBridge("rotateAssembly") -- Client > Server 
local exitTank = bridgeNet.CreateBridge("exitTank") -- Client > Server 
local getOwner = bridgeNet.CreateBridge("getOwner") -- Client > Server 

--// Vars n stuff
local player = game.Players.LocalPlayer
local character = player.Character
local humanoid = character:FindFirstChildWhichIsA("Humanoid")
local playerCam = game.Workspace.CurrentCamera
local viewMain = mainParts:FindFirstChild("View0") or character.Head or seat or hullMain

local gui:ScreenGui = player.PlayerGui:WaitForChild("DTS_UI"); gui.IgnoreGuiInset = true
local guiw = gui:WaitForChild("View0")
local assemblyOwned = true
local active = true

local groupID = vehicleConfig.GroupID
local groupRank

local health = 99999
local timer = 0 --0 to 60 seconds
local weaponActive = 0
local weaponList = 1
local weaponsAvailable = {}
local addonsAvailable = {}

local addonData = {}
local weaponData = {}
local weaponModules = {}

local LMBdown = false
local RMBdown = false
local freeAim = false
local zoomScrolling = false
local zoomTimerTask = nil
local sensScrolling = false
local sensTimerTask	= nil

local cameraMode = 0
local cameraZoom = 0
local cameraSens = 1
local cameraIR = false
local cameraNV = false

local fireModeNames = {"SAFE", "[SEMI]", "[AUTO]", "[BURST]", "[MANUAL]"}

local aimingParams = RaycastParams.new()
local ignoreList = {game.Workspace.DTS_Workspace.Temp, game.Workspace.DTS_Workspace.Cache, game.Workspace.Vehicles,vehicle}
aimingParams.FilterType = Enum.RaycastFilterType.Exclude
aimingParams.FilterDescendantsInstances = ignoreList
aimingParams.IgnoreWater = true

--// Camera Shake
local camShake = cameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
	playerCam.CFrame = playerCam.CFrame * shakeCf
end)
camShake:Start()

local twInfo = TweenInfo.new(0.5,	Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false)
local twWpnName

--// Helper functions

--local function GetOwner()
--return modules.GetOwner:FireServer(hullMain)
--assemblyOwned = seat:HasTag("Vehicle_Owner") --Method 1: get designated driver
--assemblyOwned = hullMain.ReceiveAge == 0 --Method 2: ??
--end

local function HingeSounds(targetAngle, TJoint, GJoint)
	local hinge1:HingeConstraint = TJoint:FindFirstChild("Hinge")
	local hinge2:HingeConstraint = GJoint:FindFirstChild("Hinge")
	local sound1:Sound = TJoint:FindFirstChild("HingeSound")
	local sound2:Sound = GJoint:FindFirstChild("HingeSound")

	if not targetAngle and sound1 and sound2 then 
		sound1:Stop()
		sound2:Stop()
	elseif sound1 and sound2 then
		local moving1 = hinge1 and math.abs(hinge1.CurrentAngle - targetAngle[1]) > 0.125 --Difference threshold: tune as desired
		local moving2 = hinge2 and math.abs(hinge2.CurrentAngle - targetAngle[2]) > 0.125

		if moving1 and not sound1.Playing then
			sound1:Play()
		elseif not moving1 and sound1.Playing then
			sound1:Stop()
		end
		if moving2 and not sound2.Playing then
			sound2:Play()
		elseif not moving2 and sound2.Playing then
			sound2:Stop()
		end
	end
end

local function ResetCamZooms() --For exiting tank
	for each, Data in weaponData do
		Data.Zoom1:Cancel()
		Data.Zoom2:Cancel()
	end

	playerCam.CameraSubject = humanoid
	playerCam.FieldOfView = 70
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = game:GetService("StarterPlayer").CameraMaxZoomDistance
	player.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
	userInput.MouseDeltaSensitivity = 1
	userInput.MouseIconEnabled = true
end

local function ResetSights() --For third person view (non-gunsight)
	local Data = weaponData[weaponActive]
	local maxZoom = (Data and Data.Config.GunnerScopeZoom and Data.Config.GunnerScopeZoom[2]) or (vehicleConfig.DefaultScopeZoom and vehicleConfig.DefaultScopeZoom[2]) or (config.ZoomLimits and config.ZoomLimits[2]) or game:GetService("StarterPlayer").CameraMaxZoomDistance
	local minZoom = (Data and Data.Config.GunnerScopeZoom and Data.Config.GunnerScopeZoom[1]) or (vehicleConfig.DefaultScopeZoom and vehicleConfig.DefaultScopeZoom[1]) or (config.ZoomLimits and config.ZoomLimits[1]) or game:GetService("StarterPlayer").CameraMinZoomDistance
	
	cameraMode = 0
	cameraZoom = 0
	cameraSens = 1 
	userInput.MouseIconEnabled = false
	player.CameraMaxZoomDistance = maxZoom/3
	player.CameraMinZoomDistance = maxZoom/3
	player.CameraMaxZoomDistance = minZoom
	player.CameraMinZoomDistance = maxZoom
	
	playerCam.FieldOfView = vehicleConfig.DefaultScopeFOV[1]
	userInput.MouseDeltaSensitivity = cameraSens
end

local function ResetTurrets()
	for each, Data in weaponData do
		HingeSounds(nil, Data.Base.TJointBase, Data.Turret.GJointBase)
	end
end

--// Functions
local function UpdateGUI()
	guiw.Visible = true		

	if weaponActive == 0 then 
		guiw.HUD.Weapon.weaponcode.Text = "No weapon"
	else
		local Data = weaponData[weaponActive]
		if not Data then return end

		guiw.HUD.Weapon.weaponcode.Text = Data["Config"]["WeaponName"]
		local wpnName = Data["UI"]:FindFirstChild("Crosshair") or (Data["UI"]:FindFirstChild("Sights_Inverse") and Data["UI"].Sights_Inverse:FindFirstChild("Crosshair"))
		if wpnName and wpnName:FindFirstChild("Weapon") then -- Vanguard added 5/4/2025: checks if wpnName exists before running this function
			coroutine.wrap(function()
				twWpnName = tweens:Create(wpnName.Weapon, twInfo, {TextTransparency = 1})
				wpnName.Weapon.Text = Data["Config"]["WeaponType"]
				wpnName.Weapon.TextTransparency = 0.5
				task.wait(1)
				twWpnName:Play()
			end)()
		end
	end
end

local function GetWeaponsAvailable()
	table.insert(weaponsAvailable, 0)
	--assemblyOwned = false
	for _, Part in seat:GetChildren() do
		if Part.Name == "ControlsSystem" and Part.Value ~= 0 then
			table.insert(weaponsAvailable, Part.Value)
		elseif Part.Name == "ControlsModule" then
			table.insert(addonsAvailable, Part.Value)
		end
	end
end

local function SwitchIR(Data)
	local newIR = (Data and Data.WeaponModel:GetAttribute("internal_Infrared")) or false
	local newNV = (Data and Data.WeaponModel:GetAttribute("internal_NightVis")) or false

	if newIR and not cameraIR then
		cameraIR = true
		InfraredMod.LoadIR(player, playerCam, gui)
	elseif cameraIR and not newIR then
		cameraIR = false
		InfraredMod.RemoveIR(player, playerCam, gui)
	end

	if newNV and not cameraNV then
		cameraNV = true
		InfraredMod.LoadNV(player, playerCam, gui)
	elseif cameraNV and not newNV then
		cameraNV = false
		InfraredMod.RemoveNV(player, playerCam, gui)
	end
	InfraredMod.ResetExposure()
end

local function SwitchSights()
	local Data = weaponData[weaponActive]
	if Data~=nil then 
		guiw.Gunsights:Play()
		if cameraMode <= 0 then --wpnGui.Sights.Visible = true
			cameraMode = 1
			cameraZoom = 0
			cameraSens = 0.05
			player.CameraMaxZoomDistance = 0
			player.CameraMinZoomDistance = 0
		elseif cameraMode >= 1 then 		--wpnGui.Sights.Visible = false
			cameraMode = 0
			cameraZoom = 0
			cameraSens = 1 --math.clamp(cameraSens*10 ,0.005,1)
			player.CameraMaxZoomDistance = (Data.Config.GunnerScopeZoom and Data.Config.GunnerScopeZoom[2]) or game:GetService("StarterPlayer").CameraMaxZoomDistance
			player.CameraMinZoomDistance = (Data.Config.GunnerScopeZoom and Data.Config.GunnerScopeZoom[1]) or game:GetService("StarterPlayer").CameraMinZoomDistance
		end
		userInput.MouseIconEnabled = false
		Data.Zoom1:Cancel()
		Data.Zoom2:Cancel()
		playerCam.FieldOfView = Data.Config.GunnerScopeFOV[1]
		userInput.MouseDeltaSensitivity = cameraSens
	else --If no weapon is selected
		--if cameraMode <= 0 then
		--cameraMode = 1
		--cameraZoom = 0
		--cameraSens = 1
		--elseif cameraMode >= 1 then
		cameraMode = 0
		cameraZoom = 0
		cameraSens = 1 --math.clamp(cameraSens*10 ,0.005,1)
		--end
		userInput.MouseIconEnabled = false
		player.CameraMaxZoomDistance = 0
		player.CameraMinZoomDistance = 0
		playerCam.FieldOfView = vehicleConfig.DefaultScopeFOV[1]
		userInput.MouseDeltaSensitivity = cameraSens
	end
end

local function ForceGunsights(switch)
	local Data = weaponData[weaponActive]
	local gunsightsForceState
	local gunsightsCurrent = cameraMode>=1

	if Data and Data.Config.GunnerScopeForced~=nil then
		gunsightsForceState = Data.Config.GunnerScopeAllowed and Data.Config.GunnerScopeForced
	elseif config.ForceGunsights~=nil then
		gunsightsForceState = config.ForceGunsights
	end

	if weaponActive~=0 and gunsightsForceState==true and gunsightsCurrent==false then
		SwitchSights()
	elseif weaponActive~=0 and gunsightsForceState==false and gunsightsCurrent==true then
		ResetSights()
	elseif weaponActive~=0 and gunsightsForceState==nil and switch then
		SwitchSights()
	elseif weaponActive==0 then
		ResetSights()
	end
end

local function SwitchWeapon(inverse)
	ResetTurrets()
	table.sort(weaponsAvailable)

	local oldActive = weaponActive

	if not inverse and weaponList == #weaponsAvailable then 
		weaponList = 1
	elseif inverse and weaponList <= 1 then 
		weaponList = #weaponsAvailable
	elseif not inverse then
		weaponList +=  1
	elseif inverse then
		weaponList -= 1
	end

	weaponActive = weaponsAvailable[weaponList]
	guiw.Switch:Play()
	getOwner:Fire(hullMain)
	UpdateGUI()
	--print("WeaponActive:", weaponActive, " WeaponList:", weaponList, " WeaponsAv:", #weaponsAvailable)


	--// Handle zoom, gunsights, night vision and turret sounds
	--local gunsightsForceState
	--local gunsightsCurrent = cameraMode>=1

	local Data = weaponData[weaponActive]
	if Data then
		HingeSounds(nil, Data.Base.TJointBase, Data.Turret.GJointBase)
		SwitchIR(Data)

		--if Data.Config.GunnerScopeForced~=nil then
		--	gunsightsForceState = Data.Config.GunnerScopeAllowed and Data.Config.GunnerScopeForced
		--end
	end

	--if config.ForceGunsights~=nil then
	--	gunsightsForceState = config.ForceGunsights
	--end

	--if weaponActive~=0 and gunsightsForceState==true and gunsightsCurrent==false then
	--	SwitchSights()
	--elseif weaponActive~=0 and gunsightsForceState==false and gunsightsCurrent==true then
	--	ResetSights()
	--elseif weaponActive==0 then
	--	ResetSights()
	--end


	--// Handle modular code

	--Every weapon
	for i = 1, #weaponData do
		local DataLocal = weaponData[i]
		if DataLocal and weaponModules[DataLocal.Module].WeaponSwitch then
			weaponModules[DataLocal.Module].WeaponSwitch(oldActive, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"])
		end
	end
	--Every module
	for i = 1, #addonData do
		local DataLocal = addonData[i]
		if DataLocal and weaponModules[DataLocal.Module].WeaponSwitch then
			weaponModules[DataLocal.Module].WeaponSwitch(oldActive, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"])
		end
	end
end

local function CalculateAim(aimPos, weapon, turretLimit, gunLimit, turretPivot, gunPivot, shellVelocity, GJointBase)
	-- Set vehicle angle (Pitch)
	local gjLookVector = GJointBase.CFrame.LookVector
	local xzNormalVector = Vector3.new(0, 1, 0)

	local dot = gjLookVector:Dot(xzNormalVector)
	local curVehDeg = 90 - math.deg(math.acos(dot))
	weapon:SetAttribute("internal_VehAngle", curVehDeg)

	local zeroing = weapon:GetAttribute("internal_Zero") or 0
	local tgtAngle, tgtAngle2 = bcalc.FindAngleToShootAt(zeroing, shellVelocity*3.5, workspace.Gravity,curVehDeg)
	local camrot = workspace.CurrentCamera.CFrame.LookVector
	local vert = bcalc.CalculateParallaxCompensation(workspace.CurrentCamera.CameraSubject.Position,weapon.Gun.Grip.Position,zeroing)

	--Calculate the direction vector from the yaw attachment to the target
	local pYaw = turretPivot:Inverse() * aimPos
	local yaw = math.atan2(-pYaw.Z, pYaw.X)

	--Calculate the direction vector from the pitch attachment to the target
	local targetCF = turretPivot:ToWorldSpace(CFrame.new(pYaw))
	local pPitch = gunPivot:Inverse() * targetCF.Position
	local pitch = math.atan2(-pPitch.Y, (pPitch.X^2 + pPitch.Z^2)^0.5)

	--Decide if we're using indirect fire or not
	local indirectFire = weapon:GetAttribute("internal_IndirectFire")
	local trueAngle = (indirectFire and math.abs(tgtAngle2)>=1 and math.deg(pitch)+tgtAngle2) or (indirectFire and math.abs(tgtAngle2)<1 and math.max(tgtAngle2, 45)) or (not indirectFire and math.deg(pitch)+tgtAngle)

	yaw = -(math.deg(yaw))

	pitch = trueAngle --math.deg(pitch)+trueAngle
	yaw = math.clamp(yaw, -turretLimit[1], turretLimit[2])
	pitch = math.clamp(pitch, -gunLimit[1], gunLimit[2])

	return {yaw, pitch}
end

local function CalculateParallax(aimPos:Vector3, weapon:Model)
	local view1:BasePart = weapon.Misc:FindFirstChild("View1")
	local view2:BasePart = weapon.Misc:FindFirstChild("View2")
	local grip:BasePart = weapon.Gun:FindFirstChild("Grip")
	if not view1 or not view2 or not grip or not aimPos then return end

	local v1Weld = view1:FindFirstChild("HingeWeld")
	local v2Weld = view2:FindFirstChild("HingeWeld")
	if not v1Weld or not v2Weld then return end

	local zeroing = weapon:GetAttribute("internal_Zero") or 100
	local finalPos = aimPos --(grip.Position - aimPos).Unit*zeroing

	local v1CFinal = CFrame.lookAt(view1.Position, finalPos).LookVector
	local v2CFinal = CFrame.lookAt(view2.Position, finalPos).LookVector
	v1Weld.C1 = CFrame.identity*CFrame.Angles(v1CFinal.X, v1CFinal.Y, v1CFinal.Z) --v1CFinal
	v2Weld.C1 = CFrame.identity*CFrame.Angles(v2CFinal.X, v2CFinal.Y, v2CFinal.Z)
end

local function AimWeapon(aimPos, weapon, turretLimit, gunLimit, turretSpeed, gunSpeed, Turret, Base, shellVelocity, dt)
	local targetAngle = CalculateAim(aimPos, weapon, turretLimit, gunLimit, Base.TJointBase.Direction.WorldCFrame, Turret.GJointBase.Direction.WorldCFrame, shellVelocity, Turret.GJointBase)
	--CalculateParallax(aimPos, weapon)

	weapon:SetAttribute("internal_CurAngleAz", targetAngle[1]) --weapon.Gun.Grip.Orientation.X
	weapon:SetAttribute("internal_CurAngle", targetAngle[2]) --weapon.Gun.Grip.Orientation.X
	HingeSounds(targetAngle, Base.TJointBase, Turret.GJointBase)

	local hinge1:HingeConstraint = Base.TJointBase:FindFirstChild("Hinge")
	local hinge2:HingeConstraint = Turret.GJointBase:FindFirstChild("Hinge")
	local weld1:Weld = Base.TJointBase:FindFirstChild("HingeWeld")
	local weld2:Weld = Turret.GJointBase:FindFirstChild("HingeWeld")

	if config.UseWeldReplication then --Replacing hinges with welds
		local t1CFinal
		if weld1 then
			local t1CFrame = CFrame.identity*CFrame.Angles(0, 0, math.rad(targetAngle[1]))
			local t1Axis, t1AngleDif = (weld1.C1:inverse() * t1CFrame):ToAxisAngle()
			t1CFinal =  weld1.C1:Lerp(t1CFrame, math.min(turretSpeed*dt/t1AngleDif, 1))
		end

		local t2CFinal
		if weld2 then
			local t2CFrame = CFrame.identity*CFrame.Angles(0, math.rad(targetAngle[2]), 0)
			local t2Axis, t2AngleDif = (weld2.C1:inverse() * t2CFrame):ToAxisAngle()
			t2CFinal =  weld2.C1:Lerp(t2CFrame, math.min(gunSpeed*dt/t2AngleDif, 1)) 
		end

		if not assemblyOwned or config.DirectTurretReplication then
			rotateAssembly:Fire(weld1, weld2, t1CFinal, t2CFinal, turretSpeed, gunSpeed)
		end
		if assemblyOwned or config.DirectTurretReplication then
			if weld1 and t1CFinal then
				weld1.C1 = t1CFinal
			end
			if weld2 and t2CFinal then
				weld2.C1 = t2CFinal
			end

			--We only move the hinges for compatibility reasons. They are not actually moving the turrets, they're disabled by now
			if hinge1 then
				hinge1.TargetAngle = targetAngle[1]
				hinge1.AngularSpeed = turretSpeed
			end
			if hinge2 then
				hinge2.TargetAngle = targetAngle[2]
				hinge2.AngularSpeed = gunSpeed
			end
		end
	else --Keeping hinges
		if not assemblyOwned then
			rotateAssembly:Fire(hinge1, hinge2, targetAngle[1], targetAngle[2], turretSpeed, gunSpeed)
		end
		if assemblyOwned or config.DirectTurretReplication then
			if hinge1 then
				hinge1.TargetAngle = targetAngle[1]
				hinge1.AngularSpeed = turretSpeed
			end
			if hinge2 then
				hinge2.TargetAngle = targetAngle[2]
				hinge2.AngularSpeed = gunSpeed
			end
		end
	end
end

--// Core Functions
local function ResetJump()
	humanoid.JumpPower = game.StarterPlayer.CharacterJumpPower
	humanoid.JumpHeight = game.StarterPlayer.CharacterJumpHeight
	humanoid.Jump = true
	humanoid.UseJumpPower = game.StarterPlayer.CharacterUseJumpPower
end

local function Exit()
	if not active then return end
	cameraIR = false
	InfraredMod.RemoveIR(player, playerCam, gui)
	active = false

	local Data = weaponData[weaponActive]
	if Data then
		Data.WeaponModel:SetAttribute("internal_Cycled", true)
		HingeSounds(nil, Data.Base.TJointBase, Data.Turret.GJointBase)
	end
	weaponActive = 0
	ResetTurrets()
	ResetCamZooms()
	ResetJump()
	gui.Enabled = false	
	exitTank:Fire(gui)
end

local function CheckIfInGroup()
	local inGroup = true
	if vehicleConfig.GroupID ~= 0 then
		if player:GetRankInGroup(vehicleConfig.GroupID) >= vehicleConfig.GroupRank or player.Backpack:FindFirstChild(vehicleConfig.BypassTool) then
			inGroup = true	
		else
			inGroup = false
		end
	end

	if not inGroup then
		Exit()
	end
end

local function keyChanged(InputObject:InputObject, Chat)
	if Chat or not active then return end

	if InputObject.UserInputType == Enum.UserInputType.MouseWheel and cameraMode>=1 then
		if userInput:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			--Zoom
			local Data = weaponData[weaponActive]
			if Data~=nil and Data.Config.GunnerScopeVariableZoom then 
				local newFOV = math.clamp(playerCam.FieldOfView-InputObject.Position.Z*3, Data.Config.GunnerScopeFOV[2], Data.Config.GunnerScopeFOV[1])

				if playerCam.FieldOfView ~= newFOV then
					playerCam.FieldOfView = newFOV

					if not zoomScrolling then
						zoomScrolling = true
						guiw.Zoom2:Play() 
					end
					if zoomTimerTask then
						task.cancel(zoomTimerTask) 
						zoomTimerTask = nil
					end
					zoomTimerTask = task.delay(0.25, function()
						zoomScrolling = false
						guiw.Zoom2:Stop()
						zoomTimerTask = nil
					end)
				end
			end
		else
			--Sensitivity
			cameraSens = math.clamp(cameraSens - 0.01*-InputObject.Position.Z,0.005,0.5)
			userInput.MouseDeltaSensitivity = cameraSens

			if cameraSens>0.005 and cameraSens<0.5 then
				if not sensScrolling then
					sensScrolling = true
					guiw.Sens:Play() 
				end
				if sensTimerTask then
					task.cancel(sensTimerTask) 
					sensTimerTask = nil
				end
				sensTimerTask = task.delay(0.25, function()
					sensScrolling = false
					guiw.Sens:Stop()
					sensTimerTask = nil
				end)
			end
		end
	end
end

local function keyDown(InputObject, Chat)
	if Chat or not active then return end
	local Data = weaponData[weaponActive]

	--if weaponActive~=0 and not Data then --Vanguard added 5/4/2025
	--	warn("DTS_Controller KeyDown: Weapon Data not Found!")
	--	return
	--end

	local modifier = InputObject:IsModifierKeyDown(Enum.ModifierKey.Shift)

	if InputObject.UserInputType == Enum.UserInputType.MouseButton1 or InputObject.KeyCode==Enum.KeyCode.ButtonR2 then
		LMBdown = true
		vehicle:SetAttribute("internal_holdingLMB", true)
	elseif InputObject.UserInputType  == Enum.UserInputType.MouseButton2 or InputObject.KeyCode==Enum.KeyCode.ButtonL2 then
		RMBdown = true
		vehicle:SetAttribute("internal_holdingRMB", true)

		if Data~=nil then 
			if cameraMode>=1 then
				if cameraZoom>=1 then
					cameraZoom = 0

					if cameraMode<1 or (cameraMode>=1 and not Data.Config.GunnerScopeVariableZoom) then
						Data.Zoom1:Play()
						guiw.Zoom:Play()
					end
				elseif cameraZoom<=0 then
					cameraZoom = 1

					if cameraMode<1 or (cameraMode>=1 and not Data.Config.GunnerScopeVariableZoom) then
						Data.Zoom2:Play()
						guiw.Zoom:Play()
					end
				end
			end
		end
	elseif InputObject.KeyCode == Enum.KeyCode.C then
		freeAim = true
		vehicle:SetAttribute("internal_freeAim", true)
	elseif InputObject.KeyCode == Enum.KeyCode.F or InputObject.KeyCode==Enum.KeyCode.ButtonX then
		SwitchWeapon(modifier)
		ForceGunsights()
	elseif InputObject.KeyCode == Enum.KeyCode.G or InputObject.KeyCode==Enum.KeyCode.ButtonY then
		ForceGunsights(true)

		--[[
			local gunsightsForceState
	local gunsightsCurrent = cameraMode<=0
	
	local Data = weaponData[weaponActive]
	if Data then
		HingeSounds(nil, Data.Base.TJointBase, Data.Turret.GJointBase)
		SwitchIR(Data)
		
		if Data.Config.GunnerScopeForced then
			gunsightsForceState = Data.Config.GunnerScopeAllowed and Data.Config.GunnerScopeForced
		end
	end

	if config.ForceGunsights~=nil then
		gunsightsForceState = config.ForceGunsights
	end
		--]]


	elseif InputObject.KeyCode == Enum.KeyCode.N and Data then
		if Data.Config.GunnerScopeInfrared then
			Data.WeaponModel:SetAttribute("internal_Infrared", not Data.WeaponModel:GetAttribute("internal_Infrared"))
		end
		if Data.Config.GunnerScopeNightVis then
			Data.WeaponModel:SetAttribute("internal_NightVis", not Data.WeaponModel:GetAttribute("internal_NightVis"))
		end

		guiw.Switch2:Play()
		SwitchIR(Data)
	elseif InputObject.KeyCode == Enum.KeyCode.Space or InputObject.KeyCode == Enum.KeyCode.ButtonA then
		if (config.JumpPreventionSpeed and character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude < config.JumpPreventionSpeed) or config.JumpPreventionSpeed==nil then 
			Exit()
		end
	end

	--Every weapon
	for i = 1, #weaponData do
		local DataLocal = weaponData[i]
		if DataLocal and weaponModules[DataLocal.Module].InputBegan then
			weaponModules[DataLocal.Module].InputBegan(InputObject, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"])
		end

		if DataLocal and DataLocal["WeaponModel"]:GetAttribute("internal_BulletsFired")~=nil then
			DataLocal["WeaponModel"]:SetAttribute("internal_BulletsFired", 0)
		end
	end
	--Every module
	for each, DataLocal in addonData do
		local wpnConfig = Data and Data["Config"] --The currently selected weapon's data. Not the module's!

		if DataLocal and weaponModules[DataLocal.Module].InputBegan then
			--inputObj:InputObject, weaponActive, vehicle, addonObj, gun, addonConfig, guiw
			weaponModules[DataLocal.Module].InputBegan(InputObject, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"])
		end
	end

	--for i = 1, #addonData do
	--	print("Input0")
	--	local DataLocal = addonData[i]
	--	--inputObj:InputObject, weaponActive, vehicle, addonObj, gun, addonConfig, guiw

	--end
end

local function keyUp(InputObject)
	if InputObject.UserInputType  == Enum.UserInputType.MouseButton1 or InputObject.KeyCode==Enum.KeyCode.ButtonR2 then
		LMBdown = false
		vehicle:SetAttribute("internal_holdingLMB", false)
	elseif InputObject.UserInputType  == Enum.UserInputType.MouseButton2 or InputObject.KeyCode==Enum.KeyCode.ButtonL2 then
		RMBdown = false
		vehicle:SetAttribute("internal_holdingRMB", false)
		zoomScrolling = false
		guiw.Zoom2:Stop()
		if zoomTimerTask then
			task.cancel(zoomTimerTask)
			zoomTimerTask = nil
		end
	elseif InputObject.KeyCode == Enum.KeyCode.C then
		freeAim = false
		vehicle:SetAttribute("internal_freeAim", false)
	end

	--Every weapon
	for i = 1, #weaponData do
		local DataLocal = weaponData[i]
		if DataLocal and weaponModules[DataLocal.Module].InputEnded then
			weaponModules[DataLocal.Module].InputEnded(InputObject, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"])
		end
	end
	--Every module
	for i = 1, #addonData do
		local DataLocal = addonData[i]
		if DataLocal and weaponModules[DataLocal.Module].InputEnded then
			weaponModules[DataLocal.Module].InputEnded(InputObject, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"])
		end
	end
end

local function FindModelWithCode(models:{Model}, targetCode)
	for _, model in models do
		local code = model:GetAttribute("Weapon_Code") or model:GetAttribute("Addon_Code")
		if code and targetCode==code then return model end
	end
end

local function WeaponSetup()
	--Setup weapons
	for each, value in pairs(weaponsAvailable) do
		local weaponObj = FindModelWithCode(weapons:GetChildren(), value)
		if not weaponObj then continue end

		local module = weaponObj:FindFirstChildOfClass("ModuleScript")
		local moduleUI = module and module:FindFirstChildOfClass("Frame")
		local localUI = moduleUI and gui:WaitForChild(moduleUI.Name)
		local moduleCFG = module and require(module) --settings module

		if not localUI then print("NO LOCAL UI FOR MODULE???!") return end

		if not moduleCFG or not localUI then continue end

		--Insert data
		table.insert(weaponData, value,
			{
				["Config"]= moduleCFG,
				["Module"]=  moduleCFG.WeaponModule, --weaponModule, was supposed to require the module once per gun even if repeated
				["Turreted"]= moduleCFG.TurretInstalled,
				["Firing"]= false,
				["Reloading"] = false,
				["WeaponModel"] = weaponObj,
				["Gun"] = weaponObj.Gun,
				["Turret"] = weaponObj.Turret,
				["Base"] = weaponObj.Base,
				["Misc"] = weaponObj.Misc,
				["Zoom1"] = tweens:Create(playerCam, moduleCFG.GunnerScopeTween, {FieldOfView = moduleCFG.GunnerScopeFOV[1]}),
				["Zoom2"] = tweens:Create(playerCam, moduleCFG.GunnerScopeTween, {FieldOfView = moduleCFG.GunnerScopeFOV[2]}),
				["UI"] = localUI
			}
		)
		--Load modules if they weren't already
		if table.find(weaponModules, moduleCFG.WeaponModule)==nil then 
			local loadedModule = require(wmodules[moduleCFG.WeaponModule]) --functionality module
			weaponModules[moduleCFG.WeaponModule] = loadedModule
			loadedModule.LoadGun(weaponObj, vehicle, localUI)
		else
			weaponModules[moduleCFG.WeaponModule].LoadGun(weaponObj, vehicle)
		end
	end	

	--Setup modules
	for _, value in addonsAvailable do
		local moduleObj = FindModelWithCode(addons:GetChildren(), value)
		if not moduleObj then continue end

		local module = moduleObj:FindFirstChildOfClass("ModuleScript")
		local moduleUI = module and module:FindFirstChildOfClass("Frame")
		local localUI = moduleUI and gui:WaitForChild(moduleUI.Name)
		local moduleCFG = module and require(module) --settings module

		if not localUI then print("NO LOCAL UI FOR MODULE???!") continue end

		if not moduleCFG or not localUI then continue end

		--Insert data
		table.insert(addonData, value,
			{
				["Config"]= moduleCFG,
				["Module"]=  moduleCFG.AddonModule, --weaponModule, was supposed to require the module once per gun even if repeated
				["WeaponModel"] =  moduleObj,
				["Gun"] = moduleObj:FindFirstChild("Gun") or moduleObj:FindFirstChildOfClass("Model"),
				["Turret"] = moduleObj:FindFirstChild("Turret"),
				["Base"] = moduleObj:FindFirstChild("Base"),
				["Misc"] = moduleObj:FindFirstChild("Misc"),
				["UI"] = localUI
			}
		)
		--Load modules if they weren't already
		if table.find(weaponModules, moduleCFG.AddonModule)==nil then 
			local loadedModule = require(amodules[moduleCFG.AddonModule]) --functionality module
			weaponModules[moduleCFG.AddonModule] = loadedModule

			if not loadedModule.LoadModule then continue end
			loadedModule.LoadModule(moduleObj, vehicle, localUI)
		else
			if not weaponModules[moduleCFG.AddonModule].LoadModule then continue end
			weaponModules[moduleCFG.AddonModule].LoadModule(moduleObj, vehicle)
		end
	end	
end

local function MobileKeyEmulation(button, keyPressed)
	if not active then return end
	local InputObject = 
		{ 
			["KeyCode"] = Enum.KeyCode:FromName(button:GetAttribute("KeyCode")) or nil,
			["UserInputType"] = Enum.UserInputType:FromName(button:GetAttribute("UserInputType")) or Enum.UserInputType.Keyboard
		}
	if keyPressed then
		keyDown(InputObject, false)
	else
		keyUp(InputObject, false)
	end
end

local function MobileSupportSetup()
	--Mobile support
	if userInput.KeyboardEnabled==false and active then
		gui.MobileControl.Visible = true

		for each, button in pairs(gui.MobileControl:GetChildren()) do
			if not button:IsA("TextButton") then continue end

			button.InputBegan:Connect(function()
				MobileKeyEmulation(button, true)
			end)
			button.InputEnded:Connect(function()
				MobileKeyEmulation(button, false)
			end)
		end
	else
		gui.MobileControl.Visible = false
	end
end

local function RenderLoop(deltaTime)
	if not active then return end

	--Selected Weapon
	local Data = weaponData[weaponActive]

	if weaponActive~= 0 and Data then
		--Zoom controlled mouse lock
		local zoom = (Data.Misc.View2.CFrame.Position - playerCam.CFrame.Position).Magnitude
		local maxZoom = (Data.Config.GunnerScopeZoom and Data.Config.GunnerScopeZoom[2]) or (config.ZoomLimits and config.ZoomLimits[2]) or game:GetService("StarterPlayer").CameraMaxZoomDistance
		local minZoom = (Data.Config.GunnerScopeZoom and Data.Config.GunnerScopeZoom[1]) or (config.ZoomLimits and config.ZoomLimits[1]) or game:GetService("StarterPlayer").CameraMinZoomDistance

		if cameraMode<=0 and zoom>0.7 then 
			userInput.MouseIconEnabled = true
		else
			userInput.MouseIconEnabled = false
		end

		--Sights
		if cameraMode>=1 then
			playerCam.CameraSubject = Data.Misc.View1
			--userInput.MouseDeltaSensitivity = 0.1
			--playerCam:PivotTo(Data.Misc.View1.CFrame)

			player.CameraMaxZoomDistance = 0
			player.CameraMinZoomDistance = 0
			player.CameraMode = Enum.CameraMode.Classic
		else
			playerCam.CameraSubject = Data.Misc.View2
			--userInput.MouseDeltaSensitivity = 1
			--playerCam:PivotTo(Data.Misc.View2.CFrame)

			player.CameraMaxZoomDistance = maxZoom
			player.CameraMinZoomDistance = minZoom
			player.CameraMode = Enum.CameraMode.Classic
		end

		--Stats
		guiw.HUD.AmmoFrame.Ammo.Ammo.Text = Data.WeaponModel:GetAttribute("clipAmmo").."/"..Data.WeaponModel:GetAttribute("storedAmmo")
		guiw.HUD.Other.Firemode.Text = fireModeNames[(Data.WeaponModel:GetAttribute("internal_Firemode") or 0) + 1]
		guiw.HUD.Other.Sens.Text = string.format("%.2f", userInput.MouseDeltaSensitivity)
	else 
		--Zoom controlled mouse lock
		local zoom = (viewMain.CFrame.Position - playerCam.CFrame.Position).Magnitude
		local maxZoom = (vehicleConfig.DefaultScopeZoom and vehicleConfig.DefaultScopeZoom[2]) or (config.ZoomLimits and config.ZoomLimits[2]) or game:GetService("StarterPlayer").CameraMaxZoomDistance
		local minZoom = (vehicleConfig.DefaultScopeZoom and vehicleConfig.DefaultScopeZoom[1]) or (config.ZoomLimits and config.ZoomLimits[1]) or game:GetService("StarterPlayer").CameraMinZoomDistance

		if cameraMode<=0 and zoom>0.7 then 
			userInput.MouseIconEnabled = true
		else
			userInput.MouseIconEnabled = false
		end

		--Sights
		if cameraMode>=1 then
			playerCam.CameraSubject = viewMain
			player.CameraMaxZoomDistance = 0
			player.CameraMinZoomDistance = 0
			player.CameraMode = Enum.CameraMode.Classic
		else
			playerCam.CameraSubject = viewMain
			player.CameraMaxZoomDistance = maxZoom
			player.CameraMinZoomDistance = minZoom
			player.CameraMode = Enum.CameraMode.Classic
		end
		guiw.HUD.Other.Sens.Text = string.format("%.2f", userInput.MouseDeltaSensitivity)
		guiw.HUD.AmmoFrame.Ammo.Ammo.Text = "N/A"
		guiw.HUD.Other.Firemode.Text = "N/A"
	end

	--Every weapon
	for each, DataLocal in weaponData do
		--print(DataLocal["UI"])
		if weaponModules[DataLocal.Module].RenderLoop then
			local aimPos = weaponModules[DataLocal.Module].RenderLoop(deltaTime, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Turret"],  DataLocal["Config"], DataLocal["UI"], cameraMode, userInput:GetMouseDelta())
			if aimPos and DataLocal.Config.TurretInstalled and table.find(DataLocal.Config.WeaponCodeAiming, weaponActive)~=nil and not freeAim then
				AimWeapon(aimPos, DataLocal["WeaponModel"], DataLocal.Config.TurretLimits, DataLocal.Config.GunLimits, DataLocal.Config.TurretSpeed, DataLocal.Config.GunSpeed, DataLocal.Turret, DataLocal.Base, DataLocal.Config.ShellVelocity, deltaTime)
			end
		end	
	end

	--Every module
	for each, DataLocal in addonData do
		--print(DataLocal["UI"])
		if DataLocal and weaponModules[DataLocal.Module].RenderLoop then
			local aimPos = weaponModules[DataLocal.Module].RenderLoop(deltaTime, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"], cameraMode, userInput:GetMouseDelta())
			if aimPos and DataLocal.Config.TurretInstalled and table.find(DataLocal.Config.AddonCodeAiming, weaponActive)~=nil and not freeAim then
				AimWeapon(aimPos, DataLocal["WeaponModel"], DataLocal.Config.TurretLimits, DataLocal.Config.GunLimits, DataLocal.Config.TurretSpeed, DataLocal.Config.GunSpeed, DataLocal.Turret, DataLocal.Base, DataLocal.Config.ShellVelocity or 1, deltaTime)
			end
		end
	end

	--Infrared vision
	if Data and cameraIR then
		InfraredMod.RenderExposure(2)
		InfraredMod.RenderHighlights(player, playerCam, gui, cameraNV, vehicle, deltaTime)
	elseif Data and cameraNV then
		InfraredMod.RenderExposure(2)
		InfraredMod.RenderNoise(player, playerCam, gui)
	end

end

local function RunLoop(deltaTime)
	if not active then return end

	--Current weapon
	local Data = weaponData[weaponActive]

	--Every weapon
	for each, DataLocal in weaponData do
		if DataLocal and weaponModules[DataLocal.Module].RunLoop then
			weaponModules[DataLocal.Module].RunLoop(deltaTime, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"], camShake)
		end
	end

	--Every module
	for each, DataLocal in addonData do
		local wpnConfig = Data and Data["Config"] --The currently selected weapon's data. Not the module's!

		if DataLocal and weaponModules[DataLocal.Module].RunLoop then
			weaponModules[DataLocal.Module].RunLoop(deltaTime, weaponActive, vehicle, DataLocal["WeaponModel"], DataLocal["Gun"], DataLocal["Config"], DataLocal["UI"], wpnConfig)
		end
	end
end

local function SetDefaults()
	if config.ForceGunsights then --Switch to gunsights inmediately, then prevent the user from switching manually
		SwitchSights()
	end
end

--// Game loop & Connections
getOwner:Connect(function(owner, bool)
	if owner==player then 
		assemblyOwned=true 
	else
		assemblyOwned = false
	end
end)
humanoid.HealthChanged:Connect(function()
	if humanoid.Health<=0 then
		Exit()
	end
end)
humanoid.Seated:Connect(function(sitting)
	if not sitting then Exit() end
end) 	
vehicle:GetAttributeChangedSignal("Vehicle_HP"):Connect(function()
	local newHealth = vehicle:GetAttribute("Vehicle_HP")
	if newHealth < health then
		camShake:Shake(cameraShaker.Presets.Bump)
		guiw.Hit:Play()
		health = newHealth
	end
end)
getOwner:Fire(hullMain)

CheckIfInGroup()
GetWeaponsAvailable()
WeaponSetup()
userInput.InputBegan:Connect(keyDown)
userInput.InputEnded:Connect(keyUp)
userInput.InputChanged:Connect(keyChanged)
MobileSupportSetup()
runService.RenderStepped:Connect(RenderLoop)
runService.Heartbeat:Connect(RunLoop)
SetDefaults()
UpdateGUI()
--print("Assembly:", assemblyOwned)