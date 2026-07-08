--!strict
--#selene: allow(incorrect_standard_library_use, undefined_variable)
local ServerRuntime = require("@game/ServerScriptService/Systems/Objective/ServerRuntime")
local Hardpoint = require("../Builders/Hardpoint")
local Domination = require("../Builders/Domination")
local Payload = require("../Builders/Payload")
local TDM = require("../Builders/TDM")
local MultiPhase = require("../Builders/MultiPhase")

local State = require("../Core/State")
local Types = require("../Core/Types")
local StateActions = require("../Logic/StateActions")

local function fakePlayer(teamId: string): Player
	return ({ TeamId = teamId } :: any) :: Player
end

local function makeAccess()
	return {
		Assets = Instance.new("Folder"),
		Config = {
			GetTeamId = function(player: Player)
				return (player :: any).TeamId :: string?
			end,
		},
	}
end

local function makeContext(definition: Types.ObjectiveDefinition)
	local state = State()
	StateActions.SetSnapshot(state, StateActions.DefaultSnapshot(definition))
	StateActions.UpdateSnapshot(state, definition.ID, function(snapshot)
		local nextSnapshot = table.clone(snapshot)
		nextSnapshot.Status = "Active"
		return nextSnapshot
	end)

	local completed = {
		count = 0,
		winnerTeam = nil :: string?,
		reason = nil :: string?,
	}

	local context: Types.ObjectiveContext
	context = {
		ObjectiveId = definition.ID,
		Definition = definition,
		State = state,
		Maid = nil :: any,
		Access = makeAccess(),

		GetSnapshot = function()
			return state.objectiveById()[definition.ID]
		end,
		SetSnapshot = function(snapshot)
			StateActions.SetSnapshot(state, snapshot)
		end,
		UpdateSnapshot = function(update)
			StateActions.UpdateSnapshot(state, definition.ID, update)
		end,
		AddScore = function(teamId, amount)
			return StateActions.AddScore(state, definition.ID, teamId, amount)
		end,
		SetProgress = function(progress)
			StateActions.SetProgress(state, definition.ID, progress)
		end,
		Complete = function(result)
			completed.count += 1
			if result then
				completed.winnerTeam = result.winnerTeam
				completed.reason = result.reason
			end
		end,
		End = function(reason)
			completed.count += 1
			completed.reason = reason
		end,
		GetTeamId = function(player)
			return (player :: any).TeamId :: string?
		end,
		OnHeartbeat = function(_callback)
			return nil
		end,
	}

	return context, completed
end

local function makeSignal()
	local signal = {
		disconnects = 0,
		connections = {},
	}

	function signal:Connect(callback)
		local connection = {
			Connected = true,
			Disconnect = function(item)
				if item.Connected then
					item.Connected = false
					signal.disconnects += 1
				end
			end,
		}
		table.insert(signal.connections, {
			callback = callback,
			connection = connection,
		})
		return connection
	end

	return signal
end

return function()
	describe("ServerRuntime", function()
		it("starts and ends multiple objectives independently", function()
			local runtime = ServerRuntime.new({ access = makeAccess() })
			local starts = 0
			local ends = 0

			runtime:RegisterObjective({
				ID = "alpha",
				Kind = "Test",
				OnStart = function()
					starts += 1
					return nil
				end,
				OnEnd = function()
					ends += 1
				end,
			})
			runtime:RegisterObjective({
				ID = "bravo",
				Kind = "Test",
				OnStart = function()
					starts += 1
					return nil
				end,
				OnEnd = function()
					ends += 1
				end,
			})

			expect(runtime:StartObjective("alpha")).to.equal(true)
			expect(runtime:StartObjective("bravo")).to.equal(true)
			expect(runtime:StartObjective("alpha")).to.equal(false)
			expect(starts).to.equal(2)

			expect(runtime:EndObjective("alpha", "done")).to.equal(true)
			expect(runtime.state.objectiveById().alpha.Status).to.equal("Ended")
			expect(runtime.state.objectiveById().bravo.Status).to.equal("Active")
			expect(ends).to.equal(1)

			runtime:Destroy()
			expect(ends).to.equal(2)
		end)
	end)

	describe("MultiPhase", function()
		it("runs one phase at a time and ends the active phase on wrapper end", function()
			local runtime = ServerRuntime.new({ access = makeAccess() })
			local phaseContexts = {}
			local events = {}

			local objective = MultiPhase.build({
				ID = "multi",
				Phases = {
					{
						ID = "one",
						Kind = "Phase",
						OnStart = function(context)
							table.insert(events, "start-one")
							table.insert(phaseContexts, context)
							return nil
						end,
						OnEnd = function()
							table.insert(events, "end-one")
						end,
					},
					{
						ID = "two",
						Kind = "Phase",
						OnStart = function(context)
							table.insert(events, "start-two")
							table.insert(phaseContexts, context)
							return nil
						end,
						OnEnd = function()
							table.insert(events, "end-two")
						end,
					},
				},
			})

			runtime:RegisterObjective(objective)
			runtime:StartObjective("multi")

			expect(events[1]).to.equal("start-one")
			phaseContexts[1].Complete()
			expect(events[2]).to.equal("end-one")
			expect(events[3]).to.equal("start-two")
			expect(runtime.state.objectiveById().multi.PhaseIndex).to.equal(2)

			runtime:EndObjective("multi", "cancelled")
			expect(events[4]).to.equal("end-two")
		end)
	end)

	describe("Hardpoint", function()
		it("captures for one team, contests mixed teams, and scores the owner", function()
			local config = {
				ID = "hp",
				GetPlayersInZone = function()
					return { fakePlayer("Red") }
				end,
				ScoreRate = 2,
				ScoreLimit = 10,
			}
			local definition = Hardpoint.build(config)
			local context = makeContext(definition)

			Hardpoint.Step(context, config, 1)

			expect(context.GetSnapshot().OwnerTeam).to.equal("Red")
			expect(context.GetSnapshot().Scores.Red).to.equal(2)
		end)

		it("does not score while contested", function()
			local config = {
				ID = "hp",
				GetPlayersInZone = function()
					return { fakePlayer("Red") }
				end,
				ScoreRate = 1,
			}
			local definition = Hardpoint.build(config)
			local context = makeContext(definition)

			Hardpoint.Step(context, config, 1)
			config.GetPlayersInZone = function()
				return { fakePlayer("Red"), fakePlayer("Blue") }
			end
			Hardpoint.Step(context, config, 1)

			expect(context.GetSnapshot().OwnerTeam).to.equal("Red")
			expect(context.GetSnapshot().ContestingTeam).to.equal("Contested")
			expect(context.GetSnapshot().Scores.Red).to.equal(1)
		end)
	end)

	describe("Domination", function()
		it("tracks zone owners and scores for every owned zone", function()
			local config = {
				ID = "dom",
				Zones = {
					{
						ID = "a",
						GetPlayersInZone = function()
							return { fakePlayer("Red") }
						end,
					},
					{
						ID = "b",
						GetPlayersInZone = function()
							return { fakePlayer("Red") }
						end,
					},
				},
				ScoreRate = 1,
				ScoreLimit = 2,
			}
			local definition = Domination.build(config)
			local context, completed = makeContext(definition)

			Domination.Step(context, config, 1)

			expect(context.GetSnapshot().Details.zones.a.ownerTeam).to.equal("Red")
			expect(context.GetSnapshot().Scores.Red).to.equal(2)
			expect(completed.count).to.equal(1)
			expect(completed.winnerTeam).to.equal("Red")
		end)
	end)

	describe("Payload", function()
		it("advances with attackers and pauses while contested", function()
			local occupants = { fakePlayer("Red") }
			local config = {
				ID = "payload",
				Waypoints = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0) },
				AttackerTeams = { "Red" },
				Speed = 0.5,
				GetPlayersInZone = function()
					return occupants
				end,
			}
			local definition = Payload.build(config)
			local context = makeContext(definition)

			Payload.Step(context, config, 1)
			expect(context.GetSnapshot().Progress).to.equal(0.5)

			occupants = { fakePlayer("Red"), fakePlayer("Blue") }
			Payload.Step(context, config, 1)
			expect(context.GetSnapshot().Progress).to.equal(0.5)
			expect(context.GetSnapshot().Details.contested).to.equal(true)
		end)
	end)

	describe("TDM", function()
		it("attaches kill listeners on start and detaches them on end", function()
			local added = makeSignal()
			local removing = makeSignal()
			local playerSource = {
				PlayerAdded = added,
				PlayerRemoving = removing,
				GetPlayers = function()
					return {}
				end,
			}

			local runtime = ServerRuntime.new({ access = makeAccess() })
			runtime:RegisterObjective(TDM.build({
				ID = "tdm-listeners",
				PlayerSource = playerSource,
			}))

			runtime:StartObjective("tdm-listeners")
			expect(#added.connections).to.equal(1)
			expect(#removing.connections).to.equal(1)

			runtime:EndObjective("tdm-listeners", "done")
			expect(added.disconnects).to.equal(1)
			expect(removing.disconnects).to.equal(1)
		end)

		it("scores valid enemy kills without using ServerRuntime ReportKill", function()
			local config = {
				ID = "tdm",
				ScoreLimit = 2,
			}
			local definition = TDM.build(config)
			local context, completed = makeContext(definition)

			expect(TDM.ScoreKill(context, config, fakePlayer("Red"), fakePlayer("Blue"))).to.equal(true)
			expect(TDM.ScoreKill(context, config, fakePlayer("Red"), fakePlayer("Red"))).to.equal(false)
			expect(TDM.ScoreKill(context, config, fakePlayer("Red"), fakePlayer("Blue"))).to.equal(true)

			expect(context.GetSnapshot().Scores.Red).to.equal(2)
			expect(completed.count).to.equal(1)
			expect(completed.winnerTeam).to.equal("Red")
			expect((ServerRuntime :: any).ReportKill).to.equal(nil)
		end)
	end)
end
