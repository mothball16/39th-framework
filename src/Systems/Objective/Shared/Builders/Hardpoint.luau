--!strict
--#selene: allow(incorrect_standard_library_use)
local PlayerUtil = require("../Logic/PlayerUtil")
local Types = require("../Core/Types")

local Hardpoint = {}

export type Config = {
	ID: string,
	AutoStart: boolean?,
	Zone: BasePart?,
	Radius: number?,
	ScoreLimit: number?,
	ScoreRate: number?,
	Duration: number?,
	GetPlayersInZone: ((BasePart?) -> { Player })?,
}

local function getPlayers(config: Config): { Player }
	if config.GetPlayersInZone then
		return config.GetPlayersInZone(config.Zone)
	end

	assert(config.Zone, "Hardpoint requires Zone or GetPlayersInZone")
	return PlayerUtil.GetPlayersNearPart(config.Zone, config.Radius)
end

function Hardpoint.Step(context: Types.ObjectiveContext, config: Config, dt: number)
	local players = getPlayers(config)
	local occupyingTeam, contested = PlayerUtil.ResolveSingleTeam(players, context.GetTeamId)
	local now = os.clock()

	context.UpdateSnapshot(function(snapshot)
		local nextSnapshot = table.clone(snapshot)
		local details = table.clone(snapshot.Details or {})
		local elapsed = (details.elapsed or 0) + dt
		details.elapsed = elapsed

		if contested then
			nextSnapshot.ContestingTeam = "Contested"
		else
			nextSnapshot.ContestingTeam = nil
			if occupyingTeam then
				nextSnapshot.OwnerTeam = occupyingTeam
			end
		end

		nextSnapshot.Details = details
		return nextSnapshot
	end)

	local snapshot = context.GetSnapshot()
	local ownerTeam = if snapshot then snapshot.OwnerTeam else nil
	if ownerTeam and not contested then
		local score = context.AddScore(ownerTeam, (config.ScoreRate or 1) * dt)
		if config.ScoreLimit and score >= config.ScoreLimit then
			context.Complete({ winnerTeam = ownerTeam })
			return
		end
	end

	snapshot = context.GetSnapshot()
	local elapsed = if snapshot and snapshot.Details then snapshot.Details.elapsed or 0 else 0
	if config.Duration and elapsed >= config.Duration then
		local winnerTeam = ownerTeam
		local bestScore = -math.huge
		for teamId, score in pairs(if snapshot then snapshot.Scores else {}) do
			if score > bestScore then
				bestScore = score
				winnerTeam = teamId
			end
		end
		context.Complete({ winnerTeam = winnerTeam, reason = "completed", details = { completedAt = now } })
	end
end

function Hardpoint.build(config: Config): Types.ObjectiveDefinition
	return {
		ID = config.ID,
		Kind = "Hardpoint",
		AutoStart = config.AutoStart,
		OnStart = function(context)
			context.UpdateSnapshot(function(snapshot)
				local nextSnapshot = table.clone(snapshot)
				nextSnapshot.Details = table.clone(snapshot.Details or {})
				nextSnapshot.Details.elapsed = 0
				return nextSnapshot
			end)

			context.OnHeartbeat(function(dt)
				Hardpoint.Step(context, config, dt)
			end)
			return nil
		end,
	}
end

return Hardpoint
