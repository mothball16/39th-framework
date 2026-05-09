local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework.Core.Types)
local Mocks = require(Access.Framework.Core.Mocks)


return function()
	local ServerRoot = game.ServerScriptService.Class_Server
	local ClassServerRuntime = require(ServerRoot.ClassServerRuntime)
	local StateActions = require(ServerRoot.StateActions)
	local itemProviders = {
		Test = Mocks.ItemProvider("Test"),
	}
	local classConfigs = {
		RiflemanA = Mocks.ClassConfig("RiflemanA"),
		RiflemanB = Mocks.ClassConfig("RiflemanB"),
		EngineerA = Mocks.ClassConfig("EngineerA"),
		MarksmanA = Mocks.ClassConfig("MarksmanA"),
		MarksmanB = Mocks.ClassConfig("MarksmanB"),
	}
	local factionConfigs = {
		alpha = Mocks.FactionConfig("alpha"),
		bravo = Mocks.FactionConfig("bravo"),
	}

	local runtime
    local playerOne
    local playerTwo

    beforeEach(function()
        playerOne = Mocks.Player("1")
        playerTwo = Mocks.Player("2")

        runtime = ClassServerRuntime.new({
            itemProviders = itemProviders,
            classConfigs = classConfigs,
            factionConfigs = factionConfigs,
            shouldSync = false,
        })
    end)

	afterEach(function()
		runtime:Destroy()
	end)

	it("should register provided faction configs into state", function()
		local registeredFactions = runtime.state.factionConfigs()
		expect(registeredFactions.alpha).to.equal(factionConfigs.alpha)
		expect(registeredFactions.bravo).to.equal(factionConfigs.bravo)
	end)

	it("should assign the default class when a player is set to a faction", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		expect(runtime.state.playerClassKeys()[playerOne.UserId]).to.equal("Rifleman")
		expect(runtime.state.playerClassIds()[playerOne.UserId]).to.equal("RiflemanA")
	end)

	it("should update state accordingly when a class is assigned to a player", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		
		runtime.classSelectionHandler:HandleClassRequest(playerOne, {
			classKey = "Rifleman",
			classId = "RiflemanA",
		})

		expect(runtime.state.playerFactionIds()[playerOne.UserId]).to.equal("alpha")
		expect(runtime.state.playerClassKeys()[playerOne.UserId]).to.equal("Rifleman")
		expect(runtime.state.playerClassIds()[playerOne.UserId]).to.equal("RiflemanA")
	end)

	it("should remove all assignments when a player is unassigned from a faction", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		StateActions.RemovePlayerFaction(runtime.state, playerOne.UserId)

		expect(runtime.state.playerFactionIds()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerClassKeys()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerClassIds()[playerOne.UserId]).to.equal(nil)
	end)

	it("should remove the assignment when a class is assigned to a player that is not in a faction", function()
		runtime.classSelectionHandler:HandleClassRequest(playerOne, {
			classKey = "Rifleman",
			classId = "RiflemanA",
		})

		expect(runtime.state.playerFactionIds()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerClassKeys()[playerOne.UserId]).to.equal(nil)
		expect(runtime.state.playerClassIds()[playerOne.UserId]).to.equal(nil)
	end)

	it("should not assign the class when a player is assigned to a full class slot", function()
		StateActions.SetPlayerFaction(runtime.state, playerOne.UserId, "alpha")
		StateActions.SetPlayerFaction(runtime.state, playerTwo.UserId, "alpha")
		runtime.classSelectionHandler:HandleClassRequest(playerOne, {
			classKey = "Marksman",
			classId = "MarksmanA",
		})
		runtime.classSelectionHandler:HandleClassRequest(playerTwo, {
			classKey = "Marksman",
			classId = "MarksmanA",
		})
		expect(runtime.state.playerClassKeys()[playerOne.UserId]).to.equal("Marksman")
		expect(runtime.state.playerClassKeys()[playerTwo.UserId]).to.equal("Rifleman")
		expect(runtime.state.classCountsByFaction()["alpha"]["Marksman"]).to.equal(1)
		expect(runtime.state.classCountsByFaction()["alpha"]["Rifleman"]).to.equal(1)
	end)

end
