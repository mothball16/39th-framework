local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Access = require("@game/ReplicatedStorage/Class_Framework/Access")
local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")
local ServerRuntime = require("./ServerRuntime")

if Access.Config.DebugMode then
	if not game:GetService("RunService"):IsStudio() then
        return
    end

    local DevPackages = ReplicatedStorage:WaitForChild("DevPackages")
    local TestEZ = require(DevPackages:WaitForChild("TestEZ"))

    TestEZ.TestBootstrap:run({ ReplicatedStorage.Class_Framework.Tests }, TestEZ.Reporters.TextReporterQuiet)
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

local runtime = ServerRuntime.new({
	access = Access,
	itemProviders = getItemProviders(ReplicatedStorage.Class_Framework.ItemProviders),
	classConfigs = getClassConfigs(Access.Assets.ClassConfigs),
	configByFactionId = getFactionConfigs(Access.Assets.FactionConfigs),
	shouldSync = true,
})
runtime:Start()
