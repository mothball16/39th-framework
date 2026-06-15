--[[
utility module for performing state transformations
]]

local Types = require("../Core/Types")
local State = require("../Core/State")
local Utilities = require("./Utilities")

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
	for userId, assignment in pairs(state.playerAssignmentByUserId()) do
		if assignment.FactionId == idToRemove then
			table.insert(affectedPlayers, userId)
		end
	end

	if #affectedPlayers == 0 then
		return true, `no players are affected by the removal of faction {idToRemove}`
	end

	local nextPlayerAssignmentByUserId = table.clone(state.playerAssignmentByUserId())
	for _, userId in ipairs(affectedPlayers) do
		nextPlayerAssignmentByUserId[userId] = nil
	end

	state.playerAssignmentByUserId(nextPlayerAssignmentByUserId)
	return true, nil
end

function StateActions.SetPlayerFaction(state: State.State, userId: number | string, factionId: string): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)

	if not state.configByFactionId()[factionId] then
		return false, `denied: faction {factionId} is not a valid faction`
	end

	local assignment = state.playerAssignmentByUserId()[userId]
	if assignment and assignment.FactionId == factionId then
		return true, `ignored: faction id {factionId} is the same as the previous`
	end

	return StateActions.SetPlayerToDefaultGroupClass(state, userId, factionId)
end

function StateActions.SetPlayerGroupClass(state: State.State, userId: number | string, groupKey: string?, classId: string?): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)
	local assignment = state.playerAssignmentByUserId()[userId]
	-- either intentionally or accidentally empty, remove everything cause
	-- it will brick the classes otherwise
	if not groupKey or not classId then
		groupKey = nil
		classId = nil
	else

		local playerFactionId = if assignment then assignment.FactionId else nil
		local factionConfig = state.configByFactionId()[playerFactionId]
		local currentGroupKey = if assignment then assignment.GroupKey else nil
		local currentClassId = if assignment then assignment.ClassId else nil

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

	if assignment then
		_updateMapValue(state.playerAssignmentByUserId, userId, {
			FactionId = assignment.FactionId,
			GroupKey = groupKey,
			ClassId = classId,
		})
	end
	return true, nil
end

function StateActions.RemovePlayerGroupClass(state: State.State, userId: number | string): (boolean, string?)
	return StateActions.SetPlayerGroupClass(state, userId, nil, nil)
end


function StateActions.RemovePlayerFaction(state: State.State, userId: number | string): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)
	_updateMapValue(state.playerAssignmentByUserId, userId, nil)
	return true, nil
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

	_updateMapValue(state.playerAssignmentByUserId, userId, {
		FactionId = factionId,
		GroupKey = defaultGroupKey,
		ClassId = classId,
	})
	return true, msg
end


return StateActions
