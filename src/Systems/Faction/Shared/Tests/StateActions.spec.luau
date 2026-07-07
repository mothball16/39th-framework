local StateActions = require("../Logic/StateActions")
local State = require("../Core/State")
local Mocks = require("../Core/Mocks")
local Types = require("../Core/Types")
local Utilities = require("../Logic/Utilities")
return function()
	local state: State.State
	local playerOne = Mocks.Player(1)
	local factionAlpha: Types.FactionConfig
	local factionBravo: Types.FactionConfig

	beforeEach(function()
		factionAlpha = Mocks.FactionConfig("alpha")
		factionBravo = Mocks.FactionConfig("bravo")
		state = State.new()
		StateActions.CreateFaction(state, factionAlpha)
		StateActions.CreateFaction(state, factionBravo)
		StateActions.SetPlayerFaction(state, playerOne.UserId, factionAlpha.ID)
	end)

	local function assignment(player)
		return state.playerAssignmentByUserId()[Utilities.ToPlayerKey(player.UserId)]
	end

	describe("StateActions", function()
		it("should create a faction", function()
			expect(state.configByFactionId()[factionAlpha.ID]).to.equal(factionAlpha)
		end)

		it("should remove a faction", function()
			StateActions.RemoveFaction(state, factionAlpha.ID)
			expect(state.configByFactionId()[factionAlpha.ID]).to.equal(nil)
		end)

		it("should complain about default class limits", function()
			factionAlpha.Classes.Rifleman.Limit = 10
			local success, msg = StateActions.CreateFaction(state, factionAlpha)

			expect(factionAlpha.Classes.Rifleman.Limit).to.equal(math.huge)
			expect(success).to.equal(true)
			expect(#msg > 0).to.equal(true)
		end)

		it("should complain about default class access checks", function()
			factionAlpha.Classes.Rifleman.Variants[1].AccessCheck = function(_)
				return false
			end
			local success, msg = StateActions.CreateFaction(state, factionAlpha)

			expect(success).to.equal(true)
			expect(#msg > 0).to.equal(true)
		end)

		it("should assign the default variant when a player is set to a faction", function()
			expect(assignment(playerOne).ClassKey).to.equal("Rifleman")
			expect(assignment(playerOne).VariantId).to.equal("RiflemanA")

			StateActions.SetPlayerClassVariant(state, playerOne.UserId, "Rifleman", "RiflemanB")
			local success = StateActions.SetPlayerFaction(state, playerOne.UserId, "bravo")

			expect(success).to.equal(true)
			expect(assignment(playerOne).ClassKey).to.equal("Rifleman")
			expect(assignment(playerOne).VariantId).to.equal("RiflemanA")
		end)

		it("should remove all assignments when a player is unassigned from a faction/removed from the game", function()
			StateActions.RemovePlayerFaction(state, playerOne.UserId)

			expect(assignment(playerOne)).to.equal(nil)
		end)

		it("should deny SetPlayerClassVariant when ClassKey is not a valid class of the faction", function()
			local success = StateActions.SetPlayerClassVariant(
				state,
				playerOne.UserId,
				"kanami_hate_club",
				factionAlpha.Classes.Engineer.Variants[1].Id
			)

			expect(success).to.equal(false)
			expect(assignment(playerOne).ClassKey).to.equal(factionAlpha.DefaultClassKey)
			expect(assignment(playerOne).VariantId).to.equal(
				factionAlpha.Classes[factionAlpha.DefaultClassKey].Variants[1].Id
			)
		end)

		it("should deny SetPlayerClassVariant when VariantId is not a valid variant of the class", function()
			local success = StateActions.SetPlayerClassVariant(state, playerOne.UserId, "Engineer", "super_hacker_5")

			expect(success).to.equal(false)
			expect(assignment(playerOne).ClassKey).to.equal(factionAlpha.DefaultClassKey)
			expect(assignment(playerOne).VariantId).to.equal(
				factionAlpha.Classes[factionAlpha.DefaultClassKey].Variants[1].Id
			)
		end)

		it("should deny SetPlayerClassVariant when the player is not assigned to a faction", function()
			StateActions.RemovePlayerFaction(state, playerOne.UserId)
			local success = StateActions.SetPlayerClassVariant(
				state,
				playerOne.UserId,
				factionAlpha.DefaultClassKey,
				factionAlpha.Classes[factionAlpha.DefaultClassKey].Variants[1].Id
			)

			expect(success).to.equal(false)
			expect(assignment(playerOne)).to.equal(nil)
		end)

		it("should deny SetPlayerClassVariant when the player fails the access check", function()
			local success = StateActions.SetPlayerClassVariant(state, playerOne.UserId, "Rifleman", "RiflemanZ")

			expect(success).to.equal(false)
			expect(assignment(playerOne).ClassKey).to.equal("Rifleman")
			expect(assignment(playerOne).VariantId).to.equal("RiflemanA")
		end)

		it("should deny SetPlayerClassVariant when the requested class slot is full", function()
			local playerTwo = Mocks.Player(2)
			StateActions.SetPlayerFaction(state, playerTwo.UserId, factionAlpha.ID)

			StateActions.SetPlayerClassVariant(state, playerOne.UserId, "Marksman", "MarksmanA")
			local success = StateActions.SetPlayerClassVariant(state, playerTwo.UserId, "Marksman", "MarksmanA")

			expect(success).to.equal(false)
			expect(assignment(playerOne).ClassKey).to.equal("Marksman")
			expect(assignment(playerTwo).ClassKey).to.equal("Rifleman")
			expect(state.getClassCountByFaction()[factionAlpha.ID]["Marksman"]).to.equal(1)
		end)
	end)
end
