--[[       
INTERACTIVE SYSTEM
Misc Module
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
mod.RunTags = 
	{ --tag, function to run
		["VendingMachine"] = "SetupVendingMachine",
		["ToolGiver"] = "SetupGiver",
		["DrillTarget"] = "SetupTarget"
	}

--// Folders
local assets = replicatedStorage.INTERACT_Assets
local modules = assets.Modules
local uniformMod = (modules:FindFirstChild("Wardrobe") and require(modules.Wardrobe)) --Optional
local config = require(assets.GlobalSettings)

--// Functions

local function getTextObject(message, fromPlayerId)
	local textObject
	local success, errorMessage = pcall(function()
		textObject = textserv:FilterStringAsync(message, fromPlayerId)
	end)
	if success then
		return textObject
	end
	print("Error generating TextFilterResult:", errorMessage)
	return false
end

local function getFilteredMessage(textObject)
	local filteredMessage
	local success, errorMessage = pcall(function()
		filteredMessage = textObject:GetNonChatStringForBroadcastAsync()
	end)
	if success then
		return filteredMessage
	end
	print("Error filtering message:", errorMessage)
	return false
end

local function HideModel(model:Model, value)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name~="Decal" then
			part.Transparency = value
		elseif part:IsA("SurfaceGui") then
			part.Enabled = value==0
		end
	end
end

--// Core Functions
function mod.Initialize()
	--//Whiteboard functionality
	assets.Events.Screenwrite.OnServerEvent:Connect(function(plr:Player, textbox:TextBox, textString:string)
		if not plr or not textbox or not textString then return end

		local textObj = getTextObject(textString, plr.UserId)
		local finalText = getFilteredMessage(textObj)
		textbox.Text = finalText
	end)

	--//Player autoteam
	players.PlayerAdded:Connect(function(plr: Player)
		if config.AutoTeamEnabled then
			for groupName, group in config.Groups do
				local groupID = group["GroupID"]
				local groupRank = group["GroupRank"]
				if not groupID or not groupRank then continue end

				local userRank = plr:GetRankInGroup(groupID)
				if userRank and userRank>=groupRank[1] and userRank<groupRank[2] then
					local teamFind = game.Teams[groupName]
					if not teamFind then continue end
					plr.TeamColor = teamFind.TeamColor
				end
			end
		end

		plr.CharacterAdded:Connect(function()
			if not plr.Team then return end

			if config.AutoTeamTools then
				for _, tool:Tool in plr.Team:GetChildren() do
					if not tool:IsA("Tool") then continue end
					
					local newTool = tool:Clone()
					newTool.Parent = plr.Backpack
				end
			end

			local teamMorph = plr.Team:GetAttribute("startMorph")
			if teamMorph and uniformMod then
				local findMorph = assets.Uniforms[plr.Team.Name][teamMorph]
				if not findMorph then return end

				uniformMod.GiveMorph(plr, findMorph)
			end
		end)
	end)
end

function mod.SetupVendingMachine(rootModel: Model)
	if rootModel:HasTag("INTERACT_LOADED") then return end
	if not rootModel:IsDescendantOf(workspace) then return end

	--/ Initialize
	local Trigger = rootModel:FindFirstChild("Trigger")
	if not Trigger then return end

	local click = Trigger:FindFirstChildWhichIsA("ClickDetector")
	if click then
		click.MouseClick:Connect(function(plr)
			if Trigger:FindFirstChild("USED") then return end
			if not Trigger.Object.Value then return end

			local tag = Instance.new("ObjectValue")
			tag.Name = "USED"
			tag.Parent = Trigger
			tag.Value = plr
			game.Debris:AddItem(tag, rootModel:GetAttribute("useCooldown"))

			Trigger.Dispense:Play()
			wait(2.5)

			local toolFind = assets.ToolStorage:FindFirstChild(Trigger.Object.Value)
			if not toolFind then return end
			local clone = toolFind:Clone()
			clone.Parent = workspace
			clone:PivotTo(Trigger.Drop.WorldCFrame)
		end)
	end
	local prompt = Trigger:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(plr)
			if Trigger:FindFirstChild("USED") then return end
			if not Trigger.Object.Value then return end

			local tag = Instance.new("ObjectValue")
			tag.Name = "USED"
			tag.Parent = Trigger
			tag.Value = plr
			game.Debris:AddItem(tag, rootModel:GetAttribute("useCooldown"))

			Trigger.Dispense:Play()
			wait(2.5)

			local toolFind = assets.ToolStorage:FindFirstChild(Trigger.Object.Value)
			if not toolFind then return end
			local clone = toolFind:Clone()
			clone.Parent = workspace
			clone:PivotTo(Trigger.Drop.WorldCFrame)
		end)
	end

	rootModel:AddTag("INTERACT_LOADED")
end

function mod.SetupGiver(rootModel: Model)
	if rootModel:HasTag("INTERACT_LOADED") then return end
	if not rootModel:IsDescendantOf(workspace) then return end

	--/ Initialize
	local Trigger = rootModel:FindFirstChild("Trigger")
	if not Trigger then return end

	local click = Trigger:FindFirstChildWhichIsA("ClickDetector")
	if click then
		click.MouseClick:Connect(function(plr)
			if Trigger:FindFirstChild("USED") then return end
			local toolFind = assets.ToolStorage:FindFirstChild(rootModel:GetAttribute("toolName"))
			if not toolFind then return end

			Trigger.Use:Play()
			local clone = toolFind:Clone()
			clone.Parent = plr.Backpack

			local tag = Instance.new("ObjectValue")
			tag.Name = "USED"
			tag.Parent = Trigger
			tag.Value = plr
			game.Debris:AddItem(tag, (rootModel:GetAttribute("useCooldown") or 0.5))
		end)
	end
	local prompt = Trigger:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(plr)
			if Trigger:FindFirstChild("USED") then return end
			local toolFind = assets.ToolStorage:FindFirstChild(rootModel:GetAttribute("toolName"))
			if not toolFind then return end

			Trigger.Use:Play()
			local clone = toolFind:Clone()
			clone.Parent = plr.Backpack

			local Open = rootModel:FindFirstChild("Open")
			local Close = rootModel:FindFirstChild("Closed")
			if Open and Close then
				HideModel(Open, 0)
				HideModel(Close, 1)
			end

			local tag = Instance.new("ObjectValue")
			tag.Name = "USED"
			tag.Parent = Trigger
			tag.Value = plr
			game.Debris:AddItem(tag, (rootModel:GetAttribute("useCooldown") or 0.5))

			tag.Destroying:Connect(function()
				local Open = rootModel:FindFirstChild("Open")
				local Close = rootModel:FindFirstChild("Closed")
				if Open and Close then
					HideModel(Open, 1)
					HideModel(Close, 0)
				end
			end)
		end)
	end

	rootModel:AddTag("INTERACT_LOADED")
end


function mod.SetupTarget(rootModel: Model)
	if rootModel:HasTag("INTERACT_LOADED") then return end
	if not rootModel:IsDescendantOf(workspace) then return end

	--/ Initialize
	local Trigger = rootModel:FindFirstChild("Trigger")
	if not Trigger then return end

	local human = rootModel:FindFirstChildWhichIsA("Humanoid")
	if not human then return end

	local maxHP = rootModel:GetAttribute("humanoidHealth")
	local delayTime = rootModel:GetAttribute("regenTime")

	local click = Trigger:FindFirstChildWhichIsA("ClickDetector")
	local prompt = Trigger:FindFirstChildWhichIsA("ProximityPrompt")

	rootModel.Head.Anchored = false
	Trigger.Anchored = false

	human.HealthChanged:Connect(function()
		if human.Health < 100 and not rootModel:GetAttribute("humanoidDead") then
			rootModel:SetAttribute("humanoidDead", true)

			if click and click:FindFirstChild("HighlightEnabled") then
				click:FindFirstChild("HighlightEnabled").Value = true
			elseif prompt then
				prompt:SetAttribute("Highlight_Enabled", true)
			end

			coroutine.wrap(function()		
				rootModel.Base.HingeConstraint.TargetAngle = -90
				if delayTime < 99 then
					wait(delayTime)
					human.Health = maxHP+100
					rootModel.Base.HingeConstraint.TargetAngle = 0
					rootModel:SetAttribute("humanoidDead", false)
				end
			end)()
		end
	end)

	if delayTime >= 99 then
		if click then
			click.MouseClick:Connect(function(plr)
				if rootModel:GetAttribute("humanoidDead") then
					rootModel:SetAttribute("humanoidDead", false)
					Trigger.ClickDetector.HighlightEnabled.Value = false
					human.Health = maxHP+100
					rootModel.Base.HingeConstraint.TargetAngle = 0
				end
			end)
		end
		if prompt then
			prompt.Triggered:Connect(function(plr)
				if rootModel:GetAttribute("humanoidDead") then
					rootModel:SetAttribute("humanoidDead", false)
					Trigger.ClickDetector.HighlightEnabled.Value = false
					human.Health = maxHP+100
					rootModel.Base.HingeConstraint.TargetAngle = 0
				end
			end)
		end
	else
		Trigger:Destroy()
	end

	rootModel:AddTag("INTERACT_LOADED")
end

return mod
