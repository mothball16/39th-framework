--!strict
--[[
connects the state to the ping tag renderer
the WHEN of ping tag creation/deletion is handled here
]]

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")

local PingTagRenderer = require("./PingTagRenderer")
local GetPlayerSlice = require("@game/ReplicatedStorage/Systems/Aware/Selectors/GetPlayerSlice")

local observe = Charm.observe
local effectScope = Charm.effectScope
local computed = Charm.computed
local effect = Charm.effect


return function(player: Player, state: Types.State)
	local playerSlice = GetPlayerSlice(player, state)

	observe(playerSlice.teamValues, function(_ownedValues: Types.OwnedValues, playerKey: string)
		local unmount = effectScope(function()
			local pings = computed(function()
				return playerSlice.teamValues()[playerKey].Pings
			end)

			observe(pings, function(pingInfo: Types.PingInfo, pingType: string)
				local destroyPingTag, container = PingTagRenderer.CreatePingTag(pingInfo.owner, pingInfo.position, pingInfo :: Types.PingTagProps)

				local position = computed(function(): Vector3
					return playerSlice.teamValues()[playerKey].Pings[pingType].position
				end)

				effect(function()
					container.Position = position()
				end)

				return function()
					destroyPingTag()
				end
			end)
		end)

		return unmount
	end)
end
