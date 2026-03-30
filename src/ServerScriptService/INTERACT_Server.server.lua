--[[       
INTERACTIVE SYSTEM
Server Script
1.4.3

by Jarr (@SrJarr) aka jarr__
RELEASED FOR FREE - DRAGOON'S DEN
--]]

--// Services
local players = game:GetService("Players")
local debris = game:GetService("Debris")
local collection = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")

--// Folders
local assets = replicatedStorage.INTERACT_Assets
local modules = assets.Modules
local config = require(assets.GlobalSettings)

local dtsInstall = replicatedStorage:FindFirstChild("DTS_Assets") --Dragoon tank system compat
local dtsSetup 
if dtsInstall then 
	dtsSetup = require(dtsInstall.Modules.VehicleSetup)
end

--// Functions
local function disconnect(disconnects)
	for _, evt in disconnects do evt:Disconnect() end
end

local function RunTags(mod, tags)
	for tag, func in tags do
		for _, object in collection:GetTagged(tag) do
			if object:HasTag("INTERACT_LOADED") then return end

			local success, errorMessage = pcall(mod[func], object)  -- Results in error...
			if not success then
				warn("INTERACT_Server: Tag Error, ", errorMessage)
			end
		end
	end
end

local function LoadOneMod(module)
	local mod = require(module)
	
	--First, initialize the modules
	if mod.Initialize and mod.InitializeWithCoroutine and not module:HasTag("INTERACT_LOADED") then
		module:AddTag("INTERACT_LOADED")
		coroutine.wrap(mod.Initialize)()
	elseif mod.Initialize and not module:HasTag("INTERACT_LOADED")  then
		module:AddTag("INTERACT_LOADED")
		mod.Initialize()
	end

	--Then, run the tag functions
	if mod.RunTags and mod.RunWithCoroutine then
		coroutine.wrap(function()
			RunTags(mod, mod.RunTags)
		end)()
	elseif mod.RunTags then
		RunTags(mod, mod.RunTags)
	end
end

local function LoadAllMods()
	for _, module in ipairs(modules:GetChildren()) do
		local success, errorMessage = pcall(LoadOneMod, module)  -- Results in error...
		if not success then
			warn("INTERACT_Server: Loading Error, ", errorMessage)
		end
	end
end

--// Connections
warn(config.prefix.." Loading Server "..config.version)
LoadAllMods()
assets.Events.RedoTags.Event:Connect(LoadAllMods)
warn(config.prefix.." Main server loaded successfully!")
