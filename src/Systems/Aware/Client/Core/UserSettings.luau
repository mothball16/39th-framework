--!strict
--[[
temporarily hardcoded client-side settings, will be replaced with a config system later
]]
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local atom = Charm.atom

local UserSettings: Types.UserSettings = {
	PingKey = atom(Enum.KeyCode.Z),
	ClearPingKey = atom(Enum.KeyCode.N),

	PingSize = atom(UDim2.fromOffset(55, 55)),
	UseDeadzone = atom(true),
	PingClearDeadzone = atom(0.03),
	HidePingDistance = atom(0.03),
	HidePingTransModifier = atom(0.25),

	NameTagSize = atom(14),
	NameTagTransparency = atom(0.25),
	ShowOwnNameTag = atom(false),

	-- WIP
	DefaultNameDisplayType = atom("enemies" :: Types.DisplayType),
	DefaultHealthDisplayType = atom("enemies" :: Types.DisplayType),
}

return UserSettings
