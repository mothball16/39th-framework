local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local Framework = ReplicatedStorage.Systems.Weapon
local Access = require(Framework.Access)
local config = Access.config
local Enums = require(Framework.Core.Enums)
local WeaponStateModule = require(Framework.State.WeaponState)
local CharacterStateModule = require(Framework.State.CharacterState)
local c0Ref = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0)

local MovementController = {}
MovementController.__index = MovementController

type self = {
	state: CharacterStateModule.CharacterState,
	weaponState: WeaponStateModule.WeaponState,
	targetWalkSpeed: () -> number,
	tempWalkSpeed: number,
	canJump: boolean,
	baseCharacterHipHeight: number,
	lastStanceChange: number,
	humanoid: Humanoid,
	humanoidRootPart: BasePart,
	AdjustMoveAnimSpeed: ((number) -> ())?,
	PlayCharSound: (string) -> (),
}

export type MovementController = typeof(setmetatable({} :: self, MovementController))

local function lerpNumber(number: number, target: number, speed: number): number
	return number + (target - number) * speed
end

local function isInputDown(state: Enum.UserInputState): boolean
	return state == Enum.UserInputState.Begin
end

local function updateCharacterTilt(character: Model, dt: number, localStance: number)
	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart
	local rootJoint

	if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		rootPart = character:FindFirstChild("LowerTorso")
		rootJoint = rootPart and rootPart:FindFirstChild("Root")
	else
		rootPart = character:FindFirstChild("HumanoidRootPart")
		rootJoint = rootPart and rootPart:FindFirstChild("RootJoint")
	end

	if not humanoid or humanoid.Health <= 0 or not rootPart or not rootJoint then
		return
	end
	local moveDirection = rootPart.CFrame:VectorToObjectSpace(humanoid.MoveDirection)

	local tilt = c0Ref:Inverse() * rootJoint.C0

	local target = CFrame.Angles(
		math.rad(-moveDirection.Z) * config.maxLeanAngle,
		math.rad(-moveDirection.X) * config.maxLeanAngle,
		0
	)

	local isLocal = character == Players.LocalPlayer.Character
	local disableLean = isLocal and localStance == 2

	if humanoid.Sit or disableLean or character:GetAttribute("SeatAnim") then
		target = CFrame.new()
	end
	tilt = tilt:Lerp(target, 0.2 ^ (1 / (dt * 60)))
	rootJoint.C0 = c0Ref * tilt
end

function MovementController.new(params: {
	humanoid: Humanoid,
	humanoidRootPart: BasePart,
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,
	AdjustMoveAnimSpeed: ((number) -> ())?,
	PlayCharSound: (string) -> (),
}): MovementController
	local self = setmetatable({
		state = params.state,
		weaponState = params.weaponState,
		targetWalkSpeed = nil :: () -> number,
		tempWalkSpeed = config.walkSpeed,
		canJump = true,
		baseCharacterHipHeight = params.humanoid.HipHeight,
		lastStanceChange = tick(),
		humanoid = params.humanoid,
		humanoidRootPart = params.humanoidRootPart,
		AdjustMoveAnimSpeed = params.AdjustMoveAnimSpeed,
		PlayCharSound = params.PlayCharSound,
	} :: self, MovementController)

	Charm.subscribe(self.state.sprinting, function(sprinting)
		self:SyncSprinting(sprinting)
	end)
	Charm.subscribe(self.state.stance, function(stance, oldStance)
		self:SyncStance(stance, oldStance)
	end)
	Charm.subscribe(self.state.lean, function(lean, oldLean)
		self:SyncLean(lean, oldLean)
	end)
	Charm.subscribe(self.weaponState.holdStance, function(holdStance, oldHoldStance)
		self:SyncHoldStance(holdStance, oldHoldStance)
	end)

	self.targetWalkSpeed = Charm.computed(function()
		if self.state.sprinting() then
			return config.sprintSpeed
		end
		local speed = self:GetStanceSpeed(self.state.stance())
		local ws = self.weaponState.wepStats()

		if ws and self.state.aiming() then
			speed *= ws.aimMoveMultiplier
		end
		return speed
	end)

	-- reset lean when seated
	Charm.effect(function()
		if self.state.seat() then
			self.state.lean(0)
		end
	end)

	self.humanoid.Seated:Connect(function(seated, seatPart)
		self:OnSeated(seated, seatPart)
	end)

	return self
end

function MovementController.OnSeated(self: MovementController, seated: boolean, seatPart: Seat)
	if seated then
		self.state.seat(seatPart)
	else
		self.state.seat(nil)
	end
end



function MovementController.OnSprintIntent(self: MovementController, inputState: Enum.UserInputState, _)
	local notCrawling = self.state.stance() < 2
	if isInputDown(inputState) and notCrawling and self.state.moving() then
		self.state.sprinting(true)
	else
		self.state.sprinting(false)
	end
end

function MovementController.CanLean(self: MovementController): boolean
	local notCrawling = self.state.stance() < 2
	local notSprinting = not self.state.sprinting()
	local notSitting = not self.state.seat()
	return config.canLean and notCrawling and notSprinting and notSitting
end

function MovementController.OnLeanLeftIntent(self: MovementController, inputState: Enum.UserInputState, _)
	if isInputDown(inputState) and self:CanLean() then
		self.state.lean(self.state.lean() == -1 and 0 or -1)
	end
end

function MovementController.OnLeanRightIntent(self: MovementController, inputState: Enum.UserInputState, _)
	if isInputDown(inputState) and self:CanLean() then
		self.state.lean(self.state.lean() == 1 and 0 or 1)
	end
end

function MovementController.OnStanceDownIntent(self: MovementController, inputState: Enum.UserInputState, _)
	if not isInputDown(inputState)
		or tick() - self.lastStanceChange < config.stanceThrottle
		or (not config.canProne and self.state.stance() == 1)
		or self.state.stance() >= 2
		or self.humanoid.Sit then
		return
	end
	self.state.stance(self.state.stance() + 1)
end

function MovementController.OnStanceUpIntent(self: MovementController, inputState: Enum.UserInputState, _)
	if not isInputDown(inputState)
		or tick() - self.lastStanceChange < config.stanceThrottle
		or self.state.stance() == 0
		or self.humanoid.Sit then
		return
	end
	self.state.stance(self.state.stance() - 1)
end

function MovementController.GetTargetCharacterHeight(self: MovementController, stance: number): number
	if stance == 0 then
		return self.state.Parts.IsR6 and 0 or self.baseCharacterHipHeight
	elseif stance == 1 then
		return self.state.Parts.IsR6 and 0 or self.baseCharacterHipHeight
	elseif stance == 2 then
		return self.state.Parts.IsR6 and -2 or (self.baseCharacterHipHeight * 0.5)
	end
	error("Invalid stance: " .. stance)
end

function MovementController.GetStanceSpeed(self: MovementController, stance: number): number
	if stance == 0 then
		return config.walkSpeed
	elseif stance == 1 then
		return config.crouchSpeed
	elseif stance == 2 then
		return config.proneSpeed
	end
	error("Invalid stance: " .. stance)
end

function MovementController.SyncSprinting(self: MovementController, sprinting: boolean)
	if sprinting then
		self.state.aiming(false)
		self.state.stance(0)
		self.state.lean(0)
	end
end

function MovementController.SyncLean(self: MovementController, lean: number, oldLean: number)
	if lean == oldLean then
		return
	end
	self.PlayCharSound("Lean")
end

function MovementController.SyncHoldStance(self: MovementController, holdStance: number, _oldHoldStance: number)
	if holdStance ~= Enums.HoldStance.Ready then
		self.state.sprinting(false)
	end
end

function MovementController.SyncStance(self: MovementController, stance: number, oldStance: number)
	self.lastStanceChange = tick()

	local targetCharacterHeight = self:GetTargetCharacterHeight(stance)
	local humanoid = self.humanoid

	if stance == 0 then
		self.PlayCharSound("Uncrouch")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), { HipHeight = targetCharacterHeight }):Play()
	elseif stance == 1 then
		self.state.sprinting(false)
		self.PlayCharSound(oldStance == 0 and "Crouch" or "Unprone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), { HipHeight = targetCharacterHeight }):Play()
	elseif stance == 2 then
		self.state.lean(0)
		self.state.sprinting(false)
		self.PlayCharSound("Prone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime * 1.5), { HipHeight = targetCharacterHeight }):Play()
	end
end

function MovementController.UpdateCharacterProneAngle(self: MovementController)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.humanoid.Parent }
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local rayResult = workspace:Raycast(self.humanoidRootPart.Position, Vector3.new(0, -2, 0), params)
	if rayResult and rayResult.Instance then
		local dot, uxv =
			self.humanoidRootPart.CFrame.UpVector:Dot(rayResult.Normal),
			self.humanoidRootPart.CFrame.UpVector:Cross(rayResult.Normal)
		local rotateToFloorCFrame = (dot < -0.99999) and CFrame.fromAxisAngle(Vector3.new(1, 0, 0), math.pi)
			or CFrame.new(0, 0, 0, uxv.X, uxv.Y, uxv.Z, 1 + dot)
		self.state.Parts.RootJoint.C0 *= CFrame.Angles(rotateToFloorCFrame.X, rotateToFloorCFrame.Y, rotateToFloorCFrame.Z)
	end
end

function MovementController.UpdateRender(self: MovementController, dt: number)
	local humanoid = self.humanoid
	if self.AdjustMoveAnimSpeed then
		self.AdjustMoveAnimSpeed(humanoid.WalkSpeed / 6)
	end

	if humanoid.MoveDirection.Magnitude > 0 and not self.state.moving() then
		self.state.moving(true)
	elseif humanoid.MoveDirection.Magnitude <= 0 and self.state.moving() then
		self.state.moving(false)
	end

	local xOffset = self.state.lean() * 1

	if self.state.Parts.IsR6 then
		self.state.Parts.RootJoint.C1 = self.state.Parts.RootJoint.C1:Lerp(
			CFrame.new(-xOffset / 2, 0, 0) * CFrame.Angles(math.rad(90), math.rad(180) + math.rad(17 * self.state.lean()), 0),
			0.1 * dt * 60
		)
	else
		self.state.Parts.RootJoint.C1 = self.state.Parts.RootJoint.C1:Lerp(
			CFrame.new(-xOffset / 2, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0) + math.rad(17 * self.state.lean())),
			0.1 * dt * 60
		)
	end

	if config.movementLeaning then
		local localCharacter = Players.LocalPlayer.Character
		updateCharacterTilt(localCharacter, dt, self.state.stance())

		if config.replicateMovementLeaning then
			for _, otherCharacter in CollectionService:GetTagged("SPH_Character") do
				if otherCharacter ~= localCharacter then
					updateCharacterTilt(otherCharacter, dt, 0)
				end
			end
		end
	end
end

function MovementController.UpdateHeartbeat(self: MovementController, dt: number)
	local humanoid = self.humanoid
	self.tempWalkSpeed = self.targetWalkSpeed()

	if humanoid.Health < 30 and config.lowHealthEffects then
		self.tempWalkSpeed *= humanoid.Health / 30
	end

	humanoid.WalkSpeed = lerpNumber(humanoid.WalkSpeed, self.tempWalkSpeed, 0.2 * dt * 60)

	if self.state.stance() == 2 and config.proneAngle then
		self:UpdateCharacterProneAngle()
	end
end

function MovementController.Jump(self: MovementController)
	if self.humanoid.Sit then
		self.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	elseif self.state.stance() == 0 then
		if self.humanoid.FloorMaterial == Enum.Material.Air then
			return
		end
		if self.canJump then
			self.canJump = false
			self.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.wait(config.jumpCooldown)
			self.canJump = true
		else
			self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
	else
		self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

return MovementController
