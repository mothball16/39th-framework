-- Shared helpers for fan-out sends (range / blacklist), used by Weapon controllers.

local Players = game:GetService("Players")

local M = {}

function M.asBlacklist(blacklistedPlrs: Player | { Player }): { Player }
	if typeof(blacklistedPlrs) == "Instance" and blacklistedPlrs:IsA("Player") then
		return { blacklistedPlrs }
	end
	return blacklistedPlrs :: { Player }
end

local function isBlacklisted(plr: Player, blacklist: { Player }): boolean
	return table.find(blacklist, plr) ~= nil
end

function M.playersAllExcept(blacklist: { Player }): { Player }
	local out = {}
	for _, plr in Players:GetPlayers() do
		if not isBlacklisted(plr, blacklist) then
			table.insert(out, plr)
		end
	end
	return out
end

function M.playersInRangeExcept(blacklist: { Player }, point: Vector3, range: number): { Player }
	local out = {}
	for _, plr in Players:GetPlayers() do
		if isBlacklisted(plr, blacklist) then
			continue
		end
		if plr:DistanceFromCharacter(point) <= range then
			table.insert(out, plr)
		end
	end
	return out
end

return M
