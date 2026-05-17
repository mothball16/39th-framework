local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local Types = require(Framework.Core.ConfigurationTypes)
local config = Access.config
local Enums = require(Framework.Core.Enums)
local WeaponStateModule = require(Framework.State.WeaponState)
local CharacterStateModule = require(Framework.State.CharacterState)
local c0Ref = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, -0)

local MC = {
	-- state
	state = nil :: CharacterStateModule.CharacterState,
	weaponState = nil :: WeaponStateModule.WeaponState,

    -- state vars
	targetWalkSpeed = nil,
    tempWalkSpeed = config.walkSpeed,
    canJump = true,
    baseCharacterHipHeight = 0,
	lastStanceChange = tick(),

    -- init vars
    humanoid = nil,
    humanoidRootPart = nil,
    rootJoint = nil,
    rigType = nil,

    -- callbacks
    AdjustMoveAnimSpeed = nil,
    PlayCharSound = nil,
}

local function LerpNumber(number, target, speed)
	return number + (target - number) * speed
end


function MC.Initialize(params)
	MC.humanoid = params.humanoid
	MC.humanoidRootPart = params.humanoidRootPart
	MC.rootJoint = params.rootJoint
	MC.baseCharacterHipHeight = params.humanoid.HipHeight
	MC.AdjustMoveAnimSpeed = params.AdjustMoveAnimSpeed
	MC.PlayCharSound = params.PlayCharSound
	MC.weaponState = params.weaponState
	MC.state = params.state

	Charm.subscribe(MC.state.sprinting, MC.SyncSprinting)
	Charm.subscribe(MC.state.stance, MC.SyncStance)
	Charm.subscribe(MC.state.lean, MC.SyncLean)
	Charm.subscribe(MC.weaponState.holdStance, MC.SyncHoldStance)

	MC.targetWalkSpeed = Charm.computed(function()
		if MC.state.sprinting() then
			return config.sprintSpeed
		end
		local speed = MC.GetStanceSpeed(MC.state.stance())
		local ws = MC.weaponState.wepStats()

		if ws and MC.state.aiming() then
			speed *= ws.aimMoveMultiplier
		end
		return speed
	end)
end

--#region ----------------------------[intent]----------------------------
local function isInputDown(state)
	return state == Enum.UserInputState.Begin
end
function MC.OnSprintIntent(inputState, _)
	local notCrawling = MC.state.stance() < 2
	if isInputDown(inputState) and notCrawling and MC.state.moving() then -- Begin MovementController.state.sprinting
		MC.state.sprinting(true)
	else
		MC.state.sprinting(false)
	end
end

local function _canLean()
	local notCrawling = MC.state.stance() < 2
	local notSprinting = not MC.state.sprinting()
	local notSitting = not MC.humanoid.Sit
	return config.canLean and notCrawling and notSprinting and notSitting
end

function MC.OnLeanLeftIntent(inputState, _)
	if isInputDown(inputState) and _canLean() then
		MC.state.lean(MC.state.lean() == -1 and 0 or -1)
	end
end

function MC.OnLeanRightIntent(inputState, _)
	if isInputDown(inputState) and _canLean() then
		MC.state.lean(MC.state.lean() == 1 and 0 or 1)
	end
end

function MC.OnStanceDownIntent(inputState, _)
	if not isInputDown(inputState)
	or tick() - MC.lastStanceChange < config.stanceThrottle
	or ((not config.canProne) and MC.state.stance() == 1) -- char can't prone and is already crouched
	or MC.state.stance() >= 2 -- char already crawling - can't go further down
	or MC.humanoid.Sit then -- char can't change stance, currently sitting
		return
	end
	MC.state.stance(MC.state.stance() + 1)
end

function MC.OnStanceUpIntent(inputState, _)
	if not isInputDown(inputState)
	or tick() - MC.lastStanceChange < config.stanceThrottle
	or MC.state.stance() == 0
	or MC.humanoid.Sit then
		return
	end
	MC.state.stance(MC.state.stance() - 1)
end
--#endregion ---------------------------------------------------------------
function MC.GetTargetCharacterHeight(stance)
	if stance == 0 then
		return MC.state.Parts.IsR6 and 0 or MC.baseCharacterHipHeight
	elseif stance == 1 then
		return MC.state.Parts.IsR6 and 0 or MC.baseCharacterHipHeight
	elseif stance == 2 then
		return MC.state.Parts.IsR6 and -2 or (MC.baseCharacterHipHeight * 0.5)
	end
	error("Invalid stance: " .. stance)
end

function MC.GetStanceSpeed(stance)
	if stance == 0 then
		return config.walkSpeed
	elseif stance == 1 then
		return config.crouchSpeed
	elseif stance == 2 then
		return config.proneSpeed
	end
	error("Invalid stance: " .. stance)
end



function MC.SyncSprinting(sprinting)
	if sprinting then
		MC.state.aiming(false)
		MC.state.stance(0)
		MC.state.lean(0)
	end
end


function MC.SyncLean(lean, oldLean)
	if lean == oldLean then
		return
	end
	MC.PlayCharSound("Lean")
end

function MC.SyncHoldStance(holdStance, oldHoldStance)
	if holdStance ~= Enums.HoldStance.Ready then
		MC.state.sprinting(false)
		return
	end
end

function MC.SyncStance(stance, oldStance)
	MC.lastStanceChange = tick()

	local targetCharacterHeight = MC.GetTargetCharacterHeight(stance)

	local humanoid = MC.humanoid

	if stance == 0 then -- Walking
		MC.PlayCharSound("Uncrouch")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()
	elseif stance == 1 then -- Crouching
		MC.state.sprinting(false)
		MC.PlayCharSound(oldStance == 0 and "Crouch" or "Unprone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime), {HipHeight = targetCharacterHeight}):Play()
	elseif stance == 2 then -- Prone
		MC.state.lean(0)
		MC.state.sprinting(false)
		MC.PlayCharSound("Prone")
		TweenService:Create(humanoid, TweenInfo.new(config.stanceChangeTime * 1.5), {HipHeight = targetCharacterHeight}):Play()
	end
end

function MC.UpdateCharacterProneAngle()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {MC.humanoid.Parent}
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local rayResult = workspace:Raycast(MC.humanoidRootPart.Position, Vector3.new(0, -2, 0), params)
	if rayResult and rayResult.Instance then
		local dot, uxv = MC.humanoidRootPart.CFrame.UpVector:Dot(rayResult.Normal), MC.humanoidRootPart.CFrame.UpVector:Cross(rayResult.Normal)
		local rotateToFloorCFrame = (dot < -0.99999) and CFrame.fromAxisAngle(Vector3.new(1,0,0), math.pi) or CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
		MC.rootJoint.C0 *= CFrame.Angles(rotateToFloorCFrame.X, rotateToFloorCFrame.Y, rotateToFloorCFrame.Z)
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
	local disableLean = isLocal and (MC.state.stance() == 2) or false
	
	if humanoid.Sit or disableLean or character:GetAttribute("SeatAnim") then target = CFrame.new() end
	tilt = tilt:Lerp(target, 0.2 ^ (1 / (dt * 60)))
	rootJoint.C0 = c0Ref * tilt
end

function MC.UpdateRender(dt)
	local humanoid = MC.humanoid
	if MC.AdjustMoveAnimSpeed then MC.AdjustMoveAnimSpeed(humanoid.WalkSpeed / 6) end
	
	if humanoid.MoveDirection.Magnitude > 0 and not MC.state.moving() then
		MC.state.moving(true)
	elseif humanoid.MoveDirection.Magnitude <= 0 and MC.state.moving() then
		MC.state.moving(false)
	end

	-- lean logic
	local xOffset = MC.state.lean() * 1

	if MC.state.Parts.IsR6 then
		MC.rootJoint.C1 = MC.rootJoint.C1:Lerp(CFrame.new(-xOffset / 2, 0, 0)
		* CFrame.Angles(math.rad(90), math.rad(180) + math.rad(17 * MC.state.lean()), 0), 0.1 * dt * 60)
	else
		MC.rootJoint.C1 = MC.rootJoint.C1:Lerp(CFrame.new(-xOffset / 2, 0, 0)
		* CFrame.Angles(math.rad(0), math.rad(0), math.rad(0) + math.rad(17 * MC.state.lean())), 0.1 * dt * 60)
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

function MC.UpdateHeartbeat(dt)
	local humanoid = MC.humanoid
	MC.tempWalkSpeed = MC.targetWalkSpeed()


	if humanoid.Health < 30 and config.lowHealthEffects then
		MC.tempWalkSpeed *= humanoid.Health / 30
	end

	humanoid.WalkSpeed = LerpNumber(humanoid.WalkSpeed, MC.tempWalkSpeed, 0.2 * dt * 60)

	if MC.state.stance() == 2 and config.proneAngle then
		MC.UpdateCharacterProneAngle()
	end
end

function MC.Jump()
	if MC.humanoid.Sit then
		MC.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	elseif MC.state.stance() == 0 then
		if MC.humanoid.FloorMaterial == Enum.Material.Air then return end
		if MC.canJump then
			MC.canJump = false
			MC.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.wait(config.jumpCooldown)
			MC.canJump = true
		else
			MC.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
	else
		MC.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

return MC