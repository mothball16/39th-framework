--!strict
--#selene: allow(incorrect_standard_library_use)
local PlayerUtil = require("../Logic/PlayerUtil")
local Types = require("../Core/Types")

local Payload = {}

export type Config = {
	ID: string,
	AutoStart: boolean?,
	Payload: Model | BasePart?,
	Waypoints: { Vector3 | CFrame | BasePart },
	Radius: number?,
	Speed: number?,
	TimeLimit: number?,
	AttackerTeams: { string }?,
	GetPlayersInZone: ((BasePart?) -> { Player })?,
}

local function waypointPosition(waypoint: Vector3 | CFrame | BasePart): Vector3
	if typeof(waypoint) == "Vector3" then
		return waypoint
	elseif typeof(waypoint) == "CFrame" then
		return waypoint.Position
	end
	return (waypoint :: BasePart).Position
end

local function setPayloadPosition(payload: Model | BasePart?, position: Vector3)
	if not payload then
		return
	end

	if payload:IsA("Model") then
		payload:PivotTo(CFrame.new(position))
	else
		(payload :: BasePart).CFrame = CFrame.new(position)
	end
end

local function getPathLength(waypoints: { Vector3 | CFrame | BasePart }): number
	local length = 0
	for index = 1, #waypoints - 1 do
		length += (waypointPosition(waypoints[index + 1]) - waypointPosition(waypoints[index])).Magnitude
	end
	return length
end

local function getPositionAtProgress(waypoints: { Vector3 | CFrame | BasePart }, progress: number): Vector3
	local totalLength = getPathLength(waypoints)
	if totalLength <= 0 then
		return waypointPosition(waypoints[#waypoints])
	end

	local targetDistance = totalLength * math.clamp(progress, 0, 1)
	local traversed = 0

	for index = 1, #waypoints - 1 do
		local startPosition = waypointPosition(waypoints[index])
		local endPosition = waypointPosition(waypoints[index + 1])
		local segmentLength = (endPosition - startPosition).Magnitude
		if traversed + segmentLength >= targetDistance then
			local segmentAlpha = if segmentLength > 0 then (targetDistance - traversed) / segmentLength else 1
			return startPosition:Lerp(endPosition, segmentAlpha)
		end
		traversed += segmentLength
	end

	return waypointPosition(waypoints[#waypoints])
end

local function getPlayers(config: Config): { Player }
	if config.GetPlayersInZone then
		return config.GetPlayersInZone(nil)
	end

	if config.Payload and config.Payload:IsA("BasePart") then
		return PlayerUtil.GetPlayersNearPart(config.Payload :: BasePart, config.Radius)
	end

	if config.Payload and config.Payload:IsA("Model") then
		local root = (config.Payload :: Model).PrimaryPart
		if root then
			return PlayerUtil.GetPlayersNearPart(root, config.Radius)
		end
	end

	return {}
end

local function makeTeamSet(teams: { string }?): { [string]: boolean }?
	if not teams then
		return nil
	end

	local set = {}
	for _, teamId in ipairs(teams) do
		set[teamId] = true
	end
	return set
end

function Payload.Step(context: Types.ObjectiveContext, config: Config, dt: number)
	assert(#config.Waypoints >= 2, "Payload requires at least two waypoints")

	local attackerSet = makeTeamSet(config.AttackerTeams)
	local players = getPlayers(config)
	local hasAttacker = false
	local hasDefender = false

	for _, player in ipairs(players) do
		local teamId = context.GetTeamId(player)
		if not teamId then
			continue
		end

		local isAttacker = if attackerSet then attackerSet[teamId] == true else true
		hasAttacker = hasAttacker or isAttacker
		hasDefender = hasDefender or not isAttacker
	end

	context.UpdateSnapshot(function(snapshot)
		local nextSnapshot = table.clone(snapshot)
		local details = table.clone(snapshot.Details or {})
		details.elapsed = (details.elapsed or 0) + dt
		details.contested = hasAttacker and hasDefender
		nextSnapshot.ContestingTeam = if details.contested then "Contested" else nil
		nextSnapshot.Details = details
		return nextSnapshot
	end)

	if hasAttacker and not hasDefender then
		local snapshot = context.GetSnapshot()
		local progress = (if snapshot then snapshot.Progress else 0) + ((config.Speed or 0.05) * dt)
		progress = math.clamp(progress, 0, 1)
		context.SetProgress(progress)

		setPayloadPosition(config.Payload, getPositionAtProgress(config.Waypoints, progress))

		if progress >= 1 then
			local winnerTeam = if config.AttackerTeams then config.AttackerTeams[1] else nil
			context.Complete({ winnerTeam = winnerTeam })
			return
		end
	end

	local snapshot = context.GetSnapshot()
	local elapsed = if snapshot and snapshot.Details then snapshot.Details.elapsed or 0 else 0
	if config.TimeLimit and elapsed >= config.TimeLimit then
		context.Complete({ reason = "completed", details = { timedOut = true } })
	end
end

function Payload.build(config: Config): Types.ObjectiveDefinition
	return {
		ID = config.ID,
		Kind = "Payload",
		AutoStart = config.AutoStart,
		OnStart = function(context)
			context.UpdateSnapshot(function(snapshot)
				local nextSnapshot = table.clone(snapshot)
				nextSnapshot.Progress = 0
				nextSnapshot.Details = {
					elapsed = 0,
					contested = false,
				}
				return nextSnapshot
			end)

			context.OnHeartbeat(function(dt)
				Payload.Step(context, config, dt)
			end)
			return nil
		end,
	}
end

return Payload
