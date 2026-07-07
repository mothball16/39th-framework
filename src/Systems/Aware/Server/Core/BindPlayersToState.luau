--!strict
--[[
binds Players service lifecycle and team polling to server state updates
]]
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Players = game:GetService("Players")
local PlayerKey = require("@game/ReplicatedStorage/Systems/Aware/Core/PlayerKey")

local function spawnDisconnectable(fn: () -> ())
	local thread = task.spawn(fn)
	return function()
		task.cancel(thread)
	end
end

return function(state: Types.State)
	local maid = Maid.new()

	local function bindPlayer(player: Player)
		state.valuesByPlayer(function(previous)
			local next = table.clone(previous)
			next[PlayerKey.ToPlayerKey(player)] = {
				Team = Access.config.GetTeamValue(player),
				Pings = {} :: { [string]: Types.PingInfo },
			}
			return next
		end)
	end

	maid:GiveTask(Players.PlayerAdded:Connect(bindPlayer))
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end

	maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		state.valuesByPlayer(function(previous)
			local next = table.clone(previous)
			next[PlayerKey.ToPlayerKey(player)] = nil :: any
			return next
		end)
	end))

	maid:GiveTask(spawnDisconnectable(function()
		-- polling loop to update teams per player
		while task.wait(Access.config.TeamUpdateInterval) do
			local updates: { [string]: Types.OwnedValues } = {}
			for playerKey, ownedValues in state.valuesByPlayer() do
				local team = Access.config.GetTeamValue(PlayerKey.FromPlayerKey(playerKey))
				if team ~= ownedValues.Team then
					local entry = table.clone(ownedValues)
					entry.Team = team
					updates[playerKey] = entry
				end
			end

			if next(updates) then
				state.valuesByPlayer(function(previous)
					local nextState = table.clone(previous)
					for playerKey, ownedValues in updates do
						nextState[playerKey] = ownedValues
					end
					return nextState
				end)
			end
		end
	end))

	return function()
		maid:DoCleaning()
	end
end
