--!strict
local Players = game:GetService("Players")

local Maid = require("@game/ReplicatedStorage/Packages/maid")

local State = require("@game/ReplicatedStorage/Faction_Framework/Core/State")
local Events = require("@game/ReplicatedStorage/Faction_Framework/Core/Events").GetNamespace()
local Enums = require("@game/ReplicatedStorage/Faction_Framework/Core/Enums")
local Types = require("@game/ReplicatedStorage/Faction_Framework/Core/Types")
local StateActions = require("@game/ReplicatedStorage/Faction_Framework/Logic/StateActions")
local Utilities = require("@game/ReplicatedStorage/Faction_Framework/Logic/Utilities")
local ItemEquipper = require("./ItemEquipper")
local SelectionService = require("./SelectionService")

local ServerRuntime = {}
ServerRuntime.__index = ServerRuntime

type self = {
	state: State.State,
	access: Types.Access,
	report: typeof(Utilities.Report),

	itemEquipper: ItemEquipper.ItemEquipper,
	selectionService: SelectionService.SelectionService,
	maid: Maid.Maid,

	_configByFactionId: { [string]: Types.FactionConfig },
	_configByClassId: { [string]: Types.Class },
	_itemProviders: { [string]: Types.ClassItemProvider },
}
export type ServerRuntime = typeof(setmetatable({} :: self, ServerRuntime))

function ServerRuntime.new(args: {
	access: Types.Access
})
	local self = setmetatable({
		access = args.access,
		report = args.access.Config.DebugMode and Utilities.Report or function() end,

		state = State.new(),
		maid = Maid.new(),

		_itemProviders = {},
		_configByClassId = {},
		_configByFactionId = {},
	} :: self, ServerRuntime)

	self.itemEquipper = ItemEquipper.new(self._itemProviders, self._configByClassId)
	self.selectionService = SelectionService.new(self.state, args.access.Config)

	return self
end

function ServerRuntime.RegisterFaction(self: ServerRuntime, factionConfig: Types.FactionConfig)
	assert(factionConfig.ID, "faction must have an ID")

	if self._configByFactionId[factionConfig.ID] then
		warn(`replacing existing faction for ID {factionConfig.ID}`)
	end

	self._configByFactionId[factionConfig.ID] = factionConfig
	self.report(StateActions.CreateFaction(self.state, factionConfig))
end

function ServerRuntime.UnregisterFaction(self: ServerRuntime, factionId: string)
	self.report(StateActions.RemoveFaction(self.state, factionId))
end

function ServerRuntime.RegisterClass(self: ServerRuntime, classConfig: Types.Class)
	assert(classConfig.ID, "class must have an ID")

	if self._configByClassId[classConfig.ID] then
		warn(`replacing existing class for ID {classConfig.ID}`)
	end

	self._configByClassId[classConfig.ID] = classConfig
end

function ServerRuntime.UnregisterClass(self: ServerRuntime, classId: string)
	self._configByClassId[classId] = nil
end

function ServerRuntime.RegisterItemProvider(self: ServerRuntime, provider: Types.ClassItemProvider)
	assert(provider.ID, "item provider must have an ID")

	if self._itemProviders[provider.ID] then
		warn(`replacing existing item provider for type {provider.ID}`)
	end

	self._itemProviders[provider.ID] = provider
end

function ServerRuntime.UnregisterItemProvider(self: ServerRuntime, providerId: string)
	self._itemProviders[providerId] = nil
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
			self.report(self.selectionService:HandleTeamChange(player, player.Team, self.itemEquipper))
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
		self.report(StateActions.RemovePlayerFaction(self.state, player.UserId))
	end)

	Events.packets.RequestFaction.listen(function(data, player)
		if not player then return end
		self.report(self.selectionService:HandleFactionRequest(player, data))
	end)

	Events.packets.RequestGroupClass.listen(function(data, player)
		if not player then return end
		self.report(self.selectionService:HandleGroupClassRequest(player, data, self.itemEquipper))
	end)
	
	Events.packets.RequestClassApply.listen(function(data, player)
		if not player then return end
		self.report(self.selectionService:HandleClassApplyRequest(player, data, self.itemEquipper))
	end)
end


function ServerRuntime.Destroy(self: ServerRuntime)
	self.maid:DoCleaning()
end

return ServerRuntime
