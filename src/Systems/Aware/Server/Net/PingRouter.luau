--!strict
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local NetworkTypes = require("@game/ReplicatedStorage/Systems/Aware/Core/NetworkTypes")
local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local PlayerKey = require("@game/ReplicatedStorage/Systems/Aware/Core/PlayerKey")
local ServerState = require("../Core/ServerState")

local MAIN_PING = "Main"

local PingRouter = {}

local function setMainPing(player: Player, makePing: ((owned: Types.OwnedValues) -> Types.PingInfo)?)
	local playerKey = PlayerKey.ToPlayerKey(player)
	ServerState.valuesByPlayer(function(previous)
		local owned = previous[playerKey]
		if not owned then
			error(`No state entry for player {playerKey}`)
		end
		local ownedValues = owned :: Types.OwnedValues

		local pings = table.clone(ownedValues.Pings)
		pings[MAIN_PING] = if makePing then makePing(ownedValues) else nil

		local next = table.clone(previous)
		next[playerKey] = {
			Team = ownedValues.Team,
			NameTag = ownedValues.NameTag,
			Pings = pings,
		}
		return next
	end)
end

function PingRouter.ProcessRequestPing(player: Player, inbound: NetworkTypes.RequestPingPayload)
	setMainPing(player, function(owned)
		return {
			imageId = Access.config.PingImageId,
			name = owned.NameTag,
			position = inbound.position,
			owner = player,
		}
	end)
end

function PingRouter.ProcessRequestRemovePing(player: Player)
	setMainPing(player, nil)
end

return PingRouter
