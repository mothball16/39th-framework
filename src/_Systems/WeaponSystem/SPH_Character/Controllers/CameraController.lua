local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local TweenService = game:GetService("TweenService")

local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local config = Access.config
local CharacterStateModule = require(Framework.State.CharacterState)
local WeaponStateModule = require(Framework.State.WeaponState)

local SPRINT_FOV_MULTIPLIER = 1.02

type CameraController = {
	camera: Camera,
	cameraRollAngle: number,
	cameraLeanRotation: number,
	cameraOffsetTarget: Vector3,
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,

	aimFOVTarget: Charm.Selector<number>,
	FOVTarget: Charm.Selector<number>,
	FOVLerpFactor: Charm.Selector<number>,
}

local CC: CameraController = {
	camera = nil,
	cameraRollAngle = 0,
	cameraLeanRotation = 0,
	cameraOffsetTarget = Vector3.zero,
	weaponState = nil,
	state = nil,
	aimFOVTarget = nil,
	FOVTarget = nil,
}

local function LerpNumber(number, target, speed)
	return number + (target - number) * speed
end

function CC.Initialize(params)
	CC.camera = params.camera :: Camera

	CC.weaponState = params.weaponState :: WeaponStateModule.WeaponState
	CC.state = params.state :: CharacterStateModule.CharacterState

	CC.aimFOVTarget = Charm.computed(function()
		if not CC.weaponState.wepStats() or not CC.weaponState.gunModel() then
			return config.defaultFOV
		end

		local stat = CC.weaponState.wepStats()

		return stat.aimFovs[CC.weaponState.sightIndex()] or config.defaultFOV
	end)

	CC.FOVTarget = Charm.computed(function()
		local isSprinting = CC.state.sprinting()
		local isAiming = CC.state.aiming()

		if isAiming then
			return CC.aimFOVTarget()
		else
			-- TODO: map this to the actual speed of the char v.s. sprint speed for incrementing FOV
			return config.defaultFOV * (if isSprinting then SPRINT_FOV_MULTIPLIER else 1)
		end
	end)
end

function CC.OnFreelookIntent(inputState, inputObject)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then -- Holding
		CC.state.freeLook(true)
		CC.state.Parts.Humanoid.AutoRotate = false
		CC.state.freeLookRotation(CC.camera.CFrame - CC.camera.CFrame.Position)
	else -- Stopped holding
		CC.state.freeLook(false)
		local freeLookOffset = CC.state.freeLookRotation():ToObjectSpace(CC.camera.CFrame)
		CC.state.freeLookOffset(freeLookOffset - freeLookOffset.Position)
		CC.state.Parts.Humanoid.AutoRotate = true
	end
end

function CC.UpdateRender(dt)
	if not CC.state.dead() and CC.state.Parts.Character:FindFirstChild("Head") then
		local lookDirection = CC.camera.CFrame
		if (not config.headRotation or CC.state.sprinting()) and not CC.state.firstPerson() then
			lookDirection = CC.state.Parts.HRP.CFrame
		end

		local cameraDirection = CC.state.Parts.HRP.CFrame:ToObjectSpace(lookDirection).LookVector
		local rotationCFrame = CFrame.Angles(0, math.asin(cameraDirection.X) / 1.15, 0)
			* CFrame.Angles(-math.asin(math.clamp(lookDirection.LookVector.Y, -0.8, 0.15)), 0, 0)
		local neckCFrame
		if CC.state.Parts.IsR6 then
			neckCFrame = CFrame.new(0, -0.5, 0) * rotationCFrame * CFrame.Angles(-math.rad(90), 0, math.rad(180))
		else
			neckCFrame = CFrame.new(0, -0.5, 0) * rotationCFrame * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0))
		end
		CC.state.Parts.NeckJoint.C1 =
			CC.state.Parts.NeckJoint.C1:Lerp(neckCFrame, 1 - math.exp(-config.headRotationSpeed * dt))

		local fpThreshold = 0.6
		if not CC.state.firstPerson() and CC.state.Parts.Character.Head.LocalTransparencyModifier >= fpThreshold then
			CC.state.firstPerson(true)
		elseif CC.state.firstPerson() and CC.state.Parts.Character.Head.LocalTransparencyModifier <= fpThreshold then
			CC.state.firstPerson(false)
			CC.weaponState.viewmodelVisible(false)
			CC.cameraOffsetTarget = Vector3.zero
		end
	end

	-- Limit camera rotation
	if
		(CC.state.Parts.Humanoid.Sit and not CC.state.vehicleSeated() and CC.state.firstPerson() or CC.state.freeLook())
		and config.cameraLimitInSeats
	then
		local cameraCFrame = CC.state.Parts.HRP.CFrame:ToObjectSpace(CC.camera.CFrame)
		local x, y, z = cameraCFrame:ToOrientation()
		local a = CC.camera.CFrame.Position.X
		local b = CC.camera.CFrame.Position.Y
		local c = CC.camera.CFrame.Position.Z

		local xlimit = math.rad(math.clamp(math.deg(x), -60, 60))
		local ylimit = math.rad(math.clamp(math.deg(y), -60, 60))
		local zlimit = math.rad(math.clamp(math.deg(z), -60, 60))
		local limitedCFrame =
			CC.state.Parts.HRP.CFrame:ToWorldSpace(CFrame.new(a, b, c) * CFrame.fromOrientation(xlimit, ylimit, zlimit))
		CC.camera.CFrame = CFrame.new(CC.camera.CFrame.Position) * (limitedCFrame - limitedCFrame.Position)
	end

	local xOffset
	local yOffset
	local zOffset

	if CC.state.Parts.IsR6 then -- DD_SPH: Added rig-check to correct positioning
		if config.firstPersonBody and CC.state.firstPerson() then
			local xHead = CC.state.Parts.HRP.CFrame:ToObjectSpace(CC.camera.CFrame):ToEulerAngles()
			local rotationOffset = -1.2 + (xHead + 1.4) / 2.8
			CC.cameraOffsetTarget = Vector3.new(0, 0, rotationOffset)
		else
			CC.cameraOffsetTarget = Vector3.zero
		end

		xOffset = 0
		yOffset = 0
		zOffset = CC.cameraOffsetTarget.Z

		if CC.state.stance() == 1 then
			yOffset = -1
			if CC.state.firstPerson() then
				zOffset -= 0.3
			end
		elseif CC.state.stance() == 2 then
			yOffset = -1.2
			if CC.state.firstPerson() then
				zOffset = -1.7
			end
		end

		-- Lean offset
		if CC.state.lean() < 0 then
			xOffset = -1
			yOffset += -0.2
		elseif CC.state.lean() > 0 then
			xOffset = 1
			yOffset += -0.2
		end
	else
		if config.firstPersonBody and CC.state.firstPerson() then
			local xHead = CC.state.Parts.HRP.CFrame:ToObjectSpace(CC.camera.CFrame):ToEulerAngles()
			local rotationOffset = -1.6 + (xHead + 1.4) / 2.8
			CC.cameraOffsetTarget = Vector3.new(0, 0, rotationOffset)
		else
			CC.cameraOffsetTarget = Vector3.zero
		end

		xOffset = 0
		yOffset = 0
		zOffset = CC.cameraOffsetTarget.Z

		if CC.state.stance() == 1 then -- DD_SPH: Adjusted camera positioning to reflect R15.
			yOffset = 0.5
			if CC.state.firstPerson() then
				zOffset -= 1.5
			end --rev
		elseif CC.state.stance() == 2 then
			yOffset = 1.5
			if CC.state.firstPerson() then
				zOffset = -3
			end --rev
		end

		-- Lean offset
		if CC.state.lean() < 0 then
			xOffset = -1
			yOffset -= 0.2 --rev
		elseif CC.state.lean() > 0 then
			xOffset = 1
			yOffset -= 0.2 --rev
		end
	end --</DD_SPH>

	if not CC.state.vehicleSeated() and CC.camera.CameraType == Enum.CameraType.Custom then
		-- Update camera offset
		if CC.state.Parts.IsR6 then -- DD_SPH: Different offsets for different rigs
			CC.cameraOffsetTarget = Vector3.new(xOffset, yOffset, zOffset)
		else
			CC.cameraOffsetTarget = Vector3.new(xOffset, -yOffset, zOffset)
		end
		CC.state.Parts.Humanoid.CameraOffset =
			CC.state.Parts.Humanoid.CameraOffset:Lerp(CC.cameraOffsetTarget, 0.1 * dt * 60)

		-- </DD_SPH>
		CC.cameraLeanRotation = LerpNumber(CC.cameraLeanRotation, 15 * -CC.state.lean(), 0.1)
		CC.camera.CFrame *= CFrame.Angles(0, 0, math.rad(CC.cameraLeanRotation))

		-- Camera tilt
		if config.cameraTilting and CC.state.firstPerson() then
			local maxTiltAngle = 2
			local relativeVelocity = CC.state.Parts.HRP.CFrame:VectorToObjectSpace(CC.state.Parts.HRP.Velocity)
			local viewportSize = CC.camera.ViewportSize
			local mouseDelta = UserInputService:GetMouseDelta() / viewportSize
			local targetRollAngle = math.clamp(-relativeVelocity.X, -maxTiltAngle, maxTiltAngle) + mouseDelta.X / 2
			CC.cameraRollAngle = LerpNumber(CC.cameraRollAngle, targetRollAngle, 0.07 * dt * 60)
			CC.camera.CFrame *= CFrame.Angles(0, 0, math.rad(CC.cameraRollAngle))
		end
	end

	CC.camera.CFrame = CC.camera.CFrame
		* CFrame.Angles(
			CC.weaponState.CameraSpring.p.X,
			CC.weaponState.CameraSpring.p.Y,
			CC.weaponState.CameraSpring.p.Z
		)
	CC.weaponState.CameraSpring.t = CC.weaponState.CameraSpring.t - CC.weaponState.CameraSpring.p
	CC.weaponState.CameraSpring.p = Vector3.new()

	CC.UpdateFOV(dt)
end

function CC.UpdateFOV(dt)
	local camSensFactor = CC.camera.FieldOfView / config.defaultFOV
	if CC.state.aiming() then
		UserInputService.MouseDeltaSensitivity = CC.weaponState.aimSens() * camSensFactor
	else
		UserInputService.MouseDeltaSensitivity = 1 * camSensFactor
	end
	
	CC.camera.FieldOfView =
		LerpNumber(CC.camera.FieldOfView, CC.FOVTarget(), (CC.weaponState.aimLerpFactor() / 2) * (dt * 60))
end

-- TODO: REFACTOR
local depthOfField = game.Lighting:FindFirstChild("SPH_DoF")
if not depthOfField and config.blurEffects then
	depthOfField = Instance.new("DepthOfFieldEffect", game.Lighting)
end
if depthOfField then
	depthOfField.Name = "SPH_DoF"
end

function CC.ChangeDoF(fInt, fDist, fRad, nInt)
	if not depthOfField then
		return
	end
	TweenService:Create(depthOfField, TweenInfo.new(0.2), {
		FarIntensity = fInt,
		FocusDistance = fDist,
		InFocusRadius = fRad,
		NearIntensity = nInt,
	}):Play()
end

return CC
