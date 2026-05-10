local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework.Core.Types)
local State = require(Access.Framework.Core.State)
local Enums = require(Access.Framework.Core.Enums)
local StateActions = require(script.Parent.StateActions)

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
	local factionConfig = self.state.factionConfigs()[request.factionId]
	if not factionConfig then
		return
	end

	StateActions.SetPlayerFaction(self.state, player.UserId, factionConfig.ID)
end

function SelectionHandler.HandleClassRequest(self: SelectionHandler, player: Player, request: {
	classKey: string,
	classId: string,
})
	local factionId = self.state.playerFactionIds()[player.UserId]
	local factionConfig = self.state.factionConfigs()[factionId]

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

	local classCount = self.state.classCountsByFaction()[factionConfig.ID][request.classKey]
	if classCount >= classConfig.Limit then
		warn(`player {player.UserId} requested class {request.classKey} but it is full for faction {factionConfig.ID}`)
		return
	end

	StateActions.SetPlayerClass(self.state, player.UserId, request.classKey, request.classId)
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
	local factionConfig = self.state.factionConfigs()[autoFactionAttribute]
	if not factionConfig then
		return
	end

	StateActions.SetPlayerFaction(self.state, player.UserId, factionConfig.ID)
end

return SelectionHandler
