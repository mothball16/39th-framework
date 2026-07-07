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

		-- resolve default class for future use
		for classKey, classConfig in pairs(config.Classes) do
			if classConfig.Default then
				if classConfig.Limit ~= math.huge then
					msg ..= `warning: faction {config.ID} class {classKey} should have no limit - it is a default class\n`
					classConfig.Limit = math.huge
				end
				if classConfig.Variants[1].AccessCheck then
					msg ..= `warning: the first variant of default class {classKey} of faction {config.ID} should not have an access check - the player can potentially resolve to no variants\n`
					classConfig.Variants[1].AccessCheck = nil
				end
				nextState[config.ID].DefaultClassKey = classKey
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

function StateActions.SetPlayerFaction(
	state: State.State,
	userId: number | string,
	factionId: string
): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)

	if not state.configByFactionId()[factionId] then
		return false, `denied: faction {factionId} is not a valid faction`
	end

	local assignment = state.playerAssignmentByUserId()[userId]
	if assignment and assignment.FactionId == factionId then
		return true, `ignored: faction id {factionId} is the same as the previous`
	end

	return StateActions.SetPlayerToDefaultClassVariant(state, userId, factionId)
end

function StateActions.SetPlayerClassVariant(
	state: State.State,
	userId: number | string,
	classKey: string?,
	variantId: string?
): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)
	local assignment = state.playerAssignmentByUserId()[userId]
	-- either intentionally or accidentally empty, remove everything cause
	-- it will brick the variants otherwise
	if not classKey or not variantId then
		classKey = nil
		variantId = nil
	else
		local playerFactionId = if assignment then assignment.FactionId else nil
		local factionConfig = state.configByFactionId()[playerFactionId]
		local currentClassKey = if assignment then assignment.ClassKey else nil
		local currentVariantId = if assignment then assignment.VariantId else nil

		if currentClassKey == classKey and currentVariantId == variantId then
			return true, `ignored: class key {classKey} and variant id {variantId} are the same as the previous`
		end

		if not playerFactionId then
			return false, `denied: player {userId} is not assigned to a faction`
		end

		if not factionConfig then
			return false, `denied: faction {playerFactionId} is not a valid faction`
		end

		if not factionConfig.Classes[classKey] then
			return false, `denied: class key {classKey} is not a valid class of faction {playerFactionId}`
		end

		local foundConfig: Types.VariantDescriptor?
		for _, variantConfig in ipairs(factionConfig.Classes[classKey].Variants) do
			if variantConfig.Id == variantId then
				foundConfig = variantConfig
				break
			end
		end

		if not foundConfig then
			return false,
				`denied: variant id {variantId} is not a valid variant of class {classKey} of faction {playerFactionId}`
		end

		if foundConfig.AccessCheck and not foundConfig.AccessCheck(tonumber(userId) :: number) then
			return false, `denied: player {userId} fails the access check for variant {variantId}`
		end

		if currentClassKey ~= classKey then
			local classConfig = factionConfig.Classes[classKey]
			local factionCounts = state.getClassCountByFaction()[playerFactionId]
			local classCount = if factionCounts then factionCounts[classKey] or 0 else 0
			if classCount >= classConfig.Limit then
				return false, `denied: class key {classKey} is full for faction {playerFactionId}`
			end
		end
	end

	if assignment then
		_updateMapValue(state.playerAssignmentByUserId, userId, {
			FactionId = assignment.FactionId,
			ClassKey = classKey,
			VariantId = variantId,
		})
	end
	return true, nil
end

function StateActions.RemovePlayerClassVariant(state: State.State, userId: number | string): (boolean, string?)
	return StateActions.SetPlayerClassVariant(state, userId, nil, nil)
end

function StateActions.RemovePlayerFaction(state: State.State, userId: number | string): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)
	_updateMapValue(state.playerAssignmentByUserId, userId, nil)
	return true, nil
end

function StateActions.SetPlayerToDefaultClassVariant(
	state: State.State,
	userId: number | string,
	factionId: string
): (boolean, string?)
	userId = Utilities.ToPlayerKey(userId)
	local factionConfig = state.configByFactionId()[factionId]
	local msg = ""
	if not factionConfig then
		return false, `denied: faction {factionId} is not a valid faction`
	end

	local defaultClassKey = factionConfig.DefaultClassKey
	if not defaultClassKey then
		msg ..= `faction {factionId} has no default class\n`
		defaultClassKey = next(factionConfig.Classes)
	end

	local classConfig = factionConfig.Classes[defaultClassKey]
	local variantId = classConfig.Variants[1].Id

	if not variantId then
		return false, `error: faction {factionId} has no variant ids!`
	end

	_updateMapValue(state.playerAssignmentByUserId, userId, {
		FactionId = factionId,
		ClassKey = defaultClassKey,
		VariantId = variantId,
	})
	return true, msg
end

return StateActions
