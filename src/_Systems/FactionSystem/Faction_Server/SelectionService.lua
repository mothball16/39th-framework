--[[
service layer for class/faction selection requests
validates request data, handles side effects (item assign/unassign),
and delegates pure state mutations to StateActions
]]

local Types = require("@game/ReplicatedStorage/Faction_Framework/Core/Types")
local State = require("@game/ReplicatedStorage/Faction_Framework/Core/State")
local Enums = require("@game/ReplicatedStorage/Faction_Framework/Core/Enums")
local StateActions = require("@game/ReplicatedStorage/Faction_Framework/Logic/StateActions")
local Utilities = require("@game/ReplicatedStorage/Faction_Framework/Logic/Utilities")

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
}): (boolean, string?)
	local success, msg = StateActions.SetPlayerFaction(self.state, player.UserId, request.factionId)

	return success, msg
end

function SelectionService.HandleGroupClassRequest(self: SelectionService, player: Player, request: {
	group: string,
	class: string,
}, itemEquipper: ItemEquipper.ItemEquipper): (boolean, string?)
	local prevClassId = self.state.playerByClassId()[Utilities.ToPlayerKey(player.UserId)]
	local success, msg = StateActions.SetPlayerGroupClass(
		self.state,
		player.UserId,
		request.group,
		request.class
	)

	if not success then
		return false, msg
	end

	local nextClassId = self.state.playerByClassId()[Utilities.ToPlayerKey(player.UserId)]
	if prevClassId and prevClassId ~= nextClassId then
		itemEquipper:UnassignClassItems(player, prevClassId)
	end

	if self.settings.ApplyClassMode == Enums.ApplyClassMode.Immediate then
		self:HandleClassApplyRequest(player, { enable = true }, itemEquipper)
	end

	return true, msg
end

function SelectionService.HandleClassApplyRequest(self: SelectionService, player: Player, request: {
	enable: boolean
}, itemEquipper: ItemEquipper.ItemEquipper
): (boolean, string?)
	local classId = self.state.playerByClassId()[Utilities.ToPlayerKey(player.UserId)]
	if not classId then
		return false, `denied: player {player.UserId} is not in a class`
	end

	local character = player.Character
	if not character then
		return false, `denied: player {player.UserId}'s character isn't loaded`
	end

	if request.enable then
		itemEquipper:AssignClassItems(player, classId)
	else
		itemEquipper:UnassignClassItems(player, classId)
	end

	return true, nil
end

function SelectionService.HandleTeamChange(
	self: SelectionService,
	player: Player,
	team: Team,
	itemEquipper: ItemEquipper.ItemEquipper
): (boolean, string?)
	if not team then
		return false, `denied: team is nil`
	end

	local autoFactionAttribute = team:GetAttribute(Enums.Faction.AutoFactionAttribute)
	if not autoFactionAttribute then
		return false, `denied: team {team.Name} has no AutoFaction attribute`
	end

	if not self.state.configByFactionId()[autoFactionAttribute] then
		return false, `denied: faction {autoFactionAttribute} is not a valid faction`
	end

	if self.state.playerByFactionId()[Utilities.ToPlayerKey(player.UserId)] == autoFactionAttribute then
		return true, `ignored: faction {autoFactionAttribute} is the same as the previous`
	end

	local prevClassId = self.state.playerByClassId()[Utilities.ToPlayerKey(player.UserId)]
	local success, msg = StateActions.SetPlayerFaction(self.state, player.UserId, autoFactionAttribute)
	if not success then
		if msg then
			warn(msg)
		end
		return false, msg
	end

	if prevClassId then
		itemEquipper:UnassignClassItems(player, prevClassId)
	end

	return true, msg
end

return SelectionService
