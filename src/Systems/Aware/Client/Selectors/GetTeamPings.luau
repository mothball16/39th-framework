--!strict
--[[
flattens teamValues into keyed ping entries for the renderer
]]

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")

local computed = Charm.computed

local function pingKey(playerKey: string, pingType: string): string
	return `{playerKey}/{pingType}`
end

return function(teamValues: Charm.Getter<Types.OwnedValuesByKey>): Charm.Getter<{ [string]: Types.PingInfo }>
	local derivedPings = computed(function()
		local flattened = {}

		for playerKey, ownedValues in pairs(teamValues()) do
			if not ownedValues.Pings then
				continue
			end
			for pingType, pingInfo in pairs(ownedValues.Pings) do
				local key = pingKey(playerKey, pingType)
				flattened[key] = pingInfo
			end
		end
		return flattened
	end)

	return derivedPings
end
