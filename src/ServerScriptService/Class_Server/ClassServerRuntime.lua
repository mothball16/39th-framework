local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local State = require(Access.Framework.Core:WaitForChild("State"))
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))

local ClassEquipper = require(script.Parent.ClassEquipper)
local ClassSelectionHandler = require(script.Parent.ClassSelectionHandler)
local ClassStateListener = require(script.Parent.ClassStateListener)
local ServerSyncer = require(script.Parent.ServerSyncer)
local StateActions = require(script.Parent.StateActions)

local ClassServerRuntime = {}
ClassServerRuntime.__index = ClassServerRuntime


function ClassServerRuntime.new(args: {
	itemProviders: {[string]: Types.ClassItemProvider},
	classConfigs: {[string]: Types.ClassConfig},
	factionConfigs: {[string]: Types.FactionConfig},
	shouldSync: boolean,
})
	local state = State.new()

	local self = setmetatable({
		state = state,
		factionConfigs = args.factionConfigs,
		classEquipper = ClassEquipper.new(args.itemProviders, args.classConfigs),
		classSelectionHandler = ClassSelectionHandler.new(state, args.classConfigs),
		classStateListener = ClassStateListener.new(state),
		serverSyncer = args.shouldSync and ServerSyncer.new({
			factionConfigs = state.factionConfigs,
			playerFactionIds = state.playerFactionIds,
			playerClassKeys = state.playerClassKeys,
			playerClassIds = state.playerClassIds,
			classCountsByFaction = state.classCountsByFaction,
		}, Events) or nil,
	}, ClassServerRuntime)

	for _, factionConfig in pairs(self.factionConfigs) do
		StateActions.CreateFaction(self.state, factionConfig)
	end

	self.classStateListener:Start()
	return self
end

-- wires up everything. don't call for tests
function ClassServerRuntime:Start()
	Players.PlayerAdded:Connect(function(player)
		self.classSelectionHandler:HandleTeamChange(player, player.Team)

		player:GetPropertyChangedSignal("Team"):Connect(function()
			self.classSelectionHandler:HandleTeamChange(player, player.Team)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		StateActions.RemovePlayerFaction(self.state, player.UserId)
	end)

	Events.RequestFaction.OnServerEvent:Connect(function(player: Player, request: { factionId: string })
		self.classSelectionHandler:HandleFactionRequest(player, request)
	end)

	Events.RequestClass.OnServerEvent:Connect(function(player: Player, request: { classKey: string, classId: string })
		self.classSelectionHandler:HandleClassRequest(player, request)
	end)
end

function ClassServerRuntime:Destroy()
	if self.serverSyncer then
		self.serverSyncer:Destroy()
	end
end

return ClassServerRuntime
