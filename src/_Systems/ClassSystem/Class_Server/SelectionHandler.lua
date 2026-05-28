--[[
validates and translates request events into stateaction calls.
NO LOGIC should be done here because thatd fuck with tests that rely on stateaction alone
]]

local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")
local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")
local Enums = require("@game/ReplicatedStorage/Class_Framework/Core/Enums")
local StateActions = require("@game/ReplicatedStorage/Class_Framework/StateActions")

local ItemEquipper = require("./ItemEquipper")
local SelectionHandler = {}
SelectionHandler.__index = SelectionHandler

type self = {
	state: State.State,
	setting: Types.Settings,
}
export type SelectionHandler = typeof(setmetatable({} :: self, SelectionHandler))

function SelectionHandler.new(
	state: State.State,
	setting: Types.Settings
): SelectionHandler
	local self = setmetatable({
		state = state,
		setting = setting,
	} :: self, SelectionHandler)

	return self
end

function SelectionHandler.HandleFactionRequest(self: SelectionHandler, player: Player, request: {
	factionId: string,
})
	local factionConfig = self.state.configByFactionId()[request.factionId]
	if not factionConfig then
		return
	end

	StateActions.SetPlayerFaction(self.state, player.UserId, factionConfig.ID)
end

function SelectionHandler.HandleGroupClassRequest(self: SelectionHandler, player: Player, request: {
	groupKey: string,
	classId: string,
}, itemEquipper: ItemEquipper.ItemEquipper)
	local prevClassId = self.state.playerByClassId()[player.UserId]
	if prevClassId then
		itemEquipper:UnassignClassItems(player, prevClassId)
	end

	local factionId = self.state.playerByFactionId()[player.UserId]
	local factionConfig = self.state.configByFactionId()[factionId]

	if not factionConfig then
		warn(`player {player.UserId} requested group {request.groupKey} but is not in a faction`)
		return
	end

	local groupConfig = factionConfig.Groups[request.groupKey]
	if not groupConfig then
		warn(`player {player.UserId} requested group {request.groupKey} but it is not a valid group`)
		player:Kick("invalid action 1")
		return
	end

	if not factionConfig.Groups[request.groupKey] then
		warn(`player {player.UserId} requested group {request.groupKey} but it is not a valid group for faction {factionConfig.ID}`)
		player:Kick("invalid action 2")
		return
	end

	local groupCount = self.state.groupCountByFaction()[factionConfig.ID][request.groupKey]
	if groupCount >= groupConfig.Limit then
		warn(`player {player.UserId} requested group {request.groupKey} but it is full for faction {factionConfig.ID}`)
		return
	end

	StateActions.SetPlayerGroupClass(self.state, player.UserId, request.groupKey, request.classId)
	
	-- if Access.Config.ApplyClassMode == Enums.ApplyClassMode.Immediate then
	-- 	itemEquipper:AssignClassItems(player, request.classId)
	-- end
end

function SelectionHandler.HandleTeamChange(self: SelectionHandler, player: Player, team: Team)
	if not team then
		return
	end

	-- check if the player's new team should automatically assign a faction
	local autoFactionAttribute = team:GetAttribute(Enums.Faction.AutoFactionAttribute)
	if not autoFactionAttribute then
		return
	end

	-- make sure the faction actually exists first
	local factionConfig = self.state.configByFactionId()[autoFactionAttribute]
	if not factionConfig then
		return
	end

	-- set the player's faction now that the team has been changed
	StateActions.SetPlayerFaction(self.state, player.UserId, factionConfig.ID)
end

function SelectionHandler.HandleClassApplyRequest(self: SelectionHandler, player: Player, request: { enable: boolean }, itemEquipper)
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

	if request.enable then
		itemEquipper:AssignClassItems(player, classId)
	else
		itemEquipper:UnassignClassItems(player, classId)
	end
end

return SelectionHandler
