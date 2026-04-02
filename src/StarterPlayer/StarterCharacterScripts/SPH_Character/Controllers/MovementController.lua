local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local State = require(script.Parent.CharacterState)

local MovementController = {
    -- state vars
    targetWalkSpeed = config.walkSpeed,
    tempWalkSpeed = config.walkSpeed,
    lean = 0,
    vehicleSeated = false,
    canJump = true,
    moving = false,
    baseCharacterHipHeight = 0,
    moveAnim = nil,

    -- init vars
    humanoid = nil,
    humanoidRootPart = nil,
    rootJoint = nil,
    rigType = nil,
    crouchIdleAnim = nil,
    crouchMoveAnim = nil,
    proneIdleAnim = nil,
    proneMoveAnim = nil,
    script = nil,

    -- Callbacks
    ToggleAiming = nil,
    ChangeHoldStance = nil,
    PlayAnimation = nil,
    StopAnimation = nil,
    PlayCharSound = nil,
    playerLean = nil,
    CancelFiring = nil,
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
	
	MovementController.crouchIdleAnim = params.crouchIdleAnim
	MovementController.crouchMoveAnim = params.crouchMoveAnim
	MovementController.proneIdleAnim = params.proneIdleAnim
	MovementController.proneMoveAnim = params.proneMoveAnim
	
	MovementController.ToggleAiming = params.ToggleAiming
	MovementController.ChangeHoldStance = params.ChangeHoldStance
	MovementController.PlayAnimation = params.PlayAnimation
	MovementController.StopAnimation = params.StopAnimation
	MovementController.PlayCharSound = params.PlayCharSound
	MovementController.playerLean = params.playerLean
	MovementController.CancelFiring = params.CancelFiring

	Charm.subscribe(State.sprinting, MovementController.UpdateSprint)
	Charm.subscribe(State.stance, MovementController.UpdateStance)
end

--#region ----------------------------[intent]----------------------------
local function isInputDown(state)
	return state == Enum.UserInputState.Begin
end
function MovementController.OnSprintIntent(inputState, _)
	local notCrawling = State.stance() < 2
	if isInputDown(inputState) and notCrawling and MovementController.moving then -- Begin State.sprinting
		State.sprinting(true)
	else
		State.sprinting(false)
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

function MovementController.UpdateWalkSpeed(newSpeed)
	MovementController.targetWalkSpeed = newSpeed
end

function MovementController.UpdateSprint(sprinting)
	MovementController.humanoid.Parent:SetAttribute("Sprinting", sprinting)
	if sprinting then
		if State.aiming() then MovementController.ToggleAiming(false) end
		State.stance(0)

		MovementController.UpdateWalkSpeed(config.sprintSpeed)
		MovementController.ChangeLean(0)
		MovementController.ChangeHoldStance(0)


		-- TODO: refactor this. movementcontroller shouldnt be handling firing
		MovementController.CancelFiring()
	else
		local newSpeed = MovementController.GetStanceSpeed(State.stance())
		MovementController.UpdateWalkSpeed(newSpeed)
	end
end




function MovementController.ChangeLean(newLean)
	if not config.canLean then return end
	if newLean ~= MovementController.lean then MovementController.PlayCharSound("Lean") end
	MovementController.lean = newLean
	MovementController.playerLean:Fire(newLean)
end

function MovementController.UpdateStance(stance, oldStance)
	local targetCharacterHeight = MovementController.GetTargetCharacterHeight(stance)

	local preMove = MovementController.moveAnim and MovementController.moveAnim.IsPlaying or false
	local humanoid = MovementController.humanoid
	local newSpeed = MovementController.GetStanceSpeed(stance)
	MovementController.UpdateWalkSpeed(newSpeed)

	if stance == 0 then -- Walking
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", false)
		MovementController.UpdateWalkSpeed(config.walkSpeed)
		MovementController.PlayCharSound("Uncrouch")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()

		-- TODO: move this to AnimationController
		if MovementController.moveAnim then MovementController.moveAnim:Stop(config.stanceChangeTime) end
		MovementController.moveAnim = nil
		MovementController.crouchIdleAnim:Stop(config.stanceChangeTime)
	elseif stance == 1 then -- Crouching
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", false)
		MovementController.PlayCharSound(oldStance == 0 and "Crouch" or "Unprone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()


		-- TODO: move this to AnimationController
		if MovementController.moveAnim then MovementController.moveAnim:Stop(config.stanceChangeTime) end
		MovementController.moveAnim = MovementController.crouchMoveAnim
		if MovementController.moving then MovementController.moveAnim:Play(config.stanceChangeTime) end
		MovementController.proneIdleAnim:Stop(config.stanceChangeTime)
		MovementController.crouchIdleAnim:Play(config.stanceChangeTime)
	elseif stance == 2 then -- Prone
		MovementController.ChangeLean(0)
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", true)
		MovementController.PlayCharSound("Prone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime * 1.5), {HipHeight = targetCharacterHeight}):Play()


		-- TODO: move this to AnimationController
		if MovementController.moveAnim then MovementController.moveAnim:Stop(config.stanceChangeTime) end
		MovementController.moveAnim = MovementController.proneMoveAnim
		MovementController.crouchIdleAnim:Stop(config.stanceChangeTime)
		MovementController.proneIdleAnim:Play(config.stanceChangeTime)
	end

	if preMove and MovementController.moveAnim then MovementController.moveAnim:Play() end
end

function MovementController.UpdateRender(dt)
	local humanoid = MovementController.humanoid
	if MovementController.moveAnim then MovementController.moveAnim:AdjustSpeed(humanoid.WalkSpeed / 6) end
	
	if humanoid.MoveDirection.Magnitude > 0 and not MovementController.moving then
		MovementController.moving = true
		if MovementController.moveAnim then MovementController.moveAnim:Play(config.stanceChangeTime) end
	elseif humanoid.MoveDirection.Magnitude <= 0 then
		MovementController.moving = false
		State.sprinting(false)
		if MovementController.moveAnim then MovementController.moveAnim:Stop(config.stanceChangeTime) end
	end
end

function MovementController.UpdateHeartbeat(dt)
	local humanoid = MovementController.humanoid
	MovementController.tempWalkSpeed = MovementController.targetWalkSpeed

	if MovementController.script:GetAttribute("WalkspeedOverrideToggle") then
		MovementController.tempWalkSpeed = MovementController.script:GetAttribute("WalkspeedOverride")
	end

	if humanoid.Health < 30 and config.lowHealthEffects then
		MovementController.tempWalkSpeed *= humanoid.Health / 30
	end

	humanoid.WalkSpeed = LerpNumber(humanoid.WalkSpeed, MovementController.tempWalkSpeed, 0.2 * dt * 60)
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