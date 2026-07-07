--!strict
local Signal = require("@game/ReplicatedStorage/Packages/signal")
local Types = require("@game/ReplicatedStorage/Systems/Weapon/Core/ConfigurationTypes")

export type LocalEvents = {
	BulletHit: Signal.Signal<Types.WeaponStats, Vector3, RaycastResult>,
	WeaponEquipRequested: Signal.Signal<>,
	WeaponIdleRequested: Signal.Signal<>,
	FireAnimRequested: Signal.Signal<>,
	ReloadRequested: Signal.Signal<string?>,
	SwitchFireModeAnimRequested: Signal.Signal<>,
	StopAllRequested: Signal.Signal<>,

	PlayAnimationRequested: Signal.Signal<
		string,
		{ [string]: any }?,
		{ key: string?, tag: string, defaultsKey: string? }?
	>,
	StopAnimationRequested: Signal.Signal<string, number>,
	BoltActionRequested: Signal.Signal<boolean>,
	ReloadActionRequested: Signal.Signal<boolean>,
	AnimationEventReached: Signal.Signal<string, string, string?, AnimationTrack, string>,
	AnimationStopped: Signal.Signal<string, AnimationTrack, string>,
}

return function(): LocalEvents
	return {
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
		AnimationEventReached = Signal.new(),
		AnimationStopped = Signal.new(),
	} :: LocalEvents
end
