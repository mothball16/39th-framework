local Access = require("@game/ReplicatedStorage/Class_Framework/Access")
local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")
local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")
local Enums = require("@game/ReplicatedStorage/Class_Framework/Core/Enums")
local StateActions = require("@game/ReplicatedStorage/Class_Framework/StateActions")

local ItemEquipper = require("./ItemEquipper")
local SelectionHandler = {}
SelectionHandler.__index = SelectionHandler

type self = {
	state: State.State,
	classConfigs: { [string]: Types.ClassConfig },
}
export type SelectionHandler = typeof(setmetatable({} :: self, SelectionHandler))

function SelectionHandler.new(
	state: State.State,
	classConfigs: { [string]: Types.ClassConfig }
): SelectionHandler
	local self = setmetatable({
		state = state,
		classConfigs = classConfigs,
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

function SelectionHandler.HandleClassRequest(self: SelectionHandler, player: Player, request: {
	classKey: string,
	classId: string,
}, itemEquipper: ItemEquipper.ItemEquipper)
	local prevClassId = self.state.playerByClassId()[player.UserId]
	if prevClassId then
		itemEquipper:UnassignClassItems(player, prevClassId)
	end

	local factionId = self.state.playerByFactionId()[player.UserId]
	local factionConfig = self.state.configByFactionId()[factionId]

	if not factionConfig then
		warn(`player {player.UserId} requested class {request.classKey} but is not in a faction`)
		return
	end

	local classConfig = factionConfig.Classes[request.classKey]
	if not classConfig then
		warn(`player {player.UserId} requested class {request.classKey} but it is not a valid class`)
		player:Kick("invalid action 1")
		return
	end

	if not factionConfig.Classes[request.classKey] then
		warn(`player {player.UserId} requested class {request.classKey} but it is not a valid class for faction {factionConfig.ID}`)
		player:Kick("invalid action 2")
		return
	end

	local classCount = self.state.classCountByFaction()[factionConfig.ID][request.classKey]
	if classCount >= classConfig.Limit then
		warn(`player {player.UserId} requested class {request.classKey} but it is full for faction {factionConfig.ID}`)
		return
	end

	StateActions.SetPlayerClass(self.state, player.UserId, request.classKey, request.classId)
	
	if Access.Config.ApplyClassMode == Enums.ApplyClassMode.Immediate then
		itemEquipper:AssignClassItems(player, request.classId)
	end
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
