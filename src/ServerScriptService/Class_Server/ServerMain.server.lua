local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage:WaitForChild("Utility")
local Players = game:GetService("Players")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local State = require(Access.Framework.Core:WaitForChild("State"))
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))
local Enums = require(Access.Framework.Core:WaitForChild("Enums"))

local ClassEquipper = require(script.Parent.ClassEquipper)
local ClassSelectionService = require(script.Parent.ClassSelectionService)
local ServerSyncer = require(script.Parent.ServerSyncer)
local StateActions = require(script.Parent.StateActions)

require(Utility.TestRunner)(Access.Framework:WaitForChild("Tests"))
-------------------------------------------------------------------------
--#region [ helpers ]
local function getItemProviders(path)
    local itemProviders = {}
    for _, itemProviderModule in ipairs(path:GetChildren()) do
        local itemProvider = require(itemProviderModule) :: Types.ClassItemProvider
        itemProviders[itemProvider.ID] = itemProvider
    end
    return itemProviders
end

local function getFactionConfigs(path)
    local factions = {}
    for _, factionModule in ipairs(path:GetChildren()) do
        warn("Loading faction config: " .. factionModule.Name)
        local faction = require(factionModule) :: Types.FactionConfig
        factions[faction.ID] = faction
    end
    return factions
end

local function getClassConfigs(path)
    local classes = {}
    for _, classModule in ipairs(path:GetChildren()) do
        local class = require(classModule) :: Types.Class
        classes[class.ID] = class
    end
    return classes
end
--#endregion [ helpers ]

-- init
local itemProviders = getItemProviders(Access.Framework.ItemProviders)
local classConfigs = getClassConfigs(Access.Assets.ClassConfigs)
local factionConfigs = getFactionConfigs(Access.Assets.FactionConfigs)

local state = State.new()
local classEquipper = ClassEquipper.new(itemProviders, classConfigs)
local classSelectionService = ClassSelectionService.new(state, classConfigs)
local serverSyncer = ServerSyncer.new({
	factionConfigs = state.factionConfigs,
	playerFactionIds = state.playerFactionIds,
	playerClassKeys = state.playerClassKeys,
	playerClassIds = state.playerClassIds,
	classCountsByFaction = state.classCountsByFaction,
}, Events)

for _, factionConfig in pairs(factionConfigs) do
    StateActions.CreateFaction(state, factionConfig)
end

-- wire up players
Players.PlayerAdded:Connect(function(player)
    classSelectionService:HandleTeamChange(player, player.Team)

    player:GetPropertyChangedSignal("Team"):Connect(function()
        classSelectionService:HandleTeamChange(player, player.Team)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    StateActions.CleanupPlayer(state, player.UserId)
end)

-- wire up events
Events.RequestFaction.OnServerEvent:Connect(
    function(player: Player, request: {factionId: string})
    classSelectionService:HandleFactionRequest(player, request)
end)

Events.RequestClass.OnServerEvent:Connect(
    function(player: Player, request: {classKey: string, classId: string})
    classSelectionService:HandleClassRequest(player, request)
end)
