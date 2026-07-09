--!strict
-- utility class for faction configurations so u dont have to hardcode functions
local AccessChecks = {}
local GroupService = game:GetService("GroupService")
local TeamService = game:GetService("Teams")
local Players = game:GetService("Players")

local Types = require("../Core/Types")

type GroupInfo = {
	isMember: boolean,
	roles: { string },
	roleIds: { number },
	rank: number,
}

local GroupInfoByPlayer: { [Player]: { [number]: GroupInfo } } = {}
-- table is weak-keyed for auto cleanup
setmetatable(GroupInfoByPlayer, { __mode = "k" })

function AccessChecks.InTeam(teams: { Team | string }): Types.AccessCheck
	local teamInstances = {}
	for _, team in ipairs(teams) do
		if type(team) == "string" then
			local teamInstance = TeamService:FindFirstChild(team) :: Team?
			if not teamInstance then
				error(`team {team} not found`)
			end
			table.insert(teamInstances, teamInstance)
		elseif team:IsA("Team") then
			table.insert(teamInstances, team)
		else
			error(`invalid team type: {type(team)}`)
		end
	end

	return function(userId: number)
		for _, team in ipairs(teamInstances) do
			local player = Players:GetPlayerByUserId(userId)
			if player and player.Team == team then
				return true
			end
		end

		return false
	end
end

--#region [ group access checks ]
local function getGroupInfo(player: Player, groupId: number): GroupInfo
	-- get or create the player entry for serverside caching
	local info = GroupInfoByPlayer[player]
	if not info then
		info = {}
		GroupInfoByPlayer[player] = info
	end

	local groupInfo = info[groupId]
	if groupInfo then
		return groupInfo
	end

	local nextGroupInfo: GroupInfo = {
		isMember = false,
		roles = {},
		roleIds = {},
		rank = 0,
	}

	local data: { IsMember: boolean, Roles: { { Id: number, Name: string, Rank: number } } } =
		GroupService:GetRolesInGroupAsync(player.UserId, groupId)

	nextGroupInfo.isMember = data.IsMember

	for _, role in ipairs(data.Roles) do
		nextGroupInfo.rank = math.max(nextGroupInfo.rank, role.Rank)
		table.insert(nextGroupInfo.roles, role.Name)
		table.insert(nextGroupInfo.roleIds, role.Id)
	end

	info[groupId] = nextGroupInfo
	return nextGroupInfo
end

function AccessChecks.InGroup(groupIds: { number })
	return function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return false
		end

		for _, groupId in ipairs(groupIds) do
			local groupInfo = getGroupInfo(player, groupId)
			if groupInfo.isMember then
				return true
			end
		end
		return false
	end
end

function AccessChecks.HasRoleInGroup(groupIds: { [number]: number | string }): Types.AccessCheck
	return function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return false
		end

		for groupId, role in pairs(groupIds) do
			local groupInfo = getGroupInfo(player, groupId)
			if type(role) == "number" and table.find(groupInfo.roleIds, role) then
				return true
			end
			if type(role) == "string" and table.find(groupInfo.roles, role) then
				return true
			end
		end
		return false
	end
end

function AccessChecks.AboveRankInGroup(groupIds: { [number]: number }): Types.AccessCheck
	return function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return false
		end

		for groupId, rank in pairs(groupIds) do
			local groupInfo = getGroupInfo(player, groupId)
			if groupInfo.rank >= rank then
				return true
			end
		end
		return false
	end
end
--#endregion [ group access checks ]

return AccessChecks
