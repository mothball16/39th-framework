--[[       
INTERACTIVE SYSTEM
Buildables
1.4.3

by Jarr (@SrJarr) aka jarr__
RELEASED FOR FREE - DRAGOON'S DEN
--]]

--// Services
local players = game:GetService("Players")
local tweens = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local textserv = game:GetService("TextService")
local mod = {}

mod.InitializeWithCoroutine = false 
mod.RunWithCoroutine = false
mod.RunTags = nil

--// Folders
local workspaceFolder = game.Workspace.INTERACT_Workspace
local assets = replicatedStorage.INTERACT_Assets
local modules = assets.Modules

local dtsSetup = replicatedStorage:FindFirstChild("DTS_Assets") and require(replicatedStorage.DTS_Assets.Modules.VehicleSetup)
local okamiSetup = require(modules.OkamiDD)
local miscMod = require(modules.Misc)

local toolStorage = assets.ToolStorage
local finishedProps = assets.Props.Finished
local buildingProps = assets.Props.Buildable

--// Functions
local function SetupProp(prop:Model, position:CFrame)
	if prop:HasTag("Okami_Chassis") then
		prop:PivotTo(position)
		okamiSetup.SetupCar(prop)
	elseif prop:HasTag("Okami_Trailer") then
		okamiSetup.initializeTrailer(prop)
	elseif dtsSetup and not prop:HasTag("Okami_Chassis") and prop:HasTag("Dragoon_Vehicle") then
		dtsSetup.LoadVic(prop)
	elseif miscMod and prop:HasTag("ToolGiver") then
		miscMod.SetupGiver(prop)
	end
end

function mod.Initialize()
	--// Setup events
	assets.Events.Prop.OnServerEvent:Connect(function(plr, func, ...)
		if not plr or not func then return end

		if func=="Place" then
			mod.PlaceProp(plr, ...)
		elseif func=="Build" then
			mod.BuildProp(plr, ...)
		elseif func=="Remove" then
			mod.RemoveProp(plr, ...)
		end
	end)
end

function mod.PlaceProp(player:Player, cframe:CFrame, object:string, tool:Tool)
	if not player or not cframe or not object then return end

	local prop = buildingProps:FindFirstChild(object)
	if not prop then return end

	if tool then tool:Destroy() end

	local newProp = prop:Clone()
	newProp:PivotTo(cframe)
	newProp:AddTag("BuildableProps_Incomplete")
	newProp.Parent = workspaceFolder.Props
	SetupProp(newProp, cframe)
end

function mod.BuildProp(player:Player, object:Model)
	if not player or not object then return end

	local cfg = object:FindFirstChild("BuildableProp_Config")
	local step = cfg:FindFirstChild("BuildSteps")
	local cost = cfg:FindFirstChild("MaterialPerStep")

	if step.Value == 1 then
		step.Value = 0
		local prop = finishedProps:FindFirstChild(object.Name)
		if not prop then return end

		object:Destroy()
		local newProp = prop:Clone()
		newProp:PivotTo(object.WorldPivot)
		newProp:AddTag("BuildableProps_Finished")
		newProp.Parent = workspaceFolder.Props
		SetupProp(newProp, object.WorldPivot)
	elseif step.Value > 1 then
		step.Value -= 1

		if cost.Value > 0 then

		end
	end
end

function mod.RemoveProp(player:Player, object:Model, toolString:string)
	if not player or not object then return end

	local cfg = object:FindFirstChild("BuildableProp_Config")
	local canRemove = cfg:FindFirstChild("CanReturn")

	if canRemove and canRemove.Value==true then
		object:Destroy()

		if toolString and toolString~=nil then
			local tool = toolStorage:FindFirstChild(toolString)
			if not tool then return end

			local newTool = tool:Clone()
			newTool.Parent = player.Backpack
		end
	end
end

return mod
