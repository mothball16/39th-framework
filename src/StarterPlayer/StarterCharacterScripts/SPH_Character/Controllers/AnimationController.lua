local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local State = require(script.Parent.CharacterState)
local WeaponState = require(script.Parent.WeaponState)
local AnimationEvents = require(script.Parent.AnimationEvents)
local config = require(ReplicatedStorage:WaitForChild("SPH_Assets").GameConfig)
local Enums = require(ReplicatedStorage:WaitForChild("SPH_Assets").Modules.Core.Enums)
local AnimationController = {}

AnimationController.loadedAnims = {}
AnimationController.activeTweens = {}
AnimationController.vmAnimator = nil
AnimationController.characterAnimator = nil
AnimationController.animationsFolder = nil

AnimationController.crouchIdleAnim = nil
AnimationController.crouchMoveAnim = nil
AnimationController.proneIdleAnim = nil
AnimationController.proneMoveAnim = nil
AnimationController.moveAnim = nil

local animationProperties = {
	idle        =	{ priority = Enum.AnimationPriority.Idle,    looped = true },
	sprint      =	{ priority = Enum.AnimationPriority.Action,  looped = true },
	patrol      =	{ priority = Enum.AnimationPriority.Action,  looped = true },
	holdUp      =	{ priority = Enum.AnimationPriority.Action,  looped = true },
	holdDown    =	{ priority = Enum.AnimationPriority.Action,  looped = true },
	switch      =	{ priority = Enum.AnimationPriority.Action2, looped = false },
	reload      =	{ priority = Enum.AnimationPriority.Action2, looped = false },
	boltChamber =	{ priority = Enum.AnimationPriority.Action2, looped = false },
	boltClose   =	{ priority = Enum.AnimationPriority.Action2, looped = false },
	equip       =	{ priority = Enum.AnimationPriority.Action2, looped = false },
	fire        =	{ priority = Enum.AnimationPriority.Action2, looped = false },
}

local function _getAnimationTracks(animName, parameters: {looped: boolean, priority: Enum.AnimationPriority}, animType)
	if AnimationController.loadedAnims[animName] then
		local tracks = AnimationController.loadedAnims[animName]
		parameters = parameters or {}
		tracks.vm.Looped = parameters.looped or false
		tracks.vm.Priority = parameters.priority or Enum.AnimationPriority.Action
		tracks.tp.Looped = parameters.looped or false
		tracks.tp.Priority = parameters.priority or Enum.AnimationPriority.Action
		return tracks
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
		-- IMPORTANT: animType is decided at play-time (preloading caches tracks).
		local currentType = vmTrack:GetAttribute("AnimType") or "Unknown"
		AnimationEvents.KeyframeReached:Fire(animName, keyframeName, vmTrack, currentType)
	end)

	vmTrack.Stopped:Connect(function()
		local currentType = vmTrack:GetAttribute("AnimType") or "Unknown"
		AnimationEvents.AnimationStopped:Fire(animName, vmTrack, currentType)
	end)

	local tracks = { vm = vmTrack, tp = tpTrack }
	AnimationController.loadedAnims[animName] = tracks
	return tracks
end

local function _weaponAnim(wepStats, key: string): string?
	if wepStats.Animations == nil then return nil end
	local anims = wepStats.Animations
	local v = anims and anims[key]
	return (type(v) == "string" and v ~= "") and v or nil
end


local function _preloadWeaponAnimsIntoVM(wepStats)
	local anims = wepStats.Animations
	if type(anims) ~= "table" then
		return
	end

	for key, animName in pairs(anims) do
		if type(animName) == "string" and animName ~= "" then
			local props = animationProperties[key]
			local looped = (props and props.looped) or false
			local priority = (props and props.priority) or Enum.AnimationPriority.Action
			_getAnimationTracks(animName, { looped = looped, priority = priority }, "Preload")
		end
	end
end


local function _preloadAnimation(track, looped, priority)
	local anim = State.Parts.Humanoid.Animator:LoadAnimation(track)
	anim.Looped = looped
	anim.Priority = priority
	return anim
end

local function _fadeTrack(track: AnimationTrack, targetWeight, time, speed)
	if targetWeight == 0 and not track.IsPlaying then return end
	
	if AnimationController.activeTweens[track] then
		AnimationController.activeTweens[track].onEnd:Disconnect()
		AnimationController.activeTweens[track].tween:Cancel()
		AnimationController.activeTweens[track].conn:Disconnect()
		AnimationController.activeTweens[track].val:Destroy()
		AnimationController.activeTweens[track] = nil
	end
	
	if not time or time <= 0 then
		if targetWeight > 0 then
			if not track.IsPlaying then track:Play(0, targetWeight) end
			track:AdjustWeight(targetWeight, 0)
			if speed then track:AdjustSpeed(speed) end
		else
			track:Stop(0)
		end
		return
	end
	
	if targetWeight > 0 and not track.IsPlaying then
		track:Play(0, 0.001)
	end
	if speed then track:AdjustSpeed(speed) end
	
	local val = Instance.new("NumberValue")
	val.Value = track.WeightCurrent
	local conn = val.Changed:Connect(function(w)
		track:AdjustWeight(w, 0)
	end)
	
	local tween = TweenService:Create(val, TweenInfo.new(time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Value = targetWeight})
	
	local onEnd = tween.Completed:Once(function()
		if AnimationController.activeTweens[track] == nil then return end
		conn:Disconnect()
		val:Destroy()
		AnimationController.activeTweens[track] = nil
		if targetWeight == 0 then
			track:Stop(0)
		end
	end)

	AnimationController.activeTweens[track] = {
		tween = tween,
		conn = conn,
		val = val,
		onEnd = onEnd
	}

	tween:Play()
end

function AnimationController.Initialize(params)
	AnimationController.vmAnimator = params.vmAnimator
	AnimationController.characterAnimator = params.characterAnimator
	AnimationController.animationsFolder = params.animationsFolder

	AnimationController.crouchIdleAnim = _preloadAnimation(params.animationsFolder.Crouch_Idle, true, Enum.AnimationPriority.Idle)
	AnimationController.crouchMoveAnim = _preloadAnimation(params.animationsFolder.Crouch_Move, true, Enum.AnimationPriority.Movement)
	AnimationController.proneIdleAnim = _preloadAnimation(params.animationsFolder.Prone_Idle, true, Enum.AnimationPriority.Idle)
	AnimationController.proneMoveAnim = _preloadAnimation(params.animationsFolder.Prone_Move, true, Enum.AnimationPriority.Movement)

	-- Reactive state subscriptions
	Charm.subscribe(State.sprinting, AnimationController.SyncSprinting)
	Charm.subscribe(State.stance, AnimationController.SyncStance)
	Charm.subscribe(State.moving, AnimationController.SyncMoving)
	Charm.subscribe(WeaponState.holdStance, AnimationController.SyncHoldStance)
	Charm.subscribe(WeaponState.chambering, AnimationController.SyncChambering)

	-- Listen for animation requests from other controllers via signals
	AnimationEvents.WeaponEquipRequested:Connect(function() AnimationController.WeaponEquip() end)
	AnimationEvents.WeaponIdleRequested:Connect(function() AnimationController.WeaponIdle() end)
	AnimationEvents.FireAnimRequested:Connect(function() AnimationController.PlayFireAnim() end)
	AnimationEvents.ReloadRequested:Connect(function(lastGunModelName) AnimationController.WeaponReload(lastGunModelName) end)
	AnimationEvents.SwitchFireModeAnimRequested:Connect(function() AnimationController.PlaySwitchFireModeAnim() end)
	AnimationEvents.StopAllRequested:Connect(function() AnimationController.StopAll() end)
	AnimationEvents.PlayAnimationRequested:Connect(function(animName, params, animType) AnimationController.PlayAnimation(animName, params, animType) end)
	AnimationEvents.StopAnimationRequested:Connect(function(animName, transTime) AnimationController.StopAnimation(animName, transTime) end)
	AnimationEvents.BoltActionRequested:Connect(function(boltReady) AnimationController.PlayBoltAction(boltReady) end)
	AnimationEvents.ReloadActionRequested:Connect(function(useClip) AnimationController.PlayReloadAction(useClip) end)
end

function AnimationController.SyncStance(stance, oldStance)
	if AnimationController.moveAnim then _fadeTrack(AnimationController.moveAnim, 0, config.stanceChangeTime) end

	if stance == 0 then -- Walking
		AnimationController.moveAnim = nil
		_fadeTrack(AnimationController.crouchIdleAnim, 0, config.stanceChangeTime)
		_fadeTrack(AnimationController.proneIdleAnim, 0, config.stanceChangeTime)
	elseif stance == 1 then -- Crouching
		AnimationController.moveAnim = AnimationController.crouchMoveAnim
		if State.moving() then _fadeTrack(AnimationController.moveAnim, 1, config.stanceChangeTime) end
		_fadeTrack(AnimationController.proneIdleAnim, 0, config.stanceChangeTime)
		_fadeTrack(AnimationController.crouchIdleAnim, 1, config.stanceChangeTime)
	elseif stance == 2 then -- Prone
		AnimationController.moveAnim = AnimationController.proneMoveAnim
		_fadeTrack(AnimationController.crouchIdleAnim, 0, config.stanceChangeTime)
		_fadeTrack(AnimationController.proneIdleAnim, 1, config.stanceChangeTime)
		if State.moving() then _fadeTrack(AnimationController.moveAnim, 1, config.stanceChangeTime) end
	end
end

function AnimationController.SyncMoving(moving)
	if moving then
		if AnimationController.moveAnim then _fadeTrack(AnimationController.moveAnim, 1, config.stanceChangeTime) end
	else
		if AnimationController.moveAnim then _fadeTrack(AnimationController.moveAnim, 0, config.stanceChangeTime) end
	end
end

function AnimationController.SyncSprinting(sprinting)
	if sprinting then
		local sprintAnim = _weaponAnim(WeaponState.wepStats, "sprint")
		if sprintAnim then
			AnimationController.PlayAnimation(sprintAnim, { looped = true, priority = Enum.AnimationPriority.Action, transSpeed = 0.5 })
		end
	else
		local sprintAnim = _weaponAnim(WeaponState.wepStats, "sprint")
		if sprintAnim then
			AnimationController.StopAnimation(sprintAnim, 0.5)
		end
	end
end

function AnimationController.StopAnimation(animName: string, transTime: number)
	local tracks = AnimationController.loadedAnims[animName]
	if tracks then
		_fadeTrack(tracks.vm, 0, transTime)
		_fadeTrack(tracks.tp, 0, transTime)
	end
end




function AnimationController.PlayAnimation(animName: string, parameters: table, animType: string)
	parameters = parameters or {}
	local tracks = _getAnimationTracks(animName, parameters, animType)

	if tracks then
		-- Tag track with current animType so cached/preloaded tracks report correctly.
		tracks.vm:SetAttribute("AnimType", animType)
		tracks.tp:SetAttribute("AnimType", animType)

		local transSpeed = parameters.transSpeed
		local speed = parameters.speed or 1

		_fadeTrack(tracks.vm, 1, transSpeed, speed)
		_fadeTrack(tracks.tp, 1, transSpeed, speed)
	elseif not tracks then
		warn("no tracks for anim", animName)
	end

	return tracks and tracks.vm
end

function AnimationController.StopAll()
	if AnimationController.vmAnimator then
		for _, track in ipairs(AnimationController.vmAnimator:GetPlayingAnimationTracks()) do
			_fadeTrack(track, 0, 0)
		end
	end
	if AnimationController.characterAnimator then
		for _, track in ipairs(AnimationController.characterAnimator:GetPlayingAnimationTracks()) do
			_fadeTrack(track, 0, 0)
		end
	end
end

function AnimationController.AdjustMoveAnimSpeed(speed: number)
	if AnimationController.moveAnim then
		AnimationController.moveAnim:AdjustSpeed(speed)
	end
end

AnimationController.holdAnim = nil
function AnimationController.SyncHoldStance(newStance, oldStance)
	if AnimationController.holdAnim then
		AnimationController.StopAnimation(AnimationController.holdAnim.Name, 0.3)
		AnimationController.holdAnim = nil
	end
	if not State.equippedTool() or not WeaponState.wepStats then return end

	local animToPlay
	if newStance == Enums.HoldStance.High then
		animToPlay = _weaponAnim(WeaponState.wepStats, "holdUp")
	elseif newStance == Enums.HoldStance.Patrol then
		animToPlay = _weaponAnim(WeaponState.wepStats, "patrol")
	elseif newStance == Enums.HoldStance.Low then
		animToPlay = _weaponAnim(WeaponState.wepStats, "holdDown")
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


function AnimationController.WeaponEquip()
	if not WeaponState.wepStats then return end
	AnimationController.StopAll()
	_preloadWeaponAnimsIntoVM(WeaponState.wepStats)
	local equipAnimName = _weaponAnim(WeaponState.wepStats, "equip")
	local equipAnim = equipAnimName and AnimationController.PlayAnimation(equipAnimName, { priority = Enum.AnimationPriority.Action2 }, "Equip")
	if equipAnim then
		equipAnim.Stopped:Connect(function() WeaponState.equipping(false) end)
	else
		WeaponState.equipping(false)
	end
end

function AnimationController.WeaponIdle()
	if not WeaponState.wepStats then return end
	local idleAnim = _weaponAnim(WeaponState.wepStats, "idle")
	if idleAnim then
		AnimationController.PlayAnimation(idleAnim, { looped = true, priority = Enum.AnimationPriority.Idle }, "Idle")
	end
end

function AnimationController.SyncChambering(value)
	if value == false or not WeaponState.wepStats or not State.equippedTool() then
		return
	end
	local animNameToPlay = (State.equippedTool().BoltReady.Value or WeaponState.fireMode() == 5)
		and _weaponAnim(WeaponState.wepStats, "boltChamber")
		or _weaponAnim(WeaponState.wepStats, "boltClose")

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
	if not State.equippedTool() or not WeaponState.wepStats then return end
	WeaponState.reloading(true)
	local animSpeed = WeaponState.wepStats.reloadSpeedModifier

	if WeaponState.fireMode() == 4 and WeaponState.wepStats.hasUBGL then
		local ubglStats = WeaponState.wepStats.getStatsForMode(4)
		local reloadAnim = _weaponAnim(ubglStats, "reload") or _weaponAnim(WeaponState.wepStats, "reload")
		if reloadAnim then
			AnimationController.PlayAnimation(reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
		end
		return
	end

	local gunAmmo = State.equippedTool():FindFirstChild("Ammo")
	if
		WeaponState.wepStats.operationType == 3
		or
		(WeaponState.wepStats.operationType == 2 and gunAmmo and gunAmmo.MagAmmo.Value <= 0 and not State.equippedTool().Chambered.Value) then
		local boltOpenTrack = AnimationController.PlayAnimation(WeaponState.wepStats.boltOpen, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "BoltOpen")
		if not boltOpenTrack then WeaponState.reloading(false) return end
		boltOpenTrack.Stopped:Once(function()
			if not State.equippedTool() or not gunAmmo then return end
			local cap = WeaponState.wepStats.clipSize or WeaponState.wepStats.magazineCapacity
			if WeaponState.wepStats.magType == 3 and (gunAmmo.MagAmmo.MaxValue - gunAmmo.MagAmmo.Value) >= cap and gunAmmo.ArcadeAmmoPool.Value >= cap then
					local clipReloadAnim = _weaponAnim(WeaponState.wepStats, "clipReload")
					if clipReloadAnim then
						AnimationController.PlayAnimation(clipReloadAnim, {looped = true, speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
					end
			else
				if lastGunModelName and WeaponState.gunModel() and lastGunModelName ~= WeaponState.gunModel().Name then return end
					local reloadAnim = _weaponAnim(WeaponState.wepStats, "reload")
					if reloadAnim then
						AnimationController.PlayAnimation(reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17, looped = WeaponState.wepStats.magType > 1}, "Reload")
					end
			end
		end)
	else
		local reloadAnim = _weaponAnim(WeaponState.wepStats, "reload")
		if reloadAnim then
			AnimationController.PlayAnimation(reloadAnim, {speed = animSpeed, priority = Enum.AnimationPriority.Action3, transSpeed = 0.17}, "Reload")
		end
	end
end

function AnimationController.PlayBoltAction(boltReady)
	if not WeaponState.wepStats then return end
	local animName = boltReady
		and _weaponAnim(WeaponState.wepStats, "boltChamber")
		or _weaponAnim(WeaponState.wepStats, "boltClose")
	AnimationController.PlayAnimation(animName, {priority = Enum.AnimationPriority.Action2, transSpeed = 0.05}, "BoltAction")
end

function AnimationController.PlayReloadAction(useClip)
	if not WeaponState.wepStats then return end
	local animSpeed = WeaponState.wepStats.reloadSpeedModifier
	local animName = if useClip then _weaponAnim(WeaponState.wepStats, "clipReload") else _weaponAnim(WeaponState.wepStats, "reload")
	if animName then
		AnimationController.PlayAnimation(animName, {looped = useClip, speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17}, "Reload")
	end
end

function AnimationController.PlayFireAnim()
	local fireAnim = _weaponAnim(WeaponState.wepStats, "fire")
	if fireAnim then
		AnimationController.PlayAnimation(fireAnim, {priority = Enum.AnimationPriority.Action2, looped = false}, "Fire")
	end
end

function AnimationController.PlaySwitchFireModeAnim()
	local switchAnim = _weaponAnim(WeaponState.wepStats, "switch")
	if switchAnim then
		AnimationController.PlayAnimation(switchAnim, {transSpeed = 0.2}, "Switch")
	end
end

return AnimationController
