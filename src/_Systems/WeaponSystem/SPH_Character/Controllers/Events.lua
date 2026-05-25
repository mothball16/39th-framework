local Signal = require("@game/ReplicatedStorage/Packages/signal")
local Types = require("@game/ReplicatedStorage/SPH_Framework/Core/ConfigurationTypes")
local Events = {}
Events.__index = Events

type self = {
	BulletHit: Signal.Signal<Types.WeaponStats, RaycastResult>,

	WeaponEquipRequested: Signal.Signal<>,
	WeaponIdleRequested: Signal.Signal<>,
	FireAnimRequested: Signal.Signal<>,
	ReloadRequested: Signal.Signal<string?>,
	SwitchFireModeAnimRequested: Signal.Signal<>,
	StopAllRequested: Signal.Signal<>,
	PlayAnimationRequested: Signal.Signal<string, { [string]: any }?, string?, string?>,
	StopAnimationRequested: Signal.Signal<string, number>,
	BoltActionRequested: Signal.Signal<boolean>,
	ReloadActionRequested: Signal.Signal<boolean>,
	KeyframeReached: Signal.Signal<string, string, AnimationTrack, string>,
	AnimationStopped: Signal.Signal<string, AnimationTrack, string>,
}

export type Events = setmetatable<self, typeof(Events)>

function Events.new(): Events
	return setmetatable({
		BulletHit = Signal.new(),
		
		WeaponEquipRequested = Signal.new(),
		WeaponIdleRequested = Signal.new(),
		FireAnimRequested = Signal.new(),
		ReloadRequested = Signal.new(),
		SwitchFireModeAnimRequested = Signal.new(),
		StopAllRequested = Signal.new(),
		PlayAnimationRequested = Signal.new(),
		StopAnimationRequested = Signal.new(),
		BoltActionRequested = Signal.new(),
		ReloadActionRequested = Signal.new(),
		KeyframeReached = Signal.new(),
		AnimationStopped = Signal.new(),
	} :: self, Events)
end

return Events
