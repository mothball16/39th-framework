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

		-- resolve default group for future use
		for groupKey, groupConfig in pairs(config.Groups) do
			if groupConfig.Default then
				if groupConfig.Limit ~= math.huge then
					warn(`faction {config.ID} group {groupKey} should have no limit - it is a default group`)
					groupConfig.Limit = math.huge
					continue
				end
				nextState[config.ID].DefaultGroupKey = groupKey
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
	local nextplayerByGroupKey = table.clone(state.playerByGroupKey())
	local nextplayerByClassId = table.clone(state.playerByClassId())
	for _, playerKey in ipairs(affectedPlayers) do
		nextplayerByFactionId[playerKey] = nil
		nextplayerByGroupKey[playerKey] = nil
		nextplayerByClassId[playerKey] = nil
	end

	Charm.batch(function()
		state.playerByFactionId(nextplayerByFactionId)
		state.playerByGroupKey(nextplayerByGroupKey)
		state.playerByClassId(nextplayerByClassId)
	end)
end

function StateActions.SetPlayerFaction(state: State.State, userId: string, factionId: string)
	-- if the faction id is the same as the previous, don't update
	if state.playerByFactionId()[userId] == factionId then
		return
	end

	_updateMapValue(state.playerByFactionId, userId, factionId)
	StateActions.SetPlayerToDefaultGroupClass(state, userId, factionId)
end

function StateActions.SetPlayerGroupClass(state: State.State, userId: string, groupKey: string?, classId: string?)
	-- either intentionally or accidentally empty, remove everything cause
	-- it will brick the classes otherwise
	if not groupKey or not classId then
		groupKey = nil
		classId = nil
	end

	-- if the group key and class id are the same as the previous, don't update
	if state.playerByGroupKey()[userId] == groupKey and state.playerByClassId()[userId] == classId then
		return
	end

	Charm.batch(function()
		_updateMapValue(state.playerByGroupKey, userId, groupKey)
		_updateMapValue(state.playerByClassId, userId, classId)
	end)
end

function StateActions.RemovePlayerFaction(state: State.State, userId: string)
	_updateMapValue(state.playerByFactionId, userId, nil)
	StateActions.RemovePlayerGroupClass(state, userId)
end

function StateActions.RemovePlayerGroupClass(state: State.State, userId: string)
	return StateActions.SetPlayerGroupClass(state, userId, nil, nil)
end

function StateActions.SetPlayerToDefaultGroupClass(state: State.State, userId: string, factionId: string)
	local factionConfig = state.configByFactionId()[factionId]
	if not factionConfig then
		return
	end

	local defaultGroupKey = factionConfig.DefaultGroupKey
	if not defaultGroupKey then
		warn(`faction {factionId} has no default group`)
		defaultGroupKey = next(factionConfig.Groups)
	end

	local groupConfig = factionConfig.Groups[defaultGroupKey]
	local classId = groupConfig.Classes[1].Id

	if not classId then
		error(`faction {factionId} has no class id!`)
	end

	Charm.batch(function()
		_updateMapValue(state.playerByGroupKey, userId, defaultGroupKey)
		_updateMapValue(state.playerByClassId, userId, classId)
	end)
end


return StateActions
