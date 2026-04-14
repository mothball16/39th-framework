--[[       
DRAGOON TANK SYSTEM
Launcher weapon module
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
local events = assets.Events
local modules = assets.Modules
local wmodules = assets.Weapons
local amodules = assets.Addons
local projectiles = assets.Projectiles


local hudMod = require(modules.HUDModule)
local cameraShakeInstance = require(modules.CameraShaker.CameraShakeInstance)
local hitFX = require(modules.HitFX)
local config = require(assets.GlobalSettings)

local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets") --Spearhead compat
local bridgeNet
if sphInstall then 
	bridgeNet = require(sphInstall.Modules.Network.BridgeNet)
else  
	bridgeNet = require(modules.BridgeNet) 
end

--// Events
local attSet = bridgeNet.CreateBridge("attributeSet") -- Client > Server 
local gunEvent = bridgeNet.CreateBridge("WeaponEvent")
local playerReload = bridgeNet.CreateBridge("PlayerReload2")
local forceReload = assets.Events.ReloadEvent

local workspaceFolder = game.Workspace.DTS_Workspace
local bulletContainer = workspaceFolder.Temp

local player = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

local aimingParams = RaycastParams.new()
aimingParams.FilterType = Enum.RaycastFilterType.Exclude
aimingParams.IgnoreWater = true

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

local function ConstraintUpdate(grip, firerate, weapon, vehicle)
	local Rotator:HingeConstraint = grip:FindFirstChild("Rotator")
	if Rotator then
		if vehicle:GetAttribute("internal_holdingLMB") == true and grip:GetAttribute("Muzzle_FiringOrder")==weapon:GetAttribute("internal_MuzzleCycle") then
			local angleStep = grip:GetAttribute("Cannon_RotationStep")
			local targetVelocity = math.rad((firerate/60) * angleStep)
			Rotator.AngularVelocity = targetVelocity
		else
			Rotator.AngularVelocity = 0
		end
	end
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

local function LookVectorToDegrees(lookVector)
	return math.deg(math.asin(lookVector.Y)) -- Assuming you want the angle relative to the positive X-axis
end

function module.FireFX(playerFired:Player, grip, muzzleChance)
	local humanoidRootPart = playerFired.Character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and player:DistanceFromCharacter(humanoidRootPart.Position) <= config.fireEffectDistance then

		--Fire sound
		for _, child in ipairs(grip:GetChildren()) do
			if child:IsA("Sound") and (child.Name == "Fire" or (child.Name == "Echo" and (config.firstPersonEcho or playerFired ~= player))) then
				if not child.Looped then
					local newFire = child:Clone()
					newFire.PlaybackSpeed += math.random(-10,10) / config.fireSoundVariation
					newFire.Name = newFire.Name.."_Playing"
					newFire.Parent = grip.Muzzle
					newFire:Play()
					debris:AddItem(newFire,newFire.TimeLength == 0 and 5 or newFire.TimeLength)
				else
					child:Play()
				end
			end
		end

		--Fire effect
		local muzzleChance = math.random(10) <= muzzleChance
		for _, fx in ipairs(grip.Muzzle:GetChildren()) do
			if fx:IsA("ParticleEmitter") then
				if fx:FindFirstChild("Particles") then
					local canEmit = false
					if string.find(fx.Name,"Flash") then
						if muzzleChance then
							canEmit = true
						end
					else
						canEmit = true
					end
					if canEmit then
						fx:Emit(fx.Particles.Value)
					end
				elseif fx.Name == "Smoke" then
					fx:Emit(10)
				elseif fx.Name == "Flash" and muzzleChance then
					fx:Emit(5)
				end
			elseif fx:IsA("Light") and muzzleChance then
				fx.Enabled = true
				task.delay(0.01,function() fx.Enabled = false end)
			end
		end

		-- Other effects
		local chamber:Attachment = grip:FindFirstChild("Chamber")
		if chamber then
			local casings:ParticleEmitter = chamber:FindFirstChild("Casings")
			if casings then
				casings:Emit(1)
			end
		end
	end
end

function module.ModelSpawn(player:Player, vehicle:Model, weaponObj:Model, bulletOrigin:CFrame, bulletDirection:Vector3, bulletVelocity:number, playerFired, tracerColor, fake, grip:BasePart)
	if not weaponObj then return end
	local wepStats = require(weaponObj:FindFirstChildWhichIsA("ModuleScript"))

	local newModel = wepStats.ShellModel
	local magAmmo = weaponObj:GetAttribute("clipAmmo")
	local reloading = weaponObj:GetAttribute("internal_Reloading")
	local chamber = weaponObj:GetAttribute("internal_Chambered")

	--Actual fire
	local firingModel = assets.Projectiles:FindFirstChild(newModel)
	if not firingModel then return end

	local newFired:Model = firingModel:Clone()
	newFired.Parent = bulletContainer
	newFired:PivotTo(bulletOrigin)

	local forward = grip.Muzzle.WorldCFrame.LookVector

	local desiredVelocity = grip.AssemblyLinearVelocity+forward + bulletVelocity
	local deltaV = desiredVelocity - newFired.PrimaryPart.AssemblyLinearVelocity
	local impulse = deltaV * newFired.PrimaryPart.AssemblyMass

	newFired.PrimaryPart:ApplyImpulse(impulse)
	
	local flybySound = newFired.Mass:FindFirstChild("FlyBy")
	if flybySound then
		flybySound:Play()
	end

	local newOrigin:Vector3Value = Instance.new("Vector3Value")
	newOrigin.Name = "Origin"
	newOrigin.Value = bulletOrigin.Position
	newOrigin.Parent = newFired

	local newPlrTag:ObjectValue = Instance.new("ObjectValue")
	newPlrTag.Name = "Creator"
	newPlrTag.Value = player
	newPlrTag.Parent = newFired

	local explScript = newFired:FindFirstChild("ExplodeScript")
	if explScript then explScript.Enabled =true end

	--Firing effects
	if wepStats.RecoilForce then
		local tempAtt = Instance.new("Attachment")
		tempAtt.Parent = grip
		tempAtt.CFrame = grip.Muzzle.CFrame
		local force = Instance.new("VectorForce")
		force.Parent = tempAtt
		force.Attachment0 = tempAtt
		force.Force = Vector3.new(0,0, wepStats.RecoilForce)
		debris:AddItem(tempAtt,0.1)
	end

	-- Proceed with firing logic
	if chamber and not reloading then
		weaponObj:SetAttribute("internal_Chambered", false)
		if magAmmo > 0 then
			weaponObj:SetAttribute("clipAmmo", magAmmo-1)
			magAmmo = weaponObj:GetAttribute("clipAmmo")

			if magAmmo <= 0 then --fired the last bullet, now we have to reload
				forceReload:Fire(player, vehicle, weaponObj, grip)
			else
				weaponObj:SetAttribute("internal_Chambered", true)
			end
		end
	end
end

--// Core Functions
function module.InputBegan(inputObj:InputObject, weaponActive, vehicle, weapon, gun, wpnConfig, guiw)
	if table.find(wpnConfig.WeaponCodeFiring, weaponActive)==nil then return end

	if inputObj.KeyCode == Enum.KeyCode.V or inputObj.KeyCode==Enum.KeyCode.ButtonB then
		guiw.Parent.View0.Switch2:Play()
		repeat
			weapon:SetAttribute("internal_Firemode", weapon:GetAttribute("internal_Firemode")+1)
			if  weapon:GetAttribute("internal_Firemode") > 4 then weapon:SetAttribute("internal_Firemode", 0) break end
		until wpnConfig.Firemodes[weapon:GetAttribute("internal_Firemode")]
		attSet:Fire(weapon, "internal_Firemode", weapon:GetAttribute("internal_Firemode"))
	end
end

function module.LoadGun(weaponObj:Folder)
	local wepStats = require(weaponObj:FindFirstChildWhichIsA("ModuleScript"))

	local attributes = {
		["internal_Reloading"] = false,
		["internal_ReloadStart"] = 0,
		["internal_Cycled"] = true,
		["internal_Chambered"] = true,
		["internal_Firemode"] = wepStats.Firemode or 0,
		["internal_BulletsFired"] = 0,
		["internal_MuzzleCycle"] = 1,
		["internal_MuzzleMax"] = 1,
		["internal_TgtAngle"] = 0,
		["internal_CurAngle"] = 0,
		["internal_Zero"] = 0,
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
end

function module.RenderLoop(dt, weaponActive, vehicle, weapon, gun, turret, wpnConfig, wpnGui, cameraMode, mouseDelta) --Runs on renderstepped
	local aimPos

	if table.find(wpnConfig.WeaponCodeAiming, weaponActive)~=nil then --Aiming
		local ignoreList = {game.Workspace.DTS_Workspace.Temp, game.Workspace.DTS_Workspace.Cache, vehicle, weapon, player.Character} -- WHY? why what??
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
		local targetPos = (targetObj and targetObj:GetPivot().Position) or (player:FindFirstChild("Target_Pos") and player.Target_Pos.Value)
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
		if wpnConfig.AutoTargetObj or wpnConfig.AutoTargetPos then
			weapon:SetAttribute("internal_Range", aimDist/3.5)

			if weapon:GetAttribute("internal_Zero")~= 0 then
				weapon:SetAttribute("internal_Zero", aimDist/3.5)
			end
		elseif not wpnConfig.RangefinderAllowed and (wpnConfig.BallisticCalculator or config.CalculatedAim) then
			weapon:SetAttribute("internal_Range", aimDist/3.5)

			if weapon:GetAttribute("internal_Zero")~= 0 then
				weapon:SetAttribute("internal_Zero", aimDist/3.5)
			end
		end
		
		--weapon, wpnGui, inGunsights, targetPos, cannonPos, muzzleCFrame, camCFrame, targetDist, mouseDelta, dt)
		hudMod.UpdateSights(weapon, wpnGui, cameraMode>=1, aimPos, cannonPos, muzzleCframe, playerCam:GetRenderCFrame(), aimDist, mouseDelta, dt, wpnConfig)
	else
		--Automatic ballistic calculator
		if wpnConfig.BallisticCalculator or config.CalculatedAim then
			weapon:SetAttribute("internal_Zero", 0)
		end

		aimPos = nil
	end

	if table.find(wpnConfig.WeaponCodeFiring, weaponActive)~=nil then --Firing
		wpnGui.Visible=true
	else --Not aiming
		wpnGui.Visible=false
	end

	return aimPos
end

function module.RunLoop(dt, weaponActive, vehicle, weapon, gun, wpnConfig, wpnGui, camShake) --Runs on heartbeat
	if table.find(wpnConfig.WeaponCodeFiring, weaponActive)==nil then return end

	--// Firing code
	local reloading = weapon:GetAttribute("internal_Reloading")
	local chamber = weapon:GetAttribute("internal_Chambered")
	local cycled = weapon:GetAttribute("internal_Cycled")
	local firemode = weapon:GetAttribute("internal_Firemode")
	local bulletsFired = weapon:GetAttribute("internal_BulletsFired")
	local muzzleSelected = weapon:GetAttribute("internal_MuzzleCycle")
	local muzzleMax = weapon:GetAttribute("internal_MuzzleMax")
	local gunAmmo = weapon:GetAttribute("clipAmmo")

	if gunAmmo<=0 and not reloading and not chamber and vehicle:GetAttribute("internal_holdingLMB") then
		playerReload:Fire(vehicle, weapon, gun)
		vehicle:SetAttribute("internal_holdingLMB", false)
		return 
	end

	if not reloading and chamber and cycled and vehicle:GetAttribute("internal_holdingLMB") and firemode~=fireModes.Safe and gunAmmo>0 then
		local firingMuzzles = ChooseMuzzle(muzzleSelected, gun)
		for each, muzzleObj in firingMuzzles do
			weapon:SetAttribute("internal_BulletsFired", bulletsFired+1)
			module.FireFX(player, muzzleObj, 10)
		end

		--Firemode action
		if firemode == fireModes.Semi or firemode == fireModes.Manual or (firemode == fireModes.Burst and weapon:GetAttribute("internal_BulletsFired") >= wpnConfig.BurstSize) then
			vehicle:SetAttribute("internal_holdingLMB", false)
		end
		weapon:SetAttribute("internal_Cycled", false)

		--Firing action
		for each, muzzleObj in firingMuzzles do
			-- Fire bullet
			local shotCount = wpnConfig.ShellAmount
			repeat
				shotCount -= 1
				local bulletOrigin
				local bulletDirection
				local spreadCFrame = CFrame.Angles(math.rad(math.random(-wpnConfig.ShellSpread[1],wpnConfig.ShellSpread[2])), math.rad(math.random(-wpnConfig.ShellSpread[1],wpnConfig.ShellSpread[2])), 0)

				local muzzle = muzzleObj.Muzzle
				bulletOrigin = muzzle.WorldCFrame * spreadCFrame
				bulletDirection = bulletOrigin.LookVector

				local newX = math.rad(LookVectorToDegrees(bulletDirection)+45)
				local newDirection = Vector3.new(bulletDirection.X,newX,bulletDirection.Z).Unit

				local bulletVelocity = (bulletDirection * wpnConfig.ShellVelocity * 3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)
				local tracerColor = wpnConfig.ShellTracerColor or Color3.fromRGB(255, 235, 135)

				--vehicle, data, bulletOrigin, bulletDirection, bulletVelocity, playerFired, tracerColor, fake, muzzle
				--ModelSpawn(player:Player, vehicle:Model, weaponObj:Model, bulletOrigin:Vector3, bulletDirection:Vector3, bulletVelocity:number, playerFired, tracerColor, fake, grip)
				gunEvent:Fire(script.Name, "ModelSpawn", player, vehicle, weapon, bulletOrigin, newDirection, bulletVelocity, player, tracerColor, nil, muzzleObj)
				--player:Player, module, func, ...
				--module.FireBullet(vehicle, weapon, bulletOrigin, newDirection, bulletVelocity, player, tracerColor, nil, muzzleObj, camShake)
				
				if config.cameraShake and camShake then
					--Camera shake
					local firemode = weapon:GetAttribute("internal_Firemode")
					local cycleTime = (firemode~="Burst" and wpnConfig.Firerate) or (firemode=="Burst" and wpnConfig.BurstFirerate)
					local c = cameraShakeInstance.new(wpnConfig.CameraShake or 0.5, 4, 0, 60/cycleTime) --magnitude, roughness, fadeInTime, fadeOutTime
					c.PositionInfluence = Vector3.new(0.25, 0.25, 0.25)
					c.RotationInfluence = Vector3.new(2, 1, 1)
					camShake:Shake(c)
				end
				
			until shotCount <= 0
		end

		--Muzzle cycle
		if muzzleSelected < muzzleMax then
			weapon:SetAttribute("internal_MuzzleCycle", muzzleSelected + 1)
		elseif muzzleSelected >= muzzleMax then
			weapon:SetAttribute("internal_MuzzleCycle", 1)
		end

		local cycleTime = wpnConfig.Firerate
		if firemode == fireModes.Burst and wpnConfig.BurstFirerate then
			cycleTime = wpnConfig.BurstFirerate
		end

		task.wait(60 / cycleTime)
		weapon:SetAttribute("internal_Cycled", true)
	end


	--Visual effects
	local firingMuzzles, allMuzzles = ChooseMuzzle(weapon:GetAttribute("internal_MuzzleCycle"), gun)
	for each, muzzleObj in allMuzzles do
		ConstraintUpdate(muzzleObj, wpnConfig.Firerate, weapon, vehicle)
	end
end

return module