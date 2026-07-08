--!strict
--#selene: allow(incorrect_standard_library_use)
local Types = require("../Core/Types")

local StateActions = {}

local function cloneScores(scores: Types.ScoreMap?): Types.ScoreMap
	return table.clone(scores or {})
end

function StateActions.DefaultSnapshot(definition: Types.ObjectiveDefinition): Types.ObjectiveSnapshot
	return {
		ID = definition.ID,
		Kind = definition.Kind,
		Status = "Idle",
		Scores = {},
		Progress = 0,
	}
end

function StateActions.SetSnapshot(state: Types.State, snapshot: Types.ObjectiveSnapshot)
	state.objectiveById(function(previous)
		local nextState = table.clone(previous)
		nextState[snapshot.ID] = snapshot
		return nextState
	end)
end

function StateActions.UpdateSnapshot(
	state: Types.State,
	objectiveId: string,
	update: (Types.ObjectiveSnapshot) -> Types.ObjectiveSnapshot
): Types.ObjectiveSnapshot?
	local nextSnapshot: Types.ObjectiveSnapshot? = nil

	state.objectiveById(function(previous)
		local current = previous[objectiveId]
		if not current then
			return previous
		end

		local nextState = table.clone(previous)
		nextSnapshot = update(current)
		nextState[objectiveId] = nextSnapshot :: Types.ObjectiveSnapshot
		return nextState
	end)

	return nextSnapshot
end

function StateActions.AddScore(state: Types.State, objectiveId: string, teamId: string, amount: number): number
	local nextScore = 0
	StateActions.UpdateSnapshot(state, objectiveId, function(snapshot)
		local nextSnapshot = table.clone(snapshot)
		local scores = cloneScores(snapshot.Scores)
		nextScore = (scores[teamId] or 0) + amount
		scores[teamId] = nextScore
		nextSnapshot.Scores = scores
		return nextSnapshot
	end)
	return nextScore
end

function StateActions.SetProgress(state: Types.State, objectiveId: string, progress: number)
	StateActions.UpdateSnapshot(state, objectiveId, function(snapshot)
		local nextSnapshot = table.clone(snapshot)
		nextSnapshot.Progress = math.clamp(progress, 0, 1)
		return nextSnapshot
	end)
end

return StateActions
