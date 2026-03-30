--[[       
INTERACTIVE SYSTEM
Wardrobe
1.4.3

by Jarr (@SrJarr) aka jarr__
RELEASED FOR FREE - DRAGOON'S DEN
--]]

--// Services
local tweens = game:GetService("TweenService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local mod = {}

mod.InitializeWithCoroutine = false
mod.RunWithCoroutine = false
mod.RunTags = 
	{ --tag, function to run
		["Wardrobe"] = "SetupWardrobe",
		["Wardrobe_Single"] = "SetupSingleGiver"
	}

--// Folders
local assets = replicatedStorage.INTERACT_Assets
local config = require(assets.GlobalSettings)

local infrared = assets.Modules:FindFirstChild("InfraredVision") and require(assets.Modules.InfraredVision)

local armorvalues = {"HelmetBlastProtect", "HelmetProtect", "VestBlastProtect", "VestProtect", "HelmetVida", "VestVida"}
local bodyparts = {"LeftUpperArm", "LeftLowerArm", "LeftHand", "Left Arm", "RightUpperArm", "RightLowerArm", "RightHand", "Right Arm", "LeftFoot", "LeftLowerLeg", "LeftUpperLeg", "Left Leg", "RightFoot", "RightLowerLeg", "RightUpperLeg", "Right Leg",  "Head", "UpperTorso", "LowerTorso", "Torso"}

--// Functions
local function GetUnit(plr, unit, board)
	local TrelloModule = game.ServerScriptService:FindFirstChild("TrelloAPI")
	if not TrelloModule then print("Trello API is not installed - skipping check") return true end

	local TrelloAPI = require(TrelloModule)
	local BoardID = TrelloAPI.BoardsAPI.GetBoardID(board) 
	local ListId = TrelloAPI.BoardsAPI.GetListID(BoardID,unit)

	if TrelloAPI.CardsAPI.GetCardOnList(ListId,plr.Name) then
		return true
	else
		return false
	end	
end

local function recursive(parent,root)
	for k,v in pairs(parent:GetChildren()) do
		if v:IsA("BasePart") then
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = v
			w.C1 = v.CFrame:toObjectSpace(root.CFrame)
			w.Parent = root
			v.Anchored = false
			v.CanCollide = false
		elseif v:IsA("Model") and v.Name ~= "Up" then
			recursive(v,root)
		end
	end
end

local function GiveClothes(char, shirt, pants) -- give the player their fit
	local existingShirt = char:FindFirstChildWhichIsA("Shirt")
	if shirt and existingShirt then
		existingShirt.ShirtTemplate = shirt
	elseif shirt then
		local s = Instance.new("Shirt")
		s.ShirtTemplate = shirt
		s.Parent = char
	end

	local existingPants = char:FindFirstChildWhichIsA("Pants")
	if pants and existingPants then
		existingPants.PantsTemplate = pants
	elseif pants then
		local s = Instance.new("Pants")
		s.PantsTemplate = pants
		s.Parent = char
	end	
	if char:FindFirstChild("Shirt Graphic") then -- removes t-shirts
		char:FindFirstChild("Shirt Graphic"):Destroy()
	end
end

local function GiveUI(char:Model, ui:ScreenGui, morph)
	local player = game.Players:GetPlayerFromCharacter(char)
	if not player then return end
	
	local newUI = ui:Clone()
	newUI.Parent = player.PlayerGui
end

local function GiveLoadout(char, tools, replace) --give players their guns
	local plr = game.Players:GetPlayerFromCharacter(char)
	if not plr then return end

	--Remove existing tools if requested
	if replace then
		local inv2 = char:FindFirstChildWhichIsA("Tool")
		if inv2 then inv2.Parent = plr.Backpack end

		local inventory = plr.Backpack:GetChildren()
		for _, tool in ipairs(inventory) do
			if not tool:IsA("Tool") then continue end
			tool:Destroy()
		end
	end

	--Give tools
	for _, tool in ipairs(tools) do
		if not tool:IsA("Tool") then continue end

		local newTool = tool:Clone()
		newTool.Parent = plr.Backpack
	end
end

local function GiveArmor(char, model) --Give players ACS armor 
	local ACS_Client = char:FindFirstChild("ACS_Client")
	if ACS_Client then ACS_Client=ACS_Client.Protecao end

	local ACS_Client2 = char:FindFirstChild("Saude")
	if ACS_Client2 then ACS_Client2=ACS_Client2.Protecao end

	for _,armorValue in armorvalues do
		local foundValue = (ACS_Client and ACS_Client:FindFirstChild(armorValue)) or (ACS_Client2 and ACS_Client2:FindFirstChild(armorValue))
		local newValue = model:FindFirstChild(armorValue)

		if not foundValue or not newValue then continue end
		foundValue.Value = newValue.Value
	end
end

local function HatRemove(char)
	for each, part:Accessory in char:GetChildren() do 
		if part:IsA("Accessory") then
			part:Destroy()
		end 
	end
end

local function ApplyMorph(morph, part)
	recursive(morph,morph.Middle)
	local Y = Instance.new("Weld", part)
	Y.Part0 = part
	Y.Part1 = morph.Middle
	morph.Middle.Transparency = 1
	Y.C0 = CFrame.new(0, 0, 0)
	local h = morph:GetChildren()
	for i = 1, # h do
		h[i].Anchored = false
		h[i].CanCollide = false
		h[i].Massless = true
	end
end

local function DeleteMorph(char)
	local charParts = char:GetChildren()

	for _, part in charParts do
		local isMorphPart = string.find(part.Name, "_morph")
		
		if part:IsA("Model") and isMorphPart then
			if part:GetAttribute("setInvis") then part.Transparency=0 end
			if part:FindFirstChild("face") and part.face.Transparency==1 then part.face.Transparency=0 end

			part:Destroy()
		elseif part:IsA("Model") and (part:FindFirstChild("HolsterWeld") or part:HasTag("NightVis_Goggles")) then
			part:Destroy()
		elseif part:IsA("ObjectValue") and part.Name=="UI_morph" then
			part.Value:Destroy()	
			part:Destroy()
		end
	end
	char:SetAttribute("Morph", nil)
end

local function calculateTotalWeight(parts)
	local totalWeight = 0
	for _, part in pairs(parts) do
		local weight = part:GetAttribute("chanceWeight")
		if weight then
			totalWeight += weight
		end
	end
	return totalWeight
end

local function selectWeightedPart(parts)
	local totalWeight = calculateTotalWeight(parts)
	local partWeight = {}
	local sumWeight = 0

	-- Calculate weight sum
	for _, part in pairs(parts) do
		if part:GetAttribute("chanceWeight") then
			sumWeight += part:GetAttribute("chanceWeight")
			table.insert(partWeight, {part, sumWeight})
		end
	end

	-- Select part based on the sum of weights
	local randomWeight = math.random(1, sumWeight)
	for _, entry in pairs(partWeight) do
		if entry[2] >= randomWeight then
			return entry[1]
		end
	end
end

function mod.FindMorph(char,target)
	char:SetAttribute("Morph", target.Name)

	--Gather all valid body parts and group them by name, also do clothing while we're at it
	local bodyPartGroups = {}
	for _, part in ipairs(target:GetChildren()) do

		if part:IsA("Model") and part.Name=="Loadout" then
			GiveLoadout(char, part:GetChildren(), part:GetAttribute("replaceTools"))
		elseif part:IsA("Model") and part.Name=="Armor" then
			GiveArmor(char, part)
		elseif part:IsA("Model") and part:HasTag("NightVis_Goggles") and infrared then
			infrared.GiveNVG(game.Players:GetPlayerFromCharacter(char), part)
		elseif part:IsA("Model") or part:IsA("BodyColors") then
			if not bodyPartGroups[part.Name] then bodyPartGroups[part.Name]={} end
			table.insert(bodyPartGroups[part.Name], part)
		elseif part:IsA("Shirt") then
			GiveClothes(char, part.ShirtTemplate, nil)
		elseif part:IsA("Pants") then
			GiveClothes(char, nil, part.PantsTemplate)
		elseif part:IsA("ScreenGui") then
			GiveUI(char, part)
		end
	end

	--Do morphs
	for bodyPartName, parts in pairs(bodyPartGroups) do
		local selectedParts = {}
		local weightedParts = {}

		for _, part in pairs(parts) do
			if part:GetAttribute("chanceWeight") then
				table.insert(weightedParts, part)
			else
				table.insert(selectedParts, part)
			end
		end

		-- If there are weighted parts, select one of them
		if #weightedParts > 0 then
			local selectedWeightedPart = selectWeightedPart(weightedParts)
			table.insert(selectedParts, selectedWeightedPart)
		end

		-- Clone and attach selected parts to the character
		for _, selectedPart:Model? in pairs(selectedParts) do
			if selectedPart.Name == "Uniform" then
				local shirt = selectedPart:FindFirstChildWhichIsA("Shirt")
				local pant = selectedPart:FindFirstChildWhichIsA("Pants")
				GiveClothes(char, shirt.ShirtTemplate, pant.PantsTemplate)
			elseif selectedPart:IsA("BodyColors") then
				local newPart = selectedPart:Clone()
				newPart.Parent = char
			else
				local newPart = selectedPart:Clone()

				--Head renaming & hat removal
				if newPart.Name == "Top" or newPart.Name == "Head" then
					newPart.Name = "Head"
					HatRemove(char)
				end

				local rigPart = char[newPart.Name]
				newPart.Parent = char
				newPart.Name = newPart.Name.."_morph"
				ApplyMorph(newPart,  rigPart)

				local bodypartInvis = newPart:GetAttribute("setInvis")
				if bodypartInvis then rigPart.Transparency=1 end
				if rigPart:FindFirstChild("face") and bodypartInvis==true then rigPart.face.Transparency=1 end
			end
		end
	end
end


--// Core Functions
function mod.GiveMorph(plr:Player, morph:Model)
	local unitReq = morph:GetAttribute("unitRequired")
	local unitReq2 = morph:GetAttribute("unitTrelloBoard")
	if unitReq and unitReq2 and not GetUnit(plr, unitReq, unitReq2) then return end

	local currentMorph = plr.Character:GetAttribute("Morph")
	if currentMorph and currentMorph~=nil then DeleteMorph(plr.Character) end
	DeleteMorph(plr.Character)
	HatRemove(plr.Character)
	mod.FindMorph(plr.Character, morph)
end

function mod.SetupSingleGiver(rootModel:Model)
	--/ Initialize
	local Trigger = rootModel:FindFirstChild("Trigger")
	if not Trigger then return end

	local prompt = Trigger:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(plr)
			mod.GiveMorph(plr, Trigger.Morph.Value)
		end)
	end

	rootModel:AddTag("INTERACT_LOADED")
end

function mod.Initialize()
	assets.Events.Uniform.OnServerEvent:Connect(function(plr:Player, morph:Model)
		if not plr or not morph then return end

		if morph:GetAttribute("unitFormals") then
			local unitReq = morph:GetAttribute("unitFormals")
			local unitReq2 = morph:GetAttribute("unitTrelloBoard")
			if not GetUnit(plr, unitReq, unitReq2) then return end

			local currentMorph = plr.Character:GetAttribute("Morph")
			if currentMorph and currentMorph~=nil then DeleteMorph(plr.Character) end

			local findmorph = assets.Uniforms[plr.Team.Name]["Formals"][morph:GetAttribute("unitFormals")][plr:GetRoleInGroup(config.Groups[plr.Team.Name]["GroupID"])]
			if not findmorph then return end

			HatRemove(plr.Character)
			mod.FindMorph(plr.Character, findmorph)
		else
			local unitReq = morph:GetAttribute("unitRequired")
			local unitReq2 = morph:GetAttribute("unitTrelloBoard")
			if unitReq and unitReq2 and not GetUnit(plr, unitReq, unitReq2) then return end

			local currentMorph = plr.Character:GetAttribute("Morph")
			if currentMorph and currentMorph~=nil then DeleteMorph(plr.Character) end

			HatRemove(plr.Character)
			mod.FindMorph(plr.Character, morph)
		end
	end)
end

function mod.SetupWardrobe(rootModel: Model)
	if rootModel:IsDescendantOf(replicatedStorage) then return end
	if rootModel:HasTag("INTERACT_LOADED") then return end
	
	--/ Initialize
	local Trigger = rootModel:FindFirstChild("Trigger")
	if not Trigger then return end

	local click = Trigger:FindFirstChildWhichIsA("ClickDetector")
	if click then
		click.MouseClick:Connect(function(plr)
			local oldUI = plr.PlayerGui:FindFirstChild("UniformGui")
			if oldUI then oldUI:Destroy() end

			local ui = script.UniformGui:Clone()
			ui.Parent = plr.PlayerGui
			ui.Giver.Value = rootModel
			ui.Wardrobe_Local.Enabled = true
		end)
	end
	local prompt = Trigger:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(plr)
			local oldUI = plr.PlayerGui:FindFirstChild("UniformGui")
			if oldUI then oldUI:Destroy() end

			local ui = script.UniformGui:Clone()
			ui.Parent = plr.PlayerGui
			ui.Giver.Value = rootModel
			ui.Wardrobe_Local.Enabled = true
		end)
	end

	rootModel:AddTag("INTERACT_LOADED")
end

return mod
