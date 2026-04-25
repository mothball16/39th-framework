local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local State = require(Access.Framework.Core:WaitForChild("State"))
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))
local ClassEquipper = require(Access.Framework:WaitForChild("ClassEquipper"))
local ServerSyncer = require(script.Parent.ServerSyncer)

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
	if team then
		local teamFaction = factionConfigs[team.Name]
		if teamFaction then
			return teamFaction
		end
	end

	for _, factionConfig in pairs(factionConfigs) do
		return factionConfig
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

local function assignDefaultClass(player: Player)
	local factionConfig = getFactionForPlayer(player, factionConfigs)
	if not factionConfig then
		warn("no faction configs available")
		return
	end

	local classId = getDefaultClassId(factionConfig)
	if not classId then
		warn(`no class configured for faction {factionConfig.ID}`)
		return
	end

	classEquipper:AssignClassItems(player, classId)
end

for _, factionConfig in pairs(factionConfigs) do
    state:CreateFaction(factionConfig)
end

local function hookPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		assignDefaultClass(player)
	end)

	if player.Character then
		task.defer(assignDefaultClass, player)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end
Players.PlayerAdded:Connect(hookPlayer)
