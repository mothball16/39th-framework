--[[
creates the team-check function based off of the player faction instead of the team value
in retrospect - player attributes may be a smarter choice, consider rebuilding this in the future
]]

local state = require("@game/ReplicatedStorage/Systems/Faction/Extensions/GetFactionState")
local Utilities = require("@game/ReplicatedStorage/Systems/Faction/Logic/Utilities")

return function(player: Player): string?
	local assignment = state.playerAssignmentByUserId()[Utilities.ToPlayerKey(player.UserId)]
	return assignment and assignment.FactionId or nil
end
