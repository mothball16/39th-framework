local AccessUtility = require("@game/ReplicatedStorage/Utility/Access")
local Types = require("./Core/Types")

export type Access = AccessUtility.Access<Types.GameSettings>

local access = AccessUtility.create({
	configTag = "Aware_GameConfig",
}) :: Access

return access
