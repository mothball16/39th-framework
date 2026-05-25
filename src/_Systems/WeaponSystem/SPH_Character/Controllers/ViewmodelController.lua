local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local config = Access.config
local Enums = require(Framework.Core.Enums)
local springMod = require(Framework.Weapons.SpringModule)
local CharacterStateModule = require(Framework.State.CharacterState)
local WeaponStateModule = require(Framework.State.WeaponState)

local STORAGE_CFRAME = CFrame.new(1000000, 0, 0)

local ViewmodelController = {}
ViewmodelController.__index = ViewmodelController

type self = {
	state: CharacterStateModule.CharacterState,
	weaponState: WeaponStateModule.WeaponState,
	animBase: BasePart,
	camera: Camera,
	humanoidRootPart: BasePart,
	weaponRig: Model,
	rayParams: RaycastParams,
	StopAnimation: (string, number) -> (),
	RefreshViewmodel: () -> (),
	swaySpring: typeof(springMod.new()),
	moveSpring: typeof(springMod.new()),
	pushbackOffset: number,
	hipRotation: Vector2,
	aimingOffset: CFrame,
	proneViewmodelOffset: number,
	rollAngle: number,
	strafeShift: number,
	aimTarget: CFrame,
}

export type ViewmodelController = setmetatable<self, typeof(ViewmodelController)>

local function lerpNumber(number: number, target: number, speed: number): number
	return number + (target - number) * speed
end

local function getSineOffset(addition: number): number
	return math.sin(tick() * addition * 1.3) * 0.3
end

function ViewmodelController.new(params: {
	animBase: BasePart,
	camera: Camera,
	humanoidRootPart: BasePart,
	weaponRig: Model,
	rayParams: RaycastParams,
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,
	StopAnimation: (string, number) -> (),
	RefreshViewmodel: () -> (),
}): ViewmodelController
	local self = setmetatable({
		state = params.state,
		weaponState = params.weaponState,
		animBase = params.animBase,
		camera = params.camera,
		humanoidRootPart = params.humanoidRootPart,
		weaponRig = params.weaponRig,
		rayParams = params.rayParams,
		StopAnimation = params.StopAnimation,
		RefreshViewmodel = params.RefreshViewmodel,
		swaySpring = springMod.new(),
		moveSpring = springMod.new(),
		pushbackOffset = 0,
		hipRotation = Vector2.zero,
		aimingOffset = CFrame.new(),
		proneViewmodelOffset = 0,
		rollAngle = 0,
		strafeShift = 0,
		aimTarget = CFrame.new(),
	} :: self, ViewmodelController)

	Charm.subscribe(self.state.equippedTool, function(tool)
		self:SyncEquippedTool(tool)
	end)

	return self
end

function ViewmodelController.SyncEquippedTool(self: ViewmodelController, tool: Tool?)
	if not tool then
		return
	end
	self:ResetHipRotation()
end

function ViewmodelController.ResetHipRotation(self: ViewmodelController)
	self.hipRotation = Vector2.zero
end

function ViewmodelController.UpdateViewmodelPosition(
	self: ViewmodelController,
	dt: number,
	offset: CFrame,
	sightIndex: number
)
	local animBase = self.animBase
	local camera = self.camera
	local humanoidRootPart = self.humanoidRootPart
	local weaponRig = self.weaponRig
	local rayParams = self.rayParams
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end

	animBase.CFrame = CFrame.new((camera.CFrame * offset).Position)

	if not self.state.freeLook() then
		animBase.CFrame *= camera.CFrame - camera.CFrame.Position
	else
		animBase.CFrame *= self.state.freeLookRotation()
	end

	if self.state.stance() == 2 then
		self.proneViewmodelOffset = lerpNumber(self.proneViewmodelOffset, 0.2, 0.1)
	else
		self.proneViewmodelOffset = lerpNumber(self.proneViewmodelOffset, 0, 0.1)
	end
	animBase.CFrame *= CFrame.new(0, self.proneViewmodelOffset, 0)

	local freelookRecovery = 0.2
	local newFlOffset = self.state.freeLookOffset():Lerp(CFrame.new(), freelookRecovery * dt * 60)
	self.state.freeLookOffset(newFlOffset)
	animBase.CFrame *= newFlOffset:Inverse()

	local gunModel = self.weaponState.gunModel()
	local aimPart = gunModel:FindFirstChild("AimPart" .. sightIndex) or gunModel.AimPart
	self.aimTarget = aimPart.CFrame:ToObjectSpace(camera.CFrame)

	local lerpFactor = self.weaponState.aimLerpFactor()
	if self.state.aiming() then
		self.aimingOffset = self.aimingOffset:Lerp(self.aimTarget, lerpFactor * dt * 60)
	else
		self.aimingOffset = self.aimingOffset:Lerp(CFrame.new(), lerpFactor * dt * 60)
	end
	animBase.CFrame *= self.aimingOffset

	local rayDistance = ws.gunLength
	local originCFrame = self.state.firstPerson() and animBase.CFrame or weaponRig.AnimBase.CFrame
	local newRay = workspace:Raycast(originCFrame.Position, originCFrame.LookVector * rayDistance, rayParams)

	local isBlocked = self.weaponState.blocked()
	if newRay then
		local distance = rayDistance - (animBase.CFrame.Position - newRay.Position).Magnitude
		if config.pushBackViewmodel and distance > 0 then
			local tempDist = distance
			if isBlocked then
				tempDist /= 2
			end
			self.pushbackOffset = lerpNumber(self.pushbackOffset, tempDist, 0.2 * 60 * dt)
		else
			self.pushbackOffset = lerpNumber(self.pushbackOffset, 0, 0.2 * 60 * dt)
		end

		if config.raiseGunAtWall then
			if distance >= ws.maxPushback then
				if not isBlocked then
					self.weaponState.holdStance(Enums.HoldStance.High)
					self.weaponState.blocked(true)
					self.state.aiming(false)
				end
			elseif isBlocked then
				self.weaponState.holdStance(Enums.HoldStance.Ready)
				self.weaponState.blocked(false)
				if self.weaponState.aimHeld() and self.state.firstPerson() then
					self.state.aiming(true)
				end
			end
		end
	else
		if isBlocked then
			local holdUpAnim = ws.Animations and ws.Animations.holdUp
			if type(holdUpAnim) == "string" and holdUpAnim ~= "" then
				self.StopAnimation(holdUpAnim, 0.3)
			end
		end
		self.weaponState.blocked(false)
		self.pushbackOffset = lerpNumber(self.pushbackOffset, 0, 0.2 * 60 * dt)
	end
	animBase.CFrame *= CFrame.new(0, 0, self.pushbackOffset)

	local relativeVelocity = humanoidRootPart.CFrame:VectorToObjectSpace(humanoidRootPart.Velocity)
	local targetRollAngle = math.clamp(-relativeVelocity.X, -config.maxStrafeRoll, config.maxStrafeRoll)
	local targetStrafeShift = math.clamp(-relativeVelocity.X / config.sprintSpeed, -1, 1)

	if self.state.aiming() then
		targetRollAngle = 0
		targetStrafeShift *= config.strafeShiftAimMult
	end

	if config.cameraTilting then
		targetRollAngle /= 2
	end
	self.rollAngle = lerpNumber(self.rollAngle, targetRollAngle, 0.07 * dt * 60)
	self.strafeShift = lerpNumber(self.strafeShift, targetStrafeShift, 0.07 * dt * 60)
	animBase.CFrame *= CFrame.Angles(0, math.rad(-self.strafeShift * config.maxStrafeShift), math.rad(self.rollAngle))

	local viewportSize = camera.ViewportSize
	local mouseDelta = UserInputService:GetMouseDelta() / viewportSize

	local tempHipRotation = self.hipRotation
	if config.hipfireMove and (not self.state.aiming() or self.state.aiming() and config.offCenterAiming) then
		local maxX = config.hipfireMoveX
		local maxY = config.hipfireMoveY
		if self.state.aiming() then
			maxX /= 4
			maxY /= 4
		end
		local xRotation = math.clamp(
			tempHipRotation.X - mouseDelta.X * config.hipfireMoveSpeed * dt * 60,
			-maxX,
			maxX
		)
		local yRotation = math.clamp(
			tempHipRotation.Y - mouseDelta.Y * config.hipfireMoveSpeed * dt * 60,
			-maxY,
			maxY
		)
		tempHipRotation = Vector2.new(xRotation, yRotation)
		self.hipRotation = tempHipRotation
	else
		self.hipRotation = self.hipRotation:Lerp(Vector2.zero, 0.3)
	end
	animBase.CFrame *= CFrame.Angles(math.rad(self.hipRotation.Y), math.rad(self.hipRotation.X), 0)

	self.swaySpring:shove(Vector3.new(
		-mouseDelta.X * ws.DeltaInstability.X,
		mouseDelta.Y * ws.DeltaInstability.Y,
		0
	))
	local updatedSway = self.swaySpring:update(dt)
	animBase.CFrame *= CFrame.new(updatedSway.X, updatedSway.Y, 0)

	local tickTime = tick() * 0.15
	local tempDist = config.breathingDist
	if self.state.aiming() then
		tempDist *= config.breathingAimMultiplier
	end
	animBase.CFrame *= CFrame.new(
		tempDist * math.sin(tickTime * config.breathingSpeed / 2),
		tempDist * math.sin(tickTime * config.breathingSpeed),
		0
	)

	local recoilImpact = CFrame.lookAt(
		self.weaponState.RecoilPos.p,
		self.weaponState.RecoilDir.p,
		self.weaponState.RecoilUp.p
	)
	animBase.CFrame *= recoilImpact

	if not self.weaponState.viewmodelVisible() then
		animBase.CFrame *= STORAGE_CFRAME
	end
end

function ViewmodelController.UpdateRender(self: ViewmodelController, dt: number)
	local camera = self.camera
	if self.state.equippedTool() and self.weaponState.gunModel() and camera.CameraType == Enum.CameraType.Custom then
		if self.state.firstPerson() and not self.weaponState.viewmodelVisible() then
			self.RefreshViewmodel()
			self.state.sprinting(false)
		end

		local ws = self.weaponState.wepStats()
		local currentOffset = ws and ws.viewmodelOffset or CFrame.new()
		self:UpdateViewmodelPosition(dt, currentOffset, self.weaponState.sightIndex())
	elseif self.weaponState.viewmodelVisible() and not self.weaponState.equipping() then
		self.weaponState.viewmodelVisible(false)
	end
end

function ViewmodelController.UpdateMovementSway(
	self: ViewmodelController,
	dt: number,
	tempWalkSpeed: number,
	vehicleSeated: boolean
)
	local animBase = self.animBase
	local camera = self.camera
	local humanoid = self.humanoidRootPart.Parent.Humanoid

	local tempDampening = config.bobDampening
	local speedRatio = tempWalkSpeed / config.walkSpeed
	if speedRatio > 0 then
		local difference = tempDampening - (tempDampening / speedRatio)
		tempDampening -= difference / 2
	end
	if self.state.aiming() then
		tempDampening *= config.aimBobDampening
	end

	local tempBobSpeed = config.bobSpeed * speedRatio
	local velocityMag = self.humanoidRootPart.Velocity.Magnitude

	if not humanoid.Sit and velocityMag > 0.1 then
		local moveSway = Vector3.new(
			getSineOffset(tempBobSpeed),
			getSineOffset(tempBobSpeed / 2),
			getSineOffset(tempBobSpeed / 2)
		)
		local ws = self.weaponState.wepStats()
		local moveInstability = (ws and ws.MoveInstability) or 1

		self.moveSpring:shove(moveSway * moveInstability * velocityMag / (tempDampening * tempDampening) * dt * 60)
	end

	local updatedMoveSway = self.moveSpring:update(dt)

	if updatedMoveSway.Magnitude > 0.001 then
		animBase.CFrame = animBase.CFrame:ToWorldSpace(
			CFrame.new(updatedMoveSway.Y, updatedMoveSway.X, 0) * CFrame.Angles(updatedMoveSway.Y * 0.3, 0, updatedMoveSway.Y * 0.8)
		)

		if
			config.cameraMovement
			and self.state.firstPerson()
			and not humanoid.Sit
			and not vehicleSeated
			and camera.CameraType == Enum.CameraType.Custom
		then
			camera.CFrame *= CFrame.Angles(
				math.rad(updatedMoveSway.X / config.cameraBobDampening),
				math.rad(updatedMoveSway.Y / config.cameraBobDampening),
				0
			)
		end
	end
end

return ViewmodelController
