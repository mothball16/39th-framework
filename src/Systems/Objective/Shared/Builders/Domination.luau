--!strict
--#selene: allow(incorrect_standard_library_use)
local PlayerUtil = require("../Logic/PlayerUtil")
local Types = require("../Core/Types")

local Domination = {}

export type ZoneConfig = {
	ID: string,
	Zone: BasePart?,
	Radius: number?,
	GetPlayersInZone: ((BasePart?) -> { Player })?,
}

export type Config = {
	ID: string,
	AutoStart: boolean?,
	Zones: { ZoneConfig },
	ScoreLimit: number?,
	ScoreRate: number?,
	Duration: number?,
}

local function getPlayers(zoneConfig: ZoneConfig): { Player }
	if zoneConfig.GetPlayersInZone then
		return zoneConfig.GetPlayersInZone(zoneConfig.Zone)
	end

	assert(zoneConfig.Zone, "Domination zones require Zone or GetPlayersInZone")
	return PlayerUtil.GetPlayersNearPart(zoneConfig.Zone, zoneConfig.Radius)
end

function Domination.Step(context: Types.ObjectiveContext, config: Config, dt: number)
	local ownedZonesByTeam = {}

	context.UpdateSnapshot(function(snapshot)
		local nextSnapshot = table.clone(snapshot)
		local details = table.clone(snapshot.Details or {})
		local zones = table.clone(details.zones or {})
		local elapsed = (details.elapsed or 0) + dt

		for _, zoneConfig in ipairs(config.Zones) do
			local players = getPlayers(zoneConfig)
			local occupyingTeam, contested = PlayerUtil.ResolveSingleTeam(players, context.GetTeamId)
			local zoneState = table.clone(zones[zoneConfig.ID] or {})

			if contested then
				zoneState.contestingTeam = "Contested"
			else
				zoneState.contestingTeam = nil
				if occupyingTeam then
					zoneState.ownerTeam = occupyingTeam
				end
			end

			if zoneState.ownerTeam then
				ownedZonesByTeam[zoneState.ownerTeam] = (ownedZonesByTeam[zoneState.ownerTeam] or 0) + 1
			end

			zones[zoneConfig.ID] = zoneState
		end

		details.zones = zones
		details.elapsed = elapsed
		nextSnapshot.Details = details
		return nextSnapshot
	end)

	local winningTeam = nil
	for teamId, zoneCount in pairs(ownedZonesByTeam) do
		local score = context.AddScore(teamId, zoneCount * (config.ScoreRate or 1) * dt)
		if config.ScoreLimit and score >= config.ScoreLimit then
			winningTeam = teamId
		end
	end

	local snapshot = context.GetSnapshot()
	if winningTeam then
		context.Complete({ winnerTeam = winningTeam })
		return
	end

	local elapsed = if snapshot and snapshot.Details then snapshot.Details.elapsed or 0 else 0
	if config.Duration and elapsed >= config.Duration then
		local bestScore = -math.huge
		for teamId, score in pairs(if snapshot then snapshot.Scores else {}) do
			if score > bestScore then
				bestScore = score
				winningTeam = teamId
			end
		end
		context.Complete({ winnerTeam = winningTeam })
	end
end

function Domination.build(config: Config): Types.ObjectiveDefinition
	return {
		ID = config.ID,
		Kind = "Domination",
		AutoStart = config.AutoStart,
		OnStart = function(context)
			context.UpdateSnapshot(function(snapshot)
				local nextSnapshot = table.clone(snapshot)
				nextSnapshot.Details = table.clone(snapshot.Details or {})
				nextSnapshot.Details.elapsed = 0
				nextSnapshot.Details.zones = {}
				return nextSnapshot
			end)

			context.OnHeartbeat(function(dt)
				Domination.Step(context, config, dt)
			end)
			return nil
		end,
	}
end

return Domination
