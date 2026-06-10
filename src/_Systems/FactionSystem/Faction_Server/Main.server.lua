local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Access = require("@game/ReplicatedStorage/Faction_Framework/Access")
local Types = require("@game/ReplicatedStorage/Faction_Framework/Core/Types")

local RuntimeLocator = require("./RuntimeLocator")
local ServerRuntime = require("./ServerRuntime")
local SetupStateSync = require("./SetupStateSync")

if Access.Config.DebugMode and game:GetService("RunService"):IsStudio() then
	local startTick = tick()

	local DevPackages = ReplicatedStorage:WaitForChild("DevPackages")
	local TestEZ = require(DevPackages:WaitForChild("TestEZ"))

	TestEZ.TestBootstrap:run({ ReplicatedStorage.Faction_Framework.Tests }, TestEZ.Reporters.TextReporterQuiet)

	warn(`class system test suite took {tick() - startTick} seconds`)
end

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

-- initialize the runtime
local runtime = ServerRuntime.new({access = Access})
RuntimeLocator.LoadRuntime(runtime)
runtime:Start()


-- register stuff
local itemProviders = getItemProviders(ReplicatedStorage.Faction_Framework.ItemProviders)
for _, itemProvider in pairs(itemProviders) do
	runtime:RegisterItemProvider(itemProvider)
end

local classConfigs = getClassConfigs(Access.Assets.ClassConfigs)
for _, classConfig in pairs(classConfigs) do
	runtime:RegisterClass(classConfig)
end

local factionConfigs = getFactionConfigs(Access.Assets.FactionConfigs)
for _, factionConfig in pairs(factionConfigs) do
	runtime:RegisterFaction(factionConfig)
end

-- connect the server syncer
SetupStateSync(runtime)