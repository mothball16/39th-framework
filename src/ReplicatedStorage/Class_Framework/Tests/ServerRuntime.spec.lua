local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Class_Framework.Core.Types)
local Mocks = require(ReplicatedStorage.Class_Framework.Core.Mocks)


return function()
	local ServerRoot = game.ServerScriptService.Class_Server
	local ServerRuntime = require(ServerRoot.ServerRuntime)
	local StateActions = require(ReplicatedStorage.Class_Framework.StateActions)
	local itemProviders = {
		Test = require(ReplicatedStorage.Class_Framework.ItemProviders.Test),
	}
	local classConfigs = {
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

    beforeEach(function()
        playerOne = Mocks.Player(1)
        playerTwo = Mocks.Player(2)

        runtime = ServerRuntime.new({
            itemProviders = itemProviders,
            classConfigs = classConfigs,
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
		expect(runtime.state.playerByClassKey()[playerOne.UserId]).to.equal("Rifleman")
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")

		StateActions.SetPlayerClass(runtime.state, playerOne.UserId, "Rifleman", "RiflemanB")

		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "bravo")
		expect(runtime.state.playerByClassKey()[playerOne.UserId]).to.equal("Rifleman")
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")
	end)

	it("should update state accordingly when a class is assigned to a player", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		
		runtime.selectionHandler:HandleClassRequest(playerOne, {
			classKey = "Rifleman",
			classId = "RiflemanA",
		}, runtime.itemEquipper)

		expect(runtime.state.playerByFactionId()[playerOne.UserId]).to.equal("alpha")
		expect(runtime.state.playerByClassKey()[playerOne.UserId]).to.equal("Rifleman")
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal("RiflemanA")
	end)

	it("should remove all assignments when a player is unassigned from a faction", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		StateActions.RemovePlayerFaction(runtime.state, playerOne.UserId)

		expect(runtime.state.playerByFactionId()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerByClassKey()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal(nil)
	end)

	it("should remove the assignment when a class is assigned to a player that is not in a faction", function()
		runtime.selectionHandler:HandleClassRequest(playerOne, {
			classKey = "Rifleman",
			classId = "RiflemanA"
		}, runtime.itemEquipper)

		expect(runtime.state.playerByFactionId()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerByClassKey()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerByClassId()[playerOne.UserId]).to.equal(nil)
	end)

	it("should not assign the class when a player is assigned to a full class slot", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		StateActions.SetPlayerFaction(runtime.state, playerTwo.UserId, "alpha")
		runtime.selectionHandler:HandleClassRequest(playerOne, {
			classKey = "Marksman",
			classId = "MarksmanA",
		}, runtime.itemEquipper)
		runtime.selectionHandler:HandleClassRequest(playerTwo, {
			classKey = "Marksman",
			classId = "MarksmanA",
		}, runtime.itemEquipper)
		expect(runtime.state.playerByClassKey()[playerOne.UserId]).to.equal("Marksman")
		expect(runtime.state.playerByClassKey()[playerTwo.UserId]).to.equal("Rifleman")
		expect(runtime.state.classCountByFaction()["alpha"]["Marksman"]).to.equal(1)
		expect(runtime.state.classCountByFaction()["alpha"]["Rifleman"]).to.equal(1)
	end)
	

end
