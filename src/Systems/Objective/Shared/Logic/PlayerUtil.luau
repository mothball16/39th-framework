--!strict
local Players = game:GetService("Players")

local PlayerUtil = {}

function PlayerUtil.GetDefaultTeamId(player: Player): string?
	if player.Team then
		return player.Team.Name
	end
	return nil
end

function PlayerUtil.GetCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerUtil.GetPlayersNearPart(part: BasePart, radius: number?): { Player }
	local zoneRadius = radius or math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2
	local players = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local root = PlayerUtil.GetCharacterRoot(player)
		if root and (root.Position - part.Position).Magnitude <= zoneRadius then
			table.insert(players, player)
		end
	end

	return players
end

function PlayerUtil.CountTeams(players: { Player }, getTeamId: (Player) -> string?): ({ [string]: number }, number)
	local teamCounts = {}
	local teamCount = 0

	for _, player in ipairs(players) do
		local teamId = getTeamId(player)
		if not teamId then
			continue
		end
		if not teamCounts[teamId] then
			teamCount += 1
			teamCounts[teamId] = 0
		end
		teamCounts[teamId] += 1
	end

	return teamCounts, teamCount
end

function PlayerUtil.ResolveSingleTeam(players: { Player }, getTeamId: (Player) -> string?): (string?, boolean)
	local teamCounts, teamCount = PlayerUtil.CountTeams(players, getTeamId)
	if teamCount == 0 then
		return nil, false
	end
	if teamCount > 1 then
		return nil, true
	end
	return next(teamCounts), false
end

return PlayerUtil
