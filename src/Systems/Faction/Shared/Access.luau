--[[
resolves asset paths and provides config without having to typecast in every script that uses the config
this helps reduce the amount of boilerplate that has to be put up top in every script
]]

local AccessUtility = require("@game/ReplicatedStorage/Utility/Access")
local Types = require("./Core/Types")

local access = AccessUtility.create({
	assetsTag = "Faction_Assets",
	configTag = "Faction_GameConfig",
}) :: Types.Access

return access
