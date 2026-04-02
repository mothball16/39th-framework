local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local State = require(script.Parent.CharacterState)
local config = require(ReplicatedStorage:WaitForChild("SPH_Assets").GameConfig)
local AnimationController = {}

AnimationController.loadedAnims = {}
AnimationController.vmAnimator = nil
AnimationController.characterAnimator = nil
AnimationController.animationsFolder = nil

AnimationController.crouchIdleAnim = nil
AnimationController.crouchMoveAnim = nil
AnimationController.proneIdleAnim = nil
AnimationController.proneMoveAnim = nil
AnimationController.moveAnim = nil

AnimationController.OnKeyframeReached = nil
AnimationController.OnAnimationStopped = nil

local function _getAnimationTracks(animName, parameters, animType)
	if AnimationController.loadedAnims[animName] then
		return AnimationController.loadedAnims[animName]
	end

	if not animName or not AnimationController.animationsFolder:FindFirstChild(animName) then
		return nil
	end

	local animAsset = AnimationController.animationsFolder[animName]
	parameters = parameters or {}

	local vmTrack = AnimationController.vmAnimator:LoadAnimation(animAsset)
	vmTrack.Looped = parameters.looped or false
	vmTrack.Priority = parameters.priority or Enum.AnimationPriority.Action

	local tpTrack = AnimationController.characterAnimator:LoadAnimation(animAsset)
	tpTrack.Looped = parameters.looped or false
	tpTrack.Priority = parameters.priority or Enum.AnimationPriority.Action

	vmTrack.KeyframeReached:Connect(function(keyframeName)
		if AnimationController.OnKeyframeReached then
			AnimationController.OnKeyframeReached(animName, keyframeName, vmTrack, animType)
		end
	end)

	vmTrack.Stopped:Connect(function()
		if AnimationController.OnAnimationStopped then
			AnimationController.OnAnimationStopped(animName, vmTrack, animType)
		end
	end)

	local tracks = { vm = vmTrack, tp = tpTrack }
	AnimationController.loadedAnims[animName] = tracks
	return tracks
end

function AnimationController.Initialize(params)
	AnimationController.vmAnimator = params.vmAnimator
	AnimationController.characterAnimator = params.characterAnimator
	AnimationController.animationsFolder = params.animationsFolder
	AnimationController.OnKeyframeReached = params.OnKeyframeReached
	AnimationController.OnAnimationStopped = params.OnAnimationStopped

	AnimationController.crouchIdleAnim = State.Parts.Humanoid.Animator:LoadAnimation(params.animationsFolder.Crouch_Idle)
	AnimationController.crouchIdleAnim.Looped = true
	AnimationController.crouchIdleAnim.Priority = Enum.AnimationPriority.Idle

	AnimationController.crouchMoveAnim = State.Parts.Humanoid.Animator:LoadAnimation(params.animationsFolder.Crouch_Move)
	AnimationController.crouchMoveAnim.Looped = true
	AnimationController.crouchMoveAnim.Priority = Enum.AnimationPriority.Movement

	AnimationController.proneIdleAnim = State.Parts.Humanoid.Animator:LoadAnimation(params.animationsFolder.Prone_Idle)
	AnimationController.proneIdleAnim.Looped = true
	AnimationController.proneIdleAnim.Priority = Enum.AnimationPriority.Idle

	AnimationController.proneMoveAnim = State.Parts.Humanoid.Animator:LoadAnimation(params.animationsFolder.Prone_Move)
	AnimationController.proneMoveAnim.Looped = true
	AnimationController.proneMoveAnim.Priority = Enum.AnimationPriority.Movement

	Charm.subscribe(State.sprinting, AnimationController.OnSprintChanged)
	Charm.subscribe(State.stance, AnimationController.OnStanceChanged)
	Charm.subscribe(State.moving, AnimationController.OnMovingChanged)
end

function AnimationController.OnStanceChanged(stance, oldStance)
	if AnimationController.moveAnim then AnimationController.moveAnim:Stop(config.stanceChangeTime) end

	if stance == 0 then -- Walking
		AnimationController.moveAnim = nil
		AnimationController.crouchIdleAnim:Stop(config.stanceChangeTime)
		AnimationController.proneIdleAnim:Stop(config.stanceChangeTime)
	elseif stance == 1 then -- Crouching
		AnimationController.moveAnim = AnimationController.crouchMoveAnim
		if State.moving() then AnimationController.moveAnim:Play(config.stanceChangeTime) end
		AnimationController.proneIdleAnim:Stop(config.stanceChangeTime)
		AnimationController.crouchIdleAnim:Play(config.stanceChangeTime)
	elseif stance == 2 then -- Prone
		AnimationController.moveAnim = AnimationController.proneMoveAnim
		AnimationController.crouchIdleAnim:Stop(config.stanceChangeTime)
		AnimationController.proneIdleAnim:Play(config.stanceChangeTime)
		if State.moving() then AnimationController.moveAnim:Play(config.stanceChangeTime) end
	end
end

function AnimationController.OnMovingChanged(moving)
	if moving then
		if AnimationController.moveAnim then AnimationController.moveAnim:Play(config.stanceChangeTime) end
	else
		if AnimationController.moveAnim then AnimationController.moveAnim:Stop(config.stanceChangeTime) end
	end
end

function AnimationController.OnSprintChanged(sprinting)
	if sprinting then
		if State.wepStats and State.wepStats.sprintAnim then
			AnimationController.PlayAnimation(State.wepStats.sprintAnim, {looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.2})
		end
	else
		if State.wepStats and State.wepStats.sprintAnim then
			AnimationController.StopAnimation(State.wepStats.sprintAnim, 0.2)
		end
	end
end

function AnimationController.StopAnimation(animName: string, transTime: number)
	local tracks = AnimationController.loadedAnims[animName]
	if tracks then
		tracks.vm:Stop(transTime)
		tracks.tp:Stop(transTime)
	end
end

function AnimationController.PlayAnimation(animName: string, parameters: table, animType: string, preload: boolean)
	parameters = parameters or {}
	local tracks = _getAnimationTracks(animName, parameters, animType)

	if tracks and not preload then
		local transSpeed = parameters.transSpeed
		local speed = parameters.speed or 1

		tracks.vm:Play(transSpeed)
		tracks.vm:AdjustSpeed(speed)
		tracks.tp:Play(transSpeed)
		tracks.tp:AdjustSpeed(speed)
	end

	return tracks and tracks.vm
end

function AnimationController.StopAll()
	if AnimationController.vmAnimator then
		for _, track in ipairs(AnimationController.vmAnimator:GetPlayingAnimationTracks()) do
			track:Stop()
		end
	end
	if AnimationController.characterAnimator then
		for _, track in ipairs(AnimationController.characterAnimator:GetPlayingAnimationTracks()) do
			track:Stop()
		end
	end
end

function AnimationController.AdjustMoveAnimSpeed(speed: number)
	if AnimationController.moveAnim then
		AnimationController.moveAnim:AdjustSpeed(speed)
	end
end

return AnimationController