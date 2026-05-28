local Mocks = require("../Core/Mocks")
local ServerRuntime = require("@game/ServerScriptService/Class_Server/ServerRuntime")
local StateActions = require("../StateActions")
local Maid = require("@game/ReplicatedStorage/Packages/maid")

return function()
	local globalMaid = Maid.new()
	local testAccess = {
		Assets = globalMaid:GiveTask(Instance.new("Folder")),
		Config = {
			DebugMode = true,
		},
	}

	local itemProviders = {
		Test = require("../ItemProviders/Test"),
	}
	local configByClassId = {
		RiflemanA = Mocks.ClassConfig("RiflemanA"),
		RiflemanB = Mocks.ClassConfig("RiflemanB"),
		EngineerA = Mocks.ClassConfig("EngineerA"),
		MarksmanA = Mocks.ClassConfig("MarksmanA"),
		MarksmanB = Mocks.ClassConfig("MarksmanB"),
	}
	local configByFactionId = {
		alpha = Mocks.FactionConfig("alpha"),
		bravo = Mocks.FactionConfig("bravo"),
	}

	local runtime
    local playerOne
    local playerTwo

	afterAll(function()
		globalMaid:DoCleaning()
	end)

    beforeEach(function()
        playerOne = Mocks.Player(1)
        playerTwo = Mocks.Player(2)

        runtime = ServerRuntime.new({
			access = testAccess,
            itemProviders = itemProviders,
            configByClassId = configByClassId,
            configByFactionId = configByFactionId,
            shouldSync = false,
        })
    end)

	afterEach(function()
		runtime:Destroy()
	end)

	it("should register provided faction configs into state", function()
		local registeredFactions = runtime.state.configByFactionId()
		expect(registeredFactions.alpha).to.equal(configByFactionId.alpha)
		expect(registeredFactions.bravo).to.equal(configByFactionId.bravo)
	end)

	it("should assign the default class when a player is set to a faction", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		expect(runtime.state.playerByGroupKey()[playerOne.UserId]).to.equal("Rifleman")
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")

		StateActions.SetPlayerGroupClass(runtime.state, playerOne.UserId, "Rifleman", "RiflemanB")

		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "bravo")
		expect(runtime.state.playerByGroupKey()[playerOne.UserId]).to.equal("Rifleman")
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")
	end)

	it("should update state accordingly when a class is assigned to a player", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		
		runtime.selectionHandler:HandleGroupClassRequest(playerOne, {
			groupKey = "Rifleman",
			classId = "RiflemanA",
		}, runtime.itemEquipper)

		expect(runtime.state.playerByFactionId()[playerOne.UserId]).to.equal("alpha")
		expect(runtime.state.playerByGroupKey()[playerOne.UserId]).to.equal("Rifleman")
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")
	end)

	it("should remove all assignments when a player is unassigned from a faction", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		StateActions.RemovePlayerFaction(runtime.state, playerOne.UserId)

		expect(runtime.state.playerByFactionId()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerByGroupKey()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal(nil)
	end)

	it("should remove the assignment when a class is assigned to a player that is not in a faction", function()
		runtime.selectionHandler:HandleGroupClassRequest(playerOne, {
			groupKey = "Rifleman",
			classId = "RiflemanA"
		}, runtime.itemEquipper)

		expect(runtime.state.playerByFactionId()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerByGroupKey()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal(nil)
	end)

	it("should not assign the class when a player is assigned to a full class slot", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		StateActions.SetPlayerFaction(runtime.state, playerTwo.UserId, "alpha")
		runtime.selectionHandler:HandleGroupClassRequest(playerOne, {
			groupKey = "Marksman",
			classId = "MarksmanA",
		}, runtime.itemEquipper)
		runtime.selectionHandler:HandleGroupClassRequest(playerTwo, {
			groupKey = "Marksman",
			classId = "MarksmanA",
		}, runtime.itemEquipper)
		expect(runtime.state.playerByGroupKey()[playerOne.UserId]).to.equal("Marksman")
		expect(runtime.state.playerByGroupKey()[playerTwo.UserId]).to.equal("Rifleman")
		expect(runtime.state.groupCountByFaction()["alpha"]["Marksman"]).to.equal(1)
		expect(runtime.state.groupCountByFaction()["alpha"]["Rifleman"]).to.equal(1)
	end)
	

end
