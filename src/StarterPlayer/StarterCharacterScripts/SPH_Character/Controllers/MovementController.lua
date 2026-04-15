local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local sph = require(ReplicatedStorage.SPH_Framework.Core.GameAccess)
local assets = sph.assets
local config = sph.config
local State = require(script.Parent.Parent.State.CharacterState)
local WeaponState = require(script.Parent.Parent.State.WeaponState)
local Types = require(sph.framework.Core.ConfigurationTypes)
local c0Ref = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0)

local MovementController = {
    -- state vars
	targetWalkSpeed = nil,
    tempWalkSpeed = config.walkSpeed,
    canJump = true,
    baseCharacterHipHeight = 0,

    -- init vars
    humanoid = nil,
    humanoidRootPart = nil,
    rootJoint = nil,
    rigType = nil,
    script = nil,

    -- Callbacks
    AdjustMoveAnimSpeed = nil,
    PlayCharSound = nil,
}


local function LerpNumber(number, target, speed)
	return number + (target - number) * speed
end


function MovementController.Initialize(params)
	MovementController.humanoid = params.humanoid
	MovementController.humanoidRootPart = params.humanoidRootPart
	MovementController.rootJoint = params.rootJoint
	MovementController.rigType = params.rigType
	MovementController.script = params.script
	MovementController.baseCharacterHipHeight = params.humanoid.HipHeight
	MovementController.AdjustMoveAnimSpeed = params.AdjustMoveAnimSpeed
	MovementController.PlayCharSound = params.PlayCharSound

	Charm.subscribe(State.sprinting, MovementController.SyncSprinting)
	Charm.subscribe(State.stance, MovementController.SyncStance)
	Charm.subscribe(State.lean, MovementController.SyncLean)
	Charm.subscribe(WeaponState.holdStance, MovementController.SyncHoldStance)

	MovementController.targetWalkSpeed = Charm.computed(function()
		if State.sprinting() then
			return config.sprintSpeed
		end
		local speed = MovementController.GetStanceSpeed(State.stance())
		local ws: Types.WeaponStats = WeaponState.wepStats()

		if ws and State.aiming() then
			speed *= ws.aimMoveMultiplier
		end
		return speed
	end)
end

--#region ----------------------------[intent]----------------------------
local function isInputDown(state)
	return state == Enum.UserInputState.Begin
end
function MovementController.OnSprintIntent(inputState, _)
	local notCrawling = State.stance() < 2
	if isInputDown(inputState) and notCrawling and State.moving() then -- Begin State.sprinting
		State.sprinting(true)
	else
		State.sprinting(false)
	end
end

local function _canLean()
	local notCrawling = State.stance() < 2
	local notSprinting = not State.sprinting()
	local notSitting = not State.Parts.Humanoid.Sit
	return config.canLean and notCrawling and notSprinting and notSitting
end

function MovementController.OnLeanLeftIntent(inputState, _)
	if isInputDown(inputState) and _canLean() then
		State.lean(State.lean() == -1 and 0 or -1)
	end
end

function MovementController.OnLeanRightIntent(inputState, _)
	if isInputDown(inputState) and _canLean() then
		State.lean(State.lean() == 1 and 0 or 1)
	end
end

function MovementController.OnStanceDownIntent(inputState, _)
	if not isInputDown(inputState)
	or ((not config.canProne) and State.stance() == 1) -- char can't prone and is already crouched
	or State.stance() >= 2 -- char already crawling - can't go further down
	or State.Parts.Humanoid.Sit then -- char can't change stance, currently sitting
		return
	end
	State.stance(State.stance() + 1)
end

function MovementController.OnStanceUpIntent(inputState, _)
	if not isInputDown(inputState)
	or State.stance() == 0
	or State.Parts.Humanoid.Sit then
		return
	end
	State.stance(State.stance() - 1)
end
--#endregion ---------------------------------------------------------------
function MovementController.GetTargetCharacterHeight(stance)
	if stance == 0 then
		return State.Parts.IsR6 and 0 or MovementController.baseCharacterHipHeight
	elseif stance == 1 then
		return State.Parts.IsR6 and 0 or MovementController.baseCharacterHipHeight
	elseif stance == 2 then
		return State.Parts.IsR6 and -2 or (MovementController.baseCharacterHipHeight * 0.5)
	end
end

function MovementController.GetStanceSpeed(stance)
	if stance == 0 then
		return config.walkSpeed
	elseif stance == 1 then
		return config.crouchSpeed
	elseif stance == 2 then
		return config.proneSpeed
	end
end



function MovementController.SyncSprinting(sprinting)
	if sprinting then
		State.aiming(false)
		State.stance(0)
		State.lean(0)
	end
end


function MovementController.SyncLean(lean, oldLean)
	if lean == oldLean then
		return
	end
	MovementController.PlayCharSound("Lean")
end

function MovementController.SyncHoldStance(holdStance, oldHoldStance)
	if holdStance ~= sph.enums.HoldStance.Ready then
		State.sprinting(false)
		return
	end
end

function MovementController.SyncStance(stance, oldStance)
	local targetCharacterHeight = MovementController.GetTargetCharacterHeight(stance)

	local humanoid = MovementController.humanoid

	if stance == 0 then -- Walking
		MovementController.PlayCharSound("Uncrouch")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()
	elseif stance == 1 then -- Crouching
		State.sprinting(false)
		MovementController.PlayCharSound(oldStance == 0 and "Crouch" or "Unprone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()
	elseif stance == 2 then -- Prone
		State.lean(0)
		State.sprinting(false)
		MovementController.PlayCharSound("Prone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime * 1.5), {HipHeight = targetCharacterHeight}):Play()
	end
end

function MovementController.UpdateCharacterProneAngle()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {State.Parts.Character}
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local rayResult = workspace:Raycast(State.Parts.HRP.Position, Vector3.new(0, -2, 0), params)
	if rayResult and rayResult.Instance then
		local dot, uxv = State.Parts.HRP.CFrame.UpVector:Dot(rayResult.Normal), State.Parts.HRP.CFrame.UpVector:Cross(rayResult.Normal)
		local rotateToFloorCFrame = (dot < -0.99999) and CFrame.fromAxisAngle(Vector3.new(1,0,0), math.pi) or CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
		State.Parts.RootJoint.C0 *= CFrame.Angles(rotateToFloorCFrame.X, rotateToFloorCFrame.Y, rotateToFloorCFrame.Z)
	end
end

local function UpdateCharacterTilt(character, dt)
	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart
	local rootJoint
	
	if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R6 then -- finds the rig type and sets the root accordingly I KNOW THIS IS WRONG LEAVE IT UNTIL I FIGURE OUT THE MATH BELOW OR ITLL MAKE YOU HORIZONTAL
		rootPart = character:FindFirstChild("LowerTorso")
		rootJoint = rootPart and rootPart:FindFirstChild("Root")
	else
		rootPart = character:FindFirstChild("HumanoidRootPart")
		rootJoint = rootPart and rootPart:FindFirstChild("RootJoint")
	end
	
	if not humanoid or humanoid.Health <= 0 or not rootPart or not rootJoint then return end
	local MoveDirection = rootPart.CFrame:VectorToObjectSpace(humanoid.MoveDirection)

	local tilt = c0Ref:Inverse() * rootJoint.C0

	local target = CFrame.Angles(math.rad(-MoveDirection.Z) * config.maxLeanAngle, math.rad(-MoveDirection.X) * config.maxLeanAngle, 0)
	
	local isLocal = character == Players.LocalPlayer.Character
	local disableLean = isLocal and (State.stance() == 2) or false
	
	if humanoid.Sit or disableLean or character:GetAttribute("SeatAnim") then target = CFrame.new() end
	tilt = tilt:Lerp(target, 0.2 ^ (1 / (dt * 60)))
	rootJoint.C0 = c0Ref * tilt
end

function MovementController.UpdateRender(dt)
	local humanoid = MovementController.humanoid
	if MovementController.AdjustMoveAnimSpeed then MovementController.AdjustMoveAnimSpeed(humanoid.WalkSpeed / 6) end
	
	if humanoid.MoveDirection.Magnitude > 0 and not State.moving() then
		State.moving(true)
	elseif humanoid.MoveDirection.Magnitude <= 0 and State.moving() then
		State.moving(false)
	end

	-- lean logic
	local xOffset = State.lean() * 1

	if State.Parts.IsR6 then
		State.Parts.RootJoint.C1 = State.Parts.RootJoint.C1:Lerp(CFrame.new(-xOffset / 2, 0, 0)
		* CFrame.Angles(math.rad(90), math.rad(180) + math.rad(17 * State.lean()), 0), 0.1 * dt * 60)
	else
		State.Parts.RootJoint.C1 = State.Parts.RootJoint.C1:Lerp(CFrame.new(-xOffset / 2, 0, 0)
		* CFrame.Angles(math.rad(0), math.rad(0), math.rad(0) + math.rad(17 * State.lean())), 0.1 * dt * 60)
	end


	if config.movementLeaning then
		UpdateCharacterTilt(Players.LocalPlayer.Character, dt)

		-- TODO: this is probably an optimization issue. consider caching and determining how this would work under StreamingEnabled
		if config.replicateMovementLeaning then
			for _, character in ipairs(CollectionService:GetTagged("SPH_Character")) do
				if character ~= Players.LocalPlayer.Character then
					UpdateCharacterTilt(character, dt)
				end
			end
		end
	end
end

function MovementController.UpdateHeartbeat(dt)
	local humanoid = MovementController.humanoid
	MovementController.tempWalkSpeed = MovementController.targetWalkSpeed()

	if MovementController.script:GetAttribute("WalkspeedOverrideToggle") then
		MovementController.tempWalkSpeed = MovementController.script:GetAttribute("WalkspeedOverride")
	end

	if humanoid.Health < 30 and config.lowHealthEffects then
		MovementController.tempWalkSpeed *= humanoid.Health / 30
	end

	humanoid.WalkSpeed = LerpNumber(humanoid.WalkSpeed, MovementController.tempWalkSpeed, 0.2 * dt * 60)

	if State.stance() == 2 and config.proneAngle then
		MovementController.UpdateCharacterProneAngle()
	end
end

function MovementController.Jump()
	if MovementController.humanoid.Sit then
		MovementController.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	elseif State.stance() == 0 then
		if MovementController.humanoid.FloorMaterial == Enum.Material.Air then return end
		if MovementController.canJump then
			MovementController.canJump = false
			MovementController.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.wait(config.jumpCooldown)
			MovementController.canJump = true
		else
			MovementController.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
	else
		MovementController.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

return MovementController