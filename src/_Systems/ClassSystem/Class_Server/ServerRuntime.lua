local Players = game:GetService("Players")

local Maid = require("@game/ReplicatedStorage/Packages/maid")

local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")
local Events = require("@game/ReplicatedStorage/Class_Framework/Core/Events").GetNamespace()
local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")
local StateActions = require("@game/ReplicatedStorage/Class_Framework/StateActions")

local ItemEquipper = require("./ItemEquipper")
local SelectionHandler = require("./SelectionHandler")
local ServerSyncer = require("./ServerSyncer")

local ServerRuntime = {}
ServerRuntime.__index = ServerRuntime

type self = {
	state: State.State,
	configByFactionId: { [string]: Types.FactionConfig },
	itemEquipper: ItemEquipper.ItemEquipper,
	selectionHandler: SelectionHandler.SelectionHandler,
	maid: Maid.Maid,
}
export type ServerRuntime = typeof(setmetatable({} :: self, ServerRuntime))

function ServerRuntime.new(args: {
	itemProviders: { [string]: Types.ClassItemProvider },
	classConfigs: { [string]: Types.ClassConfig },
	configByFactionId: { [string]: Types.FactionConfig },
	shouldSync: boolean,
})
	local state = State.new()

	local self = setmetatable({
		state = state,
		configByFactionId = args.configByFactionId,
		itemEquipper = ItemEquipper.new(args.itemProviders, args.classConfigs),
		selectionHandler = SelectionHandler.new(state, args.classConfigs),
		maid = Maid.new(),
	} :: self, ServerRuntime)

	for _, factionConfig in pairs(self.configByFactionId) do
		StateActions.CreateFaction(self.state, factionConfig)
	end

	if args.shouldSync then
		self.maid:GiveTask(ServerSyncer.new({
			configByFactionId = state.configByFactionId,
			playerByFactionId = state.playerByFactionId,
			playerByClassKey = state.playerByClassKey,
			playerByClassId = state.playerByClassId,
			classCountByFaction = state.classCountByFaction,
		}, Events))
	end

	return self
end

-- wires up everything. don't call for tests

function ServerRuntime.Start(self: ServerRuntime)
	Players.PlayerAdded:Connect(function(player)
		self.selectionHandler:HandleTeamChange(player, player.Team)

		player:GetPropertyChangedSignal("Team"):Connect(function()
			self.selectionHandler:HandleTeamChange(player, player.Team)
		end)

		player.CharacterAdded:Connect(function(character)
			local classId = self.state.playerByClassId()[player.UserId]

			if not classId then
				return
			end

			self.itemEquipper:AssignClassItems(player, classId)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		StateActions.RemovePlayerFaction(self.state, player.UserId)
	end)

	Events.packets.RequestFaction.listen(function(data, player)
		self.selectionHandler:HandleFactionRequest(player, data)
	end)

	Events.packets.RequestClass.listen(function(data, player)
		self.selectionHandler:HandleClassRequest(player, data, self.itemEquipper)
	end)
	
	Events.packets.RequestClassApply.listen(function(data, player)
		self.selectionHandler:HandleClassApplyRequest(player, data, self.itemEquipper)
	end)
end


function ServerRuntime.Destroy(self: ServerRuntime)
	self.maid:DoCleaning()
end

return ServerRuntime
