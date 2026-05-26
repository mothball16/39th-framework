--[[
	Plays first-person (viewmodel) and third-person animation tracks in sync.
	Charm state drives stance/movement; AnimationEvents carries weapon requests from WeaponController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local CharacterStateModule = require(Framework.State.CharacterState)
local WeaponStateModule = require(Framework.State.WeaponState)
local config = Access.config
local Enums = require(Framework.Core.Enums)
local Events = require(script.Parent.Events)

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

local AnimationController = {}
AnimationController.__index = AnimationController

type self = {
	loadedAnims: { [string]: { vm: AnimationTrack, tp: AnimationTrack } },
	activeTweens: { [AnimationTrack]: any },
	vmAnimator: Animator,
	characterAnimator: Animator,
	animationsFolder: Folder,
	crouchIdleAnim: AnimationTrack,
	crouchMoveAnim: AnimationTrack,
	proneIdleAnim: AnimationTrack,
	proneMoveAnim: AnimationTrack,
	moveAnim: AnimationTrack?,
	holdAnimKey: string?,
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,
	events: Events.Events,
}

export type AnimationController = typeof(setmetatable({} :: self, AnimationController))

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

local function clearTweenForTrack(self: AnimationController, track: AnimationTrack)
	local entry = self.activeTweens[track]
	if not entry then
		return
	end
	entry.onEnd:Disconnect()
	entry.tween:Cancel()
	entry.conn:Disconnect()
	entry.val:Destroy()
	self.activeTweens[track] = nil
end

local function fadeTrack(self: AnimationController, track: AnimationTrack, targetWeight: number, fadeTime: number?, speed: number?)
	if targetWeight == 0 and not track.IsPlaying then
		return
	end

	clearTweenForTrack(self, track)

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
		if self.activeTweens[track] == nil then
			return
		end
		conn:Disconnect()
		val:Destroy()
		self.activeTweens[track] = nil
		if targetWeight == 0 then
			track:Stop(0)
		end
	end)

	self.activeTweens[track] = {
		tween = tween,
		conn = conn,
		val = val,
		onEnd = onEnd,
	}

	tween:Play()
end

local function loadHumanoidAnim(self: AnimationController, animation: Animation, looped: boolean, priority: Enum.AnimationPriority)
	local anim = self.state.Parts.Humanoid.Animator:LoadAnimation(animation)
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

local function resolveAnimationAsset(path: Instance, animName: string)
	local split = string.find(animName, "/")
	if split then
		local folderName = animName:sub(1, split - 1)
		local remainingAnimName = animName:sub(split + 1)
		local folder = path:FindFirstChild(folderName)
		if not folder then
			error(`animation folder {folderName} not found: {animName}`)
		end
		return resolveAnimationAsset(folder, remainingAnimName)
	end
	return path:FindFirstChild(animName)
end

local function getOrCreateTracks(self: AnimationController, animName: string, playParams: { looped: boolean, priority: Enum.AnimationPriority })
	local cached = self.loadedAnims[animName]
	if cached then
		cached.vm.Looped = playParams.looped
		cached.vm.Priority = playParams.priority
		cached.tp.Looped = playParams.looped
		cached.tp.Priority = playParams.priority
		return cached
	end

	local animAsset = resolveAnimationAsset(self.animationsFolder, animName)
	if not animName or not animAsset then
		return nil
	end

	local vmTrack = self.vmAnimator:LoadAnimation(animAsset)
	vmTrack.Looped = playParams.looped
	vmTrack.Priority = playParams.priority

	local tpTrack = self.characterAnimator:LoadAnimation(animAsset)
	tpTrack.Looped = playParams.looped
	tpTrack.Priority = playParams.priority

	vmTrack.KeyframeReached:Connect(function(keyframeName)
		local currentType = vmTrack:GetAttribute("AnimType") or "Unknown"
		self.events.KeyframeReached:Fire(animName, keyframeName, vmTrack, currentType)
	end)

	vmTrack.Stopped:Connect(function()
		local currentType = vmTrack:GetAttribute("AnimType") or "Unknown"
		self.events.AnimationStopped:Fire(animName, vmTrack, currentType)
	end)

	local tracks = { vm = vmTrack, tp = tpTrack }
	self.loadedAnims[animName] = tracks
	return tracks
end

local function preloadWeaponAnimations(self: AnimationController, wepStats)
	local anims = wepStats.Animations
	if type(anims) ~= "table" then
		return
	end
	for key, animName in pairs(anims) do
		if type(animName) == "string" and animName ~= "" then
			getOrCreateTracks(self, animName, resolvePlayParams(key, nil))
		end
	end
end

function AnimationController.new(params: {
	vmAnimator: Animator,
	characterAnimator: Animator,
	animationsFolder: Folder,
	weaponState: WeaponStateModule.WeaponState,
	state: CharacterStateModule.CharacterState,
	events: Events.Events,
}): AnimationController
	local self = setmetatable({
		loadedAnims = {},
		activeTweens = {},
		vmAnimator = params.vmAnimator,
		characterAnimator = params.characterAnimator,
		animationsFolder = params.animationsFolder,
		crouchIdleAnim = nil :: AnimationTrack,
		crouchMoveAnim = nil :: AnimationTrack,
		proneIdleAnim = nil :: AnimationTrack,
		proneMoveAnim = nil :: AnimationTrack,
		moveAnim = nil,
		holdAnimKey = nil,
		weaponState = params.weaponState,
		state = params.state,
		events = params.events,	
	} :: self, AnimationController)

	self.crouchIdleAnim = loadHumanoidAnim(self, params.animationsFolder.Crouch_Idle, true, Enum.AnimationPriority.Idle)
	self.crouchMoveAnim = loadHumanoidAnim(self, params.animationsFolder.Crouch_Move, true, Enum.AnimationPriority.Movement)
	self.proneIdleAnim = loadHumanoidAnim(self, params.animationsFolder.Prone_Idle, true, Enum.AnimationPriority.Idle)
	self.proneMoveAnim = loadHumanoidAnim(self, params.animationsFolder.Prone_Move, true, Enum.AnimationPriority.Movement)

	Charm.subscribe(self.state.sprinting, function(sprinting)
		self:SyncSprinting(sprinting)
	end)
	Charm.subscribe(self.state.stance, function(stance)
		self:SyncStance(stance)
	end)
	Charm.subscribe(self.state.moving, function(moving)
		self:SyncMoving(moving)
	end)
	Charm.subscribe(self.weaponState.holdStance, function(newStance, oldStance)
		self:SyncHoldStance(newStance, oldStance)
	end)
	Charm.subscribe(self.weaponState.chambering, function(value)
		self:SyncChambering(value)
	end)

	self.events.WeaponEquipRequested:Connect(function()
		self:WeaponEquip()
	end)
	self.events.WeaponIdleRequested:Connect(function()
		self:WeaponIdle()
	end)
	self.events.FireAnimRequested:Connect(function()
		self:PlayFireAnim()
	end)
	self.events.ReloadRequested:Connect(function(lastGunModelName)
		self:WeaponReload(lastGunModelName)
	end)
	self.events.SwitchFireModeAnimRequested:Connect(function()
		self:PlaySwitchFireModeAnim()
	end)
	self.events.StopAllRequested:Connect(function()
		self:StopAll()
	end)
	self.events.PlayAnimationRequested:Connect(function(animName, parameters, animType, propertyKey)
		self:PlayAnimation(animName, parameters, animType, propertyKey)
	end)
	self.events.StopAnimationRequested:Connect(function(animName, transTime)
		self:StopAnimation(animName, transTime)
	end)
	self.events.BoltActionRequested:Connect(function(boltReady)
		self:PlayBoltAction(boltReady)
	end)
	self.events.ReloadActionRequested:Connect(function(useClip)
		self:PlayReloadAction(useClip)
	end)

	return self
end

function AnimationController.SyncStance(self: AnimationController, stance)
	if self.moveAnim then
		fadeTrack(self,self.moveAnim, 0, config.stanceChangeTime)
	end

	if stance == 0 then
		self.moveAnim = nil
		fadeTrack(self,self.crouchIdleAnim, 0, config.stanceChangeTime)
		fadeTrack(self,self.proneIdleAnim, 0, config.stanceChangeTime)
	elseif stance == 1 then
		self.moveAnim = self.crouchMoveAnim
		if self.state.moving() then
			fadeTrack(self,self.moveAnim, 1, config.stanceChangeTime)
		end
		fadeTrack(self,self.proneIdleAnim, 0, config.stanceChangeTime)
		fadeTrack(self,self.crouchIdleAnim, 1, config.stanceChangeTime)
	elseif stance == 2 then
		self.moveAnim = self.proneMoveAnim
		fadeTrack(self,self.crouchIdleAnim, 0, config.stanceChangeTime)
		fadeTrack(self,self.proneIdleAnim, 1, config.stanceChangeTime)
		if self.state.moving() then
			fadeTrack(self,self.moveAnim, 1, config.stanceChangeTime)
		end
	end
end

function AnimationController.SyncMoving(self: AnimationController, moving)
	if not self.moveAnim then
		return
	end
	if moving then
		fadeTrack(self,self.moveAnim, 1, config.stanceChangeTime)
	else
		fadeTrack(self,self.moveAnim, 0, config.stanceChangeTime)
	end
end

function AnimationController.SyncSprinting(self: AnimationController, sprinting)
	local stats = self.weaponState.wepStats()
	local sprintName = weaponAnimationName(stats, "sprint")
	if not sprintName then
		return
	end
	if sprinting then
		self:PlayAnimation(sprintName, { transSpeed = 0.5 }, "Sprint", "sprint")
	else
		self:StopAnimation(sprintName, 0.5)
	end
end

function AnimationController.StopAnimation(self: AnimationController, animName: string, transTime: number)
	local tracks = self.loadedAnims[animName]
	if tracks then
		fadeTrack(self,tracks.vm, 0, transTime)
		fadeTrack(self,tracks.tp, 0, transTime)
	end
end

function AnimationController.PlayAnimation(self: AnimationController, animName: string, parameters: {[string]: any}?, animType: string?, propertyKey: string?)
	local merged = resolvePlayParams(propertyKey, parameters)
	local tracks = getOrCreateTracks(self, animName, merged)

	if not tracks then
		warn("no tracks for anim", animName)
		return nil
	end

	local typeTag = animType or "Play"
	tracks.vm:SetAttribute("AnimType", typeTag)
	tracks.tp:SetAttribute("AnimType", typeTag)

	local transSpeed = merged.transSpeed
	local speed = merged.speed or 1

	fadeTrack(self,tracks.vm, 1, transSpeed, speed)
	fadeTrack(self,tracks.tp, 1, transSpeed, speed)

	return tracks.vm
end

function AnimationController.StopAll(self: AnimationController)
	for _, animator in { self.vmAnimator, self.characterAnimator } do
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				fadeTrack(self,track, 0, 0)
			end
		end
	end
end

function AnimationController.AdjustMoveAnimSpeed(self: AnimationController, speed: number)
	if self.moveAnim then
		self.moveAnim:AdjustSpeed(speed)
	end
end

function AnimationController.SyncHoldStance(self: AnimationController, newStance, oldStance)
	if self.holdAnimKey then
		self:StopAnimation(self.holdAnimKey, 0.3)
		self.holdAnimKey = nil
	end
	local stats = self.weaponState.wepStats()
	if not self.state.equippedTool() or not stats then
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
		self:StopAnimation(animToPlay, 0)
		local started = self:PlayAnimation(animToPlay, { transSpeed = 0.3 }, "Hold", propertyKey)
		self.holdAnimKey = started and animToPlay or nil
	else
		-- No anim for this stance: bounce Ready ↔ Patrol when dropping from Ready to Low.
		if oldStance == Enums.HoldStance.Ready and newStance == Enums.HoldStance.Low then
			self.weaponState.holdStance(Enums.HoldStance.Patrol)
		else
			self.weaponState.holdStance(Enums.HoldStance.Ready)
		end
	end
end

function AnimationController.WeaponEquip(self: AnimationController)
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end
	self:StopAll()
	self.holdAnimKey = nil
	-- Tracks were built for the previous tool; reuse breaks hold/sprint after swapping weapons.
	table.clear(self.loadedAnims)
	preloadWeaponAnimations(self, ws)

	local equipName = weaponAnimationName(ws, "equip")
	local equipTrack = equipName and self:PlayAnimation(equipName, {}, "Equip", "equip")
	if equipTrack then
		equipTrack.Stopped:Connect(function()
			self.weaponState.equipping(false)
		end)
	else
		self.weaponState.equipping(false)
	end
end

function AnimationController.WeaponIdle(self: AnimationController)
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end
	local idleName = weaponAnimationName(ws, "idle")
	if idleName then
		self:PlayAnimation(idleName, {}, "Idle", "idle")
	end
end

function AnimationController.SyncChambering(self: AnimationController, value)
	local stats = self.weaponState.wepStats()
	if value == false or not stats or not self.state.equippedTool() then
		return
	end

	local useChamber = self.state.equippedTool().BoltReady.Value or self.weaponState.fireMode() == 5
	local animName = useChamber and weaponAnimationName(stats, "boltChamber") or weaponAnimationName(stats, "boltClose")
	local chamberKey = if useChamber then "boltChamber" else "boltClose"

	local playing = self:PlayAnimation(animName, { transSpeed = 0.05 }, "Chamber", chamberKey)
	if playing then
		playing.Stopped:Once(function()
			self.weaponState.chambering(false)
		end)
	else
		warn("no chamber anim")
		self.weaponState.chambering(false)
	end
end

-- UBGL (fire mode 4) uses the UBGL stat block for the reload clip name when present.
local function playUbglReload(self: AnimationController, animSpeed: number)
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end
	local ubglStats = ws.getStatsForMode(4)
	local reloadAnim = weaponAnimationName(ubglStats, "reload") or weaponAnimationName(ws, "reload")
	if reloadAnim then
		self:PlayAnimation(reloadAnim, { speed = animSpeed, transSpeed = 0.17 }, "Reload", "reload")
	end
end

-- Open bolt, then either clip loop or normal reload depending on ammo rules.
local function playBoltOpenReloadSequence(self: AnimationController, lastGunModelName: string?, animSpeed: number)
	local tool = self.state.equippedTool()
	local gunAmmo = tool:FindFirstChild("Ammo")
	local stats = self.weaponState.wepStats()
	if not stats then
		return
	end

	local boltOpenTrack = self:PlayAnimation(
		stats.boltOpen,
		{ speed = animSpeed, priority = Enum.AnimationPriority.Action2, transSpeed = 0.17 },
		"BoltOpen",
		nil
	)
	if not boltOpenTrack then
		self.weaponState.reloading(false)
		return
	end

	boltOpenTrack.Stopped:Once(function()
		if not self.state.equippedTool() or not gunAmmo then
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
				self:PlayAnimation(clipName, { looped = true, speed = animSpeed, transSpeed = 0.17 }, "Reload", "reload")
			end
			return
		end

		if lastGunModelName and self.weaponState.gunModel() and lastGunModelName ~= self.weaponState.gunModel().Name then
			return
		end
		local reloadName = weaponAnimationName(stats, "reload")
		if reloadName then
			self:PlayAnimation(
				reloadName,
				{ speed = animSpeed, transSpeed = 0.17, looped = stats.magType > 1 },
				"Reload",
				"reload"
			)
		end
	end)
end

function AnimationController.WeaponReload(self: AnimationController, lastGunModelName)
	local ws = self.weaponState.wepStats()
	if not self.state.equippedTool() or not ws then
		return
	end
	self.weaponState.reloading(true)
	local animSpeed = ws.reloadSpeedModifier

	if self.weaponState.fireMode() == 4 and ws.hasUBGL then
		playUbglReload(self, animSpeed)
		return
	end

	local tool = self.state.equippedTool()
	local gunAmmo = tool:FindFirstChild("Ammo")
	local stats = ws

	local needsBoltOpen = stats.operationType == 3
		or (stats.operationType == 2 and gunAmmo and gunAmmo.MagAmmo.Value <= 0 and not tool.Chambered.Value)

	if needsBoltOpen then
		playBoltOpenReloadSequence(self, lastGunModelName, animSpeed)
	else
		local reloadName = weaponAnimationName(stats, "reload")
		if reloadName then
			self:PlayAnimation(reloadName, { speed = animSpeed, priority = Enum.AnimationPriority.Action3, transSpeed = 0.17 }, "Reload", "reload")
		end
	end
end

function AnimationController.PlayBoltAction(self: AnimationController, boltReady)
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end
	local animName = boltReady and weaponAnimationName(ws, "boltChamber") or weaponAnimationName(ws, "boltClose")
	local boltKey = if boltReady then "boltChamber" else "boltClose"
	self:PlayAnimation(animName, { transSpeed = 0.05 }, "BoltAction", boltKey)
end

function AnimationController.PlayReloadAction(self: AnimationController, useClip)
	local ws = self.weaponState.wepStats()
	if not ws then
		return
	end
	local animSpeed = ws.reloadSpeedModifier
	local animName = if useClip then weaponAnimationName(ws, "clipReload") else weaponAnimationName(ws, "reload")
	if animName then
		self:PlayAnimation(animName, { looped = useClip, speed = animSpeed, transSpeed = 0.17 }, "Reload", "reload")
	end
end

function AnimationController.PlayFireAnim(self: AnimationController)
	local ws = self.weaponState.wepStats()
	local fireName = weaponAnimationName(ws, "fire")
	if fireName then
		self:PlayAnimation(fireName, {}, "Fire", "fire")
	end
end

function AnimationController.PlaySwitchFireModeAnim(self: AnimationController)
	local ws = self.weaponState.wepStats()
	local switchName = weaponAnimationName(ws, "switch")
	if switchName then
		self:PlayAnimation(switchName, { transSpeed = 0.2 }, "Switch", "switch")
	end
end

return AnimationController
