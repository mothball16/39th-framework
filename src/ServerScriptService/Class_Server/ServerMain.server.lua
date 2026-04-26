local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local State = require(Access.Framework.Core:WaitForChild("State"))
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))
local ClassEquipper = require(Access.Framework:WaitForChild("ClassEquipper"))
local ServerSyncer = require(script.Parent.ServerSyncer)
local Enums = require(Access.Framework.Core:WaitForChild("Enums"))
-------------------------------------------------------------------------
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

local function getFactionForPlayer(player: Player, factionConfigs: {[string]: Types.FactionConfig}): Types.FactionConfig?
	local team = player.Team
	if not team then
		return nil
	end
	local autoFactionAttribute = team:GetAttribute(Enums.Faction.AutoFactionAttribute)
    if autoFactionAttribute then
        return factionConfigs[autoFactionAttribute]
    end
	return nil
end

local function getDefaultClassId(factionConfig: Types.FactionConfig): string?
	local fallbackClassId = nil
	for _, classConfig in pairs(factionConfig.Classes) do
		fallbackClassId = fallbackClassId or classConfig.ClassID
		if classConfig.Default then
			return classConfig.ClassID
		end
	end
	return fallbackClassId
end

-- init
local state = State.new()
ServerSyncer.new({
	FactionConfigs = state.FactionConfigs,
	PlayerAssignments = state.PlayerAssignments,
}, Events)

local itemProviders = getItemProviders(Access.Framework.ItemProviders)
local classConfigs = getClassConfigs(Access.Assets.ClassConfigs)
local factionConfigs = getFactionConfigs(Access.Assets.FactionConfigs)
local classEquipper = ClassEquipper.new(itemProviders, classConfigs)
local currentClassByUserId: {[number]: string} = {}

local function getFactionClassConfigByClassId(factionConfig: Types.FactionConfig, classId: string): {ClassID: string, Limit: number, Default: boolean}?
	for _, factionClassConfig in pairs(factionConfig.Classes) do
		if factionClassConfig.ClassID == classId then
			return factionClassConfig
		end
	end
	return nil
end

local function getClassOccupancyCount(factionId: string, classId: string): number
	return state:GetClassOccupancyCount(factionId, classId)
end

local function resolvePlayerFactionAndClass(player: Player): (Types.FactionConfig?, string?)
	local factionConfig = getFactionForPlayer(player, factionConfigs)
	if not factionConfig then
		warn("no faction configs available")
		return nil, nil
	end

	local classId = getDefaultClassId(factionConfig)
	if not classId then
		warn(`no class configured for faction {factionConfig.ID}`)
		return factionConfig, nil
	end
	return factionConfig, classId
end

local function syncPlayerFactionState(player: Player, factionConfig: Types.FactionConfig?, classId: string?)
	if factionConfig and classId then
		state:SetPlayerClass(player.UserId, factionConfig.ID, classId)
		return
	end
	state:SetPlayerClass(player.UserId, nil, nil)
end

local function assignDefaultClass(player: Player, forceAssign: boolean?)
	local factionConfig, classId = resolvePlayerFactionAndClass(player)
	syncPlayerFactionState(player, factionConfig, classId)

	local previousClassId = currentClassByUserId[player.UserId]
	if previousClassId and previousClassId ~= classId then
		classEquipper:UnassignClassItems(player, previousClassId)
	end

	if not classId then
		currentClassByUserId[player.UserId] = nil
		return
	end

	if not forceAssign and previousClassId == classId then
		return
	end

	classEquipper:AssignClassItems(player, classId)
	currentClassByUserId[player.UserId] = classId
end

Events.RequestClass.OnServerEvent:Connect(function(player: Player, requestedClassId: any)
	if typeof(requestedClassId) ~= "string" then
		warn(`invalid class request type from {player.Name}`)
		return
	end

	local factionConfig = getFactionForPlayer(player, factionConfigs)
	if not factionConfig then
		warn(`faction not found for player {player.Name}`)
		return
	end

	local classConfig = getFactionClassConfigByClassId(factionConfig, requestedClassId)
	if not classConfig then
		warn(`class {requestedClassId} is not available for faction {factionConfig.ID}`)
		return
	end

	if not classConfigs[requestedClassId] then
		warn(`class config not found for class {requestedClassId}`)
		return
	end

	local previousClassId = currentClassByUserId[player.UserId]
	if previousClassId == requestedClassId then
		state:SetPlayerClass(player.UserId, factionConfig.ID, requestedClassId)
		return
	end

	local occupancy = getClassOccupancyCount(factionConfig.ID, requestedClassId)
	if classConfig.Limit > 0 and occupancy >= classConfig.Limit then
		warn(`class {requestedClassId} is full for faction {factionConfig.ID}`)
		return
	end

	if previousClassId then
		classEquipper:UnassignClassItems(player, previousClassId)
	end
	classEquipper:AssignClassItems(player, requestedClassId)
	currentClassByUserId[player.UserId] = requestedClassId
	state:SetPlayerClass(player.UserId, factionConfig.ID, requestedClassId)
end)

for _, factionConfig in pairs(factionConfigs) do
    state:CreateFaction(factionConfig)
end

local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		assignDefaultClass(player, true)
	end)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		assignDefaultClass(player, false)
	end)

	assignDefaultClass(player, false)
	if player.Character then
		task.defer(assignDefaultClass, player, true)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(player)
	state:SetPlayerClass(player.UserId, nil, nil)
	currentClassByUserId[player.UserId] = nil
end)
