local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local springMod = require(assets.Modules.SpringModule)
local State = require(script.Parent.CharacterState)

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
local recoilUpdateCD = 0
local aimTarget = CFrame.new()

ViewmodelController.animBase = nil
ViewmodelController.camera = nil
ViewmodelController.humanoidRootPart = nil
ViewmodelController.weaponRig = nil
ViewmodelController.rayParams = nil

ViewmodelController.ChangeHoldStance = nil
ViewmodelController.PlayAnimation = nil
ViewmodelController.StopAnimation = nil
ViewmodelController.ToggleAiming = nil

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
	ViewmodelController.ToggleAiming = params.ToggleAiming
end

function ViewmodelController.ResetHipRotation()
	hipRotation = Vector2.zero
end

function ViewmodelController.UpdateViewmodelPosition(dt, offset, freeLook, freeLookRotation, freeLookOffset, sightIndex, blocked, aimHeld, viewmodelVisible)
	local fps = 1 / dt
	recoilUpdateCD -= dt

	local animBase = ViewmodelController.animBase
	local camera = ViewmodelController.camera
	local humanoidRootPart = ViewmodelController.humanoidRootPart
	local weaponRig = ViewmodelController.weaponRig
	local rayParams = ViewmodelController.rayParams

	animBase.CFrame = CFrame.new((camera.CFrame * offset).Position)

	if not freeLook then
		animBase.CFrame *= camera.CFrame - camera.CFrame.Position
	else
		animBase.CFrame *= freeLookRotation
	end

	if State.stance == 2 then
		proneViewmodelOffset = LerpNumber(proneViewmodelOffset, 0.2, 0.1)
	else
		proneViewmodelOffset = LerpNumber(proneViewmodelOffset, 0, 0.1)
	end
	animBase.CFrame *= CFrame.new(0, proneViewmodelOffset, 0)

	local freelookRecovery = 0.2
	freeLookOffset = freeLookOffset:Lerp(CFrame.new(), freelookRecovery * dt * 60)
	animBase.CFrame *= freeLookOffset:Inverse()

	local aimPart = State.gunModel:FindFirstChild("AimPart" .. sightIndex) or State.gunModel.AimPart
	if State.attStats.aimParts then
		if State.attStats.aimParts["AimPart" .. sightIndex] then
			aimPart = State.gunModel[State.attStats.aimParts["AimPart" .. sightIndex]]:FindFirstChild("AimPart" .. sightIndex)
		end
	end
	aimTarget = aimPart.CFrame:ToObjectSpace(camera.CFrame)

	local aimTime = State.wepStats.aimTime
	if State.attStats.aimTime then aimTime *= State.attStats.aimTime end

	if State.aiming() then
		aimingOffset = aimingOffset:Lerp(aimTarget, (0.7 / aimTime) * 0.3 * dt * 60)
	else
		aimingOffset = aimingOffset:Lerp(CFrame.new(), (0.7 / aimTime) * 0.3 * dt * 60)
	end
	animBase.CFrame *= aimingOffset

	local rayDistance = State.wepStats.gunLength
	if State.attStats.gunLength then rayDistance += State.attStats.gunLength end
	local originCFrame = State.firstPerson() and animBase.CFrame or weaponRig.AnimBase.CFrame
	local newRay = workspace:Raycast(originCFrame.Position, originCFrame.LookVector * rayDistance, rayParams)
	
	if newRay then
		local distance = rayDistance - (animBase.CFrame.Position - newRay.Position).Magnitude
		if config.pushBackViewmodel and distance > 0 then
			local tempDist = distance
			if blocked then tempDist /= 2 end
			pushbackOffset = LerpNumber(pushbackOffset, tempDist, 0.2 * 60 * dt)
		else
			pushbackOffset = LerpNumber(pushbackOffset, 0, 0.2 * 60 * dt)
		end

		if config.raiseGunAtWall then
			if distance >= State.wepStats.maxPushback then
				if not blocked then
					ViewmodelController.ChangeHoldStance(0)
					ViewmodelController.PlayAnimation(State.wepStats.holdUpAnim, {looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.3})
					blocked = true
					if State.aiming() then ViewmodelController.ToggleAiming(false) end
				end
			elseif blocked then
				ViewmodelController.StopAnimation(State.wepStats.holdUpAnim, 0.3)
				blocked = false
				if aimHeld and not State.aiming() and State.firstPerson() then
					ViewmodelController.ToggleAiming(true)
				end
			end
		end
	else
		if blocked then
			ViewmodelController.StopAnimation(State.wepStats.holdUpAnim, 0.3)
		end
		blocked = false
		if aimHeld and not State.aiming() and State.firstPerson() and not State.sprinting() then
			ViewmodelController.ToggleAiming(true)
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

	local mouseDelta = UserInputService:GetMouseDelta()

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

	ViewmodelController.swaySpring:shove(Vector3.new(-mouseDelta.X / 500, mouseDelta.Y / 200, 0))
	local updatedSway = ViewmodelController.swaySpring:update(dt)
	animBase.CFrame *= CFrame.new(updatedSway.X, updatedSway.Y, 0)

	local tickTime = tick() * 0.15
	local tempDist = config.breathingDist
	if State.aiming() then tempDist *= config.breathingAimMultiplier end
	animBase.CFrame *= CFrame.new(tempDist * math.sin(tickTime * config.breathingSpeed / 2), tempDist * math.sin(tickTime * config.breathingSpeed), 0)

	local updatedRecoil = ViewmodelController.recoilSpring.Position
	local updatedGunRecoil = ViewmodelController.gunRecoilSpring:update(dt)
	if recoilUpdateCD <= 0 then
		recoilUpdateCD = 1 / 60
		local currentFPS = 1 / dt
		local dtMult = (currentFPS / 60) - 1
		dtMult = dtMult / 2
		updatedRecoil = ViewmodelController.recoilSpring:update(0.016 + (0.016 * dtMult))
	end

	animBase.CFrame *= CFrame.Angles(math.rad(updatedGunRecoil.X), math.rad(updatedGunRecoil.Y), 0)
	animBase.CFrame *= CFrame.new(0, 0, updatedGunRecoil.Z)
	camera.CFrame *= CFrame.Angles(math.rad(updatedRecoil.X), math.rad(updatedRecoil.Y), math.rad(updatedRecoil.Z))

	if not viewmodelVisible then
		animBase.CFrame *= storageCFrame
	end

	return freeLookOffset, blocked
end

function ViewmodelController.UpdateMovementSway(dt, tempWalkSpeed, vehicleSeated)
	local animBase = ViewmodelController.animBase
	local camera = ViewmodelController.camera
	local humanoid = ViewmodelController.humanoidRootPart.Parent.Humanoid

	local tempDampening = config.bobDampening
	local difference = tempDampening - (tempDampening / (tempWalkSpeed / config.walkSpeed))
	difference /= 2
	tempDampening -= difference
	if State.aiming() then tempDampening *= config.aimBobDampening end

	local tempBobSpeed = config.bobSpeed
	tempBobSpeed *= tempWalkSpeed / config.walkSpeed

	if not humanoid.Sit then
		local moveSway = Vector3.new(GetSineOffset(tempBobSpeed), GetSineOffset(tempBobSpeed / 2), GetSineOffset(tempBobSpeed / 2))
		ViewmodelController.moveSpring:shove(moveSway / tempDampening * ViewmodelController.humanoidRootPart.Velocity.Magnitude / tempDampening * dt * 60)
	end

	local updatedMoveSway = ViewmodelController.moveSpring:update(dt)
	animBase.CFrame = animBase.CFrame:ToWorldSpace(CFrame.new(updatedMoveSway.Y, updatedMoveSway.X, 0) * CFrame.Angles(updatedMoveSway.Y * 0.3, 0, updatedMoveSway.Y * 0.8))

	if config.cameraMovement and (State.firstPerson() and not humanoid.Sit) and not vehicleSeated and camera.CameraType == Enum.CameraType.Custom then
		camera.CFrame *= CFrame.Angles(math.rad(updatedMoveSway.X / config.cameraBobDampening), math.rad(updatedMoveSway.Y / config.cameraBobDampening), 0)
	end
end

return ViewmodelController