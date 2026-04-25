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
        local itemProvider = require(itemProviderModule) :: Types.IClassItemProvider
        itemProviders[itemProvider.ID] = itemProvider
    end
    return itemProviders
end

local function getFactionConfigs(path)
    local factions = {}
    for _, factionModule in ipairs(path:GetChildren()) do
        warn("Loading faction config: " .. factionModule.Name)
        local faction = require(factionModule) :: Types.IFactionConfig
        factions[faction.ID] = faction
    end
    return factions
end

local function getClassConfigs(path)
    local classes = {}
    for _, classModule in ipairs(path:GetChildren()) do
        local class = require(classModule) :: Types.IClass
        classes[class.ID] = class
    end
    return classes
end

local function getFactionForPlayer(player: Player, factionConfigs: {[string]: Types.IFactionConfig}): Types.IFactionConfig?
	local team = player.Team
	local autoFactionAttribute = team:GetAttribute(Enums.Faction.AutoFactionAttribute)
    if autoFactionAttribute then
        return factionConfigs[autoFactionAttribute]
    end
	return nil
end

local function getDefaultClassId(factionConfig: Types.IFactionConfig): string?
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
	Factions = state.Factions,
}, Events)

local itemProviders = getItemProviders(Access.Framework.ItemProviders)
local classConfigs = getClassConfigs(Access.Assets.ClassConfigs)
local factionConfigs = getFactionConfigs(Access.Assets.FactionConfigs)
local classEquipper = ClassEquipper.new(itemProviders, classConfigs)

local function resolvePlayerFactionAndClass(player: Player): (Types.IFactionConfig?, string?)
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

local function syncPlayerFactionState(player: Player, factionConfig: Types.IFactionConfig?, classId: string?)
	state:RemoveFactionMemberFromAll(player.UserId)
	if factionConfig and classId then
		state:SetFactionMemberClass(factionConfig.ID, player.UserId, classId)
	end
end

local function assignDefaultClass(player: Player)
	local factionConfig, classId = resolvePlayerFactionAndClass(player)
	syncPlayerFactionState(player, factionConfig, classId)
	if not classId then
		return
	end
	classEquipper:AssignClassItems(player, classId)
end

for _, factionConfig in pairs(factionConfigs) do
    state:CreateFaction(factionConfig)
end

local function hookPlayer(player: Player)
	local function refreshStateOnly()
		local factionConfig, classId = resolvePlayerFactionAndClass(player)
		syncPlayerFactionState(player, factionConfig, classId)
	end

	player.CharacterAdded:Connect(function()
		assignDefaultClass(player)
	end)
	player:GetPropertyChangedSignal("Team"):Connect(refreshStateOnly)

	refreshStateOnly()
	if player.Character then
		task.defer(assignDefaultClass, player)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(function(player)
	state:RemoveFactionMemberFromAll(player.UserId)
end)
