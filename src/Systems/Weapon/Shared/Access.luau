local AccessUtility = require("@game/ReplicatedStorage/Utility/Access")
local ConfigurationTypes = require(script.Parent.Core.ConfigurationTypes)

type Access = AccessUtility.Access<ConfigurationTypes.MainGameSettings>

local access = AccessUtility.create({
	configTag = "SPH_GameConfig",
}) :: Access

return access
