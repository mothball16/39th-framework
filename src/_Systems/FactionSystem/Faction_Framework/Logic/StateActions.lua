--[[
utility module for performing state transformations
]]

local Types = require("../Core/Types")
local State = require("../Core/State")
local Utilities = require("./Utilities")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")

local StateActions = {}

local function _updateMapValue(atom, key, value)
	atom(function(previous)
		local nextState = table.clone(previous)
		nextState[key] = value
		return nextState
	end)
end

function StateActions.CreateFaction(state: State.State, config: Types.FactionConfig): (boolean, string?)
	local msg = ""
	state.configByFactionId(function(previous)
		local nextState = table.clone(previous)
		nextState[config.ID] = config

		-- resolve default group for future use
		for groupKey, groupConfig in pairs(config.Groups) do
			if groupConfig.Default then
				if groupConfig.Limit ~= math.huge then
					msg ..= `warning: faction {config.ID} group {groupKey} should have no limit - it is a default group\n`
					groupConfig.Limit = math.huge
				end
				if groupConfig.Classes[1].AccessCheck then
					msg ..= `warning: the first class of default group {groupKey} of faction {config.ID} should not have an access check - the player can potentially resolve to no classes\n`
					groupConfig.Classes[1].AccessCheck = nil
				end
				nextState[config.ID].DefaultGroupKey = groupKey
				break
			end
		end
		return nextState
	end)

	return true, msg
end

function StateActions.RemoveFaction(state: State.State, idToRemove: string): (boolean, string?)
	state.configByFactionId(function(previous)
		local nextState = table.clone(previous)
		nextState[idToRemove] = nil
		return nextState
	end)

	-- make a pass to get players within the removed factions
	local affectedPlayers = {}
	for userId, factionId in pairs(state.playerByFactionId()) do
		if factionId == idToRemove then
			table.insert(affectedPlayers, userId)
		end
	end

	if #affectedPlayers == 0 then
		return true, `no players are affected by the removal of faction {idToRemove}`
	end

	-- is dirty, update reactively
	local nextplayerByFactionId = table.clone(state.playerByFactionId())
	local nextplayerByGroupKey = table.clone(state.playerByGroupKey())
	local nextplayerByClassId = table.clone(state.playerByClassId())
	for _, userId in ipairs(affectedPlayers) do
		nextplayerByFactionId[userId] = nil
		nextplayerByGroupKey[userId] = nil
		nextplayerByClassId[userId] = nil
	end

	Charm.batch(function()
		state.playerByFactionId(nextplayerByFactionId)
		state.playerByGroupKey(nextplayerByGroupKey)
		state.playerByClassId(nextplayerByClassId)
	end)
	return true, nil
end

function StateActions.SetPlayerFaction(state: State.State, userId: number | string, factionId: string): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)

	if not state.configByFactionId()[factionId] then
		return false, `denied: faction {factionId} is not a valid faction`
	end

	if state.playerByFactionId()[userId] == factionId then
		return true, `ignored: faction id {factionId} is the same as the previous`
	end

	_updateMapValue(state.playerByFactionId, userId, factionId)
	local success, msg = StateActions.SetPlayerToDefaultGroupClass(state, userId, factionId)
	return success, msg
end

function StateActions.SetPlayerGroupClass(state: State.State, userId: number | string, groupKey: string?, classId: string?): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)
	-- either intentionally or accidentally empty, remove everything cause
	-- it will brick the classes otherwise
	if not groupKey or not classId then
		groupKey = nil
		classId = nil
	else

		local playerFactionId = state.playerByFactionId()[userId]
		local factionConfig = state.configByFactionId()[playerFactionId]
		local currentGroupKey = state.playerByGroupKey()[userId]
		local currentClassId = state.playerByClassId()[userId]

		if currentGroupKey == groupKey and currentClassId == classId then
			return true, `ignored: group key {groupKey} and class id {classId} are the same as the previous`
		end

		if not playerFactionId then
			return false, `denied: player {userId} is not assigned to a faction`
		end

		if not factionConfig then
			return false, `denied: faction {playerFactionId} is not a valid faction`
		end
	
		if not factionConfig.Groups[groupKey] then
			return false, `denied: group key {groupKey} is not a valid group of faction {playerFactionId}`
		end

		local foundConfig: Types.ClassDescriptor?
		for _, classConfig in ipairs(factionConfig.Groups[groupKey].Classes) do
			if classConfig.Id == classId then
				foundConfig = classConfig
				break
			end
		end

		if not foundConfig then
			return false, `denied: class id {classId} is not a valid class of group {groupKey} of faction {playerFactionId}`
		end

		if foundConfig.AccessCheck and not foundConfig.AccessCheck(tonumber(userId) :: number) then
			return false, `denied: player {userId} fails the access check for class {classId}`
		end

		if currentGroupKey ~= groupKey then
			local groupConfig = factionConfig.Groups[groupKey]
			local factionCounts = state.groupCountByFaction()[playerFactionId]
			local groupCount = if factionCounts then factionCounts[groupKey] or 0 else 0
			if groupCount >= groupConfig.Limit then
				return false, `denied: group key {groupKey} is full for faction {playerFactionId}`
			end
		end
	end

	Charm.batch(function()
		_updateMapValue(state.playerByGroupKey, userId, groupKey)
		_updateMapValue(state.playerByClassId, userId, classId)
	end)
	return true, nil
end

function StateActions.RemovePlayerGroupClass(state: State.State, userId: number | string): (boolean, string?)
	return StateActions.SetPlayerGroupClass(state, userId, nil, nil)
end


function StateActions.RemovePlayerFaction(state: State.State, userId: number | string): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)
	_updateMapValue(state.playerByFactionId, userId, nil)
	return StateActions.RemovePlayerGroupClass(state, userId)
end


function StateActions.SetPlayerToDefaultGroupClass(state: State.State, userId: number | string, factionId: string): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)
	local factionConfig = state.configByFactionId()[factionId]
	local msg = ""
	if not factionConfig then
		return false, `denied: faction {factionId} is not a valid faction`
	end

	local defaultGroupKey = factionConfig.DefaultGroupKey
	if not defaultGroupKey then
		msg ..= `faction {factionId} has no default group\n`
		defaultGroupKey = next(factionConfig.Groups)
	end

	local groupConfig = factionConfig.Groups[defaultGroupKey]
	local classId = groupConfig.Classes[1].Id

	if not classId then
		return false, `error: faction {factionId} has no class ids!`
	end

	Charm.batch(function()
		_updateMapValue(state.playerByGroupKey, userId, defaultGroupKey)
		_updateMapValue(state.playerByClassId, userId, classId)
	end)
	return true, msg
end


return StateActions
