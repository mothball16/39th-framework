--!strict
const Players = game:GetService("Players")
local state = require("@game/ReplicatedStorage/Systems/Faction/Extensions/GetFactionState")
local AwareTypes = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local PlayerKey = require("@game/ReplicatedStorage/Systems/Aware/Core/PlayerKey")
local FactionTypes = require("@game/ReplicatedStorage/Systems/Faction/Core/Types")
local function makeDefaultClassPrefix(classKey: string): string
	local prefix = {}
	-- %u = uppercase letter, [%l]* = zero or more lowercase letters after it (PascalCase word segments)
	for word in string.gmatch(classKey, "%u[%l]*") do
		table.insert(prefix, word:sub(1, 1))
	end
	return table.concat(prefix)
end


return function(classPrefixes: { [string]: string }, nameLength: number): AwareTypes.ShortenName
    local function getPrefix(assignment: FactionTypes.PlayerAssignment): string
        if not assignment then
            return ""
        end
        local classKey = assignment.ClassKey or ""
        local prefix = classPrefixes[classKey]
        if not prefix then
            prefix = makeDefaultClassPrefix(classKey)
        end
    
        return if prefix ~= "" then `[{prefix}] ` else ""
    end
    

    return function(playerKey: string): string
        local assignment = state.playerAssignmentByUserId()[playerKey]
        local player = PlayerKey.FromPlayerKey(playerKey)
        if not player then
            return "UNKNOWN"
        end

        local final = `{getPrefix(assignment)}{player.DisplayName:sub(1, nameLength)}`
        return final
    end
end
