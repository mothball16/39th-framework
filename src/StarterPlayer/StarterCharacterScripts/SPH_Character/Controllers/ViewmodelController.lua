local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local modules = assets.Modules
local springMod = require(modules.SpringModule)
local State = require(script.Parent.CharacterState)
local WeaponState = require(script.Parent.WeaponState)
local Enums = require(script.Parent.Parent.Enums)

local ViewmodelController = {}

ViewmodelController.swaySpring = springMod.new()
ViewmodelController.moveSpring = springMod.new()
ViewmodelController.recoilSpring = springMod.new()
ViewmodelController.gunRecoilSpring = springMod.new()

local storageCFrame = CFrame.new(1000000, 0, 0)
local pushbackOffset = 0
local hipRotation = Vector2.zero
local aimingOffset = CFrame.new()
local proneViewmodelOffset = 0
local rollAngle = 0
local aimTarget = CFrame.new()

ViewmodelController.animBase = nil
ViewmodelController.camera = nil
ViewmodelController.humanoidRootPart = nil
ViewmodelController.weaponRig = nil
ViewmodelController.rayParams = nil

ViewmodelController.ChangeHoldStance = nil
ViewmodelController.PlayAnimation = nil
ViewmodelController.StopAnimation = nil
ViewmodelController.RefreshViewmodel = nil

local function LerpNumber(number: number, target: number, speed: number)
	return number + (target - number) * speed
end

local function GetSineOffset(addition: number)
	return math.sin(tick() * addition * 1.3) * 0.3
end

function ViewmodelController.Initialize(params)
	ViewmodelController.animBase = params.animBase
	ViewmodelController.camera = params.camera
	ViewmodelController.humanoidRootPart = params.humanoidRootPart
	ViewmodelController.weaponRig = params.weaponRig
	ViewmodelController.rayParams = params.rayParams
	
	ViewmodelController.ChangeHoldStance = params.ChangeHoldStance
	ViewmodelController.PlayAnimation = params.PlayAnimation
	ViewmodelController.StopAnimation = params.StopAnimation
	ViewmodelController.RefreshViewmodel = params.RefreshViewmodel


	Charm.subscribe(State.equippedTool, ViewmodelController.OnEquippedToolChanged)
end

function ViewmodelController.OnEquippedToolChanged(tool, oldTool)
	if not tool then return end
	ViewmodelController.ResetHipRotation()
end

function ViewmodelController.ResetHipRotation()
	hipRotation = Vector2.zero
end

function ViewmodelController.UpdateViewmodelPosition(dt, offset, sightIndex)
	local fps = 1 / dt

	local animBase = ViewmodelController.animBase
	local camera = ViewmodelController.camera
	local humanoidRootPart = ViewmodelController.humanoidRootPart
	local weaponRig = ViewmodelController.weaponRig
	local rayParams = ViewmodelController.rayParams

	animBase.CFrame = CFrame.new((camera.CFrame * offset).Position)

	if not State.freeLook() then
		animBase.CFrame *= camera.CFrame - camera.CFrame.Position
	else
		animBase.CFrame *= State.freeLookRotation()
	end

	if State.stance() == 2 then
		proneViewmodelOffset = LerpNumber(proneViewmodelOffset, 0.2, 0.1)
	else
		proneViewmodelOffset = LerpNumber(proneViewmodelOffset, 0, 0.1)
	end
	animBase.CFrame *= CFrame.new(0, proneViewmodelOffset, 0)

	local freelookRecovery = 0.2
	local newFlOffset = State.freeLookOffset():Lerp(CFrame.new(), freelookRecovery * dt * 60)
	State.freeLookOffset(newFlOffset)
	animBase.CFrame *= newFlOffset:Inverse()

	local aimPart = WeaponState.gunModel():FindFirstChild("AimPart" .. sightIndex) or WeaponState.gunModel().AimPart
	if WeaponState.attStats.aimParts then
		if WeaponState.attStats.aimParts["AimPart" .. sightIndex] then
			aimPart = WeaponState.gunModel()[WeaponState.attStats.aimParts["AimPart" .. sightIndex]]:FindFirstChild("AimPart" .. sightIndex)
		end
	end
	aimTarget = aimPart.CFrame:ToObjectSpace(camera.CFrame)

	local aimTime = WeaponState.wepStats.aimTime
	if WeaponState.attStats.aimTime then aimTime *= WeaponState.attStats.aimTime end

	if State.aiming() then
		aimingOffset = aimingOffset:Lerp(aimTarget, (0.7 / aimTime) * 0.3 * dt * 60)
	else
		aimingOffset = aimingOffset:Lerp(CFrame.new(), (0.7 / aimTime) * 0.3 * dt * 60)
	end
	animBase.CFrame *= aimingOffset

	local rayDistance = WeaponState.wepStats.gunLength
	if WeaponState.attStats.gunLength then rayDistance += WeaponState.attStats.gunLength end
	local originCFrame = State.firstPerson() and animBase.CFrame or weaponRig.AnimBase.CFrame
	local newRay = workspace:Raycast(originCFrame.Position, originCFrame.LookVector * rayDistance, rayParams)
	
	local isBlocked = WeaponState.blocked()
	if newRay then
		local distance = rayDistance - (animBase.CFrame.Position - newRay.Position).Magnitude
		if config.pushBackViewmodel and distance > 0 then
			local tempDist = distance
			if isBlocked then tempDist /= 2 end
			pushbackOffset = LerpNumber(pushbackOffset, tempDist, 0.2 * 60 * dt)
		else
			pushbackOffset = LerpNumber(pushbackOffset, 0, 0.2 * 60 * dt)
		end

		if config.raiseGunAtWall then
			if distance >= WeaponState.wepStats.maxPushback then
				if not isBlocked then
					WeaponState.holdStance(Enums.HoldStance.High)
					WeaponState.blocked(true)
					State.aiming(false)
				end
			elseif isBlocked then
				WeaponState.holdStance(Enums.HoldStance.Ready)
				WeaponState.blocked(false)
				if WeaponState.aimHeld() and State.firstPerson() then
					State.aiming(true)
				end
			end
		end
	else
		if isBlocked then
			ViewmodelController.StopAnimation(WeaponState.wepStats.holdUpAnim, 0.3)
		end
		WeaponState.blocked(false)
		if WeaponState.aimHeld() and State.firstPerson() and not State.sprinting() then
			State.aiming(true)
		end
		pushbackOffset = LerpNumber(pushbackOffset, 0, 0.2 * 60 * dt)
	end
	animBase.CFrame *= CFrame.new(0, 0, pushbackOffset)

	local relativeVelocity = humanoidRootPart.CFrame:VectorToObjectSpace(humanoidRootPart.Velocity)
	local targetRollAngle = 0
	if not State.aiming() then targetRollAngle = math.clamp(-relativeVelocity.X, -config.maxStrafeRoll, config.maxStrafeRoll) end
	if config.cameraTilting then targetRollAngle /= 2 end
	rollAngle = LerpNumber(rollAngle, targetRollAngle, 0.07 * dt * 60)
	animBase.CFrame *= CFrame.Angles(0, 0, math.rad(rollAngle))

	local viewportSize = camera.ViewportSize
	local mouseDelta = UserInputService:GetMouseDelta() / viewportSize

	local tempHipRotation = hipRotation
	if config.hipfireMove and (not State.aiming() or State.aiming() and config.offCenterAiming) then
		local maxX = config.hipfireMoveX
		local maxY = config.hipfireMoveY
		if State.aiming() then
			maxX /= 4
			maxY /= 4
		end
		local xRotation = math.clamp(tempHipRotation.X - mouseDelta.X * config.hipfireMoveSpeed * dt * 60, -maxX, maxX)
		local yRotation = math.clamp(tempHipRotation.Y - mouseDelta.Y * config.hipfireMoveSpeed * dt * 60, -maxY, maxY)
		tempHipRotation = Vector2.new(xRotation, yRotation)
		hipRotation = tempHipRotation
	else
		hipRotation = hipRotation:Lerp(Vector2.zero, 0.3)
	end
	animBase.CFrame *= CFrame.Angles(math.rad(hipRotation.Y), math.rad(hipRotation.X), 0)

	-- mouse move sway
	ViewmodelController.swaySpring:shove(Vector3.new(
		-mouseDelta.X * WeaponState.wepStats.DeltaInstability.X,
		mouseDelta.Y * WeaponState.wepStats.DeltaInstability.Y,
		0))
	local updatedSway = ViewmodelController.swaySpring:update(dt)
	animBase.CFrame *= CFrame.new(updatedSway.X, updatedSway.Y, 0)

	-- breathing sway
	local tickTime = tick() * 0.15
	local tempDist = config.breathingDist
	if State.aiming() then tempDist *= config.breathingAimMultiplier end
	animBase.CFrame *= CFrame.new(tempDist * math.sin(tickTime * config.breathingSpeed / 2), tempDist * math.sin(tickTime * config.breathingSpeed), 0)


	-- recoil impact
	local RecoilImpact = CFrame.lookAt(WeaponState.RecoilPos.p,WeaponState.RecoilDir.p,WeaponState.RecoilUp.p)
	animBase.CFrame *= RecoilImpact


	-- hide viewmodel (wtf)
	if not WeaponState.viewmodelVisible() then
		animBase.CFrame *= storageCFrame
	end
end

function ViewmodelController.UpdateRender(dt)
	local camera = ViewmodelController.camera
	if State.equippedTool() and WeaponState.gunModel() and camera.CameraType == Enum.CameraType.Custom then
		if State.firstPerson() and not WeaponState.viewmodelVisible() then
			if ViewmodelController.RefreshViewmodel then ViewmodelController.RefreshViewmodel() end
			State.sprinting(false)
		end

		local currentOffset = WeaponState.wepStats and WeaponState.wepStats.viewmodelOffset or CFrame.new()
		ViewmodelController.UpdateViewmodelPosition(dt, currentOffset, WeaponState.sightIndex())
	elseif WeaponState.viewmodelVisible() and not State.equipping() then
		WeaponState.viewmodelVisible(false)
	end
end

function ViewmodelController.UpdateMovementSway(dt, tempWalkSpeed, vehicleSeated)
	local animBase = ViewmodelController.animBase
	local camera = ViewmodelController.camera
	local humanoid = ViewmodelController.humanoidRootPart.Parent.Humanoid

	local tempDampening = config.bobDampening
	local speedRatio = tempWalkSpeed / config.walkSpeed
	if speedRatio > 0 then
		local difference = tempDampening - (tempDampening / speedRatio)
		tempDampening -= difference / 2
	end
	if State.aiming() then tempDampening *= config.aimBobDampening end

	local tempBobSpeed = config.bobSpeed * speedRatio
	local velocityMag = ViewmodelController.humanoidRootPart.Velocity.Magnitude

	if not humanoid.Sit and velocityMag > 0.1 then
		local moveSway = Vector3.new(GetSineOffset(tempBobSpeed), GetSineOffset(tempBobSpeed / 2), GetSineOffset(tempBobSpeed / 2))
		local moveInstability = (WeaponState.wepStats and WeaponState.wepStats.MoveInstability) or 1
		
		ViewmodelController.moveSpring:shove(moveSway * moveInstability * velocityMag / (tempDampening * tempDampening) * dt * 60)
	end

	local updatedMoveSway = ViewmodelController.moveSpring:update(dt)

	if updatedMoveSway.Magnitude > 0.001 then
		animBase.CFrame = animBase.CFrame:ToWorldSpace(CFrame.new(updatedMoveSway.Y, updatedMoveSway.X, 0) * CFrame.Angles(updatedMoveSway.Y * 0.3, 0, updatedMoveSway.Y * 0.8))

		if config.cameraMovement and (State.firstPerson() and not humanoid.Sit) and not vehicleSeated and camera.CameraType == Enum.CameraType.Custom then
			camera.CFrame *= CFrame.Angles(math.rad(updatedMoveSway.X / config.cameraBobDampening), math.rad(updatedMoveSway.Y / config.cameraBobDampening), 0)
		end
	end
end

return ViewmodelController