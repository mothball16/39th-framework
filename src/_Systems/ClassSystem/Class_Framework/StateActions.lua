--[[
utility module for performing state transformations
]]

local Types = require("./Core/Types")
local State = require("./Core/State")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")

local StateActions = {}

local function _updateMapValue(atom, key, value)
	atom(function(previous)
		local nextState = table.clone(previous)
		nextState[key] = value
		return nextState
	end)
end

function StateActions.CreateFaction(state: State.State, config: Types.FactionConfig)
	state.configByFactionId(function(previous)
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
	state.configByFactionId(function(previous)
		local nextState = table.clone(previous)
		nextState[idToRemove] = nil
		return nextState
	end)

	-- make a pass to get players within the removed factions
	local affectedPlayers = {}
	for playerKey, factionId in pairs(state.playerByFactionId()) do
		if factionId == idToRemove then
			table.insert(affectedPlayers, playerKey)
		end
	end

	if #affectedPlayers == 0 then
		return
	end

	-- is dirty, update reactively
	local nextplayerByFactionId = table.clone(state.playerByFactionId())
	local nextplayerByClassKey = table.clone(state.playerByClassKey())
	local nextplayerByClassId = table.clone(state.playerByClassId())
	for _, playerKey in ipairs(affectedPlayers) do
		nextplayerByFactionId[playerKey] = nil
		nextplayerByClassKey[playerKey] = nil
		nextplayerByClassId[playerKey] = nil
	end

	Charm.batch(function()
		state.playerByFactionId(nextplayerByFactionId)
		state.playerByClassKey(nextplayerByClassKey)
		state.playerByClassId(nextplayerByClassId)
	end)
end

function StateActions.SetPlayerFaction(state: State.State, userId: string, factionId: string)
	_updateMapValue(state.playerByFactionId, userId, factionId)
	StateActions.SetPlayerToDefaultClass(state, userId, factionId)
end

function StateActions.SetPlayerClass(state: State.State, userId: string, classKey: string?, classId: string?)
	-- either intentionally or accidentally empty, remove everything cause
	-- it will brick the classes otherwise
	if not classKey or not classId then
		classKey = nil
		classId = nil
	end
	Charm.batch(function()
		_updateMapValue(state.playerByClassKey, userId, classKey)
		_updateMapValue(state.playerByClassId, userId, classId)
	end)
end

function StateActions.RemovePlayerFaction(state: State.State, userId: string)
	_updateMapValue(state.playerByFactionId, userId, nil)
	StateActions.RemovePlayerClass(state, userId)
end

function StateActions.RemovePlayerClass(state: State.State, userId: string)
	return StateActions.SetPlayerClass(state, userId, nil, nil)
end

function StateActions.SetPlayerToDefaultClass(state: State.State, userId: string, factionId: string)
	print(`player {userId} has faction {factionId}`)
	local factionConfig = state.configByFactionId()[factionId]
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

	Charm.batch(function()
		_updateMapValue(state.playerByClassKey, userId, defaultClassKey)
		_updateMapValue(state.playerByClassId, userId, classId)
	end)
end


return StateActions
