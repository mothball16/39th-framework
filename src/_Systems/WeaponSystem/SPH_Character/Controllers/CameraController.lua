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
local WeaponPrefs = require(Framework.Weapons.WeaponPrefsClient)

local SPRINT_FOV_MULTIPLIER = 1.03

local CameraController = {}
CameraController.__index = CameraController

type self = {
	camera: Camera,
	cameraRollAngle: number,
	cameraLeanRotation: number,
	cameraOffsetTarget: Vector3,
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,
	aimFOVTarget: () -> number,
	FOVTarget: () -> number,
}

export type CameraController = typeof(setmetatable({} :: self, CameraController))

local function lerpNumber(number: number, target: number, speed: number): number
	return number + (target - number) * speed
end

local depthOfField = game.Lighting:FindFirstChild("SPH_DoF")
if not depthOfField and config.blurEffects then
	depthOfField = Instance.new("DepthOfFieldEffect", game.Lighting)
end
if depthOfField then
	depthOfField.Name = "SPH_DoF"
end

function CameraController.new(params: {
	camera: Camera,
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,
}): CameraController
	local self = setmetatable({
		camera = params.camera,
		cameraRollAngle = 0,
		cameraLeanRotation = 0,
		cameraOffsetTarget = Vector3.zero,
		weaponState = params.weaponState,
		state = params.state,
		aimFOVTarget = nil :: () -> number,
		FOVTarget = nil :: () -> number,
	} :: self, CameraController)

	self.aimFOVTarget = Charm.computed(function()
		if not self.weaponState.wepStats() or not self.weaponState.gunModel() then
			return config.defaultFOV
		end

		local stat = self.weaponState.wepStats()
		return stat.aimFovs[self.weaponState.sightIndex()] or config.defaultFOV
	end)

	self.FOVTarget = Charm.computed(function()
		local isSprinting = self.state.sprinting()
		local isAiming = self.state.aiming()

		if isAiming then
			return self.aimFOVTarget()
		end
		return config.defaultFOV * (if isSprinting then SPRINT_FOV_MULTIPLIER else 1)
	end)

	return self
end

function CameraController.OnFreelookIntent(self: CameraController, inputState: Enum.UserInputState, _)
	local inputBegan = Enum.UserInputState.Begin
	if inputState == inputBegan then
		self.state.freeLook(true)
		self.state.Parts.Humanoid.AutoRotate = false
		self.state.freeLookRotation(self.camera.CFrame - self.camera.CFrame.Position)
	else
		self.state.freeLook(false)
		local freeLookOffset = self.state.freeLookRotation():ToObjectSpace(self.camera.CFrame)
		self.state.freeLookOffset(freeLookOffset - freeLookOffset.Position)
		self.state.Parts.Humanoid.AutoRotate = true
	end
end

function CameraController.UpdateFOV(self: CameraController, dt: number)
	local camSensFactor = self.camera.FieldOfView / config.defaultFOV
	if self.state.aiming() then
		UserInputService.MouseDeltaSensitivity = WeaponPrefs.getGlobal("aimSens") * camSensFactor
	else
		UserInputService.MouseDeltaSensitivity = 1 * camSensFactor
	end

	self.camera.FieldOfView = lerpNumber(
		self.camera.FieldOfView,
		self.FOVTarget(),
		self.weaponState.aimCamLerpFactor() * (dt * 60)
	)
end

function CameraController.UpdateRender(self: CameraController, dt: number)
	if not self.state.dead() and self.state.Parts.Character:FindFirstChild("Head") then
		local lookDirection = self.camera.CFrame
		if (not config.headRotation or self.state.sprinting()) and not self.state.firstPerson() then
			lookDirection = self.state.Parts.HRP.CFrame
		end

		local cameraDirection = self.state.Parts.HRP.CFrame:ToObjectSpace(lookDirection).LookVector
		local rotationCFrame = CFrame.Angles(0, math.asin(cameraDirection.X) / 1.15, 0)
			* CFrame.Angles(-math.asin(math.clamp(lookDirection.LookVector.Y, -0.8, 0.15)), 0, 0)
		local neckCFrame
		if self.state.Parts.IsR6 then
			neckCFrame = CFrame.new(0, -0.5, 0) * rotationCFrame * CFrame.Angles(-math.rad(90), 0, math.rad(180))
		else
			neckCFrame = CFrame.new(0, -0.5, 0) * rotationCFrame * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0))
		end
		self.state.Parts.NeckJoint.C1 =
			self.state.Parts.NeckJoint.C1:Lerp(neckCFrame, 1 - math.exp(-config.headRotationSpeed * dt))

		local fpThreshold = 0.6
		if not self.state.firstPerson() and self.state.Parts.Character.Head.LocalTransparencyModifier >= fpThreshold then
			self.state.firstPerson(true)
		elseif self.state.firstPerson() and self.state.Parts.Character.Head.LocalTransparencyModifier <= fpThreshold then
			self.state.firstPerson(false)
			self.weaponState.viewmodelVisible(false)
			self.cameraOffsetTarget = Vector3.zero
		end
	end

	if
		(self.state.Parts.Humanoid.Sit and not self.state.vehicleSeated() and self.state.firstPerson() or self.state.freeLook())
		and config.cameraLimitInSeats
	then
		local cameraCFrame = self.state.Parts.HRP.CFrame:ToObjectSpace(self.camera.CFrame)
		local x, y, z = cameraCFrame:ToOrientation()
		local a = self.camera.CFrame.Position.X
		local b = self.camera.CFrame.Position.Y
		local c = self.camera.CFrame.Position.Z

		local xlimit = math.rad(math.clamp(math.deg(x), -60, 60))
		local ylimit = math.rad(math.clamp(math.deg(y), -60, 60))
		local zlimit = math.rad(math.clamp(math.deg(z), -60, 60))
		local limitedCFrame =
			self.state.Parts.HRP.CFrame:ToWorldSpace(CFrame.new(a, b, c) * CFrame.fromOrientation(xlimit, ylimit, zlimit))
		self.camera.CFrame = CFrame.new(self.camera.CFrame.Position) * (limitedCFrame - limitedCFrame.Position)
	end

	local xOffset
	local yOffset
	local zOffset

	if self.state.Parts.IsR6 then
		if config.firstPersonBody and self.state.firstPerson() then
			local xHead = self.state.Parts.HRP.CFrame:ToObjectSpace(self.camera.CFrame):ToEulerAngles()
			local rotationOffset = -1.2 + (xHead + 1.4) / 2.8
			self.cameraOffsetTarget = Vector3.new(0, 0, rotationOffset)
		else
			self.cameraOffsetTarget = Vector3.zero
		end

		xOffset = 0
		yOffset = 0
		zOffset = self.cameraOffsetTarget.Z

		if self.state.stance() == 1 then
			yOffset = -1
			if self.state.firstPerson() then
				zOffset -= 0.3
			end
		elseif self.state.stance() == 2 then
			yOffset = -1.2
			if self.state.firstPerson() then
				zOffset = -1.7
			end
		end

		if self.state.lean() < 0 then
			xOffset = -1
			yOffset += -0.2
		elseif self.state.lean() > 0 then
			xOffset = 1
			yOffset += -0.2
		end
	else
		if config.firstPersonBody and self.state.firstPerson() then
			local xHead = self.state.Parts.HRP.CFrame:ToObjectSpace(self.camera.CFrame):ToEulerAngles()
			local rotationOffset = -1.6 + (xHead + 1.4) / 2.8
			self.cameraOffsetTarget = Vector3.new(0, 0, rotationOffset)
		else
			self.cameraOffsetTarget = Vector3.zero
		end

		xOffset = 0
		yOffset = 0
		zOffset = self.cameraOffsetTarget.Z

		if self.state.stance() == 1 then
			yOffset = 0.5
			if self.state.firstPerson() then
				zOffset -= 1.5
			end
		elseif self.state.stance() == 2 then
			yOffset = 1.5
			if self.state.firstPerson() then
				zOffset = -3
			end
		end

		if self.state.lean() < 0 then
			xOffset = -1
			yOffset -= 0.2
		elseif self.state.lean() > 0 then
			xOffset = 1
			yOffset -= 0.2
		end
	end

	if not self.state.vehicleSeated() and self.camera.CameraType == Enum.CameraType.Custom then
		if self.state.Parts.IsR6 then
			self.cameraOffsetTarget = Vector3.new(xOffset, yOffset, zOffset)
		else
			self.cameraOffsetTarget = Vector3.new(xOffset, -yOffset, zOffset)
		end
		self.state.Parts.Humanoid.CameraOffset =
			self.state.Parts.Humanoid.CameraOffset:Lerp(self.cameraOffsetTarget, 0.1 * dt * 60)

		self.cameraLeanRotation = lerpNumber(self.cameraLeanRotation, 15 * -self.state.lean(), 0.1)
		self.camera.CFrame *= CFrame.Angles(0, 0, math.rad(self.cameraLeanRotation))

		if config.cameraTilting and self.state.firstPerson() then
			local maxTiltAngle = 2
			local relativeVelocity = self.state.Parts.HRP.CFrame:VectorToObjectSpace(self.state.Parts.HRP.Velocity)
			local viewportSize = self.camera.ViewportSize
			local mouseDelta = UserInputService:GetMouseDelta() / viewportSize
			local targetRollAngle = math.clamp(-relativeVelocity.X, -maxTiltAngle, maxTiltAngle) + mouseDelta.X / 2
			self.cameraRollAngle = lerpNumber(self.cameraRollAngle, targetRollAngle, 0.07 * dt * 60)
			self.camera.CFrame *= CFrame.Angles(0, 0, math.rad(self.cameraRollAngle))
		end
	end

	self.camera.CFrame = self.camera.CFrame
		* CFrame.Angles(
			self.weaponState.CameraSpring.p.X,
			self.weaponState.CameraSpring.p.Y,
			self.weaponState.CameraSpring.p.Z
		)
	self.weaponState.CameraSpring.t = self.weaponState.CameraSpring.t - self.weaponState.CameraSpring.p
	self.weaponState.CameraSpring.p = Vector3.new()

	self:UpdateFOV(dt)
end

function CameraController.ChangeDoF(_self: CameraController, fInt: number, fDist: number, fRad: number, nInt: number)
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

return CameraController
