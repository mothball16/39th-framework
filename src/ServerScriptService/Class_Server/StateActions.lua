--[[
utility module for performing state transformations
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework.Core.Types)
local State = require(Access.Framework.Core.State)

local StateActions = {}

local function _updateMapValue(atom, key, value)
	atom(function(previous)
		local nextState = table.clone(previous)
		nextState[key] = value
		return nextState
	end)
end

function StateActions.CreateFaction(state: State.State, config: Types.FactionConfig)
	state.factionConfigs(function(previous)
		local nextState = table.clone(previous)
		nextState[config.ID] = config

		-- resolve default class for future use
		for classKey, classConfig in pairs(config.Classes) do
			if classConfig.Default then
				nextState[config.ID].DefaultClassKey = classKey
			end
		end
		return nextState
	end)

	return config
end

function StateActions.RemoveFaction(state: State.State, idToRemove: string)
	state.factionConfigs(function(previous)
		local nextState = table.clone(previous)
		nextState[idToRemove] = nil
		return nextState
	end)

	-- make a pass to get players within the removed factions
	local affectedPlayers = {}
	for playerKey, factionId in pairs(state.playerFactionIds()) do
		if factionId == idToRemove then
			table.insert(affectedPlayers, playerKey)
		end
	end

	if #affectedPlayers == 0 then
		return
	end

	-- is dirty, update reactively
	local nextPlayerFactionIds = table.clone(state.playerFactionIds())
	local nextPlayerClassKeys = table.clone(state.playerClassKeys())
	local nextPlayerClassIds = table.clone(state.playerClassIds())
	for _, playerKey in ipairs(affectedPlayers) do
		nextPlayerFactionIds[playerKey] = nil
		nextPlayerClassKeys[playerKey] = nil
		nextPlayerClassIds[playerKey] = nil
	end

	state.playerFactionIds(nextPlayerFactionIds)
	state.playerClassKeys(nextPlayerClassKeys)
	state.playerClassIds(nextPlayerClassIds)
end

function StateActions.SetPlayerFaction(state: State.State, userId: string, factionId: string)
	_updateMapValue(state.playerFactionIds, userId, factionId)
	local factionConfig = state.factionConfigs()[factionId]
	if not factionConfig then
		return
	end

	local defaultClassKey = factionConfig.DefaultClassKey
	if not defaultClassKey then
		warn(`faction {factionId} has no default class`)
		defaultClassKey = next(factionConfig.Classes)
	end

	local classConfig = factionConfig.Classes[defaultClassKey]
	local classId = classConfig.ClassIDs[1].Id

	_updateMapValue(state.playerClassKeys, userId, defaultClassKey)
	_updateMapValue(state.playerClassIds, userId, classId)
end

function StateActions.SetPlayerClass(state: State.State, userId: string, classKey: string?, classId: string?)
	-- either intentionally or accidentally empty, remove everything cause
	-- it will brick the classes otherwise
	if not classKey or not classId then
		classKey = nil
		classId = nil
	end

	_updateMapValue(state.playerClassKeys, userId, classKey)
	_updateMapValue(state.playerClassIds, userId, classId)
end

function StateActions.RemovePlayerFaction(state: State.State, userId: string)
	_updateMapValue(state.playerFactionIds, userId, nil)
	StateActions.RemovePlayerClass(state, userId)
end

function StateActions.RemovePlayerClass(state: State.State, userId: string)
	return StateActions.SetPlayerClass(state, userId, nil, nil)
end


return StateActions
