--!strict
--#selene: allow(incorrect_standard_library_use)
local Charm = require("@game/ReplicatedStorage/Packages/Charm")

local Types = require("./Types")

return function(): Types.State
	local state = {
		objectiveById = Charm.atom({} :: { [string]: Types.ObjectiveSnapshot }),
	}

	return state
end
