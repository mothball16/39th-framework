local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local State = require(script.Parent.CharacterState)

local assets = game.ReplicatedStorage.SPH_Assets
local modules = assets.Modules
local bridgeNet = require(modules.BridgeNet)
local playerLean = bridgeNet.CreateBridge("PlayerLean")

local MovementController = {
    -- state vars
    targetWalkSpeed = config.walkSpeed,
    tempWalkSpeed = config.walkSpeed,
    vehicleSeated = false,
    canJump = true,
    baseCharacterHipHeight = 0,

    -- init vars
    humanoid = nil,
    humanoidRootPart = nil,
    rootJoint = nil,
    rigType = nil,
    script = nil,

    -- Callbacks
    ToggleAiming = nil,
    ChangeHoldStance = nil,
    PlayAnimation = nil,
    StopAnimation = nil,
    AdjustMoveAnimSpeed = nil,
    PlayCharSound = nil,
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
	
	MovementController.ToggleAiming = params.ToggleAiming
	MovementController.ChangeHoldStance = params.ChangeHoldStance
	MovementController.PlayAnimation = params.PlayAnimation
	MovementController.StopAnimation = params.StopAnimation
	MovementController.AdjustMoveAnimSpeed = params.AdjustMoveAnimSpeed
	MovementController.PlayCharSound = params.PlayCharSound
	MovementController.CancelFiring = params.CancelFiring

	Charm.subscribe(State.sprinting, MovementController.UpdateSprint)
	Charm.subscribe(State.stance, MovementController.UpdateStance)
	Charm.subscribe(State.lean, MovementController.UpdateLean)
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
	return notCrawling and notSprinting and notSitting
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

function MovementController.UpdateWalkSpeed(newSpeed)
	MovementController.targetWalkSpeed = newSpeed
end

function MovementController.UpdateSprint(sprinting)
	MovementController.humanoid.Parent:SetAttribute("Sprinting", sprinting)
	if sprinting then
		if State.aiming() then MovementController.ToggleAiming(false) end
		State.stance(0)
		State.lean(0)
		MovementController.UpdateWalkSpeed(config.sprintSpeed)
		MovementController.ChangeHoldStance(0)


		-- TODO: refactor this. movementcontroller shouldnt be handling firing
		MovementController.CancelFiring()
	else
		local newSpeed = MovementController.GetStanceSpeed(State.stance())
		MovementController.UpdateWalkSpeed(newSpeed)
	end
end


function MovementController.UpdateLean(lean, oldLean)
	if not config.canLean or lean == oldLean then
		return
	end
	MovementController.PlayCharSound("Lean")
	playerLean:Fire(lean)
end

function MovementController.UpdateStance(stance, oldStance)
	local targetCharacterHeight = MovementController.GetTargetCharacterHeight(stance)

	local humanoid = MovementController.humanoid
	local newSpeed = MovementController.GetStanceSpeed(stance)
	MovementController.UpdateWalkSpeed(newSpeed)

	if stance == 0 then -- Walking
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", false)
		MovementController.UpdateWalkSpeed(config.walkSpeed)
		MovementController.PlayCharSound("Uncrouch")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()
	elseif stance == 1 then -- Crouching
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", false)
		MovementController.PlayCharSound(oldStance == 0 and "Crouch" or "Unprone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()
	elseif stance == 2 then -- Prone
		MovementController.UpdateLean(0)
		MovementController.script.Parent.MovementLeaning:SetAttribute("DisableLean", true)
		MovementController.PlayCharSound("Prone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime * 1.5), {HipHeight = targetCharacterHeight}):Play()
	end
end

function MovementController.UpdateRender(dt)
	local humanoid = MovementController.humanoid
	if MovementController.AdjustMoveAnimSpeed then MovementController.AdjustMoveAnimSpeed(humanoid.WalkSpeed / 6) end
	
	if humanoid.MoveDirection.Magnitude > 0 and not State.moving() then
		State.moving(true)
	elseif humanoid.MoveDirection.Magnitude <= 0 and State.moving() then
		State.moving(false)
		State.sprinting(false)
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