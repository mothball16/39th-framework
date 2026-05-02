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
type FactionClassConfig = {
	ClassIDs: {string},
	Limit: number,
	Default: boolean,
}

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

local function getDefaultClassSelection(factionConfig: Types.FactionConfig): (string?, string?)
	for classKey, classConfig: FactionClassConfig in pairs(factionConfig.Classes) do
		if classConfig.Default then
			local classId = classConfig.ClassIDs[1]
			if not classId then
				warn(`default class role {classKey} has no variants for faction {factionConfig.ID}`)
				return nil, nil
			end
			return classKey, classId
		end
	end
	return nil, nil
end

-- init
local state = State.new()
ServerSyncer.new({
	factionConfigs = state.factionConfigs,
	playerFactionIds = state.playerFactionIds,
	playerClassKeys = state.playerClassKeys,
	playerClassIds = state.playerClassIds,
	classCountsByFaction = state.classCountsByFaction,
}, Events)

local itemProviders = getItemProviders(Access.Framework.ItemProviders)
local classConfigs = getClassConfigs(Access.Assets.ClassConfigs)
local factionConfigs = getFactionConfigs(Access.Assets.FactionConfigs)
local classEquipper = ClassEquipper.new(itemProviders, classConfigs)
local currentClassByUserId: {[number]: string} = {}
local currentClassKeyByUserId: {[number]: string} = {}

local function getFactionClassConfigByClassKey(factionConfig: Types.FactionConfig, classKey: string): FactionClassConfig?
	return factionConfig.Classes[classKey]
end

local function roleIncludesClassId(classConfig: FactionClassConfig, classId: string): boolean
	for _, configuredClassId in ipairs(classConfig.ClassIDs) do
		if configuredClassId == classId then
			return true
		end
	end
	return false
end

local function getClassOccupancyCount(factionId: string, classKey: string): number
	return state:GetClassOccupancyCount(factionId, classKey)
end

local function resolvePlayerFactionAndClass(player: Player): (Types.FactionConfig?, string?, string?)
	local factionConfig = getFactionForPlayer(player, factionConfigs)
	if not factionConfig then
		warn("no faction configs available")
		return nil, nil, nil
	end

	local classKey, classId = getDefaultClassSelection(factionConfig)
	if not classKey then
		warn(`no default class role configured for faction {factionConfig.ID}`)
		return factionConfig, nil, nil
	end
	if not classId then
		warn(`no default class variant configured for role {classKey} in faction {factionConfig.ID}`)
		return factionConfig, classKey, nil
	end
	return factionConfig, classKey, classId
end

local function syncPlayerFactionState(player: Player, factionConfig: Types.FactionConfig?, classKey: string?, classId: string?)
	if factionConfig and classKey and classId then
		state:SetPlayerClass(player.UserId, factionConfig.ID, classKey, classId)
		return
	end
	state:SetPlayerClass(player.UserId, nil, nil, nil)
end

local function assignDefaultClass(player: Player, forceAssign: boolean?)
	local factionConfig, classKey, classId = resolvePlayerFactionAndClass(player)
	syncPlayerFactionState(player, factionConfig, classKey, classId)

	local previousClassId = currentClassByUserId[player.UserId]
	if previousClassId and previousClassId ~= classId then
		classEquipper:UnassignClassItems(player, previousClassId)
	end

	if not classId then
		currentClassByUserId[player.UserId] = nil
		currentClassKeyByUserId[player.UserId] = nil
		return
	end

	if not forceAssign and previousClassId == classId then
		currentClassKeyByUserId[player.UserId] = classKey
		return
	end

	classEquipper:AssignClassItems(player, classId)
	currentClassByUserId[player.UserId] = classId
	currentClassKeyByUserId[player.UserId] = classKey
end

Events.RequestClass.OnServerEvent:Connect(function(player: Player, request: any)
	if typeof(request) ~= "table" then
		warn(`invalid class request type from {player.Name}`)
		return
	end
	local classKey = request.classKey
	local classId = request.classId
	if typeof(classKey) ~= "string" or typeof(classId) ~= "string" then
		warn(`invalid class request payload from {player.Name}`)
		return
	end

	local factionConfig = getFactionForPlayer(player, factionConfigs)
	if not factionConfig then
		warn(`faction not found for player {player.Name}`)
		return
	end

	local classConfig = getFactionClassConfigByClassKey(factionConfig, classKey)
	if not classConfig then
		warn(`class role {classKey} is not available for faction {factionConfig.ID}`)
		return
	end

	if not roleIncludesClassId(classConfig, classId) then
		warn(`class {classId} is not part of role {classKey} for faction {factionConfig.ID}`)
		return
	end

	if not classConfigs[classId] then
		warn(`class config not found for class {classId}`)
		return
	end

	local previousClassId = currentClassByUserId[player.UserId]
	local previousClassKey = currentClassKeyByUserId[player.UserId]
	if previousClassId == classId and previousClassKey == classKey then
		state:SetPlayerClass(player.UserId, factionConfig.ID, classKey, classId)
		return
	end

	local occupancy = getClassOccupancyCount(factionConfig.ID, classKey)
	if previousClassKey == classKey and occupancy > 0 then
		occupancy -= 1
	end
	if classConfig.Limit > 0 and occupancy >= classConfig.Limit then
		warn(`class role {classKey} is full for faction {factionConfig.ID}`)
		return
	end

	if previousClassId then
		classEquipper:UnassignClassItems(player, previousClassId)
	end
	classEquipper:AssignClassItems(player, classId)
	currentClassByUserId[player.UserId] = classId
	currentClassKeyByUserId[player.UserId] = classKey
	state:SetPlayerClass(player.UserId, factionConfig.ID, classKey, classId)
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
	state:SetPlayerClass(player.UserId, nil, nil, nil)
	currentClassByUserId[player.UserId] = nil
	currentClassKeyByUserId[player.UserId] = nil
end)
