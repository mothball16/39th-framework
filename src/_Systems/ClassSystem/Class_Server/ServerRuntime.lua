local Players = game:GetService("Players")

local Maid = require("@game/ReplicatedStorage/Packages/maid")

local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")
local Events = require("@game/ReplicatedStorage/Class_Framework/Core/Events").GetNamespace()
local Enums = require("@game/ReplicatedStorage/Class_Framework/Core/Enums")
local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")
local StateActions = require("@game/ReplicatedStorage/Class_Framework/StateActions")

local ItemEquipper = require("./ItemEquipper")
local SelectionService = require("./SelectionService")
local ServerSyncer = require("./ServerSyncer")

local ServerRuntime = {}
ServerRuntime.__index = ServerRuntime

type self = {
	state: State.State,
	configByFactionId: { [string]: Types.FactionConfig },
	itemEquipper: ItemEquipper.ItemEquipper,
	selectionService: SelectionService.SelectionService,
	maid: Maid.Maid,
}
export type ServerRuntime = typeof(setmetatable({} :: self, ServerRuntime))

function ServerRuntime.new(args: {
	itemProviders: { [string]: Types.ClassItemProvider },
	configByClassId: { [string]: Types.Class },
	configByFactionId: { [string]: Types.FactionConfig },
	access: Types.Access,
	shouldSync: boolean,
})
	local state = State.new()

	local self = setmetatable({
		access = args.access,
		state = state,
		configByFactionId = args.configByFactionId,
		itemEquipper = ItemEquipper.new(args.itemProviders, args.configByClassId),
		selectionService = SelectionService.new(state, args.access.Config),
		maid = Maid.new(),
	} :: self, ServerRuntime)

	for _, factionConfig in pairs(self.configByFactionId) do
		StateActions.CreateFaction(self.state, factionConfig)
	end

	if args.shouldSync then
		self.maid:GiveTask(ServerSyncer.new({
			configByFactionId = state.configByFactionId,
			playerByFactionId = state.playerByFactionId,
			playerByGroupKey = state.playerByGroupKey,
			playerByClassId = state.playerByClassId,
			groupCountByFaction = state.groupCountByFaction,
		}, Events))
	end

	return self
end

-- wires up everything. don't call for tests

function ServerRuntime.Start(self: ServerRuntime)
	Players.PlayerAdded:Connect(function(player)
		local function safeAssignClassItems(player: Player)
			local classId = self.state.playerByClassId()[player.UserId]
			if not classId then
				return
			end

			self.itemEquipper:AssignClassItems(player, classId)
		end

		local function shouldAutoAssignAfterTeamChange(): boolean
			return self.access.Config.AfterTeamChangeBehavior ~= Enums.AfterTeamChangeBehavior.None
		end

		local function handleTeamChange(player: Player)
			self.selectionService:HandleTeamChange(player, player.Team, self.itemEquipper)
			if shouldAutoAssignAfterTeamChange() then
				safeAssignClassItems(player)
			end
		end

		handleTeamChange(player)

		player:GetPropertyChangedSignal("Team"):Connect(function()
			handleTeamChange(player)
		end)

		player.CharacterAdded:Connect(function(character)
			safeAssignClassItems(player)
		end)
		-- if the player has a character, assign the class items immediately
		if player.Character then
			safeAssignClassItems(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		StateActions.RemovePlayerFaction(self.state, player.UserId)
	end)

	Events.packets.RequestFaction.listen(function(data, player)
		self.selectionService:HandleFactionRequest(player, data)
	end)

	Events.packets.RequestGroupClass.listen(function(data, player)
		self.selectionService:HandleGroupClassRequest(player, data, self.itemEquipper)
	end)
	
	Events.packets.RequestClassApply.listen(function(data, player)
		self.selectionService:HandleClassApplyRequest(player, data, self.itemEquipper)
	end)
end


function ServerRuntime.Destroy(self: ServerRuntime)
	self.maid:DoCleaning()
end

return ServerRuntime
