--[[
	Plays first-person (viewmodel) and third-person animation tracks in sync.
	Charm state drives stance/movement; AnimationEvents carries weapon requests from WeaponController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local CharacterStateModule = require(ReplicatedStorage.SPH_Framework.State.CharacterState)
local WeaponStateModule = require(ReplicatedStorage.SPH_Framework.State.WeaponState)
local AnimationEvents = require(script.Parent.AnimationEvents)
local sph = require(ReplicatedStorage.SPH_Framework.GameAccess)
local config = sph.config
local Enums = require(sph.framework.Core.Enums)

-- Default loop/priority when playing a weapon anim by config key (e.g. "reload", "idle").
local ANIM_DEFAULTS = {
	idle = { priority = Enum.AnimationPriority.Idle, looped = true },
	sprint = { priority = Enum.AnimationPriority.Action, looped = true },
	patrol = { priority = Enum.AnimationPriority.Action, looped = true },
	holdUp = { priority = Enum.AnimationPriority.Action, looped = true },
	holdDown = { priority = Enum.AnimationPriority.Action, looped = true },
	switch = { priority = Enum.AnimationPriority.Action2, looped = false },
	reload = { priority = Enum.AnimationPriority.Action2, looped = false },
	boltChamber = { priority = Enum.AnimationPriority.Action2, looped = false },
	boltClose = { priority = Enum.AnimationPriority.Action2, looped = false },
	equip = { priority = Enum.AnimationPriority.Action2, looped = false },
	fire = { priority = Enum.AnimationPriority.Action2, looped = false },
}

-- ---------------------------------------------------------------------------
-- Module state (not exported; keeps the public table to just functions)
-- ---------------------------------------------------------------------------

local loadedAnims: { [string]: { vm: AnimationTrack, tp: AnimationTrack } } = {}
local activeTweens: { [AnimationTrack]: any } = {}

local vmAnimator: Animator? = nil
local characterAnimator: Animator? = nil
local animationsFolder: Folder? = nil

local crouchIdleAnim: AnimationTrack? = nil
local crouchMoveAnim: AnimationTrack? = nil
local proneIdleAnim: AnimationTrack? = nil
local proneMoveAnim: AnimationTrack? = nil
local moveAnim: AnimationTrack? = nil
-- Key used in `loadedAnims` / weapon stats for the active hold pose clip (not `AnimationTrack.Name`; that can differ).
local holdAnimKey: string? = nil

local AnimationController = {}
local weaponState: WeaponStateModule.WeaponState
local State: CharacterStateModule.CharacterState

-- ---------------------------------------------------------------------------
-- Play options: optional `propertyKey` picks ANIM_DEFAULTS; explicit fields in `parameters` win.
-- ---------------------------------------------------------------------------

local function resolvePlayParams(propertyKey: string?, parameters: { [string]: any }?)
	local defaults = propertyKey and ANIM_DEFAULTS[propertyKey]
	local p = parameters or {}
	return {
		looped = if p.looped ~= nil then p.looped elseif defaults then defaults.looped else false,
		priority = if p.priority ~= nil then p.priority elseif defaults then defaults.priority else Enum.AnimationPriority.Action,
		transSpeed = p.transSpeed,
		speed = p.speed,
	}
end

local function clearTweenForTrack(track: AnimationTrack)
	local entry = activeTweens[track]
	if not entry then
		return
	end
	entry.onEnd:Disconnect()
	entry.tween:Cancel()
	entry.conn:Disconnect()
	entry.val:Destroy()
	activeTweens[track] = nil
end

local function fadeTrack(track: AnimationTrack, targetWeight: number, fadeTime: number?, speed: number?)
	if targetWeight == 0 and not track.IsPlaying then
		return
	end

	clearTweenForTrack(track)

	if not fadeTime or fadeTime <= 0 then
		if targetWeight > 0 then
			if not track.IsPlaying then
				track:Play(0, targetWeight)
			end
			track:AdjustWeight(targetWeight, 0)
			if speed then
				track:AdjustSpeed(speed)
			end
		else
			track:Stop(0)
		end
		return
	end

	if targetWeight > 0 and not track.IsPlaying then
		track:Play(0, 0.001)
	end
	if speed then
		track:AdjustSpeed(speed)
	end

	local val = Instance.new("NumberValue")
	val.Value = track.WeightCurrent
	local conn = val.Changed:Connect(function(w)
		track:AdjustWeight(w, 0)
	end)

	local tween = TweenService:Create(val, TweenInfo.new(fadeTime, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Value = targetWeight })

	local onEnd = tween.Completed:Once(function()
		if activeTweens[track] == nil then
			return
		end
		conn:Disconnect()
		val:Destroy()
		activeTweens[track] = nil
		if targetWeight == 0 then
			track:Stop(0)
		end
	end)

	activeTweens[track] = {
		tween = tween,
		conn = conn,
		val = val,
		onEnd = onEnd,
	}

	tween:Play()
end

local function loadHumanoidAnim(animation: Animation, looped: boolean, priority: Enum.AnimationPriority)
	local anim = State.Parts.Humanoid.Animator:LoadAnimation(animation)
	anim.Looped = looped
	anim.Priority = priority
	return anim
end

-- Returns the animation asset name from weapon stats for a given key, or nil.
local function weaponAnimationName(wepStats, key: string): string?
	if not wepStats or type(wepStats.Animations) ~= "table" then
		return nil
	end
	local v = wepStats.Animations[key]
	return (type(v) == "string" and v ~= "") and v or nil
end

local function getOrCreateTracks(animName: string, playParams: { looped: boolean, priority: Enum.AnimationPriority })
	local cached = loadedAnims[animName]
	if cached then
		cached.vm.Looped = playParams.looped
		cached.vm.Priority = playParams.priority
		cached.tp.Looped = playParams.looped
		cached.tp.Priority = playParams.priority
		return cached
	end

	if not animName or not animationsFolder or not animationsFolder:FindFirstChild(animName) then
		return nil
	end

	local animAsset = animationsFolder[animName]
	local vmTrack = vmAnimator:LoadAnimation(animAsset)
	vmTrack.Looped = playParams.looped
	vmTrack.Priority = playParams.priority

	local tpTrack = characterAnimator:LoadAnimation(animAsset)
	tpTrack.Looped = playParams.looped
	tpTrack.Priority = playParams.priority

	vmTrack.KeyframeReached:Connect(function(keyframeName)
		local currentType = vmTrack:GetAttribute("AnimType") or "Unknown"
		AnimationEvents.KeyframeReached:Fire(animName, keyframeName, vmTrack, currentType)
	end)

	vmTrack.Stopped:Connect(function()
		local currentType = vmTrack:GetAttribute("AnimType") or "Unknown"
		AnimationEvents.AnimationStopped:Fire(animName, vmTrack, currentType)
	end)

	local tracks = { vm = vmTrack, tp = tpTrack }
	loadedAnims[animName] = tracks
	return tracks
end

local function preloadWeaponAnimations(wepStats)
	local anims = wepStats.Animations
	if type(anims) ~= "table" then
		return
	end
	for key, animName in pairs(anims) do
		if type(animName) == "string" and animName ~= "" then
			getOrCreateTracks(animName, resolvePlayParams(key, nil))
		end
	end
end

function AnimationController.Initialize(params)
	vmAnimator = params.vmAnimator
	characterAnimator = params.characterAnimator
	animationsFolder = params.animationsFolder
	weaponState = params.weaponState
	State = params.state

	crouchIdleAnim = loadHumanoidAnim(params.animationsFolder.Crouch_Idle, true, Enum.AnimationPriority.Idle)
	crouchMoveAnim = loadHumanoidAnim(params.animationsFolder.Crouch_Move, true, Enum.AnimationPriority.Movement)
	proneIdleAnim = loadHumanoidAnim(params.animationsFolder.Prone_Idle, true, Enum.AnimationPriority.Idle)
	proneMoveAnim = loadHumanoidAnim(params.animationsFolder.Prone_Move, true, Enum.AnimationPriority.Movement)

	Charm.subscribe(State.sprinting, AnimationController.SyncSprinting)
	Charm.subscribe(State.stance, AnimationController.SyncStance)
	Charm.subscribe(State.moving, AnimationController.SyncMoving)
	Charm.subscribe(weaponState.holdStance, AnimationController.SyncHoldStance)
	Charm.subscribe(weaponState.chambering, AnimationController.SyncChambering)

	AnimationEvents.WeaponEquipRequested:Connect(AnimationController.WeaponEquip)
	AnimationEvents.WeaponIdleRequested:Connect(AnimationController.WeaponIdle)
	AnimationEvents.FireAnimRequested:Connect(AnimationController.PlayFireAnim)
	AnimationEvents.ReloadRequested:Connect(AnimationController.WeaponReload)
	AnimationEvents.SwitchFireModeAnimRequested:Connect(AnimationController.PlaySwitchFireModeAnim)
	AnimationEvents.StopAllRequested:Connect(AnimationController.StopAll)
	AnimationEvents.PlayAnimationRequested:Connect(AnimationController.PlayAnimation)
	AnimationEvents.StopAnimationRequested:Connect(AnimationController.StopAnimation)
	AnimationEvents.BoltActionRequested:Connect(AnimationController.PlayBoltAction)
	AnimationEvents.ReloadActionRequested:Connect(AnimationController.PlayReloadAction)
end

function AnimationController.SyncStance(stance)
	if moveAnim then
		fadeTrack(moveAnim, 0, config.stanceChangeTime)
	end

	if stance == 0 then
		moveAnim = nil
		fadeTrack(crouchIdleAnim, 0, config.stanceChangeTime)
		fadeTrack(proneIdleAnim, 0, config.stanceChangeTime)
	elseif stance == 1 then
		moveAnim = crouchMoveAnim
		if State.moving() then
			fadeTrack(moveAnim, 1, config.stanceChangeTime)
		end
		fadeTrack(proneIdleAnim, 0, config.stanceChangeTime)
		fadeTrack(crouchIdleAnim, 1, config.stanceChangeTime)
	elseif stance == 2 then
		moveAnim = proneMoveAnim
		fadeTrack(crouchIdleAnim, 0, config.stanceChangeTime)
		fadeTrack(proneIdleAnim, 1, config.stanceChangeTime)
		if State.moving() then
			fadeTrack(moveAnim, 1, config.stanceChangeTime)
		end
	end
end

function AnimationController.SyncMoving(moving)
	if not moveAnim then
		return
	end
	if moving then
		fadeTrack(moveAnim, 1, config.stanceChangeTime)
	else
		fadeTrack(moveAnim, 0, config.stanceChangeTime)
	end
end

function AnimationController.SyncSprinting(sprinting)
	local stats = weaponState.wepStats()
	local sprintName = weaponAnimationName(stats, "sprint")
	if not sprintName then
		return
	end
	if sprinting then
		AnimationController.PlayAnimation(sprintName, { transSpeed = 0.5 }, "Sprint", "sprint")
	else
		AnimationController.StopAnimation(sprintName, 0.5)
	end
end

function AnimationController.StopAnimation(animName: string, transTime: number)
	local tracks = loadedAnims[animName]
	if tracks then
		fadeTrack(tracks.vm, 0, transTime)
		fadeTrack(tracks.tp, 0, transTime)
	end
end

function AnimationController.PlayAnimation(animName: string, parameters: table?, animType: string?, propertyKey: string?)
	local merged = resolvePlayParams(propertyKey, parameters)
	local tracks = getOrCreateTracks(animName, merged)

	if not tracks then
		warn("no tracks for anim", animName)
		return nil
	end

	local typeTag = animType or "Play"
	tracks.vm:SetAttribute("AnimType", typeTag)
	tracks.tp:SetAttribute("AnimType", typeTag)

	local transSpeed = merged.transSpeed
	local speed = merged.speed or 1

	fadeTrack(tracks.vm, 1, transSpeed, speed)
	fadeTrack(tracks.tp, 1, transSpeed, speed)

	return tracks.vm
end

function AnimationController.StopAll()
	for _, animator in { vmAnimator, characterAnimator } do
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				fadeTrack(track, 0, 0)
			end
		end
	end
end

function AnimationController.AdjustMoveAnimSpeed(speed: number)
	if moveAnim then
		moveAnim:AdjustSpeed(speed)
	end
end

function AnimationController.SyncHoldStance(newStance, oldStance)
	if holdAnimKey then
		AnimationController.StopAnimation(holdAnimKey, 0.3)
		holdAnimKey = nil
	end
	local stats = weaponState.wepStats()
	if not State.equippedTool() or not stats then
		return
	end

	local animToPlay: string? = nil
	local propertyKey: string? = nil

	if newStance == Enums.HoldStance.High then
		animToPlay = weaponAnimationName(stats, "holdUp")
		propertyKey = "holdUp"
	elseif newStance == Enums.HoldStance.Patrol then
		animToPlay = weaponAnimationName(stats, "patrol")
		propertyKey = "patrol"
	elseif newStance == Enums.HoldStance.Low then
		animToPlay = weaponAnimationName(stats, "holdDown")
		propertyKey = "holdDown"
	end

	if animToPlay then
		-- Hard-stop this clip first so a reused asset name after weapon swap always restarts cleanly.
		AnimationController.StopAnimation(animToPlay, 0)
		local started = AnimationController.PlayAnimation(animToPlay, { transSpeed = 0.3 }, "Hold", propertyKey)
		holdAnimKey = started and animToPlay or nil
	else
		-- No anim for this stance: bounce Ready ↔ Patrol when dropping from Ready to Low.
		if oldStance == Enums.HoldStance.Ready and newStance == Enums.HoldStance.Low then
			weaponState.holdStance(Enums.HoldStance.Patrol)
		else
			weaponState.holdStance(Enums.HoldStance.Ready)
		end
	end
end

function AnimationController.WeaponEquip()
	local ws = weaponState.wepStats()
	if not ws then
		return
	end
	AnimationController.StopAll()
	holdAnimKey = nil
	-- Tracks were built for the previous tool; reuse breaks hold/sprint after swapping weapons.
	table.clear(loadedAnims)
	preloadWeaponAnimations(ws)

	local equipName = weaponAnimationName(ws, "equip")
	local equipTrack = equipName and AnimationController.PlayAnimation(equipName, {}, "Equip", "equip")
	if equipTrack then
		equipTrack.Stopped:Connect(function()
			weaponState.equipping(false)
		end)
	else
		weaponState.equipping(false)
	end
end

function AnimationController.WeaponIdle()
	local ws = weaponState.wepStats()
	if not ws then
		return
	end
	local idleName = weaponAnimationName(ws, "idle")
	if idleName then
		AnimationController.PlayAnimation(idleName, {}, "Idle", "idle")
	end
end

function AnimationController.SyncChambering(value)
	local stats = weaponState.wepStats()
	if value == false or not stats or not State.equippedTool() then
		return
	end

	local useChamber = State.equippedTool().BoltReady.Value or weaponState.fireMode() == 5
	local animName = useChamber and weaponAnimationName(stats, "boltChamber") or weaponAnimationName(stats, "boltClose")
	local chamberKey = if useChamber then "boltChamber" else "boltClose"

	local playing = AnimationController.PlayAnimation(animName, { transSpeed = 0.05 }, "Chamber", chamberKey)
	if playing then
		playing.Stopped:Once(function()
			weaponState.chambering(false)
		end)
	else
		warn("no chamber anim")
		weaponState.chambering(false)
	end
end

-- UBGL (fire mode 4) uses the UBGL stat block for the reload clip name when present.
local function playUbglReload(animSpeed: number)
	local ws = weaponState.wepStats()
	if not ws then
		return
	end
	local ubglStats = ws.getStatsForMode(4)
	local reloadAnim = weaponAnimationName(ubglStats, "reload") or weaponAnimationName(ws, "reload")
	if reloadAnim then
		AnimationController.PlayAnimation(reloadAnim, { speed = animSpeed, transSpeed = 0.17 }, "Reload", "reload")
	end
end

-- Open bolt, then either clip loop or normal reload depending on ammo rules.
local function playBoltOpenReloadSequence(lastGunModelName: string?, animSpeed: number)
	local tool = State.equippedTool()
	local gunAmmo = tool:FindFirstChild("Ammo")
	local stats = weaponState.wepStats()
	if not stats then
		return
	end

	local boltOpenTrack = AnimationController.PlayAnimation(
		stats.boltOpen,
		{ speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17 },
		"BoltOpen",
		nil
	)
	if not boltOpenTrack then
		weaponState.reloading(false)
		return
	end

	boltOpenTrack.Stopped:Once(function()
		if not State.equippedTool() or not gunAmmo then
			return
		end
		local cap = stats.clipSize or stats.magazineCapacity
		local canFullClip =
			stats.magType == 3
			and (gunAmmo.MagAmmo.MaxValue - gunAmmo.MagAmmo.Value) >= cap
			and gunAmmo.ArcadeAmmoPool.Value >= cap

		if canFullClip then
			local clipName = weaponAnimationName(stats, "clipReload")
			if clipName then
				AnimationController.PlayAnimation(clipName, { looped = true, speed = animSpeed, transSpeed = 0.17 }, "Reload", "reload")
			end
			return
		end

		if lastGunModelName and weaponState.gunModel() and lastGunModelName ~= weaponState.gunModel().Name then
			return
		end
		local reloadName = weaponAnimationName(stats, "reload")
		if reloadName then
			AnimationController.PlayAnimation(
				reloadName,
				{ speed = animSpeed, transSpeed = 0.17, looped = stats.magType > 1 },
				"Reload",
				"reload"
			)
		end
	end)
end

function AnimationController.WeaponReload(lastGunModelName)
	local ws = weaponState.wepStats()
	if not State.equippedTool() or not ws then
		return
	end
	weaponState.reloading(true)
	local animSpeed = ws.reloadSpeedModifier

	if weaponState.fireMode() == 4 and ws.hasUBGL then
		playUbglReload(animSpeed)
		return
	end

	local tool = State.equippedTool()
	local gunAmmo = tool:FindFirstChild("Ammo")
	local stats = ws

	local needsBoltOpen = stats.operationType == 3
		or (stats.operationType == 2 and gunAmmo and gunAmmo.MagAmmo.Value <= 0 and not tool.Chambered.Value)

	if needsBoltOpen then
		playBoltOpenReloadSequence(lastGunModelName, animSpeed)
	else
		local reloadName = weaponAnimationName(stats, "reload")
		if reloadName then
			AnimationController.PlayAnimation(reloadName, { speed = animSpeed, priority = Enum.AnimationPriority.Action3, transSpeed = 0.17 }, "Reload", "reload")
		end
	end
end

function AnimationController.PlayBoltAction(boltReady)
	local ws = weaponState.wepStats()
	if not ws then
		return
	end
	local animName = boltReady and weaponAnimationName(ws, "boltChamber") or weaponAnimationName(ws, "boltClose")
	local boltKey = if boltReady then "boltChamber" else "boltClose"
	AnimationController.PlayAnimation(animName, { transSpeed = 0.05 }, "BoltAction", boltKey)
end

function AnimationController.PlayReloadAction(useClip)
	local ws = weaponState.wepStats()
	if not ws then
		return
	end
	local animSpeed = ws.reloadSpeedModifier
	local animName = if useClip then weaponAnimationName(ws, "clipReload") else weaponAnimationName(ws, "reload")
	if animName then
		AnimationController.PlayAnimation(animName, { looped = useClip, speed = animSpeed, transSpeed = 0.17 }, "Reload", "reload")
	end
end

function AnimationController.PlayFireAnim()
	local ws = weaponState.wepStats()
	local fireName = weaponAnimationName(ws, "fire")
	if fireName then
		AnimationController.PlayAnimation(fireName, {}, "Fire", "fire")
	end
end

function AnimationController.PlaySwitchFireModeAnim()
	local ws = weaponState.wepStats()
	local switchName = weaponAnimationName(ws, "switch")
	if switchName then
		AnimationController.PlayAnimation(switchName, { transSpeed = 0.2 }, "Switch", "switch")
	end
end

return AnimationController
