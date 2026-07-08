--!strict
--#selene: allow(incorrect_standard_library_use)
local Maid = require("@game/ReplicatedStorage/Packages/maid")

local Types = require("../Core/Types")

local MultiPhase = {}

export type Config = {
	ID: string,
	AutoStart: boolean?,
	Phases: { Types.ObjectiveDefinition },
	OnStart: ((Types.ObjectiveContext) -> ())?,
	OnEnd: ((Types.ObjectiveContext, Types.ObjectiveEndReason?) -> ())?,
}

local function makePhaseContext(
	parentContext: Types.ObjectiveContext,
	phaseDefinition: Types.ObjectiveDefinition,
	phaseMaid: Maid.Maid,
	onComplete: (
		{ winnerTeam: string?, reason: Types.ObjectiveEndReason?, details: { [string]: any }? }?
	) -> ()
): Types.ObjectiveContext
	local phaseContext = table.clone(parentContext) :: Types.ObjectiveContext
	phaseContext.Definition = phaseDefinition
	phaseContext.Maid = phaseMaid
	phaseContext.Complete = onComplete
	phaseContext.End = function(reason)
		onComplete({ reason = reason or "cancelled" })
	end
	return phaseContext
end

function MultiPhase.build(config: Config): Types.ObjectiveDefinition
	local activePhaseMaid: Maid.Maid? = nil
	local activePhase: Types.ObjectiveDefinition? = nil
	local activePhaseContext: Types.ObjectiveContext? = nil
	local phaseIndex = 0
	local ending = false

	local function endActivePhase(reason: Types.ObjectiveEndReason?)
		if activePhase and activePhase.OnEnd and activePhaseContext then
			activePhase.OnEnd(activePhaseContext, reason)
		end
		if activePhaseMaid then
			activePhaseMaid:DoCleaning()
		end
		activePhase = nil
		activePhaseMaid = nil
		activePhaseContext = nil
	end

	local function startNextPhase(parentContext: Types.ObjectiveContext)
		if ending then
			return
		end

		endActivePhase("completed")
		phaseIndex += 1

		local phaseDefinition = config.Phases[phaseIndex]
		if not phaseDefinition then
			parentContext.Complete()
			return
		end

		activePhase = phaseDefinition
		activePhaseMaid = Maid.new()
		parentContext.Maid:GiveTask(activePhaseMaid)

		parentContext.UpdateSnapshot(function(snapshot)
			local nextSnapshot = table.clone(snapshot)
			nextSnapshot.PhaseIndex = phaseIndex
			nextSnapshot.Details = table.clone(snapshot.Details or {})
			nextSnapshot.Details.phaseId = phaseDefinition.ID
			nextSnapshot.Details.phaseKind = phaseDefinition.Kind
			return nextSnapshot
		end)

		activePhaseContext = makePhaseContext(
			parentContext,
			phaseDefinition,
			activePhaseMaid :: Maid.Maid,
			function(result)
				if result and result.winnerTeam then
					parentContext.UpdateSnapshot(function(snapshot)
						local nextSnapshot = table.clone(snapshot)
						nextSnapshot.WinnerTeam = result.winnerTeam
						nextSnapshot.Details = result.details or snapshot.Details
						return nextSnapshot
					end)
				end
				startNextPhase(parentContext)
			end
		)

		if phaseDefinition.OnStart then
			local cleanup = phaseDefinition.OnStart(activePhaseContext :: Types.ObjectiveContext)
			if cleanup and activePhaseMaid then
				activePhaseMaid:GiveTask(cleanup)
			end
		end
	end

	return {
		ID = config.ID,
		Kind = "MultiPhase",
		AutoStart = config.AutoStart,
		OnStart = function(context)
			ending = false
			phaseIndex = 0
			if config.OnStart then
				config.OnStart(context)
			end
			startNextPhase(context)
			return nil
		end,
		OnEnd = function(context, reason)
			ending = true
			endActivePhase(reason)
			if config.OnEnd then
				config.OnEnd(context, reason)
			end
		end,
	}
end

return MultiPhase
