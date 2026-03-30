--[[       
INTERACTIVE SYSTEM
Wardrobe_Local
1.4.2
--]]

--// Services
local players = game:GetService("Players")
local plr = players.LocalPlayer
local collection = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")

--// Folders
local assets = replicatedStorage.INTERACT_Assets
local modules = assets.Modules
local wardrobe = require(modules.Wardrobe)

local ui = script.Parent
local giver = ui.Giver
local inUse = false

--// Functions
local function Combine(a1, a2)
	local new = table.create(#a1 + #a2)
	table.move(a1, 1, #a1, 1, new)
	table.move(a2, 1, #a2, 1 + #a1, new)
	return new
end

local function SetupUI()
	local uiExample = ui.Frame.List.UIListLayout.Example

	local uniformLocation1 = giver and giver.Value and giver.Value:GetAttribute("Wardrobe_Folder")
	local uniformLocation2 = plr.Team.Name
	local uniforms = (uniformLocation1 and assets.Uniforms:FindFirstChild(uniformLocation1)) or (uniformLocation2 and assets.Uniforms:FindFirstChild(uniformLocation2))
	local uniforms2 = assets.Uniforms --default, non-team non-exclusive morphs in the Uniforms folder
	local morphs = (uniforms and Combine(uniforms:GetChildren(), uniforms2:GetChildren())) or uniforms2:GetChildren()

	for _, Morph in pairs(morphs) do
		if Morph:IsA("Model") then
			local newUi = uiExample:Clone()
			newUi.Name = Morph.Name
			newUi.Example.Text = Morph.Name
			newUi.Example.Activated:Connect(function()
				if inUse then return end
				inUse = true
				if plr.Character  then
					assets.Events.Uniform:FireServer(Morph)
					EndUI()
				end
				inUse = false
			end)
			newUi.Parent = ui.Frame.List
		end
	end
end

function EndUI()
	inUse = true
	game.Debris:AddItem(script.Parent, 0.1)
end

ui.Frame.Exit.Activated:Connect(EndUI)
SetupUI()