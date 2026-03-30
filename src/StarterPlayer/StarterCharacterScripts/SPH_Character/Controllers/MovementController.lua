local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
    depthOfField = nil,
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
    ChangeDoF = nil,
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
	MovementController.depthOfField = params.depthOfField
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
	MovementController.ChangeDoF = params.ChangeDoF
	MovementController.CancelFiring = params.CancelFiring
end

function MovementController.ChangeWalkSpeed(newSpeed)
	MovementController.targetWalkSpeed = newSpeed
end

function MovementController.ChangeLean(newLean)
	if not config.canLean then return end
	if newLean ~= MovementController.lean then MovementController.PlayCharSound("Lean") end
	MovementController.lean = newLean
	MovementController.playerLean:Fire(newLean)
end

function MovementController.ToggleSprint(toggle)
	State.sprinting = toggle
	MovementController.humanoid.Parent:SetAttribute("Sprinting", toggle)
	if toggle then
		if State.aiming then MovementController.ToggleAiming(false) end
		MovementController.ChangeHoldStance(0)
		UserInputService.MouseDeltaSensitivity = 1
		MovementController.CancelFiring()
		MovementController.PlayAnimation(State.wepStats.sprintAnim, {looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.2})

		if MovementController.depthOfField then
			MovementController.ChangeDoF(0, 6, 0, 0.3)
		end
	elseif State.wepStats then
		MovementController.StopAnimation(State.wepStats.sprintAnim, 0.2)

		if MovementController.depthOfField then
			MovementController.ChangeDoF(0, 0, 0, 0)
		end
	end
end

function MovementController.ChangeStance(change)
	local number = State.stance + change
	local targetCharacterHeight = 0

	if number < 0 then number = 0 elseif number > 2 then number = 2 end

	local preMove = MovementController.moveAnim and MovementController.moveAnim.IsPlaying or false
	local humanoid = MovementController.humanoid

	if number == 0 then -- Walking
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", false)
		if MovementController.moveAnim then MovementController.moveAnim:Stop(config.stanceChangeTime) end
		MovementController.moveAnim = nil
		MovementController.crouchIdleAnim:Stop(config.stanceChangeTime)
		MovementController.ChangeWalkSpeed(config.walkSpeed)
		targetCharacterHeight = (MovementController.rigType == Enum.HumanoidRigType.R6) and 0 or MovementController.baseCharacterHipHeight
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()
		MovementController.PlayCharSound("Uncrouch")
	elseif number == 1 then -- Crouching
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", false)
		if MovementController.moveAnim then MovementController.moveAnim:Stop(config.stanceChangeTime) end
		MovementController.moveAnim = MovementController.crouchMoveAnim
		if MovementController.moving then MovementController.moveAnim:Play(config.stanceChangeTime) end
		MovementController.proneIdleAnim:Stop(config.stanceChangeTime)
		MovementController.crouchIdleAnim:Play(config.stanceChangeTime)
		MovementController.ChangeWalkSpeed(config.crouchSpeed)
		targetCharacterHeight = (MovementController.rigType == Enum.HumanoidRigType.R6) and 0 or MovementController.baseCharacterHipHeight
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()
		MovementController.PlayCharSound(State.stance == 0 and "Crouch" or "Unprone")
	elseif number == 2 then -- Prone
		MovementController.ChangeLean(0)
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", true)
		if MovementController.moveAnim then MovementController.moveAnim:Stop(config.stanceChangeTime) end
		MovementController.moveAnim = MovementController.proneMoveAnim
		MovementController.crouchIdleAnim:Stop(config.stanceChangeTime)
		MovementController.proneIdleAnim:Play(config.stanceChangeTime)
		MovementController.ChangeWalkSpeed(config.proneSpeed)
		targetCharacterHeight = (MovementController.rigType == Enum.HumanoidRigType.R6) and -2 or (MovementController.baseCharacterHipHeight * 0.5)
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime * 1.5), {HipHeight = targetCharacterHeight}):Play()
		MovementController.PlayCharSound("Prone")
	end

	if preMove and MovementController.moveAnim then MovementController.moveAnim:Play() end
	State.stance = number
end

function MovementController.UpdateRender(dt)
	local humanoid = MovementController.humanoid
	if MovementController.moveAnim then MovementController.moveAnim:AdjustSpeed(humanoid.WalkSpeed / 6) end
	
	if humanoid.MoveDirection.Magnitude > 0 and not MovementController.moving then
		MovementController.moving = true
		if MovementController.moveAnim then MovementController.moveAnim:Play(config.stanceChangeTime) end
	elseif humanoid.MoveDirection.Magnitude <= 0 then
		MovementController.moving = false
		if State.sprinting then
			MovementController.ToggleSprint(false)
			MovementController.ChangeWalkSpeed(config.walkSpeed)
		end
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
	elseif State.stance == 0 then
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