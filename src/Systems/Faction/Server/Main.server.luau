require("@game/ReplicatedStorage/Packages/Charm").flags.frozen = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Access = require("@game/ReplicatedStorage/Systems/Faction/Access")
local Types = require("@game/ReplicatedStorage/Systems/Faction/Core/Types")

local ServerRuntimeLocator = require("./ServerRuntimeLocator")
local ServerRuntime = require("./ServerRuntime")
local ServerStateSync = require("./ServerStateSync")

if Access.Config.DebugMode and game:GetService("RunService"):IsStudio() then
	local startTick = tick()

	local DevPackages = ReplicatedStorage:WaitForChild("DevPackages")
	local TestEZ = require(DevPackages:WaitForChild("TestEZ"))

	TestEZ.TestBootstrap:run({ ReplicatedStorage.Systems.Faction.Tests }, TestEZ.Reporters.TextReporterQuiet)

	warn(`faction system test suite took {tick() - startTick} seconds`)
end

--#region [ helpers ]
local function getItemProviders(path)
	local itemProviders = {}
	for _, itemProviderModule in ipairs(path:GetChildren()) do
		local itemProvider = require(itemProviderModule) :: Types.VariantItemProvider
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

local function getVariantConfigs(path)
	local variants = {}
	for _, variantModule in ipairs(path:GetChildren()) do
		local variant = require(variantModule) :: Types.Variant
		variants[variant.ID] = variant
	end
	return variants
end
--#endregion [ helpers ]

-- initialize the runtime
local runtime = ServerRuntime.new({access = Access})
ServerRuntimeLocator.LoadRuntime(runtime)
runtime:Start()


-- register stuff
local itemProviders = getItemProviders(ReplicatedStorage.Systems.Faction.ItemProviders)
for _, itemProvider in pairs(itemProviders) do
	runtime:RegisterItemProvider(itemProvider)
end

local variantConfigs = getVariantConfigs(Access.Assets.VariantConfigs)
for _, variantConfig in pairs(variantConfigs) do
	runtime:RegisterVariant(variantConfig)
end

local factionConfigs = getFactionConfigs(Access.Assets.FactionConfigs)
for _, factionConfig in pairs(factionConfigs) do
	runtime:RegisterFaction(factionConfig)
end

ServerStateSync(runtime.state)
