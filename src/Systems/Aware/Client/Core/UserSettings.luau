--!strict
--[[
temporarily hardcoded client-side settings, will be replaced with a config system later
]]
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local atom = Charm.atom
export type UserSettings = {
	PingKey: Charm.Atom<Enum.KeyCode>,
	ClearPingKey: Charm.Atom<Enum.KeyCode>,

	PingSize: Charm.Atom<UDim2>,
	UseDeadzone: Charm.Atom<boolean>,
	PingClearDeadzone: Charm.Atom<number>,

	HidePingDistance: Charm.Atom<number>,
	HidePingTransModifier: Charm.Atom<number>,
}

local UserSettings: UserSettings = {
	PingKey = atom(Enum.KeyCode.Z),
	ClearPingKey = atom(Enum.KeyCode.N),

	PingSize = atom(UDim2.fromOffset(40, 40)),
	UseDeadzone = atom(false),
	PingClearDeadzone = atom(0.03),
	HidePingDistance = atom(0.03),
	HidePingTransModifier = atom(0.25),
}

return UserSettings
