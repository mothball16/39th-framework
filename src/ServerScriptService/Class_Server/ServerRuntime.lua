local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local State = require(Access.Framework.Core:WaitForChild("State"))
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))

local ItemEquipper = require(script.Parent.ItemEquipper)
local SelectionHandler = require(script.Parent.SelectionHandler)
local StateObserver = require(script.Parent.StateObserver)
local ServerSyncer = require(script.Parent.ServerSyncer)
local StateActions = require(script.Parent.StateActions)

local ServerRuntime = {}
ServerRuntime.__index = ServerRuntime

function ServerRuntime.new(args: {
	itemProviders: { [string]: Types.ClassItemProvider },
	classConfigs: { [string]: Types.ClassConfig },
	factionConfigs: { [string]: Types.FactionConfig },
	shouldSync: boolean,
})
	local state = State.new()

	local self = setmetatable({
		state = state,
		factionConfigs = args.factionConfigs,
		itemEquipper = ItemEquipper.new(args.itemProviders, args.classConfigs),
		selectionHandler = SelectionHandler.new(state, args.classConfigs),
		stateObserver = StateObserver.new(state),
		serverSyncer = args.shouldSync and ServerSyncer.new({
			factionConfigs = state.factionConfigs,
			playerFactionIds = state.playerFactionIds,
			playerClassKeys = state.playerClassKeys,
			playerClassIds = state.playerClassIds,
			classCountsByFaction = state.classCountsByFaction,
		}, Events) or nil,
	}, ServerRuntime)

	for _, factionConfig in pairs(self.factionConfigs) do
		StateActions.CreateFaction(self.state, factionConfig)
	end

	self.stateObserver:Start()

	return self
end

-- wires up everything. don't call for tests

function ServerRuntime:Start()
	Players.PlayerAdded:Connect(function(player)
		self.selectionHandler:HandleTeamChange(player, player.Team)

		player:GetPropertyChangedSignal("Team"):Connect(function()
			self.selectionHandler:HandleTeamChange(player, player.Team)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		StateActions.RemovePlayerFaction(self.state, player.UserId)
	end)

	Events.RequestFaction.OnServerEvent:Connect(function(player: Player, request: { factionId: string })
		self.selectionHandler:HandleFactionRequest(player, request)
	end)

	Events.RequestClass.OnServerEvent:Connect(function(player: Player, request: { classKey: string, classId: string })
		self.selectionHandler:HandleClassRequest(player, request)
	end)
end

function ServerRuntime:Destroy()
	if self.serverSyncer then
		self.serverSyncer:Destroy()
	end
end

return ServerRuntime
