--!strict
--#selene: allow(incorrect_standard_library_use)
local RunService = game:GetService("RunService")

local Maid = require("@game/ReplicatedStorage/Packages/maid")

local State = require("@game/ReplicatedStorage/Systems/Objective/Core/State")
local Types = require("@game/ReplicatedStorage/Systems/Objective/Core/Types")
local PlayerUtil = require("@game/ReplicatedStorage/Systems/Objective/Logic/PlayerUtil")
local StateActions = require("@game/ReplicatedStorage/Systems/Objective/Logic/StateActions")

type ActiveObjective = {
	definition: Types.ObjectiveDefinition,
	context: Types.ObjectiveContext,
	maid: Maid.Maid,
	ending: boolean,
}

local ServerRuntime = {}
ServerRuntime.__index = ServerRuntime

type self = {
	access: Types.Access?,
	state: Types.State,
	maid: Maid.Maid,
	_definitionById: { [string]: Types.ObjectiveDefinition },
	_activeById: { [string]: ActiveObjective },
}
export type ServerRuntime = typeof(setmetatable({} :: self, ServerRuntime))

function ServerRuntime.new(args: { access: Types.Access? }?): ServerRuntime
	local self = setmetatable(
		{
			access = if args then args.access else nil,
			state = State(),
			maid = Maid.new(),
			_definitionById = {},
			_activeById = {},
		} :: self,
		ServerRuntime
	)

	return self
end

function ServerRuntime.RegisterObjective(self: ServerRuntime, definition: Types.ObjectiveDefinition): (boolean, string?)
	assert(definition.ID, "objective must have an ID")
	assert(definition.Kind, "objective must have a Kind")

	if self._definitionById[definition.ID] then
		warn(`replacing objective definition for ID {definition.ID}`)
	end

	self._definitionById[definition.ID] = definition
	StateActions.SetSnapshot(self.state, StateActions.DefaultSnapshot(definition))

	if definition.AutoStart then
		return self:StartObjective(definition.ID)
	end

	return true, nil
end

function ServerRuntime._getTeamId(self: ServerRuntime, player: Player): string?
	local access = self.access
	if access and access.Config.GetTeamId then
		return access.Config.GetTeamId(player)
	end
	return PlayerUtil.GetDefaultTeamId(player)
end

function ServerRuntime._makeContext(self: ServerRuntime, definition: Types.ObjectiveDefinition, maid: Maid.Maid)
	local function getSnapshot(): Types.ObjectiveSnapshot?
		return self.state.objectiveById()[definition.ID]
	end

	local context: Types.ObjectiveContext
	context = {
		ObjectiveId = definition.ID,
		Definition = definition,
		State = self.state,
		Maid = maid,
		Access = self.access,

		GetSnapshot = getSnapshot,
		SetSnapshot = function(snapshot)
			StateActions.SetSnapshot(self.state, snapshot)
		end,
		UpdateSnapshot = function(update)
			StateActions.UpdateSnapshot(self.state, definition.ID, update)
		end,
		AddScore = function(teamId, amount)
			return StateActions.AddScore(self.state, definition.ID, teamId, amount)
		end,
		SetProgress = function(progress)
			StateActions.SetProgress(self.state, definition.ID, progress)
		end,
		Complete = function(result)
			result = result or {}
			StateActions.UpdateSnapshot(self.state, definition.ID, function(snapshot)
				local nextSnapshot = table.clone(snapshot)
				nextSnapshot.WinnerTeam = result.winnerTeam or snapshot.WinnerTeam
				nextSnapshot.Details = result.details or snapshot.Details
				return nextSnapshot
			end)
			self:EndObjective(definition.ID, result.reason or "completed")
		end,
		End = function(reason)
			self:EndObjective(definition.ID, reason or "cancelled")
		end,
		GetTeamId = function(player)
			return self:_getTeamId(player)
		end,
		OnHeartbeat = function(callback)
			if not RunService.Heartbeat then
				return nil
			end
			local connection = RunService.Heartbeat:Connect(callback)
			maid:GiveTask(connection)
			return connection
		end,
	}

	return context
end

function ServerRuntime.StartObjective(self: ServerRuntime, objectiveId: string): (boolean, string?)
	if self._activeById[objectiveId] then
		return false, `objective {objectiveId} is already active`
	end

	local definition = self._definitionById[objectiveId]
	if not definition then
		return false, `objective {objectiveId} is not registered`
	end

	local maid = Maid.new()
	local context = self:_makeContext(definition, maid)
	self._activeById[objectiveId] = {
		definition = definition,
		context = context,
		maid = maid,
		ending = false,
	}

	StateActions.UpdateSnapshot(self.state, objectiveId, function(snapshot)
		local nextSnapshot = table.clone(snapshot)
		nextSnapshot.Status = "Active"
		nextSnapshot.StartedAt = os.clock()
		nextSnapshot.EndedAt = nil
		nextSnapshot.Reason = nil
		return nextSnapshot
	end)

	if definition.OnStart then
		local cleanup = definition.OnStart(context)
		if cleanup then
			maid:GiveTask(cleanup)
		end
	end

	return true, nil
end

function ServerRuntime.EndObjective(
	self: ServerRuntime,
	objectiveId: string,
	reason: Types.ObjectiveEndReason?
): (boolean, string?)
	local active = self._activeById[objectiveId]
	if not active then
		return false, `objective {objectiveId} is not active`
	end
	if active.ending then
		return false, `objective {objectiveId} is already ending`
	end

	active.ending = true
	local definition = active.definition
	local endReason = reason or "cancelled"

	if definition.OnEnd then
		definition.OnEnd(active.context, endReason)
	end

	active.maid:DoCleaning()
	self._activeById[objectiveId] = nil

	StateActions.UpdateSnapshot(self.state, objectiveId, function(snapshot)
		local nextSnapshot = table.clone(snapshot)
		nextSnapshot.Status = "Ended"
		nextSnapshot.EndedAt = os.clock()
		nextSnapshot.Reason = endReason
		nextSnapshot.OwnerTeam = snapshot.OwnerTeam
		nextSnapshot.ContestingTeam = nil
		return nextSnapshot
	end)

	return true, nil
end

function ServerRuntime.Destroy(self: ServerRuntime)
	local activeIds = {}
	for objectiveId in pairs(self._activeById) do
		table.insert(activeIds, objectiveId)
	end

	for _, objectiveId in ipairs(activeIds) do
		self:EndObjective(objectiveId, "destroyed")
	end

	self.maid:DoCleaning()
end

return ServerRuntime
