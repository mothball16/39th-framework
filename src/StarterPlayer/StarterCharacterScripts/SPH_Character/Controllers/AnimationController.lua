local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local State = require(script.Parent.CharacterState)
local WeaponState = require(script.Parent.WeaponState)
local config = require(ReplicatedStorage:WaitForChild("SPH_Assets").GameConfig)
local Enums = require(script.Parent.Parent.Enums)
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


local function _preloadAnimation(track, looped, priority)
	local anim = State.Parts.Humanoid.Animator:LoadAnimation(track)
	anim.Looped = looped
	anim.Priority = priority
	return anim
end

function AnimationController.Initialize(params)
	AnimationController.vmAnimator = params.vmAnimator
	AnimationController.characterAnimator = params.characterAnimator
	AnimationController.animationsFolder = params.animationsFolder
	AnimationController.OnKeyframeReached = params.OnKeyframeReached
	AnimationController.OnAnimationStopped = params.OnAnimationStopped

	AnimationController.crouchIdleAnim = _preloadAnimation(params.animationsFolder.Crouch_Idle, true, Enum.AnimationPriority.Idle)
	AnimationController.crouchMoveAnim = _preloadAnimation(params.animationsFolder.Crouch_Move, true, Enum.AnimationPriority.Movement)
	AnimationController.proneIdleAnim = _preloadAnimation(params.animationsFolder.Prone_Idle, true, Enum.AnimationPriority.Idle)
	AnimationController.proneMoveAnim = _preloadAnimation(params.animationsFolder.Prone_Move, true, Enum.AnimationPriority.Movement)


	Charm.subscribe(State.sprinting, AnimationController.OnSprintChanged)
	Charm.subscribe(State.stance, AnimationController.OnStanceChanged)
	Charm.subscribe(State.moving, AnimationController.OnMovingChanged)
	Charm.subscribe(WeaponState.holdStance, AnimationController.OnHoldStanceChanged)
	Charm.subscribe(WeaponState.chambering, AnimationController.OnWeaponChamber)
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
		if WeaponState.wepStats and WeaponState.wepStats.sprintAnim then
			AnimationController.PlayAnimation(WeaponState.wepStats.sprintAnim, {looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.2})
		end
	else
		if WeaponState.wepStats and WeaponState.wepStats.sprintAnim then
			AnimationController.StopAnimation(WeaponState.wepStats.sprintAnim, 0.2)
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

AnimationController.holdAnim = nil
function AnimationController.OnHoldStanceChanged(newStance, oldStance)
	if AnimationController.holdAnim then
		AnimationController.StopAnimation(AnimationController.holdAnim.Name, 0.3)
		AnimationController.holdAnim = nil
	end
	if not State.equipped() or not WeaponState.wepStats then return end

	local animToPlay
	if newStance == Enums.HoldStance.High and WeaponState.wepStats.holdUpAnim then
		animToPlay = WeaponState.wepStats.holdUpAnim
	elseif newStance == Enums.HoldStance.Patrol and WeaponState.wepStats.patrolAnim then
		animToPlay = WeaponState.wepStats.patrolAnim
	elseif newStance == Enums.HoldStance.Low and WeaponState.wepStats.holdDownAnim then
		animToPlay = WeaponState.wepStats.holdDownAnim
	end

	if animToPlay then
		AnimationController.holdAnim = AnimationController.PlayAnimation(animToPlay, {looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.3})
	else
		-- patrol override (bleh)
		if oldStance == Enums.HoldStance.Ready and newStance == Enums.HoldStance.Low then
			WeaponState.holdStance(Enums.HoldStance.Patrol)
		else
			WeaponState.holdStance(Enums.HoldStance.Ready)
		end
	end
end

function AnimationController.WeaponEquipPreload()
	if not WeaponState.wepStats then return end
	local newEquipAnim = AnimationController.PlayAnimation(WeaponState.wepStats.equipAnim, {priority = Enum.AnimationPriority.Action2}, "Equip", true)
	if newEquipAnim then
		newEquipAnim.Stopped:Connect(function() State.equipping(false) end)
	else
		State.equipping(false)
	end

	AnimationController.PlayAnimation(WeaponState.wepStats.boltChamber, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05, looped = false}, "Chamber", true)
	if WeaponState.wepStats.operationType == 2 or WeaponState.wepStats.operationType == 3 then
		AnimationController.PlayAnimation(WeaponState.wepStats.boltOpen, {priority = Enum.AnimationPriority.Action2, transSpeed = 0, looped = false}, "BoltOpen", true)
		AnimationController.PlayAnimation(WeaponState.wepStats.boltClose, {priority = Enum.AnimationPriority.Action2, looped = false}, "BoltClose", true)
	end
	
	local animSpeed = WeaponState.wepStats.reloadSpeedModifier
	if WeaponState.attStats and WeaponState.attStats.reloadSpeedModifier then animSpeed *= WeaponState.attStats.reloadSpeedModifier end

	if WeaponState.wepStats.magType == 1 then
		AnimationController.PlayAnimation(WeaponState.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload", true)
	else
		local gunAmmo = State.equipped():FindFirstChild("Ammo")
		AnimationController.PlayAnimation(WeaponState.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0, looped = gunAmmo and gunAmmo.MagAmmo.MaxValue > 1}, "Reload", true)
		if WeaponState.wepStats.magType == 3 then
			AnimationController.PlayAnimation(WeaponState.wepStats.clipReloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17, looped = false}, "Reload", true)
		end
	end
	
	if WeaponState.wepStats.hasUBGL and WeaponState.wepStats.ubgl and WeaponState.wepStats.ubgl.reloadAnim then
		AnimationController.PlayAnimation(WeaponState.wepStats.ubgl.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload", true)
	end
end

function AnimationController.WeaponEquip()
	if not WeaponState.wepStats then return end
	AnimationController.PlayAnimation(WeaponState.wepStats.equipAnim, {priority = Enum.AnimationPriority.Action2}, "Equip")
end

function AnimationController.WeaponIdle()
	if not WeaponState.wepStats then return end
	AnimationController.PlayAnimation(WeaponState.wepStats.idleAnim, {looped = true, priority = Enum.AnimationPriority.Idle}, "Idle")
end

function AnimationController.OnWeaponChamber(value)
	if value == false or not WeaponState.wepStats or not State.equipped() then
		return
	end
	local animNameToPlay = (State.equipped().BoltReady.Value or WeaponState.fireMode() == 5)
		and WeaponState.wepStats.boltChamber
		or WeaponState.wepStats.boltClose

	local playingAnim = AnimationController.PlayAnimation(
		animNameToPlay,
		{priority = Enum.AnimationPriority.Action2, transSpeed = 0.05},
		"Chamber")

	if playingAnim then
		playingAnim.Stopped:Once(function()
			WeaponState.chambering(false)
		end)
	else
		warn("no chamber anim")
		WeaponState.chambering(false)
	end
end


function AnimationController.WeaponReload(lastGunModelName)
	if not State.equipped() or not WeaponState.wepStats then return end
	WeaponState.reloading(true)
	WeaponState.holdStance(Enums.HoldStance.Ready)
	
	local animSpeed = WeaponState.wepStats.reloadSpeedModifier
	if WeaponState.attStats and WeaponState.attStats.reloadSpeedModifier then animSpeed *= WeaponState.attStats.reloadSpeedModifier end

	if WeaponState.fireMode() == 4 and WeaponState.wepStats.hasUBGL then
		local ubglStats = WeaponState.wepStats.getStatsForMode(4)
		AnimationController.PlayAnimation(ubglStats.reloadAnim or WeaponState.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
		return
	end

	local gunAmmo = State.equipped():FindFirstChild("Ammo")
	if WeaponState.wepStats.operationType == 3 or (WeaponState.wepStats.operationType == 2 and gunAmmo and gunAmmo.MagAmmo.Value <= 0 and not State.equipped().Chambered.Value) then
		local boltOpenTrack = AnimationController.PlayAnimation(WeaponState.wepStats.boltOpen, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "BoltOpen")
		if not boltOpenTrack then WeaponState.reloading(false) return end
		boltOpenTrack.Stopped:Once(function()
			if not State.equipped() or not gunAmmo then return end
			local cap = WeaponState.wepStats.clipSize or (WeaponState.attStats and WeaponState.attStats.magazineCapacity) or WeaponState.wepStats.magazineCapacity
			if WeaponState.wepStats.magType == 3 and (gunAmmo.MagAmmo.MaxValue - gunAmmo.MagAmmo.Value) >= cap and gunAmmo.ArcadeAmmoPool.Value >= cap then
				AnimationController.PlayAnimation(WeaponState.wepStats.clipReloadAnim, {looped = true, speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
			else
				if lastGunModelName and WeaponState.gunModel and lastGunModelName ~= WeaponState.gunModel.Name then return end
				AnimationController.PlayAnimation(WeaponState.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17, looped = WeaponState.wepStats.magType > 1}, "Reload")
			end
		end)
	else
		AnimationController.PlayAnimation(WeaponState.wepStats.reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
	end
end

function AnimationController.PlayBoltAction(boltReady)
	if not WeaponState.wepStats then return end
	AnimationController.PlayAnimation(boltReady and WeaponState.wepStats.boltChamber or WeaponState.wepStats.boltClose, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05}, "BoltAction")
end

function AnimationController.PlayReloadAction(useClip)
	if not WeaponState.wepStats then return end
	local animSpeed = WeaponState.wepStats.reloadSpeedModifier
	if WeaponState.attStats and WeaponState.attStats.reloadSpeedModifier then animSpeed *= WeaponState.attStats.reloadSpeedModifier end
	AnimationController.PlayAnimation(useClip and WeaponState.wepStats.clipReloadAnim or WeaponState.wepStats.reloadAnim, {looped = useClip, speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
end

function AnimationController.PlayFireAnim()
	if WeaponState.wepStats and WeaponState.wepStats.fireAnim then AnimationController.PlayAnimation(WeaponState.wepStats.fireAnim, {priority = Enum.AnimationPriority.Action2, looped = false}, "Fire") end
end

function AnimationController.PlaySwitchFireModeAnim()
	if WeaponState.wepStats and WeaponState.wepStats.switchAnim then AnimationController.PlayAnimation(WeaponState.wepStats.switchAnim, {transSpeed = 0.2}, "Switch") end
end

return AnimationController