--[[
	AnimationEvents
	Signal-based event bus that decouples WeaponController from AnimationController.
	
	Instead of WeaponController calling AnimationController methods directly,
	it fires request signals here. AnimationController listens and responds.
	
	Instead of AnimationController invoking WeaponController callbacks,
	it fires event signals here. WeaponController listens and responds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages.signal)

local AnimationEvents = {}

-- Weapon → Animation requests
AnimationEvents.WeaponEquipRequested = Signal.new()
AnimationEvents.WeaponIdleRequested = Signal.new()
AnimationEvents.WeaponEquipPreloadRequested = Signal.new()
AnimationEvents.FireAnimRequested = Signal.new()
AnimationEvents.ReloadRequested = Signal.new() -- (lastGunModelName: string?)
AnimationEvents.SwitchFireModeAnimRequested = Signal.new()
AnimationEvents.StopAllRequested = Signal.new()
AnimationEvents.PlayAnimationRequested = Signal.new() -- (animName, params, animType, preload)
AnimationEvents.StopAnimationRequested = Signal.new() -- (animName, transTime)
AnimationEvents.BoltActionRequested = Signal.new() -- (boltReady: boolean)
AnimationEvents.ReloadActionRequested = Signal.new() -- (useClip: boolean)

-- Animation → Weapon events
AnimationEvents.KeyframeReached = Signal.new() -- (animName, keyframeName, animTrack, animType)
AnimationEvents.AnimationStopped = Signal.new() -- (animName, animTrack, animType)

return AnimationEvents
