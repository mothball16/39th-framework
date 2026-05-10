local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utility = ReplicatedStorage:WaitForChild("Utility")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework.Core.Types)
local ServerRuntime = require(script.Parent.ServerRuntime)

if Access.Config.DebugMode then
	require(Utility.TestRunner)(Access.Framework:WaitForChild("Tests"))
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
	itemProviders = getItemProviders(Access.Framework.ItemProviders),
	classConfigs = getClassConfigs(Access.Assets.ClassConfigs),
	factionConfigs = getFactionConfigs(Access.Assets.FactionConfigs),
	shouldSync = true,
})
runtime:Start()
