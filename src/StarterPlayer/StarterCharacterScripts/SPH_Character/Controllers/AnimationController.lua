local AnimationController = {}

AnimationController.loadedAnims = {}
AnimationController.vmAnimator = nil
AnimationController.characterAnimator = nil
AnimationController.animationsFolder = nil

AnimationController.OnKeyframeReached = nil
AnimationController.OnAnimationStopped = nil

function AnimationController.Initialize(params)
	AnimationController.vmAnimator = params.vmAnimator
	AnimationController.characterAnimator = params.characterAnimator
	AnimationController.animationsFolder = params.animationsFolder
	AnimationController.OnKeyframeReached = params.OnKeyframeReached
	AnimationController.OnAnimationStopped = params.OnAnimationStopped
end

function AnimationController.StopAnimation(animName: string, transTime: number)
	if AnimationController.loadedAnims[animName] then
		if transTime then
			AnimationController.loadedAnims[animName]:Stop(transTime)
			if AnimationController.loadedAnims[animName.."ThirdPerson"] then
				AnimationController.loadedAnims[animName.."ThirdPerson"]:Stop(transTime)
			end
		else
			AnimationController.loadedAnims[animName]:Stop()
			if AnimationController.loadedAnims[animName.."ThirdPerson"] then
				AnimationController.loadedAnims[animName.."ThirdPerson"]:Stop()
			end
		end
	end
end

function AnimationController.PlayAnimation(animName: string, parameters: table, animType: string, preload: boolean)
	parameters = parameters or {}
	local animToPlay, tpAnim
	if AnimationController.loadedAnims[animName] then
		animToPlay = AnimationController.loadedAnims[animName]
		tpAnim = AnimationController.loadedAnims[animName.."ThirdPerson"]
	elseif animName and AnimationController.animationsFolder:FindFirstChild(animName) then
		local newAnim = AnimationController.vmAnimator:LoadAnimation(AnimationController.animationsFolder[animName])
		newAnim.Looped = parameters.looped or false
		newAnim.Priority = parameters.priority or Enum.AnimationPriority.Action
		AnimationController.loadedAnims[animName] = newAnim

		local thirdPersonAnim = AnimationController.characterAnimator:LoadAnimation(AnimationController.animationsFolder[animName])
		thirdPersonAnim.Looped = parameters.looped or false
		thirdPersonAnim.Priority = parameters.priority or Enum.AnimationPriority.Action
		AnimationController.loadedAnims[animName.."ThirdPerson"] = thirdPersonAnim

		newAnim.KeyframeReached:Connect(function(keyframeName)
			if AnimationController.OnKeyframeReached then
				AnimationController.OnKeyframeReached(animName, keyframeName, newAnim, animType)
			end
		end)

		newAnim.Stopped:Connect(function()
			if AnimationController.OnAnimationStopped then
				AnimationController.OnAnimationStopped(animName, newAnim, animType)
			end
		end)

		animToPlay = newAnim
		tpAnim = thirdPersonAnim
	end

	if animToPlay and not preload then
		animToPlay:Play(parameters.transSpeed or 0)
		animToPlay:AdjustSpeed(parameters.speed or 1)
		tpAnim:Play(parameters.transSpeed or 0)
		tpAnim:AdjustSpeed(parameters.speed or 1)
	end

	return animToPlay
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

return AnimationController