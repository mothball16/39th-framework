local Mocks = require("../Core/Mocks")
local Item = require("../Core/Item")
local Enums = require("../Core/Enums")
local ServerRuntime = require("@game/ServerScriptService/Faction_Server/ServerRuntime")
local StateActions = require("../Logic/StateActions")
local Utilities = require("../Logic/Utilities")
local Maid = require("@game/ReplicatedStorage/Packages/maid")

return function()
	local globalMaid = Maid.new()
	local testAccess = {
		Assets = globalMaid:GiveTask(Instance.new("Folder")),
		Config = {
			DebugMode = true,
		},
	}

	local itemCounts = {
		assign = 0,
		unassign = 0,
	}

	local function resetItemCounts()
		itemCounts.assign = 0
		itemCounts.unassign = 0
	end

	local function callbackVariant(variantId: string)
		return {
			ID = variantId,
			Items = {
				Item.callback({
					onAssign = function()
						itemCounts.assign += 1
					end,
					onUnassign = function()
						itemCounts.unassign += 1
					end,
				}),
			},
		}
	end

	local itemProviders = {
		Test = require("../ItemProviders/Test"),
		Callback = require("../ItemProviders/Callback"),
	}
	local configByVariantId = {
		RiflemanA = callbackVariant("RiflemanA"),
		RiflemanB = callbackVariant("RiflemanB"),
		EngineerA = Mocks.VariantConfig("EngineerA"),
		MarksmanA = Mocks.VariantConfig("MarksmanA"),
		MarksmanB = Mocks.VariantConfig("MarksmanB"),
	}
	local configByFactionId = {
		alpha = Mocks.FactionConfig("alpha"),
		bravo = Mocks.FactionConfig("bravo"),
	}

	local function mockTeam(factionId: string?)
		return {
			GetAttribute = function(_, attribute: string)
				if attribute == Enums.Faction.AutoFactionAttribute then
					return factionId
				end
				return nil
			end,
		}
	end

	local function createMockCharacterPlayer(userId: number)
		local character = Instance.new("Model")
		character.Name = "Character"
		globalMaid:GiveTask(character)

		return {
			UserId = userId,
			Character = character,
		}
	end

	local function assignment(runtime, player)
		return runtime.state.playerAssignmentByUserId()[Utilities.ToPlayerKey(player.UserId)]
	end


	afterAll(function()
		globalMaid:DoCleaning()
	end)

	describe("ServerRuntime", function()
		local runtime: ServerRuntime.ServerRuntime
		local playerOne: Player
		local playerTwo: Player

		beforeEach(function()
			resetItemCounts()
			playerOne = Mocks.Player(1)
			playerTwo = Mocks.Player(2)

			runtime = ServerRuntime.new({
				access = testAccess,
				shouldSync = false,
			})

			for _, itemProvider in pairs(itemProviders) do
				runtime:RegisterItemProvider(itemProvider)
			end

			for _, variantConfig in pairs(configByVariantId) do
				runtime:RegisterVariant(variantConfig)
			end

			for _, factionConfig in pairs(configByFactionId) do
				runtime:RegisterFaction(factionConfig)
			end
		end)

		afterEach(function()
			runtime:Destroy()
		end)



		describe("SelectionService", function()
			describe("HandleFactionRequest", function()
				it("should set faction and default class for a valid faction request", function()
					runtime.selectionService:HandleFactionRequest(playerOne, {
						factionId = "alpha",
					})

					expect(assignment(runtime, playerOne).FactionId).to.equal("alpha")
					expect(assignment(runtime, playerOne).ClassKey).to.equal("Rifleman")
					expect(assignment(runtime, playerOne).VariantId).to.equal("RiflemanA")
				end)

				it("should ignore faction requests for unknown factions", function()
					runtime.selectionService:HandleFactionRequest(playerOne, {
						factionId = "unknown",
					})

					expect(assignment(runtime, playerOne)).to.equal(nil)
				end)
			end)

			describe("HandleClassVariantRequest", function()
				it("should update state when a valid class variant is requested", function()
					StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")

					runtime.selectionService:HandleClassVariantRequest(playerOne, {
						class = "Rifleman",
						variant = "RiflemanA",
					}, runtime.itemEquipper)

					expect(assignment(runtime, playerOne).FactionId).to.equal("alpha")
					expect(assignment(runtime, playerOne).ClassKey).to.equal("Rifleman")
					expect(assignment(runtime, playerOne).VariantId).to.equal("RiflemanA")
				end)

				it("should not update state when the player is not in a faction", function()
					runtime.selectionService:HandleClassVariantRequest(playerOne, {
						class = "Rifleman",
						variant = "RiflemanA",
					}, runtime.itemEquipper)

					expect(assignment(runtime, playerOne)).to.equal(nil)
				end)

				it("should unassign the previous variant items before changing variant", function()
					StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
					runtime.itemEquipper:AssignVariantItems(playerOne, "RiflemanA")
					resetItemCounts()

					runtime.selectionService:HandleClassVariantRequest(playerOne, {
						class = "Rifleman",
						variant = "RiflemanB",
					}, runtime.itemEquipper)

					expect(itemCounts.unassign).to.equal(1)
					expect(assignment(runtime, playerOne).VariantId).to.equal("RiflemanB")
				end)

				it("should not assign the variant when the requested class slot is full", function()
					StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
					StateActions.SetPlayerFaction(runtime.state, playerTwo.UserId, "alpha")

					runtime.selectionService:HandleClassVariantRequest(playerOne, {
						class = "Marksman",
						variant = "MarksmanA",
					}, runtime.itemEquipper)
					runtime.selectionService:HandleClassVariantRequest(playerTwo, {
						class = "Marksman",
						variant = "MarksmanA",
					}, runtime.itemEquipper)

					expect(assignment(runtime, playerOne).ClassKey).to.equal("Marksman")
					expect(assignment(runtime, playerTwo).ClassKey).to.equal("Rifleman")
					expect(runtime.state.getClassCountByFaction()["alpha"]["Marksman"]).to.equal(1)
					expect(runtime.state.getClassCountByFaction()["alpha"]["Rifleman"]).to.equal(1)
				end)
			end)

			describe("HandleTeamChange", function()
				it("should set faction from a team AutoFaction attribute", function()
					runtime.selectionService:HandleTeamChange(playerOne, mockTeam("alpha"), runtime.itemEquipper)

					expect(assignment(runtime, playerOne).FactionId).to.equal("alpha")
					expect(assignment(runtime, playerOne).ClassKey).to.equal("Rifleman")
					expect(assignment(runtime, playerOne).VariantId).to.equal("RiflemanA")
				end)

				it("should unassign variant items when team change switches faction", function()
					StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
					runtime.itemEquipper:AssignVariantItems(playerOne, "RiflemanA")
					resetItemCounts()

					runtime.selectionService:HandleTeamChange(playerOne, mockTeam("bravo"), runtime.itemEquipper)

					expect(itemCounts.unassign).to.equal(1)
					expect(assignment(runtime, playerOne).FactionId).to.equal("bravo")
				end)

				it("should ignore team change when team is nil", function()
					runtime.selectionService:HandleTeamChange(playerOne, nil, runtime.itemEquipper)

					expect(assignment(runtime, playerOne)).to.equal(nil)
				end)

				it("should ignore team change when team has no AutoFaction attribute", function()
					runtime.selectionService:HandleTeamChange(playerOne, mockTeam(nil), runtime.itemEquipper)

					expect(assignment(runtime, playerOne)).to.equal(nil)
				end)

				it("should ignore team change when AutoFaction points to an unknown faction", function()
					runtime.selectionService:HandleTeamChange(playerOne, mockTeam("unknown"), runtime.itemEquipper)

					expect(assignment(runtime, playerOne)).to.equal(nil)
				end)

				it("should ignore team change when the player is already on that faction", function()
					StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
					runtime.itemEquipper:AssignVariantItems(playerOne, "RiflemanA")
					resetItemCounts()

					runtime.selectionService:HandleTeamChange(playerOne, mockTeam("alpha"), runtime.itemEquipper)

					expect(itemCounts.unassign).to.equal(0)
					expect(assignment(runtime, playerOne).FactionId).to.equal("alpha")
				end)
			end)

			describe("HandleVariantApplyRequest", function()
				it("should assign variant items when apply is enabled", function()
					local player = createMockCharacterPlayer(1)

					StateActions.SetPlayerFaction(runtime.state, player.UserId, "alpha")

					runtime.selectionService:HandleVariantApplyRequest(player, {
						enable = true,
					}, runtime.itemEquipper)

					expect(itemCounts.assign).to.equal(1)
				end)

				it("should unassign variant items when apply is disabled", function()
					local player = createMockCharacterPlayer(1)

					StateActions.SetPlayerFaction(runtime.state, player.UserId, "alpha")
					runtime.itemEquipper:AssignVariantItems(player, "RiflemanA")
					resetItemCounts()

					runtime.selectionService:HandleVariantApplyRequest(player, {
						enable = false,
					}, runtime.itemEquipper)

					expect(itemCounts.unassign).to.equal(1)
				end)

				it("should ignore apply requests when the player has no variant", function()
					local player = createMockCharacterPlayer(1)

					runtime.selectionService:HandleVariantApplyRequest(player, {
						enable = true,
					}, runtime.itemEquipper)

					expect(itemCounts.assign).to.equal(0)
				end)

				it("should ignore apply requests when the player has no character", function()
					StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")

					runtime.selectionService:HandleVariantApplyRequest(playerOne, {
						enable = true,
					}, runtime.itemEquipper)

					expect(itemCounts.assign).to.equal(0)
				end)
			end)
		end)
	end)
end
