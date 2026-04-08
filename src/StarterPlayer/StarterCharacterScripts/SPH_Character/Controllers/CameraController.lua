local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local TweenService = game:GetService("TweenService")

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local State = require(script.Parent.CharacterState)
local WeaponState = require(script.Parent.WeaponState)

local CC = {
	camera = nil,

	cameraRollAngle = 0,
	cameraLeanRotation = 0,
	cameraOffsetTarget = Vector3.zero,
	headRotationEventCooldown = 0,

	ReplicationController = nil,

	aimTween = nil :: Tween
}

local function LerpNumber(number, target, speed)
	return number + (target - number) * speed
end

function CC.Initialize(params)
	CC.camera = params.camera

	CC.ReplicationController = params.ReplicationController

	Charm.subscribe(State.sprinting, CC.OnSprintChanged)
	Charm.subscribe(State.aiming, CC.OnAimingChanged)
end


function CC.OnSprintChanged(sprinting)
	--[[
	if sprinting then
		if depthOfField then
			CameraController.ChangeDoF(0, 6, 0, 0.3)
		end
	end]]
end

function CC.OnAimingChanged(aiming)
	if CC.aimTween then
		CC.aimTween:Cancel()
		CC.aimTween = nil
	end
	
	if aiming then
		-- nothin yet
	else
		local aimOutTime = WeaponState.wepStats and WeaponState.wepStats.aimTime / 2 or 0.3
		CC.aimTween = TweenService:Create(
			CC.camera, TweenInfo.new(aimOutTime),{FieldOfView = config.defaultFOV})
		CC.aimTween:Play()
	end
end



function CC.OnFreelookIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then -- Holding
		State.freeLook(true)
		State.Parts.Humanoid.AutoRotate = false
		State.freeLookRotation(CC.camera.CFrame - CC.camera.CFrame.Position)
	else -- Stopped holding
		State.freeLook(false)
		local freeLookOffset = State.freeLookRotation():ToObjectSpace(CC.camera.CFrame)
		State.freeLookOffset(freeLookOffset - freeLookOffset.Position)
		State.Parts.Humanoid.AutoRotate = true
	end
end


function CC.UpdateRender(dt)
	if not State.dead() and State.Parts.Character:FindFirstChild("Head") then
		local torsoDirection
		if State.Parts.IsR6 then
			torsoDirection = State.Parts.Character.Torso.CFrame.LookVector
		else
			torsoDirection = State.Parts.Character.UpperTorso.CFrame.LookVector
		end

		local lookDirection = CC.camera.CFrame
		if (not config.headRotation or State.sprinting()) and not State.firstPerson() then
			lookDirection = State.Parts.HRP.CFrame
		end

		local cameraDirection = State.Parts.HRP.CFrame:ToObjectSpace(lookDirection).LookVector
		local rotationCFrame = CFrame.Angles(0, math.asin(cameraDirection.X)/1.15, 0) * CFrame.Angles(-math.asin(math.clamp(lookDirection.LookVector.Y,-.8,.15)) + math.asin(math.clamp(torsoDirection.Y, -.6,.6)), 0, 0)
		local neckCFrame
		if State.Parts.IsR6 then
			neckCFrame = CFrame.new(0, -.5, 0) * rotationCFrame * CFrame.Angles(-math.rad(90), 0, math.rad(180))
		else
			neckCFrame = CFrame.new(0, -.5, 0) * rotationCFrame * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0))
		end
		State.Parts.NeckJoint.C1 = State.Parts.NeckJoint.C1:Lerp(neckCFrame, 1 - math.exp(-config.headRotationSpeed * dt))

		CC.headRotationEventCooldown -= dt
		if CC.headRotationEventCooldown <= 0 and not config.disableHeadRotation then
			CC.headRotationEventCooldown = config.headRotationEventRate
			CC.ReplicationController.ReplicateHeadRotation(State.Parts.NeckJoint.C1)
		end

		local fpThreshold = 0.6
		if not State.firstPerson() and State.Parts.Character.Head.LocalTransparencyModifier >= fpThreshold then
			State.firstPerson(true)
		elseif State.firstPerson() and State.Parts.Character.Head.LocalTransparencyModifier <= fpThreshold then
			State.firstPerson(false)
			WeaponState.viewmodelVisible(false)
			CC.cameraOffsetTarget = Vector3.zero
		end
	end
	
	-- Limit camera rotation
	if (State.Parts.Humanoid.Sit and not State.vehicleSeated() and State.firstPerson() or State.freeLook()) and config.cameraLimitInSeats then
		local cameraCFrame = State.Parts.HRP.CFrame:ToObjectSpace(CC.camera.CFrame)
		local x, y, z = cameraCFrame:ToOrientation()
		local a = CC.camera.CFrame.Position.X
		local b = CC.camera.CFrame.Position.Y
		local c = CC.camera.CFrame.Position.Z

		local xlimit = math.rad(math.clamp(math.deg(x), -60, 60))
		local ylimit = math.rad(math.clamp(math.deg(y), -60, 60))
		local zlimit = math.rad(math.clamp(math.deg(z), -60, 60))
		local limitedCFrame = State.Parts.HRP.CFrame:ToWorldSpace(CFrame.new(a, b, c) * CFrame.fromOrientation(xlimit, ylimit, zlimit))
		CC.camera.CFrame = CFrame.new(CC.camera.CFrame.Position) * (limitedCFrame - limitedCFrame.Position)
	end

	local xOffset
	local yOffset
	local zOffset

	if State.Parts.IsR6 then -- DD_SPH: Added rig-check to correct positioning
		if config.firstPersonBody and State.firstPerson() then
			local xHead = State.Parts.HRP.CFrame:ToObjectSpace(CC.camera.CFrame):ToEulerAngles()
			local rotationOffset = -1.2 + (xHead + 1.4) / 2.8
			CC.cameraOffsetTarget = Vector3.new(0, 0, rotationOffset)
		else
			CC.cameraOffsetTarget = Vector3.zero
		end

		xOffset = 0
		yOffset = 0
		zOffset = CC.cameraOffsetTarget.Z

		if State.stance() == 1 then
			yOffset = -1
			if State.firstPerson() then zOffset -= 0.3 end
		elseif State.stance() == 2 then
			yOffset = -1.5
			if State.firstPerson() then zOffset = -1.7 end
		end

		-- Lean offset
		if State.lean() < 0 then
			xOffset = -1
			yOffset += -0.2
		elseif State.lean() > 0 then
			xOffset = 1
			yOffset += -0.2
		end
	else
		if config.firstPersonBody and State.firstPerson() then
			local xHead = State.Parts.HRP.CFrame:ToObjectSpace(CC.camera.CFrame):ToEulerAngles()
			local rotationOffset = -1.6 + (xHead + 1.4) / 2.8
			CC.cameraOffsetTarget = Vector3.new(0, 0, rotationOffset)
		else
			CC.cameraOffsetTarget = Vector3.zero
		end

		xOffset = 0
		yOffset = 0
		zOffset = CC.cameraOffsetTarget.Z

		if State.stance() == 1 then -- DD_SPH: Adjusted camera positioning to reflect R15.
			yOffset = .5
			if State.firstPerson() then zOffset -= 1.5 end --rev
		elseif State.stance() == 2 then
			yOffset = 1.5
			if State.firstPerson() then zOffset = -3 end --rev
		end

		-- Lean offset
		if State.lean() < 0 then
			xOffset = -1
			yOffset -= 0.2 --rev
		elseif State.lean() > 0 then
			xOffset = 1
			yOffset -= 0.2 --rev
		end
	end --</DD_SPH>

	if not State.vehicleSeated() and CC.camera.CameraType == Enum.CameraType.Custom then
		-- Update camera offset
		if State.Parts.IsR6 then -- DD_SPH: Different offsets for different rigs
			CC.cameraOffsetTarget = Vector3.new(xOffset, yOffset, zOffset)
		else
			CC.cameraOffsetTarget = Vector3.new(xOffset, -yOffset, zOffset)
		end
		State.Parts.Humanoid.CameraOffset = State.Parts.Humanoid.CameraOffset:Lerp(CC.cameraOffsetTarget, 0.1 * dt * 60)

		-- </DD_SPH>
		CC.cameraLeanRotation = LerpNumber(CC.cameraLeanRotation, 15 * -State.lean(), 0.1)
		CC.camera.CFrame *= CFrame.Angles(0, 0, math.rad(CC.cameraLeanRotation))

		-- Camera tilt
		if config.cameraTilting and State.firstPerson() then
			local maxTiltAngle = 2
			local relativeVelocity = State.Parts.HRP.CFrame:VectorToObjectSpace(State.Parts.HRP.Velocity)
			local viewportSize = CC.camera.ViewportSize
			local mouseDelta = UserInputService:GetMouseDelta() / viewportSize
			local targetRollAngle = math.clamp(-relativeVelocity.X, -maxTiltAngle, maxTiltAngle) + mouseDelta.X / 2
			CC.cameraRollAngle = LerpNumber(CC.cameraRollAngle, targetRollAngle, 0.07 * dt * 60)
			CC.camera.CFrame *= CFrame.Angles(0, 0, math.rad(CC.cameraRollAngle))
		end
	end

	CC.camera.CFrame = CC.camera.CFrame
		* CFrame.Angles(WeaponState.CameraSpring.p.X, WeaponState.CameraSpring.p.Y, WeaponState.CameraSpring.p.Z)
	WeaponState.CameraSpring.t = WeaponState.CameraSpring.t - WeaponState.CameraSpring.p
	WeaponState.CameraSpring.p = Vector3.new()
end

function CC.UpdateFOV(dt)
	local camSensFactor = CC.camera.FieldOfView / config.defaultFOV
	if State.aiming() then
		CC.camera.FieldOfView = LerpNumber(CC.camera.FieldOfView, State.aimFOVTarget(), 0.3 * (dt * 60))
		UserInputService.MouseDeltaSensitivity = WeaponState.aimSens() * camSensFactor
	else
		UserInputService.MouseDeltaSensitivity = 1 * camSensFactor
	end
end


-- TODO: REFACTOR
local depthOfField = game.Lighting:FindFirstChild("SPH_DoF")
if not depthOfField and config.blurEffects then
	depthOfField = Instance.new("DepthOfFieldEffect",game.Lighting)
end
if depthOfField then depthOfField.Name = "SPH_DoF" end

function CC.ChangeDoF(fInt,fDist,fRad,nInt)
	if not depthOfField then return end
	TweenService:Create(depthOfField,TweenInfo.new(0.2),{
		FarIntensity = fInt,
		FocusDistance = fDist,
		InFocusRadius = fRad,
		NearIntensity = nInt
	}):Play()
end

return CC