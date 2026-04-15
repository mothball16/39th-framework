--[[       
DRAGOON TANK SYSTEM
Ballistic Weapon module
1.1.1

With additions and improvements from:
- Widukindazz & Prestigeless (Zeroing, ballistic calculator)
--]]

local module = {}

--// Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInput = game:GetService("UserInputService")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local tweens = game:GetService("TweenService")
local guiservice = game:GetService("GuiService")

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules
local wmodules = assets.Weapons
local amodules = assets.Addons
local projectiles = assets.Projectiles

local bcalc = require(script.BallisticCalculator)
local hudMod = require(modules.HUDModule)
local pierceMod = require(modules.PierceMod)
local cameraShakeInstance = require(modules.CameraShaker.CameraShakeInstance)
local hitFX = require(modules.HitFX)
local config = require(assets.GlobalSettings)

local sphCore = replicatedStorage:FindFirstChild("SPH_Framework")
local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets")
local bridgeNet
local partCache
if sphCore then
	bridgeNet = require(sphCore.Network.BridgeNet)
	partCache = require(sphCore.Ballistics.PartCache)
elseif sphInstall and sphInstall:FindFirstChild("Modules") then
	bridgeNet = require(sphInstall.Modules.Network.BridgeNet)
	partCache = require(sphInstall.Modules.Ballistics.PartCache)
else
	bridgeNet = require(modules.BridgeNet)
	partCache = require(modules.PartCache)
end

--// Events
local fastCastClient = assets.Events.BallisticReplication
local attSet = bridgeNet.CreateBridge("attributeSet") -- Client > Server 
local playerReload = bridgeNet.CreateBridge("PlayerReload2")
local playerFire = bridgeNet.CreateBridge("PlayerFire2")

local player = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

local aimingParams = RaycastParams.new()
aimingParams.FilterType = Enum.RaycastFilterType.Exclude
aimingParams.IgnoreWater = true

local autoTargetUpdate = false
local spoolTimer = 0

local fireModes = {
	Safe = 0,
	Semi = 1,
	Auto = 2,
	Burst = 3,
	Manual = 4
}
local fireModeNames = {"SAFE", "[SEMI]", "[AUTO]", "[BURST]", "[MANUAL]"}

--// Functions
local function ChooseMuzzle(muzzleSel, gun)
	local currentSet = {}
	local allSet = {}

	for each, muzzle in pairs(gun:GetChildren()) do
		if muzzle.Name~="Grip" then continue end
		table.insert(allSet, muzzle)

		local priority = muzzle:GetAttribute("Muzzle_FiringOrder") or 1
		if priority == muzzleSel then
			table.insert(currentSet, muzzle)
		end
	end
	return currentSet, allSet
end

local function ConstraintUpdate(grip, firerate, weapon, vehicle, dt, spoolTime, momentum)
	-- Max angular speed (deg/sec)
	local angleStep = grip:GetAttribute("Cannon_RotationStep") or 60
	local maxDegPerSec = (firerate/60) * angleStep
	local isFiring = vehicle:GetAttribute("internal_holdingLMB") == true and grip:GetAttribute("Muzzle_FiringOrder")==weapon:GetAttribute("internal_MuzzleCycle")

	local spoolState = grip:GetAttribute("Cannon_SpoolState") or 0
	local oldSpool = spoolState
	spoolTime = spoolTime or 0
	momentum = momentum or spoolTime

	--Update spool state (accelerate or decelerate)
	if spoolTime > 0 then
		if isFiring then
			spoolState = math.clamp(spoolState + dt / spoolTime, 0, 1)
		else
			spoolState = math.clamp(spoolState - dt / momentum, 0, 1)
		end
	else
		spoolState = isFiring and 1 or 0
	end

	--Handle hinges and welds
	local rotator:HingeConstraint = grip:FindFirstChild("Rotator")
	if rotator then
		local maxRadPerSec = math.rad(maxDegPerSec)
		rotator.ActuatorType = Enum.ActuatorType.Motor
		rotator.MotorMaxTorque = math.huge
		rotator.MotorMaxAcceleration = maxRadPerSec / (spoolTime > 0 and spoolTime or 0.01)
		rotator.AngularVelocity = maxRadPerSec * spoolState
	end

	local rotatorWeld:Weld = grip:FindFirstChild("RotatorWeld")
	if rotatorWeld then
		local deltaRad = math.rad((maxDegPerSec * spoolState) * dt)
		rotatorWeld.C1 = rotatorWeld.C1 * CFrame.Angles(deltaRad, 0, 0)
	end
	
	local spoolUp_Sound:Sound = grip:FindFirstChild("SpoolUp")
	local spoolDw_Sound:Sound = grip:FindFirstChild("SpoolDown")
	local spoolR_Sound:Sound = grip:FindFirstChild("SpoolReady")
	
	if spoolUp_Sound then
		local play = spoolState>0.1 and spoolState<0.9 and oldSpool<spoolState
		if play and not spoolUp_Sound.Playing then
			spoolUp_Sound:Play()
			spoolDw_Sound:Stop()
		elseif not play and spoolUp_Sound.Playing then
			spoolUp_Sound:Stop()
		end
	end
	
	if spoolDw_Sound then
		local play = spoolState>0.1 and spoolState<0.9 and oldSpool>spoolState
		if play and not spoolDw_Sound.Playing then
			spoolDw_Sound:Play()
			spoolUp_Sound:Stop()
		elseif not play and spoolDw_Sound.Playing then
			spoolDw_Sound:Stop()
		end
	end
	
	if spoolR_Sound then
		local play = spoolState==1
		if play and not spoolR_Sound.Playing then
			spoolR_Sound:Play()
			spoolUp_Sound:Stop()
			spoolDw_Sound:Stop()
		elseif not play and spoolR_Sound.Playing then
			spoolR_Sound:Stop()
		end
	end

	grip:SetAttribute("Cannon_SpoolState", spoolState)
	--[[
	local angleStep = grip:GetAttribute("Cannon_RotationStep") or 60
	local targetVelocity = math.rad((firerate/60) * angleStep) 
	local targetVelocity2 = math.rad((firerate/60) * angleStep * dt)
	
	local rotator:HingeConstraint = grip:FindFirstChild("Rotator")
	if rotator then
		if vehicle:GetAttribute("internal_holdingLMB") == true and grip:GetAttribute("Muzzle_FiringOrder")==weapon:GetAttribute("internal_MuzzleCycle") then
			rotator.AngularVelocity = targetVelocity
		else
			rotator.AngularVelocity = 0
		end
	end
	
	local rotatorWeld:Weld = grip:FindFirstChild("RotatorWeld")
	if rotatorWeld and rotator then
		local firing = vehicle:GetAttribute("internal_holdingLMB") == true and grip:GetAttribute("Muzzle_FiringOrder")==weapon:GetAttribute("internal_MuzzleCycle")
		local targetRotation = rotatorWeld.C1 * CFrame.Angles(targetVelocity2, 0, 0)
	
		--weld.C1 = weld.C1 * CFrame.Angles(0, 0, deltaRad)
		rotatorWeld.C1 = rotatorWeld.C1:Lerp(targetRotation, math.min(targetVelocity2, 1))
	end
	--]]
end

local function IsTargetInFov(fov, cameraCFrame:CFrame, targetPosition:Vector3, fovPadding)
	fovPadding = fovPadding or 0

	-- Get camera position and forward direction
	local cameraPosition = cameraCFrame.Position
	local cameraForward = cameraCFrame.LookVector

	-- Calculate direction to target
	local toTarget = (targetPosition - cameraPosition).Unit

	-- Calculate angle between camera forward and target direction
	local dotProduct = cameraForward:Dot(toTarget)
	local angle = math.deg(math.acos(dotProduct))

	-- Check if angle is within FOV (with optional padding)
	return angle <= (fov/2) + fovPadding
end

local function TargetAngleUpdate(weapon, shellVelocity)
	local indirectFire = weapon:GetAttribute("internal_IndirectFire")
	local curZero = weapon:GetAttribute("internal_Zero") or 0
	local curVehDeg = weapon:GetAttribute("internal_VehAngle")

	local tgtAngle, tgtAngle2 = bcalc.FindAngleToShootAt(curZero, shellVelocity, workspace.Gravity, curVehDeg)
	local trueAngle = (indirectFire and tgtAngle2) or (not indirectFire and tgtAngle)
	weapon:SetAttribute("internal_TgtAngle", trueAngle - curVehDeg-0.1)
end

local function LookVectorToDegrees(lookVector)
	return math.deg(math.asin(lookVector.Y)) -- Assuming you want the angle relative to the positive X-axis
end

--// Core Functions
function module.InputBegan(inputObj:InputObject, weaponActive, vehicle, weapon, gun, wpnConfig, guiw)
	if table.find(wpnConfig.WeaponCodeFiring, weaponActive)==nil then return end

	local curZero = weapon:GetAttribute("internal_Zero") or 0
	local canZero = wpnConfig.CanZero and not wpnConfig.BallisticCalculator and not config.CalculatedAim
	local autoZero = wpnConfig.CanZero and wpnConfig.BallisticCalculator and not config.CalculatedAim
	local step = wpnConfig.ZeroingStep or 100
	local maxStep = wpnConfig.RangefinderMax or 4000

	if inputObj.KeyCode == Enum.KeyCode.R then
		local reloading = weapon:GetAttribute("internal_Reloading")
		local gunAmmo = weapon:GetAttribute("clipAmmo")
		local storedAmmo = weapon:GetAttribute("storedAmmo")
	
		--Manual reload
		if storedAmmo>0 and gunAmmo<wpnConfig.ClipSize and not reloading and not vehicle:GetAttribute("internal_holdingLMB") then
			playerReload:Fire(vehicle, weapon, gun)
			vehicle:SetAttribute("internal_holdingLMB", false)
			return 
		end
	elseif inputObj.KeyCode == Enum.KeyCode.V or inputObj.KeyCode==Enum.KeyCode.ButtonB then
		guiw.Parent.View0.Switch2:Play()
		repeat
			weapon:SetAttribute("internal_Firemode", weapon:GetAttribute("internal_Firemode")+1)
			if  weapon:GetAttribute("internal_Firemode") > 4 then weapon:SetAttribute("internal_Firemode", 0) break end
		until wpnConfig.Firemodes[weapon:GetAttribute("internal_Firemode")]
		attSet:Fire(weapon, "internal_Firemode", weapon:GetAttribute("internal_Firemode"))
	elseif wpnConfig.RangefinderAllowed and inputObj.KeyCode==Enum.KeyCode.B then
		local newZero = weapon:GetAttribute("internal_AimDist")/3.5
		weapon:SetAttribute("internal_Range", newZero)
		guiw.Parent.View0.Switch3:Play()

		TargetAngleUpdate(weapon, wpnConfig.ShellVelocity*3.5)
	elseif wpnConfig.IndirectSwitch and inputObj.KeyCode==Enum.KeyCode.M then
		local indirect = weapon:GetAttribute("internal_IndirectFire")
		weapon:SetAttribute("internal_IndirectFire", not indirect)
		guiw.Parent.View0.Switch2:Play()

		TargetAngleUpdate(weapon, wpnConfig.ShellVelocity*3.5)
	elseif autoZero and inputObj.KeyCode==Enum.KeyCode.RightBracket then
		local newZero = weapon:GetAttribute("internal_Range")
		weapon:SetAttribute("internal_Zero", newZero)
		guiw.Parent.View0.Switch3:Play()

		TargetAngleUpdate(weapon, wpnConfig.ShellVelocity*3.5)
	elseif autoZero and inputObj.KeyCode==Enum.KeyCode.LeftBracket then
		weapon:SetAttribute("internal_Zero", 0)
		guiw.Parent.View0.Switch3:Play()

		TargetAngleUpdate(weapon, wpnConfig.ShellVelocity*3.5)
	elseif inputObj.KeyCode == Enum.KeyCode.RightBracket and canZero  then
		local newZero = math.clamp(curZero+step, 0, maxStep)
		weapon:SetAttribute("internal_Zero", newZero)
		guiw.Parent.View0.Switch3:Play()

		TargetAngleUpdate(weapon, wpnConfig.ShellVelocity*3.5)
	elseif inputObj.KeyCode == Enum.KeyCode.LeftBracket and canZero  then
		local newZero = math.clamp(curZero-step, 0, maxStep)
		weapon:SetAttribute("internal_Zero", newZero)
		guiw.Parent.View0.Switch3:Play()

		TargetAngleUpdate(weapon, wpnConfig.ShellVelocity*3.5)
	end
end

function module.LoadGun(weaponObj:Folder)
	local wepStats = require(weaponObj:FindFirstChildWhichIsA("ModuleScript"))

	local attributes = {
		["internal_Reloading"] = false,
		["internal_ReloadStart"] = 0,
		["internal_Cycled"] = true,
		["internal_CycleStart"] = 0,
		["internal_Chambered"] = true,
		["internal_Firemode"] = wepStats.Firemode or 0,
		["internal_BulletsFired"] = 0,
		["internal_MuzzleCycle"] = 1,
		["internal_MuzzleMax"] = 1,
		["internal_TgtAngle"] = 0,
		["internal_CurAngle"] = 0,
		["internal_Zero"] = 0,
		["internal_Range"] = 0,
		["internal_AimDist"] = 0,
		["internal_VehAngle"] = 0,
		["internal_Infrared"] = false,
		["internal_NightVis"] = false,
	}

	--Get muzzles
	local highestPriority = 1
	for each, grip:BasePart in pairs(weaponObj.Gun:GetChildren()) do
		if grip.Name~="Grip" then continue end

		local priority = grip:GetAttribute("Muzzle_FiringOrder") or 1
		if priority>highestPriority then highestPriority=priority end
	end
	attributes.internal_MuzzleMax = highestPriority

	--Replicate attributes
	for key, value in pairs(attributes) do
		local existing = weaponObj:GetAttribute(key)
		if existing~=nil then continue end
		attSet:Fire(weaponObj, key, value, script)
		--weaponObj:SetAttribute(key, value)
	end

	weaponObj:GetAttributeChangedSignal("internal_Reloading"):Connect(function()
		local reloading = weaponObj:GetAttribute("internal_Reloading")
		if reloading then
			weaponObj:SetAttribute("internal_ReloadStart", os.clock())
		end
	end)

	weaponObj:GetAttributeChangedSignal("internal_Cycled"):Connect(function()
		--local cycled = weaponObj:GetAttribute("internal_Cycled")
		--if cycled then
		weaponObj:SetAttribute("internal_CycleStart", os.clock())
		--end
	end)
end

function module.RenderLoop(dt, weaponActive, vehicle, weapon, gun, turret, wpnConfig, wpnGui, cameraMode, mouseDelta) --Runs on renderstepped
	local aimPos

	if table.find(wpnConfig.WeaponCodeAiming, weaponActive)~=nil then --Aiming
		local ignoreList = {game.Workspace.DTS_Workspace.Temp, game.Workspace.DTS_Workspace.Cache, vehicle, weapon, player.Character} -- WHY? --why what??
		local rangeMax = (wpnConfig.RangefinderAllowed and wpnConfig.RangefinderMax) or 1000
		local aimDist = 0
		local aimCFrame
		aimingParams.FilterDescendantsInstances = ignoreList

		--Get muzzle position
		local muzzleMax = weapon:GetAttribute("internal_MuzzleMax")
		local muzzleAlt:Attachment = gun.GJointTop:FindFirstChild("MuzzleDirection")
		local muzzleCframe
		if muzzleMax<=1 then
			muzzleCframe = gun.Grip.CFrame
		elseif muzzleAlt then
			muzzleCframe = muzzleAlt.WorldCFrame
		else
			muzzleCframe = gun.GJointTop.CFrame
		end

		--Raycasts
		local targetObj:ObjectValue = player:FindFirstChild("Target_Obj") and player.Target_Obj.Value
		local targetPos = (player:FindFirstChild("Target_Pos") and player.Target_Pos.Value~=Vector3.zero and player.Target_Pos.Value) or (targetObj and targetObj:GetPivot().Position)
		local inFov = targetPos and IsTargetInFov(wpnConfig.AutoTargetFOV or 20, playerCam.CFrame, targetPos, 10)

		if (wpnConfig.AutoTargetObj or wpnConfig.AutoTargetPos) and targetPos and targetPos~=Vector3.zero and inFov then
			local dir = (muzzleCframe.Position - targetPos)

			aimCFrame = CFrame.lookAlong(targetPos, dir)
			aimPos = aimCFrame.Position
			aimDist = dir.Magnitude
		elseif wpnConfig.AimWithMouse or config.AimWithMouse then
			--Aim at the mouse
			local mouseXY = userInput:GetMouseLocation()
			local mouseRay:Ray = playerCam:ViewportPointToRay(mouseXY.X, mouseXY.Y, 0)

			local aimingCast = workspace:Raycast(mouseRay.Origin, mouseRay.Direction*rangeMax, aimingParams)
			if aimingCast then
				aimCFrame = CFrame.lookAlong(aimingCast.Position, mouseRay.Direction)
				aimPos = aimingCast.Position
				aimDist = aimingCast.Distance
			else
				aimCFrame = CFrame.new(mouseRay.Origin + mouseRay.Direction*rangeMax)
				aimPos = aimCFrame.Position
				aimDist = rangeMax*2
			end

		else
			--Aim at the center of the screen
			local camXY = playerCam.ViewportSize/2
			local camRay:Ray = playerCam:ViewportPointToRay(camXY.X, camXY.Y, 0)

			local aimingCast = workspace:Raycast(camRay.Origin, camRay.Direction*rangeMax, aimingParams)
			if aimingCast then
				aimCFrame = CFrame.lookAlong(aimingCast.Position, camRay.Direction)
				aimPos = aimingCast.Position
				aimDist = aimingCast.Distance
			else
				aimCFrame = CFrame.new(camRay.Origin + camRay.Direction*rangeMax)
				aimPos = aimCFrame.Position
				aimDist = rangeMax*2
			end
		end
		weapon:SetAttribute("internal_AimDist", aimDist)

		local cannonCast = workspace:Raycast(muzzleCframe.Position, muzzleCframe.LookVector*1000, aimingParams)
		local cannonPos
		if cannonCast then
			cannonPos = cannonCast.Position
		else
			cannonPos = CFrame.new(muzzleCframe.Position + muzzleCframe.LookVector*aimDist).Position
		end

		--Automatic ballistic calculator
		if (wpnConfig.AutoTargetObj or wpnConfig.AutoTargetPos) and targetPos then
			if inFov then
				weapon:SetAttribute("internal_Range", aimDist/3.5)

				if weapon:GetAttribute("internal_Zero")~= 0 then
					weapon:SetAttribute("internal_Zero", aimDist/3.5)
				end
				autoTargetUpdate = true
			elseif not inFov and autoTargetUpdate then
				autoTargetUpdate = false
				weapon:SetAttribute("internal_Zero", 0)
			end

		elseif not wpnConfig.RangefinderAllowed and (wpnConfig.BallisticCalculator or config.CalculatedAim) then
			weapon:SetAttribute("internal_Range", aimDist/3.5)

			if weapon:GetAttribute("internal_Zero")~= 0 then
				weapon:SetAttribute("internal_Zero", aimDist/3.5)
			end
		end

		--weapon, wpnGui, inGunsights, targetPos, cannonPos, muzzleCFrame, camCFrame, targetDist, mouseDelta, dt)
		hudMod.UpdateSights(weapon, wpnGui, cameraMode>=1, aimPos, cannonPos, muzzleCframe, playerCam:GetRenderCFrame(), weapon:GetAttribute("internal_Range")*3.5, mouseDelta, dt, wpnConfig)
	else
		--Automatic ballistic calculator
		if wpnConfig.BallisticCalculator or config.CalculatedAim then
			weapon:SetAttribute("internal_Zero", 0)
		end

		aimPos = nil
	end

	if weaponActive==wpnConfig.WeaponCode and wpnGui then --Firing --table.find(wpnConfig.WeaponCodeFiring, weaponActive)~=nil
		wpnGui.Visible=true
	else --Not aiming
		wpnGui.Visible=false
	end

	--Set target angle for current zero
	local OldVDeg = weapon:GetAttribute("internal_VehAngle") or 0
	local NewVDeg = math.deg(math.asin(turret.GJointBase.CFrame.LookVector.Y))

	if math.abs(NewVDeg - OldVDeg) > 0.07 then
		local curZero = weapon:GetAttribute("internal_Zero") or 0
		local indirectFire = weapon:GetAttribute("internal_IndirectFire")

		local tgtAngle, tgtAngle2 = bcalc.FindAngleToShootAt(curZero, wpnConfig.ShellVelocity*3.5, workspace.Gravity, NewVDeg)
		local trueAngle = (indirectFire and tgtAngle2) or (not indirectFire and tgtAngle)

		weapon:SetAttribute("internal_TgtAngle", trueAngle - NewVDeg-0.1)
	end

	return aimPos
end

function module.RunLoop(dt, weaponActive, vehicle, weapon, gun, wpnConfig, wpnGui, camShake) --Runs on heartbeat
	if table.find(wpnConfig.WeaponCodeFiring, weaponActive)==nil then return end

	--// Firing preparations, autoreload and cycle time
	local reloading = weapon:GetAttribute("internal_Reloading")
	local chamber = weapon:GetAttribute("internal_Chambered")
	local cycled = weapon:GetAttribute("internal_Cycled")
	local cycleStart = weapon:GetAttribute("internal_CycleStart")
	local firemode = weapon:GetAttribute("internal_Firemode")
	local bulletsFired = weapon:GetAttribute("internal_BulletsFired")
	local muzzleSelected = weapon:GetAttribute("internal_MuzzleCycle")
	local muzzleMax = weapon:GetAttribute("internal_MuzzleMax")
	local gunAmmo = weapon:GetAttribute("clipAmmo")
	local currentTime = os.clock()
	local spoolTime = wpnConfig.SpoolUpTime or wpnConfig.Firerate/60/16 --seconds to full speed
	local momentum = wpnConfig.SpoolDownTime or wpnConfig.Firerate/60/12  --seconds to spin down

	--Spool up or down
	if wpnConfig.SpoolUpTime and vehicle:GetAttribute("internal_holdingLMB") then
		spoolTimer = math.clamp(spoolTimer + dt, 0, spoolTime)
	elseif wpnConfig.SpoolUpTime then
		spoolTimer = math.clamp(spoolTimer - dt * (spoolTime/momentum), 0, spoolTime)
	end

	--Firerate adjustment
	local cycleTime = (firemode==fireModes.Burst and wpnConfig.BurstFirerate) or wpnConfig.Firerate
	local spoolReady = (wpnConfig.SpoolUpTime~=nil and spoolTimer/spoolTime>0.9) or wpnConfig.SpoolUpTime==nil

	--Autoreload
	if gunAmmo<=0 and not reloading and not chamber and vehicle:GetAttribute("internal_holdingLMB") and wpnConfig.Autoreload~=false then
		playerReload:Fire(vehicle, weapon, gun)
		vehicle:SetAttribute("internal_holdingLMB", false)
		return 
	end

	--Autocycle
	if not cycled then
		local elapsed = currentTime - cycleStart
		--print(elapsed, cycleTime)
		if elapsed>=cycleTime then --math.clamp(elapsed/cycleTime, 0, 1) >=1
			weapon:SetAttribute("internal_Cycled", true)
			cycled = true
		end
	end
	--[[
	duration, began) --wpnConfig.ReloadTime, weapon:GetAttribute("internal_ReloadStart")
	local currentTime = os.clock()
	local elapsed = currentTime - began
	local progress = math.clamp(elapsed/duration, 0, 1)
	local isReloading = progress < 1
	--]]

	--// Firing Code
	if not reloading and chamber and cycled and spoolReady and vehicle:GetAttribute("internal_holdingLMB") and firemode~=fireModes.Safe and gunAmmo>0 then
		local firingMuzzles = ChooseMuzzle(muzzleSelected, gun)
		for each, muzzleObj in firingMuzzles do
			weapon:SetAttribute("internal_BulletsFired", bulletsFired+1)
			fastCastClient:Fire("FireFX", player, player, muzzleObj, 10)
			--module.FireFX(player, muzzleObj, 10)
		end

		--Firemode action
		if firemode == fireModes.Semi or firemode == fireModes.Manual or (firemode == fireModes.Burst and weapon:GetAttribute("internal_BulletsFired") >= wpnConfig.BurstSize) then
			vehicle:SetAttribute("internal_holdingLMB", false)
		end
		weapon:SetAttribute("internal_Cycled", false)

		--Firing action
		for each, muzzleObj in firingMuzzles do
			local shotCount = wpnConfig.ShellAmount
			repeat
				shotCount -= 1
				local bulletOrigin
				local bulletDirection
				local spreadCFrame = CFrame.Angles(math.rad(math.random(-wpnConfig.ShellSpread[1],wpnConfig.ShellSpread[2])), math.rad(math.random(-wpnConfig.ShellSpread[1],wpnConfig.ShellSpread[2])), 0)

				local muzzle = muzzleObj.Muzzle
				bulletOrigin = muzzle.WorldCFrame.Position
				bulletDirection = (muzzle.WorldCFrame * spreadCFrame).LookVector

				local newX = math.rad(LookVectorToDegrees(bulletDirection)+45)
				local newDirection = Vector3.new(bulletDirection.X,newX,bulletDirection.Z).Unit

				local bulletVelocity = (bulletDirection * wpnConfig.ShellVelocity * 3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)
				local tracerColor = wpnConfig.ShellTracerColor or Color3.fromRGB(255, 235, 135)

				fastCastClient:Fire("FireBullet", player, vehicle, weapon, bulletOrigin, newDirection, bulletVelocity, player, tracerColor, nil, muzzleObj)
				--module.FireBullet(vehicle, weapon, bulletOrigin, newDirection, bulletVelocity, player, tracerColor, nil, muzzleObj, camShake)
			until shotCount <= 0

			playerFire:Fire(muzzleObj.Muzzle.WorldCFrame, vehicle, weapon, muzzleObj)
		end

		--Muzzle cycle
		if muzzleSelected < muzzleMax then
			weapon:SetAttribute("internal_MuzzleCycle", muzzleSelected + 1)
		elseif muzzleSelected >= muzzleMax then
			weapon:SetAttribute("internal_MuzzleCycle", 1)
		end

		task.wait(60/cycleTime)
		weapon:SetAttribute("internal_Cycled", true)
	end

	--Visual effects
	local firingMuzzles, allMuzzles = ChooseMuzzle(weapon:GetAttribute("internal_MuzzleCycle"), gun)
	for each, muzzleObj in allMuzzles do
		ConstraintUpdate(muzzleObj, wpnConfig.Firerate, weapon, vehicle, dt, spoolTime, momentum)
	end
end

return module