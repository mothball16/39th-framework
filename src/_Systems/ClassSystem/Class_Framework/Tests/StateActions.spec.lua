local StateActions = require("../Logic/StateActions")
local State = require("../Core/State")
local Mocks = require("../Core/Mocks")
local Types = require("../Core/Types")
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

	describe("StateActions", function()
		it("should create a faction", function()
            expect(state.configByFactionId()[factionAlpha.ID]).to.equal(factionAlpha)
		end)

        it("should remove a faction", function()
            StateActions.RemoveFaction(state, factionAlpha.ID)
            expect(state.configByFactionId()[factionAlpha.ID]).to.equal(nil)
        end)

        it("should complain about default group limits", function()
            factionAlpha.Groups.Rifleman.Limit = 10
            local success, msg = StateActions.CreateFaction(state, factionAlpha)

            expect(factionAlpha.Groups.Rifleman.Limit).to.equal(math.huge)
            expect(success).to.equal(true)
            expect(#msg > 0).to.equal(true)
        end)

        it("should complain about default group access checks", function()
            factionAlpha.Groups.Rifleman.Classes[1].AccessCheck = function(_) return false end
            local success, msg = StateActions.CreateFaction(state, factionAlpha)

            expect(success).to.equal(true)
            expect(#msg > 0).to.equal(true)
        end)

        it("should assign the default class when a player is set to a faction", function()
            expect(state.playerByGroupKey()[playerOne.UserId]).to.equal("Rifleman")
            expect(state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")

            StateActions.SetPlayerGroupClass(state, playerOne.UserId, "Rifleman", "RiflemanB")
            local success = StateActions.SetPlayerFaction(state, playerOne.UserId, "bravo")

            expect(success).to.equal(true)
            expect(state.playerByGroupKey()[playerOne.UserId]).to.equal("Rifleman")
            expect(state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")
        end)

        it("should remove all assignments when a player is unassigned from a faction/removed from the game", function()
            StateActions.RemovePlayerFaction(state, playerOne.UserId)

            expect(state.playerByFactionId()[playerOne.UserId]).to.equal(nil)
            expect(state.playerByGroupKey()[playerOne.UserId]).to.equal(nil)
            expect(state.playerByClassId()[playerOne.UserId]).to.equal(nil)
        end)

        it("should deny SetPlayerGroupClass when GroupKey is not a valid group of the faction", function()
            local success = StateActions.SetPlayerGroupClass(
                state, playerOne.UserId,
                "kanami_hate_club",
                factionAlpha.Groups.Engineer.Classes[1].Id)

            expect(success).to.equal(false)
            expect(state.playerByGroupKey()[playerOne.UserId])
                .to.equal(factionAlpha.DefaultGroupKey)
            expect(state.playerByClassId()[playerOne.UserId])
                .to.equal(factionAlpha.Groups[factionAlpha.DefaultGroupKey].Classes[1].Id)
        end)

        it("should deny SetPlayerGroupClass when ClassId is not a valid class of the group", function()
            local success = StateActions.SetPlayerGroupClass(state, playerOne.UserId,
                "Engineer",
                "super_hacker_5")

            expect(success).to.equal(false)
            expect(state.playerByGroupKey()[playerOne.UserId])
                .to.equal(factionAlpha.DefaultGroupKey)
            expect(state.playerByClassId()[playerOne.UserId])
                .to.equal(factionAlpha.Groups[factionAlpha.DefaultGroupKey].Classes[1].Id)
        end)

        it("should deny SetPlayerGroupClass when the player is not assigned to a faction", function()
            StateActions.RemovePlayerFaction(state, playerOne.UserId)
            local success = StateActions.SetPlayerGroupClass(
                state, playerOne.UserId,
                factionAlpha.DefaultGroupKey,
                factionAlpha.Groups[factionAlpha.DefaultGroupKey].Classes[1].Id)

            expect(success).to.equal(false)
            expect(state.playerByGroupKey()[playerOne.UserId]).to.equal(nil)
            expect(state.playerByClassId()[playerOne.UserId]).to.equal(nil)
        end)

        it("should deny SetPlayerGroupClass when the player fails the access check", function()
            local success = StateActions.SetPlayerGroupClass(state, playerOne.UserId,
                "Rifleman",
                "RiflemanZ")

            expect(success).to.equal(false)
            expect(state.playerByGroupKey()[playerOne.UserId]).to.equal("Rifleman")
            expect(state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")
        end)
	end)
end