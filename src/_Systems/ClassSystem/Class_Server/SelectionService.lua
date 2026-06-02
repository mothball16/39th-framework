--[[
service layer for class/faction selection requests
validates request data, handles side effects (item assign/unassign),
and delegates pure state mutations to StateActions
]]

local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")
local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")
local Enums = require("@game/ReplicatedStorage/Class_Framework/Core/Enums")
local StateActions = require("@game/ReplicatedStorage/Class_Framework/Logic/StateActions")

local ItemEquipper = require("./ItemEquipper")
local SelectionService = {}
SelectionService.__index = SelectionService

type self = {
	state: State.State,
	settings: Types.Settings,
}
export type SelectionService = typeof(setmetatable({} :: self, SelectionService))

function SelectionService.new(
	state: State.State,
	settings: Types.Settings
): SelectionService
	local self = setmetatable({
		state = state,
		settings = settings,
	} :: self, SelectionService)

	return self
end

function SelectionService.HandleFactionRequest(self: SelectionService, player: Player, request: {
	factionId: string,
})
	local factionConfig = self.state.configByFactionId()[request.factionId]
	if not factionConfig then
		return
	end

	StateActions.SetPlayerFaction(self.state, player.UserId, factionConfig.ID)
end

function SelectionService.HandleGroupClassRequest(self: SelectionService, player: Player, request: {
	group: string,
	class: string,
}, itemEquipper: ItemEquipper.ItemEquipper)
	local prevClassId = self.state.playerByClassId()[player.UserId]
	if prevClassId then
		itemEquipper:UnassignClassItems(player, prevClassId)
	end

	local factionId = self.state.playerByFactionId()[player.UserId]
	local factionConfig = self.state.configByFactionId()[factionId]

	-- check if the faction exists
	if not factionConfig then
		warn(`player {player.UserId} requested group {request.group} but is not in a faction`)
		return
	end

	-- check if the group exists
	local groupConfig = factionConfig.Groups[request.group]
	if not groupConfig then
		warn(`player {player.UserId} requested group {request.group} but it is not a valid group`)
		player:Kick("invalid action 1")
		return
	end

	-- check if the group is valid
	if not factionConfig.Groups[request.group] then
		warn(`player {player.UserId} requested group {request.group} but it is not a valid group for faction {factionConfig.ID}`)
		player:Kick("invalid action 2")
		return
	end

	-- check if the group is full
	local groupCount = self.state.groupCountByFaction()[factionConfig.ID][request.group]
	if groupCount >= groupConfig.Limit then
		warn(`player {player.UserId} requested group {request.group} but it is full for faction {factionConfig.ID}`)
		return
	end

	-- set the player's group and class
	StateActions.SetPlayerGroupClass(self.state, player.UserId, request.group, request.class)

	-- if the apply class mode is immediate, assign the class items immediately
	if self.settings.ApplyClassMode == Enums.ApplyClassMode.Immediate then
		self:HandleClassApplyRequest(player, { enable = true }, itemEquipper)
	end
end

function SelectionService.HandleClassApplyRequest(self: SelectionService, player: Player, request: {
	enable: boolean
}, itemEquipper: ItemEquipper.ItemEquipper
)
	local classId = self.state.playerByClassId()[player.UserId]
	if not classId then
		warn(`player {player.UserId} requested class applicable but is not in a class`)
		warn(self.state.playerByClassId())
		return
	end
	local character = player.Character
	if not character then
		warn(`player {player.UserId} requested class applicable but is not in a character`)
		return
	end

	-- StateActions only changes assignment state;
	-- item application is explicitly handled at the service boundary.
	if request.enable then
		itemEquipper:AssignClassItems(player, classId)
	else
		itemEquipper:UnassignClassItems(player, classId)
	end
end

function SelectionService.HandleTeamChange(
	self: SelectionService,
	player: Player,
	team: Team,
	itemEquipper: ItemEquipper.ItemEquipper
)
	-- check if the player is even on a team to begin with
	if not team then
		return
	end

	-- check if the player's new team should automatically assign a faction
	local autoFactionAttribute = team:GetAttribute(Enums.Faction.AutoFactionAttribute)
	if not autoFactionAttribute then
		return
	end

	-- make sure the faction the team is assigned to actually exists first
	local factionConfig = self.state.configByFactionId()[autoFactionAttribute]
	if not factionConfig then
		return
	end

	-- if the faction of the new team is the same, don't do anything
	if self.state.playerByFactionId()[player.UserId] == factionConfig.ID then
		return
	end

	-- unassign whatever class the player is in right now because its about to be different
	local prevClassId = self.state.playerByClassId()[player.UserId]
	if prevClassId then
		itemEquipper:UnassignClassItems(player, prevClassId)
	end

	-- set the player's faction now that the team has been changed
	StateActions.SetPlayerFaction(self.state, player.UserId, factionConfig.ID)
end

return SelectionService
